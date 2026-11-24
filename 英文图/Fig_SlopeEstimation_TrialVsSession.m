% [存档] 旧编号脚本（已去图号，不再对应正式面板），保留代码备查。
% 逐 trial 斜率计算的示意：同一只鼠，两种数据层级的拟合
%
% (a) 逐 trial：每个试次的 0/1 结果为观测，二项似然拟合 sigmoid
%     —— 与正文数值完全同一算法：TransferLearning.FitPenalizedSigmoid（下限 0、上限 1，
%        含 Jeffreys/Fisher 信息惩罚与 log(k)~N(0,2^2) 弱惩罚）
% (b) 会话均值：每个 block 的命中率（±SEM）为观测，最小二乘拟合同模型
%
% 目的：直观说明"斜率 k 从哪些数据算出来"，以及两种口径为何给出不同的 k。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

mouse = "yqn2005";
DS = TransferLearning.LAInterspersed();

Tq = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], Mouse = mouse, Stimulus = "LightWater");
[~, ~, dtIdx] = unique(Tq.DateTime);
y = double(Tq.Behavior);
ok = isfinite(y);
x = double(dtIdx(ok));
y = y(ok);
nBlock = max(x);

% --- 逐 trial：惩罚版二项 sigmoid（与正文/Fig1C/Fig4G 完全同一算法）
fitTL = TransferLearning.FitPenalizedSigmoid(x, y, FixLowerZero = true);
kTL = fitTL.Slope;
midTL = fitTL.Midpoint;
lowTL = fitTL.Lower;
% --- 会话级 LS
perf = splitapply(@mean, y, findgroups(x));
sem = splitapply(@(v) std(v) / sqrt(numel(v)), y, findgroups(x));
b = (1:nBlock)';
objLS = @(p) sum((perf - 1 ./ (1 + exp(-exp(p(1)) .* (b - p(2))))).^ 2);
pLS = fminsearch(objLS, [log(0.8); median(b)], optimset('Display', 'off'));
kLS = exp(pLS(1));
fprintf('%s：%d block / %d trial\n  逐 trial 惩罚版 k=%.2f (mid %.2f)\n  会话级 LS     k=%.2f (mid %.2f)\n', ...
	mouse, nBlock, numel(x), kTL, midTL, kLS, pLS(2));

% --- 颜色
cMain = TransferLearning.CurveNaive() / 255;      % 主色（曲线用加深版）
cDot = iBlend(cMain, [1 1 1], 0.55);            % 试次点（浅）
cFit = iBlend(cMain, [0 0 0], 0.20);            % 拟合线（深）
cGray = [0.45 0.45 0.45];

fig = figure('Color', 'w', 'Name', 'Slope estimation: trial vs session');
fig.Units = 'centimeters';
fig.Position(3:4) = [9 4.5];
t = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

xFit = linspace(0.5, nBlock + 0.5, 200)';

%% (a) 逐 trial
ax1 = nexttile(t, 1);
hold(ax1, 'on');
% 块内等间隔铺开，避免重叠
xJit = zeros(size(x));
for bi = 1:nBlock
	idx = find(x == bi);
	xJit(idx) = bi - 0.5 + (1:numel(idx))' / (numel(idx) + 1);
end
hMiss = scatter(ax1, xJit(y == 0), zeros(sum(y == 0), 1), 6, cDot, 'o', 'filled');
hHit = scatter(ax1, xJit(y == 1), ones(sum(y == 1), 1), 6, cDot, 'o', 'filled');
plot(ax1, xFit, lowTL + (1 - lowTL) ./ (1 + exp(-kTL * (xFit - midTL))), '-', 'Color', cFit, ...
	'LineWidth', 1, 'Tag', 'TransferLearningSupplementalLine');
ax1.XLim = [0.5 nBlock + 0.5];
ax1.XTick = 1:nBlock;
xlabel(ax1, 'Block');
ylabel(ax1, 'Outcome');
title(ax1, 'Trial level', 'FontWeight', 'normal');
text(ax1, 0.57, 0.30, sprintf('k = %.2f', kTL), 'Units', 'normalized', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 6, 'Color', cFit);
text(ax1, 0.57, 0.18, sprintf('%d trials', numel(x)), 'Units', 'normalized', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 5.5, 'Color', cGray);

%% (b) 会话均值
ax2 = nexttile(t, 2);
hold(ax2, 'on');
errorbar(ax2, b, perf, zeros(size(perf)), sem, 'o', 'Color', cMain, ...
	'MarkerFaceColor', 'w', 'MarkerEdgeColor', cMain, 'MarkerSize', 3, ...
	'LineWidth', 0.5, 'CapSize', 2);
plot(ax2, xFit, 1 ./ (1 + exp(-kLS * (xFit - pLS(2)))), '-', 'Color', cGray, ...
	'LineWidth', 1, 'Tag', 'TransferLearningSupplementalLine');
ax2.XLim = [0.5 nBlock + 0.5];
ax2.XTick = 1:nBlock;
xlabel(ax2, 'Block');
ylabel(ax2, 'Hit rate');
title(ax2, 'Session means', 'FontWeight', 'normal');
text(ax2, 0.04, 0.90, sprintf('k = %.2f', kLS), 'Units', 'normalized', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
	'FontSize', 6, 'Color', cGray);
text(ax2, 0.04, 0.78, sprintf('%d means', nBlock), 'Units', 'normalized', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
	'FontSize', 5.5, 'Color', cGray);

% 共享 y 轴
for ax = [ax1 ax2]
	ax.YLim = [-0.03 1.05];
	ax.YTick = [0 0.5 1];
	ax.LineWidth = 0.5;
	box(ax, 'off');
end

p = TransferLearning.ExportStandardFigure(fig, 1, 'English_Fig_SlopeEstimation_TrialVsSession.svg');
fprintf('Wrote: %s\n', p);

%% ---------------------------------------------------------------
function c = iBlend(c, target, w)
c = c * (1 - w) + target .* w;
end
