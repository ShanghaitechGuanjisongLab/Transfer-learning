% 表征复用（第五步）：LAI 穿插队列的 cue vs action 分解
%
% 为什么用 LAI（光声穿插，12 只）：
%   **同一个 session 内**同时出现 5 类试次 → 同一批细胞、同一状态、同一唤醒水平、同一成像漂移，
%   这是分离 "线索身份" 与 "动作(舔/给水)" 的天然 2×2 设计：
%     LightWater / AudioWater ：线索 + 动作（已学线索通常舔）
%     LightOnly  / AudioOnly  ：线索，**无强化 → 基本不舔**（纯线索条件）
%     WaterOnly              ：无线索，只有给水 + 舔（纯动作条件）
%
% 两项分析：
%   (一) 线索身份判别轴的动作无关性
%        轴 w = mean_cells(LightWater) − mean_cells(AudioWater)（已学、含动作，分离最强）
%        → 用**同一根轴**去投影 **LightOnly vs AudioOnly**（无动作）：若仍显著分离，
%          说明"线索身份表征"在没有动作的试次里依然存在。
%        对照：用同一根轴投影 WaterOnly，不应分离（证明 w 不是动作轴）。
%        null 用标签置换（B 次），报告逐鼠 AUC 与置换 p。
%   (二) 群体响应的加性方差分解（描述性、无模型）
%        令 v(*) 为某条件下跨细胞的平均响应向量（读出窗口均值），定义
%          SS_cue  = ½(‖v(LW)−v(AW)‖² + ‖v(LO)−v(AO)‖²)          固定动作状态，比较两种线索
%          SS_act  = ½(‖v(LW)−v(LO)‖² + ‖v(AW)−v(AO)‖²)          固定线索身份，比较有无动作
%          SS_int  = ‖(v(LW)−v(AW)) − (v(LO)−v(AO))‖² / 2        线索轴是否随动作改变
%        报告三者占总和的比例 —— 直接回答 "有多少表征变化与动作无关"。
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
win(1).Name = "wA 0-1.5s";     win(1).Mask = tAll >= 0   & tAll <= 1.5;
win(2).Name = "w1 0.5-1.5s";   win(2).Mask = tAll >= 0.5 & tAll <= 1.5;

nPerm  = 400;
rng(20261112, 'twister');
phases = ["Recall", "Transfer", "Final"];      % 已学之后（Naive 阶段 LightWater 尚未学会）
stim   = struct('LW', "LightWater", 'AW', "AudioWater", ...
                'LO', "LightOnly",  'AO', "AudioOnly", 'WO', "WaterOnly");

DS = TransferLearning.LAInterspersed();
TT = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus", "Behavior"]);
TT.Mouse = string(TT.Mouse); TT.Phase = string(TT.Phase); TT.Stimulus = string(TT.Stimulus);

A = table();
Dec = table();          % 方差分解
PermRows = table();

