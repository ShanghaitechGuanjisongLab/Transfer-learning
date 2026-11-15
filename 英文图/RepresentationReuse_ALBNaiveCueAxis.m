% 表征复用（第八步）：把 LAI 的"线索身份轴"分析搬到 ALB 自己的 Naive 阶段
%
% 动机：LAI 的 AUC=0.70 只能说明"穿插队列里线索身份与动作可分离"，不能直接外推到迁移范式
%   （另一个数据集、另一种范式，且"无动作"是设计出来的而非行为失败）。
%   本脚本把同样的分析放进 **ALB 自己** 的 Naive 阶段 —— 同一队列、同一成像条件。
%
% ALB Naive 的实际结构（实测）：
%   上午 session：LightOnly(LO, 无强化) + AudioOnly(AO, 无强化) [+ WaterOnly(WO, 无线索只给水)]
%   晚上 session：AudioWater(AW, 学会中的声线索)
%   ⇒ 光/声身份轴可在"完全没有给水、没有舔"的 LO vs AO 上定义（构造上即与动作无关）
%     动作对照 = WO vs (LO∪AO)，同 session
%     跨 session 推广 = 把晚上的 AW 投影到该轴
%
% 读出：
%   (1) 2 折交叉验证 AUC（轴在一半试次上定，另一半上测，避免过拟合）
%   (2) 描述性分解：‖Δcue‖² = ‖v(AO)−v(LO)‖²（纯线索）
%                ‖Δact‖² = ‖v(WO) − (v(AO)+v(LO))/2‖²（动作/结局）
%
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
win = struct();
win(1).Name = "wA 0-1.5s";   win(1).Mask = tAll >= 0   & tAll <= 1.5;
win(2).Name = "w1 0.5-1.5s"; win(2).Mask = tAll >= 0.5 & tAll <= 1.5;
nPerm = 300;  rng(20261112, 'twister');

DS = TransferLearning.AudioLightBaseline();
TT = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
TT.Mouse = string(TT.Mouse); TT.Phase = string(TT.Phase); TT.Stimulus = string(TT.Stimulus);
Naive = TT(TT.Phase == "Naive" & TT.Stimulus ~= "StartMonitor" & TT.Stimulus ~= "StopMonitor", :);

