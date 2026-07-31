%% DecodeALB_TransferToLearned.m
% 仿 Runyan et al. 2017 — 跨刺激泛化解码
%
% 思路:
%   训练集 = Transfer 阶段 LightWater（光水）0-1s 钙活动
%   验证集 = Learned 阶段 AudioWater（声水）0-1s 钙活动
%   考察训练于光水的解码器能否区分声水的 hit/miss
%
% 若迁移阶段的实际命中率 > 50%，chance level = 该命中率；
% 若 ≤ 50%，chance level = 50%
%
% 方法: 逐时间点 LASSO 逻辑回归（与 Runyan 一致）

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end

rng(42);

%% 1. Load dataset and time axis
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);

%% 2. List mice
TQ = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialUID"]);
TQ.Mouse = string(TQ.Mouse);
TQ.Phase = string(TQ.Phase);
TQ = sortrows(TQ, ["Mouse","DateTime"]);

mice = unique(TQ.Mouse);
fprintf('=== Decode ALB: Transfer LightWater → Learned AudioWater ===\n');
fprintf('Total mice: %d\n\n', numel(mice));

%% 2b. Define 0-1s post-stimulus window
tMask = (xs >= 0) & (xs <= 1);
tIdx = find(tMask);
nTimeWin = numel(tIdx);
fprintf('Time window: %.2f-%.2f s (%d time points / %d total)\n', ...
    xs(tIdx(1)), xs(tIdx(end)), nTimeWin, numel(xs));

%% 3. Per-mouse decoding
nMice = numel(mice);
decResults = cell(nMice, 1);
chanceByMouse = nan(nMice, 1);

