function [fig, SummaryTable] = PlotPreFormalConnectionWeightStdBars(WeightValues, Cond)
arguments
	WeightValues (1, 1) struct
	Cond table
end

classNames = ["EE", "EI", "IE", "II"];
classLabels = ["E→E", "E→I", "I→E", "I→I"];
groupFields = ["Naive", "AfterPretrain"];
groupConditionNames = ["Naive", "Transfer"];
groupLabels = ["Naive", "After pretrain"];

meanMat = nan(numel(classNames), numel(groupFields));
semMat = nan(numel(classNames), numel(groupFields));
nMat = nan(numel(classNames), numel(groupFields));
pValues = nan(numel(classNames), 1);
for classIndex = 1:numel(classNames)
	className = classNames(classIndex);
	for groupIndex = 1:numel(groupFields)
		values = WeightValues.MouseStd.(groupFields(groupIndex)).(className);
		[meanMat(classIndex, groupIndex), semMat(classIndex, groupIndex), nMat(classIndex, groupIndex)] = iMeanSemFinite(values);
	end
	pValues(classIndex) = iWeightStdPValue(WeightValues.MouseStd.Naive.(className), WeightValues.MouseStd.AfterPretrain.(className));
end

fig = figure('Color', 'w', 'Name', 'Fig382C pre-formal connection weight SD bars');
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 9, 8];
fig.PaperSize = [9, 8];

ax = axes(fig);
hold(ax, 'on');
barHandles = bar(ax, meanMat, 'grouped', 'LineStyle', 'none');
errorbarHandles = gobjects(numel(groupFields), 1);
for groupIndex = 1:numel(groupFields)
	color = iConditionColor(Cond, groupConditionNames(groupIndex));
	barHandles(groupIndex).FaceColor = color;
	barHandles(groupIndex).EdgeColor = 'none';
	barHandles(groupIndex).LineStyle = 'none';
	xBar = barHandles(groupIndex).XEndPoints;
	yBar = barHandles(groupIndex).YEndPoints;
	upperError = semMat(:, groupIndex)';
	errorbarHandles(groupIndex) = errorbar(ax, xBar, yBar, zeros(size(upperError)), upperError, ...
		'LineStyle', 'none', ...
		'Color', color, ...
		'LineWidth', 1, ...
		'CapSize', 6);
end

ax.XLim = [0.5, numel(classNames) + 0.5];
ax.XTick = 1:numel(classNames);
ax.XTickLabel = cellstr(classLabels);
ax.XTickLabelRotation = 0;
yTop = max(meanMat + semMat, [], 'all', 'omitnan');
if ~(isfinite(yTop) && yTop > 0)
	yTop = 1;
end
ylim(ax, [0, yTop * 1.45]);
xlabel(ax, 'Connection type');
title(ax, 'Weight SD');
box(ax, 'off');
grid(ax, 'off');
iDrawPValueLines(errorbarHandles, pValues);
legend(ax, barHandles, cellstr(groupLabels), 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');

SummaryTable = iSummaryTable(classNames, groupLabels, meanMat, semMat, nMat);
end

function iDrawPValueLines(errorbarHandles, pValues)
comparisonCount = numel(pValues);
objectA = repmat(errorbarHandles(1), comparisonCount, 1);
objectB = repmat(errorbarHandles(2), comparisonCount, 1);
indexA = (1:comparisonCount)';
indexB = indexA;
pText = strings(comparisonCount, 1);
for comparisonIndex = 1:comparisonCount
	pText(comparisonIndex) = iFormatPValue(pValues(comparisonIndex));
end
extraOffset = zeros(comparisonCount, 1);
descriptors = table(objectA, objectB, indexA, indexB, pText, extraOffset, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
MATLAB.Graphics.PLine(descriptors);
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

function pValue = iWeightStdPValue(valuesA, valuesB)
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
	textValue = sprintf("p=%.3f", pValue);
end
end

function SummaryTable = iSummaryTable(classNames, groupLabels, meanMat, semMat, nMat)
nRows = numel(classNames) * numel(groupLabels);
connectionType = strings(nRows, 1);
group = strings(nRows, 1);
meanMouseWeightSD = nan(nRows, 1);
semMouseWeightSD = nan(nRows, 1);
nMice = nan(nRows, 1);
rowIndex = 0;
for classIndex = 1:numel(classNames)
	for groupIndex = 1:numel(groupLabels)
		rowIndex = rowIndex + 1;
		connectionType(rowIndex) = classNames(classIndex);
		group(rowIndex) = groupLabels(groupIndex);
		meanMouseWeightSD(rowIndex) = meanMat(classIndex, groupIndex);
		semMouseWeightSD(rowIndex) = semMat(classIndex, groupIndex);
		nMice(rowIndex) = nMat(classIndex, groupIndex);
	end
end
SummaryTable = table(connectionType, group, meanMouseWeightSD, semMouseWeightSD, nMice, ...
	'VariableNames', {'ConnectionType','Group','MeanMouseWeightSD','SemMouseWeightSD','NMice'});
end