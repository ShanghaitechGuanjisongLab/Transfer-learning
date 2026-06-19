% Chinese Fig44E: initial vs continual LightWater divergence by layer.

Data = TransferLearning.PrepareFig44CEData();
barColors = Data.GroupColors;
compareGroup = Data.CompareGroup;

f = figure('Color', 'w', 'Name', 'Chinese Fig44E Initial/Continual LightWater divergence');
f.Units = 'centimeters';
f.Position(3:4) = [4, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4, 8];
f.PaperSize = [4, 8];

layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');

axL23 = nexttile(layout, 1);
[~, optL23, barsL23, errL23] = UniExp.BarScatterCompare({double(Data.NaiveL23(:)), double(Data.ContinualL23(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optL23);
iStyleBarPanel(axL23, optL23, barsL23, errL23, barColors, 'Divergence', 'Layer 2/3');
[pTop, tTop] = iExtractFirstPValueAndText(optL23);

axL5 = nexttile(layout, 2);
[~, optL5, barsL5, errL5] = UniExp.BarScatterCompare({double(Data.NaiveL5(:)), double(Data.ContinualL5(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optL5);
iStyleBarPanel(axL5, optL5, barsL5, errL5, barColors, 'Divergence', 'Layer 5');
[pBottom, tBottom] = iExtractFirstPValueAndText(optL5);

for axItem = [axL23, axL5]
	if isprop(axItem, 'Toolbar') && ~isempty(axItem.Toolbar)
		axItem.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig44E_InitialTransferLight_DivByLayer.svg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== Fig44E initial/continual LightWater divergence ===\n');
fprintf('Top (Layer 2/3 divergence): Naive %d mice, %d cells; Continual %d mice, %d cells; BarScatterCompare PValue=%.6g, PText="%s"\n', ...
	nnz(Data.MaskNaiveL23), Data.NCellNaiveL23, nnz(Data.MaskContinualL23), Data.NCellContinualL23, pTop, tTop);
fprintf('Bottom (Layer 5 divergence): Naive %d mice, %d cells; Continual %d mice, %d cells; BarScatterCompare PValue=%.6g, PText="%s"\n', ...
	nnz(Data.MaskNaiveL5), Data.NCellNaiveL5, nnz(Data.MaskContinualL5), Data.NCellContinualL5, pBottom, tBottom);

assignin('base', 'Fig44E_DivergenceTable', Data.DivergenceTable);
assignin('base', 'Fig44E_DivergenceSummary', Data.DivergenceSummary);
assignin('base', 'Fig44E_PTop', pTop);
assignin('base', 'Fig44E_PBottom', pBottom);
assignin('base', 'Fig44E_PTextTop', tTop);
assignin('base', 'Fig44E_PTextBottom', tBottom);

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
