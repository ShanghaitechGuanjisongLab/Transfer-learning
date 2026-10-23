%% FigS4B_PreCueDistanceTrace.m
% English FigS4B: population-state distance to the learned trajectory over time
% （仿 Nature 2026 s41586-026-11174-3 Fig.3a-b：non-target 神经元 PCA → 与 learned
%   movement trial 平均轨迹的欧氏距离随时间的 profile，hit/miss 分开）
% 口径：PCA 在 non-early 细胞的 cue±2 s 活动上拟合（Learned block），保留 80%
% 方差；learned trajectory = Learned hit trial 的平均 PC 轨迹（对 Learned 自身
% hit 用 leave-one-out）；逐 trial 距离 d(t)。灰色竖带 = 线索前分析窗
% [-0.5, 0] s（文献 Fig.3b 的 pre-activity 窗）。
% 示例鼠：Transfer 中 hit 与 miss 各 ≥5 trial 且非 early 细胞最多的鼠。
%
% Outputs (SVG): English_FigS4B_PreCueDistanceTrace.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M; P = S.P;

% 选示例鼠：Transfer 内 hit/miss 均 >=5，细胞数最多
cand = [];
for i = 1:numel(M)
	nH = sum(M(i).YT == 1); nM_ = sum(M(i).YT == 0);
	if nH >= 5 && nM_ >= 5, cand(end+1) = i; end %#ok<SAGROW>
end
if isempty(cand), error('FigS4B:NoMouse', '无 hit/miss 均 >=5 的鼠。'); end
[~, im] = max([M(cand).nC]);
iS = cand(im);
m = M(iS);
fprintf('示例鼠 %s（nC=%d, Transfer hit=%d miss=%d）\n', m.Mouse, m.nC, sum(m.YT==1), sum(m.YT==0));

hitColor = TransferLearning.ColorA;
missColor = TransferLearning.ColorB;
phaseName = ["Learned (🔊💧)", "Transfer (💡💧)"];

f = figure('Color', 'w', 'Name', 'English FigS4B PreCueDistanceTrace');
f.Units = 'centimeters';
f.Position(3:4) = [15, 8];
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% ---- tile 1：PC 空间轨迹（仿 Fig.4b left：learned 黑线 + 高/低相似 trial 灰线）----
ax = nexttile(tl);
hold(ax, 'on'); box(ax, 'off');
ax.FontSize = 12; ax.FontName = 'Segoe UI Emoji'; ax.LineWidth = 2;
wF = m.tF >= -0.5 & m.tF <= 1.0;                 % 线索前 0.5 s + 线索后 1 s（文献两窗合并展示）
tW = m.tF(wF);
trajL = squeeze(mean(m.coordsL(:, wF, :), 1));   % nFw x k
thrC = prctile(m.corrT, [33.3, 66.6]);
hiT = m.corrT > thrC(2); loT = m.corrT < thrC(1);
trajH = squeeze(mean(m.coordsT(hiT, wF, :), 1));
trajLo = squeeze(mean(m.coordsT(loT, wF, :), 1));
plot(ax, trajL(:,1), trajL(:,2), '-', 'Color', [0 0 0], 'LineWidth', 2);
hH = plot(ax, trajH(:,1), trajH(:,2), '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.6);
hLo = plot(ax, trajLo(:,1), trajLo(:,2), ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.6);
[~, iCueW] = min(abs(tW - 0));
[~, iLkW] = min(abs(tW - m.lickOnT));
plot(ax, trajL(iCueW,1), trajL(iCueW,2), 'o', 'Color', [0 0 0], 'MarkerFaceColor', 'w', 'MarkerSize', 7, 'LineWidth', 1.6);
plot(ax, trajL(iLkW,1), trajL(iLkW,2), '.', 'Color', [0 0 0], 'MarkerSize', 14);
xlabel(ax, 'PC1'); ylabel(ax, 'PC2');
title(ax, sprintf('%s — population trajectories', m.Mouse), 'FontSize', 12, 'FontWeight', 'normal');
lg1 = legend(ax, [plot(ax, nan, nan, '-', 'Color', [0 0 0], 'LineWidth', 2), hH, hLo], ...
	{'Learned (mean)', 'Transfer high-corr', 'Transfer low-corr'}, 'Location', 'best', 'Box', 'off');
lg1.FontSize = 9;
ax.Toolbar.Visible = 'off';

% ---- tile 2：距离时间过程（hit/miss，仿 ED Fig.10 的 mean±SEM 时间过程样式）----
hHit = gobjects(1); hMiss = gobjects(1);
ax2 = nexttile(tl);
hold(ax2, 'on'); box(ax2, 'off');
ax2.FontSize = 12; ax2.FontName = 'Segoe UI Emoji'; ax2.LineWidth = 2;
D = m.dProfT; Y = m.YT;
muAll = mean(D, 1, 'omitnan');
for grp = 1:2
	sel = (Y == (2-grp));                  % grp=1 → hit, grp=2 → miss
	if sum(sel) < 2, continue; end
	Dg = D(sel, :);
	mu = mean(Dg, 1, 'omitnan');
	se = std(Dg, 0, 1, 'omitnan') ./ sqrt(sum(sel));
	if grp == 1, c = hitColor; else, c = missColor; end
	patch(ax2, [m.tF(:); flipud(m.tF(:))], [mu(:) + se(:); flipud(mu(:) - se(:))], c, ...
		'EdgeColor', 'none', 'FaceAlpha', 0.25);
	h = plot(ax2, m.tF, mu, '-', 'Color', c, 'LineWidth', 2);
	if grp == 1, hHit = h; else, hMiss = h; end
end
plot(ax2, m.tF, muAll, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
uistack(findobj(ax2, 'Type', 'patch'), 'bottom');
ylA = ylim(ax2);
hBand = fill(ax2, [P.preWin(1) P.preWin(2) P.preWin(2) P.preWin(1)], ...
	[ylA(1) ylA(1) ylA(2) ylA(2)], [0.88 0.88 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.8);
uistack(hBand, 'bottom');
xline(ax2, 0, ':k', 'LineWidth', 2);
ylB = ylim(ax2);
ylim(ax2, [max(0, ylB(1)), 1.25*ylB(2)]);
xlim(P.tWin);
xlabel(ax2, 'Time from cue (s)');
ylabel(ax2, 'Distance to learned trajectory');
title(ax2, phaseName(2), 'FontSize', 12, 'FontWeight', 'normal');
ax2.Toolbar.Visible = 'off';
if isvalid(hHit) && isvalid(hMiss)
	lg = legend(ax2, [hHit, hMiss], {'Hit', 'Miss'}, 'Location', 'northeast', 'Box', 'off');
	lg.FontSize = 10;
end
ttl = title(tl, 'PC-space distance to learned trajectory (non-early cells, 80% var.)');
ttl.FontSize = 12;

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS4B_PreCueDistanceTrace.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4B_Mouse', m.Mouse);
