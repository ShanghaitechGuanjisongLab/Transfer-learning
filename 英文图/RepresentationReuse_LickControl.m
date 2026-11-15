% 表征复用（第三步：舔/动作控制）—— 用 hit/miss 标签做"无动作"对照
%
% 问题：上一版 ensemble 是在 **Learned（AudioWater / LightWater）** 上定义的，
%       而 Learned 阶段这些线索的 hit rate ≈ 1.0（几乎每试次都舔），
%       所以 "ensemble 在 Transfer 上更活跃" 完全可能只是 "这些细胞编码舔水动作"。
%
% 本脚本用 Trials.Behavior（1=hit 舔了 / 0=miss 未舔）做三类对照：
%   all  ：全部试次（= 上一版口径，复现用）
%   miss ：只用 **未舔** 试次 → 若 ensemble 仍有响应，则该成分与动作无关
%   hit  ：只用 **舔了** 的试次 → 看动作本身能解释多少
%   ⚠ 二值预测变量下，"对舔回归后的截距"在非参数意义上等价于 miss-only 均值，
%     所以 miss 这一栏即"回归残差重算"的结果，无需另写一套 OLS。
%
% 条件（与 ControlCue 版一致）：
%   ALB 声→光：Learn=Learned/AudioWater，Tran=Transfer/LightWater，Ctrl=Naive/LightOnly
%   LAB 光→声：Learn=Learned/LightWater，Tran=Transfer/AudioWater，Ctrl=Naive/AudioOnly
%   注：Ctrl 是"同模态但从未被强化"的线索，其 hit rate ≈ 0，天然是"无舔"条件。
%
% 定义：ensemble = Learned 阶段、读出窗口内逐细胞对回合做单样本 t（vs 0）> tThr
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
win(1).Name = "w1 0.5-1.5s";   win(1).Mask = tAll >= 0.5 & tAll <= 1.5;
win(2).Name = "wA 0-1.5s";     win(2).Mask = tAll >= 0 & tAll <= 1.5;
win(3).Name = "w3 0.1-0.5s";   win(3).Mask = tAll >= 0.1 & tAll <= 0.5;
tThr  = 2.5;
nMinT = 3;

cfg = struct();
cfg(1).Name = "ALB 声→光"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(1).Learn = struct('Phase', "Learned",  'Stimulus', "AudioWater");
cfg(1).Tran  = struct('Phase', "Transfer", 'Stimulus', "LightWater");
cfg(1).Ctrl  = struct('Phase', "Naive",    'Stimulus', "LightOnly");
cfg(1).CtrlLabel = "LightOnly";
cfg(2).Name = "LAB 光→声"; cfg(2).DS = TransferLearning.LightAudioBaseline();
cfg(2).Learn = struct('Phase', "Learned",  'Stimulus', "LightWater");
cfg(2).Tran  = struct('Phase', "Transfer", 'Stimulus', "AudioWater");
cfg(2).Ctrl  = struct('Phase', "Naive",    'Stimulus', "AudioOnly");
cfg(2).CtrlLabel = "AudioOnly";

SubsetName = ["all", "miss", "hit"];
Rows = {};

