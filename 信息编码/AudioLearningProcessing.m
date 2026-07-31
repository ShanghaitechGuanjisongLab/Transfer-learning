%% AudioLearningProcessing.m
% 仿 Runyan et al. 2017 — 解码听觉学习阶段的 hit vs miss
%
% 数据: AudioLightBaseline, AudioWater 阶段
% 每只鼠: 选取命中率最接近 50% 的 block
% 20 trials 训练, 10 trials 验证
% 时间窗口: 0-1s (post-stimulus)
% 目标: 线性解码器检测 hit/miss
% 图中标注所选 block 的命中率

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

%% 2. Define time windows
% Post-stimulus: 0-1s
tMask   = (xs >= 0) & (xs <= 1);
tIdx    = find(tMask);
nTimeWin = numel(tIdx);
fprintf('Time window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdx(1)), xs(tIdx(end)), nTimeWin);

%% 3. Per-mouse block selection
% Get Blocks table with Performance
Blk = DS.Blocks;
Blk.BlockUID = uint64(Blk.BlockUID);
Blk.DateTime = datetime(Blk.DateTime);
if ~isempty(Blk.DateTime.TimeZone); Blk.DateTime.TimeZone = ''; end
Blk.Mouse = strings(height(Blk), 1);

% Map DateTime -> Mouse
DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
[~, idxDt] = ismember(Blk.DateTime, DT.DateTime);
validDt = idxDt > 0;
Blk.Mouse(validDt) = DT.Mouse(idxDt(validDt));

% Trials table for trial-to-block mapping
Tr = DS.Trials;
Tr.BlockUID = uint64(Tr.BlockUID);
Tr.Stimulus = string(Tr.Stimulus);
Tr.Behavior = double(Tr.Behavior);

mice = unique(DT.Mouse);
fprintf('=== AudioLearningProcessing: block selection ===\n');

% Store selected block info per mouse
selBlock = struct('Mouse', cell(numel(mice), 1), 'BlockUID', [], ...
    'DateTime', [], 'HitRate', [], 'NTrials', [], 'TrainUIDs', [], ...
    'ValUIDs', []);

nValid = 0;
for iM = 1:numel(mice)
    m = mice(iM);
    
    % Find AudioWater blocks for this mouse
    blkIdx = find(Blk.Mouse == m);
    awBlocks = Blk(blkIdx, :);
    
    % Match to trials to confirm AudioWater
    hasAW = false(height(awBlocks), 1);
    for iB = 1:height(awBlocks)
        trIdx = (Tr.BlockUID == awBlocks.BlockUID(iB));
        hasAW(iB) = any(Tr.Stimulus(trIdx) == "AudioWater");
    end
    awBlocks = awBlocks(hasAW, :);
    if isempty(awBlocks)
        fprintf('  %s: no AudioWater blocks found\n', m);
        continue;
    end
    
    % Get block hit rates
    hitRates = awBlocks.Performance;
    validBlocks = ~isnan(hitRates);
    awBlocks = awBlocks(validBlocks, :);
    hitRates = hitRates(validBlocks);
    if isempty(awBlocks)
        fprintf('  %s: no blocks with valid Performance\n', m);
        continue;
    end
    
    % Find block with hit rate closest to 50%
    [~, bestIdx] = min(abs(hitRates - 0.5));
    chosenBlk = awBlocks(bestIdx, :);
    chosenHR = hitRates(bestIdx);
    
    % Get trials for this block
    trInBlock = Tr(Tr.BlockUID == chosenBlk.BlockUID, :);
    trInBlock = trInBlock(trInBlock.Stimulus == "AudioWater", :);
    trialUIDs = unique(uint64(trInBlock.TrialUID));
    
    % Filter to trials with valid behavior
    beh = trInBlock.Behavior;
    validTr = ~isnan(beh);
    trInBlock = trInBlock(validTr, :);
    trialUIDs = unique(uint64(trInBlock.TrialUID));
    
    nTrAvail = numel(trialUIDs);
    if nTrAvail < 30
        fprintf('  %s: block HR=%.1f%%, only %d trials (need 30), skipping\n', ...
            m, chosenHR*100, nTrAvail);
        continue;
    end
    
    % Split: 20 training, 10 validation (stratified by behavior)
    % First, get behavior for each trial
    behByTrial = nan(nTrAvail, 1);
    for iT = 1:nTrAvail
        rows = trInBlock(uint64(trInBlock.TrialUID) == trialUIDs(iT), :);
        behByTrial(iT) = mode(double(rows.Behavior));
    end
    
    hitIdx = find(behByTrial == 1);
    missIdx = find(behByTrial == 0);
    nHit = numel(hitIdx);
    nMiss = numel(missIdx);
    if nHit < 2 || nMiss < 2
        fprintf('  %s: block HR=%.1f%%, imbalance H=%d M=%d, skipping\n', ...
            m, chosenHR*100, nHit, nMiss);
        continue;
    end
    
    % Adaptive stratified split — reserve at least 2 of each class for validation
    nValHit  = min(5, max(2, floor(nHit/3)));
    nValMiss = min(5, max(2, floor(nMiss/3)));
    nTrHit  = nHit - nValHit;
    nTrMiss = nMiss - nValMiss;
    if nTrHit + nTrMiss < 10 || nValHit + nValMiss < 4
        continue;
    end
    
    rng(iM); % per-mouse seed
    permHit = hitIdx(randperm(nHit));
    permMiss = missIdx(randperm(nMiss));
    trainHit = permHit(1:nTrHit);
    trainMiss = permMiss(1:nTrMiss);
    valHit = permHit(nTrHit+1 : nHit);
    valMiss = permMiss(nTrMiss+1 : nMiss);
    
    trainIdx = [trainHit; trainMiss];
    valIdx = [valHit; valMiss];
    
    nValid = nValid + 1;
    selBlock(nValid).Mouse = m;
    selBlock(nValid).BlockUID = chosenBlk.BlockUID;
    selBlock(nValid).DateTime = chosenBlk.DateTime;
    selBlock(nValid).HitRate = chosenHR;
    selBlock(nValid).NTrials = nTrAvail;
    selBlock(nValid).TrainUIDs = trialUIDs(trainIdx);
    selBlock(nValid).ValUIDs = trialUIDs(valIdx);
    selBlock(nValid).TrainBeh = behByTrial(trainIdx);
    selBlock(nValid).ValBeh = behByTrial(valIdx);
    
    fprintf('  %s: block HR=%.1f%%, trials=%d (train H=%d M=%d, val H=%d M=%d)\n', ...
        m, chosenHR*100, nTrAvail, nTrHit, nTrMiss, nValHit, nValMiss);
end
selBlock = selBlock(1:nValid);

if nValid == 0
    fprintf('No valid mice found.\n');
    return;
end
fprintf('Total valid mice: %d\n', nValid);

%% 4. Decoding: per-mouse LASSO logistic regression
% 每个时间点独立训练解码器 (0-1s)
decResults = cell(nValid, 1);

for iM = 1:nValid
    s = selBlock(iM);
    fprintf('========== Decoding %s (%d/%d) ==========\n', s.Mouse, iM, nValid);
    
    % Query neural data for this session
    q = struct('Mouse', s.Mouse, 'DateTime', s.DateTime, 'Stimulus', "AudioWater");
    resp = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:nTime, ...
        'ExtraColumns', ["Behavior","DateTime"]);
    if isempty(resp) || isempty(resp{1})
        fprintf('  SKIP: no neural data\n');
        continue;
    end
    rawTbl = resp{1};
    if ~ismember('TrialSignal', string(rawTbl.Properties.VariableNames))
        fprintf('  SKIP: no TrialSignal\n');
        continue;
    end
    
    % Filter to selected trial UIDs
    allTrialUIDs = uint64(rawTbl.TrialUID);
    trainMask = ismember(allTrialUIDs, s.TrainUIDs);
    valMask   = ismember(allTrialUIDs, s.ValUIDs);
    
    trainRaw = rawTbl(trainMask, :);
    valRaw   = rawTbl(valMask, :);
    
    if height(trainRaw) < 10 || height(valRaw) < 5
        fprintf('  SKIP: too few trials after filtering\n');
        continue;
    end
    
    % Build cell UIDs
    allCellUIDs = [trainRaw.CellUID; valRaw.CellUID];
    cellUIDs = uint64(unique(allCellUIDs));
    nCell = numel(cellUIDs);
    if nCell < 5
        fprintf('  SKIP: %d cells\n', nCell);
        continue;
    end
    
    % Build trial matrices (0-1s window)
    [XTrain, yTrain] = iBuildTrialMatrix(trainRaw, cellUIDs, tIdx);
    [XVal,   yVal]   = iBuildTrialMatrix(valRaw,   cellUIDs, tIdx);
    
    if isempty(XTrain) || isempty(XVal)
        fprintf('  SKIP: empty feature matrix\n');
        continue;
    end
    if sum(yTrain==1) < 2 || sum(yTrain==0) < 2 || ...
       sum(yVal==1) < 2 || sum(yVal==0) < 2
        fprintf('  SKIP: class imbalance\n');
        continue;
    end
    
    nTr = size(XTrain, 1);
    nVl = size(XVal, 1);
    nT = size(XTrain, 3);
    fprintf('  Cells=%d  Train=%d(H%d/M%d)  Val=%d(H%d/M%d)  TimePts=%d\n', ...
        nCell, nTr, sum(yTrain==1), sum(yTrain==0), ...
        nVl, sum(yVal==1), sum(yVal==0), nT);
    
    % Per-time-point LASSO logistic regression
    decAccTr = nan(nT, 1);
    decAccVl = nan(nT, 1);
    decPVal  = nan(nT, 1);
    decShufMn = nan(nT, 1);
    decShufSd = nan(nT, 1);
    
    lambdaFix = 1 / sqrt(nTr) * 0.02;
    nShuffle = 100;
    
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
        
        % Train LASSO
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
                sa(iS) = 0.5;
            end
        end
        decShufMn(iT) = mean(sa, 'omitnan');
        decShufSd(iT) = std(sa, 'omitnan');
        decPVal(iT) = (sum(sa >= decAccVl(iT), 'omitnan') + 1) / (nShuf + 1);
    end
    
    % Store
    decRes = struct();
    decRes.Mouse = s.Mouse;
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
    decRes.BlockHitRate = s.HitRate;
    decResults{iM} = decRes;
    
    bestT = find(decAccVl == max(decAccVl, [], 'omitnan'), 1);
    if ~isempty(bestT)
        fprintf('  Peak @t=%.2fs: Acc=%.1f%% (train=%.1f%%)\n', ...
            xs(tIdx(bestT)), decAccVl(bestT)*100, decAccTr(bestT)*100);
    end
