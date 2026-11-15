% 表征复用（第九步）：把 Naive 里"无动作"定义的模态轴，拿到 Learned / Transfer 期去读
%
% 逻辑链：
%   第 8 步已在 ALB Naive 内证明：光/声模态轴可以在**零给水、零舔**的 AudioOnly vs LightOnly 上
%   定义并交叉验证地读出（AUC 0.71），且同一根轴不编码动作（WaterOnly 对照 AUC 0.52）。
%   本步把**同一根轴**（w = AO − LO，构造上与动作无关）拿去投影 Learned/AudioWater 与
%   Transfer/LightWater，看迁移期还能不能读出"这是光还是声"。
%
%   ⚠ 这一步的结论只能这样表述：
%     "存在一根在无动作条件下定义的模态轴，它在迁移期仍能读出线索身份"
%     不能说成"迁移期复用了学会表征"（模态轴在学会之前就存在，不是学习产物）；
%     也不能完全排除跨 session 的整体偏移（每个 session 只有一种线索，无法在 session 内居中）。
%     缓解手段：逐鼠看符号一致性 + 对称对照（光应当落在"光端"、声应当落在"声端"）。
%
% 读出：
%   AUC(AW@Learned vs LW@Transfer) —— 迁移期模态可分性（主指标，应 ≫0.5）
%   AUC(AW@Learned vs LO@Naive)    —— 声应高于光（正向对照）
%   AUC(LW@Transfer vs AO@Naive)   —— 光应低于声（反向对照，应 ≪0.5）
%   ALB 与 V7（7 天）都算，用于回答"7 天后丢的是感觉编码还是联想"
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

cfg = struct();
cfg(1).Name = "ALB 声→光 即时"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(2).Name = "V7 声→光 7天";  cfg(2).DS = TransferLearning.Vacation7();

Rows = {};
for ic = 1:2
	DS = cfg(ic).DS;
	fprintf('\n=============== %s ===============\n', cfg(ic).Name);
	for iw = 1:numel(win)
		fprintf('--- 窗口 %s ---\n', win(iw).Name);
			fprintf('%-9s %6s %6s | %9s | %9s %9s | %9s %9s %9s\n', ...
				'鼠', 'nCell', 'nTrn', 'AW/LW', 'AW/LO', 'LW/AO', 'AW/LWmiss', 'AW/LWhit', 'nMiss');
		for m = unique(iMouse(DS))'
			% —— Naive 里定轴：需要同一 session 的 LO 与 AO
			[dts, stim] = iList(DS, m);
			isN = stim == "LightOnly"; isA = stim == "AudioOnly";
			best = NaT; bestN = 0;
			for k = unique(dts(isN))'
				n = min(sum(dts == k & isN), sum(dts == k & isA));
				if n > bestN, bestN = n; best = k; end
			end
			if isnat(best) || bestN < 5
				fprintf('  [跳过] %-9s 无同时含 LO/AO 的 Naive session（bestN=%d）\n', string(m), bestN);
				continue;
			end
			nLO = iQuery(DS, m, best, "LightOnly");
			nAO = iQuery(DS, m, best, "AudioOnly");
			nWO = iQuery(DS, m, best, "WaterOnly");
			% —— Learned / Transfer
			dtL = iFirst(DS, m, "Learned", "AudioWater");
			dtT = iFirst(DS, m, "Transfer", "LightWater");
			if isnat(dtL) || isnat(dtT)
				fprintf('  [跳过] %-9s Learned=%s Transfer=%s\n', string(m), string(dtL), string(dtT));
				continue;
			end
			nAW = iQuery(DS, m, dtL, "AudioWater");
			nLW = iQuery(DS, m, dtT, "LightWater");
			if any(cellfun(@isempty, {nLO, nAO, nAW, nLW}))
				fprintf('  [跳过] %-9s LO=%d AO=%d AW=%d LW=%d  （空=QueryNTS 失败或无试次）\n', ...
					string(m), ~isempty(nLO), ~isempty(nAO), ~isempty(nAW), ~isempty(nLW));
				continue;
			end

			cells = intersect(intersect(nLO.CellUID, nAO.CellUID), ...
				intersect(nAW.CellUID, nLW.CellUID));
			if ~isempty(nWO), cells = intersect(cells, nWO.CellUID); end
			if numel(cells) < 50
				fprintf('  [跳过] %-9s 共同细胞只有 %d\n', string(m), numel(cells));
				continue;
			end

			BLO = iCellMat(DS, nLO, cells, win(iw).Mask);
			BAO = iCellMat(DS, nAO, cells, win(iw).Mask);
			BAW = iCellMat(DS, nAW, cells, win(iw).Mask);
			BLW = iCellMat(DS, nLW, cells, win(iw).Mask);
			w = mean(BAO, 2, 'omitnan') - mean(BLO, 2, 'omitnan');
			if norm(w) == 0, continue; end

			pAO = iProj(BAO, w); pLO = iProj(BLO, w);
			pAW = iProj(BAW, w); pLW = iProj(BLW, w);

			a1 = iAUC(pAW, pLW);   % 主指标
			a2 = iAUC(pAW, pLO);
			a3 = iAUC(pLW, pAO);
			a4 = iAUC(pAW, pAO);
			% 关键控制：LW 只用未舔试次 / 只用舔了的试次
			bLW = iBeh(DS, nLW);
			nM = 0; a1m = NaN; a1h = NaN;
			if numel(bLW) == numel(pLW)
				nM = sum(bLW == 0);
				if nM >= 3, a1m = iAUC(pAW, pLW(bLW == 0)); end
				if sum(bLW == 1) >= 3, a1h = iAUC(pAW, pLW(bLW == 1)); end
			end

			fprintf('%-9s %6d %6d | %9.2f | %9.2f %9.2f | %9.2f %9.2f %9d\n', string(m), numel(cells), ...
				numel(pLW), a1, a2, a3, a1m, a1h, nM);
			Rows(end+1, :) = {string(cfg(ic).Name), string(win(iw).Name), string(m), numel(cells), ...
				numel(pAW), numel(pLW), a1, a2, a3, a4, a1m, a1h, nM}; %#ok<SAGROW>
		end
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Window", "Mouse", "NCells", "nAW", "nLW", ...
	"AUC_AW_LW", "AUC_AW_LO", "AUC_LW_AO", "AUC_AW_AO", "AUC_AW_LWmiss", "AUC_AW_LWhit", "nLWmiss"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_NaiveAxisToTransfer.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠均值 ± SEM；括号内为 AUC>0.5 的鼠数）===============\n');
