function state = RunInternalAreasReadoutSilent(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, inputToIL23, l23InhibitoryProjectionSource)
if nargin < 6 || isempty(inputToIL23)
	inputToIL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(inputToL23, 2)]);
end
if nargin < 7 || isempty(l23InhibitoryProjectionSource)
	l23InhibitoryProjectionSource = TransferLearning.THModel.Zeros([Params.NIL23, size(inputToL23, 2)]);
end
inputToL5RewardRecv = inputToL5RewardRecv - max(Mouse.WI23ToL5RewardRecv, 0) * max(l23InhibitoryProjectionSource, 0);
[state.L23, state.IL23] = TransferLearning.THModel.RunArea(inputToL23, 'l23', Mouse, Params, inputToIL23);
[state.L5RewardRecv, state.IL5RewardRecv] = TransferLearning.THModel.RunArea(inputToL5RewardRecv, 'l5rewardrecv', Mouse, Params);
state.L5Read = TransferLearning.THModel.Zeros([Params.NL5Read, size(inputToL5Read, 2)]);
state.IL5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, size(inputToL5Read, 2)]);
state.All = [state.L23; state.L5RewardRecv; state.L5Read];
end
