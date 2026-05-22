function [perf, Signals, perfExpected, Mouse, TrialTable] = SimulateSessionNoiseFirstStateCarryover(Mouse, Params, Cond, usePreCue)
numTrials = Params.NumTrials;

if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	l23InhibitoryCuePattern = Mouse.PreCueL23InhibitoryPattern;
	eta = Params.PretrainHebbRate;
else
	cueInputPattern = Mouse.CueInputPattern;
	l23InhibitoryCuePattern = Mouse.CueL23InhibitoryPattern;
	eta = Params.FormalHebbRate;
end
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, usePreCue);

rL23CueAll = TransferLearning.THModel.Zeros([Params.NL23, numTrials]);
rL5RewardRecvCueAll = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, numTrials]);
rL5ReadCueAll = TransferLearning.THModel.Zeros([Params.NL5Read, numTrials]);
l5RewardRecvHeterogeneityAll = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, numTrials]);
l5ReadHeterogeneityAll = TransferLearning.THModel.Zeros([Params.NL5Read, numTrials]);
rL23LearningAll = TransferLearning.THModel.Zeros([Params.NL23, numTrials]);
rL5RewardRecvLearningAll = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, numTrials]);
rL5ReadLearningAll = TransferLearning.THModel.Zeros([Params.NL5Read, numTrials]);
rL5ReadInhibitoryLearningAll = TransferLearning.THModel.Zeros([Params.NIL5Read, numTrials]);
isHit = false(1, numTrials);
decisionDrive = nan(numTrials, 1);
noisePassAttempt = nan(numTrials, 1);
noisePassDecisionDrive = nan(numTrials, 1);

for iTrial = 1:numTrials
	[Mouse, noisePassState] = TransferLearning.THModel.RunNoiseCueBacktrainingUntilPass(Mouse, Params, eta);
	noisePassAttempt(iTrial) = noisePassState.Attempt;
	noisePassDecisionDrive(iTrial) = noisePassState.DecisionDrive;

	cueInputCue = cueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23Cue = l23InhibitoryCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	initialActivityCue = noisePassState.InternalActivity;
	l23Rows = 1:Params.NL23;
	initialActivityCue(l23Rows) = TransferLearning.THModel.ClampActivity(initialActivityCue(l23Rows) + cueInputCue, Params);
	zeroL5RewardRecvInput = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
	zeroL5ReadInput = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
	[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue, inhibitoryStateCue, internalHistoryCue] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivityCue, noisePassState.InhibitoryState.L23, cueInputCue, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23Cue, Params.RecurrentPasses, true);
	heterogeneityHistoryCue = internalHistoryCue;
	if size(heterogeneityHistoryCue, 2) < Params.RecurrentPasses + 1
		[~, ~, ~, ~, ~, heterogeneityHistoryCue] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivityCue, noisePassState.InhibitoryState.L23, cueInputCue, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23Cue, Params.RecurrentPasses, true, false);
	end
	decisionDrive(iTrial) = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadCue, inhibitoryStateCue.L5Read, Params);
	isHit(iTrial) = decisionDrive(iTrial) >= Params.HitThreshold;
	heterogeneityTeachingSignalScale = teachingSignalScale;
	if ~isHit(iTrial)
		heterogeneityTeachingSignalScale = 0;
	end
	[~, l5RewardRecvHeterogeneity, l5ReadHeterogeneity] = TransferLearning.THModel.DecisionIterationDeltaActivity(heterogeneityHistoryCue, Mouse, Params, heterogeneityTeachingSignalScale);
	[Mouse, ~, rL23Learning, rL5RewardRecvLearning, rL5ReadLearning, rL5ReadInhibitoryLearning] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, cueInputCue, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, teachingSignalScale, eta, 1, inhibitoryStateCue.L23, inhibitoryStateCue.L5Read, internalHistoryCue);

	rL23CueAll(:, iTrial) = rL23Cue;
	rL5RewardRecvCueAll(:, iTrial) = rL5RewardRecvCue;
	rL5ReadCueAll(:, iTrial) = rL5ReadCue;
	l5RewardRecvHeterogeneityAll(:, iTrial) = l5RewardRecvHeterogeneity;
	l5ReadHeterogeneityAll(:, iTrial) = l5ReadHeterogeneity;
	rL23LearningAll(:, iTrial) = rL23Learning;
	rL5RewardRecvLearningAll(:, iTrial) = rL5RewardRecvLearning;
	rL5ReadLearningAll(:, iTrial) = rL5ReadLearning;
	rL5ReadInhibitoryLearningAll(:, iTrial) = rL5ReadInhibitoryLearning;
end

perf = mean(isHit);
perfExpected = perf;

Signals.mL23 = TransferLearning.THModel.GatherValue(mean(rL23LearningAll, 2));
Signals.mReward = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
Signals.mL5RewardRecv = TransferLearning.THModel.GatherValue(mean(rL5RewardRecvLearningAll, 2));
Signals.mL5Read = TransferLearning.THModel.GatherValue(mean(rL5ReadLearningAll, 2));
Signals.mIL5Read = TransferLearning.THModel.GatherValue(mean(rL5ReadInhibitoryLearningAll, 2));
Signals.ProcessMeanL23 = TransferLearning.THModel.GatherValue(mean(rL23CueAll, 2));
processMeanL5RewardRecv = mean(l5RewardRecvHeterogeneityAll, 2);
processMeanL5Read = mean(l5ReadHeterogeneityAll, 2);
Signals.ProcessMeanL5 = TransferLearning.THModel.GatherValue([processMeanL5RewardRecv; processMeanL5Read]);
Signals.ProcessMeanL5RewardRecv = TransferLearning.THModel.GatherValue(processMeanL5RewardRecv);
Signals.ProcessMeanL5Read = TransferLearning.THModel.GatherValue(processMeanL5Read);

if nargout >= 5
	TrialTable = table((1:numTrials)', isHit(:), decisionDrive, noisePassAttempt, noisePassDecisionDrive, 'VariableNames', {'Trial','Hit','DecisionDrive','NoisePassAttempt','NoisePassDecisionDrive'});
end
end