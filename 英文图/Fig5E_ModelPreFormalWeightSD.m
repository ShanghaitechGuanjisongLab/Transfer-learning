% English Fig5E: model per-mouse connection weight SD before formal Cue B
% training. Data: shared model cache PreFormalWeightValues.MouseStd (per-mouse
% SD of each initialized connection-type weight matrix; EE/EI/IE/II; n = 50
% simulated mice per group), Naive (untrained) vs CueA learned (after Cue A
% pretraining). Top tile of Chinese Fig54B, exported as a standalone English
% panel. P-values: rank-sum per connection type (English-figure caliber).
%
% Claim: Cue A learning leaves the inherited connection weights more
% heterogeneous than an untrained network.
%
% Outputs (SVG):
%   - English_Fig5E_ModelPreFormalWeightSD.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

svgName = "English_Fig5E_ModelPreFormalWeightSD.svg";

thisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

run(fullfile(thisDir, '..', '中文图', 'Fig5556_LoadSharedModelData.m'));
WeightValues = Fig5556Data.PreFormalWeightValues;

classNames = ["EE", "EI", "IE", "II"];
classLabels = ["E→E", "E→I", "I→E", "I→I"];
groupFields = ["Naive", "AfterPretrain"];
groupLabels = ["Naive", "CueA learned"];
groupColors = [TransferLearning.NaiveColor; TransferLearning.LearnedColor];

% 规范：基础高 4 cm；有 legend 放大 ×2 → 8 cm；宽 12 cm（中文 54B 上半幅）
fig = figure('Color', 'w', 'Name', 'English Fig5E model pre-formal connection weight SD');
fig.Units = 'centimeters';
fig.Position(3:4) = [12, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 12, 8];
fig.PaperSize = [12, 8];

ax = axes(fig);
[dataTable, meanMat, semMat, nMat] = iBuildMetricDataTable(WeightValues.MouseStd, classNames, classLabels, groupFields, groupLabels, ["ConnectionType", "Group"]);
pVec = iPairRanksumP(WeightValues.MouseStd, classNames, groupFields);
[~, optional] = iPlotGroupedBars(ax, dataTable, iWithinItemCompareGroup(classLabels, groupLabels, dataTable.Properties.DimensionNames), groupLabels, groupColors, classLabels, pVec);
iRetunePValueLines(optional);

fprintf('=== English Fig5E pre-formal connection weight SD ===\n');
for pairIndex = 1:numel(classNames)
	fprintf('%s: %s %.4f +/- %.4f (n=%d) vs %s %.4f +/- %.4f (n=%d), rank-sum p = %.4g\n', ...
		classLabels(pairIndex), groupLabels(1), meanMat(pairIndex, 1), semMat(pairIndex, 1), nMat(pairIndex, 1), ...
		groupLabels(2), meanMat(pairIndex, 2), semMat(pairIndex, 2), nMat(pairIndex, 2), ...
		pVec(pairIndex));
end

SummaryTable = iSummaryTable("ConnectionWeightSD", classNames, groupLabels, meanMat, semMat, nMat);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig5E_ModelPreFormalWeightSummary', SummaryTable);

%% ========== local functions (copied from PlotPreFormalConnectionWeightStdBars) ==========
function [dataTable, meanMat, semMat, nMat] = iBuildMetricDataTable(MetricValues, itemNames, itemLabels, groupFields, groupLabels, dimensionNames)
meanMat = nan(numel(itemNames), numel(groupFields));
semMat = nan(numel(itemNames), numel(groupFields));
nMat = nan(numel(itemNames), numel(groupFields));
dataCell = cell(numel(itemNames), numel(groupFields));
for itemIndex = 1:numel(itemNames)
	itemName = itemNames(itemIndex);
	for groupIndex = 1:numel(groupFields)
		values = MetricValues.(groupFields(groupIndex)).(itemName);
		values = values(:);
		values = values(isfinite(values));
		dataCell{itemIndex, groupIndex} = values;
		[meanMat(itemIndex, groupIndex), semMat(itemIndex, groupIndex), nMat(itemIndex, groupIndex)] = iMeanSemFinite(values);
	end
