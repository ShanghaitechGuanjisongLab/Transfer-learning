% 神经 -> 行为 的可解码性：在学习阶段 vs 学会之后（undelayed 成像队列）
%
% 背景：undelayed 范式里学会后舔水被压成刻板动作（CV 0.03-0.05），没有任何
% trial 间变异可解释；但"尚未学会"的 block（命中率 < 0.9）行为变异很大
% （CV 0.22-0.35）。本脚本检验：在这些学习期 block 里，群体活动能否预测
% 该 trial 的舔水量（cue 后 0-2 s 帧数）。
%
% 做法：每只鼠把 block 分成 early（Performance < 0.9）与 learned（>= 0.9），
% 各取最多 3 个 block 合并成一个训练集；用 5 折交叉验证的 ridge
% （PCA 在折内拟合，避免泄漏）计算 R^2，并用 100 次标签打乱得到经验 p 值。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nPC = 8;
nBlockMax = 3;
nPerm = 100;

xs = seconds(TransferLearning.Xs); xs = xs(:);
win = (xs >= -1) & (xs <= 0.25);   % 只用反应之前的活动（避免“用刚噂完的活动预测噂水量”的循环）

DS = TransferLearning.AudioLightBaseline();
Tr = DS.Trials;
Tr.TrialUID = uint64(Tr.TrialUID);
mice = unique(string(DS.Cells.Mouse));

R = table();
fprintf('%-9s %-8s %-5s %-8s %-8s %-8s\n', 'mouse', 'stage', 'nTr', 'behCV', 'R2cv', 'p_perm');
for i = 1:numel(mice)
	m = char(mice(i));
	T = TransferLearning.QueryZScoreNts(DS, m, 'AudioWater');
	if isempty(T), continue; end
	bL = unique(T.BlockUID);
	tm = arrayfun(@(x) iBlockTime(DS, x), bL);
	[~, o] = sort(tm);
	bL = bL(o);
	perf = arrayfun(@(x) iBlockPerf(DS, x), bL);

	stageBlk = {bL(perf < 0.9), bL(perf >= 0.9)};
	stageName = ["early", "learned"];
	for s = 1:2
		blks = stageBlk{s};
		if numel(blks) < 1, continue; end
		blks = blks(1:min(nBlockMax, numel(blks)));
		F = []; y = []; g = [];
		for bi = 1:numel(blks)
			[X, yy] = iBlockXY(DS, Tr, T, blks(bi), win);
			if isempty(X), continue; end
			F = [F; X]; %#ok<AGROW>
			y = [y; yy]; %#ok<AGROW>
			g = [g; repmat(bi, numel(yy), 1)]; %#ok<AGROW>
		end
		if numel(y) < 25, continue; end
		behCV = std(y) / max(mean(y), eps);
		% block 内去均值：否则解码器只需识别“这是哪个 block”就能预测该 block
		% 的平均嘸水量，得到的 R^2 反映的是 block 间差异，而不是 trial 间耦合
		for bi = unique(g)'
			r = g == bi;
			F(r, :) = F(r, :) - mean(F(r, :), 1);
			y(r) = y(r) - mean(y(r));
		end
		r2 = iCVridge(F, y, nPC);
		rng(0);
		pr = zeros(nPerm, 1);
		for t = 1:nPerm
			pr(t) = iCVridge(F, y(randperm(numel(y))), nPC);
		end
		pPerm = mean(pr >= r2);
		fprintf('%-9s %-8s %-5d %-8.2f %-8.3f %-8.3f\n', m, stageName(s), numel(y), ...
			behCV, r2, pPerm);
		R = [R; table(string(m), stageName(s), numel(y), behCV, r2, pPerm, ...
			'VariableNames', {'Mouse','Stage','NTrial','BehCV','R2','Pperm'})]; %#ok<AGROW>
	end
end

fprintf('\n--- 汇总 ---\n');
for s = ["early", "learned"]
	sel = R.Stage == s;
	if any(sel)
		fprintf('%-8s: R2 = %.2f +- %.2f (n = %d mice), 显著鼠数 %d/%d\n', s, ...
			mean(R.R2(sel)), std(R.R2(sel)) / sqrt(nnz(sel)), nnz(sel), ...
			nnz(R.Pperm(sel) < 0.05), nnz(sel));
	end
end
assignin('base', 'NeuroBehavDecoding', R);

%% ------------------------------------------------------------------
function t = iBlockTime(DS, b)
t = DS.Blocks.DateTime(find(DS.Blocks.BlockUID == b, 1));
end

function p = iBlockPerf(DS, b)
p = DS.Blocks.Performance(find(DS.Blocks.BlockUID == b, 1));
end

function [F, y] = iBlockXY(DS, Tr, T, blk, win)
X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blk, :), unique(T.CellUID));
F = []; y = [];
if isempty(X), return; end
X = X(:, :, win);
tu = unique(T.TrialUID(T.BlockUID == blk));
sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blk;
tags = Tr.ResampledTags(sel);
tuSel = Tr.TrialUID(sel);
if isempty(tags), return; end
[~, ord] = sort(tuSel);
tags = tags(ord);
[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
y = double(sum(Lick(:, tt >= 0 & tt <= 2), 2));
[nTr, nC, nT] = size(X);
F = reshape(permute(X, [1 3 2]), nTr, nT * nC);
if numel(y) ~= nTr
	n = min(nTr, numel(y));
	F = F(1:n, :); y = y(1:n);
end
end

function r2 = iCVridge(F, y, nPC)
% 5 折 CV；PCA 在折内拟合；ridge 正则由内层留一近似固定为 1
n = size(F, 1);
if n < 20, r2 = NaN; return; end
cv = cvpartition(n, 'KFold', 5);
yhat = nan(n, 1);
for f = 1:cv.NumTestSets
	trn = training(cv, f);
	tst = test(cv, f);
	mu = mean(F(trn, :), 1);
	[~, ~, V] = svd(F(trn, :) - mu, 'econ');
	k = min(nPC, size(V, 2));
	W = V(:, 1:k);
	Ztr = [ones(sum(trn), 1), (F(trn, :) - mu) * W];
	Zte = [ones(sum(tst), 1), (F(tst, :) - mu) * W];
	lam = 1;
	b = (Ztr' * Ztr + lam * eye(k + 1)) \ (Ztr' * y(trn));
	yhat(tst) = Zte * b;
end
r2 = 1 - sum((y - yhat).^2) / sum((y - mean(y)).^2);
end
