% Fig1 指标两两对比｜三指标 × 两比较的 2×3 面板 + 12 h vs 7 d 三张独立小图
%
% 指标（口径同 Fig1_MetricBars_ThreeGroups.m）：
%   1  First block：首位光水 block 命中率
%   2  Blocks to 50%：达 50% 命中率的 block（相邻两点线性插值）
%   3  Sigmoid slope：**【逐 trial 惩罚版】** 每鼠全部 LightWater trial 的 0/1 作二项似然，
%      会话序号作 block，TransferLearning.FitPenalizedSigmoid(FixLowerZero=true)
%      → 下限固定 0、上限固定 1，斜率与中点自由（log-odds/block）
%      封装：TransferLearning.Metrics.TrialLevelSlopePerMouse
%
% 版式（《英文图规范》）：
%   排版尺寸统一 18×40 mm、6 pt → 导出 36×80 mm、12 pt（缩 1/2 正好命中）
%   图 A（3 张）：上下列叠放 = 上行 Naive vs 12 h、下行 Naive vs 7 d，单指标一张，
%                 两行共用同一 Y 限制，Y 轴标题整列居中共用
%   图 B（3 张）：12 h vs 7 d 单指标，同尺寸 18×40 mm
%   x 轴刻度即比较对象；Scale 2（导出 12 pt）
%   bar 无边框、与误差棒同色；误差棒只向上，且手绘（errorbar 会在柱顶多画一条横帽）
%   P 值线用 MATLAB.Graphics.PLine（导出时自动 PLineRetune），显著性用星号
%
% 配色：TransferLearning.ColorNaive / Color12h / Color7d（0–255 → /255）
clear variables; close all;
cd('d:\git\Transfer-Learning');
%包 +TransferLearning 只在工程根目录（current folder）解析，run() 会临时切 cwd，所以显式加 path
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

gName = ["Naive", "Transfer", "7dayTransfer"];
%12 pt 导出（画布 30 mm 宽）：标签去空格、柱间距拉大，否则两组标签会相撞
gLabel = ["Naive", "12h", "7d"];
cNaive = TransferLearning.ColorNaive / 255;
c12h = TransferLearning.Color12h / 255;
c7d = TransferLearning.Color7d / 255;

%% 数据（优先读缓存；数据结构改动后置 ForceRebuild=true 重建）
ForceRebuild = false;
D = TransferLearning.Metrics.LightWaterMetricData(ForceRebuild = ForceRebuild);
Sess = D.Sess;
Summ = D.Summ;
% 逐 trial 惩罚 sigmoid（下限 0、上限 1）；Group | Mouse | NBlocks | NTrials | Slope | AtSlopeBoundary
Slope = D.Slope;
fprintf('\n=== 逐 trial 惩罚 sigmoid 斜率（%d 只鼠）===\n', height(Slope));
for g = unique(Slope.Group, 'stable').'
	fprintf('  %-13s n=%2d  斜率均值 %.3f  停在斜率上界的 %d 只\n', g, ...
		nnz(Slope.Group == g), mean(Slope.Slope(Slope.Group == g)), nnz(Slope.Group == g & Slope.AtSlopeBoundary));
end

metricTitle = ["First block", "Blocks to 50%", "Sigmoid slope"];
metricYlab = ["Hit rate", "Blocks to 50%", "Sigmoid slope"];
M = {double(Summ.FirstPerf), double(Summ.BlocksToHalf), double(Slope.Slope)};
G = {string(Summ.Group), string(Summ.Group), string(Slope.Group)};

% 每组每个指标的样本（去掉 NaN）
V = cell(3, 3);
for m = 1:3
	for k = 1:3
		v = M{m}(G{m} == gName(k));
		V{m, k} = v(isfinite(v));
	end
end

