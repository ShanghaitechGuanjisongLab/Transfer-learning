function RunSmallSampleRepeatBNoVar()
% Repeat small-sample MNIST transfer 5 times.
% TaskA: CIFAR-10, vw=0 vs vw=0.5 res2-4, 100 epochs.
% TaskB: MNIST small subset, B vw=0 for both groups, 4 epochs.
% Metric: mean accuracy over TaskB epochs 2:4.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();

dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTrFull, ymTrFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmValFull, ymValFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inputSize = [32 32 3];
numClasses = 10;
miniBatchSize = 128;
learnRate = 1e-3;
maxEpochsA = 100;
samplesPerEpochA = 500;
maxEpochsB = 4;
varWeightA = 0.5;
varWeightB = 0;
layers = ["res2b_relu", "res3b_relu", "res4b_relu"];
seeds = 20260631:20260635;
numRepeats = numel(seeds);

gpuDevice(3);
[XgCifar, TgCifar] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, numClasses);

results = table('Size', [numRepeats 16], ...
    'VariableTypes', ["double", "double", "double", "double", "double", "double", "double", "double", ...
                      "double", "double", "double", "double", "double", "double", "double", "double"], ...
    'VariableNames', ["repeat", "seed", "a0FinalVar", "a1FinalVar", "a0FinalAcc", "a1FinalAcc", ...
                      "b0Acc2", "b0Acc3", "b0Acc4", "b1Acc2", "b1Acc3", "b1Acc4", ...
                      "b0Mean2to4", "b1Mean2to4", "diffMean2to4", "b1Wins"]);
accB0All = zeros(numRepeats, maxEpochsB);
accB1All = zeros(numRepeats, maxEpochsB);
varB0All = zeros(numRepeats, maxEpochsB);
varB1All = zeros(numRepeats, maxEpochsB);

for repeatIdx = 1:numRepeats
    seed = seeds(repeatIdx);
    fprintf("\n=== Repeat %d/%d | seed=%d ===\n", repeatIdx, numRepeats, seed);

    [XmTrSmall, ymTrSmall, XmValSmall, ymValSmall] = makeSmallMnistSubset( ...
        XmTrFull, ymTrFull, XmValFull, ymValFull, 30, 10, seed, numClasses);

    % A0: CIFAR vw=0
    fprintf("--- Train A0: CIFAR vw=0 ---\n");
    rng(seed);
    net0 = TransferLearning.BuildResNet18Classifier(inputSize, numClasses);
    statsA0 = trainTaskAVar(net0, XgCifar, TgCifar, dataset.taskA.valX, dataset.taskA.valY, ...
        inputSize, numClasses, maxEpochsA, miniBatchSize, learnRate, 0, layers, samplesPerEpochA);
    fprintf("A0 final var=%.4f acc=%.4f\n", statsA0.trainVar(end), statsA0.finalValAccuracy);

    % A1: CIFAR vw=0.5, same seed as A0
    fprintf("--- Train A1: CIFAR vw=0.5 res2-4 ---\n");
    rng(seed);
    net1 = TransferLearning.BuildResNet18Classifier(inputSize, numClasses);
    statsA1 = trainTaskAVar(net1, XgCifar, TgCifar, dataset.taskA.valX, dataset.taskA.valY, ...
        inputSize, numClasses, maxEpochsA, miniBatchSize, learnRate, varWeightA, layers, samplesPerEpochA);
    fprintf("A1 final var=%.4f acc=%.4f\n", statsA1.trainVar(end), statsA1.finalValAccuracy);

    % TaskB: both no variance, fixed 300-image order every epoch
    fprintf("--- Train B0/B1: MNIST small, B vw=0 ---\n");
    [varB0, accB0] = trainTaskBVarSmall(statsA0.netFinal, XmTrSmall, ymTrSmall, XmValSmall, ymValSmall, ...
        inputSize, numClasses, maxEpochsB, miniBatchSize, learnRate, varWeightB, layers);
    [varB1, accB1] = trainTaskBVarSmall(statsA1.netFinal, XmTrSmall, ymTrSmall, XmValSmall, ymValSmall, ...
        inputSize, numClasses, maxEpochsB, miniBatchSize, learnRate, varWeightB, layers);

    meanB0 = mean(accB0(2:4));
    meanB1 = mean(accB1(2:4));
    diffMean = meanB1 - meanB0;
    fprintf("B0 acc: "); fprintf("%.4f ", accB0); fprintf("\n");
    fprintf("B1 acc: "); fprintf("%.4f ", accB1); fprintf("\n");
    fprintf("meanAcc2to4: B0=%.4f B1=%.4f diff=%+.4f\n", meanB0, meanB1, diffMean);

    results.repeat(repeatIdx) = repeatIdx;
    results.seed(repeatIdx) = seed;
    results.a0FinalVar(repeatIdx) = statsA0.trainVar(end);
    results.a1FinalVar(repeatIdx) = statsA1.trainVar(end);
    results.a0FinalAcc(repeatIdx) = statsA0.finalValAccuracy;
    results.a1FinalAcc(repeatIdx) = statsA1.finalValAccuracy;
    results.b0Acc2(repeatIdx) = accB0(2);
    results.b0Acc3(repeatIdx) = accB0(3);
    results.b0Acc4(repeatIdx) = accB0(4);
    results.b1Acc2(repeatIdx) = accB1(2);
    results.b1Acc3(repeatIdx) = accB1(3);
    results.b1Acc4(repeatIdx) = accB1(4);
    results.b0Mean2to4(repeatIdx) = meanB0;
    results.b1Mean2to4(repeatIdx) = meanB1;
    results.diffMean2to4(repeatIdx) = diffMean;
    results.b1Wins(repeatIdx) = diffMean > 0;

    accB0All(repeatIdx, :) = accB0(:)';
    accB1All(repeatIdx, :) = accB1(:)';
    varB0All(repeatIdx, :) = varB0(:)';
    varB1All(repeatIdx, :) = varB1(:)';
