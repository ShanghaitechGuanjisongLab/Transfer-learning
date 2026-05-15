function Report = DiagnoseTransferFormalLimit(Params, numMice, numDiagnosticSessions)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(numMice)
	numMice = Params.NumMice;
end
if nargin < 3 || isempty(numDiagnosticSessions)
	numDiagnosticSessions = 16;
end

pretrainCond.RewardInputLevel = 1.00;
formalCond.RewardInputLevel = 1.00;
sessionRows = struct([]);
mouseRows = struct([]);
rowIndex = 0;

for iMouse = 1:numMice
	Mouse = TransferLearning.THModel.DrawMouse(Params);
	pretrainReached = false;
	pretrainFinalHit = NaN;
	for iPretrainSession = 1:Params.MaxPretrainSessions
		[pretrainFinalHit, ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, pretrainCond, true);
		if pretrainFinalHit >= Params.Ceiling
			pretrainReached = true;
			break;
		end
		Mouse = TransferLearning.THModel.OvernightConsolidate(Mouse, Params);
	end

	formalHit = nan(numDiagnosticSessions, 1);
	endDrive = nan(numDiagnosticSessions, 1);
	endNoInhDrive = nan(numDiagnosticSessions, 1);
	startDrive = nan(numDiagnosticSessions, 1);
	startNoInhDrive = nan(numDiagnosticSessions, 1);
	randomCueHit = nan(numDiagnosticSessions, 1);
	zeroCueHit = nan(numDiagnosticSessions, 1);
	first100 = NaN;
	for iSession = 1:numDiagnosticSessions
		startDrive(iSession) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, false);
		startNoInhDrive(iSession) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, false);
		randomProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "randomCue", Params.NumTrials, true);
		zeroProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "zeroCue", Params.NumTrials, true);
		randomCueHit(iSession) = mean(randomProbe.Hit, 'omitnan');
		zeroCueHit(iSession) = mean(zeroProbe.Hit, 'omitnan');
		if isfinite(first100)
			formalHit(iSession) = Params.Ceiling;
			endDrive(iSession) = startDrive(iSession);
			endNoInhDrive(iSession) = startNoInhDrive(iSession);
		else
			[formalHit(iSession), ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, formalCond, false);
			endDrive(iSession) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, false);
			endNoInhDrive(iSession) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, false);
			if formalHit(iSession) >= Params.Ceiling
				first100 = iSession;
			end
		end

		rowIndex = rowIndex + 1;
		sessionRows(rowIndex).Mouse = iMouse;
		sessionRows(rowIndex).Session = iSession;
		sessionRows(rowIndex).HitRate = formalHit(iSession);
		sessionRows(rowIndex).StartDrive = startDrive(iSession);
		sessionRows(rowIndex).EndDrive = endDrive(iSession);
		sessionRows(rowIndex).StartNoInhDrive = startNoInhDrive(iSession);
		sessionRows(rowIndex).EndNoInhDrive = endNoInhDrive(iSession);
		sessionRows(rowIndex).EndInhibitionGap = endNoInhDrive(iSession) - endDrive(iSession);
		sessionRows(rowIndex).RandomCueHitRate = randomCueHit(iSession);
		sessionRows(rowIndex).ZeroCueHitRate = zeroCueHit(iSession);

		if iSession < numDiagnosticSessions && ~isfinite(first100)
			Mouse = TransferLearning.THModel.OvernightConsolidate(Mouse, Params);
		end
	end

	lateStart = max(1, numDiagnosticSessions - 3);
	lateX = (lateStart:numDiagnosticSessions)';
	lateY = formalHit(lateStart:numDiagnosticSessions);
	lateSlope = NaN;
	if sum(isfinite(lateY)) >= 2
		p = polyfit(lateX(isfinite(lateY)), lateY(isfinite(lateY)), 1);
		lateSlope = p(1);
	end
	mouseRows(iMouse).Mouse = iMouse;
	mouseRows(iMouse).PretrainReached = pretrainReached;
	mouseRows(iMouse).PretrainSessions = iPretrainSession;
	mouseRows(iMouse).PretrainFinalHit = pretrainFinalHit;
	mouseRows(iMouse).FirstFormalHit = formalHit(1);
	mouseRows(iMouse).FormalHitAtNominalLast = formalHit(min(Params.NumSessions, numDiagnosticSessions));
	mouseRows(iMouse).FinalDiagnosticHit = formalHit(end);
	mouseRows(iMouse).FirstPerfectSession = first100;
	mouseRows(iMouse).LateSlope = lateSlope;
	mouseRows(iMouse).FinalDrive = endDrive(end);
	mouseRows(iMouse).FinalNoInhDrive = endNoInhDrive(end);
	mouseRows(iMouse).FinalInhibitionGap = endNoInhDrive(end) - endDrive(end);
end

SessionTable = struct2table(sessionRows);
MouseTable = struct2table(mouseRows);
Report.SessionTable = SessionTable;
Report.MouseTable = MouseTable;
Report.Summary = table( ...
	mean(MouseTable.PretrainReached), ...
	mean(MouseTable.FirstFormalHit, 'omitnan'), ...
	mean(MouseTable.FormalHitAtNominalLast, 'omitnan'), ...
	mean(MouseTable.FinalDiagnosticHit, 'omitnan'), ...
	mean(MouseTable.FirstPerfectSession <= Params.NumSessions, 'omitnan'), ...
	mean(isfinite(MouseTable.FirstPerfectSession), 'omitnan'), ...
	median(MouseTable.FirstPerfectSession, 'omitnan'), ...
	mean(MouseTable.LateSlope, 'omitnan'), ...
	mean(MouseTable.FinalDrive, 'omitnan'), ...
	mean(MouseTable.FinalNoInhDrive, 'omitnan'), ...
	mean(MouseTable.FinalInhibitionGap, 'omitnan'), ...
	'VariableNames', {'PretrainReachRate','MeanFirstFormalHit','MeanHitAtNominalLast','MeanFinalDiagnosticHit','ReachPerfectByNominalRate','ReachPerfectByDiagnosticRate','MedianFirstPerfectSession','MeanLateSlope','MeanFinalDrive','MeanFinalNoInhDrive','MeanFinalInhibitionGap'});
end
