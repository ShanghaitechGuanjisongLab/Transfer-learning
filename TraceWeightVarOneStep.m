function TraceWeightVarOneStep()
% One-batch diagnostic for weight-variance regularization.
% Decomposes gradient of L = CE/(1 + lambda * VarTerm) into CE and VarTerm channels.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);

cfg.inputSize = [32 32 3];
cfg.numClasses = 10;
cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3;
cfg.varWeight = 500;
cfg.weightLayerPrefixes = ["res2b", "res3b", "res4b"];

rng(20260703);
gpuDevice(3);
[Xg, Tg] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, cfg.numClasses);
net = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);

batchIdx = randperm(size(Xg, 4), cfg.miniBatchSize);
dlX = dlarray(single(Xg(:,:,:,batchIdx)) / 255, "SSCB");
dlT = dlarray(Tg(:, batchIdx), "CB");

[ceLoss, varTerm, loss] = dlfeval(@evalScalars, net, dlX, dlT, cfg.varWeight, cfg.weightLayerPrefixes);
gradCE = dlfeval(@gradCEOnly, net, dlX, dlT);
gradVar = dlfeval(@gradVarOnly, net, dlX, cfg.weightLayerPrefixes);
gradLoss = dlfeval(@gradLossCombined, net, dlX, dlT, cfg.varWeight, cfg.weightLayerPrefixes);
ceValue = double(gather(extractdata(ceLoss)));
varValue = double(gather(extractdata(varTerm)));
lossValue = double(gather(extractdata(loss)));
denominator = 1 + cfg.varWeight * varValue;
beta = 1 / denominator;
alpha = ceValue * cfg.varWeight / denominator^2;

fprintf("=== One-batch weight-var trace ===\n");
fprintf("CE=%.6f  VarTerm=%.9f  lambda=%g  denominator=%.6f  loss=%.6f\n", ceValue, varValue, cfg.varWeight, denominator, lossValue);
fprintf("Gradient coefficients: beta=1/denom=%.6f, alpha=CE*lambda/denom^2=%.6f\n\n", beta, alpha);

summarizeGradients(net, gradCE, gradVar, gradLoss, cfg.weightLayerPrefixes, beta, alpha);

% Simulate one Adam step from the same initial network.
netCE = adamupdate(net, gradCE, [], [], 1, cfg.learnRate);
netWV = adamupdate(net, gradLoss, [], [], 1, cfg.learnRate);
varInitial = measureWeightVarTerm(net, cfg.weightLayerPrefixes);
varAfterCE = measureWeightVarTerm(netCE, cfg.weightLayerPrefixes);
varAfterWV = measureWeightVarTerm(netWV, cfg.weightLayerPrefixes);

fprintf("\n=== One Adam step effect on VarTerm ===\n");
fprintf("initial: %.9f\n", varInitial);
fprintf("CE only: %.9f  delta=%+.9f\n", varAfterCE, varAfterCE - varInitial);
fprintf("CE + weight-var: %.9f  delta=%+.9f\n", varAfterWV, varAfterWV - varInitial);
fprintf("extra delta from weight-var channel: %+.9f\n", (varAfterWV - varInitial) - (varAfterCE - varInitial));
end

function [ceLoss, varTerm, loss] = evalScalars(net, dlX, dlT, varWeight, prefixes)
logits = forward(net, dlX, Outputs="fc_logits");
probabilities = softmax(logits);
ceLoss = crossentropy(probabilities, dlT, TargetCategories="independent");
varTerm = weightVarTerm(net, prefixes);
loss = ceLoss / (1 + varWeight * varTerm);
end

function gradCE = gradCEOnly(net, dlX, dlT)
logits = forward(net, dlX, Outputs="fc_logits");
probabilities = softmax(logits);
ceLoss = crossentropy(probabilities, dlT, TargetCategories="independent");
gradCE = dlgradient(ceLoss, net.Learnables);
end

function gradVar = gradVarOnly(net, dlX, prefixes)
logits = forward(net, dlX, Outputs="fc_logits");
varTerm = weightVarTerm(net, prefixes);
dummy = 0 * sum(logits, "all");
gradVar = dlgradient(varTerm + dummy, net.Learnables);
end

function gradLoss = gradLossCombined(net, dlX, dlT, varWeight, prefixes)
logits = forward(net, dlX, Outputs="fc_logits");
probabilities = softmax(logits);
ceLoss = crossentropy(probabilities, dlT, TargetCategories="independent");
varTerm = weightVarTerm(net, prefixes);
loss = ceLoss / (1 + varWeight * varTerm);
gradLoss = dlgradient(loss, net.Learnables);
end