for iM = 1:nMice
    m = mice(iM);
    fprintf('========== Mouse %s (%d/%d) ==========\n', m, iM, nMice);

    % ---- 3a. Training data: Transfer LightWater ----
    trainRaw = table();
    qTr = struct('Mouse', m, 'Phase', "Transfer", 'Stimulus', "LightWater");
    try
        resp = DS.QueryNTS(qTr, UniExp.Flags.ZScore, 1:nTime, ...
            'ExtraColumns', ["Behavior","DateTime"]);
        if ~isempty(resp) && ~isempty(resp{1})
            trainRaw = resp{1};
        end
    catch
    end

    if isempty(trainRaw) || ~ismember('TrialSignal', string(trainRaw.Properties.VariableNames))
        fprintf('  SKIP: no Transfer LightWater data\n');
        continue;
    end

    % Compute actual hit rate in Transfer LightWater → chance level
    trainBehaviors = double(trainRaw.Behavior);
    trainHitRate = mean(trainBehaviors == 1, 'omitnan');
    chanceLevel = max(trainHitRate, 0.5);
    chanceByMouse(iM) = chanceLevel;
    fprintf('  Transfer LightWater hit rate: %.1f%% → chance level: %.1f%%\n', ...
        trainHitRate*100, chanceLevel*100);

    % ---- 3b. Validation data: Learned AudioWater ----
    valRaw = table();
    qVal = struct('Mouse', m, 'Phase', "Learned", 'Stimulus', "AudioWater");
    try
        resp = DS.QueryNTS(qVal, UniExp.Flags.ZScore, 1:nTime, ...
            'ExtraColumns', ["Behavior","DateTime"]);
        if ~isempty(resp) && ~isempty(resp{1})
            valRaw = resp{1};
        end
    catch
    end

    if isempty(valRaw) || ~ismember('TrialSignal', string(valRaw.Properties.VariableNames))
        fprintf('  SKIP: no Learned AudioWater data\n');
        continue;
    end

    % ---- 3c. Build trial matrices ----
    allCellUIDs = [trainRaw.CellUID; valRaw.CellUID];
    cellUIDs = uint64(unique(allCellUIDs));
    nCell = numel(cellUIDs);
    if nCell < 5
        fprintf('  SKIP: only %d cells\n', nCell);
        continue;
    end

    [XTrain, yTrain] = iBuildTrialMatrix(trainRaw, cellUIDs);
    [XVal,   yVal]   = iBuildTrialMatrix(valRaw,   cellUIDs);

    % Subset to 0-1s post-stimulus window
    XTrain = XTrain(:, :, tIdx);
    XVal   = XVal(:, :, tIdx);

    if isempty(XTrain) || isempty(XVal)
        fprintf('  SKIP: empty feature matrix\n');
        continue;
    end
    if sum(yTrain==1) < 2 || sum(yTrain==0) < 2
        fprintf('  SKIP: training class imbalance (H=%d, M=%d)\n', ...
            sum(yTrain==1), sum(yTrain==0));
        continue;
    end
    fprintf('  Validation: H=%d, M=%d\n', sum(yVal==1), sum(yVal==0));

    nTr = size(XTrain, 1);
    nVl = size(XVal, 1);
    nT = size(XTrain, 3);
    fprintf('  Cells=%d  Train=%d(H%d/M%d, HR=%.1f%%)  Val=%d(H%d/M%d)  TimePts=%d\n', ...
        nCell, nTr, sum(yTrain==1), sum(yTrain==0), trainHitRate*100, ...
        nVl, sum(yVal==1), sum(yVal==0), nT);

    % ---- 3d. Decoding: per-time-point LASSO logistic regression ----
    decAccTr = nan(nT, 1);
    decAccVl = nan(nT, 1);
    decPVal  = nan(nT, 1);
    decShufMn = nan(nT, 1);
    decShufSd = nan(nT, 1);

    lambdaFix = 1 / sqrt(nTr) * 0.02;
    nShuffle = 1000;

    for iT = 1:nT
        xTr = squeeze(XTrain(:, :, iT));
        xVl = squeeze(XVal(:, :, iT));

        % Standardize
        muTr = mean(xTr, 1, 'omitnan');
        sdTr = std(xTr, 0, 1, 'omitnan');
        sdTr(sdTr == 0) = 1;
        xTrS = (xTr - muTr) ./ sdTr;
        xVlS = (xVl - muTr) ./ sdTr;
        xTrS(isnan(xTrS)) = 0;
        xVlS(isnan(xVlS)) = 0;

        if all(xTrS(:) == 0), continue; end

        % Train LASSO logistic regression
        try
            lrMdl = fitclinear(xTrS, yTrain, ...
                'Learner', 'logistic', ...
                'Regularization', 'lasso', ...
                'Lambda', lambdaFix, ...
                'Solver', 'sparsa');
        catch
            try
                lrMdl = fitclinear(xTrS, yTrain, ...
                    'Learner', 'logistic', ...
                    'Regularization', 'lasso', ...
                    'Lambda', lambdaFix);
            catch
                continue;
            end
        end

        % Predict
        predTr = predict(lrMdl, xTrS);
        predVl = predict(lrMdl, xVlS);

        decAccTr(iT) = mean(predTr == yTrain);
        decAccVl(iT) = mean(predVl == yVal);

        % Permutation test
        nShuf = min(nShuffle, nTr);
        sa = zeros(nShuf, 1);
        for iS = 1:nShuf
            sy = yTrain(randperm(nTr));
            try
                smdl = fitclinear(xTrS, sy, ...
                    'Learner', 'logistic', ...
                    'Regularization', 'lasso', ...
                    'Lambda', lambdaFix);
                sp = predict(smdl, xVlS);
                sa(iS) = mean(sp == yVal);
            catch
                sa(iS) = chanceLevel;
            end
        end
        decShufMn(iT) = mean(sa, 'omitnan');
        decShufSd(iT) = std(sa, 'omitnan');
        decPVal(iT) = (sum(sa >= decAccVl(iT), 'omitnan') + 1) / (nShuf + 1);
    end

    % ---- Store results ----
    decRes = struct();
    decRes.Mouse = m;
    decRes.CellUIDs = cellUIDs;
    decRes.NCells = nCell;
    decRes.DecAccTrain = decAccTr;
    decRes.DecAccVal   = decAccVl;
    decRes.PVal        = decPVal;
    decRes.ShufMean    = decShufMn;
    decRes.ShufStd     = decShufSd;
    decRes.NTrain = nTr;
    decRes.NVal   = nVl;
    decRes.NHitVal = sum(yVal==1);
    decRes.NMissVal = sum(yVal==0);
    decRes.TrainHitRate = trainHitRate;
    decRes.ChanceLevel = chanceLevel;
    decResults{iM} = decRes;

    bestT = find(decAccVl == max(decAccVl, [], 'omitnan'), 1);
    if ~isempty(bestT)
        fprintf('  Peak @t=%.2fs: ValAcc=%.1f%% (train=%.1f%%, chance=%.1f%%)\n', ...
            xs(tIdx(bestT)), decAccVl(bestT)*100, decAccTr(bestT)*100, chanceLevel*100);
    end
end

%% 4. Summary
validIdx = find(~cellfun(@isempty, decResults));
nValid = numel(validIdx);
fprintf('\n========== SUMMARY ==========\n');
fprintf('Valid mice: %d/%d\n', nValid, nMice);

peakValAcc    = nan(nValid, 1);
meanValAcc    = nan(nValid, 1);
mouseNames    = cell(nValid, 1);
mouseChance   = nan(nValid, 1);
aboveChanceCount = 0;

