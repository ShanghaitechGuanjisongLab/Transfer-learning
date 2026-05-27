% 中文图325：Learned 🔊💧 的 inter-trial divergence PCA（双 tile，不对齐到 0 点）

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
};

G = iNtsSuperMouse(DSList, "Learned", "AudioWater", 30);
GPlot = iAverageAdjacentTrials(G, 3);
PlotData = iComputePcaPlotData(GPlot);
nCellsUsed = height(GPlot);
nMiceUsed = numel(unique(string(GPlot.Mouse)));

f = figure('Color', 'w', 'Name', '中文图325 Learned AudioWater PCA No Align');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tlo, 1);
[hMarker, hDrift] = iPlotRestingDriftOnAxes(ax1, PlotData);
title(ax1, 'Resting state drift', 'FontSize', 12);

ax2 = nexttile(tlo, 2);
hTrial = iPlotTrialsAttachedOnAxes(ax2, PlotData);
title(ax2, 'Trials attached', 'FontSize', 12);
ax2.YAxis.Visible = 'off';

iApplySharedLimits([ax1, ax2], PlotData);
xlabel(tlo, sprintf('PC1 (%.1f%%)', PlotData.PcaTable.Explained(1)), 'FontSize', 12);
ylabel(tlo, sprintf('PC2 (%.1f%%)', PlotData.PcaTable.Explained(2)), 'FontSize', 12);

hMarkerLegend = plot(ax1, nan, nan, 'o', 'LineStyle', 'none', ...
	'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0 0 1], 'LineWidth', 1.2);
hTrialLegend = plot(ax1, nan, nan, '-', 'LineWidth', 2, 'Color', [1 0 0]);
hDriftLegend = plot(ax1, nan, nan, '--', 'LineWidth', 1.5, 'Color', [0 0 1]);

lgd = legend(ax1, [hMarkerLegend, hTrialLegend, hDriftLegend], ["Trial #", "Trial", "Resting drift"], ...
	'Orientation', 'horizontal', 'NumColumns', 3);
lgd.Layout.Tile = 'south';
lgd.Box = 'off';
lgd.FontSize = 12;
lgd.FontName = 'Segoe UI Emoji';
lgd.ItemTokenSize = [8, 8];

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig325_LearnedAudioWater_PCA_NoAlign.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('Fig325 cells used: %d\n', nCellsUsed);
fprintf('Fig325 mice used: %d\n', nMiceUsed);

assignin('base', 'Fig36_GroupNtats', GPlot);

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
	error('Fig325:EmptySuperMouse', 'No cells found after pooling for requested trials.');
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
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2,true);
PcaLines = PcaTable.Score;

PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
sampleRate = 8;
idxCue = 3 * sampleRate;
idxWater = idxCue + round(1.0 * sampleRate);
idxCue = max(1, min(nTime, idxCue));
idxWater = max(1, min(nTime, idxWater));
idxPlotTime = idxCue:idxWater;
PcaData = PcaDataAll(:, idxPlotTime, :);

PlotData = struct();
PlotData.PcaTable = PcaTable;
PlotData.PcaData = PcaData;
PlotData.cuePts = squeeze(PcaData(:, 1, :)).';
PlotData.waterPts = squeeze(PcaData(:, end, :)).';
PlotData.nLines = size(PcaData, 3);
PlotData.lineColors = iAlphaRamp([1 0 0], PlotData.nLines);

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

function [hMarker, hDrift] = iPlotRestingDriftOnAxes(ax, PlotData)
iFormatAxes(ax);

cuePts = PlotData.cuePts;
hDrift = plot(ax, cuePts(:, 1), cuePts(:, 2), '--', 'LineWidth', 1.5, 'Color', [0 0 1]);
hMarker = plot(ax, cuePts(:, 1), cuePts(:, 2), 'o', 'LineStyle', 'none', ...
	'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0 0 1], 'LineWidth', 1.2);

xOffset = 0.025 * PlotData.xSpan;
yOffset = 0.02 * PlotData.ySpan;
for iLine = 1:PlotData.nLines
	if mod(iLine, 2) == 1
		yText = cuePts(iLine, 2) + yOffset;
		vAlign = 'bottom';
	else
		yText = cuePts(iLine, 2) - yOffset;
		vAlign = 'top';
	end
	text(ax, cuePts(iLine, 1) + xOffset, yText, sprintf('%d', iLine), ...
		'FontSize', 12, 'HorizontalAlignment', 'left', 'VerticalAlignment', vAlign, ...
		'Clipping', 'on', 'HandleVisibility', 'off');
end

view(ax, 2);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function hTrial = iPlotTrialsAttachedOnAxes(ax, PlotData)
iFormatAxes(ax);

PcaData = PlotData.PcaData;
cuePts = PlotData.cuePts;
waterPts = PlotData.waterPts;

	for iLine = 1:PlotData.nLines
		xy = squeeze(PcaData(:, :, iLine));
		plot(ax, xy(1, :), xy(2, :), '-', 'LineWidth', 2, 'Color', PlotData.lineColors(iLine, :), 'HandleVisibility', 'off');
	end

% Connect 0s points (cue onset) across trials with blue dashed line
plot(ax, cuePts(:, 1), cuePts(:, 2), '--', 'LineWidth', 1.5, 'Color', [0 0 1], 'HandleVisibility', 'off');

hTrial = plot(ax, nan, nan, '-', 'LineWidth', 2, 'Color', [1 0 0]);

for iLine = 1:PlotData.nLines
	text(ax, cuePts(iLine, 1), cuePts(iLine, 2), '🔊', ...
		'FontSize', 12, 'FontName', 'Segoe UI Emoji', 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle', 'Clipping', 'on', 'HandleVisibility', 'off');
	text(ax, waterPts(iLine, 1), waterPts(iLine, 2), '💧', ...
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
ax.LineWidth = 2;
box(ax, 'off');
grid(ax, 'off');
hold(ax, 'on');
end

function iApplySharedLimits(axs, PlotData)
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

xLim = [min(xAll) - xMargin, max(xAll) + xMargin];
yLim = [min(yAll) - yMargin, max(yAll) + yMargin];

for iAx = 1:numel(axs)
	xlim(axs(iAx), xLim);
	ylim(axs(iAx), yLim);
end
end

function colors = iAlphaRamp(baseColor, nLines)
if nLines <= 1
	colors = [baseColor, 1];
	return;
end

alphaVals = linspace(0.25, 1.0, nLines)';
colors = [repmat(baseColor, nLines, 1), alphaVals];
end

