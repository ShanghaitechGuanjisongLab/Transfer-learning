% 线索窗口长度扫描：延长 cue 窗口是否带来更多信息？
%
% 对每个候选窗口 W，报告
%   AUC(W)        只用 W 的解码（声水 block 内 5 折交叉验证）
%   AUC(pre)      只用 cue 前窗口（-1.0 ~ -0.05 s）
%   AUC(pre+W)    两者合并
%   dAUC          合并 - 仅 pre（"W 带来的增量"）
% 并对若干窗口做"安静 trial"版本（剔除 cue 后 0.6 s 内已开始舔水的 trial），
% 以区分"线索诱发"与"预期性舔水"。

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
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse);
xs = linspace(-3, 3, 48)';

wins = [0 0.3; 0 0.5; 0 0.8; 0 1.0; 0.1 0.6];
mice = unique(C.Mouse);

res = nan(numel(mice), size(wins,1), 4);   % [AUC_W, AUC_pre, AUC_preW, dAUC]
resQ = nan(numel(mice), size(wins,1), 3);  % 安静 trial: [AUC_W, AUC_preW, dAUC]
nQ = nan(numel(mice), size(wins,1));
hitQ = nan(numel(mice), size(wins,1));
for i = 1:numel(mice)
	m = char(mice(i));
	T = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	if isempty(T), continue; end
	cells = unique(T.CellUID);
	[X, y, g, onset] = iStack(DS, Tr, T, cells, xs >= -1 & xs <= 1.0, tWater);
	if numel(y) < 100, continue; end
	xsW = xs(xs >= -1 & xs <= 1.0);

	F = iFlat(X, g);
	idxP = find(xsW < -0.05 & xsW >= -1.0);
	FP = F(:, iCols(idxP, numel(cells)));
	aucP = iCV(FP, y, nPC);
	for w = 1:size(wins,1)
		idxW = find(xsW >= wins(w,1) & xsW <= wins(w,2));
		FW = F(:, iCols(idxW, numel(cells)));
		aW = iCV(FW, y, nPC);
		aPW = iCV([FP, FW], y, nPC);
		res(i,w,:) = [aW, aucP, aPW, aPW - aucP];

		% 安静 trial：水窗口内没有舔水（首次舔水 > 结束时刻，或全程无舔）
		q = isnan(onset) | onset > wins(w,2);
		nQ(i,w) = nnz(q);
		if nnz(q) > 60 && numel(unique(y(q))) == 2
			hitQ(i,w) = mean(y(q));
			aWq = iCV(FW(q,:), y(q), nPC);
			aPWq = iCV([FP(q,:), FW(q,:)], y(q), nPC);
			aPq = iCV(FP(q,:), y(q), nPC);
			resQ(i,w,:) = [aWq, aPWq, aPWq - aPq];
		end
	end
	fprintf('%-9s ', m);
	for w = 1:size(wins,1), fprintf('[%.2f %.2f] %.3f/%.3f  ', wins(w,1), wins(w,2), res(i,w,1), res(i,w,4)); end
	fprintf('\n');
end

fprintf('\n=== 均值（n = %d mice）===\n', numel(mice));
fprintf('%-12s %-9s %-9s %-10s %-9s\n','window','AUC_W','AUC_pre','AUC_pre+W','dAUC');
for w = 1:size(wins,1)
	fprintf('[%.2f, %.2f]   %-9.3f %-9.3f %-10.3f %+.3f\n', wins(w,1), wins(w,2), ...
		mean(res(:,w,1),'omitnan'), mean(res(:,w,2),'omitnan'), ...
		mean(res(:,w,3),'omitnan'), mean(res(:,w,4),'omitnan'));
end
assignin('base','DelayWindowSweep', struct('Wins', wins, 'Res', res, 'Mice', mice, ...
	'ResQ', resQ, 'NQ', nQ, 'HitQ', hitQ));

fprintf('\n=== 安静 trial（窗口内无舔水）===\n');
fprintf('%-12s %-5s %-9s %-10s %-9s %-7s\n','window','n','AUC_W_q','AUC_preW_q','dAUC_q','hit_q');
for w = 1:size(wins,1)
	fprintf('[%.2f, %.2f]   %-5.0f %-9.3f %-10.3f %+.3f   %-.2f\n', wins(w,1), wins(w,2), ...
		mean(nQ(:,w),'omitnan'), mean(resQ(:,w,1),'omitnan'), mean(resQ(:,w,2),'omitnan'), ...
		mean(resQ(:,w,3),'omitnan'), mean(hitQ(:,w),'omitnan'));
end

%% ------------------------------------------------------------------
function c = iCols(idx, nC)
c = [];
for k = idx(:)'
	c = [c, (k-1)*nC + (1:nC)]; %#ok<AGROW>
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
