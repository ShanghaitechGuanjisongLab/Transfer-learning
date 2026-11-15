% FigS5A：强化（给水）因子能否单独解释表征可靠度的上升？
%
% 位置：Fig5 的补充图。配合主图 (e)。
%
% 设计：LAInterspersed（光→声穿插）内部天然的 2×2
%         LightOnly(无给水) / LightWater(给水)  ×  Naive(未学) / Transfer(已学)
%       同一天、同一阶段、同一条线索（光），唯一差别是"这一试次给不给水"。
%
% 判读：学习效应大（前两根柱），给水效应≈0（后两根柱压零线）。
%       ⇒ 分阶段范式（ALB）中 rel 的上升不能归因于给水/舔。
%
% 数据：Check_ProbeWaterControl_MOp2-3.csv
% 导出：English_FigS5A_ProbeWaterControl.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

T = readtable(fullfile(thisDir, 'Check_ProbeWaterControl_MOp2-3.csv'), 'TextType', 'string');
ok = isfinite(T.rel_NaiveLO) & isfinite(T.rel_NaiveLW) & ...
	isfinite(T.rel_TrnLO) & isfinite(T.rel_TrnLW);
T = T(ok, :);

P = TransferLearning.CodexPaletteLight();
if max(P(:)) > 1, P = double(P) / 255; end
cNaive = P(9, :);      % Sky
cTrans = P(5, :);      % Peach
cLearn = P(11, :);     % Blue
cGrey  = [0.55 0.55 0.55];
mixW = @(c, w) c + (1 - c) * w;   % 向白色混合

cNL = mixW(cNaive, 0.52); cNW = cNaive;
cTL = mixW(cTrans, 0.52); cTW = cTrans;

nM = height(T);
sem = @(x) std(x, 'omitnan') / sqrt(sum(isfinite(x)));

%% ---------- 画布 ----------
f = figure('Color', 'w', 'Name', 'FigS5A reinforcement control');
f.Units = 'centimeters';
f.Position(3:4) = [15.0, 8.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 15.0, 8.0];
f.PaperSize = [15.0, 8.0];

tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

%% ================= (a) 四个条件的原始可靠度 =================
axA = nexttile(tlo);
hold(axA, 'on');
xx = [1 2];
dx = 0.19; bw = 0.34;
mLO = [mean(T.rel_NaiveLO, 'omitnan'), mean(T.rel_TrnLO, 'omitnan')];
mLW = [mean(T.rel_NaiveLW, 'omitnan'), mean(T.rel_TrnLW, 'omitnan')];
RAW = {T.rel_NaiveLO, T.rel_TrnLO; T.rel_NaiveLW, T.rel_TrnLW};   % 2×2 cell

% 空心 = LightOnly（无给水）；实心 = LightWater（给水）
hb = bar(axA, xx, [mLO(:), mLW(:)], 0.60, 'FaceColor', 'flat', 'EdgeColor', 'none');
hb(1).FaceColor = 'w'; hb(1).EdgeColor = 'flat'; hb(1).LineWidth = 0.8;
hb(1).CData = [cNaive; cTrans];
hb(2).FaceColor = 'flat'; hb(2).EdgeColor = 'none';
hb(2).CData = [cNaive; cTrans];
xL = hb(1).XEndPoints;            % LightOnly 柱中心
xW = hb(2).XEndPoints;            % LightWater 柱中心
dxL = xW(1) - xL(1);

% 配对连线：同一只鼠、同一阶段，无给水 ↔ 给水
for i = 1:nM
	plot(axA, [xL(1), xW(1)], [T.rel_NaiveLO(i), T.rel_NaiveLW(i)], ...
		'-', 'Color', [0.80 0.80 0.80], 'LineWidth', 0.35, 'HandleVisibility', 'off');
	plot(axA, [xL(2), xW(2)], [T.rel_TrnLO(i), T.rel_TrnLW(i)], ...
		'-', 'Color', [0.80 0.80 0.80], 'LineWidth', 0.35, 'HandleVisibility', 'off');
end

