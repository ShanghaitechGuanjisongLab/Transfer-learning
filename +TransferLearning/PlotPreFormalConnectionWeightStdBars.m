function [fig, SummaryTable] = PlotPreFormalConnectionWeightStdBars(WeightValues)
arguments
	WeightValues (1, 1) struct
end

classNames = ["EE", "EI", "IE", "II"];
classLabels = ["E→E", "E→I", "I→E", "I→I"];
heterogeneityNames = ["L23E", "L23I", "L5E", "L5I"];
heterogeneityLabels = ["L2/3 E", "L2/3 I", "L5 E", "L5 I"];
groupFields = ["Naive", "AfterPretrain"];
topGroupLabels = ["Naive", "CueA learned"];
bottomGroupLabels = ["Naive", "Transfer"];
topGroupColors = [TransferLearning.NaiveColor;TransferLearning.LearnedColor];
bottomGroupColors = [TransferLearning.NaiveColor;TransferLearning.TransferColor];

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
	if isfield(bottomOptional, 'Legend') && isgraphics(bottomOptional.Legend)
		bottomOptional.Legend.Title.String = 'Cue B';
		bottomOptional.Legend.Title.FontWeight = 'normal';
	end
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
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, iColorTable(groupLabels, groupColors), ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
for iBar = 1:numel(barHandles)
	barHandles(iBar).LineStyle = 'none';
	barHandles(iBar).FaceColor = groupColors(iBar, :);
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
	bestDist = inf;
	bestColor = groupColors(1, :);
	for iBar2 = 1:numel(barHandles)
		xp = double(barHandles(iBar2).XEndPoints(:));
		d = min(abs(xp - x));
		if d < bestDist
			bestDist = d;
			bestColor = barHandles(iBar2).FaceColor;
		end
	end
	errorBar.Color = bestColor;
end

xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
box(ax, 'off');
grid(ax, 'off');
legendHandle = optional.Legend;
legendHandle.String = cellstr(groupLabels);
legendHandle.Location = 'eastoutside';
legendHandle.Box = 'off';
legendHandle.FontSize = 12;
iRecalcErrorBarCapSize(ax, barHandles, errorBars, 0.5);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

end

function iRecalcErrorBarCapSize(ax, barHandles, errorBars, capSizeRatio)
% Recompute CapSize using the same formula as BarScatterCompare
% CapSize = Ax.Position(3) * BarWidth * GroupWidth * capSizeRatio / (diff(xlim) * numel(Bars))
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