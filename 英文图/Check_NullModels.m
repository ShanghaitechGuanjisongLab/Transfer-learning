% Check_NullModels.m
% 置换零模型：论点① 的「低维/平滑结构」与论点② 的「跨阶段一致性」
% 是否显著超出随机？—— 时间打乱（per-cell independent time shuffle）。
%
% 三个检验：
%   1) 维度：PR_real vs PR_perm（每细胞独立打乱时间后，跨细胞协方差被破坏）
%      统计量 dPR = mean(PR_perm) − PR_real（越大 = 结构越低维于随机）
%   2) 平滑：smooth_real vs smooth_perm（白噪声 smooth ≈ 4）
%      统计量 dSmooth = mean(smooth_perm) − smooth_real
%   3) 跨阶段一致性：overlap(A,B)_real vs overlap(A_perm, B)
%      只打乱 A 的时间，B 保持真实 ⇒ 零分布 = 「A 的时间结构完全无关时」的一致性
%
% 输出：Check_NullModels_<Layer>.csv
%       每行 = 队列 × 鼠 × 检验 × (指标值、零均值、z、p)
%
% 口径：0–8 s 全 65 帧（与 Fig5 (a)–(d)、(e) 一致）；k=3；nPerm=200。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

if ~exist('LayerTag', 'var'), LayerTag = "MOp2-3"; end
if ~exist('kSub', 'var'),     kSub = 3; end
nPerm = 200;
rng(20261118, 'twister');

cacheFile = fullfile(tempdir, 'PCAstage_G_' + string(LayerTag) + '.mat');
assert(exist(cacheFile, 'file') == 2, 'Null:NoCache', '缺 %s', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));

cohorts   = ["ALB", "V7"];
stageName = ["Naive", "Learned", "Transfer", "Final"];
pairs     = [1 2; 2 3; 1 3; 3 4];
pairName  = ["N→L", "L→T", "N→T", "T→F"];

Rows = {};
for k = 1:2
	iDS = find(dsNames == cohorts(k), 1);
	common = G{iDS, 1}.CellUID;
	for iS = 2:4, common = intersect(common, G{iDS, iS}.CellUID); end
	common = sort(unique(common));
	X = cell(1, 4); MO = cell(1, 4);
	for iS = 1:4
		[~, loc] = ismember(common, G{iDS, iS}.CellUID);
		X{iS} = double(G{iDS, iS}.NTATS.Data(loc, :, :));
		MO{iS} = string(G{iDS, iS}.Mouse(loc));
	end
	mice = unique(MO{1});
	fprintf('\n=== %s：%d 细胞 / %d 鼠 ===\n', cohorts(k), numel(common), numel(mice));
	fprintf('%-9s %-5s %9s %9s %7s %7s | %9s %9s %7s\n', ...
		'鼠', '检验', 'real', 'null', 'z', 'p', '', '', '');

	for im = 1:numel(mice)
		rm = MO{1} == mice(im);
		Xm = cell(1, 4);
		for iS = 1:4, Xm{iS} = mean(X{iS}(rm, :, :), 3, 'omitnan'); end

		% ---------- 1) 维度 + 2) 平滑：逐阶段 ----------
		for iS = 1:4
			V = Xm{iS};
			prReal = iPR(V); smReal = iSmooth(V);
			prN = nan(nPerm, 1); smN = nan(nPerm, 1);
			for t = 1:nPerm
				P = iShufTime(V);
				prN(t) = iPR(P); smN(t) = iSmooth(P);
			end
			dPR = mean(prN) - prReal;  dSM = mean(smN) - smReal;
			zPR = -dPR / std(prN);     zSM = dSM / std(smN);
			pPR = (1 + sum(prN <= prReal)) / (nPerm + 1);
			pSM = (1 + sum(smN >= smReal)) / (nPerm + 1);
			Rows(end+1, :) = {cohorts(k), mice(im), "PR/" + stageName(iS), ...
				prReal, mean(prN), zPR, pPR, dPR}; %#ok<SAGROW>
			Rows(end+1, :) = {cohorts(k), mice(im), "smooth/" + stageName(iS), ...
				smReal, mean(smN), zSM, pSM, dSM}; %#ok<SAGROW>
		end

		% ---------- 3) 跨阶段一致性：只打乱 A 的时间 ----------
		for ip = 1:size(pairs, 1)
			iA = pairs(ip, 1); iB = pairs(ip, 2);
			ovReal = iSubAngle(iTopSub(Xm{iA}, kSub), iTopSub(Xm{iB}, kSub));
			ovN = nan(nPerm, 1);
			for t = 1:nPerm
				ovN(t) = iSubAngle(iTopSub(iShufTime(Xm{iA}), kSub), iTopSub(Xm{iB}, kSub));
			end
			dOV = ovReal - mean(ovN);
			zOV = dOV / std(ovN);
			pOV = (1 + sum(ovN >= ovReal)) / (nPerm + 1);
			Rows(end+1, :) = {cohorts(k), mice(im), "overlap/" + pairName(ip), ...
				ovReal, mean(ovN), zOV, pOV, dOV}; %#ok<SAGROW>
			fprintf('%-9s %-14s real %6.3f  null %6.3f  z %6.2f  p %.4f\n', ...
				string(mice(im)), "overlap/" + pairName(ip), ovReal, mean(ovN), zOV, pOV);
		end
	end
