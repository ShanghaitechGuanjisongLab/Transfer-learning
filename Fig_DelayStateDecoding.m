% 延迟范式（不舔不给水）：状态预测应答 + 窗口/运动对照
%
% 面板：
%   A  示例鼠 cue 诱发轨迹（PC1-PC2），命中 vs 未命中（描述性）
%   B  逐鼠解码 AUC：cue 前(-1~-0.05 s)、整段 cue(0~1.0 s)、整段 cue 但只用
%      "安静 trial"（cue 后 0.8 s 内无舔水）
%   C  增量：在 cue 前特征上加入 cue 期特征后的 ΔAUC（全部 trial vs 安静 trial）
%   D  应答概率随"到学会态距离"的变化（五分位，AW 与 LW）
%
% 说明：
%   - 特征均在 block 内去均值；PCA 与读出在训练折内拟合；5 折交叉验证
%   - "有动作 vs 无动作"无法直接做两组各自解码：有动作的 trial 几乎都是命中，
%     类别极度不平衡，AUC 不可估。因此用"安静 trial 子集"作为运动对照，
%     并将"窗口拉长后 AUC 上升"解释为运动贡献。
%   - 超过 0.8 s 后几乎不存在无舔水的 trial（安静子集命中率降到 0.08），
%     故安静对照只做到 0.8 s。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nPC = 8;
nPerm = 50;
tWater = 1.4;
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse);
xs = linspace(-3, 3, 48)';

wAll = xs >= -1.0 & xs <= 1.5;
xsW = xs(wAll);
idxP = find(xsW >= -1.0 & xsW <= -0.05);   % cue 前
idxC = find(xsW >= 0 & xsW <= 1.0);        % 整段 cue
idxC8 = find(xsW >= 0 & xsW <= 0.8);       % 安静对照用到的 cue 段

mice = unique(C.Mouse);
nM = numel(mice);
AUC_P = nan(nM,1); AUC_C = nan(nM,1); AUC_Cq = nan(nM,1);
AUC_PC = nan(nM,1); AUC_PCq = nan(nM,1); AUC_Pq = nan(nM,1);
dAll = nan(nM,1); pAll = nan(nM,1); dQ = nan(nM,1); pQ = nan(nM,1);
nQ = nan(nM,1); hitQ = nan(nM,1);
binAW = nan(nM,5); binLW = nan(nM,5); ExT = [];

for i = 1:nM
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	[XA, yA, gA, onA] = iStack(DS, Tr, TA, cells, wAll, tWater);
	[XL, yL, gL] = iStack(DS, Tr, TL, cells, wAll, tWater);
	if numel(yA) < 100 || numel(yL) < 100, continue; end

	FA = iFlat(XA, gA); FL = iFlat(XL, gL);
	rng(20260101, 'twister');   % 固定折划分，保证可复现
	FP = FA(:, iCols(idxP, numel(cells))); FC = FA(:, iCols(idxC, numel(cells)));
	FC8 = FA(:, iCols(idxC8, numel(cells)));
	PL = FL(:, iCols(idxP, numel(cells))); CL = FL(:, iCols(idxC, numel(cells)));

	q = isnan(onA) | onA > 0.8;      % 安静 trial（cue 后 0.8 s 内无舔水）
	nQ(i) = nnz(q); hitQ(i) = mean(yA(q));

	AUC_P(i) = iCV(FP, yA, nPC);
	AUC_C(i) = iCV(FC, yA, nPC);
	AUC_PC(i) = iCV([FP, FC], yA, nPC);
	dAll(i) = AUC_PC(i) - AUC_P(i);

	if nnz(q) > 60 && numel(unique(yA(q))) == 2
		AUC_Pq(i)  = iCV(FP(q,:), yA(q), nPC);
		AUC_Cq(i)  = iCV(FC8(q,:), yA(q), nPC);
		AUC_PCq(i) = iCV([FP(q,:), FC8(q,:)], yA(q), nPC);
		dQ(i) = AUC_PCq(i) - AUC_Pq(i);
	end

	rng(0); nulA = nan(nPerm,1);
	for t = 1:nPerm
		Cp = FC(randperm(size(FC,1)), :);
		nulA(t) = iCV([FP, Cp], yA, nPC) - AUC_P(i);
	end
	pAll(i) = mean(nulA >= dAll(i));

	if isfinite(dQ(i))
		rng(1); nulQ = nan(nPerm,1);
		qq = find(q); yy = yA(q);
		for t = 1:nPerm
			perm = randperm(numel(qq));
			Cq = FC8(qq(perm), :);
			nulQ(t) = iCV([FP(qq,:), Cq], yy, nPC) - AUC_Pq(i);
		end
		pQ(i) = mean(nulQ >= dQ(i));
	end

	% D 面板：距离 vs 应答概率
	[TrajA, TrajL] = iTraj(iBaseX(XA), iBaseX(XL));
	MU = reshape(mean(TrajA,1), 1, []);
	dA = sqrt(sum((reshape(TrajA, size(TrajA,1), []) - MU).^2, 2));
	dL = sqrt(sum((reshape(TrajL, size(TrajL,1), []) - MU).^2, 2));
	binAW(i,:) = iBinHit(dA, yA, 5);
	binLW(i,:) = iBinHit(dL, yL, 5);
	if strcmp(m, 'yqn2200'), ExT = struct('PA', TrajA, 'yA', yA); end

	fprintf('%-9s AUC_pre %.3f | AUC_cue %.3f | dAll %+.3f (p=%.2f) | quiet n=%d hit=%.2f AUC_cue %.3f dQ %+.3f (p=%.2f)\n', ...
		m, AUC_P(i), AUC_C(i), dAll(i), pAll(i), nQ(i), hitQ(i), AUC_Cq(i), dQ(i), pQ(i));
