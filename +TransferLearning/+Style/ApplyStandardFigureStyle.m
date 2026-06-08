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
	iSetAllNonScatterLineWidths(Fig, otherLineWidth, axisLineWidth);
else
	iSetAllLineWidths(Fig, otherLineWidth, axisLineWidth);
	iSetScatterSizes(Fig, scatterSize);
end
iSetAxisLineWidths(Fig, axisLineWidth);
iSetConstantLineWidths(Fig, axisLineWidth);
iHideBarBaseLines(Fig);
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

function iSetAllLineWidths(Fig, lineWidth, axisAlignedLineWidth)
handles = findall(Fig, '-property', 'LineWidth');
for iH = 1:numel(handles)
	if iShouldPreserveLineWidth(handles(iH)) || iIsBidirectionalErrorBar(handles(iH))
		continue;
	end
	if iIsTwoPointAxisAlignedLine(handles(iH))
		handles(iH).LineWidth = axisAlignedLineWidth;
		continue;
	end
	handles(iH).LineWidth = lineWidth;
end
end

function iSetAllNonScatterLineWidths(Fig, lineWidth, axisAlignedLineWidth)
handles = findall(Fig, '-property', 'LineWidth');
for iH = 1:numel(handles)
	if iShouldPreserveLineWidth(handles(iH)) || isa(handles(iH), 'matlab.graphics.chart.primitive.Scatter') || iIsBidirectionalErrorBar(handles(iH))
		continue;
	end
	if iIsTwoPointAxisAlignedLine(handles(iH))
		handles(iH).LineWidth = axisAlignedLineWidth;
		continue;
	end
	handles(iH).LineWidth = lineWidth;
end
end

function tf = iShouldPreserveLineWidth(handleObj)
if ~isgraphics(handleObj)
	tf = false;
	return;
end
tf = isappdata(handleObj, 'TransferLearningPreserveLineWidth') && isequal(getappdata(handleObj, 'TransferLearningPreserveLineWidth'), true);
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

function tf = iIsTwoPointAxisAlignedLine(handleObj)
if ~isa(handleObj, 'matlab.graphics.chart.primitive.Line')
	tf = false;
	return;
end
xData = handleObj.XData;
yData = handleObj.YData;
tf = iIsFinitePair(xData) && iIsFinitePair(yData) && (iIsEqualPair(xData) || iIsEqualPair(yData));
end

function tf = iIsFinitePair(data)
if numel(data) ~= 2
	tf = false;
	return;
end
if isdatetime(data)
	tf = ~any(isnat(data(:)));
elseif isduration(data)
	tf = all(isfinite(seconds(data(:))));
elseif isnumeric(data) || islogical(data)
	tf = all(isfinite(double(data(:))));
else
	tf = false;
end
end

function tf = iIsEqualPair(data)
tf = data(1) == data(2);
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

function iSetScatterSizes(Fig, scatterSize)
handles = findall(Fig, '-isa', 'matlab.graphics.chart.primitive.Scatter');
for iH = 1:numel(handles)
	handles(iH).SizeData = scatterSize;
end
end

function iHideBarBaseLines(Fig)
barHandles = findall(Fig, 'Type', 'Bar');
for barIndex = 1:numel(barHandles)
	barHandle = barHandles(barIndex);
	if isprop(barHandle, 'BaseLine') && isgraphics(barHandle.BaseLine)
		if iShouldPreserveBarBaseLine(barHandle) || iShouldPreserveMixedSignBarBaseLine(barHandle)
			barHandle.BaseLine.Visible = 'on';
			continue;
		end
		ax = ancestor(barHandle, 'axes');
		if ~isempty(ax) && isgraphics(ax) && isprop(ax.XAxis, 'Visible') && strcmp(ax.XAxis.Visible, 'off')
			barHandle.BaseLine.Visible = 'on';
			continue;
		end
		barHandle.BaseLine.Visible = 'off';
	end
end
end

function tf = iShouldPreserveBarBaseLine(barHandle)
appdataName = 'TransferLearningPreserveBarBaseLine';
tf = isappdata(barHandle, appdataName) && isequal(getappdata(barHandle, appdataName), true);
if tf || ~isprop(barHandle, 'BaseLine') || ~isgraphics(barHandle.BaseLine)
	return;
end
tf = isappdata(barHandle.BaseLine, appdataName) && isequal(getappdata(barHandle.BaseLine, appdataName), true);
end

function tf = iShouldPreserveMixedSignBarBaseLine(barHandle)
if ~isgraphics(barHandle) || ~isprop(barHandle, 'YData')
	tf = false;
	return;
end

ax = ancestor(barHandle, 'axes');
if ~isgraphics(ax)
	tf = false;
	return;
end

barsInAxes = findall(ax, 'Type', 'Bar');
allY = [];
for iB = 1:numel(barsInAxes)
	y = double(barsInAxes(iB).YData);
	allY = [allY; y(:)]; %#ok<AGROW>
end

allY = allY(isfinite(allY));
if isempty(allY)
	tf = false;
	return;
end

hasPositive = any(allY > 0);
hasNegative = any(allY < 0);
tf = hasPositive && hasNegative;
end