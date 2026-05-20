% Fig382C model-simulated Naive/Continual learning curve with sigmoid fits.

svgName = '中文图Fig382C_ModelNaiveContinualLearningCurve.svg';
iEnsureTransferLearningProject();

if evalin('base', 'exist(''THRandomSeed'', ''var'')')
	rng(evalin('base', 'THRandomSeed'));
else
	rng('shuffle');
end

Params = TransferLearning.THModel.DefaultParams();
Params = TransferLearning.THModel.ApplyBaseParameterOverrides(Params);
Cond = TransferLearning.THModel.ConditionTable();
[naivePerformance, continualPerformance, RunInfo] = iSimulateNaiveContinualLearning(Params, Cond);

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

function [naivePerformance, continualPerformance, RunInfo] = iSimulateNaiveContinualLearning(Params, Cond)
numMice = Params.NumMice;
numSessions = Params.NumSessions;
naivePerformance = nan(numMice, numSessions);
continualPerformance = nan(numMice, numSessions);
pretrainReached = false(numMice, 1);
pretrainSessions = nan(numMice, 1);
mouseSeeds = randi(2^31 - 1, numMice, 2);
naiveCond = Cond(Cond.Name == "Naive", :);
continualCond = Cond(Cond.Name == "Transfer", :);

iPrepareParallelWorkers();
parfor mouseIndex = 1:numMice
	[naivePerformance(mouseIndex, :), continualPerformance(mouseIndex, :), pretrainReached(mouseIndex), pretrainSessions(mouseIndex)] = iRunOneMousePair(Params, naiveCond, continualCond, mouseSeeds(mouseIndex, :));
end

if ~all(pretrainReached)
	failedMice = find(~pretrainReached);
	error('Fig382C:PretrainDidNotReachCeiling', 'Continual pretraining failed for %d/%d mice. First failed mouse index: %d.', numel(failedMice), numMice, failedMice(1));
end
RunInfo = table((1:numMice)', mouseSeeds(:, 1), mouseSeeds(:, 2), pretrainReached, pretrainSessions, ...
	'VariableNames', {'Mouse','NaiveSeed','ContinualSeed','ContinualPretrainReached','ContinualPretrainSessions'});
end

function [naivePerformance, continualPerformance, pretrainReached, pretrainSessions] = iRunOneMousePair(Params, naiveCond, continualCond, mouseSeeds)
rng(mouseSeeds(1), 'twister');
naiveMouse = TransferLearning.THModel.DrawMouse(Params);
naiveResult = TransferLearning.THModel.SimulateFormalTraining(naiveMouse, Params, naiveCond);
naivePerformance = TransferLearning.THModel.GatherValue(naiveResult.Performance);

rng(mouseSeeds(2), 'twister');
continualMouse = TransferLearning.THModel.DrawMouse(Params);
[continualMouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(continualMouse, Params, continualCond);
pretrainReached = pretrainResult.Reached;
pretrainSessions = pretrainResult.TrainingSessions;
continualResult = TransferLearning.THModel.SimulateFormalTraining(continualMouse, Params, continualCond);
continualPerformance = TransferLearning.THModel.GatherValue(continualResult.Performance);
end

function iPrepareParallelWorkers()
pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
end
