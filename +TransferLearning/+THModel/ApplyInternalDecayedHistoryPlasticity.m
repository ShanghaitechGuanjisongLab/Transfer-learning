function [Mouse, l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity] = ApplyInternalDecayedHistoryPlasticity(Mouse, Params, internalHistory, eta, inhibitoryHistory)
learningActivity = TransferLearning.THModel.DecayedHistoryMaxActivity(internalHistory, Params.DecisionIterationEarlyWeightDecay);
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.Hebb(Mouse.W_L23L5ToL23L5, learningActivity, learningActivity, eta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold);
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.ZeroSelfProjection(Mouse.W_L23L5ToL23L5);
[l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity] = TransferLearning.THModel.SplitInternalActivity(learningActivity, Params);
if nargin < 5
	inhibitoryHistory = [];
end
inhibitoryLearningActivity = TransferLearning.THModel.DecayedInhibitoryHistoryMax(inhibitoryHistory, Params);
Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity, eta, inhibitoryLearningActivity.L23, inhibitoryLearningActivity.L5Read, inhibitoryLearningActivity.L5RewardRecv);
end