% 三对比较的秩和 p
pairName = ["Naive vs 12 h", "Naive vs 7 d", "12 h vs 7 d"];
pairIdx = {[1 2], [1 3], [2 3]};
P = nan(3, 3);   % metric × pair
fprintf('\n=== 两两比较（双侧秩和）===\n');
for m = 1:3
	fprintf('\n[%s]\n', metricTitle(m));
	for k = 1:3
		ij = pairIdx{k};
		P(m, k) = iRS(V{m, ij(1)}, V{m, ij(2)});
		fprintf('  %-13s n=%2d (%.3f±%.3f)  vs  %-13s n=%2d (%.3f±%.3f)   p = %.4g\n', ...
			gName(ij(1)), numel(V{m, ij(1)}), mean(V{m, ij(1)}), iSEM(V{m, ij(1)}), ...
			gName(ij(2)), numel(V{m, ij(2)}), mean(V{m, ij(2)}), iSEM(V{m, ij(2)}), P(m, k));
	end
end

%% 统一 Y 轴上限（同一指标的三个比较共用，便于跨比较对照）
topAll = zeros(3, 1);
for m = 1:3
	top = 0;
	for k = 1:3
		ij = pairIdx{k};
		top = max([top, mean(V{m, ij(1)}) + iSEM(V{m, ij(1)}), ...
			mean(V{m, ij(2)}) + iSEM(V{m, ij(2)})]);
	end
	topAll(m) = top * 1.75;   %留足 P 值括号 + 星号的位置，避免星号被顶到框外
end

%% 出图
% 图 A（3 张）：每个指标一张竖列图，3×8 cm = 上行 Naive vs 12 h / 下行 Naive vs 7 d，
%   两行共用同一 Y 轴上限，上下直接可比；Y 轴标题在整列居中共享
% 图 B（3 张）：12 h vs 7 d 仍为单指标 3×4 cm 小图
metricTag = ["FirstBlock", "BlocksTo50", "SigmoidSlope"];
pairCols = {[cNaive; c12h], [cNaive; c7d], [c12h; c7d]};
%目标排版尺寸 18×40 mm、6 pt → 导出 36×80 mm、12 pt，排版时缩到 1/2 正好命中
fontScale = 2;
figW = 1.8;   %cm，排版宽度（最终 18 mm）
figH = 4.0;   %cm，排版高度（最终 40 mm）
%轴矩形（归一化）：所有图统一，保证绘图区宽度一致 → 柱宽/x 轴标签间距一致
iAxesRectTop = [0.42 0.60 0.56 0.34];
iAxesRectBot = [0.42 0.13 0.56 0.34];
%试版开关：false = 全出（竖列 3 张 + 12h vs 7d 3 张）
previewOnly = false;
previewMetric = 3;   %previewOnly=true 时只出这一张（1=First block, 2=Blocks to 50%, 3=Sigmoid slope）
if previewOnly
	metricLoopA = previewMetric;
else
	metricLoopA = 1:3;
end
fprintf('\n=== 图 A：Naive vs 12 h（上）/ Naive vs 7 d（下）竖列，排版 %.0f×%.0f mm，导出 %.0f×%.0f mm、字号 %.0f pt ===\n', ...
	figW * 10, figH * 10, figW * 10 * fontScale, figH * 10 * fontScale, 6 * fontScale);
for m = metricLoopA
	f = figure('Color', 'w', 'Name', sprintf('NaiveVs12h_over_NaiveVs7d_%s', metricTag(m)));
	f.Units = 'centimeters';
	f.Position(3:4) = [figW figH] * fontScale;
	%不用 tiledlayout：它的绘图区宽度会随 Y 轴刻度标签/标题长度变化，
	%导致不同指标之间柱宽、x 轴标签间距都不一致。这里固定轴矩形。
	axTop = axes(f, 'Position', iAxesRectTop);
	axBot = axes(f, 'Position', iAxesRectBot);
	ij = pairIdx{1};
	iBarPair(axTop, V{m, ij(1)}, V{m, ij(2)}, pairCols{1}, gLabel(ij), P(m, 1), '', topAll(m));
	ij = pairIdx{2};
	iBarPair(axBot, V{m, ij(1)}, V{m, ij(2)}, pairCols{2}, gLabel(ij), P(m, 2), '', topAll(m));
	%PLine 会把需要空间的哪一格 YLim 描高；取两格较大者统一，保证刻度一致且括号/星号在框内
	yBoth = max(axTop.YLim(2), axBot.YLim(2));
	axTop.YLim = [0 yBoth];
	axBot.YLim = [0 yBoth];
	%整列共享的 Y 轴标题（旋转 90°，垂直居中于整张图）
	%用轴内 text 而不是 annotation：annotation 的 textbox 旋转 90° 后 print 不显示
