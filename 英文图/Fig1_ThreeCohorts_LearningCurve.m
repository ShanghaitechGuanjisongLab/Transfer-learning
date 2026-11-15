% Fig1 三组光水学习曲线（与 Fig1_MetricBars_* 完全同一数据源）
%
% 队列：TransferLearning.BehaviorSessions.LightWaterLearningSessions（undelayed 成像队列）
%       Naive / Transfer(12 h) / 7dayTransfer(7 d)，与 bar 图逐鼠指标同源。
% 数据：TransferLearning.Metrics.LightWaterMetricData 的缓存 Sess 表
%       （Session = 每鼠按时间排序的会话序号，即 block）。
%
% 样式：每 block 跨鼠 mean ± SEM；实心圆点 + 单向（只向上）误差棒；
%       **不画拟合线**（与 Fig1B 的 sigmoid 拟合版区分）。
% 配色：与 bar 图一致 TransferLearning.ColorNaive / Color12h / Color7d。
% 尺寸：排版 45×40 mm、6 pt → 导出 90×80 mm、12 pt。
clear variables; close all;
cd('d:\git\Transfer-Learning');
%包 +TransferLearning 只在工程根目录（current folder）解析，run() 会临时切 cwd，所以显式加 path
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end

groupOrder = ["Naive", "Transfer", "7dayTransfer"];
groupLabel = ["Naive", "12 h", "7 d"];
%配色与 bar 图完全一致；useCurveColor = true 则换成曲线版（主色压黑 35%，更墨）
useCurveColor = false;
if useCurveColor
	groupColor = [TransferLearning.CurveNaive(); TransferLearning.Curve12h(); TransferLearning.Curve7d()] / 255;
else
	groupColor = [TransferLearning.ColorNaive; TransferLearning.Color12h; TransferLearning.Color7d] / 255;
end
%描边/误差棒颜色：与填充同色为纯实心点；想让点更清楚可改成 groupColor*0.8（会有一圈深描边）
nG = numel(groupOrder);
edgeColor = zeros(nG, 3);
for g = 1:nG
	edgeColor(g, :) = groupColor(g, :);
end

%% 数据（缓存；结构改动后置 ForceRebuild=true）
D = TransferLearning.Metrics.LightWaterMetricData(ForceRebuild = false);
Sess = D.Sess;

nG = numel(groupOrder);
X = cell(nG, 1); MU = cell(nG, 1); SEM = cell(nG, 1);
maxBlock = 7;   %只显示前 maxBlock 个 block（三组都适用；设 Inf 则全画）
fprintf('\n=== 三组光水学习曲线（mean±SEM，跳鼠，block 1–%d）===\n', maxBlock);
for g = 1:nG
	S = Sess(string(Sess.Group) == groupOrder(g), :);
	b = double(S.Session);
	p = double(S.Performance);
	ok = isfinite(b) & isfinite(p) & b >= 1 & b <= maxBlock;
	b = b(ok);
	p = p(ok);
	ub = unique(b);
	MU{g} = zeros(numel(ub), 1);
	SEM{g} = zeros(numel(ub), 1);
	for k = 1:numel(ub)
		v = p(b == ub(k));
		MU{g}(k) = mean(v);
		SEM{g}(k) = std(v) / sqrt(numel(v));
		fprintf('      block %2d: n=%2d  mean=%.3f  sem=%.3f\n', ub(k), numel(v), MU{g}(k), SEM{g}(k));
	end
	X{g} = ub;
	fprintf('  %-13s 鼠 %2d，block 1–%d\n', groupOrder(g), ...
		numel(unique(string(S.Mouse))), max(ub));
end

%% 统计：两两 two-way ANOVA（Group × Block，block 1–maxBlock）
%因变量为逐鼠逐 block 的命中率；组效应 p 取自 anovan（mouse 未作为随机效应建模，
%与 Fig61B 既有的「two-way ANOVA Group P (blocks 1-7)」口径一致）。
Tb = table();
for g = 1:nG
	S = Sess(string(Sess.Group) == groupOrder(g), :);
	b = double(S.Session);
	p = double(S.Performance);
	m = string(S.Mouse);
	ok = isfinite(b) & isfinite(p) & b >= 1 & b <= maxBlock;
	Tb = [Tb; table(repmat(groupOrder(g), nnz(ok), 1), m(ok), b(ok), p(ok), ...
		'VariableNames', {'Group', 'Mouse', 'Block', 'Y'})]; %#ok<AGROW>
end
pairIdx = [1 2; 1 3; 2 3];
pGroup = nan(3, 1);
fprintf('\n=== 两两 two-way ANOVA（Group × Block）===\n');
for k = 1:3
	Q = Tb(ismember(Tb.Group, groupOrder(pairIdx(k, :))), :);
	panova = anovan(Q.Y, {categorical(Q.Group), Q.Block}, 'Model', 'interaction', ...
		'display', 'off', 'varnames', {'Group', 'Block'});
	pGroup(k) = panova(1);
	fprintf('  %-13s vs %-13s Group p=%.4g  交互 p=%.4g  (n=%d)\n', ...
		groupOrder(pairIdx(k, 1)), groupOrder(pairIdx(k, 2)), ...
		panova(1), panova(3), height(Q));
end

