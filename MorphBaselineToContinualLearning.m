function MorphBaselineToContinualLearning()
% Starts from proven MNIST baseline, morphs step-by-step to our setup.
% Each step runs 5 epochs. Reports test accuracy at each step.
% Stops if accuracy drops below threshold.

maxEpochs = 5;
batchSize = 100;
learnRate = 1e-3;
varWeight = 0.02;
accThreshold = 0.90;  % below this = problem detected

dataRoot = "D:\训练数据";
TransferLearning.PrepareOfficialMNIST();
PrepareOfficialCIFAR10TaskAB();

gpuDevice(3);

fprintf("========== Step 0: BASELINE (1ch, 28x28, normalize, pure CE) ==========\n");
[Xtrain, ytrain, Xtest, ytest] = loadMnistRaw(dataRoot);
mu = single(0.1307); sig = single(0.3081);
numTrain = size(Xtrain,3); numTest = size(Xtest,3);
Xtrain28 = gpuArray(single(reshape(Xtrain, [28 28 1 numTrain])));
Xtest28  = gpuArray(single(reshape(Xtest,  [28 28 1 numTest])));

net0 = TransferLearning.BuildResNet18MnistClassifier();
[trainLoss, testAcc] = trainMnist(net0, Xtrain28, Xtest28, ytrain, ytest, ...
    mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, 0, "Step0_Baseline");

fprintf("Step 0 Final: testAcc=%.4f\n", testAcc(end));
if testAcc(end) < accThreshold, fprintf("*** STOP: accuracy below threshold ***\n"); return; end

% ---- Step 1: ADD variance loss (pool5 features) ----
fprintf("\n========== Step 1: ADD variance loss (pool5 features, varWeight=%.2f) ==========\n", varWeight);
net1 = TransferLearning.BuildResNet18MnistClassifier();
[trainLoss, testAcc] = trainMnist(net1, Xtrain28, Xtest28, ytrain, ytest, ...
    mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, varWeight, "Step1_VarianceLoss");

fprintf("Step 1 Final: testAcc=%.4f\n", testAcc(end));
if testAcc(end) < accThreshold, fprintf("*** STOP: variance loss caused drop ***\n"); return; end

% ---- Step 2: 3-channel input, replicate grayscale ----
fprintf("\n========== Step 2: 3-channel input (replicate grayscale) ==========\n");
Xtrain28_4d = reshape(Xtrain, [28 28 1 numTrain]);
Xtest28_4d = reshape(Xtest, [28 28 1 numTest]);
Xtrain28_3ch = gpuArray(single(repmat(Xtrain28_4d, [1 1 3 1])));
Xtest28_3ch = gpuArray(single(repmat(Xtest28_4d, [1 1 3 1])));

net2 = TransferLearning.BuildResNet18Classifier([28 28 3], 10);  % uses our 3ch builder
[trainLoss, testAcc] = trainMnist(net2, Xtrain28_3ch, Xtest28_3ch, ytrain, ytest, ...
    mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, varWeight, "Step2_3Channel");

fprintf("Step 2 Final: testAcc=%.4f\n", testAcc(end));
if testAcc(end) < accThreshold, fprintf("*** STOP: 3-channel caused drop ***\n"); return; end

% ---- Step 3: 32x32 input (imresize from 28) ----
fprintf("\n========== Step 3: 32x32 input (imresize from 28) ==========\n");
Xtrain32 = gpuArray(single(zeros([32 32 3 numTrain])));
Xtest32  = gpuArray(single(zeros([32 32 3 numTest])));
for i = 1:numTrain
    Xtrain32(:,:,:,i) = imresize(Xtrain28_3ch(:,:,:,i), [32 32]);
end
for i = 1:numTest
    Xtest32(:,:,:,i) = imresize(Xtest28_3ch(:,:,:,i), [32 32]);
end

net3 = TransferLearning.BuildResNet18Classifier([32 32 3], 10);
[trainLoss, testAcc] = trainMnist(net3, Xtrain32, Xtest32, ytrain, ytest, ...
    mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, varWeight, "Step3_32x32");

fprintf("Step 3 Final: testAcc=%.4f\n", testAcc(end));
if testAcc(end) < accThreshold, fprintf("*** STOP: 32x32 caused drop ***\n"); return; end

% ---- Step 4: Task A (CIFAR-10) before Task B (MNIST) ----
fprintf("\n========== Step 4: Continual learning (CIFAR-10 → MNIST) ==========\n");
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot, 0.1, 0.8, 20260616);
[XaTrain, yaTrain] = deal(dataset.taskA.trainX, dataset.taskA.trainY);
[XaVal, yaVal] = deal(dataset.taskA.valX, dataset.taskA.valY);
numTrainA = size(XaTrain, 1);
numValA = size(XaVal, 1);
numClassesA = numel(dataset.classNames);

[XaTrainGpu, TaFullGpu] = TransferLearning.PreUploadCifarToGpu(XaTrain, yaTrain, numClassesA);
[XaValGpu,   TaValGpu]  = TransferLearning.PreUploadCifarToGpu(XaVal, yaVal, numClassesA);