end

fprintf("\n=== Summary: mean accuracy over TaskB epochs 2:4 ===\n");
disp(results(:, ["repeat", "seed", "b0Mean2to4", "b1Mean2to4", "diffMean2to4", "b1Wins"]));
winCount = sum(results.b1Wins);
fprintf("B1 wins: %d/%d\n", winCount, numRepeats);
fprintf("Mean diff=%.4f | median diff=%.4f | std=%.4f\n", ...
    mean(results.diffMean2to4), median(results.diffMean2to4), std(results.diffMean2to4));

outPath = fullfile(dataRoot, "models", "small_sample_repeat_b_no_var.mat");
save(outPath, "results", "accB0All", "accB1All", "varB0All", "varB1All", "seeds", "-v7.3");
fprintf("Saved: %s\n", outPath);

plotRepeatSummary(results, accB0All, accB1All, varB0All, varB1All);
end

function [XmTrSmall, ymTrSmall, XmValSmall, ymValSmall] = makeSmallMnistSubset( ...
    XmTrFull, ymTrFull, XmValFull, ymValFull, trainPerClass, valPerClass, seed, numClasses)
rng(seed);
XmTrSmall = zeros(trainPerClass * numClasses, size(XmTrFull, 2), "uint8");
ymTrSmall = zeros(trainPerClass * numClasses, 1, "uint8");
XmValSmall = zeros(valPerClass * numClasses, size(XmValFull, 2), "uint8");
ymValSmall = zeros(valPerClass * numClasses, 1, "uint8");
for classIdx = 1:numClasses
    trainIdx = find(ymTrFull == classIdx);
    trainChosen = trainIdx(randperm(numel(trainIdx), trainPerClass));
    valIdx = find(ymValFull == classIdx);
    valChosen = valIdx(randperm(numel(valIdx), valPerClass));

    trainRows = (classIdx-1)*trainPerClass+1 : classIdx*trainPerClass;
    valRows = (classIdx-1)*valPerClass+1 : classIdx*valPerClass;
    XmTrSmall(trainRows, :) = XmTrFull(trainChosen, :);
    ymTrSmall(trainRows) = classIdx;
    XmValSmall(valRows, :) = XmValFull(valChosen, :);
    ymValSmall(valRows) = classIdx;
end
end

function stats = trainTaskAVar(net, Xg, Tg, Xv, yv, inputSize, numClasses, maxEpochs, miniBatchSize, learnRate, varWeight, layers, samplesPerEpoch)
numTrain = size(Xg, 4);
samplesPerEpoch = min(samplesPerEpoch, numTrain);
[dlXv, dlTv] = TransferLearning.PreprocessCifarRows(Xv, yv, inputSize, numClasses);
stats = struct();
stats.trainVar = zeros(maxEpochs, 1);
stats.valAccuracy = zeros(maxEpochs, 1);
trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
for epoch = 1:maxEpochs
    stats.valAccuracy(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXv, dlTv, miniBatchSize);
    order = randperm(numTrain, samplesPerEpoch);
    epochVar = 0;
    batchCount = 0;
    for startIdx = 1:miniBatchSize:samplesPerEpoch
        endIdx = min(startIdx+miniBatchSize-1, samplesPerEpoch);
        batchIdx = order(startIdx:endIdx);
        iteration = iteration + 1;
        dlX = dlarray(single(Xg(:,:,:,batchIdx))/255, "SSCB");
        dlT = dlarray(Tg(:,batchIdx), "CB");
        [gradients, ~, ~, varTerm] = dlfeval(@lossVar, net, dlX, dlT, varWeight, layers);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate);
        epochVar = epochVar + double(extractdata(varTerm));
        batchCount = batchCount + 1;
    end
    stats.trainVar(epoch) = epochVar / batchCount;
