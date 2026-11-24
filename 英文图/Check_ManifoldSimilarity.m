% Check_ManifoldSimilarity.m
% 计算「流形 / 子空间相似性」的标准指标（只出数值 + CSV，不画图）。
%
% 动机：Fig5 (e)(f) 用的 split-half reliability（rel）只反映"群体响应模式在试次间可重复"，
%       不含任何几何信息，且是 SNR 的单调函数 —— 不能用来推断"流形稳定"。
%       本脚本给出真正可测的流形相似性指标。
%
% 数据：tempdir/PCAstage_G_<Layer>.mat（由 Check_StageToStageShape.m 生成）
%       G{iDS,iS}.NTATS.Data = cells × nOut(65, 0–8 s) × 10（超鼠线：每细胞把该阶段
%       全部回合按顺序均分成 10 组取平均 ⇒ 10 条相互独立的试次子集平均轨迹）
%       G{iDS,iS}.Mouse / .CellUID 给出每个细胞的归属鼠
%
% 指标（全部逐鼠计算，再做跨鼠统计）：
%   A. principal angles / subspace overlap
%      U = 前 k 个左奇异向量（cells × k）= 轨迹所张的 k 维子空间
%      cosθ_i = svd(U_A' U_B)；overlap = mean(cos²θ) ∈ [0,1]，1 = 同一子空间
%      噪声地板：同一阶段内 5 vs 5 条线分半（重复 nSplit 次）⇒ 该阶段子空间估计的不可约偏差
%   B. crossnobis 风格 RDM 相关
%      时间分箱（0.5 s/箱）→ 每箱跨线平均得模式 P(cells × nBin)
%      RDM = 1 − corr(P_i, P_j)  (Spearman)  —— 二阶同构（Kriegeskorte 2008 Step 4）
%      分半交叉：R_ij = 1 − ½[corr(P_i^1,P_j^2) + corr(P_i^2,P_j^1)]
%   C. Procrustes 残差（4 阶段合并 PCA 的公共 2D 基）
%      d_rot   : 允许旋转+镜像+缩放（procrustes 默认 Reflection='best'）
%      d_norot : Reflection=false（禁镜像，仍允许旋转），与 Fig5 命名一致
%   D. participation ratio（有效维度）
%      PR = (Σλ)²/Σλ²；PR_raw 用 X 的奇异值，PR_ctr 先去时间均值（只看"变化"占几维）
%   E. 拓扑（persistent homology）：需要 TDA 工具箱，脚本自动探测；缺失则跳过
%   F. 潜变量模型一致性（rSLDS）：需要 ssm 工具箱 + 逐条件拟合，本脚本不做（标注）
%
% 输出：Check_ManifoldSimilarity_<Layer>.csv
%      每行 = 队列 × 鼠 × 阶段对 × 指标
%
% 口径：MOp2/3；cue 后 0–8 s（65 帧，与 Fig5 a–d 一致）；z-score 已在缓存内完成。
%       k 默认 5；overlap 另报 k=3/10 供敏感性检查。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

if ~exist('LayerTag', 'var'), LayerTag = "MOp2-3"; end
if ~exist('kSub', 'var'),    kSub = 3; end
if ~exist('tWinSel', 'var'), tWinSel = [0, 1.5]; end    % 分析窗（秒，cue 后）
if ~exist('nCellCap','var'), nCellCap = 100; end    % 0 = 不做细胞数匹配
nRepCap = 10; nSplitCap = 30;
nSplit = 100;
rng(20261118, 'twister');

cacheFile = fullfile(tempdir, 'PCAstage_G_' + string(LayerTag) + '.mat');
assert(exist(cacheFile, 'file') == 2, 'ManifoldSim:NoCache', ...
	'缺 %s，请先跑 英文图/Check_StageToStageShape.m（LayerTag="%s"）', cacheFile, LayerTag);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));

