function Fig371_BaselineConvergenceBarFigure(values, compareGroup, yLabel, svgFileName, xTickLabels)
if nargin < 5 || isempty(xTickLabels)
    xTickLabels = {"Learned", "Naive", "C-hit", "C-miss"};
end

if ~isstruct(values)
    error('Fig371:BarInputType', 'values must be a struct keyed by phase name.');
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
[~, Optional, barsObj, errorBars] = UniExp.BarScatterCompare(dataCell, compareGroup, AsteriskThreshold=0.01, CapSize=0.5);

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

iStyleBarsBlack(barsObj);
iRemoveScatter(ax);
iStyleErrorBarsBlack(errorBars);
iStyleAxesContents(f, ax);

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
    ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
    mkdir(outDirUNC);
end
svgPath = char(svgFileName);
    MATLAB.Graphics.PLineRetune(Optional.MultiCompare.PLine, Optional.MultiCompare.PText);
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
    error('Fig371:CompareGroupNotFound', 'Compare group is missing from bar values: %s', strjoin(missingGroup, ', '));
end
compareGroup.GroupPair = groupPairIndex;
end

function iStyleBarsBlack(barsObj)
if isscalar(barsObj)
    barsObj.FaceColor = 'flat';
    barsObj.CData = repmat([0, 0, 0], numel(barsObj.YData), 1);
    barsObj.EdgeColor = 'none';
    barsObj.LineWidth = 1;
    if isprop(barsObj, 'BaseLine') && ~isempty(barsObj.BaseLine)
        barsObj.BaseLine.LineWidth = 1;
    end
else
    for iBar = 1:numel(barsObj)
        barsObj(iBar).FaceColor = [0, 0, 0];
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

function iStyleErrorBarsBlack(errorBars)
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
    errorBarObjects(iEb).Color = [0, 0, 0];
    errorBarObjects(iEb).LineWidth = 1;
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

