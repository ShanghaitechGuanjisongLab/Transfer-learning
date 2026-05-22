function [Mouse, Result] = RunCueDecisionLearningFromState(Mouse, Params, initialActivity, initialL23InhibitoryActivity, inputToL23, inputToL5RewardRecv, inputToL5Read, inputToIL23, eta, teachingSignalScale, numDecisionIterations, includeInitialState)
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
if nargin < 8 || isempty(inputToIL23)
	inputToIL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2)]);
end
if nargin < 11 || isempty(numDecisionIterations)
	numDecisionIterations = Params.RecurrentPasses;
end
if nargin < 12 || isempty(includeInitialState)
	includeInitialState = true;
end

state.All = initialActivity;
[state.L23, state.L5RewardRecv, state.L5Read] = TransferLearning.THModel.SplitInternalActivity(state.All, Params);
if nargin < 4 || isempty(initialL23InhibitoryActivity)
	state.IL23 = TransferLearning.THModel.Zeros([Params.NIL23, size(externalPre, 2)]);
else
	state.IL23 = initialL23InhibitoryActivity;
end
state.IL5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, size(externalPre, 2)]);
state.IL5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, size(externalPre, 2)]);
readoutInhibitionSource = [state.L23; state.L5RewardRecv];
l23InhibitoryProjectionSource = state.IL23;

historyLength = numDecisionIterations + double(includeInitialState);
internalHistory = TransferLearning.THModel.Zeros([Params.NL23L5, historyLength]);
inhibitoryHistory.L23 = TransferLearning.THModel.Zeros([Params.NIL23, historyLength]);
inhibitoryHistory.L5RewardRecv = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, historyLength]);
inhibitoryHistory.L5Read = TransferLearning.THModel.Zeros([Params.NIL5Read, historyLength]);
historyCount = 0;
if includeInitialState
	historyCount = 1;
	internalHistory(:, historyCount) = state.All;
	inhibitoryHistory.L23(:, historyCount) = state.IL23;
	inhibitoryHistory.L5RewardRecv(:, historyCount) = state.IL5RewardRecv;
	inhibitoryHistory.L5Read(:, historyCount) = state.IL5Read;
end

decisionDriveTrace = nan(numDecisionIterations, 1);
hitTrace = false(numDecisionIterations, 1);
learningEventCount = 0;
learningIteration = NaN;
learningL23 = TransferLearning.THModel.Zeros([Params.NL23, 1]);
learningL5RewardRecv = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
learningL5Read = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
learningL5ReadInhibitory = TransferLearning.THModel.Zeros([Params.NIL5Read, 1]);

for iIteration = 1:numDecisionIterations
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + max(Mouse.W_L23L5ToL23L5, 0) * state.All, Params);
	state = TransferLearning.THModel.RunInternalAreas(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params, true, readoutInhibitionSource, inputToIL23, l23InhibitoryProjectionSource);
	historyCount = historyCount + 1;
	internalHistory(:, historyCount) = state.All;
	inhibitoryHistory.L23(:, historyCount) = state.IL23;
	inhibitoryHistory.L5RewardRecv(:, historyCount) = state.IL5RewardRecv;
	inhibitoryHistory.L5Read(:, historyCount) = state.IL5Read;

	decisionDriveTrace(iIteration) = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, state.L5Read, state.IL5Read, Params);
	hitTrace(iIteration) = decisionDriveTrace(iIteration) >= Params.HitThreshold;
	if hitTrace(iIteration) && learningEventCount == 0
		[Mouse, ~, eventL23, eventL5RewardRecv, eventL5Read, eventL5ReadInhibitory] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, inputToL23, state.All, state.L23, state.L5RewardRecv, state.L5Read, teachingSignalScale, eta, 1, state.IL23, state.IL5Read, internalHistory(:, 1:historyCount), TransferLearning.THModel.SliceInhibitoryHistory(inhibitoryHistory, historyCount));
		learningEventCount = 1;
		learningIteration = iIteration;
		learningL23 = eventL23;
		learningL5RewardRecv = eventL5RewardRecv;
		learningL5Read = eventL5Read;
		learningL5ReadInhibitory = eventL5ReadInhibitory;
		state.All = TransferLearning.THModel.ApplyReadoutTeachingToInternalActivity(state.All, Mouse, Params, teachingSignalScale);
		[state.L23, state.L5RewardRecv, state.L5Read] = TransferLearning.THModel.SplitInternalActivity(state.All, Params);
		internalHistory(:, historyCount) = state.All;
		inhibitoryHistory.L23(:, historyCount) = state.IL23;
		inhibitoryHistory.L5RewardRecv(:, historyCount) = state.IL5RewardRecv;
		inhibitoryHistory.L5Read(:, historyCount) = state.IL5Read;
	end

	readoutInhibitionSource = [state.L23; state.L5RewardRecv];
	l23InhibitoryProjectionSource = state.IL23;
end

hasHit = any(hitTrace);
if ~hasHit
	[Mouse, ~, learningL23, learningL5RewardRecv, learningL5Read, learningL5ReadInhibitory] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, inputToL23, state.All, state.L23, state.L5RewardRecv, state.L5Read, teachingSignalScale, eta, 1, state.IL23, state.IL5Read, internalHistory(:, 1:historyCount), TransferLearning.THModel.SliceInhibitoryHistory(inhibitoryHistory, historyCount));
	learningEventCount = 1;
	learningIteration = numDecisionIterations;
end

Result.L23 = state.L23;
Result.L5RewardRecv = state.L5RewardRecv;
Result.L5Read = state.L5Read;
Result.InternalActivity = state.All;
Result.InhibitoryState.L23 = state.IL23;
Result.InhibitoryState.L5RewardRecv = state.IL5RewardRecv;
Result.InhibitoryState.L5Read = state.IL5Read;
Result.InternalHistory = internalHistory(:, 1:historyCount);
Result.InhibitoryHistory = TransferLearning.THModel.SliceInhibitoryHistory(inhibitoryHistory, historyCount);
Result.DecisionDrive = max(decisionDriveTrace, [], 'omitnan');
Result.DecisionDriveTrace = decisionDriveTrace;
Result.HitTrace = hitTrace;
Result.Hit = hasHit;
Result.LearningEventCount = learningEventCount;
Result.LearningIteration = learningIteration;
Result.LearningL23 = learningL23;
Result.LearningL5RewardRecv = learningL5RewardRecv;
Result.LearningL5Read = learningL5Read;
Result.LearningL5ReadInhibitory = learningL5ReadInhibitory;
end