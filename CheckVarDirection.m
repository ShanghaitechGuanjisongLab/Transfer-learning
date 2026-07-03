function CheckVarDirection()
% Verify: does CE/(1+vw*var) push variance up or down during TaskA training?
dataRoot="D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
dataset=TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
inp=[32 32 3]; nc=10; mb=128; lr=1e-3; epA=2; sA=500;
layers="res3b_relu";
gpuDevice(3);

rng(20260629);
[Xg,Tg]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net=TransferLearning.BuildResNet18Classifier(inp,nc);
ta=[];tsq=[];iter=0;
varLog=zeros(epA,1);
for ep=1:epA
    nTr=min(sA,size(Xg,4));
    ord=randperm(nTr,sA);
    epVar=0;nb=0;
    for s=1:mb:sA
        e=min(s+mb-1,sA);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@lossWithVar,net,dlX,dlT,0.01,layers);
        epVar=epVar+double(extractdata(vt));nb=nb+1;
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
    end
    varLog(ep)=epVar/nb;
end
fprintf("vw=0.01 TaskA CIFAR var (res3b): ");
fprintf("%.4f ",varLog); fprintf("\n");
end

function [gr,lo,ce,vt]=lossWithVar(net,dlX,dlT,vw,lay)
[logits,feat]=forward(net,dlX,Outputs=["fc_logits",lay]);
f=reshape(stripdims(feat),[],size(feat,4));
vt=mean(var(f,0,2),"all");
p=softmax(logits);
ce=crossentropy(p,dlT,TargetCategories="independent");
lo=ce/(1+vw*vt);
gr=dlgradient(lo,net.Learnables);
end
