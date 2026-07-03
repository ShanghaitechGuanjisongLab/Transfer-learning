function RunTaskACifarVar02Res24VsBaseline()
% TaskA CIFAR-10: vw=0.2 res2-4 vs vw=0. 100 epochs. Fig with per-epoch stats.
dataRoot="D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
dataset=TransferLearning.LoadCifar10TaskABInMemory(dataRoot);

inp=[32 32 3];nc=10;mb=128;lr=1e-3;ep=100;sPerEp=500;
layers=["res2b_relu","res3b_relu","res4b_relu"];
seed=20260629;
gpuDevice(3);

% ---- Baseline: vw=0 ----
fprintf("=== TaskA CIFAR vw=0 (res2-4) ===\n");
rng(seed);
[Xg0,Tg0]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net0=TransferLearning.BuildResNet18Classifier(inp,nc);
stats0=trainWithStats(net0,Xg0,Tg0,dataset.taskA.valX,dataset.taskA.valY,inp,nc,ep,mb,lr,0,layers,sPerEp);
fprintf("  final: loss=%.4f ce=%.4f var=%.4f valAcc=%.4f\n",...
    stats0.trainLoss(end),stats0.trainCE(end),stats0.trainVar(end),stats0.finalValAccuracy);

% ---- Var: vw=0.2 res2-4 ----
fprintf("=== TaskA CIFAR vw=0.2 (res2-4) ===\n");
rng(seed);
[Xg1,Tg1]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net1=TransferLearning.BuildResNet18Classifier(inp,nc);
stats1=trainWithStats(net1,Xg1,Tg1,dataset.taskA.valX,dataset.taskA.valY,inp,nc,ep,mb,lr,0.2,layers,sPerEp);
fprintf("  final: loss=%.4f ce=%.4f var=%.4f valAcc=%.4f\n",...
    stats1.trainLoss(end),stats1.trainCE(end),stats1.trainVar(end),stats1.finalValAccuracy);

% ---- Report ----
fprintf("\n=== Results ===\n");
fprintf("vw=0:   loss=%.4f ce=%.4f var=%.4f valAcc=%.4f\n",...
    stats0.trainLoss(end),stats0.trainCE(end),stats0.trainVar(end),stats0.finalValAccuracy);
fprintf("vw=0.2: loss=%.4f ce=%.4f var=%.4f valAcc=%.4f\n",...
    stats1.trainLoss(end),stats1.trainCE(end),stats1.trainVar(end),stats1.finalValAccuracy);
fprintf("Diff:   loss=%+.4f ce=%+.4f var=%+.4f valAcc=%+.4f\n",...
    stats1.trainLoss(end)-stats0.trainLoss(end),...
    stats1.trainCE(end)-stats0.trainCE(end),...
    stats1.trainVar(end)-stats0.trainVar(end),...
    stats1.finalValAccuracy-stats0.finalValAccuracy);

% ---- Plot ----
f=TransferLearning.PlotTrainingCurvesCompareVariance(...
    stats1,stats0,...
    "vw=0.2 res2-4","vw=0",...
    "TaskA (CIFAR-10): vw=0.2 res2-4 vs No Variance (ResNet-18)",ep);
TransferLearning.ExportStandardFigure(f,2,"TaskA_CIFAR_vw020_res24_vs_Baseline_100ep.svg");
fprintf("\nSVG: %s\n",TransferLearning.StandardFigureSvgPath("TaskA_CIFAR_vw020_res24_vs_Baseline_100ep.svg"));
end

function stats=trainWithStats(net,Xg,Tg,Xv,yv,inSz,nc,maxEp,mb,lr,vw,lay,sEp)
nTr=size(Xg,4);sEp=min(sEp,nTr);
[dlXv,dlTv]=TransferLearning.PreprocessCifarRows(Xv,yv,inSz,nc);
stats=struct();
stats.trainLoss=zeros(maxEp,1);stats.trainCE=zeros(maxEp,1);
stats.trainVar=zeros(maxEp,1);stats.valAccuracy=zeros(maxEp,1);
ta=[];tsq=[];iter=0;
for ep=1:maxEp
    stats.valAccuracy(ep)=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,mb);
    ord=randperm(nTr,sEp);
    epL=0;epC=0;epV=0;nb=0;
    for s=1:mb:sEp
        e=min(s+mb-1,sEp);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg(:,idx),"CB");
        [gr,lo,ce,vt]=dlfeval(@lossVar,net,dlX,dlT,vw,lay);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
        epL=epL+double(extractdata(lo));
        epC=epC+double(extractdata(ce));
        epV=epV+double(extractdata(vt));
        nb=nb+1;
    end
    stats.trainLoss(ep)=epL/nb;
    stats.trainCE(ep)=epC/nb;
    stats.trainVar(ep)=epV/nb;
end
stats.finalValAccuracy=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,mb);
stats.netFinal=net;
end

function [gr,lo,ce,vt]=lossVar(net,dlX,dlT,vw,lay)
outputs=["fc_logits",lay];
C=cell(1,numel(lay));
[logits,C{:}]=forward(net,dlX,Outputs=outputs);
p=softmax(logits);
ce=crossentropy(p,dlT,TargetCategories="independent");
vv=zeros(1,numel(lay),"like",C{1});
for i=1:numel(lay)
    f=reshape(stripdims(C{i}),[],size(C{i},4));
    vv(i)=mean(var(f,0,2),"all");
end
vt=mean(vv,"all");
lo=ce/(1+vw*vt);
gr=dlgradient(lo,net.Learnables);
end
