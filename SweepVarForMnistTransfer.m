function SweepVarForMnistTransfer()
% Sweep variance configs to maximize TaskB learning advantage.
% For each config: train TaskA(5ep), then TaskB(5ep) with var and without var.
% Metric: val accuracy of TaskB at epoch 5, difference (var - noVar).

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTrain, ymTrain] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inputSize = [32 32 3]; numClasses = 10;
mb = 128; epA = 5; epB = 5; samplesA = 500; samplesB = 600; lr = 1e-3;

varianceLayerSets = {
    ["res2b_relu","res3b_relu","res4b_relu"]
    ["res2b_relu","res3b_relu","res4b_relu","res5b_relu"]
    ["res2b_relu","res3b_relu"]
    ["res3b_relu","res4b_relu"]
    ["res2b_relu"]
    ["res3b_relu"]
    ["res4b_relu"]
    };
layerSetNames = ["res2-4","res2-5","res2-3","res3-4","res2only","res3only","res4only"];
varWeights = [0.001, 0.005, 0.01, 0.02, 0.05, 0.1];

nConfigs = numel(varianceLayerSets) * numel(varWeights);
results = table();
rng(20260626); gpuDevice(3);
configIdx = 0;

for iL = 1:numel(varianceLayerSets)
    layNames = varianceLayerSets{iL};
    layTag = layerSetNames(iL);
    for iV = 1:numel(varWeights)
        vw = varWeights(iV);
        configIdx = configIdx + 1;
        tag = sprintf("vw=%.3f_%s", vw, layTag);

        % Train TaskA with variance
        netVar = TransferLearning.BuildResNet18Classifier(inputSize, numClasses);
        netVar = trainTaskAShort(netVar, dataset, inputSize, numClasses, epA, mb, lr, vw, samplesA, layNames);

        % Train TaskB with variance on top
        [~, statsBVar] = trainTaskBShort(netVar, XmTrain, ymTrain, XmVal, ymVal, inputSize, numClasses, epB, mb, lr, vw, samplesB, layNames);

        % Train TaskA without variance (baseline)
        netNo = TransferLearning.BuildResNet18Classifier(inputSize, numClasses);
        netNo = trainTaskAShort(netNo, dataset, inputSize, numClasses, epA, mb, lr, 0, samplesA, layNames);

        % Train TaskB without variance
        [~, statsBNo] = trainTaskBShort(netNo, XmTrain, ymTrain, XmVal, ymVal, inputSize, numClasses, epB, mb, lr, 0, samplesB, layNames);

        accVar = statsBVar.valAccuracy(end);
        accNo = statsBNo.valAccuracy(end);
        diff = accVar - accNo;
        finalAccVar = statsBVar.finalValAccuracy;
        finalAccNo = statsBNo.finalValAccuracy;
        diffFinal = finalAccVar - finalAccNo;

        results = [results; table(string(tag), vw, layTag, numel(layNames), accVar, accNo, diff, finalAccVar, finalAccNo, diffFinal, ...
            'VariableNames', ["tag","varWeight","layerset","nLayers","B_preVal5_Var","B_preVal5_No","B_diff_preVal","B_finalVar","B_finalNo","B_diff_final"])]; %#ok<AGROW>

        fprintf("[%d/%d] %s: preVal5 Var=%.4f No=%.4f diff=%.5f | final Var=%.4f No=%.4f diff=%.5f\n", ...
            configIdx, nConfigs, tag, accVar, accNo, diff, finalAccVar, finalAccNo, diffFinal);
    end
end

fprintf("\n===== TOP 10 by B_preVal5 diff (var-noVar) =====\n");
results = sortrows(results, "B_diff_preVal", "descend");
disp(results(1:min(10, height(results)), :));
fprintf("\n===== TOP 10 by B_final diff =====\n");
results = sortrows(results, "B_diff_final", "descend");
disp(results(1:min(10, height(results)), :));
save(fullfile("D:\训练数据\models", "sweep_variance_mnist_results.mat"), "results", "-v7.3");
end

function net = trainTaskAShort(net, dataset, inputSize, numClasses, maxEpochs, mb, lr, varWeight, samplesPerEp, varianceLayers)
[XTrain, yTrain] = deal(dataset.taskA.trainX, dataset.taskA.trainY);
numTrain = size(XTrain,1); samplesPerEp = min(samplesPerEp, numTrain);
trailingAvg=[]; trailingSq=[]; iter=0;
[Xgpu, Tgpu] = TransferLearning.PreUploadCifarToGpu(XTrain, yTrain, numClasses);
for ep=1:maxEpochs
    order=randperm(numTrain, samplesPerEp);
    for s=1:mb:samplesPerEp
        e=min(s+mb-1,samplesPerEp); idx=order(s:e); iter=iter+1;
        dlXb=dlarray(single(Xgpu(:,:,:,idx))/255,"SSCB");
        dlTb=dlarray(Tgpu(:,idx),"CB");
        [gr,~,~,~]=dlfeval(@(n,x,t) iSweepLoss(n,x,t,varWeight,varianceLayers),net,dlXb,dlTb);
        [net,trailingAvg,trailingSq]=adamupdate(net,gr,trailingAvg,trailingSq,iter,lr);
    end
end
end

function [net, stats] = trainTaskBShort(net, XTrain, yTrain, XVal, yVal, inputSize, numClasses, maxEpochs, mb, lr, varWeight, samplesPerEp, varianceLayers)
numTrain = size(XTrain,1); samplesPerEp = min(samplesPerEp, numTrain);
trailingAvg=[]; trailingSq=[]; iter=0;
stats.valAccuracy=zeros(maxEpochs,1);
[Xgpu, Tgpu] = TransferLearning.PreUploadCifarToGpu(XTrain, yTrain, numClasses);
[dlXval, dlTval] = TransferLearning.PreprocessCifarRows(XVal, yVal, inputSize, numClasses);
for ep=1:maxEpochs
    stats.valAccuracy(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net, dlXval, dlTval, mb);
    order=randperm(numTrain, samplesPerEp);
    for s=1:mb:samplesPerEp
        e=min(s+mb-1,samplesPerEp); idx=order(s:e); iter=iter+1;
        dlXb=dlarray(single(Xgpu(:,:,:,idx))/255,"SSCB");
        dlTb=dlarray(Tgpu(:,idx),"CB");
        [gr,~,~,~]=dlfeval(@(n,x,t) iSweepLoss(n,x,t,varWeight,varianceLayers),net,dlXb,dlTb);
        [net,trailingAvg,trailingSq]=adamupdate(net,gr,trailingAvg,trailingSq,iter,lr);
    end
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
