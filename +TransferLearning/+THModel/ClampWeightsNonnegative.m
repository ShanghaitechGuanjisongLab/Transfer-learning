function weights = ClampWeightsNonnegative(weights, upperBound, lowerBound)
if nargin < 3 || isempty(lowerBound)
	lowerBound = 0;
end
weights = min(weights, upperBound);
weights = max(weights, lowerBound);
end
