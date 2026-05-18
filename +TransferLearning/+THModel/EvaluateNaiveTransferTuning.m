function Report = EvaluateNaiveTransferTuning(Params, numMice, seedValues)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(numMice)
	numMice = Params.NumMice;
end
if nargin < 3
	seedValues = [];
end
seedValues = iNormalizeSeedValues(seedValues, numMice);

pretrainCond.RewardInputLevel = 1.00;
formalCond.RewardInputLevel = 1.00;

naivePerf = nan(numMice, Params.NumSessions);
transferPerf = nan(numMice, Params.NumSessions);
pretrainReached = false(numMice, 1);
pretrainSessions = nan(numMice, 1);
pretrainFinalHit = nan(numMice, 1);
naiveSlope = nan(numMice, 1);
transferSlope = nan(numMice, 1);
naiveMeanDeltaHit = nan(numMice, 1);
transferMeanDeltaHit = nan(numMice, 1);
naiveFirstPerfectSession = nan(numMice, 1);
transferFirstPerfectSession = nan(numMice, 1);

useParallel = numMice > 1 && ~isempty(gcp('nocreate'));
if useParallel
	parfor iMouse = 1:numMice
		[naivePerfRow, transferPerfRow, pretrainReachedValue, pretrainSessionsValue, pretrainFinalHitValue, naiveSlopeValue, transferSlopeValue, naiveMeanDeltaHitValue, transferMeanDeltaHitValue, naiveFirstPerfectValue, transferFirstPerfectValue] = iEvaluateOneMouse(Params, pretrainCond, formalCond, seedValues(iMouse));
		naivePerf(iMouse, :) = naivePerfRow;
		transferPerf(iMouse, :) = transferPerfRow;
		pretrainReached(iMouse) = pretrainReachedValue;
		pretrainSessions(iMouse) = pretrainSessionsValue;
		pretrainFinalHit(iMouse) = pretrainFinalHitValue;
		naiveSlope(iMouse) = naiveSlopeValue;
		transferSlope(iMouse) = transferSlopeValue;
		naiveMeanDeltaHit(iMouse) = naiveMeanDeltaHitValue;
		transferMeanDeltaHit(iMouse) = transferMeanDeltaHitValue;
		naiveFirstPerfectSession(iMouse) = naiveFirstPerfectValue;
		transferFirstPerfectSession(iMouse) = transferFirstPerfectValue;
	end
else
	for iMouse = 1:numMice
		[naivePerfRow, transferPerfRow, pretrainReachedValue, pretrainSessionsValue, pretrainFinalHitValue, naiveSlopeValue, transferSlopeValue, naiveMeanDeltaHitValue, transferMeanDeltaHitValue, naiveFirstPerfectValue, transferFirstPerfectValue] = iEvaluateOneMouse(Params, pretrainCond, formalCond, seedValues(iMouse));
		naivePerf(iMouse, :) = naivePerfRow;
		transferPerf(iMouse, :) = transferPerfRow;
		pretrainReached(iMouse) = pretrainReachedValue;
		pretrainSessions(iMouse) = pretrainSessionsValue;
		pretrainFinalHit(iMouse) = pretrainFinalHitValue;
		naiveSlope(iMouse) = naiveSlopeValue;
		transferSlope(iMouse) = transferSlopeValue;
		naiveMeanDeltaHit(iMouse) = naiveMeanDeltaHitValue;
		transferMeanDeltaHit(iMouse) = transferMeanDeltaHitValue;
		naiveFirstPerfectSession(iMouse) = naiveFirstPerfectValue;
		transferFirstPerfectSession(iMouse) = transferFirstPerfectValue;
	end
end

naiveFirst = naivePerf(:, 1);
transferFirst = transferPerf(:, 1);
firstPValue = ranksum(naiveFirst, transferFirst);

