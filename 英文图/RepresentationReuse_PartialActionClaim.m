% 表征复用（第十六步）：退而求其次 —— "学会↔迁移的模式相似**不完全**由动作造成"
%
% 强命题（②）：相似性与动作无关。
% 弱命题（本轮）：相似性**不完全**由动作造成。三条相互独立的检验：
%
%   检验 1（最直接）：把目标换成**迁移期未舔试次**
%       r1 = corr( vL , mean(LW_hit) )   两侧都有动作（基线）
%       r2 = corr( vL , mean(LW_miss) )  **迁移侧完全没有动作**
%       ⇒ r2 显著 > 0 即说明"即使迁移试次没有动作，模式仍与学会模式正相关"
%
%   检验 2（动作方向剔除）：用**同一 session 内**最强的动作方向
%       u = mean(LW_hit) − mean(LW_miss)（本 session 的舔/结局轴）
%       把 vL 与目标都对 u 正交化后再算相关
%       ⇒ 剔除后仍 > 0 ⇒ 相似性的主要承载方向不是动作方向
%
%   检验 3（噪声校正）：split-half 信度 → Spearman-Brown
%       r_corr = r / sqrt(rel_a * rel_b)
%       ⇒ 消除测量噪声造成的衰减，给出真实共享成分的下界估计
%
% 队列：ALB（即时）与 V7（7 天，未舔试次更多）
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧；窗口 0–1.5 s

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
iW = find(tAll >= 0 & tAll <= 1);   % ⚠ 必须与 hit/miss 判定窗一致（miss 仅保证 1 s 内无舔）
nBoot = 200; rng(20261113, 'twister');
if ~exist('LayerSel', 'var'), LayerSel = ""; end   % ""=全部；"MOp2/3"；"MOp5"

cfg = struct();
cfg(1).Name = "ALB"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(2).Name = "V7";  cfg(2).DS = TransferLearning.Vacation7();
cfg(3).Name = "TH";  cfg(3).DS = TransferLearning.THInhibit();   % 丘脑后部化学遗传抑制（CNO 覆盖光水训练期）
cohorts = string({cfg.Name});

