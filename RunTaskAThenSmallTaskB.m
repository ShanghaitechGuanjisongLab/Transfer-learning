function RunTaskAThenSmallTaskB()
% TaskA: CIFAR 100ep vw=0 vs vw=0.5 res2-4
% TaskB: small-sample MNIST (300/100), compare B vw=0 vs B vw=0.5
% Compare whether adding the same variance objective on B helps or hurts.

dataRoot="D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset=TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTrFull,ymTrFull]=TransferLearning.LoadMnistAsCifarFormat(dataRoot,"train",0,20260616);
[XmValFull,ymValFull]=TransferLearning.LoadMnistAsCifarFormat(dataRoot,"t10k",0,20260616);

% Build small MNIST subsets
rng(20260630);nc=10;nTrCls=30;nValCls=10;
XmTrS=zeros(nTrCls*nc,size(XmTrFull,2),"uint8");ymTrS=zeros(nTrCls*nc,1,"uint8");
XmValS=zeros(nValCls*nc,size(XmValFull,2),"uint8");ymValS=zeros(nValCls*nc,1,"uint8");
for c=1:nc
    tidx=find(ymTrFull==c);tchosen=tidx(randperm(numel(tidx),nTrCls));
    vidx=find(ymValFull==c);vchosen=vidx(randperm(numel(vidx),nValCls));
    XmTrS((c-1)*nTrCls+1:c*nTrCls,:)=XmTrFull(tchosen,:);
    ymTrS((c-1)*nTrCls+1:c*nTrCls)=c;
    XmValS((c-1)*nValCls+1:c*nValCls,:)=XmValFull(vchosen,:);
    ymValS((c-1)*nValCls+1:c*nValCls)=c;
end
fprintf("MNIST subset: %d train, %d val\n",size(XmTrS,1),size(XmValS,1));

inp=[32 32 3];mb=128;lr=1e-3;epA=100;sA=500;epB=10;
layers=["res2b_relu","res3b_relu","res4b_relu"];
seed=20260630;
gpuDevice(3);

% ---- Phase 1: Train TaskA vw=0 ----
fprintf("\n=== Phase 1: TaskA CIFAR vw=0 ===\n");
rng(seed);
[Xg0,Tg0]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net0=TransferLearning.BuildResNet18Classifier(inp,nc);
statsA0=trainTaskAVar(net0,Xg0,Tg0,dataset.taskA.valX,dataset.taskA.valY,inp,nc,epA,mb,lr,0,layers,sA);
fprintf("  A0 final: var=%.4f valAcc=%.4f\n",statsA0.trainVar(end),statsA0.finalValAccuracy);

% ---- Phase 1: Train TaskA vw=0.5 ----
fprintf("\n=== Phase 1: TaskA CIFAR vw=0.5 ===\n");
rng(seed);
[Xg1,Tg1]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net1=TransferLearning.BuildResNet18Classifier(inp,nc);
statsA1=trainTaskAVar(net1,Xg1,Tg1,dataset.taskA.valX,dataset.taskA.valY,inp,nc,epA,mb,lr,0.5,layers,sA);
fprintf("  A1 final: var=%.4f valAcc=%.4f\n",statsA1.trainVar(end),statsA1.finalValAccuracy);

% ---- Phase 2: TaskB from A0 checkpoint ----
fprintf("\n=== Phase 2: TaskB from A0 (vw=0) ===\n");
[varB0,accB0]=trainTaskBVarSmall(statsA0.netFinal,XmTrS,ymTrS,XmValS,ymValS,inp,nc,epB,mb,lr,0,layers);
fprintf("  B0 var: ");fprintf("%.4f ",varB0);fprintf("\n");
fprintf("  B0 acc: ");fprintf("%.4f ",accB0);fprintf("\n");

% ---- Phase 2: TaskB from A1 checkpoint ----
fprintf("\n=== Phase 2: TaskB from A1 (vw=0.5) ===\n");
[varB1,accB1]=trainTaskBVarSmall(statsA1.netFinal,XmTrS,ymTrS,XmValS,ymValS,inp,nc,epB,mb,lr,0,layers);
fprintf("  B1 var: ");fprintf("%.4f ",varB1);fprintf("\n");
fprintf("  B1 acc: ");fprintf("%.4f ",accB1);fprintf("\n");

% ---- Phase 2: TaskB from A1 checkpoint, also with vw=0.5 ----
fprintf("\n=== Phase 2: TaskB from A1 (B vw=0.5) ===\n");
[varB2,accB2]=trainTaskBVarSmall(statsA1.netFinal,XmTrS,ymTrS,XmValS,ymValS,inp,nc,epB,mb,lr,0.5,layers);
fprintf("  B2 var: ");fprintf("%.4f ",varB2);fprintf("\n");
fprintf("  B2 acc: ");fprintf("%.4f ",accB2);fprintf("\n");

