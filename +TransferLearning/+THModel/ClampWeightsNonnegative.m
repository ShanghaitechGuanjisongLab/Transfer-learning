function weights = ClampWeightsNonnegative(weights, upperBound)
weights = min(weights, upperBound);
end
