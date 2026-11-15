% 表征复用（第十二步）：针对"论点②"的两条补救
%
% 背景：上一轮发现，ALB 的 Learned/AudioWater 几乎 100% 舔 → M1 的"两侧都无动作"版本
%       功效极低（p=0.20），我因此说"结构上无法检验"。用户指出两点，本脚本把它们做实：
%
% 【补救 A】"纯线索试次不一定不舔" → 用**完全未舔**的 AO/LO 重新定轴
%   ALB Naive 的 AudioOnly hit≈0.18、LightOnly hit≈0.09，并非零舔。
%   做法：Naive session 里只取 Behavior==0 的 AO 与 LO 定轴（每鼠约 16–18 试次/条件），
%         再做 2 折交叉验证，并重新投影 Learned/AW 与 Transfer/LW（含 miss-only）。
%   ⇒ 若与"全部试次定轴"结果一致，说明模态轴不是靠舔建起来的。
%
% 【补救 B】"动作匹配 + 显式剔除动作成分"（不需要 AW 的未舔试次）
%   做法：
%     1) 动作匹配：Learned 只取 hit、Transfer 只取 hit ⇒ 两侧都舔，动作差异被匹配掉
%     2) 用 **WaterOnly**（无线索、给水+舔）估计"动作/结局模式" u = v_WO/‖v_WO‖
%        把两侧条件向量对 u 正交化：v⊥ = v − (v·u)u
%     3) 比较正交化前后的 (i) 模式相似相关 r(Lrn,Trn)，(ii) 判别 AUC(Lrn-hit vs Trn-hit)
%   ⇒ 若正交化后仍显著，则这部分相似/判别不能由动作解释
%
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧；窗口 0–1.5 s

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
iW = find(tAll >= 0 & tAll <= 1.5);

DS = TransferLearning.AudioLightBaseline();
Rows = {};
fprintf('%-9s %6s | %10s %10s %10s | %7s %7s | %7s %7s %7s %7s | %7s %7s\n', ...
	'鼠', 'nCell', 'AUC0(全部轴)', 'AUCcv(全轴)', 'AUCcv(净轴)', 'r原', 'r⊥', 'AUC原', 'AUC⊥', 'r⊥3', 'AUC⊥3', 'nAW', 'nLW');
