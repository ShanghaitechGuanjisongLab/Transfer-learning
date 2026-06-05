function [f, summaryTbl] = PlotMetricByLayer(Data, metricField, figName, yLabelText, svgName)
arguments
	Data struct
	metricField (1,1) string
	figName (1,1) string
	yLabelText (1,1) string
	svgName (1,1) string
end

groupColors = TransferLearning.GroupColors(["Naive", "Continual"]);
colorNaive = groupColors(1, :);
colorContinual = groupColors(2, :);

f = figure('Color', 'w', 'Name', char(figName));
f.Units = 'centimeters';
f.Position(3:4) = [4, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4, 8];
f.PaperSize = [4, 8];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
summaryTbl = table();
axList = gobjects(2, 1);

for iLayer = 1:2
	if iLayer == 1
		zLayer = "MOp2/3";
	else
		zLayer = "MOp5";
	end
	M = Data.Metrics(Data.Metrics.ZLayer == zLayer, :);
	naiveVals = double(M.(metricField)(M.Group == "Naive"));
	continualVals = double(M.(metricField)(M.Group == "Continual"));
	naiveVals = naiveVals(isfinite(naiveVals));
	continualVals = continualVals(isfinite(continualVals));
	if isempty(naiveVals) || isempty(continualVals)
		error('Fig51:EmptyMetricLayer', 'Metric %s for %s is empty.', char(metricField), char(zLayer));
	end

	ax = nexttile(Layout, iLayer);
	axList(iLayer) = ax;
	[~, optional, Bars, ErrorBars] = UniExp.BarScatterCompare({naiveVals, continualVals}, UniExp.Flags.empty, ...
		table([1 2], 'VariableNames', {'GroupPair'}), UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
	iTagPValueObjects(optional);
	ax.FontSize = 6;
	ax.LineWidth = 1;
	ax.FontName = 'Arial';
	ax.TickDir = 'out';
	box(ax, 'off');
	grid(ax, 'off');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	ax.XTick = [1 2];
	ax.XTickLabel = {'Naive', 'Continual'};
	if iLayer == 1
		title(ax, 'MOp2/3', 'FontSize', 6, 'FontWeight', 'normal');
		ax.XAxis.Visible = 'on';
		ax.XTickLabel = {'', ''};
	else
		title(ax, 'MOp5', 'FontSize', 6, 'FontWeight', 'normal');
		ax.XAxis.Visible = 'on';
	end
	xlabel(ax, '');
	for pt = iFindPText(optional)'
		pt.FontSize = 6;
	end
	iStyleBars(Bars, colorNaive, colorContinual);
	iStyleErrorBars(ErrorBars, [colorNaive; colorContinual]);

	row = table(zLayer, mean(naiveVals), mean(continualVals), numel(naiveVals), numel(continualVals), ...
		'VariableNames', {'ZLayer', 'NaiveMean', 'ContinualMean', 'NaiveN', 'ContinualN'});
	summaryTbl = [summaryTbl; row]; %#ok<AGROW>
	end

ylabel(Layout, yLabelText, 'FontSize', 6);

svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);
end

function pText = iFindPText(optional)
pText = gobjects(0, 1);
if isstruct(optional) && isfield(optional, 'MultiCompare') && istable(optional.MultiCompare) && ismember('PText', optional.MultiCompare.Properties.VariableNames)
	pText = optional.MultiCompare.PText;
end
end

function iStyleBars(Bars, colorNaive, colorContinual)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nBar = numel(Bars.YData);
	Bars.CData = repmat([colorNaive; colorContinual], ceil(nBar / 2), 1);
	Bars.CData = Bars.CData(1:nBar, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.BaseLine.Visible = 'off';
	if isprop(Bars, 'FaceAlpha')
		Bars.FaceAlpha = 1;
	end
else
	if numel(Bars) >= 2
		Bars(1).FaceColor = colorNaive;
		Bars(2).FaceColor = colorContinual;
		Bars(1).BarWidth = 0.5;
		Bars(2).BarWidth = 0.5;
		Bars(1).LineWidth = 1;
		Bars(2).LineWidth = 1;
		Bars(1).EdgeColor = 'none';
		Bars(2).EdgeColor = 'none';
		Bars(1).BaseLine.Visible = 'off';
		Bars(2).BaseLine.Visible = 'off';
		if isprop(Bars(1), 'FaceAlpha')
			Bars(1).FaceAlpha = 1;
			Bars(2).FaceAlpha = 1;
		end
	end
	end
end

function iStyleErrorBars(errorBars, colors)
for iE = 1:height(errorBars)
	errorBar = errorBars.Object(iE);
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

