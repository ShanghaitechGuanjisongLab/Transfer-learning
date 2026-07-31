% TrainClassifierPerMouse.m
% 对AudioLightBaseline每只鼠训练分类器（SGD逻辑回归，逐epoch记录准确率）
% 训练集：从第一个Naive session到第一个Learned session之间的所有trial
%         （含Phase=Naive, <missing>, Learned，只要Behavior有0/1即hit/miss）
% 特征：每个细胞在0-1s窗口的平均ZScore（基线-3~0s）
% 验证集：Transfer阶段的LightWater trial
% 输出：每只鼠训练集学习曲线 + 验证集学习曲线 + 权重热图

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

rng(42);

%% ===== 0) Setup =====
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
xsSec = seconds(xs);
mask01 = (xsSec >= 0) & (xsSec <= 1);
idx01 = find(mask01);
idxBaseline = 1:24;

%% ===== 1) List mice =====
TQ = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialUID"]);
TQ.Mouse = string(TQ.Mouse);
TQ.Phase = string(TQ.Phase);
TQ = sortrows(TQ, ["Mouse","DateTime"]);
mice = unique(TQ.Mouse);
fprintf('=== AudioLightBaseline Mice (%d) ===\n', numel(mice));
for i = 1:numel(mice)
    fprintf('  %d. %s\n', i, mice(i));
end

%% ===== 2) Per-mouse classifier training =====
nMice = numel(mice);
results = cell(nMice, 1);

N_EPOCHS = 60;

for iM = 1:nMice
    m = mice(iM);
    fprintf('\n========== Mouse %s (%d/%d) ==========\n', m, iM, nMice);

    cellRows = DS.Cells(string(DS.Cells.Mouse) == m, :);
    cellUIDs = uint64(cellRows.CellUID);
    nC = numel(cellUIDs);
    fprintf('  Cells: %d\n', nC);
    if nC < 5, fprintf('  SKIP: too few cells\n'); continue; end

    mouseTrials = TQ(TQ.Mouse == m, :);
    if isempty(mouseTrials), fprintf('  SKIP: no trials\n'); continue; end

    % Session range: first Naive -> first Learned
    naiveIdx = find(mouseTrials.Phase == "Naive", 1, 'first');
    learnedIdx = find(mouseTrials.Phase == "Learned", 1, 'first');
    if isempty(naiveIdx), fprintf('  SKIP: no Naive phase\n'); continue; end

    if ~isempty(learnedIdx)
        learnedDT = mouseTrials.DateTime(learnedIdx);
        trainMask = (1:height(mouseTrials))' >= naiveIdx & mouseTrials.DateTime <= learnedDT;
    else
        trainMask = (1:height(mouseTrials))' >= naiveIdx;
    end

    valMask = mouseTrials.Phase == "Transfer";
    hasBehavior = isfinite(mouseTrials.Behavior);

    trainTrials = mouseTrials(trainMask & hasBehavior, :);
    valTrials = mouseTrials(valMask & hasBehavior, :);

    validStimuli = ["AudioOnly","AudioWater","LightOnly","LightWater"];
    trainTrials = trainTrials(ismember(string(trainTrials.Stimulus), validStimuli), :);
    valTrials = valTrials(ismember(string(valTrials.Stimulus), validStimuli), :);

    if height(trainTrials) < 10 || height(valTrials) < 5
        fprintf('  SKIP: too few train/val (%d train, %d val)\n', ...
            height(trainTrials), height(valTrials));
        continue;
    end

    % Query neural data
    trainData = iQueryNtsByGroup(DS, m, trainTrials, idxBaseline);
    valData = iQueryNtsByGroup(DS, m, valTrials, idxBaseline);
    if isempty(trainData) || isempty(valData), fprintf('  SKIP: empty neural data\n'); continue; end

    % Build feature matrices
    [XTrain, yTrain, trainUIDs] = iBuildTrialFeatureMatrix(trainData, cellUIDs, idx01);
    [XVal, yVal, valUIDs] = iBuildTrialFeatureMatrix(valData, cellUIDs, idx01);
    if isempty(XTrain) || isempty(XVal), fprintf('  SKIP: empty feature matrix\n'); continue; end

    nTr = size(XTrain, 1);
    nVl = size(XVal, 1);
    nHitTr = sum(yTrain == 1);
    nMissTr = sum(yTrain == 0);
    nHitVl = sum(yVal == 1);
    nMissVl = sum(yVal == 0);

    fprintf('  Train: %d trials (%d hit, %d miss), %d cells\n', nTr, nHitTr, nMissTr, nC);
    fprintf('  Val:   %d trials (%d hit, %d miss)\n', nVl, nHitVl, nMissVl);

    if nHitTr < 2 || nMissTr < 2, fprintf('  SKIP: need >=2 per class\n'); continue; end

    % ---- GRU Network (Ajioka 2024) ----
    % Scale hidden size to data amount
    if nTr < 120
        hiddenSize = 12;
    elseif nTr < 180
        hiddenSize = 14;
    else
        hiddenSize = 20;
    end
    fprintf('  Hidden=%d\n', hiddenSize);
    % Class weights for balanced loss
    classWeightHit = nTr / (2 * nHitTr);
    classWeightMiss = nTr / (2 * nMissTr);
    lr0 = 0.0005;
    batchSize = min(32, nTr);

    [net, trainBaccEpoch, valBaccEpoch] = iTrainGruNetwork(...
        XTrain, yTrain, XVal, yVal, N_EPOCHS, lr0, batchSize, hiddenSize, classWeightHit, classWeightMiss);

    finalTrBacc = trainBaccEpoch(end);
    finalVlBacc = valBaccEpoch(end);
    beta = [];
    betaRaw = [];

    fprintf('  Train BAcc: epoch0=%.3f, final=%.3f\n', trainBaccEpoch(1), finalTrBacc);
    fprintf('  Val BAcc:   epoch0=%.3f, final=%.3f\n', valBaccEpoch(1), finalVlBacc);

    res = struct();
    res.Mouse = m;
    res.CellUIDs = cellUIDs;
    res.NCells = nC;
    res.NTrain = nTr;
    res.HiddenSize = hiddenSize;
    res.NVal = nVl;
    res.TrainBAcc = finalTrBacc;
    res.ValBAcc = finalVlBacc;
    res.TrainBaccEpoch = trainBaccEpoch;
    res.ValBaccEpoch = valBaccEpoch;
    res.NEpochs = numel(valBaccEpoch);  % epoch 0 + actual trained epochs
    res.ValNpos = nHitVl;
    res.ValNneg = nMissVl;
    res.Net = net;
    res.XTrain = XTrain;
    res.yTrain = yTrain;
    res.XVal = XVal;
    res.yVal = yVal;
    results{iM} = res;
