% Fig1C_PPT_MetricBars_PairwiseBars.m —— 1C 的 PPT 版（每个子图单独出一张图）
%
%   与 Fig1C_MetricBars_PairwiseBars.m 同一数据/同一画法，区别只有版式：
%     - 原版把「Naive vs 12h」与「Naive vs 7d」上下叠在 1 张图里，12h vs 7d 另出 1 张；
%     - 本版把 Naive-12h / Naive-7d / 12h-7d **三个比较各自单独输出**，全部用同一画布 30 × 40 mm。
%   指标：First block hit rate / Blocks to 50% / Learning speed（= 原 Sigmoid slope）
%   字号：统一 6 pt（ApplyStandardFigureStyle 的 Scale = 1）
%
%   每个比较各自按本面板数据定 y 轴上限（单图独立可读），不跨面板共用 —— 原版叠放时共用是为了上下可比。
%
% 输出：English_Fig1C_PPT_<Metric>_NaiveVs12h.svg
%       English_Fig1C_PPT_<Metric>_NaiveVs7d.svg
%       English_Fig1C_PPT_<Metric>_12hVs7d.svg

clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

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

pairTag = ["NaiveVs12h", "NaiveVs7d", "12hVs7d"];

% 单图统一画布：30 × 40 mm
bW = 3.0;  bH = 4.0;
axPos = [0.240 0.200 0.700 0.660];

fprintf('\n=== 1C PPT 版：三个比较各自单独输出（6 pt） ===\n');
for m = 1:3
	vN  = M{m}(G{m} == gName(1));  vN = vN(isfinite(vN));
	v12 = M{m}(G{m} == gName(2));  v12 = v12(isfinite(v12));
	v7  = M{m}(G{m} == gName(3));  v7 = v7(isfinite(v7));

	sets = {{vN,  v12, groupColors([1 2], :), gLabel([1 2]), iRS(vN, v12)}, ...
	        {vN,  v7,  groupColors([1 3], :), gLabel([1 3]), iRS(vN, v7)}, ...
	        {v12, v7,  groupColors([2 3], :), gLabel([2 3]), iRS(v12, v7)}};

	for j = 1:3
		fprintf('%-18s %-12s n=%2d/%2d p=%.4g\n', ...
			metricTag(m), pairTag(j), numel(sets{j}{1}), numel(sets{j}{2}), sets{j}{5});

		outName = sprintf('English_Fig1C_PPT_%s_%s', metricTag(m), pairTag(j));
		f = iNewFig(bW, bH, outName);
		ax = axes(f, 'Position', axPos);
		iMetricBar(ax, sets{j}{1}, sets{j}{2}, sets{j}{3}, sets{j}{4}, sets{j}{5}, ...
			metricYlab(m), iBracketY(sets{j}{1}, sets{j}{2}));
		% 6 pt 字号 + 标准线宽（散点尺寸/描边自己控制，不被覆盖）
		TransferLearning.Style.ApplyStandardFigureStyle(f, 1, PreserveScatterStyle = true);
		svgPath = TransferLearning.StandardFigureSvgPath([outName '.svg']);
		print(f, svgPath, '-dsvg');
		fprintf('Wrote: %s\n', svgPath);
		close(f);
	end
end

%% ================= 局部函数（与 Fig1C_MetricBars_PairwiseBars 一致） =================
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
	% 逐鼠散点：填充 = 柱色稍加深（HSV 只降明度，保持色相）
	jit = (rand(numel(vals{k}), 1) - 0.5) * 0.20;
	scatter(ax, k + jit, vals{k}, 3.8, 'o', 'filled', ...
		'MarkerFaceColor', iDark(cols(k, :), 0.80), ...
		'MarkerEdgeColor', iDark(cols(k, :), 0.55), 'LineWidth', 0.15, 'HandleVisibility', 'off');
	% 单向误差棒：直接压在散点之上
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
	'VerticalAlignment', 'bottom', 'FontSize', 6, 'Color', [0.2 0.2 0.2], 'HandleVisibility', 'off');
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
