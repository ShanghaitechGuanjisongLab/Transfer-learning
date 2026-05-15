function weights = ClampWeightsNonnegative(weights, upperBound)
weights = max(min(weights, upperBound), 0);
end
