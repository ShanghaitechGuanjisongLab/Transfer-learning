function state = RunInternalAreas(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, useReadoutInhibition, readoutInhibitionSource, inputToIL23, l23InhibitoryProjectionSource)
if nargin < 6
	useReadoutInhibition = true;
end
if nargin < 7 || isempty(readoutInhibitionSource)
	readoutInhibitionSource = TransferLearning.THModel.Zeros([Params.NL23 + Params.NL5RewardRecv, size(inputToL23, 2)]);
end
if nargin < 8 || isempty(inputToIL23)
	inputToIL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(inputToL23, 2)]);
end
if nargin < 9 || isempty(l23InhibitoryProjectionSource)
	l23InhibitoryProjectionSource = TransferLearning.THModel.Zeros([Params.NIL23, size(inputToL23, 2)]);
end
activeL23InhibitorySource = max(l23InhibitoryProjectionSource, 0);
inputToL5RewardRecv = inputToL5RewardRecv - max(Mouse.WI23ToL5RewardRecv, 0) * activeL23InhibitorySource;
inputToL5Read = inputToL5Read - max(Mouse.WI23ToL5Read, 0) * activeL23InhibitorySource;
[state.L23, state.IL23] = TransferLearning.THModel.RunArea(inputToL23, 'l23', Mouse, Params, inputToIL23);
[state.L5RewardRecv, state.IL5RewardRecv] = TransferLearning.THModel.RunArea(inputToL5RewardRecv, 'l5rewardrecv', Mouse, Params);
if useReadoutInhibition
	[state.L5Read, state.IL5Read] = TransferLearning.THModel.RunReadoutArea(inputToL5Read, readoutInhibitionSource, Mouse, Params);
else
	state.L5Read = TransferLearning.THModel.ClampActivity(Params.ResponseScale * tanh(inputToL5Read), Params);
	state.IL5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, size(inputToL23, 2)]);
end
state.All = [state.L23; state.L5RewardRecv; state.L5Read];
end
