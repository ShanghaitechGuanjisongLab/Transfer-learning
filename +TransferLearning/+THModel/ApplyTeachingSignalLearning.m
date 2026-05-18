function [Mouse, rewardActivity, l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity, l5ReadInhibitoryLearningActivity] = ApplyTeachingSignalLearning(Mouse, Params, ~, ~, l23CueActivity, l5RewardRecvCueActivity, l5ReadCueActivity, teachingSignalScale, eta, teachingScale, l23InhibitoryCueActivity, ~, internalHistory)
if nargin < 10 || isempty(teachingScale)
	teachingScale = 1;
end
if nargin < 11 || isempty(l23InhibitoryCueActivity)
	l23InhibitoryCueActivity = [];
end
scaledTeachingSignal = teachingScale * teachingSignalScale;
rewardActivity = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
l23LearningActivity = l23CueActivity;
fullL5ReadTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadoutPattern, Params);
fullL5ReadInhibitoryTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadInhibitoryReadoutPattern, Params);
l5RewardRecvLearningActivity = l5RewardRecvCueActivity;
l5ReadLearningActivity = l5ReadCueActivity + scaledTeachingSignal * (fullL5ReadTeachingActivity - l5ReadCueActivity);
l5ReadInhibitoryLearningActivity = scaledTeachingSignal * fullL5ReadInhibitoryTeachingActivity;

postHistory = internalHistory;
l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
postHistory(l5ReadRows, :) = internalHistory(l5ReadRows, :) + scaledTeachingSignal * (repmat(fullL5ReadTeachingActivity(:), 1, size(internalHistory, 2)) - internalHistory(l5ReadRows, :));
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalLaggedHistory(Mouse.W_L23L5ToL23L5, postHistory, internalHistory, eta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold);

actL23Trial = (l23CueActivity + l23LearningActivity) / 2;
actL5RewardRecvTrial = (l5RewardRecvCueActivity + l5RewardRecvLearningActivity) / 2;
actL5ReadTrial = (l5ReadCueActivity + l5ReadLearningActivity) / 2;
if scaledTeachingSignal > 0
	actL5ReadInhibitoryTrial = l5ReadInhibitoryLearningActivity;
else
	actL5ReadInhibitoryTrial = [];
end
Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, actL23Trial, actL5RewardRecvTrial, actL5ReadTrial, eta, l23InhibitoryCueActivity, actL5ReadInhibitoryTrial);
end