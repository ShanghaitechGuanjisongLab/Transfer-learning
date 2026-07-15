% Fig63E model learning-process heterogeneity by layer and neuron type.

svgName = '中文图Fig63E_ModelLayerNeuronTypeHeterogeneityBars.svg';
iEnsureTransferLearningProject();

run(fullfile(fileparts(mfilename('fullpath')), 'Fig5556_LoadSharedModelData.m'));
RunInfo = Fig5556Data.RunInfo;
Heterogeneity.Normal = Fig5556Data.Heterogeneity.Transfer;
Heterogeneity.THInhibited = Fig5556Data.Heterogeneity.THOff;

[fig, SummaryTable] = iPlotLayerNeuronTypeHeterogeneityBars(Heterogeneity);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig63E_ModelLayerNeuronTypeHeterogeneity', Heterogeneity);
assignin('base', 'Fig63E_ModelLayerNeuronTypeRunInfo', RunInfo);
assignin('base', 'Fig63E_ModelLayerNeuronTypeSummary', SummaryTable);
assignin('base', 'Fig63E_ModelLayerNeuronTypeSvgPath', svgPath);

function iEnsureTransferLearningProject()
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end
end

function [fig, SummaryTable] = iPlotLayerNeuronTypeHeterogeneityBars(Heterogeneity)
layerNames = ["L23", "L5"];
layerLabels = ["L2/3", "L5"];
cellTypeLabels = ["E", "I"];
groupFields = ["Normal", "THInhibited"];
groupLabels = ["Normal", "TH inhibited"];
groupColors = [TransferLearning.ContinualColor; TransferLearning.ColorB];

fig = figure('Color', 'w', 'Name', 'Fig63E layer and neuron type heterogeneity bars');
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 9, 8];
fig.PaperSize = [9, 8];

tileLayout = tiledlayout(fig, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
summaryCells = cell(numel(layerNames), 1);
optionalCells = cell(numel(layerNames), 1);
for layerIndex = 1:numel(layerNames)
	layerName = layerNames(layerIndex);
	ax = nexttile(tileLayout, layerIndex);
	metricNames = layerName + ["E", "I"];
	[dataTable, meanMat, semMat, nMat] = iBuildMetricDataTable(Heterogeneity, metricNames, cellTypeLabels, groupFields, groupLabels, ["NeuronType", "Group"]);
	[~, optionalCells{layerIndex}] = iPlotGroupedBars(ax, dataTable, iWithinItemCompareGroup(cellTypeLabels, groupLabels, dataTable.Properties.DimensionNames), groupLabels, groupColors, layerLabels(layerIndex));
	if layerIndex > 1 && isfield(optionalCells{layerIndex}, 'Legend') && isgraphics(optionalCells{layerIndex}.Legend)
		delete(optionalCells{layerIndex}.Legend);
	end
	summaryCells{layerIndex} = iSummaryTable(layerLabels(layerIndex), metricNames, groupLabels, meanMat, semMat, nMat);
end
xlabel(tileLayout, 'Neuron type', 'FontSize', 12);
ylabel(tileLayout, 'Heterogeneity', 'FontSize', 12);
SummaryTable = vertcat(summaryCells{:});
iSetFigureTextFontSize(fig, 12);
for layerIndex = 1:numel(layerNames)
	iRetunePValueLines(optionalCells{layerIndex});
end
end

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

function [barHandles, optional] = iPlotGroupedBars(ax, dataTable, compareGroup, groupLabels, groupColors, titleText)
barWidth = 0.5;
capSize = 4;
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, UniExp.Flags.empty, compareGroup, iColorTable(groupLabels, groupColors), ax, 'AsteriskThreshold', 0.05, 'CapSize', capSize);
fprintf('\n=== Fig63E %s BarScatterCompare P-values ===\n', titleText);
if isfield(optional, 'MultiCompare') && istable(optional.MultiCompare)
	for iMC = 1:height(optional.MultiCompare)
		fprintf('  %s vs %s: %s\n', ...
			optional.MultiCompare.Group{iMC, 1}, optional.MultiCompare.Group{iMC, 2}, ...
			TransferLearning.Style.iFormatPText(optional.MultiCompare.PValue(iMC)));
	end
end
for barIndex = 1:numel(barHandles)
	barHandles(barIndex).BarWidth = barWidth;
	barHandles(barIndex).LineWidth = 1;
	barHandles(barIndex).EdgeColor = 'none';
	barHandles(barIndex).LineStyle = 'none';
	barHandles(barIndex).DisplayName = groupLabels(barIndex);
	if isprop(barHandles(barIndex), 'FaceAlpha')
		barHandles(barIndex).FaceAlpha = 1;
	end
	if isprop(barHandles(barIndex), 'BaseLine') && isgraphics(barHandles(barIndex).BaseLine)
		barHandles(barIndex).BaseLine.Visible = 'off';
	end
end
iStyleErrorBars(errorBars, barHandles, groupColors, capSize);

