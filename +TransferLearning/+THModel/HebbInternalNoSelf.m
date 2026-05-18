function recurrentWeights = HebbInternalNoSelf(recurrentWeights, activity, eta, cap, postActivityThreshold)
if nargin < 5 || isempty(postActivityThreshold)
	postActivityThreshold = 0.5;
end
recurrentWeights = TransferLearning.THModel.Hebb(recurrentWeights, activity, activity, eta, cap, postActivityThreshold);
recurrentWeights = TransferLearning.THModel.ZeroSelfProjection(recurrentWeights);
end