for ic = 1:2
	for iw = 1:numel(win)
		sel = strcmp(T.Cohort, cfg(ic).Name) & strcmp(T.Window, win(iw).Name);
		if sum(sel) < 3, continue; end
		n = sum(sel);
		fprintf('%-16s %-13s n=%2d | 主: AW/LW=%.2f±%.2f (%d/%d, p=%.3g) | AW/LWmiss=%.2f±%.2f (%d/%d, p=%.3g) | AW/LWhit=%.2f | AW/LO=%.2f | LW/AO=%.2f\n', ...
			cfg(ic).Name, win(iw).Name, n, ...
			mean(T.AUC_AW_LW(sel)), std(T.AUC_AW_LW(sel))/sqrt(n), sum(T.AUC_AW_LW(sel) > 0.5), n, ...
			iSafeP(T.AUC_AW_LW(sel) - 0.5), ...
			mean(T.AUC_AW_LWmiss(sel), 'omitnan'), std(T.AUC_AW_LWmiss(sel), 'omitnan')/sqrt(sum(isfinite(T.AUC_AW_LWmiss(sel)))), ...
			sum(T.AUC_AW_LWmiss(sel) > 0.5), sum(isfinite(T.AUC_AW_LWmiss(sel))), ...
			iSafeP(T.AUC_AW_LWmiss(sel) - 0.5), ...
			mean(T.AUC_AW_LWhit(sel), 'omitnan'), ...
			mean(T.AUC_AW_LO(sel)), mean(T.AUC_LW_AO(sel)));
	end
end

%% ========== local ==========
function u = iMouse(DS)
% ⚠ 不能只用 TableQuery(["Mouse"])：它会解析到含 Mouse 的最小表，V7 那里只给出 2 只鼠
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

function b = iBeh(DS, nts)
b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(numel(Tu), 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end

function p = iProj(B, w)
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

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
