% 延迟范式：光水（LW）block 的"是否应答"解码，以及 AW→LW 的跨模态迁移解码
%
% 严格流程（与 DelayNeuralBehaviour.m 一致）：
%   - 特征只用 cue 前 1 s 到 cue 后 0.3 s 的活动（水在 1.4 s 才可喝，预舔不会混进来）
%   - 特征在每个 block 内去均值（测试集只用自身的 block 均值，属无监督，不构成泄漏）
%   - PCA / 回归器只在训练数据上拟合
%   - 100 次标签打乱给经验 p 值
%
% 分析：
%   (1) LW 内部 5 折 CV 的 AUC（每只鼠）；yqn2200 的最后一个 LW block（命中率 0.38）按用户要求剔除
%   (2) AW 训练 -> LW 测试 的 AUC（跨模态迁移），并与 AW 内部 CV 的 AUC 对比

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
dropLW = struct('Mouse', "yqn2200", 'Block', 15);   % 用户要求剔除

DS = TransferLearning.ALDelayed();
Tr = DS.Trials;
Tr.TrialUID = uint64(Tr.TrialUID);
xs = linspace(-3, 3, 48)';
selWin = xs >= winFeat(1) & xs <= winFeat(2);

mice = unique(string(DS.Cells.Mouse));
fprintf('%-9s %-5s %-5s %-7s %-7s %-7s %-7s %-7s\n', ...
	'mouse', 'nAW', 'nLW', 'AUC_AW', 'AUC_LW', 'AUC_X', 'pX', 'hitLW');
Out = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 20, continue; end

	[FA, yA, gA] = iStack(DS, Tr, TA, cells, selWin, tWater);
	[FL, yL, gL] = iStack(DS, Tr, TL, cells, selWin, tWater);
	% 剔除指定 block
	if string(m) == dropLW.Mouse
		keep = gL ~= find(unique(TL.BlockUID) == dropLW.Block, 1);
		FL = FL(keep, :); yL = yL(keep); gL = gL(keep);
	end
	if numel(yA) < 80 || numel(yL) < 80, continue; end

	FA = iCenter(FA, gA); FL = iCenter(FL, gL);

	aucA = iCVAUC(FA, yA, nPC);
	aucL = iCVAUC(FL, yL, nPC);

	% AW -> LW 迁移
	[aucX, pX] = iTransferAUC(FA, yA, FL, yL, nPC, nPerm);

	fprintf('%-9s %-5d %-5d %-7.3f %-7.3f %-7.3f %-7.3f %-7.2f\n', m, numel(yA), numel(yL), ...
		aucA, aucL, aucX, pX, mean(yL));
	Out = [Out; table(string(m), numel(yA), numel(yL), aucA, aucL, aucX, pX, mean(yL), ...
		'VariableNames', {'Mouse','NAW','NLW','AUC_AW','AUC_LW','AUC_X','P_X','HitLW'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 ---\n');
fprintf('AW 内部 CV AUC   = %.3f +- %.3f\n', mean(Out.AUC_AW), std(Out.AUC_AW)/sqrt(height(Out)));
fprintf('LW 内部 CV AUC   = %.3f +- %.3f\n', mean(Out.AUC_LW), std(Out.AUC_LW)/sqrt(height(Out)));
fprintf('AW->LW 迁移 AUC  = %.3f +- %.3f, 显著鼠数 %d/%d\n', mean(Out.AUC_X), ...
	std(Out.AUC_X)/sqrt(height(Out)), nnz(Out.P_X < 0.05), height(Out));
assignin('base', 'DelayCrossModal', Out);

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
	for i = 1:size(Lick, 1)
		if any(Lick(i, :) & tt >= tWater)
			resp(i) = true;
		end
	end
	[nTr, nC, nT] = size(X);
	Fi = reshape(permute(X, [1 3 2]), nTr, nT * nC);
	n = min(size(Fi, 1), numel(resp));
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

function [auc, p] = iTransferAUC(FA, yA, FL, yL, nPC, nPerm)
auc = iTrainTestAUC(FA, yA, FL, yL, nPC);
rng(0);
null = zeros(nPerm, 1);
for t = 1:nPerm
	null(t) = iTrainTestAUC(FA, yA(randperm(numel(yA))), FL, yL, nPC);
end
p = mean(null >= auc);
end

function auc = iTrainTestAUC(Ftr, ytr, Fte, yte, nPC)
mu = mean(Ftr, 1);
[~, ~, V] = svd(Ftr - mu, 'econ');
k = min(nPC, size(V, 2));
W = V(:, 1:k);
Ztr = [ones(size(Ftr, 1), 1), (Ftr - mu) * W];
Zte = [ones(size(Fte, 1), 1), (Fte - mu) * W];
b = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * ytr);
score = Zte * b;
if numel(unique(yte)) < 2, auc = NaN; return; end
[~, ~, ~, auc] = perfcurve(yte, score, 1);
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
if numel(unique(y(cv.test(1)))) < 1
	[~, ~, ~, auc] = perfcurve(y, score, 1);
else
	[~, ~, ~, auc] = perfcurve(y, score, 1);
end
end