for m = unique(iMouse(DS))'
	[dts, stim] = iList(DS, m);
	isN = stim == "LightOnly"; isA = stim == "AudioOnly";
	best = NaT; bestN = 0;
	for k = unique(dts(isN))'
		n = min(sum(dts == k & isN), sum(dts == k & isA));
		if n > bestN, bestN = n; best = k; end
	end
	if isnat(best) || bestN < 5, continue; end
	nLO = iQuery(DS, m, best, "LightOnly");
	nAO = iQuery(DS, m, best, "AudioOnly");
	nWO = iQuery(DS, m, best, "WaterOnly");
	dtL = iFirst(DS, m, "Learned", "AudioWater");
	dtT = iFirst(DS, m, "Transfer", "LightWater");
	if isnat(dtL) || isnat(dtT), continue; end
	nAW = iQuery(DS, m, dtL, "AudioWater");
	nLW = iQuery(DS, m, dtT, "LightWater");
	if any(cellfun(@isempty, {nLO, nAO, nAW, nLW})), continue; end

	cells = intersect(intersect(nLO.CellUID, nAO.CellUID), intersect(nAW.CellUID, nLW.CellUID));
	useWO = ~isempty(nWO);
	if useWO, cells = intersect(cells, nWO.CellUID); end
	if numel(cells) < 50, continue; end

	[MLO, bLO] = iMat(DS, nLO, cells, iW);
	[MAO, bAO] = iMat(DS, nAO, cells, iW);
	[MAW, bAW] = iMat(DS, nAW, cells, iW);
	[MLW, bLW] = iMat(DS, nLW, cells, iW);
	if useWO, [MWO, ~] = iMat(DS, nWO, cells, iW); else, MWO = []; end

	% ---------- 补救 A：全部轴（基线）与"完全未舔"轴 ----------
	wAll = mean(MAO, 2, 'omitnan') - mean(MLO, 2, 'omitnan');
	auc0 = iAUC(iProj(MAW, wAll), iProj(MLW, wAll));
	% 2 折交叉验证（全部试次）
	iAO = 1:2:size(MAO, 2); jAO = 2:2:size(MAO, 2);
	iLO = 1:2:size(MLO, 2); jLO = 2:2:size(MLO, 2);
	cvAll = nan(2, 1); cvNet = nan(2, 1);
	% 完全未舔子集
	okAO = find(bAO == 0); okLO = find(bLO == 0);
	nAOc = 0; nLOc = 0;
	if numel(okAO) >= 6 && numel(okLO) >= 6
		kAO = 1:2:numel(okAO); kLO = 1:2:numel(okLO);
		nAOc = numel(okAO); nLOc = numel(okLO);
	end
	for f = 1:2
		if f == 1, aTr = iAO; aTe = jAO; lTr = iLO; lTe = jLO;
		else,      aTr = jAO; aTe = iAO; lTr = jLO; lTe = iLO; end
		w = mean(MAO(:, aTr), 2, 'omitnan') - mean(MLO(:, lTr), 2, 'omitnan');
		cvAll(f) = iAUC(iProj(MAO(:, aTe), w), iProj(MLO(:, lTe), w));
		if nAOc > 0
			if f == 1, aa = okAO(kAO); bb = okLO(kLO); cc = okAO(2:2:end); dd = okLO(2:2:end);
			else,      aa = okAO(2:2:end); bb = okLO(2:2:end); cc = okAO(kAO); dd = okLO(kLO); end
			wn = mean(MAO(:, aa), 2, 'omitnan') - mean(MLO(:, bb), 2, 'omitnan');
			cvNet(f) = iAUC(iProj(MAO(:, cc), wn), iProj(MLO(:, dd), wn));
		end
	end

	% ---------- 补救 B：动作匹配（hit vs hit）+ 动作轴正交化 ----------
	nAWu = 0; nLWu = 0; rRaw = NaN; rOrth = NaN; aucRaw = NaN; aucOrth = NaN;
	rOrth3 = NaN; aucOrth3 = NaN; d2raw = NaN; d2orth = NaN; nTM = 0;
	okAH = find(bAW == 1); okTH = find(bLW == 1);
	nAWu = numel(okAH); nLWu = numel(okTH);
	if nAWu >= 4 && nLWu >= 4
		vL = mean(MAW(:, okAH), 2, 'omitnan');
		vT = mean(MLW(:, okTH), 2, 'omitnan');
		rRaw = iCorr(vL, vT);
		aucRaw = iAUC(iProj(MAW(:, okAH), wAll), iProj(MLW(:, okTH), wAll));
		if useWO
			u = mean(MWO, 2, 'omitnan'); u = u / norm(u);
			vLp = vL - (vL.' * u) * u;
			vTp = vT - (vT.' * u) * u;
			rOrth = iCorr(vLp, vTp);
			% 正交化后的判别：把每个试次向量也投影掉 u，再用同一根模态轴
			PAW = MAW(:, okAH) - u * (u.' * MAW(:, okAH));
			PLW = MLW(:, okTH) - u * (u.' * MLW(:, okTH));
			aucOrth = iAUC(iProj(PAW, wAll), iProj(PLW, wAll));
			% 更严格：用 WaterOnly 前 3 个主成分张成的动作子空间
			Wm = MWO(:, all(isfinite(MWO), 1));
			if size(Wm, 2) >= 4
				Wc = Wm - mean(Wm, 2);
				[Uu, ~, ~] = svd(Wc, 'econ');          % Uu: 细胞 × min(n) —— 列空间才是细胞空间的子空间
				Q = Uu(:, 1:min(3, size(Uu, 2)));
				rOrth3 = iCorr(vL - Q*(Q.'*vL), vT - Q*(Q.'*vT));
				PAW3 = MAW(:, okAH) - Q*(Q.'*MAW(:, okAH));
				PLW3 = MLW(:, okTH) - Q*(Q.'*MLW(:, okTH));
				aucOrth3 = iAUC(iProj(PAW3, wAll), iProj(PLW3, wAll));
				% ---- 决定性指标：d2 的动作剔除版本 ----
				%   Trn 用未舔试次、Ctrl 用未学光（都不舔），再把三者都对动作子空间正交化
				okTM = find(bLW == 0);
				nTM = numel(okTM);
				if nTM >= 4
					vT = mean(MLW(:, okTM), 2, 'omitnan');
					vC = mean(MLO, 2, 'omitnan');
					d2raw = iCorr(vT, vL) - iCorr(vT, vC);
					vTp = vT - Q*(Q.'*vT); vCp = vC - Q*(Q.'*vC);
					d2orth = iCorr(vTp, vL - Q*(Q.'*vL)) - iCorr(vTp, vCp);
				end
			end
		end
	end

	fprintf('%-9s %6d | %10.2f %10.2f %10.2f | %7.2f %7.2f | %7.2f %7.2f %7.2f %7.2f | %7.2f %7.2f | %7d %7d\n', string(m), numel(cells), ...
		auc0, mean(cvAll, 'omitnan'), mean(cvNet, 'omitnan'), rRaw, rOrth, aucRaw, aucOrth, rOrth3, aucOrth3, ...
		d2raw, d2orth, nAWu, nLWu);
	Rows(end+1, :) = {string(m), numel(cells), nAOc, nLOc, auc0, mean(cvAll, 'omitnan'), mean(cvNet, 'omitnan'), ...
		rRaw, rOrth, aucRaw, aucOrth, rOrth3, aucOrth3, d2raw, d2orth, nAWu, nLWu}; %#ok<SAGROW>
end

T = cell2table(Rows, 'VariableNames', ["Mouse", "NCells", "nAO_clean", "nLO_clean", ...
	"AUC0_allaxis", "AUCcv_allTrials", "AUCcv_cleanAxis", ...
	"r_raw", "r_orth", "AUC_raw", "AUC_orth", "r_orth3", "AUC_orth3", "d2_raw", "d2_orth", "nAW_hit", "nLW_hit"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_ActionControl.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平 ===============\n');
f = @(x) sprintf('%.2f±%.2f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
fprintf('补救A（纯线索轴，只用了 Behavior==0 的 AO/LO 定轴）\n');
fprintf('  AUCcv 全轴=%s (p=%.3g)  vs  净轴=%s (p=%.3g)   n=%d 鼠\n', ...
	f(T.AUCcv_allTrials), iSafeP(T.AUCcv_allTrials - 0.5), ...
	f(T.AUCcv_cleanAxis), iSafeP(T.AUCcv_cleanAxis - 0.5), sum(isfinite(T.AUCcv_cleanAxis)));
fprintf('  （净轴每鼠只用 %s 个 AO / %s 个 LO 未舔试次）\n', ...
	num2str(round(mean(T.nAO_clean(T.nAO_clean > 0)))), num2str(round(mean(T.nLO_clean(T.nLO_clean > 0)))));
fprintf('补救B（Learned-hit vs Transfer-hit，两侧都舔，再用 WaterOnly 正交化动作成分）\n');
fprintf('  r(Lrn,Trn)  原=%s  (p vs 0: %.3g)  →  正交后=%s  (p vs 0: %.3g)\n', ...
	f(T.r_raw), iSafeP(T.r_raw), f(T.r_orth), iSafeP(T.r_orth));
fprintf('  AUC(Lrn,Trn) 原=%s  →  正交后=%s  (p vs 0.5: %.3g)\n', ...
	f(T.AUC_raw), f(T.AUC_orth), iSafeP(T.AUC_orth - 0.5));
fprintf('  更严格（WaterOnly 前3主成分子空间）：r=%s (p vs 0: %.3g) | AUC=%s (p vs 0.5: %.3g) | n=%d 鼠\n', ...
	f(T.r_orth3), iSafeP(T.r_orth3), f(T.AUC_orth3), iSafeP(T.AUC_orth3 - 0.5), sum(isfinite(T.r_orth3)));
fprintf('决定性指标 d2 = r(Trn,Lrn) − r(Trn,Ctrl)：Trn 用未舔试次、Ctrl 用未学光\n');
fprintf('  d2 原=%s (p vs 0: %.3g)  →  动作子空间剔除后=%s (p vs 0: %.3g)  n=%d 鼠\n', ...
	f(T.d2_raw), iSafeP(T.d2_raw), f(T.d2_orth), iSafeP(T.d2_orth), sum(isfinite(T.d2_orth)));

%% ========== local ==========
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

function [M, b] = iMat(DS, nts, cells, iW)
M = []; b = [];
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
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(nT, 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end

function p = iProj(M, w)
if isempty(M) || isempty(w), p = []; return; end
p = (w(:).' * M).';
end

function a = iAUC(x, y)
x = x(isfinite(x)); y = y(isfinite(y));
if isempty(x) || isempty(y), a = NaN; return; end
allv = [x(:); y(:)]; r = tiedrank(allv);
nx = numel(x); ny = numel(y);
a = (sum(r(1:nx)) - nx*(nx+1)/2) / (nx*ny);
end

function r = iCorr(a, b)
a = a(:); b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 10, r = NaN; return; end
a = a(ok); b = b(ok);
if std(a) == 0 || std(b) == 0, r = NaN; return; end
c = corrcoef(a, b); r = c(1, 2);
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