Rows = {};
for ic = 1:numel(cfg)
	DS = cfg(ic).DS;
	fprintf('\n=============== %s ===============\n', cfg(ic).Name);
	for m = unique(iMouse(DS))'
	dtL = iFirst(DS, m, "Learned", "AudioWater");
	dtT = iFirst(DS, m, "Transfer", "LightWater");
	if isnat(dtL) || isnat(dtT), continue; end
	nAW = iQuery(DS, m, dtL, "AudioWater");
	nLW = iQuery(DS, m, dtT, "LightWater");
	% 独立动作模板：Naive 阶段、仅给水无线索（与 Learned/Transfer 不同日、不同刺激）
	dtW = iFirst(DS, m, "Naive", "WaterOnly");
	if isnat(dtW), continue; end
	nWO = iQuery(DS, m, dtW, "WaterOnly");
	if isempty(nAW) || isempty(nLW) || isempty(nWO), continue; end
	cells = intersect(intersect(nAW.CellUID, nLW.CellUID), nWO.CellUID);
	if strlength(LayerSel) > 0
		Cx = DS.Cells; Cx.CellUID = uint64(Cx.CellUID); Cx.ZLayer = string(Cx.ZLayer);
		[okm, idxm] = ismember(cells, Cx.CellUID);
		keepm = false(size(cells)); keepm(okm) = Cx.ZLayer(idxm(okm)) == LayerSel;
		cells = cells(keepm);
	end
	if numel(cells) < 50, continue; end
	[MAW, bAW] = iMatBeh(DS, nAW, cells, iW);
	[MLW, bLW] = iMatBeh(DS, nLW, cells, iW);
	MWO = iMat(nWO, cells, iW);
	okAH = find(bAW == 1); okH = find(bLW == 1); okM = find(bLW == 0);
	if numel(okAH) < 5 || numel(okM) < 4, continue; end

	vL = mean(MAW(:, okAH), 2, 'omitnan');
	vH = mean(MLW(:, okH), 2, 'omitnan');
	vM = mean(MLW(:, okM), 2, 'omitnan');
	vA = mean(MWO, 2, 'omitnan');   % 独立动作模板
	relL = iRel(MAW(:, okAH), nBoot);
	relH = iRel(MLW(:, okH), nBoot);
	relM = iRel(MLW(:, okM), nBoot);

	r1r = iCorr(vL, vH);
	r2r = iCorr(vL, vM);
	r1 = min(iAdj(r1r, relL, relH), 1);
	r2 = min(iAdj(r2r, relL, relM), 1);
	% 动作轴 1：session 内 hit − miss（会导致 r1⊥ ≡ r2⊥，仅供对照）
	u = vH - vM; u = u / norm(u);
	vLp = vL - (vL.' * u) * u;
	vHp = vH - (vH.' * u) * u;
	vMp = vM - (vM.' * u) * u;
	r1p = min(iAdj(iCorr(vLp, vHp), relL, relH), 1);
	r2p = min(iAdj(iCorr(vLp, vMp), relL, relM), 1);
	r1pr = iCorr(vLp, vHp); r2pr = iCorr(vLp, vMp);
	fracU = norm((vH.' * u) * u) / max(norm(vH), eps);
	% 动作轴 2（推荐）：独立 Naive/WaterOnly 模板 —— 不与目标共享试次，r1 与 r2 不再恒等
	uA = vA / norm(vA);
	vLa = vL - (vL.' * uA) * uA;
	vHa = vH - (vH.' * uA) * uA;
	vMa = vM - (vM.' * uA) * uA;
	r1ar = iCorr(vLa, vHa); r2ar = iCorr(vLa, vMa);
	r1a = min(iAdj(r1ar, relL, relH), 1);
	r2a = min(iAdj(r2ar, relL, relM), 1);
	fracUA = norm((vH.' * uA) * uA) / max(norm(vH), eps);

	Rows(end+1, :) = {string(cfg(ic).Name), string(m), numel(cells), numel(okH), numel(okM), ...
		r1, r2, r1p, r2p, fracU, relL, relH, relM, r1r, r2r, r1pr, r2pr, ...
		r1a, r2a, r1ar, r2ar, fracUA}; %#ok<SAGROW>
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Mouse", "NCells", "nHit", "nMiss", ...
	"r1_hit", "r2_miss", "r1_orth", "r2_orth", "fracU", "rel_Lrn", "rel_Hit", "rel_Miss", ...
	"r1_raw", "r2_raw", "r1_orth_raw", "r2_orth_raw", ...
	"r1_orthA", "r2_orthA", "r1_orthA_raw", "r2_orthA_raw", "fracUA"]);
suffix = "";
if strlength(LayerSel) > 0, suffix = "_" + replace(LayerSel, "/", "-"); end
csvPath = fullfile(thisDir, "RepresentationReuse_PartialActionClaim" + suffix + ".csv");
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠均值 ± SEM；p 为 vs 0 的 signrank）===============\n');
f = @(x) sprintf('%+.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
for c = cohorts
	sel = T.Cohort == c;
	if sum(sel) < 3, continue; end
	fprintf('%-4s n=%2d | 信度: Lrn=%s Hit=%s Miss=%s\n', c, sum(sel), ...
		f(T.rel_Lrn(sel)), f(T.rel_Hit(sel)), f(T.rel_Miss(sel)));
	fprintf('     检验1  r(hit)=%s (p=%.3g)   **r(miss)=%s (p=%.3g)**\n', ...
		f(T.r1_hit(sel)), iSafeP(T.r1_hit(sel)), f(T.r2_miss(sel)), iSafeP(T.r2_miss(sel)));
	fprintf('     检验2  剔动作后 r(hit)=%s   **r(miss)=%s (p=%.3g)**   动作方向占 vHit 的 %s\n', ...
		f(T.r1_orth(sel)), f(T.r2_orth(sel)), iSafeP(T.r2_orth(sel)), f(T.fracU(sel)));
	fprintf('     原始（未校正）: r(hit)=%s   **r(miss)=%s (p=%.3g)** | 剔动作: hit=%s  **miss=%s (p=%.3g)**\n', ...
		f(T.r1_raw(sel)), f(T.r2_raw(sel)), iSafeP(T.r2_raw(sel)), ...
		f(T.r1_orth_raw(sel)), f(T.r2_orth_raw(sel)), iSafeP(T.r2_orth_raw(sel)));
end

%% ========== local ==========
function rel = iRel(M, nBoot)
% split-half → Spearman-Brown
n = size(M, 2);
rel = NaN;
if n < 6, return; end
r = nan(nBoot, 1);
for b = 1:nBoot
	p = randperm(n);
	a1 = p(1:floor(n/2)); a2 = p(floor(n/2)+1:end);
	r(b) = iCorr(mean(M(:, a1), 2, 'omitnan'), mean(M(:, a2), 2, 'omitnan'));
end
r0 = mean(r, 'omitnan');
if isfinite(r0) && r0 > -1, rel = 2*r0/(1+r0); end
end

function r = iAdj(r, ra, rb)
if ~isfinite(r) || ~isfinite(ra) || ~isfinite(rb) || ra <= 0 || rb <= 0, r = NaN; return; end
r = r / sqrt(ra * rb);
end

function u = iMouse(DS)
T = DS.TableQuery(["Mouse", "DateTime"]);
u = unique(string(T.Mouse));
end

function dt = iFirst(DS, m, ph, stim)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse); T.Phase = string(T.Phase); T.Stimulus = string(T.Stimulus);
sel = T.Mouse == m & T.Phase == ph & T.Stimulus == stim;
if ~any(sel), dt = NaT; return; end
d = sort(unique(T.DateTime(sel))); dt = d(1);
end

function nts = iQuery(DS, mouse, dt, stim)
nts = [];
try
	nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), UniExp.Flags.ZScore, 1:24);
catch
	return;
end
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
end

function M = iMat(nts, cells, iW)
M = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
[~, jTu] = ismember(nts.TrialUID, Tu);
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal(:, iW));
M = nan(numel(cells), numel(Tu));
for i = 1:numel(cells)
	rows = find(cu == cells(i));
	if isempty(rows), continue; end
	M(i, jTu(rows)) = mean(sig(rows, :), 2);
end
end

function [M, b] = iMatBeh(DS, nts, cells, iW)
M = iMat(nts, cells, iW); b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(numel(Tu), 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end

function r = iCorr(a, b)
a = a(:); b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 5, r = NaN; return; end
a = a(ok); b = b(ok);
if std(a) == 0 || std(b) == 0, r = NaN; return; end
c = corrcoef(a, b); r = c(1, 2);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
