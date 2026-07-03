function RunWeightVarVsBaseline()
% Compare amplified weight-variance regularization (geometric mean) vs baseline.
% Loss: L = CE / (1 + vw * geomean(var(Wpos), var(Wneg)) over res2b/res3b/res4b weights)
% TaskB uses full MNIST train pool, samples 1% (600 images) per epoch, full t10k validation.
% TaskA: CIFAR vw=0 vs vw=500 res2-4, TaskB: both vw=0.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTrain, ymTrain] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

cfg.inputSize = [32 32 3]; cfg.numClasses = 10; cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3; cfg.maxEpochsA = 100; cfg.maxEpochsB = 10;
cfg.samplesPerEpochA = 500; cfg.varWeightA = 500; cfg.varWeightB = 0;
cfg.samplesPerEpochB = 600;
cfg.weightLayerPrefixes = ["res2b", "res3b", "res4b"];  % layers whose weight variance is penalized

seeds = 20260711:20260720; nRepeats = numel(seeds);
gpuCount = gpuDeviceCount("available"); nWorkers = min(nRepeats, gpuCount);
fprintf("Weight-variance: %d seeds, %d GPUs, %d workers\n", nRepeats, gpuCount, nWorkers);

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
    task = getCurrentTask(); w = 1; if ~isempty(task), w = task.ID; end
    gpuIdx = mod(w-1, gpuCount) + 1; gpuDevice(gpuIdx);
    seed = seeds(ri);
    fprintf("[repeat %d/%d] seed=%d gpu=%d\n", ri, nRepeats, seed, gpuIdx);

    nc = cfg.numClasses;

    % ---- TaskA vw=0 (baseline) ----
    rng(seed);
    [XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
    net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
    [net0, varA0, accA0] = trainTaskAWeightVar(net0, XgA, TgA, dataset.taskA.valX, dataset.taskA.valY, cfg, 0);
    varA0Final(ri) = varA0(end); accA0Final(ri) = accA0(end);

    % ---- TaskA vw=0.5 (weight variance) ----
    rng(seed);
    [~, ~] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
    net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
    [net1, varA1, accA1] = trainTaskAWeightVar(net1, XgA, TgA, dataset.taskA.valX, dataset.taskA.valY, cfg, cfg.varWeightA);
    varA1Final(ri) = varA1(end); accA1Final(ri) = accA1(end);

    % ---- TaskB from both checkpoints (full MNIST pool, 1% per epoch, vw=0) ----
    [XgT, TgT] = TransferLearning.PreUploadCifarToGpu(XmTrain, ymTrain, nc);
    taskBOrders = makeTaskBOrders(size(XmTrain, 1), cfg.samplesPerEpochB, cfg.maxEpochsB, seed + 5000);
    [v0, a0] = trainTaskBWeightVar(net0, XgT, TgT, XmVal, ymVal, taskBOrders, cfg);
    [v1, a1] = trainTaskBWeightVar(net1, XgT, TgT, XmVal, ymVal, taskBOrders, cfg);

    accB0(ri, :) = a0; accB1(ri, :) = a1;
    varB0(ri, :) = v0; varB1(ri, :) = v1;
    fprintf("[repeat %d] ep3: B0=%.3f B1=%.3f diff=%+.3f | ep10: B0=%.3f B1=%.3f diff=%+.3f\n", ...
        ri, a0(3), a1(3), a1(3)-a0(3), a0(end), a1(end), a1(end)-a0(end));
end

fprintf("\n=== Weight-Variance Regularization: TaskB Accuracy (10 seeds) ===\n");
fprintf("%-8s %-8s %-8s %-8s %-8s\n", "Epoch", "B0_mean", "B1_mean", "Diff", "Pos");
for ep = 1:cfg.maxEpochsB
    d = accB1(:,ep) - accB0(:,ep);
    fprintf("%-8d %-8.4f %-8.4f %+8.4f  %d/%d\n", ep, mean(accB0(:,ep)), mean(accB1(:,ep)), mean(d), sum(d>0), nRepeats);
end

fprintf("\n=== TaskA Weight-Var ===\n");
fprintf("B0 final var=%.4f acc=%.4f\n", mean(varA0Final), mean(accA0Final));
fprintf("B1 final var=%.4f acc=%.4f\n", mean(varA1Final), mean(accA1Final));

% ---- Plot ----
figureHandle = figure("Position", [100 100 900 350]);
subplot(1,2,1);
mb0 = mean(accB0, 1); mb1 = mean(accB1, 1);
sb0 = std(accB0, 0, 1) / sqrt(nRepeats); sb1 = std(accB1, 0, 1) / sqrt(nRepeats);
epochs = 1:cfg.maxEpochsB;
errorbar(epochs, mb0*100, sb0*100, "b-o", "LineWidth",1.2,"MarkerSize",4); hold on;
errorbar(epochs, mb1*100, sb1*100, "r-s", "LineWidth",1.2,"MarkerSize",4);
xlabel("TaskB Epoch"); ylabel("Accuracy (%)");
title("Pos/Neg Weight-Var Geomean, Full MNIST 1%/epoch");
legend("A vw=0","A vw=500","Location","best"); grid on;

subplot(1,2,2);
md = mean(accB1 - accB0, 1) * 100;
sd = std(accB1 - accB0, 0, 1) / sqrt(nRepeats) * 100;
errorbar(epochs, md, sd, "k-o", "LineWidth",1.2,"MarkerSize",4); hold on;
yline(0, "k-");
xlabel("TaskB Epoch"); ylabel("Diff (pp)");
title("Weight-Var Advantage"); grid on;
sgtitle("Pos/Neg Weight-Variance Geomean (vw=500, full MNIST 1%/epoch)");

TransferLearning.ExportStandardFigure(figureHandle, 2, "TaskB_WeightVar_PosNegGeomean_FullMNIST_vw500_10seeds.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_WeightVar_PosNegGeomean_FullMNIST_vw500_10seeds.svg"));

