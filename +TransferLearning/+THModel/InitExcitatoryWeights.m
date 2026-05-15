function weights = InitExcitatoryWeights(weightSize, Params)
weights = Params.InitExcWeightMean + Params.InitExcWeightStd * TransferLearning.THModel.InitialWeightNoise(weightSize, Params);
weights = TransferLearning.THModel.ClampWeightsNonnegative(weights, Inf);
end
