function [Mouse, passState, Trace] = RunNoiseCueBacktrainingTrace(Mouse, Params, eta)
maxAttempts = Params.NoiseCueBacktrainMaxAttempts;
attemptIndex = (1:maxAttempts)';
decisionDrive = nan(maxAttempts, 1);
combinedTarget = nan(maxAttempts, 1);
combinedOffTarget = nan(maxAttempts, 1);
l5ReadTarget = nan(maxAttempts, 1);
l5ReadOffTarget = nan(maxAttempts, 1);
iL5ReadTarget = nan(maxAttempts, 1);
iL5ReadOffTarget = nan(maxAttempts, 1);
sameCuePostUpdateDrive = nan(maxAttempts, 1);
sameCuePostUpdateTarget = nan(maxAttempts, 1);
sameCuePostUpdateOffTarget = nan(maxAttempts, 1);
internalCapBefore = nan(maxAttempts, 1);
internalZeroBefore = nan(maxAttempts, 1);
l5ReadWIECapBefore = nan(maxAttempts, 1);
l5ReadWEICapBefore = nan(maxAttempts, 1);

l5TargetMask = Mouse.L5ReadoutPattern(:) > 0;
l5OffTargetMask = ~l5TargetMask;
iTargetMask = Mouse.L5ReadInhibitoryReadoutPattern(:) > 0;
iOffTargetMask = ~iTargetMask;
passState = [];

for iBacktrainAttempt = 1:maxAttempts
	weightSummary = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
	internalCapBefore(iBacktrainAttempt) = weightSummary.InternalCapFraction;
	internalZeroBefore(iBacktrainAttempt) = weightSummary.InternalZeroFraction;
	l5ReadWIECapBefore(iBacktrainAttempt) = weightSummary.L5ReadWIECapFraction;
	l5ReadWEICapBefore(iBacktrainAttempt) = weightSummary.L5ReadWEICapFraction;

	backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
	backtrainL23InhibitoryPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL23, 1])));
	cueInputBacktrain = Params.NoiseScale * backtrainCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23Backtrain = Params.NoiseScale * backtrainL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	preL23Backtrain = cueInputBacktrain + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
	preL5RewardRecvBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
	preL5ReadBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	[rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, internalActivityBacktrain, inhibitoryStateBacktrain, internalHistoryBacktrain, inhibitoryHistoryBacktrain] = TransferLearning.THModel.RunInternalNetwork(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params, inputIL23Backtrain, Params.NoiseCueBacktrainRecurrentPasses);
	[decisionDrive(iBacktrainAttempt), combinedTarget(iBacktrainAttempt), combinedOffTarget(iBacktrainAttempt)] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadBacktrain, inhibitoryStateBacktrain.L5Read, Params);
	l5ReadTarget(iBacktrainAttempt) = mean(rL5ReadBacktrain(l5TargetMask), 'omitnan');
	l5ReadOffTarget(iBacktrainAttempt) = mean(rL5ReadBacktrain(l5OffTargetMask), 'omitnan');
	iL5ReadTarget(iBacktrainAttempt) = mean(inhibitoryStateBacktrain.L5Read(iTargetMask), 'omitnan');
	iL5ReadOffTarget(iBacktrainAttempt) = mean(inhibitoryStateBacktrain.L5Read(iOffTargetMask), 'omitnan');
	if decisionDrive(iBacktrainAttempt) < Params.HitThreshold
		passState.L23 = rL23Backtrain;
		passState.L5RewardRecv = rL5RewardRecvBacktrain;
		passState.L5Read = rL5ReadBacktrain;
		passState.InternalActivity = internalActivityBacktrain;
		passState.InhibitoryState = inhibitoryStateBacktrain;
		passState.InternalHistory = internalHistoryBacktrain;
		passState.InhibitoryHistory = inhibitoryHistoryBacktrain;
		passState.DecisionDrive = decisionDrive(iBacktrainAttempt);
		passState.Attempt = iBacktrainAttempt;
		Trace.Failed = false;
		Trace.Message = "";
		Trace.RngAfter = rng;
		Trace.AttemptTable = table(attemptIndex(1:iBacktrainAttempt), decisionDrive(1:iBacktrainAttempt), combinedTarget(1:iBacktrainAttempt), combinedOffTarget(1:iBacktrainAttempt), l5ReadTarget(1:iBacktrainAttempt), l5ReadOffTarget(1:iBacktrainAttempt), iL5ReadTarget(1:iBacktrainAttempt), iL5ReadOffTarget(1:iBacktrainAttempt), sameCuePostUpdateDrive(1:iBacktrainAttempt), sameCuePostUpdateTarget(1:iBacktrainAttempt), sameCuePostUpdateOffTarget(1:iBacktrainAttempt), internalCapBefore(1:iBacktrainAttempt), internalZeroBefore(1:iBacktrainAttempt), l5ReadWIECapBefore(1:iBacktrainAttempt), l5ReadWEICapBefore(1:iBacktrainAttempt), 'VariableNames', {'Attempt','DecisionDrive','CombinedTarget','CombinedOffTarget','L5ReadTarget','L5ReadOffTarget','IL5ReadTarget','IL5ReadOffTarget','SameCuePostUpdateDrive','SameCuePostUpdateTarget','SameCuePostUpdateOffTarget','InternalCapBefore','InternalZeroBefore','L5ReadWIECapBefore','L5ReadWEICapBefore'});
		return;
	end
	if iBacktrainAttempt == maxAttempts
		Trace.Failed = true;
		Trace.Message = string(sprintf('Noise-cue backtraining reached %d attempts without finding a non-hit noise cue. Last decision drive = %.3f.', Params.NoiseCueBacktrainMaxAttempts, decisionDrive(iBacktrainAttempt)));
		Trace.RngAfter = rng;
		Trace.AttemptTable = table(attemptIndex, decisionDrive, combinedTarget, combinedOffTarget, l5ReadTarget, l5ReadOffTarget, iL5ReadTarget, iL5ReadOffTarget, sameCuePostUpdateDrive, sameCuePostUpdateTarget, sameCuePostUpdateOffTarget, internalCapBefore, internalZeroBefore, l5ReadWIECapBefore, l5ReadWEICapBefore, 'VariableNames', {'Attempt','DecisionDrive','CombinedTarget','CombinedOffTarget','L5ReadTarget','L5ReadOffTarget','IL5ReadTarget','IL5ReadOffTarget','SameCuePostUpdateDrive','SameCuePostUpdateTarget','SameCuePostUpdateOffTarget','InternalCapBefore','InternalZeroBefore','L5ReadWIECapBefore','L5ReadWEICapBefore'});
		return;
	end

	backtrainEta = -eta;
	Mouse = TransferLearning.THModel.ApplyInternalDecayedHistoryPlasticity(Mouse, Params, internalHistoryBacktrain, backtrainEta, inhibitoryHistoryBacktrain);
	[~, ~, rL5ReadPostUpdate, ~, inhibitoryStatePostUpdate] = TransferLearning.THModel.RunInternalNetwork(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params, inputIL23Backtrain, Params.NoiseCueBacktrainRecurrentPasses);
	[sameCuePostUpdateDrive(iBacktrainAttempt), sameCuePostUpdateTarget(iBacktrainAttempt), sameCuePostUpdateOffTarget(iBacktrainAttempt)] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadPostUpdate, inhibitoryStatePostUpdate.L5Read, Params);
end
end