Rows = {};
for iw = 1:numel(win)
	fprintf('\n--- 读出窗口 %s ---\n', win(iw).Name);
	fprintf('%-9s %6s | %8s %8s | %9s %7s | %8s %8s | %8s %8s\n', ...
		'鼠', 'nCell', 'AUC训练', 'AUCcv线索', 'AUCcv动作', 'p', 'AUC(AW/LO)', 'AUC(AW/AO)', 'dCue2', 'dAct2');
	for m = unique(Naive.Mouse)'
		% 找同时含 LO 与 AO 的 session
		d0 = unique(Naive.DateTime(Naive.Mouse == m));
		best = NaT; bestN = 0;
		for k = 1:numel(d0)
			s = Naive(Naive.Mouse == m & Naive.DateTime == d0(k), :);
			n = min(sum(s.Stimulus == "LightOnly"), sum(s.Stimulus == "AudioOnly"));
			if n > bestN, bestN = n; best = d0(k); end
		end
		if isnat(best) || bestN < 5, continue; end
		nLO = iQuery(DS, m, best, "LightOnly");
		nAO = iQuery(DS, m, best, "AudioOnly");
		nWO = iQuery(DS, m, best, "WaterOnly");
		% 另一 session 的 AW
		nAW = [];
		for k = 1:numel(d0)
			if d0(k) == best, continue; end
			nAW = iQuery(DS, m, d0(k), "AudioWater");
			if ~isempty(nAW), break; end
		end
		if isempty(nLO) || isempty(nAO), continue; end

		cells = intersect(nLO.CellUID, nAO.CellUID);
		useAW = ~isempty(nAW);
		if useAW, cells = intersect(cells, nAW.CellUID); end
		useWO = ~isempty(nWO);
		if useWO, cells = intersect(cells, nWO.CellUID); end
		if numel(cells) < 50, continue; end

		BLO = iCellMat(DS, nLO, cells, win(iw).Mask);
		BAO = iCellMat(DS, nAO, cells, win(iw).Mask);
		if useWO, BWO = iCellMat(DS, nWO, cells, win(iw).Mask); else, BWO = []; end
		if useAW, BAW = iCellMat(DS, nAW, cells, win(iw).Mask); else, BAW = []; end

		% ---- 2 折交叉验证 ----
		i1 = 1:2:size(BAO, 2); i2 = 2:2:size(BAO, 2);
		j1 = 1:2:size(BLO, 2); j2 = 2:2:size(BLO, 2);
		if isempty(i2) || isempty(j2), continue; end
		aucTrV = nan(2, 1); aucCue = nan(2, 1); aucAct = nan(2, 1);
		for f = 1:2
			if f == 1, aTr = i1; aTe = i2; lTr = j1; lTe = j2;
			else,      aTr = i2; aTe = i1; lTr = j2; lTe = j1; end
			w = mean(BAO(:, aTr), 2, 'omitnan') - mean(BLO(:, lTr), 2, 'omitnan');
			if norm(w) == 0, continue; end
			pAO = iProj(BAO(:, aTe), w);
			pLO = iProj(BLO(:, lTe), w);
			aucCue(f) = iAUC(pAO, pLO);
			aucTrV(f) = iAUC(iProj(BAO(:, aTr), w), iProj(BLO(:, lTr), w));
			if useWO
				pWO = iProj(BWO, w);
				aucAct(f) = iAUC(pWO, [pAO; pLO]);
			end
		end
		aucCue = mean(aucCue, 'omitnan');
		aucTrain = mean(aucTrV, 'omitnan');
		aucAct = mean(aucAct, 'omitnan');

		% ---- 全程轴：动作对照 + 跨 session 推广 ----
		wFull = mean(BAO, 2, 'omitnan') - mean(BLO, 2, 'omitnan');
		pAct = NaN;
		if useWO
			pAct = iPermAUC(iProj(BWO, wFull), iProj([BAO, BLO], wFull), nPerm);
		end
		aucAWLO = NaN; aucAWAO = NaN;
		if useAW
			pAW = iProj(BAW, wFull);
			aucAWLO = iAUC(pAW, iProj(BLO, wFull));
			aucAWAO = iAUC(pAW, iProj(BAO, wFull));
		end

		% ---- 描述性分解 ----
		vLO = mean(BLO, 2, 'omitnan'); vAO = mean(BAO, 2, 'omitnan');
		ssCue = norm(vAO - vLO)^2;
		ssAct = NaN;
		if useWO, ssAct = norm(mean(BWO, 2, 'omitnan') - (vAO + vLO)/2)^2; end

		fprintf('%-9s %6d | %8.2f %8.2f | %9.2f %7.3f | %8.2f %8.2f | %8.0f %8.0f\n', string(m), numel(cells), ...
			aucTrain, aucCue, aucAct, pAct, aucAWLO, aucAWAO, ssCue, ssAct);
		Rows(end+1, :) = {string(win(iw).Name), string(m), numel(cells), size(BAO, 2), size(BLO, 2), ...
			size(BWO, 2), size(BAW, 2), aucTrain, aucCue, aucAct, pAct, aucAWLO, aucAWAO, ssCue, ssAct}; %#ok<SAGROW>
	end
end

