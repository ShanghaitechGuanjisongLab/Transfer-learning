% 补充检查 1 + 4（不画图）
%
% 检查 1（论点① 的定量缺口）：**同口径** split-half 可靠度，Naive 对照 Learned
%   为什么要"同口径"：split-half + Spearman-Brown 估计的是"全长（全部试次均值）"的可靠度，
%   试次越多可靠度越高。Naive 每条件 20-30 试次、Learned 30 试次，所以必须**按试次数匹配**再比，
%   否则"学会后更可靠"可能只是"试次更多"。
%
% 检查 4（论点③ 的一个替代解释）：模板 vL / vC / vA 之间的余弦相似度
%   若 cos(vL,vA) 很高，则"动作模板 u_A≈0"只是共线冗余，不能当成"动作成分不存在"。
%
% 输出：Check_ReliabilityAndTemplateCos_<layer>.csv

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
iW = find(tAll >= 0 & tAll <= 1.5);   % 取完整响应窗（不声称“无舔”，故无需限制在 1 s）
nBoot = 200; rng(20261113, 'twister');
if ~exist('LayerSel', 'var'), LayerSel = "MOp2/3"; end

cfg = struct();
cfg(1).Name = "ALB"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(2).Name = "V7";  cfg(2).DS = TransferLearning.Vacation7();
Rows = {};

for ic = 1:2
	DS = cfg(ic).DS;
	for m = unique(iMouse(DS))'
		[dts, stim] = iList(DS, m);
		isN = stim == "LightOnly"; isA = stim == "AudioOnly";
		best = NaT; bestN = 0;
		for k = unique(dts(isN))'
			n = min(sum(dts == k & isN), sum(dts == k & isA));
			if n > bestN, bestN = n; best = k; end
		end
		if isnat(best) || bestN < 8, continue; end
		nLO = iQuery(DS, m, best, "LightOnly");
		nAO = iQuery(DS, m, best, "AudioOnly");
		nWO = iQuery(DS, m, best, "WaterOnly");
		dtL = iFirst(DS, m, "Learned", "AudioWater");
		dtT = iFirst(DS, m, "Transfer", "LightWater");
		if isnat(dtL) || isnat(dtT), continue; end
		nAW = iQuery(DS, m, dtL, "AudioWater");
		nLW = iQuery(DS, m, dtT, "LightWater");
		if any(cellfun(@isempty, {nLO, nAO, nAW, nLW})), continue; end

		cellsR = intersect(intersect(nLO.CellUID, nAO.CellUID), intersect(nAW.CellUID, nLW.CellUID));
		if strlength(LayerSel) > 0
			cellsR = iKeepLayer(DS, cellsR, LayerSel);
		end
		if numel(cellsR) < 50, continue; end

		[MAO, bAO] = iMatBeh(DS, nAO, cellsR, iW);
		[MLO, bLO] = iMatBeh(DS, nLO, cellsR, iW);
		[MAW, bAW] = iMatBeh(DS, nAW, cellsR, iW);
		[MLW, bLW] = iMatBeh(DS, nLW, cellsR, iW);
		% 未给水条件（Naive 的 AO/LO）行为可能全 NaN → 当作"未舔"
		bAO(isnan(bAO)) = 0; bLO(isnan(bLO)) = 0;

		iAH = find(bAW == 1); iLH = find(bLW == 1); iLM = find(bLW == 0);
		iAN = find(bAO == 0); iLN = find(bLO == 0);   % 未舔的 Naive 试次（本来也几乎不舔）

		% ---- 匹配试次数 ----
		nPair = min([numel(iAN), numel(iLN), numel(iAH)]);
		if nPair < 8, continue; end
		rNaiveAO = iRelAtN(MAO(:, iAN), nPair, nBoot);
		rNaiveLO = iRelAtN(MLO(:, iLN), nPair, nBoot);
		rLrnAW   = iRelAtN(MAW(:, iAH), nPair, nBoot);
		rTrnMiss = iRelAtN(MLW(:, iLM), min(nPair, numel(iLM)), nBoot);
		rTrnHit  = iRelAtN(MLW(:, iLH), min(nPair, numel(iLH)), nBoot);

		% ---- 模板余弦（需要 WaterOnly，单独一套细胞）----
		cLA = NaN; cLC = NaN; cCA = NaN; nC = NaN;
		if ~isempty(nWO)
			cellsT = intersect(cellsR, nWO.CellUID);
			if strlength(LayerSel) > 0
				cellsT = iKeepLayer(DS, cellsT, LayerSel);
			end
			if numel(cellsT) >= 50
				MWO = iMat(nWO, cellsT, iW);
				[MAW2, bAW2] = iMatBeh(DS, nAW, cellsT, iW);
				MLO2 = iMat(nLO, cellsT, iW);
				okH = find(bAW2 == 1);
				if numel(okH) >= 4
					vL = mean(MAW2(:, okH), 2, 'omitnan');
					vC = mean(MLO2, 2, 'omitnan');
					vA = mean(MWO, 2, 'omitnan');
					cLA = iCos(vL, vA);
					cLC = iCos(vL, vC);
					cCA = iCos(vC, vA);
					nC = numel(cellsT);
				end
			end
		end

		Rows(end+1, :) = {string(cfg(ic).Name), string(m), numel(cellsR), nPair, ...
			numel(iAN), numel(iAH), numel(iLM), numel(iLH), ...
			rNaiveAO, rNaiveLO, rLrnAW, rTrnMiss, rTrnHit, cLA, cLC, cCA, nC}; %#ok<SAGROW>
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Mouse", "NCells", "nMatched", ...
	"nNaiveAO", "nLrnHit", "nTrnMiss", "nTrnHit", ...
	"rel_NaiveAO", "rel_NaiveLO", "rel_LrnAW", "rel_TrnMiss", "rel_TrnHit", ...
	"cos_LA", "cos_LC", "cos_CA", "nCellT"]);
