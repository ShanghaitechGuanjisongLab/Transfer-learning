function weights = InitInhibitoryWeights(weightSize, Params)
weights = Params.InitInhWeightMean + Params.InitInhWeightStd * TransferLearning.THModel.InitialWeightNoise(weightSize, Params);
weights = TransferLearning.THModel.ClampWeightsNonnegative(weights, Params.InhWeightMax);
end
