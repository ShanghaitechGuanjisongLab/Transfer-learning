% 延迟范式 pre-cue 解码的重建分析（方案 2）+ 时段阴性对照
%
% 设计：
%   - 只用命中率 0.2~0.8 的 block（排除学习过渡与单类 block）
%   - 标签 = 本 trial 是否命中
%   - 行为基线 = 上一 trial 结果 + 前 8 trial 滑动命中率 + block 内 trial 序号
%   - 神经增量 = 嵌套模型 dAUC（行为基线 -> 行为 + 神经 PC）
%   - CV = block 内连续 10-trial 分块（杜绝相邻 trial 泄漏）
%   - 置换 = block 内打乱神经特征（保留 block 结构与行为标签配对）
%   - 阴性对照 = 同一流程换成 ITI 中段(-3~-2 s)与水后(2~3 s)的伪特征
clear all; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet','class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off','UniExp:Exception:Block_must_warn');

nPC = 4; nPerm = 100; tWater = 1.4; chunkLen = 10;
hitWin = [0.20 0.80];
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.Mouse = string(C.Mouse);
xs = linspace(-3,3,48)';
zones = struct( ...
	'name', {'pre','ITI','post'}, ...
	'sel',  {xs>=-1.0 & xs<=-0.05, xs>=-3.0 & xs<=-2.05, xs>=2.0 & xs<=2.95});
mice = unique(C.Mouse);

Out = table();
fprintf('%-9s %-6s %-5s %-8s %-8s %-8s %-9s | %-9s %-9s\n', ...
	'mouse','nKeep','nB','AUC_base','AUC_nerve','AUC_joint','dAUC_pre','dAUC_ITI','dAUC_post');
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	if isempty(TA), continue; end
	cells = unique(TA.CellUID);
	[Ffull, y, g, beh] = iStack(Tr, TA, cells, true(size(xs)), tWater);
	if numel(y) < 100, continue; end

	nT = numel(xs); nC = numel(cells);
	F3 = permute(reshape(Ffull, size(Ffull,1), nT, nC), [1 3 2]);
	badC = any(any(~isfinite(F3), 3), 1);
	if any(badC)
		F3 = F3(:, ~badC, :);
		nC = nnz(~badC);
	end
	if nC < 20, continue; end

	blks = unique(g);
	okB = arrayfun(@(b) mean(y(g==b)) >= hitWin(1) && mean(y(g==b)) <= hitWin(2), blks);
	keepB = blks(okB);
	if isempty(keepB), fprintf('%-9s no eligible block\n', m); continue; end
	sel = ismember(g, keepB);
	F3 = F3(sel, :, :); y = y(sel); g = g(sel); beh = beh(sel, :);
	if numel(unique(y)) < 2 || numel(y) < 80, continue; end

	grp = iChunk(g, chunkLen);
	dA = nan(1, 3); ab = NaN; an = NaN; aj = NaN;
	for z = 1:3
		Fz = iCenter(reshape(F3(:,:,zones(z).sel), size(F3,1), []), g);
		[a0, a1, a2] = iRunCV(Fz, beh, y, grp, nPC);
		dA(z) = a2 - a0;
		if z == 1, ab = a0; an = a1; aj = a2; end
	end

	rng(5,'twister'); nul = nan(nPerm,1);
	Fpre = iCenter(reshape(F3(:,:,zones(1).sel), size(F3,1), []), g);
for t = 1:nPerm
		Fp = Fpre;
		for b = unique(g)'
			ix = find(g == b);
			Fp(ix,:) = Fpre(ix(randperm(numel(ix))), :);
		end
		[~, ~, a] = iRunCV(Fp, beh, y, grp, nPC);
		nul(t) = a - ab;
	end
	p = mean(nul >= dA(1));

	fprintf('%-9s %-6d %-5d %-8.3f %-8.3f %-8.3f %-+9.3f | %-+9.3f %-+9.3f\n', ...
		m, numel(y), numel(keepB), ab, an, aj, dA(1), dA(2), dA(3));
	fprintf('          null: 5%%=%+.3f med=%+.3f 95%%=%+.3f ; p(pre)=%.3f ; hit=%.2f\n', ...
		quantile(nul,0.05), median(nul), quantile(nul,0.95), p, mean(y));
	Out = [Out; table(string(m), numel(y), numel(keepB), ab, an, aj, dA(1), dA(2), dA(3), p, mean(y), ...
		'VariableNames',{'Mouse','N','NBlock','AUC_base','AUC_nerve','AUC_joint', ...
		'dAUC_pre','dAUC_ITI','dAUC_post','P_pre','Hit'})]; %#ok<AGROW>
end

