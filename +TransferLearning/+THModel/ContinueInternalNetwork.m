function [l23Activity, l5RewardRecvActivity, l5ReadActivity, internalActivity, inhibitoryState] = ContinueInternalNetwork(inputToL23, inputToL5RewardRecv, inputToL5Read, initialActivity, Mouse, Params, inputToIL23, initialL23InhibitoryActivity)
if nargin < 7 || isempty(inputToIL23)
	inputToIL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(inputToL23, 2)]);
end
if nargin < 8 || isempty(initialL23InhibitoryActivity)
	initialL23InhibitoryActivity = TransferLearning.THModel.Zeros([Params.NIL23, size(inputToL23, 2)]);
end
state.All = initialActivity;
state.IL23 = initialL23InhibitoryActivity;
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
for iPass = 1:Params.RecurrentPasses
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + max(Mouse.W_L23L5ToL23L5, 0) * state.All, Params);
	state = TransferLearning.THModel.RunInternalAreas(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params, false, [], inputToIL23, state.IL23);
end
l23Activity = state.L23;
l5RewardRecvActivity = state.L5RewardRecv;
l5ReadActivity = state.L5Read;
internalActivity = state.All;
inhibitoryState.L23 = state.IL23;
inhibitoryState.L5RewardRecv = state.IL5RewardRecv;
inhibitoryState.L5Read = state.IL5Read;
end
