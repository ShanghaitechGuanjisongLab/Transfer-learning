function RunSmallSampleRepeatParallel()
% Parallel 5-seed repeat: TaskA CIFAR vw=0 vs vw=0.5 res2-4.
% TaskB MNIST small-sample: 30 train/class, 10 val/class, B always vw=0.
% Metric: mean accuracy over TaskB epochs 2-4.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();

dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTrFull, ymTrFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmValFull, ymValFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

cfg.inputSize = [32 32 3];
cfg.numClasses = 10;
cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3;
cfg.maxEpochsA = 100;
cfg.maxEpochsB = 4;
cfg.samplesPerEpochA = 500;
cfg.nTrainPerClassB = 30;
cfg.nValPerClassB = 10;
cfg.varWeightA = 0.5;
cfg.varWeightB = 0;
cfg.layers = ["res2b_relu", "res3b_relu", "res4b_relu"];

seeds = 20260631:20260635;
nRepeats = numel(seeds);
gpuCount = gpuDeviceCount("available");
nWorkers = min(nRepeats, gpuCount);
fprintf("Parallel repeats: %d seeds, %d GPUs, %d workers\n", nRepeats, gpuCount, nWorkers);

pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= nWorkers
    delete(pool);
    pool = [];
end
if isempty(pool)
    parpool("Processes", nWorkers);
end

accB0 = zeros(nRepeats, cfg.maxEpochsB);
accB1 = zeros(nRepeats, cfg.maxEpochsB);
varB0 = zeros(nRepeats, cfg.maxEpochsB);
varB1 = zeros(nRepeats, cfg.maxEpochsB);
varA0Final = zeros(nRepeats, 1);
varA1Final = zeros(nRepeats, 1);
accA0Final = zeros(nRepeats, 1);
accA1Final = zeros(nRepeats, 1);
gpuUsed = zeros(nRepeats, 1);

parfor ri = 1:nRepeats
    task = getCurrentTask();
    if isempty(task)
        workerIdx = 1;
    else
        workerIdx = task.ID;
    end
    gpuIdx = mod(workerIdx - 1, gpuCount) + 1;
    gpuDevice(gpuIdx);

    seed = seeds(ri);
    fprintf("[repeat %d/%d] seed=%d worker=%d gpu=%d\n", ri, nRepeats, seed, workerIdx, gpuIdx);

    [XmTrSmall, ymTrSmall, XmValSmall, ymValSmall] = makeMnistSmallSubset( ...
        XmTrFull, ymTrFull, XmValFull, ymValFull, cfg.numClasses, ...
        cfg.nTrainPerClassB, cfg.nValPerClassB, seed);

    % Baseline: A(CIFAR vw=0) -> B(MNIST-small vw=0)
    rng(seed);
    [XgA0, TgA0] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, cfg.numClasses);
    net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    statsA0 = trainTaskA(net0, XgA0, TgA0, dataset.taskA.valX, dataset.taskA.valY, cfg, 0);
    [var0, acc0] = trainTaskBSmall(statsA0.netFinal, XmTrSmall, ymTrSmall, XmValSmall, ymValSmall, cfg, cfg.varWeightB);

    % A-var: A(CIFAR vw=0.5) -> B(MNIST-small vw=0)
    rng(seed);
    [XgA1, TgA1] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, cfg.numClasses);
    net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    statsA1 = trainTaskA(net1, XgA1, TgA1, dataset.taskA.valX, dataset.taskA.valY, cfg, cfg.varWeightA);
    [var1, acc1] = trainTaskBSmall(statsA1.netFinal, XmTrSmall, ymTrSmall, XmValSmall, ymValSmall, cfg, cfg.varWeightB);

    accB0(ri, :) = acc0;
    accB1(ri, :) = acc1;
    varB0(ri, :) = var0;
    varB1(ri, :) = var1;
    varA0Final(ri) = statsA0.trainVar(end);
    varA1Final(ri) = statsA1.trainVar(end);
    accA0Final(ri) = statsA0.finalValAccuracy;
    accA1Final(ri) = statsA1.finalValAccuracy;
    gpuUsed(ri) = gpuIdx;

    fprintf("[repeat %d] meanAcc2-4: base=%.4f avar=%.4f diff=%+.4f\n", ...
        ri, mean(acc0(2:4)), mean(acc1(2:4)), mean(acc1(2:4)) - mean(acc0(2:4)));
