% Fig5a_Formation.m —— 论点①：Naive → Learned 形成一个**新的**低维稳定结构
%
% 3 行 × 3 列（20 × 12.5 cm，Scale 2）
%   (a) 轨迹 ALB Naive vs Learned
%   (b) split-half reliability（ALB matched-trial）—— 测量前提
%   (c) overlap(Naive, Learned) —— 低值 ⇒ 新结构，不是旧结构变清晰
%   (d) participation ratio（有效维度）
%   (e) twoNN 内在维度
%   (f) 单阶段自稳定（子空间 split-half overlap）
%   (g) 轨迹平滑度（二阶/一阶差分能量）
%   (h) 置换零模型 z（PR 与平滑度 vs 时间打乱）
%   (i) Procrustes d_norot（形状距离）
%
% 口径：MOp2/3，0–8 s（65 帧），k=3，超鼠 10 线；逐鼠统计（ALB n=10，V7 n=6）
% 数据：Check_ManifoldSimilarity_MOp2-3_k3_w8000ms.csv、Check_NullModels_MOp2-3.csv、
%       Check_ReliabilityAndTemplateCos_MOp2-3.csv、tempdir/PCAstage_G_MOp2-3.mat

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

cNaive   = TransferLearning.ColorNaive   / 255;
cLearned = TransferLearning.ColorLearned / 255;
cALB     = TransferLearning.ColorAudio   / 255;
cV7      = TransferLearning.Color7d      / 255;

nSeg = 60; smoothFrames = 1; kCV = 3;

%% ================= 数据 =================
MS = readtable(fullfile(thisDir, 'Check_ManifoldSimilarity_MOp2-3_k3_w8000ms.csv'), 'TextType', 'string');
NM = readtable(fullfile(thisDir, 'Check_NullModels_MOp2-3.csv'), 'TextType', 'string');
TR = readtable(fullfile(thisDir, 'Check_ReliabilityAndTemplateCos_MOp2-3.csv'), 'TextType', 'string');
TR = TR(TR.Cohort == "ALB", :);
relN = TR.rel_NaiveAO; relL = TR.rel_LrnAW;
ok = isfinite(relN) & isfinite(relL); relN = relN(ok); relL = relL(ok);

mNL = @(c, v) MS{MS.Cohort == c & MS.Pair == "N→L", v};
zOf = @(c, t) NM.Z(NM.Cohort == c & NM.Test == t);

%% ================= 画布 =================
f = figure('Color', 'w', 'Name', 'Fig5a formation');
f.Units = 'centimeters';
f.Position = [2, 2, 20, 12.5];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 20, 12.5];
f.PaperSize = [20, 12.5];
tlo = tiledlayout(f, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

%% ---------- (a) 轨迹 ALB Naive vs Learned ----------
cacheFile = fullfile(tempdir, 'PCAstage_G_MOp2-3.mat');
assert(exist(cacheFile, 'file') == 2, 'Fig5a:NoCache', '缺 %s', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));
iDS = find(dsNames == "ALB", 1);
nL = size(G{iDS, 1}.NTATS.Data, 3);
common = G{iDS, 1}.CellUID;
for iS = 2:4, common = intersect(common, G{iDS, iS}.CellUID); end
common = sort(unique(common));
nOut = size(G{iDS, 1}.NTATS.Data, 2);
data = nan(numel(common), nOut, 4 * nL); MOst = cell(1, 4);
for iS = 1:4
	[~, loc] = ismember(common, G{iDS, iS}.CellUID);
	data(:, :, (iS - 1) * nL + (1:nL)) = double(G{iDS, iS}.NTATS.Data(loc, :, :));
	MOst{iS} = string(G{iDS, iS}.Mouse(loc));