for ic = 1:2
	DS = cfg(ic).DS;
	[dtL, kL] = iFirstSession(DS, cfg(ic).Learn);
	[dtT, kT] = iFirstSession(DS, cfg(ic).Tran);
	[dtC, kC] = iFirstSession(DS, cfg(ic).Ctrl);
	mice = intersect(intersect(kL.Mouse, kT.Mouse), kC.Mouse);
	fprintf('\n=============== %s：三条件齐全 %d 鼠 ===============\n', cfg(ic).Name, numel(mice));

	Store = struct('mouse', {}, 'cells', {}, 'S', {}, 'b', {});
	for im = 1:numel(mice)
		m = mice(im);
		iL = find(kL.Mouse == m, 1); iT = find(kT.Mouse == m, 1); iC = find(kC.Mouse == m, 1);
		if isempty(iL) || isempty(iT) || isempty(iC), continue; end
		nL = iQuery(DS, m, dtL(iL), cfg(ic).Learn.Stimulus);
		nT = iQuery(DS, m, dtT(iT), cfg(ic).Tran.Stimulus);
		nC = iQuery(DS, m, dtC(iC), cfg(ic).Ctrl.Stimulus);
		if isempty(nL) || isempty(nT) || isempty(nC), continue; end
		cells = intersect(intersect(nL.CellUID, nT.CellUID), nC.CellUID);
		if numel(cells) < 50, continue; end
		[SL, bL] = iCellMat(DS, nL, cells);
		[ST, bT] = iCellMat(DS, nT, cells);
		[SC, bC] = iCellMat(DS, nC, cells);
		if isempty(bL) || isempty(bT) || isempty(bC), continue; end
		Store(end+1).mouse = m; %#ok<SAGROW>
		Store(end).cells = cells;
		Store(end).S = {SL, ST, SC};        % 1=Learn 2=Tran 3=Ctrl，nCell × nTrial × 48
		Store(end).b = {bL, bT, bC};
	end
	if isempty(Store), fprintf('   （无可用鼠）\n'); continue; end

	fprintf('%-9s %-24s %-24s %-24s\n', '鼠', 'Learn n(hit%)', 'Tran n(hit%)', [cfg(ic).CtrlLabel ' n(hit%)']);
	for im = 1:numel(Store)
		s = "";
		for k = 1:3
			b = Store(im).b{k};
			s = s + sprintf('%-24s', sprintf('%d (%.2f)miss=%d', numel(b), mean(b), sum(b == 0)));
		end
		fprintf('%-9s %s\n', string(Store(im).mouse), s);
	end

	for iw = 1:numel(win)
		fprintf('\n--- 读出窗口 %s ---\n', win(iw).Name);
		fprintf('%-16s %7s | %-16s | %-16s | %-16s\n', '鼠:子集', 'ens%', ...
			[cfg(ic).CtrlLabel ' ens/ctl'], 'Tran ens/ctl', 'Learn ens/ctl');
		for im = 1:numel(Store)
			W = cell(1, 3);
			for k = 1:3, W{k} = mean(Store(im).S{k}(:, :, win(iw).Mask), 3); end
			% ensemble 定义：Learned / all trials / 该窗口
			tL0 = iTfromW(W{1}, true(size(W{1}, 2), 1), nMinT);
			ens = tL0 > tThr;
			if ~any(ens), continue; end
			res = nan(3, 3, 2);                         % sub × cond × (ens, ctl)
			for is = 1:3
				for k = 1:3
					b = Store(im).b{k};
					switch SubsetName(is)
						case "all",  keep = true(numel(b), 1);
						case "miss", keep = b == 0;
						case "hit",  keep = b == 1;
					end
					tv = iTfromW(W{k}, keep, nMinT);
					ok = isfinite(tv);
					if ~any(ok & ens), continue; end
					res(is, k, 1) = mean(tv(ok & ens) > tThr);
					if any(ok & ~ens), res(is, k, 2) = mean(tv(ok & ~ens) > tThr); end
				end
				fprintf('%-16s %6.1f | %-16s | %-16s | %-16s\n', ...
					string(Store(im).mouse) + ":" + SubsetName(is), 100*mean(ens), ...
					sprintf('%5.1f/%-5.1f', 100*res(is,3,1), 100*res(is,3,2)), ...
					sprintf('%5.1f/%-5.1f', 100*res(is,2,1), 100*res(is,2,2)), ...
					sprintf('%5.1f/%-5.1f', 100*res(is,1,1), 100*res(is,1,2)));
				Rows(end+1, :) = {char(cfg(ic).Name), char(win(iw).Name), char(SubsetName(is)), ...
					char(string(Store(im).mouse)), 100*mean(ens), ...
					100*res(is,1,1), 100*res(is,1,2), 100*res(is,2,1), 100*res(is,2,2), ...
					100*res(is,3,1), 100*res(is,3,2)}; %#ok<SAGROW>
			end
		end
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Window", "Subset", "Mouse", "EnsPct", ...
	"LearnEnsPct", "LearnCtlPct", "TranEnsPct", "TranCtlPct", "CtrlEnsPct", "CtrlCtlPct"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_LickControl.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠配对，均值 ± SEM）===============\n');
