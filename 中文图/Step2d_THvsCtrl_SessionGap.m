%% Step2d_THvsCtrl_SessionGap.m — 后部丘脑抑制是否改变"舔水轴的天尺度漂移"
%
% 动机
%   Step 2c 发现：同一任务序列里，两个 session 相隔越久，舔水轴越不像
%   （同天 ~0.54 → >72 h ~0.17；逐鼠配对 p=0.031）。这个"天尺度漂移"有两种解释：
%     (a) 生物学漂移（自发可塑性 / 学习）
%     (b) 技术漂移（同一批 ROI 跨天的 SNR、神经毡、焦平面变化）
%   若 (a) 且漂移依赖丘脑输入，则 TH 抑制组应当漂移更慢。
%
% 数据
%   直接复用 Step2 的产出：`_step2_pairs_ALB.mat`（对照组）与 `_step2_pairs_TH.mat`（后部丘脑
%   化学遗传抑制，DREADD hM4D(Gi) + CNO）。只取 kind == "series" 的配对（同 Design 连续序列）。
%
% 结论（见 console）
%   TH 与 Ctrl 在各间隔箱上基本重合，Δ 无差异（ranksum p ≈ 0.67）
%   ⇒ 该漂移**不依赖后部丘脑输入**；更倾向技术/自发漂移的解释。
%
% 1) 依赖：MATLAB R2023b+，本项目 +TransferLearning；需先跑过 Step2（ALB 与 TH 各一次）
% 2) 前置：`Step2_LickAxisStability.m` 生成的 `_step2_pairs_*.mat`
% 3) 图注：左＝归一化共享比例随两 session 间隔的变化（均值±SEM，每只鼠 1 个值；虚线=1）；
%          右＝跨 session 原始余弦（同间隔口径）。空心=Cntrl，实心=TH。
% 4) 代码

%% 0. 参数
cohorts = ["ALB", "TH"];
cohortLabel = ["对照 (无 TH)", "TH 抑制"];
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
iw = 1;   % W = 2 s