end

ok = isfinite(AUC_P);
fprintf('\n=== 均值 (%d mice) ===\n', nnz(ok));
fprintf('cue 前 %.3f | 整段 cue %.3f | cue+前 %.3f | dAUC %+.3f\n', ...
	mean(AUC_P(ok)), mean(AUC_C(ok)), mean(AUC_PC(ok)), mean(dAll(ok)));
fprintf('安静 trial：cue 前 %.3f | cue 0-0.8 %.3f | cue+前 %.3f | dAUC %+.3f\n', ...
	mean(AUC_Pq(ok),'omitnan'), mean(AUC_Cq(ok),'omitnan'), mean(AUC_PCq(ok),'omitnan'), mean(dQ(ok),'omitnan'));

%% ---------- 出图 ----------
f = figure('Color','w','Name','Delay: state and cue contributions');
f.Units = 'centimeters'; f.Position(3:4) = [26, 7.4];

axA = axes(f,'Position',[0.040 0.150 0.165 0.620]);
if ~isempty(ExT), iDrawTraj(axA, ExT, TransferLearning.TransferColor, [0.5 0.5 0.5]); end
title(axA,'Example mouse: cue-evoked trajectories','FontWeight','normal','FontSize',7.5);

axB = axes(f,'Position',[0.255 0.150 0.190 0.620]); hold(axB,'on');
V = [AUC_P(ok) AUC_C(ok) AUC_Cq(ok)];
for i = 1:size(V,1)
	xv = [1 2 3]; yv = V(i,:);
	plot(axB, xv(isfinite(yv)), yv(isfinite(yv)), '-', 'Color',[0.65 0.65 0.65], 'LineWidth',0.6);
end
for c = 1:3
	v = V(:,c); v = v(isfinite(v));
	plot(axB, c+0.07*(rand(numel(v),1)-0.5), v, 'o', 'MarkerSize',5, ...
		'MarkerFaceColor', TransferLearning.TransferColor, 'MarkerEdgeColor','none');
	plot(axB, [c-0.22 c+0.22], mean(v)*[1 1], '-', 'Color',[0.1 0.1 0.1], 'LineWidth',1.6);
end
plot(axB,[0.5 3.5],[0.5 0.5],':','Color',[0.5 0.5 0.5]);
xlim(axB,[0.5 3.5]); ylim(axB,[0.4 0.85]);
xticks(axB,1:3);
xticklabels(axB,{'pre-cue','cue (all)','cue (quiet)'});
set(axB,'XTickLabelRotation',0,'FontSize',7);
ylabel(axB,'AUC (hit vs miss)');
title(axB,sprintf('Decoding (n = %d mice)', nnz(ok)),'FontWeight','normal','FontSize',7.5);
box(axB,'off');

axC = axes(f,'Position',[0.520 0.150 0.150 0.620]); hold(axC,'on');
plot(axC,[0.4 2.6],[0 0],':','Color',[0.5 0.5 0.5]);
pairs = {dAll, pAll; dQ, pQ};
for c = 1:2
	for k = 1:nnz(ok)
		i = find(ok); i = i(k);
		pcol = [0.55 0.55 0.55];
		if pairs{c,2}(i) < 0.05, pcol = TransferLearning.TransferColor; end
		bar(axC, c + 0.18*(k - (nnz(ok)+1)/2)/nnz(ok), pairs{c,1}(i), 0.13, ...
			'FaceColor', pcol, 'EdgeColor','none');
	end
