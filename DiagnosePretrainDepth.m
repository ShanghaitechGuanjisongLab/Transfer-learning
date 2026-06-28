function DiagnosePretrainDepth()
dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTr, ymTr] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inp=[32 32 3]; nc=10; mb=128; lr=1e-3; sA=500; sB=600; epB=5;
lay = ["res2b_relu","res3b_relu","res4b_relu"];

for ptEp = [1, 5]
    rng(20260626); gpuDevice(3);
    fprintf("=== PT %d epochs ===\n", ptEp);
    netA = TransferLearning.BuildResNet18Classifier(inp, nc);
    for ep=1:ptEp
        netA = trainA1ep(netA, dataset, inp, nc, mb, lr, 0.1, sA, lay);
    end
    ckpt = "D:\训练数据\models\tmp_ckpt.mat";
    save(ckpt, "netA", "-v7.3");

    for vw = [0, 0.1]
        load(ckpt, "netA");
        stats = trainBshort(netA, XmTr, ymTr, XmVal, ymVal, inp, nc, epB, mb, lr, vw, sB, lay);
        fprintf("  vw=%.1f: acc3=%.4f acc5=%.4f final=%.4f\n", vw, stats.valAccuracy(3), stats.valAccuracy(5), stats.finalValAccuracy);
        if vw == 0
            base3 = stats.valAccuracy(3); base5 = stats.valAccuracy(5); baseF = stats.finalValAccuracy;
        else
            fprintf("  -> diff vs vw=0: acc3=%+.4f acc5=%+.4f final=%+.4f\n", stats.valAccuracy(3)-base3, stats.valAccuracy(5)-base5, stats.finalValAccuracy-baseF);
        end
    end
end
end

function net = trainA1ep(net, ds, inSz, nc, mb, lr, vw, sEp, lay)
[XT,yT] = deal(ds.taskA.trainX, ds.taskA.trainY);
nTr=size(XT,1); sEp=min(sEp,nTr);
ta=[]; tsq=[]; iter=0;
[Xg,Tg] = TransferLearning.PreUploadCifarToGpu(XT, yT, nc);
ord=randperm(nTr, sEp);
for s=1:mb:sEp
    e=min(s+mb-1,sEp); idx=ord(s:e); iter=iter+1;
    dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
    dlT=dlarray(Tg(:,idx),"CB");
    [gr,~,~,~]=dlfeval(@(n,x,t) sweepLoss(n,x,t,vw,lay),net,dlX,dlT);
    [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
end
end

function stats = trainBshort(net, XTr, yTr, XV, yV, inSz, nc, maxEp, mb, lr, vw, sEp, lay)
nTr=size(XTr,1); sEp=min(sEp,nTr);
ta=[]; tsq=[]; iter=0;
stats.valAccuracy=zeros(maxEp,1);
[Xg,Tg] = TransferLearning.PreUploadCifarToGpu(XTr, yTr, nc);
[dlXV, dlTV] = TransferLearning.PreprocessCifarRows(XV, yV, inSz, nc);
for ep=1:maxEp
    stats.valAccuracy(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
    ord=randperm(nTr, sEp);
    for s=1:mb:sEp
        e=min(s+mb-1,sEp); idx=ord(s:e); iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,~]=dlfeval(@(n,x,t) sweepLoss(n,x,t,vw,lay),net,dlX,dlT);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,lr);
    end
end
stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXV, dlTV, mb);
end

function [gr,lo,ce,vt] = sweepLoss(net,dlX,dlT,vw,lay)
outputs=["fc_logits", lay];
C=cell(1,numel(lay));
[logits, C{:}]=forward(net,dlX,Outputs=outputs);
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
