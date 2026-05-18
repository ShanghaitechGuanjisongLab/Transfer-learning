function [Mouse, SessionSummary, TrialTable] = DiagnosePretrainSession(Mouse, Params, usePreCue)
if nargin < 3
	usePreCue = true;
end
numTrials = Params.NumTrials;
if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	l23InhibitoryCuePattern = Mouse.PreCueL23InhibitoryPattern;
else
	cueInputPattern = Mouse.CueInputPattern;
	l23InhibitoryCuePattern = Mouse.CueL23InhibitoryPattern;
end
eta = Params.PretrainHebbRate;

trialIndex = (1:numTrials)';
isHit = false(numTrials, 1);
beforeDrive = nan(numTrials, 1);
beforeNoInhDrive = nan(numTrials, 1);
decisionDrive = nan(numTrials, 1);
afterRewardHebbDrive = nan(numTrials, 1);
afterRewardInhDrive = nan(numTrials, 1);
afterTrialDrive = nan(numTrials, 1);
afterRewardHebbNoInhDrive = nan(numTrials, 1);
afterRewardInhNoInhDrive = nan(numTrials, 1);
afterTrialNoInhDrive = nan(numTrials, 1);
rewardHebbDelta = nan(numTrials, 1);
rewardInhDelta = nan(numTrials, 1);
rewardNoInhDelta = nan(numTrials, 1);
noiseHebbDeltaSum = zeros(numTrials, 1);
noiseInhDeltaSum = zeros(numTrials, 1);
noiseNoInhDeltaSum = zeros(numTrials, 1);
noiseUpdateCount = zeros(numTrials, 1);
noiseTestMaxDrive = nan(numTrials, 1);
noiseTestLastDrive = nan(numTrials, 1);
netDelta = nan(numTrials, 1);
netNoInhDelta = nan(numTrials, 1);
hitPatternDelta = nan(numTrials, 1);
hitPatternNoInhDelta = nan(numTrials, 1);

for iTrial = 1:numTrials
	beforeDrive(iTrial) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
	beforeNoInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);

	cueInputCue = cueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23Cue = l23InhibitoryCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	preL23Cue = cueInputCue + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
	preL5RewardRecvCue = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
	preL5ReadCue = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	[rL23Cue, rL5RewardRecvCue, rL5ReadCue, ~, inhibitoryStateCue, internalHistoryCue] = TransferLearning.THModel.RunInternalNetwork(preL23Cue, preL5RewardRecvCue, preL5ReadCue, Mouse, Params, inputIL23Cue);

	decisionDrive(iTrial) = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadCue, inhibitoryStateCue.L5Read, Params);
	isHit(iTrial) = decisionDrive(iTrial) >= Params.HitThreshold;
	rL23Learning = rL23Cue;
	rL5RewardRecvLearning = rL5RewardRecvCue;
	rL5ReadLearning = TransferLearning.THModel.PatternActivity(Mouse.L5ReadoutPattern, Params);
	rL5ReadInhibitoryLearning = TransferLearning.THModel.PatternActivity(Mouse.L5ReadInhibitoryReadoutPattern, Params);

	postHistory = TransferLearning.THModel.ApplyReadoutTeachingToHistory(internalHistoryCue, rL5ReadLearning, Params);
	Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalLaggedHistory(Mouse.W_L23L5ToL23L5, postHistory, internalHistoryCue, eta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold);
	afterRewardHebbDrive(iTrial) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
	afterRewardHebbNoInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
	rewardHebbDelta(iTrial) = afterRewardHebbDrive(iTrial) - beforeDrive(iTrial);

	actL23Trial = (rL23Cue + rL23Learning) / 2;
	actL5RewardRecvTrial = (rL5RewardRecvCue + rL5RewardRecvLearning) / 2;
	actL5ReadTrial = (rL5ReadCue + rL5ReadLearning) / 2;
	actL5ReadInhibitoryTrial = rL5ReadInhibitoryLearning;
	Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, actL23Trial, actL5RewardRecvTrial, actL5ReadTrial, eta, inhibitoryStateCue.L23, actL5ReadInhibitoryTrial);
	afterRewardInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
	afterRewardInhNoInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
	rewardInhDelta(iTrial) = afterRewardInhDrive(iTrial) - afterRewardHebbDrive(iTrial);
	rewardNoInhDelta(iTrial) = afterRewardInhNoInhDrive(iTrial) - beforeNoInhDrive(iTrial);

	for iBacktrainAttempt = 1:Params.NoiseCueBacktrainMaxAttempts
		backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
		backtrainL23InhibitoryPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL23, 1])));
		cueInputBacktrain = Params.NoiseCueBacktrainInputGain * backtrainCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
		inputIL23BacktrainTest = Params.NoiseCueBacktrainInputGain * backtrainL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
		preL23BacktrainTest = cueInputBacktrain + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
		preL5RewardRecvBacktrainTest = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
		preL5ReadBacktrainTest = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
		[rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, ~, inhibitoryStateBacktrain, internalHistoryBacktrain] = TransferLearning.THModel.RunInternalNetwork(preL23BacktrainTest, preL5RewardRecvBacktrainTest, preL5ReadBacktrainTest, Mouse, Params, inputIL23BacktrainTest, Params.NoiseCueBacktrainRecurrentPasses);
		backtrainDecision = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadBacktrain, inhibitoryStateBacktrain.L5Read, Params);
		if isnan(noiseTestMaxDrive(iTrial)) || backtrainDecision > noiseTestMaxDrive(iTrial)
			noiseTestMaxDrive(iTrial) = backtrainDecision;
		end
		noiseTestLastDrive(iTrial) = backtrainDecision;
		if backtrainDecision < Params.HitThreshold
			break;
		end
		if iBacktrainAttempt == Params.NoiseCueBacktrainMaxAttempts
			error('THModel:NoiseCueBacktrainMaxAttemptsReached', 'Noise-cue backtraining reached %d attempts without finding a non-hit noise cue. Last decision drive = %.3f.', Params.NoiseCueBacktrainMaxAttempts, backtrainDecision);
		end

		noiseUpdateCount(iTrial) = noiseUpdateCount(iTrial) + 1;
		beforeNoiseDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
		beforeNoiseNoInhDrive = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);

		backtrainEta = -eta;
		Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalLaggedHistory(Mouse.W_L23L5ToL23L5, internalHistoryBacktrain, internalHistoryBacktrain, backtrainEta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold);
		afterNoiseHebbDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
		noiseHebbDeltaSum(iTrial) = noiseHebbDeltaSum(iTrial) + afterNoiseHebbDrive - beforeNoiseDrive;

		Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, backtrainEta, inhibitoryStateBacktrain.L23);
		afterNoiseInhDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
		afterNoiseNoInhDrive = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
		noiseInhDeltaSum(iTrial) = noiseInhDeltaSum(iTrial) + afterNoiseInhDrive - afterNoiseHebbDrive;
		noiseNoInhDeltaSum(iTrial) = noiseNoInhDeltaSum(iTrial) + afterNoiseNoInhDrive - beforeNoiseNoInhDrive;
	end

	afterTrialDrive(iTrial) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
	afterTrialNoInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
	netDelta(iTrial) = afterTrialDrive(iTrial) - beforeDrive(iTrial);
	netNoInhDelta(iTrial) = afterTrialNoInhDrive(iTrial) - beforeNoInhDrive(iTrial);
