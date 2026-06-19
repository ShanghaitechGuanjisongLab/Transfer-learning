% Chinese Fig44C: initial vs continual LightWater 1 s z-score and active fraction.

Data = TransferLearning.PrepareFig44CEData();
barColors = Data.GroupColors;
compareGroup = Data.CompareGroup;

f = figure('Color', 'w', 'Name', 'Chinese Fig44C Initial/Continual LightWater 1s bars');
f.Units = 'centimeters';
f.Position(3:4) = [4, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4, 8];
f.PaperSize = [4, 8];

layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');

axZ = nexttile(layout, 1);
[~, optZ, barsZ, errZ] = UniExp.BarScatterCompare({double(Data.VInitial(:)), double(Data.VTransfer(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optZ);
iStyleBarPanel(axZ, optZ, barsZ, errZ, barColors, 'z-score', '1 s z-score');
[pTop, tTop] = iExtractFirstPValueAndText(optZ);

axActive = nexttile(layout, 2);
[~, optActive, barsActive, errActive] = UniExp.BarScatterCompare({double(Data.ActiveNaive(:)), double(Data.ActiveContinual(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optActive);
iStyleBarPanel(axActive, optActive, barsActive, errActive, barColors, 'Active fraction', 'Active fraction');
ylim(axActive, [0, max(0.1, axActive.YLim(2))]);
[pBottom, tBottom] = iExtractFirstPValueAndText(optActive);

for axItem = [axZ, axActive]
	if isprop(axItem, 'Toolbar') && ~isempty(axItem.Toolbar)
		axItem.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig44C_InitialTransferLight_1s_BarScatter.svg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== Fig44C initial/continual LightWater bars ===\n');
fprintf('Naive 1s z-score: %d mice, %d cells\n', Data.InitialStats.MouseCount, Data.InitialStats.CellCount);
fprintf('Continual 1s z-score: %d mice, %d cells\n', Data.TransferStats.MouseCount, Data.TransferStats.CellCount);
fprintf('Top (1 s z-score): BarScatterCompare PValue=%.6g, PText="%s"\n', pTop, tTop);
fprintf('Bottom (active fraction): BarScatterCompare PValue=%.6g, PText="%s"\n', pBottom, tBottom);

assignin('base', 'Fig44C_NTATS1s', struct('Initial', Data.VInitial, 'Continual', Data.VTransfer, ...
	'XsSec', Data.XsSec, 'ActiveNaive', Data.ActiveNaive, 'ActiveContinual', Data.ActiveContinual, ...
	'PTop', pTop, 'PBottom', pBottom, 'PTextTop', tTop, 'PTextBottom', tBottom, ...
	'InitialStats', Data.InitialStats, 'ContinualStats', Data.TransferStats));

function iStyleBarPanel(ax, optional, bars, errorBars, colors, yLabelText, titleText)
iTagPValueObjects(optional);
delete(findobj(ax, 'Type', 'Scatter'));
iStyleAxes(ax, yLabelText, titleText);
iStyleBars(bars, colors(1, :), colors(2, :));
iStyleErrorBars(errorBars, colors);
end

function iStyleAxes(ax, yLabelText, titleText)
ax.FontName = 'Arial';
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ax.XAxis.Visible = 'on';
ax.XTick = [1 2];
ax.XTickLabel = {'Naive', 'Continual'};
legend(ax, 'off');
ylabel(ax, yLabelText, 'FontName', 'Arial', 'FontSize', 6);
title(ax, titleText, 'FontName', 'Arial', 'FontSize', 6, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
for textItem = findobj(ax, 'Type', 'Text')'
	textItem.FontName = 'Arial';
	textItem.FontSize = 6;
end
end

function iStyleBars(bars, colorA, colorB)
if isscalar(bars)
	bars.FaceColor = 'flat';
	nBar = numel(bars.YData);
	bars.CData = repmat([colorA; colorB], ceil(nBar / 2), 1);
	bars.CData = bars.CData(1:nBar, :);
	bars.BarWidth = 0.5;
	bars.LineWidth = 1;
	bars.BaseLine.Visible = 'off';
	bars.EdgeColor = 'none';
	bars.FaceAlpha = 1;
	return;
end
if numel(bars) >= 2
	bars(1).FaceColor = colorA;
	bars(2).FaceColor = colorB;
	bars(1).BarWidth = 0.5;
	bars(2).BarWidth = 0.5;
	bars(1).FaceAlpha = 1;
	bars(2).FaceAlpha = 1;
	bars(1).LineWidth = 1;
	bars(2).LineWidth = 1;
	bars(1).BaseLine.Visible = 'off';
	bars(2).BaseLine.Visible = 'off';
	bars(1).EdgeColor = 'none';
	bars(2).EdgeColor = 'none';
end
end

function iStyleErrorBars(errorBars, colors)
for iE = 1:height(errorBars)
	errorBar = errorBars.Object(iE);
	errorBar.LineWidth = 1;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
	if isprop(errorBar, 'LineStyle')
		errorBar.LineStyle = 'none';
	end
	if isprop(errorBar, 'CapSize')
		errorBar.CapSize = 7;
	end
end
end

function [pValue, pText] = iExtractFirstPValueAndText(options)
pValue = NaN;
pText = "";
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PValue', options.MultiCompare.Properties.VariableNames) && ~isempty(options.MultiCompare.PValue)
	pValue = options.MultiCompare.PValue(1);
	if ismember('PText', options.MultiCompare.Properties.VariableNames) && ~isempty(options.MultiCompare.PText)
		pTextObj = options.MultiCompare.PText(1);
		if isgraphics(pTextObj) && isprop(pTextObj, 'String')
			pText = string(pTextObj.String);
		end
	end
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
			pLine.LineWidth = 1;
		end
	end
end
if ismember('PText', multiCompare.Properties.VariableNames)
	for pText = multiCompare.PText(:)'
		if isgraphics(pText)
			pText.Tag = 'PText';
			pText.FontName = 'Arial';
			pText.FontSize = 6;
		end
	end
end
end
