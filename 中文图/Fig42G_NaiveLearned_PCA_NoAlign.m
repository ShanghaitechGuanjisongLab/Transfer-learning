% 中文图42G：Naive AudioOnly & Learned AudioWater 的 PCA（统一空间）

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

[GNaive, GLearned] = iNtsSuperMousePaired(DSList, "Naive", "AudioOnly", "Learned", "AudioWater", 30);
GNaiveP = iAverageAdjacentTrials(GNaive, 3);
GLearnedP = iAverageAdjacentTrials(GLearned, 3);

% Build merged NTATS: (nCommonCells, nTime, nTrialsN + nTrialsL)
XNaive = GNaiveP.NTATS{:,:,:};
XLearned = GLearnedP.NTATS{:,:,:};
XMerged = cat(3, XNaive, XLearned);
nTrialsNaive = size(XNaive, 3);
nTrialsLearned = size(XLearned, 3);
ntMerged = MATLAB.DataTypes.NDTable(XMerged);

% Shared PCA
PcaTable = UniExp.LinearPca(ntMerged, 2, true);
PcaAll = PcaTable.Score.Data;  % (2, nTime, nTrialsTotal)

% Split back
PcaNaive = PcaAll(:, :, 1:nTrialsNaive);
PcaLearned = PcaAll(:, :, nTrialsNaive+1:end);

nTime = size(PcaAll, 2);
PlotDataNaive = iBuildPlotData(PcaNaive, nTime, PcaTable.Explained);
PlotDataLearned = iBuildPlotData(PcaLearned, nTime, PcaTable.Explained);

nCellsNaive = height(GNaiveP);
nMiceNaive = numel(unique(string(GNaiveP.Mouse)));
nCellsLearned = height(GLearnedP);
nMiceLearned = numel(unique(string(GLearnedP.Mouse)));

f = figure('Color', 'w', 'Name', '中文图42G Naive+Learned PCA');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
ax1 = nexttile(tlo, 1);
[hMarkerN, hDriftN] = iPlotRestingDriftOnAxes(ax1, PlotDataNaive, TransferLearning.ColorA, 1);
[hMarkerL, hDriftL] = iPlotRestingDriftOnAxes(ax1, PlotDataLearned, TransferLearning.LearnedColor, 2);
title(ax1, 'Resting state drift', 'FontSize', 12);

ax2 = nexttile(tlo, 2);
hTrialN = iPlotTrialsOnAxes(ax2, PlotDataNaive, TransferLearning.NaiveColor);
hTrialL = iPlotTrialsOnAxes(ax2, PlotDataLearned, TransferLearning.LearnedColor);
title(ax2, "🔊 response in" + newline + "the same PCA space", 'FontSize', 12);
ax2.YAxis.Visible = 'off';

iApplySharedLimits([ax1, ax2], PcaAll);
xlabel(tlo, sprintf('PC1 (%.1f%%)', PlotDataNaive.PcaTable.Explained(1)), 'FontSize', 12);
ylabel(tlo, sprintf('PC2 (%.1f%%)', PlotDataNaive.PcaTable.Explained(2)), 'FontSize', 12);

hMarkerLegend = plot(ax1, nan, nan, 'o', 'LineStyle', 'none', ...
	'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', TransferLearning.ColorA, 'LineWidth', 1);
hDriftNLegend = plot(ax1, nan, nan, '--', 'LineWidth', 2, 'Color', TransferLearning.ColorA);
hDriftLLegend = plot(ax1, nan, nan, '--', 'LineWidth', 2, 'Color', TransferLearning.LearnedColor);
hNaiveLine = plot(ax1, nan, nan, '-', 'LineWidth', 2, 'Color', TransferLearning.NaiveColor);
hLearnedLine = plot(ax1, nan, nan, '-', 'LineWidth', 2, 'Color', TransferLearning.LearnedColor);

lgd = legend(ax1, [hMarkerLegend, hDriftNLegend, hDriftLLegend, hNaiveLine, hLearnedLine], ...
	["Trial #", "Naive drift", "Learned drift", "Naive 🔊", "Learned 🔊"], ...
	'Orientation', 'horizontal', 'NumColumns', 5);
