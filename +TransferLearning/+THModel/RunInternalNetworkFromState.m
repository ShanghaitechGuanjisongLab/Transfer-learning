function [l23Activity, l5RewardRecvActivity, l5ReadActivity, internalActivity, inhibitoryState, internalHistory, inhibitoryHistory] = RunInternalNetworkFromState(initialActivity, initialL23InhibitoryActivity, inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, inputToIL23, numRecurrentPasses, includeInitialState, stopAtHit)
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
if nargin < 8 || isempty(inputToIL23)
	inputToIL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2)]);
end
if nargin < 9 || isempty(numRecurrentPasses)
	numRecurrentPasses = Params.RecurrentPasses;
end
if nargin < 10 || isempty(includeInitialState)
	includeInitialState = true;
end
if nargin < 11 || isempty(stopAtHit)
	stopAtHit = true;
end

state.All = initialActivity;
[state.L23, state.L5RewardRecv, state.L5Read] = TransferLearning.THModel.SplitInternalActivity(state.All, Params);
if nargin < 2 || isempty(initialL23InhibitoryActivity)
	state.IL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2)]);
else
	state.IL23 = initialL23InhibitoryActivity;
end
state.IL5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, size(externalPre, 2)]);
state.IL5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, size(externalPre, 2)]);
readoutInhibitionSource = [state.L23; state.L5RewardRecv];
l23InhibitoryProjectionSource = state.IL23;
historyCount = 0;
if nargout >= 6
	historyLength = numRecurrentPasses + double(includeInitialState);
	if size(externalPre, 2) == 1
		internalHistory = TransferLearning.THModel.Zeros([Params.NL23L5, historyLength]);
	else
		internalHistory = TransferLearning.THModel.Zeros([Params.NL23L5, size(externalPre, 2), historyLength]);
	end
	if includeInitialState
		historyCount = 1;
		if size(externalPre, 2) == 1
			internalHistory(:, historyCount) = state.All;
		else
			internalHistory(:, :, historyCount) = state.All;
		end
	end
end
if nargout >= 7
	historyLength = numRecurrentPasses + double(includeInitialState);
	if size(externalPre, 2) == 1
		inhibitoryHistory.L23 = TransferLearning.THModel.Zeros([Params.NIL23, historyLength]);
		inhibitoryHistory.L5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, historyLength]);
		inhibitoryHistory.L5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, historyLength]);
	else
		inhibitoryHistory.L23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2), historyLength]);
		inhibitoryHistory.L5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, size(externalPre, 2), historyLength]);
		inhibitoryHistory.L5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, size(externalPre, 2), historyLength]);
	end
	if includeInitialState
		if size(externalPre, 2) == 1
			inhibitoryHistory.L23(:, historyCount) = state.IL23;
			inhibitoryHistory.L5RewardRecv(:, historyCount) = state.IL5RewardRecv;
			inhibitoryHistory.L5Read(:, historyCount) = state.IL5Read;
		else
			inhibitoryHistory.L23(:, :, historyCount) = state.IL23;
			inhibitoryHistory.L5RewardRecv(:, :, historyCount) = state.IL5RewardRecv;
			inhibitoryHistory.L5Read(:, :, historyCount) = state.IL5Read;
		end
	end
end

for iPass = 1:numRecurrentPasses
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
	if nargout >= 7
		if size(externalPre, 2) == 1
			inhibitoryHistory.L23(:, historyCount) = state.IL23;
			inhibitoryHistory.L5RewardRecv(:, historyCount) = state.IL5RewardRecv;
			inhibitoryHistory.L5Read(:, historyCount) = state.IL5Read;
		else
			inhibitoryHistory.L23(:, :, historyCount) = state.IL23;
			inhibitoryHistory.L5RewardRecv(:, :, historyCount) = state.IL5RewardRecv;
			inhibitoryHistory.L5Read(:, :, historyCount) = state.IL5Read;
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
if nargout >= 7
	if size(externalPre, 2) == 1
		inhibitoryHistory.L23 = inhibitoryHistory.L23(:, 1:historyCount);
		inhibitoryHistory.L5RewardRecv = inhibitoryHistory.L5RewardRecv(:, 1:historyCount);
		inhibitoryHistory.L5Read = inhibitoryHistory.L5Read(:, 1:historyCount);
	else
		inhibitoryHistory.L23 = inhibitoryHistory.L23(:, :, 1:historyCount);
		inhibitoryHistory.L5RewardRecv = inhibitoryHistory.L5RewardRecv(:, :, 1:historyCount);
		inhibitoryHistory.L5Read = inhibitoryHistory.L5Read(:, :, 1:historyCount);
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