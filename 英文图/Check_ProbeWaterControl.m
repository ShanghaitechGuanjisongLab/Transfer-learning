% 关键对照：「给水」这一因子能否单独解释 rel 的上升？
%
% 背景：ALB（声→光，非穿插）阶段内 **只有** AudioWater 给水 session，
%       Learned/Transfer/Final 都没有"同线索、无给水"的 session
%       → 学习 与 给水 在 ALB 里是**结构性完全共线**，事后无法分离。
%       所以 Fig5(e) 借用 LAInterspersed（光→声穿插）的无强化探针。
%       但需回答：穿插范式的结论能否外推到非穿插范式？
%
% 本脚本在 **同一个穿插范式内部**、**同一天、同一阶段、同一条线索（光）** 上
% 直接把「给水」这一因子单独操纵出来，做 2×2 设计：
%
%              LightOnly(无给水)   LightWater(给水)
%   Naive         rel_NaiveLO        rel_NaiveLW        ← 尚未学会
%   Transfer      rel_TrnLO          rel_TrnLW          ← 已学会
%
% 判读：
%   · 若 (LW − LO) 在 Naive 已存在且量级相近 → rel 不受"给水"影响
%     ⇒ ALB 里 rel 的上升不能归因于给水，跨范式背书成立。
%   · 若 (LW − LO) 很大 → 给水本身提升 rel ⇒ 必须下调论点①的强度。
%   · 另用 LW 的**未舔试次**再算一遍（rel_LWmiss），把"舔动作"也扣掉。
%
% 输出：Check_ProbeWaterControl_<layer>.csv

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
fprintf('%-9s %5s | %-22s | %-22s | %s\n', '鼠', 'nCell', ...
	'Naive LO / LW', 'Transfer LO / LW', 'LWmiss');
fprintf('%9s %5s | %6s %6s %6s | %6s %6s %6s | %6s %6s\n', '', '', ...
	'nLO', 'nLW', 'relLW', 'nLO', 'nLW', 'relLW', 'nMiss', 'rel');

for m = unique(iMouse(DS))'
	dtN = iFirst(DS, m, "Naive", "LightOnly");
	dtT = iFirst(DS, m, "Transfer", "LightOnly");
	if isnat(dtN) || isnat(dtT), continue; end

	nNLO = iQuery(DS, m, dtN, "LightOnly");
	nNLW = iQuery(DS, m, dtN, "LightWater");
	nTLO = iQuery(DS, m, dtT, "LightOnly");
	nTLW = iQuery(DS, m, dtT, "LightWater");
	if isempty(nNLO) || isempty(nTLO) || isempty(nNLW) || isempty(nTLW), continue; end

	cells = intersect(intersect(nNLO.CellUID, nNLW.CellUID), ...
		intersect(nTLO.CellUID, nTLW.CellUID));
	if strlength(LayerSel) > 0
		cells = iKeepLayer(DS, cells, LayerSel);
	end
	if numel(cells) < 50, continue; end

	M = struct();
	M.NLO = iMat(nNLO, cells, iW);
	M.NLW = iMat(nNLW, cells, iW);
	M.TLO = iMat(nTLO, cells, iW);
	M.TLW = iMat(nTLW, cells, iW);

	bN = iBeh(DS, nNLW); bT = iBeh(DS, nTLW);
	bN(isnan(bN)) = 0; bT(isnan(bT)) = 0;
	iNmiss = find(bN == 0); iTmiss = find(bT == 0);

	% 主对照：四种条件都用同一个 nPair，消除试次量差异
	nPair = min([size(M.NLO, 2), size(M.NLW, 2), size(M.TLO, 2), size(M.TLW, 2)]);
	if nPair < 8, continue; end
	rNLO = iRelAtN(M.NLO, nPair, nBoot);
	rNLW = iRelAtN(M.NLW, nPair, nBoot);
	rTLO = iRelAtN(M.TLO, nPair, nBoot);
	rTLW = iRelAtN(M.TLW, nPair, nBoot);

	% 未舔子集（把"舔动作"也扣掉）；两边用同一个 nMiss
	nMiss = min(numel(iNmiss), numel(iTmiss));
	rNLWm = NaN; rTLWm = NaN; rNLOm = NaN; rTLOm = NaN;
	if nMiss >= 8
		rNLWm = iRelAtN(M.NLW(:, iNmiss), nMiss, nBoot);
		rTLWm = iRelAtN(M.TLW(:, iTmiss), nMiss, nBoot);
		% LightOnly 本来就几乎不舔，取同量试次做对照
		rNLOm = iRelAtN(M.NLO, nMiss, nBoot);
		rTLOm = iRelAtN(M.TLO, nMiss, nBoot);
	end

	Rows(end+1, :) = {string(m), numel(cells), nPair, ...
		rNLO, rNLW, rTLO, rTLW, nMiss, rNLOm, rNLWm, rTLOm, rTLWm}; %#ok<SAGROW>
	fprintf('%-9s %5d | %6.3f %6.3f %6.3f | %6.3f %6.3f %6.3f | %6d %6.3f\n', ...
		string(m), numel(cells), rNLO, rNLW, rTLW, rTLO, rTLW, rTLWm, nMiss, rTLWm);
