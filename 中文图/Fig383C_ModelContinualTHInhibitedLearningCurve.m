% Fig383C model-simulated Continual/TH inhibited learning curve with sigmoid fits.

svgName = '中文图Fig383C_ModelContinualTHInhibitedLearningCurve.svg';
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
[Performance, RunInfo] = TransferLearning.THModel.SimulateConditionLearningCurves(Params, Cond, ["Transfer", "THOff"], OutputNames=["Continual", "THInhibited"], SeedBase=seedBase);
iAssertAllPretrained(RunInfo);
continualPerformance = Performance.Continual;
thInhibitedPerformance = Performance.THInhibited;

[fig, SigmoidStats] = TransferLearning.PlotSigmoidLearningCurvePanels( ...
	continualPerformance, thInhibitedPerformance, ...
	"Transfer", "THOff", "Continual", "TH inhibited", ...
	FigureName="Fig383C model Continual TH inhibited sigmoid", ...
	FigureSizeCm=[9, 8], ...
	Scale=2, ...
	NPermutation=0);

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(fig, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig383C_ModelContinualTHInhibitedPerformance', struct('Continual', continualPerformance, 'THInhibited', thInhibitedPerformance));
assignin('base', 'Fig383C_ModelContinualTHInhibitedRunInfo', RunInfo);
assignin('base', 'Fig383C_ModelContinualTHInhibitedSigmoidStats', SigmoidStats);
assignin('base', 'Fig383C_ModelContinualTHInhibitedSvgPath', svgPath);

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

function iAssertAllPretrained(RunInfo)
continualPretrainReached = RunInfo.ContinualPretrainReached;
thInhibitedPretrainReached = RunInfo.THInhibitedPretrainReached;
if ~all(continualPretrainReached)
	failedMice = find(~continualPretrainReached);
	error('Fig383C:ContinualPretrainDidNotReachCeiling', 'Continual pretraining failed for %d/%d mice. First failed mouse index: %d.', numel(failedMice), height(RunInfo), failedMice(1));
end
if ~all(thInhibitedPretrainReached)
	failedMice = find(~thInhibitedPretrainReached);
	error('Fig383C:THInhibitedPretrainDidNotReachCeiling', 'TH inhibited pretraining failed for %d/%d mice. First failed mouse index: %d.', numel(failedMice), height(RunInfo), failedMice(1));
end
end
