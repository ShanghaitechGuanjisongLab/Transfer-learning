function inhibitoryActivity = DecayedInhibitoryHistoryMax(inhibitoryHistory, Params)
if nargin < 1 || isempty(inhibitoryHistory)
	inhibitoryActivity.L23 = [];
	inhibitoryActivity.L5RewardRecv = [];
	inhibitoryActivity.L5Read = [];
	return;
end
inhibitoryActivity.L23 = TransferLearning.THModel.DecayedHistoryMaxActivity(inhibitoryHistory.L23, Params.DecisionIterationEarlyWeightDecay);
inhibitoryActivity.L5RewardRecv = TransferLearning.THModel.DecayedHistoryMaxActivity(inhibitoryHistory.L5RewardRecv, Params.DecisionIterationEarlyWeightDecay);
inhibitoryActivity.L5Read = TransferLearning.THModel.DecayedHistoryMaxActivity(inhibitoryHistory.L5Read, Params.DecisionIterationEarlyWeightDecay);
end
