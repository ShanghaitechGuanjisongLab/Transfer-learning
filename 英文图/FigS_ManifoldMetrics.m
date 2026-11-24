% FigS_ManifoldMetrics.m
% 补充图：把所有「子空间一致性」指标并排展示（证明结论不依赖单一指标）
%   (a) overlap 原始            (d) AI (Transfer→Learned)
%   (b) ovRatio（÷噪声上限）    (e) θ̄（平均主角度）
%   (c) AI (Learned→Transfer)   (f) θmax（最大主角度）
%
% 数据：Check_ManifoldSimilarity_MOp2-3_k3_w8000ms.csv（逐鼠，nCell 匹配 cap=100）
% 口径：MOp2/3，0–8 s，k=3，独立估子空间（不共用 PCA 基），3 个阶段对 × 2 队列
% 注意：θ̄/θmax 方向相反——角度越小越相似；overlap/AI 越大越相似。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

cALB = TransferLearning.ColorAudio / 255;   % #89DCEB
cV7  = TransferLearning.Color7d    / 255;   % #F5C2E7

MS = readtable(fullfile(thisDir, 'Check_ManifoldSimilarity_MOp2-3_k3_w8000ms.csv'), 'TextType', 'string');
pick = @(c, pn, v) MS{MS.Cohort == c & MS.Pair == pn, v};

f = figure('Color', 'w', 'Name', 'FigS manifold metrics');
f.Units = 'centimeters';
f.Position = [2, 2, 20, 8.6];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 20, 8.6];
f.PaperSize = [20, 8.6];
tlo = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

spec = { ...
	"overlap",           '(a)', 'overlap';
	"ovRatio",           '(b)', 'ovRatio';
	"AI_AB",             '(c)', 'AI: L→T';
	"AI_BA",             '(d)', 'AI: T→L';
	"thetaMean_deg",     '(e)', 'θ̄ (deg)';
	"thetaMax_deg",      '(f)', 'θmax (deg)'};

axs = gobjects(1, 6);
for i = 1:6
	ax = nexttile(tlo);
	axs(i) = ax;
	v = spec{i, 1};
	iTwoSeries(ax, ...
		{pick("ALB", "N→T", v), pick("ALB", "L→T", v), pick("ALB", "T→F", v)}, ...
		{pick("V7",  "N→T", v), pick("V7",  "L→T", v), pick("V7",  "T→F", v)}, cALB, cV7);
	ax.XTick = [1 2 3];
	ax.XTickLabel = {'N→T', 'L→T', 'T→F'};
	ylabel(ax, spec{i, 3});
	ax.Box = 'off'; ax.LineWidth = 1;
	title(ax, spec{i, 2}, 'FontWeight', 'normal');
end

% 图例（放在 (a) 内空白处，两队列）
hold(axs(1), 'on');
h1 = plot(axs(1), nan, nan, 's', 'MarkerSize', 5, 'MarkerFaceColor', cALB, 'MarkerEdgeColor', 'none', 'DisplayName', 'ALB');
h2 = plot(axs(1), nan, nan, 's', 'MarkerSize', 5, 'MarkerFaceColor', cV7,  'MarkerEdgeColor', 'none', 'DisplayName', 'V7');
lgd = legend(axs(1), [h1 h2], 'Orientation', 'horizontal', 'Box', 'off', 'Location', 'northwest');
lgd.NumColumns = 2;

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS_ManifoldMetrics.svg');
fprintf('Wrote: %s\n', svgPath);
exportgraphics(f, fullfile(thisDir, '_figS_mm_check.png'), 'Resolution', 400, 'BackgroundColor', 'white');

%% ================= 局部函数 =================
function iTwoSeries(ax, A, B, cA, cB, useMed)
% 每个 group 两根柱（两队列）+ 逐鼠散点
if nargin < 6, useMed = false; end
hold(ax, 'on');
n = numel(A);
for g = 1:n
	for s = 1:2
		if s == 1, v = A{g}; cc = cA; dx = -0.17;
		else,      v = B{g}; cc = cB; dx = 0.17; end
		v = v(:); v = v(isfinite(v));
		if isempty(v), continue; end
		if useMed
			m = median(v); se = 1.2533 * std(v) / sqrt(numel(v));
		else
			m = mean(v); se = std(v) / sqrt(numel(v));
		end
		bar(ax, g + dx, m, 0.28, 'FaceColor', cc, 'EdgeColor', 'none', 'HandleVisibility', 'off');
		errorbar(ax, g + dx, m, se, 'Color', cc, 'LineStyle', 'none', ...
			'LineWidth', 1, 'CapSize', 3, 'HandleVisibility', 'off');
		plot(ax, g + dx + (rand(numel(v), 1) - 0.5) * 0.13, v, 'o', 'MarkerSize', 2.2, ...
			'MarkerFaceColor', 'none', 'MarkerEdgeColor', cc, 'LineWidth', 0.4, ...
			'HandleVisibility', 'off');
	end
end
xlim(ax, [0.5 n + 0.5]);
yline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end
