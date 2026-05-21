% Fig383B model-simulated Continual/TH inhibited learning curve with sigmoid fits.

svgName = '中文图Fig383B_ModelContinualTHInhibitedLearningCurve.svg';
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
%% 

[fig, SigmoidStats] = TransferLearning.PlotSigmoidLearningCurvePanels( ...
	continualPerformance, thInhibitedPerformance, ...
	"Transfer", "THOff", "Continual", "TH inhibited", ...
	FigureName="Fig383B model Continual TH inhibited sigmoid", ...
	FigureSizeCm=[9, 8], ...
	Scale=2, ...
	LegendPanel="A", ...
	NPermutation=0);

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(fig, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig383B_ModelContinualTHInhibitedPerformance', struct('Continual', continualPerformance, 'THInhibited', thInhibitedPerformance));
assignin('base', 'Fig383B_ModelContinualTHInhibitedRunInfo', RunInfo);
assignin('base', 'Fig383B_ModelContinualTHInhibitedSigmoidStats', SigmoidStats);
assignin('base', 'Fig383B_ModelContinualTHInhibitedSvgPath', svgPath);

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
	error('Fig383B:ContinualPretrainDidNotReachCeiling', 'Continual pretraining failed for %d/%d mice. First failed mouse index: %d.', numel(failedMice), height(RunInfo), failedMice(1));
end
if ~all(thInhibitedPretrainReached)
	failedMice = find(~thInhibitedPretrainReached);
	error('Fig383B:THInhibitedPretrainDidNotReachCeiling', 'TH inhibited pretraining failed for %d/%d mice. First failed mouse index: %d.', numel(failedMice), height(RunInfo), failedMice(1));
end
end
