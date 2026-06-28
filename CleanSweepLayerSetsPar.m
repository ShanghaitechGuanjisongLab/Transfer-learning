function CleanSweepLayerSetsPar()
% Fixed checkpoint TaskA -> sweep only TaskB layer sets + varWeights.
% CLEAN control: same checkpoint for all configs.
% PARALLEL: each independent config runs on its own GPU worker.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr, ymTr] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inp=[32 32 3]; nc=10; mb=128; lr=1e-3; epA=5; sA=500; epB=5; sB=600;

% ---- Phase 1: train fixed TaskA checkpoint (serial) ----
rng(20260626); gpuDevice(3);
netA = TransferLearning.BuildResNet18Classifier(inp, nc);
layA = ["res2b_relu","res3b_relu","res4b_relu"];
[XgA,TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, nc);
nTrA = min(sA, size(dataset.taskA.trainX, 1));
ta=[]; tsq=[]; iter=0;
for ep=1:epA
    ordA=randperm(nTrA, sA);
    for s=1:mb:sA
        e=min(s+mb-1,sA); idx=ordA(s:e); iter=iter+1;
        dlX=dlarray(single(XgA(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(TgA(:,idx),"CB");
        [gr,~,~,~]=dlfeval(@(n,x,t) lossFun(n,x,t,0.01,layA),netA,dlX,dlT);
        [netA,ta,tsq]=adamupdate(netA,gr,ta,tsq,iter,lr);
    end
end
ckptPath = "D:\训练数据\models\tmp_ckpt.mat";
save(ckptPath, "netA", "-v7.3");
fprintf("Checkpoint saved (CIFAR 5ep).\n");

% ---- Phase 2: parallel sweep on TaskB ----
layerSets = {
    ["res2b_relu","res3b_relu","res4b_relu"], ["res2b_relu","res3b_relu","res4b_relu","res5b_relu"], ...
    ["res2b_relu","res3b_relu"], ["res3b_relu","res4b_relu"], ...
    ["res2b_relu"], ["res3b_relu"], ["res4b_relu"] ...
    };
layerSetNames = ["res2-4","res2-5","res2-3","res3-4","res2only","res3only","res4only"];
varWeights = [0, 0.01, 0.05, 0.1];

nLayers = numel(layerSets);
nVars = numel(varWeights);
nConfigs = nLayers * nVars;
gpuCount = gpuDeviceCount("available");
fprintf("GPUs available: %d, configs: %d\n", gpuCount, nConfigs);

% Build config table
configs = cell(nConfigs, 5); % {layNames, layTag, nLay, vw, tag}
idx = 1;
for iL = 1:nLayers
    lay = layerSets{iL};
    layTag = layerSetNames(iL);
    for iV = 1:nVars
        configs{idx,1} = lay;
        configs{idx,2} = layTag;
        configs{idx,3} = numel(lay);
        configs{idx,4} = varWeights(iV);
        configs{idx,5} = sprintf("vw=%.2f_%s", varWeights(iV), layTag);
        idx = idx + 1;
    end
end

% Open parallel pool with exactly gpuCount workers (processes)
pool = gcp("nocreate");
if ~isempty(pool)
    delete(pool);
end
parpool("Processes", gpuCount);

resultsCell = cell(nConfigs, 1);
resultsAcc3 = zeros(nConfigs, 1);
resultsAcc5 = zeros(nConfigs, 1);
resultsFinal = zeros(nConfigs, 1);
tags = strings(nConfigs, 1);
vws = zeros(nConfigs, 1);
layerTags = strings(nConfigs, 1);
nLays = zeros(nConfigs, 1);

parfor ci = 1:nConfigs
    % Each worker claims its own GPU
    workerIdx = getCurrentTask().ID;
    gpuIdx = mod(workerIdx - 1, gpuCount) + 1;
    gpuDevice(gpuIdx);
    
    lay = configs{ci,1};
    layTag = configs{ci,2};
    nLay = configs{ci,3};
    vw = configs{ci,4};
    tag = configs{ci,5};
    
    % Load checkpoint
    netLocal = load(ckptPath, "netA");
    netLocal = netLocal.netA;
    
    % Train TaskB
    stats = trainBfixedPar(netLocal, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, vw, sB, lay);
    
    resultsCell{ci} = stats;
    resultsAcc3(ci) = stats.valAccuracy(3);
    resultsAcc5(ci) = stats.valAccuracy(5);
    resultsFinal(ci) = stats.finalValAccuracy;
    tags(ci) = tag;
    vws(ci) = vw;
    layerTags(ci) = layTag;
    nLays(ci) = nLay;
    
    fprintf("[worker %d, GPU %d] %s: acc3=%.4f acc5=%.4f final=%.4f\n", workerIdx, gpuIdx, tag, stats.valAccuracy(3), stats.valAccuracy(5), stats.finalValAccuracy);
end

% ---- Report ----
results = table(tags, vws, layerTags, nLays, resultsAcc3, resultsAcc5, resultsFinal, ...
    'VariableNames', ["tag","varWeight","layerset","nLayers","valAcc3","valAcc5","finalVal"]);

v0idx = find(results.varWeight==0 & results.layerset=="res2-4", 1);
if ~isempty(v0idx)
    base3=results.valAcc3(v0idx); base5=results.valAcc5(v0idx); baseF=results.finalVal(v0idx);
    fprintf("\nBaseline (vw=0, res2-4): acc3=%.4f acc5=%.4f final=%.4f\n", base3, base5, baseF);
    results.diff3 = results.valAcc3 - base3;
    results.diff5 = results.valAcc5 - base5;
    results.diffF = results.finalVal - baseF;

    fprintf("\nTop 10 by acc5 diff:\n");
    rs = sortrows(results, "diff5", "descend");
    disp(rs(1:min(10,height(rs)), ["tag","valAcc3","valAcc5","finalVal","diff3","diff5","diffF"]));

    fprintf("\nTop 10 by acc3 diff:\n");
    rs = sortrows(results, "diff3", "descend");
    disp(rs(1:min(10,height(rs)), ["tag","valAcc3","valAcc5","finalVal","diff3","diff5","diffF"]));
end

save(fullfile("D:\训练数据\models", "clean_sweep_layers_results.mat"), "results", "-v7.3");
delete(pool);
end

function stats = trainBfixedPar(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, sEp, lay)
nTr=size(XTr,1); sEp=min(sEp,nTr);
ta=[]; tsq=[]; iter=0;
stats = struct();
stats.valAccuracy=zeros(maxEp,1);
[Xg,Tg]=TransferLearning.PreUploadCifarToGpu(XTr,yTr,nc);
[dlXV,dlTV]=TransferLearning.PreprocessCifarRows(XV,yV,inSz,nc);
for ep=1:maxEp
    stats.valAccuracy(ep)=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXV,dlTV,mb);
    ord=randperm(nTr,sEp);
    for s=1:mb:sEp
        e=min(s+mb-1,sEp); idx=ord(s:e); iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,~]=dlfeval(@(n,x,t) lossFun(n,x,t,vw,lay),net,dlX,dlT);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
    end
end
stats.finalValAccuracy=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXV,dlTV,mb);
end

function [gr,lo,ce,vt] = lossFun(net,dlX,dlT,vw,lay)
outputs=["fc_logits",lay];
C=cell(1,numel(lay));
[logits,C{:}]=forward(net,dlX,Outputs=outputs);
p=softmax(logits);
ceLoss=crossentropy(p,dlT,TargetCategories="independent");
vv=zeros(1,numel(lay),"like",C{1});
for i=1:numel(lay)
    f=reshape(stripdims(C{i}),[],size(C{i},4));
    vv(i)=mean(var(f,0,2),"all");
end
vt=mean(vv,"all");
lo=ceLoss/(1+vw*vt);
gr=dlgradient(lo,net.Learnables);
ce=ceLoss;
end
