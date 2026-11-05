% 增量检验：控制 cue 前状态后，cue 早期（0-0.3 s）是否还带来额外信息？
%
% 三个模型（都在同一批 trial、同一套交叉验证/迁移协议下）：
%   P     只用 cue 前窗口（-1.0 ~ -0.05 s）的主成分
%   P+E   cue 前 + cue 早期（0 ~ 0.3 s）
%   Eres  cue 早期对 cue 前回归后的残差（正交化）
%
% 评价：
%   (1) 声水 block 内 5 折交叉验证 AUC
%   (2) 全部声水训练 -> 全部光水测试 的 AUC
%   增量 = AUC(P+E) - AUC(P)；零分布由"打乱 cue 早期部分（trial 维度）"生成，
%   同时保留 cue 前状态与标签的对应关系。

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
selP = xs(wAll) < 0;            % cue 前
selE = xs(wAll) >= 0;           % cue 早期

mice = unique(string(C.Mouse));
fprintf('%-9s %-8s %-8s %-7s %-8s %-9s %-8s %-8s %-7s %-8s\n', ...
	'mouse', 'cv_P', 'cv_PE', 'd_cv', 'p_cv', 'tr_P', 'tr_PE', 'd_tr', 'rEres');
Rows = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	[XA, yA, gA] = iStack(DS, Tr, TA, cells, wAll, tWater);
	[XL, yL, gL] = iStack(DS, Tr, TL, cells, wAll, tWater);
	if numel(yA) < 100 || numel(yL) < 100, continue; end

	FA = iFlat(XA, gA); FL = iFlat(XL, gL);     % 每个 trial 一行（时间*细胞）
	PA = FA(:, iCols(selP, size(XA, 2))); EA = FA(:, iCols(selE, size(XA, 2)));
	PL = FL(:, iCols(selP, size(XL, 2))); EL = FL(:, iCols(selE, size(XL, 2)));

	cvP = iCV(PA, yA, nPC);
	cvPE = iCV([PA, EA], yA, nPC);
	trP = iTransfer(PA, yA, PL, yL, nPC);
	trPE = iTransfer([PA, EA], yA, [PL, EL], yL, nPC);

	% 增量置换：打乱 cue 早期那段（trial 维度），保留 cue 前与标签的对应
	rng(0);
	null = zeros(nPerm, 1);
	for t = 1:nPerm
		perm = randperm(numel(yA));
		null(t) = iTransfer([PA, EA(perm, :)], yA, [PL, EL], yL, nPC);
	end
	pInc = mean(null >= trPE);

	% 残差模型：E 对 P 做线性回归后的残差（训练集拟合，测试集用同一系数）
	rE = iResidAUC(PA, EA, yA, PL, EL, yL, nPC);

	fprintf('%-9s %-8.3f %-8.3f %-7.3f %-8.3f %-9.3f %-8.3f %-8.3f %-7.3f\n', ...
		m, cvP, cvPE, cvPE - cvP, pInc, trP, trPE, trPE - trP, rE);
	Rows = [Rows; table(string(m), cvP, cvPE, cvPE - cvP, pInc, trP, trPE, trPE - trP, rE, ...
		'VariableNames', {'Mouse','CV_P','CV_PE','dCV','P_inc','TR_P','TR_PE','dTR','TR_Eres'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 ---\n');
fprintf('CV: P %.3f -> P+E %.3f (增量 %.3f)\n', mean(Rows.CV_P), mean(Rows.CV_PE), mean(Rows.dCV));
fprintf('迁移: P %.3f -> P+E %.3f (增量 %.3f), 增量显著的鼠数 %d/%d\n', ...
	mean(Rows.TR_P), mean(Rows.TR_PE), mean(Rows.dTR), nnz(Rows.P_inc < 0.05), height(Rows));
fprintf('仅用 cue 早期残差（已剔除 cue 前状态）：迁移 AUC = %.3f\n', mean(Rows.TR_Eres));
assignin('base', 'DelayIncremental', Rows);

%% ------------------------------------------------------------------
function c = iCols(sel, nC)
idx = find(sel);
c = [];
for k = idx(:)'
	c = [c, (k - 1) * nC + (1:nC)]; %#ok<AGROW>
end
end

function [X, y, g] = iStack(DS, Tr, T, cells, wAll, tWater)
X = []; y = []; g = [];
blks = unique(T.BlockUID);
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

function F = iFlat(X, g)
F = reshape(permute(X, [1 3 2]), size(X, 1), []);
for bi = unique(g)'
	r = g == bi;
	F(r, :) = F(r, :) - mean(F(r, :), 1);
end
end

function auc = iCV(F, y, nPC)
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

function auc = iTransfer(Ftr, ytr, Fte, yte, nPC)
if numel(unique(ytr)) < 2 || numel(unique(yte)) < 2, auc = NaN; return; end
mu = mean(Ftr, 1);
[~, ~, V] = svd(Ftr - mu, 'econ');
k = min(nPC, size(V, 2));
W = V(:, 1:k);
Ztr = [ones(size(Ftr, 1), 1), (Ftr - mu) * W];
Zte = [ones(size(Fte, 1), 1), (Fte - mu) * W];
b = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * ytr);
[~, ~, ~, auc] = perfcurve(yte, Zte * b, 1);
end

function auc = iResidAUC(PA, EA, yA, PL, EL, yL, nPC)
% 在训练集上把 E 对 P 回归，取残差，再用残差单独解码（迁移到光水）
muP = mean(PA, 1); [~, ~, Vp] = svd(PA - muP, 'econ');
kp = min(nPC, size(Vp, 2)); Wp = Vp(:, 1:kp);
ZpA = [ones(size(PA, 1), 1), (PA - muP) * Wp];
ZpL = [ones(size(PL, 1), 1), (PL - muP) * Wp];
muE = mean(EA, 1); [~, ~, Ve] = svd(EA - muE, 'econ');
ke = min(nPC, size(Ve, 2)); We = Ve(:, 1:ke);
ZeA = [ones(size(EA, 1), 1), (EA - muE) * We];
ZeL = [ones(size(EL, 1), 1), (EL - muE) * We];
% E 的 PC 分数对 P 的 PC 分数回归（训练集）
B = (ZpA' * ZpA + eye(kp + 1)) \ (ZpA' * ZeA(:, 2:end));
resA = ZeA(:, 2:end) - ZpA * B;
resL = ZeL(:, 2:end) - ZpL * B;
Ztr = [ones(size(resA, 1), 1), resA];
Zte = [ones(size(resL, 1), 1), resL];
b = (Ztr' * Ztr + eye(size(Ztr, 2))) \ (Ztr' * yA);
[~, ~, ~, auc] = perfcurve(yL, Zte * b, 1);
end
