% FigS_ModalityOverlap_Bars.m —— 超模态细胞比例：观察值 vs 独立期望（按层）
%
% 数据：FigS_ModalityOverlap_LAI.csv（由 FigS_ModalityOverlap_LAI.m 生成）
%   每行 = 一只鼠一个 session 的 【响应细胞并集】中，两模态都响应的比例
%   FracBoth    ：观察到的两模态重叠比例
%   ExpFracBoth ：两模态响应相互独立时的期望比例
%
% 图：L2/3 与 L5 各一对柱（obs / exp），逐 session 圆点叠在 obs 柱上，
%     星号为 obs 与 exp 的逐鼠配对 Wilcoxon（iFormatPStars）。
%
% 输出：English_FigS_ModalityOverlap_Bars.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

T = readtable(fullfile(thisDir, 'FigS_ModalityOverlap_LAI.csv'), 'TextType', 'string');
if ~islogical(T.Valid), T.Valid = logical(T.Valid); end
V = T(T.Valid, :);
if isempty(V), error('FigS_ModalityOverlap:NoValidRows', 'CSV 里没有可评估的 session。'); end

layerKey  = ["MOp2/3", "MOp5"];
layerLab  = ["L2/3", "L5"];
colObs    = [TransferLearning.ColorLearned; TransferLearning.Color12h] / 255;

figW = 4.2; figH = 4.4;
f = figure('Color', 'w', 'Name', 'Supramodal fraction');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH];
f.PaperUnits = 'centimeters';
f.PaperSize = [figW figH];
f.PaperPosition = [0 0 figW figH];
f.PaperPositionMode = 'manual';

ax = axes(f, 'Position', [0.185 0.275 0.770 0.665]);
hold(ax, 'on');

dx = 0.19; bw = 0.32;
xObs = nan(1, 2); xExp = nan(1, 2);
yObs = cell(1, 2); yExp = cell(1, 2);
for iL = 1:2
	sel = V.Layer == layerKey(iL);
	yObs{iL} = V.FracBoth(sel);
	yExp{iL} = V.ExpFracBoth(sel);
	xObs(iL) = iL - dx;  xExp(iL) = iL + dx;
	% 观察柱（分组色实心）
	bar(ax, xObs(iL), mean(yObs{iL}), bw, 'FaceColor', colObs(iL, :), 'EdgeColor', 'none');
	% 期望柱（同色淡调 + 细实边）
	lightFill = 1 - 0.32 * (1 - colObs(iL, :));
	bar(ax, xExp(iL), mean(yExp{iL}), bw, 'FaceColor', lightFill, ...
		'EdgeColor', colObs(iL, :) * 0.55, 'LineWidth', 0.5);
	% error bar（SEM，单向）
	m = mean(yObs{iL}); s = std(yObs{iL}) / sqrt(numel(yObs{iL}));
	plot(ax, [xObs(iL) xObs(iL)], [m m + s], '-', 'Color', [0.25 0.25 0.25], 'LineWidth', 0.5);
	m = mean(yExp{iL}); s = std(yExp{iL}) / sqrt(numel(yExp{iL}));
	plot(ax, [xExp(iL) xExp(iL)], [m m + s], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.5);
	% 逐 session 圆点（轻微水平抖动）
	jit = (rand(numel(yObs{iL}), 1) - 0.5) * 0.11;
	scatter(ax, xObs(iL) + jit, yObs{iL}, 5, 'o', 'filled', ...
		'MarkerFaceColor', colObs(iL, :) * 0.62, 'MarkerEdgeColor', 'none');
end

% 显著性：每个层 obs vs exp 的逐鼠配对
yTop = 0;
for iL = 1:2
	pv = iPairedP(yObs{iL}, yExp{iL});
	yBar = max([yObs{iL}; yExp{iL}]) * 1.16;
	plot(ax, [xObs(iL) xExp(iL)], [yBar yBar], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5);
	text(ax, mean([xObs(iL) xExp(iL)]), yBar, ['  ' TransferLearning.Style.iFormatPStars(pv)], ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 5.5);
	yTop = max(yTop, yBar);
end

set(ax, 'XTick', sort([xObs xExp]), 'XTickLabel', {'obs', 'exp', 'obs', 'exp'});
xlim(ax, [0.45 2.55]);
ylim(ax, [0, yTop * 1.12]);
plot(ax, [0.45 2.55], [0 0], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5);
ylabel(ax, 'Both-modality fraction', 'FontSize', 6);
ax.FontSize = 6;
ax.LineWidth = 0.5;
box(ax, 'off');
grid(ax, 'off');

% 层标签（轴下方一行，用归一化坐标避开 ylim）
xFrac = (([1 2]) - 0.45) / (2.55 - 0.45);
for iL = 1:2
	text(ax, xFrac(iL), -0.155, sprintf('%s (n=%d)', layerLab(iL), numel(yObs{iL})), ...
		'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
		'FontSize', 5.5, 'Color', colObs(iL, :) * 0.85, 'FontWeight', 'bold');
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS_ModalityOverlap_Bars.svg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== 超模态比例（obs vs 独立期望）===\n');
for iL = 1:2
	fprintf('%-7s n=%2d | obs=%.3f±%.3f | exp=%.3f±%.3f | p=%.4g\n', ...
		layerLab(iL), numel(yObs{iL}), mean(yObs{iL}), std(yObs{iL})/sqrt(numel(yObs{iL})), ...
		mean(yExp{iL}), std(yExp{iL})/sqrt(numel(yExp{iL})), ...
		iPairedP(yObs{iL}, yExp{iL}));
end

function p = iPairedP(x, y)
v = x(:) - y(:);
v = v(isfinite(v));
if numel(v) < 3 || all(v == 0)
	p = NaN;
else
	p = signrank(v);
end
end