end

%% ===== 3) Summary =====
validIdx = find(~cellfun(@isempty, results));
fprintf('\n\n========== SUMMARY ==========\n');
fprintf('Mice with valid classifiers: %d/%d\n', numel(validIdx), nMice);

trBaccAll = nan(numel(validIdx), 1);
vlBaccAll = nan(numel(validIdx), 1);
mouseNames = cell(numel(validIdx), 1);
for i = 1:numel(validIdx)
    r = results{validIdx(i)};
    trBaccAll(i) = r.TrainBAcc;
    vlBaccAll(i) = r.ValBAcc;
    mouseNames{i} = r.Mouse;
    nHitTr = sum(r.yTrain==1);
    nMissTr = sum(r.yTrain==0);
    nEpActual = r.NEpochs - 1; % exclude epoch 0
    baccStr = sprintf('%.3f', r.ValBAcc);
    if r.ValBAcc > 0.5, baccStr = [baccStr, '*']; end
    fprintf('  %s: %d cells, %d train(%dH/%dM)/%d val, Train BAcc=%.3f, Val BAcc=%s (hidden=%d, epochs=%d)\n', ...
        r.Mouse, r.NCells, r.NTrain, nHitTr, nMissTr, r.NVal, r.TrainBAcc, baccStr, r.HiddenSize, nEpActual);
end
fprintf('Mean train BAcc: %.3f\n', mean(trBaccAll));
fprintf('Mean val BAcc:   %.3f\n', mean(vlBaccAll));

