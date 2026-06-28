function TestRandomResNet18Mnist5Epoch()
% Test fully random ResNet-18 on full MNIST for 5 epochs.

dataRoot = "D:\训练数据";
TransferLearning.PrepareOfficialMNIST();
gpuDevice(3);

[Xtrain, ytrain] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[Xval, yval] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

fprintf("MNIST train=%d, val=%d\n", size(Xtrain,1), size(Xval,1));

inputSize = [32 32 3];
numClasses = 10;
miniBatchSize = 128;
learnRate = 1e-3;
maxEpochs = 5;

net = TransferLearning.BuildResNet18RandomClassifier(inputSize, numClasses);
fprintf("Random ResNet-18 built. Learnables=%d\n", height(net.Learnables));

[~, stats] = TransferLearning.TrainImageTaskVarianceLoss( ...
    net, Xtrain, ytrain, Xval, yval, string(0:9), inputSize, maxEpochs, ...
    miniBatchSize, learnRate, 0, 3);

fprintf("Random ResNet18 final valAcc=%.4f\n", stats.valAccuracy(end));
end
