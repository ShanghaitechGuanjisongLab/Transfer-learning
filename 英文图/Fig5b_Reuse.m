% Fig5b_Reuse.m —— 论点②：Learned → Transfer 复用同一低维结构
%
% 3 行 × 3 列（20 × 12.5 cm，Scale 2）
%   (a) 轨迹 ALB Learned vs Transfer
%   (b) subspace overlap（3 阶段对 × 2 队列）
%   (c) ovRatio（overlap ÷ 同阶段 split-half 上限）
%   (d) alignment index（Transfer 的方差被 Learned 子空间捕获的比例）
%   (e) θ̄（平均主角度）
%   (f) participation ratio（Learned vs Transfer）
%   (g) twoNN 内在维度
%   (h) 三模板独特方差（Cue / Learned / Action）
%   (i) 零模型 z（overlap vs 时间打乱，3 阶段对）
%
% 口径：MOp2/3，0–8 s，k=3，独立估子空间；逐鼠（ALB n=10，V7 n=6）

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

cALB     = TransferLearning.ColorAudio   / 255;
cV7      = TransferLearning.Color7d      / 255;
cLearned = TransferLearning.ColorLearned / 255;
cTransfer= TransferLearning.Color12h     / 255;
cTmplC   = TransferLearning.ColorcFos    / 255;
cTmplA   = TransferLearning.ColorTH      / 255;

nSeg = 60; smoothFrames = 1;

MS = readtable(fullfile(thisDir, 'Check_ManifoldSimilarity_MOp2-3_k3_w8000ms.csv'), 'TextType', 'string');
NM = readtable(fullfile(thisDir, 'Check_NullModels_MOp2-3.csv'), 'TextType', 'string');
FD = readtable(fullfile(thisDir, 'RepresentationReuse_FormalVarDecomp_MOp2-3.csv'), 'TextType', 'string');
FD = FD(FD.Subset == "all", :);

mp = @(c, pn, v) MS{MS.Cohort == c & MS.Pair == pn, v};
zOf = @(c, t) NM.Z(NM.Cohort == c & NM.Test == t);

f = figure('Color', 'w', 'Name', 'Fig5b reuse');
f.Units = 'centimeters';
f.Position = [2, 2, 20, 12.5];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 20, 12.5];
f.PaperSize = [20, 12.5];
tlo = tiledlayout(f, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

%% ---------- (a) 轨迹 ALB Learned vs Transfer ----------
cacheFile = fullfile(tempdir, 'PCAstage_G_MOp2-3.mat');
assert(exist(cacheFile, 'file') == 2, 'Fig5b:NoCache', '缺 %s', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));
iDS = find(dsNames == "ALB", 1);
nL = size(G{iDS, 1}.NTATS.Data, 3);
common = G{iDS, 1}.CellUID;
for iS = 2:4, common = intersect(common, G{iDS, iS}.CellUID); end
common = sort(unique(common));
nOut = size(G{iDS, 1}.NTATS.Data, 2);
data = nan(numel(common), nOut, 4 * nL);
for iS = 1:4
	[~, loc] = ismember(common, G{iDS, iS}.CellUID);
	data(:, :, (iS - 1) * nL + (1:nL)) = double(G{iDS, iS}.NTATS.Data(loc, :, :));
end
Tp = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), 2, true);
Sc = double(Tp.Score.Data);
axA = nexttile(tlo);
iGrad(axA, Sc(:, :, 2 * nL - nL + (1:nL)), cLearned, nSeg, smoothFrames);
iGrad(axA, Sc(:, :, 3 * nL - nL + (1:nL)), cTransfer, nSeg, smoothFrames);
axA.Box = 'off'; axA.XTick = []; axA.YTick = []; axA.LineWidth = 1;
ylabel(axA, 'PC2'); xlabel(axA, 'PC1');
title(axA, '(a)', 'FontWeight', 'normal');
hold(axA, 'on');
h1 = plot(axA, nan, nan, '-', 'Color', cLearned, 'LineWidth', 1.5, 'DisplayName', 'Learned');
h2 = plot(axA, nan, nan, '-', 'Color', cTransfer, 'LineWidth', 1.5, 'DisplayName', 'Transfer');
setappdata(h1, 'TransferLearningPreserveLineWidth', true);
setappdata(h2, 'TransferLearningPreserveLineWidth', true);
lgd = legend(axA, [h1 h2], 'Box', 'off', 'Location', 'southeast');
lgd.NumColumns = 1; lgd.FontSize = 6; lgd.ItemTokenSize = [6 6];

