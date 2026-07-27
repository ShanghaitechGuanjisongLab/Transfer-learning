function Fig71_BaselineConvergenceBarFigure(values, compareGroup, yLabel, svgFileName, xTickLabels)
if nargin < 5 || isempty(xTickLabels)
    xTickLabels = {"Learned", "Naive", "C-hit", "C-miss"};
end

if ~isstruct(values)
    error('Fig71:BarInputType', 'values must be a struct keyed by phase name.');
end

valueNames = string(fieldnames(values)).';
for iValue = 1:numel(valueNames)
    values.(valueNames(iValue)) = double(values.(valueNames(iValue))(:));
    values.(valueNames(iValue)) = values.(valueNames(iValue))(isfinite(values.(valueNames(iValue))));
end
dataCell = iStructToRowCell(values, valueNames);
compareGroup = iCompareGroupToIndex(compareGroup, valueNames);

f = figure('Color', 'w', 'Name', char(svgFileName));
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4.5, 4.0];
f.PaperSize = [4.5, 4.0];

ax = axes(f);
ax.FontSize = 6;
[~, Optional, barsObj, errorBars] = UniExp.BarScatterCompare(dataCell, compareGroup, AsteriskThreshold=1, CapSize=0.5);
TransferLearning.Style.SetBarPValues(Optional);
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
    ax.XAxis.LineWidth = 1;
    ax.YAxis.LineWidth = 1;
end
box(ax, 'off');
grid(ax, 'off');
ylabel(ax, yLabel);
ax.XTick = 1:numel(valueNames);
ax.XTickLabel = cellstr(string(xTickLabels));
ax.XTickLabelRotation = 25;

iStyleBars(barsObj, valueNames);
iRemoveScatter(ax);
iStyleErrorBars(errorBars, valueNames);
iPreserveZeroBaseline(barsObj, ax);
iStyleAxesContents(f, ax);
iTagRetunablePValues(Optional);

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
    ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
    mkdir(outDirUNC);
end
svgPath = char(svgFileName);
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);
end

function dataCell = iStructToRowCell(values, valueNames)
dataCell = cell(1, numel(valueNames));
for iValue = 1:numel(valueNames)
    dataCell{iValue} = values.(valueNames(iValue));
end
end

function compareGroup = iCompareGroupToIndex(compareGroup, valueNames)
if isempty(compareGroup) || ~ismember('GroupPair', compareGroup.Properties.VariableNames) || isnumeric(compareGroup.GroupPair)
    return;
end

[isFound, groupPairIndex] = ismember(string(compareGroup.GroupPair), valueNames);
if ~all(isFound, 'all')
    missingGroup = unique(string(compareGroup.GroupPair(~isFound)));
    error('Fig71:CompareGroupNotFound', 'Compare group is missing from bar values: %s', strjoin(missingGroup, ', '));
end
compareGroup.GroupPair = groupPairIndex;
end

function iStyleBars(barsObj, valueNames)
colors = iValueColors(valueNames);
if isscalar(barsObj)
    barsObj.FaceColor = 'flat';
    barsObj.CData = colors(1:numel(barsObj.YData), :);
    barsObj.EdgeColor = 'none';
    barsObj.LineWidth = 1;
    if isprop(barsObj, 'BaseLine') && ~isempty(barsObj.BaseLine)
        barsObj.BaseLine.LineWidth = 1;
    end
else
    for iBar = 1:numel(barsObj)
        barsObj(iBar).FaceColor = colors(iBar, :);
        barsObj(iBar).EdgeColor = 'none';
        barsObj(iBar).LineWidth = 1;
        if isprop(barsObj(iBar), 'BaseLine') && ~isempty(barsObj(iBar).BaseLine)
            barsObj(iBar).BaseLine.LineWidth = 1;
        end
    end
end
end

function iRemoveScatter(ax)
scatters = findobj(ax, 'Type', 'Scatter');
for iScatter = 1:numel(scatters)
    delete(scatters(iScatter));
end
end

function iStyleErrorBars(errorBars, valueNames)
colors = iValueColors(valueNames);
if istable(errorBars) && ismember('Object', errorBars.Properties.VariableNames)
    errorBarObjects = errorBars.Object;
elseif isstruct(errorBars) && isfield(errorBars, 'Object')
    errorBarObjects = errorBars.Object;
else
    errorBarObjects = gobjects(0, 1);
end

for iEb = 1:numel(errorBarObjects)
    if ~isgraphics(errorBarObjects(iEb))
        continue;
    end
    x = double(errorBarObjects(iEb).XData(:));
    [~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
    errorBarObjects(iEb).Color = colors(colorIndex, :);
    errorBarObjects(iEb).LineWidth = 1;
end
end

function colors = iValueColors(valueNames)
colors = zeros(numel(valueNames), 3);
for iValue = 1:numel(valueNames)
    colors(iValue, :) = iValueColor(valueNames(iValue));
end
end

function color = iValueColor(valueName)
switch string(valueName)
    case "LearnedAudio"
        color = TransferLearning.LearnedColor;
    case "NaiveLight"
        color = TransferLearning.NaiveColor;
    case "TransferLightHit"
		color = TransferLearning.TransferColor;
	case "TransferLightMiss"
		color = TransferLearning.ColorB;
    otherwise
        color = TransferLearning.GroupColors(string(valueName));
end
end

function iTagRetunablePValues(options)
if ~isfield(options, 'MultiCompare')
    return;
end
multiCompare = options.MultiCompare;
if ismember('PLine', multiCompare.Properties.VariableNames) && ismember('PText', multiCompare.Properties.VariableNames)
    for iPair = 1:height(multiCompare)
        iTagRetunablePValuePair(multiCompare.PLine(iPair), multiCompare.PText(iPair), iPair);
    end
end
end

function iPreserveZeroBaseline(barsObj, ax)
barObjects = reshape(barsObj, 1, []);
for iBar = 1:numel(barObjects)
    if ~isgraphics(barObjects(iBar)) || ~isprop(barObjects(iBar), 'BaseLine') || ~isgraphics(barObjects(iBar).BaseLine)
        continue;
    end
    barObjects(iBar).BaseLine.Visible = 'on';
    barObjects(iBar).BaseLine.LineWidth = 0.5;
    barObjects(iBar).BaseLine.Color = ax.XColor;
    setappdata(barObjects(iBar).BaseLine, 'TransferLearningPreserveBarBaseLine', true);
    setappdata(barObjects(iBar).BaseLine, 'TransferLearningPreserveLineWidth', true);
end
end

function iTagRetunablePValuePair(pLine, pText, pairIndex)
if isgraphics(pLine)
    pLine.Tag = 'PLine';
    setappdata(pLine, 'TransferLearningPValuePairIndex', pairIndex);
end
if isgraphics(pText)
    pText.Tag = 'PText';
    pText.FontName = 'Microsoft YaHei';
    setappdata(pText, 'TransferLearningPValuePairIndex', pairIndex);
end
end

function iStyleAxesContents(f, ax)
textObj = findall(f, 'Type', 'Text');
for iText = 1:numel(textObj)
    textObj(iText).FontSize = 6;
end

lineObj = findobj(ax, 'Type', 'Line');
for iLine = 1:numel(lineObj)
    lineObj(iLine).LineWidth = 1;
end

ax.FontSize = 6;
end

