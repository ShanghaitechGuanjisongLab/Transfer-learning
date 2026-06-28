function ReplotTaskBFirst10()
modelDir = "D:\训练数据\models";

sContinual = load(fullfile(modelDir, "statsB_afterVarA.mat"), "statsB_afterVarA");
sDirect    = load(fullfile(modelDir, "statsB_direct.mat"),      "statsB_direct");
sNoVar     = load(fullfile(modelDir, "statsB_noVar.mat"),       "statsB_noVar");

maxEpochs = 10;
sCont10 = truncateStats(sContinual.statsB_afterVarA, maxEpochs);
sDir10  = truncateStats(sDirect.statsB_direct, maxEpochs);
sNoVar10= truncateStats(sNoVar.statsB_noVar, maxEpochs);

% Continual vs Naive
f1 = TransferLearning.PlotTrainingCurvesCompare(sCont10, sDir10);
TransferLearning.ExportStandardFigure(f1, 2, "TaskB_ContinualVsNaive.svg");
fprintf("Continual vs Naive -> TaskB_ContinualVsNaive.svg\n");

% A-had-var vs A-had-no-var
f2 = TransferLearning.PlotTrainingCurvesCompareVariance(sCont10, sNoVar10, ...
    "A had variance", "A had no variance", ...
    "Task B (MNIST, first 10 epochs): Effect of Variance in Task A");
TransferLearning.ExportStandardFigure(f2, 2, "TaskB_VarianceOnAvsNoVarianceOnA.svg");
fprintf("Variance vs NoVariance -> TaskB_VarianceOnAvsNoVarianceOnA.svg\n");
end

function s = truncateStats(s, n)
s.trainLoss = s.trainLoss(1:n);
s.trainCE = s.trainCE(1:n);
s.trainVar = s.trainVar(1:n);
s.valAccuracy = s.valAccuracy(1:n);
end
