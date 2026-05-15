function [perf, Signals, perfExpected, Mouse, TrialTable] = SimulateSession(Mouse, Params, Cond, usePreCue)
numTrials = Params.NumTrials;

if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	cueGain = Params.CueInputGainPretrain;
else
	cueInputPattern = Mouse.CueInputPattern;
	cueGain = Params.CueInputGain;
end
rewardInputLevel = Cond.RewardInputLevel;
formalHebbGain = 1;
if ~usePreCue
	formalHebbGain = Mouse.FormalHebbGain;
end
eta = Params.HebbRate * formalHebbGain;

rL23CueAll = TransferLearning.THModel.Zeros([Params.NL23, numTrials]);
rL5RewardRecvCueAll = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, numTrials]);
rL5ReadCueAll = TransferLearning.THModel.Zeros([Params.NL5Read, numTrials]);
rL23LearningAll = TransferLearning.THModel.Zeros([Params.NL23, numTrials]);
rRewardLearningAll = TransferLearning.THModel.Zeros([Params.NReward, numTrials]);
rL5RewardRecvLearningAll = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, numTrials]);
rL5ReadLearningAll = TransferLearning.THModel.Zeros([Params.NL5Read, numTrials]);
isHit = false(1, numTrials);
decisionDrive = nan(numTrials, 1);

for iTrial = 1:numTrials
	cueInputCue = cueGain * cueInputPattern + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	preL23Cue = cueInputCue + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NL23, 1]);
	preL5RewardRecvCue = Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
	preL5ReadCue = Params.NoiseRead * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue] = TransferLearning.THModel.RunInternalNetwork(preL23Cue, preL5RewardRecvCue, preL5ReadCue, Mouse, Params);

	decisionDrive(iTrial) = TransferLearning.THModel.GatherScalar(mean(Mouse.L5ReadoutPattern .* rL5ReadCue));
	isHit(iTrial) = decisionDrive(iTrial) >= Params.HitThreshold;
	if isHit(iTrial)
		[Mouse, rRewardLearning] = TransferLearning.THModel.ApplyEmergentHitLearning(Mouse, Params, rL23Cue, rL5RewardRecvCue, rL5ReadCue, rewardInputLevel, eta);
		rL23Learning = rL23Cue;
		rL5RewardRecvLearning = rL5RewardRecvCue;
		rL5ReadLearning = rL5ReadCue;
		if ~usePreCue && Params.FormalHitTeachingScale > 0
			[Mouse, rRewardLearning, rL23Learning, rL5RewardRecvLearning, rL5ReadLearning] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, preL23Cue, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, rewardInputLevel, eta, Params.FormalHitTeachingScale);
		end
	else
		[Mouse, rRewardLearning, rL23Learning, rL5RewardRecvLearning, rL5ReadLearning] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, preL23Cue, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, rewardInputLevel, eta, 1);
	end

	for iBacktrainAttempt = 1:Params.NoiseCueBacktrainMaxAttempts
		backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
		cueInputBacktrain = Params.NoiseCueBacktrainInputGain * backtrainCuePattern + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
		preL23BacktrainTest = cueInputBacktrain + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NL23, 1]);
		preL5RewardRecvBacktrainTest = Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
		preL5ReadBacktrainTest = Params.NoiseRead * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
		[~, ~, rL5ReadBacktrainTest] = TransferLearning.THModel.RunInternalNetwork(preL23BacktrainTest, preL5RewardRecvBacktrainTest, preL5ReadBacktrainTest, Mouse, Params);

		backtrainDecision = TransferLearning.THModel.GatherScalar(mean(Mouse.L5ReadoutPattern .* rL5ReadBacktrainTest));
		if backtrainDecision < Params.HitThreshold
			break;
		end
		if iBacktrainAttempt == Params.NoiseCueBacktrainMaxAttempts
			error('THModel:NoiseCueBacktrainMaxAttemptsReached', 'Noise-cue backtraining reached %d attempts without finding a non-hit noise cue. Last decision drive = %.3f.', Params.NoiseCueBacktrainMaxAttempts, backtrainDecision);
		end

		preL23Backtrain = cueInputBacktrain + Params.NoiseCue * TransferLearning.THModel.Randn([Params.NL23, 1]);
		if rewardInputLevel > 0
			preRewardBacktrain = Params.NoiseRew * TransferLearning.THModel.Randn([Params.NReward, 1]);
			rRewardBacktrain = TransferLearning.THModel.RunArea(preRewardBacktrain, 'reward', Mouse, Params);
		else
			rRewardBacktrain = TransferLearning.THModel.Zeros([Params.NReward, 1]);
		end
		preL5RewardRecvBacktrain = (Mouse.W_RewardToL5RewardRecv * rRewardBacktrain) / Params.RewardAfferentNorm + Params.NoiseRew * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
		preL5ReadBacktrain = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
		[rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain] = TransferLearning.THModel.RunInternalNetworkReadoutSilent(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params);

		backtrainEta = -eta;
		Mouse.W_RewardToL5RewardRecv = TransferLearning.THModel.HebbAfferent(Mouse.W_RewardToL5RewardRecv, rL5RewardRecvBacktrain, rRewardBacktrain, backtrainEta, Params.AfferentWCap);
		internalActivityBacktrain = [rL23Backtrain; rL5RewardRecvBacktrain; rL5ReadBacktrain];
		Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalNoSelf(Mouse.W_L23L5ToL23L5, internalActivityBacktrain, backtrainEta, Params.WCap);
		Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, -1);
	end

	rL23CueAll(:, iTrial) = rL23Cue;
	rL5RewardRecvCueAll(:, iTrial) = rL5RewardRecvCue;
	rL5ReadCueAll(:, iTrial) = rL5ReadCue;
	rL23LearningAll(:, iTrial) = rL23Learning;
	rRewardLearningAll(:, iTrial) = rRewardLearning;
	rL5RewardRecvLearningAll(:, iTrial) = rL5RewardRecvLearning;
	rL5ReadLearningAll(:, iTrial) = rL5ReadLearning;
end

perf = mean(isHit);
perfExpected = perf;

Signals.mL23 = TransferLearning.THModel.GatherValue(mean(rL23LearningAll, 2));
Signals.mReward = TransferLearning.THModel.GatherValue(mean(rRewardLearningAll, 2));
Signals.mL5RewardRecv = TransferLearning.THModel.GatherValue(mean(rL5RewardRecvLearningAll, 2));
Signals.mL5Read = TransferLearning.THModel.GatherValue(mean(rL5ReadLearningAll, 2));
Signals.ProcessMeanL23 = TransferLearning.THModel.GatherValue(mean(rL23CueAll, 2));
processMeanL5RewardRecv = mean(rL5RewardRecvCueAll, 2);
processMeanL5Read = mean(rL5ReadCueAll, 2);
Signals.ProcessMeanL5 = TransferLearning.THModel.GatherValue([processMeanL5RewardRecv; processMeanL5Read]);
Signals.ProcessMeanL5RewardRecv = TransferLearning.THModel.GatherValue(processMeanL5RewardRecv);
Signals.ProcessMeanL5Read = TransferLearning.THModel.GatherValue(processMeanL5Read);

if nargout >= 5
	TrialTable = table((1:numTrials)', isHit(:), decisionDrive, 'VariableNames', {'Trial','Hit','DecisionDrive'});
end
end