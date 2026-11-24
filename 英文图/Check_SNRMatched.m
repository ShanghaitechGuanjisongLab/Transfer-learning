% Check_SNRMatched.m
% 严格性检查：Learned 的子空间自稳定高于 Naive，是否只是「信噪比更高」造成的？
%
% 做法：给 Learned 阶段注入高斯白噪声，逐步加大直到其跨试次可重复性（rel）降到
%       与同一只鼠的 Naive 相同，然后在「SNR 匹配」的条件下重新计算子空间自稳定。
%
%   rel        : 10 条超鼠线随机分 5+5，各取时间平均 → 跨细胞相关（50 次平均，Spearman-Brown）
%   自稳定      : 同阶段内 5 vs 5 条线各估 k 维子空间 → 主角度 overlap（50 次平均）
%
% 输出：Check_SNRMatched_<Layer>.csv
%   Naive 与 Learned(匹配后) 的自稳定配对比较 —— 若 Learned 仍更高，则不是 SNR 假象。
%
% 口径：MOp2/3，0–8 s 65 帧，k=3，逐鼠（ALB n=10，V7 n=6）

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

if ~exist('LayerTag', 'var'), LayerTag = "MOp2-3"; end
if ~exist('kSub', 'var'),     kSub = 3; end
nSplit = 50;
rng(20261119, 'twister');

cacheFile = fullfile(tempdir, 'PCAstage_G_' + string(LayerTag) + '.mat');
assert(exist(cacheFile, 'file') == 2, 'SNR:NoCache', '缺 %s', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));

cohorts = ["ALB", "V7"];
Rows = {};
for k = 1:2
	iDS = find(dsNames == cohorts(k), 1);
	nL = size(G{iDS, 1}.NTATS.Data, 3);
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
	fprintf('%-9s %7s %7s %8s %8s %8s %7s\n', '鼠', 'relN', 'relL', '自稳N', '自稳L', '自稳L*', 'sigma');

	for im = 1:numel(mice)
		rm = MO{1} == mice(im);
		XN = X{1}(rm, :, :); XL = X{2}(rm, :, :);
		if size(XN, 1) < 10, continue; end

		relN = iRel(XN, nSplit);
		selfN = iSelfOv(XN, kSub, nSplit);
		relL = iRel(XL, nSplit);
		selfL = iSelfOv(XL, kSub, nSplit);

		% ---- 搜索噪声强度，使 rel(L + noise) ≈ relN ----
		sd = std(XL(:));
		sigGrid = linspace(0, 3 * sd, 25);
		relG = nan(size(sigGrid));
		for j = 1:numel(sigGrid)
			relG(j) = iRel(XL + sigGrid(j) * randn(size(XL)), nSplit / 2);
		end
		% 单调下降：取 rel 最接近 relN 的 sigma（线性插值）
		[~, jBest] = min(abs(relG - relN));
		sig = sigGrid(jBest);
		selfLm = iSelfOv(XL + sig * randn(size(XL)), kSub, nSplit);
		relLm = iRel(XL + sig * randn(size(XL)), nSplit);

prN = iPR(mean(XN,3,'omitnan')); prL = iPR(mean(XL,3,'omitnan'));
prLm = iPR(mean(XL + sig*randn(size(XL)),3,'omitnan'));
Rows(end+1, :) = {cohorts(k), mice(im), relN, relL, selfN, selfL, relLm, selfLm, sig/sd, prN, prL, prLm};
		fprintf('%-9s %7.3f %7.3f %8.3f %8.3f %8.3f %7.2f\n', ...
			string(mice(im)), relN, relL, selfN, selfL, selfLm, sig / sd);
	end
end

T = cell2table(Rows, 'VariableNames', ...
	["Cohort", "Mouse", "rel_Naive", "rel_Learned", "selfOv_Naive", "selfOv_Learned", ...
	"rel_LearnedMatched", "selfOv_LearnedMatched", "noiseSigmaRel", "PR_Naive", "PR_Learned", "PR_LearnedMatched"]);
