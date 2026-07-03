function RunSwappedAonly001Res3onlyVsBaseline()
% Swapped: TaskA = MNIST (vw=0.01 res3only), TaskB = CIFAR-10 (vw=0)
% Aonly mode: only A has variance, B is pure CE.
% Compare vs baseline (both vw=0).
dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr, ymTr] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inp = [32 32 3];  nc = 10;  mb = 128;  lr = 1e-3;
epA = 5;  sA = 600;  epB = 5;  sB = 500;
seed = 20260629;
layers = ["res3b_relu"];
gpuDevice(3);

% ---- Baseline: A(MNIST) vw=0, B(CIFAR) vw=0 ----
fprintf("=== Baseline: A(MNIST vw=0) -> B(CIFAR vw=0) ===\n");
rng(seed);
[XgA0, TgA0] = TransferLearning.PreUploadCifarToGpu(XmTr, ymTr, nc);
net0 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA0 = trainTaskSwapped(net0, XgA0, TgA0, XmVal, ymVal, inp, nc, epA, mb, lr, 0, layers, sA);
statsB0 = trainTaskSwapped(statsA0.netFinal, dataset.taskA.trainX, dataset.taskA.trainY, dataset.taskA.valX, dataset.taskA.valY, inp, nc, epB, mb, lr, 0, layers, sB);

% ---- Aonly: A(MNIST vw=0.01 res3only) -> B(CIFAR vw=0) ----
fprintf("\n=== Aonly: A(MNIST vw=0.01) -> B(CIFAR vw=0) ===\n");
rng(seed);
[XgA1, TgA1] = TransferLearning.PreUploadCifarToGpu(XmTr, ymTr, nc);
net1 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA1 = trainTaskSwapped(net1, XgA1, TgA1, XmVal, ymVal, inp, nc, epA, mb, lr, 0.01, layers, sA);
statsB1 = trainTaskSwapped(statsA1.netFinal, dataset.taskA.trainX, dataset.taskA.trainY, dataset.taskA.valX, dataset.taskA.valY, inp, nc, epB, mb, lr, 0, layers, sB);

% ---- Report ----
m30=mean(statsB0.valAccuracy(1:3)); m50=mean(statsB0.valAccuracy(1:5)); mA0=mean(statsB0.valAccuracy(1:end));
m31=mean(statsB1.valAccuracy(1:3)); m51=mean(statsB1.valAccuracy(1:5)); mA1=mean(statsB1.valAccuracy(1:end));
fprintf("\n=== TaskB (CIFAR-10) Results ===\n");
fprintf("%-40s  mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", "Baseline: A(MNIST vw=0) -> B(vw=0)", m30, m50, mA0);
fprintf("%-40s  mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", "Aonly: A(MNIST vw=0.01 res3) -> B(vw=0)", m31, m51, mA1);
fprintf("diff3=%+.4f  diff5=%+.4f  diffAll=%+.4f\n", m31-m30, m51-m50, mA1-mA0);

% ---- Plot ----
f = TransferLearning.PlotTrainingCurvesCompareVariance( ...
    statsB1, statsB0, ...
    "Aonly: MNIST(vw=0.01 res3)", "Baseline: MNIST(vw=0)", ...
    "Swapped: A(MNIST vw=0.01 res3only) \rightarrow B(CIFAR-10 vw=0)  vs  Baseline", epB);
TransferLearning.ExportStandardFigure(f, 2, "TaskB_Swapped_Aonly_vw001_res3only_vs_Baseline.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_Swapped_Aonly_vw001_res3only_vs_Baseline.svg"));
end

% -------------------------------------------------------------------------
function stats = trainTaskSwapped(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, lay, sEp)
% XTr, yTr: either pre-uploaded GPU 4D or CPU rows. XV, yV: CPU rows for validation.
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
    ord = randperm(nTr, sEp);
    epLoss = 0; epCE = 0; epVar = 0; nBatch = 0;
    for s = 1:mb:sEp
        e = min(s+mb-1,sEp); idx = ord(s:e); iter = iter+1;
        dlX = dlarray(single(XTr(:,:,:,idx))/255, "SSCB");
        dlT = dlarray(yTr(:,idx), "CB");
        [gr, lo, ce, vt] = dlfeval(@(n,x,t) lossFunSwapped(n,x,t,vw,lay), net, dlX, dlT);
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

function [gr, lo, ce, vt] = lossFunSwapped(net, dlX, dlT, vw, lay)
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
