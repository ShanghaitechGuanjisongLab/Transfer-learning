function [statsA, statsB] = TrainTaskATaskB(dataset, cfg, varWeightA, varWeightB, XbTrain, ybTrain, XbVal, ybVal, samplesPerEpochA, samplesPerEpochB)
% Train Task A (CIFAR-10) then Task B (MNIST), each with its own variance weight.
% samplesPerEpochA/B: how many training images per epoch (default: all)
net = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);

if nargin < 5 || isempty(varWeightB), varWeightB = 0; end
if nargin < 6
    XbTrain = dataset.taskB.trainX;
    ybTrain = dataset.taskB.trainY;
    XbVal = dataset.taskB.valX;
    ybVal = dataset.taskB.valY;
end
if nargin < 8 || isempty(samplesPerEpochA), samplesPerEpochA = size(dataset.taskA.trainX,1); end
if nargin < 9 || isempty(samplesPerEpochB), samplesPerEpochB = size(XbTrain,1); end

tagA = condTag(varWeightA);
tagB = condTag(varWeightB);

fprintf("=== Train Task A %s ===\n", tagA);
[net, statsA] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, dataset.taskA.trainX, dataset.taskA.trainY, dataset.taskA.valX, dataset.taskA.valY, ...
    dataset.classNames, cfg.inputSize, cfg.maxEpochsA, ...
    cfg.miniBatchSize, cfg.learnRate, varWeightA, cfg.gpuIndices, samplesPerEpochA);
fprintf("Task A %s final val acc: %.4f\n", tagA, statsA.finalValAccuracy);

fprintf("=== Train Task B %s ===\n", tagB);
[~, statsB] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, XbTrain, ybTrain, XbVal, ybVal, ...
    dataset.classNames, cfg.inputSize, cfg.maxEpochsB, ...
    cfg.miniBatchSize, cfg.learnRate, varWeightB, cfg.gpuIndices, samplesPerEpochB);
fprintf("Task B %s final val acc: %.4f\n", tagB, statsB.finalValAccuracy);
end

function s = condTag(vw)
if vw == 0, s = "(no variance)";
else, s = sprintf("(varWeight=%.2f)", vw);
end
end