% Summary bar plot
fSum = figure('Color','w','Name','AUC summary');
fSum.Units = 'centimeters';
fSum.Position(3:4) = [8, 5];
axS = axes(fSum);
barData = [trBaccAll, vlBaccAll];
b = bar(axS, barData, 'grouped');
b(1).FaceColor = [0 0.4470 0.7410];
b(2).FaceColor = [0.8500 0.3250 0.0980];
set(axS, 'XTickLabel', mouseNames);
xtickangle(axS, 45);
ylabel(axS, 'Balanced Accuracy');
legend(axS, {'Train','Validation'},'Location','southeast','Box','off');
title(axS, 'Classifier Balanced Accuracy per mouse');
axS.FontSize = 8;
box(axS, 'off');
ylim(axS, [0 1]);
yline(axS, 0.5, '--k');
TransferLearning.ExportStandardFigure(fSum, 2, 'TrainClassifier_BAcc_Summary.svg');

%% ===== 4) Combined learning curves (subplots) =====
% All training curves in one figure, all validation curves in another
nValid = numel(validIdx);
nCols = 4;
nRows = 3;
window = max(1, round(N_EPOCHS/50));

% ---- Training curves ----
fTrain = figure('Color','w','Name','Training AUC curves (all mice)');
fTrain.Units = 'centimeters';
fTrain.Position(3:4) = [nCols*3.2, nRows*2.8];
LayoutTrain = tiledlayout(fTrain, nRows, nCols, 'TileSpacing','compact','Padding','compact');
xlabel(LayoutTrain, 'Epoch', 'FontSize',7);
ylabel(LayoutTrain, 'Balanced Acc', 'FontSize',7);

for i = 1:nValid
    r = results{validIdx(i)};
    ax = nexttile(LayoutTrain);
    bacc = r.TrainBaccEpoch;
    epochs = 0:(numel(bacc)-1);
    baccSmooth = movmean(bacc, window);
    plot(ax, epochs, bacc, '-', 'Color',[0 0.4470 0.7410],'LineWidth',0.3);
    hold(ax,'on');
    plot(ax, epochs, baccSmooth, '-', 'Color',[0 0.4470 0.7410],'LineWidth',1.2);
    yline(ax, 0.5, '--', 'Color',[0.5 0.5 0.5],'LineWidth',0.4);
    ylim(ax, [0 1]);
    xlim(ax, [0, r.NEpochs - 1]);
    title(ax, r.Mouse, 'FontSize',6, 'FontWeight','normal');
    ax.FontSize = 5;
    nEp = r.NEpochs - 1;
    ax.XTick = 0:5:nEp;
    box(ax,'off');
    % Balanced accuracy text at bottom-left
    text(ax, 0.02, 0.08, sprintf('%.3f', r.TrainBAcc), ...
        'Units','normalized', 'FontSize',5, 'Color',[0 0.4470 0.7410], ...
        'VerticalAlignment','bottom', 'HorizontalAlignment','left');
end
for i = nValid+1 : nRows*nCols
    nexttile(LayoutTrain); axis off;
end
TransferLearning.ExportStandardFigure(fTrain, 2, 'TrainClassifier_AllTrainBaccCurves.svg');

% ---- Validation curves ----
fVal = figure('Color','w','Name','Validation AUC curves (all mice)');
fVal.Units = 'centimeters';
fVal.Position(3:4) = [nCols*3.2, nRows*2.8];
LayoutVal = tiledlayout(fVal, nRows, nCols, 'TileSpacing','compact','Padding','compact');
xlabel(LayoutVal, 'Epoch', 'FontSize',7);
ylabel(LayoutVal, 'Balanced Acc', 'FontSize',7);

for i = 1:nValid
    r = results{validIdx(i)};
    ax = nexttile(LayoutVal);
    bacc = r.ValBaccEpoch;
    epochs = 0:(numel(bacc)-1);
    baccSmooth = movmean(bacc, window);
    plot(ax, epochs, bacc, '-', 'Color',[0.8500 0.3250 0.0980],'LineWidth',0.3);
    hold(ax,'on');
    plot(ax, epochs, baccSmooth, '-', 'Color',[0.8500 0.3250 0.0980],'LineWidth',1.2);
    yline(ax, 0.5, '--', 'Color',[0.5 0.5 0.5],'LineWidth',0.4);
    ylim(ax, [0 1]);
    xlim(ax, [0, r.NEpochs - 1]);
    title(ax, r.Mouse, 'FontSize',6, 'FontWeight','normal');
    ax.FontSize = 5;
    nEp = r.NEpochs - 1;
    ax.XTick = 0:5:nEp;
    box(ax,'off');
    % Balanced accuracy text at bottom-left; asterisk if >0.5
    baccStr = sprintf('%.3f', r.ValBAcc);
    if r.ValBAcc > 0.5, baccStr = [baccStr, '*']; end
    text(ax, 0.02, 0.08, baccStr, ...
        'Units','normalized', 'FontSize',5, 'Color',[0.8500 0.3250 0.0980], ...
        'VerticalAlignment','bottom', 'HorizontalAlignment','left');
