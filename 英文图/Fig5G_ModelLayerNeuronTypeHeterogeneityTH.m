% English Fig5G: model response heterogeneity during formal Cue B learning,
% Normal (Transfer condition) vs simulated TH inhibition (THOff condition,
% reduced TeachingSignalScale), by layer and neuron type. Caliber copied from
% Chinese Fig63E; P-values overridden as rank-sum per pair (English-figure
% caliber, same as Fig5D). Data: shared model cache top-level Heterogeneity
% (per-mouse mean across-cell SD of cue response; L23E/L23I/L5E/L5I;
% n = 50 simulated mice per group).
%
% Claim: simulated thalamic inhibition lowers response heterogeneity,
% reproducing the in-vivo TH-inhibition result (Figure 4D).
%
% Outputs (SVG):
%   - English_Fig5G_ModelLayerNeuronTypeHeterogeneityTH.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

svgName = "English_Fig5G_ModelLayerNeuronTypeHeterogeneityTH.svg";

thisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

run(fullfile(thisDir, '..', '中文图', 'Fig5556_LoadSharedModelData.m'));
Heterogeneity = Fig5556Data.Heterogeneity;

layerNames = ["L23", "L5"];
layerLabels = ["L2/3", "L5"];
cellTypeLabels = ["E", "I"];
groupFields = ["Transfer", "THOff"];
groupLabels = ["Normal", "TH inhibited"];
groupColors = [TransferLearning.TransferColor; TransferLearning.ColorB];

% 规范：两行 bar tile 可选放大 ×2（同中文 63E）；高 8 cm，宽 9 cm；legend 挂 Layout 北侧
fig = figure('Color', 'w', 'Name', 'English Fig5G model Normal TH heterogeneity');
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 9, 8];
fig.PaperSize = [9, 8];

