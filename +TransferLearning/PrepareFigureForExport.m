function PrepareFigureForExport(figHandle, options)
arguments
	figHandle
	options.ForceLegendOrColorbar (1,1) logical = false
end

if ~ishghandle(figHandle, 'figure')
	figHandle = ancestor(figHandle, 'figure');
end

legendHandles = findall(figHandle, 'Type', 'legend');
colorbarHandles = findall(figHandle, 'Type', 'colorbar');
hasLegendOrColorbar = options.ForceLegendOrColorbar || ~isempty(legendHandles) || ~isempty(colorbarHandles);
lineWidthTarget = 1 + hasLegendOrColorbar;

lineWidthHandles = findall(figHandle, '-property', 'LineWidth');
for handle = lineWidthHandles(:)'
	if isappdata(handle, 'TransferLearningPreserveLineWidth') && getappdata(handle, 'TransferLearningPreserveLineWidth')
		continue;
	end
	handle.LineWidth = lineWidthTarget;
end

scatterHandles = findall(figHandle, 'Type', 'scatter');
for scatterHandle = scatterHandles(:)'
	scatterHandle.LineWidth = 0.2;
end

barHandles = findall(figHandle, 'Type', 'bar');
for barHandle = barHandles(:)'
	iSyncBarEdgeColor(barHandle);
	if isprop(barHandle, 'BaseLine') && ~isempty(barHandle.BaseLine) && isgraphics(barHandle.BaseLine)
		barHandle.BaseLine.LineWidth = lineWidthTarget;
	end
end

errorbarHandles = findall(figHandle, 'Type', 'errorbar');
for errorbarHandle = errorbarHandles(:)'
	iSyncErrorBarColor(errorbarHandle, lineWidthTarget);
end

for legendHandle = legendHandles(:)'
	legendHandle.Box = 'off';
	legendHandle.LineWidth = lineWidthTarget;
end

if hasLegendOrColorbar
	fontHandles = findall(figHandle, '-property', 'FontSize');
	for handle = fontHandles(:)'
		handle.FontSize = 12;
	end
	for colorbarHandle = colorbarHandles(:)'
		colorbarHandle.FontSize = 12;
		colorbarHandle.Label.FontSize = 12;
	end
end
end

function iSyncBarEdgeColor(barHandle)
if ~isgraphics(barHandle, 'bar')
	return;
end

if ~isprop(barHandle, 'EdgeColor') || ~isprop(barHandle, 'FaceColor')
	return;
end

faceColor = barHandle.FaceColor;
if ischar(faceColor) || (isstring(faceColor) && isscalar(faceColor))
	faceMode = string(faceColor);
	if strcmpi(faceMode, "flat")
		barHandle.EdgeColor = 'flat';
	elseif strcmpi(faceMode, "none")
		barHandle.EdgeColor = 'none';
	end
	return;
end

if isnumeric(faceColor) && isequal(size(faceColor), [1, 3])
	barHandle.EdgeColor = faceColor;
end
end

function iSyncErrorBarColor(errorbarHandle, lineWidthTarget)
if ~isgraphics(errorbarHandle, 'errorbar')
	return;
end

if isappdata(errorbarHandle, 'TransferLearningSplitErrorbar')
	return;
end

ax = ancestor(errorbarHandle, 'axes');
if isempty(ax) || ~isgraphics(ax, 'axes')
	return;
end

colors = iColorsForErrorbar(ax, errorbarHandle);
if isempty(colors)
	return;
end

xData = errorbarHandle.XData;
yData = errorbarHandle.YData;
yNeg = errorbarHandle.YNegativeDelta;
yPos = errorbarHandle.YPositiveDelta;

if ~(isnumeric(xData) && isnumeric(yData) && isnumeric(yNeg) && isnumeric(yPos))
	return;
end

xData = xData(:);
	yData = yData(:);
	yNeg = yNeg(:);
	yPos = yPos(:);

	if isempty(yNeg) && ~isempty(yPos)
		yNeg = yPos;
	elseif isempty(yPos) && ~isempty(yNeg)
		yPos = yNeg;
	end

if numel(xData) ~= size(colors, 1) || numel(yData) ~= numel(xData) ...
		|| numel(yNeg) ~= numel(xData) || numel(yPos) ~= numel(xData)
	return;
end

if numel(xData) == 1
	errorbarHandle.Color = colors(1, :);
	return;
end

setappdata(errorbarHandle, 'TransferLearningSplitErrorbar', true);

holdState = ishold(ax);
	hold(ax, 'on');
	for iPoint = 1:numel(xData)
		newHandle = errorbar(ax, xData(iPoint), yData(iPoint), yNeg(iPoint), yPos(iPoint), ...
			'LineStyle', 'none', ...
			'Color', colors(iPoint, :), ...
			'LineWidth', lineWidthTarget, ...
			'CapSize', errorbarHandle.CapSize, ...
			'HandleVisibility', 'off');
		try
			newHandle.Annotation.LegendInformation.IconDisplayStyle = 'off';
		catch
		end
	end
	if ~holdState
		hold(ax, 'off');
	end

	errorbarHandle.Visible = 'off';
end

function colors = iColorsForErrorbar(ax, errorbarHandle)
colors = [];
xData = errorbarHandle.XData;
if ~isnumeric(xData)
	return;
end

nPoints = numel(xData);
barHandles = flip(findall(ax, 'Type', 'bar'));
if isempty(barHandles)
	return;
end

if numel(barHandles) == 1
	colors = iColorsForSingleBarHandle(barHandles, nPoints);
	return;
end

colors = nan(nPoints, 3);
xCenters = nan(numel(barHandles), 1);
for iBar = 1:numel(barHandles)
	thisBar = barHandles(iBar);
	thisColors = iColorsForSingleBarHandle(thisBar, 1);
	if isempty(thisColors)
		colors = [];
		return;
	end
	colors(iBar, :) = thisColors(1, :);
	xCenters(iBar) = iBarXCenter(thisBar, iBar);
end

if numel(barHandles) ~= nPoints
	colors = [];
	return;
end

[~, order] = sort(xCenters);
	colors = colors(order, :);
end

function colors = iColorsForSingleBarHandle(barHandle, nPoints)
colors = [];
if ~isgraphics(barHandle, 'bar')
	return;
end

if isprop(barHandle, 'CData') && isnumeric(barHandle.CData) ...
		&& size(barHandle.CData, 2) == 3 && size(barHandle.CData, 1) >= nPoints
	colors = barHandle.CData(1:nPoints, :);
	return;
end

faceColor = barHandle.FaceColor;
if isnumeric(faceColor) && isequal(size(faceColor), [1, 3])
	colors = repmat(faceColor, nPoints, 1);
end
end

function xCenter = iBarXCenter(barHandle, fallbackValue)
xCenter = fallbackValue;
try
	if isprop(barHandle, 'XEndPoints') && ~isempty(barHandle.XEndPoints)
		xCenter = mean(barHandle.XEndPoints(:), 'omitnan');
		return;
	end
catch
end

try
	if isprop(barHandle, 'XData') && ~isempty(barHandle.XData)
		xCenter = mean(barHandle.XData(:), 'omitnan');
	end
catch
end
end