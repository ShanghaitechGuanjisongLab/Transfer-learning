function RunSmallSampleSizeSweepParallel()
% Parallel sample-size sweep for TaskB MNIST.
% TaskA: CIFAR-10, vw=0 vs vw=0.5 res2-4.
% TaskB: MNIST fixed subsets, B always vw=0.
% Sample sizes: train/class = 15, 200, 2000; val/class = round(train/3).
% Metric: per-epoch TaskB accuracy diff = A-var minus baseline.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();

dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmFull, ymFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);

cfg.inputSize = [32 32 3];
cfg.numClasses = 10;
cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3;
cfg.maxEpochsA = 100;
cfg.maxEpochsB = 10;
cfg.samplesPerEpochA = 500;
cfg.varWeightA = 0.5;
cfg.varWeightB = 0;
cfg.layers = ["res2b_relu", "res3b_relu", "res4b_relu"];

trainPerClassList = [15, 200, 2000];
valPerClassList = round(trainPerClassList / 3);
seeds = 20260641:20260645;
nRepeats = numel(seeds);
nSizes = numel(trainPerClassList);

gpuCount = gpuDeviceCount("available");
nWorkers = min(nRepeats, gpuCount);
fprintf("Sample-size sweep: %d sizes, %d seeds, %d GPUs, %d workers\n", nSizes, nRepeats, gpuCount, nWorkers);
fprintf("train/class: "); fprintf("%d ", trainPerClassList); fprintf("\n");
fprintf("val/class:   "); fprintf("%d ", valPerClassList); fprintf("\n\n");

pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= nWorkers
    delete(pool);
    pool = [];
end
if isempty(pool)
    parpool("Processes", nWorkers);
end

accB0 = zeros(nRepeats, nSizes, cfg.maxEpochsB);
accB1 = zeros(nRepeats, nSizes, cfg.maxEpochsB);
varB0 = zeros(nRepeats, nSizes, cfg.maxEpochsB);
varB1 = zeros(nRepeats, nSizes, cfg.maxEpochsB);
varA0Final = zeros(nRepeats, 1);
varA1Final = zeros(nRepeats, 1);
accA0Final = zeros(nRepeats, 1);
accA1Final = zeros(nRepeats, 1);
gpuUsed = zeros(nRepeats, 1);

parfor repeatIdx = 1:nRepeats
    task = getCurrentTask();
    if isempty(task)
        workerIdx = 1;
    else
        workerIdx = task.ID;
    end
    gpuIdx = mod(workerIdx - 1, gpuCount) + 1;
    gpuDevice(gpuIdx);

    seed = seeds(repeatIdx);
    fprintf("[repeat %d/%d] seed=%d worker=%d gpu=%d\n", repeatIdx, nRepeats, seed, workerIdx, gpuIdx);

    rng(seed);
    [XgA0, TgA0] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, cfg.numClasses);
    net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    statsA0 = trainTaskA(net0, XgA0, TgA0, dataset.taskA.valX, dataset.taskA.valY, cfg, 0);

    rng(seed);
    [XgA1, TgA1] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, cfg.numClasses);
    net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    statsA1 = trainTaskA(net1, XgA1, TgA1, dataset.taskA.valX, dataset.taskA.valY, cfg, cfg.varWeightA);

    localAccB0 = zeros(nSizes, cfg.maxEpochsB);
    localAccB1 = zeros(nSizes, cfg.maxEpochsB);
    localVarB0 = zeros(nSizes, cfg.maxEpochsB);
    localVarB1 = zeros(nSizes, cfg.maxEpochsB);

    for sizeIdx = 1:nSizes
        nTrainPerClass = trainPerClassList(sizeIdx);
        nValPerClass = valPerClassList(sizeIdx);
        [XTrainSmall, yTrainSmall, XValSmall, yValSmall] = makeMnistDisjointSubset( ...
            XmFull, ymFull, cfg.numClasses, nTrainPerClass, nValPerClass, seed + 1000 * sizeIdx);

        [var0, acc0] = trainTaskBSmall(statsA0.netFinal, XTrainSmall, yTrainSmall, XValSmall, yValSmall, cfg, cfg.varWeightB);
        [var1, acc1] = trainTaskBSmall(statsA1.netFinal, XTrainSmall, yTrainSmall, XValSmall, yValSmall, cfg, cfg.varWeightB);

        localAccB0(sizeIdx, :) = acc0;
        localAccB1(sizeIdx, :) = acc1;
        localVarB0(sizeIdx, :) = var0;
        localVarB1(sizeIdx, :) = var1;

        epochDiff = acc1 - acc0;
        positiveEpochs = find(epochDiff > 0);
        fprintf("[repeat %d size %d/class] diff ep1-10: ", repeatIdx, nTrainPerClass);
        fprintf("%+.2f ", epochDiff * 100);
        fprintf("| positive epochs: "); fprintf("%d ", positiveEpochs); fprintf("\n");
    end

    accB0(repeatIdx, :, :) = localAccB0;
    accB1(repeatIdx, :, :) = localAccB1;
    varB0(repeatIdx, :, :) = localVarB0;
    varB1(repeatIdx, :, :) = localVarB1;
    varA0Final(repeatIdx) = statsA0.trainVar(end);
    varA1Final(repeatIdx) = statsA1.trainVar(end);
    accA0Final(repeatIdx) = statsA0.finalValAccuracy;
    accA1Final(repeatIdx) = statsA1.finalValAccuracy;
    gpuUsed(repeatIdx) = gpuIdx;
