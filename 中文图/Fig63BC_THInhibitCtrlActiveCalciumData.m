function Data = Fig63BC_THInhibitCtrlActiveCalciumData()
% Shared data for Fig63B/C: learned AudioWater active cells (MOp5 only) in first Transfer LightWater session.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = xsSec >= -3 & xsSec < 0;
plotMask = xsSec >= -1 & xsSec <= 3;
earlyMask = xsSec >= 0 & xsSec < 1;
lateMask = xsSec >= 1 & xsSec <= 3;
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig63BC:No1s', 'Cannot find sample close to 1 s.');
end

ctrlDS = TransferLearning.AudioLightBaseline();
thDS = TransferLearning.THInhibit();
ctrl = iBuildGroupData(ctrlDS, "Ctrl", baseMask, idx1s, plotMask, earlyMask, lateMask);
th = iBuildGroupData(thDS, "TH", baseMask, idx1s, plotMask, earlyMask, lateMask);
ctrl = iFilterL5(ctrl, ctrlDS);
th = iFilterL5(th, thDS);

if isempty(ctrl.Trace) || isempty(th.Trace)
	error('Fig63BC:EmptyData', 'No learned-active cells found in Ctrl or TH group.');
end

lineMean = [mean(ctrl.Trace, 1, 'omitnan').', mean(th.Trace, 1, 'omitnan').'];
lineSem = [iSem(ctrl.Trace, 1).', iSem(th.Trace, 1).'];
[pLate, ~] = ranksum(ctrl.LateMean, th.LateMean);
[pInteraction, ~] = ranksum(ctrl.LateMinusEarly, th.LateMinusEarly);

rng(38305, 'twister');
[decreaseEarlyBoot, decreaseLateBoot] = iBootstrapDecrease(ctrl.EarlyMean, ctrl.LateMean, th.EarlyMean, th.LateMean, 2000);

Data = struct();
Data.XSec = xsSec(:);
Data.XPlot = xsSec(plotMask(:));
Data.Ctrl = ctrl;
Data.TH = th;
Data.LineMean = lineMean;
Data.LineSem = lineSem;
Data.LatePValue = pLate;
Data.InteractionPValue = pInteraction;
Data.DecreaseEarlyBootstrap = decreaseEarlyBoot;
Data.DecreaseLateBootstrap = decreaseLateBoot;
Data.DecreaseEarlyMean = mean(ctrl.EarlyMean, 'omitnan') - mean(th.EarlyMean, 'omitnan');
Data.DecreaseLateMean = mean(ctrl.LateMean, 'omitnan') - mean(th.LateMean, 'omitnan');
Data.NCtrlCell = numel(ctrl.LateMean);
Data.NTHCell = numel(th.LateMean);
Data.NCtrlMouse = numel(unique(ctrl.CellRows.Mouse));
Data.NTHMouse = numel(unique(th.CellRows.Mouse));
end

function groupData = iBuildGroupData(DS, groupName, baseMask, idx1s, plotMask, earlyMask, lateMask)
learnedSessions = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
transferSessions = DS.TableQuery(["Mouse","DateTime"], Phase="Transfer", Stimulus="LightWater", Design="LightWater");
if isempty(learnedSessions) || isempty(transferSessions)
	groupData = iEmptyGroupData(groupName, nnz(plotMask));
	return;
end

learnedSessions.Mouse = string(learnedSessions.Mouse);
learnedSessions.DateTime = iNormalizeDateTime(learnedSessions.DateTime);
transferSessions.Mouse = string(transferSessions.Mouse);
transferSessions.DateTime = iNormalizeDateTime(transferSessions.DateTime);

