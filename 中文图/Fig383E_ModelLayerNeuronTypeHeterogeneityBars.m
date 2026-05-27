% Fig383E model learning-process heterogeneity by layer and neuron type.

svgName = '中文图Fig383E_ModelLayerNeuronTypeHeterogeneityBars.svg';
iEnsureTransferLearningProject();

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
Cond = Fig382383Data.Cond;
RunInfo = Fig382383Data.RunInfo;
Heterogeneity.Continual = Fig382383Data.Heterogeneity.Transfer;
Heterogeneity.THInhibited = Fig382383Data.Heterogeneity.THOff;
%%

[fig, SummaryTable] = iPlotLayerNeuronTypeHeterogeneityBars(Heterogeneity, Cond);
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig383E_ModelLayerNeuronTypeHeterogeneity', Heterogeneity);
assignin('base', 'Fig383E_ModelLayerNeuronTypeRunInfo', RunInfo);
assignin('base', 'Fig383E_ModelLayerNeuronTypeSummary', SummaryTable);
assignin('base', 'Fig383E_ModelLayerNeuronTypeSvgPath', svgPath);

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

function [fig, SummaryTable] = iPlotLayerNeuronTypeHeterogeneityBars(Heterogeneity, Cond)
layerNames = ["L23", "L5"];
layerLabels = ["L2/3", "L5"];
cellTypeLabels = ["E", "I"];
groupFields = ["Continual", "THInhibited"];
groupLabels = ["Normal", "TH inhibited"];
groupConditionNames = ["Transfer", "THOff"];

fig = figure('Color', 'w', 'Name', 'Fig383E layer and neuron type heterogeneity bars');
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 9, 8];
fig.PaperSize = [9, 8];