end

summarizeResults(accB0, accB1, trainPerClassList, seeds);

outPath = fullfile(dataRoot, "models", "small_sample_size_sweep_parallel.mat");
save(outPath, "accB0", "accB1", "varB0", "varB1", "varA0Final", "varA1Final", ...
    "accA0Final", "accA1Final", "trainPerClassList", "valPerClassList", "seeds", "gpuUsed", "cfg", "-v7.3");
fprintf("Saved: %s\n", outPath);

plotSampleSizeSweep(accB0, accB1, trainPerClassList);
end

function [XTrainSmall, yTrainSmall, XValSmall, yValSmall] = makeMnistDisjointSubset(XFull, yFull, numClasses, nTrainPerClass, nValPerClass, seed)
rng(seed);
XTrainSmall = zeros(nTrainPerClass * numClasses, size(XFull, 2), "uint8");
yTrainSmall = zeros(nTrainPerClass * numClasses, 1, "uint8");
XValSmall = zeros(nValPerClass * numClasses, size(XFull, 2), "uint8");
yValSmall = zeros(nValPerClass * numClasses, 1, "uint8");
for classIdx = 1:numClasses
    classRows = find(yFull == classIdx);
    classRows = classRows(randperm(numel(classRows)));
    totalNeeded = nTrainPerClass + nValPerClass;
    assert(numel(classRows) >= totalNeeded, "Class %d has only %d samples, need %d.", classIdx, numel(classRows), totalNeeded);
    trainChosen = classRows(1:nTrainPerClass);
    valChosen = classRows(nTrainPerClass+1:totalNeeded);

    trainRange = (classIdx-1)*nTrainPerClass+1 : classIdx*nTrainPerClass;
    valRange = (classIdx-1)*nValPerClass+1 : classIdx*nValPerClass;
    XTrainSmall(trainRange, :) = XFull(trainChosen, :);
    yTrainSmall(trainRange) = classIdx;
    XValSmall(valRange, :) = XFull(valChosen, :);
    yValSmall(valRange) = classIdx;
end

trainOrder = randperm(size(XTrainSmall, 1));
XTrainSmall = XTrainSmall(trainOrder, :);
yTrainSmall = yTrainSmall(trainOrder);

