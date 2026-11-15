% 表征复用（第二版，加"未学线索"对照）：LightOnly / AudioOnly vs Transfer
%
% 问题：上一版发现 Learned ensemble 在 **Naive（同为 AW 线索）** 上就已经更活跃，
%       因此"Transfer 高活跃"可能只是"这些细胞本来更容易被线索驱动"。
% 本脚本改用**同模态但从未被强化过的线索**作对照：
%   ALB（声→光）：ensemble = Learned 的 AudioWater 活跃细胞；
%                 对照线索 = Naive 校准场的 **LightOnly**（光单独呈现、无给水，从未学过）
%                 目标     = Transfer 的 LightWater
%   LAB（光→声）：ensemble = Learned 的 LightWater 活跃细胞；
%                 对照线索 = Naive 校准场的 **AudioOnly**；目标 = Transfer 的 AudioWater
%   ⇒ 若 "Transfer ≫ LightOnly/AudioOnly"，说明 ensemble 对新线索的响应是**学会之后/迁移时才出现**的，
%     而不是细胞本身的泛反应性。
%
% 活跃定义：对每细胞的**逐回合**窗口均值做单样本 t 检验（vs 0，z 已按 cue 前 3 s 基线归一），t > 2.5
% 两个读出窗口：w1 = 0.5–1.5 s（含舔/给水）；w2 = 0–0.25 s（舔前）
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧 —— 与项目论文口径一致

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

tAll = linspace(-3, 3, 48)';
win = struct();
win(1).Name = "w1 0.5-1.5s";  win(1).Mask = tAll >= 0.5 & tAll <= 1.5;
win(2).Name = "w2 0-0.25s";   win(2).Mask = tAll >= 0 & tAll <= 0.25;
win(3).Name = "w3 0.1-0.5s";  win(3).Mask = tAll >= 0.1 & tAll <= 0.5;
tThr = 2.5;

cfg = struct();
cfg(1).Name = "ALB 声→光"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(1).Learn = struct('Phase', "Learned",  'Stimulus', "AudioWater");
cfg(1).Tran  = struct('Phase', "Transfer", 'Stimulus', "LightWater");
cfg(1).Ctrl  = struct('Phase', "Naive",    'Stimulus', "LightOnly");
cfg(1).CtrlLabel = "LightOnly(未学光)";
cfg(2).Name = "LAB 光→声"; cfg(2).DS = TransferLearning.LightAudioBaseline();
cfg(2).Learn = struct('Phase', "Learned",  'Stimulus', "LightWater");
cfg(2).Tran  = struct('Phase', "Transfer", 'Stimulus', "AudioWater");
cfg(2).Ctrl  = struct('Phase', "Naive",    'Stimulus', "AudioOnly");
cfg(2).CtrlLabel = "AudioOnly(未学声)";

Rows = {};
for ic = 1:2
	DS = cfg(ic).DS;
	getKey = @(q) iFirstSession(DS, q);
	[dtL, kL] = getKey(cfg(ic).Learn);
	[dtT, kT] = getKey(cfg(ic).Tran);
	[dtC, kC] = getKey(cfg(ic).Ctrl);
	mice = intersect(intersect(kL.Mouse, kT.Mouse), kC.Mouse);
	fprintf('\n=============== %s：三条件齐全 %d 鼠 ===============\n', cfg(ic).Name, numel(mice));

	% 收集每鼠三条件的 逐细胞 t 统计
	Store = struct('mouse', {}, 'ens', {}, 'rate', {}, 'cells', {});
	for im = 1:numel(mice)
		m = mice(im);
		sel = @(T, dt) T.Mouse == m;
		if isempty(dtL) || ~any(sel(kL, 0)), continue; end
		iL = find(sel(kL, 0), 1); iT = find(sel(kT, 0), 1); iC = find(sel(kC, 0), 1);
		if isempty(iT) || isempty(iC), continue; end
		nL = iQuery(DS, m, dtL(iL), cfg(ic).Learn.Stimulus);
		nT = iQuery(DS, m, dtT(iT), cfg(ic).Tran.Stimulus);
		nC = iQuery(DS, m, dtC(iC), cfg(ic).Ctrl.Stimulus);
		if isempty(nL) || isempty(nT) || isempty(nC), continue; end
		cells = intersect(intersect(nL.CellUID, nT.CellUID), nC.CellUID);
		if numel(cells) < 50, continue; end
		Store(im).mouse = m; %#ok<SAGROW>
		Store(im).cells = cells;
		Store(im).tab = {nL, nT, nC};
	end
	Store = Store(~cellfun(@isempty, {Store.mouse}));
	if isempty(Store), fprintf('   （无可用鼠）\n'); continue; end

	for iw = 1:numel(win)
		fprintf('--- 读出窗口 %s ---\n', win(iw).Name);
		fprintf('%-9s %11s %18s %18s %18s\n', '鼠', 'Learned活跃%', ...
			[char(cfg(ic).CtrlLabel) ' ens/ctl'], 'Transfer ens/ctl', 'Learned ens/ctl');
		for im = 1:numel(Store)
			cells = Store(im).cells;
			tt = cell(1, 3);                     % 1=Learned, 2=Transfer, 3=Ctrl
			for k = 1:3
				tt{k} = iCellT(Store(im).tab{k}, cells, win(iw).Mask);
			end
			ens = tt{1} > tThr;
			if ~any(ens), continue; end
			r = nan(3, 2);
			for k = 1:3
				r(k, 1) = mean(tt{k}(ens) > tThr);
				if any(~ens), r(k, 2) = mean(tt{k}(~ens) > tThr); end
			end
			fprintf('%-9s %11.1f %8.1f/%-8.1f %9.1f/%-8.1f %9.1f/%-8.1f\n', string(Store(im).mouse), ...
				100*mean(ens), 100*r(3,1), 100*r(3,2), 100*r(2,1), 100*r(2,2), 100*r(1,1), 100*r(1,2));
			Rows(end+1, :) = {char(cfg(ic).Name), char(win(iw).Name), char(string(Store(im).mouse)), 100*mean(ens), ...
				100*r(3,1), 100*r(3,2), 100*r(2,1), 100*r(2,2), 100*r(1,1), 100*r(1,2)}; %#ok<SAGROW>
		end
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Window", "Mouse", "EnsPct", ...
	"CtrlEnsPct", "CtrlCtlPct", "TranEnsPct", "TranCtlPct", "LearnEnsPct", "LearnCtlPct"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_ControlCue.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠配对，均值 ± SEM）===============\n');
