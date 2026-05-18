function Probe = CueDecisionProbe(Mouse, cueInputPattern, Params, cueGain, l23InhibitoryCuePattern)
if nargin < 4
	cueGain = 1;
end
if nargin < 5 || isempty(l23InhibitoryCuePattern)
	l23InhibitoryCuePattern = TransferLearning.THModel.Zeros([Params.NIL23, 1]);
end
inputToL23 = cueGain * cueInputPattern;
inputToIL23 = cueGain * l23InhibitoryCuePattern;
zeroReward = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
zeroRead = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
[l23Activity, l5RewardRecvActivity, l5ReadActivity, ~, inhibitoryState] = TransferLearning.THModel.RunInternalNetwork(inputToL23, zeroReward, zeroRead, Mouse, Params, inputToIL23);
[Probe.Drive, Probe.TargetMeanActivity, Probe.OffTargetMeanActivity] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, l5ReadActivity, inhibitoryState.L5Read, Params);
Probe.RawReadout = Probe.TargetMeanActivity;
Probe.Hit = Probe.Drive >= Params.HitThreshold;
Probe.MeanL23 = TransferLearning.THModel.GatherScalar(mean(l23Activity, 'all'));
Probe.MeanIL23 = TransferLearning.THModel.GatherScalar(mean(inhibitoryState.L23, 'all'));
Probe.MeanL5RewardRecv = TransferLearning.THModel.GatherScalar(mean(l5RewardRecvActivity, 'all'));
Probe.MeanL5Read = TransferLearning.THModel.GatherScalar(mean(l5ReadActivity, 'all'));
Probe.MeanIL5Read = TransferLearning.THModel.GatherScalar(mean(inhibitoryState.L5Read, 'all'));
end