end
for i = nValid+1 : nRows*nCols
    nexttile(LayoutVal); axis off;
end
TransferLearning.ExportStandardFigure(fVal, 2, 'TrainClassifier_AllValBaccCurves.svg');

fprintf('\nDone.\n');


% ===================== Local functions =====================

function [net, trainBacc, valBacc] = iTrainGruNetwork(XTrain, yTrain, XVal, yVal, nEpochs, lr0, batchSize, hiddenSize, wHit, wMiss)
% Ajioka 2024-style GRU network using custom dlnetwork training loop
% Returns trained network and balanced accuracy trajectories
% XTrain: cell array {nTrials×1}, each cell [nCells × 8] sequence
% yTrain: [nTrials×1] binary labels

nCells = size(XTrain{1}, 1);
nTrain = numel(yTrain);

% Build GRU network with dropout and L2 regularization
if hiddenSize <= 12
    dropoutRate = 0.1;
elseif hiddenSize <= 14
    dropoutRate = 0.2;
else
    dropoutRate = 0.3;
end
if dropoutRate > 0
    layers = [
        sequenceInputLayer(nCells, 'Name', 'input', 'Normalization', 'none')
        gruLayer(hiddenSize, 'Name', 'gru', 'OutputMode', 'last', ...
            'StateActivationFunction', 'tanh', 'GateActivationFunction', 'sigmoid')
        dropoutLayer(dropoutRate, 'Name', 'dropout')
        fullyConnectedLayer(1, 'Name', 'fc', 'WeightL2Factor', 2, 'BiasL2Factor', 1)
        sigmoidLayer('Name', 'sigmoid')
    ];
else
    layers = [
        sequenceInputLayer(nCells, 'Name', 'input', 'Normalization', 'none')
        gruLayer(hiddenSize, 'Name', 'gru', 'OutputMode', 'last', ...
            'StateActivationFunction', 'tanh', 'GateActivationFunction', 'sigmoid')
        fullyConnectedLayer(1, 'Name', 'fc', 'WeightL2Factor', 2, 'BiasL2Factor', 1)
        sigmoidLayer('Name', 'sigmoid')
    ];
end
net = dlnetwork(layerGraph(layers));

% Adam state
avgG = [];
avgSqG = [];

trainBacc = zeros(nEpochs + 1, 1);
valBacc = zeros(nEpochs + 1, 1);

% Convert cell arrays to 3-D dlarray: [nCells, nTrials, nTime]
XTr3D = cat(3, XTrain{:});
XTr3D = permute(XTr3D, [1, 3, 2]);
XTrDl = dlarray(single(XTr3D), 'CBT');

XVal3D = cat(3, XVal{:});
XVal3D = permute(XVal3D, [1, 3, 2]);
XValDl = dlarray(single(XVal3D), 'CBT');

% Epoch 0: evaluate initial network
pTr = double(extractdata(predict(net, XTrDl)))';
pVl = double(extractdata(predict(net, XValDl)))';

% Safety: ensure row vectors
pTr = pTr(:)'; pVl = pVl(:)';
yTr = yTrain(:); yVl = yVal(:);

trainBacc(1) = iBalancedAcc(pTr, yTr);
valBacc(1) = iBalancedAcc(pVl, yVl);

% Early stopping based on accuracy
patience = 5;
bestValAcc = -1;
bestEpoch = 0;
stallCount = 0;
nActualEpochs = nEpochs;

