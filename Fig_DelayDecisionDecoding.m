% 延迟范式：群体状态预测"是否应答"，以及该编码的跨模态复用
%
% 参考 Neuron/Nature "M1 activity explains movement variability" 的分析框架，
% 但我们的读出是离散决策（应答 / 不应答），因为实测连续量（RT）不可解码。
%
%   A  示例鼠：cue 期群体轨迹（PC1-PC2），命中（实线）vs 未命中（虚线）
%   B  逐鼠 AUC：AW 内部 CV、LW 内部 CV、AW->LW 迁移，三条件并列
%   C  单 trial 版：活动到"学会态"的距离 vs 应答概率（按距离分箱），AW 与 LW
%   D  迁移解码与置换零分布：每只鼠的 AUC_X 与打乱标签的零分布
%
% 严格口径（同 DelayNeuralBehaviour.m / DelayCrossModalDecode.m）：
%   - 特征只用 cue -1.0 -> +0.3 s（水在 1.4 s 才可喝，预期性舔水不混入）
%   - 特征在每个 block 内去均值（测试集只用自身 block 均值，无监督）
%   - PCA/回归器只在训练数据上拟合；置换检验打乱训练标签
%   - yqn2200 的最后一个 LW block（命中率 0.38）按用户要求剔除

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nPC = 8;
nPerm = 100;
tWater = 1.4;
winFeat = [-1.0, 0.3];
dropMouse = "yqn2200";
dropBlock = 15;

DS = TransferLearning.ALDelayed();
Tr = DS.Trials;
Tr.TrialUID = uint64(Tr.TrialUID);
xs = linspace(-3, 3, 48)';
selWin = xs >= winFeat(1) & xs <= winFeat(2);
xsWin = xs(selWin);
nBase = nnz(xsWin < -0.3);   % 基线帧数（cue 前 0.3 s 之前）
% 仅用于画轨迹的较长窗口（含预期性嘸水段，所以只作展示）
dispWin = xs >= -1.0 & xs <= 1.3;
xsDisp = xs(dispWin);
idxWin = xsDisp <= winFeat(2);   % 解码用的帧在展示窗口内的位置

mice = unique(string(DS.Cells.Mouse));
nM = numel(mice);

% 汇总容器
AUC_AW = nan(nM, 1); AUC_LW = nan(nM, 1); AUC_X = nan(nM, 1);
P_X = nan(nM, 1); NullMean = nan(nM, 1); NullP95 = nan(nM, 1);
nAW = nan(nM, 1); nLW = nan(nM, 1);
binHitAW = nan(nM, 5); binHitLW = nan(nM, 5);
ExTraj = [];
fprintf('%-9s %-5s %-5s %-7s %-7s %-7s %-6s\n', 'mouse', 'nAW', 'nLW', 'AUC_AW', 'AUC_LW', 'AUC_X', 'pX');

