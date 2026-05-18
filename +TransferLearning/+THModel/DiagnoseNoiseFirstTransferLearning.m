function Report = DiagnoseNoiseFirstTransferLearning(Params, numMice, seedBase, numSessions, nominalSessions)
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
if nargin < 5 || isempty(nominalSessions)
	nominalSessions = Params.NumSessions;
end

Cond = TransferLearning.THModel.ConditionTable();
transferCond = Cond(Cond.Name == "Transfer", :);
mouseReports = cell(numMice, 1);
pool = gcp('nocreate');
if isempty(pool) && numMice > 1
	parpool('local', min(20, numMice));
	pool = gcp('nocreate');
end
if numMice > 1 && ~isempty(pool)
	parfor iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnoseNoiseFirstTransferMouse(Params, transferCond, iMouse, seedValues(iMouse), numSessions, nominalSessions);
	end
else
	for iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnoseNoiseFirstTransferMouse(Params, transferCond, iMouse, seedValues(iMouse), numSessions, nominalSessions);
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

Report.Params = Params;
Report.NumMice = numMice;
Report.SeedValues = seedValues;
Report.NumSessions = numSessions;
Report.NominalSessions = nominalSessions;
Report.MouseTable = MouseTable;
Report.SessionTable = SessionTable;
Report.SessionSummary = groupsummary(SessionTable, 'Session', 'mean', { ...
	'HitRate', 'MeanDecisionDrive', 'MaxDecisionDrive', 'MeanCombinedTarget', 'MeanCombinedOffTarget', ...
	'MeanL5ReadTarget', 'MeanL5ReadOffTarget', 'MeanIL5ReadTarget', 'MeanIL5ReadOffTarget', ...
	'MeanNoisePassAttempt', 'MaxNoisePassAttempt', 'MeanNoisePassDecisionDrive', ...
	'InternalCapFraction', 'InternalZeroFraction', 'L5ReadWIECapFraction', 'L5ReadWEICapFraction'});
Report.NominalFailureSessionTable = SessionTable(ismember(SessionTable.Mouse, MouseTable.Mouse(MouseTable.FailedAtNominal)), :);
Report.NominalSuccessSessionTable = SessionTable(ismember(SessionTable.Mouse, MouseTable.Mouse(~MouseTable.FailedAtNominal)), :);
end