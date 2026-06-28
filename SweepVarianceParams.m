function SweepVarianceParams()
dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
inputSize = [32 32 3]; numClasses = 10;
mb = 128; maxEpochs = 5; samplesPerEp = 500; lr = 1e-3;

varWeights = [0, 0.001, 0.01, 0.05, 0.1, 0.5];
varianceLayerSets = {
    ["res2b_relu","res3b_relu","res4b_relu"]
    ["res2b_relu","res3b_relu","res4b_relu","res5b_relu"]
    ["res2a_relu","res2b_relu","res3a_relu","res3b_relu","res4a_relu","res4b_relu","res5a_relu","res5b_relu"]
    ["res2b_relu"]
    ["res3b_relu"]
    ["res4b_relu"]
    ["res5b_relu"]
    };
layerSetNames = ["res2-4","res2-5","all8","res2only","res3only","res4only","res5only"];

nConfigs = numel(varWeights) * numel(varianceLayerSets);
results = table();
rng(20260626); gpuDevice(3);

configIdx = 0;
for iV = 1:numel(varWeights)
    vw = varWeights(iV);
    for iL = 1:numel(varianceLayerSets)
        configIdx = configIdx + 1;
        layNames = varianceLayerSets{iL};
        layTag = layerSetNames(iL);
        tag = sprintf("vw=%.3f_%s", vw, layTag);

        net = TransferLearning.BuildResNet18Classifier(inputSize, numClasses);
        [stats] = trainTaskASweep(net, dataset, inputSize, numClasses, ...
            maxEpochs, mb, lr, vw, samplesPerEp, layNames);

        results = [results; table(string(tag), vw, layTag, numel(layNames), ...
            stats.valAccuracy(end), stats.finalValAccuracy, mean(stats.trainVar), stats.trainVar(end), ...
            'VariableNames', ["tag","varWeight","layerset","nLayers","lastPreVal","finalVal","meanVar","finalVar"])]; %#ok<AGROW>

        fprintf("[%d/%d] %s: lastPreVal=%.4f finalVal=%.4f meanVar=%.4f finalVar=%.4f\n", ...
            configIdx, nConfigs, tag, stats.valAccuracy(end), stats.finalValAccuracy, ...
            mean(stats.trainVar), stats.trainVar(end));
    end
end

fprintf("\n===== TOP 10 by finalVal =====\n");
results = sortrows(results, "finalVal", "descend");
disp(results(1:min(10, height(results)), :));
fprintf("\n===== TOP 10 by meanVar =====\n");
results2 = sortrows(results, "meanVar", "descend");
disp(results2(1:min(10, height(results2)), :));
save(fullfile("D:\训练数据\models", "sweep_variance_results.mat"), "results", "-v7.3");
end

function [stats] = trainTaskASweep(net, dataset, inputSize, numClasses, maxEpochs, mb, lr, varWeight, samplesPerEp, varianceLayers)
[XTrain, yTrain] = deal(dataset.taskA.trainX, dataset.taskA.trainY);
[XVal, yVal] = deal(dataset.taskA.valX, dataset.taskA.valY);
numTrain = size(XTrain,1); samplesPerEp = min(samplesPerEp, numTrain);
trailingAvg=[]; trailingSq=[]; iter=0;
stats.trainLoss=zeros(maxEpochs,1); stats.trainCE=zeros(maxEpochs,1);
stats.trainVar=zeros(maxEpochs,1); stats.valAccuracy=zeros(maxEpochs,1);
[Xgpu, Tgpu] = TransferLearning.PreUploadCifarToGpu(XTrain, yTrain, numClasses);
[dlXval, dlTval] = TransferLearning.PreprocessCifarRows(XVal, yVal, inputSize, numClasses);
for ep=1:maxEpochs
    stats.valAccuracy(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXval, dlTval, mb);
    order=randperm(numTrain, samplesPerEp);
    lossG=gpuArray(single(0)); ceG=gpuArray(single(0)); varG=gpuArray(single(0)); bc=0;
    for s=1:mb:samplesPerEp
        e=min(s+mb-1,samplesPerEp); idx=order(s:e); iter=iter+1; bc=bc+1;
        dlXb=dlarray(single(Xgpu(:,:,:,idx))/255,"SSCB");
        dlTb=dlarray(Tgpu(:,idx),"CB");
        [gr,lo,ce,vt]=dlfeval(@(n,x,t) iSweepLoss(n,x,t,varWeight,varianceLayers),net,dlXb,dlTb);
        [net,trailingAvg,trailingSq]=adamupdate(net,gr,trailingAvg,trailingSq,iter,lr);
        lossG=lossG+extractdata(lo); ceG=ceG+extractdata(ce); varG=varG+extractdata(vt);
    end
    stats.trainLoss(ep)=double(gather(lossG))/bc;
    stats.trainCE(ep)=double(gather(ceG))/bc;
    stats.trainVar(ep)=double(gather(varG))/bc;
end
stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXval, dlTval, mb);
end

function [gr,lo,ce,vt] = iSweepLoss(net,dlX,dlT,varWeight,varianceLayers)
outputs=["fc_logits", varianceLayers];
C=cell(1,numel(varianceLayers));
[logits, C{:}]=forward(net,dlX,Outputs=outputs);
probs=softmax(logits);
ceLoss=crossentropy(probs,dlT,TargetCategories="independent");
varVals=zeros(1,numel(varianceLayers),"like",C{1});
for i=1:numel(varianceLayers)
    Xflat=reshape(stripdims(C{i}),[],size(C{i},4));
    varVals(i)=mean(var(Xflat,0,2),"all");
end
vt=mean(varVals,"all");
lo=ceLoss/(1+varWeight*vt);
gr=dlgradient(lo,net.Learnables);
ce=ceLoss;
end