for i = 1:nValid
    r = decResults{validIdx(i)};
    peakValAcc(i) = max(r.DecAccVal, [], 'omitnan');
    meanValAcc(i) = mean(r.DecAccVal, 'omitnan');
    mouseNames{i} = r.Mouse;
    mouseChance(i) = r.ChanceLevel;
    bestT = find(r.DecAccVal == peakValAcc(i), 1);
    sigStr = '';
    if ~isnan(r.PVal(bestT)) && r.PVal(bestT) < 0.05
        sigStr = ' *';
        aboveChanceCount = aboveChanceCount + 1;
    end
    fprintf('  %s: cells=%d trainHR=%.1f%% chance=%.1f%% peakAcc=%.1f%% meanAcc=%.1f%% (H%d/M%d)%s\n', ...
        r.Mouse, r.NCells, r.TrainHitRate*100, r.ChanceLevel*100, ...
        peakValAcc(i)*100, meanValAcc(i)*100, ...
        r.NHitVal, r.NMissVal, sigStr);
end
fprintf('\nSignificant mice (peak p<0.05): %d/%d\n', aboveChanceCount, nValid);

%% 5. Figures
if nValid == 0
    fprintf('\nNo valid mice to plot.\n');
    return;
end

% ---- 5a. Per-mouse time-resolved decoding ----
nCols = min(4, nValid);
nRows = ceil(nValid / nCols);
fDec = figure('Name','Decode Transfer→Learned','Color','w', ...
    'Position', [50 50 nCols*320 nRows*260]);
tiledlayout(fDec, nRows, nCols, 'TileSpacing','compact','Padding','compact');

timeVec = xs(tIdx);

