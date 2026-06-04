% 中文图42F：Naive 🔊 的 inter-trial divergence PCA（模仿42E）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DSList = {
	TransferLearning.AudioLightBaseline()
	TransferLearning.ALInterspersed()
	TransferLearning.Vacation7()
	TransferLearning.LightAudioBaseline()
	TransferLearning.LAInterspersed()
	TransferLearning.THInhibit()
};

G = iNtsSuperMouse(DSList, "Naive", "AudioOnly", 10);
PlotData = iComputePcaPlotData(G);
nCellsUsed = height(G);
nMiceUsed = numel(unique(string(G.Mouse)));
trialColor = TransferLearning.NaiveColor;
driftColor = TransferLearning.ColorA;

f = figure('Color', 'w', 'Name', '中文图42F Naive AudioOnly PCA No Align');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

ax = axes(f);
hold(ax, 'on');
hTrial = iPlotTrialsAttachedOnAxes(ax, PlotData, trialColor, driftColor);
title(ax, "Naive 🔊 response in variable directions", 'FontSize', 12);

iApplySingleLimit(ax, PlotData);
xlabel(ax, sprintf('PC1 (%.1f%%)', PlotData.PcaTable.Explained(1)), 'FontSize', 12);
ylabel(ax, sprintf('PC2 (%.1f%%)', PlotData.PcaTable.Explained(2)), 'FontSize', 12);

ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 1;
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

hBeforeCueLegend = plot(ax, nan, nan, '-', 'LineWidth', 1, 'Color', TransferLearning.ColorB);
hAfterCueLegend = plot(ax, nan, nan, '-', 'LineWidth', 2, 'Color', trialColor);
hDriftLegend = plot(ax, nan, nan, '--', 'LineWidth', 2, 'Color', driftColor);

lgd = legend(ax, [hBeforeCueLegend, hAfterCueLegend, hDriftLegend], ...
	["3s before 🔊", "1s after 🔊", "Inter-trial drift"], ...
	'Location', 'eastoutside');
lgd.Box = 'off';
lgd.FontSize = 12;
lgd.FontName = 'Segoe UI Emoji';

svgPath = TransferLearning.StandardFigureSvgPath('中文图Fig42F_NaiveAudioOnly_PCA_NoAlign.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Fig42F cells used: %d\n', nCellsUsed);
fprintf('Fig42F mice used: %d\n', nMiceUsed);

assignin('base', 'Fig42F_GroupNtats', G);

function GroupNtats = iNtsSuperMouse(DSList, phaseName, stimulusName, minTrials)
cellTraces = {};
cellUIDList = zeros(0, 1, 'uint64');
mouseList = strings(0, 1);
nTime = [];

for iDS = 1:numel(DSList)
	DS = DSList{iDS};
	cellMeta = DS.Cells(:, ["CellUID", "Mouse"]);
	cellMeta.CellUID = uint64(cellMeta.CellUID);
	cellMeta.Mouse = string(cellMeta.Mouse);
	ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Phase', string(phaseName)), UniExp.Flags.No_special_operation, 1:24);
	nts = ntsCell{1};
	cellUIDs = unique(uint64(nts.CellUID));
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		rowsC = (uint64(nts.CellUID) == cid);
		if sum(rowsC) < minTrials
			continue;
		end
		uid = uint64(nts.TrialUID(rowsC));
		sig = double(nts.TrialSignal(rowsC, :));
		[~, order] = sort(uid);
		sig = sig(order, :);
		sig = sig(1:minTrials, :);
		if any(~isfinite(sig), 'all')
			continue;
		end
		% Per-cell z-score to eliminate inter-dataset scale differences
		mu = mean(sig, 'all', 'omitnan');
		sd = std(sig, 0, 'all', 'omitnan');
		if sd == 0 || ~isfinite(sd)
			continue;
		end
		sig = (sig - mu) / sd;
		cellTraces{end+1, 1} = sig; %#ok<AGROW>
		cellUIDList(end+1, 1) = cid; %#ok<AGROW>
		cellMetaIndex = find(cellMeta.CellUID == cid, 1, 'first');
		mouseList(end+1, 1) = cellMeta.Mouse(cellMetaIndex); %#ok<AGROW>
		if isempty(nTime)
			nTime = size(sig, 2);
		end
	end
end

if isempty(cellTraces)
	error('Fig42F:EmptySuperMouse', 'No cells found after pooling for requested trials.');
end

