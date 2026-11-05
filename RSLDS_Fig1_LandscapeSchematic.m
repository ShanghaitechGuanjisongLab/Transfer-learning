% rSLDS 分析 图 1（示意图）：Naive vs Transfer 的状态空间景观切片
%
% 1) 依赖
%    - MATLAB R2023b
%    - 本项目 +TransferLearning 包（TransferLearning.NaiveColor / TransferColor /
%      ExportStandardFigure），无需任何工具箱。
%
% 2) 前置
%    - 无。本图为**纯示意图**，用解析势能函数演示"迁移塑造景观"的几何直觉，
%      不依赖 rSLDS 拟合结果、不依赖任何 .mat 数据库。
%    - 待 rSLDS 拟合完成后，可将本图的等高面替换为数据驱动切片（同版式）。
%
% 3) 图注
%    图 1 | 迁移学习把"状态空间景观"预先塑形（示意）。线索（黑色箭头）把群体状态从
%    "抑制舔水"推过势垒；随后**同一组**线索前状态（y 方向等间距）在两个景观上向下游
%    演化：(A) Naive 组势垒低、谷宽，各条轨迹保持自身横向偏移 → 扇形分叉（散度大）；
%    (B) Transfer 组势垒高、谷窄，轨迹被汇入同一通道 → 平行（散度小）。
%    x 轴为动作轴（-1 = 抑制舔水 withhold，+1 = 触发舔水 lick），y 轴为漂移轴；
%    DeltaV 为势垒高度（相对较低的谷底）。
%    Figure 1 | Prior learning pre-shapes the population landscape (schematic). A cue
%    (black arrow) pushes the state past the barrier; the same set of pre-cue states
%    (evenly spaced along y) then evolves under two landscapes. (A) In the naive group
%    the barrier is low and the valley broad, so trajectories retain their lateral
%    offset and splay out (high divergence). (B) After transfer learning the barrier is
%    high and the valley narrow, so trajectories are funnelled into a single channel and
%    run parallel (low divergence). x, action axis; y, drift axis.
%
% 4) 作图代码

% ---- 可调参数 ----
specs = [ ...
	builtin('struct', 'Title', "Naive",    'Color', TransferLearning.NaiveColor,    'Alpha', 1.00, 'Gamma', 0.05, 'Delta', -0.15)
	builtin('struct', 'Title', "Transfer", 'Color', TransferLearning.TransferColor, 'Alpha', 2.20, 'Gamma', 2.00, 'Delta', -0.15)
];
xLim = [-1.60, 1.60];
yLim = [-1.40, 1.40];
levels = 0.25:0.25:2.00;
startX = 0.05;
startYs = linspace(-1.25, 1.25, 7);
nStep = 1400;
stepSize = 0.001;

% ---- 画布（无 legend：基础高 4 cm，宽取 1.5 cm 整倍数）----
f = figure('Color', 'w', 'Name', 'RSLDS Fig1 landscape schematic');
f.Units = 'centimeters';
f.Position(3:4) = [9.0, 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9.0, 4.0];
f.PaperSize = [9.0, 4.0];

tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = gobjects(1, numel(specs));
for i = 1:numel(specs)
	ax(i) = nexttile(tlo, i);
	iPlotLandscape(ax(i), specs(i), xLim, yLim, levels, startX, startYs, nStep, stepSize);
end
ax(2).YAxisLocation = 'right';

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'RSLDS_Fig1_LandscapeSchematic.svg');
fprintf('Wrote: %s\n', svgPath);

%% ========== local functions ==========
function V = iPotential(xg, yg, spec)
V = spec.Alpha .* (xg.^2 - 1).^2 + spec.Gamma .* yg.^2 + spec.Delta .* xg;
end

function a = iArrowIndex(px, startX)
% 箭头画在“已走过 x 方向 55% 行程”的位置，保证两组的箭头落在同一横向区间
xTarget = startX + 0.55 .* (px(end) - startX);
[~, a] = min(abs(px - xTarget));
end

function [px, py] = iDescend(spec, x0, y0, nStep, stepSize)
px = zeros(nStep, 1);
py = zeros(nStep, 1);
px(1) = x0;
py(1) = y0;
for k = 1:nStep-1
	x = px(k);
	y = py(k);
	gx = 4 .* spec.Alpha .* x .* (x.^2 - 1) + spec.Delta;
	gy = 2 .* spec.Gamma .* y;
	px(k + 1) = x - stepSize .* gx;
	py(k + 1) = y - stepSize .* gy;
end
end

function iPlotLandscape(ax, spec, xLim, yLim, levels, startX, startYs, nStep, stepSize)
[xg, yg] = meshgrid(linspace(xLim(1), xLim(2), 240), linspace(yLim(1), yLim(2), 240));
contourf(ax, xg, yg, iPotential(xg, yg, spec), levels, 'LineColor', 'none');
colormap(ax, repmat(linspace(1.00, 0.55, 64)', 1, 3));
hold(ax, 'on');

for i = 1:numel(startYs)
	[px, py] = iDescend(spec, startX, startYs(i), nStep, stepSize);
	plot(ax, px, py, '-', 'Color', spec.Color, 'LineWidth', 1);
	a = iArrowIndex(px, startX);
	a0 = max(1, a - 30);
	vx = px(a) - px(a0);
	vy = py(a) - py(a0);
	vn = hypot(vx, vy);
	arrowLen = 0.22;
	vx = vx ./ vn .* arrowLen;
	vy = vy ./ vn .* arrowLen;
	quiver(ax, px(a) - vx, py(a) - vy, vx, vy, 0, ...
		'Color', spec.Color, 'MaxHeadSize', 3, 'LineWidth', 1);
end

plot(ax, [-1, 1], [0, 0], 'o', 'MarkerSize', 5, ...
	'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0, 0, 0], 'LineWidth', 0.5);
text(ax, -1, -0.26, 'withhold', 'HorizontalAlignment', 'center');
text(ax, 1, -0.26, 'lick', 'HorizontalAlignment', 'center');
text(ax, xLim(1) + 0.10, yLim(2) * 0.84, sprintf('\DeltaV = %.2f', spec.Alpha - spec.Delta), ...
	'HorizontalAlignment', 'left');

% 线索输入：把状态从“抑制舔水”推过势垒
cueTail = -0.62;
cueHead = -0.05;
plot(ax, [cueTail, cueHead - 0.16], [0, 0], '-', 'Color', [0, 0, 0], 'LineWidth', 2);
quiver(ax, cueHead - 0.16, 0, 0.16, 0, 0, 'Color', [0, 0, 0], 'MaxHeadSize', 3, 'LineWidth', 2);
text(ax, (cueTail + cueHead) / 2, 0.16, 'cue', 'HorizontalAlignment', 'center');

axis(ax, [xLim, yLim]);
title(ax, spec.Title);
xlabel(ax, 'action axis');
ylabel(ax, 'drift axis');
hold(ax, 'off');
end
