function dataset = LoadCifar10TaskABInMemory(dataRoot, taskAValRatio, taskBTrainRatio, randomSeed)
extractDir = fullfile(dataRoot, "raw", "cifar10", "cifar-10-batches-mat");
meta = load(fullfile(extractDir, "batches.meta.mat"));
classNames = string(meta.label_names);

rng(randomSeed);

Xtrain = [];
ytrain = [];
for b = 1:5
    S = load(fullfile(extractDir, sprintf("data_batch_%d.mat", b)));
    Xtrain = [Xtrain; S.data]; %#ok<AGROW>
    ytrain = [ytrain; double(S.labels) + 1]; %#ok<AGROW>
end

[XaTrain, yaTrain, XaVal, yaVal] = splitByClass(Xtrain, ytrain, numel(classNames), taskAValRatio, true);

Stest = load(fullfile(extractDir, "test_batch.mat"));
Xtest = Stest.data;
ytest = double(Stest.labels) + 1;

[XbTrain, ybTrain, XbVal, ybVal] = splitByClass(Xtest, ytest, numel(classNames), taskBTrainRatio, false);

dataset.classNames = classNames;
dataset.taskA.trainX = XaTrain;
dataset.taskA.trainY = yaTrain;
dataset.taskA.valX = XaVal;
dataset.taskA.valY = yaVal;
dataset.taskB.trainX = XbTrain;
dataset.taskB.trainY = ybTrain;
dataset.taskB.valX = XbVal;
dataset.taskB.valY = ybVal;
end

function [XtrainOut, ytrainOut, XvalOut, yvalOut] = splitByClass(X, y, numClasses, ratio, isValRatio)
trainListX = cell(numClasses, 1);
trainListY = cell(numClasses, 1);
valListX = cell(numClasses, 1);
valListY = cell(numClasses, 1);

for ci = 1:numClasses
    idx = find(y == ci);
    idx = idx(randperm(numel(idx)));

    if isValRatio
        nVal = round(ratio * numel(idx));
        valIdx = idx(1:nVal);
        trainIdx = idx(nVal+1:end);
    else
        nTrain = round(ratio * numel(idx));
        trainIdx = idx(1:nTrain);
        valIdx = idx(nTrain+1:end);
    end

    trainListX{ci} = X(trainIdx, :);
    trainListY{ci} = y(trainIdx);
    valListX{ci} = X(valIdx, :);
    valListY{ci} = y(valIdx);
end

XtrainOut = vertcat(trainListX{:});
ytrainOut = vertcat(trainListY{:});
XvalOut = vertcat(valListX{:});
yvalOut = vertcat(valListY{:});
end