for i = 1:nValid
    r = decResults{validIdx(i)};
    ax = nexttile;
    hold(ax, 'on');

    % Validation accuracy
    validT = ~isnan(r.DecAccVal);
    hl = plot(ax, timeVec(validT), r.DecAccVal(validT)*100, '-', ...
        'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
    % Training accuracy
    plot(ax, timeVec(validT), r.DecAccTrain(validT)*100, '-', ...
        'Color', [0 0.4470 0.7410], 'LineWidth', 0.8);
    % Shuffle baseline
    if any(~isnan(r.ShufMean))
        plot(ax, timeVec(validT), r.ShufMean(validT)*100, '--', ...
            'Color', [0.5 0.5 0.5], 'LineWidth', 0.6);
        xV = timeVec(validT);
        yLo = (r.ShufMean(validT) - r.ShufStd(validT)) * 100;
        yHi = (r.ShufMean(validT) + r.ShufStd(validT)) * 100;
        fill(ax, [xV; flipud(xV)], [yLo; flipud(yHi)], ...
            [0.5 0.5 0.5], 'EdgeColor', 'none', 'FaceAlpha', 0.15);
    end
    % Chance level = max(trainHitRate, 50%)
    yline(ax, r.ChanceLevel*100, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

    % Highlight significant time points
    sigT = validT & r.PVal < 0.05;
    if any(sigT)
        scatter(ax, timeVec(sigT), r.DecAccVal(sigT)*100, 6, ...
            [0.8500 0.3250 0.0980], 'filled', 'MarkerEdgeColor', 'none');
    end

    hold(ax, 'off');
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Decoding (%)');
    title(ax, sprintf('%s (cells=%d)', r.Mouse, r.NCells), ...
        'FontSize', 8, 'FontWeight', 'normal');
    xlim(ax, [xs(tIdx(1)), xs(tIdx(end))]);
    ylim(ax, [min(30, min(r.DecAccVal(validT))*100 - 5), ...
              max(100, max(r.DecAccVal(validT))*100 + 5)]);
    ax.FontSize = 7;
    box(ax, 'off');
    if i == 1
        legend(ax, {'Validation (Learned AW)','Training (Transfer LW)','Shuffle'}, ...
            'Location', 'southeast', 'Box', 'off', 'FontSize', 5);
    end
end
for i = nValid+1 : nRows*nCols
    nexttile; axis off;
end
sgtitle(fDec, ...
    'Decode hit vs miss: Train on Transfer LightWater → Test on Learned AudioWater', ...
    'FontSize', 9);

% ---- 5b. Average decoding curve across mice ----
fAvg = figure('Name','Average decoding Transfer→Learned','Color','w', ...
    'Position', [100 100 360 280]);
axAvg = axes(fAvg);
hold(axAvg, 'on');

nTwin = numel(tIdx);
allDec = nan(nValid, nTwin);
allShuf = nan(nValid, nTwin);
for i = 1:nValid
    r = decResults{validIdx(i)};
    allDec(i, :) = r.DecAccVal(:)';
    allShuf(i, :) = r.ShufMean(:)';
end

mnDec = mean(allDec, 1, 'omitnan') * 100;
seDec = std(allDec, 0, 1, 'omitnan') / sqrt(nValid) * 100;
mnShuf = mean(allShuf, 1, 'omitnan') * 100;

% Mean chance level across mice
meanChance = mean(mouseChance) * 100;

hl = plot(axAvg, timeVec, mnDec, '-', 'Color', [0.8500 0.3250 0.0980], ...
    'LineWidth', 2);
% SE shading
xV = timeVec';
yLo = mnDec - seDec;
yHi = mnDec + seDec;
fill(axAvg, [xV; flipud(xV)], [yLo; flipud(yHi)], ...
    [0.8500 0.3250 0.0980], 'EdgeColor', 'none', 'FaceAlpha', 0.2);
% Shuffle
plot(axAvg, timeVec, mnShuf, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
% Chance level
yline(axAvg, meanChance, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

hold(axAvg, 'off');
xlabel(axAvg, 'Time from stimulus (s)');
ylabel(axAvg, 'Decoding accuracy (%)');
title(axAvg, sprintf('Average across %d mice (chance=%.1f%%)', nValid, meanChance), ...
    'FontSize', 9, 'FontWeight', 'normal');
legend(axAvg, {'Decoding','Shuffle','Chance'}, ...
    'Location', 'southeast', 'Box', 'off');
xlim(axAvg, [xs(tIdx(1)), xs(tIdx(end))]);
ylim(axAvg, [min(30, min(mnDec)-5), max(100, max(mnDec)+5)]);
box(axAvg, 'off');

% ---- 5c. Summary bar chart: mean decoding vs chance per mouse ----
fBar = figure('Name','Per-mouse mean decoding','Color','w', ...
    'Position', [150 150 400 300]);
axBar = axes(fBar);
hold(axBar, 'on');

xM = 1:nValid;
barColors = [0.8500 0.3250 0.0980];
b = bar(axBar, xM, meanValAcc*100, 'FaceColor', barColors, ...
    'EdgeColor', 'none', 'BarWidth', 0.6);
% Overlay chance level per mouse
scatter(axBar, xM, mouseChance*100, 40, 'ks', 'filled', ...
    'MarkerEdgeColor', 'k');

% Label significant mice
for i = 1:nValid
    r = decResults{validIdx(i)};
    bestT = find(r.DecAccVal == max(r.DecAccVal, [], 'omitnan'), 1);
    isSig = ~isnan(r.PVal(bestT)) && r.PVal(bestT) < 0.05;
    if isSig
        text(axBar, xM(i), meanValAcc(i)*100 + 2, '*', ...
            'HorizontalAlignment', 'center', 'FontSize', 14, ...
            'Color', 'r');
    end
end

hold(axBar, 'off');
xlabel(axBar, 'Mouse'); ylabel(axBar, 'Mean decoding (%)');
title(axBar, 'Mean decoding accuracy (0-1s)', ...
    'FontSize', 9, 'FontWeight', 'normal');
axBar.XTick = xM;
axBar.XTickLabel = mouseNames;
axBar.XTickLabelRotation = 45;
axBar.FontSize = 7;
box(axBar, 'off');
ylim(axBar, [0, max([meanValAcc*100; mouseChance*100])*1.3 + 5]);

fprintf('\nDone. %d/%d mice with valid data.\n', nValid, nMice);


% ==================== Local Functions ====================

function [X, y] = iBuildTrialMatrix(rawTbl, cellUIDs)
% Convert QueryNTS table to [nTrial x nCell x nTime] array
% cellUIDs: uint64 vector of cells to include
sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), 'VariableNames', {'CellUID','TrialUID','Behavior'});
sigCell = cell(size(sig,1), 1);
for i = 1:size(sig,1); sigCell{i} = sig(i,:); end
ntsTbl.Signal = sigCell;

% Filter to relevant cells
keepRows = ismember(ntsTbl.CellUID, cellUIDs);
ntsTbl = ntsTbl(keepRows, :);
if isempty(ntsTbl); X=[]; y=[]; return; end

trialUIDs = unique(ntsTbl.TrialUID);
nTrials = numel(trialUIDs);
nCells = numel(cellUIDs);
X = zeros(nTrials, nCells, nTime);
y = nan(nTrials, 1);
for iT = 1:nTrials
    rows = ntsTbl(ntsTbl.TrialUID == trialUIDs(iT), :);
    [~, loc] = ismember(rows.CellUID, cellUIDs);
    for iR = 1:height(rows)
        ci = loc(iR);
        if ci > 0
            X(iT, ci, :) = rows.Signal{iR};
        end
    end
    beh = rows.Behavior(~isnan(rows.Behavior));
    if isempty(beh); y(iT) = NaN; else; y(iT) = mode(beh); end
end

% Remove degenerate trials
hasData = all(isfinite(X), [2 3]) & isfinite(y);
X = X(hasData, :, :);
y = y(hasData);
X(isnan(X)) = 0;
end
