% 补充检查（论点① 的干净对照）：**学会之后、不给水**的同一线索探针
%
% 动机：ALB 里没有"学会后再测无给水 AudioOnly"的 session，所以
%       "Naive 声 vs Learned 声" 的可靠度上升里混着"给水/舔"的贡献。
%
% 可用数据：LAInterspersed（光→声 穿插）。被学会的线索是**光**。
%   · Naive/LightOnly      无给水、未学习
%   · Learned/LightWater   给水（已学会）
%   · Transfer/LightOnly   无给水、**已学会**   ← 关键对照：同线索、同（无）强化、只差"学过没有"
%   · Transfer/WaterOnly   纯动作/结局模板（同阶段，用于减去动作成分）
%
% 判据：若 rel(LO@Transfer) 显著高 rel(LO@Naive)，则"表征成形"不能由给水/奖赏驱动解释。
%
% 输出：Check_PostLearningProbe_<layer>.csv

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
iW = find(tAll >= 0 & tAll <= 1.5);
nBoot = 200; rng(20261113, 'twister');
if ~exist('LayerSel', 'var'), LayerSel = "MOp2/3"; end

DS = TransferLearning.LAInterspersed();
Rows = {};
fprintf('%-9s %6s | %6s %6s %6s %6s | %7s %7s  %6s\n', ...
	'鼠', 'nCell', 'nNaLO', 'nTrLO', 'nTrWO', 'nLrLW', 'rel_NaLO', 'rel_TrLO', 'Δ');

