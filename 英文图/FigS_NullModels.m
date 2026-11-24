% FigS_NullModels.m
% 补充图：置换零模型（每细胞独立打乱时间）—— 证明结构与一致性显著超出随机
%   (a) PR 的 z（真实值低于零模型的标准化距离；越大越负 = 越低维）
%   (b) 平滑度的 z（真实值比零模型更平滑）
%   (c) 跨阶段 overlap 的 z（真实一致性超出「时间结构无关」零模型的程度）
%
% 数据：Check_NullModels_MOp2-3.csv（逐鼠，nPerm=200）
% 口径：MOp2/3，0–8 s 65 帧，k=3

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

cALB = TransferLearning.ColorAudio / 255;
cV7  = TransferLearning.Color7d    / 255;

N = readtable(fullfile(thisDir, 'Check_NullModels_MOp2-3.csv'), 'TextType', 'string');
stages = ["Naive", "Learned", "Transfer", "Final"];
pairs  = ["N→L", "L→T", "N→T"];
cGet = @(c, t) N.Z(N.Cohort == c & N.Test == t);

f = figure('Color', 'w', 'Name', 'FigS null models');
f.Units = 'centimeters';
f.Position = [2, 2, 20, 7.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 20, 7.0];
f.PaperSize = [20, 7.0];
tlo = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% ---------- (a) PR ----------
axA = nexttile(tlo);
A = arrayfun(@(s) cGet("ALB", "PR/" + s), stages, 'UniformOutput', false);
B = arrayfun(@(s) cGet("V7",  "PR/" + s), stages, 'UniformOutput', false);
iZSeries(axA, A, B, cALB, cV7, true);
axA.XTick = 1:4; axA.XTickLabel = stages;
ylabel(axA, 'z (PR vs shuffled)');
title(axA, '(a)', 'FontWeight', 'normal');

% ---------- (b) 平滑度 ----------
axB = nexttile(tlo);
A = arrayfun(@(s) cGet("ALB", "smooth/" + s), stages, 'UniformOutput', false);
B = arrayfun(@(s) cGet("V7",  "smooth/" + s), stages, 'UniformOutput', false);
iZSeries(axB, A, B, cALB, cV7, true);
axB.XTick = 1:4; axB.XTickLabel = stages;
ylabel(axB, 'z (smoothness vs shuffled)');
title(axB, '(b)', 'FontWeight', 'normal');

% ---------- (c) 跨阶段 overlap ----------
axC = nexttile(tlo);
A = arrayfun(@(p) cGet("ALB", "overlap/" + p), pairs, 'UniformOutput', false);
B = arrayfun(@(p) cGet("V7",  "overlap/" + p), pairs, 'UniformOutput', false);
iZSeries(axC, A, B, cALB, cV7);
axC.XTick = 1:3; axC.XTickLabel = pairs;
ylabel(axC, 'z (overlap vs shuffled)');
title(axC, '(c)', 'FontWeight', 'normal');


svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS_NullModels.svg');
fprintf('Wrote: %s\n', svgPath);
exportgraphics(f, fullfile(thisDir, '_figS_null_check.png'), 'Resolution', 400, 'BackgroundColor', 'white');

%% ================= 局部函数 =================
function iZSeries(ax, A, B, cA, cB, useMed)
if nargin < 6, useMed = false; end
hold(ax, 'on');
n = numel(A);
for g = 1:n
	for s = 1:2
		if s == 1, v = A{g}; cc = cA; dx = -0.17;
		else,      v = B{g}; cc = cB; dx = 0.17; end
		v = v(:); v = v(isfinite(v));
		if isempty(v), continue; end
		if useMed, m = median(v); se = 1.2533*std(v)/sqrt(numel(v)); else, m = mean(v); se = std(v)/sqrt(numel(v)); end
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
ax.Box = 'off'; ax.LineWidth = 1;
end