csvPath = fullfile(thisDir, "Check_SNRMatched_" + replace(string(LayerTag), "/", "-") + ".csv");
writetable(T, csvPath);
fprintf('\nWrote: %s  (%d 行)\n', csvPath, height(T));

%% ================= 检验 =================
fprintf('\n=== 自稳定：Naive vs Learned（原始与 SNR 匹配后）===\n');
for c = cohorts
	m = T.Cohort == c;
	if sum(m) < 4, continue; end
	p0 = signrank(T.selfOv_Naive(m), T.selfOv_Learned(m));
	p1 = signrank(T.selfOv_Naive(m), T.selfOv_LearnedMatched(m));
	fprintf('%-4s 原始  %.3f → %.3f  p=%.4g (n=%d)\n', c, ...
		median(T.selfOv_Naive(m)), median(T.selfOv_Learned(m)), p0, sum(m));
	pr0 = signrank(T.PR_Naive(m), T.PR_Learned(m));
	pr1 = signrank(T.PR_Naive(m), T.PR_LearnedMatched(m));
	fprintf('     PR 原始  %.2f → %.2f  p=%.4g\n', median(T.PR_Naive(m)), median(T.PR_Learned(m)), pr0);
	fprintf('     PR SNR匹配 %.2f → %.2f  p=%.4g\n', median(T.PR_Naive(m)), median(T.PR_LearnedMatched(m)), pr1);
	fprintf('     SNR匹配 %.3f → %.3f  p=%.4g   [rel 已被拉平: %.3f vs %.3f]\n', ...
		median(T.selfOv_Naive(m)), median(T.selfOv_LearnedMatched(m)), p1, ...
		median(T.rel_Naive(m)), median(T.rel_LearnedMatched(m)));
end

%% ================= 局部函数 =================
function r = iRel(X, nSplit)
% 10 条线随机分 5+5 → 时间平均 → 跨细胞相关 → Spearman-Brown
M = squeeze(mean(X, 2, 'omitnan'));   % cells × nLine
nl = size(M, 2);
if nl < 4, r = NaN; return; end
h = floor(nl / 2);
rr = nan(nSplit, 1);
for t = 1:nSplit
	p = randperm(nl);
	a = mean(M(:, p(1:h)), 2, 'omitnan');
	b = mean(M(:, p(h+1:end)), 2, 'omitnan');
	rr(t) = iCorr(a, b);
end
r0 = mean(rr, 'omitnan');
if ~isfinite(r0) || r0 <= -1, r = NaN; else, r = 2 * r0 / (1 + r0); end
end

function ov = iSelfOv(X, k, nSplit)
% 同阶段 5 vs 5 线各估子空间 → overlap
nl = size(X, 3);
if nl < 4, ov = NaN; return; end
h = floor(nl / 2);
vv = nan(nSplit, 1);
for t = 1:nSplit
	p = randperm(nl);
	v1 = iSub(iTop(mean(X(:, :, p(1:h)), 3, 'omitnan'), k), iTop(mean(X(:, :, p(h+1:end)), 3, 'omitnan'), k));
	vv(t) = v1;
end
ov = mean(vv, 'omitnan');
end

function U = iTop(X, k)
[U, ~, ~] = svd(X, 'econ');
U = U(:, 1:min(k, size(U, 2)));
end

function ov = iSub(U1, U2)
k = min(size(U1, 2), size(U2, 2));
[~, S, ~] = svd(U1(:, 1:k)' * U2(:, 1:k), 'econ');
c = min(max(diag(S), -1), 1);
ov = mean(c .^ 2);
end

function r = iCorr(a, b)
ok = isfinite(a) & isfinite(b);
if sum(ok) < 10, r = NaN; return; end
a = a(ok); b = b(ok);
a = a - mean(a); b = b - mean(b);
sa = norm(a); sb = norm(b);
if sa == 0 || sb == 0, r = NaN; return; end
r = (a' * b) / (sa * sb);
end


function pr = iPR(X)
X = X - mean(X, 2, 'omitnan');
s = svd(X, 'econ'); l = s .^ 2;
if sum(l) == 0, pr = NaN; return; end
l = l / sum(l); pr = 1 / sum(l .^ 2);
end