fprintf('关键：Transfer(ens) − Ctrl(ens) —— 同一批 ensemble 细胞，对新线索"迁移后 vs 从未学过"\n');
for ic = 1:2
	for iw = 1:numel(win)
		sel = strcmp(T.Cohort, cfg(ic).Name) & strcmp(T.Window, win(iw).Name);
		if ~any(sel), continue; end
		dTC = T.TranEnsPct(sel) - T.CtrlEnsPct(sel);
		dTe = T.TranEnsPct(sel) - T.TranCtlPct(sel);
		dCe = T.CtrlEnsPct(sel) - T.CtrlCtlPct(sel);
		fprintf('%-11s %-13s n=%2d | Tran−Ctrl(ens)=%+6.1f±%4.1f p=%.3g | Tran(ens−ctl)=%+6.1f±%4.1f p=%.3g | Ctrl(ens−ctl)=%+6.1f±%4.1f p=%.3g\n', ...
			cfg(ic).Name, win(iw).Name, sum(sel), mean(dTC), std(dTC)/sqrt(sum(sel)), iSafeP(dTC), ...
			mean(dTe), std(dTe)/sqrt(sum(sel)), iSafeP(dTe), mean(dCe), std(dCe)/sqrt(sum(sel)), iSafeP(dCe));
	end
end

%% ========== local ==========
function [dts, T] = iFirstSession(DS, q)
% 该 Phase/Stimulus 下，每鼠最早会话的 DateTime
T = DS.TableQuery(["Mouse", "DateTime"]);
T.Mouse = string(T.Mouse);
tq = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
tq.Mouse = string(tq.Mouse); tq.Stimulus = string(tq.Stimulus); tq.Phase = string(tq.Phase);
keep = tq.Phase == q.Phase & tq.Stimulus == q.Stimulus;
tq = tq(keep, :);
dts = NaT(0, 1); T = table(strings(0, 1), NaT(0, 1), 'VariableNames', {'Mouse', 'DateTime'});
u = unique(tq.Mouse);
for i = 1:numel(u)
	d = sort(unique(tq.DateTime(tq.Mouse == u(i))));
	if isempty(d), continue; end
	dts(end+1, 1) = d(1); %#ok<AGROW>
	T(end+1, :) = {u(i), d(1)}; %#ok<AGROW>
end
end

function nts = iQuery(DS, mouse, dt, stim)
nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), UniExp.Flags.ZScore, 1:24);
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
end

function tStat = iCellT(nts, cells, mask)
% 每细胞：逐回合窗口均值 → 对回合做单样本 t（vs 0）
tStat = nan(numel(cells), 1);
for i = 1:numel(cells)
	rows = nts.CellUID == cells(i);
	if ~any(rows), continue; end
	X = double(nts.TrialSignal(rows, :));
	w = mean(X(:, mask), 2, 'omitnan');
	w = w(isfinite(w));
	if numel(w) < 3, continue; end
	s = std(w) / sqrt(numel(w));
	if s == 0, continue; end
	tStat(i) = mean(w) / s;
end
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
