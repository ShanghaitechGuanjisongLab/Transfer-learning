function RunResNetTaskABWithVarianceLoss(mode)
% RunResNetTaskABWithVarianceLoss  Train ResNet-18 on Task A→Task B.
%
%   RunResNetTaskABWithVarianceLoss("both")       % train all groups, plot comparison
%   RunResNetTaskABWithVarianceLoss("transfer")   % only A→B with variance
%   RunResNetTaskABWithVarianceLoss("noVar")      % only A→B no variance
%   RunResNetTaskABWithVarianceLoss("direct")     % only B from scratch with variance
%   RunResNetTaskABWithVarianceLoss("compare")    % load saved stats and plot only
%
% Comparisons:
%   1) TaskB_transfer vs TaskB_direct (both with variance) → TaskB_TransferVsDirect.svg
%   2) TaskB_transfer (withVar) vs TaskB_transfer (noVar) → TaskB_VarianceVsNoVariance.svg
%
% Task A: CIFAR-10;  Task B: MNIST handwritten digits.
%
% Save paths:
%   D:\训练数据\models\statsA_var_transfer.mat,  statsB_var_transfer.mat
%   D:\训练数据\models\statsB_var_direct.mat
%   D:\训练数据\models\statsB_noVar_transfer.mat

arguments
    mode (1,:) char {mustBeMember(mode, ["both","transfer","noVar","direct","compare"])} = "both"
end

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();

cfg.inputSize = [32 32 3];
cfg.numClasses = 10;
cfg.miniBatchSize = 128;
cfg.maxEpochsA = 20;
cfg.maxEpochsB = 20;
cfg.learnRate = 1e-3;
cfg.varWeight = 0.02;
cfg.gpuIndices = 3;
cfg.disableCPUThreads = true;

gpuCount = gpuDeviceCount("available");
assert(all(cfg.gpuIndices >= 1 & cfg.gpuIndices <= gpuCount), ...
    "cfg.gpuIndices exceeds available GPU count (%d).", gpuCount);

if cfg.disableCPUThreads
    maxNumCompThreads(1);
end

modelDir = fullfile(dataRoot, "models");
if ~isfolder(modelDir)
    mkdir(modelDir);
end

rng(20260616);
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot, 0.1, 0.8, 20260616);

[XmnistTrain, ymnistTrain] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0.8, 20260616);
[XmnistVal,   ymnistVal]   = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k",  0.2,  20260616);

% ---- Group 1: A→B, with variance ----
if ismember(mode, ["both","transfer"])
    fprintf("=== Group: A->B with variance (varWeight=%.2f) ===\n", cfg.varWeight);
    [statsA_transfer, statsB_var_transfer] = TransferLearning.TrainTaskATaskB( ...
        dataset, cfg, cfg.varWeight, XmnistTrain, ymnistTrain, XmnistVal, ymnistVal);
    save(fullfile(modelDir, "statsA_var_transfer.mat"), "statsA_transfer", "-v7.3");
    save(fullfile(modelDir, "statsB_var_transfer.mat"), "statsB_var_transfer", "-v7.3");
end

% ---- Group 2: A→B, no variance ----
if ismember(mode, ["both","noVar"])
    fprintf("=== Group: A->B no variance (varWeight=0) ===\n");
    [~, statsB_noVar_transfer] = TransferLearning.TrainTaskATaskB( ...
        dataset, cfg, 0, XmnistTrain, ymnistTrain, XmnistVal, ymnistVal);
    save(fullfile(modelDir, "statsB_noVar_transfer.mat"), "statsB_noVar_transfer", "-v7.3");
end

% ---- Group 3: B from scratch, with variance ----
if ismember(mode, ["both","direct"])
    fprintf("=== Group: B-DIRECT with variance (varWeight=%.2f) ===\n", cfg.varWeight);
    rng(20260616);
    net = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    [~, statsB_var_direct] = TransferLearning.TrainImageTaskVarianceLoss( ...
        net, XmnistTrain, ymnistTrain, XmnistVal, ymnistVal, ...
        dataset.classNames, cfg.inputSize, cfg.maxEpochsB, ...
        cfg.miniBatchSize, cfg.learnRate, cfg.varWeight, cfg.gpuIndices);
    save(fullfile(modelDir, "statsB_var_direct.mat"), "statsB_var_direct", "-v7.3");
end

% ---- Comparison 1: Transfer vs Direct (both with variance) ----
if ismember(mode, ["both","compare"])
    loaded_transfer = load(fullfile(modelDir, "statsB_var_transfer.mat"), "statsB_var_transfer");
    loaded_direct   = load(fullfile(modelDir, "statsB_var_direct.mat"),   "statsB_var_direct");
    fTD = TransferLearning.PlotTrainingCurvesCompare( ...
        loaded_transfer.statsB_var_transfer, loaded_direct.statsB_var_direct);
    TransferLearning.ExportStandardFigure(fTD, 2, "TaskB_TransferVsDirect.svg");
    fprintf("Transfer vs Direct chart -> TaskB_TransferVsDirect.svg\n");
end

% ---- Comparison 2: Variance vs No Variance (both A→B) ----
if ismember(mode, ["both","compare"])
    loaded_withVar = load(fullfile(modelDir, "statsB_var_transfer.mat"),    "statsB_var_transfer");
    loaded_noVar   = load(fullfile(modelDir, "statsB_noVar_transfer.mat"),  "statsB_noVar_transfer");
    fVar = TransferLearning.PlotTrainingCurvesCompareVariance( ...
        loaded_withVar.statsB_var_transfer, loaded_noVar.statsB_noVar_transfer);
    TransferLearning.ExportStandardFigure(fVar, 2, "TaskB_VarianceVsNoVariance.svg");
    fprintf("Variance vs NoVariance chart -> TaskB_VarianceVsNoVariance.svg\n");
end
end