end
xlim(axC,[0.4 2.6]); 
allo = [dAll(ok); dQ(ok)]; allo = allo(isfinite(allo));
ylim(axC,[min(-0.03,min(allo)*1.25), max(0.12, max(allo)*1.25)]);
xticks(axC,1:2); xticklabels(axC,{'all trials','quiet'});
set(axC,'FontSize',7,'XTickLabelRotation',0);
plot(axC,1,mean(dAll(ok)),'_','Color',[0.1 0.1 0.1],'MarkerSize',12,'LineWidth',1.6);
plot(axC,2,mean(dQ(ok),'omitnan'),'_','Color',[0.1 0.1 0.1],'MarkerSize',12,'LineWidth',1.6);
ylabel(axC,'\DeltaAUC from adding cue period');
title(axC,'Cue-period increment','FontWeight','normal','FontSize',7.5);
box(axC,'off');

axD = axes(f,'Position',[0.740 0.150 0.200 0.620]); hold(axD,'on');
nB = 5;
mA = mean(binAW(ok,:),1,'omitnan'); sA = std(binAW(ok,:),0,1,'omitnan')/sqrt(nnz(ok));
mL = mean(binLW(ok,:),1,'omitnan'); sL = std(binLW(ok,:),0,1,'omitnan')/sqrt(nnz(ok));
errorbar(axD,1:nB,mA,sA,'-o','Color',TransferLearning.NaiveColor,'MarkerFaceColor',TransferLearning.NaiveColor,'MarkerSize',4,'LineWidth',0.9,'CapSize',2);
errorbar(axD,1:nB,mL,sL,'-o','Color',TransferLearning.TransferColor,'MarkerFaceColor',TransferLearning.TransferColor,'MarkerSize',4,'LineWidth',0.9,'CapSize',2);
xlim(axD,[0.6 nB+0.4]); ylim(axD,[0 1]);
xticks(axD,1:nB); xlabel(axD,'Distance to learned state (quintile)');
ylabel(axD,'Response probability');
set(axD,'FontSize',7);
title(axD,'AW vs LW (descriptive)','FontWeight','normal','FontSize',7.5);
legend(axD,{'AW','LW'},'Location','southwest','FontSize',7,'Box','off');
box(axD,'off');

annotation(f,'textbox',[0.02 0.930 0.95 0.055],'String', ...
	'Pre-stimulus state predicts responding; cue-period activity adds little independent information once licking is excluded', ...
	'EdgeColor','none','FontSize',8.5,'FontWeight','bold');
annotation(f,'textbox',[0.02 0.875 0.95 0.045],'String', ...
	['Delayed paradigm. Features mean-centred within block; PCA fitted inside folds; 5-fold CV. ' ...
	'"quiet" = trials with no lick within 0.8 s of cue onset (few such trials exist beyond 0.8 s, hit rate 0.08).'], ...
	'EdgeColor','none','FontSize',6.3,'Color',[0.4 0.4 0.4]);

outDir = fileparts(mfilename('fullpath'));
savefig(f, fullfile(outDir,'Fig_DelayStateDecoding.fig'));
fprintf('Saved: %s\n', fullfile(outDir,'Fig_DelayStateDecoding.fig'));
assignin('base','DelayStateDecoding', table(mice(ok), AUC_P(ok), AUC_C(ok), AUC_Cq(ok), ...
	dAll(ok), pAll(ok), AUC_Pq(ok), dQ(ok), pQ(ok), nQ(ok), hitQ(ok), ...
	'VariableNames',{'Mouse','AUC_pre','AUC_cue','AUC_cue_quiet','dAUC_all','P_all', ...
	'AUC_pre_quiet','dAUC_quiet','P_quiet','N_quiet','Hit_quiet'}));

%% ------------------------------------------------------------------
function c = iCols(idx, nC)
c = [];
for k = idx(:)'
	c = [c, (k-1)*nC + (1:nC)]; %#ok<AGROW>
end
end

function X = iBaseX(X)
nb = max(1, round(0.7 / (6 / (size(X,3) - 1))));
b = mean(X(:,:,1:nb), 3);
X = X - repmat(b, 1, 1, size(X,3));
end

