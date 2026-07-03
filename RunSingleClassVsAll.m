function RunSingleClassVsAll()
% TaskB: MNIST 30 samples from ONE class only (class 0).
% Validation: all 10 classes, 10/class = 100 total. Class-sorted, batch=128.
% TaskA: CIFAR vw=0 vs vw=0.5 res2-4 (100ep).
% 5 seeds parallel.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmFull, ymFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);

cfg.inputSize = [32 32 3]; cfg.numClasses = 10; cfg.learnRate = 1e-3;
cfg.maxEpochsA = 100; cfg.maxEpochsB = 10;
cfg.samplesPerEpochA = 500; cfg.varWeightA = 0.5; cfg.varWeightB = 0;
cfg.miniBatchSize = 128;  % for TaskA
cfg.taskBBatchSize = 128; % for TaskB
cfg.layers = ["res2b_relu","res3b_relu","res4b_relu"];
cfg.nTrainSamples = 30;   % total training samples from class 0
cfg.nValPerClass = 10;
cfg.trainClass = 0;       % only digit 0 for training

seeds = 20260701:20260705; nRepeats = numel(seeds);
gpuCount = gpuDeviceCount("available"); nWorkers = min(nRepeats, gpuCount);
fprintf("Single-class test: train only digit %d, %d samples, val all 10 classes\n", cfg.trainClass, cfg.nTrainSamples);
fprintf("%d seeds, %d GPUs\n", nRepeats, gpuCount);

pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= nWorkers, delete(pool); end
if isempty(pool), parpool("Processes", nWorkers); end

accB0 = zeros(nRepeats, cfg.maxEpochsB);
accB1 = zeros(nRepeats, cfg.maxEpochsB);

parfor ri = 1:nRepeats
    task = getCurrentTask(); w = 1; if ~isempty(task), w = task.ID; end
    gpuIdx = mod(w-1, gpuCount) + 1; gpuDevice(gpuIdx);
    seed = seeds(ri);
    fprintf("[repeat %d] seed=%d gpu=%d\n", ri, seed, gpuIdx);

    rng(seed);
    nc = cfg.numClasses;
    % Training set: only class 0
    class0Idx = find(ymFull == cfg.trainClass + 1);  % MATLAB 1-indexed
    class0Idx = class0Idx(randperm(numel(class0Idx)));
    nTrain = cfg.nTrainSamples;
    XTr = XmFull(class0Idx(1:nTrain), :);
    yTr = ones(nTrain, 1, "uint8");  % all class 0+1 = 1

    % Validation set: 10/class from all classes
    XVal = zeros(cfg.nValPerClass * nc, size(XmFull, 2), "uint8");
    yVal = zeros(cfg.nValPerClass * nc, 1, "uint8");
    for c = 1:nc
        rows = find(ymFull == c);
        rows = rows(randperm(numel(rows)));
        chosen = rows(1:cfg.nValPerClass);
        XVal((c-1)*cfg.nValPerClass+1 : c*cfg.nValPerClass, :) = XmFull(chosen, :);
        yVal((c-1)*cfg.nValPerClass+1 : c*cfg.nValPerClass) = c;
    end
    % Shuffle validation
    valOrd = randperm(size(XVal, 1));
    XVal = XVal(valOrd, :); yVal = yVal(valOrd);

    [XgTr, TgTr] = TransferLearning.PreUploadCifarToGpu(XTr, yTr, nc);
    nTrTotal = size(XTr, 1);

    mb = cfg.taskBBatchSize;

    % TaskA vw=0
    rng(seed);
    [XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
    net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
    net0 = trainTaskA(net0, XgA, TgA, cfg, 0);
    [~, a0] = trainTaskB(net0, XgTr, TgTr, XVal, yVal, cfg, mb);

    % TaskA vw=0.5
    rng(seed);
    [~, ~] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
    net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
    net1 = trainTaskA(net1, XgA, TgA, cfg, cfg.varWeightA);
    [~, a1] = trainTaskB(net1, XgTr, TgTr, XVal, yVal, cfg, mb);

    accB0(ri, :) = a0;
    accB1(ri, :) = a1;
    fprintf("[repeat %d] ep3: B0=%.3f B1=%.3f diff=%+.3f  |  ep10: B0=%.3f B1=%.3f diff=%+.3f\n", ...
        ri, a0(3), a1(3), a1(3)-a0(3), a0(end), a1(end), a1(end)-a0(end));
end

fprintf("\n=== Single-Class (digit %d) TaskB Accuracy ===\n", cfg.trainClass);
for ep = 1:cfg.maxEpochsB
    d = accB1(:, ep) - accB0(:, ep);
    epStr = sprintf("epoch %2d", ep);
    fprintf("%s: B0=%.3f B1=%.3f diff=%+.3f pos=%d/%d\n", epStr, mean(accB0(:,ep)), mean(accB1(:,ep)), mean(d), sum(d>0), nRepeats);
end

% Plot
figureHandle = figure("Position", [100 100 900 350]);
subplot(1,2,1);
meanB0 = mean(accB0, 1); meanB1 = mean(accB1, 1);
semB0 = std(accB0, 0, 1) / sqrt(nRepeats);
semB1 = std(accB1, 0, 1) / sqrt(nRepeats);
epochs = 1:cfg.maxEpochsB;
errorbar(epochs, meanB0*100, semB0*100, "b-o", "LineWidth",1.2,"MarkerSize",4); hold on;
errorbar(epochs, meanB1*100, semB1*100, "r-s", "LineWidth",1.2,"MarkerSize",4);
xlabel("TaskB Epoch"); ylabel("Accuracy (%)");
title(sprintf("Single-Class Training (digit %d only)", cfg.trainClass));
legend("A vw=0","A vw=0.5","Location","best"); grid on;

subplot(1,2,2);
diff = accB1 - accB0;
meanDiff = mean(diff, 1) * 100;
semDiff = std(diff, 0, 1) / sqrt(nRepeats) * 100;
errorbar(epochs, meanDiff, semDiff, "k-o", "LineWidth",1.2,"MarkerSize",4); hold on;
yline(0, "k-");
xlabel("TaskB Epoch"); ylabel("Variance Advantage (pp)");
title("A-var advantage"); grid on;
sgtitle(sprintf("Variance Regularization on Single-Class TaskB (digit %d)", cfg.trainClass));

TransferLearning.ExportStandardFigure(figureHandle, 2, "TaskB_SingleClass_AvarAdvantage.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_SingleClass_AvarAdvantage.svg"));