%% 1. 读取两队列的配对
R = struct(); X = struct();
for c = cohorts
	f = fullfile(thisDir, "Step2_pairs_" + c + ".mat");
	assert(exist(f, 'file') > 0, '缺少 %s，请先跑 Step2（Step2Cohort = "%s"）', f, c);
	L = load(f);
	pr = L.pair(string({L.pair.kind}) == "series");
	mo = string({pr.mouse});
	gp = [pr.gapH];
	gb = discretize(gp, L.gapEdges);
	nB = numel(L.gapLabel);
	RR = nan(numel(L.mice), nB); XX = nan(numel(L.mice), nB); NN = zeros(numel(L.mice), nB);
	CR = reshape([pr.cosRatio], numel(L.hpList), [])';
	CC = reshape([pr.cosCross], numel(L.hpList), [])';
	for m = 1:numel(L.mice)
		for b = 1:nB
			s = mo == L.mice(m) & gb == b;
			if any(s)
				RR(m, b) = mean(CR(s, iw), 'omitnan');
				XX(m, b) = mean(CC(s, iw), 'omitnan');
				NN(m, b) = sum(s);
			end
		end
	end
	R.(c) = RR; X.(c) = XX; N.(c) = NN; %#ok<SAGROW>
	% 逐鼠漂移秩相关 ρ（用满全部小鼠）
	RH = nan(numel(L.mice), 1);
	for m = 1:numel(L.mice)
		s = mo == L.mice(m);
		if sum(s) >= 4 && numel(unique(round(gp(s)))) >= 3
			RH(m) = corr(gp(s)', CR(s, iw), 'type', 'Spearman');
		end
	end
	Rho.(c) = RH; %#ok<SAGROW>
	gapLabel = L.gapLabel; nB = numel(gapLabel);
end

%% 2. 统计
fprintf('=== 后部丘脑抑制 vs 对照：舔水轴的 session 间隔依赖（W = 2 s）===\n');
fprintf('%-14s %s\n', '队列', sprintf('%10s', gapLabel));
for c = cohorts
	fprintf('%-14s %s\n', c, sprintf('%10.3f', median(R.(c), 1, 'omitnan')));
end
fprintf('%-14s %s\n', '→ 逐箱 n', sprintf('%10d', sum(N.ALB, 1)));
fprintf('%-14s %s\n', '  （TH）', sprintf('%10d', sum(N.TH, 1)));
a = R.ALB(:, 1) - R.ALB(:, 3); a = a(isfinite(a));
b = R.TH(:, 1) - R.TH(:, 3); b = b(isfinite(b));
fprintf('\n逐鼠 Δ(<18h − 36-72h)：对照 %+.3f (n=%d)；TH %+.3f (n=%d)；ranksum p = %.3f\n', ...
	median(a), numel(a), median(b), numel(b), ranksum(a, b));
ra = Rho.ALB(isfinite(Rho.ALB)); rb = Rho.TH(isfinite(Rho.TH));
fprintf('逐鼠 ρ(cosRatio, 间隔)：对照 中位 %+.3f (n=%d, 其中负的 %d 只)；TH 中位 %+.3f (n=%d, 负的 %d 只)；ranksum p = %.3f\n', ...
	median(ra), numel(ra), sum(ra < 0), median(rb), numel(rb), sum(rb < 0), ranksum(ra, rb));
fprintf('两队列技术量可比，且样本量小 → 只能说"未见差异"\n');
fprintf('各箱逐鼠中位（对照 vs TH）：\n');
for k = 1:nB
	fprintf('  %-9s %6.3f  vs  %6.3f\n', gapLabel(k), median(R.ALB(:, k), 'omitnan'), median(R.TH(:, k), 'omitnan'));
end

%% 3. 作图
f = iNewFigure('Step2d TH vs Ctrl session gap', [9, 4]);
tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
mk = {'o', 's'};
cl = {[0 0 0], [0.85 0.35 0.10]};
ax = nexttile(tlo, 1);
hold(ax, 'on');
for ci = 1:numel(cohorts)
	Y = R.(cohorts(ci));
	n = sum(isfinite(Y), 1);
	errorbar(ax, 1:nB, mean(Y, 1, 'omitnan'), std(Y, 0, 1, 'omitnan')./sqrt(max(n, 1)), ...
		['-' mk{ci}], 'Color', cl{ci}, 'MarkerSize', 3.5, 'MarkerFaceColor', 'w', 'CapSize', 2);
end
yline(ax, 1, '--', 'Color', [0.7 0.7 0.7]);
set(ax, 'XTick', 1:nB, 'XTickLabel', cellstr(gapLabel), 'XLim', [0.6, nB + 2.4], 'YLim', [0, 1.15]);
xtickangle(ax, 25); xlabel(ax, '两个 session 的间隔'); ylabel(ax, '跨session ÷ 同块折半'); box(ax, 'off');
title(ax, '归一化共享比例', 'FontWeight', 'normal');
yEnd = arrayfun(@(ci) mean(R.(cohorts(ci))(end, :), 'omitnan'), 1:numel(cohorts));
[ys, ord] = sort(yEnd); gapY = 0.07;
for i = 2:numel(ys); if ys(i) - ys(i-1) < gapY; ys(i) = ys(i-1) + gapY; end; end
for i = 1:numel(ord)
	text(ax, nB + 0.25, ys(i), cohortLabel(ord(i)), 'FontSize', 6, 'VerticalAlignment', 'middle', 'Clipping', 'off');
end

% 右：逐鼠漂移 ρ（每只鼠一个点；同时看清 n 与效应量）
ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
vals = {Rho.ALB(isfinite(Rho.ALB)), Rho.TH(isfinite(Rho.TH))};
for ci = 1:2
	v = vals{ci};
	nv = numel(v);
	jit = linspace(-0.13, 0.13, max(nv, 2));
	scatter(ax2, ci + jit(1:nv), v, 14, cl{ci}, 'filled', 'MarkerFaceAlpha', 0.65);
	mv = median(v);
	plot(ax2, [ci - 0.3, ci + 0.3], [mv, mv], '-', 'Color', cl{ci}, 'LineWidth', 1.2);
	text(ax2, ci, max(v) + 0.05, sprintf('n=%d\n中位 %+.2f', nv, mv), 'FontSize', 6, ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end
yline(ax2, 0, '--k');
set(ax2, 'XTick', 1:2, 'XTickLabel', {'对照', 'TH 抑制'}, 'XLim', [0.5, 2.5]);
ylabel(ax2, '逐鼠 \rho（cosRatio vs 间隔）'); box(ax2, 'off');
title(ax2, '漂移斜率（每只鼠 1 点）', 'FontWeight', 'normal');
TransferLearning.ExportStandardFigure(f, 1, 'Step2d_THvsCtrl_SessionGap.svg');
fprintf('\nDone.\n');

%% ===== Local functions =====
function f = iNewFigure(figName, sizeCm)
f = figure('Color', 'w', 'Name', figName);
f.Units = 'centimeters';
f.Position(3:4) = sizeCm;
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, sizeCm];
f.PaperSize = sizeCm;
end
