function recurrentWeights = HebbInternalLaggedHistoryWithEligibility(recurrentWeights, postHistory, preHistory, eta, cap, postActivityThreshold, eligibilityDecay)
if nargin < 6 || isempty(postActivityThreshold)
	postActivityThreshold = 0.5;
end
if nargin < 7 || isempty(eligibilityDecay)
	eligibilityDecay = 1;
end
deltaWeights = zeros(size(recurrentWeights), 'like', recurrentWeights);
numHistoryColumns = size(postHistory, 2);
for iPass = 2:numHistoryColumns
	eligibilityWeight = eligibilityDecay ^ (numHistoryColumns - iPass);
	if eligibilityWeight == 0
		continue;
	end
	deltaWeights = deltaWeights + eligibilityWeight * (postHistory(:, iPass) - postActivityThreshold) * preHistory(:, iPass - 1)';
end
recurrentWeights = TransferLearning.THModel.ClampWeightsNonnegative(recurrentWeights + eta * deltaWeights, cap);
recurrentWeights = TransferLearning.THModel.ZeroSelfProjection(recurrentWeights);
end