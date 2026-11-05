% 对比：7 天间隔的跨模态迁移组（Vacation7, 光水学习）vs cFos 抑制组（MOp, CNO）
%
% 目的：两者都是"迁移/学习受损"组，比较它们的光水（LightWater）学习轨迹差异。
%   A  逐 session 命中率（mean +- SEM across mice，点 + 误差线，不画拟合、不加阴影）
%   B  首个 session 命中率（逐鼠点 + 组均值 ± SEM），秩和检验
%   C  达到 50% 命中率所需 session 数（逐鼠点 + 组均值 ± SEM），秩和检验
%
% 注意口径：两个数据集的"一格"都是**一个 session**（cFos 每 session 30 trial），
% 不是 block。两组的 session 时长/试次构成不完全相同，故只作轨迹与到半速度的比较。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

groupNames = ["7 d transfer", "cFos inhibited"];
colors = [TransferLearning.ColorB; 0.35 0.35 0.35];

% ---------- 数据 ----------
S7 = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
S7 = S7(S7.Group == "7dayTransfer", :);

SC = TransferLearning.BehaviorSessions.CFosInhibitionSessions();
SC = SC(SC.Group == "MOp", :);

sets = {S7, SC};
P = cell(1, 2);
for k = 1:2
	P{k} = TransferLearning.Metrics.PerMouseSessionSummary(sets{k});
end

% ---------- 逐 session 曲线 ----------
xMax = 10;
mu = cell(1, 2);
se = cell(1, 2);
for k = 1:2
	S = sets{k};
	mice = unique(S.Mouse, 'stable');
	M = nan(numel(mice), xMax);
	for i = 1:numel(mice)
		r = S(S.Mouse == mice(i), :);
		[~, ord] = sort(r.DateTime);
		y = double(r.Performance(ord));
		n = min(numel(y), xMax);
		M(i, 1:n) = y(1:n).';
	end
	mu{k} = mean(M, 1, 'omitnan');
	se{k} = std(M, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(M), 1));
	se{k}(~isfinite(se{k})) = 0;
end

% ---------- 统计 ----------
first = cellfun(@(t) t.FirstPerf, P, 'UniformOutput', false);
half = cellfun(@(t) t.BlocksToHalf, P, 'UniformOutput', false);
pFirst = iRanksum(first{1}, first{2});
pHalf = iRanksum(half{1}, half{2});

% 曲线本身：两组的 session x 组 混合模型（只用 1-7，避免末端掉样本）
S7c = S7(:, {'Group','Mouse','DateTime','Performance','Session'});
S7c.Group(:) = "7dayTransfer";
SCc = SC(:, {'Group','Mouse','DateTime','Performance','Session'});
SCc.Group(:) = "MOp";
Tall = [S7c(S7c.Session <= 7, :); SCc(SCc.Session <= 7, :)];
pCurve = TransferLearning.Style.TwoWayAnovaGroupPValue(Tall, 'Performance', 'Session', 'Group', 'Mouse');

%% ---------- 出图 ----------
f = figure('Color', 'w', 'Name', '7 d transfer vs cFos inhibition');
f.Units = 'centimeters';
f.Position(3:4) = [24, 7.6];

posA = [0.065 0.170 0.290 0.700];
posB = [0.430 0.170 0.240 0.700];
posC = [0.750 0.170 0.240 0.700];

% A: 学习曲线
axA = axes(f, 'Position', posA);
hold(axA, 'on');
for k = 1:2
	xs = (1:xMax).';
	plot(axA, xs, mu{k}(:), '-', 'Color', colors(k, :), 'LineWidth', 1);
	errorbar(axA, xs, mu{k}(:), se{k}(:), 'o', 'Color', colors(k, :), ...
		'MarkerFaceColor', colors(k, :), 'MarkerSize', 3, 'LineWidth', 0.8, 'CapSize', 2);
end
xlabel(axA, 'Session (light-water)');
ylabel(axA, 'Hit rate');
xlim(axA, [0.6, xMax + 0.4]);
ylim(axA, [0, 1]);
yticks(axA, 0:0.2:1);
title(axA, 'Light-water learning curve', 'FontWeight', 'normal', 'FontSize', 9);
lg = legend(axA, groupNames, 'Location', 'southeast');
lg.Box = 'off';
text(axA, 0.04, 0.94, sprintf('group \\times session: %s', iPTxt(pCurve)), ...
	'Units', 'normalized', 'FontSize', 7, 'Color', [0.35 0.35 0.35]);
