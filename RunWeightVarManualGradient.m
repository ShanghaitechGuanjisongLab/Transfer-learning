function RunWeightVarManualGradient()
% Corrected weight-variance regularization with manual dVar/dW gradient.
% TaskA: CIFAR vw=0 vs vw=5000 using pos/neg geomean weight variance on res2b/res3b/res4b.
% TaskB: full MNIST train pool, 600 random samples/epoch, full t10k validation, B vw=0.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTrain, ymTrain] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

cfg.inputSize = [32 32 3]; cfg.numClasses = 10; cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3; cfg.maxEpochsA = 100; cfg.maxEpochsB = 10;
cfg.samplesPerEpochA = 500; cfg.samplesPerEpochB = 600;
cfg.varWeightA = 5000; cfg.varWeightB = 0;
cfg.weightLayerPrefixes = ["res2b", "res3b", "res4b"];

seeds = 20260751:20260770; nRepeats = numel(seeds);
gpuCount = gpuDeviceCount("available"); nWorkers = min(nRepeats, gpuCount);
fprintf("Manual weight-var gradient: %d seeds, %d GPUs, %d workers\n", nRepeats, gpuCount, nWorkers);

pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= nWorkers, delete(pool); end
if isempty(pool), parpool("Processes", nWorkers); end

accB0 = zeros(nRepeats, cfg.maxEpochsB);
accB1 = zeros(nRepeats, cfg.maxEpochsB);
varB0 = zeros(nRepeats, cfg.maxEpochsB);
varB1 = zeros(nRepeats, cfg.maxEpochsB);
varA0Final = zeros(nRepeats, 1);
varA1Final = zeros(nRepeats, 1);
accA0Final = zeros(nRepeats, 1);
accA1Final = zeros(nRepeats, 1);

parfor ri = 1:nRepeats
    task = getCurrentTask(); workerIdx = 1; if ~isempty(task), workerIdx = task.ID; end
    gpuIdx = mod(workerIdx - 1, gpuCount) + 1; gpuDevice(gpuIdx);
    seed = seeds(ri);
    fprintf("[repeat %d/%d] seed=%d gpu=%d\n", ri, nRepeats, seed, gpuIdx);

    rng(seed);
    [XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, cfg.numClasses);

    net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    [net0, varA0, accA0] = trainTaskA(net0, XgA, TgA, dataset.taskA.valX, dataset.taskA.valY, cfg, 0, false);
    varA0Final(ri) = varA0(end); accA0Final(ri) = accA0(end);

    rng(seed);
    net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    [net1, varA1, accA1] = trainTaskA(net1, XgA, TgA, dataset.taskA.valX, dataset.taskA.valY, cfg, cfg.varWeightA, true);
    varA1Final(ri) = varA1(end); accA1Final(ri) = accA1(end);

    [XgT, TgT] = TransferLearning.PreUploadCifarToGpu(XmTrain, ymTrain, cfg.numClasses);
    taskBOrders = makeTaskBOrders(size(XmTrain, 1), cfg.samplesPerEpochB, cfg.maxEpochsB, seed + 5000);
    [v0, a0] = trainTaskB(net0, XgT, TgT, XmVal, ymVal, taskBOrders, cfg);
    [v1, a1] = trainTaskB(net1, XgT, TgT, XmVal, ymVal, taskBOrders, cfg);

    varB0(ri, :) = v0; varB1(ri, :) = v1;
    accB0(ri, :) = a0; accB1(ri, :) = a1;
    fprintf("[repeat %d] Avar: B0=%.6g B1=%.6g | ep3 diff=%+.4f ep10 diff=%+.4f\n", ...
        ri, varA0(end), varA1(end), a1(3)-a0(3), a1(end)-a0(end));
end

fprintf("\n=== Corrected Weight-Variance: TaskA var ===\n");
fprintf("A0 var mean=%.9f range=[%.9f, %.9f]\n", mean(varA0Final), min(varA0Final), max(varA0Final));
fprintf("A1 var mean=%.9f range=[%.9f, %.9f]\n", mean(varA1Final), min(varA1Final), max(varA1Final));
fprintf("A1-A0 var diff mean=%+.9f\n", mean(varA1Final - varA0Final));

