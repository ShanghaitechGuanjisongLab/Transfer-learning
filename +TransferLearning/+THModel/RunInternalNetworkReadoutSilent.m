function [l23Activity, l5RewardRecvActivity, l5ReadActivity, internalActivity] = RunInternalNetworkReadoutSilent(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params)
state = TransferLearning.THModel.RunInternalAreasReadoutSilent(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params);
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
for iPass = 1:Params.RecurrentPasses
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + (Mouse.W_L23L5ToL23L5 * state.All) / Params.NL23L5, Params);
	state = TransferLearning.THModel.RunInternalAreasReadoutSilent(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params);
end
l23Activity = state.L23;
l5RewardRecvActivity = state.L5RewardRecv;
l5ReadActivity = state.L5Read;
internalActivity = state.All;
end
