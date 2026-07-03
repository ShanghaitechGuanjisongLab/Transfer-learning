function CheckVarCrossDataset()
% Verify: (1) TaskA CIFAR var vw=0 vs 0.01; (2) TaskB MNIST var from both checkpoints.
% Both TaskB use vw=0, only start from different A checkpoints.

dataRoot="D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset=TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr,ymTr]=TransferLearning.LoadMnistAsCifarFormat(dataRoot,"train",0,20260616);
[XmVal,ymVal]=TransferLearning.LoadMnistAsCifarFormat(dataRoot,"t10k",0,20260616);

inp=[32 32 3];nc=10;mb=128;lr=1e-3;epA=5;sA=500;epB=5;
layers=["res3b_relu"];
gpuDevice(3);
seed=20260629;

% ---- Train A0: vw=0 ----
fprintf("=== A0: CIFAR vw=0 ===\n");
rng(seed);
[Xg0,Tg0]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
netA0=TransferLearning.BuildResNet18Classifier(inp,nc);
ta=[];tsq=[];iter=0;
varA0=zeros(epA,1);
for ep=1:epA
    nTr=min(sA,size(Xg0,4));
    ord=randperm(nTr,sA);
    epVar=0;nb=0;
    for s=1:mb:sA
        e=min(s+mb-1,sA);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg0(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg0(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@lossVarCheck,netA0,dlX,dlT,0,layers);
        epVar=epVar+double(extractdata(vt));nb=nb+1;
        [netA0,ta,tsq]=adamupdate(netA0,gr,ta,tsq,iter,lr);
    end
    varA0(ep)=epVar/nb;
end
fprintf("  A0 var (CIFAR): ");fprintf("%.4f ",varA0);fprintf("\n");

% ---- Train A1: vw=0.01 ----
fprintf("=== A1: CIFAR vw=0.01 ===\n");
rng(seed);
[Xg1,Tg1]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
netA1=TransferLearning.BuildResNet18Classifier(inp,nc);
ta=[];tsq=[];iter=0;
varA1=zeros(epA,1);
for ep=1:epA
    nTr=min(sA,size(Xg1,4));
    ord=randperm(nTr,sA);
    epVar=0;nb=0;
    for s=1:mb:sA
        e=min(s+mb-1,sA);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg1(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg1(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@lossVarCheck,netA1,dlX,dlT,0.01,layers);
        epVar=epVar+double(extractdata(vt));nb=nb+1;
        [netA1,ta,tsq]=adamupdate(netA1,gr,ta,tsq,iter,lr);
    end
    varA1(ep)=epVar/nb;
end
fprintf("  A1 var (CIFAR): ");fprintf("%.4f ",varA1);fprintf("\n");
fprintf("  A1-A0 var diff: ");fprintf("%+.4f ",varA1-varA0);fprintf("\n\n");

% ---- Measure var on MNIST (one forward pass, no training) ----
fprintf("=== Measure res3b variance on MNIST (no training, just forward) ===\n");
[XgMn,TgMn]=TransferLearning.PreUploadCifarToGpu(XmTr,ymTr,nc);
nMn=300; % small subset for speed
nMn=min(nMn,size(XgMn,4));
idxMn=1:nMn;
dlXm=dlarray(single(XgMn(:,:,:,idxMn))/255,"SSCB");

% A0 checkpoint on MNIST
[~,feat0]=forward(netA0,dlXm,Outputs=["fc_logits",layers]);
f0=reshape(stripdims(feat0),[],nMn);
varMn0=mean(var(f0,0,2),"all");
fprintf("  A0 (vw=0)        MNIST var=%.4f\n",double(extractdata(varMn0)));

% A1 checkpoint on MNIST
[~,feat1]=forward(netA1,dlXm,Outputs=["fc_logits",layers]);
f1=reshape(stripdims(feat1),[],nMn);
varMn1=mean(var(f1,0,2),"all");
fprintf("  A1 (vw=0.01)     MNIST var=%.4f\n",double(extractdata(varMn1)));
fprintf("  A1-A0 MNIST var: %+.4f\n",double(extractdata(varMn1-varMn0)));

% Also check on CIFAR test set
fprintf("\n=== Measure res3b variance on CIFAR test ===\n");
[XgCt,TgCt]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.valX,dataset.taskA.valY,nc);
nCt=500;
nCt=min(nCt,size(XgCt,4));
idxCt=1:nCt;
dlXc=dlarray(single(XgCt(:,:,:,idxCt))/255,"SSCB");
[~,fc0]=forward(netA0,dlXc,Outputs=["fc_logits",layers]);
f0c=reshape(stripdims(fc0),[],nCt);
varC0=mean(var(f0c,0,2),"all");
[~,fc1]=forward(netA1,dlXc,Outputs=["fc_logits",layers]);
f1c=reshape(stripdims(fc1),[],nCt);
varC1=mean(var(f1c,0,2),"all");
fprintf("  A0 (vw=0)        CIFAR var=%.4f\n",double(extractdata(varC0)));
fprintf("  A1 (vw=0.01)     CIFAR var=%.4f\n",double(extractdata(varC1)));
fprintf("  A1-A0 CIFAR var: %+.4f\n",double(extractdata(varC1-varC0)));
end

function [gr,lo,ce,vt]=lossVarCheck(net,dlX,dlT,vw,lay)
[logits,feat]=forward(net,dlX,Outputs=["fc_logits",lay]);
f=reshape(stripdims(feat),[],size(feat,4));
vt=mean(var(f,0,2),"all");
p=softmax(logits);
ce=crossentropy(p,dlT,TargetCategories="independent");
lo=ce/(1+vw*vt);
gr=dlgradient(lo,net.Learnables);
end
