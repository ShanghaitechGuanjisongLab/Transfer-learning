function recurrentWeights = HebbInternalLaggedHistory(recurrentWeights, postHistory, preHistory, eta, cap, postActivityThreshold)
if nargin < 6 || isempty(postActivityThreshold)
	postActivityThreshold = 0.5;
end
deltaWeights = zeros(size(recurrentWeights), 'like', recurrentWeights);
for iPass = 2:size(postHistory, 2)
	deltaWeights = deltaWeights + (postHistory(:, iPass) - postActivityThreshold) * preHistory(:, iPass - 1)';
end
recurrentWeights = TransferLearning.THModel.ClampWeightsNonnegative(recurrentWeights + eta * deltaWeights, cap);
recurrentWeights = TransferLearning.THModel.ZeroSelfProjection(recurrentWeights);
end