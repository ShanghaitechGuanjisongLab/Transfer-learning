% 表征复用（第六步）：跨模态迁移的"群体模式"证据 —— 动作匹配版本
%
% 前情（已跑完的三步）：
%   ① 活跃率口径的 "Transfer ensemble 更活跃" 在控制舔之后消失（ALB miss-only p=0.30）
%   ② LAI 穿插队列里，线索身份轴在"无强化、不舔"的试次上仍可分（AUC 0.70）
%   ⇒ 结论必须从"活跃率"改口到"群体模式"。
%
% 本脚本把 ② 的思路搬到 **ALB/LAB 的跨模态迁移**上（用户最初命题的直接检验）：
%
%   核心指标 = 群体模式相似度  r(a,b) = corr_cells( v_a , v_b )
%     v = 该条件下跨试次平均的 z 响应向量（读出窗口），细胞为共同细胞
%   关键对照 = **动作匹配**：
%     ALB 用 Transfer 的 **miss 试次**（无舔）去比，而对照 Ctrl = Naive/LightOnly（也无舔）
%     ⇒ 两侧舔水行为都为零，"相似度差异"不能由动作解释
%   必备校正 = **信度校正**（split-half, Spearman-Brown）：
%     条件本身信号弱时原始 r 会天然偏低，除以 sqrt(ρa·ρb) 才不会误判
%
%   条件：
%     ALB 声→光：Lrn=Learned/AudioWater，Trn=Transfer/LightWater，Ctrl=Naive/LightOnly
%     LAB 光→声：Lrn=Learned/LightWater，Trn=Transfer/AudioWater，Ctrl=Naive/AudioOnly
%   ⚠ LAB 的 Transfer hit≈0.96–1.00，几乎没有 miss 试次 → 只能出 all 版本
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
nMinTrial = 4;      % 每条件至少回合数（信度估计需要）

cfg = struct();
cfg(1).Name = "ALB 声→光"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(1).Lrn = struct('Phase', "Learned",  'Stimulus', "AudioWater");
cfg(1).Trn = struct('Phase', "Transfer", 'Stimulus', "LightWater");
cfg(1).Ctl = struct('Phase', "Naive",    'Stimulus', "LightOnly");
cfg(1).CtlLabel = "Naive LightOnly";
cfg(2).Name = "LAB 光→声"; cfg(2).DS = TransferLearning.LightAudioBaseline();
cfg(2).Lrn = struct('Phase', "Learned",  'Stimulus', "LightWater");
cfg(2).Trn = struct('Phase', "Transfer", 'Stimulus', "AudioWater");
cfg(2).Ctl = struct('Phase', "Naive",    'Stimulus', "AudioOnly");
cfg(2).CtlLabel = "Naive AudioOnly";

Subs = ["all", "miss", "hit"];
Rows = {};

for ic = 1:2
	DS = cfg(ic).DS;
	[dtL, kL] = iFirstSession(DS, cfg(ic).Lrn);
	[dtT, kT] = iFirstSession(DS, cfg(ic).Trn);
	[dtC, kC] = iFirstSession(DS, cfg(ic).Ctl);
	mice = intersect(intersect(kL.Mouse, kT.Mouse), kC.Mouse);
	fprintf('\n=============== %s：三条件齐全 %d 鼠 ===============\n', cfg(ic).Name, numel(mice));

	for iw = 1:numel(win)
		fprintf('\n--- 读出窗口 %s ---\n', win(iw).Name);
		fprintf('%-9s %6s %14s %14s %14s | %10s %10s %8s\n', ...
			'鼠', 'nCell', 'r(Trn,Lrn)', 'r(Trn,Ctrl)', 'r(Lrn,Ctrl)', 'd_all', 'd_miss', 'p');
		for im = 1:numel(mice)
			m = mice(im);
			iL = find(kL.Mouse == m, 1); iT = find(kT.Mouse == m, 1); iC = find(kC.Mouse == m, 1);
			if isempty(iL) || isempty(iT) || isempty(iC), continue; end
			nL = iQuery(DS, m, dtL(iL), cfg(ic).Lrn.Stimulus);
			nT = iQuery(DS, m, dtT(iT), cfg(ic).Trn.Stimulus);
			nC = iQuery(DS, m, dtC(iC), cfg(ic).Ctl.Stimulus);
			if isempty(nL) || isempty(nT) || isempty(nC), continue; end
			cells = intersect(intersect(nL.CellUID, nT.CellUID), nC.CellUID);
			if numel(cells) < 50, continue; end
			[BL, ~] = iCellMat(DS, nL, cells, win(iw).Mask);
			[BT, bT] = iCellMat(DS, nT, cells, win(iw).Mask);
			[BC, ~] = iCellMat(DS, nC, cells, win(iw).Mask);
			vL = mean(BL, 2, 'omitnan');
			vC = mean(BC, 2, 'omitnan');
			nc = [size(BT, 2), sum(bT == 0), sum(bT == 1)];   % all / miss / hit 回合数

			rL = iSplitHalf(BL, nMinTrial);
			rC = iSplitHalf(BC, nMinTrial);
			rT = iSplitHalf(BT, nMinTrial);

			% ---- all ----
			vT = mean(BT, 2, 'omitnan');
			res = struct();
			res.all = iTriplet(vL, vT, vC, rL, rT, rC);
			% ---- miss / hit ----
			for is = 2:3
				keep = bT == (is - 2);        % miss: bT==0 ; hit: bT==1
				if sum(keep) < nMinTrial, res.(Subs(is)) = iEmptyTriplet(); continue; end
				Bsub = BT(:, keep);
				vS = mean(Bsub, 2, 'omitnan');
				rS = iSplitHalf(Bsub, nMinTrial);
				res.(Subs(is)) = iTriplet(vL, vS, vC, rL, rS, rC);
			end

			fprintf('%-9s %6d %14s %14s %14s | %10.2f %10s %8s\n', string(m), numel(cells), ...
				sprintf('%.2f(%.2f)', res.all.rLT, res.all.cLT), ...
				sprintf('%.2f(%.2f)', res.all.rTC, res.all.cTC), ...
				sprintf('%.2f(%.2f)', res.all.rLC, res.all.cLC), ...
				res.all.d2, sprintf('%.2f', res.miss.d2), sprintf('n=%d', nc(1)));

			for is = 1:3
				R = res.(Subs(is));
				Rows(end+1, :) = {string(cfg(ic).Name), string(win(iw).Name), string(Subs(is)), ...
					string(m), numel(cells), nc(is), ...
					R.rLT, R.rTC, R.rLC, R.cLT, R.cTC, R.cLC, R.d1, R.d2}; %#ok<SAGROW>
			end
		end
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Window", "Subset", "Mouse", "NCells", "nTrn", ...
	"r_LT", "r_TC", "r_LC", "c_LT", "c_TC", "c_LC", "d1", "d2"]);
