function dataset = LoadCifar10TaskABInMemory(dataRoot)
% Task A uses official CIFAR-10 splits: 5 train batches (50k), test_batch (10k).
extractDir = fullfile(dataRoot, "raw", "cifar10", "cifar-10-batches-mat");
meta = load(fullfile(extractDir, "batches.meta.mat"));
classNames = string(meta.label_names);

Xtrain = [];
ytrain = [];
for b = 1:5
    S = load(fullfile(extractDir, sprintf("data_batch_%d.mat", b)));
    Xtrain = [Xtrain; S.data]; %#ok<AGROW>
    ytrain = [ytrain; double(S.labels) + 1]; %#ok<AGROW>
end

Stest = load(fullfile(extractDir, "test_batch.mat"));
Xval = Stest.data;
yval = double(Stest.labels) + 1;

dataset.classNames = classNames;
dataset.taskA.trainX = Xtrain;
dataset.taskA.trainY = ytrain;
dataset.taskA.valX = Xval;
dataset.taskA.valY = yval;
end