for m = unique(iMouse(DS))'
	dtN = iFirst(DS, m, "Naive", "LightOnly");
	dtT = iFirst(DS, m, "Transfer", "LightOnly");
	dtL = iFirst(DS, m, "Learned", "LightWater");
	if isnat(dtT), continue; end
	nNLO = iQuery(DS, m, dtN, "LightOnly");
	nTLO = iQuery(DS, m, dtT, "LightOnly");
	nTWO = iQuery(DS, m, dtT, "WaterOnly");
	nLLW = iQuery(DS, m, dtL, "LightWater");
	if isempty(nNLO) || isempty(nTLO), continue; end

	cells = intersect(nNLO.CellUID, nTLO.CellUID);
	if ~isempty(nTWO), cells = intersect(cells, nTWO.CellUID); end
	if strlength(LayerSel) > 0
		cells = iKeepLayer(DS, cells, LayerSel);
	end
	if numel(cells) < 50, continue; end

	MNa = iMat(nNLO, cells, iW);
	MTr = iMat(nTLO, cells, iW);
	MWO = iMat(nTWO, cells, iW);

	nPair = min(size(MNa, 2), size(MTr, 2));
	if nPair < 8, continue; end
	relNa = iRelAtN(MNa, nPair, nBoot);
	relTr = iRelAtN(MTr, nPair, nBoot);
	vNa = mean(MNa, 2, 'omitnan');
	vTr = mean(MTr, 2, 'omitnan');
	cNaTr = iCos(vNa, vTr);

	% 与"给水的学会状态"对比（细胞取交集）
	relLrn = NaN; cLrnTr = NaN; cLrnNa = NaN; MLr = [];
	if ~isempty(nLLW)
		cells2 = intersect(cells, nLLW.CellUID);
		MLr = iMatBeh2(DS, nLLW, cells2, iW, false);
		if ~isempty(MLr) && sum(size(MLr) > 0) == 2
			okH = find(iBeh(DS, nLLW) == 1);
			if numel(okH) >= 5
				relLrn = iRelAtN(MLr(:, okH), min(nPair, numel(okH)), nBoot);
				vLr = mean(MLr(:, okH), 2, 'omitnan');
				vTr2 = mean(iMat(nTLO, cells2, iW), 2, 'omitnan');
				vNa2 = mean(iMat(nNLO, cells2, iW), 2, 'omitnan');
				cLrnTr = iCos(vLr, vTr2);
				cLrnNa = iCos(vLr, vNa2);
			end
		end
	end

	% 动作控制：把同阶段 WaterOnly 模板正交化掉后，再算 Naive↔Transfer 的相似
	cOrth = NaN; relNaO = NaN; relTrO = NaN;
	if ~isempty(MWO)
		vW = mean(MWO, 2, 'omitnan');
		[uW, ~] = iUnit(vW);
		vNaP = vNa - (vNa' * uW) * uW;
		vTrP = vTr - (vTr' * uW) * uW;
		cOrth = iCos(vNaP, vTrP);
		% 逐试次也正交化后再算可靠度（"超出动作方向的可靠结构"）
		MNaP = MNa - uW * (uW' * MNa);
		MTrP = MTr - uW * (uW' * MTr);
		relNaO = iRelAtN(MNaP, nPair, nBoot);
		relTrO = iRelAtN(MTrP, nPair, nBoot);
	end

	Rows(end+1, :) = {string(m), numel(cells), size(MNa, 2), size(MTr, 2), size(MWO, 2), ...
		size(MLr, 2), relNa, relTr, relLrn, cNaTr, cLrnTr, cLrnNa, cOrth, relNaO, relTrO}; %#ok<SAGROW>
	fprintf('%-9s %6d | %6d %6d %6d %6d | %7.3f %7.3f  %+6.3f\n', ...
		string(m), numel(cells), size(MNa, 2), size(MTr, 2), size(MWO, 2), ...
		size(MLr, 2), relNa, relTr, relTr - relNa);
end

T = cell2table(Rows, 'VariableNames', ["Mouse", "NCells", "nNaLO", "nTrLO", "nTrWO", "nLrLW", ...
	"rel_NaiveLO", "rel_TrnLO", "rel_LrnLW", "cos_NaTr", "cos_LrnTrn", "cos_LrnNaive", "cos_Orth", ...
	"rel_NaiveLO_orth", "rel_TrnLO_orth"]);
csvPath = fullfile(thisDir, "Check_PostLearningProbe_" + replace(LayerSel, "/", "-") + ".csv");
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

%% ---------- 汇总 ----------
f = @(x) sprintf('%.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
d = T.rel_TrnLO - T.rel_NaiveLO;
fprintf('\n=== 层 %s：同线索（光）、同无给水，Before vs After 学习  n=%d 鼠 ===\n', LayerSel, height(T));
fprintf('  rel(LightOnly @ Naive)    = %s\n', f(T.rel_NaiveLO));
fprintf('  rel(LightOnly @ Transfer) = %s\n', f(T.rel_TrnLO));
fprintf('  Δ = %+.3f ± %.3f   signrank p=%.4g   逐鼠 %s\n', ...
	mean(d, 'omitnan'), std(d, 'omitnan')/sqrt(sum(isfinite(d))), signrank(d), strjoin(compose('%+.2f', d'), ' '));
fprintf('  rel(LightWater @ Learned, 有条水) = %s  (n=%d)\n', f(T.rel_LrnLW), sum(isfinite(T.rel_LrnLW)));
fprintf('\n  模式相似度（余弦，逐鼠均值）:\n');
fprintf('    cos(LO@Naive, LO@Transfer)      = %s\n', f(T.cos_NaTr));
fprintf('    cos(LW@Learned, LO@Transfer)    = %s  (n=%d)\n', f(T.cos_LrnTrn), sum(isfinite(T.cos_LrnTrn)));
fprintf('    cos(LW@Learned, LO@Naive)       = %s  (n=%d)\n', f(T.cos_LrnNaive), sum(isfinite(T.cos_LrnNaive)));
fprintf('    去掉动作(WOnly)后 cos(Naive,Transfer) = %s\n', f(T.cos_Orth));
fprintf('\n=== 动作正交化后的可靠度（把 WaterOnly 方向从每个试次里减掉）===\n');
d2 = T.rel_TrnLO_orth - T.rel_NaiveLO_orth;
fprintf('  rel(LO@Naive, ⊥动作)    = %s\n', f(T.rel_NaiveLO_orth));
fprintf('  rel(LO@Transfer, ⊥动作) = %s\n', f(T.rel_TrnLO_orth));
fprintf('  Δ = %+.3f ± %.3f   signrank p=%.4g   逐鼠 %s\n', ...
	mean(d2, 'omitnan'), std(d2, 'omitnan')/sqrt(sum(isfinite(d2))), signrank(d2), strjoin(compose('%+.2f', d2'), ' '));

%% ========== local ==========
function rel = iRelAtN(M, nUse, nBoot)
n = size(M, 2); rel = NaN;
if n < nUse || nUse < 6, return; end
r = nan(nBoot, 1);
for b = 1:nBoot
	cols = randperm(n, nUse);
	Msub = M(:, cols); h = floor(nUse/2);
	r(b) = iCorr(mean(Msub(:, 1:h), 2, 'omitnan'), mean(Msub(:, h+1:end), 2, 'omitnan'));
end
r0 = mean(r, 'omitnan');
if isfinite(r0) && r0 > -1, rel = 2*r0/(1+r0); end
end

function [u, n] = iUnit(v)
n = norm(v); if n == 0, n = eps; end
u = v / n;
end

function c = iCos(a, b)
ok = isfinite(a) & isfinite(b);
if sum(ok) < 10, c = NaN; return; end
a = a(ok) - mean(a(ok)); b = b(ok) - mean(b(ok));
na = norm(a); nb = norm(b);
if na == 0 || nb == 0, c = NaN; return; end
c = (a' * b) / (na * nb);
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

function cells = iKeepLayer(DS, cells, layer)
Cx = DS.Cells; Cx.CellUID = uint64(Cx.CellUID); Cx.ZLayer = string(Cx.ZLayer);
[okm, idxm] = ismember(cells, Cx.CellUID);
keep = false(size(cells)); keep(okm) = Cx.ZLayer(idxm(okm)) == string(layer);
cells = cells(keep);
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
nT = numel(Tu);
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal(:, iW));
M = nan(numel(cells), nT);
for i = 1:numel(cells)
	rows = find(cu == cells(i));
	if isempty(rows), continue; end
	M(i, jTu(rows)) = mean(sig(rows, :), 2);
end
end

function M = iMatBeh2(DS, nts, cells, iW, useBeh) %#ok<INUSD>
M = iMat(nts, cells, iW);
end

function b = iBeh(DS, nts)
b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(numel(Tu), 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end
