% Fig1 metric bars｜三个学习速度指标的 bar 图（当前色卡）
%
% 指标：
%   1  Sigmoid slope：**【逐 trial 惩罚版】** 每鼠全部 LightWater trial 的 0/1 作二项似然，
%      会话序号作 block，TransferLearning.FitPenalizedSigmoid(FixLowerZero=true)
%      → 下限固定 0、上限固定 1，斜率与中点自由（log-odds/block，概率空间最大瞬时斜率 = k/4）；
%      封装：TransferLearning.Metrics.TrialLevelSlopePerMouse
%   2  Blocks to 50%：达到 50% 命中率的 block，相邻两点线性插值；末次未达标记 max+1。
%   3  First block：首位光水 block 的命中率。
%
% 分组：Naive / 12 h（Transfer）/ 7 d（7dayTransfer），与 Fig1 学习曲线同一口径。
% 配色：TransferLearning.ColorNaive / Color12h / Color7d（0–255 → /255）。
%
% 规范：3 bar 图各一张 4.5×4 cm，Scale 1（6 pt），bar 无边框、errorbar 单向、无散点；
%       轴宽 0.5 pt；组间双侧秩和检验；P 值用星号（**** p<1e-4 / *** p<0.001 / ** p<0.01 / * p<0.05 / n.s.）。导出到 \\Data-Server-2\个人数据\<USERNAME>\<YYYYMM>。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

groupOrder = ["Naive", "Transfer", "7dayTransfer"];
groupLabels = ["Naive", "12 h", "7 d"];
colors = [TransferLearning.ColorNaive; TransferLearning.Color12h; TransferLearning.Color7d] / 255;

%% 数据（优先读缓存；数据结构改动后置 ForceRebuild=true 重建）
ForceRebuild = false;
D = TransferLearning.Metrics.LightWaterMetricData(ForceRebuild = ForceRebuild);
Sess = D.Sess;
Summ = D.Summ;
Slope = D.Slope;
fprintf('\n=== 逐 trial 惩罚 sigmoid 斜率（%d 只鼠）===\n', height(Slope));
for g = unique(Slope.Group, 'stable').'
	fprintf('  %-13s n=%2d  斜率均值 %.3f  停在斜率上界的 %d 只\n', g, ...
		nnz(Slope.Group == g), mean(Slope.Slope(Slope.Group == g)), nnz(Slope.Group == g & Slope.AtSlopeBoundary));
end

%% 统计（组间双侧秩和检验）
pairIdx = [1 2; 2 3; 1 3];
metricName = ["Learning speed", "Blocks to 50%", "First block"];
ylab = ["Learning speed", "Blocks to 50%", "Hit rate"];

pMat = nan(3, 3);   % metric × pair
fprintf('\n=== 三组学习速度指标 ===\n');
for m = 1:3
	q = cell(1, 3);
	for k = 1:3
		v = iMetric(m, groupOrder(k), Slope, Summ);
		q{k} = v(isfinite(v));
	end
	fprintf('\n[%s]\n', metricName(m));
	for k = 1:3
		fprintf('  %-13s n=%2d  mean %.4f  sem %.4f  median %.4f\n', ...
			groupOrder(k), numel(q{k}), mean(q{k}), iSEM(q{k}), median(q{k}));
	end
	for k = 1:3
		pMat(m, k) = iRS(q{pairIdx(k, 1)}, q{pairIdx(k, 2)});
		fprintf('  %-13s vs %-13s p = %.4g\n', groupOrder(pairIdx(k, 1)), ...
			groupOrder(pairIdx(k, 2)), pMat(m, k));
	end
end

%% 画图 + 导出
figNames = ["English_Fig1_MetricBars_LearningSpeed.svg", ...
	"English_Fig1_MetricBars_BlocksTo50.svg", ...
	"English_Fig1_MetricBars_FirstBlock.svg"];
for m = 1:3
	q = cell(1, 3);
	for k = 1:3
		v = iMetric(m, groupOrder(k), Slope, Summ);
		q{k} = v(isfinite(v));
	end
	f = figure('Color', 'w', 'Name', char(figNames(m)));
	f.Units = 'centimeters';
	f.Position(3:4) = [4.5 4];
	ax = axes(f, 'Position', [0.22 0.19 0.72 0.66]);
	iBar(ax, q, pairIdx(1:2, :), pMat(m, 1:2), colors, groupLabels, ylab(m));
	p = TransferLearning.ExportStandardFigure(f, 1, figNames(m));
	fprintf('Wrote: %s\n', p);
end

%% ---------------------------------------------------------------
function v = iMetric(m, grp, Slope, Summ)
switch m
	case 1
		v = double(Slope.Slope(Slope.Group == grp));
	case 2
		v = double(Summ.BlocksToHalf(Summ.Group == grp));
	otherwise
		v = double(Summ.FirstPerf(Summ.Group == grp));
end
v = v(:);
end
function iBar(ax, data, pairs, pVals, cols, labels, ylab)
hold(ax, 'on');
y = cellfun(@(v) mean(v(isfinite(v))), data);
e = cellfun(@(v) iSEM(v), data);
% 三个独立 Bar 对象：PLine 需要“不同对象 + Index”才能画成水平括号线
b = gobjects(1, 3);
for k = 1:3
	b(k) = bar(ax, k, y(k), 0.38, 'FaceColor', cols(k, :), 'EdgeColor', 'none', 'LineWidth', 0.5);
	% 单向 errorbar（只向上）
	errorbar(ax, k, y(k), 0, e(k), 'Color', cols(k, :), 'LineWidth', 0.5, 'CapSize', 2);
	% 逐鼠散点（叠在柱上）
	v = data{k};  v = v(isfinite(v));
	jit = (rand(numel(v), 1) - 0.5) * 0.20;
	scatter(ax, k + jit, v, 4, 'o', 'filled', 'MarkerFaceColor', cols(k, :) * 0.60, ...
		'MarkerEdgeColor', 'none');
end
ax.XTick = 1:3;
ax.XTickLabel = cellstr(labels);
ax.FontSize = 6;
ax.LineWidth = 0.5;
xlim(ax, [0.4 3.6]);
ylabel(ax, ylab);
% 上方留白给 PLine（PLine 不会自动改变 ylim）
ax.YLim = [0, max(y(:) + e(:)) * 1.55];
% P 值线：按《英文图规范》用 MATLAB.Graphics.PLine（导出时自动 PLineRetune）。
% 用一个不可见的、跨三组的 errorbar 作为定位对象：PLine 会按误差条顶端放线，
% 避免括号线压住真实 errorbar。
EBall = errorbar(ax, 1:3, y(:).', zeros(1, 3), e(:).', 'LineStyle', 'none', ...
	'Color', 'none', 'CapSize', 0.01);
nP = size(pairs, 1);
txt = strings(nP, 1);
for k = 1:nP
	txt(k) = string(iFmtP(pVals(k)));
end
D = table(repmat(EBall, nP, 1), repmat(EBall, nP, 1), pairs(:, 1), pairs(:, 2), txt, ...
	'VariableNames', ["ObjectA", "ObjectB", "IndexA", "IndexB", "Text"]);
MATLAB.Graphics.PLine(D);
box(ax, 'off');
end

function p = iRS(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function s = iFmtP(p)
% 直接把数值 p 写在括号上方（不再用星号）
if ~isfinite(p)
	s = 'n.s.';
elseif p < 1e-3
	s = '<0.001';
else
	s = sprintf('%.3f', p);
end
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
