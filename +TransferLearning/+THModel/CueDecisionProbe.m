function Probe = CueDecisionProbe(Mouse, cueInputPattern, Params, cueGain)
if nargin < 4
	cueGain = Params.CueInputGain;
end
inputToL23 = cueGain * cueInputPattern;
zeroReward = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
zeroRead = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
[l23Activity, l5RewardRecvActivity, l5ReadActivity] = TransferLearning.THModel.RunInternalNetwork(inputToL23, zeroReward, zeroRead, Mouse, Params);
Probe.Drive = TransferLearning.THModel.GatherScalar(mean(Mouse.L5ReadoutPattern .* l5ReadActivity));
Probe.RawReadout = Probe.Drive;
Probe.Hit = Probe.Drive >= Params.HitThreshold;
Probe.MeanL23 = TransferLearning.THModel.GatherScalar(mean(l23Activity, 'all'));
Probe.MeanL5RewardRecv = TransferLearning.THModel.GatherScalar(mean(l5RewardRecvActivity, 'all'));
Probe.MeanL5Read = TransferLearning.THModel.GatherScalar(mean(l5ReadActivity, 'all'));
end
