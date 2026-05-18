function MouseReport = DiagnosePretrainingFailureMouse(Params, mouseIndex, seedValue, numProbeTrials)
if nargin < 4 || isempty(numProbeTrials)
	numProbeTrials = Params.NumTrials;
end
if isfinite(seedValue)
	rng(seedValue, 'twister');
end

Mouse = TransferLearning.THModel.DrawMouse(Params);
sessionRows = repmat(iEmptySessionRow(), Params.MaxPretrainSessions, 1);
firstPerfectSession = NaN;
lastHitRate = NaN;

for iSession = 1:Params.MaxPretrainSessions
	startDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, true);
	startNoInhDrive = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, true);
	startCueProbe = TransferLearning.THModel.CueDecisionProbe(Mouse, Mouse.PreCueInputPattern, Params, 1, Mouse.PreCueL23InhibitoryPattern);
	startProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "preCue", numProbeTrials, true);
	startRandomProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "randomCue", numProbeTrials, true);
	startZeroProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "zeroCue", numProbeTrials, true);
	preWeights = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);

	if isfinite(firstPerfectSession)
		hitRate = Params.Ceiling;
		endDrive = startDrive;
		endNoInhDrive = startNoInhDrive;
		meanNoiseUpdateCount = 0;
		totalNoiseUpdateCount = 0;
		meanRewardHebbDelta = 0;
		meanRewardInhDelta = 0;
		meanNoiseHebbDeltaSum = 0;
		meanNoiseInhDeltaSum = 0;
		postWeights = preWeights;
	else
		[Mouse, sessionSummary] = TransferLearning.THModel.DiagnosePretrainSession(Mouse, Params, true);
		hitRate = sessionSummary.HitRate;
		lastHitRate = hitRate;
		endDrive = sessionSummary.EndDrive;
		endNoInhDrive = sessionSummary.EndNoInhDrive;
		meanNoiseUpdateCount = sessionSummary.MeanNoiseUpdateCount;
		totalNoiseUpdateCount = sessionSummary.TotalNoiseUpdateCount;
		meanRewardHebbDelta = sessionSummary.MeanRewardHebbDelta;
		meanRewardInhDelta = sessionSummary.MeanRewardInhDelta;
		meanNoiseHebbDeltaSum = sessionSummary.MeanNoiseHebbDeltaSum;
		meanNoiseInhDeltaSum = sessionSummary.MeanNoiseInhDeltaSum;
		postWeights = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
		if hitRate >= Params.Ceiling
			firstPerfectSession = iSession;
			hitRate = Params.Ceiling;
			lastHitRate = Params.Ceiling;
		end
	end

	sessionRows(iSession).Mouse = mouseIndex;
	sessionRows(iSession).Session = iSession;
	sessionRows(iSession).HitRate = hitRate;
	sessionRows(iSession).StartDrive = startDrive;
	sessionRows(iSession).StartNoInhDrive = startNoInhDrive;
	sessionRows(iSession).StartTargetMeanActivity = startCueProbe.TargetMeanActivity;
	sessionRows(iSession).StartOffTargetMeanActivity = startCueProbe.OffTargetMeanActivity;
	sessionRows(iSession).EndDrive = endDrive;
	sessionRows(iSession).EndNoInhDrive = endNoInhDrive;
	sessionRows(iSession).EndInhibitionGap = endNoInhDrive - endDrive;
	sessionRows(iSession).StartProbeHitRate = mean(startProbe.Hit, 'omitnan');
	sessionRows(iSession).StartProbeMeanDrive = mean(startProbe.Drive, 'omitnan');
	sessionRows(iSession).RandomCueHitRate = mean(startRandomProbe.Hit, 'omitnan');
	sessionRows(iSession).RandomCueMeanDrive = mean(startRandomProbe.Drive, 'omitnan');
	sessionRows(iSession).ZeroCueHitRate = mean(startZeroProbe.Hit, 'omitnan');
	sessionRows(iSession).ZeroCueMeanDrive = mean(startZeroProbe.Drive, 'omitnan');
	sessionRows(iSession).InternalMean = postWeights.InternalMean;
	sessionRows(iSession).InternalCapFraction = postWeights.InternalCapFraction;
	sessionRows(iSession).InternalZeroFraction = postWeights.InternalZeroFraction;
	sessionRows(iSession).L5ReadWIEMean = postWeights.L5ReadWIEMean;
	sessionRows(iSession).L5ReadWIECapFraction = postWeights.L5ReadWIECapFraction;
	sessionRows(iSession).L5ReadWEIMean = postWeights.L5ReadWEIMean;
	sessionRows(iSession).L5ReadWEICapFraction = postWeights.L5ReadWEICapFraction;
	sessionRows(iSession).MeanRewardHebbDelta = meanRewardHebbDelta;
	sessionRows(iSession).MeanRewardInhDelta = meanRewardInhDelta;
	sessionRows(iSession).MeanNoiseHebbDeltaSum = meanNoiseHebbDeltaSum;
	sessionRows(iSession).MeanNoiseInhDeltaSum = meanNoiseInhDeltaSum;
	sessionRows(iSession).MeanNoiseUpdateCount = meanNoiseUpdateCount;
	sessionRows(iSession).TotalNoiseUpdateCount = totalNoiseUpdateCount;
