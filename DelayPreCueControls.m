% 延迟范式：pre-cue 状态预测"是否应答"——严格性控制
%
% 三个必须排除的假象：
%   (1) 相邻 trial 自相关：随机 5 折 CV 会把相邻 trial 分到训练/测试两侧，
%       AUC 被严重高估。→ 改为 leave-one-block-out，以及 block 内连续 10-trial 分块
%   (2) 行为本身的时间自相关：动物成串响应/成串不响应，则"任何慢变状态"都能
%       预测当前 trial。→ 用"上一 trial 是否命中"作为唯一基线，再看神经增量
%   (3) 个体一致性：只有少数鼠显著时，均值不可采信。→ 报逐鼠置换 p
%
% 输出：AUC_rand / AUC_lobo / AUC_chunk / AUC_prev / AUC_joint
clear all; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet','class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off','UniExp:Exception:Block_must_warn');

nPC = 8; nPerm = 100; tWater = 1.4; chunkLen = 10;
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.Mouse = string(C.Mouse);
xs = linspace(-3,3,48)';
selW = xs >= -1.0 & xs <= -0.05;

mice = unique(C.Mouse);
Out = table();
fprintf('%-9s %-6s %-8s %-8s %-9s %-8s %-9s %-8s %-7s %-7s\n', 'mouse','n','AUC_rand', ...
	'AUC_lobo','AUC_chunk','AUC_prev','AUC_joint','dlobo','p_lobo','p_prev');

for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	if isempty(TA), continue; end
	cells = unique(TA.CellUID);
	if numel(cells) < 20, continue; end

	[F, y, g, pv] = iStack(Tr, TA, cells, selW, tWater);
	if numel(y) < 200, continue; end
	F = iCenter(F, g);

	rng(20260101,'twister'); aRand = iCVrand(F, y, nPC, 5);
	[aLOBO, scLOBO, pLOBO] = iCVgroup(F, y, g, nPC, nPerm);
	chunk = iChunk(g, chunkLen);
	rng(20260101,'twister'); aChunk = iCVgroup(F, y, chunk, nPC, 0);

	% 行为基线：上一 trial 是否命中
	pvA = pv;
	ok = isfinite(pvA);
	aPrev = NaN;
	if nnz(ok) > 100 && numel(unique(pvA(ok))) == 2
		[~,~,~,aPrev] = perfcurve(y(ok), pvA(ok), 1);
	end
	% 神经 + 行为联合（leave-one-block-out）
	aJoint = iJoint(F, y, g, pv, nPC);

	fprintf('%-9s %-6d %-8.3f %-8.3f %-9.3f %-8.3f %-9.3f %-+8.3f %-7.3f %-7.3f\n', ...
		m, numel(y), aRand, aLOBO, aChunk, aPrev, aJoint, aLOBO-0.5, pLOBO, ...
		iPermPrev(y, pv));
	Out = [Out; table(string(m), numel(y), aRand, aLOBO, aChunk, aPrev, aJoint, pLOBO, ...
		'VariableNames',{'Mouse','N','AUC_rand','AUC_lobo','AUC_chunk','AUC_prev','AUC_joint','P_lobo'})]; %#ok<AGROW>
end

if height(Out) > 0
	se = @(v) std(v)/sqrt(numel(v));
	fprintf('\n=== %d mice (AW phase) ===\n', height(Out));
	fprintf('随机 5 折 CV      %.3f +- %.3f\n', mean(Out.AUC_rand), se(Out.AUC_rand));
	fprintf('留一 block        %.3f +- %.3f  (显著 %d/%d)\n', mean(Out.AUC_lobo), se(Out.AUC_lobo), nnz(Out.P_lobo<0.05), height(Out));
	fprintf('连续 10-trial 分块 %.3f +- %.3f\n', mean(Out.AUC_chunk), se(Out.AUC_chunk));
	fprintf('仅上一 trial 结果  %.3f +- %.3f\n', mean(Out.AUC_prev), se(Out.AUC_prev));
	fprintf('神经+行为 联合     %.3f +- %.3f\n', mean(Out.AUC_joint), se(Out.AUC_joint));
	fprintf('神经相对行为的增量 %+.3f +- %.3f\n', mean(Out.AUC_lobo-Out.AUC_prev), se(Out.AUC_lobo-Out.AUC_prev));
end
assignin('base','PreCueControls', Out);