mice = unique(TT.Mouse);
for im = 1:numel(mice)
	m = mice(im);
	for ip = 1:numel(phases)
		ph = phases(ip);
		sel = TT.Mouse == m & TT.Phase == ph;
		if ~any(sel), continue; end
		dts = unique(TT.DateTime(sel));
		for idt = 1:numel(dts)
			dt = dts(idt);
			% 该 session 内取五条件
			nts = struct();
			for fn = ["LW", "AW", "LO", "AO", "WO"]
				nts.(fn) = iQuery(DS, m, dt, stim.(fn));
				if isempty(nts.(fn)), nts.(fn) = []; end
			end
			if any(structfun(@isempty, nts)), continue; end
			cells = nts.LW.CellUID;
			for fn = ["AW", "LO", "AO", "WO"]
				cells = intersect(cells, nts.(fn).CellUID);
			end
			if numel(cells) < 50, continue; end

			for iw = 1:numel(win)
				% 每条件：细胞 × 试次 → 细胞级条件均值（试次平均）
				V = struct();  B = struct();
				for fn = ["LW", "AW", "LO", "AO", "WO"]
					[V.(fn), B.(fn)] = iCondVec(nts.(fn), cells, win(iw).Mask);
				end
				% ---- (一) 判别轴的跨条件推广 ----
				w = V.LW - V.AW;                       % 线索身份轴（用含动作的已学线索定义）
				if norm(w) == 0, continue; end
				pLW = B.LW.' * w;  pAW = B.AW.' * w;   % 逐试次投影（细胞 × 试次 → 试次 × 1）
				pLO = B.LO.' * w;  pAO = B.AO.' * w;
				pWO = B.WO.' * w;
				aucTrain = iAUC(pLW, pAW);
				aucNoAct = iAUC(pLO, pAO);             % 关键：无动作条件下的线索分离
				aucAct   = iAUC(pWO, [pLO; pAO]);      % 动作对照（应 ≈0.5）
				p1 = iPermAUC(pLO, pAO, nPerm);
				p2 = iPermAUC(pWO, [pLO; pAO], nPerm);
				Dec(end+1, :) = {string(m), string(ph), string(win(iw).Name), numel(cells), ...
					size(B.LW, 2), size(B.AW, 2), size(B.LO, 2), size(B.AO, 2), size(B.WO, 2), ...
					aucTrain, aucNoAct, p1, aucAct, p2}; %#ok<SAGROW>
				% ---- (二) 加性方差分解 ----
				sCue = 0.5*(norm(V.LW - V.AW)^2 + norm(V.LO - V.AO)^2);
				sAct = 0.5*(norm(V.LW - V.LO)^2 + norm(V.AW - V.AO)^2);
				sInt = 0.5*norm((V.LW - V.AW) - (V.LO - V.AO))^2;
				tot  = sCue + sAct + sInt;
				A(end+1, :) = {string(m), string(ph), string(win(iw).Name), numel(cells), ...
					sCue, sAct, sInt, sCue/tot, sAct/tot, sInt/tot}; %#ok<SAGROW>
			end
		end
	end
end

A.Properties.VariableNames = ["Mouse", "Phase", "Window", "NCells", ...
	"SS_Cue", "SS_Act", "SS_Int", "Frac_Cue", "Frac_Act", "Frac_Int"];
Dec.Properties.VariableNames = ["Mouse", "Phase", "Window", "NCells", ...
	"nLW", "nAW", "nLO", "nAO", "nWO", "AUC_Train", "AUC_NoAction", "p_NoAction", ...
	"AUC_ActionCtrl", "p_ActionCtrl"];

writetable(Dec, fullfile(thisDir, 'RepresentationReuse_CueVsAction_LAI_AUC.csv'));
writetable(A,   fullfile(thisDir, 'RepresentationReuse_CueVsAction_LAI_VarDecomp.csv'));

%% ---------------- 报告 ----------------
fprintf('\n=============== (一) 线索身份轴能否在"无动作"条件下推广 ===============\n');
fprintf('%-9s %-9s %-12s %5s %10s %12s %8s %12s %8s\n', ...
	'鼠', 'Phase', '窗口', 'nCell', 'AUC训练', 'AUC(无动作)', 'p', 'AUC(纯动作)', 'p');
for i = 1:height(Dec)
	fprintf('%-9s %-9s %-12s %5d %10.2f %12.2f %8.3f %12.2f %8.3f\n', ...
		Dec.Mouse(i), Dec.Phase(i), Dec.Window(i), Dec.NCells(i), ...
		Dec.AUC_Train(i), Dec.AUC_NoAction(i), Dec.p_NoAction(i), ...
		Dec.AUC_ActionCtrl(i), Dec.p_ActionCtrl(i));
end

fprintf('\n--- 组水平（逐 session 配对）---\n');
for iw = 1:numel(win)
	sel = strcmp(Dec.Window, win(iw).Name);
	if ~any(sel), continue; end
	u = unique(Dec.Mouse(sel));
	d1 = nan(numel(u), 1); d2 = nan(numel(u), 1);
	for i = 1:numel(u)
		s = sel & Dec.Mouse == u(i);
		d1(i) = mean(Dec.AUC_NoAction(s), 'omitnan');
		d2(i) = mean(Dec.AUC_ActionCtrl(s), 'omitnan');
	end
	ok = isfinite(d1);
	fprintf('%-12s n=%2d session=%2d | AUC(无动作 线索判别)=%.2f±%.2f p=%.3g | AUC(纯动作 对照)=%.2f±%.2f p=%.3g\n', ...
		win(iw).Name, sum(sel), sum(ok), mean(d1(ok)), std(d1(ok))/sqrt(sum(ok)), iSafeP(d1(ok)-0.5), ...
		mean(d2(isfinite(d2))), std(d2(isfinite(d2)))/sqrt(sum(isfinite(d2))), iSafeP(d2(isfinite(d2))-0.5));
