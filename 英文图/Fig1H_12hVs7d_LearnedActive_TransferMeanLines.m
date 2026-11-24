% 英文图1H：12 h与7 d各自声水Learned阶段活跃细胞在迁移光水阶段的两条钙活动均值线。
% 复用1P口径：Learned/AudioWater的cue+1 s响应高于cue前基线均值+3σ，细胞只在各自队列内与Transfer/LightWater配准。
% 迁移阶段不筛选Behavior，合并hit/miss后逐细胞取trial中位数，再跨选中细胞计算均值±SEM。
% 时间窗、版式沿用当前1P：cue前1 s至后3 s，12×8 cm，缩放2，图例位于左上角。

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

datasets = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
cohorts = ["12 h", "7 d"];
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
	error('Fig1H:No1s', '找不到接近cue+1 s的采样点。');
end

qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTransfer = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
Y = nan(numel(xsPlot), 2);
E = nan(numel(xsPlot), 2);
transferSignals = cell(2, 1);
activeMasks = cell(2, 1);
sampleCounts = table();
for cohortIndex = 1:numel(datasets)
	DS = datasets{cohortIndex};
	G = struct();
	G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	G.Transfer = DS.QueryNTATS(qTransfer, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	S = UniExp.NtatsCellStrip(G);
	X = iGetNtats3D(S);
	if isempty(X) || size(X, 2) ~= numel(xsSec) || size(X, 3) ~= 2
		error('Fig1H:InvalidSignals', '%s的Learned/Transfer配准数据为空或维度不匹配。', cohorts(cohortIndex));
	end
	XLearned = X(:, :, 1);
	baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
	baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
	v1 = XLearned(:, idx1s);
	activeMask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
	if ~any(activeMask)
		error('Fig1H:NoActiveCells', '%s中没有符合声水Learned活跃标准的配准细胞。', cohorts(cohortIndex));
	end
	panelNames = ["Learned"; "Transfer"];
	sampleMasks = false(size(X, 1), 2);
	for panelIndex = 1:2
		panelData = X(:, :, panelIndex);
		sampleMasks(:, panelIndex) = activeMask & any(isfinite(panelData(:, xMask)), 2);
	end
	groupCounts = TransferLearning.PanelSampleCountTable(S, panelNames, sampleMasks, DS.Cells);
	transferCounts = groupCounts(string(groupCounts.Panel) == "Transfer", :);
	sampleCounts = [sampleCounts; table(cohorts(cohortIndex), transferCounts.NMouse, transferCounts.NCell, 'VariableNames', {'Cohort', 'NMouse', 'NCell'})];
	transferData = X(activeMask, xMask, 2);
	transferSignals{cohortIndex} = transferData;
	activeMasks{cohortIndex} = activeMask;
	Y(:, cohortIndex) = mean(transferData, 1, 'omitnan')';
	E(:, cohortIndex) = std(transferData, 0, 1, 'omitnan')' / sqrt(size(transferData, 1));
end
%%
% 绘制（版式与 Fig1G 完全一致：无坐标轴、只留事件虚线 + emoji、左上标题、
% 基线左上 0.5 z / 0.5 s 比例尺、右侧手工图例并对齐 emoji 行）
f = figure('Color', 'w', 'Name', 'English Fig1H 12h vs 7d learned active transfer mean lines');
f.Units = 'centimeters';
f.Position(3:4) = [13.5, 6];

axPos = [0.095 0.055 0.560 0.870];
Ax = axes(f, 'Position', axPos);
hold(Ax, 'on');

lineColors = [TransferLearning.Color12h; TransferLearning.Color7d] / 255;
Patches = MATLAB.Graphics.MultiShadowedLines(Y, E, 0.2, X=repmat(xsPlot(:), 1, 2), EdgeColors=lineColors);

% 固定纵轴：曲线（峰值 12 h ≈ 1.23、 7 d ≈ 0.46）占中上部，上方留标题、下方留 emoji 行
yl = [-0.65 1.95];
ylim(Ax, yl);
xlim(Ax, [-1 3]);

% 事件虚线：只跨数据区，不延伸到标题 / emoji 区
yDash = [min(Y(:) - E(:)) - 0.12, max(Y(:) + E(:)) + 0.12];
plot(Ax, [0 0], yDash, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.5, 'HandleVisibility', 'off');
plot(Ax, [1 1], yDash, '--', 'Color', [0.80 0.20 0.15], 'LineWidth', 0.5, 'HandleVisibility', 'off');

% 无坐标轴：底线 / 刻度 / y 轴全部去掉
Ax.XAxis.Visible = 'off';
Ax.YAxis.Visible = 'off';
Ax.Box = 'off';
Ax.TickLength = [0 0];

% 事件 emoji（迁移阶段线索是光）
yEm = -0.47;
hEmoji = gobjects(1, 2);
hEmoji(1) = text(Ax, 0, yEm, "💡", 'FontName', 'Segoe UI Emoji', 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Clipping', 'off');
hEmoji(2) = text(Ax, 1, yEm, "💧", 'FontName', 'Segoe UI Emoji', 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Clipping', 'off');

% 比例尺：基线上方、cue 虚线左侧
iScaleBar(Ax, -1.58, 0.50, 0.5, 0.5);

% 图例：单独一个不显示的坐标区（两行）
lgPos = [0.660 0.150 0.350 0.420];
axLg = axes(f, 'Position', lgPos, 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
hold(axLg, 'on');
lgY = [0.72 0.28];
for iLg = 1:2
	plot(axLg, [0.01 0.20], [lgY(iLg) lgY(iLg)], '-', 'Color', lineColors(iLg, :), ...
		'LineWidth', 1, 'Clipping', 'off');
	text(axLg, 0.24, lgY(iLg), cohorts(iLg), 'FontSize', 6, 'Color', [0.15 0.15 0.15], ...
		'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

% 标题：左上角左对齐
axT = axes(f, 'Position', [0 0 1 1], 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
hold(axT, 'on');
text(axT, 0.062, 0.925, '🔊💧 learned active cells', 'FontName', 'Segoe UI Emoji', ...
	'FontSize', 6, 'Color', [0.10 0.10 0.10], ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

% 套统一样式，再把图例最下面一行对齐到 emoji 行
TransferLearning.Style.ApplyStandardFigureStyle(f, 3);
drawnow;
pAx = Ax.Position;
eEm = hEmoji(1).Extent;
yEmData = eEm(2) + eEm(4) / 2;
yEmFig = pAx(2) + (yEmData - yl(1)) / (yl(2) - yl(1)) * pAx(4);
axLg.Position = [lgPos(1), yEmFig - lgY(2) * lgPos(4), lgPos(3), lgPos(4)];

svgPath = TransferLearning.StandardFigureSvgPath('English_Fig1H_12hVs7d_LearnedActive_TransferMeanLines.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== Fig1H：迁移光水全部回合，不区分hit/miss ===\n');
disp(sampleCounts);

function iScaleBar(ax, x0, y0, tLen, zLen)
% 左下角的「反 L」比例尺：横 = 时间，纵 = z
col = [0.25 0.25 0.25];
xl = xlim(ax);  dx = xl(2) - xl(1);
yl = ylim(ax);  dy = yl(2) - yl(1);
plot(ax, [x0, x0 + tLen], [y0, y0], '-', 'Color', col, 'LineWidth', 0.75, ...
	'Clipping', 'off', 'HandleVisibility', 'off');
plot(ax, [x0 + tLen, x0 + tLen], [y0, y0 + zLen], '-', 'Color', col, 'LineWidth', 0.75, ...
	'Clipping', 'off', 'HandleVisibility', 'off');
% 0.5 z：竖线右侧、与竖线中点垂直居中
text(ax, x0 + tLen + 0.03 * dx, y0 + zLen / 2, sprintf('%g z', zLen), 'FontSize', 6, 'Color', col, ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Clipping', 'off');
% 0.5 s：横线下方、与横线左端对齐（偏移随纵轴跨度缩放）
text(ax, x0, y0 - 0.10 * dy, sprintf('%g s', tLen), 'FontSize', 6, 'Color', col, ...
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
error('Fig1H:BadNTATS', '不支持的NTATS容器类型：%s。', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[distance, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(distance) && distance <= tolSec;
end