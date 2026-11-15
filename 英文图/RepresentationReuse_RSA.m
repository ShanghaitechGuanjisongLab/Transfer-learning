% Fig5 补充：**交叉验证 RSA —— 跨阶段"时间对应性"**
%
% 为什么需要：现有几何类指标（Procrustes d / 能量比 / 圆度）全部依赖 PC 基
% （基敏感性检验已显示 d 的显著性会随基变化）。RSA 是唯一同时满足
% 「不依赖降维、不假设线性模板、直接比较表征几何」的指标。
%
% ⚠ 做法选择（踩过的坑）：直接比较两个阶段的**时间 RDM**（1−corr(模式_i, 模式_j)）并把 |Δt| 偏掉，
%   得到的相关在 ALB/V7、四个阶段对上全部落在 0.89–0.96，无法区分任何东西 ——
%   因为 RDM 的方差主要来自"响应包络（起落）"，而包络在各阶段/各队列几乎一样。
%   ⇒ 改用**跨阶段时间对应矩阵的对角优势**，它直接问"学会的 t 时刻是否对应迁移的 t 时刻"。
%
% 指标：
%   C[i,j] = corr( P_A(bin i), P_B(bin j) )        （在共有细胞上，逐鼠算）
%   peakness = mean(diag C) − mean( |i−j| ≥ 2 的 C )
%     大  = 两个阶段轨迹按时间对齐 ⇒ 同一段流形
%     ≈0 = 没有时间对应关系
%   选择性指数 = peakness(Learned→Transfer) − peakness(Learned→Naive)
%     >0 = 迁移期轨迹**更像学会的**而不像 naive 的（"复用"的几何定义）
%
% 数据：tempdir/PCAstage_G_MOp2-3.mat（0–8 s，每细胞 10 条超鼠线）；无需重新取数。
% 输出：RepresentationReuse_RSA.csv

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nBin = 8; nPerm = 200; rng(20261113, 'twister');
cacheFile = fullfile(tempdir, 'PCAstage_G_MOp2-3.mat');
assert(exist(cacheFile, 'file') == 2, 'RSA:NoCache', '缺 %s', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));
cohorts = ["ALB", "V7"];
stageNames = ["Naive", "Learned", "Transfer", "Final"];
pairs = [2 3; 2 4; 2 1; 3 4];
pairLab = stageNames(pairs(:, 1)) + "→" + stageNames(pairs(:, 2));
RES = struct();
Rows = {};

