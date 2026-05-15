function [Mouse, SessionSummary, TrialTable] = DiagnosePretrainSession(Mouse, Params, usePreCue)
if nargin < 3
	usePreCue = true;
end
numTrials = Params.NumTrials;
if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	cueGain = Params.CueInputGainPretrain;
else
	cueInputPattern = Mouse.CueInputPattern;
	cueGain = Params.CueInputGain;
end
rewardInputLevel = 1.00;
eta = Params.HebbRate;

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

	cueInputCue = cueGain * cueInputPattern + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	preL23Cue = cueInputCue + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NL23, 1]);
	preL5RewardRecvCue = Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
	preL5ReadCue = Params.NoiseRead * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue] = TransferLearning.THModel.RunInternalNetwork(preL23Cue, preL5RewardRecvCue, preL5ReadCue, Mouse, Params);

	decisionDrive(iTrial) = TransferLearning.THModel.GatherScalar(mean(Mouse.L5ReadoutPattern .* rL5ReadCue));
	isHit(iTrial) = decisionDrive(iTrial) >= Params.HitThreshold;
	if isHit(iTrial)
		Mouse = TransferLearning.THModel.ApplyEmergentHitLearning(Mouse, Params, rL23Cue, rL5RewardRecvCue, rL5ReadCue, rewardInputLevel, eta);
		afterTrialDrive(iTrial) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
		afterTrialNoInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
		hitPatternDelta(iTrial) = afterTrialDrive(iTrial) - beforeDrive(iTrial);
		hitPatternNoInhDelta(iTrial) = afterTrialNoInhDrive(iTrial) - beforeNoInhDrive(iTrial);
		netDelta(iTrial) = hitPatternDelta(iTrial);
		netNoInhDelta(iTrial) = hitPatternNoInhDelta(iTrial);
		continue;
	end

	preL23Learning = preL23Cue;
	preRewardLearning = rewardInputLevel * Params.RewInputGain * Mouse.RewardPattern + Params.NoiseRew * TransferLearning.THModel.Randn([Params.NReward, 1]);
	rRewardLearning = TransferLearning.THModel.RunArea(preRewardLearning, 'reward', Mouse, Params);
	preL5RewardRecvLearning = (Mouse.W_RewardToL5RewardRecv * rRewardLearning) / Params.RewardAfferentNorm ...
		+ rewardInputLevel * Params.THRewardRecvInputGain * Mouse.L5RewardRecvTeachingPattern ...
		+ Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
	readTeachingGain = Params.ReadInputGain + rewardInputLevel * Params.THReadInputGain;
	preL5ReadLearning = readTeachingGain * Mouse.L5ReadoutPattern ...
		+ rewardInputLevel * Params.THReadHeterogeneityGain * Mouse.L5ReadHeterogeneityPattern ...
		+ Params.NoiseRead * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	[rL23Learning, rL5RewardRecvLearning, rL5ReadLearning] = TransferLearning.THModel.ContinueInternalNetwork(preL23Learning, preL5RewardRecvLearning, preL5ReadLearning, decisionActivityCue, Mouse, Params);

	Mouse.W_RewardToL5RewardRecv = TransferLearning.THModel.HebbAfferent(Mouse.W_RewardToL5RewardRecv, rL5RewardRecvLearning, rRewardLearning, eta, Params.AfferentWCap);
	internalActivityLearning = [rL23Learning; rL5RewardRecvLearning; rL5ReadLearning];
	Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalNoSelf(Mouse.W_L23L5ToL23L5, internalActivityLearning, eta, Params.WCap);
	afterRewardHebbDrive(iTrial) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
	afterRewardHebbNoInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
	rewardHebbDelta(iTrial) = afterRewardHebbDrive(iTrial) - beforeDrive(iTrial);

	actL23Trial = (rL23Cue + rL23Learning) / 2;
	actL5RewardRecvTrial = (rL5RewardRecvCue + rL5RewardRecvLearning) / 2;
	actL5ReadTrial = (rL5ReadCue + rL5ReadLearning) / 2;
	Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, actL23Trial, actL5RewardRecvTrial, actL5ReadTrial);
	afterRewardInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
	afterRewardInhNoInhDrive(iTrial) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue);
	rewardInhDelta(iTrial) = afterRewardInhDrive(iTrial) - afterRewardHebbDrive(iTrial);
	rewardNoInhDelta(iTrial) = afterRewardInhNoInhDrive(iTrial) - beforeNoInhDrive(iTrial);

	for iBacktrainAttempt = 1:Params.NoiseCueBacktrainMaxAttempts
		backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
		cueInputBacktrain = Params.NoiseCueBacktrainInputGain * backtrainCuePattern + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
		preL23BacktrainTest = cueInputBacktrain + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NL23, 1]);
		preL5RewardRecvBacktrainTest = Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
		preL5ReadBacktrainTest = Params.NoiseRead * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
		[~, ~, rL5ReadBacktrainTest] = TransferLearning.THModel.RunInternalNetwork(preL23BacktrainTest, preL5RewardRecvBacktrainTest, preL5ReadBacktrainTest, Mouse, Params);
		backtrainDecision = TransferLearning.THModel.GatherScalar(mean(Mouse.L5ReadoutPattern .* rL5ReadBacktrainTest));
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

		preL23Backtrain = cueInputBacktrain + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NL23, 1]);
		preRewardBacktrain = Params.NoiseRew * TransferLearning.THModel.Randn([Params.NReward, 1]);
		rRewardBacktrain = TransferLearning.THModel.RunArea(preRewardBacktrain, 'reward', Mouse, Params);
		preL5RewardRecvBacktrain = (Mouse.W_RewardToL5RewardRecv * rRewardBacktrain) / Params.RewardAfferentNorm + Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
		preL5ReadBacktrain = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
		[rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain] = TransferLearning.THModel.RunInternalNetworkReadoutSilent(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params);

		backtrainEta = -eta;
		Mouse.W_RewardToL5RewardRecv = TransferLearning.THModel.HebbAfferent(Mouse.W_RewardToL5RewardRecv, rL5RewardRecvBacktrain, rRewardBacktrain, backtrainEta, Params.AfferentWCap);
		internalActivityBacktrain = [rL23Backtrain; rL5RewardRecvBacktrain; rL5ReadBacktrain];
		Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalNoSelf(Mouse.W_L23L5ToL23L5, internalActivityBacktrain, backtrainEta, Params.WCap);
		afterNoiseHebbDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, usePreCue);
		noiseHebbDeltaSum(iTrial) = noiseHebbDeltaSum(iTrial) + afterNoiseHebbDrive - beforeNoiseDrive;

		Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, -1);
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
SessionSummary.MeanRewardHebbDelta = mean(rewardHebbDelta(missMask), 'omitnan');
SessionSummary.MeanRewardInhDelta = mean(rewardInhDelta(missMask), 'omitnan');
SessionSummary.MeanRewardNoInhDelta = mean(rewardNoInhDelta(missMask), 'omitnan');
SessionSummary.MeanHitPatternDelta = mean(hitPatternDelta(hitMask), 'omitnan');
SessionSummary.MeanHitPatternNoInhDelta = mean(hitPatternNoInhDelta(hitMask), 'omitnan');
SessionSummary.MeanNoiseHebbDeltaSum = mean(noiseHebbDeltaSum(missMask), 'omitnan');
SessionSummary.MeanNoiseInhDeltaSum = mean(noiseInhDeltaSum(missMask), 'omitnan');
SessionSummary.MeanNoiseNoInhDeltaSum = mean(noiseNoInhDeltaSum(missMask), 'omitnan');
SessionSummary.MeanNoiseUpdateCount = mean(noiseUpdateCount(missMask), 'omitnan');
SessionSummary.TotalNoiseUpdateCount = sum(noiseUpdateCount);
SessionSummary.MeanNetDelta = mean(netDelta(missMask), 'omitnan');
SessionSummary.MeanNetNoInhDelta = mean(netNoInhDelta(missMask), 'omitnan');
SessionSummary.EndInhibitionGap = SessionSummary.EndNoInhDrive - SessionSummary.EndDrive;
end
