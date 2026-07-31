%% DecodeALB_TransferToNaiveVsLearned.m
% 仿 Runyan et al. 2017 — 跨刺激泛化解码：Naive vs Learned 对比
%
% 思路:
%   训练集 = Transfer 阶段 LightWater（光水）0-1s 钙活动（固定）
%   验证集 = Naive AudioWater vs Learned AudioWater（对比）
%
%   若解码器在 Naive 上差、在 Learned 上好 → 表征是任务学习塑造的
%   若解码器在两者上均好 → 表征先天存在或与任务无关
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
fprintf('=== Decode ALB: Transfer→Naive vs Learned ===\n');
fprintf('Total mice: %d\n\n', numel(mice));

%% 2b. Define 0-1s post-stimulus window
tMask = (xs >= 0) & (xs <= 1);
tIdx = find(tMask);
nTimeWin = numel(tIdx);
fprintf('Time window: %.2f-%.2f s (%d time points / %d total)\n', ...
    xs(tIdx(1)), xs(tIdx(end)), nTimeWin, numel(xs));

%% 3. Per-mouse decoding (two validation sets)
nMice = numel(mice);
decNaive   = cell(nMice, 1);  % Train: Transfer LW → Val: Naive AW
decLearned = cell(nMice, 1);  % Train: Transfer LW → Val: Learned AW