end

TrialTable = table(trialIndex, isHit, beforeDrive, beforeNoInhDrive, decisionDrive, afterRewardHebbDrive, afterRewardInhDrive, afterTrialDrive, afterRewardHebbNoInhDrive, afterRewardInhNoInhDrive, afterTrialNoInhDrive, rewardHebbDelta, rewardInhDelta, rewardNoInhDelta, hitPatternDelta, hitPatternNoInhDelta, noiseHebbDeltaSum, noiseInhDeltaSum, noiseNoInhDeltaSum, noiseUpdateCount, noiseTestMaxDrive, noiseTestLastDrive, netDelta, netNoInhDelta, ...
	'VariableNames', {'Trial','Hit','BeforeDrive','BeforeNoInhDrive','DecisionDrive','AfterRewardHebbDrive','AfterRewardInhDrive','AfterTrialDrive','AfterRewardHebbNoInhDrive','AfterRewardInhNoInhDrive','AfterTrialNoInhDrive','RewardHebbDelta','RewardInhDelta','RewardNoInhDelta','HitPatternDelta','HitPatternNoInhDelta','NoiseHebbDeltaSum','NoiseInhDeltaSum','NoiseNoInhDeltaSum','NoiseUpdateCount','NoiseTestMaxDrive','NoiseTestLastDrive','NetDelta','NetNoInhDelta'});

missMask = ~isHit;
hitMask = isHit;
SessionSummary.HitRate = mean(isHit);
SessionSummary.StartDrive = beforeDrive(1);
SessionSummary.EndDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
SessionSummary.StartNoInhDrive = beforeNoInhDrive(1);
SessionSummary.EndNoInhDrive = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
SessionSummary.MissTrials = sum(missMask);
SessionSummary.MeanRewardHebbDelta = mean(rewardHebbDelta, 'omitnan');
SessionSummary.MeanRewardInhDelta = mean(rewardInhDelta, 'omitnan');
SessionSummary.MeanRewardNoInhDelta = mean(rewardNoInhDelta, 'omitnan');
SessionSummary.MeanHitPatternDelta = mean(hitPatternDelta(hitMask), 'omitnan');
SessionSummary.MeanHitPatternNoInhDelta = mean(hitPatternNoInhDelta(hitMask), 'omitnan');
SessionSummary.MeanNoiseHebbDeltaSum = mean(noiseHebbDeltaSum, 'omitnan');
SessionSummary.MeanNoiseInhDeltaSum = mean(noiseInhDeltaSum, 'omitnan');
SessionSummary.MeanNoiseNoInhDeltaSum = mean(noiseNoInhDeltaSum, 'omitnan');
SessionSummary.MeanNoiseUpdateCount = mean(noiseUpdateCount, 'omitnan');
SessionSummary.TotalNoiseUpdateCount = sum(noiseUpdateCount);
SessionSummary.MeanNetDelta = mean(netDelta, 'omitnan');
SessionSummary.MeanNetNoInhDelta = mean(netNoInhDelta, 'omitnan');
SessionSummary.EndInhibitionGap = SessionSummary.EndNoInhDrive - SessionSummary.EndDrive;
end