for k = 1:2
	iDS = find(dsNames == cohorts(k), 1);
	common = G{iDS, 1}.CellUID;
	for iS = 2:4, common = intersect(common, G{iDS, iS}.CellUID); end
	common = sort(unique(common));

	% ---- 逐鼠、逐 bin 的群体模式：PM{iS}{mouse} = cells_m × nBin ----
	PM = cell(1, 4); uM = [];
	for iS = 1:4
		[ok, loc] = ismember(common, G{iDS, iS}.CellUID);
		assert(all(ok));
		X = double(G{iDS, iS}.NTATS.Data(loc, :, :));   % cells × 65 × 10
		nT = size(X, 2);
		ed = round(linspace(0, nT, nBin + 1));
		mo = string(G{iDS, iS}.Mouse); mo = mo(loc); uM = unique(mo);
		PM{iS} = cell(numel(uM), 1);
		for i = 1:numel(uM)
			sel = (mo == uM(i));
			Bi = nan(sum(sel), nBin);
			for b = 1:nBin
				Bi(:, b) = mean(mean(X(sel, (ed(b) + 1):ed(b + 1), :), 3, 'omitnan'), 2, 'omitnan');
			end
			PM{iS}{i} = Bi;
		end
	end
	nM = numel(uM);
	fprintf('\n==== %s（%d 只鼠，%d 个 1 s time bin，0–8 s）====\n', cohorts(k), nM, nBin);

	% ---- 逐鼠 peakness + 置换零分布 ----
	Pk = nan(nM, size(pairs, 1));
	NullM = nan(nM, size(pairs, 1));
	for i = 1:nM
		for p = 1:size(pairs, 1)
			A = PM{pairs(p, 1)}{i}; Bm = PM{pairs(p, 2)}{i};
			Cm = iCMat(A, Bm);
			Pk(i, p) = iPeakFromC(Cm);
			nv = nan(nPerm, 1);
			for q = 1:nPerm
				nv(q) = iPeakFromC(Cm(:, randperm(nBin)));
			end
			NullM(i, p) = mean(nv, 'omitnan');
		end
	end
	for p = 1:size(pairs, 1)
		v = Pk(:, p); v = v(isfinite(v));
		nm = mean(NullM(:, p), 'omitnan');
		fprintf('  %-18s peakness = %+.3f ± %.3f   (置换 null %+.3f)  signrank p=%.4g  逐鼠 %s\n', ...
			pairLab(p), mean(v), std(v) / sqrt(numel(v)), nm, signrank(v, 0), strjoin(compose('%+.2f', v'), ' '));
		Rows(end+1, :) = {cohorts(k), pairLab(p), mean(v), std(v) / sqrt(numel(v)), nm, signrank(v, 0)}; %#ok<SAGROW>
	end

	% ---- 选择性指数：L→T 减 L→N（逐鼠配对）----
	iLT = find(pairs(:, 1) == 2 & pairs(:, 2) == 3, 1);
	iLN = find(pairs(:, 1) == 2 & pairs(:, 2) == 1, 1);
	sel = Pk(:, iLT) - Pk(:, iLN);
	sel = sel(isfinite(sel));
	fprintf('  选择性 (L→T) − (L→N) = %+.3f ± %.3f  signrank p=%.4g\n', ...
		mean(sel), std(sel) / sqrt(numel(sel)), signrank(sel, 0));
	Rows(end+1, :) = {cohorts(k), 'Selectivity_LT_minus_LN', mean(sel), std(sel) / sqrt(numel(sel)), NaN, signrank(sel, 0)}; %#ok<SAGROW>
	RES.(cohorts(k)) = struct('Pk', Pk, 'sel', sel);
end

% ---- 组间对比 ----
fprintf('\n==== 组间对比（V7 vs ALB，rank-sum）====\n');
iLT = find(pairs(:, 1) == 2 & pairs(:, 2) == 3, 1);
iLN = find(pairs(:, 1) == 2 & pairs(:, 2) == 1, 1);
for p = [iLT, iLN]
	a = RES.ALB.Pk(:, p); a = a(isfinite(a));
	b = RES.V7.Pk(:, p);  b = b(isfinite(b));
	fprintf('  %-18s ALB %+.3f vs V7 %+.3f   p=%.4g\n', pairLab(p), mean(a), mean(b), ranksum(a, b));
end
pvS = ranksum(RES.ALB.sel, RES.V7.sel);
fprintf('  选择性指数        ALB %+.3f vs V7 %+.3f   p=%.4g\n', ...
	mean(RES.ALB.sel), mean(RES.V7.sel), pvS);
Rows(end+1, :) = {"ALB_vs_V7", "Selectivity_LT_minus_LN", mean(RES.ALB.sel), NaN, mean(RES.V7.sel), pvS};

Tab = cell2table(Rows, 'VariableNames', ["Cohort", "Metric", "Value", "SEM", "Null_or_V7", "p"]);
writetable(Tab, fullfile(thisDir, 'RepresentationReuse_RSA.csv'));
fprintf('\nWrote: %s\n', fullfile(thisDir, 'RepresentationReuse_RSA.csv'));

%% ========== local ==========
function C = iCMat(A, B)
% A,B: cells × nBin → C(i,j) = corr(A(:,i), B(:,j))
n = size(A, 2); C = nan(n);
for i = 1:n
	for j = 1:n
		a = A(:, i); b = B(:, j);
		ok = isfinite(a) & isfinite(b);
		a = a(ok); b = b(ok);
		a = a - mean(a); b = b - mean(b);
		sa = norm(a); sb = norm(b);
		if sa == 0 || sb == 0, continue; end
		C(i, j) = (a' * b) / (sa * sb);
	end
end
end

function pk = iPeakFromC(C)
n = size(C, 1);
dg = mean(diag(C), 'omitnan');
m = abs(bsxfun(@minus, 1:n, (1:n)')) >= 2;
pk = dg - mean(C(m), 'omitnan');
end
