% 决策轴的同一性 + 特异性对照
%
% 目标：从"表征重叠"升级为"同一套编码"
%   (1) 分别在 AW 与 LW 上独立估计"决策轴"（hit 均值 - miss 均值，细胞空间），
%       比较两者余弦相似度 cos(AW, LW)
%       上限 = 同条件内分半估计的余弦；下限 = 打乱标签后的余弦分布
%   (2) 特异性：AW 的响应模式与 LW 的重叠，是否大于与"未配对线索"
%       （AudioPreTrainCueOnly）的重叠；为避免 trial 数不等带来的偏倚，
%       三者统一随机抽取 20 个 trial 后计算，重复 200 次
%
% 特征：cue 后 0.1-0.6 s 的平均响应（已减 cue 前基线），窗口内时间平均 -> 细胞向量

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nPerm = 200;
nSplit = 100;
nSub = 20;

DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse);
mice = unique(C.Mouse);

fprintf('%-9s %-6s %-8s %-8s %-8s %-7s %-9s %-9s %-7s\n', ...
	'mouse', 'nCell', 'cos_AW_LW', 'ceil_AW', 'ceil_LW', 'p', 'r_AW-LW20', 'r_AW-Pre20', 'pSpec');
Rows = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	TP = TransferLearning.QueryZScoreNts(DS, m, 'AudioPreTrainCueOnly');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	[FA, yA] = iFeat(DS, Tr, TA, cells);
	[FL, yL] = iFeat(DS, Tr, TL, cells);
	[FP, yP] = iFeat(DS, Tr, TP, cells);
	if isempty(FA) || isempty(FL) || numel(unique(yA)) < 2 || numel(unique(yL)) < 2, continue; end
	if numel(FP) > 0
		badRow = any(~isfinite(FP), 2);
		FP(badRow, :) = [];
	else
		FP = [];
	end

	% ---- 决策轴 ----
	wA = mean(FA(yA == 1, :), 1) - mean(FA(yA == 0, :), 1);
	wL = mean(FL(yL == 1, :), 1) - mean(FL(yL == 0, :), 1);
	cosAL = iCos(wA, wL);

	% 上限：同条件分半
	cA = mean(arrayfun(@(k) iSplitCos(FA, yA), 1:nSplit), 'omitnan');
	cL = mean(arrayfun(@(k) iSplitCos(FL, yL), 1:nSplit), 'omitnan');

	% 下限：打乱 AW 标签
	rng(0); nul = nan(nPerm, 1);
	for t = 1:nPerm
		yp = yA(randperm(numel(yA)));
		if numel(unique(yp)) < 2, continue; end
		wp = mean(FA(yp == 1, :), 1) - mean(FA(yp == 0, :), 1);
		nul(t) = iCos(wp, wL);
	end
	p = mean(nul >= cosAL);

	% ---- 特异性：统一取 20 trial 比较模式相关 ----
	rAL = nan(nPerm, 1); rAP = nan(nPerm, 1);
	if size(FP, 1) >= nSub
		rng(1);
		for t = 1:nPerm
			ia = randperm(size(FA, 1), nSub);
			il = randperm(size(FL, 1), nSub);
			ip = randperm(size(FP, 1), nSub);
			pa = mean(FA(ia, :), 1)'; pl = mean(FL(il, :), 1)'; pp = mean(FP(ip, :), 1)';
			rAL(t) = corr(pa, pl);
			rAP(t) = corr(pa, pp);
		end
	end
	pSpec = NaN;
	try
		if ~isempty(rAL) && all(isfinite(rAL(:))) && all(isfinite(rAP(:))) && any(rAL ~= rAP)
			pSpec = signrank(rAL, rAP);
		end
	catch
		pSpec = NaN;
	end

	fprintf('%-9s %-6d %-8.3f %-8.3f %-8.3f %-7.3f %-9.3f %-9.3f %-7.3f\n', ...
		m, numel(cells), cosAL, cA, cL, p, mean(rAL, 'omitnan'), mean(rAP, 'omitnan'), pSpec);
	Rows = [Rows; table(string(m), numel(cells), cosAL, cA, cL, p, ...
		mean(rAL, 'omitnan'), mean(rAP, 'omitnan'), pSpec, ...
		'VariableNames', {'Mouse','NCells','Cos_AW_LW','Ceil_AW','Ceil_LW','P_cos', ...
		'R_AW_LW20','R_AW_Pre20','P_spec'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 ---\n');
fprintf('cos(AW, LW) = %.3f +- %.3f（同条件上限 %.3f / %.3f；打乱下限≈0）\n', ...
	mean(Rows.Cos_AW_LW), std(Rows.Cos_AW_LW)/sqrt(height(Rows)), mean(Rows.Ceil_AW), mean(Rows.Ceil_LW));
fprintf('cos 显著高于打乱的鼠数: %d/%d\n', nnz(Rows.P_cos < 0.05), height(Rows));
fprintf('特异性（各 20 trial）: r(AW,LW) = %.3f vs r(AW,PreTrain) = %.3f，差异显著鼠数 %d/%d\n', ...
	mean(Rows.R_AW_LW20), mean(Rows.R_AW_Pre20), nnz(Rows.P_spec < 0.05), height(Rows));
assignin('base', 'DelayAxisAlign', Rows);

%% ------------------------------------------------------------------
function [F, y] = iFeat(DS, Tr, T, cells)
F = []; y = [];
if isempty(T), return; end
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi), :), cells);
	if isempty(X), continue; end
	xs = linspace(-3, 3, size(X, 3))';
	iBase = xs >= -1.0 & xs < -0.3;
	iResp = xs >= 0.1 & xs <= 0.6;
	R = mean(X(:, :, iResp), 3) - mean(X(:, :, iBase), 3);   % trials x cells

	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel); tuSel = Tr.TrialUID(sel);
	okTag = cellfun(@(x) isa(x, 'table'), tags);
	tags = tags(okTag); tuSel = tuSel(okTag);
	if numel(tags) < 5, continue; end
	[~, ord] = sort(tuSel); tags = tags(ord);
	[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	lab = double(any(Lick & tt >= 1.4, 2));
	n = min(size(R, 1), numel(lab));
	F = [F; R(1:n, :)]; %#ok<AGROW>
	y = [y; lab(1:n)]; %#ok<AGROW>
end
end

function c = iCos(u, v)
u = u(:); v = v(:);
nu = norm(u); nv = norm(v);
if nu == 0 || nv == 0, c = NaN; else, c = (u' * v) / (nu * nv); end
end

function c = iSplitCos(F, y)
n = size(F, 1);
idx = randperm(n); h1 = idx(1:floor(n/2)); h2 = idx(floor(n/2)+1:end);
if numel(unique(y(h1))) < 2 || numel(unique(y(h2))) < 2, c = NaN; return; end
w1 = mean(F(h1(y(h1) == 1), :), 1) - mean(F(h1(y(h1) == 0), :), 1);
w2 = mean(F(h2(y(h2) == 1), :), 1) - mean(F(h2(y(h2) == 0), :), 1);
c = iCos(w1, w2);
end