%% ---------- (b) overlap ----------
axB = nexttile(tlo);
iBarG(axB, {mp("ALB","N→T","overlap"), mp("ALB","L→T","overlap"), mp("ALB","T→F","overlap"), ...
	mp("V7","N→T","overlap"), mp("V7","L→T","overlap"), mp("V7","T→F","overlap")}, {cALB,cALB,cALB,cV7,cV7,cV7}, {'A-NT','A-LT','A-TF','V-NT','V-LT','V-TF'});
ylabel(axB, 'overlap'); title(axB, '(b)', 'FontWeight', 'normal');

%% ---------- (c) ovRatio ----------
axC = nexttile(tlo);
iBarG(axC, {mp("ALB","N→T","ovRatio"), mp("ALB","L→T","ovRatio"), mp("ALB","T→F","ovRatio"), ...
	mp("V7","N→T","ovRatio"), mp("V7","L→T","ovRatio"), mp("V7","T→F","ovRatio")}, {cALB,cALB,cALB,cV7,cV7,cV7}, {'A-NT','A-LT','A-TF','V-NT','V-LT','V-TF'});
ylabel(axC, 'ovRatio'); title(axC, '(c)', 'FontWeight', 'normal');

%% ---------- (d) AI ----------
axD = nexttile(tlo);
iBarG(axD, {mp("ALB","N→T","AI_BA"), mp("ALB","L→T","AI_BA"), mp("ALB","T→F","AI_BA"), ...
	mp("V7","N→T","AI_BA"), mp("V7","L→T","AI_BA"), mp("V7","T→F","AI_BA")}, {cALB,cALB,cALB,cV7,cV7,cV7}, {'A-NT','A-LT','A-TF','V-NT','V-LT','V-TF'});
ylabel(axD, 'AI'); title(axD, '(d)', 'FontWeight', 'normal');

%% ---------- (e) θ̄ ----------
axE = nexttile(tlo);
iBarG(axE, {mp("ALB","N→T","thetaMean_deg"), mp("ALB","L→T","thetaMean_deg"), mp("ALB","T→F","thetaMean_deg"), ...
	mp("V7","N→T","thetaMean_deg"), mp("V7","L→T","thetaMean_deg"), mp("V7","T→F","thetaMean_deg")}, {cALB,cALB,cALB,cV7,cV7,cV7}, {'A-NT','A-LT','A-TF','V-NT','V-LT','V-TF'});
ylabel(axE, 'θ̄ (deg)'); title(axE, '(e)', 'FontWeight', 'normal');

%% ---------- (f) PR ----------
axF = nexttile(tlo);
iPairG(axF, {mp("ALB","L→T","PR_A"), mp("ALB","L→T","PR_B"), mp("V7","L→T","PR_A"), mp("V7","L→T","PR_B")}, ...
	{cALB,cALB,cV7,cV7}, {'ALB-L','ALB-T','V7-L','V7-T'});
ylabel(axF, 'participation ratio'); title(axF, '(f)', 'FontWeight', 'normal');

%% ---------- (g) twoNN ID ----------
axG = nexttile(tlo);
iPairG(axG, {mp("ALB","L→T","ID_A"), mp("ALB","L→T","ID_B"), mp("V7","L→T","ID_A"), mp("V7","L→T","ID_B")}, ...
	{cALB,cALB,cV7,cV7}, {'ALB-L','ALB-T','V7-L','V7-T'});
ylabel(axG, 'twoNN ID'); title(axG, '(g)', 'FontWeight', 'normal');

%% ---------- (h) 三模板独特方差 ----------
axH = nexttile(tlo);
gC = 100 * FD.uniq_C ./ FD.R2_full;
gL = 100 * FD.uniq_L ./ FD.R2_full;
gA = 100 * FD.uniq_A ./ FD.R2_full;
iBarH(axH, {gC, gL, gA}, {cTmplC, cLearned, cTmplA}, {'Cue', 'Learned', 'Action'});
axH.XTick = [0 50 100];
xlabel(axH, 'u (% of R^2)'); title(axH, '(h)', 'FontWeight', 'normal');

%% ---------- (i) 零模型 z ----------
axI = nexttile(tlo);
iBarG(axI, {zOf("ALB","overlap/N→T"), zOf("ALB","overlap/L→T"), ...
	zOf("V7","overlap/N→T"), zOf("V7","overlap/L→T")}, {cALB,cALB,cV7,cV7}, {'A-NT','A-LT','V-NT','V-LT'});
ylabel(axI, 'z vs shuffled'); title(axI, '(i)', 'FontWeight', 'normal');