if height(Out) > 0
	se = @(v) std(v)/sqrt(numel(v));
	fprintf('\n=== %d mice ===\n', height(Out));
	fprintf('行为基线          %.3f +- %.3f\n', mean(Out.AUC_base), se(Out.AUC_base));
	fprintf('仅神经            %.3f +- %.3f\n', mean(Out.AUC_nerve), se(Out.AUC_nerve));
	fprintf('行为 + 神经       %.3f +- %.3f\n', mean(Out.AUC_joint), se(Out.AUC_joint));
	fprintf('增量 pre-cue      %+.3f +- %.3f  (p<0.05: %d/%d)\n', mean(Out.dAUC_pre), ...
		se(Out.dAUC_pre), nnz(Out.P_pre<0.05), height(Out));
	fprintf('增量 ITI(-3~-2s) %+.3f +- %.3f  <- negative control\n', mean(Out.dAUC_ITI), se(Out.dAUC_ITI));
	fprintf('增量 post(2~3s)  %+.3f +- %.3f  <- negative control\n', mean(Out.dAUC_post), se(Out.dAUC_post));
end
assignin('base','PreCueIncrement', Out);

%% ---------------------------------------------------------------
function c = iChunk(g, L)
c = zeros(size(g));
for b = unique(g)'
	ix = find(g == b);
	c(ix) = ceil((1:numel(ix))'/L) + 1000*b;
end
[~,~,c] = unique(c);
end

function F = iCenter(F, g)
for b = unique(g)'
	r = g == b;
	if nnz(r) > 1, F(r,:) = F(r,:) - mean(F(r,:),1); end
end
end

function [ab, an, aj] = iRunCV(F, beh, y, grp, nPC)
gs = unique(grp);
sb = nan(numel(y),1); sn = nan(numel(y),1); sj = nan(numel(y),1);
for k = 1:numel(gs)
	tst = grp == gs(k); trn = ~tst;
	if nnz(tst) < 3 || nnz(trn) < 40, continue; end
	if numel(unique(y(trn))) < 2, continue; end
	mu = mean(F(trn,:),1); [~,~,V] = svd(F(trn,:)-mu,'econ');
	kk = min(nPC, size(V,2)); W = V(:,1:kk);
	Zt = (F(trn,:)-mu)*W; Ze = (F(tst,:)-mu)*W;
	sd = std(Zt,0,1); sd(sd==0) = 1;
	Zt = Zt./sd; Ze = Ze./sd;
	sb(tst) = iFit([ones(nnz(trn),1), beh(trn,:)], y(trn), [ones(nnz(tst),1), beh(tst,:)]);
	sn(tst) = iFit([ones(nnz(trn),1), Zt], y(trn), [ones(nnz(tst),1), Ze]);
	sj(tst) = iFit([ones(nnz(trn),1), beh(trn,:), Zt], y(trn), [ones(nnz(tst),1), beh(tst,:), Ze]);
end
ok = isfinite(sb) & isfinite(sn) & isfinite(sj);
if nnz(ok) < 40 || numel(unique(y(ok))) < 2, ab = NaN; an = NaN; aj = NaN; return; end
[~,~,~,ab] = perfcurve(y(ok), sb(ok), 1);
[~,~,~,an] = perfcurve(y(ok), sn(ok), 1);
[~,~,~,aj] = perfcurve(y(ok), sj(ok), 1);
end

function s = iFit(X, y, Xe)
lam = 1e-2;
B = X'*X + lam*eye(size(X,2)); B(1,1) = B(1,1) - lam;
w = B \ (X'*y);
s = Xe*w;
end

function [F, y, g, beh] = iStack(Tr, T, cells, PSel, tWater)
F = []; y = []; g = []; beh = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi),:), cells);
	if isempty(X), continue; end
	X = X(:,:,PSel);
	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel); tuSel = Tr.TrialUID(sel);
	ok = cellfun(@(x) isa(x,'table'), tags);
	tags = tags(ok); tuSel = tuSel(ok);
	if numel(tags) < 15, continue; end
	[~, ord] = sort(tuSel); tags = tags(ord);
	[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	resp = false(size(Lick,1),1);
	for k = 1:size(Lick,1)
		if any(Lick(k,:) & tt >= tWater), resp(k) = true; end
	end
	Fi = reshape(permute(X,[1 3 2]), size(X,1), []);
	n = min(size(Fi,1), numel(resp));
	if n < 15, continue; end
	yy = double(resp(1:n));
	prev = [0.5; yy(1:end-1)];
	roll = 0.5*ones(n,1);
	for k = 2:n
		lo = max(1, k-8);
		roll(k) = mean(yy(lo:k-1));
	end
	pos = ((1:n)' - 1) / max(1, n-1);
	beh = [beh; prev, roll, pos];
	F = [F; Fi(1:n,:)]; y = [y; yy]; g = [g; repmat(bi,n,1)];
end
end
