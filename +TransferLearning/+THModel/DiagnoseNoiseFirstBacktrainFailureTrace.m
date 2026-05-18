function Report = DiagnoseNoiseFirstBacktrainFailureTrace(Params, Cond, seedValue, maxFormalSessions, probeCount)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(Cond)
	condTable = TransferLearning.THModel.ConditionTable();
	Cond = condTable(condTable.Name == "Transfer", :);
end
if nargin < 3 || isempty(seedValue)
	seedValue = NaN;
end
if nargin < 4 || isempty(maxFormalSessions)
	maxFormalSessions = Params.NumSessions;
end
if nargin < 5 || isempty(probeCount)
	probeCount = 500;
end
Params.NoiseFirstStateCarryover = 1;
if isfinite(seedValue)
	rng(seedValue, 'twister');
end

pretrainCond.RewardInputLevel = 1.00;
Mouse = TransferLearning.THModel.DrawMouse(Params);
[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, pretrainCond);
eta = Params.FormalHebbRate;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, false);

maxTrialsTotal = maxFormalSessions * Params.NumTrials;
trialRows = repmat(struct('Session',NaN,'Trial',NaN,'Hit',false,'DecisionDrive',NaN,'CombinedTarget',NaN,'CombinedOffTarget',NaN,'L5ReadTarget',NaN,'L5ReadOffTarget',NaN,'IL5ReadTarget',NaN,'IL5ReadOffTarget',NaN,'NoisePassAttempt',NaN,'NoisePassDecisionDrive',NaN), maxTrialsTotal, 1);
sessionRows = repmat(struct('Session',NaN,'Completed',false,'Failed',false,'HitRate',NaN,'MeanDecisionDrive',NaN,'MaxDecisionDrive',NaN,'MeanNoisePassAttempt',NaN,'MaxNoisePassAttempt',NaN,'MeanNoisePassDecisionDrive',NaN), maxFormalSessions, 1);
trialCount = 0;

Report = struct();
Report.Seed = seedValue;
Report.PretrainResult = pretrainResult;
Report.Failed = false;
Report.FailureSession = NaN;
Report.FailureTrial = NaN;
Report.FailureMessage = "";
Report.FailureAttemptTable = table();
Report.PreFailureProbe = struct();
Report.PostAttemptProbe = struct();

l5TargetMask = Mouse.L5ReadoutPattern(:) > 0;
l5OffTargetMask = ~l5TargetMask;
iTargetMask = Mouse.L5ReadInhibitoryReadoutPattern(:) > 0;
iOffTargetMask = ~iTargetMask;
for iSession = 1:maxFormalSessions
	sessionStartTrial = trialCount + 1;
	for iTrial = 1:Params.NumTrials
		mouseBeforeTrial = Mouse;
		rngBeforeTrial = rng;
		[Mouse, noisePassState, backtrainTrace] = TransferLearning.THModel.RunNoiseCueBacktrainingTrace(Mouse, Params, eta);
		if backtrainTrace.Failed
			Report.Failed = true;
			Report.FailureSession = iSession;
			Report.FailureTrial = iTrial;
			Report.FailureMessage = backtrainTrace.Message;
			Report.FailureAttemptTable = backtrainTrace.AttemptTable;
			Report.MouseBeforeFailure = mouseBeforeTrial;
			Report.MouseAfterFailedAttempts = Mouse;
			Report.RngBeforeFailure = rngBeforeTrial;
			Report.RngAfterFailedAttempts = backtrainTrace.RngAfter;
			rng(rngBeforeTrial);
			Report.PreFailureProbe = TransferLearning.THModel.ProbeNoiseCueLandscape(mouseBeforeTrial, Params, probeCount);
			rng(backtrainTrace.RngAfter);
			Report.PostAttemptProbe = TransferLearning.THModel.ProbeNoiseCueLandscape(Mouse, Params, probeCount);
			break;
		end

		cueInputCue = Mouse.CueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
		inputIL23Cue = Mouse.CueL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
		initialActivityCue = noisePassState.InternalActivity;
		l23Rows = 1:Params.NL23;
		initialActivityCue(l23Rows) = TransferLearning.THModel.ClampActivity(initialActivityCue(l23Rows) + cueInputCue, Params);
		zeroL5RewardRecvInput = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
		zeroL5ReadInput = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
		[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue, inhibitoryStateCue, internalHistoryCue] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivityCue, noisePassState.InhibitoryState.L23, cueInputCue, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23Cue, Params.RecurrentPasses, true);
		[decisionDrive, combinedTarget, combinedOffTarget] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadCue, inhibitoryStateCue.L5Read, Params);
		trialCount = trialCount + 1;
		trialRows(trialCount).Session = iSession;
		trialRows(trialCount).Trial = iTrial;
		trialRows(trialCount).Hit = decisionDrive >= Params.HitThreshold;
		trialRows(trialCount).DecisionDrive = decisionDrive;
		trialRows(trialCount).CombinedTarget = combinedTarget;
		trialRows(trialCount).CombinedOffTarget = combinedOffTarget;
		trialRows(trialCount).L5ReadTarget = mean(rL5ReadCue(l5TargetMask), 'omitnan');
		trialRows(trialCount).L5ReadOffTarget = mean(rL5ReadCue(l5OffTargetMask), 'omitnan');
		trialRows(trialCount).IL5ReadTarget = mean(inhibitoryStateCue.L5Read(iTargetMask), 'omitnan');
		trialRows(trialCount).IL5ReadOffTarget = mean(inhibitoryStateCue.L5Read(iOffTargetMask), 'omitnan');
		trialRows(trialCount).NoisePassAttempt = noisePassState.Attempt;
		trialRows(trialCount).NoisePassDecisionDrive = noisePassState.DecisionDrive;
		[Mouse, ~, ~, ~, ~, ~] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, cueInputCue, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, teachingSignalScale, eta, 1, inhibitoryStateCue.L23, inhibitoryStateCue.L5Read, internalHistoryCue);
	end
	if Report.Failed
		sessionRows(iSession).Session = iSession;
		sessionRows(iSession).Failed = true;
		break;
	end
	sessionTrialRange = sessionStartTrial:trialCount;
	sessionRows(iSession).Session = iSession;
	sessionRows(iSession).Completed = true;
	sessionRows(iSession).HitRate = mean([trialRows(sessionTrialRange).Hit], 'omitnan');
	sessionRows(iSession).MeanDecisionDrive = mean([trialRows(sessionTrialRange).DecisionDrive], 'omitnan');
	sessionRows(iSession).MaxDecisionDrive = max([trialRows(sessionTrialRange).DecisionDrive], [], 'omitnan');
	sessionRows(iSession).MeanNoisePassAttempt = mean([trialRows(sessionTrialRange).NoisePassAttempt], 'omitnan');
	sessionRows(iSession).MaxNoisePassAttempt = max([trialRows(sessionTrialRange).NoisePassAttempt], [], 'omitnan');
	sessionRows(iSession).MeanNoisePassDecisionDrive = mean([trialRows(sessionTrialRange).NoisePassDecisionDrive], 'omitnan');
end

Report.SessionTable = struct2table(sessionRows);
Report.TrialTable = struct2table(trialRows(1:trialCount));
Report.FinalWeightSummary = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
end