function [Mouse, passState] = RunNoiseCueBacktrainingUntilPassSingleTeachingEvent(Mouse, Params, eta)
eligibilityDecay = 1;
if isfield(Params, 'PlasticityEligibilityDecay') && ~isempty(Params.PlasticityEligibilityDecay)
	eligibilityDecay = Params.PlasticityEligibilityDecay;
end

for iBacktrainAttempt = 1:Params.NoiseCueBacktrainMaxAttempts
	backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
	backtrainL23InhibitoryPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL23, 1])));
	cueInputBacktrain = Params.NoiseCueBacktrainInputGain * backtrainCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23BacktrainTest = Params.NoiseCueBacktrainInputGain * backtrainL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	preL23BacktrainTest = cueInputBacktrain + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
	preL5RewardRecvBacktrainTest = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
	preL5ReadBacktrainTest = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
	[rL23Backtrain, rL5RewardRecvBacktrain, rL5ReadBacktrain, internalActivityBacktrain, inhibitoryStateBacktrain, internalHistoryBacktrain, inhibitoryHistoryBacktrain] = TransferLearning.THModel.RunInternalNetworkWithInhibitoryHistory(preL23BacktrainTest, preL5RewardRecvBacktrainTest, preL5ReadBacktrainTest, Mouse, Params, inputIL23BacktrainTest, Params.NoiseCueBacktrainRecurrentPasses);
	backtrainDecision = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadBacktrain, inhibitoryStateBacktrain.L5Read, Params);
	if backtrainDecision < Params.HitThreshold
		passState.L23 = rL23Backtrain;
		passState.L5RewardRecv = rL5RewardRecvBacktrain;
		passState.L5Read = rL5ReadBacktrain;
		passState.InternalActivity = internalActivityBacktrain;
		passState.InhibitoryState = inhibitoryStateBacktrain;
		passState.InternalHistory = internalHistoryBacktrain;
		passState.InhibitoryHistory = inhibitoryHistoryBacktrain;
		passState.DecisionDrive = backtrainDecision;
		passState.Attempt = iBacktrainAttempt;
		return;
	end
	if iBacktrainAttempt == Params.NoiseCueBacktrainMaxAttempts
		error('THModel:NoiseCueBacktrainMaxAttemptsReached', 'Noise-cue backtraining reached %d attempts without finding a non-hit noise cue. Last decision drive = %.3f.', Params.NoiseCueBacktrainMaxAttempts, backtrainDecision);
	end

	backtrainEta = -eta;
	Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalLaggedHistoryWithEligibility(Mouse.W_L23L5ToL23L5, internalHistoryBacktrain, internalHistoryBacktrain, backtrainEta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold, eligibilityDecay);
	Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticityHistory(Mouse, Params, internalHistoryBacktrain, inhibitoryHistoryBacktrain, backtrainEta, [], eligibilityDecay);
end
end