% ---- Report ----
fprintf("\n=== TaskB Variance Comparison ===\n");
fprintf("Epoch  B0(A0,B0)  B1(A0.5,B0)  B2(A0.5,B0.5)  B1-B0  B2-B1\n");
for ep=1:epB
    fprintf("%d     %.4f     %.4f       %.4f          %+.4f  %+.4f\n",ep,varB0(ep),varB1(ep),varB2(ep),varB1(ep)-varB0(ep),varB2(ep)-varB1(ep));
end
fprintf("\nTaskB Accuracy:\n");
fprintf("Epoch  B0(A0,B0)  B1(A0.5,B0)  B2(A0.5,B0.5)  B1-B0  B2-B1\n");
for ep=1:epB
    fprintf("%d     %.4f     %.4f       %.4f          %+.4f  %+.4f\n",ep,accB0(ep),accB1(ep),accB2(ep),accB1(ep)-accB0(ep),accB2(ep)-accB1(ep));
end

% ---- Plot: TaskB variance & accuracy from all three conditions ----
f=figure("Position",[100 100 900 350]);
subplot(1,2,1);
plot(1:epB,varB0,"b-o","LineWidth",1.2,"MarkerSize",4);hold on;
plot(1:epB,varB1,"r-s","LineWidth",1.2,"MarkerSize",4);
plot(1:epB,varB2,"k-^","LineWidth",1.2,"MarkerSize",4);
xlabel("Epoch");ylabel("Hidden Var (res2-4)");
title("TaskB (MNIST) Variance");
legend("A0/B0","A0.5/B0","A0.5/B0.5","Location","best");grid on;

subplot(1,2,2);
plot(1:epB,accB0,"b-o","LineWidth",1.2,"MarkerSize",4);hold on;
plot(1:epB,accB1,"r-s","LineWidth",1.2,"MarkerSize",4);
plot(1:epB,accB2,"k-^","LineWidth",1.2,"MarkerSize",4);
xlabel("Epoch");ylabel("Accuracy");
title("TaskB (MNIST) Accuracy");
legend("A0/B0","A0.5/B0","A0.5/B0.5","Location","best");grid on;
sgtitle("TaskB Variance Objective on Small-Sample MNIST");

TransferLearning.ExportStandardFigure(f,2,"TaskB_MNIST_BVariance_vw05.svg");
fprintf("\nSVG: %s\n",TransferLearning.StandardFigureSvgPath("TaskB_MNIST_BVariance_vw05.svg"));
end

% -------------------------------------------------------------------------
function stats=trainTaskAVar(net,Xg,Tg,Xv,yv,inSz,nc,maxEp,mb,lr,vw,lay,sEp)
nTr=size(Xg,4);sEp=min(sEp,nTr);
[dlXv,dlTv]=TransferLearning.PreprocessCifarRows(Xv,yv,inSz,nc);
stats=struct();
stats.trainVar=zeros(maxEp,1);stats.valAccuracy=zeros(maxEp,1);
ta=[];tsq=[];iter=0;
for ep=1:maxEp
    stats.valAccuracy(ep)=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,mb);
    ord=randperm(nTr,sEp);
    epV=0;nb=0;
    for s=1:mb:sEp
        e=min(s+mb-1,sEp);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@lossVar,net,dlX,dlT,vw,lay);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
        epV=epV+double(extractdata(vt));nb=nb+1;
    end
    stats.trainVar(ep)=epV/nb;
end
stats.finalValAccuracy=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,mb);
stats.netFinal=net;
end

function [varVec,accVec]=trainTaskBVarSmall(net,XTr,yTr,XV,yV,inSz,nc,maxEp,mb,lr,vw,lay)
nTr=size(XTr,1);
[Xg,Tg]=TransferLearning.PreUploadCifarToGpu(XTr,yTr,nc);
[dlXv,dlTv]=TransferLearning.PreprocessCifarRows(XV,yV,inSz,nc);
varVec=zeros(maxEp,1);accVec=zeros(maxEp,1);
ta=[];tsq=[];iter=0;
for ep=1:maxEp
    accVec(ep)=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,mb);
    ord=1:nTr;  % fixed order every epoch (same 300 images)
    epV=0;nb=0;
    for s=1:mb:nTr
        e=min(s+mb-1,nTr);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@lossVar,net,dlX,dlT,vw,lay);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
        epV=epV+double(extractdata(vt));nb=nb+1;
    end
    varVec(ep)=epV/nb;
end
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
