function [l23Activity, l5RewardRecvActivity, l5ReadActivity, internalActivity, inhibitoryState, internalHistory] = RunInternalNetwork(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, inputToIL23, numRecurrentPasses, stopAtHit)
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
if nargin < 6 || isempty(inputToIL23)
	inputToIL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2)]);
end
if nargin < 7 || isempty(numRecurrentPasses)
	numRecurrentPasses = Params.RecurrentPasses;
end
if nargin < 8 || isempty(stopAtHit)
	stopAtHit = true;
end
state.All = TransferLearning.THModel.Zeros([Params.NL23L5, size(externalPre, 2)]);
state.IL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2)]);
readoutInhibitionSource = TransferLearning.THModel.Zeros([Params.NL23 + Params.NL5RewardRecv, size(externalPre, 2)]);
l23InhibitoryProjectionSource = state.IL23;
historyCount = 0;
if nargout >= 6
	if size(externalPre, 2) == 1
		internalHistory = TransferLearning.THModel.Zeros([Params.NL23L5, numRecurrentPasses + 1]);
	else
		internalHistory = TransferLearning.THModel.Zeros([Params.NL23L5, size(externalPre, 2), numRecurrentPasses + 1]);
	end
end
for iPass = 0:numRecurrentPasses
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + max(Mouse.W_L23L5ToL23L5, 0) * state.All, Params);
	state = TransferLearning.THModel.RunInternalAreas(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params, true, readoutInhibitionSource, inputToIL23, l23InhibitoryProjectionSource);
	if nargout >= 6
		historyCount = historyCount + 1;
		if size(externalPre, 2) == 1
			internalHistory(:, historyCount) = state.All;
		else
			internalHistory(:, :, historyCount) = state.All;
		end
	end
	decisionDrive = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, state.L5Read, state.IL5Read, Params);
	if stopAtHit && decisionDrive >= Params.HitThreshold
		break;
	end
	readoutInhibitionSource = [state.L23; state.L5RewardRecv];
	l23InhibitoryProjectionSource = state.IL23;
end
if nargout >= 6
	if size(externalPre, 2) == 1
		internalHistory = internalHistory(:, 1:historyCount);
	else
		internalHistory = internalHistory(:, :, 1:historyCount);
	end
end
l23Activity = state.L23;
l5RewardRecvActivity = state.L5RewardRecv;
l5ReadActivity = state.L5Read;
internalActivity = state.All;
inhibitoryState.L23 = state.IL23;
inhibitoryState.L5RewardRecv = state.IL5RewardRecv;
inhibitoryState.L5Read = state.IL5Read;
end