Report.Params = Params;
Report.NaivePerf = naivePerf;
Report.TransferPerf = transferPerf;
Report.PretrainReached = pretrainReached;
Report.PretrainSessions = pretrainSessions;
Report.PretrainFinalHit = pretrainFinalHit;
Report.NaiveSlope = naiveSlope;
Report.TransferSlope = transferSlope;
Report.NaiveMeanDeltaHit = naiveMeanDeltaHit;
Report.TransferMeanDeltaHit = transferMeanDeltaHit;
Report.NaiveFirstPerfectSession = naiveFirstPerfectSession;
Report.TransferFirstPerfectSession = transferFirstPerfectSession;
Report.Summary = table( ...
	mean(pretrainReached), ...
	median(pretrainSessions, 'omitnan'), ...
	max(pretrainSessions), ...
	mean(naiveFirst, 'omitnan'), ...
	mean(transferFirst, 'omitnan'), ...
	mean(transferFirst, 'omitnan') - mean(naiveFirst, 'omitnan'), ...
	firstPValue, ...
	mean(naivePerf(:, end), 'omitnan'), ...
	mean(transferPerf(:, end), 'omitnan'), ...
	mean(naivePerf, 'all', 'omitnan'), ...
	mean(transferPerf, 'all', 'omitnan'), ...
	mean(naiveSlope, 'omitnan'), ...
	mean(transferSlope, 'omitnan'), ...
	iRanksumIfFinite(naiveSlope, transferSlope), ...
	'VariableNames', {'PretrainReachRate','MedianPretrainSessions','MaxPretrainSessions','NaiveFirst','TransferFirst','TransferMinusNaiveFirst','FirstPValue','NaiveFinal','TransferFinal','NaiveAUC','TransferAUC','NaiveSlope','TransferSlope','SlopePValue'});
end


function pValue = iRanksumIfFinite(valuesA, valuesB)
valuesA = valuesA(isfinite(valuesA));
valuesB = valuesB(isfinite(valuesB));
if isempty(valuesA) || isempty(valuesB)
	pValue = NaN;
	return;
end
pValue = ranksum(valuesA, valuesB);
end
function seedValues = iNormalizeSeedValues(seedValues, numMice)
if isempty(seedValues)
	seedValues = nan(numMice, 1);
	return;
end
if isscalar(seedValues)
	seedValues = double(seedValues) + (0:numMice - 1)';
	return;
end
seedValues = double(seedValues(:));
if numel(seedValues) ~= numMice
	error('THModel:InvalidSeedValues', 'seedValues must be empty, scalar, or contain one value per mouse.');
end
end

function [naivePerf, transferPerf, pretrainReached, pretrainSessions, pretrainFinalHit, naiveSlope, transferSlope, naiveMeanDeltaHit, transferMeanDeltaHit, naiveFirstPerfectSession, transferFirstPerfectSession] = iEvaluateOneMouse(Params, pretrainCond, formalCond, seedValue)
if isfinite(seedValue)
	rng(seedValue, 'twister');
end

naiveMouse = TransferLearning.THModel.DrawMouse(Params);
[naiveResult, ~] = TransferLearning.THModel.SimulateFormalTraining(naiveMouse, Params, formalCond);
naivePerf = naiveResult.Performance;
naiveSlope = naiveResult.Slope;
naiveMeanDeltaHit = naiveResult.MeanDeltaHit;
naiveFirstPerfectSession = naiveResult.FirstPerfectSession;

transferMouse = TransferLearning.THModel.DrawMouse(Params);
[transferMouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(transferMouse, Params, pretrainCond);
pretrainReached = pretrainResult.Reached;
pretrainSessions = pretrainResult.TrainingSessions;
pretrainFinalHit = pretrainResult.FinalHit;

[transferResult, ~] = TransferLearning.THModel.SimulateFormalTraining(transferMouse, Params, formalCond);
transferPerf = transferResult.Performance;
transferSlope = transferResult.Slope;
transferMeanDeltaHit = transferResult.MeanDeltaHit;
transferFirstPerfectSession = transferResult.FirstPerfectSession;
end
