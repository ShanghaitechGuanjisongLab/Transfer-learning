%% debug_compare_heatmaps.m
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
rng(42);

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);

tMaskFull  = (xs >= -1) & (xs <= 1);
tMaskTrain = (xs >= 0) & (xs <= 1);
tIdxFull   = find(tMaskFull);
tIdxTrain  = find(tMaskTrain);
tIdxTrainInFull = find(ismember(tIdxFull, tIdxTrain));
nTfull     = numel(tIdxFull);
nTtrain    = numel(tIdxTrain);

TQ = DS.TableQuery("Mouse", Phase="Transfer", Stimulus="LightWater");
TQ.Mouse = string(TQ.Mouse);
mice = sort(unique(TQ.Mouse));

allNormCells = 0;
allRawCells = 0;
allSameMaskCount = 0;
allSamePeakCount = 0;

for iM = 1:numel(mice)
    m = mice(iM);
    resp = DS.QueryNTS(struct('Mouse',m,'Phase','Transfer','Stimulus','LightWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior","DateTime"]);
    rawTbl = resp{1};
    if isempty(rawTbl) || ~ismember('TrialSignal', string(rawTbl.Properties.VariableNames))
        continue;
    end
    cellUIDs = uint64(unique(rawTbl.CellUID));
    [X, yHit] = iBuildTransferHitMissMatrix(rawTbl, cellUIDs);
    if isempty(X)
        continue;
    end
    X = X(:, :, tIdxFull);
    nTr = size(X, 1);
    if sum(yHit == 1) < 2 || sum(yHit == 0) < 2
        continue;
    end

    nCell = numel(cellUIDs);
    miHit = nan(nCell, nTfull);
    encP = nan(nCell, nTfull);
    nBins = max(3, min(8, round(sqrt(nTr)/2)*2));

    for iC = 1:nCell
        for iT = 1:nTfull
            act = squeeze(X(:, iC, iT));
            if all(isnan(act)) || range(act) == 0
                continue;
            end
            try
                [~, ~, stats] = glmfit(yHit, act, 'normal');
                encP(iC, iT) = stats.p(2);
            catch
            end
            miHit(iC, iT) = iPtCorrectedMI(act, yHit, nBins);
        end
    end

    miHitNorm = nan(size(miHit));
    for iC = 1:nCell
        denom = max(miHit(iC, tIdxTrainInFull), [], 'omitnan');
        if ~isnan(denom) && denom > 0
            miHitNorm(iC, :) = miHit(iC, :) ./ denom;
        end
    end

    sigTrain = any(encP(:, tIdxTrainInFull) < 0.05, 2);
    if ~any(sigTrain)
        continue;
    end

    normPeak = max(miHitNorm(sigTrain, tIdxTrainInFull), [], 2, 'omitnan');
    rawPeak = max(miHit(sigTrain, tIdxTrainInFull), [], 2, 'omitnan');

    validNorm = ~isnan(normPeak);
    validRaw = ~isnan(rawPeak);

    allNormCells = allNormCells + sum(validNorm);
    allRawCells = allRawCells + sum(validRaw);
    allSameMaskCount = allSameMaskCount + sum(sigTrain);
    allSamePeakCount = allSamePeakCount + sum(validNorm & validRaw);
end

fprintf('Total significant cells by same mask: %d\n', allSameMaskCount);
fprintf('Heatmap C valid cells (norm MI): %d\n', allNormCells);
fprintf('Heatmap D valid cells (raw MI): %d\n', allRawCells);
fprintf('Cells with valid peak in both heatmaps: %d\n', allSamePeakCount);

function mi = iPtCorrectedMI(act, label, nBins)
    n = numel(act);
    if n < 4 || range(act) == 0 || numel(unique(label)) < 2
        mi = 0; return;
    end
    [~, edges] = histcounts(act, nBins);
    if numel(unique(edges)) < 2
        mi = 0; return;
    end
    actBin = discretize(act, edges);
    if all(isnan(actBin)); mi = 0; return; end
    joint = zeros(nBins, 2);
    for i = 1:n
        if ~isnan(actBin(i))
            joint(actBin(i), label(i)+1) = joint(actBin(i), label(i)+1) + 1;
        end
    end
    joint(sum(joint,2)==0, :) = [];
    pJoint = joint / sum(joint(:));
    px = sum(pJoint, 2);
    py = sum(pJoint, 1);
    miRaw = 0;
    for i = 1:size(pJoint,1)
        for j = 1:2
            if pJoint(i,j) > 0 && px(i) > 0 && py(j) > 0
                miRaw = miRaw + pJoint(i,j) * log2(pJoint(i,j) / (px(i) * py(j)));
            end
        end
    end
    Mx = size(pJoint, 1);
    My = 2;
    bias = (Mx - 1) * (My - 1) / (2 * n * log(2));
    mi = max(0, miRaw - bias);
end

function [X, yHit] = iBuildTransferHitMissMatrix(rawTbl, cellUIDs)
    sig = double(rawTbl.TrialSignal);
    nTime = size(sig, 2);
    ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), double(rawTbl.Behavior), ...
        'VariableNames', {'CellUID','TrialUID','Behavior'});
    sigCell = cell(size(sig, 1), 1);
    for i = 1:size(sig, 1)
        sigCell{i} = sig(i, :);
    end
    ntsTbl.Signal = sigCell;
    keepRows = ismember(ntsTbl.CellUID, cellUIDs);
    ntsTbl = ntsTbl(keepRows, :);
    if isempty(ntsTbl)
        X = []; yHit = []; return;
    end
    trialUIDs = unique(ntsTbl.TrialUID);
    nTrials = numel(trialUIDs);
    nCells = numel(cellUIDs);
    X = zeros(nTrials, nCells, nTime);
    yHit = nan(nTrials, 1);
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
        if isempty(beh)
            yHit(iT) = NaN;
        else
            yHit(iT) = mode(beh);
        end
    end
    hasData = all(isfinite(X), [2 3]) & isfinite(yHit);
    X = X(hasData, :, :);
    yHit = yHit(hasData);
    X(isnan(X)) = 0;
end
