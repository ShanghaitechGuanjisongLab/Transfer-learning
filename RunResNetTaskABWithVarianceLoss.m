function RunResNetTaskABWithVarianceLoss(mode)
% RunResNetTaskABWithVarianceLoss  Train ResNet-18 on Task A→Task B.
%
%   RunResNetTaskABWithVarianceLoss("both")       % train both groups, plot comparison
%   RunResNetTaskABWithVarianceLoss("withVar")    % only with-variance group
%   RunResNetTaskABWithVarianceLoss("noVar")      % only no-variance group
%   RunResNetTaskABWithVarianceLoss("compare")    % load saved stats and plot only
%
% Variance metric: hidden response variance from ResNet-18 pool5 features.
%
% Save paths:
%   D:\训练数据\models\statsA_noVar.mat, statsB_noVar.mat
%   D:\训练数据\models\statsA_withVar.mat, statsB_withVar.mat
%   TaskB_VarianceVsNoVariance.svg

arguments
    mode (1,:) char {mustBeMember(mode, ["both","withVar","noVar","compare"])} = "both"
end

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();

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

if ismember(mode, ["both","noVar"])
    fprintf("=== Group: NO variance (varWeight=0) ===\n");
    [statsA_noVar, statsB_noVar] = TransferLearning.TrainTaskATaskB(dataset, cfg, 0);
    save(fullfile(modelDir, "statsA_noVar.mat"), "statsA_noVar", "-v7.3");
    save(fullfile(modelDir, "statsB_noVar.mat"), "statsB_noVar", "-v7.3");
end

if ismember(mode, ["both","withVar"])
    fprintf("=== Group: WITH variance (varWeight=%.2f) ===\n", cfg.varWeight);
    [statsA_withVar, statsB_withVar] = TransferLearning.TrainTaskATaskB(dataset, cfg, cfg.varWeight);
    save(fullfile(modelDir, "statsA_withVar.mat"), "statsA_withVar", "-v7.3");
    save(fullfile(modelDir, "statsB_withVar.mat"), "statsB_withVar", "-v7.3");
end

if ismember(mode, ["both","compare"])
    loaded_noVar = load(fullfile(modelDir, "statsB_noVar.mat"), "statsB_noVar");
    loaded_withVar = load(fullfile(modelDir, "statsB_withVar.mat"), "statsB_withVar");
    fVar = TransferLearning.PlotTrainingCurvesCompareVariance( ...
        loaded_withVar.statsB_withVar, loaded_noVar.statsB_noVar);
    TransferLearning.ExportStandardFigure(fVar, 2, "TaskB_VarianceVsNoVariance.svg");
    fprintf("Comparison chart exported to TaskB_VarianceVsNoVariance.svg\n");
end
end
