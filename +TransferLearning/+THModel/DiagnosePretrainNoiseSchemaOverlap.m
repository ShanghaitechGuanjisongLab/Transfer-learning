function Report = DiagnosePretrainNoiseSchemaOverlap(Params, seedValue, sessionIndex, numNoiseSamples)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(seedValue)
	seedValue = NaN;
end
if nargin < 3 || isempty(sessionIndex)
	sessionIndex = 1;
end
if nargin < 4 || isempty(numNoiseSamples)
	numNoiseSamples = 200;
end
if isfinite(seedValue)
	rng(seedValue, 'twister');
end

Mouse = TransferLearning.THModel.DrawMouse(Params);
pretrainCond.RewardInputLevel = 1.00;
for iSession = 1:sessionIndex - 1
	[~, ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, pretrainCond, true);
end

[preCueHistory, preCueDrive, preCueTarget, preCueOffTarget] = iCueHistory(Mouse, Params, true);
preCueVector = preCueHistory(:);

noiseRows = repmat(iEmptyNoiseRow(), numNoiseSamples, 1);
for iSample = 1:numNoiseSamples
	[noiseHistory, noiseDrive, noiseTarget, noiseOffTarget] = iNoiseHistory(Mouse, Params);
	noiseVector = noiseHistory(:);
	noiseRows(iSample).Sample = iSample;
	noiseRows(iSample).Drive = noiseDrive;
	noiseRows(iSample).Hit = noiseDrive >= Params.HitThreshold;
	noiseRows(iSample).TargetMeanActivity = noiseTarget;
	noiseRows(iSample).OffTargetMeanActivity = noiseOffTarget;
	noiseRows(iSample).CosineWithPreCueHistory = iCosine(preCueVector, noiseVector);
	noiseRows(iSample).CorrelationWithPreCueHistory = iCorrelation(preCueVector, noiseVector);
end
NoiseTable = struct2table(noiseRows);

hitMask = NoiseTable.Hit;
missMask = ~hitMask;
Report.Params = Params;
Report.Seed = seedValue;
Report.SessionIndex = sessionIndex;
Report.NumNoiseSamples = numNoiseSamples;
Report.PreCueDrive = preCueDrive;
Report.PreCueTargetMeanActivity = preCueTarget;
Report.PreCueOffTargetMeanActivity = preCueOffTarget;
Report.NoiseTable = NoiseTable;
Report.Summary = table( ...
	preCueDrive, ...
	mean(hitMask), ...
	mean(NoiseTable.Drive(hitMask), 'omitnan'), ...
	mean(NoiseTable.Drive(missMask), 'omitnan'), ...
	mean(NoiseTable.CosineWithPreCueHistory(hitMask), 'omitnan'), ...
	mean(NoiseTable.CosineWithPreCueHistory(missMask), 'omitnan'), ...
	mean(NoiseTable.CorrelationWithPreCueHistory(hitMask), 'omitnan'), ...
	mean(NoiseTable.CorrelationWithPreCueHistory(missMask), 'omitnan'), ...
	mean(NoiseTable.TargetMeanActivity(hitMask), 'omitnan'), ...
	mean(NoiseTable.OffTargetMeanActivity(hitMask), 'omitnan'), ...
	'VariableNames', {'PreCueDrive','NoiseHitFraction','HitNoiseMeanDrive','MissNoiseMeanDrive','HitNoiseMeanHistoryCosine','MissNoiseMeanHistoryCosine','HitNoiseMeanHistoryCorrelation','MissNoiseMeanHistoryCorrelation','HitNoiseTargetMeanActivity','HitNoiseOffTargetMeanActivity'});
end

function [internalHistory, drive, targetMeanActivity, offTargetMeanActivity] = iCueHistory(Mouse, Params, usePreCue)
if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	l23InhibitoryCuePattern = Mouse.PreCueL23InhibitoryPattern;
else
	cueInputPattern = Mouse.CueInputPattern;
	l23InhibitoryCuePattern = Mouse.CueL23InhibitoryPattern;
end
preL23 = cueInputPattern;
inputIL23 = l23InhibitoryCuePattern;
preL5RewardRecv = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
preL5Read = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
[~, ~, rL5Read, ~, inhibitoryState, internalHistory] = TransferLearning.THModel.RunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, Params, inputIL23);
[drive, targetMeanActivity, offTargetMeanActivity] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5Read, inhibitoryState.L5Read, Params);
end

function [internalHistory, drive, targetMeanActivity, offTargetMeanActivity] = iNoiseHistory(Mouse, Params)
backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
backtrainL23InhibitoryPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL23, 1])));
cueInputBacktrain = Params.NoiseScale * backtrainCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
inputIL23Backtrain = Params.NoiseScale * backtrainL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
preL23Backtrain = cueInputBacktrain + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
preL5RewardRecvBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
preL5ReadBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
[~, ~, rL5ReadBacktrain, ~, inhibitoryStateBacktrain, internalHistory] = TransferLearning.THModel.RunInternalNetwork(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params, inputIL23Backtrain, Params.NoiseCueBacktrainRecurrentPasses);
[drive, targetMeanActivity, offTargetMeanActivity] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadBacktrain, inhibitoryStateBacktrain.L5Read, Params);
end

function value = iCosine(a, b)
a = double(gather(a(:)));
b = double(gather(b(:)));
denominator = norm(a) * norm(b);
if denominator == 0
	value = NaN;
else
	value = (a' * b) / denominator;
end
end

function value = iCorrelation(a, b)
a = double(gather(a(:)));
b = double(gather(b(:)));
if numel(a) < 2 || std(a, 0, 'omitnan') == 0 || std(b, 0, 'omitnan') == 0
	value = NaN;
else
	value = corr(a, b, 'Rows', 'complete');
end
end

function row = iEmptyNoiseRow()
row.Sample = NaN;
row.Drive = NaN;
row.Hit = false;
row.TargetMeanActivity = NaN;
row.OffTargetMeanActivity = NaN;
row.CosineWithPreCueHistory = NaN;
row.CorrelationWithPreCueHistory = NaN;
end
