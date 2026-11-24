% Fig5d_DelayLoss.m —— 论点④：停训 7 天后（V7）未观察到复用
%
% 3 行 × 2 列（20 × 12.5 cm，Scale 2）
%   (a) 轨迹 V7 Learned vs Transfer
%   (b) subspace overlap（L→T，ALB vs V7）
%   (c) RSA peakness（L→T / L→N / T→F）
%   (d) selectivity = (L→T) − (L→N)
%   (e) Procrustes d_norot（L→T）
%   (f) participation ratio（Transfer 阶段）
%
% 口径：MOp2/3，0–8 s，k=3，独立估子空间；ALB n=10，V7 n=6

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

nSeg = 60; smoothFrames = 1;

MS = readtable(fullfile(thisDir, 'Check_ManifoldSimilarity_MOp2-3_k3_w8000ms.csv'), 'TextType', 'string');
mp = @(c, pn, v) MS{MS.Cohort == c & MS.Pair == pn, v};

%% ================= 缓存 → DATA / MO =================
cacheFile = fullfile(tempdir, 'PCAstage_G_MOp2-3.mat');
assert(exist(cacheFile, 'file') == 2, 'Fig5d:NoCache', '缺 %s', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));
cohorts = ["ALB", "V7"];
DATA = cell(2, 4); MO = cell(2, 4); SC = cell(2, 4);
for k = 1:2
	iDS = find(dsNames == cohorts(k), 1);
	nL = size(G{iDS, 1}.NTATS.Data, 3);
	common = G{iDS, 1}.CellUID;
	for iS = 2:4, common = intersect(common, G{iDS, iS}.CellUID); end
	common = sort(unique(common));
	nOut = size(G{iDS, 1}.NTATS.Data, 2);
	data = nan(numel(common), nOut, 4 * nL);
	MOst = cell(1, 4);
	for iS = 1:4
		[~, loc] = ismember(common, G{iDS, iS}.CellUID);
		data(:, :, (iS - 1) * nL + (1:nL)) = double(G{iDS, iS}.NTATS.Data(loc, :, :));
		mo = string(G{iDS, iS}.Mouse(loc)); MOst{iS} = mo;
	end
	Tp = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), 2, true);
	Sc = double(Tp.Score.Data);
	for iS = 1:4
		SC{k, iS} = Sc(:, :, (iS - 1) * nL + (1:nL));
		DATA{k, iS} = data(:, :, (iS - 1) * nL + (1:nL));
		MO{k, iS} = MOst{iS};
	end
end

%% ================= RSA peakness =================
nBinR = 8; pairsR = [2 3; 2 1; 3 4]; pairLabR = ["L→T", "L→N", "T→F"];
PkR = cell(1, 2);
for k = 1:2
	PB = cell(1, 4); uM = [];
	for iS = 1:4
		X = DATA{k, iS}; nT = size(X, 2);
		ed = round(linspace(0, nT, nBinR + 1));
		mo = MO{k, iS}; uM = unique(mo);
		PB{iS} = cell(numel(uM), 1);
		for i = 1:numel(uM)
			sel = (mo == uM(i));
			Bi = nan(sum(sel), nBinR);
			for b = 1:nBinR
				Bi(:, b) = mean(mean(X(sel, (ed(b) + 1):ed(b + 1), :), 3, 'omitnan'), 2, 'omitnan');
			end
			PB{iS}{i} = Bi;
		end
	end
	PkR{k} = nan(numel(uM), numel(pairLabR));
	for i = 1:numel(uM)
		for p = 1:numel(pairLabR)
			PkR{k}(i, p) = iPeakCell(PB{pairsR(p, 1)}{i}, PB{pairsR(p, 2)}{i});
		end
	end
end
selALB = PkR{1}(:, 1) - PkR{1}(:, 2); selALB = selALB(isfinite(selALB));
selV7  = PkR{2}(:, 1) - PkR{2}(:, 2); selV7  = selV7(isfinite(selV7));

