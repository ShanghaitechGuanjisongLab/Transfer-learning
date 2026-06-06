function [fig, SummaryTable] = PlotPreFormalConnectionWeightStdBars(WeightValues)
arguments
	WeightValues (1, 1) struct
end

classNames = ["EE", "EI", "IE", "II"];
classLabels = ["E→E", "E→I", "I→E", "I→I"];
heterogeneityNames = ["L23E", "L23I", "L5E", "L5I"];
heterogeneityLabels = ["L2/3 E", "L2/3 I", "L5 E", "L5 I"];
groupFields = ["Naive", "AfterPretrain"];
topGroupLabels = ["Naive", "After pretrain"];
bottomGroupLabels = ["Naive", "Continual"];
topGroupColors = TransferLearning.GroupColors(["Naive", "Learned"]);
bottomGroupColors = TransferLearning.GroupColors(["Naive", "Continual"]);

[weightData, weightMeanMat, weightSemMat, weightNMat] = iBuildMetricDataTable(WeightValues.MouseStd, classNames, classLabels, groupFields, topGroupLabels, ["ConnectionType", "Group"]);
[heterogeneityData, heterogeneityMeanMat, heterogeneitySemMat, heterogeneityNMat] = iBuildMetricDataTable(WeightValues.Heterogeneity, heterogeneityNames, heterogeneityLabels, groupFields, bottomGroupLabels, ["CellType", "Group"]);

fig = figure('Color', 'w', 'Name', 'Fig54B pre-formal connection weight SD and learning-process heterogeneity bars');
fig.Units = 'centimeters';
fig.Position(3:4) = [12, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 12, 8];
fig.PaperSize = [12, 8];

tileLayout = tiledlayout(fig, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
topAx = nexttile(tileLayout, 1);
[~, topOptional] = iPlotGroupedBars(topAx, weightData, iWithinItemCompareGroup(classLabels, topGroupLabels, weightData.Properties.DimensionNames), topGroupLabels, topGroupColors, 'Connection type', 'Weight SD');

bottomAx = nexttile(tileLayout, 2);
[~, bottomOptional] = iPlotGroupedBars(bottomAx, heterogeneityData, iWithinItemCompareGroup(heterogeneityLabels, bottomGroupLabels, heterogeneityData.Properties.DimensionNames), bottomGroupLabels, bottomGroupColors, 'Layer and cell type', 'Heterogeneity');
iSetFigureTextFontSize(fig, 12);
iRetunePValueLines(topOptional);
iRetunePValueLines(bottomOptional);

weightSummary = iSummaryTable("ConnectionWeightSD", classNames, topGroupLabels, weightMeanMat, weightSemMat, weightNMat);
heterogeneitySummary = iSummaryTable("ProcessHeterogeneity", heterogeneityNames, bottomGroupLabels, heterogeneityMeanMat, heterogeneitySemMat, heterogeneityNMat);
SummaryTable = [weightSummary; heterogeneitySummary];
end

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

function [barHandles, optional] = iPlotGroupedBars(ax, dataTable, compareGroup, groupLabels, groupColors, xLabelText, yLabelText)
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, UniExp.Flags.empty, compareGroup, iColorTable(groupLabels, groupColors), ax, 'AsteriskThreshold', 0.05);
for barHandle = barHandles(:)'
	barHandle.BarWidth = 0.5;
	barHandle.LineWidth = 1;
	barHandle.EdgeColor = 'none';
	barHandle.LineStyle = 'none';
	barHandle.DisplayName = groupLabels(find(barHandles == barHandle, 1, 'first'));
	if isprop(barHandle, 'FaceAlpha')
		barHandle.FaceAlpha = 1;
	end
	if isprop(barHandle, 'BaseLine') && isgraphics(barHandle.BaseLine)
		barHandle.BaseLine.Visible = 'off';
	end
end
for errorBar = findobj(ax, 'Type', 'ErrorBar')'
	errorBar.LineWidth = 1;
	errorBar.Color = [0, 0, 0];
	errorBar.HandleVisibility = 'off';
	setappdata(errorBar, 'TransferLearningPreserveLineWidth', true);
end

ax.XLim = [0.5, height(dataTable) + 0.5];
ax.XTickLabelRotation = 0;
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
box(ax, 'off');
grid(ax, 'off');
legendHandle = optional.Legend;
legendHandle.String = cellstr(groupLabels);
legendHandle.Location = 'eastoutside';
legendHandle.Orientation = 'vertical';
legendHandle.Box = 'off';
legendHandle.FontSize = 12;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
if ~isempty(errorBars)
	for rowIndex = 1:height(errorBars)
		if isgraphics(errorBars.Object(rowIndex))
			errorBars.Object(rowIndex).LineWidth = 1;
			setappdata(errorBars.Object(rowIndex), 'TransferLearningPreserveLineWidth', true);
		end
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
colors{'ErrorBar', {'R','G','B'}} = [0, 0, 0];
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