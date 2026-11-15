% 表征复用（第七步）："沉默的再激活" —— ALB 与 7 天组（V7）用同一个口径对比
%
% 动机：
%   ALB 的 Transfer 有 5–27 个 miss 试次，V7（7 天）的 Transfer 几乎全是 miss（21–30/30，
%   hit 仅 0.13）。因此 V7 提供了**最干净的无动作样本**：动物在迁移期基本没有舔、也没有迁移行为。
%
%   于是可以问一个比"复用强弱"更锐利的问题：
%     没有动作、也没有行为输出时，光线索还唤起不唤起"学会声水"的那套群体表征？
%       · 唤起（r(TrnMiss,Lrn) > r(TrnMiss,Ctrl)）⇒ 表征在，问题在读出/动机
%       · 不唤起                                        ⇒ 真正的遗忘
%
% 两个读出（同一批细胞、同一读出窗口）：
%   (1) 活跃率：以 Learned 阶段定义的 ensemble 细胞，在 Transfer-miss / Ctrl 上的活跃比例
%   (2) 模式相似度：r = corr_cells( v_a , v_b )，并做 split-half 信度校正
%       d2 = r(TrnMiss,Lrn) − r(TrnMiss,Ctrl)
%
% 条件（两个队列结构相同，便于直接对比）：
%   Lrn = Learned / AudioWater   （学会，hit≈1）
%   Trn = Transfer / LightWater   （迁移；ALB hit≈0.5，V7 hit≈0.13）
%   Ctl = Naive   / LightOnly     （同模态、从未强化，hit≈0.1–0.16）
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
tThr = 2.5; nMinT = 4;

cfg = struct();
cfg(1).Name = "ALB 声→光 即时"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(2).Name = "V7 声→光 7天";  cfg(2).DS = TransferLearning.Vacation7();
for ic = 1:2
	cfg(ic).Lrn = struct('Phase', "Learned",  'Stimulus', "AudioWater");
	cfg(ic).Trn = struct('Phase', "Transfer", 'Stimulus', "LightWater");
	cfg(ic).Ctl = struct('Phase', "Naive",    'Stimulus', "LightOnly");
end

Rows = {};
for ic = 1:2
	DS = cfg(ic).DS;
	[dtL, kL] = iFirstSession(DS, cfg(ic).Lrn);
	[dtT, kT] = iFirstSession(DS, cfg(ic).Trn);
	[dtC, kC] = iFirstSession(DS, cfg(ic).Ctl);
	mice = intersect(intersect(kL.Mouse, kT.Mouse), kC.Mouse);
	fprintf('\n=============== %s（三条件齐全 %d 鼠）===============\n', cfg(ic).Name, numel(mice));

	for iw = 1:numel(win)
		fprintf('\n--- 读出窗口 %s ---\n', win(iw).Name);
		fprintf('%-9s %6s %5s %5s | %8s %8s %8s | %7s %7s %7s | %7s\n', ...
			'鼠', 'nCell', 'nTrn', 'nMis', 'actLrn', 'actTrnM', 'actCtl', ...
			'rTmLrn', 'rTmCtl', 'rLrnCtl', 'd2');
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
			[BL, ~]  = iCellMat(DS, nL, cells, win(iw).Mask);
			[BT, bT] = iCellMat(DS, nT, cells, win(iw).Mask);
			[BC, ~]  = iCellMat(DS, nC, cells, win(iw).Mask);

			% ensemble：Learned 全部试次 t>tThr
			tL = iTstat(BL, nMinT);
			ens = tL > tThr;
			if ~any(ens), continue; end
			% 活跃率
			keepM = bT == 0;
			actL = iActPct(BL, ens, true(size(BL, 2), 1), nMinT, tThr);
			actTM = iActPct(BT, ens, keepM, nMinT, tThr);
			actC = iActPct(BC, ens, true(size(BC, 2), 1), nMinT, tThr);

			% 模式相似度（信度校正）
			vL = mean(BL, 2, 'omitnan');
			vC = mean(BC, 2, 'omitnan');
			rhoL = iSplitHalf(BL, nMinT);
			rhoC = iSplitHalf(BC, nMinT);
			if sum(keepM) >= nMinT
				BTm = BT(:, keepM);
				vTm = mean(BTm, 2, 'omitnan');
				rhoTm = iSplitHalf(BTm, nMinT);
				rTmL = iAdj(iCorr(vTm, vL), rhoTm, rhoL);
				rTmC = iAdj(iCorr(vTm, vC), rhoTm, rhoC);
			else
				nTm = NaN; rTmL = NaN; rTmC = NaN;
			end
			rLC = iAdj(iCorr(vL, vC), rhoL, rhoC);
			d2 = rTmL - rTmC;

			fprintf('%-9s %6d %5d %5d | %8.1f %8.1f %8.1f | %7.2f %7.2f %7.2f | %7.2f\n', string(m), ...
				numel(cells), size(BT, 2), sum(keepM), 100*actL, 100*actTM, 100*actC, rTmL, rTmC, rLC, d2);
			Rows(end+1, :) = {string(cfg(ic).Name), string(win(iw).Name), string(m), numel(cells), ...
				size(BT, 2), sum(keepM), mean(bT(isfinite(bT))), ...
				100*mean(ens), 100*actL, 100*actTM, 100*actC, rTmL, rTmC, rLC, d2}; %#ok<SAGROW>
		end
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Window", "Mouse", "NCells", "nTrn", "nTrnMiss", ...
	"TrnHit", "EnsPct", "ActLrn", "ActTrnMiss", "ActCtl", "r_Tm_Lrn", "r_Tm_Ctl", "r_Lrn_Ctl", "d2"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_SilentReinstatement.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠配对，均值 ± SEM）===============\n');
