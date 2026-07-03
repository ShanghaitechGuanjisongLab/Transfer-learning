function RunSmallSampleAonlyVsBaseline()
% Small-sample TaskB: MNIST 30 train/class, 10 val/class (300 train, 100 val total).
% Same fixed subset every epoch. TaskA: CIFAR-10 unchanged.
% Compare Aonly (A vw=0.01 res3only, B vw=0) vs baseline (both vw=0).

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();

% Load full MNIST
[XmTrFull, ymTrFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmValFull, ymValFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

% ---- Select fixed small subsets ----
rng(20260629);
nc = 10;
nTrainPerClass = 30;
nValPerClass = 10;

% Build train subset
XmTrSmall = zeros(nTrainPerClass * nc, size(XmTrFull, 2), "uint8");
ymTrSmall = zeros(nTrainPerClass * nc, 1, "uint8");
for c = 1:nc
    classIdx = find(ymTrFull == c);
    chosen = classIdx(randperm(numel(classIdx), nTrainPerClass));
    XmTrSmall((c-1)*nTrainPerClass+1 : c*nTrainPerClass, :) = XmTrFull(chosen, :);
    ymTrSmall((c-1)*nTrainPerClass+1 : c*nTrainPerClass) = c;
end

% Build val subset
XmValSmall = zeros(nValPerClass * nc, size(XmValFull, 2), "uint8");
ymValSmall = zeros(nValPerClass * nc, 1, "uint8");
for c = 1:nc
    classIdx = find(ymValFull == c);
    chosen = classIdx(randperm(numel(classIdx), nValPerClass));
    XmValSmall((c-1)*nValPerClass+1 : c*nValPerClass, :) = XmValFull(chosen, :);
    ymValSmall((c-1)*nValPerClass+1 : c*nValPerClass) = c;
end
fprintf("Train subset: %d samples, Val subset: %d samples\n", size(XmTrSmall,1), size(XmValSmall,1));

% ---- Config ----
inp = [32 32 3];  mb = 128;  lr = 1e-3;
epA = 5;  sA = 500;
epB = 5;  % use all 300 training images, no subsampling needed since dataset is small
layers = ["res3b_relu"];
seed = 20260629;
gpuDevice(3);

dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);

% ---- Baseline: A(CIFAR vw=0) -> B(MNIST small vw=0) ----
fprintf("\n=== Baseline: A(CIFAR vw=0) -> B(MNIST-small vw=0) ===\n");
rng(seed);
[XgA0, TgA0] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
net0 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA0 = trainTaskSmall(net0, XgA0, TgA0, [], [], inp, nc, epA, mb, lr, 0, layers, sA, false);
statsB0 = trainTaskSmall(statsA0.netFinal, XmTrSmall, ymTrSmall, XmValSmall, ymValSmall, inp, nc, epB, mb, lr, 0, layers, size(XmTrSmall,1), true);

% ---- Aonly: A(CIFAR vw=0.01) -> B(MNIST-small vw=0) ----
fprintf("\n=== Aonly: A(CIFAR vw=0.01 res3) -> B(MNIST-small vw=0) ===\n");
rng(seed);
[XgA1, TgA1] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
net1 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA1 = trainTaskSmall(net1, XgA1, TgA1, [], [], inp, nc, epA, mb, lr, 0.01, layers, sA, false);
statsB1 = trainTaskSmall(statsA1.netFinal, XmTrSmall, ymTrSmall, XmValSmall, ymValSmall, inp, nc, epB, mb, lr, 0, layers, size(XmTrSmall,1), true);

% ---- Report ----
m30=mean(statsB0.valAccuracy(1:3)); m50=mean(statsB0.valAccuracy(1:5)); mA0=mean(statsB0.valAccuracy(1:end));
m31=mean(statsB1.valAccuracy(1:3)); m51=mean(statsB1.valAccuracy(1:5)); mA1=mean(statsB1.valAccuracy(1:end));
fprintf("\n=== TaskB (MNIST 300/100 small) Results ===\n");
fprintf("%-40s  mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", "Baseline: A(CIFAR vw=0) -> B(vw=0)", m30, m50, mA0);
fprintf("%-40s  mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", "Aonly: A(CIFAR vw=0.01 res3) -> B(vw=0)", m31, m51, mA1);
fprintf("diff3=%+.4f  diff5=%+.4f  diffAll=%+.4f\n", m31-m30, m51-m50, mA1-mA0);