tileLayout = tiledlayout(fig, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
summaryCells = cell(numel(layerNames), 1);
pLineCells = cell(numel(layerNames), 1);
pTextCells = cell(numel(layerNames), 1);
for layerIndex = 1:numel(layerNames)
	layerName = layerNames(layerIndex);
	ax = nexttile(tileLayout, layerIndex);
	metricNames = layerName + ["E", "I"];
	[meanMat, semMat, nMat, pValues] = iBuildMetricMatrices(Heterogeneity, metricNames, groupFields);
	[barHandles, pLineCells{layerIndex}, pTextCells{layerIndex}] = iPlotGroupedBars(ax, meanMat, semMat, pValues, cellTypeLabels, groupFields, groupLabels, groupConditionNames, Cond, layerLabels(layerIndex));
	if layerIndex == 1
		ax.XAxis.Visible = 'off';
	end
	if layerIndex == 1
		legend(ax, barHandles, cellstr(groupLabels), 'Location', 'eastoutside', 'Orientation', 'vertical', 'Box', 'off', 'FontSize', 12);
	end
	summaryCells{layerIndex} = iSummaryTable(layerLabels(layerIndex), metricNames, groupLabels, meanMat, semMat, nMat);
end
xlabel(tileLayout, 'Neuron type', 'FontSize', 12);
ylabel(tileLayout, 'Heterogeneity', 'FontSize', 12);
SummaryTable = vertcat(summaryCells{:});
iSetFigureTextFontSize(fig, 12);
for layerIndex = 1:numel(layerNames)
	iRetunePValueLines(pLineCells{layerIndex}, pTextCells{layerIndex});
end
end

function [meanMat, semMat, nMat, pValues] = iBuildMetricMatrices(Heterogeneity, metricNames, groupFields)
meanMat = nan(numel(metricNames), numel(groupFields));
semMat = nan(numel(metricNames), numel(groupFields));
nMat = nan(numel(metricNames), numel(groupFields));
pValues = nan(numel(metricNames), 1);
for metricIndex = 1:numel(metricNames)
	metricName = metricNames(metricIndex);
	for groupIndex = 1:numel(groupFields)
		values = Heterogeneity.(groupFields(groupIndex)).(metricName);
		[meanMat(metricIndex, groupIndex), semMat(metricIndex, groupIndex), nMat(metricIndex, groupIndex)] = iMeanSemFinite(values);
	end
	pValues(metricIndex) = iRanksumFinite(Heterogeneity.(groupFields(1)).(metricName), Heterogeneity.(groupFields(2)).(metricName));
end
end

function [barHandles, pLines, pTexts] = iPlotGroupedBars(ax, meanMat, semMat, pValues, itemLabels, groupFields, groupLabels, groupConditionNames, Cond, titleText)
hold(ax, 'on');
barHandles = bar(ax, meanMat, 'grouped', 'LineStyle', 'none');
errorbarHandles = gobjects(numel(groupFields), 1);
for groupIndex = 1:numel(groupFields)
	color = iConditionColor(Cond, groupConditionNames(groupIndex));
	barHandles(groupIndex).FaceColor = color;
	barHandles(groupIndex).EdgeColor = 'none';
	barHandles(groupIndex).LineStyle = 'none';
	barHandles(groupIndex).DisplayName = groupLabels(groupIndex);
	xBar = barHandles(groupIndex).XEndPoints;
	yBar = barHandles(groupIndex).YEndPoints;
	upperError = semMat(:, groupIndex)';
	upperError(~isfinite(upperError)) = 0;
	errorbarHandles(groupIndex) = errorbar(ax, xBar, yBar, [], upperError, ...
		'LineStyle', 'none', ...
		'Color', color, ...
		'LineWidth', 1, ...
		'CapSize', 6);
end

ax.XLim = [0.5, numel(itemLabels) + 0.5];
ax.XTick = 1:numel(itemLabels);
ax.XTickLabel = cellstr(itemLabels);
yTop = max(meanMat + semMat, [], 'all', 'omitnan');
if ~(isfinite(yTop) && yTop > 0)
	yTop = 1;
end
ylim(ax, [0, yTop * 1.45]);
title(ax, titleText, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 12;
[pLines, pTexts] = iDrawPValueLines(errorbarHandles, pValues);
end

function [pLines, pTexts] = iDrawPValueLines(errorbarHandles, pValues)
pLines = gobjects(0, 1);
pTexts = gobjects(0, 1);
comparisonIndexValues = find(isfinite(pValues));
comparisonCount = numel(comparisonIndexValues);
if comparisonCount == 0
	return;
end
objectA = repmat(errorbarHandles(1), comparisonCount, 1);
objectB = repmat(errorbarHandles(2), comparisonCount, 1);
indexA = comparisonIndexValues(:);
indexB = indexA;
pText = strings(comparisonCount, 1);
for rowIndex = 1:comparisonCount
	pText(rowIndex) = iFormatPValue(pValues(comparisonIndexValues(rowIndex)));
end
extraOffset = zeros(comparisonCount, 1);
descriptors = table(objectA, objectB, indexA, indexB, pText, extraOffset, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[pLines, pTexts] = MATLAB.Graphics.PLine(descriptors);
end

function iRetunePValueLines(pLines, pTexts)
if isempty(pLines)
	return;
end
MATLAB.Graphics.PLineRetune(pLines, pTexts);
end

function iSetFigureTextFontSize(anchorObject, fontSize)
fig = ancestor(anchorObject, 'figure');
set(findall(fig, 'Type', 'axes'), 'FontSize', fontSize);
set(findall(fig, 'Type', 'legend'), 'FontSize', fontSize);
set(findall(fig, 'Type', 'text'), 'FontSize', fontSize);
end

function color = iConditionColor(Cond, conditionName)
conditionIndex = find(Cond.Name == conditionName, 1, 'first');
color = Cond.Color(conditionIndex, :);
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

function pValue = iRanksumFinite(valuesA, valuesB)
valuesA = valuesA(:);
valuesB = valuesB(:);
valuesA = valuesA(isfinite(valuesA));
valuesB = valuesB(isfinite(valuesB));
if numel(valuesA) < 2 || numel(valuesB) < 2
	pValue = NaN;
	return;
end
pValue = ranksum(valuesA, valuesB);
end

function textValue = iFormatPValue(pValue)
if ~isfinite(pValue)
	textValue = "p=NaN";
	return;
end
if pValue < 0.05
	textValue = "*";
else
	textValue = "p=" + MATLAB.SignificantFixedpoint(pValue, 2);
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