for epochIdx = 1:nEpochs
    idx = randperm(nTrain);
    yShuf = yTrain(idx);
    XShufDl = XTrDl(:, idx, :);

    for start = 1:batchSize:nTrain
        endIdx = min(start + batchSize - 1, nTrain);
        batchIdx = start:endIdx;
        XBatch = XShufDl(:, batchIdx, :);
        yBatch = dlarray(single(yShuf(batchIdx))', 'CB');

        [loss, gradients] = dlfeval(@iGruModelLoss, net, XBatch, yBatch, wHit, wMiss);
        [net, avgG, avgSqG] = adamupdate(net, gradients, avgG, avgSqG, epochIdx, lr0);
    end

    % Evaluate after training
    pTr = double(extractdata(predict(net, XTrDl)))';
    pVl = double(extractdata(predict(net, XValDl)))';
    pTr = pTr(:)'; pVl = pVl(:)';
    
    trainBacc(epochIdx + 1) = iBalancedAcc(pTr, yTr);
    valBacc(epochIdx + 1) = iBalancedAcc(pVl, yVl);
    
    trAcc = mean((pTr >= 0.5) == yTr);
    vlAcc = mean((pVl >= 0.5) == yVl);

    if trAcc >= 0.95
        if vlAcc > bestValAcc
            bestValAcc = vlAcc;
            bestEpoch = epochIdx;
            stallCount = 0;
        else
            stallCount = stallCount + 1;
            if stallCount >= patience
                nActualEpochs = epochIdx;
                break;
            end
        end
    else
        if vlAcc > bestValAcc
            bestValAcc = vlAcc;
            bestEpoch = epochIdx;
        end
        stallCount = 0;
    end
end

% Trim arrays to actual epochs
trainBacc = trainBacc(1 : nActualEpochs + 1);
valBacc = valBacc(1 : nActualEpochs + 1);
end

function bacc = iBalancedAcc(scores, labels)
% Balanced accuracy = (sensitivity + specificity) / 2
pred = scores >= 0.5;
hitIdx = (labels == 1);
nHit = sum(hitIdx);
if nHit > 0
    sens = sum(pred(hitIdx)) / nHit;
else
    sens = 0.5;
end
missIdx = (labels == 0);
nMiss = sum(missIdx);
if nMiss > 0
    spec = sum(~pred(missIdx)) / nMiss;
else
    spec = 0.5;
end
bacc = (sens + spec) / 2;
end

function [loss, gradients] = iGruModelLoss(net, X, y, wHit, wMiss)
% Weighted binary cross-entropy loss with L2 regularization for GRU dlnetwork
Y = forward(net, X);
epsilon = 1e-6;
Y = max(min(Y, 1 - epsilon), epsilon);

% Class-weighted BCE
weightPerSample = wHit * y + wMiss * (1 - y);
loss = -mean(weightPerSample .* (y .* log(Y) + (1 - y) .* log(1 - Y)), 'all');

% L2 regularization
l2Lambda = 0.002;
l2Penalty = l2Lambda * sum(cellfun(@(w) sum(w.^2, 'all'), net.Learnables.Value));
loss = loss + l2Penalty;

gradients = dlgradient(loss, net.Learnables);
end

function auc = iComputeAUC(scores, labels)
% AUC using Mann-Whitney U statistic (threshold-independent)
scores = scores(:);
labels = labels(:);
posIdx = (labels == 1);
negIdx = (labels == 0);
nPos = sum(posIdx);
nNeg = sum(negIdx);
if nPos == 0 || nNeg == 0
    auc = 0.5;
    return;
end
posScores = scores(posIdx);
negScores = scores(negIdx);
% Vectorized: fraction of (pos > neg) pairs with 0.5 for ties
n = nPos * nNeg;
if n > 0
    cmp = posScores > negScores';  % nPos x nNeg
    ties = posScores == negScores';
    auc = (sum(cmp(:)) + 0.5 * sum(ties(:))) / n;
else
    auc = 0.5;
end
end

function tbl = iQueryNtsByGroup(DS, mouse, trialInfo, idxBaseline)
tbl = table();
if isempty(trialInfo), return; end

phases = string(trialInfo.Phase);
stims = string(trialInfo.Stimulus);
combo = unique([phases, stims], 'rows');
validStim = ["AudioOnly","AudioWater","LightOnly","LightWater"];
combo(~ismember(combo(:,2), validStim), :) = [];

hasPhase = combo(:,1) ~= "";
noPhase  = combo(:,1) == "";

parts = {};
nOk = 0;

if any(hasPhase)
    cP = combo(hasPhase, :);
    for iG = 1:size(cP, 1)
        try
            q = struct('Mouse', mouse, 'Phase', cP(iG,1), 'Stimulus', cP(iG,2));
            res = DS.QueryNTS(q, UniExp.Flags.ZScore, idxBaseline, 'ExtraColumns', ["Behavior","DateTime"]);
            if ~isempty(res) && ~isempty(res{1})
                nOk = nOk + 1; parts{nOk} = res{1};
            end
        catch, end
    end
end

if any(noPhase)
    cP = combo(noPhase, :);
    for iG = 1:size(cP, 1)
        try
            q = struct('Mouse', mouse, 'Stimulus', cP(iG,2));
            res = DS.QueryNTS(q, UniExp.Flags.ZScore, idxBaseline, 'ExtraColumns', ["Behavior","DateTime"]);
            if ~isempty(res) && ~isempty(res{1})
                nOk = nOk + 1; parts{nOk} = res{1};
            end
        catch, end
    end
end

if nOk == 0, return; end
tbl = vertcat(parts{1:nOk});
end

function [X, y, trialUIDs] = iBuildTrialFeatureMatrix(rawTbl, cellUIDs, timeIdx)
% Build sequence data: cell array {nTrials×1}, each cell [nCells × nTime]
sig = double(rawTbl.TrialSignal);
if size(sig, 2) >= max(timeIdx)
    sigWin = sig(:, timeIdx);
else
    sigWin = sig;
end
nTime = size(sigWin, 2);

% Build table with per-cell signal stored as row vectors
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), ...
    'VariableNames', {'CellUID','TrialUID','Behavior'});