net4 = TransferLearning.BuildResNet18Classifier([32 32 3], 10);

% Train Task A (CIFAR-10, with variance)
fprintf("  Task A (CIFAR-10, %d train, %d val)...\n", numTrainA, numValA);
trailingAvg=[]; trailingAvgSq=[]; iter=0;
for epoch = 1:maxEpochs
    order = randperm(numTrainA);
    for startIdx = 1:batchSize:numTrainA
        endIdx = min(startIdx+batchSize-1, numTrainA);
        batchIdx = order(startIdx:endIdx);
        dlXa = dlarray(single(XaTrainGpu(:,:,:,batchIdx))/255, "SSCB");
        dlTa = dlarray(TaFullGpu(:,batchIdx), "CB");
        iter=iter+1;
        [gr,loss,ce,vt] = dlfeval(@TransferLearning.ComputeModelGradientsVarianceLoss, net4, dlXa, dlTa, varWeight);
        [net4,trailingAvg,trailingAvgSq] = adamupdate(net4,gr,trailingAvg,trailingAvgSq,iter,learnRate);
    end
    % Val accuracy Task A
    numCorrectA=0; numTotalA=0;
    for startIdx = 1:batchSize:numValA
        endIdx = min(startIdx+batchSize-1, numValA);
        batchIdx = startIdx:endIdx;
        dlX = dlarray(single(XaValGpu(:,:,:,batchIdx))/255, "SSCB");
        logits = forward(net4, dlX);
        [~,pred] = max(gather(extractdata(logits)),[],1);
        numCorrectA = numCorrectA + nnz(pred == yaVal(batchIdx)');
        numTotalA = numTotalA + numel(batchIdx);
    end
    if mod(epoch,1)==0
        fprintf("  TaskA Epoch %d | valAcc=%.4f\n", epoch, numCorrectA/numTotalA);
    end
end
fprintf("  Task A final valAcc=%.4f\n", numCorrectA/numTotalA);

% Train Task B (MNIST) on same network
[trainLoss, testAcc] = trainMnist(net4, Xtrain32, Xtest32, ytrain, ytest, ...
    mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, 0, "Step4_Continual_B");

fprintf("Step 4 Final: testAcc=%.4f\n", testAcc(end));
if testAcc(end) < accThreshold, fprintf("*** STOP: continual caused drop ***\n"); return; end

fprintf("\n========== ALL STEPS PASSED ==========\n");
end

% ---- Shared training function ----
function [trainLoss, testAcc] = trainMnist(net, Xtrain, Xtest, ytrain, ytest, ...
    mu, sig, numTrain, numTest, maxEpochs, batchSize, learnRate, varWeight, tag)

trailingAvg=[]; trailingAvgSq=[]; iter=0;
trainLoss = zeros(maxEpochs,1);
testAcc  = zeros(maxEpochs,1);

for epoch = 1:maxEpochs
    order = randperm(numTrain);
    epochLoss = single(0); batchCount = 0;

    for startIdx = 1:batchSize:numTrain
        endIdx = min(startIdx+batchSize-1, numTrain);
        batchIdx = order(startIdx:endIdx);
        iter = iter+1; batchCount = batchCount+1;

        Xb = (Xtrain(:,:,:,batchIdx) / 255 - mu) / sig;
        dlX = dlarray(Xb, "SSCB");
        Tb = gpuArray(zeros(10, numel(batchIdx), "single"));
        linearIdx = sub2ind([10 numel(batchIdx)], ytrain(batchIdx)', 1:numel(batchIdx));
        Tb(linearIdx) = 1;
        dlT = dlarray(Tb, "CB");

        if varWeight == 0
            [gr, loss] = dlfeval(@mnistPureCELoss, net, dlX, dlT);
        else
            [gr, loss, ce, vt] = dlfeval(@TransferLearning.ComputeModelGradientsVarianceLoss, net, dlX, dlT, varWeight); %#ok<ASGLU>
        end

        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gr, trailingAvg, trailingAvgSq, iter, learnRate);
        epochLoss = epochLoss + extractdata(loss);
    end

    trainLoss(epoch) = double(gather(epochLoss)) / batchCount;

    numCorrect = 0;
    for startIdx = 1:batchSize:numTest
        endIdx = min(startIdx+batchSize-1, numTest);
        batchIdx = startIdx:endIdx;
        Xb = (Xtest(:,:,:,batchIdx) / 255 - mu) / sig;
        dlX = dlarray(Xb, "SSCB");
        logits = forward(net, dlX);
        [~, pred] = max(gather(extractdata(logits)), [], 1);
        numCorrect = numCorrect + nnz(pred == ytest(batchIdx)');
    end
    testAcc(epoch) = numCorrect / numTest;
    fprintf("  [%s] E%d | loss=%.4f acc=%.4f\n", tag, epoch, trainLoss(epoch), testAcc(epoch));
end
end

function [gradients, loss] = mnistPureCELoss(net, dlX, dlT)
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
