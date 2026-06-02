function Report = CompareNoiseBacktrainUpdateComponents(MouseBeforeFailure, Params, eta, rngBeforeFailure, probeCount)
if nargin < 5 || isempty(probeCount)
	probeCount = 1000;
end
modeNameList = ["None"; "InternalOnly"; "InhibitoryOnly"; "All"];
numModes = numel(modeNameList);
summaryRows = repmat(struct('Mode',"",'FirstPassAttempt',NaN,'Failed',false,'MeanAttemptDrive',NaN,'MinAttemptDrive',NaN,'MaxAttemptDrive',NaN,'FinalInternalCapFraction',NaN,'FinalInternalZeroFraction',NaN,'FinalL5ReadWIECapFraction',NaN,'FinalL5ReadWEICapFraction',NaN,'ProbeHitFraction',NaN,'ProbeMeanDrive',NaN,'ProbeMaxDrive',NaN,'ProbeMeanTarget',NaN,'ProbeMeanOffTarget',NaN), numModes, 1);
modeTraces = cell(numModes, 1);
for iMode = 1:numModes
	modeName = modeNameList(iMode);
	rng(rngBeforeFailure);
	Mouse = MouseBeforeFailure;
	maxAttempts = Params.NoiseCueBacktrainMaxAttempts;
	attemptIndex = (1:maxAttempts)';
	decisionDrive = nan(maxAttempts, 1);
	combinedTarget = nan(maxAttempts, 1);
	combinedOffTarget = nan(maxAttempts, 1);
	sameCuePostUpdateDrive = nan(maxAttempts, 1);
	firstPassAttempt = NaN;
	for iBacktrainAttempt = 1:maxAttempts
		backtrainCuePattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
		backtrainL23InhibitoryPattern = TransferLearning.THModel.BinaryPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NIL23, 1])));
		cueInputBacktrain = Params.NoiseScale * backtrainCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
		inputIL23Backtrain = Params.NoiseScale * backtrainL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
		preL23Backtrain = cueInputBacktrain + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL23, 1]);
		preL5RewardRecvBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5RewardRecv, 1]);
		preL5ReadBacktrain = Params.NoiseScale * TransferLearning.THModel.Randn([Params.NL5Read, 1]);
		[~, ~, rL5ReadBacktrain, ~, inhibitoryStateBacktrain, internalHistoryBacktrain, inhibitoryHistoryBacktrain] = TransferLearning.THModel.RunInternalNetwork(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params, inputIL23Backtrain, Params.NoiseCueBacktrainRecurrentPasses);
		[decisionDrive(iBacktrainAttempt), combinedTarget(iBacktrainAttempt), combinedOffTarget(iBacktrainAttempt)] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadBacktrain, inhibitoryStateBacktrain.L5Read, Params);
		if isnan(firstPassAttempt) && decisionDrive(iBacktrainAttempt) < Params.HitThreshold
			firstPassAttempt = iBacktrainAttempt;
		end
		if iBacktrainAttempt < maxAttempts && decisionDrive(iBacktrainAttempt) >= Params.HitThreshold
			backtrainEta = -eta;
			if modeName == "InternalOnly" || modeName == "All"
				Mouse.W_L23L5ToL23L5 = TransferLearning.THModel.HebbInternalDecayedHistoryMax(Mouse.W_L23L5ToL23L5, internalHistoryBacktrain, internalHistoryBacktrain, backtrainEta, Params.WeightMax, Params.ExcitatoryPostActivityThreshold, Params.DecisionIterationEarlyWeightDecay, Params.InitWeightMin);
			end
			if modeName == "InhibitoryOnly" || modeName == "All"
				[actL23Backtrain, actL5RewardRecvBacktrain, actL5ReadBacktrain] = TransferLearning.THModel.SplitInternalActivity(TransferLearning.THModel.DecayedHistoryMaxActivity(internalHistoryBacktrain, Params.DecisionIterationEarlyWeightDecay), Params);
				inhibitoryLearningActivity = TransferLearning.THModel.DecayedInhibitoryHistoryMax(inhibitoryHistoryBacktrain, Params);
				Mouse = TransferLearning.THModel.ApplyInhibitoryCircuitPlasticity(Mouse, Params, actL23Backtrain, actL5RewardRecvBacktrain, actL5ReadBacktrain, backtrainEta, inhibitoryLearningActivity.L23, inhibitoryLearningActivity.L5Read, inhibitoryLearningActivity.L5RewardRecv);
			end
			[~, ~, rL5ReadPostUpdate, ~, inhibitoryStatePostUpdate] = TransferLearning.THModel.RunInternalNetwork(preL23Backtrain, preL5RewardRecvBacktrain, preL5ReadBacktrain, Mouse, Params, inputIL23Backtrain, Params.NoiseCueBacktrainRecurrentPasses);
			sameCuePostUpdateDrive(iBacktrainAttempt) = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadPostUpdate, inhibitoryStatePostUpdate.L5Read, Params);
		end
	end
	probe = TransferLearning.THModel.ProbeNoiseCueLandscape(Mouse, Params, probeCount);
	weightSummary = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
	summaryRows(iMode).Mode = modeName;
	summaryRows(iMode).FirstPassAttempt = firstPassAttempt;
	summaryRows(iMode).Failed = isnan(firstPassAttempt);
	summaryRows(iMode).MeanAttemptDrive = mean(decisionDrive, 'omitnan');
	summaryRows(iMode).MinAttemptDrive = min(decisionDrive, [], 'omitnan');
	summaryRows(iMode).MaxAttemptDrive = max(decisionDrive, [], 'omitnan');
	summaryRows(iMode).FinalInternalCapFraction = weightSummary.InternalCapFraction;
	summaryRows(iMode).FinalInternalZeroFraction = weightSummary.InternalZeroFraction;
	summaryRows(iMode).FinalL5ReadWIECapFraction = weightSummary.L5ReadWIECapFraction;
	summaryRows(iMode).FinalL5ReadWEICapFraction = weightSummary.L5ReadWEICapFraction;
	summaryRows(iMode).ProbeHitFraction = probe.HitFraction;
	summaryRows(iMode).ProbeMeanDrive = probe.MeanDrive;
	summaryRows(iMode).ProbeMaxDrive = probe.MaxDrive;
	summaryRows(iMode).ProbeMeanTarget = probe.MeanTarget;
	summaryRows(iMode).ProbeMeanOffTarget = probe.MeanOffTarget;
	modeTraces{iMode} = table(attemptIndex, decisionDrive, combinedTarget, combinedOffTarget, sameCuePostUpdateDrive, 'VariableNames', {'Attempt','DecisionDrive','CombinedTarget','CombinedOffTarget','SameCuePostUpdateDrive'});
end
Report.Summary = struct2table(summaryRows);
Report.ModeTraces = modeTraces;
Report.ModeNames = modeNameList;
end