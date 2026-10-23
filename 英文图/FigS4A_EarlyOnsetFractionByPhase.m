%% FigS4A_EarlyOnsetFractionByPhase.m
% English FigS4A: early-onset neuron fractions, Learned vs Transfer
% （仿 Nature 2026 s41586-026-11174-3 Fig.1c 的 early/late/no-onset 占比图）
% 文献口径：movement(=舔水)锁定 PSTH，onset = 基线([-1,-0.5]s)+1SD 且持续
% 200 ms（200 Hz 上采样网格）；onset<0 → early-onset，onset≥0 → late-onset，
% 无 onset → no onset。占比 = 各类细胞数 / 全部记录细胞。
% 本图：AudioLightBaseline 每鼠 Learned(AudioWater) 与 Transfer(LightWater)
% block 分别判定（数据源 FigS4_PreCueStatePCA_Analysis.m）。三个 panel：
%   1/2) early/late/no-onset 占比堆叠条（概念对应 Fig.1c/Fig.2a 的 onset 分类与占比）；
%   3) early 细胞 lick(=movement) 锁定平均 PSTH ± SEM（样式对应 Fig.1c 右示例轨迹）。
%
% Outputs (SVG): English_FigS4A_EarlyOnsetFractionByPhase.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

nM = numel(M);
frac = nan(nM, 3, 2);       % mouse x {early,late,none} x {Learned,Transfer}
for i = 1:nM
	nTotL = M(i).nEarly + M(i).nLate + M(i).nNone;
	nTotT = M(i).nEarlyT + M(i).nLateT + M(i).nNoneT;
	frac(i, :, 1) = [M(i).nEarly, M(i).nLate, M(i).nNone] / nTotL * 100;
	frac(i, :, 2) = [M(i).nEarlyT, M(i).nLateT, M(i).nNoneT] / nTotT * 100;
end
[pE, hE] = signrank(frac(:,1,1), frac(:,1,2));
[pL, ~] = signrank(frac(:,2,1), frac(:,2,2));
fprintf('early%% Learned med=%.2f Transfer med=%.2f，Wilcoxon p=%.4g（%d/%d 鼠上升）\n', ...
	median(frac(:,1,1)), median(frac(:,1,2)), pE, sum(frac(:,1,2)>frac(:,1,1)), nM);
fprintf('late%%  Learned med=%.2f Transfer med=%.2f，Wilcoxon p=%.4g\n', ...
	median(frac(:,2,1)), median(frac(:,2,2)), pL);

% ---- figure（3 tiles：两阶段占比堆叠条 + early 细胞 lick 锁定 PSTH，后者仿 Fig.1c 右）----
cEarly = [0.478, 0.204, 0.012];       % 文献深棕
cLate  = [255, 127, 14] ./ 255;       % 文献橙
cNone  = [0.85, 0.85, 0.85];          % 文献浅灰
phaseColor = [TransferLearning.LearnedColor; TransferLearning.TransferColor];
phaseName = ["Learned (🔊💧)", "Transfer (💡💧)"];

f = figure('Color', 'w', 'Name', 'English FigS4A EarlyOnsetFractionByPhase');
f.Units = 'centimeters';
f.Position(3:4) = [18, 8];
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
axList = gobjects(3, 1);
for ip = 1:2
	ax = nexttile(tl);
	axList(ip) = ax;
	hold(ax, 'on'); box(ax, 'off');
	ax.FontSize = 12; ax.LineWidth = 2; ax.FontName = 'Segoe UI Emoji';
	b = bar(ax, 1:nM, squeeze(frac(:, :, ip)), 'stacked', 'BarWidth', 0.7, 'EdgeColor', 'none');
	b(1).FaceColor = cEarly; b(2).FaceColor = cLate; b(3).FaceColor = cNone;
	ylim([0, 100]);
	ylabel(ax, '% of recorded cells');
	xlabel(ax, 'Mouse');
	title(ax, phaseName(ip), 'Color', phaseColor(ip,:), 'FontSize', 12, 'FontWeight', 'bold');
	set(ax, 'XTick', 1:nM, 'XTickLabel', string({M.Mouse})', 'FontSize', 7, ...
		'XTickLabelRotation', 90);
	if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end

% tile 3：early-onset 细胞 lick(=movement) 锁定平均 PSTH（仿 Fig.1c 右示例轨迹）
% 各鼠原生帧率不同（8/30 Hz）→ 先插值到公共 100 Hz 网格再跨鼠平均
ax = nexttile(tl);
axList(3) = ax;
hold(ax, 'on'); box(ax, 'off');
ax.FontSize = 12; ax.FontName = 'Segoe UI Emoji'; ax.LineWidth = 2;
tC = (-1.5 : 0.01 : 2)';
PL = nan(numel(tC), nM); PT = nan(numel(tC), nM);
for i = 1:nM
	PL(:, i) = interp1(M(i).tP(:), M(i).psthEL(:), tC, 'linear', nan);
	PT(:, i) = interp1(M(i).tP(:), M(i).psthET(:), tC, 'linear', nan);
end
mL = mean(PL, 2, 'omitnan'); sL = std(PL, 0, 2, 'omitnan') ./ sqrt(sum(isfinite(PL), 2));
mT = mean(PT, 2, 'omitnan'); sT = std(PT, 0, 2, 'omitnan') ./ sqrt(sum(isfinite(PT), 2));
patch(ax, [tC; flipud(tC)], [mL+sL; flipud(mL-sL)], phaseColor(1,:), 'EdgeColor', 'none', 'FaceAlpha', 0.2);
patch(ax, [tC; flipud(tC)], [mT+sT; flipud(mT-sT)], phaseColor(2,:), 'EdgeColor', 'none', 'FaceAlpha', 0.2);
hL = plot(ax, tC, mL, '-', 'Color', phaseColor(1,:), 'LineWidth', 2);
hT = plot(ax, tC, mT, '-', 'Color', phaseColor(2,:), 'LineWidth', 2);
xline(ax, 0, ':k', 'LineWidth', 2);
xlabel(ax, 'Time from lick onset (s)');
ylabel(ax, 'z-score');
title(ax, 'Early-onset cells', 'FontSize', 12, 'FontWeight', 'normal');
lg0 = legend(ax, [hL, hT], {'Learned', 'Transfer'}, 'Location', 'northwest', 'Box', 'off');
lg0.FontSize = 10;
ax.Toolbar.Visible = 'off';

lg = legend(axList(1), {"early-onset", "late-onset", "no onset"}, 'Location', 'southoutside', ...
	'Orientation', 'horizontal', 'Box', 'off');
lg.FontSize = 12;
ttl = title(tl, sprintf('early-onset: Learned \\rightarrow Transfer, Wilcoxon p=%.3f', pE));
ttl.FontSize = 12;

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS4A_EarlyOnsetFractionByPhase.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4A_Frac', frac);
assignin('base', 'FigS4A_P', struct('pEarly', pE, 'pLate', pL));
