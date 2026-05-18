function Report = DiagnoseTransferFirstHighMechanism(Params, numMice, seedBase, numRandomProbeCues)
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
if nargin < 4 || isempty(numRandomProbeCues)
	numRandomProbeCues = max(30, Params.NumTrials);
end

mouseReports = cell(numMice, 1);
useParallel = numMice > 1 && ~isempty(gcp('nocreate'));
if useParallel
	parfor iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnoseTransferFirstHighMechanismMouse(Params, iMouse, seedValues(iMouse), numRandomProbeCues);
	end
else
	for iMouse = 1:numMice
		mouseReports{iMouse} = TransferLearning.THModel.DiagnoseTransferFirstHighMechanismMouse(Params, iMouse, seedValues(iMouse), numRandomProbeCues);
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
Report.Params = Params;
Report.NumMice = numMice;
Report.SeedValues = seedValues;
Report.NumRandomProbeCues = numRandomProbeCues;
Report.MouseTable = MouseTable;
Report.SessionTable = SessionTable;
Report.SessionSummary = iSessionSummary(SessionTable);
Report.FinalSummary = iFinalSummary(MouseTable);
end

function Summary = iSessionSummary(SessionTable)
sessionValues = unique(SessionTable.PretrainSession);
summaryRows = repmat(iEmptySessionSummaryRow(), numel(sessionValues), 1);
for iSessionValue = 1:numel(sessionValues)
	sessionValue = sessionValues(iSessionValue);
	sessionMask = SessionTable.PretrainSession == sessionValue;
	subTable = SessionTable(sessionMask, :);
	summaryRows(iSessionValue).PretrainSession = sessionValue;
	summaryRows(iSessionValue).NumRows = height(subTable);
	summaryRows(iSessionValue).MeanPretrainHit = mean(subTable.PretrainHitObserved, 'omitnan');
	summaryRows(iSessionValue).MeanPreCueDrive = mean(subTable.PreCueDrive, 'omitnan');
	summaryRows(iSessionValue).MeanFormalDrive = mean(subTable.FormalDrive, 'omitnan');
	summaryRows(iSessionValue).MeanFormalNoLearningHit = mean(subTable.FormalNoLearningHitRate, 'omitnan');
	summaryRows(iSessionValue).MeanFormalFirstSessionHit = mean(subTable.FormalFirstSessionHitRate, 'omitnan');
	summaryRows(iSessionValue).MeanRandomNoisyHit = mean(subTable.RandomNoisyHitRate, 'omitnan');
	summaryRows(iSessionValue).MeanZeroNoisyHit = mean(subTable.ZeroNoisyHitRate, 'omitnan');
	summaryRows(iSessionValue).MeanFormalNoRecurrentDrive = mean(subTable.FormalNoRecurrentDrive, 'omitnan');
	summaryRows(iSessionValue).MeanFormalPreCueSourceOnlyDrive = mean(subTable.FormalPreCueSourceOnlyDrive, 'omitnan');
	summaryRows(iSessionValue).MeanFormalNonPreCueSourceOnlyDrive = mean(subTable.FormalNonPreCueSourceOnlyDrive, 'omitnan');
	summaryRows(iSessionValue).MeanFormalL23SourceOnlyDrive = mean(subTable.FormalL23SourceOnlyDrive, 'omitnan');
	summaryRows(iSessionValue).MeanFormalL5SourceOnlyDrive = mean(subTable.FormalL5SourceOnlyDrive, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromPreCueL23 = mean(subTable.TargetFromPreCueL23Mean, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromFormalL23 = mean(subTable.TargetFromFormalL23Mean, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromNonPreCueSource = mean(subTable.TargetFromNonPreCueSourceMean, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromL5Source = mean(subTable.TargetFromL5SourceMean, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromPreCueL23Cap = mean(subTable.TargetFromPreCueL23CapFraction, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromFormalL23Cap = mean(subTable.TargetFromFormalL23CapFraction, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromNonPreCueSourceCap = mean(subTable.TargetFromNonPreCueSourceCapFraction, 'omitnan');
	summaryRows(iSessionValue).MeanTargetFromL5SourceCap = mean(subTable.TargetFromL5SourceCapFraction, 'omitnan');
end
Summary = struct2table(summaryRows);
end

function Summary = iFinalSummary(MouseTable)
Summary = table( ...
	mean(MouseTable.Reached), ...
	mean(MouseTable.FinalFormalNoLearningHitRate, 'omitnan'), ...
	mean(MouseTable.FinalFormalFirstSessionHitRate, 'omitnan'), ...
	mean(MouseTable.FinalRandomNoisyHitRate, 'omitnan'), ...
	mean(MouseTable.FinalZeroNoisyHitRate, 'omitnan'), ...
	mean(MouseTable.FinalFormalNoRecurrentDrive, 'omitnan'), ...
	mean(MouseTable.FinalFormalPreCueSourceOnlyDrive, 'omitnan'), ...
	mean(MouseTable.FinalFormalNonPreCueSourceOnlyDrive, 'omitnan'), ...
	mean(MouseTable.FinalFormalL23SourceOnlyDrive, 'omitnan'), ...
	mean(MouseTable.FinalFormalL5SourceOnlyDrive, 'omitnan'), ...
	mean(MouseTable.FinalTargetFromPreCueL23CapFraction, 'omitnan'), ...
	mean(MouseTable.FinalTargetFromNonPreCueSourceCapFraction, 'omitnan'), ...
	'VariableNames', {'ReachRate','MeanFinalFormalNoLearningHit','MeanFinalFormalFirstSessionHit','MeanFinalRandomNoisyHit','MeanFinalZeroNoisyHit','MeanFinalFormalNoRecurrentDrive','MeanFinalFormalPreCueSourceOnlyDrive','MeanFinalFormalNonPreCueSourceOnlyDrive','MeanFinalFormalL23SourceOnlyDrive','MeanFinalFormalL5SourceOnlyDrive','MeanFinalTargetFromPreCueL23CapFraction','MeanFinalTargetFromNonPreCueSourceCapFraction'});
end

function row = iEmptySessionSummaryRow()
row.PretrainSession = NaN;
row.NumRows = NaN;
row.MeanPretrainHit = NaN;
row.MeanPreCueDrive = NaN;
row.MeanFormalDrive = NaN;
row.MeanFormalNoLearningHit = NaN;
row.MeanFormalFirstSessionHit = NaN;
row.MeanRandomNoisyHit = NaN;
row.MeanZeroNoisyHit = NaN;
row.MeanFormalNoRecurrentDrive = NaN;
row.MeanFormalPreCueSourceOnlyDrive = NaN;
row.MeanFormalNonPreCueSourceOnlyDrive = NaN;
row.MeanFormalL23SourceOnlyDrive = NaN;
row.MeanFormalL5SourceOnlyDrive = NaN;
row.MeanTargetFromPreCueL23 = NaN;
row.MeanTargetFromFormalL23 = NaN;
row.MeanTargetFromNonPreCueSource = NaN;
row.MeanTargetFromL5Source = NaN;
row.MeanTargetFromPreCueL23Cap = NaN;
row.MeanTargetFromFormalL23Cap = NaN;
row.MeanTargetFromNonPreCueSourceCap = NaN;
row.MeanTargetFromL5SourceCap = NaN;
end
