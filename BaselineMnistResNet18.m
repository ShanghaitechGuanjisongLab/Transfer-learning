function BaselineMnistResNet18()
% Reproduce PyTorch ResNet-18 MNIST baseline (99%+ accuracy).
% Exact match:
%   Input: 28x28x1, normalized (x/255 - 0.1307)/0.3081
%   Net: ResNet-18, conv1=3x3 stride1, no pool1, 10 classes
%   Optimizer: Adam, lr=0.001
%   Epochs: 30, batch: 100, full 60k train / 10k test

dataRoot = "D:\训练数据";
TransferLearning.PrepareOfficialMNIST();

gpuDevice(3);

% ---- Load MNIST ----
fprintf("Loading MNIST...\n");
[Xtrain, ytrain, Xtest, ytest] = loadMnistRaw(dataRoot);

% Standard MNIST normalization
mu  = single(0.1307);
sig = single(0.3081);

numTrain = size(Xtrain, 3);
numTest  = size(Xtest, 3);

% Pre-upload to GPU, add channel dim
XtrainGpu = gpuArray(single(reshape(Xtrain, [28 28 1 numTrain])));
XtestGpu  = gpuArray(single(reshape(Xtest,  [28 28 1 numTest])));

% ---- Build network ----
net = TransferLearning.BuildResNet18MnistClassifier();
fprintf("Net built, learnables: %d\n", height(net.Learnables));

% ---- Training config (PyTorch baseline) ----
maxEpochs  = 30;
batchSize  = 100;
learnRate  = 1e-3;

trailingAvg   = [];
trailingAvgSq = [];
iteration = 0;

testAccHistory = zeros(maxEpochs, 1);
trainLossHistory = zeros(maxEpochs, 1);

fprintf("=== Training ResNet-18 on MNIST (baseline reproduction) ===\n");

for epoch = 1:maxEpochs
    order = randperm(numTrain);
    epochLoss = single(0);
    batchCount = 0;

    for startIdx = 1:batchSize:numTrain
        iteration = iteration + 1;
        batchCount = batchCount + 1;

        endIdx = min(startIdx + batchSize - 1, numTrain);
        batchIdx = order(startIdx:endIdx);

        % Normalize and format
        Xb = (XtrainGpu(:, :, :, batchIdx) / 255 - mu) / sig;
        dlX = dlarray(Xb, "SSCB");

        Tb = gpuArray(zeros(10, numel(batchIdx), "single"));
        linearIdx = sub2ind([10 numel(batchIdx)], ytrain(batchIdx)', 1:numel(batchIdx));
        Tb(linearIdx) = 1;
        dlT = dlarray(Tb, "CB");

        % Forward + backward (pure CE, no variance)
        [gradients, loss] = dlfeval(@mnistPureCELoss, net, dlX, dlT);

        [net, trailingAvg, trailingAvgSq] = adamupdate( ...
            net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate);

        epochLoss = epochLoss + extractdata(loss);
    end

    trainLossHistory(epoch) = double(gather(epochLoss)) / batchCount;

    % ---- Test accuracy ----
    numCorrect = 0;
    for startIdx = 1:batchSize:numTest
        endIdx = min(startIdx + batchSize - 1, numTest);
        batchIdx = startIdx:endIdx;

        Xb = (XtestGpu(:, :, :, batchIdx) / 255 - mu) / sig;
        dlX = dlarray(Xb, "SSCB");

        logits = forward(net, dlX);
        [~, pred] = max(gather(extractdata(logits)), [], 1);
        trueLabels = ytest(batchIdx)';
        numCorrect = numCorrect + nnz(pred == trueLabels);
    end
    testAccHistory(epoch) = numCorrect / numTest;

    fprintf("Epoch %d/%d | trainLoss=%.4f | testAcc=%.4f\n", ...
        epoch, maxEpochs, trainLossHistory(epoch), testAccHistory(epoch));
end

fprintf("=== Final test accuracy: %.4f ===\n", testAccHistory(end));

% ---- Plot ----
figure("Position", [100 100 900 400]);
subplot(1, 2, 1);
plot(1:maxEpochs, trainLossHistory, "b-o", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Loss"); title("Training Loss"); grid on;

subplot(1, 2, 2);
plot(1:maxEpochs, testAccHistory * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Accuracy (%)"); title("Test Accuracy");
ylim([0 100]); grid on;

sgtitle("ResNet-18 MNIST Baseline (MATLAB reproduction of PyTorch setup)");
saveas(gcf, fullfile(dataRoot, "models", "BaselineMnistResNet18.png"));
end

% ---- Helpers ----

function [gradients, loss] = mnistPureCELoss(net, dlX, dlT)
logits = forward(net, dlX);
loss = crossentropy(softmax(logits), dlT, TargetCategories="independent");
gradients = dlgradient(loss, net.Learnables);
end

function [Xtrain, ytrain, Xtest, ytest] = loadMnistRaw(dataRoot)
rawDir = fullfile(dataRoot, "raw", "mnist");

% Training images
fid = fopen(fullfile(rawDir, "train-images-idx3-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be");
nTrain = fread(fid, 1, "int32", 0, "ieee-be");
nRows = fread(fid, 1, "int32", 0, "ieee-be");
nCols = fread(fid, 1, "int32", 0, "ieee-be");
imgs = fread(fid, inf, "uint8");
fclose(fid);
Xtrain = reshape(imgs, [nCols nRows nTrain]);
Xtrain = permute(Xtrain, [2 1 3]);

% Training labels
fid = fopen(fullfile(rawDir, "train-labels-idx1-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be");
fread(fid, 1, "int32", 0, "ieee-be");
ytrain = fread(fid, inf, "uint8") + 1;
fclose(fid);

% Test images
fid = fopen(fullfile(rawDir, "t10k-images-idx3-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be");
nTest = fread(fid, 1, "int32", 0, "ieee-be");
fread(fid, 1, "int32", 0, "ieee-be");
fread(fid, 1, "int32", 0, "ieee-be");
imgs = fread(fid, inf, "uint8");
fclose(fid);
Xtest = reshape(imgs, [28 28 nTest]);
Xtest = permute(Xtest, [2 1 3]);

% Test labels
fid = fopen(fullfile(rawDir, "t10k-labels-idx1-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be");
fread(fid, 1, "int32", 0, "ieee-be");
ytest = fread(fid, inf, "uint8") + 1;
fclose(fid);
end
