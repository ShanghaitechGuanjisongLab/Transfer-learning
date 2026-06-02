function [Mouse, rewardActivity, l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity, l5ReadInhibitoryLearningActivity] = ApplyTeachingSignalLearning(Mouse, Params, ~, ~, ~, ~, ~, teachingSignalScale, eta, teachingScale, ~, ~, internalHistory, inhibitoryHistory)
if nargin < 10 || isempty(teachingScale)
	teachingScale = 1;
end
scaledTeachingSignal = teachingScale * teachingSignalScale;
rewardActivity = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
fullL5ReadInhibitoryTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadInhibitoryReadoutPattern, Params);
l5ReadInhibitoryLearningActivity = scaledTeachingSignal * fullL5ReadInhibitoryTeachingActivity;

postHistory = internalHistory;
postHistory(:, end) = TransferLearning.THModel.ApplyReadoutTeachingToInternalActivity(internalHistory(:, end), Mouse, Params, scaledTeachingSignal);
preActivity = TransferLearning.THModel.DecayedHistoryMaxActivity(internalHistory, Params.DecisionIterationEarlyWeightDecay);
postActivity = TransferLearning.THModel.DecayedHistoryMaxActivity(postHistory, Params.DecisionIterationEarlyWeightDecay);
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.Hebb(Mouse.W_L23L5ToL23L5, postActivity, preActivity, eta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold, Params.InitWeightMin);
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.ZeroSelfProjection(Mouse.W_L23L5ToL23L5);
[l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity] = TransferLearning.THModel.SplitInternalActivity(postActivity, Params);
if nargin < 14
	inhibitoryHistory = [];
end
inhibitoryLearningActivity = TransferLearning.THModel.DecayedInhibitoryHistoryMax(inhibitoryHistory, Params);

actL23Trial = l23LearningActivity;
actL5RewardRecvTrial = l5RewardRecvLearningActivity;
actL5ReadTrial = l5ReadLearningActivity;
if scaledTeachingSignal > 0
	if isempty(inhibitoryHistory)
		actL5ReadInhibitoryTrial = l5ReadInhibitoryLearningActivity;
	else
		l5ReadInhibitoryPostHistory = inhibitoryHistory.L5Read;
		l5ReadInhibitoryPostHistory(:, end) = l5ReadInhibitoryLearningActivity;
		actL5ReadInhibitoryTrial = TransferLearning.THModel.DecayedHistoryMaxActivity(l5ReadInhibitoryPostHistory, Params.DecisionIterationEarlyWeightDecay);
	end
else
	actL5ReadInhibitoryTrial = inhibitoryLearningActivity.L5Read;
end
Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, actL23Trial, actL5RewardRecvTrial, actL5ReadTrial, eta, inhibitoryLearningActivity.L23, actL5ReadInhibitoryTrial, inhibitoryLearningActivity.L5RewardRecv);
end