function CleanSweepLayerSets()
% Fixed checkpoint TaskA -> sweep only TaskB layer sets + varWeights.
% Clean control: same checkpoint for all configs.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr, ymTr] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inp=[32 32 3]; nc=10; mb=128; lr=1e-3; epA=5; sA=500; epB=5; sB=600;

% Build fixed TaskA checkpoint (res2-4, vw=0.01)
rng(20260626); gpuDevice(3);
netA = TransferLearning.BuildResNet18Classifier(inp, nc);
layA = ["res2b_relu","res3b_relu","res4b_relu"];
for ep=1:epA
    ordA=randperm(min(sA,size(dataset.taskA.trainX,1)),sA);
    [Xg,Tg]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
    ta=[]; tsq=[]; iter=0;
    for s=1:mb:sA
        e=min(s+mb-1,sA); idx=ordA(s:e); iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,~]=dlfeval(@(n,x,t) lossFun(n,x,t,0.01,layA),netA,dlX,dlT);
        [netA,ta,tsq]=adamupdate(netA,gr,ta,tsq,iter,lr);
    end
end
ckptPath = "D:\训练数据\models\tmp_ckpt.mat";
save(ckptPath, "netA", "-v7.3");
fprintf("Checkpoint saved (CIFAR 5ep, res2-4).\n");

% Sweep
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
varWeights = [0, 0.01, 0.05, 0.1];

results = table();
nConfigs = numel(layerSets) * numel(varWeights);
configIdx = 0;

for iL = 1:numel(layerSets)
    lay = layerSets{iL};
    layTag = layerSetNames(iL);
    for iV = 1:numel(varWeights)
        vw = varWeights(iV);
        configIdx = configIdx + 1;
        tag = sprintf("vw=%.2f_%s", vw, layTag);

        load(ckptPath, "netA");
        stats = trainBfixed(netA, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, vw, sB, lay);

        results = [results; table(string(tag), vw, layTag, numel(lay), ...
            stats.valAccuracy(3), stats.valAccuracy(5), stats.finalValAccuracy, ...
            'VariableNames', ["tag","varWeight","layerset","nLayers","valAcc3","valAcc5","finalVal"])]; %#ok<AGROW>

        fprintf("[%d/%d] %s: acc3=%.4f acc5=%.4f final=%.4f\n", ...
            configIdx, nConfigs, tag, stats.valAccuracy(3), stats.valAccuracy(5), stats.finalValAccuracy);
    end
end

% Report
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
end

function stats = trainBfixed(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, sEp, lay)
nTr=size(XTr,1); sEp=min(sEp,nTr);
ta=[]; tsq=[]; iter=0;
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