function [TrajA, TrajL] = iTraj(XA, XL)
nA = size(XA,1); nT = size(XA,3);
RA = reshape(permute(XA,[1 3 2]), nA*nT, []);
mu = mean(RA,1); [~,~,V] = svd(RA-mu,'econ'); W = V(:,1:min(3,size(V,2)));
TrajA = reshape((RA-mu)*W, nA, nT, []);
nL = size(XL,1);
RL = reshape(permute(XL,[1 3 2]), nL*nT, []);
TrajL = reshape((RL-mu)*W, nL, nT, []);
end

function b = iBinHit(d, y, nB)
b = nan(1,nB); ok = isfinite(d);
if nnz(ok) < nB*3, return; end
q = quantile(d(ok), linspace(0,1,nB+1));
for k = 1:nB
	r = ok & d >= q(k) & d <= q(k+1);
	if any(r), b(k) = mean(y(r)); end
end
end

function [X, y, g, onset] = iStack(DS, Tr, T, cells, wAll, tWater)
X = []; y = []; g = []; onset = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	Xi = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi), :), cells);
	if isempty(Xi), continue; end
	Xi = Xi(:,:,wAll);
	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel); tuSel = Tr.TrialUID(sel);
	okTag = cellfun(@(x) isa(x,'table'), tags);
	tags = tags(okTag); tuSel = tuSel(okTag);
	if numel(tags) < 10, continue; end
	[~,ord] = sort(tuSel); tags = tags(ord);
	[Lick,on,tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	resp = false(size(Lick,1),1);
	for k = 1:size(Lick,1)
		if any(Lick(k,:) & tt >= tWater), resp(k) = true; end
	end
	n = min(size(Xi,1), numel(resp));
	if n < 10, continue; end
	X = cat(1,X,Xi(1:n,:,:)); %#ok<AGROW>
	y = [y; double(resp(1:n))]; %#ok<AGROW>
	g = [g; repmat(bi,n,1)]; %#ok<AGROW>
	onset = [onset; on(1:n)]; %#ok<AGROW>
end
end

function F = iFlat(X, g)
F = reshape(permute(X,[1 3 2]), size(X,1), []);
for bi = unique(g)'
	r = g == bi; F(r,:) = F(r,:) - mean(F(r,:),1);
end
end

function auc = iCV(F, y, nPC)
n = size(F,1);
if n < 40 || numel(unique(y)) < 2, auc = NaN; return; end
cv = cvpartition(n,'KFold',5); sc = nan(n,1);
for f = 1:cv.NumTestSets
	trn = training(cv,f); tst = test(cv,f);
	mu = mean(F(trn,:),1); [~,~,V] = svd(F(trn,:)-mu,'econ');
	k = min(nPC, size(V,2)); W = V(:,1:k);
	Zt = [ones(sum(trn),1), (F(trn,:)-mu)*W];
	Ze = [ones(sum(tst),1), (F(tst,:)-mu)*W];
	b = (Zt'*Zt + eye(k+1)) \ (Zt'*y(trn));
	sc(tst) = Ze*b;
end
[~,~,~,auc] = perfcurve(y, sc, 1);
end

function iDrawTraj(ax, E, colHit, colMiss)
hold(ax,'on');
lims = prctile(reshape(E.PA,[],3), [10 90], 1);
for pass = 1:2
	if pass == 1, col = colHit; ls='-'; tag='hit'; else, col = colMiss; ls='--'; tag='miss'; end
	sel = E.yA == (pass-1);
	if ~any(sel), continue; end
	Q = E.PA(sel,:,:); n = size(Q,1);
	mT = reshape(mean(Q,1), [], 3);
	plot(ax, mT(:,1), mT(:,2), ls, 'Color', col, 'LineWidth', 2.0);
	plot(ax, mT(1,1), mT(1,2), '.', 'Color',[0.1 0.1 0.1],'MarkerSize',8);
	text(ax, 0.04, 0.94 - 0.09*(pass-1), sprintf('%s (n=%d)',tag,n), 'Units','normalized', ...
		'FontSize',7,'Color',col,'HorizontalAlignment','left','VerticalAlignment','top');
end
pad = 0.1*diff(lims,1,1);
xlim(ax, lims(:,1)' + [-pad(1) pad(1)]);
ylim(ax, lims(:,2)' + [-pad(2) pad(2)]);
xlabel(ax,'PC1'); ylabel(ax,'PC2'); box(ax,'off');
end
