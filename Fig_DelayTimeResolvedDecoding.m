% 延迟范式：时间分辨解码 —— 群体活动信息随时间如何变化
%
% 每一帧独立解码"本 trial 是否命中"（该帧全部细胞 -> PCA 8 维 -> logistic）
% CV = block 内连续 10-trial 分块；PCA 与回归均只在训练折内拟合
%
% 关键判读：
%   若信息是"cue 前预告"，AUC(t) 应在 cue 前已升高、cue 后不再增长；
%   若信息随接近行为而单调增长（水后最高），则为同步相关，不是预告。
%
% 面板：
%   A  AUC(t)（神经单独），4 鼠均值 ± SEM，灰色细线为单鼠
%   B  ΔAUC(t)（在行为基线之上的增量），灰色阴影为 block 内打乱标签的 null 带
clear all; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet','class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off','UniExp:Exception:Block_must_warn');

nPC = 8; nPerm = 60; tWater = 1.4; chunkLen = 10;
hitWin = [0.20 0.80];
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.Mouse = string(C.Mouse);
xs = linspace(-3,3,48)';
mice = unique(C.Mouse);
nT = numel(xs);

AUCn = nan(numel(mice), nT); AUCj = nan(numel(mice), nT);
AUCb = nan(numel(mice), 1);
NUL = nan(numel(mice), nT, nPerm);
fprintf('%-9s %-6s %-4s %-8s %-9s %-9s %-9s\n','mouse','n','nB','AUC_base','AUC(-1s)','AUC(0.5s)','AUC(2.5s)');
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	if isempty(TA), continue; end
	cells = unique(TA.CellUID);
	[F, y, g, beh] = iStack(Tr, TA, cells, tWater);
	if numel(y) < 100, continue; end
	nC = numel(cells);

	blks = unique(g);
	okB = arrayfun(@(b) mean(y(g==b)) >= hitWin(1) && mean(y(g==b)) <= hitWin(2), blks);
	keepB = blks(okB);
	if isempty(keepB), continue; end
	sel = ismember(g, keepB);
	F = F(sel,:); y = y(sel); g = g(sel); beh = beh(sel,:);
	if numel(unique(y)) < 2 || numel(y) < 80, continue; end

	% 去掉含 NaN 的细胞
	F3 = permute(reshape(F, size(F,1), nT, nC), [1 3 2]);
	badC = any(any(~isfinite(F3),3),1);
	if any(badC), F3 = F3(:,[~badC],:); nC = nnz(~badC); end
	if nC < 20, continue; end
	F = reshape(permute(F3,[1 3 2]), size(F3,1), []);
	F = iCenter(F, g);

	grp = iChunk(g, chunkLen);
	gs = unique(grp);
	% 预计算每折每帧的投影（PCA 无监督，置换时可复用）
	P = cell(numel(gs), nT);
	for k = 1:numel(gs)
		tst = grp == gs(k); trn = ~tst;
		if nnz(tst) < 3 || nnz(trn) < 40 || numel(unique(y(trn))) < 2, continue; end
		for t = 1:nT
			Fc = F(:, (t-1)*nC + (1:nC));
			mu = mean(Fc(trn,:),1); [~,~,V] = svd(Fc(trn,:)-mu,'econ');
			W = V(:,1:min(nPC,size(V,2)));
			Zt = (Fc(trn,:)-mu)*W; Ze = (Fc(tst,:)-mu)*W;
			sd = std(Zt,0,1); sd(sd==0) = 1;
			P{k,t} = struct('Zt',Zt./sd,'Ze',Ze./sd,'trn',trn,'tst',tst);
		end
	end

	% 行为基线（不随时间变化）
	sb = nan(numel(y),1);
	for k = 1:numel(gs)
		if isempty(P{k,1}), continue; end
		e = P{k,1};
		sb(e.tst) = iFit([ones(nnz(e.trn),1), beh(e.trn,:)], y(e.trn), [ones(nnz(e.tst),1), beh(e.tst,:)]);
	end
	ok = isfinite(sb);
	[~,~,~,AUCb(i)] = perfcurve(y(ok), sb(ok), 1);

	an = nan(nT,1); aj = nan(nT,1);
	for t = 1:nT
		s1 = nan(numel(y),1); s2 = nan(numel(y),1);
		for k = 1:numel(gs)
			if isempty(P{k,t}), continue; end
			e = P{k,t};
			s1(e.tst) = iFit([ones(nnz(e.trn),1), e.Zt], y(e.trn), [ones(nnz(e.tst),1), e.Ze]);
			s2(e.tst) = iFit([ones(nnz(e.trn),1), beh(e.trn,:), e.Zt], y(e.trn), ...
				[ones(nnz(e.tst),1), beh(e.tst,:), e.Ze]);
		end
		[~,~,~,an(t)] = perfcurve(y, s1, 1);
		[~,~,~,aj(t)] = perfcurve(y, s2, 1);
	end
	AUCn(i,:) = an'; AUCj(i,:) = aj';

	% null：block 内打乱标签
	rng(17,'twister');
	for t = 1:nPerm
		yp = y;
		for b = unique(g)'
			ix = find(g == b);
			yp(ix) = y(ix(randperm(numel(ix))));
		end
		% 同一套打乱标签下重算行为基线，增量才是可比的
		sbp = nan(numel(y),1);
		for k = 1:numel(gs)
			if isempty(P{k,1}), continue; end
			e = P{k,1};
			sbp(e.tst) = iFit([ones(nnz(e.trn),1), beh(e.trn,:)], yp(e.trn), ...
				[ones(nnz(e.tst),1), beh(e.tst,:)]);
		end
		[~,~,~,abp] = perfcurve(yp, sbp, 1);
		at = nan(nT,1);
		for tt = 1:nT
			s2 = nan(numel(y),1);
			for k = 1:numel(gs)
				if isempty(P{k,tt}), continue; end
				e = P{k,tt};
				s2(e.tst) = iFit([ones(nnz(e.trn),1), beh(e.trn,:), e.Zt], yp(e.trn), ...
					[ones(nnz(e.tst),1), beh(e.tst,:), e.Ze]);
			end
			[~,~,~,at(tt)] = perfcurve(yp, s2, 1);
		end
		NUL(i,:,t) = at' - abp;
	end
	fprintf('%-9s %-6d %-4d %-8.3f %-9.3f %-9.3f %-9.3f\n', m, numel(y), numel(keepB), ...
		AUCb(i), an(round(interp1(xs,1:nT,-1))), ...
		an(round(interp1(xs,1:nT,0.5))), an(round(interp1(xs,1:nT,2.5))));