for i = 1:nM
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 20, continue; end

	[XA, yA, gA] = iStack(DS, Tr, TA, cells, dispWin, tWater);
	[XL, yL, gL] = iStack(DS, Tr, TL, cells, dispWin, tWater);
	if string(m) == dropMouse
		keep = gL ~= find(unique(TL.BlockUID) == dropBlock, 1);
		XL = XL(keep, :, :); yL = yL(keep); gL = gL(keep);
	end
	if numel(yA) < 80 || numel(yL) < 80, continue; end

	% 展平为 trial x (time*cells)，并在 block 内去均值（只用解码窗口的帧）
	[FA, gA] = iFlatten(XA(:, :, idxWin), gA);
	[FL, gL] = iFlatten(XL(:, :, idxWin), gL);

	% 轨迹：每个 trial 减自身基线（保留诱发响应形状），AW 上拟合前 3 个主成分
	[TrajA, TrajL] = iTraj(iBaselineX(XA, nBase), iBaselineX(XL, nBase));

	AUC_AW(i) = iCVAUC(FA, yA, nPC);
	AUC_LW(i) = iCVAUC(FL, yL, nPC);
	[AUC_X(i), P_X(i), NullMean(i), NullP95(i)] = iTransferAUC(FA, yA, FL, yL, nPC, nPerm);
	nAW(i) = numel(yA); nLW(i) = numel(yL);

	% ---- C 面板：到"学会态"的距离 vs 应答概率 ----
	nB = 5;
	MU = reshape(mean(TrajA, 1), 1, []);              % 学会态平均轨迹（展平）
	dA = sqrt(sum((reshape(TrajA, size(TrajA,1), []) - MU).^2, 2));
	dL = sqrt(sum((reshape(TrajL, size(TrajL,1), []) - MU).^2, 2));
	binHitAW(i, :) = iBinHit(dA, yA, nB);
	binHitLW(i, :) = iBinHit(dL, yL, nB);

	if strcmp(m, 'yqn2200')     % 示例鼠
		ExTraj = struct('PA', TrajA, 'PL', TrajL, 'yA', yA, 'yL', yL);
	end

	fprintf('%-9s %-5d %-5d %-7.3f %-7.3f %-7.3f %-6.3f\n', m, numel(yA), numel(yL), ...
		AUC_AW(i), AUC_LW(i), AUC_X(i), P_X(i));
end

ok = isfinite(AUC_AW);
fprintf('\n--- 汇总 (%d mice) ---\n', nnz(ok));
fprintf('AW 内部 AUC %.3f | LW 内部 AUC %.3f | AW->LW 迁移 AUC %.3f (null %.3f)\n', ...
	mean(AUC_AW(ok)), mean(AUC_LW(ok)), mean(AUC_X(ok)), mean(NullMean(ok)));

%% ---------- 出图 ----------
f = figure('Color', 'w', 'Name', 'Delay: decision decodable across modalities');
f.Units = 'centimeters';
f.Position(3:4) = [26, 7.6];

colHit = TransferLearning.TransferColor;
colMiss = [0.45 0.45 0.45];

% A 示例鼠轨迹（PC1-PC2）
axA = axes(f, 'Position', [0.045 0.145 0.180 0.620]);
if ~isempty(ExTraj)
	iDrawHitMiss(axA, ExTraj, colHit, colMiss);
end
title(axA, 'Example mouse: cue-evoked trajectories', 'FontWeight', 'normal', 'FontSize', 8);