lgd.Layout.Tile = 'south';
lgd.Box = 'off';
lgd.FontSize = 12;
lgd.FontName = 'Segoe UI Emoji';
lgd.ItemTokenSize(1) = 8;

svgPath = TransferLearning.StandardFigureSvgPath('中文图Fig42G_NaiveLearned_PCA_NoAlign.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Fig42G Naive cells: %d, mice: %d\n', nCellsNaive, nMiceNaive);
fprintf('Fig42G Learned cells: %d, mice: %d\n', nCellsLearned, nMiceLearned);

assignin('base', 'Fig42G_GNaive', GNaiveP);
assignin('base', 'Fig42G_GLlearned', GLearnedP);

function [GroupNtatsNaive, GroupNtatsLearned] = iNtsSuperMousePaired(DSList, phaseN, stimN, phaseL, stimL, minTrials)
cellNaive = {}; cellLearned = {};
uidNaive = zeros(0, 1, 'uint64'); uidLearned = zeros(0, 1, 'uint64');
mouseNaive = strings(0, 1); mouseLearned = strings(0, 1);
nTime = [];

for iDS = 1:numel(DSList)
	DS = DSList{iDS};
	cellMeta = DS.Cells(:, ["CellUID", "Mouse"]);
	cellMeta.CellUID = uint64(cellMeta.CellUID);
	cellMeta.Mouse = string(cellMeta.Mouse);

	ntsN = DS.QueryNTS(struct('Stimulus', stimN, 'Phase', phaseN), UniExp.Flags.No_special_operation, 1:24);
	ntsL = DS.QueryNTS(struct('Stimulus', stimL, 'Phase', phaseL), UniExp.Flags.No_special_operation, 1:24);
	ntsNaive = ntsN{1}; ntsLearned = ntsL{1};

	uidsN = unique(uint64(ntsNaive.CellUID));
	uidsL = unique(uint64(ntsLearned.CellUID));
	commonUIDs = intersect(uidsN, uidsL);

	for iC = 1:numel(commonUIDs)
		cid = commonUIDs(iC);
		rowsN = (uint64(ntsNaive.CellUID) == cid);
		rowsL = (uint64(ntsLearned.CellUID) == cid);
		if sum(rowsN) < minTrials || sum(rowsL) < minTrials
			continue;
		end
		sigN = sortrows(table(uint64(ntsNaive.TrialUID(rowsN)), double(ntsNaive.TrialSignal(rowsN, :))), 1);
		sigN = sigN{1:minTrials, 2:end};
		sigL = sortrows(table(uint64(ntsLearned.TrialUID(rowsL)), double(ntsLearned.TrialSignal(rowsL, :))), 1);
		sigL = sigL{1:minTrials, 2:end};
		if any(~isfinite(sigN), 'all') || any(~isfinite(sigL), 'all')
			continue;
		end
		cellNaive{end+1, 1} = sigN; %#ok<AGROW>
		cellLearned{end+1, 1} = sigL; %#ok<AGROW>
		uidNaive(end+1, 1) = cid; %#ok<AGROW>
		uidLearned(end+1, 1) = cid; %#ok<AGROW>
		idx = find(cellMeta.CellUID == cid, 1);
		mouseNaive(end+1, 1) = cellMeta.Mouse(idx); %#ok<AGROW>
		mouseLearned(end+1, 1) = cellMeta.Mouse(idx); %#ok<AGROW>
		if isempty(nTime)
			nTime = size(sigN, 2);
		end
	end
end

if isempty(cellNaive)
	error('Fig42G:EmptyPaired', 'No paired cells found.');
end