end

use = find(isfinite(AUCb));
mN = mean(AUCn(use,:),1,'omitnan'); sN = std(AUCn(use,:),0,1,'omitnan')/sqrt(numel(use));
dJ = AUCj(use,:) - AUCb(use);
mD = mean(dJ,1,'omitnan'); sD = std(dJ,0,1,'omitnan')/sqrt(numel(use));
nulm = squeeze(mean(NUL(use,:,:),1,'omitnan'));
lo = quantile(nulm,0.05,2); hi = quantile(nulm,0.95,2);
% 3 帧滑动平均，降低单帧噪声
sm = @(v) [v(1); conv(v(:), ones(3,1)/3, 'valid'); v(end)];
mNs = sm(mN); sNs = sm(sN); mDs = sm(mD); sDs = sm(sD);

fprintf('\n=== AUC(t) 关键帧（%d mice）===\n', numel(use));
for tk = [-2.5 -1.5 -0.5 0 0.5 1.0 1.5 2.0 2.5]
	[~,it] = min(abs(xs-tk));
	fprintf('  t=%+.1f s  AUC=%.3f  dAUC=%+.3f (null %.3f~%.3f)\n', xs(it), mN(it), mD(it), lo(it), hi(it));
end

%% ---------------- 出图 ----------------
f = figure('Color','w');
f.Units = 'centimeters'; f.Position(3:4) = [26 9.6];
col = [0.20 0.45 0.75];

