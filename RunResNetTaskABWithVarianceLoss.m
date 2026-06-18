function RunResNetTaskABWithVarianceLoss()
% Train a ResNet-50 on task A (10 classes), then continue on task B (10 classes)
% GPU memory safe range (RTX3090 24GB): batch 64-256. 128 is sweet spot.

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

dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot, 0.1, 0.8, 20260616);
classNames = dataset.classNames;
assert(numel(classNames) == cfg.numClasses, "Task A/B dataset must have 10 classes.");

net = TransferLearning.BuildResNet50Classifier(cfg.inputSize, cfg.numClasses);

fprintf("=== Train Task A ===\n");
[net, statsA] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, dataset.taskA.trainX, dataset.taskA.trainY, dataset.taskA.valX, dataset.taskA.valY, ...
    classNames, cfg.inputSize, cfg.maxEpochsA, ...
    cfg.miniBatchSize, cfg.learnRate, cfg.varWeight, cfg.gpuIndices);

fprintf("Task A final val acc: %.4f\n", statsA.valAccuracy(end));

fprintf("=== Train Task B (continue from Task A weights) ===\n");
[net, statsB] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, dataset.taskB.trainX, dataset.taskB.trainY, dataset.taskB.valX, dataset.taskB.valY, ...
    classNames, cfg.inputSize, cfg.maxEpochsB, ...
    cfg.miniBatchSize, cfg.learnRate, cfg.varWeight, cfg.gpuIndices);

fprintf("Task B final val acc: %.4f\n", statsB.valAccuracy(end));

modelDir = fullfile(dataRoot, "models");
if ~isfolder(modelDir)
    mkdir(modelDir);
end
save(fullfile(modelDir, "trainedNet_afterTaskA.mat"), "statsA", "-v7.3");
save(fullfile(modelDir, "trainedNet_afterTaskB.mat"), "net", "statsB", "-v7.3");
end
