function WII = InitIToIWeights(numInhibitoryCells, Params)
weights = TransferLearning.THModel.InitInhibitoryWeights([numInhibitoryCells, numInhibitoryCells], Params);
WII = TransferLearning.THModel.ZeroSelfProjection(weights);
end
