function [perf, Signals, perfExpected, Mouse, TrialTable] = SimulateSessionNoiseFirstStateCarryoverWithInhibitoryStats(Mouse, Params, Cond, usePreCue)
numTrials = Params.NumTrials;

if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	l23InhibitoryCuePattern = Mouse.PreCueL23InhibitoryPattern;
else
	cueInputPattern = Mouse.CueInputPattern;
	l23InhibitoryCuePattern = Mouse.CueL23InhibitoryPattern;
end
eta = Params.HebbRate;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, usePreCue);

rL23CueAll = TransferLearning.THModel.Zeros([Params.NL23, numTrials]);
rL5RewardRecvCueAll = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, numTrials]);
rL5ReadCueAll = TransferLearning.THModel.Zeros([Params.NL5Read, numTrials]);
iL23CueAll = TransferLearning.THModel.Zeros([Params.NIL23, numTrials]);
iL5RewardRecvCueAll = TransferLearning.THModel.Zeros([Params.NIL5RewardRecv, numTrials]);
iL5ReadCueAll = TransferLearning.THModel.Zeros([Params.NIL5Read, numTrials]);
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
	[Mouse, cueDecision] = TransferLearning.THModel.RunCueDecisionLearningFromState(Mouse, Params, initialActivityCue, noisePassState.InhibitoryState.L23, cueInputCue, zeroL5RewardRecvInput, zeroL5ReadInput, inputIL23Cue, eta, teachingSignalScale, Params.RecurrentPasses, true);
	rL23Cue = cueDecision.L23;
	rL5RewardRecvCue = cueDecision.L5RewardRecv;
	rL5ReadCue = cueDecision.L5Read;
	inhibitoryStateCue = cueDecision.InhibitoryState;
	heterogeneityHistoryCue = cueDecision.InternalHistory;
	decisionDrive(iTrial) = cueDecision.DecisionDrive;
	isHit(iTrial) = cueDecision.Hit;
	[~, l5RewardRecvHeterogeneity, l5ReadHeterogeneity] = TransferLearning.THModel.DecisionIterationDeltaActivity(heterogeneityHistoryCue, Mouse, Params, 0);
	rL23Learning = cueDecision.LearningL23;
	rL5RewardRecvLearning = cueDecision.LearningL5RewardRecv;
	rL5ReadLearning = cueDecision.LearningL5Read;
	rL5ReadInhibitoryLearning = cueDecision.LearningL5ReadInhibitory;

	rL23CueAll(:, iTrial) = rL23Cue;
	rL5RewardRecvCueAll(:, iTrial) = rL5RewardRecvCue;
	rL5ReadCueAll(:, iTrial) = rL5ReadCue;
	iL23CueAll(:, iTrial) = inhibitoryStateCue.L23;
	iL5RewardRecvCueAll(:, iTrial) = inhibitoryStateCue.L5RewardRecv;
	iL5ReadCueAll(:, iTrial) = inhibitoryStateCue.L5Read;
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
Signals.ProcessMeanIL23 = TransferLearning.THModel.GatherValue(mean(iL23CueAll, 2));
processMeanL5RewardRecv = mean(l5RewardRecvHeterogeneityAll, 2);
processMeanL5Read = mean(l5ReadHeterogeneityAll, 2);
processMeanIL5RewardRecv = mean(iL5RewardRecvCueAll, 2);
processMeanIL5Read = mean(iL5ReadCueAll, 2);
Signals.ProcessMeanL5 = TransferLearning.THModel.GatherValue([processMeanL5RewardRecv; processMeanL5Read]);
Signals.ProcessMeanL5RewardRecv = TransferLearning.THModel.GatherValue(processMeanL5RewardRecv);
Signals.ProcessMeanL5Read = TransferLearning.THModel.GatherValue(processMeanL5Read);
Signals.ProcessMeanIL5 = TransferLearning.THModel.GatherValue([processMeanIL5RewardRecv; processMeanIL5Read]);
Signals.ProcessMeanIL5RewardRecv = TransferLearning.THModel.GatherValue(processMeanIL5RewardRecv);
Signals.ProcessMeanIL5Read = TransferLearning.THModel.GatherValue(processMeanIL5Read);

if nargout >= 5
	TrialTable = table((1:numTrials)', isHit(:), decisionDrive, noisePassAttempt, noisePassDecisionDrive, 'VariableNames', {'Trial','Hit','DecisionDrive','NoisePassAttempt','NoisePassDecisionDrive'});
end
end
