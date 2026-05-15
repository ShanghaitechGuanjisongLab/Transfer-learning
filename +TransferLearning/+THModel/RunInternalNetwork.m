function [l23Activity, l5RewardRecvActivity, l5ReadActivity, internalActivity] = RunInternalNetwork(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params)
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
state.All = TransferLearning.THModel.Zeros([Params.NL23L5, size(externalPre, 2)]);
previousReadoutSource = TransferLearning.THModel.Zeros([Params.NL23 + Params.NL5RewardRecv, size(externalPre, 2)]);
readoutInhibitionSource = previousReadoutSource;
for iPass = 0:Params.RecurrentPasses
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + (Mouse.W_L23L5ToL23L5 * state.All) / Params.NL23L5, Params);
	state = TransferLearning.THModel.RunInternalAreas(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params, true, readoutInhibitionSource);
	readoutInhibitionSource = previousReadoutSource;
	previousReadoutSource = [state.L23; state.L5RewardRecv];
end
l23Activity = state.L23;
l5RewardRecvActivity = state.L5RewardRecv;
l5ReadActivity = state.L5Read;
internalActivity = state.All;
end