cohorts   = ["ALB", "V7"];
stageName = ["Naive", "Learned", "Transfer", "Final"];
pairs     = [1 2; 2 3; 3 4; 1 3];          % N→L, L→T, T→F, N→T(负对照)
pairName  = ["N→L", "L→T", "T→F", "N→T"];

%% ================= 0) 探测可选工具箱 =================
hasTDA = exist('computePersistentHomology', 'file') == 2 || ...
	exist('ph_pdist', 'file') == 2 || exist('rips', 'file') == 2;
hasSSM = exist('ssm.SLDS', 'class') == 4 || exist('ssm', 'dir') == 7;
fprintf('可选工具箱：TDA(persistent homology)=%d, ssm(rSLDS)=%d\n', hasTDA, hasSSM);

%% ================= 1) 逐队列 × 逐鼠计算 =================
Rows = {};
for k = 1:2
	iDS = find(dsNames == cohorts(k), 1);
	assert(~isempty(iDS), 'ManifoldSim:NoCohort', '缓存里没有 %s', cohorts(k));

	% 四阶段共有细胞（跨阶段对齐），并按 Mouse 分配
	common = G{iDS, 1}.CellUID;
	for iS = 2:4, common = intersect(common, G{iDS, iS}.CellUID); end
	common = sort(unique(common));
	nOut = size(G{iDS, 1}.NTATS.Data, 2);
	nL   = size(G{iDS, 1}.NTATS.Data, 3);      % 10 条线
	tAll = linspace(0, 8, nOut);
	iT   = find(tAll >= tWinSel(1) & tAll <= tWinSel(2));
	fprintf('[窗 %.2f–%.2f s → %d 帧, k=%d]\n', tWinSel(1), tWinSel(2), numel(iT), kSub);
	X = cell(1, 4); MO = cell(1, 4); XF = cell(1, 4);
	for iS = 1:4
		[ok, loc] = ismember(common, G{iDS, iS}.CellUID);
		assert(all(ok), 'ManifoldSim:CellMismatch', 'Cell mismatch');
		XF{iS} = double(G{iDS, iS}.NTATS.Data(loc, :, :));      % 全程 65 帧（算维度用）
		X{iS}  = XF{iS}(:, iT, :);                              % 分析窗（算子空间用）
		MO{iS} = string(G{iDS, iS}.Mouse(loc));
	end

	% ---- 队列级公共 PC 基（4 阶段合并拟合，与 Fig5 a–d 同口径）----
	dataAll = cat(3, X{:});
	nOut = size(X{1}, 2);
	Tp = UniExp.LinearPca(MATLAB.DataTypes.NDTable(dataAll), 2, true);
	Sc  = double(Tp.Score.Data);                              % 2 × nOut × (4*nL)
	PCc = cell(1, 4);
	for iS = 1:4
		PCc{iS} = double(squeeze(mean(Sc(:, :, (iS - 1) * nL + (1:nL)), 3)))';   % nOut × 2
	end

	mice = unique(MO{1});
		fprintf('\n=== %s：%d 细胞 / %d 鼠 / %d 帧 / 随机基线 overlap≈%.4f ===\n', ...
			cohorts(k), numel(common), numel(mice), nOut, kSub / numel(common));
		fprintf('%-9s %-5s %7s %7s %8s %8s %7s %7s %7s %7s %7s %7s %6s %6s\n', ...
			'鼠', '对', 'θ̄(°)', 'θmax', 'overlap', 'noiseOv', 'ovRatio', 'AI_A→B', 'AI_B→A', 'RDMsp', 'd_rot', 'PR_ctr', 'ID_A', 'ID_B');
	for im = 1:numel(mice)
		rowMask = MO{1} == mice(im);
		for ip = 1:size(pairs, 1)
			iA = pairs(ip, 1); iB = pairs(ip, 2);
			XA = X{iA}(rowMask, :, :); XB = X{iB}(rowMask, :, :);
			if size(XA, 1) < 10, continue; end

			% ---------- A. 子空间主角度（nCellCap>0 时随机下采样到同一细胞数，重复平均）----------
			SA = iPairSub(XA, XB, kSub, nCellCap, nRepCap, nSplitCap);
			ov = SA.ov; cm = SA.cm; aiAB = SA.aiAB; aiBA = SA.aiBA;
			ovNoise = SA.ovNoise; selfA = SA.selfA; selfB = SA.selfB;

			% ---------- B. crossnobis 风格 RDM（分半交叉）----------
			nBin = 16;  edges = round(linspace(1, nOut + 1, nBin + 1));
			PA = iBinPattern(XA, edges); PB = iBinPattern(XB, edges);   % cells × nBin × 2(半)
			RA = iCrossRDM(PA); RB = iCrossRDM(PB);                     % nBin × nBin
			iu = triu(true(nBin), 1);
			rdmR = iSpearman(RA(iu), RB(iu));

			% ---------- C. Procrustes（公共 2D 基）----------
			tA = PCc{iA}(:, 1:2); tB = PCc{iB}(:, 1:2);
			dRot   = procrustes(tA, tB, 'Scaling', true);
			dNoRot = procrustes(tA, tB, 'Scaling', true, 'Reflection', false);

			% ---------- D. 有效维度 / 内在维度（全程 65 帧，去时间均值）----------
			XA0 = mean(XF{iA}(rowMask, :, :), 3, 'omitnan');
			XB0 = mean(XF{iB}(rowMask, :, :), 3, 'omitnan');
			prA = iPR(XA0, true); prB = iPR(XB0, true);
			idA = iTwoNN(XA0); idB = iTwoNN(XB0);
			smthA = iSmooth(XA0); smthB = iSmooth(XB0);   % 轨迹平滑度（二阶/一阶差分能量比）

			Rows(end+1, :) = {cohorts(k), mice(im), pairName(ip), sum(rowMask), ...
		size(XA, 1), kSub, SA.thMeanDeg, SA.thMaxDeg, ov, cm, ovNoise, ...
				ov / ovNoise, aiAB, aiBA, rdmR, dRot, dNoRot, prA, prB, idA, idB, selfA, selfB, ...
				smthA, smthB}; %#ok<SAGROW>
			fprintf('%-9s %-5s %7.1f %7.1f %8.3f %8.3f %7.2f %7.3f %7.3f %7.3f %7.3f %7.2f %7.2f %6.2f %6.2f %7.3f %7.3f %6.2f %6.2f\n', ...
			string(mice(im)), pairName(ip), SA.thMeanDeg, SA.thMaxDeg, ...
				ov, ovNoise, ov / ovNoise, aiAB, aiBA, rdmR, dRot, dNoRot, prB, idB, selfA, selfB, smthA, smthB);
		end
	end

	% ---- k 敏感性（队列级，仅报告）----
	ovByK = nan(1, 3); kk = [3 5 10];
	for q = 1:3
		UAq = iTopSub(mean(X{2}, 3, 'omitnan'), kk(q));
		UBq = iTopSub(mean(X{3}, 3, 'omitnan'), kk(q));
		[~, ovByK(q)] = iSubAngle(UAq, UBq);
	end
	fprintf('%s 队列级 overlap(L→T) 对 k=[3 5 10] = [%.3f %.3f %.3f]\n', ...
		cohorts(k), ovByK);
