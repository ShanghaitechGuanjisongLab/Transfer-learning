function [Mouse, rewardActivity] = ApplyEmergentHitLearning(Mouse, Params, l23Activity, l5RewardRecvActivity, l5ReadActivity, rewardInputLevel, eta)
if rewardInputLevel > 0
	preReward = rewardInputLevel * Params.RewInputGain * Mouse.RewardPattern;
	rewardActivity = TransferLearning.THModel.RunArea(preReward, 'reward', Mouse, Params);
else
	rewardActivity = TransferLearning.THModel.Zeros([Params.NReward, 1]);
end

Mouse.W_RewardToL5RewardRecv = TransferLearning.THModel.HebbAfferent(Mouse.W_RewardToL5RewardRecv, l5RewardRecvActivity, rewardActivity, eta, Params.AfferentWCap);
internalActivity = [l23Activity; l5RewardRecvActivity; l5ReadActivity];
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalNoSelf(Mouse.W_L23L5ToL23L5, internalActivity, eta, Params.WCap);
Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, l23Activity, l5RewardRecvActivity, l5ReadActivity);
end