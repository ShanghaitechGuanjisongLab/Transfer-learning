function CleanVarOnB()
% Clean ablation: same TaskA checkpoint -> TaskB with/without variance.
% Also sweeps variance on B only across layer sets and varWeights.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmTrain, ymTrain] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);
[XmVal, ymVal] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "t10k", 0, 20260616);

inputSize=[32 32 3]; numClasses=10; mb=128; epA=5; epB=5; samplesA=500; samplesB=600; lr=1e-3;

% First, train a fixed TaskA with variance (res2-4, vw=0.01)
rng(20260626); gpuDevice(3);
netA = TransferLearning.BuildResNet18Classifier(inputSize, numClasses);
netA = trainTaskAShort(netA, dataset, inputSize, numClasses, epA, mb, lr, 0.01, samplesA, ...
    ["res2b_relu","res3b_relu","res4b_relu"]);

% Checkpoint
checkpointPath = fullfile("D:\训练数据\models", "cleanVar_checkpointA.mat");
save(checkpointPath, "netA", "-v7.3");
fprintf("TaskA checkpoint saved. CIFAR val acc (5ep): check.\n");

% ---- Ablation: variance on TaskB only ----
varianceLayerSets = {
    ["res2b_relu","res3b_relu","res4b_relu"]
    ["res2b_relu","res3b_relu","res4b_relu","res5b_relu"]
    ["res2b_relu","res3b_relu"]
    ["res2b_relu"]
    ["res3b_relu"]
    ["res4b_relu"]
    };
layerSetNames = ["res2-4","res2-5","res2-3","res2only","res3only","res4only"];
varWeights = [0, 0.001, 0.005, 0.01, 0.02, 0.05, 0.1];

nConfigs = numel(varianceLayerSets) * numel(varWeights);
results = table();
configIdx = 0;

for iL = 1:numel(varianceLayerSets)
    layNames = varianceLayerSets{iL};
    layTag = layerSetNames(iL);
    for iV = 1:numel(varWeights)
        vw = varWeights(iV);
        configIdx = configIdx + 1;

        % Reset to checkpoint
        loaded = load(checkpointPath, "netA");
        % Train TaskB with this variance config
        [~, statsB] = trainTaskBShort(loaded.netA, XmTrain, ymTrain, XmVal, ymVal, inputSize, numClasses, epB, mb, lr, vw, samplesB, layNames);

        tag = sprintf("vw=%.3f_%s", vw, layTag);
        results = [results; table(string(tag), vw, layTag, numel(layNames), ...
            statsB.valAccuracy(3), statsB.valAccuracy(5), statsB.finalValAccuracy, ...
            'VariableNames', ["tag","varWeight","layerset","nLayers","B_valAcc3","B_valAcc5","B_finalVal"])]; %#ok<AGROW>

        fprintf("[%d/%d] %s: valAcc3=%.4f valAcc5=%.4f finalVal=%.4f\n", ...
            configIdx, nConfigs, tag, statsB.valAccuracy(3), statsB.valAccuracy(5), statsB.finalValAccuracy);
    end
end

% Baseline (varWeight=0) serves as reference - take from res2-4, vw=0
v0idx = find(results.varWeight==0 & results.layerset=="res2-4", 1);
if ~isempty(v0idx)
    fprintf("\n===== baseline (vw=0, res2-4): valAcc3=%.4f valAcc5=%.4f finalVal=%.4f =====\n", ...
        results.B_valAcc3(v0idx), results.B_valAcc5(v0idx), results.B_finalVal(v0idx));
    results.diff_valAcc3 = results.B_valAcc3 - results.B_valAcc3(v0idx);
    results.diff_valAcc5 = results.B_valAcc5 - results.B_valAcc5(v0idx);
    results.diff_final = results.B_finalVal - results.B_finalVal(v0idx);

    fprintf("\n===== TOP 10 by valAcc5 diff =====\n");
    results = sortrows(results, "diff_valAcc5", "descend");
    disp(results(1:min(10, height(results)), :));
    fprintf("\n===== TOP 10 by valAcc3 diff =====\n");
    results = sortrows(results, "diff_valAcc3", "descend");
    disp(results(1:min(10, height(results)), :));
end

save(fullfile("D:\训练数据\models", "cleanVar_onB_results.mat"), "results", "-v7.3");
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