T = cell2table(Rows, 'VariableNames', ["Window", "Mouse", "NCells", "nAO", "nLO", "nWO", "nAW", ...
	"AUC_train", "AUC_cue_cv", "AUC_actionctl_cv", "p_actionctl", "AUC_AW_LO", "AUC_AW_AO", "SS_cue", "SS_act"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_ALBNaiveCueAxis.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠，均值 ± SEM）===============\n');
fprintf('AUC_cue_cv   = 用 AO vs LO（都无给水、不舔）定轴后留出试次上的判别力\n');
fprintf('AUC_actionctl= 同一根轴区分 WaterOnly 与线索类的力（应 ≈0.5）\n');
for iw = 1:numel(win)
	sel = strcmp(T.Window, win(iw).Name);
	if ~any(sel), continue; end
	s = sel & isfinite(T.AUC_cue_cv);
	sa = sel & isfinite(T.AUC_actionctl_cv);
	sl = sel & isfinite(T.AUC_AW_LO);
	so = sel & isfinite(T.AUC_AW_AO);
	fprintf('%-13s n=%2d | AUC_cue_cv=%.2f±%.2f (p=%.3g) | AUC_actionctl=%.2f±%.2f (n=%d, p=%.3g) | AUC(AW/LO)=%.2f±%.2f | AUC(AW/AO)=%.2f±%.2f (n=%d)\n', ...
		win(iw).Name, sum(s), mean(T.AUC_cue_cv(s)), std(T.AUC_cue_cv(s))/sqrt(sum(s)), ...
		iSafeP(T.AUC_cue_cv(s) - 0.5), ...
		mean(T.AUC_actionctl_cv(sa)), std(T.AUC_actionctl_cv(sa))/sqrt(max(sum(sa),1)), sum(sa), ...
		iSafeP(T.AUC_actionctl_cv(sa) - 0.5), ...
		mean(T.AUC_AW_LO(sl)), std(T.AUC_AW_LO(sl))/sqrt(max(sum(sl),1)), ...
		mean(T.AUC_AW_AO(so)), std(T.AUC_AW_AO(so))/sqrt(max(sum(so),1)), sum(so));
	sc = sel & isfinite(T.SS_cue) & isfinite(T.SS_act);
	if any(sc)
		frac = T.SS_cue(sc) ./ (T.SS_cue(sc) + T.SS_act(sc));
		fprintf('              分解 f_cue=%.2f±%.2f  f_act=%.2f±%.2f (n=%d)\n', ...
			mean(frac), std(frac)/sqrt(numel(frac)), 1-mean(frac), std(frac)/sqrt(numel(frac)), sum(sc));
	end
end

%% ========== local ==========
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

function B = iCellMat(DS, nts, cells, mask)
B = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
[~, jTu] = ismember(nts.TrialUID, Tu);
nT = numel(Tu);
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal);
B = nan(numel(cells), nT);
for i = 1:numel(cells)
	rows = find(cu == cells(i));
	if isempty(rows), continue; end
	B(i, jTu(rows)) = mean(sig(rows, mask), 2);
end
end

function p = iProj(B, w)
% 逐试次投影：B 为 细胞×试次，w 为 细胞×1 → 试次×1
if isempty(B) || isempty(w), p = []; return; end
if size(B, 1) ~= numel(w)
	error('iProj: 维度不符 B=%s w=%s', mat2str(size(B)), mat2str(size(w)));
end
p = (w(:).' * B).';
end

function a = iAUC(x, y)
x = x(isfinite(x)); y = y(isfinite(y));
if isempty(x) || isempty(y), a = NaN; return; end
allv = [x(:); y(:)]; r = tiedrank(allv);
nx = numel(x); ny = numel(y);
a = (sum(r(1:nx)) - nx*(nx+1)/2) / (nx*ny);
end

function p = iPermAUC(x, y, nPerm)
x = x(isfinite(x)); y = y(isfinite(y));
if numel(x) < 3 || numel(y) < 3, p = NaN; return; end
d0 = abs(iAUC(x, y) - 0.5);
allv = [x(:); y(:)]; nx = numel(x); cnt = 0;
for b = 1:nPerm
	idx = randperm(numel(allv));
	if abs(iAUC(allv(idx(1:nx)), allv(idx(nx+1:end))) - 0.5) >= d0, cnt = cnt + 1; end
end
p = (cnt + 1) / (nPerm + 1);
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
