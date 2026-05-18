function Mouse = DrawMouse(Params)
[Mouse.PreCueInputPattern, Mouse.CueInputPattern] = TransferLearning.THModel.DrawCuePatternPair(Params.NCueInput, Params.CueInputGainPretrain, Params.CueInputGain, Params.CueModalityCorr, Params);
[Mouse.PreCueL23InhibitoryPattern, Mouse.CueL23InhibitoryPattern] = TransferLearning.THModel.DrawCuePatternPair(Params.NIL23, Params.CueInputGainPretrain, Params.CueInputGain, Params.CueModalityCorr, Params);
Mouse.L5ReadoutPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NL5Read, 1]) + 0.55 * sign(TransferLearning.THModel.Randn([Params.NL5Read, 1]))));
Mouse.L5ReadInhibitoryReadoutPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL5Read, 1]) + 0.55 * sign(TransferLearning.THModel.Randn([Params.NIL5Read, 1]))));

Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.ZeroSelfProjection(TransferLearning.THModel.InitExcitatoryWeights([Params.NL23L5, Params.NL23L5], Params));

weightEToI_L23 = TransferLearning.THModel.InitInhibitoryWeights([Params.NIL23, Params.NL23], Params);
weightIToE_L23 = TransferLearning.THModel.InitInhibitoryWeights([Params.NL23, Params.NIL23], Params);
Mouse.WIE_L23 = weightIToE_L23;
Mouse.WEI_L23 = weightEToI_L23;
Mouse.WII_L23 = TransferLearning.THModel.InitIToIWeights(Params.NIL23, Params);
weightEToI_L5RewardRecv = TransferLearning.THModel.InitInhibitoryWeights([Params.NIL5RewardRecv, Params.NL5RewardRecv], Params);
weightIToE_L5RewardRecv = TransferLearning.THModel.InitInhibitoryWeights([Params.NL5RewardRecv, Params.NIL5RewardRecv], Params);
Mouse.WIE_L5RewardRecv = weightIToE_L5RewardRecv;
Mouse.WEI_L5RewardRecv = weightEToI_L5RewardRecv;
Mouse.WII_L5RewardRecv = TransferLearning.THModel.InitIToIWeights(Params.NIL5RewardRecv, Params);
weightEToI_L5Read = TransferLearning.THModel.InitInhibitoryWeights([Params.NIL5Read, Params.NL23 + Params.NL5RewardRecv], Params);
weightIToE_L5Read = TransferLearning.THModel.InitInhibitoryWeights([Params.NL5Read, Params.NIL5Read], Params);
Mouse.WIE_L5Read = weightIToE_L5Read;
Mouse.WEI_L5Read = weightEToI_L5Read;
Mouse.WII_L5Read = TransferLearning.THModel.InitIToIWeights(Params.NIL5Read, Params);
Mouse.WI23ToL5RewardRecv = TransferLearning.THModel.InitInhibitoryWeights([Params.NL5RewardRecv, Params.NIL23], Params);
Mouse.WI23ToL5Read = TransferLearning.THModel.InitInhibitoryWeights([Params.NL5Read, Params.NIL23], Params);
end
