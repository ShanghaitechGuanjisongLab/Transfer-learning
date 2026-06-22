function [statsA, statsB] = TrainTaskATaskB(dataset, cfg, varWeight)
net = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);

if varWeight == 0
    tag = "(no variance)";
else
    tag = sprintf("(varWeight=%.2f)", varWeight);
end

fprintf("=== Train Task A %s ===\n", tag);
[net, statsA] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, dataset.taskA.trainX, dataset.taskA.trainY, dataset.taskA.valX, dataset.taskA.valY, ...
    dataset.classNames, cfg.inputSize, cfg.maxEpochsA, ...
    cfg.miniBatchSize, cfg.learnRate, varWeight, cfg.gpuIndices);
fprintf("Task A %s final val acc: %.4f\n", tag, statsA.valAccuracy(end));

fprintf("=== Train Task B %s ===\n", tag);
[~, statsB] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, dataset.taskB.trainX, dataset.taskB.trainY, dataset.taskB.valX, dataset.taskB.valY, ...
    dataset.classNames, cfg.inputSize, cfg.maxEpochsB, ...
    cfg.miniBatchSize, cfg.learnRate, varWeight, cfg.gpuIndices);
fprintf("Task B %s final val acc: %.4f\n", tag, statsB.valAccuracy(end));
end
