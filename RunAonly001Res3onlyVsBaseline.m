function RunAonly001Res3onlyVsBaseline()
% Aonly: TaskA vw=0.01 res3only, TaskB vw=0  vs  Baseline: both vw=0
dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr, ymTr] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inp = [32 32 3];  nc = 10;  mb = 128;  lr = 1e-3;
epA = 5;  sA = 500;  epB = 5;  sB = 600;
seed = 20260626;
layers = ["res3b_relu"];
gpuDevice(3);

% ---- Baseline: A vw=0, B vw=0 ----
fprintf("=== Baseline (AB vw=0) ===\n");
rng(seed);
[XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
net0 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA0 = trainTask(net0, XgA, TgA, [], [], inp, nc, epA, mb, lr, 0, layers, sA);
statsB0 = trainTask(statsA0.netFinal, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, 0, layers, sB);

% ---- Aonly: A vw=0.01 res3only, B vw=0 ----
fprintf("\n=== Aonly (A vw=0.01 res3only, B vw=0) ===\n");
rng(seed);
[XgA2, TgA2] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
net1 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA1 = trainTask(net1, XgA2, TgA2, [], [], inp, nc, epA, mb, lr, 0.01, layers, sA);
statsB1 = trainTask(statsA1.netFinal, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, 0, layers, sB);

% ---- Report ----
m30=mean(statsB0.valAccuracy(1:3)); m50=mean(statsB0.valAccuracy(1:5)); mA0=mean(statsB0.valAccuracy(1:end));
m31=mean(statsB1.valAccuracy(1:3)); m51=mean(statsB1.valAccuracy(1:5)); mA1=mean(statsB1.valAccuracy(1:end));
fprintf("\n=== Results ===\n");
fprintf("%-30s  mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", "Baseline (AB vw=0)", m30, m50, mA0);
fprintf("%-30s  mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", "Aonly vw=0.01 res3only", m31, m51, mA1);
fprintf("diff3=%+.4f  diff5=%+.4f  diffAll=%+.4f\n", m31-m30, m51-m50, mA1-mA0);

% ---- Plot ----
f = TransferLearning.PlotTrainingCurvesCompareVariance( ...
    statsB1, statsB0, ...
    "Aonly vw=0.01 res3only", "Baseline (AB vw=0)", ...
    "Aonly: A(vw=0.01 res3only) \rightarrow B(vw=0)  vs  Baseline (AB vw=0)", 5);
TransferLearning.ExportStandardFigure(f, 2, "TaskB_Aonly_vw001_res3only_vs_Baseline.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_Aonly_vw001_res3only_vs_Baseline.svg"));
end

% -------------------------------------------------------------------------
function stats = trainTask(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, lay, sEp)
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
        [gr, lo, ce, vt] = dlfeval(@(n,x,t) lossFun(n,x,t,vw,lay), net, dlX, dlT);
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

function [gr, lo, ce, vt] = lossFun(net, dlX, dlT, vw, lay)
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
