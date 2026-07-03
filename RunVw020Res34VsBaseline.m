function RunVw020Res34VsBaseline()
% AB-consistent: vw=0.20, res3-4 vs vw=0 baseline.
% Generates comparison plot with per-epoch stats.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr, ymTr] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inp = [32 32 3];  nc = 10;  mb = 128;  lr = 1e-3;
epA = 5;  sA = 500;  epB = 5;  sB = 600;
seed = 20260626;

gpuDevice(3);

% ---- Config ----
layersRes34 = ["res3b_relu", "res4b_relu"];

% ---- Run baseline: vw=0 ----
fprintf("=== Baseline vw=0 ===\n");
rng(seed);
[XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
net0 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA0 = trainTaskWithStats(net0, XgA, TgA, [], [], inp, nc, epA, mb, lr, 0, layersRes34, sA);
statsB0 = trainTaskWithStats(statsA0.netFinal, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, 0, layersRes34, sB);

% ---- Run test: vw=0.20, res3-4 ----
fprintf("\n=== vw=0.20, res3-4 ===\n");
rng(seed);
[XgA2, TgA2] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
net20 = TransferLearning.BuildResNet18Classifier(inp, nc);
statsA20 = trainTaskWithStats(net20, XgA2, TgA2, [], [], inp, nc, epA, mb, lr, 0.20, layersRes34, sA);
statsB20 = trainTaskWithStats(statsA20.netFinal, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, 0.20, layersRes34, sB);

% ---- Report numbers ----
m30  = mean(statsB0.valAccuracy(1:3));  m50  = mean(statsB0.valAccuracy(1:5));  mA0  = mean(statsB0.valAccuracy(1:end));
m320 = mean(statsB20.valAccuracy(1:3)); m520 = mean(statsB20.valAccuracy(1:5)); mA20 = mean(statsB20.valAccuracy(1:end));
fprintf("\n=== Results ===\n");
fprintf("%-20s  meanAcc3=%.4f  meanAcc5=%.4f  meanAccAll=%.4f\n", "Baseline vw=0", m30, m50, mA0);
fprintf("%-20s  meanAcc3=%.4f  meanAcc5=%.4f  meanAccAll=%.4f\n", "vw=0.20 res3-4", m320, m520, mA20);
fprintf("diff3=%+.4f  diff5=%+.4f  diffAll=%+.4f\n", m320-m30, m520-m50, mA20-mA0);

% ---- Plot ----
f = TransferLearning.PlotTrainingCurvesCompareVariance( ...
    statsB20, statsB0, ...
    "AB vw=0.20 res3-4", "AB vw=0", ...
    "AB-Consistent: vw=0.20 res3-4 vs Baseline (vw=0)", 5);
TransferLearning.ExportStandardFigure(f, 2, "TaskB_AB_vw020_res34_vs_Baseline.svg");
fprintf("\nSVG: %s\n", TransferLearning.StandardFigureSvgPath("TaskB_AB_vw020_res34_vs_Baseline.svg"));
end

% -------------------------------------------------------------------------
function stats = trainTaskWithStats(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, lay, sEp)
% Train for maxEp epochs, collecting per-epoch stats including loss/variance.
% XTr: either pre-uploaded GPU 4-D array or CPU rows (N×3072). yTr: one-hot GPU or CPU labels.
% XV, yV: optional validation data (CPU rows); if empty, skip validation.

% Detect data format: 4-D = pre-uploaded GPU, 2-D = CPU rows (N×3072)
if ndims(XTr) == 4
    nTr = size(XTr, 4);
else
    nTr = size(XTr, 1);
    [XTr, yTr] = TransferLearning.PreUploadCifarToGpu(XTr, yTr, nc);
end
sEp = min(sEp, nTr);

% Preprocess validation data (if provided)
doVal = ~isempty(XV);
if doVal
    [dlXV, dlTV] = TransferLearning.PreprocessCifarRows(XV, yV, inSz, nc);
end

stats = struct();
stats.trainLoss   = zeros(maxEp, 1);
stats.trainCE     = zeros(maxEp, 1);
stats.trainVar    = zeros(maxEp, 1);
stats.valAccuracy = zeros(maxEp, 1);

ta = [];  tsq = [];  iter = 0;

for ep = 1:maxEp
    % Validate at start of epoch
    if doVal
        stats.valAccuracy(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
    end

    % Train
    ord = randperm(nTr, sEp);
    epLoss = 0;  epCE = 0;  epVar = 0;  nBatch = 0;
    for s = 1:mb:sEp
        e = min(s + mb - 1, sEp);  idx = ord(s:e);  iter = iter + 1;
        dlX = dlarray(single(XTr(:,:,:,idx)) / 255, "SSCB");
        dlT = dlarray(yTr(:,idx), "CB");
        [gr, lo, ce, vt] = dlfeval(@(n,x,t) lossFunAB(n,x,t,vw,lay), net, dlX, dlT);
        [net, ta, tsq] = adamupdate(net, gr, ta, tsq, iter, lr);
        epLoss = epLoss + double(extractdata(lo));
        epCE   = epCE   + double(extractdata(ce));
        epVar  = epVar  + double(extractdata(vt));
        nBatch = nBatch + 1;
    end
    stats.trainLoss(ep) = epLoss / nBatch;
    stats.trainCE(ep)   = epCE   / nBatch;
    stats.trainVar(ep)  = epVar  / nBatch;
end

% Final validation
if doVal
    stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
else
    stats.finalValAccuracy = NaN;
end
stats.netFinal = net;
end

% -------------------------------------------------------------------------
function [gr, lo, ce, vt] = lossFunAB(net, dlX, dlT, vw, lay)
outputs = ["fc_logits", lay];
C = cell(1, numel(lay));
[logits, C{:}] = forward(net, dlX, Outputs=outputs);
p = softmax(logits);
ceLoss = crossentropy(p, dlT, TargetCategories="independent");
vv = zeros(1, numel(lay), "like", C{1});
for i = 1:numel(lay)
    f = reshape(stripdims(C{i}), [], size(C{i}, 4));
    vv(i) = mean(var(f, 0, 2), "all");
end
vt = mean(vv, "all");
lo = ceLoss / (1 + vw * vt);
gr = dlgradient(lo, net.Learnables);
ce = ceLoss;
end