text(axBot, -0.62, 1.09, string(metricYlab(m)), 'Units', 'normalized', ...
		'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
		'FontSize', 6, 'Clipping', 'off');
	iExactPaper(f, figW * fontScale, figH * fontScale);
	%先应用标准样式（字号/线宽），再校正柱宽，最后 print：
	%否则样式改字体 → tiledlayout 又重排一次，柱宽会再次跑偏
	exportName = sprintf('English_Fig1_MetricBars_NaiveVs12hOverNaiveVs7d_%s.svg', metricTag(m));
	TransferLearning.ApplyStandardExportStyle(f, fontScale);
	iFixBarWidths(f, figW * 10, 1 * fontScale);
	svgPath = TransferLearning.StandardFigureSvgPath(exportName);
	print(f, svgPath, '-dsvg');
	fprintf('Wrote: %s\n', svgPath);
end
if previewOnly
	return;
end

fprintf('\n=== 图 B：12 h vs 7 d 单指标，排版 3×4 cm，导出 %.0f×%.0f cm、字号 %.0f pt ===\n', ...
	3 * fontScale, 4 * fontScale, 6 * fontScale);
ij = pairIdx{3};
for m = 1:3
	f = figure('Color', 'w', 'Name', sprintf('12hVs7d_%s', metricTag(m)));
	f.Units = 'centimeters';
	f.Position(3:4) = [3 4] * fontScale;
	%用 tiledlayout 而不是固定 Position：字号加大时它会自动让出轴标题的位置
	t = tiledlayout(f, 1, 1, 'Padding', 'loose');
	ax = nexttile(t);
	iBarPair(ax, V{m, ij(1)}, V{m, ij(2)}, pairCols{3}, gLabel(ij), P(m, 3), metricYlab(m), topAll(m));
	iExactPaper(f, 3, 4);
	exportName = sprintf('English_Fig1_MetricBars_12hVs7d_%s.svg', metricTag(m));
	TransferLearning.ApplyStandardExportStyle(f, fontScale);
	iFixBarWidths(f, 30, 1 * fontScale);
	svgPath = TransferLearning.StandardFigureSvgPath(exportName);
	print(f, svgPath, '-dsvg');
	fprintf('Wrote: %s\n', svgPath);
end

%% ---------------------------------------------------------------
function iFixBarWidths(f, figWmm, lw)
%柱宽/横帽按【物理 mm】固定，而不是数据单位。
%不同指标的 Y 轴标题长度不同 → tiledlayout 留的左边距不同 → 绘图区宽度不同，
%若用固定数据单位宽度，换来的物理柱宽就不一样（Hit rate 那张会明显更粗）。
%必须在【标准样式已应用、print 之前】调用：样式会改字号并触发 tiledlayout 重排。
iAxesLeft = 0.44;    %所有图统一：左边距占比
iAxesWidth = 0.52;   %所有图统一：绘图区宽度占比
drawnow;
fpx = getpixelposition(f);
xSpan = 2;          %xlim 跨度
barWmm = 3.0;       %柱宽（mm）
capHalfMm = 0.95;   %横帽半宽（mm）→ 总宽 ≈ 1.9 mm
%先把每个轴固定成同一个矩形：不同指标 Y 轴刻度标签宽度不同（0.0 vs 3）会让
%tiledlayout 给出不同绘图区宽度，不仅柱宽不一致，x 轴标签也会在窄的那张里撞车。
for ax = findall(f, 'Type', 'axes').'
	p = ax.Position;
	ax.Position = [iAxesLeft, p(2), iAxesWidth, p(4)];
