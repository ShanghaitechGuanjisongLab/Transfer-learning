function [Mouse, rewardActivity, l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity] = ApplyTeachingSignalLearning(Mouse, Params, preL23Learning, decisionActivityCue, l23CueActivity, l5RewardRecvCueActivity, l5ReadCueActivity, rewardInputLevel, eta, teachingScale)
if nargin < 10 || isempty(teachingScale)
	teachingScale = 1;
end

scaledRewardInputLevel = teachingScale * rewardInputLevel;
if scaledRewardInputLevel > 0
	preRewardLearning = scaledRewardInputLevel * Params.RewInputGain * Mouse.RewardPattern + Params.NoiseRew * TransferLearning.THModel.Randn([Params.NReward, 1]);
	rewardActivity = TransferLearning.THModel.RunArea(preRewardLearning, 'reward', Mouse, Params);
else
	rewardActivity = TransferLearning.THModel.Zeros([Params.NReward, 1]);
end
preL5RewardRecvLearning = (Mouse.W_RewardToL5RewardRecv * rewardActivity) / Params.RewardAfferentNorm ...
	+ scaledRewardInputLevel * Params.THRewardRecvInputGain * Mouse.L5RewardRecvTeachingPattern ...
	+ Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
readTeachingGain = Params.ReadInputGain + scaledRewardInputLevel * Params.THReadInputGain;
preL5ReadLearning = readTeachingGain * Mouse.L5ReadoutPattern ...
	+ scaledRewardInputLevel * Params.THReadHeterogeneityGain * Mouse.L5ReadHeterogeneityPattern ...
	+ Params.NoiseRead * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
[l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity] = TransferLearning.THModel.ContinueInternalNetwork(preL23Learning, preL5RewardRecvLearning, preL5ReadLearning, decisionActivityCue, Mouse, Params);

Mouse.W_RewardToL5RewardRecv = TransferLearning.THModel.HebbAfferent(Mouse.W_RewardToL5RewardRecv, l5RewardRecvLearningActivity, rewardActivity, eta, Params.AfferentWCap);
internalActivityLearning = [l23LearningActivity; l5RewardRecvLearningActivity; l5ReadLearningActivity];
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalNoSelf(Mouse.W_L23L5ToL23L5, internalActivityLearning, eta, Params.WCap);

actL23Trial = (l23CueActivity + l23LearningActivity) / 2;
actL5RewardRecvTrial = (l5RewardRecvCueActivity + l5RewardRecvLearningActivity) / 2;
actL5ReadTrial = (l5ReadCueActivity + l5ReadLearningActivity) / 2;
Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, actL23Trial, actL5RewardRecvTrial, actL5ReadTrial);
end