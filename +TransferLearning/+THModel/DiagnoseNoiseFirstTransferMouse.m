function MouseReport = DiagnoseNoiseFirstTransferMouse(Params, Cond, mouseIndex, seedValue, numSessions, nominalSessions)
if isfinite(seedValue)
	rng(seedValue, 'twister');
end
Mouse = TransferLearning.THModel.DrawMouse(Params);
pretrainCond.RewardInputLevel = 1.00;
[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, pretrainCond);

sessionRows = repmat(iEmptySessionRow(), numSessions, 1);
firstPerfectSession = NaN;
lastRawRow = [];
for iSession = 1:numSessions
	if isfinite(firstPerfectSession)
		rawRow = lastRawRow;
		rawRow.Session = iSession;
		rawRow.HitRate = Params.Ceiling;
	else
		[Mouse, rawRow] = iSimulateDiagnosticFormalSession(Mouse, Params, Cond);
		rawRow.Session = iSession;
		if rawRow.HitRate >= Params.Ceiling
			firstPerfectSession = iSession;
			rawRow.HitRate = Params.Ceiling;
		end
		lastRawRow = rawRow;
	end
	rawRow.Mouse = mouseIndex;
	rawRow.Seed = seedValue;
	sessionRows(iSession) = rawRow;
end

nominalIndex = min(nominalSessions, numSessions);
MouseRow.Mouse = mouseIndex;
MouseRow.Seed = seedValue;
MouseRow.PretrainReached = pretrainResult.Reached;
MouseRow.PretrainSessions = pretrainResult.TrainingSessions;
MouseRow.PretrainFinalHit = pretrainResult.FinalHit;
MouseRow.FirstPerfectSession = firstPerfectSession;
MouseRow.NominalHit = sessionRows(nominalIndex).HitRate;
MouseRow.FinalHit = sessionRows(end).HitRate;
MouseRow.FailedAtNominal = sessionRows(nominalIndex).HitRate < Params.Ceiling;
MouseRow.FailedAtFinal = sessionRows(end).HitRate < Params.Ceiling;
MouseRow.NominalMeanDecisionDrive = sessionRows(nominalIndex).MeanDecisionDrive;
MouseRow.NominalMaxDecisionDrive = sessionRows(nominalIndex).MaxDecisionDrive;
MouseRow.NominalCombinedTargetMinusOffTarget = sessionRows(nominalIndex).MeanCombinedTarget - sessionRows(nominalIndex).MeanCombinedOffTarget;
MouseRow.NominalL5ReadTargetMinusOffTarget = sessionRows(nominalIndex).MeanL5ReadTarget - sessionRows(nominalIndex).MeanL5ReadOffTarget;
MouseRow.NominalIL5ReadTargetMinusOffTarget = sessionRows(nominalIndex).MeanIL5ReadTarget - sessionRows(nominalIndex).MeanIL5ReadOffTarget;
MouseRow.NominalInternalCapFraction = sessionRows(nominalIndex).InternalCapFraction;
MouseRow.NominalInternalZeroFraction = sessionRows(nominalIndex).InternalZeroFraction;
MouseRow.NominalL5ReadWIECapFraction = sessionRows(nominalIndex).L5ReadWIECapFraction;
MouseRow.NominalL5ReadWEICapFraction = sessionRows(nominalIndex).L5ReadWEICapFraction;

MouseReport.MouseRow = MouseRow;
MouseReport.SessionTable = struct2table(sessionRows);
end

function [Mouse, row] = iSimulateDiagnosticFormalSession(Mouse, Params, Cond)
numTrials = Params.NumTrials;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, false);
eta = Params.HebbRate;
l5TargetMask = Mouse.L5ReadoutPattern(:) > 0;
l5OffTargetMask = ~l5TargetMask;
iTargetMask = Mouse.L5ReadInhibitoryReadoutPattern(:) > 0;
iOffTargetMask = ~iTargetMask;

isHit = false(numTrials, 1);
decisionDrive = nan(numTrials, 1);
combinedTarget = nan(numTrials, 1);
combinedOffTarget = nan(numTrials, 1);
l5ReadTarget = nan(numTrials, 1);
l5ReadOffTarget = nan(numTrials, 1);
iL5ReadTarget = nan(numTrials, 1);
iL5ReadOffTarget = nan(numTrials, 1);
noisePassAttempt = nan(numTrials, 1);
noisePassDecisionDrive = nan(numTrials, 1);