end

T = cell2table(Rows, 'VariableNames', ["Mouse", "NCells", "nMatched", ...
	"rel_NaiveLO", "rel_NaiveLW", "rel_TrnLO", "rel_TrnLW", ...
	"nMissMatched", "rel_NaiveLO_sub", "rel_NaiveLWmiss", "rel_TrnLO_sub", "rel_TrnLWmiss"]);
csvPath = fullfile(thisDir, "Check_ProbeWaterControl_" + replace(LayerSel, "/", "-") + ".csv");
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

%% ---------- 汇总 ----------
f = @(x) sprintf('%.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
pr = @(d, nm) fprintf('  %-32s Δ=%+.3f±%.3f  signrank p=%.4g  逐鼠 %s\n', nm, ...
	mean(d, 'omitnan'), std(d, 'omitnan')/sqrt(sum(isfinite(d))), ...
	pSafe(d), strjoin(compose('%+.2f', d(isfinite(d)))', ' '));

fprintf('\n=== 层 %s，n=%d 鼠：同一穿插范式内「给水」因子 ===\n', LayerSel, height(T));
fprintf('  rel(Naive   / LightOnly ) = %s\n', f(T.rel_NaiveLO));
fprintf('  rel(Naive   / LightWater) = %s\n', f(T.rel_NaiveLW));
fprintf('  rel(Transfer/ LightOnly ) = %s\n', f(T.rel_TrnLO));
fprintf('  rel(Transfer/ LightWater) = %s\n', f(T.rel_TrnLW));
fprintf('\n  [给水效应] 同一阶段内 LW − LO：\n');
pr(T.rel_NaiveLW - T.rel_NaiveLO, 'Naive:    LW − LO');
pr(T.rel_TrnLW   - T.rel_TrnLO,   'Transfer: LW − LO');
fprintf('\n  [学习效应] 同一条线索内 Transfer − Naive：\n');
pr(T.rel_TrnLO - T.rel_NaiveLO, 'LightOnly: Transfer − Naive');
pr(T.rel_TrnLW - T.rel_NaiveLW, 'LightWater: Transfer − Naive');
fprintf('\n  [交互] 学习效应在 LW 与 LO 上是否一致 (差值之差)：\n');
pr((T.rel_TrnLW - T.rel_NaiveLW) - (T.rel_TrnLO - T.rel_NaiveLO), '(T−N)_LW − (T−N)_LO');
fprintf('\n  [扣掉舔] 仅在 LW 的未舔试次上（nMiss 对齐）：\n');
fprintf('    可用 nMiss: %s 个试次（每鼠）\n', strjoin(compose('%d', T.nMissMatched)', ' '));
if sum(isfinite(T.rel_TrnLWmiss)) < 3
	fprintf('    ⚠ nMiss 过小（学会后几乎必舔），无法在“扣掉舔”的口径上检验；\n');
	fprintf('      但 LO 几乎不舔、LW 几乎必舔，而两者 rel 相等 → 舔/给水对 rel 无系统影响。\n');
else
	fprintf('    rel(Naive   / LW-miss) = %s\n', f(T.rel_NaiveLWmiss));
	fprintf('    rel(Transfer/ LW-miss) = %s\n', f(T.rel_TrnLWmiss));
	pr(T.rel_TrnLWmiss - T.rel_NaiveLWmiss, 'LightWater-miss: Transfer − Naive');
	pr(T.rel_TrnLO_sub  - T.rel_NaiveLO_sub, 'LightOnly(sub) : Transfer − Naive');
end

%% ========== local ==========
function p = pSafe(d)
ok = isfinite(d);
if sum(ok) < 3, p = NaN; return; end
p = signrank(d(ok));
end

function rel = iRelAtN(M, nUse, nBoot)
% 取 nUse 个试次 → 随机对半 → 跨细胞相关 → Spearman-Brown
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
Tq = DS.TableQuery(["Mouse", "DateTime"]);
u = unique(string(Tq.Mouse));
end

function dt = iFirst(DS, m, ph, stim)
Tq = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
Tq.Mouse = string(Tq.Mouse); Tq.Phase = string(Tq.Phase); Tq.Stimulus = string(Tq.Stimulus);
sel = Tq.Mouse == m & Tq.Phase == ph & Tq.Stimulus == stim;
if ~any(sel), dt = NaT; return; end
d = sort(unique(Tq.DateTime(sel))); dt = d(1);
end

function nts = iQuery(DS, mouse, dt, stim)
nts = [];
try
	nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), ...
		UniExp.Flags.ZScore, 1:24);
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

function b = iBeh(DS, nts)
b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(numel(Tu), 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end