ax.XLim = [0.5, height(dataTable) + 0.5];
ax.XTickLabelRotation = 0;
title(ax, titleText, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 12;
if isfield(optional, 'Legend') && isgraphics(optional.Legend)
	optional.Legend.String = cellstr(groupLabels);
	optional.Legend.Location = 'eastoutside';
	optional.Legend.Orientation = 'vertical';
	optional.Legend.Box = 'off';
	optional.Legend.FontSize = 12;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
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

function iStyleErrorBars(errorBars, barHandles, groupColors, capSize)
if isempty(errorBars)
	return;
end
processedErrorBars = gobjects(height(errorBars), 1);
nProcessed = 0;
for rowIndex = 1:height(errorBars)
	errorBar = errorBars.Object(rowIndex);
	if ~isgraphics(errorBar)
		continue;
	end
	if nProcessed > 0 && any(processedErrorBars(1:nProcessed) == errorBar)
		continue;
	end
	nProcessed = nProcessed + 1;
	processedErrorBars(nProcessed) = errorBar;
	xData = double(errorBar.XData(:));
	yData = double(errorBar.YData(:));
	yNegative = iErrorDelta(errorBar, 'YNegativeDelta', 'LData', numel(xData));
	yPositive = iErrorDelta(errorBar, 'YPositiveDelta', 'UData', numel(xData));
	groupIndex = arrayfun(@(x) iNearestBarGroupFromX(x, barHandles, size(groupColors, 1)), xData);
	parentAxes = errorBar.Parent;
	if numel(unique(groupIndex)) > 1
		holdState = ishold(parentAxes);
		cleanupHold = onCleanup(@()hold(parentAxes, holdState));
		hold(parentAxes, 'on');
		errorBar.Visible = 'off';
		errorBar.HandleVisibility = 'off';
		for pointIndex = 1:numel(xData)
			newErrorBar = errorbar(parentAxes, xData(pointIndex), yData(pointIndex), yNegative(pointIndex), yPositive(pointIndex), ...
				'LineStyle', 'none', 'Color', groupColors(groupIndex(pointIndex), :), 'LineWidth', 1, ...
				'CapSize', capSize, 'HandleVisibility', 'off');
			setappdata(newErrorBar, 'TransferLearningPreserveLineWidth', true);
		end
	else
		errorBar.LineWidth = 1;
		errorBar.Color = groupColors(groupIndex(1), :);
		errorBar.HandleVisibility = 'off';
		if isprop(errorBar, 'CapSize')
			errorBar.CapSize = capSize;
		end
		setappdata(errorBar, 'TransferLearningPreserveLineWidth', true);
	end
end
end

function delta = iErrorDelta(errorBar, propertyName, fallbackPropertyName, nPoint)
if isprop(errorBar, propertyName)
	delta = double(errorBar.(propertyName)(:));
else
	delta = [];
end
if isempty(delta) && isprop(errorBar, fallbackPropertyName)
	delta = double(errorBar.(fallbackPropertyName)(:));
end
if isempty(delta)
	delta = zeros(nPoint, 1);
end
if isscalar(delta) && nPoint > 1
	delta = repmat(delta, nPoint, 1);
end
if numel(delta) < nPoint
	delta(end + 1:nPoint, 1) = delta(end);
end
delta = delta(1:nPoint);
end

function groupIndex = iNearestBarGroupFromX(x, barHandles, nGroup)
if ~isfinite(x)
	groupIndex = 1;
	return;
end
bestDistance = inf;
groupIndex = 1;
for barIndex = 1:numel(barHandles)
	if ~isgraphics(barHandles(barIndex)) || ~isprop(barHandles(barIndex), 'XEndPoints')
		continue;
	end
	barX = double(barHandles(barIndex).XEndPoints(:));
	barX = barX(isfinite(barX));
	if isempty(barX)
		continue;
	end
	distance = min(abs(barX - x));
	if distance < bestDistance
		bestDistance = distance;
		groupIndex = barIndex;
	end
end
groupIndex = min(groupIndex, nGroup);
end

function iRetunePValueLines(optional)
if ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
if ~all(ismember({'PLine','PText'}, optional.MultiCompare.Properties.VariableNames))
	return;
end
MATLAB.Graphics.PLineRetune(optional.MultiCompare.PLine, optional.MultiCompare.PText);
for pLine = optional.MultiCompare.PLine(:)'
	if isgraphics(pLine)
		pLine.LineWidth = 1;
		pLine.Tag = 'PLine';
	end
end
for pText = optional.MultiCompare.PText(:)'
	if isgraphics(pText)
		pText.Tag = 'PText';
	end
end
end

function iSetFigureTextFontSize(anchorObject, fontSize)
fig = ancestor(anchorObject, 'figure');
set(findall(fig, 'Type', 'axes'), 'FontSize', fontSize);
set(findall(fig, 'Type', 'legend'), 'FontSize', fontSize);
set(findall(fig, 'Type', 'text'), 'FontSize', fontSize);
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