% d1 = r(Trn,Lrn) − r(Lrn,Ctrl)   ：迁移表征比未学线索更接近学会表征
% d2 = r(Trn,Lrn) − r(Trn,Ctrl)   ：对迁移而言，学会表征比未学线索更接近
csvPath = fullfile(thisDir, 'RepresentationReuse_CrossModalPattern.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);
fprintf('说明：括号内为信度校正后的相似度 c = r / sqrt(rho_a*rho_b)\n');

fprintf('\n=============== 组水平（逐鼠配对，均值 ± SEM）===============\n');
fprintf('d2 = r(Trn,Lrn) − r(Trn,Ctrl)：正 = 迁移期群体模式更像"学会的线索"而不是"未学线索"\n');
for ic = 1:2
	for iw = 1:numel(win)
		for is = 1:3
			sel = strcmp(T.Cohort, cfg(ic).Name) & strcmp(T.Window, win(iw).Name) & strcmp(T.Subset, Subs(is));
			x = T.d2(sel); x = x(isfinite(x));
			y = T.d1(sel); y = y(isfinite(y));
			if numel(x) < 3, continue; end
			n = numel(x);
			fprintf('%-11s %-13s %-5s n=%2d | d2=%+6.2f±%4.2f p=%.3g | d1=%+6.2f±%4.2f p=%.3g\n', ...
				cfg(ic).Name, win(iw).Name, Subs(is), n, ...
				mean(x), std(x)/sqrt(n), iSafeP(x), mean(y), std(y)/sqrt(numel(y)), iSafeP(y));
		end
	end
end

% 信度本身：确认三个条件的信号都不至于弱到无法比较
fprintf('\n=============== 条件信度（split-half Spearman-Brown）===============\n');
for ic = 1:2
	fprintf('%-11s 见逐鼠表；此处只提示：c_* 已按信度校正\n', cfg(ic).Name);
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

function [B, b] = iCellMat(DS, nts, cells, mask)
% B: nCell × nTrial（窗口均值）；b: nTrial×1 行为（1=hit）
B = []; b = [];
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
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
TuAll = uint64(Tr.TrialUID);
[ok, idx] = ismember(Tu, TuAll);
b = nan(nT, 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end

function rho = iSplitHalf(B, nMinTrial)
% 奇偶回合分半 → 跨细胞相关 → Spearman-Brown 信度
rho = NaN;
n = size(B, 2);
if n < nMinTrial, return; end
i1 = 1:2:n; i2 = 2:2:n;
if numel(i1) < 2 || numel(i2) < 2, return; end
a = mean(B(:, i1), 2, 'omitnan');
b = mean(B(:, i2), 2, 'omitnan');
r = iCorr(a, b);
if isfinite(r), rho = 2*r / (1 + r); end
end

function R = iTriplet(vL, vX, vC, rhoL, rhoX, rhoC)
R.rLT = iCorr(vL, vX);
R.rTC = iCorr(vX, vC);
R.rLC = iCorr(vL, vC);
R.cLT = iAdj(R.rLT, rhoL, rhoX);
R.cTC = iAdj(R.rTC, rhoX, rhoC);
R.cLC = iAdj(R.rLC, rhoL, rhoC);
R.d1  = R.cLT - R.cLC;
R.d2  = R.cLT - R.cTC;
R.nT  = size(vX, 1);       % 占位，调用处覆盖
end

function R = iEmptyTriplet()
R = struct('rLT', NaN, 'rTC', NaN, 'rLC', NaN, ...
	'cLT', NaN, 'cTC', NaN, 'cLC', NaN, 'd1', NaN, 'd2', NaN, 'nT', NaN);
end

function r = iAdj(r, rhoA, rhoB)
if ~isfinite(r) || ~isfinite(rhoA) || ~isfinite(rhoB) || rhoA <= 0 || rhoB <= 0
	r = NaN; return;
end
r = r / sqrt(rhoA * rhoB);
end

function r = iCorr(a, b)
a = a(:); b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 10, r = NaN; return; end
a = a(ok); b = b(ok);
if std(a) == 0 || std(b) == 0, r = NaN; return; end
c = corrcoef(a, b);
r = c(1, 2);
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
