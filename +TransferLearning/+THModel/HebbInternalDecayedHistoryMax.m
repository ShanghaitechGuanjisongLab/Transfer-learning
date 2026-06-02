function recurrentWeights = HebbInternalDecayedHistoryMax(recurrentWeights, postHistory, preHistory, eta, cap, postActivityThreshold, historyDecay, lowerBound)
if nargin < 6 || isempty(postActivityThreshold)
	postActivityThreshold = 0.5;
end
if nargin < 7 || isempty(historyDecay)
	historyDecay = 1;
end
if nargin < 8 || isempty(lowerBound)
	lowerBound = 0;
end
postActivity = TransferLearning.THModel.DecayedHistoryMaxActivity(postHistory, historyDecay);
preActivity = TransferLearning.THModel.DecayedHistoryMaxActivity(preHistory, historyDecay);
recurrentWeights = TransferLearning.THModel.Hebb(recurrentWeights, postActivity, preActivity, eta, cap, postActivityThreshold, lowerBound);
recurrentWeights = TransferLearning.THModel.ZeroSelfProjection(recurrentWeights);
end