learnedByMouse = groupsummary(learnedSessions, "Mouse", "max", "DateTime");
learnedByMouse.Properties.VariableNames{end} = 'DateTimeLearned';
transferByMouse = groupsummary(transferSessions(:, ["Mouse","DateTime"]), "Mouse", "min", "DateTime");
transferByMouse.Properties.VariableNames{end} = 'DateTimeTransfer';
sessions = innerjoin(learnedByMouse(:, ["Mouse","DateTimeLearned"]), transferByMouse(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');

traceCells = cell(height(sessions), 1);
earlyCells = cell(height(sessions), 1);
lateCells = cell(height(sessions), 1);
rowCells = cell(height(sessions), 1);
for iSession = 1:height(sessions)
	mouseName = string(sessions.Mouse(iSession));
	dateTimeLearned = sessions.DateTimeLearned(iSession);
	dateTimeTransfer = sessions.DateTimeTransfer(iSession);

	learnedNtats = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dateTimeLearned, ...
		'Phase', 'Learned', 'Stimulus', 'AudioWater', 'Design', 'AudioWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	transferNtats = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dateTimeTransfer, ...
		'Phase', 'Transfer', 'Stimulus', 'LightWater', 'Design', 'LightWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

	[learnedX, learnedCellUID] = iExtractNtats2D(learnedNtats);
	[transferX, transferCellUID] = iExtractNtats2D(transferNtats);
	if isempty(learnedX) || isempty(transferX)
		traceCells{iSession} = nan(0, nnz(plotMask));
		earlyCells{iSession} = nan(0, 1);
		lateCells{iSession} = nan(0, 1);
		rowCells{iSession} = iEmptyCellRows();
		continue;
	end

	[commonCellUID, learnedIdx, transferIdx] = intersect(learnedCellUID, transferCellUID, 'stable');
	learnedX = learnedX(learnedIdx, :);
	transferX = transferX(transferIdx, :);
	learnedActive = iIsActiveAt1s(learnedX, baseMask, idx1s, 3);

	selectedCellUID = commonCellUID(learnedActive);
	selectedTrace = transferX(learnedActive, plotMask);
	selectedEarly = mean(transferX(learnedActive, earlyMask), 2, 'omitnan');
	selectedLate = mean(transferX(learnedActive, lateMask), 2, 'omitnan');
	validRows = all(isfinite([selectedEarly, selectedLate]), 2);

	selectedCellUID = selectedCellUID(validRows);
	selectedTrace = selectedTrace(validRows, :);
	selectedEarly = selectedEarly(validRows);
	selectedLate = selectedLate(validRows);
	traceCells{iSession} = selectedTrace;
	earlyCells{iSession} = selectedEarly;
	lateCells{iSession} = selectedLate;
	rowCells{iSession} = table( ...
		repmat(string(groupName), numel(selectedCellUID), 1), ...
		repmat(mouseName, numel(selectedCellUID), 1), ...
		repmat(dateTimeLearned, numel(selectedCellUID), 1), ...
		repmat(dateTimeTransfer, numel(selectedCellUID), 1), ...
		selectedCellUID(:), selectedEarly(:), selectedLate(:), selectedLate(:) - selectedEarly(:), ...
		'VariableNames', {'Group','Mouse','DateTimeLearned','DateTimeTransfer','CellUID','EarlyMean','LateMean','LateMinusEarly'});
end

trace = vertcat(traceCells{:});
earlyMean = vertcat(earlyCells{:});
lateMean = vertcat(lateCells{:});
cellRows = vertcat(rowCells{:});
groupData = struct();
groupData.Group = groupName;
groupData.Trace = trace;
groupData.EarlyMean = earlyMean;
groupData.LateMean = lateMean;
groupData.LateMinusEarly = lateMean - earlyMean;
groupData.CellRows = cellRows;
end

function groupData = iEmptyGroupData(groupName, nPlotPoint)
groupData = struct();
groupData.Group = groupName;
groupData.Trace = nan(0, nPlotPoint);
groupData.EarlyMean = nan(0, 1);
groupData.LateMean = nan(0, 1);
groupData.LateMinusEarly = nan(0, 1);
groupData.CellRows = iEmptyCellRows();
end

function T = iEmptyCellRows()
T = table(strings(0, 1), strings(0, 1), NaT(0, 1), NaT(0, 1), uint64.empty(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Group','Mouse','DateTimeLearned','DateTimeTransfer','CellUID','EarlyMean','LateMean','LateMinusEarly'});
end

function [earlyBoot, lateBoot] = iBootstrapDecrease(ctrlEarly, ctrlLate, thEarly, thLate, nBoot)
ctrlEarly = ctrlEarly(:);
ctrlLate = ctrlLate(:);
thEarly = thEarly(:);
thLate = thLate(:);
nCtrl = numel(ctrlEarly);
nTH = numel(thEarly);
ctrlIdx = randi(nCtrl, nCtrl, nBoot);
thIdx = randi(nTH, nTH, nBoot);
earlyBoot = mean(ctrlEarly(ctrlIdx), 1, 'omitnan').' - mean(thEarly(thIdx), 1, 'omitnan').';
lateBoot = mean(ctrlLate(ctrlIdx), 1, 'omitnan').' - mean(thLate(thIdx), 1, 'omitnan').';
end

function semValue = iSem(x, dim)
semValue = std(x, 0, dim, 'omitnan') ./ sqrt(sum(isfinite(x), dim));
end

function [X, cellUID] = iExtractNtats2D(G)
cellUID = uint64([]);
X = [];
if isempty(G)
	return;
end
ntats = G.NTATS;
cellUID = uint64(G.CellUID);
if isa(ntats, 'MATLAB.DataTypes.NDTable')
	X = double(ntats.Data);
else
	X = double(ntats);
end
if ndims(X) == 3
	X = squeeze(X(:, :, 1));
end
end

function active = iIsActiveAt1s(X, baseMask, idx1s, kSigma)
baseMean = mean(X(:, baseMask), 2, 'omitnan');
baseStd = std(X(:, baseMask), 0, 2, 'omitnan');
value1s = X(:, idx1s);
active = isfinite(value1s) & isfinite(baseMean) & isfinite(baseStd) & value1s > baseMean + kSigma .* baseStd;
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && d <= tolSec;
end

function groupData = iFilterL5(groupData, DS)
if isempty(groupData.CellRows)
	return;
end
Cells = DS.Cells(:, {'CellUID','ZLayer'});
Cells.CellUID = uint64(Cells.CellUID);
[~, loc] = ismember(groupData.CellRows.CellUID, Cells.CellUID);
isL5 = string(Cells.ZLayer(loc)) == "MOp5";
isL5(~isfinite(isL5)) = false;
if ~any(isL5)
	groupData = iEmptyGroupData(groupData.Group, size(groupData.Trace, 2));
	return;
end
groupData.Trace = groupData.Trace(isL5, :);
groupData.EarlyMean = groupData.EarlyMean(isL5);
groupData.LateMean = groupData.LateMean(isL5);
groupData.LateMinusEarly = groupData.LateMinusEarly(isL5);
groupData.CellRows = groupData.CellRows(isL5, :);
end
