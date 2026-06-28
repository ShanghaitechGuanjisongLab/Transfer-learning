function RunResNetTaskABWithVarianceLoss(mode)
% RunResNetTaskABWithVarianceLoss  Train ResNet-18 on Task A→Task B.
%
%   RunResNetTaskABWithVarianceLoss("both")       % train all groups, plot comparison
%   RunResNetTaskABWithVarianceLoss("transfer")   % only A→B (only A has variance)
%   RunResNetTaskABWithVarianceLoss("noVar")      % only A→B (no variance at all)
%   RunResNetTaskABWithVarianceLoss("direct")     % only B from scratch (no variance)
%   RunResNetTaskABWithVarianceLoss("compare")    % load saved stats and plot only
%
% Comparisons:
%   1) Continual B vs Naive B → TaskB_ContinualVsNaive.svg
%   2) Task A with variance vs without → TaskA_VarianceVsNoVariance.svg
%   3) Task B (A-had-var) vs Task B (A-had-no-var) → TaskB_VarianceOnAVsNoVarianceOnA.svg
%
% Task A: CIFAR-10;  Task B: MNIST.  Only Task A ever uses variance.
%
% Save paths:
%   D:\训练数据\models\statsA_var.mat,   statsB_afterVarA.mat
%   D:\训练数据\models\statsA_noVar.mat, statsB_noVar.mat
%   D:\训练数据\models\statsB_direct.mat

arguments
    mode (1,:) char {mustBeMember(mode, ["both","transfer","noVar","direct","compare"])} = "both"
end

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();

cfg.inputSize = [32 32 3];
cfg.numClasses = 10;
cfg.miniBatchSize = 128;
cfg.maxEpochsA = 100;
cfg.maxEpochsB = 100;
cfg.learnRate = 1e-3;
cfg.varWeight = 0.01;
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
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);

[XmnistTrain, ymnistTrain] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmnistVal,   ymnistVal]   = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k",  0, 20260616);

% ---- Group 1: A (with var) → B (no var) ----
if ismember(mode, ["both","transfer"])
    fprintf("=== Group: A(variance) → B(no variance) ===\n");
    [statsA_var, statsB_afterVarA] = TransferLearning.TrainTaskATaskB( ...
        dataset, cfg, cfg.varWeight, 0, XmnistTrain, ymnistTrain, XmnistVal, ymnistVal, 500, 600);
    save(fullfile(modelDir, "statsA_var.mat"), "statsA_var", "-v7.3");
    save(fullfile(modelDir, "statsB_afterVarA.mat"), "statsB_afterVarA", "-v7.3");
end

% ---- Group 2: A (no var) → B (no var) ----
if ismember(mode, ["both","noVar"])
    fprintf("=== Group: A(no variance) → B(no variance) ===\n");
    [statsA_noVar, statsB_noVar] = TransferLearning.TrainTaskATaskB( ...
        dataset, cfg, 0, 0, XmnistTrain, ymnistTrain, XmnistVal, ymnistVal, 500, 600);
    save(fullfile(modelDir, "statsA_noVar.mat"), "statsA_noVar", "-v7.3");
    save(fullfile(modelDir, "statsB_noVar.mat"), "statsB_noVar", "-v7.3");
end

% ---- Group 3: B from scratch (no var) ----
if ismember(mode, ["both","direct"])
    fprintf("=== Group: B-DIRECT (no variance) ===\n");
    rng(20260616);
    net = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    [~, statsB_direct] = TransferLearning.TrainImageTaskVarianceLoss( ...
        net, XmnistTrain, ymnistTrain, XmnistVal, ymnistVal, ...
        dataset.classNames, cfg.inputSize, cfg.maxEpochsB, ...
        cfg.miniBatchSize, cfg.learnRate, 0, cfg.gpuIndices, 600);
    save(fullfile(modelDir, "statsB_direct.mat"), "statsB_direct", "-v7.3");
end

% ---- Comparison 1: Continual B vs Naive B ----
if ismember(mode, ["both","compare"])
    loaded_continual = load(fullfile(modelDir, "statsB_afterVarA.mat"), "statsB_afterVarA");
    loaded_direct     = load(fullfile(modelDir, "statsB_direct.mat"),     "statsB_direct");
    f = TransferLearning.PlotTrainingCurvesCompare( ...
        loaded_continual.statsB_afterVarA, loaded_direct.statsB_direct, ...
        "Continual B", "Naive B", "Continual vs Naive Learning: Task B (MNIST)", 10);
    TransferLearning.ExportStandardFigure(f, 2, "TaskB_ContinualVsNaive.svg");
    fprintf("Continual vs Naive -> TaskB_ContinualVsNaive.svg\n");
end

% ---- Comparison 2: Task A with variance vs without ----
if ismember(mode, ["both","compare"])
    loaded_varA   = load(fullfile(modelDir, "statsA_var.mat"),   "statsA_var");
    loaded_noVarA = load(fullfile(modelDir, "statsA_noVar.mat"), "statsA_noVar");
    f = TransferLearning.PlotTrainingCurvesCompareVariance( ...
        loaded_varA.statsA_var, loaded_noVarA.statsA_noVar, ...
        "With Variance", "No Variance", "Task A (CIFAR-10): Variance vs No Variance (ResNet-18)", 100);
    TransferLearning.ExportStandardFigure(f, 2, "TaskA_VarianceVsNoVariance.svg");
    fprintf("TaskA variance vs noVar -> TaskA_VarianceVsNoVariance.svg\n");
end

% ---- Comparison 3: Task B (A had var) vs Task B (A had no var) ----
if ismember(mode, ["both","compare"])
    loaded_bAfterVar   = load(fullfile(modelDir, "statsB_afterVarA.mat"), "statsB_afterVarA");
    loaded_bNoVar      = load(fullfile(modelDir, "statsB_noVar.mat"),      "statsB_noVar");
    f = TransferLearning.PlotTrainingCurvesCompareVariance( ...
        loaded_bAfterVar.statsB_afterVarA, loaded_bNoVar.statsB_noVar, ...
        "A had variance", "A had no variance", "Task B (MNIST): Effect of Variance in Task A (ResNet-18)", 10);
    TransferLearning.ExportStandardFigure(f, 2, "TaskB_VarianceOnAvsNoVarianceOnA.svg");
    fprintf("TaskB (A-had-var) vs TaskB (A-had-no-var) -> TaskB_VarianceOnAvsNoVarianceOnA.svg\n");
end
end