nCells = numel(cellTraces);
CellTrialTimes = nan(nCells, minTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellTraces{iC};
end

ntatsData = permute(CellTrialTimes, [1, 3, 2]);
ntats = MATLAB.DataTypes.NDTable(ntatsData);
GroupNtats = table(ntats, cellUIDList, mouseList, 'VariableNames', ["NTATS", "CellUID", "Mouse"]);
end

function GroupNtatsOut = iAverageAdjacentTrials(GroupNtatsIn, groupSize)
X = GroupNtatsIn.NTATS{:,:,:};
nTrial = size(X, 3);
nKeep = floor(nTrial / groupSize) * groupSize;
X = X(:, :, 1:nKeep);
nGroup = nKeep / groupSize;
Xr = reshape(X, size(X, 1), size(X, 2), groupSize, nGroup);
Xg = mean(Xr, 3, 'omitnan');
Xg = reshape(Xg, size(X, 1), size(X, 2), nGroup);
ntats = MATLAB.DataTypes.NDTable(Xg);
GroupNtatsOut = table(ntats, GroupNtatsIn.CellUID, GroupNtatsIn.Mouse, 'VariableNames', ["NTATS", "CellUID", "Mouse"]);
end

function PlotData = iComputePcaPlotData(GroupNtats)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2, true);
PcaLines = PcaTable.Score;

PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
idxPreCue = iFindPlotTimeIndex(nTime, -3);
idxCue = iFindPlotTimeIndex(nTime, 0);
idxWater = iFindPlotTimeIndex(nTime, 1);
idxPlotTime = idxPreCue:idxWater;
PcaData = PcaDataAll(:, idxPlotTime, :);
idxCueInPlot = idxCue - idxPreCue + 1;
idxWaterInPlot = idxWater - idxPreCue + 1;

PlotData = struct();
PlotData.PcaTable = PcaTable;
PlotData.PcaData = PcaData;
PlotData.preCueSegment = 1:idxCueInPlot;
PlotData.postCueSegment = idxCueInPlot:idxWaterInPlot;
PlotData.cuePts = squeeze(PcaData(:, idxCueInPlot, :)).';
PlotData.waterPts = squeeze(PcaData(:, idxWaterInPlot, :)).';
PlotData.nLines = size(PcaData, 3);
PlotData.lineColors = iAlphaRamp(TransferLearning.NaiveColor, PlotData.nLines);

xAll = reshape(PcaData(1, :, :), [], 1);
yAll = reshape(PcaData(2, :, :), [], 1);
PlotData.xSpan = max(xAll) - min(xAll);
PlotData.ySpan = max(yAll) - min(yAll);
if ~(isfinite(PlotData.xSpan) && PlotData.xSpan > 0)
	PlotData.xSpan = 1;
end
if ~(isfinite(PlotData.ySpan) && PlotData.ySpan > 0)
	PlotData.ySpan = 1;
end
end

function hTrial = iPlotTrialsAttachedOnAxes(ax, PlotData, trialColor, driftColor)
iFormatAxes(ax);

PcaData = PlotData.PcaData;
cuePts = PlotData.cuePts;
waterPts = PlotData.waterPts;

for iLine = 1:PlotData.nLines
	xy = squeeze(PcaData(:, :, iLine));
	plot(ax, xy(1, PlotData.preCueSegment), xy(2, PlotData.preCueSegment), '-', 'LineWidth', 1, 'Color', TransferLearning.ColorB, 'HandleVisibility', 'off');
	plot(ax, xy(1, PlotData.postCueSegment), xy(2, PlotData.postCueSegment), '-', 'LineWidth', 2, 'Color', PlotData.lineColors(iLine, :), 'HandleVisibility', 'off');
end

plot(ax, cuePts(:, 1), cuePts(:, 2), '--', 'LineWidth', 2, 'Color', driftColor, 'HandleVisibility', 'off');

hTrial = plot(ax, nan, nan, '-', 'LineWidth', 2, 'Color', trialColor);

for iLine = 1:PlotData.nLines
	text(ax, cuePts(iLine, 1), cuePts(iLine, 2), '🔊', ...
		'FontSize', 12, 'FontName', 'Segoe UI Emoji', 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle', 'Clipping', 'on', 'HandleVisibility', 'off');
end

view(ax, 2);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iFormatAxes(ax)
ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 1;
box(ax, 'off');
grid(ax, 'off');
hold(ax, 'on');
end

function iApplySingleLimit(ax, PlotData)
xAll = reshape(PlotData.PcaData(1, :, :), [], 1);
yAll = reshape(PlotData.PcaData(2, :, :), [], 1);
xMargin = 0.06 * PlotData.xSpan;
yMargin = 0.08 * PlotData.ySpan;

if ~(isfinite(xMargin) && xMargin > 0)
	xMargin = 1;
end
if ~(isfinite(yMargin) && yMargin > 0)
	yMargin = 1;
end

xlim(ax, [min(xAll) - xMargin, max(xAll) + xMargin]);
ylim(ax, [min(yAll) - yMargin, max(yAll) + yMargin]);
end

function colors = iAlphaRamp(baseColor, nLines)
if nLines <= 1
	colors = [baseColor, 1];
	return;
end
alphaVals = linspace(0.45, 1.0, nLines)';
colors = 1 - alphaVals .* (1 - repmat(baseColor, nLines, 1));
end

function idx = iFindPlotTimeIndex(nTime, targetSec)
xsSec = seconds(TransferLearning.Xs);
if numel(xsSec) == nTime
	[~, idx] = min(abs(xsSec(:) - targetSec));
	return;
end
sampleRate = 8;
idx = round((targetSec + 3) * sampleRate) + 1;
idx = max(1, min(nTime, idx));
end