% B 逐鼠 AUC
axB = axes(f, 'Position', [0.290 0.145 0.190 0.620]);
hold(axB, 'on');
V = [AUC_AW(ok), AUC_LW(ok), AUC_X(ok)];
for i = 1:size(V, 1)
	plot(axB, [1 2 3], V(i, :), '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.6);
end
for c = 1:3
	plot(axB, c + 0.08 * (rand(size(V,1), 1) - 0.5), V(:, c), 'o', 'MarkerSize', 5, ...
		'MarkerFaceColor', colHit, 'MarkerEdgeColor', 'none');
	plot(axB, [c - 0.22, c + 0.22], mean(V(:, c)) * [1 1], '-', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.6);
end
plot(axB, [0.5 3.5], [0.5 0.5], ':', 'Color', [0.5 0.5 0.5]);
xlim(axB, [0.5 3.5]); ylim(axB, [0.45 0.9]);
xticks(axB, 1:3); xticklabels(axB, {'AW', 'LW', 'AW\toLW'});
ylabel(axB, 'AUC (hit vs miss)');
title(axB, sprintf('Decoding (n = %d mice)', nnz(ok)), 'FontWeight', 'normal', 'FontSize', 8);
box(axB, 'off');

% C 距离 -> 应答概率
axC = axes(f, 'Position', [0.560 0.145 0.180 0.620]);
hold(axC, 'on');
nB = size(binHitAW, 2);
mAW = mean(binHitAW(ok, :), 1, 'omitnan');
sAW = std(binHitAW(ok, :), 0, 1, 'omitnan') ./ sqrt(nnz(ok));
mLW = mean(binHitLW(ok, :), 1, 'omitnan');
sLW = std(binHitLW(ok, :), 0, 1, 'omitnan') ./ sqrt(nnz(ok));
plot(axC, 1:nB, mAW, '-o', 'Color', TransferLearning.NaiveColor, 'MarkerFaceColor', TransferLearning.NaiveColor, 'MarkerSize', 4);
errorbar(axC, 1:nB, mAW, sAW, 'Color', TransferLearning.NaiveColor, 'LineWidth', 0.8, 'CapSize', 2);
plot(axC, 1:nB, mLW, '-o', 'Color', colHit, 'MarkerFaceColor', colHit, 'MarkerSize', 4);
errorbar(axC, 1:nB, mLW, sLW, 'Color', colHit, 'LineWidth', 0.8, 'CapSize', 2);
xlim(axC, [0.6 nB + 0.4]); ylim(axC, [0 1]);
xticks(axC, 1:nB); xticklabels(axC, compose('%d', 1:nB));
xlabel(axC, 'Distance to learned-state (quintile)');
ylabel(axC, 'Response probability');
title(axC, 'Response probability vs distance', 'FontWeight', 'normal', 'FontSize', 7);
text(axC, 0.97, 0.94, 'AW', 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
	'FontSize', 7, 'Color', TransferLearning.NaiveColor);
text(axC, 0.97, 0.86, 'LW', 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
	'FontSize', 7, 'Color', colHit);
box(axC, 'off');

% D 迁移解码 vs 置换零分布
axD = axes(f, 'Position', [0.815 0.145 0.150 0.620]);
hold(axD, 'on');
for i = find(ok)'
	plot(axD, i, NaN, 'o');   % 占位保证坐标范围
end
xIdx = find(ok);
for k = 1:numel(xIdx)
	i = xIdx(k);
	plot(axD, [k k], [mean(NullMean(i)) - 0.0, NullP95(i)], '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 5);
	plot(axD, k, AUC_X(i), 'o', 'MarkerSize', 6, 'MarkerFaceColor', colHit, 'MarkerEdgeColor', 'none');
end
plot(axD, [0.5, numel(xIdx) + 0.5], [0.5 0.5], ':', 'Color', [0.5 0.5 0.5]);
xlim(axD, [0.5, numel(xIdx) + 0.5]); ylim(axD, [0.45 0.9]);
xticks(axD, 1:numel(xIdx));
xticklabels(axD, compose('%d', 1:numel(xIdx)));
xlabel(axD, 'Mouse'); ylabel(axD, 'AUC');
title(axD, 'Transfer AUC vs label shuffle', 'FontWeight', 'normal', 'FontSize', 7);
box(axD, 'off');

annotation(f, 'textbox', [0.02 0.945 0.95 0.045], 'String', ...
	'Cue-evoked population state predicts whether the animal responds, and the code is shared across modalities', ...
	'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold');
annotation(f, 'textbox', [0.02 0.895 0.95 0.045], 'String', ...
	['Delayed paradigm (water only upon licking). Features: cue -1.0 to +0.3 s only; ' ...
	'within-block centering; PCA fitted inside training folds; grey bar in D = 5-95% of 100 label shuffles.'], ...
	'EdgeColor', 'none', 'FontSize', 6.5, 'Color', [0.4 0.4 0.4]);

outDir = fileparts(mfilename('fullpath'));
savefig(f, fullfile(outDir, 'Fig_DelayDecisionDecoding.fig'));
fprintf('Saved: %s\n', fullfile(outDir, 'Fig_DelayDecisionDecoding.fig'));
assignin('base', 'DelayDecisionData', struct('AUC_AW', AUC_AW, 'AUC_LW', AUC_LW, ...
	'AUC_X', AUC_X, 'P_X', P_X, 'NullMean', NullMean, 'NullP95', NullP95, ...
	'BinHitAW', binHitAW, 'BinHitLW', binHitLW, 'Mice', mice));

%% ------------------------------------------------------------------
function [X, y, g] = iStack(DS, Tr, T, cells, selWin, tWater)
X = []; y = []; g = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	Xi = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi), :), cells);
	if isempty(Xi), continue; end
	Xi = Xi(:, :, selWin);
	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel);
	tuSel = Tr.TrialUID(sel);
	okTag = cellfun(@(x) isa(x, 'table'), tags);
	tags = tags(okTag); tuSel = tuSel(okTag);
	if numel(tags) < 10, continue; end
	[~, ord] = sort(tuSel);
	tags = tags(ord);
	[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	resp = false(size(Lick, 1), 1);
	for i = 1:size(Lick, 1)
		if any(Lick(i, :) & tt >= tWater)
			resp(i) = true;
		end
	end
	n = min(size(Xi, 1), numel(resp));
	if n < 10, continue; end
	X = cat(1, X, Xi(1:n, :, :)); %#ok<AGROW>
	y = [y; double(resp(1:n))]; %#ok<AGROW>
	g = [g; repmat(bi, n, 1)]; %#ok<AGROW>
end
end

function [F, g] = iFlatten(X, g)
% trials x (time*cells)，并按 block 内去均值
F = reshape(permute(X, [1 3 2]), size(X, 1), []);
for bi = unique(g)'
	r = g == bi;
	F(r, :) = F(r, :) - mean(F(r, :), 1);
end
end

function X = iBaselineX(X, nBase)
% 每个 trial 减去自身基线（cue 前 nBase 帧的均值）；保留诱发响应、去掉直流差异
if nBase < 1, return; end
b = mean(X(:, :, 1:nBase), 3);
X = X - repmat(b, 1, 1, size(X, 3));
end

function X = iCenterX(X, g)
% 每个 block 减去自己的平均时空模式（只平移，不改轨迹形状）
for bi = unique(g)'
	r = g == bi;
	m = reshape(mean(X(r, :, :), 1), 1, [], size(X, 3));
	X(r, :, :) = X(r, :, :) - repmat(m, nnz(r), 1, 1);
end
end

function [TA, TL] = iTraj(XA, XL)
% 用 AW 数据拟合前 3 个主成分，把 AW / LW 都投影成 trials x time x 3 的轨迹
nA = size(XA, 1); nT = size(XA, 3);
RA = reshape(permute(XA, [1 3 2]), nA * nT, []);
mu = mean(RA, 1);
[~, ~, V] = svd(RA - mu, 'econ');
W = V(:, 1:min(3, size(V, 2)));
TA = reshape((RA - mu) * W, nA, nT, []);
nL = size(XL, 1);
RL = reshape(permute(XL, [1 3 2]), nL * nT, []);
TL = reshape((RL - mu) * W, nL, nT, []);
if size(TA, 3) < 3, TA = cat(3, TA, zeros(size(TA,1), size(TA,2), 3 - size(TA,3))); end
if size(TL, 3) < 3, TL = cat(3, TL, zeros(size(TL,1), size(TL,2), 3 - size(TL,3))); end
end

function [F, m] = iCenter(F, g)
m = zeros(1, size(F, 2));
for bi = unique(g)'
	r = g == bi;
	c = mean(F(r, :), 1);
	F(r, :) = F(r, :) - c;
	m = m + c * (nnz(r) / numel(g));
end
end

function P = iCenterP(P, g)
% 按每个 block 自己的平均轨迹做平移（只影响位置，不影响轨迹形状）
for bi = unique(g)'
	r = g == bi;
	mT = reshape(mean(P(r, :, :), 1), 1, [], 3);
	P(r, :, :) = P(r, :, :) - repmat(mT, nnz(r), 1, 1);
end
end

function b = iBinHit(d, y, nB)
b = nan(1, nB);
ok = isfinite(d);
if nnz(ok) < nB * 3, return; end
q = quantile(d(ok), linspace(0, 1, nB + 1));
for k = 1:nB
	r = ok & d >= q(k) & d <= q(k + 1);
	if any(r), b(k) = mean(y(r)); end
end
end

function [auc, p, nm, np95] = iTransferAUC(FA, yA, FL, yL, nPC, nPerm)
mu = mean(FA, 1);
[~, ~, V] = svd(FA - mu, 'econ');
k = min(nPC, size(V, 2));
W = V(:, 1:k);
Ztr = [ones(size(FA, 1), 1), (FA - mu) * W];
Zte = [ones(size(FL, 1), 1), (FL - mu) * W];
b = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * yA);
[~, ~, ~, auc] = perfcurve(yL, Zte * b, 1);
rng(0);
null = zeros(nPerm, 1);
for t = 1:nPerm
	bt = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * yA(randperm(numel(yA))));
	[~, ~, ~, a] = perfcurve(yL, Zte * bt, 1);
	null(t) = a;
