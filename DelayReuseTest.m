% "光水复用了声水信息"——按这个思路重新组织解码分析
%
% 核心推论：若 LW 的表现依赖复用 AW 学到的群体编码，则应观察到
%   (1) 用 AW trial 拟合的判读轴，在**首个光水 block（动物尚无光水经验）**就已经能
%       预测该 trial 是否应答；
%   (2) 该"复用强度"在鼠间应与光水学习速度相关（复用越强 -> 光水学得越快）。
%
% 特征窗口三选一（脚本一次全跑，便于比较）：
%   P  cue 前 -1.0 ~ -0.05 s（刺激前状态）
%   E  cue 早期 0 ~ 0.30 s（线索诱发，正文曾用）
%   两个都算，分别给出"首个 LW block 的迁移 AUC"
%
% 注意：本数据集没有"延迟范式下的 naive 光水组"，因此"比 naive 学得快"这一
% 行为结论无法在本数据内直接检验；这里检验的是其神经前提（复用）。

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
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID);
xs = linspace(-3, 3, 48)';
wAll = xs >= -1.0 & xs <= 0.30;
selP = xs(wAll) < 0;
selE = xs(wAll) >= 0;

mice = unique(string(C.Mouse));
fprintf('%-9s %-6s %-8s %-8s %-8s %-9s %-9s\n', ...
	'mouse', 'LW1hit', 'AUC_E_all', 'AUC_E_LW1', 'AUC_P_LW1', 'p_E_LW1', 'LW_to80');
Rows = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	[XA, yA, gA, dA] = iStack(DS, Tr, TA, cells, wAll, tWater);
	[XL, yL, gL, dL] = iStack(DS, Tr, TL, cells, wAll, tWater);
	if numel(yA) < 100 || numel(yL) < 100, continue; end

	FA = iFlat(XA, gA); FL = iFlat(XL, gL);
	PA = FA(:, iCols(selP, size(XA, 2))); EA = FA(:, iCols(selE, size(XA, 2)));
	PL = FL(:, iCols(selP, size(XL, 2))); EL = FL(:, iCols(selE, size(XL, 2)));

	% 首个光水 block 的索引（按时间排序）
	ub = unique(gL);
	firstBlk = 1;

	aAll = iTransfer(EA, yA, EL, yL, nPC);
	mE1 = gL == firstBlk;
	aE1 = iTransfer(EA, yA, EL(mE1, :), yL(mE1), nPC);
	mP1 = mE1;
	aP1 = iTransfer(PA, yA, PL(mP1, :), yL(mP1), nPC);

	% 置换：打乱 AW 标签，看首个 LW block 的 AUC 零分布
	rng(0);
	null = nan(nPerm, 1);
	for t = 1:nPerm
		null(t) = iTransfer(EA, yA(randperm(numel(yA))), EL(mE1, :), yL(mE1), nPC);
	end
	pE1 = mean(null >= aE1);

	% 行为：首个光水 block 命中率、达到 0.8 所需 block 数
	lw1 = mean(yL(mE1));
	perBlk = arrayfun(@(b) mean(yL(gL == b)), ub(:));
	k = find(perBlk >= 0.8, 1);
	if isempty(k), to80 = NaN; elseif k == 1, to80 = 1; else, to80 = k - 1 + (0.8 - perBlk(k-1)) / (perBlk(k) - perBlk(k-1)); end

	fprintf('%-9s %-6.2f %-8.3f %-8.3f %-8.3f %-9.3f %-9.2f\n', m, lw1, aAll, aE1, aP1, pE1, to80);
	Rows = [Rows; table(string(m), lw1, aAll, aE1, aP1, pE1, to80, numel(yL), ...
		'VariableNames', {'Mouse','LW1hit','AUC_E_all','AUC_E_LW1','AUC_P_LW1','P_E_LW1','LW_to80','NLW'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 ---\n');
fprintf('首个 LW block 的迁移 AUC（cue 窗口 E）: %.3f（均值），显著 %d/%d\n', ...
	mean(Rows.AUC_E_LW1), nnz(Rows.P_E_LW1 < 0.05), height(Rows));
[r1, p1] = corr(Rows.AUC_E_LW1, Rows.LW1hit, 'Type', 'Spearman');
[r2, p2] = corr(Rows.AUC_E_LW1, Rows.LW_to80, 'Type', 'Spearman', 'Rows', 'complete');
fprintf('复用强度 vs 首个 LW 命中率: rho = %.2f (p = %.2g)\n', r1, p1);
fprintf('复用强度 vs 达 0.8 所需 block: rho = %.2f (p = %.2g)\n', r2, p2);
assignin('base', 'DelayReuse', Rows);

%% ------------------------------------------------------------------
function c = iCols(sel, nC)
idx = find(sel); c = [];
for k = idx(:)'
	c = [c, (k - 1) * nC + (1:nC)]; %#ok<AGROW>
end
end

function [X, y, g, dtv] = iStack(DS, Tr, T, cells, wAll, tWater)
X = []; y = []; g = []; dtv = [];
blks = unique(T.BlockUID);
tm = arrayfun(@(b) DS.Blocks.DateTime(find(DS.Blocks.BlockUID == b, 1)), blks);
[~, ord] = sort(tm);
blks = blks(ord);
for bi = 1:numel(blks)
	Xi = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi), :), cells);
	if isempty(Xi), continue; end
	Xi = Xi(:, :, wAll);
	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel);
	tuSel = Tr.TrialUID(sel);
	okTag = cellfun(@(x) isa(x, 'table'), tags);
	tags = tags(okTag); tuSel = tuSel(okTag);
	if numel(tags) < 10, continue; end
	[~, o2] = sort(tuSel);
	tags = tags(o2);
	[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	resp = false(size(Lick, 1), 1);
	for k = 1:size(Lick, 1)
		if any(Lick(k, :) & tt >= tWater)
			resp(k) = true;
		end
	end
	n = min(size(Xi, 1), numel(resp));
	if n < 10, continue; end
	X = cat(1, X, Xi(1:n, :, :)); %#ok<AGROW>
	y = [y; double(resp(1:n))]; %#ok<AGROW>
	g = [g; repmat(bi, n, 1)]; %#ok<AGROW>
	dtv = [dtv; repmat(tm(ord(bi)), n, 1)]; %#ok<AGROW>
end
end

function F = iFlat(X, g)
F = reshape(permute(X, [1 3 2]), size(X, 1), []);
for bi = unique(g)'
	r = g == bi;
	F(r, :) = F(r, :) - mean(F(r, :), 1);
end
end

function auc = iTransfer(Ftr, ytr, Fte, yte, nPC)
if numel(ytr) < 40 || numel(unique(ytr)) < 2 || numel(unique(yte)) < 2, auc = NaN; return; end
mu = mean(Ftr, 1);
[~, ~, V] = svd(Ftr - mu, 'econ');
k = min(nPC, size(V, 2));
W = V(:, 1:k);
Ztr = [ones(size(Ftr, 1), 1), (Ftr - mu) * W];
Zte = [ones(size(Fte, 1), 1), (Fte - mu) * W];
b = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * ytr);
[~, ~, ~, auc] = perfcurve(yte, Zte * b, 1);
end
