function CleanSweepABConsistent()
% AB-consistent variance sweep with two TaskB modes:
%   "AB" mode: TaskA and TaskB share the same (vw, layers).
%   "Aonly" mode: TaskA has (vw, layers), TaskB has vw=0 (no variance).
% All configs share the same initial rng seed; differences come purely from
% variance regularization, not initialisation noise.
%
% Each config:
%   1. rng(seed) → build fresh ResNet18
%   2. Train TaskA (CIFAR-10, 5ep) with (vw, layers)
%   3. Train TaskB (MNIST, 5ep) from that checkpoint
%      - "AB": same (vw, layers) as TaskA
%      - "Aonly": TaskB vw=0 (no variance on B)

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr, ymTr] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inp = [32 32 3];  nc = 10;  mb = 128;  lr = 1e-3;
epA = 5;  sA = 500;  epB = 5;  sB = 600;
seed = 20260626;

gpuDevice(3);  % set GPU once, never reset inside loop

layerSets = {
    ["res2b_relu","res3b_relu","res4b_relu"]
    ["res2b_relu","res3b_relu","res4b_relu","res5b_relu"]
    ["res2b_relu","res3b_relu"]
    ["res3b_relu","res4b_relu"]
    ["res2b_relu"]
    ["res3b_relu"]
    ["res4b_relu"]
    };
layerSetNames = ["res2-4","res2-5","res2-3","res3-4","res2only","res3only","res4only"];
varWeights = [0, 0.01, 0.05, 0.1, 0.2];

nLay = numel(layerSets);
nVW = numel(varWeights);
% "AB" mode for all configs, "Aonly" mode only for vw>0
nAB = nLay * nVW;
nAonly = nLay * (nVW - 1);  % exclude vw=0
nConfigs = nAB + nAonly;
fprintf("Total configs: %d (AB=%d, Aonly=%d)\n\n", nConfigs, nAB, nAonly);

results = table();
configIdx = 0;

