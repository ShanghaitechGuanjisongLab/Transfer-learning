function [f, summaryTbl] = PlotMetricByLayer(Data, metricField, figName, yLabelText, svgName)
arguments
	Data struct
	metricField (1,1) string
	figName (1,1) string
	yLabelText (1,1) string
	svgName (1,1) string
end

palette2 = TransferLearning.FigurePalette(2);
colorNaive = palette2(1, :);
colorTransfer = palette2(2, :);

f = figure('Color', 'w', 'Name', char(figName));
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
summaryTbl = table();
axList = gobjects(2, 1);
pLineAll = gobjects(0, 1);
pTextAll = gobjects(0, 1);

for iLayer = 1:2
	if iLayer == 1
		zLayer = "MOp2/3";
	else
		zLayer = "MOp5";
	end
	M = Data.Metrics(Data.Metrics.ZLayer == zLayer, :);
	naiveVals = double(M.(metricField)(M.Group == "Naive"));
	tranVals = double(M.(metricField)(M.Group == "Transfer"));
	naiveVals = naiveVals(isfinite(naiveVals));
	tranVals = tranVals(isfinite(tranVals));
	if isempty(naiveVals) || isempty(tranVals)
		error('Fig341:EmptyMetricLayer', 'Metric %s for %s is empty.', char(metricField), char(zLayer));
	end

	ax = nexttile(Layout, iLayer);
	axList(iLayer) = ax;
	[~, optional, Bars, ErrorBars] = UniExp.BarScatterCompare({naiveVals, tranVals}, false, table([1 2], 'VariableNames', {'GroupPair'}));
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
	ax.XTickLabel = {'Naive', 'Transfer'};
	if iLayer == 1
		title(ax, 'MOp2/3', 'FontSize', 6, 'FontWeight', 'normal');
		ax.XAxis.Visible = 'off';
	else
		title(ax, 'MOp5', 'FontSize', 6, 'FontWeight', 'normal');
		ax.XAxis.Visible = 'on';
	end
	xlabel(ax, '');
	for pt = iFindPText(optional)'
		pt.FontSize = 6;
	end
	[pLineAll, pTextAll] = iAppendPLineHandles(optional, pLineAll, pTextAll);
	iStyleBars(Bars, colorNaive, colorTransfer);
	iKeepUpperErrorBarOnly(ax, ErrorBars, Bars, colorNaive, colorTransfer);

	row = table(zLayer, mean(naiveVals), mean(tranVals), numel(naiveVals), numel(tranVals), ...
		'VariableNames', {'ZLayer', 'NaiveMean', 'TransferMean', 'NaiveN', 'TransferN'});
	summaryTbl = [summaryTbl; row]; %#ok<AGROW>
	end

ylabel(Layout, yLabelText, 'FontSize', 6);
MATLAB.Graphics.UnifyAxesLims(axList, @ylim);
if ~isempty(pLineAll) || ~isempty(pTextAll)
	MATLAB.Graphics.PLineRetune(pLineAll, pTextAll);
end

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, char(svgName));
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
end

function pText = iFindPText(optional)
pText = gobjects(0, 1);
if isstruct(optional) && isfield(optional, 'MultiCompare') && istable(optional.MultiCompare) && ismember('PText', optional.MultiCompare.Properties.VariableNames)
	pText = optional.MultiCompare.PText;
end
end

function iStyleBars(Bars, colorNaive, colorTransfer)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nBar = numel(Bars.YData);
	Bars.CData = repmat([colorNaive; colorTransfer], ceil(nBar / 2), 1);
	Bars.CData = Bars.CData(1:nBar, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	try
		Bars.FaceAlpha = 1/3;
	catch
	end
else
	if numel(Bars) >= 2
		Bars(1).FaceColor = colorNaive;
		Bars(2).FaceColor = colorTransfer;
		Bars(1).LineWidth = 1;
		Bars(2).LineWidth = 1;
		try
			Bars(1).FaceAlpha = 1/3;
			Bars(2).FaceAlpha = 1/3;
		catch
		end
	end
	end
end

function iKeepUpperErrorBarOnly(~, errorBars, ~, ~, ~)
% Directly modify original ErrorBar object: upper-only, set line width
for eb = errorBars.Object(:)'
	if ~isgraphics(eb)
		continue;
	end
	eb.YNegativeDelta = zeros(size(eb.YPositiveDelta));
	eb.LineWidth = 1;
	eb.Color = 'k';
	eb.HandleVisibility = 'off';
end
end

function [pLineAll, pTextAll] = iAppendPLineHandles(optional, pLineAll, pTextAll)
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
mc = optional.MultiCompare;
if ismember('PLine', mc.Properties.VariableNames)
	pLine = mc.PLine;
	pLine = pLine(isgraphics(pLine));
	if ~isempty(pLine)
		pLineAll(end+1:end+numel(pLine), 1) = pLine(:); %#ok<AGROW>
	end
end
if ismember('PText', mc.Properties.VariableNames)
	pText = mc.PText;
	pText = pText(isgraphics(pText));
	if ~isempty(pText)
		pTextAll(end+1:end+numel(pText), 1) = pText(:); %#ok<AGROW>
	end
end
end