fprintf("\n=== Corrected Weight-Variance: TaskB accuracy ===\n");
fprintf("%-8s %-8s %-8s %-9s %-8s %-10s %-10s\n", "Epoch", "B0_mean", "B1_mean", "Diff", "Pos", "p_ttest", "sig_Bonf");
alphaBonf = 0.05 / cfg.maxEpochsB;
for ep = 1:cfg.maxEpochsB
    d = accB1(:,ep) - accB0(:,ep);
    [~, pValue] = ttest(d);
    sigText = "no";
    if pValue < alphaBonf
        sigText = "yes";
    end
    fprintf("%-8d %-8.4f %-8.4f %+9.4f %-8s %-10.4g %-10s\n", ...
        ep, mean(accB0(:,ep)), mean(accB1(:,ep)), mean(d), sprintf("%d/%d", sum(d>0), nRepeats), pValue, sigText);
end
fprintf("Bonferroni threshold across %d epochs: p < %.4g\n", cfg.maxEpochsB, alphaBonf);

figureHandle = figure("Position", [100 100 900 350]);
subplot(1,2,1);
epochs = 1:cfg.maxEpochsB;
meanB0 = mean(accB0, 1); meanB1 = mean(accB1, 1);
semB0 = std(accB0, 0, 1) / sqrt(nRepeats); semB1 = std(accB1, 0, 1) / sqrt(nRepeats);
errorbar(epochs, meanB0*100, semB0*100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
errorbar(epochs, meanB1*100, semB1*100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("TaskB Epoch"); ylabel("Accuracy (%)");
title("Manual dVar/dW, Full MNIST 1%/epoch");
legend("A vw=0", "A vw=5000", "Location", "best"); grid on;

subplot(1,2,2);
diffAcc = accB1 - accB0;
meanDiff = mean(diffAcc, 1) * 100;
semDiff = std(diffAcc, 0, 1) / sqrt(nRepeats) * 100;
errorbar(epochs, meanDiff, semDiff, "k-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
yline(0, "k-");
xlabel("TaskB Epoch"); ylabel("Diff (pp)");
title("Corrected Weight-Var Advantage"); grid on;
sgtitle("Corrected Pos/Neg Weight-Variance Geomean (vw=5000, n=20)");

TransferLearning.ExportStandardFigure(figureHandle, 2, "TaskB_WeightVar_ManualGradient_vw5000_20seeds.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_WeightVar_ManualGradient_vw5000_20seeds.svg"));

outPath = fullfile(dataRoot, "models", "weight_var_manual_gradient_vw5000_20seeds.mat");
save(outPath, "accB0", "accB1", "varB0", "varB1", "varA0Final", "varA1Final", "accA0Final", "accA1Final", "cfg", "seeds", "-v7.3");
fprintf("Saved: %s\n", outPath);
end

function orders = makeTaskBOrders(numTrain, samplesPerEpoch, maxEpochs, seed)
rng(seed);
orders = zeros(maxEpochs, samplesPerEpoch);
for epoch = 1:maxEpochs
    orders(epoch, :) = randperm(numTrain, samplesPerEpoch);
end
end

function [net, varLog, accLog] = trainTaskA(net, Xg, Tg, XVal, yVal, cfg, varWeight, useManualWeightVar)
nTrain = size(Xg, 4); samplesPerEpoch = min(cfg.samplesPerEpochA, nTrain);
[dlXVal, dlTVal] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
varLog = zeros(cfg.maxEpochsA, 1); accLog = zeros(cfg.maxEpochsA, 1);
trailingAvg = []; trailingAvgSq = []; iteration = 0;
for epoch = 1:cfg.maxEpochsA
    accLog(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXVal, dlTVal, cfg.miniBatchSize);
    order = randperm(nTrain, samplesPerEpoch);
    epochVar = 0; batchCount = 0;
    for startIdx = 1:cfg.miniBatchSize:samplesPerEpoch
        endIdx = min(startIdx + cfg.miniBatchSize - 1, samplesPerEpoch);
        batchIdx = order(startIdx:endIdx); iteration = iteration + 1;
        dlX = dlarray(single(Xg(:,:,:,batchIdx)) / 255, "SSCB");
        dlT = dlarray(Tg(:, batchIdx), "CB");
        [gradients, ceLoss] = dlfeval(@ceGradOnly, net, dlX, dlT);
        varTerm = weightVarTermNumeric(net, cfg.weightLayerPrefixes);
        if useManualWeightVar && varWeight ~= 0
            gradients = addManualWeightVarGradient(net, gradients, ceLoss, varTerm, varWeight, cfg.weightLayerPrefixes);
            scale = 1 / (1 + varWeight * varTerm);
            gradients.Value = cellfun(@(g) g * scale, gradients.Value, 'UniformOutput', false);
        end
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, cfg.learnRate);
        epochVar = epochVar + varTerm; batchCount = batchCount + 1;
    end
    varLog(epoch) = epochVar / batchCount;
end
end

function [varVec, accVec] = trainTaskB(net, XgTr, TgTr, XVal, yVal, taskBOrders, cfg)
[dlXVal, dlTVal] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
varVec = zeros(1, cfg.maxEpochsB); accVec = zeros(1, cfg.maxEpochsB);
trailingAvg = []; trailingAvgSq = []; iteration = 0;
for epoch = 1:cfg.maxEpochsB
    accVec(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXVal, dlTVal, cfg.miniBatchSize);
    order = taskBOrders(epoch, :); epochVar = 0; batchCount = 0;
    for startIdx = 1:cfg.miniBatchSize:numel(order)
        endIdx = min(startIdx + cfg.miniBatchSize - 1, numel(order));
        batchIdx = order(startIdx:endIdx); iteration = iteration + 1;
        dlX = dlarray(single(XgTr(:,:,:,batchIdx)) / 255, "SSCB");
        dlT = dlarray(TgTr(:, batchIdx), "CB");
        [gradients, ~] = dlfeval(@ceGradOnly, net, dlX, dlT);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, cfg.learnRate);
        epochVar = epochVar + weightVarTermNumeric(net, cfg.weightLayerPrefixes); batchCount = batchCount + 1;
    end
    varVec(epoch) = epochVar / batchCount;
