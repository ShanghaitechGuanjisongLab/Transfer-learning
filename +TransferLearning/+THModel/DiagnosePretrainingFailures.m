function Report = DiagnosePretrainingFailures(Params, numMice, seedBase, numProbeTrials)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
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
if nargin < 4 || isempty(numProbeTrials)
	numProbeTrials = Params.NumTrials;
end

mouseReports = cell(numMice, 1);
useParallel = numMice > 1 && ~isempty(gcp('nocreate'));
if useParallel
	parfor iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnosePretrainingFailureMouse(Params, iMouse, seedValues(iMouse), numProbeTrials);
	end
else
	for iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnosePretrainingFailureMouse(Params, iMouse, seedValues(iMouse), numProbeTrials);
	end
end

mouseRows = cell(numMice, 1);
sessionTables = cell(numMice, 1);
for iMouse = 1:numMice
	mouseRows{iMouse} = mouseReports{iMouse}.MouseRow;
	sessionTables{iMouse} = mouseReports{iMouse}.SessionTable;
end
MouseTable = struct2table(vertcat(mouseRows{:}));
SessionTable = vertcat(sessionTables{:});
failedMask = ~MouseTable.Reached;

Report.Params = Params;
Report.NumMice = numMice;
Report.SeedValues = seedValues;
Report.NumProbeTrials = numProbeTrials;
Report.MouseTable = MouseTable;
Report.SessionTable = SessionTable;
Report.FailedMouseTable = MouseTable(failedMask, :);
Report.FailedSessionTable = SessionTable(ismember(SessionTable.Mouse, MouseTable.Mouse(failedMask)), :);
Report.Summary = iBuildSummary(MouseTable, SessionTable, Params);
end

function Summary = iBuildSummary(MouseTable, SessionTable, Params)
failedMask = ~MouseTable.Reached;
lastSessionMask = SessionTable.Session == Params.MaxPretrainSessions;
failedLast = SessionTable(lastSessionMask & ismember(SessionTable.Mouse, MouseTable.Mouse(failedMask)), :);
if isempty(failedLast)
	failedMeanLastHit = NaN;
	failedMeanLastDrive = NaN;
	failedMeanLastNoInhDrive = NaN;
	failedMeanLastInhibitionGap = NaN;
	failedMeanLastInternalCapFraction = NaN;
	failedMeanLastNoiseUpdateCount = NaN;
else
	failedMeanLastHit = mean(failedLast.HitRate, 'omitnan');
	failedMeanLastDrive = mean(failedLast.EndDrive, 'omitnan');
	failedMeanLastNoInhDrive = mean(failedLast.EndNoInhDrive, 'omitnan');
	failedMeanLastInhibitionGap = mean(failedLast.EndInhibitionGap, 'omitnan');
	failedMeanLastInternalCapFraction = mean(failedLast.InternalCapFraction, 'omitnan');
	failedMeanLastNoiseUpdateCount = mean(failedLast.MeanNoiseUpdateCount, 'omitnan');
end
Summary = table( ...
	mean(MouseTable.Reached), ...
	sum(MouseTable.Reached), ...
	height(MouseTable), ...
	median(MouseTable.FirstPerfectSession, 'omitnan'), ...
	max(MouseTable.FirstPerfectSession, [], 'omitnan'), ...
	sum(failedMask), ...
	mean(MouseTable.FinalHitRate, 'omitnan'), ...
	failedMeanLastHit, ...
	failedMeanLastDrive, ...
	failedMeanLastNoInhDrive, ...
	failedMeanLastInhibitionGap, ...
	failedMeanLastInternalCapFraction, ...
	failedMeanLastNoiseUpdateCount, ...
	'VariableNames', {'ReachRate','ReachedCount','NumMice','MedianFirstPerfectSession','MaxFirstPerfectSession','FailedCount','MeanFinalHit','FailedMeanLastHit','FailedMeanLastDrive','FailedMeanLastNoInhDrive','FailedMeanLastInhibitionGap','FailedMeanLastInternalCapFraction','FailedMeanLastNoiseUpdateCount'});
end