for iL = 1:nLay
    lay = layerSets{iL};
    layTag = layerSetNames(iL);
    for iV = 1:nVW
        vw = varWeights(iV);

        % ---- Phase 1: train TaskA from scratch (shared by both modes) ----
        rng(seed);
        [XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
        netA = TransferLearning.BuildResNet18Classifier(inp, nc);
        ta = [];  tsq = [];  iter = 0;
        for ep = 1:epA
            nTrA = min(sA, size(dataset.taskA.trainX, 1));
            ordA = randperm(nTrA, sA);
            for s = 1:mb:sA
                e = min(s+mb-1, sA);  idxB = ordA(s:e);  iter = iter + 1;
                dlX = dlarray(single(XgA(:,:,:,idxB)) / 255, "SSCB");
                dlT = dlarray(TgA(:,idxB), "CB");
                [gr, ~, ~, ~] = dlfeval(@(n,x,t) lossFun(n,x,t,vw,lay), netA, dlX, dlT);
                [netA, ta, tsq] = adamupdate(netA, gr, ta, tsq, iter, lr);
            end
        end

        % ---- Phase 2a: AB mode (TaskB has same vw) ----
        configIdx = configIdx + 1;
        tagAB = sprintf("AB_vw=%.2f_%s", vw, layTag);
        statsB_AB = trainTaskB(netA, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, vw, sB, lay);
        m3 = mean(statsB_AB.valAccuracy(1:3));
        m5 = mean(statsB_AB.valAccuracy(1:5));
        mA = mean(statsB_AB.valAccuracy(1:end));
        results = [results; table(string(tagAB), vw, layTag, "AB", numel(lay), ...
            m3, m5, mA, ...
            'VariableNames', ["tag","varWeight","layerset","mode","nLayers","meanAcc3","meanAcc5","meanAccAll"])]; %#ok<AGROW>
        fprintf("[%d/%d] %s: mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", configIdx, nConfigs, tagAB, m3, m5, mA);

        % ---- Phase 2b: Aonly mode (TaskB vw=0, only for vw>0) ----
        if vw > 0
            configIdx = configIdx + 1;
            tagAO = sprintf("Aonly_vw=%.2f_%s", vw, layTag);
            statsB_AO = trainTaskB(netA, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, 0, sB, lay);
            m3 = mean(statsB_AO.valAccuracy(1:3));
            m5 = mean(statsB_AO.valAccuracy(1:5));
            mA = mean(statsB_AO.valAccuracy(1:end));
            results = [results; table(string(tagAO), vw, layTag, "Aonly", numel(lay), ...
                m3, m5, mA, ...
                'VariableNames', ["tag","varWeight","layerset","mode","nLayers","meanAcc3","meanAcc5","meanAccAll"])]; %#ok<AGROW>
            fprintf("[%d/%d] %s: mean3=%.4f  mean5=%.4f  meanAll=%.4f\n", configIdx, nConfigs, tagAO, m3, m5, mA);
        end
    end
end

% ---- Report ----
% Baseline: AB mode, vw=0, res2-4
baseRows = results.varWeight == 0 & results.mode == "AB" & results.layerset == "res2-4";
if any(baseRows)
    base3 = results.meanAcc3(baseRows);
    base5 = results.meanAcc5(baseRows);
    baseAll = results.meanAccAll(baseRows);
    fprintf("\nBaseline (AB vw=0, res2-4):  meanAcc3=%.4f  meanAcc5=%.4f  meanAccAll=%.4f\n", base3, base5, baseAll);

    results.diff3 = results.meanAcc3 - base3;
    results.diff5 = results.meanAcc5 - base5;
    results.diffAll = results.meanAccAll - baseAll;

    % Top by meanAcc5 (all modes)
    fprintf("\nTop 10 by meanAcc5 diff:\n");
    rs = sortrows(results, "diff5", "descend");
    disp(rs(1:min(10, height(rs)), ["tag","meanAcc3","meanAcc5","meanAccAll","diff3","diff5","diffAll"]));

    % Top by meanAcc3 (all modes)
    fprintf("\nTop 10 by meanAcc3 diff:\n");
    rs = sortrows(results, "diff3", "descend");
    disp(rs(1:min(10, height(rs)), ["tag","meanAcc3","meanAcc5","meanAccAll","diff3","diff5","diffAll"]));

    % Within-config comparison: AB vs Aonly (same vw, same layers)
    fprintf("\n=== AB vs Aonly: TaskB variance delta (AB - Aonly) ===\n");
    fprintf("%-14s  %-12s %-12s %-12s\n", "config", "AB_mean5", "Aonly_mean5", "delta");
    for iL = 1:nLay
        layTag = layerSetNames(iL);
        for iV = 2:nVW  % skip vw=0
            vw = varWeights(iV);
            tagAB = sprintf("AB_vw=%.2f_%s", vw, layTag);
            tagAO = sprintf("Aonly_vw=%.2f_%s", vw, layTag);
            rAB = results(strcmp(results.tag, tagAB), :);
            rAO = results(strcmp(results.tag, tagAO), :);
            if ~isempty(rAB) && ~isempty(rAO)
                d3 = rAB.meanAcc3 - rAO.meanAcc3;
                d5 = rAB.meanAcc5 - rAO.meanAcc5;
                dA = rAB.meanAccAll - rAO.meanAccAll;
                fprintf("%-14s  %-12s %-12s %+8.4f  | d3=%+.4f dAll=%+.4f\n", ...
                    sprintf("vw=%.2f_%s", vw, layTag), ...
                    sprintf("%.4f", rAB.meanAcc5), sprintf("%.4f", rAO.meanAcc5), d5, d3, dA);
            end
        end
    end
end

outPath = fullfile("D:\训练数据\models", "clean_sweep_ab_consistent_v2.mat");
save(outPath, "results", "-v7.3");
fprintf("\nSaved: %s\n", outPath);
end

% -------------------------------------------------------------------------
function stats = trainTaskB(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, sEp, lay)
nTr = size(XTr, 1);
sEp = min(sEp, nTr);
ta = [];  tsq = [];  iter = 0;
stats = struct();
stats.valAccuracy = zeros(maxEp, 1);
[Xg, Tg] = TransferLearning.PreUploadCifarToGpu(XTr, yTr, nc);
[dlXV, dlTV] = TransferLearning.PreprocessCifarRows(XV, yV, inSz, nc);
for ep = 1:maxEp
    stats.valAccuracy(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
    ord = randperm(nTr, sEp);
    for s = 1:mb:sEp
        e = min(s + mb - 1, sEp);  idx = ord(s:e);  iter = iter + 1;
        dlX = dlarray(single(Xg(:,:,:,idx)) / 255, "SSCB");
        dlT = dlarray(Tg(:,idx), "CB");
        [gr, ~, ~, ~] = dlfeval(@(n,x,t) lossFun(n,x,t,vw,lay), net, dlX, dlT);
        [net, ta, tsq] = adamupdate(net, gr, ta, tsq, iter, lr);
    end
end
stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
end

% -------------------------------------------------------------------------
function [gr, lo, ce, vt] = lossFun(net, dlX, dlT, vw, lay)
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