xp = [xL(1), xL(2), xW(1), xW(2)];
for k = 1:4
	rr = 1 + (k > 2);                       % 1 = LightOnly, 2 = LightWater
	cs = 1 + (k == 2 || k == 4);            % 1 = Naive, 2 = Transfer
	cc = cNaive; if cs == 2, cc = cTrans; end
	if rr == 2, cc = cc * 0.72; end
	y = RAW{rr, cs};
	plot(axA, xp(k) + (rand(nM, 1) - 0.5) * dxL * 0.70, y, 'o', 'MarkerSize', 2.4, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', cc, ...
		'LineWidth', 0.5, 'HandleVisibility', 'off');
	errorbar(axA, xp(k), mean(y, 'omitnan'), sem(y), 'Color', cc, ...
		'LineStyle', 'none', 'LineWidth', 0.9, 'CapSize', 3, ...
		'HandleVisibility', 'off');
end

axA.XTick = xx; axA.XTickLabel = {'Naive', 'Transfer'};
ylabel(axA, 'rel.');
iTail(axA);
title(axA, '(a)', 'FontWeight', 'normal');

h1 = plot(axA, nan, nan, 's', 'MarkerSize', 4, 'MarkerFaceColor', 'w', ...
	'MarkerEdgeColor', [0.45 0.45 0.45], 'LineWidth', 0.8, 'DisplayName', 'LightOnly');
h2 = plot(axA, nan, nan, 's', 'MarkerSize', 4, 'MarkerFaceColor', [0.45 0.45 0.45], ...
	'MarkerEdgeColor', 'none', 'DisplayName', 'LightWater');
lgd = legend(axA, [h1, h2], 'Orientation', 'horizontal', 'Box', 'off');
lgd.Layout.Tile = 'north';

%% ================= (b) 效应量 =================
axB = nexttile(tlo);
hold(axB, 'on');

dLearnLO = T.rel_TrnLO - T.rel_NaiveLO;            % 学习效应（无给水）
dLearnLW = T.rel_TrnLW - T.rel_NaiveLW;            % 学习效应（给水）
dWaterN  = T.rel_NaiveLW - T.rel_NaiveLO;          % 给水效应（未学）
dWaterT  = T.rel_TrnLW - T.rel_TrnLO;              % 给水效应（已学）
D = [dLearnLO, dLearnLW, dWaterN, dWaterT];
nmE = {'Learn LO', 'Learn LW', 'Water (Naive)', 'Water (Transfer)'};
colE = {cLearn, cLearn, cGrey, cGrey};

ye = 1:4;
hb = barh(axB, ye, mean(D, 1, 'omitnan'), 0.62, 'FaceColor', 'flat', 'EdgeColor', 'none');
hb.CData = vertcat(colE{:});
hb.EdgeColor = 'none';
for k = 1:4
	errorbar(axB, mean(D(:, k), 'omitnan'), ye(k), sem(D(:, k)), 'horizontal', ...
		'Color', colE{k} * 0.6, 'LineStyle', 'none', 'LineWidth', 0.9, ...
		'CapSize', 3, 'HandleVisibility', 'off');
end
for k = 1:4
	plot(axB, D(:, k), ye(k) + (rand(nM, 1) - 0.5) * 0.28, 'o', 'MarkerSize', 2.4, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', colE{k} * 0.6, ...
		'LineWidth', 0.5, 'HandleVisibility', 'off');
end
xline(axB, 0, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.6, 'HandleVisibility', 'off');

axB.YTick = ye; axB.YTickLabel = nmE; axB.YDir = 'reverse';
xlabel(axB, 'Δ rel.');
iTail(axB);
title(axB, '(b)', 'FontWeight', 'normal');

%% ---------- 导出 ----------
TransferLearning.ApplyStandardExportStyle(f, 2);
lgd.FontSize = axA.FontSize;
svgPath = TransferLearning.StandardFigureSvgPath('English_FigS5A_ProbeWaterControl.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ---------- 自检图（本地，检查后删） ----------
exportgraphics(f, fullfile(thisDir, '_figs5a_check.png'), 'Resolution', 400);

%% ========== local ==========
function iTail(ax)
ax.Box = 'off';
ax.TickDir = 'out';
end