end

%% 5. Summary
validIdx = find(~cellfun(@isempty, decResults));
nValidDone = numel(validIdx);
fprintf('\n========== SUMMARY ==========\n');
fprintf('Valid mice: %d/%d\n', nValidDone, nValid);

for i = 1:nValidDone
    r = decResults{validIdx(i)};
    peakAcc = max(r.DecAccVal, [], 'omitnan');
    meanAcc = mean(r.DecAccVal, 'omitnan');
    fprintf('  %s: cells=%d blockHR=%.1f%% peakAcc=%.1f%% meanAcc=%.1f%% (H%d/M%d)\n', ...
        r.Mouse, r.NCells, r.BlockHitRate*100, peakAcc*100, meanAcc*100, ...
        r.NHitVal, r.NMissVal);
end

%% 6. Figure
if nValidDone == 0
    fprintf('No valid results to plot.\n');
    return;
end

% ---- 6a. Per-mouse time-resolved decoding ----
nCols = min(4, nValidDone);
nRows = ceil(nValidDone / nCols);
fDec = figure('Name','AudioLearningProcessing','Color','w', ...
    'Position', [50 50 nCols*320 nRows*260]);
tiledlayout(fDec, nRows, nCols, 'TileSpacing','compact','Padding','compact');

timeVec = xs(tIdx);

