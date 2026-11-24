% Fig1G：声水学会、光水迁移命中/错失三条均值线
%   样式：无坐标轴（无底线/刻度/y 轴），仅保留 0 s / 1 s 事件虚线 + emoji；
%         左下角 0.5 z / 0.5 s 反 L 比例尺（cue 虚线左侧，两个标签都在竖线右侧）；
%         图例单独绘制在右侧空白区，最下一行与事件 emoji 行对齐。
%   导出：135 × 60 mm（Scale 3），排版按 45 × 20 mm。

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

xMask = (xsSec >= -1) & (xsSec <= 3);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1P:No1s', 'Cannot find sample close to 1s.');
end

qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTHit = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 1);
qTMiss = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 0);

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit = DS.QueryNTATS(qTHit, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = DS.QueryNTATS(qTMiss, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

XLearned = squeeze(X(:, :, 1));
baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
v1 = XLearned(:, idx1s);
activeMask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
panelNames = ["Learned"; "Hit"; "Miss"];
sampleMasks = false(size(X, 1), numel(panelNames));
for panelIndex = 1:numel(panelNames)
	panelData = squeeze(X(:, :, panelIndex));
	sampleMasks(:, panelIndex) = activeMask & any(isfinite(panelData(:, xMask)), 2);
end
sampleCounts = TransferLearning.PanelSampleCountTable(S, panelNames, sampleMasks, DS.Cells);
X = X(activeMask, xMask, :);

nCells = size(X, 1);
nT = size(X, 2);
Y = nan(nT, 3);
E = nan(nT, 3);
for iL = 1:3
	D = squeeze(X(:, :, iL));
	Y(:, iL) = mean(D, 1, 'omitnan')';
	E(:, iL) = std(D, 0, 1, 'omitnan')' / sqrt(nCells);
end
%% 绘图
f = figure('Color', 'w', 'Name', 'English Fig1G Learned Transfer Hit Miss mean lines');
f.Units = 'centimeters';
f.Position(3:4) = [13.5, 6];

axPos = [0.095 0.055 0.560 0.870];
Ax = axes(f, 'Position', axPos);
hold(Ax, 'on');

lineColors = [TransferLearning.ColorLearned; TransferLearning.ColorHit; TransferLearning.ColorMiss] / 255;

Patches = MATLAB.Graphics.MultiShadowedLines(Y, E, 0.2, X=repmat(xsPlot(:), 1, 3), EdgeColors=lineColors);

% 事件虚线（0 s cue / 1 s 给水）：只跨数据区，不延伸到标题 / emoji 区
% 固定纵轴：曲线占中上部，上方留标题、下方留事件 emoji 行
yl = [-1.20 4.40];
ylim(Ax, yl);
xlim(Ax, [-1 3]);
yDash = [min(Y(:) - E(:)) - 0.12, max(Y(:) + E(:)) + 0.12];
plot(Ax, [0 0], yDash, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.5, 'HandleVisibility', 'off');
plot(Ax, [1 1], yDash, '--', 'Color', [0.80 0.20 0.15], 'LineWidth', 0.5, 'HandleVisibility', 'off');

% 只保留事件 emoji：底部横线 / 刻度 / y 轴全部去掉
Ax.XAxis.Visible = 'off';
Ax.YAxis.Visible = 'off';
Ax.Box = 'off';
Ax.TickLength = [0 0];

% cue / 给水 emoji（画在轴线下方）
yEm = -1.02;
hEmoji = gobjects(1, 2);
hEmoji(1) = text(Ax, 0, yEm, "🔊/💡", 'FontName', 'Segoe UI Emoji', 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Clipping', 'off');
hEmoji(2) = text(Ax, 1, yEm, "💧", 'FontName', 'Segoe UI Emoji', 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Clipping', 'off');

% 比例尺：基线上方、cue 虚线左侧（0.5 s 从轴左边界外起画，Clipping 关闭）
% 整体左移，使「0.5 z」文字右端不会碰到 cue 虚线
iScaleBar(Ax, -1.58, 1.05, 0.5, 0.5);

% 图例单独画在一个不显示的坐标区里（不用 eastoutside，否则会压缩绘图区）
lgPos = [0.660 0.150 0.350 0.420];
axLg = axes(f, 'Position', lgPos, 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
hold(axLg, 'on');
lgY = [0.85 0.52 0.19];
lgNames = ["🔊 Learned", "💡 Hit", "💡 Miss"];
for iLg = 1:3
	plot(axLg, [0.01 0.20], [lgY(iLg) lgY(iLg)], '-', 'Color', lineColors(iLg, :), ...
		'LineWidth', 1, 'Clipping', 'off');
	text(axLg, 0.24, lgY(iLg), lgNames(iLg), 'FontSize', 6, 'FontName', 'Segoe UI Emoji', ...
		'Color', [0.15 0.15 0.15], 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end
% 标题：左上角左对齐（放在全图坐标里，不用 axes title）
axT = axes(f, 'Position', [0 0 1 1], 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
hold(axT, 'on');
text(axT, 0.062, 0.925, '🔊💧 learned active cells', 'FontName', 'Segoe UI Emoji', ...
	'FontSize', 6, 'Color', [0.10 0.10 0.10], ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

% 先套统一样式，再把图例最下面一行对齐到 emoji 行
TransferLearning.Style.ApplyStandardFigureStyle(f, 3);
drawnow;
pAx = Ax.Position;
eEm = hEmoji(1).Extent;                                                 % data 单位
yEmData = eEm(2) + eEm(4) / 2;                                          % emoji 行中心
yEmFig = pAx(2) + (yEmData - yl(1)) / (yl(2) - yl(1)) * pAx(4);
axLg.Position = [lgPos(1), yEmFig - lgY(3) * lgPos(4), lgPos(3), lgPos(4)];

svgPath = TransferLearning.StandardFigureSvgPath('English_Fig1G_Learned_TransferHitMiss_MeanLines.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

function iScaleBar(ax, x0, y0, tLen, zLen)
% 左下角的「反 L」比例尺：横 = 时间，纵 = z
col = [0.25 0.25 0.25];
xl = xlim(ax);  yl = ylim(ax);
dx = xl(2) - xl(1);  dy = yl(2) - yl(1);
plot(ax, [x0, x0 + tLen], [y0, y0], '-', 'Color', col, 'LineWidth', 0.75, ...
	'Clipping', 'off', 'HandleVisibility', 'off');
plot(ax, [x0 + tLen, x0 + tLen], [y0, y0 + zLen], '-', 'Color', col, 'LineWidth', 0.75, ...
	'Clipping', 'off', 'HandleVisibility', 'off');
% 0.5 z：竖线右侧、与竖线中点垂直居中
text(ax, x0 + tLen + 0.03 * dx, y0 + zLen / 2, sprintf('%g z', zLen), 'FontSize', 6, 'Color', col, ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Clipping', 'off');
% 0.5 s：横线下方、与横线左端对齐
text(ax, x0, y0 - 0.55, sprintf('%g s', tLen), 'FontSize', 6, 'Color', col, ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Clipping', 'off');
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
if isnumeric(nt) && ndims(nt) == 3
	X = nt;
	return;
end
	error('Fig1P:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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