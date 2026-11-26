% Fig1C_MetricBars_PairwiseBars.m —— 1C：按「指标」分组输出
%
%   图（40 × 80 mm）：每个指标一张，Naive vs 12h（上）与 Naive vs 7d（下）上下叠放，共享 y 轴范围与居中 y 轴标题
%   指标：First block hit rate / Blocks to 50% / Learning speed（= 原 Sigmoid slope）
%
% 样式：bar 无边框 + 单向手绘误差棒（压在散点之上）+ 逐鼠散点（点色 = 柱色，细描边）
%       + 括号上的数值 p（不显著写 n.s.）。
%
% 输出：English_Fig1C_<Metric>_NaiveVs12h_NaiveVs7d.svg


gName  = ["Naive", "Transfer", "7dayTransfer"];
gLabel = ["Naive", "12h", "7d"];
groupColors = [TransferLearning.ColorNaive; TransferLearning.Color12h; TransferLearning.Color7d] / 255;

D = TransferLearning.Metrics.LightWaterMetricData(ForceRebuild = false);
Summ = D.Summ;
Slope = D.Slope;

metricTag = ["FirstBlockHitRate", "BlocksTo50", "LearningSpeed"];
metricYlab = ["First block hit rate", "Blocks to 50%", "Learning speed"];
M = {double(Summ.FirstPerf), double(Summ.BlocksToHalf), double(Slope.Slope)};
G = {string(Summ.Group), string(Summ.Group), string(Slope.Group)};

pairTag   = ["NaiveVs12h", "NaiveVs7d", "12hVs7d"];
pairIdx   = {[1 2], [1 3], [2 3]};

fprintf('\n=== 1C 两柱对比图（按指标分组输出） ===\n');
% A 图：Naive vs 12h（上）｜ Naive vs 7d（下）上下叠放，40 × 80 mm
aW = 4.0;  aH = 8.0;
%% 

for m = 1:3
	vN  = M{m}(G{m} == gName(1));  vN = vN(isfinite(vN));
	v12 = M{m}(G{m} == gName(2));  v12 = v12(isfinite(v12));
	v7  = M{m}(G{m} == gName(3));  v7 = v7(isfinite(v7));
	pvN12 = iRS(vN, v12);
	pvN7  = iRS(vN, v7);
	pv127 = iRS(v12, v7);
	fprintf('%-18s N/12h n=%2d/%2d p=%.4g | N/7d n=%2d/%2d p=%.4g | 12h/7d n=%2d/%2d p=%.4g\n', ...
		metricTag(m), numel(vN), numel(v12), pvN12, numel(vN), numel(v7), pvN7, ...
		numel(v12), numel(v7), pv127);

	% ---------- A：Naive vs 12h ｜ Naive vs 7d（并排，共用一个 y 轴范围与括号高度） ----------
	sets = {{vN, v12, groupColors([1 2], :), gLabel([1 2]), pvN12}, ...
	        {vN, v7,  groupColors([1 3], :), gLabel([1 3]), pvN7}};
	yBr = 0;
	for j = 1:2
		yBr = max(yBr, iBracketY(sets{j}{1}, sets{j}{2}));
	end
	outA = sprintf('English_Fig1C_%s_NaiveVs12h_NaiveVs7d', metricTag(m));
	f = iNewFig(aW, aH, outA);
	Layout = tiledlayout(f, 2, 1, TileSpacing='compact', Padding='compact');
	TileAxes = gobjects(1, 2);
	hT = gobjects(1, 2);
	for j = 1:2
		axm = nexttile(Layout, j);
		TileAxes(j) = axm;
		hT(j) = iMetricBar(axm, sets{j}{1}, sets{j}{2}, sets{j}{3}, sets{j}{4}, sets{j}{5}, "", yBr);
	end
	MATLAB.Graphics.UnifyAxesLims(TileAxes(:), @xlim, @ylim);
	% 统一字体/线宽；散点尺寸与描边宽度自己控制，不被覆盖
	TransferLearning.Style.ApplyStandardFigureStyle(f, 2, PreserveScatterStyle = true);
	% 共享 y 轴标题：Layout 级（两个 tile 的 y 范围已统一，标题即整列垂直居中）
	ylabel(Layout, metricYlab(m));
	svgPath = TransferLearning.StandardFigureSvgPath([outA '.svg']);
	print(f, svgPath, '-dsvg');
	fprintf('Wrote: %s\n', svgPath);
