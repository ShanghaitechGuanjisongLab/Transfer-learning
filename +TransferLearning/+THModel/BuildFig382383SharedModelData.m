function Data = BuildFig382383SharedModelData(options)
arguments
	options.SeedBase (1, 1) double {mustBeInteger, mustBePositive} = 38238304
	options.NPermutation (1, 1) double {mustBeInteger, mustBeNonnegative} = 10000
	options.PermutationSeed (1, 1) double {mustBeInteger, mustBePositive} = 1
	options.IncludeHeatmap (1, 1) logical = true
end

Params = TransferLearning.THModel.DefaultParams();
Cond = TransferLearning.THModel.ConditionTable();
conditionNames = ["Naive", "Transfer", "THOff"];
seedValues = iConditionSeedValues(Params.NumMice, conditionNames, options.SeedBase);

iPrepareParallelWorkers();
mouseConditionCells = cell(Params.NumMice, 1);
parfor mouseIndex = 1:Params.NumMice
	mouseConditionCells{mouseIndex} = iRunOneMouseConditions(Params, Cond, conditionNames, seedValues(mouseIndex, :));
end

[Performance, RunInfo, Heterogeneity, PreFormalWeightValues] = iCollectMouseConditionData(mouseConditionCells, Params, conditionNames, seedValues);
Sigmoid = iComputeSigmoidStats(Performance, options.NPermutation, options.PermutationSeed);
iValidateAcceptance(Performance, RunInfo, Heterogeneity, Sigmoid, Params, Cond);

HeatmapData = struct();
HeatmapRunInfo = table();
if options.IncludeHeatmap
	heatmapSeedValues = iConditionSeedValues(1, ["Naive", "Transfer"], options.SeedBase);
	[HeatmapData, HeatmapRunInfo] = TransferLearning.THModel.FirstFormalUnitDecisionHeatmapData(Params, Cond, heatmapSeedValues);
end

Data = struct();
Data.CacheVersion = 3;
Data.SeedBase = options.SeedBase;
Data.NPermutation = options.NPermutation;
Data.PermutationSeed = options.PermutationSeed;
Data.Params = Params;
Data.Cond = Cond;
Data.ConditionNames = conditionNames;
Data.ConditionSeedValues = seedValues;
Data.Performance = Performance;
Data.RunInfo = RunInfo;
Data.Heterogeneity = Heterogeneity;
Data.PreFormalWeightValues = PreFormalWeightValues;
Data.Sigmoid = Sigmoid;
Data.HeatmapData = HeatmapData;
Data.HeatmapRunInfo = HeatmapRunInfo;
Data.Acceptance.Passed = true;
Data.Acceptance.CheckedAt = datetime('now');
end

function conditionResults = iRunOneMouseConditions(Params, Cond, conditionNames, seedValues)
conditionResults = cell(1, numel(conditionNames));
for conditionIndex = 1:numel(conditionNames)
	conditionName = conditionNames(conditionIndex);
	condRow = Cond(Cond.Name == conditionName, :);
	if height(condRow) ~= 1
		error('THModel:UnknownConditionName', 'Expected exactly one condition named %s.', conditionName);
	end

	rng(seedValues(conditionIndex), 'twister');
	Mouse = TransferLearning.THModel.DrawMouse(Params);
	pretrainReached = true;
	pretrainSessions = 0;
	pretrainFinalHit = NaN;
	if conditionName ~= "Naive"
		[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, condRow);
		pretrainReached = pretrainResult.Reached;
		pretrainSessions = pretrainResult.TrainingSessions;
		pretrainFinalHit = pretrainResult.FinalHit;
	end
	preFormalWeights = iCollectConnectionTypeWeights(Mouse);
	[formalResult, Mouse] = TransferLearning.THModel.SimulateFormalTrainingWithInhibitoryStats(Mouse, Params, condRow);
	postFormalWeights = iCollectConnectionTypeWeights(Mouse);
	conditionResults{conditionIndex} = iBuildOneConditionResult(formalResult, pretrainReached, pretrainSessions, pretrainFinalHit, preFormalWeights, postFormalWeights);
end
end