end

T = cell2table(Rows, 'VariableNames', ...
	["Cohort", "Mouse", "Pair", "nMouseCells", "nCell", "k", ...
	"thetaMean_deg", "thetaMax_deg", "overlap", "meanCos", "noiseOverlap", "ovRatio", ...
	"AI_AB", "AI_BA", "RDM_spearman", "d_rot", "d_norot", "PR_A", "PR_B", "ID_A", "ID_B", ...
	"selfOvA", "selfOvB", "smoothA", "smoothB"]);
csvPath = fullfile(thisDir, "Check_ManifoldSimilarity_" + replace(string(LayerTag), "/", "-") + ...
	"_k" + string(kSub) + "_w" + string(round(tWinSel(2) * 1000)) + "ms.csv");
writetable(T, csvPath);
fprintf('\nWrote: %s  (%d 行)\n', csvPath, height(T));

%% ================= 2) 统计检验 =================
fprintf('\n=== 队列内：L→T 是否高于 N→T（配对，signrank）===\n');
metrics = ["overlap", "ovRatio", "AI_AB", "AI_BA", "RDM_spearman"];
for c = cohorts
	for mt = metrics
		a = T{T.Cohort == c & T.Pair == "L→T", mt};
		b = T{T.Cohort == c & T.Pair == "N→T", mt};
		n = min(numel(a), numel(b));
		if n < 4, continue; end
		p = signrank(a(1:n), b(1:n));
		fprintf('  %-4s %-13s L→T %.3f vs N→T %.3f  n=%d  p=%.4g\n', ...
			c, mt, median(a(1:n)), median(b(1:n)), n, p);
	end