%% ---------- 显著性标注 ----------
pOv  = signrank(mp("ALB","N→T","overlap"), mp("ALB","L→T","overlap"));
pOvV = signrank(mp("V7", "N→T","overlap"), mp("V7", "L→T","overlap"));
pPR2 = signrank(mp("ALB","L→T","PR_A"), mp("ALB","L→T","PR_B"));
iBracket(axB, 1, 2, pOv, 0.80);  iBracket(axB, 4, 5, pOvV, 0.80);
iBracket(axC, 1, 2, pOv, 0.80);  iBracket(axC, 4, 5, pOvV, 0.80);
iBracket(axD, 1, 2, pOv, 0.80);  iBracket(axD, 4, 5, pOvV, 0.80);
iBracket(axE, 1, 2, pOv, 0.80);  iBracket(axE, 4, 5, pOvV, 0.80);
iBracket(axF, 1, 2, pPR2, 0.80);
iBracket(axG, 1, 2, signrank(mp("ALB","L→T","ID_A"), mp("ALB","L→T","ID_B")), 0.80);
pnL = ["N→T","L→T","N→T","L→T"];
coL = ["ALB","ALB","V7","V7"];
zA = NM.Z(NM.Test == "overlap/N→T" & NM.Cohort == "ALB");
zB = NM.Z(NM.Test == "overlap/L→T" & NM.Cohort == "ALB");
zC = NM.Z(NM.Test == "overlap/N→T" & NM.Cohort == "V7");
zD = NM.Z(NM.Test == "overlap/L→T" & NM.Cohort == "V7");
iBracket(axI, 1, 2, signrank(zA, zB), 0.80);
iBracket(axI, 3, 4, signrank(zC, zD), 0.80);
fprintf('Wrote: %s\n', svgPath);
exportgraphics(f, fullfile(thisDir, '_fig5b_check.png'), 'Resolution', 400, 'BackgroundColor', 'white');

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

function iTS(ax, A, B, cA, cB, useMed)
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
			mu = mean(v); se = std(v) / sqrt(numel(v));
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

function iBarH(ax, D, colors, labs)
hold(ax, 'on');
nG = numel(D);
for k = 1:nG
	v = D{k}(:); v = v(isfinite(v));
	if isempty(v), continue; end
	m = mean(v); s = std(v) / sqrt(numel(v));
	barh(ax, k, m, 0.55, 'FaceColor', colors{k}, 'EdgeColor', 'none');
	errorbar(ax, m, k, s, 'horizontal', 'Color', colors{k}, 'LineStyle', 'none', ...
		'LineWidth', 1, 'CapSize', 3, 'HandleVisibility', 'off');
	plot(ax, v, k + (rand(numel(v), 1) - 0.5) * 0.26, 'o', 'MarkerSize', 2.2, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', colors{k}, 'LineWidth', 0.4, ...
		'HandleVisibility', 'off');
	text(ax, max(m, 0) + 6, k + 0.30, sprintf('%.1f', m), 'HorizontalAlignment', 'left', ...
	'VerticalAlignment', 'top', 'HandleVisibility', 'off');
end
xv = []; for kk = 1:nG, xv = [xv; D{kk}(:)]; end
xv = xv(isfinite(xv));
lo = min([0; xv]); hi = max([0; xv]);
padx = 0.04 * max(hi - lo, eps);
xlim(ax, [lo - padx, hi + padx]);
ylim(ax, [0.5 nG + 0.5]);
ax.YTick = 1:nG; ax.YTickLabel = labs;
xline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.Box = 'off'; ax.LineWidth = 1;
end


function iBarG(ax, S, C, lab)
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

function iPairG(ax, S, C, lab)
hold(ax, 'on');
n = numel(S);
if n == 4, link = [1 2; 3 4]; else, link = zeros(0, 2); end
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


function iStar(ax, x, p)
if ~isfinite(p) || p >= 0.05, return; end   % 只标显著，n.s. 放图注
yl = ylim(ax); yr = diff(yl);
if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; elseif p < 0.05, s = '*'; else, s = 'n.s.'; end
text(ax, x, yl(1) + 0.85 * yr, s, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end


function iBracket(ax, x1, x2, p, yFrac)   % yFrac 不再使用：自动放在最高柱之上
if ~isfinite(p) || p >= 0.05, return; end
yl = ylim(ax); yr = diff(yl);
hb = findall(ax, 'Type', 'Bar');
if isempty(hb), top = yl(2); else, top = max(arrayfun(@(h) max(h.YEndPoints), hb)); end
y = top + 0.06 * yr; h = 0.025 * yr;
plot(ax, [x1 x1 x2 x2], [y, y + h, y + h, y], '-', 'Color', [0.15 0.15 0.15], ...
	'LineWidth', 0.7, 'HandleVisibility', 'off');
if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; else, s = '*'; end
text(ax, (x1 + x2) / 2, y - 0.004*yr, s, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end
