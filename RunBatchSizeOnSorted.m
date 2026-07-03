function RunBatchSizeOnSorted()
% Class-sorted 30/class MNIST, vary batch size.
% TaskA: CIFAR vw=0 vs vw=0.5 res2-4.
% TaskB: MNIST 30/class, class-sorted, B vw=0.
% Batch sizes: 16, 32, 64, 128, 256, 300 (full).
% 5 seeds parallel.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmFull, ymFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);

cfg.inputSize = [32 32 3]; cfg.numClasses = 10; cfg.learnRate = 1e-3;
cfg.maxEpochsA = 100; cfg.maxEpochsB = 5;
cfg.samplesPerEpochA = 500; cfg.varWeightA = 0.5; cfg.varWeightB = 0;
cfg.miniBatchSize = 128;  % for TaskA training only
cfg.layers = ["res2b_relu","res3b_relu","res4b_relu"];
cfg.nTrainPerClass = 30; cfg.nValPerClass = 10;
batchSizes = [16, 32, 64, 128, 256, 300];

seeds = 20260671:20260675; nRepeats = numel(seeds);
nBS = numel(batchSizes);
gpuCount = gpuDeviceCount("available"); nWorkers = min(nRepeats, gpuCount);
fprintf("Batch-size sweep: %d sizes, %d seeds, %d GPUs\n", nBS, nRepeats, gpuCount);

pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= nWorkers, delete(pool); end
if isempty(pool), parpool("Processes", nWorkers); end

meanAccB0 = zeros(nRepeats, nBS, cfg.maxEpochsB);
meanAccB1 = zeros(nRepeats, nBS, cfg.maxEpochsB);

parfor ri = 1:nRepeats
    task = getCurrentTask(); w = 1; if ~isempty(task), w = task.ID; end
    gpuIdx = mod(w-1, gpuCount) + 1; gpuDevice(gpuIdx);
    seed = seeds(ri);
    fprintf("[repeat %d] seed=%d gpu=%d\n", ri, seed, gpuIdx);

    % Build class-sorted subset
    rng(seed);
    nc = cfg.numClasses; nTr = cfg.nTrainPerClass; nVal = cfg.nValPerClass;
    XTr = zeros(nTr*nc, size(XmFull,2), "uint8"); yTr = zeros(nTr*nc, 1, "uint8");
    XVl = zeros(nVal*nc, size(XmFull,2), "uint8"); yVl = zeros(nVal*nc, 1, "uint8");
    for c = 1:nc
        rows = find(ymFull == c); rows = rows(randperm(numel(rows)));
        XTr((c-1)*nTr+1:c*nTr,:) = XmFull(rows(1:nTr),:);
        yTr((c-1)*nTr+1:c*nTr) = c;
        XVl((c-1)*nVal+1:c*nVal,:) = XmFull(rows(nTr+1:nTr+nVal),:);
        yVl((c-1)*nVal+1:c*nVal) = c;
    end
    [XgTr, TgTr] = TransferLearning.PreUploadCifarToGpu(XTr, yTr, nc);
    nTrTotal = size(XTr, 1);

    % Train TaskA checkpoints fresh for each batch size (avoids in-place reuse)
    for bi = 1:nBS
        mb = batchSizes(bi);
        rng(seed);
        [XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
        net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
        net0 = trainA(net0, XgA, TgA, cfg, 0);
        rng(seed);
        [~, ~] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
        net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
        net1 = trainA(net1, XgA, TgA, cfg, cfg.varWeightA);
        [acc0, acc1] = trainBbatchSize(net0, net1, XgTr, TgTr, XVl, yVl, cfg, 0, mb);
        meanAccB0(ri, bi, :) = acc0;
        meanAccB1(ri, bi, :) = acc1;
    end
    fprintf("[repeat %d] done batch-size sweep\n", ri);
end

fprintf("\n=== Batch-size × Variance Effect (class-sorted 30/class) ===\n");
fprintf("batch  B0_ep3  B1_ep3  VarAdv   |  B0_ep5  B1_ep5  VarAdv  |  pos3  pos5\n");
for bi = 1:nBS
    ep3d = meanAccB1(:, bi, 3) - meanAccB0(:, bi, 3);
    ep5d = meanAccB1(:, bi, 5) - meanAccB0(:, bi, 5);
    fprintf("%4d  %.3f  %.3f  %+.3f  |  %.3f  %.3f  %+.3f  |  %d/%d   %d/%d\n", ...
        batchSizes(bi), mean(meanAccB0(:, bi, 3)), mean(meanAccB1(:, bi, 3)), mean(ep3d), ...
        mean(meanAccB0(:, bi, 5)), mean(meanAccB1(:, bi, 5)), mean(ep5d), ...
        sum(ep3d>0), nRepeats, sum(ep5d>0), nRepeats);
end

% Plot
figureHandle = figure("Position", [100 100 1000 400]);
subplot(1,2,1);
for bi = 1:nBS
    ep3d = squeeze(meanAccB1(:, bi, 3) - meanAccB0(:, bi, 3));
    errorbar(batchSizes(bi), mean(ep3d)*100, std(ep3d)/sqrt(nRepeats)*100, "ko-", "LineWidth",1.2,"MarkerSize",8); hold on;
end
yline(0,"k-"); xlabel("Batch Size"); ylabel("Epoch 3 Diff (pp)");
title("Class-Sorted: Variance Effect by Batch Size"); grid on;

subplot(1,2,2);
for bi = 1:nBS
    m0 = squeeze(mean(meanAccB0(:, bi, :), 1)); m1 = squeeze(mean(meanAccB1(:, bi, :), 1));
    plot(1:cfg.maxEpochsB, (m1-m0)*100, "o-", "LineWidth",1.2,"MarkerSize",4, "DisplayName", sprintf("mb=%d", batchSizes(bi))); hold on;
end
yline(0,"k-"); xlabel("Epoch"); ylabel("Variance Advantage (pp)");
title("Learning Curve Difference by Batch Size");
legend("Location","best"); grid on;
sgtitle("Batch Size × Variance Regularization (Class-Sorted 30/class MNIST)");

TransferLearning.ExportStandardFigure(figureHandle, 2, "TaskB_BatchSizeOnSorted_VarianceEffect.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_BatchSizeOnSorted_VarianceEffect.svg"));
end

