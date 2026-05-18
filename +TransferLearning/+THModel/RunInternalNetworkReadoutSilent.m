function [l23Activity, l5RewardRecvActivity, l5ReadActivity, internalActivity, inhibitoryState] = RunInternalNetworkReadoutSilent(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, inputToIL23)
if nargin < 6 || isempty(inputToIL23)
	inputToIL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(inputToL23, 2)]);
end
state = TransferLearning.THModel.RunInternalAreasReadoutSilent(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, inputToIL23);
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
for iPass = 1:Params.RecurrentPasses
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + max(Mouse.W_L23L5ToL23L5, 0) * state.All, Params);
	state = TransferLearning.THModel.RunInternalAreasReadoutSilent(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params, inputToIL23, state.IL23);
end
l23Activity = state.L23;
l5RewardRecvActivity = state.L5RewardRecv;
l5ReadActivity = state.L5Read;
internalActivity = state.All;
inhibitoryState.L23 = state.IL23;
inhibitoryState.L5RewardRecv = state.IL5RewardRecv;
inhibitoryState.L5Read = state.IL5Read;
end