end

meanB0_2_4 = mean(accB0(:, 2:4), 2);
meanB1_2_4 = mean(accB1(:, 2:4), 2);
diff2_4 = meanB1_2_4 - meanB0_2_4;

results = table(seeds(:), gpuUsed, accA0Final, accA1Final, varA0Final, varA1Final, ...
    meanB0_2_4, meanB1_2_4, diff2_4, ...
    'VariableNames', ["seed", "gpu", "accA0Final", "accA1Final", "varA0Final", "varA1Final", ...
    "meanB0_2_4", "meanB1_2_4", "diff2_4"]);

fprintf("\n=== Repeat Summary: TaskB mean accuracy over epochs 2-4 ===\n");
disp(results(:, ["seed", "meanB0_2_4", "meanB1_2_4", "diff2_4"]));
fprintf("Positive repeats: %d/%d\n", sum(diff2_4 > 0), nRepeats);
fprintf("Mean diff=%.4f, SEM=%.4f, median=%.4f, range=[%+.4f, %+.4f]\n", ...
    mean(diff2_4), std(diff2_4) / sqrt(nRepeats), median(diff2_4), min(diff2_4), max(diff2_4));

outPath = fullfile(dataRoot, "models", "small_sample_repeat_parallel.mat");
save(outPath, "results", "accB0", "accB1", "varB0", "varB1", "cfg", "seeds", "-v7.3");
fprintf("Saved: %s\n", outPath);

plotRepeatSummary(accB0, accB1, diff2_4);
end

function [XmTrSmall, ymTrSmall, XmValSmall, ymValSmall] = makeMnistSmallSubset(XmTrFull, ymTrFull, XmValFull, ymValFull, numClasses, nTrainPerClass, nValPerClass, seed)
rng(seed);
XmTrSmall = zeros(nTrainPerClass * numClasses, size(XmTrFull, 2), "uint8");
ymTrSmall = zeros(nTrainPerClass * numClasses, 1, "uint8");
XmValSmall = zeros(nValPerClass * numClasses, size(XmValFull, 2), "uint8");
ymValSmall = zeros(nValPerClass * numClasses, 1, "uint8");
for classIdx = 1:numClasses
    trainRows = find(ymTrFull == classIdx);
    trainChosen = trainRows(randperm(numel(trainRows), nTrainPerClass));
    valRows = find(ymValFull == classIdx);
    valChosen = valRows(randperm(numel(valRows), nValPerClass));

    trainRange = (classIdx-1)*nTrainPerClass+1 : classIdx*nTrainPerClass;
    valRange = (classIdx-1)*nValPerClass+1 : classIdx*nValPerClass;
    XmTrSmall(trainRange, :) = XmTrFull(trainChosen, :);
    ymTrSmall(trainRange) = classIdx;
    XmValSmall(valRange, :) = XmValFull(valChosen, :);
    ymValSmall(valRange) = classIdx;
end
end

function stats = trainTaskA(net, Xg, Tg, XVal, yVal, cfg, varWeight)
nTr = size(Xg, 4);
samplesPerEpoch = min(cfg.samplesPerEpochA, nTr);
[dlXVal, dlTVal] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
stats = struct();
stats.trainVar = zeros(cfg.maxEpochsA, 1);
stats.valAccuracy = zeros(cfg.maxEpochsA, 1);
trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
for epoch = 1:cfg.maxEpochsA
    stats.valAccuracy(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXVal, dlTVal, cfg.miniBatchSize);
    order = randperm(nTr, samplesPerEpoch);
    epochVar = 0;
    batchCount = 0;
    for startIdx = 1:cfg.miniBatchSize:samplesPerEpoch
        endIdx = min(startIdx + cfg.miniBatchSize - 1, samplesPerEpoch);
        batchIdx = order(startIdx:endIdx);
        iteration = iteration + 1;
        dlX = dlarray(single(Xg(:,:,:,batchIdx)) / 255, "SSCB");
        dlT = dlarray(Tg(:, batchIdx), "CB");
        [gradients, ~, ~, varTerm] = dlfeval(@lossVar, net, dlX, dlT, varWeight, cfg.layers);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, cfg.learnRate);
        epochVar = epochVar + double(extractdata(varTerm));
        batchCount = batchCount + 1;
    end
    stats.trainVar(epoch) = epochVar / batchCount;
