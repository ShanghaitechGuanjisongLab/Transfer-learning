% 中文图43F/43G：活跃细胞占总细胞比例（模仿英文图1I样式）
% 43F: 声水 Learned 活跃细胞占总细胞比例
% 43G: 光水 Continual 首个训练单元活跃细胞占总细胞比例

if ~exist('UniExp.DataSet', 'class')
    thisFile = mfilename('fullpath');
    thisDir = fileparts(thisFile);
    prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
    if exist(prjFile, 'file')
        matlab.project.loadProject(prjFile);
    end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs)
    xsSec = seconds(xs);
else
    xsSec = double(xs);
end

baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
    error('Fig43FG:No1s', 'Cannot find sample close to 1s.');
end

kSigma = 3;

% 43F: Learned AudioWater
qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
GLearned = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
learnedTable = iBuildActiveCellTable(GLearned, idx1s, baseMask, kSigma);
[learnedActiveN, learnedTotalN] = iUniqueCounts(learnedTable);

% 43G: Transfer LightWater 每只鼠首个训练单元
firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS);
continualTables = cell(height(firstTransfer), 1);
for iMouse = 1:height(firstTransfer)
    qTransferOne = struct('Stimulus', 'LightWater', 'DateTime', firstTransfer.DateTime(iMouse));
    GTransferOne = DS.QueryNTATS(qTransferOne, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
    continualTables{iMouse} = iBuildActiveCellTable(GTransferOne, idx1s, baseMask, kSigma);
end
if isempty(continualTables)
    continualTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
else
    continualTable = vertcat(continualTables{:});
end
[continualActiveN, continualTotalN] = iUniqueCounts(continualTable);

[fF, fracLearned] = iPlotOnePie(learnedActiveN, learnedTotalN, '中文图43F 声水Learned活跃细胞占比', sprintf('🔊💧\nactive cells'));
[fG, fracContinual] = iPlotOnePie(continualActiveN, continualTotalN, '中文图43G 光水Continual首单元活跃细胞占比', sprintf('💡💧\nactive cells'));

svgF = '中文图Fig43F_LearnedAudioActiveFractionPie.svg';
svgG = '中文图Fig43G_ContinualFirstLightActiveFractionPie.svg';
svgFPath = TransferLearning.ExportStandardFigureTransparent(fF, 1, svgF);
svgGPath = TransferLearning.ExportStandardFigureTransparent(fG, 1, svgG);
fprintf('Wrote: %s\n', svgFPath);
fprintf('Wrote: %s\n', svgGPath);

summary = table(learnedActiveN, learnedTotalN, fracLearned, continualActiveN, continualTotalN, fracContinual, ...
    'VariableNames', {'LearnedActiveN', 'LearnedTotalN', 'LearnedFraction', 'ContinualFirstActiveN', 'ContinualFirstTotalN', 'ContinualFirstFraction'});
assignin('base', 'Fig43FG_Summary', summary);
assignin('base', 'Fig43F_SvgPath', svgFPath);
assignin('base', 'Fig43G_SvgPath', svgGPath);

function firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
    T.DateTime.TimeZone = '';
end
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);

T = T(T.Phase == "Transfer" & T.Stimulus == "LightWater", {'Mouse', 'DateTime'});
if isempty(T)
    firstTransfer = table(string.empty(0, 1), NaT(0, 1), 'VariableNames', {'Mouse', 'DateTime'});
    return;
end

T = sortrows(T, {'Mouse', 'DateTime'});
[groupId, mouseName] = findgroups(T.Mouse);
firstDate = splitapply(@(x) x(1), T.DateTime, groupId);
firstTransfer = table(mouseName, firstDate, 'VariableNames', {'Mouse', 'DateTime'});
end

function activeTable = iBuildActiveCellTable(G, idx1s, baseMask, kSigma)
if isempty(G)
    activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
    return;
end
S = UniExp.NtatsCellStrip(struct('Q', G));
X = iGetNtats3D(S);
if isempty(X)
    activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
    return;
end
if size(X, 3) > 1
    XLane = squeeze(X(:, :, 1));
else
    XLane = squeeze(X);
