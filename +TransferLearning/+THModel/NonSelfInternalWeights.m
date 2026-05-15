function weights = NonSelfInternalWeights(weights)
weights = TransferLearning.THModel.GatherValue(weights);
numCells = size(weights, 1);
internalMask = true(size(weights));
internalMask(1:numCells+1:end) = false;
weights = weights(internalMask);
end