%% 画图
figScale = 2;          %导出倍率：90×80 mm、12 pt → 排版缩 1/2 得 45×40 mm、6 pt
figWmm = 45;           %排版宽度（mm），用于把点/误差棒尺寸固定成物理尺寸
figHmm = 40;
f = figure('Color', 'w', 'Name', 'Fig1 three cohorts learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [figWmm, figHmm] / 10 * figScale;
ax = axes(f, 'Position', [0.18 0.19 0.79 0.75]);
hold(ax, 'on');

%点大小：样式会把所有 LineWidth 设为 1 pt（导出 12 pt 体系下 2 pt），
%而 marker 的描边宽度也走 LineWidth，所以点要开得比线宽大一截才不会被描边吃掉
markerSize = 8;   %pt（导出尺寸）→ 排版后约 4 pt、直径 ≈1.4 mm
hPt = gobjects(nG, 1);
for g = 1:nG
	%绘制顺序：连接线在最下、误差棒居中、实心点在最上
	plot(ax, X{g}, MU{g}, '-', 'Color', groupColor(g, :), 'LineWidth', 1, 'Tag', 'connLine');
	iErrorBar(ax, X{g}, MU{g}, SEM{g}, groupColor(g, :), figWmm);
	hPt(g) = plot(ax, X{g}, MU{g}, 'o', 'LineStyle', 'none', 'Tag', 'dataPt', ...
		'MarkerSize', markerSize, 'MarkerFaceColor', groupColor(g, :), ...
		'MarkerEdgeColor', 'none');
end

%图右侧显著性：「工」字形括号 + 星号
%只标指定的比较：1 = Naive vs 12 h，2 = Naive vs 7 d，3 = 12 h vs 7 d
annotPairs = 1;
sigK = annotPairs(pGroup(annotPairs) < 0.05);
armLen = 0.75;     %横线长度：左端正好落在最后一个 block，紧贴要对比的两条曲线末端
stubLen = 0.10;    %竖线右侧的小出头
xlimRight = maxBlock + 0.75 + stubLen + 0.30;
ax.XLim = [0.4, xlimRight];   %右侧留出显著性标记的位置
ax.XTick = 1:maxBlock;   %每个 block 都标刻度（block 是整数序号）
ax.YLim = [0, 1.05];   %顶部留余量，免得命中率 1.0 的点与横帽压在边框上
xlabel(ax, 'Block');
ylabel(ax, 'Hit rate');
ax.FontSize = 6;
ax.LineWidth = 0.5;
box(ax, 'off');
grid(ax, 'off');

for i = 1:numel(sigK)
	k = sigK(i);
	xk = maxBlock + 0.75 + 0.55 * (i - 1);
	%两道横线的高度用被比较两组【各自曲线的末端值】，这样横线正对着要对比的那两条线
	ya = MU{pairIdx(k, 1)}(end);
	yb = MU{pairIdx(k, 2)}(end);
	yLo = min(ya, yb);
	yHi = max(ya, yb);
	xArmL = xk - armLen;         %向左伸到最后一个 block 附近
	xArmR = xk + stubLen;
	%一条折线画完「上横 — 竖线 — 下横」，保证三段线宽一致
	plot(ax, [xArmL, xArmR, xk, xk, xArmL, xArmR], ...
		[yHi, yHi, yHi, yLo, yLo, yLo], '-', 'Color', [0 0 0], 'LineWidth', 1);
	%星号放在竖线左侧（工字的开口里），竖向居中于两道横线之间
	text(ax, xk - 0.12, (yLo + yHi) / 2, ...
		string(TransferLearning.Style.iFormatPStars(pGroup(k))), ...
		'FontSize', 6, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
		'Color', [0 0 0]);
end

lg = legend(ax, hPt, cellstr(groupLabel), 'Location', 'southeast', 'NumColumns', 1);
lg.Box = 'off';

iExactPaper(f, figWmm / 10 * figScale, figHmm / 10 * figScale);
%先上标准样式（所有线宽会被统一成 1 pt），再单独把误差棒调细到 0.5 pt
TransferLearning.ApplyStandardExportStyle(f, figScale);
set(findall(f, 'Type', 'line', '-regexp', 'Tag', '^errBar'), 'LineWidth', 0.5 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig1_ThreeCohorts_LearningCurve.svg');
print(f, svgPath, '-dsvg');
fprintf('\nWrote: %s\n', svgPath);

%% ---------------------------------------------------------------
function iErrorBar(ax, x, y, e, col, figWmm)
%mean±SEM 对称误差棒（竖线 + 上下两个横帽）。
%不用 errorbar 的原因：CapSize 以点为单位、不随字号/画布缩放，导出 12 pt 时会过短
%. 且宽度无法直接按 mm 控制。
drawnow;
apx = getpixelposition(ax);
fpx = getpixelposition(ancestor(ax, 'figure'));
xSpan = diff(ax.XLim);
axesWmm = apx(3) / fpx(3) * figWmm;
capHalf = 0.60 * xSpan / axesWmm;   %横帽半宽（mm）→ 总宽 ≈ 1.2 mm
lw = 1;
for k = 1:numel(x)
	if ~(e(k) > 0)
		continue;   %SEM=0 时横帽会正好压在点上，看起来像一条粗线，干脆不画
	end
	yLo = y(k) - e(k);
	yHi = y(k) + e(k);
	%一条折线画完「上横—竖线—下横」：保证三段线宽完全一致
	%（分三条画时，横帽会被渲染得比竖线粗；只给 4 点时横帽会只剩半边）
	xs = [x(k) - capHalf, x(k) + capHalf, x(k), x(k), x(k) - capHalf, x(k) + capHalf];
	ys = [yHi, yHi, yHi, yLo, yLo, yLo];
	plot(ax, xs, ys, '-', 'Color', col, 'LineWidth', lw, 'Tag', 'errBar');
end
end

function iExactPaper(f, wCm, hCm)
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end
