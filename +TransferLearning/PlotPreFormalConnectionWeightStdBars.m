function [fig, SummaryTable] = PlotPreFormalConnectionWeightStdBars(WeightValues, Cond)
arguments
	WeightValues (1, 1) struct
	Cond table
end

classNames = ["EE", "EI", "IE", "II"];
classLabels = ["E→E", "E→I", "I→E", "I→I"];
heterogeneityNames = ["L23E", "L23I", "L5E", "L5I"];
heterogeneityLabels = ["L2/3 E", "L2/3 I", "L5 E", "L5 I"];
groupFields = ["Naive", "AfterPretrain"];
groupConditionNames = ["Naive", "Transfer"];
topGroupLabels = ["Naive", "After pretrain"];
bottomGroupLabels = ["Naive", "Continual"];

[weightMeanMat, weightSemMat, weightNMat, weightPValues] = iBuildMetricMatrices(WeightValues.MouseStd, classNames, groupFields);
[heterogeneityMeanMat, heterogeneitySemMat, heterogeneityNMat, heterogeneityPValues] = iBuildMetricMatrices(WeightValues.Heterogeneity, heterogeneityNames, groupFields);

fig = figure('Color', 'w', 'Name', 'Fig382B pre-formal connection weight SD and learning-process heterogeneity bars');
fig.Units = 'centimeters';
fig.Position(3:4) = [12, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 12, 8];
fig.PaperSize = [12, 8];

tileLayout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
topAx = nexttile(tileLayout, 1);
topBars = iPlotGroupedBars(topAx, weightMeanMat, weightSemMat, weightPValues, classLabels, groupFields, topGroupLabels, groupConditionNames, Cond, 'Connection type', 'Weight SD');
legend(topAx, topBars, cellstr(topGroupLabels), 'Location', 'eastoutside', 'Orientation', 'vertical', 'Box', 'off', 'FontSize', 12);

bottomAx = nexttile(tileLayout, 2);
bottomBars = iPlotGroupedBars(bottomAx, heterogeneityMeanMat, heterogeneitySemMat, heterogeneityPValues, heterogeneityLabels, groupFields, bottomGroupLabels, groupConditionNames, Cond, 'Layer and cell type', 'Heterogeneity');
legend(bottomAx, bottomBars, cellstr(bottomGroupLabels), 'Location', 'eastoutside', 'Orientation', 'vertical', 'Box', 'off', 'FontSize', 12);

weightSummary = iSummaryTable("ConnectionWeightSD", classNames, topGroupLabels, weightMeanMat, weightSemMat, weightNMat);
heterogeneitySummary = iSummaryTable("ProcessHeterogeneity", heterogeneityNames, bottomGroupLabels, heterogeneityMeanMat, heterogeneitySemMat, heterogeneityNMat);
SummaryTable = [weightSummary; heterogeneitySummary];
end

function [meanMat, semMat, nMat, pValues] = iBuildMetricMatrices(MetricValues, itemNames, groupFields)
meanMat = nan(numel(itemNames), numel(groupFields));
semMat = nan(numel(itemNames), numel(groupFields));
nMat = nan(numel(itemNames), numel(groupFields));
pValues = nan(numel(itemNames), 1);
for itemIndex = 1:numel(itemNames)
	itemName = itemNames(itemIndex);
	for groupIndex = 1:numel(groupFields)
		values = MetricValues.(groupFields(groupIndex)).(itemName);
		[meanMat(itemIndex, groupIndex), semMat(itemIndex, groupIndex), nMat(itemIndex, groupIndex)] = iMeanSemFinite(values);
	end
	pValues(itemIndex) = iRanksumFinite(MetricValues.(groupFields(1)).(itemName), MetricValues.(groupFields(2)).(itemName));
end
end

function barHandles = iPlotGroupedBars(ax, meanMat, semMat, pValues, itemLabels, groupFields, groupLabels, groupConditionNames, Cond, xLabelText, yLabelText)
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
	errorbarHandles(groupIndex) = errorbar(ax, xBar, yBar, zeros(size(upperError)), upperError, ...
		'LineStyle', 'none', ...
		'Color', color, ...
		'LineWidth', 1, ...
		'CapSize', 6);
end

ax.XLim = [0.5, numel(itemLabels) + 0.5];
ax.XTick = 1:numel(itemLabels);
ax.XTickLabel = cellstr(itemLabels);
ax.XTickLabelRotation = 0;
yTop = max(meanMat + semMat, [], 'all', 'omitnan');
if ~(isfinite(yTop) && yTop > 0)
	yTop = 1;
end
ylim(ax, [0, yTop * 1.45]);
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
box(ax, 'off');
grid(ax, 'off');
iDrawPValueLines(ax, errorbarHandles, pValues);
end

function iDrawPValueLines(ax, errorbarHandles, pValues)
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
iSetFigureTextFontSize(ax, 12);
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