for iM = 1:nMice
    m = mice(iM);
    fprintf('========== Mouse %s (%d/%d) ==========\n', m, iM, nMice);

    % ---- Training data: Transfer LightWater (shared) ----
    trainRaw = table();
    try
        resp = DS.QueryNTS(struct('Mouse',m,'Phase',"Transfer",'Stimulus',"LightWater"), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","DateTime"]);
        if ~isempty(resp) && ~isempty(resp{1}); trainRaw = resp{1}; end
    catch, end

    if isempty(trainRaw) || ~ismember('TrialSignal', string(trainRaw.Properties.VariableNames))
        fprintf('  SKIP: no Transfer LightWater data\n'); continue;
    end

    trainBehaviors = double(trainRaw.Behavior);
    trainHitRate = mean(trainBehaviors == 1, 'omitnan');
    chanceLevel = max(trainHitRate, 0.5);
    fprintf('  Transfer LightWater HR=%.1f%% → chance=%.1f%%\n', ...
        trainHitRate*100, chanceLevel*100);
    if sum(trainBehaviors==1) < 2 || sum(trainBehaviors==0) < 2
        fprintf('  SKIP: training class imbalance\n'); continue;
    end

    % ---- Validation set 1: Naive AudioWater ----
    valNaive = table();
    try
        resp = DS.QueryNTS(struct('Mouse',m,'Phase',"Naive",'Stimulus',"AudioWater"), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","DateTime"]);
        if ~isempty(resp) && ~isempty(resp{1}); valNaive = resp{1}; end
    catch, end

    % ---- Validation set 2: Learned AudioWater ----
    valLearned = table();
    try
        resp = DS.QueryNTS(struct('Mouse',m,'Phase',"Learned",'Stimulus',"AudioWater"), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","DateTime"]);
        if ~isempty(resp) && ~isempty(resp{1}); valLearned = resp{1}; end
    catch, end

    if isempty(valNaive) || isempty(valLearned)
        fprintf('  SKIP: missing validation data (Naive=%d, Learned=%d)\n', ...
            height(valNaive), height(valLearned)); continue;
    end
    if ~ismember('TrialSignal', string(valNaive.Properties.VariableNames)) || ...
       ~ismember('TrialSignal', string(valLearned.Properties.VariableNames))
        fprintf('  SKIP: no TrialSignal in validation\n'); continue;
    end

    % ---- Build common cell list ----
    allCellUIDs = [trainRaw.CellUID; valNaive.CellUID; valLearned.CellUID];
    cellUIDs = uint64(unique(allCellUIDs));
    nCell = numel(cellUIDs);
    if nCell < 5; fprintf('  SKIP: %d cells\n', nCell); continue; end

    % ---- Build trial matrices ----
    [XTrain, yTrain] = iBuildTrialMatrix(trainRaw, cellUIDs);
    [XNaive, yNaive] = iBuildTrialMatrix(valNaive, cellUIDs);
    [XLearned, yLearned] = iBuildTrialMatrix(valLearned, cellUIDs);

    XTrain = XTrain(:, :, tIdx);
    XNaive = XNaive(:, :, tIdx);
    XLearned = XLearned(:, :, tIdx);

    if isempty(XTrain) || isempty(XNaive) || isempty(XLearned)
        fprintf('  SKIP: empty feature matrix\n'); continue;
    end

    nTr = size(XTrain, 1);
    nT = size(XTrain, 3);
    fprintf('  Cells=%d  Train=%d(H%d/M%d)  ', nCell, nTr, sum(yTrain==1), sum(yTrain==0));
    fprintf('Naive=%d(H%d/M%d)  Learned=%d(H%d/M%d)\n', ...
        size(XNaive,1), sum(yNaive==1), sum(yNaive==0), ...
        size(XLearned,1), sum(yLearned==1), sum(yLearned==0));

    % ---- Run decoding for both validation sets ----
    lambdaFix = 1 / sqrt(nTr) * 0.02;
    nShuffle = 1000;

    for valSet = 1:2
        if valSet == 1
            XVl = XNaive; yVl = yNaive; phaseStr = 'Naive';
        else
            XVl = XLearned; yVl = yLearned; phaseStr = 'Learned';
        end

        decAccTr = nan(nT, 1);
        decAccVl = nan(nT, 1);
        decPVal  = nan(nT, 1);
        decShufMn = nan(nT, 1);
        decShufSd = nan(nT, 1);

        for iT = 1:nT
            xTr = squeeze(XTrain(:, :, iT));
            xVl = squeeze(XVl(:, :, iT));

            muTr = mean(xTr, 1, 'omitnan');
            sdTr = std(xTr, 0, 1, 'omitnan');
            sdTr(sdTr == 0) = 1;
            xTrS = (xTr - muTr) ./ sdTr;
            xVlS = (xVl - muTr) ./ sdTr;
            xTrS(isnan(xTrS)) = 0;
            xVlS(isnan(xVlS)) = 0;

            if all(xTrS(:) == 0), continue; end

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
                catch, continue; end
            end

            predTr = predict(lrMdl, xTrS);
            predVl = predict(lrMdl, xVlS);
            decAccTr(iT) = mean(predTr == yTrain);
            decAccVl(iT) = mean(predVl == yVl);

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
                    sa(iS) = mean(sp == yVl);
                catch
                    sa(iS) = chanceLevel;
                end
            end
            decShufMn(iT) = mean(sa, 'omitnan');
            decShufSd(iT) = std(sa, 'omitnan');
            decPVal(iT) = (sum(sa >= decAccVl(iT), 'omitnan') + 1) / (nShuf + 1);
        end

        res = struct();
        res.Mouse = m;
        res.Phase = phaseStr;
        res.CellUIDs = cellUIDs;
        res.NCells = nCell;
        res.DecAccTrain = decAccTr;
        res.DecAccVal   = decAccVl;
        res.PVal        = decPVal;
        res.ShufMean    = decShufMn;
        res.ShufStd     = decShufSd;
        res.NTrain = nTr;
        res.NVal   = size(XVl, 1);
        res.NHitVal = sum(yVl==1);
        res.NMissVal = sum(yVl==0);
        res.TrainHitRate = trainHitRate;
        res.ChanceLevel = chanceLevel;

        if valSet == 1
            decNaive{iM} = res;
        else
            decLearned{iM} = res;
        end

        bestT = find(decAccVl == max(decAccVl, [], 'omitnan'), 1);
        if ~isempty(bestT)
            fprintf('  %s: peak @t=%.2fs ValAcc=%.1f%% (chance=%.1f%%)\n', ...
                phaseStr, xs(tIdx(bestT)), decAccVl(bestT)*100, chanceLevel*100);
        end
    end
end

%% 4. Summary
validNaiveIdx   = find(~cellfun(@isempty, decNaive));
validLearnedIdx = find(~cellfun(@isempty, decLearned));
commonIdx = intersect(validNaiveIdx, validLearnedIdx);
nValid = numel(commonIdx);

fprintf('\n========== SUMMARY ==========\n');
fprintf('Mice with both Naive and Learned: %d/%d\n', nValid, nMice);

meanNaive   = nan(nValid, 1);
meanLearned = nan(nValid, 1);
peakNaive   = nan(nValid, 1);
peakLearned = nan(nValid, 1);
mouseNames  = cell(nValid, 1);

for i = 1:nValid
    idx = commonIdx(i);
    rN = decNaive{idx};
    rL = decLearned{idx};
    mouseNames{i} = rN.Mouse;
    meanNaive(i)   = mean(rN.DecAccVal, 'omitnan');
    meanLearned(i) = mean(rL.DecAccVal, 'omitnan');
    peakNaive(i)   = max(rN.DecAccVal, [], 'omitnan');
    peakLearned(i) = max(rL.DecAccVal, [], 'omitnan');

    btN = find(rN.DecAccVal == peakNaive(i), 1);
    btL = find(rL.DecAccVal == peakLearned(i), 1);
    sigN = ~isnan(rN.PVal(btN)) && rN.PVal(btN) < 0.05;
    sigL = ~isnan(rL.PVal(btL)) && rL.PVal(btL) < 0.05;

    fprintf('  %s: cells=%d | Naive: peak=%.1f%% mean=%.1f%% (H%d/M%d)%s | Learned: peak=%.1f%% mean=%.1f%% (H%d/M%d)%s\n', ...
        rN.Mouse, rN.NCells, ...
        peakNaive(i)*100, meanNaive(i)*100, rN.NHitVal, rN.NMissVal, ternary(sigN,' *',''), ...
        peakLearned(i)*100, meanLearned(i)*100, rL.NHitVal, rL.NMissVal, ternary(sigL,' *',''));
end

% Paired test
if nValid >= 3
    [~, pairedP] = ttest(meanNaive, meanLearned);
    fprintf('\nPaired t-test (Naive vs Learned mean acc): p=%.4f\n', pairedP);
    dCohen = (mean(meanLearned) - mean(meanNaive)) / std(meanLearned - meanNaive, 'omitnan');
    fprintf('Cohen''s d = %.3f (%.1f%% vs %.1f%%)\n', dCohen, ...
        mean(meanLearned)*100, mean(meanNaive)*100);
end

%% 5. Figures
if nValid == 0
    fprintf('\nNo valid mice to plot.\n');
    return;
end

timeVec = reshape(xs(tIdx), 1, []);
nTwin = numel(tIdx);

% ---- 5a. Per-mouse: Naive vs Learned time course ----
nCols = min(4, nValid);
nRows = ceil(nValid / nCols);
fComp = figure('Name','Naive vs Learned decoding','Color','w', ...
    'Position', [50 50 nCols*340 nRows*280]);
tiledlayout(fComp, nRows, nCols, 'TileSpacing','compact','Padding','compact');

for i = 1:nValid
    idx = commonIdx(i);
    rN = decNaive{idx};
    rL = decLearned{idx};
    ax = nexttile; hold(ax, 'on');

    validT = ~isnan(rN.DecAccVal);
    hl = plot(ax, timeVec(validT), rL.DecAccVal(validT)*100, '-', ...
        'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
    hn = plot(ax, timeVec(validT), rN.DecAccVal(validT)*100, '-', ...
        'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);

    % Shuffle bands (Learned) — not included in legend
    if any(~isnan(rL.ShufMean))
        xV = timeVec(validT);
        yLo = (rL.ShufMean(validT)' - rL.ShufStd(validT)') * 100;
        yHi = (rL.ShufMean(validT)' + rL.ShufStd(validT)') * 100;
        fill(ax, [xV; flipud(xV)], [yLo; flipud(yHi)], ...
            [0.8500 0.3250 0.0980], 'EdgeColor', 'none', 'FaceAlpha', 0.08, ...
            'HandleVisibility', 'off');
    end
    % Shuffle bands (Naive) — not included in legend
    if any(~isnan(rN.ShufMean))
        xV = timeVec(validT);
        yLo = (rN.ShufMean(validT)' - rN.ShufStd(validT)') * 100;
        yHi = (rN.ShufMean(validT)' + rN.ShufStd(validT)') * 100;
        fill(ax, [xV; flipud(xV)], [yLo; flipud(yHi)], ...
            [0 0.4470 0.7410], 'EdgeColor', 'none', 'FaceAlpha', 0.08, ...
            'HandleVisibility', 'off');
    end

    % Chance level
    hc = yline(ax, rN.ChanceLevel*100, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.6);

    % Significant time points (Learned)
    sigT = validT & rL.PVal < 0.05;
    if any(sigT)
        scatter(ax, timeVec(sigT), rL.DecAccVal(sigT)*100, 4, ...
            [0.8500 0.3250 0.0980], 'filled', 'MarkerEdgeColor', 'none');
    end
    % Significant time points (Naive)
    sigN = validT & rN.PVal < 0.05;
    if any(sigN)
        scatter(ax, timeVec(sigN), rN.DecAccVal(sigN)*100, 4, ...
            [0 0.4470 0.7410], 'filled', 'MarkerEdgeColor', 'none');
    end

    hold(ax, 'off');
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Decoding (%)');
    title(ax, sprintf('%s (%d cells)', rN.Mouse, rN.NCells), ...
        'FontSize', 8, 'FontWeight', 'normal');
    xlim(ax, [xs(tIdx(1)), xs(tIdx(end))]);
    ylim(ax, [0 105]);
    ax.FontSize = 7;
    box(ax, 'off');
    if i == 1
        legend(ax, [hl, hn, hc], {'Learned AW','Naive AW','Chance'}, ...
            'Location', 'southeast', 'Box', 'off', 'FontSize', 5);
    end
end
for i = nValid+1 : nRows*nCols
    nexttile; axis off;
end
sgtitle(fComp, ...
    'Decode hit vs miss: Train Transfer LightWater, test on Naive vs Learned AudioWater', ...
    'FontSize', 8);

% ---- 5b. Average time course (Naive vs Learned) ----
fAvg = figure('Name','Average Naive vs Learned','Color','w', ...
    'Position', [100 100 360 280]);
axAvg = axes(fAvg); hold(axAvg, 'on');

allN = nan(nValid, nTwin);
allL = nan(nValid, nTwin);
for i = 1:nValid
    idx = commonIdx(i);
    allN(i, :) = decNaive{idx}.DecAccVal(:)';
    allL(i, :) = decLearned{idx}.DecAccVal(:)';
end

mnN = mean(allN, 1, 'omitnan') * 100;
seN = std(allN, 0, 1, 'omitnan') / sqrt(nValid) * 100;
mnL = mean(allL, 1, 'omitnan') * 100;
seL = std(allL, 0, 1, 'omitnan') / sqrt(nValid) * 100;

hL = plot(axAvg, timeVec, mnL, '-', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 2);
hN = plot(axAvg, timeVec, mnN, '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 2);
% SE shading — not included in legend
fill(axAvg, [timeVec, fliplr(timeVec)], [mnL-seL, fliplr(mnL+seL)], ...
    [0.8500 0.3250 0.0980], 'EdgeColor', 'none', 'FaceAlpha', 0.15, ...
    'HandleVisibility', 'off');
fill(axAvg, [timeVec, fliplr(timeVec)], [mnN-seN, fliplr(mnN+seN)], ...
    [0 0.4470 0.7410], 'EdgeColor', 'none', 'FaceAlpha', 0.15, ...
    'HandleVisibility', 'off');

% Average chance
meanChance = mean(arrayfun(@(i) decNaive{commonIdx(i)}.ChanceLevel, 1:nValid)) * 100;
hC = yline(axAvg, meanChance, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

hold(axAvg, 'off');
xlabel(axAvg, 'Time from stimulus (s)');
ylabel(axAvg, 'Decoding accuracy (%)');
title(axAvg, sprintf('Average across %d mice', nValid), ...
    'FontSize', 9, 'FontWeight', 'normal');
legend(axAvg, [hL, hN, hC], {'Learned AW','Naive AW','Chance'}, ...
    'Location', 'southeast', 'Box', 'off');
xlim(axAvg, [xs(tIdx(1)), xs(tIdx(end))]);
ylim(axAvg, [0 105]);
box(axAvg, 'off');

% ---- 5c. Paired bar chart: mean decoding (Naive vs Learned per mouse) ----
fBar = figure('Name','Paired comparison','Color','w', ...
    'Position', [150 150 500 350]);
axBar = axes(fBar); hold(axBar, 'on');

xM = 1:nValid;
barWidth = 0.35;
% Learned bars
bar(axBar, xM - barWidth/2, meanLearned*100, barWidth, ...
    'FaceColor', [0.8500 0.3250 0.0980], 'EdgeColor', 'none');
% Naive bars
bar(axBar, xM + barWidth/2, meanNaive*100, barWidth, ...
    'FaceColor', [0 0.4470 0.7410], 'EdgeColor', 'none');

% Connect paired points with lines
for i = 1:nValid
    plot(axBar, xM(i) + [-1 1]*barWidth/2, ...
        [meanNaive(i) meanLearned(i)]*100, '-', ...
        'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
end

% Mark significance
for i = 1:nValid
    idx = commonIdx(i);
    btN = find(decNaive{idx}.DecAccVal == peakNaive(i), 1);
    btL = find(decLearned{idx}.DecAccVal == peakLearned(i), 1);
    sigN = ~isnan(decNaive{idx}.PVal(btN)) && decNaive{idx}.PVal(btN) < 0.05;
    sigL = ~isnan(decLearned{idx}.PVal(btL)) && decLearned{idx}.PVal(btL) < 0.05;
    if sigL
        text(axBar, xM(i)-barWidth/2, meanLearned(i)*100+2, '*', ...
            'HorizontalAlignment','center','FontSize',12,'Color',[0.8500 0.3250 0.0980]);
    end
    if sigN
        text(axBar, xM(i)+barWidth/2, meanNaive(i)*100+2, '*', ...
            'HorizontalAlignment','center','FontSize',12,'Color',[0 0.4470 0.7410]);
    end
end

hold(axBar, 'off');
xlabel(axBar, 'Mouse'); ylabel(axBar, 'Mean decoding 0-1s (%)');
title(axBar, 'Transfer LightWater → AudioWater decoding', ...
    'FontSize', 9, 'FontWeight', 'normal');
axBar.XTick = xM;
axBar.XTickLabel = mouseNames;
axBar.XTickLabelRotation = 45;
axBar.FontSize = 7;
box(axBar, 'off');
ylim(axBar, [0 110]);
legend(axBar, {'Learned AW','Naive AW'}, ...
    'Location', 'northeast', 'Box', 'off');

% Paired t-test annotation
if nValid >= 3
    [~, pValPaired] = ttest(meanNaive, meanLearned);
    annotation(fBar, 'textbox', [0.15 0.92 0.7 0.05], ...
        'String', sprintf('Paired t: p=%.4f, d=%.3f (N=%d)', ...
        pValPaired, (mean(meanLearned)-mean(meanNaive))/std(meanLearned-meanNaive,'omitnan'), nValid), ...
        'FontSize', 7, 'EdgeColor', 'none', 'HorizontalAlignment', 'center');
end

fprintf('\nDone. %d/%d mice with both validation sets.\n', nValid, nMice);


% ==================== Local Functions ====================

function [X, y] = iBuildTrialMatrix(rawTbl, cellUIDs)
sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), 'VariableNames', {'CellUID','TrialUID','Behavior'});
sigCell = cell(size(sig,1), 1);
for i = 1:size(sig,1); sigCell{i} = sig(i,:); end
ntsTbl.Signal = sigCell;
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
        if ci > 0; X(iT, ci, :) = rows.Signal{iR}; end
    end
    beh = rows.Behavior(~isnan(rows.Behavior));
    if isempty(beh); y(iT) = NaN; else; y(iT) = mode(beh); end
end
hasData = all(isfinite(X), [2 3]) & isfinite(y);
X = X(hasData, :, :);
y = y(hasData);
X(isnan(X)) = 0;
end

function s = ternary(cond, t, f)
if cond; s = t; else; s = f; end
end