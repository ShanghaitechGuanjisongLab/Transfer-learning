function recurrentWeights = HebbInternalNoSelf(recurrentWeights, activity, eta, cap, postActivityThreshold, lowerBound)
if nargin < 5 || isempty(postActivityThreshold)
	postActivityThreshold = 0.5;
end
if nargin < 6 || isempty(lowerBound)
	lowerBound = 0;
end
recurrentWeights = TransferLearning.THModel.Hebb(recurrentWeights, activity, activity, eta, cap, postActivityThreshold, lowerBound);
recurrentWeights = TransferLearning.THModel.ZeroSelfProjection(recurrentWeights);
end
