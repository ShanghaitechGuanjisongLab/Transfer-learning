function Mouse = DrawMouse(Params)
preCueInputPattern = TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1]));
cueUnique = TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1]));
cueUnique = cueUnique - (sum(cueUnique .* preCueInputPattern) / sum(preCueInputPattern .^ 2)) * preCueInputPattern;
cueUnique = TransferLearning.THModel.Standardize(cueUnique);
cueInputPattern = TransferLearning.THModel.Standardize(Params.CueModalityCorr * preCueInputPattern + sqrt(1 - Params.CueModalityCorr ^ 2) * cueUnique);
Mouse.PreCueInputPattern = TransferLearning.THModel.ClampPattern(preCueInputPattern, Params);
Mouse.CueInputPattern = TransferLearning.THModel.ClampPattern(cueInputPattern, Params);
Mouse.RewardPattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NReward, 1]) + 0.55 * sign(TransferLearning.THModel.Randn([Params.NReward, 1]))), Params);
Mouse.L5ReadoutPattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NL5Read, 1]) + 0.55 * sign(TransferLearning.THModel.Randn([Params.NL5Read, 1]))), Params);
Mouse.FormalHebbGain = TransferLearning.THModel.MouseScalarGain(Params.FormalHebbGainStd, Params.FormalHebbGainMin, Params.FormalHebbGainMax);
Mouse.L5RewardRecvTeachingPattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]) + 0.55 * sign(TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]))), Params);
readHeterogeneityPattern = TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NL5Read, 1]) + 0.55 * sign(TransferLearning.THModel.Randn([Params.NL5Read, 1])));
readHeterogeneityPattern = readHeterogeneityPattern - (sum(readHeterogeneityPattern .* Mouse.L5ReadoutPattern) / sum(Mouse.L5ReadoutPattern .^ 2)) * Mouse.L5ReadoutPattern;
Mouse.L5ReadHeterogeneityPattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(readHeterogeneityPattern), Params);

Mouse.W_RewardToL5RewardRecv = TransferLearning.THModel.InitExcitatoryWeights([Params.NL5RewardRecv, Params.NReward], Params);
Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.InitExcitatoryWeights([Params.NL23L5, Params.NL23L5], Params));

Mouse.WIE_L23 = TransferLearning.THModel.InitInhibitoryWeights([Params.NIL23, Params.NL23], Params);
Mouse.WEI_L23 = TransferLearning.THModel.InitInhibitoryWeights([Params.NL23, Params.NIL23], Params);
Mouse.WII_L23 = TransferLearning.THModel.InitIToIWeights(Params.NIL23, Params);
Mouse.WIE_L5RewardRecv = TransferLearning.THModel.InitInhibitoryWeights([Params.NIL5RewardRecv, Params.NL5RewardRecv], Params);
Mouse.WEI_L5RewardRecv = TransferLearning.THModel.InitInhibitoryWeights([Params.NL5RewardRecv, Params.NIL5RewardRecv], Params);
Mouse.WII_L5RewardRecv = TransferLearning.THModel.InitIToIWeights(Params.NIL5RewardRecv, Params);
Mouse.WIE_L5Read = TransferLearning.THModel.InitInhibitoryWeights([Params.NIL5Read, Params.NL23 + Params.NL5RewardRecv], Params);
Mouse.WEI_L5Read = TransferLearning.THModel.InitInhibitoryWeights([Params.NL5Read, Params.NIL5Read], Params);
Mouse.WII_L5Read = TransferLearning.THModel.InitIToIWeights(Params.NIL5Read, Params);
end
