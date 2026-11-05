% 延迟范式（不舔不给水）数据：反应前群体活动能否预测本次行为？
%
% 严格流程（吸取 undelayed 数据的教训）：
%   1) 特征只用**反应之前**的活动：cue -1.0 s → +1.3 s（水在 1.5 s 才可用）
%   2) 行为只在 1.4 s 之后的首个舔水算作"应答"（1.4 s 之前的舔是预期性的）
%   3) 特征与行为**在每个 block 内去均值**，避免解码器只靠"识别 block"得分
%   4) PCA 在交叉验证折内拟合；R^2 / AUC 由 5 折 CV 给出；100 次打乱得到经验 p
%
% 输出：每只鼠每阶段的 hit/miss 解码 AUC 与 RT 解码 R^2
%
% 备注：yqn2200 的最后一个 LW block（命中率 0.38）按用户要求剔除；
%       本脚本只分析 AW（AudioLearnWater）block，故不受影响。

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
tWater = 1.4;      % 应答判定起点（s，相对 cue）
winFeat = [-1.0, 1.3];

DS = TransferLearning.ALDelayed();
Tr = DS.Trials;
Tr.TrialUID = uint64(Tr.TrialUID);
xs = linspace(-3, 3, 48)';
selWin = xs >= winFeat(1) & xs <= winFeat(2);

mice = unique(string(DS.Cells.Mouse));
fprintf('%-9s %-5s %-6s %-7s %-7s %-7s %-7s\n', 'mouse', 'nTr', 'hit%', 'AUC', 'pAUC', 'R2_RT', 'pR2');

Res = table();
for i = 1:numel(mice)
	m = char(mice(i));
	T = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	if isempty(T), continue; end

	blks = unique(T.BlockUID);
	F = []; yhit = []; yrt = []; g = [];
	for bi = 1:numel(blks)
		[Fi, hitv, rtv] = iBlockXY(DS, Tr, T, blks(bi), selWin, tWater);
		if isempty(Fi), continue; end
		F = [F; Fi]; %#ok<AGROW>
		yhit = [yhit; hitv]; %#ok<AGROW>
		yrt = [yrt; rtv]; %#ok<AGROW>
		g = [g; repmat(bi, numel(hitv), 1)]; %#ok<AGROW>
	end
	if numel(yhit) < 60, continue; end
	hitRate = mean(yhit);

	% block 内去均值：特征与连续目标去均值；分类标签保持 0/1 不变
	for bi = unique(g)'
		r = g == bi;
		F(r, :) = F(r, :) - mean(F(r, :), 1);
		yr = yrt(r);
		yrt(r) = yr - mean(yr, 'omitnan');
	end

	% (1) hit / miss
	auc = iCVAUC(F, yhit, nPC);
	rng(0);
	pa = zeros(nPerm, 1);
	for t = 1:nPerm
		pa(t) = iCVAUC(F, yhit(randperm(numel(yhit))), nPC);
	end
	pAUC = mean(pa >= auc);

	% (2) RT（仅命中 trial）
	ok = isfinite(yrt);
	r2 = iCVR2(F(ok, :), yrt(ok), nPC);
	rng(0);
	pr = zeros(nPerm, 1);
	for t = 1:nPerm
		yy = yrt(ok);
		pr(t) = iCVR2(F(ok, :), yy(randperm(numel(yy))), nPC);
	end
	pR2 = mean(pr >= r2);

	fprintf('%-9s %-5d %-6.2f %-7.3f %-7.3f %-7.3f %-7.3f\n', m, numel(yhit), ...
		hitRate, auc, pAUC, r2, pR2);
	Res = [Res; table(string(m), numel(yhit), hitRate, auc, pAUC, r2, pR2, ...
		'VariableNames', {'Mouse','NTrial','HitRate','AUC','PAUC','R2RT','PR2'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 ---\n');
fprintf('AUC = %.2f +- %.2f (n = %d mice)\n', mean(Res.AUC), std(Res.AUC) / sqrt(height(Res)), height(Res));
fprintf('R2(RT) = %.3f +- %.3f\n', mean(Res.R2RT), std(Res.R2RT) / sqrt(height(Res)));
assignin('base', 'DelayNeuroBehav', Res);

%% ------------------------------------------------------------------
function [F, hitv, rtv] = iBlockXY(DS, Tr, T, blk, selWin, tWater)
F = []; hitv = []; rtv = [];
X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blk, :), unique(T.CellUID));
if isempty(X), return; end
X = X(:, :, selWin);
tu = unique(T.TrialUID(T.BlockUID == blk));
sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blk;
tags = Tr.ResampledTags(sel);
tuSel = Tr.TrialUID(sel);
okTag = cellfun(@(x) isa(x, 'table'), tags);
tags = tags(okTag); tuSel = tuSel(okTag);
if isempty(tags), return; end
[~, ord] = sort(tuSel);
tags = tags(ord);
tuSel = tuSel(ord);
[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
resp = false(size(Lick, 1), 1);
rtv = nan(size(Lick, 1), 1);
for i = 1:size(Lick, 1)
	k = find(Lick(i, :) & tt >= tWater, 1);
	if ~isempty(k)
		resp(i) = true;
		rtv(i) = tt(k) - tWater;
	end
end
hitv = double(resp);
[nTr, nC, nT] = size(X);
F = reshape(permute(X, [1 3 2]), nTr, nT * nC);
% trial 对齐：X 的行按 TrialUID 升序，与 tuSel 一致
n = min(size(F, 1), numel(hitv));
F = F(1:n, :); hitv = hitv(1:n); rtv = rtv(1:n);
end

function auc = iCVAUC(F, y, nPC)
% 5 折 CV 的 ridge 回归打分 -> AUC
n = size(F, 1);
if n < 30, auc = NaN; return; end
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
if numel(unique(y)) < 2, auc = NaN; return; end
[~, ~, ~, a] = perfcurve(y, score, 1);
auc = a;
end

function r2 = iCVR2(F, y, nPC)
n = size(F, 1);
if n < 30, r2 = NaN; return; end
cv = cvpartition(n, 'KFold', 5);
yhat = nan(n, 1);
for f = 1:cv.NumTestSets
	trn = training(cv, f); tst = test(cv, f);
	mu = mean(F(trn, :), 1);
	[~, ~, V] = svd(F(trn, :) - mu, 'econ');
	k = min(nPC, size(V, 2));
	W = V(:, 1:k);
	Ztr = [ones(sum(trn), 1), (F(trn, :) - mu) * W];
	Zte = [ones(sum(tst), 1), (F(tst, :) - mu) * W];
	b = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * y(trn));
	yhat(tst) = Zte * b;
end
r2 = 1 - sum((y - yhat).^2) / sum((y - mean(y)).^2);
end
