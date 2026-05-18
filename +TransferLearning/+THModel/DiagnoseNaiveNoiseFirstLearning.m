function Report = DiagnoseNaiveNoiseFirstLearning(Params, numMice, seedBase, numSessions)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
Params.NoiseFirstStateCarryover = 1;
if nargin < 2 || isempty(numMice)
	numMice = Params.NumMice;
end
if nargin < 3 || isempty(seedBase)
	seedValues = nan(numMice, 1);
elseif isscalar(seedBase)
	seedValues = double(seedBase) + (0:numMice - 1)';
else
	seedValues = double(seedBase(:));
	if numel(seedValues) ~= numMice
		error('THModel:InvalidSeedBase', 'seedBase must be empty, scalar, or contain one seed per mouse.');
	end
end
if nargin < 4 || isempty(numSessions)
	numSessions = Params.NumSessions;
end

Cond = TransferLearning.THModel.ConditionTable();
naiveCond = Cond(Cond.Name == "Naive", :);
mouseReports = cell(numMice, 1);
pool = gcp('nocreate');
if isempty(pool) && numMice > 1
	parpool('local', min(20, numMice));
	pool = gcp('nocreate');
end
if numMice > 1 && ~isempty(pool)
	parfor iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnoseNaiveNoiseFirstLearningMouse(Params, naiveCond, iMouse, seedValues(iMouse), numSessions);
	end
else
	for iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnoseNaiveNoiseFirstLearningMouse(Params, naiveCond, iMouse, seedValues(iMouse), numSessions);
	end
end

mouseRows = cell(numMice, 1);
sessionTables = cell(numMice, 1);
for iMouse = 1:numMice
	mouseRows{iMouse} = mouseReports{iMouse}.MouseRow;
	sessionTables{iMouse} = mouseReports{iMouse}.SessionTable;
end
SessionTable = vertcat(sessionTables{:});
MouseTable = struct2table(vertcat(mouseRows{:}));
completedSessionTable = SessionTable(SessionTable.Completed, :);

Report.Params = Params;
Report.NumMice = numMice;
Report.SeedValues = seedValues;
Report.NumSessions = numSessions;
Report.SessionTable = SessionTable;
Report.MouseTable = MouseTable;
Report.CompletedSessionTable = completedSessionTable;
Report.SessionSummary = iSessionSummary(completedSessionTable);
Report.FailureSummary = iFailureSummary(MouseTable);
end

function Summary = iSessionSummary(completedSessionTable)
if isempty(completedSessionTable)
	Summary = table();
	return;
end
Summary = groupsummary(completedSessionTable, 'Session', 'mean', { ...
	'HitRate', 'MeanDecisionDrive', 'MaxDecisionDrive', ...
	'MeanNoisePassAttempt', 'MaxNoisePassAttempt', 'MeanNoisePassDecisionDrive', ...
	'ProcessTargetL5Read', 'ProcessOffTargetL5Read', 'ProcessTargetMinusOffTarget', ...
	'StartDirectDrive', 'EndDirectDrive', 'StartDirectNoInhDrive', 'EndDirectNoInhDrive', ...
	'EndDirectInhibitionGap', 'EndDirectL5ReadTarget', 'EndDirectL5ReadOffTarget', ...
	'EndDirectIL5ReadTarget', 'EndDirectIL5ReadOffTarget', ...
	'InternalCapFraction', 'InternalZeroFraction', 'L5ReadWIECapFraction', 'L5ReadWEICapFraction'});
end

function Summary = iFailureSummary(MouseTable)
failureMask = isfinite(MouseTable.FailureSession);
failureSessions = MouseTable.FailureSession(failureMask);
if isempty(failureSessions)
	medianFailureSession = NaN;
	minFailureSession = NaN;
	maxFailureSession = NaN;
else
	medianFailureSession = median(failureSessions, 'omitnan');
	minFailureSession = min(failureSessions, [], 'omitnan');
	maxFailureSession = max(failureSessions, [], 'omitnan');
end
Summary = table( ...
	sum(failureMask), height(MouseTable), medianFailureSession, minFailureSession, maxFailureSession, ...
	mean(MouseTable.CompletedSessions, 'omitnan'), ...
	mean(MouseTable.LastCompletedHit, 'omitnan'), ...
	mean(MouseTable.LastCompletedDirectDrive, 'omitnan'), ...
	mean(MouseTable.LastCompletedDirectNoInhDrive, 'omitnan'), ...
	mean(MouseTable.LastCompletedInternalCapFraction, 'omitnan'), ...
	'VariableNames', {'FailureCount','NumMice','MedianFailureSession','MinFailureSession','MaxFailureSession','MeanCompletedSessions','MeanLastCompletedHit','MeanLastCompletedDirectDrive','MeanLastCompletedDirectNoInhDrive','MeanLastCompletedInternalCapFraction'});
end