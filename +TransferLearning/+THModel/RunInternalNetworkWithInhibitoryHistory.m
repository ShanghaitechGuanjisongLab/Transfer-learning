function [l23Activity, l5RewardRecvActivity, l5ReadActivity, internalActivity, inhibitoryState, internalHistory, inhibitoryHistory] = RunInternalNetworkWithInhibitoryHistory(inputToL23, inputToL5RewardRecv, inputToL5Read, Mouse, Params, inputToIL23, numRecurrentPasses, stopAtHit)
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
state.IL5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, size(externalPre, 2)]);
state.IL5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, size(externalPre, 2)]);
readoutInhibitionSource = TransferLearning.THModel.Zeros([Params.NL23 + Params.NL5RewardRecv, size(externalPre, 2)]);
l23InhibitoryProjectionSource = state.IL23;
historyCount = 0;
if size(externalPre, 2) == 1
	internalHistory = TransferLearning.THModel.Zeros([Params.NL23L5, numRecurrentPasses + 1]);
	inhibitoryHistory.L23 = TransferLearning.THModel.Zeros([Params.NIL23, numRecurrentPasses + 1]);
	inhibitoryHistory.L5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, numRecurrentPasses + 1]);
	inhibitoryHistory.L5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, numRecurrentPasses + 1]);
else
	internalHistory = TransferLearning.THModel.Zeros([Params.NL23L5, size(externalPre, 2), numRecurrentPasses + 1]);
	inhibitoryHistory.L23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2), numRecurrentPasses + 1]);
	inhibitoryHistory.L5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, size(externalPre, 2), numRecurrentPasses + 1]);
	inhibitoryHistory.L5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, size(externalPre, 2), numRecurrentPasses + 1]);
end
for iPass = 0:numRecurrentPasses
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + max(Mouse.W_L23L5ToL23L5, 0) * state.All, Params);
	state = TransferLearning.THModel.RunInternalAreas(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params, true, readoutInhibitionSource, inputToIL23, l23InhibitoryProjectionSource);
	historyCount = historyCount + 1;
	if size(externalPre, 2) == 1
		internalHistory(:, historyCount) = state.All;
		inhibitoryHistory.L23(:, historyCount) = state.IL23;
		inhibitoryHistory.L5RewardRecv(:, historyCount) = state.IL5RewardRecv;
		inhibitoryHistory.L5Read(:, historyCount) = state.IL5Read;
	else
		internalHistory(:, :, historyCount) = state.All;
		inhibitoryHistory.L23(:, :, historyCount) = state.IL23;
		inhibitoryHistory.L5RewardRecv(:, :, historyCount) = state.IL5RewardRecv;
		inhibitoryHistory.L5Read(:, :, historyCount) = state.IL5Read;
	end
	decisionDrive = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, state.L5Read, state.IL5Read, Params);
	if stopAtHit && decisionDrive >= Params.HitThreshold
		break;
	end
	readoutInhibitionSource = [state.L23; state.L5RewardRecv];
	l23InhibitoryProjectionSource = state.IL23;
end
if size(externalPre, 2) == 1
	internalHistory = internalHistory(:, 1:historyCount);
	inhibitoryHistory.L23 = inhibitoryHistory.L23(:, 1:historyCount);
	inhibitoryHistory.L5RewardRecv = inhibitoryHistory.L5RewardRecv(:, 1:historyCount);
	inhibitoryHistory.L5Read = inhibitoryHistory.L5Read(:, 1:historyCount);
else
	internalHistory = internalHistory(:, :, 1:historyCount);
	inhibitoryHistory.L23 = inhibitoryHistory.L23(:, :, 1:historyCount);
	inhibitoryHistory.L5RewardRecv = inhibitoryHistory.L5RewardRecv(:, :, 1:historyCount);
	inhibitoryHistory.L5Read = inhibitoryHistory.L5Read(:, :, 1:historyCount);
end
l23Activity = state.L23;
l5RewardRecvActivity = state.L5RewardRecv;
l5ReadActivity = state.L5Read;
internalActivity = state.All;
inhibitoryState.L23 = state.IL23;
inhibitoryState.L5RewardRecv = state.IL5RewardRecv;
inhibitoryState.L5Read = state.IL5Read;
end