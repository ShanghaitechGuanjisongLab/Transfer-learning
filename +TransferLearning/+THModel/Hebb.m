function weights = Hebb(weights, postActivity, preActivity, eta, cap)
weights = weights + eta * (postActivity * preActivity');
weights = TransferLearning.THModel.ClampWeightsNonnegative(weights, cap);
end