end

if isfinite(firstPerfectSession)
	lastHitRate = Params.Ceiling;
end
SessionTable = struct2table(sessionRows);
MouseRow.Mouse = mouseIndex;
MouseRow.Seed = seedValue;
MouseRow.Reached = isfinite(firstPerfectSession);
MouseRow.FirstPerfectSession = firstPerfectSession;
MouseRow.FinalHitRate = lastHitRate;
MouseRow.FinalDrive = sessionRows(end).EndDrive;
MouseRow.FinalNoInhDrive = sessionRows(end).EndNoInhDrive;
MouseRow.FinalInhibitionGap = sessionRows(end).EndInhibitionGap;
MouseRow.FinalRandomCueHitRate = sessionRows(end).RandomCueHitRate;
MouseRow.FinalZeroCueHitRate = sessionRows(end).ZeroCueHitRate;
MouseRow.FinalInternalCapFraction = sessionRows(end).InternalCapFraction;
MouseRow.FinalL5ReadWIECapFraction = sessionRows(end).L5ReadWIECapFraction;
MouseRow.FinalL5ReadWEICapFraction = sessionRows(end).L5ReadWEICapFraction;

MouseReport.MouseRow = MouseRow;
MouseReport.SessionTable = SessionTable;
end

function row = iEmptySessionRow()
row.Mouse = NaN;
row.Session = NaN;
row.HitRate = NaN;
row.StartDrive = NaN;
row.StartNoInhDrive = NaN;
row.StartTargetMeanActivity = NaN;
row.StartOffTargetMeanActivity = NaN;
row.EndDrive = NaN;
row.EndNoInhDrive = NaN;
row.EndInhibitionGap = NaN;
row.StartProbeHitRate = NaN;
row.StartProbeMeanDrive = NaN;
row.RandomCueHitRate = NaN;
row.RandomCueMeanDrive = NaN;
row.ZeroCueHitRate = NaN;
row.ZeroCueMeanDrive = NaN;
row.InternalMean = NaN;
row.InternalCapFraction = NaN;
row.InternalZeroFraction = NaN;
row.L5ReadWIEMean = NaN;
row.L5ReadWIECapFraction = NaN;
row.L5ReadWEIMean = NaN;
row.L5ReadWEICapFraction = NaN;
row.MeanRewardHebbDelta = NaN;
row.MeanRewardInhDelta = NaN;
row.MeanNoiseHebbDeltaSum = NaN;
row.MeanNoiseInhDeltaSum = NaN;
row.MeanNoiseUpdateCount = NaN;
row.TotalNoiseUpdateCount = NaN;
end
