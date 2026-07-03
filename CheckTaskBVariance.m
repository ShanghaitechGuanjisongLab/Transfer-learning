function CheckTaskBVariance()
% Extract TaskB hidden variance: both TaskB vw=0, but different TaskA checkpoints.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();

[XmTrFull, ymTrFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmValFull, ymValFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

rng(20260629); nc=10; nTrainPerClass=30; nValPerClass=10;
XmTrSmall=zeros(nTrainPerClass*nc,size(XmTrFull,2),"uint8"); ymTrSmall=zeros(nTrainPerClass*nc,1,"uint8");
for c=1:nc
    idx=find(ymTrFull==c); chosen=idx(randperm(numel(idx),nTrainPerClass));
    XmTrSmall((c-1)*nTrainPerClass+1:c*nTrainPerClass,:)=XmTrFull(chosen,:);
    ymTrSmall((c-1)*nTrainPerClass+1:c*nTrainPerClass)=c;
end
XmValSmall=zeros(nValPerClass*nc,size(XmValFull,2),"uint8"); ymValSmall=zeros(nValPerClass*nc,1,"uint8");
for c=1:nc
    idx=find(ymValFull==c); chosen=idx(randperm(numel(idx),nValPerClass));
    XmValSmall((c-1)*nValPerClass+1:c*nValPerClass,:)=XmValFull(chosen,:);
    ymValSmall((c-1)*nValPerClass+1:c*nValPerClass)=c;
end

fprintf("=== TaskB variance check: both B vw=0, different A checkpoints ===\n\n");

inp=[32 32 3]; mb=128; lr=1e-3; epA=5; sA=500; epB=5; layers=["res3b_relu"];
gpuDevice(3);
dataset=TransferLearning.LoadCifar10TaskABInMemory(dataRoot);

% Group 0
fprintf("Group 0: A(CIFAR vw=0) -> B(vw=0)\n");
rng(20260629);
[Xg0,Tg0]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net0=TransferLearning.BuildResNet18Classifier(inp,nc);
net0 = trainAquick(net0,Xg0,Tg0,epA,mb,lr,0,layers,sA);
[s0,~] = trainBvar(net0,XmTrSmall,ymTrSmall,XmValSmall,ymValSmall,inp,nc,epB,mb,lr,0,layers);
fprintf("  TaskB var: "); fprintf("%.4f ", s0(1:epB)); fprintf("\n");

% Group 1
fprintf("Group 1: A(CIFAR vw=0.01 res3) -> B(vw=0)\n");
rng(20260629);
[Xg1,Tg1]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net1=TransferLearning.BuildResNet18Classifier(inp,nc);
net1 = trainAquick(net1,Xg1,Tg1,epA,mb,lr,0.01,layers,sA);
[s1,~] = trainBvar(net1,XmTrSmall,ymTrSmall,XmValSmall,ymValSmall,inp,nc,epB,mb,lr,0,layers);
fprintf("  TaskB var: "); fprintf("%.4f ", s1(1:epB)); fprintf("\n\n");

fprintf("Var diff (G1-G0): ");
fprintf("%+.4f ", s1(1:epB)-s0(1:epB));
fprintf("\n");
end

function net = trainAquick(net,XgA,TgA,epA,mb,lr,vw,lay,sA)
ta=[]; tsq=[]; iter=0;
for ep=1:epA
    nTr=min(sA,size(XgA,4));
    ord=randperm(nTr,sA);
    for s=1:mb:sA
        e=min(s+mb-1,sA); idx=ord(s:e); iter=iter+1;
        dlX=dlarray(single(XgA(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(TgA(:,idx),"CB");
        [gr,~,~,~]=dlfeval(@(n,x,t)lossFun(n,x,t,vw,lay),net,dlX,dlT);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
    end
end
end

function [varVec,net] = trainBvar(net,XTr,yTr,XV,yV,inSz,nc,maxEp,mb,lr,vw,lay)
nTr=size(XTr,1);
[XTr,yTr]=TransferLearning.PreUploadCifarToGpu(XTr,yTr,nc);
[dlXV,dlTV]=TransferLearning.PreprocessCifarRows(XV,yV,inSz,nc);
varVec=zeros(maxEp,1);
ta=[]; tsq=[]; iter=0;
for ep=1:maxEp
    TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXV,dlTV,mb);  % warmup
    ord=1:nTr;
    epVar=0; nBatch=0;
    for s=1:mb:nTr
        e=min(s+mb-1,nTr); idx=ord(s:e); iter=iter+1;
        dlX=dlarray(single(XTr(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(yTr(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@(n,x,t)lossFun(n,x,t,vw,lay),net,dlX,dlT);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
        epVar=epVar+double(extractdata(vt));
        nBatch=nBatch+1;
    end
    varVec(ep)=epVar/nBatch;
end
end

function [gr,lo,ce,vt]=lossFun(net,dlX,dlT,vw,lay)
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