nCells = numel(cellNaive);
CellTrialTimes = nan(nCells, minTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellNaive{iC};
end
ntatsN = MATLAB.DataTypes.NDTable(permute(CellTrialTimes, [1, 3, 2]));
GroupNtatsNaive = table(ntatsN, uidNaive, mouseNaive, 'VariableNames', ["NTATS", "CellUID", "Mouse"]);

for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellLearned{iC};
end
ntatsL = MATLAB.DataTypes.NDTable(permute(CellTrialTimes, [1, 3, 2]));
GroupNtatsLearned = table(ntatsL, uidLearned, mouseLearned, 'VariableNames', ["NTATS", "CellUID", "Mouse"]);
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

function PlotData = iBuildPlotData(score, nTime, explained)
idxPreCue = iFindPlotTimeIndex(nTime, -3);
idxCue = iFindPlotTimeIndex(nTime, 0);
idxWater = iFindPlotTimeIndex(nTime, 1);
idxPlotTime = idxPreCue:idxWater;
PcaData = score(:, idxPlotTime, :);
idxCueInPlot = idxCue - idxPreCue + 1;
idxWaterInPlot = idxWater - idxPreCue + 1;

PcaTable = struct();
PcaTable.Explained = explained;
PcaTable.ScoreData = score;

PlotData = struct();
PlotData.PcaTable = PcaTable;
PlotData.PcaData = PcaData;
PlotData.preCueSegment = 1:idxCueInPlot;
PlotData.postCueSegment = idxCueInPlot:idxWaterInPlot;
PlotData.cuePts = squeeze(PcaData(:, idxCueInPlot, :)).';
PlotData.waterPts = squeeze(PcaData(:, idxWaterInPlot, :)).';
PlotData.nLines = size(PcaData, 3);
end

function [hMarker, hDrift] = iPlotRestingDriftOnAxes(ax, PlotData, driftColor, offset)
iFormatAxes(ax);

cuePts = PlotData.cuePts;
hDrift = plot(ax, cuePts(:, 1), cuePts(:, 2), '--', 'LineWidth', 2, 'Color', driftColor);
hMarker = plot(ax, cuePts(:, 1), cuePts(:, 2), 'o', 'LineStyle', 'none', ...
	'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', driftColor, 'LineWidth', 1);

xAll = reshape(PlotData.PcaData(1, :, :), [], 1);
yAll = reshape(PlotData.PcaData(2, :, :), [], 1);
xSpan = max(xAll) - min(xAll);
ySpan = max(yAll) - min(yAll);
if ~isfinite(xSpan) || xSpan <= 0, xSpan = 1; end
if ~isfinite(ySpan) || ySpan <= 0, ySpan = 1; end

xOffset = 0.025 * xSpan;
yOffset = 0.02 * ySpan;
for iLine = 1:PlotData.nLines
	if mod(iLine + offset, 2) == 1
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

function hTrial = iPlotTrialsOnAxes(ax, PlotData, lineColor)
iFormatAxes(ax);

PcaData = PlotData.PcaData;
cuePts = PlotData.cuePts;
lineColors = iAlphaRamp(lineColor, PlotData.nLines);

for iLine = 1:PlotData.nLines
	xy = squeeze(PcaData(:, :, iLine));
	plot(ax, xy(1, PlotData.preCueSegment), xy(2, PlotData.preCueSegment), '-', 'LineWidth', 0.5, 'Color', TransferLearning.ColorB, 'HandleVisibility', 'off');
	plot(ax, xy(1, PlotData.postCueSegment), xy(2, PlotData.postCueSegment), '-', 'LineWidth', 2, 'Color', lineColors(iLine, :), 'HandleVisibility', 'off');
end

% Mark cue onset
plot(ax, cuePts(:, 1), cuePts(:, 2), '--', 'LineWidth', 2, 'Color', lineColor, 'HandleVisibility', 'off');

for iLine = 1:PlotData.nLines
	text(ax, cuePts(iLine, 1), cuePts(iLine, 2), '🔊', ...
		'FontSize', 12, 'FontName', 'Segoe UI Emoji', 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle', 'Clipping', 'on', 'HandleVisibility', 'off');
end

hTrial = plot(ax, nan, nan, '-', 'LineWidth', 2, 'Color', lineColor);

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

function iApplySharedLimits(axs, PcaDataAll)
xAll = reshape(PcaDataAll(1, :, :), [], 1);
yAll = reshape(PcaDataAll(2, :, :), [], 1);
xLim = prctile(xAll, [0.5, 99.5]);
yLim = prctile(yAll, [0.5, 99.5]);
if ~isfinite(xLim(1)), xLim = [min(xAll), max(xAll)]; end
if ~isfinite(yLim(1)), yLim = [min(yAll), max(yAll)]; end
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