% Print per-epoch comparison
fprintf("\nPer-epoch accuracy:\n");
fprintf("Epoch    Baseline    Aonly       Diff\n");
for ep = 1:epB
    fprintf("%d        %.4f      %.4f      %+.4f\n", ep, statsB0.valAccuracy(ep), statsB1.valAccuracy(ep), statsB1.valAccuracy(ep)-statsB0.valAccuracy(ep));
end

% ---- Plot ----
f = TransferLearning.PlotTrainingCurvesCompareVariance( ...
    statsB1, statsB0, ...
    "Aonly: CIFAR(vw=0.01 res3)", "Baseline: CIFAR(vw=0)", ...
    "Small-Sample: A(CIFAR vw=0.01 res3only) \rightarrow B(MNIST 300/100 vw=0)  vs  Baseline", epB);
TransferLearning.ExportStandardFigure(f, 2, "TaskB_SmallSample_Aonly_vw001_res3only_vs_Baseline.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_SmallSample_Aonly_vw001_res3only_vs_Baseline.svg"));
end

% -------------------------------------------------------------------------
function stats = trainTaskSmall(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, lay, sEp, useAllData)
% useAllData=true: train on all available data without subsampling (fixed subset mode)
% useAllData=false: random subsample sEp per epoch (standard mode)

if ndims(XTr) == 4
    nTr = size(XTr, 4);
else
    nTr = size(XTr, 1);
    [XTr, yTr] = TransferLearning.PreUploadCifarToGpu(XTr, yTr, nc);
end
sEp = min(sEp, nTr);

doVal = ~isempty(XV);
if doVal
    [dlXV, dlTV] = TransferLearning.PreprocessCifarRows(XV, yV, inSz, nc);
end
stats = struct();
stats.trainLoss = zeros(maxEp,1); stats.trainCE = zeros(maxEp,1);
stats.trainVar = zeros(maxEp,1); stats.valAccuracy = zeros(maxEp,1);
ta = []; tsq = []; iter = 0;

for ep = 1:maxEp
    if doVal
        stats.valAccuracy(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
    end

    if useAllData
        % Fixed order every epoch (use all, no random subsample)
        ord = 1:nTr;
        nThisEp = nTr;
    else
        ord = randperm(nTr, sEp);
        nThisEp = sEp;
    end

    epLoss = 0; epCE = 0; epVar = 0; nBatch = 0;
    for s = 1:mb:nThisEp
        e = min(s+mb-1, nThisEp); idx = ord(s:e); iter = iter+1;
        dlX = dlarray(single(XTr(:,:,:,idx))/255, "SSCB");
        dlT = dlarray(yTr(:,idx), "CB");
        [gr, lo, ce, vt] = dlfeval(@(n,x,t) lossFunSmall(n,x,t,vw,lay), net, dlX, dlT);
        [net, ta, tsq] = adamupdate(net, gr, ta, tsq, iter, lr);
        epLoss = epLoss + double(extractdata(lo));
        epCE = epCE + double(extractdata(ce));
        epVar = epVar + double(extractdata(vt));
        nBatch = nBatch + 1;
    end
    stats.trainLoss(ep) = epLoss/nBatch;
    stats.trainCE(ep) = epCE/nBatch;
    stats.trainVar(ep) = epVar/nBatch;
end
if doVal
    stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
else
    stats.finalValAccuracy = NaN;
end
stats.netFinal = net;
end

function [gr, lo, ce, vt] = lossFunSmall(net, dlX, dlT, vw, lay)
outputs = ["fc_logits", lay];
C = cell(1, numel(lay));
[logits, C{:}] = forward(net, dlX, Outputs=outputs);
p = softmax(logits);
ceLoss = crossentropy(p, dlT, TargetCategories="independent");
vv = zeros(1, numel(lay), "like", C{1});
for i = 1:numel(lay)
    f = reshape(stripdims(C{i}), [], size(C{i},4));
    vv(i) = mean(var(f,0,2), "all");
end
vt = mean(vv, "all");
lo = ceLoss / (1 + vw*vt);
gr = dlgradient(lo, net.Learnables);
ce = ceLoss;
end
