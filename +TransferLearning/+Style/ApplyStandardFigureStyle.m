function ApplyStandardFigureStyle(Fig, Scale, options)
arguments
	Fig (1,1) matlab.ui.Figure
	Scale (1,1) double {mustBePositive}
	options.PreserveScatterStyle (1,1) logical = false
end

fontSize = 6 * Scale;
axisLineWidth = 0.5 * Scale;
otherLineWidth = 1 * Scale;
scatterSize = 4 * Scale*Scale;

iSetAllFontSizes(Fig, fontSize);
iSetLegendBoxesOff(Fig);
if options.PreserveScatterStyle
	iSetAllNonScatterLineWidths(Fig, otherLineWidth);
else
	iSetAllLineWidths(Fig, otherLineWidth);
	iSetScatterSizes(Fig, scatterSize);
end
iSetAxisLineWidths(Fig, axisLineWidth);
iSetConstantLineWidths(Fig, axisLineWidth);
iSetPValueLineWidths(Fig, axisLineWidth);
iSetBarBaseLineWidths(Fig, axisLineWidth);
end

function iSetAllFontSizes(Fig, fontSize)
handles = findall(Fig, '-property', 'FontSize');
for iH = 1:numel(handles)
	handles(iH).FontSize = fontSize;
end
iSetAxesFontMultipliers(Fig);
iSetTiledLayoutTextFontSizes(Fig, fontSize);
end

function iSetAxesFontMultipliers(Fig)
axesHandles = findall(Fig, 'Type', 'axes');
for axisIndex = 1:numel(axesHandles)
	ax = axesHandles(axisIndex);
	ax.LabelFontSizeMultiplier = 1;
	ax.TitleFontSizeMultiplier = 1;
end
end

function iSetTiledLayoutTextFontSizes(Fig, fontSize)
layouts = findall(Fig, '-isa', 'matlab.graphics.layout.TiledChartLayout');
for layoutIndex = 1:numel(layouts)
	layout = layouts(layoutIndex);
	iSetObjectFontSize(layout, 'Title', fontSize);
	iSetObjectFontSize(layout, 'XLabel', fontSize);
	iSetObjectFontSize(layout, 'YLabel', fontSize);
end
end

function iSetObjectFontSize(parentObject, propertyName, fontSize)
if isprop(parentObject, propertyName) && isprop(parentObject.(propertyName), 'FontSize')
	parentObject.(propertyName).FontSize = fontSize;
end
end

function iSetLegendBoxesOff(Fig)
legends = findall(Fig, '-isa', 'matlab.graphics.illustration.Legend');
for iL = 1:numel(legends)
	legends(iL).Box = 'off';
end
end

function iSetAllLineWidths(Fig, lineWidth)
handles = findall(Fig, '-property', 'LineWidth');
for iH = 1:numel(handles)
	if iIsBidirectionalErrorBar(handles(iH))
		continue;
	end
	handles(iH).LineWidth = lineWidth;
end
end

function iSetAllNonScatterLineWidths(Fig, lineWidth)
handles = findall(Fig, '-property', 'LineWidth');
for iH = 1:numel(handles)
	if isa(handles(iH), 'matlab.graphics.chart.primitive.Scatter') || iIsBidirectionalErrorBar(handles(iH))
		continue;
	end
	handles(iH).LineWidth = lineWidth;
end
end

function tf = iIsBidirectionalErrorBar(handleObj)
tf = isa(handleObj, 'matlab.graphics.chart.primitive.ErrorBar') && ...
	(iHasBidirectionalDelta(handleObj, 'X') || iHasBidirectionalDelta(handleObj, 'Y'));
end

function tf = iHasBidirectionalDelta(handleObj, axisName)
negativeProp = [axisName, 'NegativeDelta'];
positiveProp = [axisName, 'PositiveDelta'];
if ~isprop(handleObj, negativeProp) || ~isprop(handleObj, positiveProp)
	tf = false;
	return;
end
negativeDelta = double(handleObj.(negativeProp));
positiveDelta = double(handleObj.(positiveProp));
hasNegativeDelta = any(isfinite(negativeDelta(:)) & abs(negativeDelta(:)) > 0);
hasPositiveDelta = any(isfinite(positiveDelta(:)) & abs(positiveDelta(:)) > 0);
tf = hasNegativeDelta && hasPositiveDelta;
end

function iSetAxisLineWidths(Fig, lineWidth)
axesHandles = findall(Fig, 'Type', 'axes');
for iA = 1:numel(axesHandles)
	ax = axesHandles(iA);
	ax.LineWidth = lineWidth;
	axisObjects = iAxesRulerObjects(ax);
	for axisObj = axisObjects(:).'
		axisObj.LineWidth = lineWidth;
	end
end

colorBars = findall(Fig, '-isa', 'matlab.graphics.illustration.ColorBar');
for iC = 1:numel(colorBars)
	colorBars(iC).LineWidth = lineWidth;
end
end

function axisObjects = iAxesRulerObjects(ax)
axisObjects = [ax.XAxis(:); ax.YAxis(:); ax.ZAxis(:)];
axisObjects = axisObjects(isgraphics(axisObjects));
end

function iSetConstantLineWidths(Fig, lineWidth)
handles = findall(Fig, '-isa', 'matlab.graphics.chart.decoration.ConstantLine');
for iH = 1:numel(handles)
	handles(iH).LineWidth = lineWidth;
end
end

function iSetPValueLineWidths(Fig, lineWidth)
handles = findall(Fig, 'Type', 'line');
for iH = 1:numel(handles)
	h = handles(iH);
	if numel(h.XData) ~= 2 || numel(h.YData) ~= 2
		continue;
	end
	if ~all(isfinite(h.YData)) || h.YData(1) ~= h.YData(2)
		continue;
	end
	if string(h.Marker) ~= "none"
		continue;
	end
	h.LineWidth = lineWidth;
end
end

function iSetScatterSizes(Fig, scatterSize)
handles = findall(Fig, '-isa', 'matlab.graphics.chart.primitive.Scatter');
for iH = 1:numel(handles)
	handles(iH).SizeData = scatterSize;
end
end

function iSetBarBaseLineWidths(Fig, lineWidth)
handles = findall(Fig, '-property', 'BaseLine');
for iH = 1:numel(handles)
	handles(iH).BaseLine.LineWidth = lineWidth;
end
end