%% ================= 画布 =================
f = figure('Color', 'w', 'Name', 'Fig5d delay loss');
f.Units = 'centimeters';
f.Position = [2, 2, 20, 12.5];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 20, 12.5];
f.PaperSize = [20, 12.5];
tlo = tiledlayout(f, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

%% ---------- (a) V7 轨迹 ----------
axA = nexttile(tlo);
iGrad(axA, SC{2, 2}, cLearned, nSeg, smoothFrames);
iGrad(axA, SC{2, 3}, cTransfer, nSeg, smoothFrames);
axA.Box = 'off'; axA.XTick = []; axA.YTick = []; axA.LineWidth = 1;
ylabel(axA, 'PC2'); xlabel(axA, 'PC1');
title(axA, '(a)', 'FontWeight', 'normal');
hold(axA, 'on');
h1 = plot(axA, nan, nan, '-', 'Color', cLearned, 'LineWidth', 1.5, 'DisplayName', 'Learned');
h2 = plot(axA, nan, nan, '-', 'Color', cTransfer, 'LineWidth', 1.5, 'DisplayName', 'Transfer');
setappdata(h1, 'TransferLearningPreserveLineWidth', true);
setappdata(h2, 'TransferLearningPreserveLineWidth', true);
lgd = legend(axA, [h1 h2], 'Box', 'off', 'Location', 'southeast');
lgd.NumColumns = 1; lgd.FontSize = 5;

%% ---------- (b) overlap ----------
axB = nexttile(tlo);
iBarG(axB, {mp("ALB","L→T","overlap"), mp("V7","L→T","overlap")}, ...
	{cALB, cV7}, {'ALB','V7'});
ylabel(axB, 'overlap'); title(axB, '(b)', 'FontWeight', 'normal');

%% ---------- (c) peakness ----------
axC = nexttile(tlo);
iBarG(axC, {PkR{1}(:,1), PkR{1}(:,2), PkR{1}(:,3), PkR{2}(:,1), PkR{2}(:,2), PkR{2}(:,3)}, ...
	{cALB,cALB,cALB,cV7,cV7,cV7}, {'A-LT','A-LN','A-TF','V-LT','V-LN','V-TF'});
ylabel(axC, 'temporal peakness'); title(axC, '(c)', 'FontWeight', 'normal');

%% ---------- (d) selectivity ----------
axD = nexttile(tlo);
iBarG(axD, {selALB, selV7}, {cALB, cV7}, {'ALB','V7'});

ylabel(axD, 'selectivity'); title(axD, '(d)', 'FontWeight', 'normal');

%% ---------- (e) d_norot ----------
axE = nexttile(tlo);
iBarG(axE, {mp("ALB","L→T","d_norot"), mp("V7","L→T","d_norot")}, ...
	{cALB, cV7}, {'ALB','V7'});
ylabel(axE, 'd (no rotation)'); title(axE, '(e)', 'FontWeight', 'normal');

%% ---------- (f) PR ----------
axF = nexttile(tlo);
iBarG(axF, {mp("ALB","L→T","PR_B"), mp("V7","L→T","PR_B")}, ...
	{cALB, cV7}, {'ALB','V7'});
ylabel(axF, 'participation ratio'); title(axF, '(f)', 'FontWeight', 'normal');

%% ---------- 显著性标注（bracket 连接对应柱）----------
iBracket(axB, 1, 2, ranksum(mp("ALB","L→T","overlap"), mp("V7","L→T","overlap")), 0.80);
iBracket(axC, 1, 2, signrank(PkR{1}(:,1), PkR{1}(:,2)), 0.80);
iBracket(axC, 4, 5, signrank(PkR{2}(:,1), PkR{2}(:,2)), 0.80);
iBracket(axD, 1, 2, ranksum(selALB, selV7), 0.80);
iBracket(axE, 1, 2, ranksum(mp("ALB","L→T","d_norot"), mp("V7","L→T","d_norot")), 0.80);
iBracket(axF, 1, 2, ranksum(mp("ALB","L→T","PR_B"), mp("V7","L→T","PR_B")), 0.80);

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig5d_DelayLoss.svg');
fprintf('Wrote: %s\n', svgPath);
exportgraphics(f, fullfile(thisDir, '_fig5d_check.png'), 'Resolution', 400, 'BackgroundColor', 'white');

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

function pk = iPeakCell(A, B)
% A,B: cells × nBin（同阶段某鼠的模式）→ 跨阶段时间对应矩阵的对角优势
n = size(A, 2);
C = nan(n);
for i = 1:n
	for j = 1:n
		a = A(:, i); b = B(:, j);
		ok = isfinite(a) & isfinite(b);
		a = a(ok); b = b(ok);
		a = a - mean(a); b = b - mean(b);
		sa = norm(a); sb = norm(b);
		if sa == 0 || sb == 0, continue; end
		C(i, j) = (a' * b) / (sa * sb);
	end
end
d = diag(C);
off = C(abs((1:n)' - (1:n)) >= 2);
pk = mean(d, 'omitnan') - mean(off(:), 'omitnan');
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
	'VerticalAlignment', 'top', 'HandleVisibility', 'off');
end