end
if ~istable(S) || ~ismember('CellUID', S.Properties.VariableNames)
    error('Fig43FG:MissingCellUID', 'NtatsCellStrip result does not contain CellUID.');
end

baseMu = mean(XLane(:, baseMask), 2, 'omitnan');
baseSd = std(XLane(:, baseMask), 0, 2, 'omitnan');
v1 = XLane(:, idx1s);
isActive = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
activeTable = table(uint64(S.CellUID), logical(isActive), 'VariableNames', {'CellUID', 'IsActive'});
end

function X = iGetNtats3D(S)
if istable(S)
    nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
    nt = S.NTATS;
else
    nt = S;
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
    try
        X = nt.Data.Data;
    catch
        X = nt{:,:,:}.Data;
    end
    return;
end

if isnumeric(nt)
    if ndims(nt) ~= 3
        error('Fig43FG:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
    end
    X = nt;
    return;
end

error('Fig43FG:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [activeN, totalN] = iUniqueCounts(activeTable)
if isempty(activeTable)
    activeN = 0;
    totalN = 0;
    return;
end
[cellUID, idx] = unique(uint64(activeTable.CellUID), 'stable');
isActive = logical(activeTable.IsActive(idx));
activeN = nnz(isActive);
totalN = numel(cellUID);
end

function [fig, frac] = iPlotOnePie(activeN, totalN, figName, smallSliceLabel)
fig = figure('Color', 'none', 'Name', figName);
fig.Units = 'centimeters';
fig.Position(3:4) = [6.0, 4.0];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 6.0, 4.0];
fig.PaperSize = [6.0, 4.0];

if totalN > 0
    frac = activeN / totalN;
else
    frac = NaN;
end

pActive = frac;
pInactive = 1 - pActive;
if ~isfinite(pActive)
    pActive = NaN;
    pInactive = NaN;
end

majorColor = 0.7922 .* [1 1 1];
minorColor = [0, 0.6275, 0.9137];
if pActive >= pInactive
    wedgeColors = [majorColor; minorColor];
else
    wedgeColors = [minorColor; majorColor];
end

ax = axes(fig, 'Position', [0.22, 0.12, 0.56, 0.78]);
labelTexts = [smallSliceLabel, "all cells"];
valueVec = [pActive, pInactive];
[~, majorIdx] = max(valueVec);
[~, minorIdx] = min(valueVec);
sideLabels = strings(1, 2);
if majorIdx == minorIdx
    titleText = iCapitalizeLeadingLetter(labelTexts(2));
else
    titleText = iCapitalizeLeadingLetter(labelTexts(majorIdx));
end
MATLAB.Graphics.NestedPie( ...
    {valueVec}, ...
    WedgeColors={wedgeColors}, ...
    LabelText=sideLabels, ...
    PercentStatus="on", ...
    PercentFontColor='k', ...
    RhoLower=0.4, ...
    LineWidth=0.5, ...
    LabelOffset=0.16, ...
    AxesHandle=ax);
title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');

if all(isfinite(valueVec)) && sum(valueVec) > 0
    startAngleDeg = [0, 360 * valueVec(1) / sum(valueVec)];
    endAngleDeg = [startAngleDeg(2), 360];
    thetaDeg = 0.5 * (startAngleDeg(minorIdx) + endAngleDeg(minorIdx));
    theta = deg2rad(thetaDeg);
    labelRadius = 1.12;
    tx = labelRadius * cos(theta);
    ty = labelRadius * sin(theta);
    if tx >= 0
        hAlign = 'left';
        tx = tx + 0.005;
    else
        hAlign = 'right';
        tx = tx - 0.005;
    end
    text(ax, tx, ty, labelTexts(1), 'FontSize', 6, 'FontWeight', 'normal', ...
        'Color', minorColor, 'HorizontalAlignment', hAlign, ...
        'VerticalAlignment', 'middle', 'Clipping', 'off');
end

set(findobj(fig, 'Type', 'text'), 'FontSize', 6);
end

function outText = iCapitalizeLeadingLetter(inText)
outText = string(inText);
chars = char(outText);
idx = regexp(chars, '[A-Za-z]', 'once');
if isempty(idx)
    return;
end
chars(idx) = upper(chars(idx));
outText = string(chars);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
    idx = 1;
    ok = false;
    return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
