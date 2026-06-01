function [f, summaryTbl] = PlotMetricsCombinedByLayer(Data, metricFields, panelLabels, yLabelTexts, figName, svgName)
arguments
	Data struct
	metricFields (:,1) string
	panelLabels (:,1) string
	yLabelTexts (:,1) string
	figName (1,1) string
	svgName (1,1) string
end

if numel(metricFields) ~= numel(panelLabels) || numel(metricFields) ~= numel(yLabelTexts)
	error('Fig51:MetricSpecSizeMismatch', 'Metric, panel, and ylabel arrays must have the same length.');
end

groupColors = TransferLearning.GroupColors(["Naive", "Continual"]);
layerNames = ["MOp2/3", "MOp5"];
layerLabels = ["MOp2/3", "MOp5"];
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color', 'w', 'Name', char(figName));
f.Units = 'centimeters';
f.Position(3:4) = [8, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 8, 4];
f.PaperSize = [8, 4];

layout = tiledlayout(f, 2, numel(metricFields) * 2, 'TileSpacing', 'tight', 'Padding', 'tight');
summaryTbl = table();

for layerIndex = 1:numel(layerNames)
	for metricIndex = 1:numel(metricFields)
		metricField = metricFields(metricIndex);
		[dataCell, metricSummary] = iMetricDataForLayer(Data, metricField, layerNames(layerIndex));
		tileIndex = (layerIndex - 1) * numel(metricFields) * 2 + (metricIndex - 1) * 2 + 1;
		ax = nexttile(layout, tileIndex, [1 2]);
		[~, optional, bars, errorBars] = UniExp.BarScatterCompare(dataCell, UniExp.Flags.empty, compareGroup, ...
			UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
		iTagPValueObjects(optional);
		iStyleBars(bars, groupColors);
		iStyleErrorBars(errorBars, groupColors);
		titleText = sprintf('%s %s', char(panelLabels(metricIndex)), char(layerLabels(layerIndex)));
		iStyleAxes(ax, yLabelTexts(metricIndex), titleText, layerIndex == 1 && metricIndex == 1, layerIndex == numel(layerNames));
		metricSummary.Panel = repmat(panelLabels(metricIndex), height(metricSummary), 1);
		metricSummary.Metric = repmat(metricField, height(metricSummary), 1);
		summaryTbl = [summaryTbl; metricSummary]; %#ok<AGROW>
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);
end

function [dataCell, summaryTbl] = iMetricDataForLayer(Data, metricField, layerName)
M = Data.Metrics(Data.Metrics.ZLayer == layerName, :);
naiveVals = double(M.(metricField)(M.Group == "Naive"));
continualVals = double(M.(metricField)(M.Group == "Continual"));
naiveVals = naiveVals(isfinite(naiveVals));
continualVals = continualVals(isfinite(continualVals));
if isempty(naiveVals) || isempty(continualVals)
	error('Fig51:EmptyMetricLayer', 'Metric %s for %s is empty.', char(metricField), char(layerName));
end
dataCell = {naiveVals, continualVals};
pValue = ranksum(naiveVals, continualVals);
summaryTbl = table(layerName, mean(naiveVals), mean(continualVals), numel(naiveVals), numel(continualVals), pValue, ...
	'VariableNames', {'ZLayer', 'NaiveMean', 'ContinualMean', 'NaiveN', 'ContinualN', 'PValue'});
end

function iStyleAxes(ax, yLabelText, panelLabel, showLegend, showXLabels)
hold(ax, 'on');
ax.FontName = 'Arial';
ax.FontSize = 6;
ax.LineWidth = 1;
ax.TickDir = 'out';
ax.XLim = [0.5, 2.5];
ax.XTick = [1, 2];
if showXLabels
	ax.XTickLabel = {'Naive', 'Continual'};
else
	ax.XTickLabel = {'', ''};
end
ylabel(ax, yLabelText, 'FontSize', 6);
title(ax, panelLabel, 'FontSize', 6, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
if showLegend
	hNaive = plot(ax, nan, nan, 's', 'MarkerFaceColor', TransferLearning.NaiveColor, 'MarkerEdgeColor', 'none', 'DisplayName', 'Naive');
	hContinual = plot(ax, nan, nan, 's', 'MarkerFaceColor', TransferLearning.ContinualColor, 'MarkerEdgeColor', 'none', 'DisplayName', 'Continual');
	legend(ax, [hNaive, hContinual], {'Naive', 'Continual'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 6);
end
end

function iStyleBars(bars, colors)
if isscalar(bars)
	bars.FaceColor = 'flat';
	nBar = numel(bars.YData);
	bars.CData = colors(1:nBar, :);
	bars.BarWidth = 0.5;
	bars.LineWidth = 1;
	bars.EdgeColor = 'none';
	bars.BaseLine.Visible = 'off';
	if isprop(bars, 'FaceAlpha')
		bars.FaceAlpha = 1;
	end
	return;
end
for barIndex = 1:min(numel(bars), size(colors, 1))
	bars(barIndex).FaceColor = colors(barIndex, :);
	bars(barIndex).BarWidth = 0.5;
	bars(barIndex).LineWidth = 1;
	bars(barIndex).EdgeColor = 'none';
	bars(barIndex).BaseLine.Visible = 'off';
	if isprop(bars(barIndex), 'FaceAlpha')
		bars(barIndex).FaceAlpha = 1;
	end
end
end

function iStyleErrorBars(errorBars, colors)
for errorIndex = 1:height(errorBars)
	errorBar = errorBars.Object(errorIndex);
	if ~isgraphics(errorBar)
		continue;
	end
	errorBar.YNegativeDelta = zeros(size(errorBar.YPositiveDelta));
	errorBar.LineWidth = 1;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
	errorBar.HandleVisibility = 'off';
end
end

function iTagPValueObjects(optional)
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
multiCompare = optional.MultiCompare;
if ismember('PLine', multiCompare.Properties.VariableNames)
	for pLine = multiCompare.PLine(:)'
		if isgraphics(pLine)
			pLine.Tag = 'PLine';
		end
	end
end
if ismember('PText', multiCompare.Properties.VariableNames)
	for pText = multiCompare.PText(:)'
		if isgraphics(pText)
			pText.Tag = 'PText';
		end
	end
end
end