function result = iBuildOneConditionResult(formalResult, pretrainReached, pretrainSessions, pretrainFinalHit, preFormalWeights, postFormalWeights)
result = struct();
result.Performance = TransferLearning.THModel.GatherValue(formalResult.Performance);
result.PretrainReached = pretrainReached;
result.PretrainSessions = pretrainSessions;
result.PretrainFinalHit = pretrainFinalHit;
result.Heterogeneity.L23E = formalResult.MeanH23;
result.Heterogeneity.L23I = formalResult.MeanH23I;
result.Heterogeneity.L5E = formalResult.MeanH5;
result.Heterogeneity.L5I = formalResult.MeanH5I;
result.PreFormalWeights = preFormalWeights;
result.PostFormalWeights = postFormalWeights;
end

function [Performance, RunInfo, Heterogeneity, PreFormalWeightValues] = iCollectMouseConditionData(mouseConditionCells, Params, conditionNames, seedValues)
numMice = Params.NumMice;
numConditions = numel(conditionNames);
classNames = iConnectionClassNames();
heterogeneityNames = ["L23E", "L23I", "L5E", "L5I"];

Performance = struct();
Heterogeneity = struct();
pretrainReached = false(numMice, numConditions);
pretrainSessions = nan(numMice, numConditions);
pretrainFinalHit = nan(numMice, numConditions);
preFormalWeightCells = struct();
for conditionIndex = 1:numConditions
	conditionName = conditionNames(conditionIndex);
	Performance.(conditionName) = nan(numMice, Params.NumSessions);
	for heterogeneityIndex = 1:numel(heterogeneityNames)
		Heterogeneity.(conditionName).(heterogeneityNames(heterogeneityIndex)) = nan(numMice, 1);
	end
	for classIndex = 1:numel(classNames)
		preFormalWeightCells.(conditionName).(classNames(classIndex)) = cell(numMice, 1);
	end
end

for mouseIndex = 1:numMice
	conditionResults = mouseConditionCells{mouseIndex};
	for conditionIndex = 1:numConditions
		conditionName = conditionNames(conditionIndex);
		oneResult = conditionResults{conditionIndex};
		Performance.(conditionName)(mouseIndex, :) = oneResult.Performance;
		pretrainReached(mouseIndex, conditionIndex) = oneResult.PretrainReached;
		pretrainSessions(mouseIndex, conditionIndex) = oneResult.PretrainSessions;
		pretrainFinalHit(mouseIndex, conditionIndex) = oneResult.PretrainFinalHit;
		for heterogeneityIndex = 1:numel(heterogeneityNames)
			heterogeneityName = heterogeneityNames(heterogeneityIndex);
			Heterogeneity.(conditionName).(heterogeneityName)(mouseIndex) = oneResult.Heterogeneity.(heterogeneityName);
		end
		for classIndex = 1:numel(classNames)
			className = classNames(classIndex);
			preFormalWeightCells.(conditionName).(className){mouseIndex} = oneResult.PreFormalWeights.(className);
		end
	end
end

