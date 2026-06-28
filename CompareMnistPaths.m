function CompareMnistPaths()
dataRoot="D:\训练数据"; rawDir=fullfile(dataRoot,"raw","mnist");

[Xt28,yt]=loadMnistRaw(fullfile(rawDir,"train-images-idx3-ubyte"),fullfile(rawDir,"train-labels-idx1-ubyte"));
[Xte28,yte]=loadMnistRaw(fullfile(rawDir,"t10k-images-idx3-ubyte"),fullfile(rawDir,"t10k-labels-idx1-ubyte"));

gpuDevice(3);

% ---- Path A: 1ch 28x28, normalized, buildMnistClassifier ----
mu=single(0.1307); sig=single(0.3081);
netA=TransferLearning.BuildResNet18MnistClassifier();
trailingA=[]; trailingSqA=[]; iterA=0;
for ep=1:5
    order=randperm(60000); lossGpu=gpuArray(single(0)); bc=0;
    for s=1:100:60000
        e=min(s+99,60000); idx2=order(s:e); iterA=iterA+1; bc=bc+1;
        Xb=gpuArray(single(reshape(Xt28(:,:,idx2),[28 28 1 numel(idx2)])))/255;
        Xb=(Xb-mu)/sig;
        dlX=dlarray(Xb,"SSCB");
        Tb=gpuArray(single(full(sparse(yt(idx2),1:numel(idx2),1,10,numel(idx2)))));
        dlT=dlarray(Tb,"CB");
        [gr,l]=dlfeval(@lossPureCE,netA,dlX,dlT);
        [netA,trailingA,trailingSqA]=adamupdate(netA,gr,trailingA,trailingSqA,iterA,1e-3);
        lossGpu=lossGpu+extractdata(l);
    end
    correct=0;
    for s=1:200:10000
        e=min(s+199,10000); idx2=s:e;
        Xb=gpuArray(single(reshape(Xte28(:,:,idx2),[28 28 1 numel(idx2)])))/255;
        Xb=(Xb-mu)/sig;
        logits=forward(netA,dlarray(Xb,"SSCB"));
        [~,pred]=max(gather(extractdata(logits)),[],1);
        correct=correct+nnz(pred==yte(idx2)');
    end
    fprintf("A_1ch_28x28 Ep%d: loss=%.4f acc=%.4f\n",ep,double(gather(lossGpu))/bc,correct/10000);
end

% ---- Path B: 3ch 32x32, LoadMnistAsCifarFormat + BuildResNet18Classifier ----
TransferLearning.PrepareOfficialMNIST();
[Xrow,yr]=TransferLearning.LoadMnistAsCifarFormat(dataRoot,"train",0.8,20260616);
[XrowV,yv]=TransferLearning.LoadMnistAsCifarFormat(dataRoot,"t10k",0.2,20260616);
[Xgpu,Tgpu]=TransferLearning.PreUploadCifarToGpu(Xrow,yr,10);
[dlXval,dlTval]=TransferLearning.PreprocessCifarRows(XrowV,yv,[32 32 3],10);

netB=TransferLearning.BuildResNet18Classifier([32 32 3],10);
trailingB=[]; trailingSqB=[]; iterB=0; nTrain=size(Xrow,1);
for ep=1:5
    order=randperm(nTrain); lossGpu=gpuArray(single(0)); bc=0;
    for s=1:128:nTrain
        e=min(s+127,nTrain); idx2=order(s:e); iterB=iterB+1; bc=bc+1;
        dlXb=dlarray(single(Xgpu(:,:,:,idx2))/255,"SSCB");
        dlTb=dlarray(Tgpu(:,idx2),"CB");
        [gr,l]=dlfeval(@lossPureCE,netB,dlXb,dlTb);
        [netB,trailingB,trailingSqB]=adamupdate(netB,gr,trailingB,trailingSqB,iterB,1e-3);
        lossGpu=lossGpu+extractdata(l);
    end
    valAcc=TransferLearning.EvaluateClassificationAccuracyDlarray(netB,dlXval,dlTval,128);
    fprintf("B_3ch_32x32_12k Ep%d: loss=%.4f valAcc=%.4f\n",ep,double(gather(lossGpu))/bc,valAcc);
end
end

function [imgs,lbls]=loadMnistRaw(imgFile,lblFile)
fid=fopen(imgFile,"rb"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be");
imgs=fread(fid,inf,"uint8"); fclose(fid);
imgs=permute(reshape(imgs,[28 28 numel(imgs)/(28*28)]),[2 1 3]);
fid=fopen(lblFile,"rb"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be");
lbls=fread(fid,inf,"uint8")+1; fclose(fid);
end

function [gr,loss]=lossPureCE(net,dlX,dlT)
logits=forward(net,dlX);
loss=crossentropy(softmax(logits),dlT,TargetCategories="independent");
gr=dlgradient(loss,net.Learnables);
end