end
stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXVal, dlTVal, cfg.miniBatchSize);
stats.netFinal = net;
end

function [varVec, accVec] = trainTaskBSmall(net, XTrain, yTrain, XVal, yVal, cfg, varWeight)
numTrain = size(XTrain, 1);
[Xg, Tg] = TransferLearning.PreUploadCifarToGpu(XTrain, yTrain, cfg.numClasses);
[dlXVal, dlTVal] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
varVec = zeros(1, cfg.maxEpochsB);
accVec = zeros(1, cfg.maxEpochsB);
trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
for epoch = 1:cfg.maxEpochsB
    accVec(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXVal, dlTVal, cfg.miniBatchSize);
    order = 1:numTrain;
    epochVar = 0;
    batchCount = 0;
    for startIdx = 1:cfg.miniBatchSize:numTrain
        endIdx = min(startIdx + cfg.miniBatchSize - 1, numTrain);
        batchIdx = order(startIdx:endIdx);
        iteration = iteration + 1;
        dlX = dlarray(single(Xg(:,:,:,batchIdx)) / 255, "SSCB");
        dlT = dlarray(Tg(:, batchIdx), "CB");
        [gradients, ~, ~, varTerm] = dlfeval(@lossVar, net, dlX, dlT, varWeight, cfg.layers);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, cfg.learnRate);
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
probabilities = softmax(logits);
ceLoss = crossentropy(probabilities, dlT, TargetCategories="independent");
varianceTerms = zeros(1, numel(layers), "like", features{1});
for layerIdx = 1:numel(layers)
    featureMatrix = reshape(stripdims(features{layerIdx}), [], size(features{layerIdx}, 4));
    varianceTerms(layerIdx) = mean(var(featureMatrix, 0, 2), "all");
end
varTerm = mean(varianceTerms, "all");
loss = ceLoss / (1 + varWeight * varTerm);
gradients = dlgradient(loss, net.Learnables);
end

function plotRepeatSummary(accB0, accB1, diff2_4)
epochs = 1:size(accB0, 2);
meanB0 = mean(accB0, 1);
meanB1 = mean(accB1, 1);
semB0 = std(accB0, 0, 1) / sqrt(size(accB0, 1));
semB1 = std(accB1, 0, 1) / sqrt(size(accB1, 1));

figureHandle = figure("Position", [100 100 900 350]);
subplot(1,2,1);
errorbar(epochs, meanB0 * 100, semB0 * 100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
errorbar(epochs, meanB1 * 100, semB1 * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("TaskB Epoch"); ylabel("Accuracy (%)");
title("Small-Sample MNIST: Mean Across 5 Seeds");
legend("A vw=0 -> B vw=0", "A vw=0.5 -> B vw=0", "Location", "best");
grid on;

subplot(1,2,2);
bar(diff2_4 * 100);
yline(0, "k-");
xlabel("Repeat"); ylabel("meanAcc2-4 Diff (pp)");
title("A-var Advantage over Epochs 2-4");
grid on;

sgtitle("Parallel 5-Seed Repeat: TaskA Variance Effect on Small-Sample TaskB");
TransferLearning.ExportStandardFigure(figureHandle, 2, "TaskB_SmallSample_Repeat5_AvarAdvantage.svg");
fprintf("SVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_SmallSample_Repeat5_AvarAdvantage.svg"));
end
