function [Mouse, rewardActivity, l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity, l5ReadInhibitoryLearningActivity] = ApplySingleTeachingEventLearning(Mouse, Params, learningHistory, inhibitoryLearningHistory, teachingSignalScale, eta)
eligibilityDecay = 1;
if isfield(Params, 'PlasticityEligibilityDecay') && ~isempty(Params.PlasticityEligibilityDecay)
	eligibilityDecay = Params.PlasticityEligibilityDecay;
end
rewardActivity = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
learningPreActivity = learningHistory(:, end);
learningPostActivity = TransferLearning.THModel.ApplyReadoutTeachingEventToActivity(learningPreActivity, Mouse, Params, teachingSignalScale);
[l23LearningActivity, l5RewardRecvLearningActivity, l5ReadLearningActivity] = TransferLearning.THModel.SplitInternalActivity(learningPostActivity, Params);

postHistory = learningHistory;
postHistory(:, end) = learningPostActivity;
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalLaggedHistoryWithEligibility(Mouse.W_L23L5ToL23L5, postHistory, learningHistory, eta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold, eligibilityDecay, Params.InitWeightMin);

fullL5ReadInhibitoryTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadInhibitoryReadoutPattern, Params);
l5ReadInhibitoryLearningActivity = teachingSignalScale * fullL5ReadInhibitoryTeachingActivity;
if teachingSignalScale > 0
	actL5ReadInhibitoryTrial = l5ReadInhibitoryLearningActivity;
else
	actL5ReadInhibitoryTrial = [];
end
Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticityHistory(Mouse, Params, postHistory, inhibitoryLearningHistory, eta, actL5ReadInhibitoryTrial, eligibilityDecay);
end
