%% FigS4B_PreCueDistanceTrace.m
% English FigS4B: PC 轨迹与到 learned trajectory 的距离时间过程。
% 左：Fig.4b 左侧样式，cue 前 [-0.5,0] s，黑=Learned hit 均值，灰实/虚=
% Transfer 高(>0.7)/低(<=0.5)舔水相关 trial。严格只用解释 80% 方差的 PC；
% 本数据仅需 1–2 个 PC，经确认示例鼠画 PC1–PC2，不额外引入第 3 个 PC。
% 右：ED Fig.10 的 mean±SEM 误差线样式，按 Movement/No movement 分组；
% 纵轴仍是本工程的距离而非文献活动幅度，浅粉带表示实际 cue 时长 0–0.2 s。
% 示例鼠：Transfer 中 hit/miss 各 >=5、k>=2 且记录细胞最多的鼠。
%
% Outputs (SVG): English_FigS4B_PreCueDistanceTrace.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

% 选示例鼠：Transfer 内 hit/miss 均 >=5、80% 方差 PC 至少 2 个，细胞数最多
cand = [];
for i = 1:numel(M)
	nH = sum(M(i).YT == 1); nM_ = sum(M(i).YT == 0);
	if nH >= 5 && nM_ >= 5 && M(i).k >= 2, cand(end+1) = i; end %#ok<SAGROW>
end
if isempty(cand), error('FigS4B:NoMouse', '无 hit/miss 均 >=5 且至少 2 个 PC 的鼠。'); end
[~, im] = max([M(cand).nC]);
iS = cand(im);
m = M(iS);
fprintf('示例鼠 %s（nC=%d, k=%d, Transfer hit=%d miss=%d）\n', m.Mouse, m.nC, m.k, sum(m.YT==1), sum(m.YT==0));

hitColor = [0.66, 0.32, 0.50];
missColor = [0.82, 0.72, 0.67];
transferColor = hitColor;

f = figure('Color', 'w', 'Name', 'English FigS4B PreCueDistanceTrace');
f.Units = 'centimeters';
f.Position(3:4) = [12, 4];
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

% ---- tile 1：Fig.4b 左侧线型；80% PC 不足 3 个，经确认只用 PC1-2 二维 ----
ax = nexttile(tl);
hold(ax, 'on');
wF = m.tF >= -0.5 & m.tF <= 0;
hiT = m.corrT > 0.7; loT = m.corrT <= 0.5 & isfinite(m.corrT);
if ~any(hiT) || ~any(loT)
	error('FigS4B:EmptyTrajectoryGroup', '示例鼠在固定阈值下缺少高或低相似 trial。');
end
for j = find(hiT).'
	tr = squeeze(m.coordsT(j, wF, 1:2));
	plot(ax, tr(:,1), tr(:,2), '-', 'Color', [0.48, 0.48, 0.48], 'LineWidth', 0.4);
end
for j = find(loT).'
	tr = squeeze(m.coordsT(j, wF, 1:2));
	plot(ax, tr(:,1), tr(:,2), ':', 'Color', [0.48, 0.48, 0.48], 'LineWidth', 0.4);
end
trajL = squeeze(mean(m.coordsL(m.YL == 1, wF, 1:2), 1));
plot(ax, trajL(:,1), trajL(:,2), '-', 'Color', 'k', 'LineWidth', 1.25);
grid(ax, 'off'); box(ax, 'off');
set(ax, 'XTick', [], 'YTick', []);
xlabel(ax, 'PC1'); ylabel(ax, 'PC2');
text(ax, 0.02, 0.98, 'Transfer', 'Units', 'normalized', 'VerticalAlignment', 'top', ...
	'FontName', 'Arial', 'FontSize', 6, 'Color', transferColor);
iStyleAxes(ax);

% ---- tile 2：ED Fig.10 样式 mean±SEM 误差线；色带为实际 0.2 s cue ----
ax2 = nexttile(tl);
hold(ax2, 'on');
wT = m.tF >= -0.5 & m.tF <= 2;
tW = m.tF(wT);
D = m.dProfT(:, wT); Y = m.YT;
for grp = 1:2
	sel = (Y == (2-grp));
	if sum(sel) < 2, continue; end
	Dg = D(sel, :);
	mu = mean(Dg, 1, 'omitnan');
	se = std(Dg, 0, 1, 'omitnan') ./ sqrt(sum(sel));
	if grp == 1, c = hitColor; else, c = missColor; end
	errorbar(ax2, tW, mu, se, '-', 'Color', c, 'LineWidth', 0.75, 'CapSize', 1.5);
end
xlim(ax2, [-0.5, 2]); set(ax2, 'XTick', 0:1:2);
yl = ylim(ax2); yl(1) = 0; ylim(ax2, yl);
hBand = fill(ax2, [0, 0.2, 0.2, 0], [yl(1), yl(1), yl(2), yl(2)], ...
	[0.96, 0.86, 0.91], 'EdgeColor', 'none');
uistack(hBand, 'bottom');
text(ax2, 0.03, 0.95, 'Movement', 'Units', 'normalized', 'VerticalAlignment', 'top', ...
	'FontName', 'Arial', 'FontSize', 6, 'Color', hitColor);
text(ax2, 0.03, 0.85, 'No movement', 'Units', 'normalized', 'VerticalAlignment', 'top', ...
	'FontName', 'Arial', 'FontSize', 6, 'Color', missColor);
xlabel(ax2, 'Time from cue onset (s)');
ylabel(ax2, 'Distance to learned trajectory');
iStyleAxes(ax2);

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS4B_PreCueDistanceTrace.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4B_Mouse', m.Mouse);

function iStyleAxes(ax)
box(ax, 'off');
ax.FontName = 'Arial'; ax.FontSize = 6; ax.LineWidth = 0.5;
ax.XColor = 'k'; ax.YColor = 'k'; ax.TickDir = 'out'; ax.TickLength = [0.025, 0.025];
ax.LabelFontSizeMultiplier = 1; ax.TitleFontSizeMultiplier = 1;
if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end
