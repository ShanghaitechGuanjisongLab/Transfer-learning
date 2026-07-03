function CheckPosNegWeightVar()
% Check whether positive and negative weight variances change separately.
% TaskA CIFAR: vw=0 vs vw=500, pos/neg geomean weight variance.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);

cfg.inputSize = [32 32 3]; cfg.numClasses = 10; cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3; cfg.maxEpochsA = 100; cfg.samplesPerEpochA = 500;
cfg.varWeightA = 500;
cfg.weightLayerPrefixes = ["res2b", "res3b", "res4b"];
seed = 20260711;
gpuDevice(3);

rng(seed);
[Xg, Tg] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, cfg.numClasses);

net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
initialStats = measurePosNeg(net0, cfg.weightLayerPrefixes);
net0 = trainTaskA(net0, Xg, Tg, cfg, 0);
stats0 = measurePosNeg(net0, cfg.weightLayerPrefixes);

rng(seed);
net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
net1 = trainTaskA(net1, Xg, Tg, cfg, cfg.varWeightA);
stats1 = measurePosNeg(net1, cfg.weightLayerPrefixes);

fprintf("\n=== Pos/Neg Weight Variance by Tensor ===\n");
fprintf("%-24s  %-10s  %-12s  %-12s  %-12s\n", "Layer", "Sign", "Initial", "vw=0", "vw=500");
for i = 1:height(initialStats)
    fprintf("%-24s  %-10s  %.6e  %.6e  %.6e\n", ...
        initialStats.Layer(i), initialStats.Sign(i), initialStats.Var(i), stats0.Var(i), stats1.Var(i));
end

fprintf("\n=== Summary ===\n");
for signName = ["positive", "negative"]
    rows = initialStats.Sign == signName;
    fprintf("%s mean: initial=%.6e  vw=0=%.6e  vw=500=%.6e  diff(vw500-vw0)=%+.6e\n", ...
        signName, mean(initialStats.Var(rows)), mean(stats0.Var(rows)), mean(stats1.Var(rows)), mean(stats1.Var(rows)-stats0.Var(rows)));
end
fprintf("geomean: initial=%.6e  vw=0=%.6e  vw=500=%.6e\n", geomean(initialStats.Var), geomean(stats0.Var), geomean(stats1.Var));
end

function net = trainTaskA(net, Xg, Tg, cfg, varWeight)
nTrain = size(Xg, 4);
samplesPerEpoch = min(cfg.samplesPerEpochA, nTrain);
trailingAvg = [];
trailingAvgSq = [];
iteration = 0;
for epoch = 1:cfg.maxEpochsA
    order = randperm(nTrain, samplesPerEpoch);
    for startIdx = 1:cfg.miniBatchSize:samplesPerEpoch
        endIdx = min(startIdx + cfg.miniBatchSize - 1, samplesPerEpoch);
        batchIdx = order(startIdx:endIdx);
        iteration = iteration + 1;
        dlX = dlarray(single(Xg(:,:,:,batchIdx)) / 255, "SSCB");
        dlT = dlarray(Tg(:, batchIdx), "CB");
        [gradients, ~] = dlfeval(@lossWeightVar, net, dlX, dlT, varWeight, cfg.weightLayerPrefixes);
        [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, trailingAvg, trailingAvgSq, iteration, cfg.learnRate);
    end
end
end

function stats = measurePosNeg(net, layerPrefixes)
learnables = net.Learnables;
layers = strings(0,1);
signs = strings(0,1);
vars = zeros(0,1);
for layerIdx = 1:numel(layerPrefixes)
    prefix = layerPrefixes(layerIdx);
    for paramIdx = 1:height(learnables)
        paramLayer = string(learnables.Layer(paramIdx));
        paramName = string(learnables.Parameter(paramIdx));
        if startsWith(paramLayer, prefix) && endsWith(paramName, "Weights")
            W = learnables.Value{paramIdx};
            positiveWeights = W(W > 0);
            negativeWeights = W(W < 0);
            layers(end+1,1) = paramLayer; %#ok<AGROW>
            signs(end+1,1) = "positive"; %#ok<AGROW>
            vars(end+1,1) = double(var(positiveWeights(:))); %#ok<AGROW>
            layers(end+1,1) = paramLayer; %#ok<AGROW>
            signs(end+1,1) = "negative"; %#ok<AGROW>
            vars(end+1,1) = double(var(negativeWeights(:))); %#ok<AGROW>
        end
    end
end
stats = table(layers, signs, vars, 'VariableNames', ["Layer", "Sign", "Var"]);
end

function [gradients, loss] = lossWeightVar(net, dlX, dlT, varWeight, layerPrefixes)
logits = forward(net, dlX, Outputs="fc_logits");
probabilities = softmax(logits);
ceLoss = crossentropy(probabilities, dlT, TargetCategories="independent");
learnables = net.Learnables;
allVars = [];
for layerIdx = 1:numel(layerPrefixes)
    prefix = layerPrefixes(layerIdx);
    for paramIdx = 1:height(learnables)
        paramLayer = string(learnables.Layer(paramIdx));
        paramName = string(learnables.Parameter(paramIdx));
        if startsWith(paramLayer, prefix) && endsWith(paramName, "Weights")
            W = learnables.Value{paramIdx};
            positiveWeights = W(W > 0);
            negativeWeights = W(W < 0);
            allVars(end+1) = var(positiveWeights(:)); %#ok<AGROW>
            allVars(end+1) = var(negativeWeights(:)); %#ok<AGROW>
        end
    end
end
varTerm = geomean(allVars);
loss = ceLoss / (1 + varWeight * varTerm);
gradients = dlgradient(loss, net.Learnables);
end
