% Fig382C model-simulated Naive/Continual learning curve with sigmoid fits.

svgName = '中文图Fig382C_ModelNaiveContinualLearningCurve.svg';
iEnsureTransferLearningProject();

if evalin('base', 'exist(''Fig38C_ModelLearningCurveSeedBase'', ''var'')')
	seedBase = evalin('base', 'Fig38C_ModelLearningCurveSeedBase');
elseif evalin('base', 'exist(''THRandomSeed'', ''var'')')
	seedBase = evalin('base', 'THRandomSeed');
else
	seedBase = 38238302;
end

Params = TransferLearning.THModel.DefaultParams();
Params = TransferLearning.THModel.ApplyBaseParameterOverrides(Params);
Cond = TransferLearning.THModel.ConditionTable();
[Performance, RunInfo] = TransferLearning.THModel.SimulateConditionLearningCurves(Params, Cond, ["Naive", "Transfer"], OutputNames=["Naive", "Continual"], SeedBase=seedBase);
iAssertPretrainReached(RunInfo, "Continual", 'Fig382C:PretrainDidNotReachCeiling');
naivePerformance = Performance.Naive;
continualPerformance = Performance.Continual;

[fig, SigmoidStats] = TransferLearning.PlotSigmoidLearningCurvePanels( ...
	naivePerformance, continualPerformance, ...
	"Naive", "Transfer", "Naive", "Continual", ...
	FigureName="Fig382C model Naive Continual sigmoid", ...
	FigureSizeCm=[9, 8], ...
	Scale=2, ...
	NPermutation=0);

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(fig, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382C_ModelNaiveContinualPerformance', struct('Naive', naivePerformance, 'Continual', continualPerformance));
assignin('base', 'Fig382C_ModelNaiveContinualRunInfo', RunInfo);
assignin('base', 'Fig382C_ModelNaiveContinualSigmoidStats', SigmoidStats);

function iEnsureTransferLearningProject()
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end
end

function iAssertPretrainReached(RunInfo, conditionLabel, errorId)
reachedVariableName = conditionLabel + "PretrainReached";
pretrainReached = RunInfo.(reachedVariableName);
if ~all(pretrainReached)
	failedMice = find(~pretrainReached);
	error(errorId, '%s pretraining failed for %d/%d mice. First failed mouse index: %d.', conditionLabel, numel(failedMice), height(RunInfo), failedMice(1));
end
end