%% ----------------------------------------------------------
function c = iChunk(g, L)
c = zeros(size(g));
for b = unique(g)'
	ix = find(g == b);
	c(ix) = ceil((1:numel(ix))' / L) + 1000*b;
end
[~,~,c] = unique(c);
end

function p = iPermPrev(y, pv)
y = y(:); pv = pv(:);
idx = find(isfinite(pv));
if numel(idx) < 100 || numel(unique(pv(idx))) < 2, p = NaN; return; end
[~,~,~,a] = perfcurve(y(idx), pv(idx), 1);
rng(3,'twister'); nul = nan(200,1);
for t = 1:200
	[~,~,~,nul(t)] = perfcurve(y(idx), pv(idx(randperm(numel(idx)))), 1);
end
p = mean(nul >= a);
end

function auc = iCVrand(F, y, nPC, k)
cv = cvpartition(numel(y),'KFold',k); sc = nan(numel(y),1);
for f = 1:cv.NumTestSets
	trn = training(cv,f); tst = test(cv,f);
	[Zt, Ze] = iProj(F, trn, tst, nPC);
	b = (Zt'*Zt + eye(size(Zt,2))) \ (Zt'*y(trn));
	sc(tst) = Ze*b;
end
[~,~,~,auc] = perfcurve(y, sc, 1);
end

function [auc, sc, p] = iCVgroup(F, y, g, nPC, nPerm)
gs = unique(g); sc = nan(numel(y),1);
Zm = cell(numel(gs),1); Em = cell(numel(gs),1);
for k = 1:numel(gs)
	tst = g == gs(k); trn = ~tst;
	[Zt, Ze] = iProj(F, trn, tst, nPC);
	Zm{k} = Zt; Em{k} = Ze;
	b = (Zt'*Zt + eye(size(Zt,2))) \ (Zt'*y(trn));
	sc(tst) = Ze*b;
end
[~,~,~,auc] = perfcurve(y, sc, 1);
p = NaN;
if nPerm > 0
	rng(11,'twister'); nul = nan(nPerm,1);
	for t = 1:nPerm
		yp = y(randperm(numel(y))); s = nan(numel(y),1);
		for k = 1:numel(gs)
			tst = g == gs(k); trn = ~tst;
			Zt = Zm{k}; Ze = Em{k};
			bb = (Zt'*Zt + eye(size(Zt,2))) \ (Zt'*yp(trn));
			s(tst) = Ze*bb;
		end
		[~,~,~,nul(t)] = perfcurve(yp, s, 1);
	end
	p = mean(nul >= auc);
end
end

function [Zt, Ze] = iProj(F, trn, tst, nPC)
mu = mean(F(trn,:),1); [~,~,V] = svd(F(trn,:)-mu,'econ');
k = min(nPC, size(V,2)); W = V(:,1:k);
Zt = [ones(nnz(trn),1), (F(trn,:)-mu)*W];
Ze = [ones(nnz(tst),1), (F(tst,:)-mu)*W];
end

function auc = iJoint(F, y, g, pv, nPC)
gs = unique(g); sc = nan(numel(y),1);
pvz = pv; pvz(~isfinite(pvz)) = mean(y);
for k = 1:numel(gs)
	tst = g == gs(k); trn = ~tst;
	[Zt, Ze] = iProj(F, trn, tst, nPC);
	Zt = [Zt, pvz(trn)]; Ze = [Ze, pvz(tst)];
	b = (Zt'*Zt + eye(size(Zt,2))) \ (Zt'*y(trn));
	sc(tst) = Ze*b;
end
[~,~,~,auc] = perfcurve(y, sc, 1);
end

function F = iCenter(F, g)
for b = unique(g)'
	r = g == b;
	if nnz(r) > 1, F(r,:) = F(r,:) - mean(F(r,:),1); end
end
end

function [F, y, g, pv] = iStack(Tr, T, cells, selW, tWater)
F = []; y = []; g = []; pv = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi),:), cells);
	if isempty(X), continue; end
	X = X(:,:,selW);
	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel); tuSel = Tr.TrialUID(sel);
	ok = cellfun(@(x) isa(x,'table'), tags);
	tags = tags(ok); tuSel = tuSel(ok);
	if numel(tags) < 10, continue; end
	[~, ord] = sort(tuSel); tags = tags(ord);
	[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	resp = false(size(Lick,1),1);
	for k = 1:size(Lick,1)
		if any(Lick(k,:) & tt >= tWater), resp(k) = true; end
	end
	Fi = reshape(permute(X,[1 3 2]), size(X,1), []);
	n = min(size(Fi,1), numel(resp));
	if n < 10, continue; end
	F = [F; Fi(1:n,:)]; y = [y; double(resp(1:n))];
	g = [g; repmat(bi,n,1)]; pv = [pv; [NaN; double(resp(1:n-1))]];
end
end
