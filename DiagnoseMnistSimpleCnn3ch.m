function DiagnoseMnistSimpleCnn3ch()
% Verify whether RGB-replicated MNIST data itself is learnable.
% A simple 3-channel CNN should reach high MNIST accuracy in 5 epochs.

dataRoot = "D:\训练数据";
TransferLearning.PrepareOfficialMNIST();
gpuDevice(3);

[Xtrain, ytrain, Xtest, ytest] = loadMnistRaw(dataRoot);
numTrain = size(Xtrain,3); numTest = size(Xtest,3);
mu = single(0.1307); sig = single(0.3081);

Xtrain4 = reshape(Xtrain, [28 28 1 numTrain]);
Xtest4 = reshape(Xtest, [28 28 1 numTest]);
Xtrain3 = gpuArray(single(repmat(Xtrain4, [1 1 3 1])));
Xtest3 = gpuArray(single(repmat(Xtest4, [1 1 3 1])));

layers = [
    imageInputLayer([28 28 3], Normalization="none", Name="in")
    convolution2dLayer(5, 16, Padding="same", Name="conv1")
    batchNormalizationLayer(Name="bn1")
    reluLayer(Name="relu1")
    maxPooling2dLayer(2, Stride=2, Name="pool1")
    convolution2dLayer(5, 32, Padding="same", Name="conv2")
    batchNormalizationLayer(Name="bn2")
    reluLayer(Name="relu2")
    maxPooling2dLayer(2, Stride=2, Name="pool2")
    fullyConnectedLayer(128, Name="fc1")
    reluLayer(Name="relu3")
    fullyConnectedLayer(10, Name="fc_logits")
    ];
net = dlnetwork(layerGraph(layers));

maxEpochs=5; batchSize=100; learnRate=1e-3;
trailingAvg=[]; trailingAvgSq=[]; iter=0;
for epoch=1:maxEpochs
    order=randperm(numTrain); epochLoss=single(0); batchCount=0;
    for startIdx=1:batchSize:numTrain
        endIdx=min(startIdx+batchSize-1,numTrain);
        idx=order(startIdx:endIdx);
        iter=iter+1; batchCount=batchCount+1;
        Xb=(Xtrain3(:,:,:,idx)/255-mu)/sig;
        dlX=dlarray(Xb,"SSCB");
        Tb=gpuArray(zeros(10,numel(idx),"single"));
        lin=sub2ind([10 numel(idx)], ytrain(idx)', 1:numel(idx));
        Tb(lin)=1;
        dlT=dlarray(Tb,"CB");
        [gr,loss]=dlfeval(@pureCELoss,net,dlX,dlT);
        [net,trailingAvg,trailingAvgSq]=adamupdate(net,gr,trailingAvg,trailingAvgSq,iter,learnRate);
        epochLoss=epochLoss+extractdata(loss);
    end
    correct=0;
    for startIdx=1:batchSize:numTest
        endIdx=min(startIdx+batchSize-1,numTest);
        idx=startIdx:endIdx;
        Xb=(Xtest3(:,:,:,idx)/255-mu)/sig;
        logits=forward(net,dlarray(Xb,"SSCB"));
        [~,pred]=max(gather(extractdata(logits)),[],1);
        correct=correct+nnz(pred==ytest(idx)');
    end
    acc=correct/numTest;
    fprintf("[SimpleCNN-3ch] Epoch %d/%d | loss=%.4f | testAcc=%.4f\n",epoch,maxEpochs,double(gather(epochLoss))/batchCount,acc);
end
end

function [gr,loss]=pureCELoss(net,dlX,dlT)
logits=forward(net,dlX);
loss=crossentropy(softmax(logits),dlT,TargetCategories="independent");
gr=dlgradient(loss,net.Learnables);
end

function [Xtrain,ytrain,Xtest,ytest]=loadMnistRaw(dataRoot)
rawDir=fullfile(dataRoot,"raw","mnist");
fid=fopen(fullfile(rawDir,"train-images-idx3-ubyte"),"rb");
fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be");
imgs=fread(fid,inf,"uint8"); fclose(fid);
Xtrain=permute(reshape(imgs,[28 28 60000]),[2 1 3]);
fid=fopen(fullfile(rawDir,"train-labels-idx1-ubyte"),"rb");
fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be");
ytrain=fread(fid,inf,"uint8")+1; fclose(fid);
fid=fopen(fullfile(rawDir,"t10k-images-idx3-ubyte"),"rb");
fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be");
imgs=fread(fid,inf,"uint8"); fclose(fid);
Xtest=permute(reshape(imgs,[28 28 10000]),[2 1 3]);
fid=fopen(fullfile(rawDir,"t10k-labels-idx1-ubyte"),"rb");
fread(fid,1,"int32",0,"ieee-be"); fread(fid,1,"int32",0,"ieee-be");
ytest=fread(fid,inf,"uint8")+1; fclose(fid);
end
