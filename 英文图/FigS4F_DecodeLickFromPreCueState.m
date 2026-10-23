%% FigS4F_DecodeLickFromPreCueState.m
% English FigS4F: decoding learned lick pattern from pre-cue population state
% （仿 Nature 2026 s41586-026-11174-3 Fig.4d：用非运动 context 的 pre-stim 活动
%   lasso 解码 movement，检验状态是否携带 movement 信息）
% 文献口径（Fig.3d）：train = 80% voluntary trial 的 pre-stim 群体活动 → lasso；
% test = 保留 20% voluntary + opto trial；shuffle 对照；box-and-whisker + 每 session 点。
% 本工程：train = 80% Learned；test = 保留 20% Learned + 全部 Transfer；
% 目标 = 舔水 trace 与 Learned hit 模板的 Pearson r；四组 box+dot（样式对应 Fig.3d 右）。
%
% Outputs (SVG): English_FigS4F_DecodeLickFromPreCueState.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

ok = isfinite([M.decR]) | isfinite([M.decRheld]);
g1 = [M(ok).decRheld]; g2 = [M(ok).decRheldSh]; g3 = [M(ok).decR]; g4 = [M(ok).decRsh];
g2(isnan(g2)) = 0; g4(isnan(g4)) = 0;
names = {M(ok).Mouse};
kk = isfinite(g1) & isfinite(g3);          % 剔除解码失败（全零系数）的鼠
g1 = g1(kk); g2 = g2(kk); g3 = g3(kk); g4 = g4(kk); names = names(kk);
G = [g1(:), g2(:), g3(:), g4(:)];
[pH, hH] = signrank(g1, g2);
[pT, hT] = signrank(g3, g4);
[p0, h0] = signrank(g3);
fprintf('解码（Fig.3d 口径）：%d 鼠\n', numel(g1));
fprintf('  held-out Learned: 中位 r=%+.3f vs shuffle p=%.4g %s\n', median(g1,'omitnan'), pH, iifS(hH==1,'(显著)','(不显著)'));
fprintf('  Transfer:         中位 r=%+.3f vs shuffle p=%.4g %s；vs 0 p=%.4g %s\n', median(g3,'omitnan'), pT, iifS(hT==1,'(显著)','(不显著)'), p0, iifS(h0==1,'(显著)','(不显著)'));
if median(g3,'omitnan') < median(g4,'omitnan')
	ttlStr = sprintf('vs shuffled p=%.3g (below chance)', pT);
else
	ttlStr = sprintf('vs shuffled p=%.3g', pT);
end

% ---- figure（仿 Fig.3d 右：四组 box-and-whisker + 每 session/鼠 点）----
groupColor = [TransferLearning.LearnedColor; 0.75 0.75 0.75; TransferLearning.TransferColor; 0.75 0.75 0.75];
f = figure('Color', 'w', 'Name', 'English FigS4F DecodeLickFromPreCueState');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
ax = axes(f);
hold(ax, 'on'); box(ax, 'off');
ax.FontSize = 12; ax.LineWidth = 2;
for g = 1:4
	bp = boxplot(ax, G(:, g), 'Positions', g, 'Colors', groupColor(g,:), 'Symbol', '', 'Widths', 0.5);
	set(bp, 'LineWidth', 1.4);
	scatter(ax, g + 0.22*(rand(numel(G(:,g)),1)-0.5), G(:, g), 14, groupColor(g,:), 'filled', ...
		'LineWidth', 0.2, 'MarkerEdgeColor', 'k');
end
yline(ax, 0, 'k--', 'LineWidth', 1.2);
xlim([0.4, 4.6]);
set(ax, 'XTick', 1:4, 'XTickLabel', ["Learned"; "shuffled"; "Transfer"; "shuffled"], 'FontSize', 10);
xlabel(ax, 'Test set');
ylabel(ax, 'Prediction accuracy (r)');
title(ax, ttlStr, 'FontSize', 12, 'FontWeight', 'normal');
ax.Toolbar.Visible = 'off';

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS4F_DecodeLickFromPreCueState.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4F_Stats', struct('held', g1, 'heldSh', g2, 'tr', g3, 'trSh', g4, ...
	'pHeldVsShuf', pH, 'pTrVsShuf', pT, 'pTrVsZero', p0));

function s = iifS(c, a, b)
if c, s = a; else, s = b; end
end
