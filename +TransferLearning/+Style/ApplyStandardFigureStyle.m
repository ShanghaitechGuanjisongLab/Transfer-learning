function ApplyStandardFigureStyle(Fig, Scale, options)
arguments
	Fig (1,1) matlab.ui.Figure
	Scale (1,1) double {mustBePositive}
	options.PreserveScatterStyle (1,1) logical = false
end

fontSize = 6 * Scale;
axisLineWidth = 0.5 * Scale;
otherLineWidth = 1 * Scale;
scatterSize = 10 * Scale;

iSetAllFontSizes(Fig, fontSize);
if options.PreserveScatterStyle
	iSetAllNonScatterLineWidths(Fig, otherLineWidth);
else
	iSetAllLineWidths(Fig, otherLineWidth);
	iSetScatterSizes(Fig, scatterSize);
end
iSetAxisLineWidths(Fig, axisLineWidth);
iSetConstantLineWidths(Fig, axisLineWidth);
iSetPValueLineWidths(Fig, axisLineWidth);
iSetBarAndErrorBarColors(Fig, [0, 0, 0]);
iSetBarBaseLineWidths(Fig, axisLineWidth);
end

function iSetAllFontSizes(Fig, fontSize)
handles = findall(Fig, '-property', 'FontSize');
for iH = 1:numel(handles)
	handles(iH).FontSize = fontSize;
end
end

function iSetAllLineWidths(Fig, lineWidth)
handles = findall(Fig, '-property', 'LineWidth');
for iH = 1:numel(handles)
	handles(iH).LineWidth = lineWidth;
end
end

function iSetAllNonScatterLineWidths(Fig, lineWidth)
handles = findall(Fig, '-property', 'LineWidth');
for iH = 1:numel(handles)
	if isa(handles(iH), 'matlab.graphics.chart.primitive.Scatter')
		continue;
	end
	handles(iH).LineWidth = lineWidth;
end
end

function iSetAxisLineWidths(Fig, lineWidth)
axesHandles = findall(Fig, 'Type', 'axes');
for iA = 1:numel(axesHandles)
	ax = axesHandles(iA);
	ax.LineWidth = lineWidth;
	for axisObj = [ax.XAxis, ax.YAxis, ax.ZAxis]
		axisObj.LineWidth = lineWidth;
	end
end

colorBars = findall(Fig, '-isa', 'matlab.graphics.illustration.ColorBar');
for iC = 1:numel(colorBars)
	colorBars(iC).LineWidth = lineWidth;
end
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

function iSetBarAndErrorBarColors(Fig, color)
bars = findall(Fig, '-isa', 'matlab.graphics.chart.primitive.Bar');
for iB = 1:numel(bars)
	bars(iB).FaceColor = color;
	bars(iB).EdgeColor = 'none';
	bars(iB).FaceAlpha = 1;
end

errorBars = findall(Fig, '-isa', 'matlab.graphics.chart.primitive.ErrorBar');
for iE = 1:numel(errorBars)
	errorBars(iE).Color = color;
end
end

function iSetBarBaseLineWidths(Fig, lineWidth)
handles = findall(Fig, '-property', 'BaseLine');
for iH = 1:numel(handles)
	handles(iH).BaseLine.LineWidth = lineWidth;
end
end