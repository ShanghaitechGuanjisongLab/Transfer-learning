function weights = Hebb(weights, postActivity, preActivity, eta, cap, postActivityThreshold, lowerBound)
if nargin < 6 || isempty(postActivityThreshold)
	postActivityThreshold = 0.5;
end
if nargin < 7 || isempty(lowerBound)
	lowerBound = 0;
end
weights = weights + eta * ((postActivity - postActivityThreshold) * preActivity');
weights = TransferLearning.THModel.ClampWeightsNonnegative(weights, cap, lowerBound);
end