box(axA, 'off');

% B: 首个 session
axB = axes(f, 'Position', posB);
iDotPanel(axB, first, colors, pFirst, 'First LW session', 'Hit rate', [0, 0.6]);

% C: 达到 50% 所需 session
axC = axes(f, 'Position', posC);
iDotPanel(axC, half, colors, pHalf, 'Sessions to 50% (LW)', 'Sessions', [0, 18]);

annotation(f, 'textbox', [0.02 0.945 0.92 0.045], 'String', ...
	'7 d transfer vs cFos inhibition: both impair light-water learning, but only cFos inhibition delays it', ...
	'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold');

outDir = fileparts(mfilename('fullpath'));
savefig(f, fullfile(outDir, 'Fig_7d_vs_CFosInhibited.fig'));
fprintf('Saved: %s\n', fullfile(outDir, 'Fig_7d_vs_CFosInhibited.fig'));

fprintf('\n=== 7 d transfer vs cFos inhibited ===\n');
for k = 1:2
	fprintf('%s: %d mice, %d sessions | first %.3f +- %.3f | sessions-to-50%% %.2f +- %.2f\n', ...
		groupNames(k), height(P{k}), height(sets{k}), ...
		mean(first{k}), iSem(first{k}), mean(half{k}), iSem(half{k}));
end
fprintf('first session    : p = %.4g (ranksum, %d vs %d mice)\n', pFirst, numel(first{1}), numel(first{2}));
fprintf('sessions to 50%%  : p = %.4g (ranksum)\n', pHalf);
fprintf('learning curve   : group x session p = %.4g (mixed model, sessions 1-7)\n', pCurve);

assignin('base', 'Fig7dVsCFos_Data', struct('Sessions7d', S7, 'SessionsCFos', SC, ...
	'Summary7d', P{1}, 'SummaryCFos', P{2}, 'PFirst', pFirst, 'PHalf', pHalf, 'PCurve', pCurve));

%% ------------------------------------------------------------------
function iDotPanel(ax, vals, colors, p, ttl, ylab, ylims)
hold(ax, 'on');
n = numel(vals);
w = 0.22;
for k = 1:n
	v = vals{k}(:);
	nv = numel(v);
	if nv == 1
		off = 0;
	else
		off = linspace(-1, 1, nv) * w;
	end
	plot(ax, k + off(:), v, 'o', 'MarkerSize', 4, 'MarkerFaceColor', 'w', ...
		'MarkerEdgeColor', colors(k, :), 'LineWidth', 0.9);
	m = mean(v);
	e = std(v) / sqrt(numel(v));
	% 均值 ± SEM：粗短横线 + 误差线
	errorbar(ax, k, m, e, 's', 'Color', colors(k, :), 'MarkerFaceColor', colors(k, :), ...
		'MarkerSize', 6, 'LineWidth', 1.2, 'CapSize', 4);
	plot(ax, k + [-0.22, 0.22], [m m], '-', 'Color', colors(k, :), 'LineWidth', 1.2);
end
xlim(ax, [0.4, n + 0.6]);
ylim(ax, ylims);
ylabel(ax, ylab);
xticks(ax, 1:n);
xticklabels(ax, {'7 d', 'cFos'});
title(ax, ttl, 'FontWeight', 'normal', 'FontSize', 9);
% 显著性标注：括号放在顶部，p 值写在括号下方（避开标题）
yTop = ylims(2) - 0.10 * diff(ylims);
plot(ax, [1 1 2 2], yTop + [0 0.03 0.03 0] * diff(ylims), '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.8);
text(ax, 1.5, yTop - 0.02 * diff(ylims), iPTxt(p), 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'top', 'FontSize', 7);
box(ax, 'off');
end

function s = iPTxt(p)
if ~isfinite(p)
	s = 'n.a.';
elseif p < 0.001
	s = 'p < 0.001';
else
	s = sprintf('p = %.3f', p);
end
end

function p = iRanksum(a, b)
a = double(a(:));
b = double(b(:));
a = a(isfinite(a));
b = b(isfinite(b));
if numel(a) < 2 || numel(b) < 2
	p = NaN;
	return;
end
p = ranksum(a, b);
end

function e = iSem(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	e = NaN;
else
	e = std(x) / sqrt(numel(x));
end
end
