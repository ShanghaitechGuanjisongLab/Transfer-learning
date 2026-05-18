function Probe = ProbeNoiseCueLandscape(Mouse, Params, numNoiseProbe)
if nargin < 3 || isempty(numNoiseProbe)
	numNoiseProbe = Params.NumTrials;
end
drives = nan(numNoiseProbe, 1);
targets = nan(numNoiseProbe, 1);
offTargets = nan(numNoiseProbe, 1);
for iProbe = 1:numNoiseProbe
	backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
	backtrainL23InhibitoryPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL23, 1])));
	cueInputBacktrain = Params.NoiseCueBacktrainInputGain * backtrainCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23Backtrain = Params.NoiseCueBacktrainInputGain * backtrainL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	preL23Backtrain = cueInputBacktrain + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
	preL5RewardRecvBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
	preL5ReadBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	[~, ~, rL5ReadBacktrain, ~, inhibitoryStateBacktrain] = TransferLearning.THModel.RunInternalNetwork(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params, inputIL23Backtrain, Params.NoiseCueBacktrainRecurrentPasses);
	[drives(iProbe), targets(iProbe), offTargets(iProbe)] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadBacktrain, inhibitoryStateBacktrain.L5Read, Params);
end
Probe.HitFraction = mean(drives >= Params.HitThreshold, 'omitnan');
Probe.MeanDrive = mean(drives, 'omitnan');
Probe.MaxDrive = max(drives, [], 'omitnan');
Probe.MeanTarget = mean(targets, 'omitnan');
Probe.MeanOffTarget = mean(offTargets, 'omitnan');
Probe.Drives = drives;
Probe.Targets = targets;
Probe.OffTargets = offTargets;
end