fprintf('actX = 已定义的 Learned-ensemble 细胞在该条件"未舔试次"上的活跃比例\n');
for ic = 1:2
	for iw = 1:numel(win)
		sel = strcmp(T.Cohort, cfg(ic).Name) & strcmp(T.Window, win(iw).Name);
		if sum(sel) < 3, continue; end
		n = sum(sel);
		fprintf('%-16s %-13s n=%2d | hit=%.2f | act: Lrn=%5.1f  TrnMiss=%5.1f  Ctl=%5.1f | d2=%+6.2f±%4.2f p=%.3g\n', ...
			cfg(ic).Name, win(iw).Name, n, mean(T.TrnHit(sel)), ...
			mean(T.ActLrn(sel)), mean(T.ActTrnMiss(sel)), mean(T.ActCtl(sel)), ...
			mean(T.d2(sel), 'omitnan'), std(T.d2(sel), 'omitnan')/sqrt(n), iSafeP(T.d2(sel)));
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
% 个别会话含基线为 0 的细胞（圈出配准范围外）→ QueryNTS 归一化报错，直接跳过该会话
nts = [];
try
	nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), UniExp.Flags.ZScore, 1:24);
catch ME
	msg = regexprep(ME.message, '\s+', ' ');
	if strlength(msg) > 90, msg = extractBefore(msg, 91) + "..."; end
	fprintf('    [跳过] %s %s %s：%s\n', string(mouse), char(stim), string(dt), msg);
	return;
end
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
end

function [B, b] = iCellMat(DS, nts, cells, mask)
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

function t = iTstat(B, nMinT)
t = nan(size(B, 1), 1);
for i = 1:size(B, 1)
	w = B(i, :).'; w = w(isfinite(w));
	if numel(w) < nMinT, continue; end
	s = std(w) / sqrt(numel(w));
	if s == 0, continue; end
	t(i) = mean(w) / s;
end
end

function p = iActPct(B, ens, keep, nMinT, tThr)
t = nan(size(B, 1), 1);
for i = 1:size(B, 1)
	w = B(i, keep).'; w = w(isfinite(w));
	if numel(w) < nMinT, continue; end
	s = std(w) / sqrt(numel(w));
	if s == 0, continue; end
	t(i) = mean(w) / s;
end
ok = isfinite(t) & ens;
if ~any(ok), p = NaN; else, p = mean(t(ok) > tThr); end
end

function rho = iSplitHalf(B, nMinT)
rho = NaN;
n = size(B, 2);
if n < nMinT, return; end
i1 = 1:2:n; i2 = 2:2:n;
if numel(i1) < 2 || numel(i2) < 2, return; end
r = iCorr(mean(B(:, i1), 2, 'omitnan'), mean(B(:, i2), 2, 'omitnan'));
if isfinite(r), rho = 2*r / (1 + r); end
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
c = corrcoef(a, b); r = c(1, 2);
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