end

T = cell2table(Rows, 'VariableNames', ...
	["Cohort", "Mouse", "Test", "Real", "Null", "Z", "P", "Delta"]);
csvPath = fullfile(thisDir, "Check_NullModels_" + replace(string(LayerTag), "/", "-") + ".csv");
writetable(T, csvPath);
fprintf('\nWrote: %s  (%d 行)\n', csvPath, height(T));

%% ================= 汇总 =================
fprintf('\n=== 逐鼠 z 的跨鼠汇总（单侧 Wilcoxon）===\n');
tests = unique(T.Test, 'stable');
fprintf('%-22s %6s %8s %8s %10s\n', '检验', 'n', 'z中位', 'p(signrank)', '结论');
for c = cohorts
	for tt = tests'
		m = T.Cohort == c & T.Test == tt;
		z = T.Z(m); p = T.P(m);
		if numel(z) < 4, continue; end
		pz = signrank(z, 0, 'tail', 'right');
		dir = "↑"; if median(z) < 0, dir = "↓"; end
		fprintf('%-22s %6d %8.2f %10.4g   %s (median p_perm=%.4f)\n', ...
			c + "/" + tt, numel(z), median(z), pz, dir, median(p));
	end
end

%% ================= 局部函数 =================
function Y = iShufTime(X)
% 每个细胞独立打乱时间索引（cells × T 或 cells × T × nL）
[nc, nt, nl] = size(X);
Y = X;
for i = 1:nc
	p = randperm(nt);
	Y(i, :, :) = X(i, p, :);
end
end

function pr = iPR(X)
% participation ratio（去时间均值）
X = X - mean(X, 2, 'omitnan');
s = svd(X, 'econ');
l = s .^ 2;
if sum(l) == 0, pr = NaN; return; end
l = l / sum(l);
pr = 1 / sum(l .^ 2);
end

function r = iSmooth(X)
% 二阶差分能量 / 一阶差分能量（越小越平滑；白噪声 ≈ 4）
X = X - mean(X, 2, 'omitnan');
e1 = norm(diff(X, 1, 2), 'fro') ^ 2;
e2 = norm(diff(X, 2, 2), 'fro') ^ 2;
if e1 == 0, r = NaN; else, r = e2 / e1; end
end

function U = iTopSub(X, k)
[U, ~, ~] = svd(X, 'econ');
U = U(:, 1:min(k, size(U, 2)));
end

function ov = iSubAngle(U1, U2)
k = min(size(U1, 2), size(U2, 2));
[~, S, ~] = svd(U1(:, 1:k)' * U2(:, 1:k), 'econ');
c = min(max(diag(S), -1), 1);
ov = mean(c .^ 2);
end
