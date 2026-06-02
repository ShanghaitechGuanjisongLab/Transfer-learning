function [StageWeightValues, StageRunInfo] = PretrainStageAllConnectionWeights(Params, Cond, RunInfo)
arguments
	Params (1, 1) struct
	Cond table
	RunInfo table
end

if ~all(ismember({'NaiveSeed', 'TransferSeed'}, RunInfo.Properties.VariableNames))
	error('THModel:MissingSeedColumns', 'RunInfo must contain NaiveSeed and TransferSeed columns.');
end

transferCond = Cond(Cond.Name == "Transfer", :);
if height(transferCond) ~= 1
	error('THModel:UnknownConditionName', 'Expected exactly one condition named Transfer.');
end

numMice = height(RunInfo);
naiveWeightsByMouse = cell(numMice, 1);
pretrainFirstBlockWeightsByMouse = cell(numMice, 1);
afterPretrainWeightsByMouse = cell(numMice, 1);
pretrainReached = false(numMice, 1);
pretrainSessions = nan(numMice, 1);
pretrainFinalHit = nan(numMice, 1);
pretrainFirstBlockHit = nan(numMice, 1);

iPrepareParallelWorkers(numMice);
parfor mouseIndex = 1:numMice
	rng(RunInfo.NaiveSeed(mouseIndex), 'twister');
	naiveMouse = TransferLearning.THModel.DrawMouse(Params);
	naiveWeightsByMouse{mouseIndex} = TransferLearning.THModel.AllConnectionWeights(naiveMouse);

	rng(RunInfo.TransferSeed(mouseIndex), 'twister');
	transferMouseStart = TransferLearning.THModel.DrawMouse(Params);

	[transferMouseAfterFirstBlock, pretrainFirstBlockResult] = TransferLearning.THModel.SimulatePretraining(transferMouseStart, Params, transferCond, 1);
	pretrainFirstBlockWeightsByMouse{mouseIndex} = TransferLearning.THModel.AllConnectionWeights(transferMouseAfterFirstBlock);
	pretrainFirstBlockHit(mouseIndex) = pretrainFirstBlockResult.FinalHit;

	[transferMouseAfterPretrain, pretrainResult] = TransferLearning.THModel.SimulatePretraining(transferMouseStart, Params, transferCond);
	afterPretrainWeightsByMouse{mouseIndex} = TransferLearning.THModel.AllConnectionWeights(transferMouseAfterPretrain);
	pretrainReached(mouseIndex) = pretrainResult.Reached;
	pretrainSessions(mouseIndex) = pretrainResult.TrainingSessions;
	pretrainFinalHit(mouseIndex) = pretrainResult.FinalHit;
end

StageWeightValues = struct();
StageWeightValues.Naive = vertcat(naiveWeightsByMouse{:});
StageWeightValues.PretrainFirstBlock = vertcat(pretrainFirstBlockWeightsByMouse{:});
StageWeightValues.AfterPretrain = vertcat(afterPretrainWeightsByMouse{:});

StageRunInfo = table((1:numMice)', RunInfo.NaiveSeed, RunInfo.TransferSeed, pretrainFirstBlockHit, pretrainReached, pretrainSessions, pretrainFinalHit, ...
	'VariableNames', {'Mouse', 'NaiveSeed', 'TransferSeed', 'PretrainFirstBlockHit', 'PretrainReached', 'PretrainSessions', 'PretrainFinalHit'});
end

function iPrepareParallelWorkers(numMice)
pool = gcp('nocreate');
if isempty(pool) && numMice > 1
	parpool('local', min(20, numMice));
end
end