tileLayout = tiledlayout(fig, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
summaryCells = cell(numel(layerNames), 1);
optionalCells = cell(numel(layerNames), 1);
fprintf('=== English Fig5G model Normal vs TH-inhibited heterogeneity ===\n');
for layerIndex = 1:numel(layerNames)
	layerName = layerNames(layerIndex);
	ax = nexttile(tileLayout, layerIndex);
	metricNames = layerName + ["E", "I"];
	[dataTable, meanMat, semMat, nMat] = iBuildMetricDataTable(Heterogeneity, metricNames, cellTypeLabels, groupFields, groupLabels, ["NeuronType", "Group"]);
	pVec = iPairRanksumP(Heterogeneity, metricNames, groupFields);
	[~, optionalCells{layerIndex}] = iPlotGroupedBars(ax, dataTable, iWithinItemCompareGroup(cellTypeLabels, groupLabels, dataTable.Properties.DimensionNames), groupLabels, groupColors, layerLabels(layerIndex), pVec);
	% 规范：同 X 轴只保留最下行刻度标签
	if layerIndex < numel(layerNames)
		ax.XTickLabel = {};
	end
	summaryCells{layerIndex} = iSummaryTable(layerLabels(layerIndex), metricNames, groupLabels, meanMat, semMat, nMat);
	for pairIndex = 1:numel(metricNames)
		fprintf('%s %s: %s %.4f +/- %.4f (n=%d) vs %s %.4f +/- %.4f (n=%d), rank-sum p = %.4g\n', ...
			layerLabels(layerIndex), cellTypeLabels(pairIndex), ...
			groupLabels(1), meanMat(pairIndex, 1), semMat(pairIndex, 1), nMat(pairIndex, 1), ...
			groupLabels(2), meanMat(pairIndex, 2), semMat(pairIndex, 2), nMat(pairIndex, 2), ...
			pVec(pairIndex));
	end
end
xlabel(tileLayout, 'Neuron type');
ylabel(tileLayout, 'Heterogeneity');
% 只保留第一 tile 的 legend，挂到 Layout 北侧横向排列（避免 eastoutside 占宽）
lgd = optionalCells{1}.Legend;
for layerIndex = 2:numel(layerNames)
	if isfield(optionalCells{layerIndex}, 'Legend') && isgraphics(optionalCells{layerIndex}.Legend)
		delete(optionalCells{layerIndex}.Legend);
	end
end
lgd.String = cellstr(groupLabels);
lgd.Layout.Tile = 'north';
lgd.Orientation = 'horizontal';
lgd.Box = 'off';
lgd.AutoUpdate = 'off';
SummaryTable = vertcat(summaryCells{:});
for layerIndex = 1:numel(layerNames)
	iRetunePValueLines(optionalCells{layerIndex});
end

svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig5G_ModelHeterogeneity', Heterogeneity);
assignin('base', 'Fig5G_ModelHeterogeneitySummary', SummaryTable);

%% ========== local functions ==========
function [dataTable, meanMat, semMat, nMat] = iBuildMetricDataTable(Heterogeneity, metricNames, itemLabels, groupFields, groupLabels, dimensionNames)
meanMat = nan(numel(metricNames), numel(groupFields));
semMat = nan(numel(metricNames), numel(groupFields));
nMat = nan(numel(metricNames), numel(groupFields));
dataCell = cell(numel(metricNames), numel(groupFields));
for metricIndex = 1:numel(metricNames)
	metricName = metricNames(metricIndex);
	for groupIndex = 1:numel(groupFields)
		values = Heterogeneity.(groupFields(groupIndex)).(metricName);
		values = values(:);
		values = values(isfinite(values));
		dataCell{metricIndex, groupIndex} = values;
		[meanMat(metricIndex, groupIndex), semMat(metricIndex, groupIndex), nMat(metricIndex, groupIndex)] = iMeanSemFinite(values);
	end
end
dataTable = cell2table(dataCell, 'VariableNames', cellstr(groupLabels), 'RowNames', cellstr(itemLabels));
dataTable.Properties.DimensionNames = cellstr(dimensionNames);
end

function pVec = iPairRanksumP(Heterogeneity, metricNames, groupFields)
pVec = nan(numel(metricNames), 1);
for metricIndex = 1:numel(metricNames)
	vA = Heterogeneity.(groupFields(1)).(metricNames(metricIndex));
	vB = Heterogeneity.(groupFields(2)).(metricNames(metricIndex));
	vA = vA(isfinite(vA));
	vB = vB(isfinite(vB));
	pVec(metricIndex) = ranksum(vA, vB);
end
end

function [barHandles, optional] = iPlotGroupedBars(ax, dataTable, compareGroup, groupLabels, groupColors, titleText, pVec)
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, iColorTable(groupLabels, groupColors), ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
delete(findobj(ax, 'Type', 'Scatter'));
for barIndex = 1:numel(barHandles)
	barHandles(barIndex).BarWidth = 0.5;
	barHandles(barIndex).LineWidth = 1;
	barHandles(barIndex).EdgeColor = 'none';
	barHandles(barIndex).FaceColor = groupColors(barIndex, :);
	barHandles(barIndex).DisplayName = groupLabels(barIndex);
	if isprop(barHandles(barIndex), 'FaceAlpha')
		barHandles(barIndex).FaceAlpha = 1;
	end
	if isprop(barHandles(barIndex), 'BaseLine') && isgraphics(barHandles(barIndex).BaseLine)
		barHandles(barIndex).BaseLine.Visible = 'off';
	end
end
iStyleErrorBars(errorBars, barHandles, groupColors);
iOverridePText(optional, pVec);
iRecalcErrorBarCapSize(ax, barHandles, errorBars, 0.5);
title(ax, titleText, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
ax.Color = 'none';
if isfield(optional, 'Legend') && isgraphics(optional.Legend)
	optional.Legend.Box = 'off';
	optional.Legend.AutoUpdate = 'off';
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iStyleErrorBars(errorBars, barHandles, groupColors)
if ~(istable(errorBars) && ~isempty(errorBars) && ismember('Object', errorBars.Properties.VariableNames))
	return;
end
for iE = 1:height(errorBars)
	eb = errorBars.Object(iE);
	if ~isgraphics(eb)
		continue;
	end
	eb.LineWidth = 1;
	xData = double(eb.XData(:));
	xData = xData(isfinite(xData));
	if isempty(xData)
		continue;
	end
	% 分组柱：每根误差条着色到最近 bar 系列（同 PlotPreFormalConnectionWeightStdBars）
	bestColor = groupColors(1, :);
	bestDist = inf;
	for iBar = 1:numel(barHandles)
		if ~isgraphics(barHandles(iBar)) || ~isprop(barHandles(iBar), 'XEndPoints')
			continue;
		end
		xp = double(barHandles(iBar).XEndPoints(:));
		xp = xp(isfinite(xp));
		if isempty(xp)
			continue;
		end
		d = min(abs(xp - xData(1)));
		if d < bestDist
			bestDist = d;
			bestColor = groupColors(iBar, :);
		end
	end
	eb.Color = bestColor;
	setappdata(eb, 'TransferLearningPreserveLineWidth', true);
end
end

function iOverridePText(Optional, pVec)
% BarScatterCompare 内部 anova/multcompare 之外统一报告 rank-sum p
if ~(isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare))
	return;
end
mc = Optional.MultiCompare;
if ~ismember('PText', mc.Properties.VariableNames) || height(mc) ~= numel(pVec)
	return;
end
for ip = 1:height(mc)
	pt = mc.PText(ip);
	if isgraphics(pt)
		pt.String = TransferLearning.Style.iFormatPText(pVec(ip));
		pt.Tag = 'PText';
	end
	if ismember('PLine', mc.Properties.VariableNames) && isgraphics(mc.PLine(ip))
		mc.PLine(ip).Tag = 'PLine';
	end
end
end

function compareGroup = iWithinItemCompareGroup(itemLabels, groupLabels, dimensionNames)
itemLabels = string(itemLabels(:));
groupLabels = string(groupLabels(:)).';
itemPair = [itemLabels, itemLabels];
groupPair = repmat(groupLabels(1:2), numel(itemLabels), 1);
GroupPair = table(itemPair, groupPair, 'VariableNames', cellstr(dimensionNames));
compareGroup = table(GroupPair);
end

function colors = iColorTable(groupLabels, groupColors)
colors = array2table(groupColors, 'VariableNames', {'R','G','B'}, 'RowNames', cellstr(groupLabels));
end

function iRecalcErrorBarCapSize(ax, barHandles, errorBars, capSizeRatio)
% Recompute CapSize using the same formula as BarScatterCompare
axUnits = ax.Units;
ax.Units = 'points';
axWidth = ax.Position(3);
ax.Units = axUnits;
barWidth = barHandles(1).BarWidth;
groupWidth = barHandles(1).GroupWidth;
xRange = diff(xlim(ax));
nBars = numel(barHandles);
capSize = axWidth * barWidth * groupWidth * capSizeRatio / (xRange * nBars);
for rowIndex = 1:height(errorBars)
	errBar = errorBars.Object(rowIndex);
	if isgraphics(errBar) && isprop(errBar, 'CapSize')
		errBar.CapSize = capSize;
	end
end
end

function iRetunePValueLines(optional)
if ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
if ~all(ismember({'PLine','PText'}, optional.MultiCompare.Properties.VariableNames))
	return;
end
MATLAB.Graphics.PLineRetune(optional.MultiCompare.PLine, optional.MultiCompare.PText);
end

function [meanValue, semValue, nValues] = iMeanSemFinite(values)
values = values(:);
values = values(isfinite(values));
nValues = numel(values);
if nValues == 0
	meanValue = NaN;
	semValue = NaN;
	return;
end
meanValue = mean(values, 'omitnan');
if nValues < 2
	semValue = NaN;
else
	semValue = std(values, 0, 'omitnan') / sqrt(nValues);
end
end

function SummaryTable = iSummaryTable(layerName, metricNames, groupLabels, meanMat, semMat, nMat)
nRows = numel(metricNames) * numel(groupLabels);
layer = strings(nRows, 1);
metric = strings(nRows, 1);
group = strings(nRows, 1);
meanValue = nan(nRows, 1);
semValue = nan(nRows, 1);
nMice = nan(nRows, 1);
rowIndex = 0;
for metricIndex = 1:numel(metricNames)
	for groupIndex = 1:numel(groupLabels)
		rowIndex = rowIndex + 1;
		layer(rowIndex) = layerName;
		metric(rowIndex) = metricNames(metricIndex);
		group(rowIndex) = groupLabels(groupIndex);
		meanValue(rowIndex) = meanMat(metricIndex, groupIndex);
		semValue(rowIndex) = semMat(metricIndex, groupIndex);
		nMice(rowIndex) = nMat(metricIndex, groupIndex);
	end
end
SummaryTable = table(layer, metric, group, meanValue, semValue, nMice, ...
	'VariableNames', {'Layer','Metric','Group','Mean','SEM','NMice'});
end
