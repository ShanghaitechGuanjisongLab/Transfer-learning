function weights = HebbAfferent(weights, postActivity, preActivity, eta, cap)
weights = TransferLearning.THModel.Hebb(weights, postActivity, preActivity, eta, cap);
end