outPath = fullfile(dataRoot, "models", "single_class_result.mat");
save(outPath, "accB0", "accB1", "cfg", "seeds", "-v7.3");
fprintf("Saved: %s\n", outPath);
end

function net = trainTaskA(net, Xg, Tg, cfg, varWeight)
nTr = size(Xg, 4); sEp = min(cfg.samplesPerEpochA, nTr);
ta=[]; tsq=[]; iter=0;
for ep = 1:cfg.maxEpochsA
    ord = randperm(nTr, sEp);
    for st = 1:cfg.miniBatchSize:sEp
        e = min(st+cfg.miniBatchSize-1, sEp); idx = ord(st:e); iter=iter+1;
        dlX = dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT = dlarray(Tg(:,idx),"CB");
        [gr,~,~,~] = dlfeval(@lossFn, net, dlX, dlT, varWeight, cfg.layers);
        [net, ta, tsq] = adamupdate(net, gr, ta, tsq, iter, cfg.learnRate);
    end
end
end

function [varVec, accVec] = trainTaskB(net, XgTr, TgTr, XVal, yVal, cfg, mb)
[dlXv, dlTv] = TransferLearning.PreprocessCifarRows(XVal, yVal, cfg.inputSize, cfg.numClasses);
varVec = zeros(1, cfg.maxEpochsB); accVec = zeros(1, cfg.maxEpochsB);
ta=[]; tsq=[]; iter=0; nTr = size(XgTr, 4);
for ep = 1:cfg.maxEpochsB
    accVec(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXv, dlTv, mb);
    ord = 1:nTr;
    for st = 1:mb:nTr
        e = min(st+mb-1, nTr); idx = ord(st:e); iter=iter+1;
        dlX = dlarray(single(XgTr(:,:,:,idx))/255, "SSCB");
        dlT = dlarray(TgTr(:, idx), "CB");
        [gr, ~, ~, vt] = dlfeval(@lossFn, net, dlX, dlT, cfg.varWeightB, cfg.layers);
        [net, ta, tsq] = adamupdate(net, gr, ta, tsq, iter, cfg.learnRate);
    end
end
end

function [gr, lo, ce, vt] = lossFn(net, dlX, dlT, vw, lay)
outputs = ["fc_logits", lay]; C = cell(1, numel(lay));
[logits, C{:}] = forward(net, dlX, Outputs=outputs);
p = softmax(logits); ce = crossentropy(p, dlT, TargetCategories="independent");
vv = zeros(1, numel(lay), "like", C{1});
for i = 1:numel(lay), f = reshape(stripdims(C{i}), [], size(C{i}, 4)); vv(i) = mean(var(f, 0, 2), "all"); end
vt = mean(vv, "all"); lo = ce / (1 + vw * vt); gr = dlgradient(lo, net.Learnables);
end