outPath = fullfile(dataRoot, "models", "weight_var_posneg_geomean_fullmnist_vw500_10seeds.mat");
save(outPath, "accB0","accB1","varB0","varB1","varA0Final","varA1Final","accA0Final","accA1Final","cfg","seeds","-v7.3");
fprintf("Saved: %s\n", outPath);
end

% -------------------------------------------------------------------------
function [net, varLog, accLog] = trainTaskAWeightVar(net, Xg, Tg, XVal, yVal, cfg, varWeight)
nTr = size(Xg, 4); sEp = min(cfg.samplesPerEpochA, nTr);
[dlXv, dlTv] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
varLog = zeros(cfg.maxEpochsA, 1); accLog = zeros(cfg.maxEpochsA, 1);
ta=[]; tsq=[]; iter=0;
for ep = 1:cfg.maxEpochsA
    accLog(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXv, dlTv, cfg.miniBatchSize);
    ord = randperm(nTr, sEp);
    epVar = 0; nb = 0;
    for st = 1:cfg.miniBatchSize:sEp
        e = min(st+cfg.miniBatchSize-1, sEp); idx = ord(st:e); iter=iter+1;
        dlX = dlarray(single(Xg(:,:,:,idx))/255, "SSCB");
        dlT = dlarray(Tg(:, idx), "CB");
        [gr, ~, ~, vt] = dlfeval(@lossWeightVar, net, dlX, dlT, varWeight, cfg.weightLayerPrefixes);
        [net, ta, tsq] = adamupdate(net, gr, ta, tsq, iter, cfg.learnRate);
        epVar = epVar + double(extractdata(vt)); nb = nb + 1;
    end
    varLog(ep) = epVar / nb;
end
end

function orders = makeTaskBOrders(numTrain, samplesPerEpoch, maxEpochs, seed)
rng(seed);
orders = zeros(maxEpochs, samplesPerEpoch);
for epoch = 1:maxEpochs
    orders(epoch, :) = randperm(numTrain, samplesPerEpoch);
end
end

function [varVec, accVec] = trainTaskBWeightVar(net, XgTr, TgTr, XVal, yVal, taskBOrders, cfg)
[dlXv, dlTv] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
varVec = zeros(1, cfg.maxEpochsB); accVec = zeros(1, cfg.maxEpochsB);
ta=[]; tsq=[]; iter=0;
for ep = 1:cfg.maxEpochsB
    accVec(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXv, dlTv, cfg.miniBatchSize);
    ord = taskBOrders(ep, :);
    epVar = 0; nb = 0;
    for st = 1:cfg.miniBatchSize:numel(ord)
        e = min(st+cfg.miniBatchSize-1, numel(ord)); idx = ord(st:e); iter=iter+1;
        dlX = dlarray(single(XgTr(:,:,:,idx))/255, "SSCB");
        dlT = dlarray(TgTr(:, idx), "CB");
        [gr, ~, ~, vt] = dlfeval(@lossWeightVar, net, dlX, dlT, cfg.varWeightB, cfg.weightLayerPrefixes);
        [net, ta, tsq] = adamupdate(net, gr, ta, tsq, iter, cfg.learnRate);
        epVar = epVar + double(extractdata(vt)); nb = nb + 1;
    end
    varVec(ep) = epVar / nb;
end
end

function [gradients, loss, ceLoss, varTerm] = lossWeightVar(net, dlX, dlT, varWeight, layerPrefixes)
logits = forward(net, dlX, Outputs="fc_logits");
probabilities = softmax(logits);
ceLoss = crossentropy(probabilities, dlT, TargetCategories="independent");

% Compute variance of weight matrices for specified layers
learnables = net.Learnables;
allVars = [];
for layerIdx = 1:numel(layerPrefixes)
    prefix = layerPrefixes(layerIdx);
    % Find all parameter rows matching this layer prefix and ending with "Weights"
    for paramIdx = 1:height(learnables)
        paramLayer = string(learnables.Layer(paramIdx));
        paramName  = string(learnables.Parameter(paramIdx));
        if startsWith(paramLayer, prefix) && endsWith(paramName, "Weights")
            W = learnables.Value{paramIdx};
            positiveWeights = W(W > 0);
            negativeWeights = W(W < 0);
            allVars(end+1) = var(positiveWeights(:)); %#ok<AGROW>
            allVars(end+1) = var(negativeWeights(:)); %#ok<AGROW>
        end
    end
end
varTerm = geomean(allVars);

loss = ceLoss / (1 + varWeight * varTerm);
gradients = dlgradient(loss, net.Learnables);
end
