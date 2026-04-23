function Fig372_PlotConvergenceVenn(Matrix, Tags, legendLabels, titleText, chanceText, figureName, figSizeCm, svgPath)
f = figure('Color', 'w', 'Name', figureName);
f.Units = 'centimeters';
f.Position(3:4) = figSizeCm;
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, figSizeCm];
f.PaperSize = figSizeCm;

ax = axes(f);
[Circles, Texts] = MATLAB.Graphics.Venn(Matrix, Tags);
axis(ax, 'off');

circleColors = [1, 0, 0; 0, 0, 1];
for iCircle = 1:min(2, numel(Circles))
	Circles(iCircle).FaceColor = circleColors(iCircle, :);
	Circles(iCircle).FaceAlpha = 1/3;
	Circles(iCircle).EdgeColor = 'none';
	Circles(iCircle).LineStyle = 'none';
end
for patchObj = findobj(ax, 'Type', 'Patch')'
	patchObj.EdgeColor = 'none';
	patchObj.LineStyle = 'none';
end
for lineObj = findobj(ax, 'Type', 'Line')'
	lineObj.Color(4) = 0;
end
for iText = 1:numel(Texts)
	if isprop(Texts(iText), 'FontSize')
		Texts(iText).FontSize = 12;
	end
end

title(ax, titleText, 'FontSize', 12, 'FontWeight', 'normal');
if numel(Circles) >= 2
	lgd = legend(Circles(1:2), cellstr(string(legendLabels(:))), 'Location', MATLAB.Graphics.OptimizedLegendLocation(Texts(2:end)), 'Box', 'off', 'FontSize', 12);
	lgd.FontName = 'Segoe UI Emoji';
end
if strlength(chanceText) > 0
	text(ax, 0.5, 0.02, chanceText, 'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12);
end

allText = findall(f, 'Type', 'Text');
for iText = 1:numel(allText)
	allText(iText).FontSize = 12;
end

if ~isfolder(fileparts(svgPath))
	mkdir(fileparts(svgPath));
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
end
