function [Performance, RunInfo, Stats] = SimulateConditionLearningCurves(Params, Cond, conditionNames, options)
arguments
	Params (1, 1) struct
	Cond table
	conditionNames (1, :) string
	options.OutputNames (1, :) string = conditionNames
	options.SeedBase (1, 1) double {mustBeInteger, mustBePositive} = 38238302
end

outputNames = options.OutputNames;
if numel(outputNames) ~= numel(conditionNames)
	error('THModel:ConditionOutputNameCountMismatch', 'OutputNames must have the same number of elements as conditionNames.');
end

numMice = Params.NumMice;
numSessions = Params.NumSessions;
numConditions = numel(conditionNames);
seedValues = iConditionSeedValues(numMice, conditionNames, options.SeedBase);

performanceCells = cell(numMice, 1);
pretrainReachedCells = cell(numMice, 1);
pretrainSessionCells = cell(numMice, 1);
heterogeneityCells = cell(numMice, 1);

iPrepareParallelWorkers();
parfor mouseIndex = 1:numMice
	[performanceCells{mouseIndex}, pretrainReachedCells{mouseIndex}, pretrainSessionCells{mouseIndex}, heterogeneityCells{mouseIndex}] = iRunOneMouseConditions(Params, Cond, conditionNames, seedValues(mouseIndex, :));
end

Performance = struct();
Stats = struct();
Stats.Heterogeneity = struct();
pretrainReached = false(numMice, numConditions);
pretrainSessions = nan(numMice, numConditions);
heterogeneityNames = ["L23E", "L23I", "L5E", "L5I"];
for conditionIndex = 1:numConditions
	conditionPerformance = nan(numMice, numSessions);
	heterogeneityValues = nan(numMice, numel(heterogeneityNames));
	for mouseIndex = 1:numMice
		conditionPerformance(mouseIndex, :) = performanceCells{mouseIndex}(conditionIndex, :);
		pretrainReached(mouseIndex, conditionIndex) = pretrainReachedCells{mouseIndex}(conditionIndex);
		pretrainSessions(mouseIndex, conditionIndex) = pretrainSessionCells{mouseIndex}(conditionIndex);
		heterogeneityValues(mouseIndex, :) = heterogeneityCells{mouseIndex}(conditionIndex, :);
	end
	Performance.(outputNames(conditionIndex)) = conditionPerformance;
	for heterogeneityIndex = 1:numel(heterogeneityNames)
		Stats.Heterogeneity.(outputNames(conditionIndex)).(heterogeneityNames(heterogeneityIndex)) = heterogeneityValues(:, heterogeneityIndex);
	end
end

RunInfo = table((1:numMice)', 'VariableNames', {'Mouse'});
for conditionIndex = 1:numConditions
	outputName = outputNames(conditionIndex);
	RunInfo.(outputName + "Seed") = seedValues(:, conditionIndex);
	RunInfo.(outputName + "PretrainReached") = pretrainReached(:, conditionIndex);
	RunInfo.(outputName + "PretrainSessions") = pretrainSessions(:, conditionIndex);
end
end

function [performanceByCondition, pretrainReached, pretrainSessions, heterogeneityByCondition] = iRunOneMouseConditions(Params, Cond, conditionNames, seedValues)
numConditions = numel(conditionNames);
performanceByCondition = nan(numConditions, Params.NumSessions);
pretrainReached = false(1, numConditions);
pretrainSessions = nan(1, numConditions);
heterogeneityByCondition = nan(numConditions, 4);

for conditionIndex = 1:numConditions
	conditionName = conditionNames(conditionIndex);
	condRow = Cond(Cond.Name == conditionName, :);
	if height(condRow) ~= 1
		error('THModel:UnknownConditionName', 'Expected exactly one condition named %s.', conditionName);
	end

	rng(seedValues(conditionIndex), 'twister');
	Mouse = TransferLearning.THModel.DrawMouse(Params);
	if conditionName == "Naive"
		pretrainReached(conditionIndex) = true;
		pretrainSessions(conditionIndex) = 0;
	else
		[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, condRow);
		pretrainReached(conditionIndex) = pretrainResult.Reached;
		pretrainSessions(conditionIndex) = pretrainResult.TrainingSessions;
	end
	formalResult = TransferLearning.THModel.SimulateFormalTraining(Mouse, Params, condRow);
	performanceByCondition(conditionIndex, :) = TransferLearning.THModel.GatherValue(formalResult.Performance);
	heterogeneityByCondition(conditionIndex, :) = [formalResult.MeanH23, formalResult.MeanH23I, formalResult.MeanH5, formalResult.MeanH5I];
end
end

function seedValues = iConditionSeedValues(numMice, conditionNames, seedBase)
seedValues = nan(numMice, numel(conditionNames));
for conditionIndex = 1:numel(conditionNames)
	conditionOffset = iConditionSeedOffset(conditionNames(conditionIndex));
	for mouseIndex = 1:numMice
		seedValues(mouseIndex, conditionIndex) = mod(seedBase + conditionOffset + mouseIndex * 1009, 2^31 - 2) + 1;
	end
end
end

function conditionOffset = iConditionSeedOffset(conditionName)
switch conditionName
	case "Naive"
		conditionOffset = 101000000;
	case "Transfer"
		conditionOffset = 202000000;
	case "THOff"
		conditionOffset = 303000000;
	otherwise
		conditionOffset = 404000000 + sum(double(char(conditionName))) * 1009;
end
end

function iPrepareParallelWorkers()
pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
end