ax1 = axes(f,'Position',[0.055 0.16 0.38 0.68]); hold(ax1,'on');
for i = use(:)'
	plot(ax1, xs, AUCn(i,:), '-', 'Color',[0.86 0.88 0.91], 'LineWidth',0.4);
end
patch(ax1, [xs; flipud(xs)], [mNs-sNs; flipud(mNs+sNs)], col, 'FaceAlpha',0.20, 'EdgeColor','none');
plot(ax1, xs, mNs, '-', 'Color',col, 'LineWidth',1.8);
plot(ax1,[-3 3],[0.5 0.5],':','Color',[0.45 0.45 0.45]);
iMark(ax1, xs, tWater);
xlim(ax1,[-3 3]); ylim(ax1,[0.4 0.9]);
xlabel(ax1,'Time from cue (s)'); ylabel(ax1,'AUC (hit vs miss)');
title(ax1,'Population decoding of trial outcome','FontWeight','normal','FontSize',9);
box(ax1,'off');

ax2 = axes(f,'Position',[0.585 0.16 0.38 0.68]); hold(ax2,'on');
patch(ax2, [xs; flipud(xs)], [lo; flipud(hi)], [0.85 0.85 0.85], 'FaceAlpha',0.55,'EdgeColor','none');
plot(ax2,[-3 3],[0 0],'-','Color',[0.45 0.45 0.45],'LineWidth',0.8);
patch(ax2, [xs; flipud(xs)], [mDs-sDs; flipud(mDs+sDs)], col, 'FaceAlpha',0.20,'EdgeColor','none');
plot(ax2, xs, mDs, '-', 'Color',col, 'LineWidth',1.8);
iMark(ax2, xs, tWater);
xlim(ax2,[-3 3]);
xlabel(ax2,'Time from cue (s)'); ylabel(ax2,'\DeltaAUC over behavioural baseline');
title(ax2,'Increment beyond previous-trial and drift model','FontWeight','normal','FontSize',9);
box(ax2,'off');

outDir = fileparts(mfilename('fullpath'));
exportgraphics(f, fullfile(outDir,'_tr.png'), 'Resolution', 150);
savefig(f, fullfile(outDir,'Fig_DelayTimeResolvedDecoding.fig'));
assignin('base','TimeResolved', struct('xs',xs,'AUCn',AUCn,'AUCj',AUCj,'AUCb',AUCb,'mN',mN,'mD',mD,'lo',lo,'hi',hi));

%% ---------------------------------------------------------
function iMark(ax, xs, tWater)
yl = ylim(ax);
plot(ax,[0 0],yl,':','Color',[0.35 0.35 0.35],'LineWidth',0.8);
plot(ax,[tWater tWater],yl,':','Color',[0.65 0.35 0.15],'LineWidth',0.8);
text(ax, 0.05, yl(2)-0.02*diff(yl), 'cue', 'FontSize',6.5, 'Color',[0.35 0.35 0.35]);
text(ax, tWater+0.05, yl(2)-0.02*diff(yl), 'water available', 'FontSize',6.5, 'Color',[0.65 0.35 0.15]);
ylim(ax, yl);
end

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

function s = iFit(X, y, Xe)
lam = 1e-2;
B = X'*X + lam*eye(size(X,2)); B(1,1) = B(1,1) - lam;
w = B \ (X'*y);
s = Xe*w;
end

function [F, y, g, beh] = iStack(Tr, T, cells, tWater)
F = []; y = []; g = []; beh = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi),:), cells);
	if isempty(X), continue; end
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
