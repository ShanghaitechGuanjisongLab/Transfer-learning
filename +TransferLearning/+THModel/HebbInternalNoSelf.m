function recurrentWeights = HebbInternalNoSelf(recurrentWeights, activity, eta, cap)
recurrentWeights = TransferLearning.THModel.Hebb(recurrentWeights, activity, activity, eta, cap);
recurrentWeights = TransferLearning.THModel.ZeroSelfProjection(recurrentWeights);
end
