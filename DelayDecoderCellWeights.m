% 解码器权重能落到细胞上吗？—— 找出"对解码最重要"的细胞，并与光水阶段的
% 重激活（response）细胞对比
%
% 做法：
%   1) 在 AW trial 上拟合 ridge 解码器（8 个主成分 + 截距）
%   2) 把 PC 权重 b 映射回 (时间 x 细胞) 空间：w = W*b（线性模型下是精确的）
%      每个细胞的重要性 = |w| 在时间上的 2 范数
%   3) 定义细胞的"应答性"：cue 前基线（-1 ~ -0.3 s）的 mean/SD，
%      若 0.2~1.0 s 的平均响应 > 基线 + 3SD 记为 active
%      reactivated = AW-active 且 LW-active（与前面印迹/重激活的定义一致）
%   4) 量化：importance 对 reactivated 的 AUC、与 LW 响应幅度的 Spearman、
%      前 10% 重要细胞中 reactivated 的比例（相对全体富集倍数）
%
% 注意：重要性只能在"该解码器所依赖的线性子空间"内解释；它不是因果权重。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nPC = 8;
tWater = 1.4;
winFeat = [-1.0, 0.3];

DS = TransferLearning.ALDelayed();
Tr = DS.Trials;
Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID);
xs = linspace(-3, 3, 48)';
selWin = xs >= winFeat(1) & xs <= winFeat(2);
dispWin = xs >= -1.0 & xs <= 1.3;
xsDisp = xs(dispWin);
idxWin = xsDisp <= winFeat(2);        % 解码只取这部分帧
iBase = find(xsDisp >= -1.0 & xsDisp < -0.3);
iResp = find(xsDisp >= 0.2 & xsDisp <= 1.0);
fprintf('%-9s %-6s %-8s %-9s %-9s %-9s %-10s %-9s\n', 'mouse', 'nCell', 'nReact', 'AUC_imp', 'rho_LWamp', 'enrich10', 'p_hyper', 'rho_AWamp');

Rows = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	% ---- 组装（全程保留 3-D 形式，便于算每细胞响应）----
[XA, yA, gA] = iStack(DS, Tr, TA, cells, dispWin, tWater);
	[XL, yL, gL] = iStack(DS, Tr, TL, cells, dispWin, tWater);
	if numel(yA) < 100 || numel(yL) < 100, continue; end

	% ---- 解码器（只用 cue -1 ~ +0.3 s 的帧）----
	[FA, gA] = iFlatten(XA(:, :, idxWin), gA);
	FA = iCenterBlock(FA, gA);
	mu = mean(FA, 1);
	[~, ~, V] = svd(FA - mu, 'econ');
	k = min(nPC, size(V, 2));
	W = V(:, 1:k);
	Z = [ones(size(FA, 1), 1), (FA - mu) * W];
	b = (Z' * Z + eye(k + 1)) \ (Z' * yA);
	w = W * b(2:end);                       % (nTimeWin*nCells) x 1
	nT = nnz(idxWin); nC = numel(cells);
	wMat = reshape(w, nT, nC);              % 时间 x 细胞（列对应 cells 顺序）
imp = sqrt(sum(wMat.^2, 1))';           % 每细胞重要性

	% ---- 细胞应答性：trial 平均响应相对 trial 间噪声显著（t > 3 且幅度 > 0.1 z）----
	rA = mean(XA(:, :, iResp), 3) - mean(XA(:, :, iBase), 3);   % trials x cells
	nA = size(rA, 1);
	tA = mean(rA, 1) ./ max(std(rA, 0, 1) / sqrt(nA), eps);
	actA = (tA > 3) & (mean(rA, 1) > 0.1);

	rL = mean(XL(:, :, iResp), 3) - mean(XL(:, :, iBase), 3);
	nL = size(rL, 1);
	ampL = mean(rL, 1)';
	tL = mean(rL, 1) ./ max(std(rL, 0, 1) / sqrt(nL), eps);
	actL = (tL > 3) & (ampL' > 0.1);

	react = actA(:) & actL(:);

	% ---- 量化 ----
	aucImp = iAUCfromScore(imp, react);
	rho = corr(imp, ampL, 'Type', 'Spearman', 'Rows', 'complete');
	rhoA = corr(imp, mean(rA, 1)', 'Type', 'Spearman', 'Rows', 'complete');
	topN = max(1, round(0.1 * nC));
	[~, ord] = sort(imp, 'descend');
	top = false(nC, 1); top(ord(1:topN)) = true;
	enrich = (mean(react(top)) + eps) / (mean(react) + eps);
	kObs = nnz(react & top);
	pHyper = hygecdf(kObs - 1, nC, nnz(react), topN);   % P(X >= kObs)

	fprintf('%-9s %-6d %-8d %-9.3f %-9.3f %-9.2f %-10.3g %-9.3f\n', m, nC, nnz(react), aucImp, rho, enrich, pHyper, rhoA);
	Rows = [Rows; table(string(m), nC, nnz(react), aucImp, rho, enrich, pHyper, rhoA, ...
		'VariableNames', {'Mouse','NCells','NReact','AUC_imp','Rho_LWamp','Enrich10','PHyper','Rho_AWamp'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 (n = %d mice) ---\n', height(Rows));
fprintf('importance 判别 reactivated 的 AUC = %.3f +- %.3f\n', mean(Rows.AUC_imp), std(Rows.AUC_imp)/sqrt(height(Rows)));
fprintf('importance 与 LW 响应幅度的 Spearman = %.3f +- %.3f\n', mean(Rows.Rho_LWamp), std(Rows.Rho_LWamp)/sqrt(height(Rows)));
fprintf('importance 与 AW 响应幅度的 Spearman = %.3f +- %.3f（对照）\n', mean(Rows.Rho_AWamp), std(Rows.Rho_AWamp)/sqrt(height(Rows)));
fprintf('前 10%% 重要细胞中 reactivated 的富集倍数 = %.2f +- %.2f, 超几何 p<0.05 的鼠数 %d/%d\n', ...
	mean(Rows.Enrich10), std(Rows.Enrich10)/sqrt(height(Rows)), nnz(Rows.PHyper < 0.05), height(Rows));
assignin('base', 'DelayDecoderWeights', Rows);

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
end
end

function [F, g] = iFlatten(X, g)
F = reshape(permute(X, [1 3 2]), size(X, 1), []);
end

function F = iCenterBlock(F, g)
for bi = unique(g)'
	r = g == bi;
	F(r, :) = F(r, :) - mean(F(r, :), 1);
end
end

function a = iAUCfromScore(s, lab)
s = s(:); lab = logical(lab(:));
pos = s(lab); neg = s(~lab);
if isempty(pos) || isempty(neg), a = NaN; return; end
a = mean((pos > neg') + 0.5 * (pos == neg'), 'all');
end