for ic = 1:2
	for iw = 1:numel(win)
		for is = 1:3
			sel = strcmp(T.Cohort, cfg(ic).Name) & strcmp(T.Window, win(iw).Name) & strcmp(T.Subset, SubsetName(is));
			if sum(sel) < 3, continue; end
			dTC = T.TranEnsPct(sel) - T.CtrlEnsPct(sel);
			dTe = T.TranEnsPct(sel) - T.TranCtlPct(sel);
			dCe = T.CtrlEnsPct(sel) - T.CtrlCtlPct(sel);
			n = sum(sel);
			fprintf('%-11s %-13s %-5s n=%2d | Tran-Ctrl(ens)=%+6.1f±%4.1f p=%.3g | Tran(ens-ctl)=%+6.1f±%4.1f p=%.3g | Ctrl(ens-ctl)=%+6.1f±%4.1f p=%.3g\n', ...
				cfg(ic).Name, win(iw).Name, SubsetName(is), n, ...
				mean(dTC), std(dTC)/sqrt(n), iSafeP(dTC), ...
				mean(dTe), std(dTe)/sqrt(n), iSafeP(dTe), ...
				mean(dCe), std(dCe)/sqrt(n), iSafeP(dCe));
		end
	end
end

fprintf('\n=============== 动作能解释多少：Transfer ens 在 miss vs hit 试次 ===============\n');
for ic = 1:2
	for iw = 1:numel(win)
		sM = strcmp(T.Cohort, cfg(ic).Name) & strcmp(T.Window, win(iw).Name) & T.Subset == "miss";
		sH = strcmp(T.Cohort, cfg(ic).Name) & strcmp(T.Window, win(iw).Name) & T.Subset == "hit";
		[ism, iM] = ismember(T.Mouse(sM), T.Mouse(sH));
		if ~any(ism), continue; end
		h = find(sH); h = h(iM(ism));
		d = T.TranEnsPct(sM); d = d(ism);
		e = T.TranEnsPct(h);
		dd = d - e; ok = isfinite(dd);
		n = sum(ok);
		if n < 3, continue; end
		fprintf('%-11s %-13s n=%2d | miss=%5.1f  hit=%5.1f  差(miss-hit)=%+6.1f±%4.1f p=%.3g\n', ...
			cfg(ic).Name, win(iw).Name, n, mean(d(ok)), mean(e(ok)), mean(dd(ok)), std(dd(ok))/sqrt(n), iSafeP(dd));
	end
end

%% ========== local ==========
function [dts, T] = iFirstSession(DS, q)
T = DS.TableQuery(["Mouse", "DateTime"]);
T.Mouse = string(T.Mouse);
tq = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
tq.Mouse = string(tq.Mouse); tq.Stimulus = string(tq.Stimulus); tq.Phase = string(tq.Phase);
tq = tq(tq.Phase == q.Phase & tq.Stimulus == q.Stimulus, :);
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
nts.TrialUID = uint64(nts.TrialUID);
end

function [S, b] = iCellMat(DS, nts, cells)
% S: nCell × nTrial × 48（z 后 TrialSignal）；b: nTrial×1 行为（1=hit）
S = []; b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
[~, jTu] = ismember(nts.TrialUID, Tu);
nT = numel(Tu); nF = width(nts.TrialSignal);
cu = uint64(nts.CellUID);
S = nan(numel(cells), nT, nF);
sig = double(nts.TrialSignal);
for i = 1:numel(cells)
	rows = find(cu == cells(i));
	if isempty(rows), continue; end
	S(i, jTu(rows), :) = reshape(sig(rows, :), 1, numel(rows), nF);
end
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
TuAll = uint64(Tr.TrialUID);
[ok, idx] = ismember(Tu, TuAll);
b = nan(nT, 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end

function tStat = iTfromW(W, keep, nMinT)
tStat = nan(size(W, 1), 1);
for i = 1:size(W, 1)
	w = W(i, keep).';
	w = w(isfinite(w));
	if numel(w) < nMinT, continue; end
	s = std(w) / sqrt(numel(w));
	if s == 0, continue; end
	tStat(i) = mean(w) / s;
end
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