end
end

function [gradients, ceLoss] = ceGradOnly(net, dlX, dlT)
logits = forward(net, dlX, Outputs="fc_logits");
probabilities = softmax(logits);
ceLoss = crossentropy(probabilities, dlT, TargetCategories="independent");
gradients = dlgradient(ceLoss, net.Learnables);
end

function gradients = addManualWeightVarGradient(net, gradients, ceLoss, varTerm, varWeight, layerPrefixes)
coefficient = -double(gather(extractdata(ceLoss))) * varWeight / (1 + varWeight * varTerm)^2;
learnables = net.Learnables;
componentVars = collectWeightVarianceComponents(learnables, layerPrefixes);
numComponents = numel(componentVars);
for paramIdx = 1:height(learnables)
    layerName = string(learnables.Layer(paramIdx));
    paramName = string(learnables.Parameter(paramIdx));
    if ~matchesPrefix(layerName, layerPrefixes) || ~endsWith(paramName, "Weights")
        continue
    end
    weights = learnables.Value{paramIdx};
    manual = zeros(size(weights), "like", weights);
    positiveMask = weights > 0;
    negativeMask = weights < 0;
    positiveWeights = weights(positiveMask);
    negativeWeights = weights(negativeMask);
    positiveVar = double(gather(extractdata(var(positiveWeights(:)))));
    negativeVar = double(gather(extractdata(var(negativeWeights(:)))));
    if numel(positiveWeights) > 1
        dVar = varianceGradient(positiveWeights, numel(positiveWeights));
        manual(positiveMask) = manual(positiveMask) + coefficient * varTerm / (numComponents * positiveVar) * dVar;
    end
    if numel(negativeWeights) > 1
        dVar = varianceGradient(negativeWeights, numel(negativeWeights));
        manual(negativeMask) = manual(negativeMask) + coefficient * varTerm / (numComponents * negativeVar) * dVar;
    end
    gradients.Value{paramIdx} = gradients.Value{paramIdx} + manual;
end
end

function componentVars = collectWeightVarianceComponents(learnables, layerPrefixes)
componentVars = [];
for paramIdx = 1:height(learnables)
    layerName = string(learnables.Layer(paramIdx));
    paramName = string(learnables.Parameter(paramIdx));
    if matchesPrefix(layerName, layerPrefixes) && endsWith(paramName, "Weights")
        weights = learnables.Value{paramIdx};
        positiveWeights = weights(weights > 0);
        negativeWeights = weights(weights < 0);
        componentVars(end+1) = double(gather(extractdata(var(positiveWeights(:))))); %#ok<AGROW>
        componentVars(end+1) = double(gather(extractdata(var(negativeWeights(:))))); %#ok<AGROW>
    end
end
end

function varTerm = weightVarTermNumeric(net, layerPrefixes)
componentVars = collectWeightVarianceComponents(net.Learnables, layerPrefixes);
varTerm = geomean(componentVars);
end

function gradValues = varianceGradient(values, count)
gradValues = 2 * (values - mean(values, "all")) / (count - 1);
end

function tf = matchesPrefix(layerName, prefixes)
tf = false;
for idx = 1:numel(prefixes)
    if startsWith(layerName, prefixes(idx))
        tf = true;
        return
    end
end
end
