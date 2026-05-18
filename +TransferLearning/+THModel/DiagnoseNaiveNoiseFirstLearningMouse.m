function MouseReport = DiagnoseNaiveNoiseFirstLearningMouse(Params, Cond, mouseIndex, seedValue, numSessions)
if isfinite(seedValue)
	rng(seedValue, 'twister');
end
Mouse = TransferLearning.THModel.DrawMouse(Params);
sessionRows = repmat(iEmptySessionRow(), numSessions, 1);
l5TargetMask = Mouse.L5ReadoutPattern(:) > 0;
l5OffTargetMask = ~l5TargetMask;
iTargetMask = Mouse.L5ReadInhibitoryReadoutPattern(:) > 0;
iOffTargetMask = ~iTargetMask;
failureSession = NaN;
failureMessage = "";

for iSession = 1:numSessions
	sessionRows(iSession).Mouse = mouseIndex;
	sessionRows(iSession).Seed = seedValue;
	sessionRows(iSession).Session = iSession;
	startProbe = iDirectCueProbe(Mouse, Params, l5TargetMask, l5OffTargetMask, iTargetMask, iOffTargetMask);
	sessionRows(iSession).StartDirectDrive = startProbe.Drive;
	sessionRows(iSession).StartDirectNoInhDrive = startProbe.NoInhDrive;
	try
		[hitRate, Signals, ~, Mouse, TrialTable] = TransferLearning.THModel.SimulateSession(Mouse, Params, Cond, false);
	catch ME
		if ME.identifier ~= "THModel:NoiseCueBacktrainMaxAttemptsReached"
			rethrow(ME);
		end
		sessionRows(iSession).Failed = true;
		sessionRows(iSession).FailureMessage = string(ME.message);
		failureSession = iSession;
		failureMessage = string(ME.message);
		break;
	end
	endProbe = iDirectCueProbe(Mouse, Params, l5TargetMask, l5OffTargetMask, iTargetMask, iOffTargetMask);
	weights = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
	processL5Read = Signals.ProcessMeanL5Read(:);
	sessionRows(iSession).Completed = true;
	sessionRows(iSession).HitRate = hitRate;
	sessionRows(iSession).MeanDecisionDrive = mean(TrialTable.DecisionDrive, 'omitnan');
	sessionRows(iSession).MaxDecisionDrive = max(TrialTable.DecisionDrive, [], 'omitnan');
	sessionRows(iSession).MeanNoisePassAttempt = mean(TrialTable.NoisePassAttempt, 'omitnan');
	sessionRows(iSession).MaxNoisePassAttempt = max(TrialTable.NoisePassAttempt, [], 'omitnan');
	sessionRows(iSession).MeanNoisePassDecisionDrive = mean(TrialTable.NoisePassDecisionDrive, 'omitnan');
	sessionRows(iSession).ProcessTargetL5Read = mean(processL5Read(l5TargetMask), 'omitnan');
	sessionRows(iSession).ProcessOffTargetL5Read = mean(processL5Read(l5OffTargetMask), 'omitnan');
	sessionRows(iSession).ProcessTargetMinusOffTarget = sessionRows(iSession).ProcessTargetL5Read - sessionRows(iSession).ProcessOffTargetL5Read;
	sessionRows(iSession).EndDirectDrive = endProbe.Drive;
	sessionRows(iSession).EndDirectNoInhDrive = endProbe.NoInhDrive;
	sessionRows(iSession).EndDirectInhibitionGap = endProbe.NoInhDrive - endProbe.Drive;
	sessionRows(iSession).EndDirectL5ReadTarget = endProbe.L5ReadTarget;
	sessionRows(iSession).EndDirectL5ReadOffTarget = endProbe.L5ReadOffTarget;
	sessionRows(iSession).EndDirectIL5ReadTarget = endProbe.IL5ReadTarget;
	sessionRows(iSession).EndDirectIL5ReadOffTarget = endProbe.IL5ReadOffTarget;
	sessionRows(iSession).InternalCapFraction = weights.InternalCapFraction;
	sessionRows(iSession).InternalZeroFraction = weights.InternalZeroFraction;
	sessionRows(iSession).L5ReadWIECapFraction = weights.L5ReadWIECapFraction;
	sessionRows(iSession).L5ReadWEICapFraction = weights.L5ReadWEICapFraction;
