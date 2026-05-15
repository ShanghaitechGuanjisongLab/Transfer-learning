function Mouse = OvernightConsolidate(Mouse, Params)
retention = Params.OvernightRetention;
noiseScale = Params.OvernightNoise;
Mouse.W_RewardToL5RewardRecv = retention * Mouse.W_RewardToL5RewardRecv + noiseScale * TransferLearning.THModel.Randn(size(Mouse.W_RewardToL5RewardRecv));
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.ZeroSelfProjection(retention * Mouse.W_L23L5ToL23L5 + noiseScale * TransferLearning.THModel.Randn(size(Mouse.W_L23L5ToL23L5)));
Mouse.W_RewardToL5RewardRecv = TransferLearning.THModel.ClampWeightsNonnegative(Mouse.W_RewardToL5RewardRecv, Inf);
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.ClampWeightsNonnegative(Mouse.W_L23L5ToL23L5, Inf));
end