function net = trainA(net, Xg, Tg, cfg, varWeight)
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

function [acc0, acc1] = trainBbatchSize(net0, net1, XgTr, TgTr, XVl, yVl, cfg, varWeightB, mb)
[dlXv, dlTv] = TransferLearning.PreprocessCifarRows(XVl, yVl, cfg.inputSize, cfg.numClasses);
acc0 = zeros(1, cfg.maxEpochsB); acc1 = zeros(1, cfg.maxEpochsB);
ta0=[]; tsq0=[]; iter0=0; ta1=[]; tsq1=[]; iter1=0;
nTr = size(XgTr, 4);
for ep = 1:cfg.maxEpochsB
    acc0(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net0, dlXv, dlTv, mb);
    acc1(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net1, dlXv, dlTv, mb);
    ord = 1:nTr; % class-sorted
    for st = 1:mb:nTr
        e = min(st+mb-1, nTr); idx = ord(st:e); %#ok<PFBNS>
        dlX = dlarray(single(XgTr(:,:,:,idx))/255, "SSCB");
        dlT = dlarray(TgTr(:, idx), "CB");
        iter0=iter0+1; iter1=iter1+1;
        [gr0, ~, ~, ~] = dlfeval(@lossFn, net0, dlX, dlT, varWeightB, cfg.layers);
        [gr1, ~, ~, ~] = dlfeval(@lossFn, net1, dlX, dlT, varWeightB, cfg.layers);
        [net0, ta0, tsq0] = adamupdate(net0, gr0, ta0, tsq0, iter0, cfg.learnRate);
        [net1, ta1, tsq1] = adamupdate(net1, gr1, ta1, tsq1, iter1, cfg.learnRate);
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