end

completedIndex = find([sessionRows.Completed]);
MouseRow.Mouse = mouseIndex;
MouseRow.Seed = seedValue;
MouseRow.FailureSession = failureSession;
MouseRow.FailureMessage = failureMessage;
MouseRow.CompletedSessions = numel(completedIndex);
if isempty(completedIndex)
	MouseRow.LastCompletedHit = NaN;
	MouseRow.LastCompletedDirectDrive = NaN;
	MouseRow.LastCompletedDirectNoInhDrive = NaN;
	MouseRow.LastCompletedInternalCapFraction = NaN;
else
	lastIndex = completedIndex(end);
	MouseRow.LastCompletedHit = sessionRows(lastIndex).HitRate;
	MouseRow.LastCompletedDirectDrive = sessionRows(lastIndex).EndDirectDrive;
	MouseRow.LastCompletedDirectNoInhDrive = sessionRows(lastIndex).EndDirectNoInhDrive;
	MouseRow.LastCompletedInternalCapFraction = sessionRows(lastIndex).InternalCapFraction;
end

MouseReport.MouseRow = MouseRow;
MouseReport.SessionTable = struct2table(sessionRows);
end

function Probe = iDirectCueProbe(Mouse, Params, l5TargetMask, l5OffTargetMask, iTargetMask, iOffTargetMask)
zeroReward = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
zeroRead = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
[~, ~, rL5Read, ~, inhibitoryState] = TransferLearning.THModel.RunInternalNetwork(Mouse.CueInputPattern, zeroReward, zeroRead, Mouse, Params, Mouse.CueL23InhibitoryPattern);
Probe.Drive = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5Read, inhibitoryState.L5Read, Params);
Probe.NoInhDrive = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, false);
Probe.L5ReadTarget = mean(rL5Read(l5TargetMask), 'omitnan');
Probe.L5ReadOffTarget = mean(rL5Read(l5OffTargetMask), 'omitnan');
Probe.IL5ReadTarget = mean(inhibitoryState.L5Read(iTargetMask), 'omitnan');
Probe.IL5ReadOffTarget = mean(inhibitoryState.L5Read(iOffTargetMask), 'omitnan');
end

function row = iEmptySessionRow()
row.Mouse = NaN;
row.Seed = NaN;
row.Session = NaN;
row.Completed = false;
row.Failed = false;
row.FailureMessage = "";
row.HitRate = NaN;
row.MeanDecisionDrive = NaN;
row.MaxDecisionDrive = NaN;
row.MeanNoisePassAttempt = NaN;
row.MaxNoisePassAttempt = NaN;
row.MeanNoisePassDecisionDrive = NaN;
row.ProcessTargetL5Read = NaN;
row.ProcessOffTargetL5Read = NaN;
row.ProcessTargetMinusOffTarget = NaN;
row.StartDirectDrive = NaN;
row.EndDirectDrive = NaN;
row.StartDirectNoInhDrive = NaN;
row.EndDirectNoInhDrive = NaN;
row.EndDirectInhibitionGap = NaN;
row.EndDirectL5ReadTarget = NaN;
row.EndDirectL5ReadOffTarget = NaN;
row.EndDirectIL5ReadTarget = NaN;
row.EndDirectIL5ReadOffTarget = NaN;
row.InternalCapFraction = NaN;
row.InternalZeroFraction = NaN;
row.L5ReadWIECapFraction = NaN;
row.L5ReadWEICapFraction = NaN;
end