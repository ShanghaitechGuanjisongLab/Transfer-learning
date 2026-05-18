function weights = Hebb(weights, postActivity, preActivity, eta, cap, postActivityThreshold)
if nargin < 6 || isempty(postActivityThreshold)
	postActivityThreshold = 0.5;
end
weights = weights + eta * ((postActivity - postActivityThreshold) * preActivity');
weights = TransferLearning.THModel.ClampWeightsNonnegative(weights, cap);
end
