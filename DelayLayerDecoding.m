% 延迟范式：按层（MOp2/3 vs MOp5）分别做"是否应答"解码与跨模态迁移
%
% 与 DelayCrossModalDecode.m 完全相同的严格口径：
%   - 特征：cue -1.0 -> +0.3 s（水在 1.4 s 才可喝）
%   - 特征在 block 内去均值；PCA 仅在训练折内拟合
%   - 100 次训练标签打乱给经验 p 值
%   - yqn2200 的最后一个 LW block（命中率 0.38）剔除
%
% 输出：每只鼠 x 每层的 AW 内部 AUC、LW 内部 AUC、AW->LW 迁移 AUC 与 p

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
C = DS.Cells;
C.CellUID = uint64(C.CellUID);
xs = linspace(-3, 3, 48)';
selWin = xs >= winFeat(1) & xs <= winFeat(2);

layers = ["MOp2/3", "MOp5"];
mice = unique(string(C.Mouse));
Rows = table();

for L = 1:numel(layers)
	fprintf('\n===== %s =====\n', layers(L));
	fprintf('%-9s %-5s %-5s %-7s %-7s %-7s %-6s\n', 'mouse', 'nC', 'nTr', 'AUC_AW', 'AUC_LW', 'AUC_X', 'pX');
	for i = 1:numel(mice)
		m = char(mice(i));
		TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
		TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
		if isempty(TA) || isempty(TL), continue; end
		cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
		idx = C.Mouse == string(m) & C.ZLayer == layers(L);
		cells = intersect(cells, C.CellUID(idx));
		if numel(cells) < 15, continue; end

		[FA, yA, gA] = iStack(DS, Tr, TA, cells, selWin, tWater);
		[FL, yL, gL] = iStack(DS, Tr, TL, cells, selWin, tWater);
		if string(m) == dropMouse
			keep = gL ~= find(unique(TL.BlockUID) == dropBlock, 1);
			FL = FL(keep, :); yL = yL(keep); gL = gL(keep);
		end
		if numel(yA) < 80 || numel(yL) < 80, continue; end

		FA = iCenter(FA, gA);
		FL = iCenter(FL, gL);

		aucA = iCVAUC(FA, yA, nPC);
		aucL = iCVAUC(FL, yL, nPC);
		[aucX, pX, nm] = iTransferAUC(FA, yA, FL, yL, nPC, nPerm);

		fprintf('%-9s %-5d %-5d %-7.3f %-7.3f %-7.3f %-6.3f\n', m, numel(cells), numel(yA), aucA, aucL, aucX, pX);
		Rows = [Rows; table(string(layers(L)), string(m), numel(cells), numel(yA), numel(yL), ...
			aucA, aucL, aucX, pX, nm, 'VariableNames', ...
			{'Layer','Mouse','NCells','NAW','NLW','AUC_AW','AUC_LW','AUC_X','P_X','NullX'})]; %#ok<AGROW>
	end
end

fprintf('\n--- 汇总 ---\n');
for L = 1:numel(layers)
	sel = Rows.Layer == layers(L);
	if any(sel)
		fprintf('%-8s: AW %.3f | LW %.3f | 迁移 %.3f (null %.3f), 显著 %d/%d\n', layers(L), ...
			mean(Rows.AUC_AW(sel)), mean(Rows.AUC_LW(sel)), mean(Rows.AUC_X(sel)), ...
			mean(Rows.NullX(sel)), nnz(Rows.P_X(sel) < 0.05), nnz(sel));
	end
end
assignin('base', 'DelayLayerDecoding', Rows);

%% ------------------------------------------------------------------
function [F, y, g] = iStack(DS, Tr, T, cells, selWin, tWater)
F = []; y = []; g = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi), :), cells);
	if isempty(X), continue; end
	X = X(:, :, selWin);
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
	nTr = size(X, 1); nC = size(X, 2); nT = size(X, 3);
	Fi = reshape(permute(X, [1 3 2]), nTr, nT * nC);
	n = min(nTr, numel(resp));
	if n < 10, continue; end
	F = [F; Fi(1:n, :)]; %#ok<AGROW>
	y = [y; double(resp(1:n))]; %#ok<AGROW>
	g = [g; repmat(bi, n, 1)]; %#ok<AGROW>
end
end

function F = iCenter(F, g)
for bi = unique(g)'
	r = g == bi;
	F(r, :) = F(r, :) - mean(F(r, :), 1);
end
end

function [auc, p, nm] = iTransferAUC(FA, yA, FL, yL, nPC, nPerm)
mu = mean(FA, 1);
[~, ~, V] = svd(FA - mu, 'econ');
k = min(nPC, size(V, 2));
W = V(:, 1:k);
Ztr = [ones(size(FA, 1), 1), (FA - mu) * W];
Zte = [ones(size(FL, 1), 1), (FL - mu) * W];
M = Ztr' * Ztr + eye(k + 1);
b = M \ (Ztr' * yA);
[~, ~, ~, auc] = perfcurve(yL, Zte * b, 1);
rng(0);
null = zeros(nPerm, 1);
for t = 1:nPerm
	bt = M \ (Ztr' * yA(randperm(numel(yA))));
	[~, ~, ~, a] = perfcurve(yL, Zte * bt, 1);
	null(t) = a;
end
p = mean(null >= auc);
nm = mean(null);
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