end

fprintf('\n=============== (二) 群体响应方差分解（线索 vs 动作 vs 交互）===============\n');
fprintf('%-9s %-9s %-12s %6s %8s %8s %8s | %8s %8s %8s\n', ...
	'鼠', 'Phase', '窗口', 'nCell', 'SS_Cue', 'SS_Act', 'SS_Int', 'f_Cue', 'f_Act', 'f_Int');
for i = 1:height(A)
	fprintf('%-9s %-9s %-12s %6d %8.2f %8.2f %8.2f | %8.2f %8.2f %8.2f\n', ...
		A.Mouse(i), A.Phase(i), A.Window(i), A.NCells(i), ...
		A.SS_Cue(i), A.SS_Act(i), A.SS_Int(i), A.Frac_Cue(i), A.Frac_Act(i), A.Frac_Int(i));
end
fprintf('\n--- 组水平比例（均值 ± SEM，按 session）---\n');
for iw = 1:numel(win)
	sel = strcmp(A.Window, win(iw).Name);
	if ~any(sel), continue; end
	fprintf('%-12s n=%2d | f_Cue=%.2f±%.2f  f_Act=%.2f±%.2f  f_Int=%.2f±%.2f\n', ...
		win(iw).Name, sum(sel), ...
		mean(A.Frac_Cue(sel)), std(A.Frac_Cue(sel))/sqrt(sum(sel)), ...
		mean(A.Frac_Act(sel)), std(A.Frac_Act(sel))/sqrt(sum(sel)), ...
		mean(A.Frac_Int(sel)), std(A.Frac_Int(sel))/sqrt(sum(sel)));
end

%% ========== local ==========
function nts = iQuery(DS, mouse, dt, stim)
nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), UniExp.Flags.ZScore, 1:24);
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
end

function [v, B] = iCondVec(nts, cells, mask)
% 细胞级条件均值（跨试次平均）与逐试次矩阵（细胞 × 试次）
nC = numel(cells);
B = nan(nC, 0);
if isempty(nts), v = nan(nC, 1); return; end
cu = uint64(nts.CellUID);
nu = numel(unique(nts.TrialUID));
B = nan(nC, nu);
sig = double(nts.TrialSignal);
Tu = unique(nts.TrialUID, 'stable');
[~, jTu] = ismember(nts.TrialUID, Tu);
for i = 1:nC
	rows = find(cu == cells(i));
	if isempty(rows), continue; end
	B(i, jTu(rows)) = mean(sig(rows, mask), 2);
end
v = mean(B, 2, 'omitnan');
end

function a = iAUC(x, y)
% rank-based AUC：P(x > y) + 0.5 P(x == y)
x = x(isfinite(x)); y = y(isfinite(y));
if isempty(x) || isempty(y), a = NaN; return; end
allv = [x(:); y(:)]; r = tiedrank(allv);
rx = sum(r(1:numel(x))); nx = numel(x); ny = numel(y);
a = (rx - nx*(nx+1)/2) / (nx*ny);
end

function p = iPermAUC(x, y, nPerm)
% 标签置换检验：AUC 偏离 0.5 的显著性
x = x(isfinite(x)); y = y(isfinite(y));
if numel(x) < 3 || numel(y) < 3, p = NaN; return; end
a0 = iAUC(x, y);
d0 = abs(a0 - 0.5);
allv = [x(:); y(:)]; nx = numel(x);
cnt = 0;
for b = 1:nPerm
	idx = randperm(numel(allv));
	a = iAUC(allv(idx(1:nx)), allv(idx(nx+1:end)));
	if abs(a - 0.5) >= d0, cnt = cnt + 1; end
end
p = (cnt + 1) / (nPerm + 1);
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
