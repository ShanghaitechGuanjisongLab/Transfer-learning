function Report = DiagnosePretrainUpdateProjection(Params, seedValue, sessionIndex, numNoiseSamples)
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
	numNoiseSamples = 100;
end
if isfinite(seedValue)
	rng(seedValue, 'twister');
end

Mouse = TransferLearning.THModel.DrawMouse(Params);
pretrainCond.RewardInputLevel = 1.00;
for iSession = 1:sessionIndex - 1
	[~, ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, pretrainCond, true);
end

cueRows = repmat(iEmptyUpdateRow(), numNoiseSamples, 1);
noiseRows = repmat(iEmptyUpdateRow(), numNoiseSamples, 1);
for iSample = 1:numNoiseSamples
	cueRows(iSample) = iCueRewardUpdateDelta(Mouse, Params, pretrainCond, iSample);
	noiseRows(iSample) = iHitNoiseBacktrainDelta(Mouse, Params, iSample);
end
CueTable = struct2table(cueRows);
NoiseTable = struct2table(noiseRows);

hitNoise = NoiseTable(NoiseTable.IsHit, :);
Report.Params = Params;
Report.Seed = seedValue;
Report.SessionIndex = sessionIndex;
Report.NumNoiseSamples = numNoiseSamples;
Report.CueTable = CueTable;
Report.NoiseTable = NoiseTable;
Report.HitNoiseTable = hitNoise;
Report.Summary = table( ...
	mean(CueTable.DriveDelta, 'omitnan'), ...
	mean(CueTable.NoInhDriveDelta, 'omitnan'), ...
	mean(CueTable.TargetDelta, 'omitnan'), ...
	mean(CueTable.OffTargetDelta, 'omitnan'), ...
	mean(NoiseTable.IsHit), ...
	mean(hitNoise.DriveDelta, 'omitnan'), ...
	mean(hitNoise.NoInhDriveDelta, 'omitnan'), ...
	mean(hitNoise.TargetDelta, 'omitnan'), ...
	mean(hitNoise.OffTargetDelta, 'omitnan'), ...
	'VariableNames', {'CueMeanDriveDelta','CueMeanNoInhDriveDelta','CueMeanTargetDelta','CueMeanOffTargetDelta','NoiseHitFraction','HitNoiseMeanDriveDelta','HitNoiseMeanNoInhDriveDelta','HitNoiseMeanTargetDelta','HitNoiseMeanOffTargetDelta'});
end

function row = iCueRewardUpdateDelta(Mouse, Params, Cond, sampleIndex)
MouseBefore = Mouse;
beforeProbe = iPreCueProbe(MouseBefore, Params);
cueInputCue = Mouse.CueInputPattern;
if isfield(Mouse, 'PreCueInputPattern')
	cueInputCue = Mouse.PreCueInputPattern;
end
inputIL23Cue = Mouse.PreCueL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
preL23Cue = cueInputCue + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
preL5RewardRecvCue = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
preL5ReadCue = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue, inhibitoryStateCue, internalHistoryCue, inhibitoryHistoryCue] = TransferLearning.THModel.RunInternalNetwork(preL23Cue, preL5RewardRecvCue, preL5ReadCue, MouseBefore, Params, inputIL23Cue);
MouseAfter = TransferLearning.THModel.ApplyTeachingSignalLearning(MouseBefore, Params, preL23Cue, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, Cond.RewardInputLevel, Params.HebbRate, 1, inhibitoryStateCue.L23, inhibitoryStateCue.L5Read, internalHistoryCue, inhibitoryHistoryCue);
afterProbe = iPreCueProbe(MouseAfter, Params);
row = iUpdateRow(sampleIndex, true, beforeProbe, afterProbe);
end

function row = iHitNoiseBacktrainDelta(Mouse, Params, sampleIndex)
MouseBefore = Mouse;
beforeProbe = iPreCueProbe(MouseBefore, Params);
[noiseDrive, ~, ~, ~, ~, internalHistoryBacktrain, inhibitoryHistoryBacktrain] = iSampleNoiseState(MouseBefore, Params);
MouseAfter = MouseBefore;
if noiseDrive >= Params.HitThreshold
	backtrainEta = -Params.HebbRate;
	MouseAfter = TransferLearning.THModel.ApplyInternalDecayedHistoryPlasticity(MouseAfter, Params, internalHistoryBacktrain, backtrainEta, inhibitoryHistoryBacktrain);
end
afterProbe = iPreCueProbe(MouseAfter, Params);
row = iUpdateRow(sampleIndex, noiseDrive >= Params.HitThreshold, beforeProbe, afterProbe);
end

function [noiseDrive, rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, inhibitoryStateBacktrain, internalHistoryBacktrain, inhibitoryHistoryBacktrain] = iSampleNoiseState(Mouse, Params)
backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
backtrainL23InhibitoryPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL23, 1])));
cueInputBacktrain = Params.NoiseScale * backtrainCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
inputIL23Backtrain = Params.NoiseScale * backtrainL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
preL23Backtrain = cueInputBacktrain + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
preL5RewardRecvBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
preL5ReadBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
[rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, ~, inhibitoryStateBacktrain, internalHistoryBacktrain, inhibitoryHistoryBacktrain] = TransferLearning.THModel.RunInternalNetwork(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params, inputIL23Backtrain, Params.NoiseCueBacktrainRecurrentPasses);
noiseDrive = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadBacktrain, inhibitoryStateBacktrain.L5Read, Params);
end

function Probe = iPreCueProbe(Mouse, Params)
Probe = TransferLearning.THModel.CueDecisionProbe(Mouse, Mouse.PreCueInputPattern, Params, 1, Mouse.PreCueL23InhibitoryPattern);
Probe.NoInhDrive = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, true);
end

function row = iUpdateRow(sampleIndex, isHit, beforeProbe, afterProbe)
row = iEmptyUpdateRow();
row.Sample = sampleIndex;
row.IsHit = isHit;
row.BeforeDrive = beforeProbe.Drive;
row.AfterDrive = afterProbe.Drive;
row.DriveDelta = afterProbe.Drive - beforeProbe.Drive;
row.NoInhDriveDelta = afterProbe.NoInhDrive - beforeProbe.NoInhDrive;
row.TargetDelta = afterProbe.TargetMeanActivity - beforeProbe.TargetMeanActivity;
row.OffTargetDelta = afterProbe.OffTargetMeanActivity - beforeProbe.OffTargetMeanActivity;
end

function row = iEmptyUpdateRow()
row.Sample = NaN;
row.IsHit = false;
row.BeforeDrive = NaN;
row.AfterDrive = NaN;
row.DriveDelta = NaN;
row.NoInhDriveDelta = NaN;
row.TargetDelta = NaN;
row.OffTargetDelta = NaN;
end
