function CheckWeightVarRange()
dataRoot="D:\训练数据"; PrepareOfficialCIFAR10TaskAB();
dataset=TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
inp=[32 32 3];nc=10;mb=128;lr=1e-3;sA=500;
prefixes=["res2b","res3b","res4b"];
gpuDevice(3);

% ---- Probe vw=0 weight variance drift ----
rng(20260701);
[Xg0,Tg0]=TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
net0=TransferLearning.BuildResNet18Classifier(inp,nc);
fprintf("vw=0 weightVar: initial=%.6f\n", measureWvar(net0,prefixes));

ta=[];tsq=[];iter=0;
for ep=1:100
    ord=randperm(min(sA,size(Xg0,4)),sA);
    for s=1:mb:sA
        e=min(s+mb-1,sA);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg0(:,:,:,idx))/255,"SSCB");dlT=dlarray(Tg0(:,idx),"CB");
        [gr]=dlfeval(@(n,x,t)lossWv(n,x,t,0,prefixes),net0,dlX,dlT);
        [net0,ta,tsq]=adamupdate(net0,gr,ta,tsq,iter,lr);
    end
    if ismember(ep,[1,5,20,100])
        fprintf("vw=0 epoch %3d: weightVar=%.6f\n", ep, measureWvar(net0,prefixes));
    end
end
fprintf("vw=0 final weightVar=%.6f\n\n", measureWvar(net0,prefixes));

% ---- Probe vw=5 extreme ----
rng(20260701);
net5=TransferLearning.BuildResNet18Classifier(inp,nc);
fprintf("vw=5 weightVar: initial=%.6f\n", measureWvar(net5,prefixes));
ta=[];tsq=[];iter=0;
for ep=1:100
    ord=randperm(min(sA,size(Xg0,4)),sA);
    for s=1:mb:sA
        e=min(s+mb-1,sA);idx=ord(s:e);iter=iter+1;
        dlX=dlarray(single(Xg0(:,:,:,idx))/255,"SSCB");dlT=dlarray(Tg0(:,idx),"CB");
        [gr]=dlfeval(@(n,x,t)lossWv(n,x,t,5,prefixes),net5,dlX,dlT);
        [net5,ta,tsq]=adamupdate(net5,gr,ta,tsq,iter,lr);
    end
    if ismember(ep,[1,5,20,100])
        fprintf("vw=5 epoch %3d: weightVar=%.6f\n", ep, measureWvar(net5,prefixes));
    end
end
fprintf("vw=5 final weightVar=%.6f\n", measureWvar(net5,prefixes));
end

function v = measureWvar(net,prefixes)
L=net.Learnables; av=[];
for lp=1:numel(prefixes)
    for i=1:height(L)
        if startsWith(string(L.Layer(i)),prefixes(lp)) && endsWith(string(L.Parameter(i)),"Weights")
            av(end+1)=var(L.Value{i}(:));
        end
    end
end
v=double(mean(av));
end

function [gr,lo]=lossWv(net,dlX,dlT,vw,prefixes)
logits=forward(net,dlX,Outputs="fc_logits");
p=softmax(logits);ce=crossentropy(p,dlT,TargetCategories="independent");
L=net.Learnables;av=[];
for lp=1:numel(prefixes)
    for i=1:height(L)
        if startsWith(string(L.Layer(i)),prefixes(lp)) && endsWith(string(L.Parameter(i)),"Weights")
            av(end+1)=var(L.Value{i}(:));
        end
    end
end
vt=mean(av); lo=ce/(1+vw*vt); gr=dlgradient(lo,net.Learnables);
end