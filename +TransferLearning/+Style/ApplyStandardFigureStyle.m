function ApplyStandardFigureStyle(Fig, Scale, options)
arguments
	Fig (1,1) matlab.ui.Figure
	Scale (1,1) double {mustBePositive}
	options.PreserveScatterStyle (1,1) logical = false
end

fontSize = 6 * Scale;
axisLineWidth = 0.5 * Scale;
otherLineWidth = 1 * Scale;
scatterSize = 5 * Scale*Scale;

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
iSetBarAndErrorBarColors(Fig);
iSetBarBaseLineWidths(Fig, axisLineWidth);
end

function iSetAllFontSizes(Fig, fontSize)
handles = findall(Fig, '-property', 'FontSize');
for iH = 1:numel(handles)
	handles(iH).FontSize = fontSize;
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

function iSetBarAndErrorBarColors(Fig)
axesHandles = findall(Fig, 'Type', 'axes');
palette = [1, 0, 0; 0, 0, 1; 0, 0.6809, 0];
for iA = 1:numel(axesHandles)
	ax = axesHandles(iA);
	barSpec = iColorBarsInAxes(ax, palette);
	iColorErrorBarsInAxes(ax, barSpec);
	end
end

function barSpec = iColorBarsInAxes(ax, palette)
bars = findall(ax, '-isa', 'matlab.graphics.chart.primitive.Bar');
barSpec = table.empty;
if isempty(bars)
	return;
end

entryObject = gobjects(0, 1);
entryPointIndex = zeros(0, 1);
entryX = zeros(0, 1);
for iB = 1:numel(bars)
	x = iGetBarXPositions(bars(iB));
	if isempty(x)
		continue;
	end
	nPoint = numel(x);
	entryObject = [entryObject; repmat(bars(iB), nPoint, 1)]; %#ok<AGROW>
	entryPointIndex = [entryPointIndex; (1:nPoint).']; %#ok<AGROW>
	entryX = [entryX; x(:)]; %#ok<AGROW>
	bars(iB).FaceColor = 'flat';
	bars(iB).EdgeColor = 'none';
		bars(iB).FaceAlpha = 1;
	end

	if isempty(entryX)
		return;
	end

	[sortedX, order] = sort(entryX);
	sortedColors = repmat(palette, ceil(numel(sortedX) / size(palette, 1)), 1);
	sortedColors = sortedColors(1:numel(sortedX), :);
	entryColors = zeros(numel(sortedX), 3);
	entryColors(order, :) = sortedColors;
	for iB = 1:numel(bars)
		x = iGetBarXPositions(bars(iB));
		if isempty(x)
			continue;
		end
		mask = entryObject == bars(iB);
		cdata = zeros(numel(x), 3);
		cdata(entryPointIndex(mask), :) = entryColors(mask, :);
		bars(iB).CData = cdata;
	end
	barSpec = table(sortedX, sortedColors, 'VariableNames', {'X', 'Color'});
end

function iColorErrorBarsInAxes(ax, barSpec)
	errorBars = findall(ax, '-isa', 'matlab.graphics.chart.primitive.ErrorBar');
	if isempty(errorBars) || isempty(barSpec)
		return;
	end
	for iE = 1:numel(errorBars)
		x = errorBars(iE).XData(:);
		if isempty(x)
			continue;
		end
		[~, idx] = min(abs(barSpec.X - x(1)));
		errorBars(iE).Color = barSpec.Color(idx, :);
	end
end

function x = iGetBarXPositions(barObj)
	if isprop(barObj, 'XEndPoints') && ~isempty(barObj.XEndPoints)
		x = double(barObj.XEndPoints(:));
	elseif isprop(barObj, 'XData') && ~isempty(barObj.XData)
		x = double(barObj.XData(:));
	else
		x = [];
	end
end

function iSetBarBaseLineWidths(Fig, lineWidth)
handles = findall(Fig, '-property', 'BaseLine');
for iH = 1:numel(handles)
	handles(iH).BaseLine.LineWidth = lineWidth;
end
end