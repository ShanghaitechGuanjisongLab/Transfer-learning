function DiagnoseMnistRgbStem()
% Diagnose whether MNIST failure is caused by RGB replicated grayscale or by ImageNet stem.
% Compare:
%   Case A: 3-channel MNIST + original ImageNet ResNet-18 stem (7x7 stride2 + maxpool)
%   Case B: 3-channel MNIST + CIFAR/MNIST stem (3x3 stride1, no maxpool)

dataRoot = "D:\训练数据";
TransferLearning.PrepareOfficialMNIST();
gpuDevice(3);

[Xtrain, ytrain, Xtest, ytest] = loadMnistRaw(dataRoot);
numTrain = size(Xtrain, 3);
numTest = size(Xtest, 3);

mu = single(0.1307);
sig = single(0.3081);

Xtrain4 = reshape(Xtrain, [28 28 1 numTrain]);
Xtest4 = reshape(Xtest, [28 28 1 numTest]);
Xtrain3 = gpuArray(single(repmat(Xtrain4, [1 1 3 1])));
Xtest3 = gpuArray(single(repmat(Xtest4, [1 1 3 1])));

maxEpochs = 5;
batchSize = 100;
learnRate = 1e-3;

fprintf("=== Case A: 3ch MNIST + original ImageNet stem ===\n");
netA = buildResNet18OriginalStem28x28();
accA = trainAndEval(netA, Xtrain3, Xtest3, ytrain, ytest, mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, "3ch-original-stem");

fprintf("=== Case B: 3ch MNIST + 3x3 stride1 no-pool stem ===\n");
netB = buildResNet18CifarStem28x28();
accB = trainAndEval(netB, Xtrain3, Xtest3, ytrain, ytest, mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, "3ch-cifar-stem");

fprintf("Summary: original stem final=%.4f, cifar stem final=%.4f\n", accA(end), accB(end));
end

function net = buildResNet18OriginalStem28x28()
lgraph = layerGraph(imagePretrainedNetwork("resnet18"));
lgraph = replaceLayer(lgraph, "data", imageInputLayer([28 28 3], Normalization="none", Name="data"));
lgraph = replaceLayer(lgraph, "fc1000", fullyConnectedLayer(10, Name="fc_logits"));
lgraph = removeLayers(lgraph, "prob");
net = dlnetwork(lgraph);
end

function net = buildResNet18CifarStem28x28()
lgraph = layerGraph(imagePretrainedNetwork("resnet18"));
lgraph = replaceLayer(lgraph, "data", imageInputLayer([28 28 3], Normalization="none", Name="data"));
lgraph = replaceLayer(lgraph, "conv1", convolution2dLayer(3, 64, Stride=1, Padding=1, Name="conv1"));
lgraph = disconnectLayers(lgraph, "conv1_relu", "pool1");
lgraph = disconnectLayers(lgraph, "pool1", "res2a_branch2a");
lgraph = disconnectLayers(lgraph, "pool1", "res2a/in2");
lgraph = removeLayers(lgraph, "pool1");
lgraph = connectLayers(lgraph, "conv1_relu", "res2a_branch2a");
lgraph = connectLayers(lgraph, "conv1_relu", "res2a/in2");
lgraph = replaceLayer(lgraph, "fc1000", fullyConnectedLayer(10, Name="fc_logits"));
lgraph = removeLayers(lgraph, "prob");
net = dlnetwork(lgraph);
end

function acc = trainAndEval(net, Xtrain, Xtest, ytrain, ytest, mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, tag)
trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
acc = zeros(maxEpochs, 1);

for epoch = 1:maxEpochs
    order = randperm(numTrain);
    epochLoss = single(0);
    batchCount = 0;
    for startIdx = 1:batchSize:numTrain
        endIdx = min(startIdx + batchSize - 1, numTrain);
        batchIdx = order(startIdx:endIdx);
        iteration = iteration + 1;
        batchCount = batchCount + 1;

        Xb = (Xtrain(:, :, :, batchIdx) / 255 - mu) / sig;
        dlX = dlarray(Xb, "SSCB");
        Tb = gpuArray(zeros(10, numel(batchIdx), "single"));
        linearIdx = sub2ind([10 numel(batchIdx)], ytrain(batchIdx)', 1:numel(batchIdx));
        Tb(linearIdx) = 1;
        dlT = dlarray(Tb, "CB");

        [gradients, loss] = dlfeval(@pureCELoss, net, dlX, dlT);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate);
        epochLoss = epochLoss + extractdata(loss);
    end

    numCorrect = 0;
    for startIdx = 1:batchSize:numTest
        endIdx = min(startIdx + batchSize - 1, numTest);
        batchIdx = startIdx:endIdx;
        Xb = (Xtest(:, :, :, batchIdx) / 255 - mu) / sig;
        dlX = dlarray(Xb, "SSCB");
        logits = forward(net, dlX);
        [~, pred] = max(gather(extractdata(logits)), [], 1);
        numCorrect = numCorrect + nnz(pred == ytest(batchIdx)');
    end
    acc(epoch) = numCorrect / numTest;
    fprintf("[%s] Epoch %d/%d | loss=%.4f | testAcc=%.4f\n", tag, epoch, maxEpochs, double(gather(epochLoss)) / batchCount, acc(epoch));
end
end

function [gradients, loss] = pureCELoss(net, dlX, dlT)
logits = forward(net, dlX);
loss = crossentropy(softmax(logits), dlT, TargetCategories="independent");
gradients = dlgradient(loss, net.Learnables);
end

function [Xtrain, ytrain, Xtest, ytest] = loadMnistRaw(dataRoot)
rawDir = fullfile(dataRoot, "raw", "mnist");
fid = fopen(fullfile(rawDir, "train-images-idx3-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be"); fread(fid, 1, "int32", 0, "ieee-be");
fread(fid, 1, "int32", 0, "ieee-be"); fread(fid, 1, "int32", 0, "ieee-be");
imgs = fread(fid, inf, "uint8"); fclose(fid);
Xtrain = permute(reshape(imgs, [28 28 60000]), [2 1 3]);
fid = fopen(fullfile(rawDir, "train-labels-idx1-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be"); fread(fid, 1, "int32", 0, "ieee-be");
ytrain = fread(fid, inf, "uint8") + 1; fclose(fid);
fid = fopen(fullfile(rawDir, "t10k-images-idx3-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be"); fread(fid, 1, "int32", 0, "ieee-be");
fread(fid, 1, "int32", 0, "ieee-be"); fread(fid, 1, "int32", 0, "ieee-be");
imgs = fread(fid, inf, "uint8"); fclose(fid);
Xtest = permute(reshape(imgs, [28 28 10000]), [2 1 3]);
fid = fopen(fullfile(rawDir, "t10k-labels-idx1-ubyte"), "rb");
fread(fid, 1, "int32", 0, "ieee-be"); fread(fid, 1, "int32", 0, "ieee-be");
ytest = fread(fid, inf, "uint8") + 1; fclose(fid);
end