RunInfo = table((1:numMice)', 'VariableNames', {'Mouse'});
for conditionIndex = 1:numConditions
	conditionName = conditionNames(conditionIndex);
	RunInfo.(conditionName + "Seed") = seedValues(:, conditionIndex);
	RunInfo.(conditionName + "PretrainReached") = pretrainReached(:, conditionIndex);
	RunInfo.(conditionName + "PretrainSessions") = pretrainSessions(:, conditionIndex);
	RunInfo.(conditionName + "PretrainFinalHit") = pretrainFinalHit(:, conditionIndex);
end

PreFormalWeightValues = iBuildPreFormalWeightValues(preFormalWeightCells, Heterogeneity, classNames, heterogeneityNames);
end

function PreFormalWeightValues = iBuildPreFormalWeightValues(preFormalWeightCells, Heterogeneity, classNames, heterogeneityNames)
for classIndex = 1:numel(classNames)
	className = classNames(classIndex);
	PreFormalWeightValues.Naive.(className) = vertcat(preFormalWeightCells.Naive.(className){:});
	PreFormalWeightValues.AfterPretrain.(className) = vertcat(preFormalWeightCells.Transfer.(className){:});
	PreFormalWeightValues.MouseStd.Naive.(className) = iClassWeightStdByMouse(preFormalWeightCells.Naive.(className));
	PreFormalWeightValues.MouseStd.AfterPretrain.(className) = iClassWeightStdByMouse(preFormalWeightCells.Transfer.(className));
end
for heterogeneityIndex = 1:numel(heterogeneityNames)
	heterogeneityName = heterogeneityNames(heterogeneityIndex);
	PreFormalWeightValues.Heterogeneity.Naive.(heterogeneityName) = Heterogeneity.Naive.(heterogeneityName);
	PreFormalWeightValues.Heterogeneity.AfterPretrain.(heterogeneityName) = Heterogeneity.Transfer.(heterogeneityName);
end
end

function Sigmoid = iComputeSigmoidStats(Performance, nPermutation, permutationSeed)
Sigmoid = struct();
Sigmoid.Fig382C = TransferLearning.THModel.CompareSigmoidSlope(Performance.Naive, Performance.Transfer, "Naive", "Transfer", nPermutation, permutationSeed);
Sigmoid.Fig383D = TransferLearning.THModel.CompareSigmoidSlope(Performance.Transfer, Performance.THOff, "Transfer", "THOff", nPermutation, permutationSeed + 1);
end

function iValidateAcceptance(Performance, RunInfo, Heterogeneity, Sigmoid, Params, Cond)
iAssertAllPretrained(RunInfo, ["Transfer", "THOff"]);
iCheckNaiveLastSessionExceedsFirst(Performance, Cond);
iCheckTransferTHOffFirstSessionHitBelowMax(Performance, Cond, Params.TransferTHOffFirstSessionHitMax);
iCheckTransferPerfectWithinSessions(Performance, Cond, Params.NumSessions, Params.Ceiling);
iCheckTransferMetricSignificantlyHighest(Heterogeneity, Cond, "L5E", "Mean L5 heterogeneity", Params.TransferHighestAlpha);
iCheckSigmoidSlopeSignificantlyHighest(Sigmoid, Params.TransferHighestAlpha);
end

function iAssertAllPretrained(RunInfo, conditionNames)
for conditionIndex = 1:numel(conditionNames)
	conditionName = conditionNames(conditionIndex);
	fieldName = conditionName + "PretrainReached";
	pretrainReached = RunInfo.(fieldName);
	if all(pretrainReached)
		continue;
	end
	failedMice = find(~pretrainReached);
	error('THModel:PretrainDidNotReachCeiling', '%s pretraining failed for %d/%d mice. First failed mouse index: %d.', conditionName, numel(failedMice), height(RunInfo), failedMice(1));
end
end

function iCheckNaiveLastSessionExceedsFirst(Performance, Cond)
naiveIndex = find(Cond.Name == "Naive", 1);
naivePerformance = Performance.(Cond.Name(naiveIndex));
firstSessionHit = naivePerformance(:, 1);
lastSessionHit = naivePerformance(:, end);
failedMouseIndex = find(~(lastSessionHit > firstSessionHit));
if isempty(failedMouseIndex)
	return;
end
failureText = strings(numel(failedMouseIndex), 1);
for iFailure = 1:numel(failedMouseIndex)
	mouseIndex = failedMouseIndex(iFailure);
	failureText(iFailure) = sprintf('mouse %d: first=%.4f, last=%.4f', mouseIndex, firstSessionHit(mouseIndex), lastSessionHit(mouseIndex));
end
error('THModel:NaiveLastSessionNotAboveFirst', 'Every Naive mouse must have last-session hit rate above first-session hit rate. %s', strjoin(failureText, '; '));
end

function iCheckTransferTHOffFirstSessionHitBelowMax(Performance, Cond, maxFirstSessionHit)
conditionNamesToCheck = ["Transfer", "THOff"];
failedConditions = strings(0, 1);
for conditionIndex = 1:numel(conditionNamesToCheck)
	conditionName = conditionNamesToCheck(conditionIndex);
	condIndex = find(Cond.Name == conditionName, 1);
	conditionPerformance = Performance.(Cond.Name(condIndex));
	firstSessionMean = mean(conditionPerformance(:, 1), 'omitnan');
	if ~(isfinite(firstSessionMean) && firstSessionMean <= maxFirstSessionHit)
		failedConditions(end + 1, 1) = sprintf('%s first-session mean=%.4f, max allowed=%.4f', conditionName, firstSessionMean, maxFirstSessionHit); %#ok<AGROW>
	end
end
if isempty(failedConditions)
	return;
end
error('THModel:TransferTHOffFirstSessionHitTooHigh', 'Transfer and THOff first-session mean hit rates must be <= %.3f. %s', maxFirstSessionHit, strjoin(failedConditions, '; '));
end

function iCheckTransferPerfectWithinSessions(Performance, Cond, maxSession, ceilingHit)
transferIndex = find(Cond.Name == "Transfer", 1);
transferPerformance = Performance.(Cond.Name(transferIndex));
windowPerformance = transferPerformance(:, 1:maxSession);
reachedPerfect = any(windowPerformance >= ceilingHit, 2);
if all(reachedPerfect)
	return;
end
failedMouse = find(~reachedPerfect);
bestHit = max(windowPerformance(failedMouse, :), [], 2, 'omitnan');
failureText = strings(numel(failedMouse), 1);
for iFailure = 1:numel(failedMouse)
	failureText(iFailure) = sprintf('mouse %d max=%.3f', failedMouse(iFailure), bestHit(iFailure));
end
error('THModel:TransferDidNotReachPerfectHitWithinWindow', 'Every Transfer mouse must reach %.3f hit within %d training units. %s', ceilingHit, maxSession, strjoin(failureText, '; '));
end

function iCheckTransferMetricSignificantlyHighest(Heterogeneity, Cond, metricName, metricLabel, alpha)
transferValues = Heterogeneity.Transfer.(metricName);
transferValues = transferValues(isfinite(transferValues));
failedComparisons = strings(0, 1);
for conditionIndex = 1:height(Cond)
	conditionName = Cond.Name(conditionIndex);
	if conditionName == "Transfer"
		continue;
	end
	otherValues = Heterogeneity.(conditionName).(metricName);
	otherValues = otherValues(isfinite(otherValues));
	transferMean = mean(transferValues, 'omitnan');
	otherMean = mean(otherValues, 'omitnan');
	pValue = ranksum(transferValues, otherValues);
	if ~(transferMean > otherMean && pValue < alpha)
		failedComparisons(end + 1, 1) = sprintf('%s: Transfer mean=%.4f, %s mean=%.4f, ranksum p=%.4g', conditionName, transferMean, Cond.Label(conditionIndex), otherMean, pValue); %#ok<AGROW>
	end
end
if isempty(failedComparisons)
	return;
end
error('THModel:TransferNotSignificantlyHighest', 'Transfer must be significantly highest for %s (alpha=%.3f). %s', metricLabel, alpha, strjoin(failedComparisons, '; '));
end

function iCheckSigmoidSlopeSignificantlyHighest(Sigmoid, alpha)
iAssertSigmoidComparison(Sigmoid.Fig382C, alpha, true, 'Naive');
iAssertSigmoidComparison(Sigmoid.Fig383D, alpha, false, 'THOff');
end

function iAssertSigmoidComparison(stats, alpha, expectPositiveDifference, otherName)
comparison = stats.ComparisonTable;
observedDifference = comparison.ObservedSlopeDifference(1);
pValue = comparison.PValueTwoSided(1);
if expectPositiveDifference
	passesDirection = observedDifference > 0;
else
	passesDirection = observedDifference < 0;
end
if passesDirection && pValue < alpha
	return;
end
error('THModel:TransferNotSignificantlyHighest', 'Transfer must be significantly highest for sigmoid slope versus %s (alpha=%.3f). %s observed difference=%.4f, two-sided permutation p=%.4g.', otherName, alpha, char(comparison.Comparison(1)), observedDifference, pValue);
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
classNames = iConnectionClassNames();
for classIndex = 1:numel(classNames)
	weightClasses.(classNames(classIndex)) = [];
end
end

function weightClasses = iAppendConnectionClassWeights(weightClasses, className, weights)
weights = TransferLearning.THModel.GatherValue(weights(:));
weights = weights(isfinite(weights) & weights > 0);
weightClasses.(className) = [weightClasses.(className); weights];
end

function classNames = iConnectionClassNames()
classNames = ["EE", "EI", "IE", "II"];
end

function stdValues = iClassWeightStdByMouse(mouseWeights)
stdValues = nan(numel(mouseWeights), 1);
for mouseIndex = 1:numel(mouseWeights)
	stdValues(mouseIndex) = iWeightDistributionStd(mouseWeights{mouseIndex});
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