end
p = mean(null >= auc);
nm = mean(null);
np95 = prctile(null, 95);
end

function auc = iCVAUC(F, y, nPC)
n = size(F, 1);
if n < 40 || numel(unique(y)) < 2, auc = NaN; return; end
cv = cvpartition(n, 'KFold', 5);
score = nan(n, 1);
for f = 1:cv.NumTestSets
	trn = training(cv, f); tst = test(cv, f);
	mu = mean(F(trn, :), 1);
	[~, ~, V] = svd(F(trn, :) - mu, 'econ');
	k = min(nPC, size(V, 2));
	W = V(:, 1:k);
	Ztr = [ones(sum(trn), 1), (F(trn, :) - mu) * W];
	Zte = [ones(sum(tst), 1), (F(tst, :) - mu) * W];
	b = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * y(trn));
	score(tst) = Zte * b;
end
[~, ~, ~, auc] = perfcurve(y, score, 1);
end

function iDrawHitMiss(ax, E, colHit, colMiss)
% 两条均值轨迹 + SEM 带（不画单 trial，避免糊成一团）
hold(ax, 'on');
allPts = reshape(E.PA, [], 3);
lims = prctile(allPts(:, 1:2), [10 90], 1);
for pass = 1:2
	if pass == 1
		col = colHit; ls = '-'; tag = 'hit';
	else
		col = colMiss; ls = '--'; tag = 'miss';
	end
	sel = E.yA == (pass - 1);
	if ~any(sel), continue; end
	Q = E.PA(sel, :, :);
	n = size(Q, 1);
	mT = reshape(mean(Q, 1), [], 3);
	sT = reshape(std(Q, 0, 1) ./ sqrt(n), [], 3);
	% PC1-PC2 平面上的均值轨迹
	plot(ax, mT(:, 1), mT(:, 2), ls, 'Color', col, 'LineWidth', 2.0);
	% 用垂直于轨迹方向的误差不现实，这里直接把两个主成分的 SEM 画成细框
	plot(ax, mT(:, 1) - sT(:, 1), mT(:, 2) - sT(:, 2), ':', 'Color', [col 0.6], 'LineWidth', 0.6);
	plot(ax, mT(:, 1) + sT(:, 1), mT(:, 2) + sT(:, 2), ':', 'Color', [col 0.6], 'LineWidth', 0.6);
	plot(ax, mT(1, 1), mT(1, 2), '.', 'Color', [0.1 0.1 0.1], 'MarkerSize', 8);
	text(ax, mT(end, 1), mT(end, 2) + (pass - 1.5) * 0.9, sprintf('%s (n=%d)', tag, n), ...
		'FontSize', 7, 'Color', col, 'HorizontalAlignment', 'center');
end
pad = 0.10 * diff(lims, 1, 1);
xlim(ax, lims(:, 1)' + [-pad(1) pad(1)]);
ylim(ax, lims(:, 2)' + [-pad(2) pad(2)]);
box(ax, 'off');
xlabel(ax, 'PC1'); ylabel(ax, 'PC2');
end