valOrder = randperm(size(XValSmall, 1));
XValSmall = XValSmall(valOrder, :);
yValSmall = yValSmall(valOrder);
end

function stats = trainTaskA(net, Xg, Tg, XVal, yVal, cfg, varWeight)
nTrain = size(Xg, 4);
samplesPerEpoch = min(cfg.samplesPerEpochA, nTrain);
[dlXVal, dlTVal] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
stats = struct();
stats.trainVar = zeros(cfg.maxEpochsA, 1);
stats.valAccuracy = zeros(cfg.maxEpochsA, 1);
trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
for epoch = 1:cfg.maxEpochsA
    stats.valAccuracy(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXVal, dlTVal, cfg.miniBatchSize);
    order = randperm(nTrain, samplesPerEpoch);
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

function summarizeResults(accB0, accB1, trainPerClassList, seeds)
diff = accB1 - accB0;
nSizes = numel(trainPerClassList);
nEpochs = size(accB0, 3);
fprintf("\n=== Stable Epoch Summary ===\n");
for sizeIdx = 1:nSizes
    fprintf("\ntrain/class=%d\n", trainPerClassList(sizeIdx));
    stablePositiveEpochs = [];
    for epoch = 1:nEpochs
        epochDiff = diff(:, sizeIdx, epoch);
        positiveCount = sum(epochDiff > 0);
        meanDiff = mean(epochDiff);
        fprintf("  epoch %2d: pos=%d/%d meanDiff=%+.4f range=[%+.4f,%+.4f]\n", ...
            epoch, positiveCount, numel(seeds), meanDiff, min(epochDiff), max(epochDiff));
        if positiveCount == numel(seeds)
            stablePositiveEpochs(end+1) = epoch; %#ok<AGROW>
        end
    end
    if isempty(stablePositiveEpochs)
        fprintf("  stable positive epochs: none\n");
    else
        fprintf("  stable positive epochs: "); fprintf("%d ", stablePositiveEpochs); fprintf("\n");
    end
end
end

function plotSampleSizeSweep(accB0, accB1, trainPerClassList)
epochs = 1:size(accB0, 3);
nSizes = numel(trainPerClassList);
figureHandle = figure("Position", [100 100 1100 700]);
for sizeIdx = 1:nSizes
    meanB0 = squeeze(mean(accB0(:, sizeIdx, :), 1));
    meanB1 = squeeze(mean(accB1(:, sizeIdx, :), 1));
    semB0 = squeeze(std(accB0(:, sizeIdx, :), 0, 1)) / sqrt(size(accB0, 1));
    semB1 = squeeze(std(accB1(:, sizeIdx, :), 0, 1)) / sqrt(size(accB1, 1));

    subplot(2, nSizes, sizeIdx);
    errorbar(epochs, meanB0 * 100, semB0 * 100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
    errorbar(epochs, meanB1 * 100, semB1 * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
    xlabel("TaskB Epoch"); ylabel("Accuracy (%)");
    title(sprintf("%d train/class", trainPerClassList(sizeIdx)));
    legend("A vw=0", "A vw=0.5", "Location", "best");
    grid on;

    subplot(2, nSizes, nSizes + sizeIdx);
    diff = squeeze(accB1(:, sizeIdx, :) - accB0(:, sizeIdx, :));
    meanDiff = mean(diff, 1);
    semDiff = std(diff, 0, 1) / sqrt(size(diff, 1));
    errorbar(epochs, meanDiff * 100, semDiff * 100, "k-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
    yline(0, "k-");
    xlabel("TaskB Epoch"); ylabel("Diff (pp)");
    title("A-var advantage");
    grid on;
end
sgtitle("MNIST Sample-Size Sweep: TaskA Variance Effect on TaskB");
TransferLearning.ExportStandardFigure(figureHandle, 2, "TaskB_SmallSample_SizeSweep_AvarAdvantage.svg");
fprintf("SVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_SmallSample_SizeSweep_AvarAdvantage.svg"));
end