end
stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXv, dlTv, miniBatchSize);
stats.netFinal = net;
end

function [varVec, accVec] = trainTaskBVarSmall(net, XTr, yTr, XV, yV, inputSize, numClasses, maxEpochs, miniBatchSize, learnRate, varWeight, layers)
numTrain = size(XTr, 1);
[Xg, Tg] = TransferLearning.PreUploadCifarToGpu(XTr, yTr, numClasses);
[dlXv, dlTv] = TransferLearning.PreprocessCifarRows(XV, yV, inputSize, numClasses);
varVec = zeros(maxEpochs, 1);
accVec = zeros(maxEpochs, 1);
trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
for epoch = 1:maxEpochs
    accVec(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXv, dlTv, miniBatchSize);
    order = 1:numTrain;
    epochVar = 0;
    batchCount = 0;
    for startIdx = 1:miniBatchSize:numTrain
        endIdx = min(startIdx+miniBatchSize-1, numTrain);
        batchIdx = order(startIdx:endIdx);
        iteration = iteration + 1;
        dlX = dlarray(single(Xg(:,:,:,batchIdx))/255, "SSCB");
        dlT = dlarray(Tg(:,batchIdx), "CB");
        [gradients, ~, ~, varTerm] = dlfeval(@lossVar, net, dlX, dlT, varWeight, layers);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate);
        epochVar = epochVar + double(extractdata(varTerm));
        batchCount = batchCount + 1;
    end
    varVec(epoch) = epochVar / batchCount;
end
end

function [gradients, loss, ceLoss, varTerm] = lossVar(net, dlX, dlT, varWeight, layers)
outputs = ["fc_logits", layers];
features = cell(1, numel(layers));
[logits, features{:}] = forward(net, dlX, Outputs=outputs);
probs = softmax(logits);
ceLoss = crossentropy(probs, dlT, TargetCategories="independent");
varValues = zeros(1, numel(layers), "like", features{1});
for layerIdx = 1:numel(layers)
    featureMatrix = reshape(stripdims(features{layerIdx}), [], size(features{layerIdx}, 4));
    varValues(layerIdx) = mean(var(featureMatrix, 0, 2), "all");
end
varTerm = mean(varValues, "all");
loss = ceLoss / (1 + varWeight * varTerm);
gradients = dlgradient(loss, net.Learnables);
end

function plotRepeatSummary(results, accB0All, accB1All, varB0All, varB1All)
numRepeats = height(results);
epochs = 1:size(accB0All, 2);
fig = figure("Position", [100 100 1100 650]);

subplot(2,2,1);
bar(results.repeat, results.diffMean2to4 * 100);
yline(0, "k--");
xlabel("Repeat"); ylabel("B1 - B0 meanAcc2-4 (pp)");
title("Epoch 2-4 Accuracy Advantage"); grid on;

subplot(2,2,2);
plot(epochs, mean(accB0All, 1) * 100, "b-o", "LineWidth", 1.4, "MarkerSize", 4); hold on;
plot(epochs, mean(accB1All, 1) * 100, "r-s", "LineWidth", 1.4, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Accuracy (%)");
title("Mean TaskB Accuracy Across Repeats");
legend("A0/B0", "A0.5/B0", "Location", "best"); grid on;

subplot(2,2,3);
plot(epochs, mean(varB0All, 1), "b-o", "LineWidth", 1.4, "MarkerSize", 4); hold on;
plot(epochs, mean(varB1All, 1), "r-s", "LineWidth", 1.4, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Hidden Var (res2-4)");
title("Mean TaskB Hidden Variance");
legend("A0/B0", "A0.5/B0", "Location", "best"); grid on;

subplot(2,2,4);
scatter(results.b0Mean2to4 * 100, results.b1Mean2to4 * 100, 45, "filled"); hold on;
minVal = min([results.b0Mean2to4; results.b1Mean2to4]) * 100;
maxVal = max([results.b0Mean2to4; results.b1Mean2to4]) * 100;
plot([minVal maxVal], [minVal maxVal], "k--");
xlabel("B0 meanAcc2-4 (%)"); ylabel("B1 meanAcc2-4 (%)");
title("Per-Repeat Paired Comparison"); grid on; axis square;

sgtitle(sprintf("Small-Sample MNIST Repeat Test: B1 wins %d/%d, mean diff %.2f pp", ...
    sum(results.b1Wins), numRepeats, mean(results.diffMean2to4) * 100));
TransferLearning.ExportStandardFigure(fig, 2, "TaskB_SmallSample_Repeat5_BNoVar_Epoch2to4.svg");
fprintf("SVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_SmallSample_Repeat5_BNoVar_Epoch2to4.svg"));
end