end

%% ================= 局部函数 =================
function f = iNewFig(w, h, nm)
f = figure('Color', 'w', 'Name', nm);
f.Units = 'centimeters';
f.Position(3:4) = [w h];
f.PaperUnits = 'centimeters';
f.PaperSize = [w h];
f.PaperPosition = [0 0 w h];
f.PaperPositionMode = 'manual';
end

function yBr = iBracketY(v1, v2)
y = [mean(v1), mean(v2)];
e = [iSEM(v1), iSEM(v2)];
yHi = max([y(:) + e(:); v1(:); v2(:)]);
yBr = yHi * 1.07;
end

function hTxt = iMetricBar(ax, v1, v2, cols, labels, pv, ylab, yBr)
hold(ax, 'on');
vals = {v1(:), v2(:)};

y = [mean(vals{1}), mean(vals{2})];
e = [iSEM(vals{1}), iSEM(vals{2})];
for k = 1:2
	bar(ax, k, y(k), 0.50, 'FaceColor', cols(k, :), 'EdgeColor', 'none');
	% 逐鼠散点：填充 = 柱色稍加深（HSV 只降明度，保持色相；避免与柱色重合看起来像空心圈）
	jit = (rand(numel(vals{k}), 1) - 0.5) * 0.20;
	scatter(ax, k + jit, vals{k}, 3.8, 'o', 'filled', ...
		'MarkerFaceColor', iDark(cols(k, :), 0.80), ...
		'MarkerEdgeColor', iDark(cols(k, :), 0.55), 'LineWidth', 0.15, 'HandleVisibility', 'off');
	% 单向误差棒：直接压在散点之上（不加白色光晕）
	cErr = iDark(cols(k, :), 0.50);
	plot(ax, [k k], [y(k), y(k) + e(k)], '-', 'Color', cErr, ...
		'LineWidth', 0.6, 'HandleVisibility', 'off');
	plot(ax, [k - 0.07, k + 0.07], [y(k) + e(k), y(k) + e(k)], '-', 'Color', cErr, ...
		'LineWidth', 0.6, 'HandleVisibility', 'off');
end

ax.XTick = 1:2;
ax.XTickLabel = cellstr(labels);
ax.XTickLabelRotation = 0;
xlim(ax, [0.4 2.6]);
% 括号放在「柱顶 + SEM」与「最高散点」两者之上，避免与散点相撞
ylim(ax, [0, yBr * 1.28]);
if strlength(string(ylab)) > 0
	ylabel(ax, ylab, 'FontSize', 6);
end
ax.FontSize = 6; ax.LineWidth = 0.5; box(ax, 'off'); grid(ax, 'off');

plot(ax, [1 2], [yBr yBr], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5, 'HandleVisibility', 'off');
hTxt = text(ax, 1.5, yBr * 1.02, ['  ' iFmtP(pv)], 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'FontSize', 5.5, 'Color', [0.2 0.2 0.2], 'HandleVisibility', 'off');
end

function p = iRS(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function s = iSEM(x)
x = double(x(:)); x = x(isfinite(x));
if isempty(x), s = NaN; else, s = std(x) / sqrt(numel(x)); end
end

function s = iFmtP(p)
% 显著→数值 p；不显著→n.s.
if ~isfinite(p) || p >= 0.05
	s = 'n.s.';
elseif p < 1e-3
	s = 'p < 0.001';
else
	s = sprintf('p = %.3f', p);
end
end

function c = iDark(rgb, vMul)
% 同色系派生色：只按 vMul 降明度，不动色相与饱和度
h = rgb2hsv(rgb);
h(3) = h(3) * vMul;
c = hsv2rgb(h);
end