end

fprintf('\n=== 有效维度（PR）/ 内在维度（twoNN）：阶段 B 逐鼠配对 ===\n');
for c = cohorts
	for pr = ["PR_B", "ID_B"]
		a = T{T.Cohort == c & T.Pair == "L→T", pr};   % B = Transfer
		b = T{T.Cohort == c & T.Pair == "N→L", pr};   % B = Learned
		n = min(numel(a), numel(b));
		if n < 4, continue; end
		fprintf('  %-4s %-5s Learned %.2f vs Transfer %.2f  n=%d  p=%.4g\n', ...
			c, pr, median(b(1:n)), median(a(1:n)), n, signrank(a(1:n), b(1:n)));
	end
end
for pr = ["PR_B", "ID_B"]
	a = T{T.Cohort == "ALB" & T.Pair == "L→T", pr};
	b = T{T.Cohort == "V7"  & T.Pair == "L→T", pr};
	fprintf('  Transfer 阶段 %-5s ALB %.2f vs V7 %.2f  p=%.4g（ranksum）\n', ...
		pr, median(a), median(b), ranksum(a, b));
end

fprintf('\n=== 纵向：单阶段自稳定性（同阶段 split-half 子空间 overlap）===\n');
fprintf('  同一行 N→L 内即 A=Naive / B=Learned 的配对\n');
for c = cohorts
	idx = T.Cohort == c & T.Pair == "N→L";
	fprintf('  %-4s 自稳定 ov：Naive %.3f → Learned %.3f  n=%d  p=%.4g\n', ...
		c, median(T.selfOvA(idx)), median(T.selfOvB(idx)), sum(idx), ...
		signrank(T.selfOvA(idx), T.selfOvB(idx)));
	fprintf('       PR：      Naive %.2f → Learned %.2f          p=%.4g\n', ...
		median(T.PR_A(idx)), median(T.PR_B(idx)), signrank(T.PR_A(idx), T.PR_B(idx)));
	fprintf('       twoNN：   Naive %.1f → Learned %.1f          p=%.4g\n', ...
		median(T.ID_A(idx)), median(T.ID_B(idx)), signrank(T.ID_A(idx), T.ID_B(idx)));
	fprintf('       平滑度：  Naive %.3f → Learned %.3f          p=%.4g\n', ...
		median(T.smoothA(idx)), median(T.smoothB(idx)), signrank(T.smoothA(idx), T.smoothB(idx)));
end

fprintf('\n=== 队列间：单阶段自稳定性（Learned）===\n');
a = T.selfOvB(T.Cohort == "ALB" & T.Pair == "N→L");
b = T.selfOvB(T.Cohort == "V7"  & T.Pair == "N→L");
fprintf('  ALB %.3f vs V7 %.3f  p=%.4g（ranksum）\n', median(a), median(b), ranksum(a, b));