end
dataTable = cell2table(dataCell, 'VariableNames', cellstr(groupLabels), 'RowNames', cellstr(itemLabels));
dataTable.Properties.DimensionNames = cellstr(dimensionNames);
end

function pVec = iPairRanksumP(MetricValues, itemNames, groupFields)
pVec = nan(numel(itemNames), 1);
for itemIndex = 1:numel(itemNames)
	vA = MetricValues.(groupFields(1)).(itemNames(itemIndex));
	vB = MetricValues.(groupFields(2)).(itemNames(itemIndex));
	vA = vA(isfinite(vA));
	vB = vB(isfinite(vB));
	pVec(itemIndex) = ranksum(vA, vB);
end
end

function [barHandles, optional] = iPlotGroupedBars(ax, dataTable, compareGroup, groupLabels, groupColors, xTickLabels, pVec)
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, iColorTable(groupLabels, groupColors), ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
delete(findobj(ax, 'Type', 'Scatter'));
for iBar = 1:numel(barHandles)
	barHandles(iBar).LineStyle = 'none';
	barHandles(iBar).FaceColor = groupColors(iBar, :);
	barHandles(iBar).BarWidth = 0.5;
	if isprop(barHandles(iBar), 'FaceAlpha')
		barHandles(iBar).FaceAlpha = 1;
	end
	if isprop(barHandles(iBar), 'BaseLine') && isgraphics(barHandles(iBar).BaseLine)
		barHandles(iBar).BaseLine.Visible = 'off';
	end
end
for rowIndex = 1:height(errorBars)
	errorBar = errorBars.Object(rowIndex);
	if ~isgraphics(errorBar)
		continue;
	end
	x = double(errorBar.XData(1));
	if ~isfinite(x)
		continue;
	end
	bestColor = groupColors(1, :);
	bestDist = inf;
	for iBar2 = 1:numel(barHandles)
		xp = double(barHandles(iBar2).XEndPoints(:));
		d = min(abs(xp - x));
		if d < bestDist
			bestDist = d;
			bestColor = groupColors(iBar2, :);
		end
	end
	errorBar.Color = bestColor;
	errorBar.LineWidth = 1;
	setappdata(errorBar, 'TransferLearningPreserveLineWidth', true);
end
iOverridePText(optional, pVec);
iRecalcErrorBarCapSize(ax, barHandles, errorBars, 0.5);
ax.XTick = 1:height(dataTable);
% 前导 3 空格触发 MATLAB X 标签自动旋转（规范：不得手动旋转）
ax.XTickLabel = cellstr("   " + string(xTickLabels));
xlabel(ax, 'Connection type');
ylabel(ax, 'Weight SD');
box(ax, 'off');
grid(ax, 'off');
ax.Color = 'none';
legendHandle = optional.Legend;
legendHandle.String = cellstr(groupLabels);
% 规范：文字不得重叠；P 值文字占满轴内顶部，legend 移到轴外北侧
legendHandle.Location = 'northoutside';
legendHandle.Orientation = 'horizontal';
legendHandle.Box = 'off';
legendHandle.AutoUpdate = 'off';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
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

function SummaryTable = iSummaryTable(panelName, itemNames, groupLabels, meanMat, semMat, nMat)
nRows = numel(itemNames) * numel(groupLabels);
panel = strings(nRows, 1);
category = strings(nRows, 1);
group = strings(nRows, 1);
meanValue = nan(nRows, 1);
semValue = nan(nRows, 1);
nMice = nan(nRows, 1);
rowIndex = 0;
for itemIndex = 1:numel(itemNames)
	for groupIndex = 1:numel(groupLabels)
		rowIndex = rowIndex + 1;
		panel(rowIndex) = panelName;
		category(rowIndex) = itemNames(itemIndex);
		group(rowIndex) = groupLabels(groupIndex);
		meanValue(rowIndex) = meanMat(itemIndex, groupIndex);
		semValue(rowIndex) = semMat(itemIndex, groupIndex);
		nMice(rowIndex) = nMat(itemIndex, groupIndex);
	end
end
SummaryTable = table(panel, category, group, meanValue, semValue, nMice, ...
	'VariableNames', {'Panel','Category','Group','Mean','SEM','NMice'});
end