function varTerm = weightVarTerm(net, prefixes)
learnables = net.Learnables;
allVars = [];
for layerIdx = 1:numel(prefixes)
    prefix = prefixes(layerIdx);
    for paramIdx = 1:height(learnables)
        layerName = string(learnables.Layer(paramIdx));
        paramName = string(learnables.Parameter(paramIdx));
        if startsWith(layerName, prefix) && endsWith(paramName, "Weights")
            weights = learnables.Value{paramIdx};
            positiveWeights = weights(weights > 0);
            negativeWeights = weights(weights < 0);
            allVars(end+1) = var(positiveWeights(:)); %#ok<AGROW>
            allVars(end+1) = var(negativeWeights(:)); %#ok<AGROW>
        end
    end
end
varTerm = geomean(allVars);
end

function scalarValue = measureWeightVarTerm(net, prefixes)
scalarValue = double(gather(extractdata(weightVarTerm(net, prefixes))));
end

function summarizeGradients(net, gradCE, gradVar, gradLoss, prefixes, beta, alpha)
learnables = net.Learnables;
rows = strings(0, 1);
normCE = zeros(0, 1);
normVar = zeros(0, 1);
normLoss = zeros(0, 1);
ratioDirectToCE = zeros(0, 1);
projectionCE = zeros(0, 1);
projectionDirect = zeros(0, 1);
projectionTotal = zeros(0, 1);
cosLossVar = zeros(0, 1);

for paramIdx = 1:height(learnables)
    layerName = string(learnables.Layer(paramIdx));
    paramName = string(learnables.Parameter(paramIdx));
    if ~endsWith(paramName, "Weights") || ~matchesPrefix(layerName, prefixes)
        continue
    end

    gCE = toColumn(gradCE.Value{paramIdx});
    gVar = toColumn(gradVar.Value{paramIdx});
    gLoss = toColumn(gradLoss.Value{paramIdx});

    nCE = norm(gCE);
    nVar = norm(gVar);
    nLoss = norm(gLoss);
    ceProj = -beta * dot(gVar, gCE);
    directProj = alpha * dot(gVar, gVar);
    totalProj = -dot(gVar, gLoss);
    cosLV = dot(gLoss, gVar) / (nLoss * nVar + eps);

    rows(end+1, 1) = layerName; %#ok<AGROW>
    normCE(end+1, 1) = nCE; %#ok<AGROW>
    normVar(end+1, 1) = nVar; %#ok<AGROW>
    normLoss(end+1, 1) = nLoss; %#ok<AGROW>
    ratioDirectToCE(end+1, 1) = (alpha * nVar) / (beta * nCE + eps); %#ok<AGROW>
    projectionCE(end+1, 1) = ceProj; %#ok<AGROW>
    projectionDirect(end+1, 1) = directProj; %#ok<AGROW>
    projectionTotal(end+1, 1) = totalProj; %#ok<AGROW>
    cosLossVar(end+1, 1) = cosLV; %#ok<AGROW>
end

tableOut = table(rows, normCE, normVar, normLoss, ratioDirectToCE, projectionCE, projectionDirect, projectionTotal, cosLossVar, ...
    'VariableNames', ["Layer", "normCE", "normVar", "normLoss", "directNormOverCE", "CEprojOnVar", "directVarProj", "totalUpdateProj", "cosGradLossVar"]);
disp(tableOut);

fprintf("=== Aggregate over targeted weights ===\n");
fprintf("sum normCE=%.6e, sum normVar=%.6e, sum normLoss=%.6e\n", sum(normCE), sum(normVar), sum(normLoss));
fprintf("mean directNorm/CE norm ratio=%.6e\n", mean(ratioDirectToCE));
fprintf("sum CE projection on var direction=%+.6e\n", sum(projectionCE));
fprintf("sum direct var projection=%+.6e\n", sum(projectionDirect));
fprintf("sum total update projection=%+.6e\n", sum(projectionTotal));
end

function tf = matchesPrefix(layerName, prefixes)
tf = false;
for prefixIdx = 1:numel(prefixes)
    if startsWith(layerName, prefixes(prefixIdx))
        tf = true;
        return
    end
end
end

function values = toColumn(x)
values = gather(extractdata(x));
values = double(values(:));
end
