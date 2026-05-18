function weights = InitialBoundedLinearWeights(weightSize, lowerBound, upperBound)
if isscalar(weightSize)
	weightSize = [weightSize, 1];
end
weightSpan = upperBound - lowerBound;
if weightSpan <= 0
	error('THModel:InvalidInitialWeightBounds', 'WeightMax must be greater than InitWeightMin.');
end
unitSamples = rand(weightSize);
weights = lowerBound + weightSpan * (1 - sqrt(unitSamples));
end