csvPath = fullfile(thisDir, "Check_ReliabilityAndTemplateCos_" + replace(LayerSel, "/", "-") + ".csv");
writetable(T, csvPath);
fprintf('Wrote: %s\n', csvPath);

%% ---------- 汇总 ----------
f = @(x) sprintf('%.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
fprintf('\n======== 检查1：同口径 split-half 可靠度（层 = %s，试次数已匹配）========\n', LayerSel);
for c = ["ALB", "V7"]
	S = T(T.Cohort == c, :);
	if height(S) < 3, continue; end
	d = S.rel_LrnAW - S.rel_NaiveAO;
	p = signrank(d);
	fprintf('%-4s n=%2d | Naive声 %s | Naive光 %s | Learned声 %s | Δ(Learned−Naive) = %+.3f±%.3f  p=%.4g  逐鼠 %s\n', ...
		c, height(S), f(S.rel_NaiveAO), f(S.rel_NaiveLO), f(S.rel_LrnAW), ...
		mean(d, 'omitnan'), std(d, 'omitnan')/sqrt(sum(isfinite(d))), p, ...
		strjoin(compose('%+.2f', d'), ' '));
	fprintf('       迁移期: 未舔 %s (n=%d) | 舔了 %s (n=%d)\n', ...
		f(S.rel_TrnMiss), sum(isfinite(S.rel_TrnMiss)), f(S.rel_TrnHit), sum(isfinite(S.rel_TrnHit)));
end

fprintf('\n======== 检查4：模板余弦相似度（层 = %s）========\n', LayerSel);
for c = ["ALB", "V7"]
	S = T(T.Cohort == c & isfinite(T.cos_LA), :);
	if height(S) < 2, continue; end
	fprintf('%-4s n=%2d | cos(vL,vA)=%s | cos(vL,vC)=%s | cos(vC,vA)=%s  逐鼠 cos(L,A) %s\n', ...
		c, height(S), f(S.cos_LA), f(S.cos_LC), f(S.cos_CA), strjoin(compose('%.2f', S.cos_LA'), ' '));
	fprintf('       |cos| 的中位: LA=%.2f LC=%.2f CA=%.2f\n', ...
		median(abs(S.cos_LA)), median(abs(S.cos_LC)), median(abs(S.cos_CA)));
end

%% ========== local ==========
function rel = iRelAtN(M, nUse, nBoot)
% 取 nUse 个试次 → 随机对半 → 相关 → Spearman-Brown
n = size(M, 2);
rel = NaN;
if n < nUse || nUse < 6, return; end
r = nan(nBoot, 1);
for b = 1:nBoot
	cols = randperm(n, nUse);
	Msub = M(:, cols);
	h = floor(nUse/2);
	r(b) = iCorr(mean(Msub(:, 1:h), 2, 'omitnan'), mean(Msub(:, h+1:end), 2, 'omitnan'));
end
r0 = mean(r, 'omitnan');
if isfinite(r0) && r0 > -1, rel = 2*r0/(1+r0); end
end

function c = iCos(a, b)
ok = isfinite(a) & isfinite(b);
if sum(ok) < 10, c = NaN; return; end
a = a(ok) - mean(a(ok)); b = b(ok) - mean(b(ok));
c = (a' * b) / (norm(a) * norm(b));
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

function [dts, stim] = iList(DS, m)
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus);
T = T(T.Mouse == m & T.Stimulus ~= "StartMonitor" & T.Stimulus ~= "StopMonitor", :);
dts = T.DateTime; stim = T.Stimulus;
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

function [M, b] = iMatBeh(DS, nts, cells, iW)
M = iMat(nts, cells, iW); b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(numel(Tu), 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end