for iTrial = 1:numTrials
	[Mouse, noisePassState] = TransferLearning.THModel.RunNoiseCueBacktrainingUntilPass(Mouse, Params, eta);
	noisePassAttempt(iTrial) = noisePassState.Attempt;
	noisePassDecisionDrive(iTrial) = noisePassState.DecisionDrive;
	cueInputCue = Mouse.CueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23Cue = Mouse.CueL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	initialActivityCue = noisePassState.InternalActivity;
	l23Rows = 1:Params.NL23;
	initialActivityCue(l23Rows) = TransferLearning.THModel.ClampActivity(initialActivityCue(l23Rows) + cueInputCue, Params);
	zeroL5RewardRecvInput = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
	zeroL5ReadInput = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
	[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue, inhibitoryStateCue, internalHistoryCue, inhibitoryHistoryCue] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivityCue, noisePassState.InhibitoryState.L23, cueInputCue, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23Cue, Params.RecurrentPasses, true);
	[decisionDrive(iTrial), combinedTarget(iTrial), combinedOffTarget(iTrial)] = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadCue, inhibitoryStateCue.L5Read, Params);
	isHit(iTrial) = decisionDrive(iTrial) >= Params.HitThreshold;
	l5ReadTarget(iTrial) = mean(rL5ReadCue(l5TargetMask), 'omitnan');
	l5ReadOffTarget(iTrial) = mean(rL5ReadCue(l5OffTargetMask), 'omitnan');
	iL5ReadTarget(iTrial) = mean(inhibitoryStateCue.L5Read(iTargetMask), 'omitnan');
	iL5ReadOffTarget(iTrial) = mean(inhibitoryStateCue.L5Read(iOffTargetMask), 'omitnan');
	Mouse = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, cueInputCue, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, teachingSignalScale, eta, 1, inhibitoryStateCue.L23, inhibitoryStateCue.L5Read, internalHistoryCue, inhibitoryHistoryCue);
end

weightSummary = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
row = iEmptySessionRow();
row.HitRate = mean(isHit, 'omitnan');
row.MeanDecisionDrive = mean(decisionDrive, 'omitnan');
row.MaxDecisionDrive = max(decisionDrive, [], 'omitnan');
row.MinDecisionDrive = min(decisionDrive, [], 'omitnan');
row.MeanCombinedTarget = mean(combinedTarget, 'omitnan');
row.MeanCombinedOffTarget = mean(combinedOffTarget, 'omitnan');
row.MeanL5ReadTarget = mean(l5ReadTarget, 'omitnan');
row.MeanL5ReadOffTarget = mean(l5ReadOffTarget, 'omitnan');
row.MeanIL5ReadTarget = mean(iL5ReadTarget, 'omitnan');
row.MeanIL5ReadOffTarget = mean(iL5ReadOffTarget, 'omitnan');
row.MeanNoisePassAttempt = mean(noisePassAttempt, 'omitnan');
row.MaxNoisePassAttempt = max(noisePassAttempt, [], 'omitnan');
row.MeanNoisePassDecisionDrive = mean(noisePassDecisionDrive, 'omitnan');
row.InternalCapFraction = weightSummary.InternalCapFraction;
row.InternalZeroFraction = weightSummary.InternalZeroFraction;
row.L5ReadWIECapFraction = weightSummary.L5ReadWIECapFraction;
row.L5ReadWEICapFraction = weightSummary.L5ReadWEICapFraction;
end

function row = iEmptySessionRow()
row.Mouse = NaN;
row.Seed = NaN;
row.Session = NaN;
row.HitRate = NaN;
row.MeanDecisionDrive = NaN;
row.MaxDecisionDrive = NaN;
row.MinDecisionDrive = NaN;
row.MeanCombinedTarget = NaN;
row.MeanCombinedOffTarget = NaN;
row.MeanL5ReadTarget = NaN;
row.MeanL5ReadOffTarget = NaN;
row.MeanIL5ReadTarget = NaN;
row.MeanIL5ReadOffTarget = NaN;
row.MeanNoisePassAttempt = NaN;
row.MaxNoisePassAttempt = NaN;
row.MeanNoisePassDecisionDrive = NaN;
row.InternalCapFraction = NaN;
row.InternalZeroFraction = NaN;
row.L5ReadWIECapFraction = NaN;
row.L5ReadWEICapFraction = NaN;
end