for i = 1:nValidDone
    r = decResults{validIdx(i)};
    ax = nexttile; hold(ax, 'on');
    
    validT = ~isnan(r.DecAccVal);
    plot(ax, timeVec(validT), r.DecAccVal(validT)*100, '-', ...
        'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
    plot(ax, timeVec(validT), r.DecAccTrain(validT)*100, '-', ...
        'Color', [0 0.4470 0.7410], 'LineWidth', 0.8);
    if any(~isnan(r.ShufMean))
        plot(ax, timeVec(validT), r.ShufMean(validT)*100, '--', ...
            'Color', [0.5 0.5 0.5], 'LineWidth', 0.6);
        xV = timeVec(validT);
        yLo = (r.ShufMean(validT) - r.ShufStd(validT)) * 100;
        yHi = (r.ShufMean(validT) + r.ShufStd(validT)) * 100;
        fill(ax, [xV; flipud(xV)], [yLo; flipud(yHi)], ...
            [0.5 0.5 0.5], 'EdgeColor', 'none', 'FaceAlpha', 0.15);
    end
    yline(ax, 50, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5);
    
    % Significant time points
    sigT = validT & r.PVal < 0.05;
    if any(sigT)
        scatter(ax, timeVec(sigT), r.DecAccVal(sigT)*100, 6, ...
            [0.8500 0.3250 0.0980], 'filled', 'MarkerEdgeColor', 'none');
    end
    
    hold(ax, 'off');
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Decoding (%)');
    title(ax, sprintf('%s (cells=%d, HR=%.0f%%)', ...
        r.Mouse, r.NCells, r.BlockHitRate*100), ...
        'FontSize', 8, 'FontWeight', 'normal');
    xlim(ax, [timeVec(1), timeVec(end)]);
    ylim(ax, [30 100]);
    ax.FontSize = 7; box(ax, 'off');
    if i == 1
        legend(ax, {'Validation','Training','Shuffle'}, ...
            'Location', 'southeast', 'Box', 'off', 'FontSize', 5);
    end
end
for i = nValidDone+1 : nRows*nCols
    nexttile; axis off;
end
sgtitle(fDec, sprintf('AudioLearningProcessing: hit/miss decoding (AudioWater, 0-1s)'), ...
    'FontSize', 9);

% ---- 6b. Average decoding curve ----
fAvg = figure('Name','ALP Average','Color','w', ...
    'Position', [100 100 360 280]);
axAvg = axes(fAvg); hold(axAvg, 'on');

nTwin = numel(tIdx);
allDec = nan(nValidDone, nTwin);
allShuf = nan(nValidDone, nTwin);
allHR = nan(nValidDone, 1);
for i = 1:nValidDone
    r = decResults{validIdx(i)};
    allDec(i, :) = r.DecAccVal(:)';
    allShuf(i, :) = r.ShufMean(:)';
    allHR(i) = r.BlockHitRate;
end

mnDec = mean(allDec, 1, 'omitnan') * 100;
seDec = std(allDec, 0, 1, 'omitnan') / sqrt(nValidDone) * 100;
mnShuf = mean(allShuf, 1, 'omitnan') * 100;

plot(axAvg, timeVec, mnDec, '-', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 2);
xV = timeVec(:)';
fill(axAvg, [xV, fliplr(xV)], [mnDec-seDec, fliplr(mnDec+seDec)], ...
    [0.8500 0.3250 0.0980], 'EdgeColor', 'none', 'FaceAlpha', 0.2);
plot(axAvg, timeVec, mnShuf, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
yline(axAvg, 50, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

hold(axAvg, 'off');
xlabel(axAvg, 'Time from stimulus (s)');
ylabel(axAvg, 'Decoding accuracy (%)');
title(axAvg, sprintf('Average across %d mice (block HR range: %.0f%%-%.0f%%)', ...
    nValidDone, min(allHR)*100, max(allHR)*100), ...
    'FontSize', 9, 'FontWeight', 'normal');
legend(axAvg, {'Decoding','Shuffle','Chance'}, ...
    'Location', 'southeast', 'Box', 'off');
xlim(axAvg, [timeVec(1), timeVec(end)]);
ylim(axAvg, [30 100]);
box(axAvg, 'off');

%% 7. Export
TransferLearning.ExportStandardFigure(fDec, 2, 'AudioLearningProcessing_PerMouse.svg');
TransferLearning.ExportStandardFigure(fAvg, 2, 'AudioLearningProcessing_Average.svg');

fprintf('\nDone. %d/%d mice with valid results.\n', nValidDone, nValid);


% ==================== Local Functions ====================

function [X, y] = iBuildTrialMatrix(rawTbl, cellUIDs, tIdx)
% Convert QueryNTS table to [nTrial x nCell x nTime] array
% Only keeps time points specified by tIdx
sig = double(rawTbl.TrialSignal);
nTimeFull = size(sig, 2);
sig = sig(:, tIdx);  % subset to window
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
