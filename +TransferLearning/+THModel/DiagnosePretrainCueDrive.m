function DebugReport = DiagnosePretrainCueDrive(Params, numMice)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(numMice)
	numMice = 3;
end
sessionRows = struct([]);
trialTables = cell(numMice * Params.MaxPretrainSessions, 1);
rowIndex = 0;
for iMouse = 1:numMice
	Mouse = TransferLearning.THModel.DrawMouse(Params);
	for iSession = 1:Params.MaxPretrainSessions
		[Mouse, sessionSummary, trialTable] = TransferLearning.THModel.DiagnosePretrainSession(Mouse, Params, true);
		rowIndex = rowIndex + 1;
		sessionRows(rowIndex).Mouse = iMouse;
		sessionRows(rowIndex).Session = iSession;
		sessionRows(rowIndex).HitRate = sessionSummary.HitRate;
		sessionRows(rowIndex).StartDrive = sessionSummary.StartDrive;
		sessionRows(rowIndex).EndDrive = sessionSummary.EndDrive;
		sessionRows(rowIndex).StartNoInhDrive = sessionSummary.StartNoInhDrive;
		sessionRows(rowIndex).EndNoInhDrive = sessionSummary.EndNoInhDrive;
		sessionRows(rowIndex).MissTrials = sessionSummary.MissTrials;
		sessionRows(rowIndex).MeanRewardHebbDelta = sessionSummary.MeanRewardHebbDelta;
		sessionRows(rowIndex).MeanRewardInhDelta = sessionSummary.MeanRewardInhDelta;
		sessionRows(rowIndex).MeanRewardNoInhDelta = sessionSummary.MeanRewardNoInhDelta;
		sessionRows(rowIndex).MeanHitPatternDelta = sessionSummary.MeanHitPatternDelta;
		sessionRows(rowIndex).MeanHitPatternNoInhDelta = sessionSummary.MeanHitPatternNoInhDelta;
		sessionRows(rowIndex).MeanNoiseHebbDeltaSum = sessionSummary.MeanNoiseHebbDeltaSum;
		sessionRows(rowIndex).MeanNoiseInhDeltaSum = sessionSummary.MeanNoiseInhDeltaSum;
		sessionRows(rowIndex).MeanNoiseNoInhDeltaSum = sessionSummary.MeanNoiseNoInhDeltaSum;
		sessionRows(rowIndex).MeanNoiseUpdateCount = sessionSummary.MeanNoiseUpdateCount;
		sessionRows(rowIndex).TotalNoiseUpdateCount = sessionSummary.TotalNoiseUpdateCount;
		sessionRows(rowIndex).MeanNetDelta = sessionSummary.MeanNetDelta;
		sessionRows(rowIndex).MeanNetNoInhDelta = sessionSummary.MeanNetNoInhDelta;
		sessionRows(rowIndex).EndInhibitionGap = sessionSummary.EndInhibitionGap;
		trialTables{rowIndex} = trialTable;
		if sessionSummary.HitRate >= Params.Ceiling
			break;
		end
	end
end
SessionTable = struct2table(sessionRows);
DebugReport.SessionTable = SessionTable;
DebugReport.TrialTables = trialTables(1:rowIndex);
DebugReport.Overall = table( ...
	mean(SessionTable.HitRate, 'omitnan'), ...
	mean(SessionTable.EndDrive, 'omitnan'), ...
	mean(SessionTable.EndNoInhDrive, 'omitnan'), ...
	mean(SessionTable.EndInhibitionGap, 'omitnan'), ...
	mean(SessionTable.MeanRewardHebbDelta, 'omitnan'), ...
	mean(SessionTable.MeanRewardInhDelta, 'omitnan'), ...
	mean(SessionTable.MeanRewardNoInhDelta, 'omitnan'), ...
	mean(SessionTable.MeanHitPatternDelta, 'omitnan'), ...
	mean(SessionTable.MeanHitPatternNoInhDelta, 'omitnan'), ...
	mean(SessionTable.MeanNoiseHebbDeltaSum, 'omitnan'), ...
	mean(SessionTable.MeanNoiseInhDeltaSum, 'omitnan'), ...
	mean(SessionTable.MeanNoiseNoInhDeltaSum, 'omitnan'), ...
	mean(SessionTable.MeanNetDelta, 'omitnan'), ...
	mean(SessionTable.MeanNetNoInhDelta, 'omitnan'), ...
	mean(SessionTable.MeanNoiseUpdateCount, 'omitnan'), ...
	mean(SessionTable.TotalNoiseUpdateCount, 'omitnan'), ...
	'VariableNames', {'MeanHitRate','MeanEndDrive','MeanEndNoInhDrive','MeanEndInhibitionGap','MeanRewardHebbDelta','MeanRewardInhDelta','MeanRewardNoInhDelta','MeanHitPatternDelta','MeanHitPatternNoInhDelta','MeanNoiseHebbDeltaSum','MeanNoiseInhDeltaSum','MeanNoiseNoInhDeltaSum','MeanNetDelta','MeanNetNoInhDelta','MeanNoiseUpdateCount','MeanTotalNoiseUpdateCount'});
end