end
Tp = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), 2, true);
Sc = double(Tp.Score.Data);
axA = nexttile(tlo);
iGrad(axA, Sc(:, :, (1 - 1) * nL + (1:nL)), cNaive, nSeg, smoothFrames);
iGrad(axA, Sc(:, :, (2 - 1) * nL + (1:nL)), cLearned, nSeg, smoothFrames);
axA.Box = 'off'; axA.XTick = []; axA.YTick = []; axA.LineWidth = 1;
ylabel(axA, 'PC2'); xlabel(axA, 'PC1');
title(axA, '(a)', 'FontWeight', 'normal');
hold(axA, 'on');
h1 = plot(axA, nan, nan, '-', 'Color', cNaive, 'LineWidth', 1.5, 'DisplayName', 'Naive');
h2 = plot(axA, nan, nan, '-', 'Color', cLearned, 'LineWidth', 1.5, 'DisplayName', 'Learned');
setappdata(h1, 'TransferLearningPreserveLineWidth', true);
setappdata(h2, 'TransferLearningPreserveLineWidth', true);
lgd = legend(axA, [h1 h2], 'Box', 'off', 'Location', 'southeast');
lgd.NumColumns = 1; lgd.FontSize = 6; lgd.ItemTokenSize = [6 6];

%% ---------- (b) 同一组方向，对两个阶段的解释力 ----------
% 红柱：Naive 前3个 PC 各自解释 Naive 数据的方差（自身谱）；
% 青柱：同一组方向（Naive 的 PC）去加权 Learned 细胞，解释 Learned 的方差。
% 若两阶段结构相同，青柱应与红柱等高；实测塌一个数量级 ⇒ 方向不共享（新）。
axB = nexttile(tlo);
nPC = 3;
M0 = mean(data(:, :, 1:nL), 3, 'omitnan');
M1 = mean(data(:, :, nL + (1:nL)), 3, 'omitnan');
Ma = M0 - mean(M0, 2); Mb = M1 - mean(M1, 2);
[Ua, ~, ~] = svd(Ma, 'econ');
vOwn = 100 * sum((Ua(:, 1:nPC)' * Ma) .^ 2, 2) / sum(Ma(:) .^ 2);
vCro = 100 * sum((Ua(:, 1:nPC)' * Mb) .^ 2, 2) / sum(Mb(:) .^ 2);
hold(axB, 'on');
bar(axB, (1:nPC) - 0.17, vOwn, 0.30, 'FaceColor', cNaive, 'EdgeColor', 'none', 'HandleVisibility', 'off');
bar(axB, (1:nPC) + 0.17, vCro, 0.30, 'FaceColor', cLearned, 'EdgeColor', 'none', 'HandleVisibility', 'off');
yline(axB, rnd, ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.7, 'HandleVisibility', 'off');
axB.XTick = 1:nPC; axB.XTickLabel = {'PC1', 'PC2', 'PC3'};
xlim(axB, [0.5 nPC + 0.5]); ylim(axB, [0 58]);
ylabel(axB, 'variance explained (%)');
text(axB, 0.95, 50, 'Naive data', 'Color', cNaive, 'FontSize', 4.5);
text(axB, 0.95, 43, 'Learned data', 'Color', cLearned, 'FontSize', 4.5);
axB.Box = 'off'; axB.LineWidth = 1;
title(axB, '(b)', 'FontWeight', 'normal');
fprintf('(b) vOwn=%s  vCro=%s  sum=%s / %s\\n', mat2str(round(vOwn',1)), mat2str(round(vCro',1)), num2str(sum(vOwn),'%.1f'), num2str(sum(vCro),'%.1f'));

%% ---------- (c) overlap(Naive, Learned) ----------
axC = nexttile(tlo);
vC = mNL("ALB","overlap");
hold(axC, 'on');
bar(axC, 1, median(vC), 0.5, 'FaceColor', cALB, 'EdgeColor', 'none', 'HandleVisibility', 'off');
errorbar(axC, 1, median(vC), 1.2533*std(vC)/sqrt(numel(vC)), 'Color', cALB, 'LineStyle', 'none', 'LineWidth', 1, 'CapSize', 3, 'HandleVisibility', 'off');
plot(axC, 1 + (rand(numel(vC),1)-0.5)*0.2, vC, 'o', 'MarkerSize', 2.4, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', cALB, 'LineWidth', 0.4, 'HandleVisibility', 'off');
rBase = median(3 ./ MS.nCell(MS.Cohort=="ALB" & MS.Pair=="N→L"));
capOv = median([mNL("ALB","selfOvA"); mNL("ALB","selfOvB")]);
yline(axC, rBase, '--', 'Color', [0.62 0.62 0.62], 'LineWidth', 0.8, 'HandleVisibility', 'off');
text(axC, 0.60, rBase, 'random', 'FontSize', 5, 'Color', [0.45 0.45 0.45], 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
yline(axC, capOv, '--', 'Color', [0.30 0.30 0.30], 'LineWidth', 0.8, 'HandleVisibility', 'off');
text(axC, 0.60, capOv, 'split-half cap', 'FontSize', 5, 'Color', [0.25 0.25 0.25], 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
xlim(axC, [0.4 1.6]); axC.XTick = 1; axC.XTickLabel = {'ALB'};
axC.Box = 'off'; axC.LineWidth = 1;
ylabel(axC, 'overlap (N→L)');
title(axC, '(c)', 'FontWeight', 'normal');

%% ---------- (d) PR ----------
axD = nexttile(tlo);
iPairG(axD, {mNL("ALB","PR_A"), mNL("ALB","PR_B")}, {cNaive, cLearned}, {'Naive','Learned'});

ylabel(axD, 'PR'); title(axD, '(d)', 'FontWeight', 'normal');

%% ---------- (e) twoNN ID ----------
axE = nexttile(tlo);
iPairG(axE, {mNL("ALB","ID_A"), mNL("ALB","ID_B")}, {cNaive, cLearned}, {'Naive','Learned'});

ylabel(axE, 'ID (twoNN)'); title(axE, '(e)', 'FontWeight', 'normal');

%% ---------- (f) 交叉验证 R²：一半试次学结构，解释另一半 ----------
axF = nexttile(tlo);
rng(20261119);
[cvN, shN] = iCVr2(data(:, :, 1:nL), MOst{1}, kCV, 40);
[cvL, shL] = iCVr2(data(:, :, nL + (1:nL)), MOst{2}, kCV, 40);
hold(axF, 'on');
bar(axF, 1 - 0.14, median(cvN), 0.24, 'FaceColor', cNaive, 'EdgeColor', 'none', 'HandleVisibility', 'off');
bar(axF, 1 + 0.14, median(shN), 0.24, 'FaceColor', [0.80 0.80 0.80], 'EdgeColor', 'none', 'HandleVisibility', 'off');
bar(axF, 2 - 0.14, median(cvL), 0.24, 'FaceColor', cLearned, 'EdgeColor', 'none', 'HandleVisibility', 'off');
bar(axF, 2 + 0.14, median(shL), 0.24, 'FaceColor', [0.80 0.80 0.80], 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(axF, 1 - 0.14 + (rand(numel(cvN),1)-0.5)*0.10, cvN, 'o', 'MarkerSize', 2.2, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', cNaive, 'LineWidth', 0.4, 'HandleVisibility', 'off');
plot(axF, 2 - 0.14 + (rand(numel(cvL),1)-0.5)*0.10, cvL, 'o', 'MarkerSize', 2.2, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', cLearned, 'LineWidth', 0.4, 'HandleVisibility', 'off');
axF.XTick = 1:2; axF.XTickLabel = {'Naive','Learned'};
xlim(axF, [0.5 2.5]);
ylabel(axF, 'cv R² (k=3)'); axF.Box = 'off'; axF.LineWidth = 1;
title(axF, '(f)', 'FontWeight', 'normal');
fprintf('cvR2 ALB: Naive %.3f (shuf %.3f) -> Learned %.3f (shuf %.3f), p=%.4g\\n', median(cvN), median(shN), median(cvL), median(shL), signrank(cvN, cvL));

%% ---------- (g) 平滑度 ----------
axG = nexttile(tlo);
iPairG(axG, {mNL("ALB","smoothA"), mNL("ALB","smoothB")}, {cNaive, cLearned}, {'Naive','Learned'});

ylabel(axG, 'smoothness'); title(axG, '(g)', 'FontWeight', 'normal');
ylim(axG, [0 3.5]);

%% ---------- (h) 零模型 z ----------
axH = nexttile(tlo);
iBarG(axH, {zOf("ALB","PR/Naive"), zOf("ALB","smooth/Naive")}, {cNaive, cLearned}, {'PR','smooth'});

ylabel(axH, 'z vs shuffled'); title(axH, '(h)', 'FontWeight', 'normal');

%% ---------- (i) d_norot ----------
axI = nexttile(tlo);
vI = mNL("ALB","d_norot");
hold(axI, 'on');
bar(axI, 1, median(vI), 0.5, 'FaceColor', cALB, 'EdgeColor', 'none', 'HandleVisibility', 'off');
errorbar(axI, 1, median(vI), 1.2533*std(vI)/sqrt(numel(vI)), 'Color', cALB, 'LineStyle', 'none', 'LineWidth', 1, 'CapSize', 3, 'HandleVisibility', 'off');
plot(axI, 1 + (rand(numel(vI),1)-0.5)*0.2, vI, 'o', 'MarkerSize', 2.4, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', cALB, 'LineWidth', 0.4, 'HandleVisibility', 'off');
yline(axI, 0, '--', 'identical', 'Color', [0.62 0.62 0.62], 'LineWidth', 0.8, 'FontSize', 5, 'LabelHorizontalAlignment', 'left');
xlim(axI, [0.4 1.6]); axI.XTick = 1; axI.XTickLabel = {'ALB'};
axI.Box = 'off'; axI.LineWidth = 1;
ylabel(axI, 'd (no rotation)');
title(axI, '(i)', 'FontWeight', 'normal');

%% ---------- 显著性标注：配对比较用横线连接两根柱 ----------
pPR   = signrank(mNL("ALB","PR_A"),    mNL("ALB","PR_B"));
pPRv  = signrank(mNL("V7", "PR_A"),    mNL("V7", "PR_B"));
pID   = signrank(mNL("ALB","ID_A"),    mNL("ALB","ID_B"));
pSf   = signrank(mNL("ALB","selfOvA"), mNL("ALB","selfOvB"));
pSm   = signrank(mNL("ALB","smoothA"), mNL("ALB","smoothB"));
pD    = ranksum(mNL("ALB","d_norot"),  mNL("V7", "d_norot"));
pC    = ranksum(mNL("ALB","overlap"),  mNL("V7", "overlap"));

iBracket(axC, 1, 2, pC,  0.86);
iBracket(axD, 1, 2, pPR, 0.92);

iBracket(axE, 1, 2, pID, 0.92);
iBracket(axF, 1, 2, signrank(cvN, cvL), 0.80);
iBracket(axG, 1, 2, pSm, 0.92);

iStar(axH, 1, signrank(zOf("ALB","PR/Naive"), 0));
iStar(axH, 2, signrank(zOf("V7", "PR/Naive"), 0));
iStar(axH, 3, signrank(zOf("ALB","smooth/Naive"), 0));
iStar(axH, 4, signrank(zOf("V7", "smooth/Naive"), 0));
fprintf('p: PR %.3g / PRv %.3g / ID %.3g / selfOv %.3g / smooth %.3g / d %.3g / c %.3g\\n', pPR, pPRv, pID, pSf, pSm, pD, pC);

%% ================= 导出 =================
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig5a_Formation.svg');
fprintf('Wrote: %s\n', svgPath);
exportgraphics(f, fullfile(thisDir, '_fig5a_check.png'), 'Resolution', 400, 'BackgroundColor', 'white');

%% ================= 局部函数 =================
function iGrad(ax, X, color, nSeg, smoothFrames)
if smoothFrames > 1, X = movmean(X, smoothFrames, 2); end
nL = size(X, 3); nT = size(X, 2);
tt = linspace(1, nT, nSeg + 1);
w = linspace(0, 1, nSeg + 1)';
c0 = 0.75 + 0.25 * color(:)';
cv = c0 + w * (color(:)' - c0);
Xp = nan(nSeg + 2, nL); Yp = nan(nSeg + 2, nL);
for i = 1:nL
	xy = squeeze(X(:, :, i));
	Xp(1:nSeg + 1, i) = interp1(1:nT, xy(1, :), tt);
	Yp(1:nSeg + 1, i) = interp1(1:nT, xy(2, :), tt);
end
C = repmat(reshape(cv, [nSeg + 1, 1, 3]), 1, nL, 1);
C(end + 1, :, :) = repmat(reshape(cv(end, :), [1, 1, 3]), 1, nL, 1);
hold(ax, 'on');
hi = patch(ax, Xp, Yp, C, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.0, 'EdgeAlpha', 0.26, 'HandleVisibility', 'off');
setappdata(hi, 'TransferLearningPreserveLineWidth', true);
Xm = mean(Xp, 2, 'omitnan'); Ym = mean(Yp, 2, 'omitnan');
Cm = reshape(cv, [nSeg + 1, 1, 3]);
Cm(end + 1, :, :) = reshape(cv(end, :), [1, 1, 3]);
hd = patch(ax, Xm, Ym, Cm * 0.58, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 2.2, 'HandleVisibility', 'off');
setappdata(hd, 'TransferLearningPreserveLineWidth', true);
hc = patch(ax, Xm, Ym, Cm, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.5, 'HandleVisibility', 'off');
setappdata(hc, 'TransferLearningPreserveLineWidth', true);
end

function iPair(ax, S, C, lab)
% 多条件配对散点 + 连线 + 均值/SEM
hold(ax, 'on');
n = numel(S); v = S{1}(:); m = numel(v);
M = nan(m, n);
for i = 1:n, vv = S{i}(:); M(:, i) = vv(1:min(m, numel(vv))); end
for i = 1:m
	if all(isfinite(M(i, :)))
		plot(ax, 1:n, M(i, :), '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5, 'HandleVisibility', 'off');
	end
end
for i = 1:n
	vv = M(:, i); vv = vv(isfinite(vv));
	plot(ax, i + (rand(numel(vv), 1) - 0.5) * 0.18, vv, 'o', 'MarkerSize', 2.6, ...
		'MarkerFaceColor', C{i}, 'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
	mu = mean(vv); se = std(vv) / sqrt(numel(vv));
	errorbar(ax, i, mu, se, 'Color', C{i}, 'LineStyle', 'none', ...
		'LineWidth', 1.2, 'CapSize', 4, 'HandleVisibility', 'off');
	plot(ax, i, mu, '_', 'Color', C{i}, 'MarkerSize', 8, 'LineWidth', 1.4, 'HandleVisibility', 'off');
end
xlim(ax, [0.6 n + 0.4]); ax.XTick = 1:n; ax.XTickLabel = lab;
ax.Box = 'off'; ax.LineWidth = 1;
end

function iTwoSeries(ax, A, B, cA, cB, useMed)
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
			mu = median(v); se = 1.2533 * std(v) / sqrt(numel(v));
		else
	mu = median(v); se = 1.2533*std(v)/sqrt(numel(v));
		end
		bar(ax, g + dx, mu, 0.28, 'FaceColor', cc, 'EdgeColor', 'none', 'HandleVisibility', 'off');
		errorbar(ax, g + dx, mu, se, 'Color', cc, 'LineStyle', 'none', ...
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


function iSig(ax, x1, x2, p, fOff)
if ~isfinite(p) || p >= 0.05, return; end   % 只标显著
if nargin < 6, xTxtFrac = 0.5; end
yl = ylim(ax); yr = diff(yl);
y = yl(2) - fOff * yr; h = 0.022 * yr;
plot(ax, [x1 x1 x2 x2], [y - h, y, y, y - h], '-', 'Color', [0.35 0.35 0.35], ...
	'LineWidth', 0.6, 'HandleVisibility', 'off');
if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; elseif p < 0.05, s = '*'; else, s = 'n.s.'; end
text(ax, mean([x1 x2]), y + 0.006 * yr, s, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'middle', 'HandleVisibility', 'off');
end

function iStar(ax, x, p)
if ~isfinite(p) || p >= 0.05, return; end
yl = ylim(ax); yr = diff(yl);
hb = findall(ax, 'Type', 'Bar');
top = yl(2);
if ~isempty(hb)
	xe = hb(1).XEndPoints; ye = hb(1).YEndPoints;
	[~, j] = min(abs(xe - x)); top = max(ye(j), 0);
end
if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; elseif p < 0.05, s = '*'; else, return; end
text(ax, x, yl(1) + 0.93 * yr, s, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end
function iPairG(ax, S, C, lab)
% 每组一根柱 + 逐鼠散点；1↔2 与 3↔4 内部配对连线（同队列前后）
hold(ax, 'on');
n = numel(S);
if n == 4
	link = [1 2; 3 4];
elseif n == 6
	link = [1 2; 3 4; 5 6];
else
	link = zeros(0, 2);
end
for r = 1:size(link, 1)
	a = S{link(r, 1)}(:); b = S{link(r, 2)}(:);
	m = min(numel(a), numel(b));
	for i = 1:m
		if isfinite(a(i)) && isfinite(b(i))
			plot(ax, [link(r, 1), link(r, 2)], [a(i), b(i)], '-', 'Color', [0.82 0.82 0.82], ...
				'LineWidth', 0.4, 'HandleVisibility', 'off');
		end
	end
end
for k = 1:n
	v = S{k}(:); v = v(isfinite(v));
	if isempty(v), continue; end
	mu = mean(v); se = std(v) / sqrt(numel(v));
	bar(ax, k, mu, 0.55, 'FaceColor', C{k}, 'EdgeColor', 'none', 'HandleVisibility', 'off');
	errorbar(ax, k, mu, se, 'Color', C{k}, 'LineStyle', 'none', 'LineWidth', 1, ...
		'CapSize', 3, 'HandleVisibility', 'off');
	plot(ax, k + (rand(numel(v), 1) - 0.5) * 0.2, v, 'o', 'MarkerSize', 2.2, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', C{k}, 'LineWidth', 0.4, 'HandleVisibility', 'off');
end
xlim(ax, [0.4 n + 0.6]); ax.XTick = 1:n; ax.XTickLabel = lab;
yline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.Box = 'off'; ax.LineWidth = 1;
end


function iBarG(ax, S, C, lab)
% 多组独立柱（无配对连线）
hold(ax, 'on');
for k = 1:numel(S)
	v = S{k}(:); v = v(isfinite(v));
	if isempty(v), continue; end
	mu = mean(v); se = std(v) / sqrt(numel(v));
	bar(ax, k, mu, 0.55, 'FaceColor', C{k}, 'EdgeColor', 'none', 'HandleVisibility', 'off');
	errorbar(ax, k, mu, se, 'Color', C{k}, 'LineStyle', 'none', 'LineWidth', 1, ...
		'CapSize', 3, 'HandleVisibility', 'off');
	plot(ax, k + (rand(numel(v), 1) - 0.5) * 0.2, v, 'o', 'MarkerSize', 2.2, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', C{k}, 'LineWidth', 0.4, 'HandleVisibility', 'off');
end
xlim(ax, [0.4 numel(S) + 0.6]); ax.XTick = 1:numel(S); ax.XTickLabel = lab;
yline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.Box = 'off'; ax.LineWidth = 1;
end


function iBracket(ax, x1, x2, p, yFrac, xTxtFrac)
if nargin < 6, xTxtFrac = 0.5; end
if ~isfinite(p) || p >= 0.05, return; end
yl = ylim(ax); yr = diff(yl);
hb = findall(ax, 'Type', 'Bar');
if isempty(hb), top = yl(2); else, top = max(arrayfun(@(h) max(h.YEndPoints), hb)); end
if isempty(hb), y = yl(2) - 0.06*yr; else, y = min(top + 0.05*yr, yl(2) - 0.10*yr); end
h = 0.025 * yr;
plot(ax, [x1 x1 x2 x2], [y, y + h, y + h, y], '-', 'Color', [0.15 0.15 0.15], ...
	'LineWidth', 0.7, 'HandleVisibility', 'off');
if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; else, s = '*'; end
text(ax, x1 + xTxtFrac * (x2 - x1), y + h/2, s, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end


function v = iScree(M, nPC)
M = M - mean(M, 2);
s = svd(M, 'econ'); l = s .^ 2 / sum(s .^ 2) * 100;
v = l(1:min(nPC, numel(l)));
end

function v = iScreeNull(M, nPC, nRep)
% 每细胞独立打乱时间（保留单细胞边缘分布，破坏跨细胞共同时间结构）
M = M - mean(M, 2);
V = nan(nRep, nPC);
for t = 1:nRep
	Mp = M;
	for i = 1:size(M, 1)
		Mp(i, :) = M(i, randperm(size(M, 2)));
	end
	Mp = Mp - mean(Mp, 2);
	s = svd(Mp, 'econ'); l = s .^ 2 / sum(s .^ 2) * 100;
	V(t, :) = l(1:nPC);
end
v = median(V, 1);
end


function [vr, vs] = iCVr2(X, mo, k, nSplit)
% 逐鼠：一半试次学 k 维子空间解释另一半；返回每鼠的中位数（配对检验用）
uM = unique(mo); vr = nan(numel(uM), 1); vs = nan(numel(uM), 1);
for mi = 1:numel(uM)
	Xm = X(mo == uM(mi), :, :); nl = size(Xm, 3); h = floor(nl / 2);
	if h < 2, continue; end
	tr = nan(nSplit, 1); ts = nan(nSplit, 1);
	for t = 1:nSplit
		q = randperm(nl);
		A = mean(Xm(:, :, q(1:h)), 3, 'omitnan'); B = mean(Xm(:, :, q(h+1:end)), 3, 'omitnan');
		A = A - mean(A, 2); B = B - mean(B, 2);
		[U, ~, ~] = svd(A, 'econ'); U = U(:, 1:k);
		tr(t) = 1 - norm(B - U*(U'*B), 'fro')^2 / norm(B, 'fro')^2;
	end
	for t = 1:nSplit
		Z = Xm;
		for i = 1:size(Z, 1), Z(i, :, :) = Xm(i, randperm(size(Xm, 2)), :); end
		q = randperm(nl);
		A = mean(Z(:, :, q(1:h)), 3, 'omitnan'); B = mean(Z(:, :, q(h+1:end)), 3, 'omitnan');
		A = A - mean(A, 2); B = B - mean(B, 2);
		[U, ~, ~] = svd(A, 'econ'); U = U(:, 1:k);
		ts(t) = 1 - norm(B - U*(U'*B), 'fro')^2 / norm(B, 'fro')^2;
	end
	vr(mi) = median(tr); vs(mi) = median(ts);
end
ok = isfinite(vr) & isfinite(vs); vr = vr(ok); vs = vs(ok);
end