sigCell = cell(size(sigWin,1), 1);
for i = 1:size(sigWin,1)
    sigCell{i} = sigWin(i, :);
end
ntsTbl.Signal = sigCell;

% Keep only requested cells
ntsTbl = ntsTbl(ismember(ntsTbl.CellUID, cellUIDs), :);
if isempty(ntsTbl), X = []; y = []; trialUIDs = []; return; end

[~, trialUIDs] = findgroups(ntsTbl.TrialUID);
nTrials = numel(trialUIDs);
nCells = numel(cellUIDs);

% Build sequence data: each trial -> [nCells × nTime] matrix
X = cell(nTrials, 1);
y = nan(nTrials, 1);

for iT = 1:nTrials
    rows = ntsTbl(ntsTbl.TrialUID == trialUIDs(iT), :);
    seqMat = nan(nCells, nTime);
    [~, loc] = ismember(rows.CellUID, cellUIDs);
    for iR = 1:height(rows)
        ci = loc(iR);
        if ci > 0
            seqMat(ci, :) = rows.Signal{iR};
        end
    end
    X{iT} = seqMat;
    y(iT) = mode(rows.Behavior);
end

% Remove incomplete trials
hasData = cellfun(@(m) all(isfinite(m), 'all'), X) & isfinite(y);
X = X(hasData);
y = y(hasData);
trialUIDs = trialUIDs(hasData);
% Fill NaN with 0
for i = 1:numel(X)
    X{i}(isnan(X{i})) = 0;
end
end

function iPlotLearningCurve(res, mode)
% mode: 'train' or 'val'
% epoch 0 (pre-training) stored at index 1, epochs 1..N at indices 2..N+1
nEpochsTotal = numel(res.TrainBaccEpoch);
epochs = 0:(nEpochsTotal - 1);
window = max(1, round((nEpochsTotal-1)/50));

if mode == "train"
    bacc = res.TrainBaccEpoch;
    tag = 'Train';
    color = [0 0.4470 0.7410];
    fName = sprintf('TrainClassifier_%s_TrainBaccCurve.svg', res.Mouse);
else
    bacc = res.ValBaccEpoch;
    tag = 'Validation';
    color = [0.8500 0.3250 0.0980];
    fName = sprintf('TrainClassifier_%s_ValBaccCurve.svg', res.Mouse);
end

baccSmooth = movmean(bacc, window);

f = figure('Color','w','Name',sprintf('%s %s BAcc curve',res.Mouse,tag));
f.Units = 'centimeters';
f.Position(3:4) = [8, 5];
ax = axes(f);
plot(ax, epochs, bacc, '-', 'Color',color,'LineWidth',0.5);
hold(ax,'on');
plot(ax, epochs, baccSmooth, '-', 'Color',color,'LineWidth',2);
yline(ax, 0.5, '--k', 'LineWidth',0.5);
xlabel(ax, 'Epoch');
ylabel(ax, 'Balanced Accuracy');
title(ax, sprintf('%s %s (final BAcc=%.3f)', res.Mouse, tag, bacc(end)));
ax.FontSize = 8;
box(ax,'off');
xlim(ax, [0, nEpochsTotal - 1]);
ylim(ax, [0 1]);

TransferLearning.ExportStandardFigure(f, 2, fName);
end