fprintf('\n=== 队列间：ALB vs V7（L→T，ranksum）===\n');
for mt = metrics
	a = T{T.Cohort == "ALB" & T.Pair == "L→T", mt};
	b = T{T.Cohort == "V7"  & T.Pair == "L→T", mt};
	p = ranksum(a, b);
	fprintf('  %-13s ALB %.3f (n=%d) vs V7 %.3f (n=%d)  p=%.4g\n', ...
		mt, median(a), numel(a), median(b), numel(b), p);
end

fprintf('\n=== 逐指标反推「噪声地板之上」的可用范围 ===\n');
fprintf('  随机基线 overlap ≈ k/nCell ≈ %.4f\n', kSub / median(T.nCell));
fprintf('  noiseOverlap（同阶段分半）中位数 = %.3f = 该指标可测到的上限\n', median(T.noiseOverlap, 'omitnan'));
fprintf('  ⇒ 判读基准是 ovRatio = overlap/noiseOverlap（0=不相似，1=达到可测上限）\n');

if ~hasTDA
	fprintf('\n[跳过] persistent homology：未检测到 TDA 工具箱（computePersistentHomology / ph_pdist / rips）。\n');
	fprintf('        替代：轨迹的闭合度/圆度已在 Fig5 轨迹脚本里报过（circularity）。\n');
end
if ~hasSSM
	fprintf('[跳过] rSLDS 一致性：未检测到 ssm 工具箱。\n');
end

%% ================= 局部函数 =================
function U = iTopSub(X, k)
% X: cells × time（不去均值，保留轨迹整体偏移）→ 前 k 个左奇异向量
[U, ~, ~] = svd(X, 'econ');
k = min(k, size(U, 2));
U = U(:, 1:k);
end

