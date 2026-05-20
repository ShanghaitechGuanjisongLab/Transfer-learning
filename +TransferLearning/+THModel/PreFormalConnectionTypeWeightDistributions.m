function [WeightValues, RunInfo] = PreFormalConnectionTypeWeightDistributions(Params, numMice, seedValues)
arguments
	Params (1, 1) struct
	numMice (1, 1) double {mustBeInteger, mustBePositive} = Params.NumMice
	seedValues (:, 2) double = nan(numMice, 2)
end

if size(seedValues, 1) ~= numMice
	error('THModel:InvalidSeedTable', 'seedValues must have one row per mouse.');
end
if any(~isfinite(seedValues), 'all')
	seedValues = randi(2^31 - 1, numMice, 2);
end

classNames = ["EE", "EI", "IE", "II"];
naiveMouseWeights = cell(numMice, 1);
afterPretrainMouseWeights = cell(numMice, 1);
pretrainReached = false(numMice, 1);
pretrainSessions = nan(numMice, 1);

	iPrepareParallelWorkers(numMice);
parfor mouseIndex = 1:numMice
	[naiveOne, afterPretrainOne, reachedOne, sessionsOne] = iRunOneMouse(Params, seedValues(mouseIndex, :));
	naiveMouseWeights{mouseIndex} = naiveOne;
	afterPretrainMouseWeights{mouseIndex} = afterPretrainOne;
	pretrainReached(mouseIndex) = reachedOne;
	pretrainSessions(mouseIndex) = sessionsOne;
end

for classIndex = 1:numel(classNames)
	className = classNames(classIndex);
	WeightValues.Naive.(className) = iVertcatClassWeights(naiveMouseWeights, className);
	WeightValues.AfterPretrain.(className) = iVertcatClassWeights(afterPretrainMouseWeights, className);
	WeightValues.MouseStd.Naive.(className) = iClassWeightStdByMouse(naiveMouseWeights, className);
	WeightValues.MouseStd.AfterPretrain.(className) = iClassWeightStdByMouse(afterPretrainMouseWeights, className);
end
RunInfo = table((1:numMice)', seedValues(:, 1), seedValues(:, 2), pretrainReached, pretrainSessions, ...
	'VariableNames', {'Mouse','NaiveSeed','AfterPretrainSeed','PretrainReached','PretrainSessions'});
end

function weights = iVertcatClassWeights(mouseWeights, className)
weights = cell(numel(mouseWeights), 1);
for mouseIndex = 1:numel(mouseWeights)
	weights{mouseIndex} = mouseWeights{mouseIndex}.(className);
end
weights = vertcat(weights{:});
end

function stdValues = iClassWeightStdByMouse(mouseWeights, className)
stdValues = nan(numel(mouseWeights), 1);
for mouseIndex = 1:numel(mouseWeights)
	stdValues(mouseIndex) = iWeightDistributionStd(mouseWeights{mouseIndex}.(className));
end
end

function stdWeight = iWeightDistributionStd(weights)
weights = weights(:);
weights = weights(isfinite(weights));
if numel(weights) < 2
	stdWeight = NaN;
	return;
end
stdWeight = std(weights, 0, 'omitnan');
end

function [naiveWeights, afterPretrainWeights, pretrainReached, pretrainSessions] = iRunOneMouse(Params, mouseSeeds)
rng(mouseSeeds(1), 'twister');
naiveMouse = TransferLearning.THModel.DrawMouse(Params);
naiveWeights = iCollectConnectionTypeWeights(naiveMouse);

rng(mouseSeeds(2), 'twister');
afterPretrainMouse = TransferLearning.THModel.DrawMouse(Params);
pretrainCond.RewardInputLevel = 1.00;
[afterPretrainMouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(afterPretrainMouse, Params, pretrainCond);
pretrainReached = pretrainResult.Reached;
pretrainSessions = pretrainResult.TrainingSessions;
afterPretrainWeights = iCollectConnectionTypeWeights(afterPretrainMouse);
end

function weightClasses = iCollectConnectionTypeWeights(Mouse)
weightClasses = iEmptyConnectionClassWeights();

weightClasses = iAppendConnectionClassWeights(weightClasses, "EE", TransferLearning.THModel.NonSelfInternalWeights(Mouse.W_L23L5ToL23L5));
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WEI_L23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WIE_L23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", TransferLearning.THModel.NonSelfInternalWeights(Mouse.WII_L23));
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WEI_L5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WIE_L5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", TransferLearning.THModel.NonSelfInternalWeights(Mouse.WII_L5RewardRecv));
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WEI_L5Read);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WIE_L5Read);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", TransferLearning.THModel.NonSelfInternalWeights(Mouse.WII_L5Read));
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WI23ToL5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WI23ToL5Read);
end

function weightClasses = iEmptyConnectionClassWeights()
classNames = ["EE", "EI", "IE", "II"];
for classIndex = 1:numel(classNames)
	weightClasses.(classNames(classIndex)) = [];
end
end

function weightClasses = iAppendConnectionClassWeights(weightClasses, className, weights)
weights = TransferLearning.THModel.GatherValue(weights(:));
weights = weights(isfinite(weights) & weights > 0);
weightClasses.(className) = [weightClasses.(className); weights];
end

function iPrepareParallelWorkers(numMice)
pool = gcp('nocreate');
if isempty(pool) && numMice > 1
	parpool('local', min(20, numMice));
end
end