end
drawnow;
for ax = findall(f, 'Type', 'axes').'
	apx = getpixelposition(ax);
	axesWmm = apx(3) / fpx(3) * figWmm;
	%重设柱宽
	set(findall(ax, 'Type', 'bar'), 'BarWidth', barWmm * xSpan / axesWmm);
	%重绘误差棒（横帽宽度按新测量值；样式已经跑过，所以线宽要自己给）
	delete(findall(ax, 'Type', 'line', '-regexp', 'Tag', '^barWhisker|^barCap'));
	D = getappdata(ax, 'BarPairData');
	iDrawErrorBars(ax, D.y, D.e, D.cols, capHalfMm * xSpan / axesWmm, lw);
end
drawnow;
end

function iDrawErrorBars(ax, y, e, cols, capHalf, lw)
%单向误差棒（只向上）。不用 errorbar 的原因：
%  a) 下误差给 0 时 errorbar 会在柱顶多画一条横帽（多余的横线）
%  b) CapSize 以点为单位、不随字号/画布缩放，导出 12 pt 时横帽显得过短
if nargin < 6
	lw = 1;
end
for k = 1:2
	yTopBar = y(k) + e(k);
	%3 点（末两点重合）避开 Style 对「两点轴向线」的轴宽处理，线宽自己给
	plot(ax, [k k k], [y(k) yTopBar yTopBar], '-', 'Color', cols(k, :), ...
		'LineWidth', lw, 'Tag', 'barWhisker');
	plot(ax, [k - capHalf, k, k + capHalf], [yTopBar yTopBar yTopBar], '-', ...
		'Color', cols(k, :), 'LineWidth', lw, 'Tag', 'barCap');
end
end

function iExactPaper(f, wCm, hCm)
%固定画布尺寸：print 的 PaperPositionMode='auto' 会在小图上额外加边距
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end

function iBarPair(ax, va, vb, cols, grpLabels, pVal, ylab, yTop)
hold(ax, 'on');
y = [mean(va), mean(vb)];
e = [iSEM(va), iSEM(vb)];
h = bar(ax, 1:2, y, 0.5, 'FaceColor', 'flat');   %宽度先给占位值，最后由 iFixBarWidths 统一校正
h.CData = cols;
h.EdgeColor = 'none';
h.LineWidth = 0.5;
%DONE 误差棒先按占位宽度画，打上 Tag，布局定型后由 iFixBarWidths 重绘
setappdata(ax, 'BarPairData', struct('y', y, 'e', e, 'cols', cols));
iDrawErrorBars(ax, y, e, cols, 0.16);
ax.XTick = 1:2;
ax.XTickLabel = cellstr(grpLabels);
ax.XTickLabelRotation = 0;   %字号加大后不让 MATLAB 自动斜排
ax.FontSize = 6;
ax.LineWidth = 0.5;
xlim(ax, [0.5 2.5]);   %柱子左右各留 0.25 数据单位，不贴 y 轴/右边框
ylabel(ax, ylab);
% 同一指标的子图共用 Y 轴范围（ylim 必须在 PLine 之前定好）
ax.YLim = [0, yTop];
% 用一个不可见的两点 errorbar 作为定位对象，PLine 会按误差条顶端放线
EB = errorbar(ax, 1:2, y, [0 0], e, 'LineStyle', 'none', 'Color', 'none', 'CapSize', 0.01);
D = table(repmat(EB, 1, 1), repmat(EB, 1, 1), 1, 2, ...
	string(TransferLearning.Style.iFormatPStars(pVal)), ...
	'VariableNames', ["ObjectA", "ObjectB", "IndexA", "IndexB", "Text"]);
MATLAB.Graphics.PLine(D);
%PLine 默认把文字垂直居中压在括号线上（"*" 的字形偏上所以看不出，n.s. 就会压线）
%这里把 P 值文字改成底对齐，让文字整个落在线上方
tx = findall(ax, 'Type', 'text');
if ~isempty(tx)
	set(tx, 'VerticalAlignment', 'bottom');
end
box(ax, 'off');
end

function p = iRS(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function s = iSEM(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end