function [theta, ov, cm] = iSubAngle(U1, U2)
% 主子空间夹角；theta 弧度；ov = mean(cos²) = subspace overlap
k = min(size(U1, 2), size(U2, 2));
[~, S, ~] = svd(U1(:, 1:k)' * U2(:, 1:k), 'econ');
c = min(max(diag(S), -1), 1);
theta = acos(c);
ov = mean(c .^ 2);
cm = mean(c);
end

function ai = iAlign(U, Y)
% Elsayed 2016 alignment index：子空间 U 能捕获 Y 的方差比例（有方向性）
% tr(U' Cy U) / tr(Cy) = ||Y'U||_F² / ||Y||_F²
num = norm(Y' * U, 'fro') ^ 2;
den = norm(Y, 'fro') ^ 2;
if den == 0, ai = NaN; else, ai = num / den; end
end

function P = iBinPattern(X, edges)
% X: cells × time × nLine → P: cells × nBin × 2（随机对半分两套独立估计）
nL = size(X, 3); p = randperm(nL); h = floor(nL / 2);
nBin = numel(edges) - 1;
P = nan(size(X, 1), nBin, 2);
for ih = 1:2
	if ih == 1, sel = p(1:h); else, sel = p(h+1:end); end
	for b = 1:nBin
		idx = edges(b):(edges(b + 1) - 1);
		P(:, b, ih) = mean(mean(X(:, idx, sel), 2, 'omitnan'), 3, 'omitnan');
	end
end
end

function R = iCrossRDM(P)
% crossnobis 风格：R_ij = 1 − ½[corr(P_i^1,P_j^2) + corr(P_i^2,P_j^1)]
n = size(P, 2); R = nan(n);
for i = 1:n
	for j = i + 1:n
		d = 0.5 * (iCorr(P(:, i, 1), P(:, j, 2)) + iCorr(P(:, i, 2), P(:, j, 1)));
		R(i, j) = 1 - d; R(j, i) = R(i, j);
	end
end
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

function r = iSpearman(a, b)
ok = isfinite(a) & isfinite(b);
if sum(ok) < 5, r = NaN; return; end
r = corr(a(ok), b(ok), 'Type', 'Spearman');
end

function pr = iPR(X, doCenter)
% participation ratio：(Σλ)²/Σλ²，λ 为 X 的奇异值平方
if doCenter, X = X - mean(X, 2, 'omitnan'); end
s = svd(X, 'econ');
l = s .^ 2;
if sum(l) == 0, pr = NaN; return; end
l = l / sum(l);
pr = 1 / sum(l .^ 2);
end

function r = iSmooth(X)
% 轨迹平滑度：二阶差分能量 / 一阶差分能量（越小越平滑；随机点云 ≈ 4）
X = X - mean(X, 2, 'omitnan');
D1 = diff(X, 1, 2); D2 = diff(X, 2, 2);
e1 = norm(D1, 'fro')^2; e2 = norm(D2, 'fro')^2;
if e1 == 0, r = NaN; else, r = e2 / e1; end
end

function d = iTwoNN(X)% twoNN 内在维度（Facco 2017）：mu_i = r2/r1，CDF: log(1-F) = -d·log(mu)
% X: cells × time（列 = 样本点）；先去掉时间均值只留"变化"
X = X - mean(X, 2, 'omitnan');
Y = X';                          % time × cells
n = size(Y, 1);
if n < 6, d = NaN; return; end
D = squareform(pdist(Y));
D(1:n + 1:end) = inf;
Ds = sort(D, 2, 'ascend');
mu = Ds(:, 2) ./ Ds(:, 1);
mu = mu(isfinite(mu) & mu > 1);
if numel(mu) < 6, d = NaN; return; end
mu = sort(mu);
F = (1:numel(mu))' / numel(mu);
keep = mu <= prctile(mu, 90);    % 去掉尾端离群点
p = polyfit(log(mu(keep)), -log(1 - F(keep)), 1);
d = p(1);
end


function S = iPairSub(XA, XB, k, cap, nRep, nSplit)
% 可选：随机下采样到 cap 个细胞（A/B 用同一批细胞索引），重复 nRep 次取平均
nc = size(XA, 1);
if cap > 0 && nc > cap
	idxList = arrayfun(@(r) randperm(nc, cap), 1:nRep, 'UniformOutput', false);
else
	idxList = {1:nc};
end
ov = []; sA = []; sB = []; aa = []; ab = []; tm = []; tx = [];
for r = 1:numel(idxList)
	s = idxList{r};
	xa = XA(s, :, :); xb = XB(s, :, :);
	ma = mean(xa, 3, 'omitnan'); mb = mean(xb, 3, 'omitnan');
	UA = iTopSub(ma, k); UB = iTopSub(mb, k);
	[th, o] = iSubAngle(UA, UB);
	ov(end+1, 1) = o; tm(end+1, 1) = mean(th) * 180 / pi; tx(end+1, 1) = max(th) * 180 / pi; %#ok<AGROW>
	aa(end+1, 1) = iAlign(UA, mb); ab(end+1, 1) = iAlign(UB, ma); %#ok<AGROW>
	nl = size(xa, 3); h = floor(nl / 2); a1 = []; a2 = [];
	for t = 1:nSplit
		q = randperm(nl);
		[~, o1] = iSubAngle(iTopSub(mean(xa(:, :, q(1:h)), 3, 'omitnan'), k), ...
			iTopSub(mean(xa(:, :, q(h+1:end)), 3, 'omitnan'), k));
		[~, o2] = iSubAngle(iTopSub(mean(xb(:, :, q(1:h)), 3, 'omitnan'), k), ...
			iTopSub(mean(xb(:, :, q(h+1:end)), 3, 'omitnan'), k));
		a1(end+1, 1) = o1; a2(end+1, 1) = o2; %#ok<AGROW>
	end
	sA(end+1, 1) = mean(a1); sB(end+1, 1) = mean(a2); %#ok<AGROW>
end
S = struct('ov', mean(ov), 'selfA', mean(sA), 'selfB', mean(sB), 'ovNoise', mean([sA; sB]), ...
	'aiAB', mean(aa), 'aiBA', mean(ab), 'thMeanDeg', mean(tm), 'thMaxDeg', mean(tx), 'cm', sqrt(mean(ov)));
end
