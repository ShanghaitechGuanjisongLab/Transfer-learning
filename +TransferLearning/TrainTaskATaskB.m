function [statsA, statsB] = TrainTaskATaskB(dataset, cfg, varWeightA, varWeightB, XbTrain, ybTrain, XbVal, ybVal)
% Train Task A (CIFAR-10) then Task B (MNIST), each with its own variance weight.
net = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);

if nargin < 5 || isempty(varWeightB), varWeightB = 0; end
if nargin < 6
    XbTrain = dataset.taskB.trainX;
    ybTrain = dataset.taskB.trainY;
    XbVal = dataset.taskB.valX;
    ybVal = dataset.taskB.valY;
end

tagA = condTag(varWeightA);
tagB = condTag(varWeightB);

fprintf("=== Train Task A %s ===\n", tagA);
[net, statsA] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, dataset.taskA.trainX, dataset.taskA.trainY, dataset.taskA.valX, dataset.taskA.valY, ...
    dataset.classNames, cfg.inputSize, cfg.maxEpochsA, ...
    cfg.miniBatchSize, cfg.learnRate, varWeightA, cfg.gpuIndices);
fprintf("Task A %s final val acc: %.4f\n", tagA, statsA.valAccuracy(end));

fprintf("=== Train Task B %s ===\n", tagB);
[~, statsB] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, XbTrain, ybTrain, XbVal, ybVal, ...
    dataset.classNames, cfg.inputSize, cfg.maxEpochsB, ...
    cfg.miniBatchSize, cfg.learnRate, varWeightB, cfg.gpuIndices);
fprintf("Task B %s final val acc: %.4f\n", tagB, statsB.valAccuracy(end));
end

function s = condTag(vw)
if vw == 0, s = "(no variance)";
else, s = sprintf("(varWeight=%.2f)", vw);
end
end
