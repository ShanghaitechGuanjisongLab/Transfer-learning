function weights = InitExcitatoryWeights(weightSize, Params)
weights = TransferLearning.THModel.InitialBoundedLinearWeights(weightSize, Params.InitWeightMin, Params.WeightMax);
end
