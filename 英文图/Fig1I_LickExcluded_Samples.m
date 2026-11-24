% Fig1I_LickExcluded_Samples.m —— 补充材料面板 S1K：复用不依赖舔水的钙信号样本
% （内容属于 supplementary，不再占用主图 1I；1I = Fig1I_ReactivationRate_HitVsMiss）
%
% 目的：用代表细胞的钙信号展示——即使试次里没有舔（miss），被复用的细胞仍在 cue +1 s 起反应，
%       因此"迁移期的表征复用"不能归因于舔执行本身。
%
% 选细胞规则（写进图注）：
%   1) learned-active：Learned 阶段 AudioWater，0.5–1.5 s 平均 z > 1.96；
%   2) 复用：Transfer 阶段 LightWater 同一窗口平均 z > 1.96；
%   3) 该 session 的 hit 与 miss 试次各 >= 8；
%   4) 上排 = 三个复用细胞（按 Transfer z 取高/中/低），下排 = 三个 learned-active 但未复用的对照细胞。
%
% 曲线：hit 实线 / miss 虚线，mean ± SEM；灰底 = 0.5–1.5 s 判定窗。
% 输出：English_FigS1K_LickExcluded_Samples.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

cHit   = TransferLearning.ColorHit  / 255;
cMiss  = TransferLearning.ColorMiss / 255;
zThr   = 1.96;
minEach = 8;

DS = TransferLearning.AudioLightBaseline();
TB = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus","Behavior"]);
TB.Mouse = string(TB.Mouse); TB.Phase = string(TB.Phase); TB.Stimulus = string(TB.Stimulus);

%% 1) 选鼠：hit 与 miss 都足够（取 min(hit,miss) 最大者）
tr = TB(TB.Phase == "Transfer" & TB.Stimulus == "LightWater", :);
mice = unique(tr.Mouse);
bestScore = -1; bestMouse = ""; bestDT = NaT; bestH = 0; bestM = 0;
for i = 1:numel(mice)
	R = tr(tr.Mouse == mice(i), :);
	for dt = unique(R.DateTime)'
		s = R(R.DateTime == dt, :);
		nH = nnz(s.Behavior == 1); nM = nnz(s.Behavior == 0);
		if nH < minEach || nM < minEach, continue; end
		sc = min(nH, nM);
		if sc > bestScore
			bestScore = sc; bestMouse = mice(i); bestDT = dt; bestH = nH; bestM = nM;
		end
	end
end
if bestScore < 0
	error('Fig1I:TooFewTrials', '没有 hit 与 miss 各 >= %d 的 session。', minEach);
end
fprintf('选中鼠 %s，Transfer session %s，hit = %d，miss = %d\n', bestMouse, string(bestDT), bestH, bestM);

%% 2) 两个 session
dtL = iFirstSession(DS, bestMouse, "Learned", "AudioWater");
if isnat(dtL), error('Fig1I:NoLearned', '找不到 Learned/AudioWater session。'); end
nLW = iQuery(DS, bestMouse, bestDT, "LightWater");
nAW = iQuery(DS, bestMouse, dtL, "AudioWater");
if isempty(nLW) || isempty(nAW), error('Fig1I:NoData', 'QueryNTS 返回空。'); end

tSec    = double(seconds(TransferLearning.Xs(:)));
maskWin = tSec >= 0.5 & tSec <= 1.5;
maskTr  = tSec >= -1.2 & tSec <= 2.0;
tAx     = tSec(maskTr);

cells = intersect(uint64(nLW.CellUID), uint64(nAW.CellUID));
zAW = iCellWinMean(nAW, cells, maskWin);
zLW = iCellWinMean(nLW, cells, maskWin);

learned = zAW > zThr;
reused  = learned & (zLW > zThr);
ctrlM   = learned & ~reused;
if nnz(reused) < 3 || nnz(ctrlM) < 3
	error('Fig1I:TooFewCells', '复用 %d、未复用 %d，无法取 3+3。', nnz(reused), nnz(ctrlM));
end

iR = find(reused);  [~, o] = sort(zLW(iR), 'descend');
pickR = iR(o(unique(round(linspace(1, numel(o), 3)))));
iC = find(ctrlM);   [~, o] = sort(zLW(iC), 'ascend');
pickC = iC(o(1:3));

%% 3) 逐试次 trace
behT    = iTrialBeh(DS, nLW);
hitIdx  = find(behT == 1);
missIdx = find(behT == 0);

pick = [pickR(:); pickC(:)];
traces = cell(6, 1);
trLearn = cell(6, 1);
for i = 1:6
	traces{i} = iTraceByBeh(nLW, cells(pick(i)), maskTr, hitIdx, missIdx);
	trLearn{i} = iTraceAll(nAW, cells(pick(i)), maskTr);
end

%% 4) 作图 2×3
figW = 8.6; figH = 4.2;
f = figure('Color', 'w', 'Name', 'Fig1I lick-excluded calcium samples');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH];
f.PaperUnits = 'centimeters';
f.PaperSize = [figW figH];
f.PaperPosition = [0 0 figW figH];
f.PaperPositionMode = 'manual';

tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

hH = []; hM = []; hL = []; yAll = [];
for k = 1:6
	ax = nexttile(tl, k);
	hold(ax, 'on');
	patch(ax, [0.5 1.5 1.5 0.5], [-1e3 -1e3 1e3 1e3], [0.85 0.85 0.85], ...
		'FaceAlpha', 0.30, 'EdgeColor', 'none');
	% 参考：Learned 阶段（声水）同一细胞的平均反应
	XL = trLearn{k};
	if ~isempty(XL)
		muL = mean(XL, 2, 'omitnan');
		hP = plot(ax, tAx, muL, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.6);
		if k == 1, hL = hP; end
		yAll = [yAll; muL(:)]; %#ok<AGROW>
	end
	T = traces{k};
	for m = [1 2]
		X = T{m};
		if isempty(X), continue; end
		mu = mean(X, 2, 'omitnan');
		sd = std(X, 0, 2, 'omitnan') / sqrt(size(X, 2));
		if m == 1, col = cHit; ls = '-'; else, col = cMiss; ls = '--'; end
		hP = plot(ax, tAx, mu, ls, 'Color', col, 'LineWidth', 0.7);
		if k == 1, if m == 1, hH = hP; else, hM = hP; end, end
		plot(ax, tAx, mu + sd, '-', 'Color', col * 0.75, 'LineWidth', 0.3);
		plot(ax, tAx, mu - sd, '-', 'Color', col * 0.75, 'LineWidth', 0.3);
		yAll = [yAll; mu(:) + sd(:); mu(:) - sd(:)]; %#ok<AGROW>
	end
	xline(ax, 0, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.4);
	yline(ax, 0, '-', 'Color', [0.72 0.72 0.72], 'LineWidth', 0.3);
	xlim(ax, [tAx(1) tAx(end)]);
	ax.XTick = [-1 0 1 2];
	ax.FontSize = 6; ax.LineWidth = 0.5; box(ax, 'off');
end

% 统一 ylim（先设范围，再隐藏多余的 tick 标签，否则会被重置）
yl  = [min(yAll, [], 'omitnan'), max(yAll, [], 'omitnan')];
pad = 0.06 * diff(yl);
for k = 1:6
	ax = nexttile(tl, k);
	ylim(ax, [yl(1) - pad, yl(2) + pad]);
end
for k = 1:6
	ax = nexttile(tl, k);
	if mod(k-1, 3) ~= 0, ax.YTickLabel = {}; end
	if k <= 3, ax.XTickLabel = {}; end
end

title(nexttile(tl, 1), 'reused', 'FontSize', 6, 'FontWeight', 'normal');
title(nexttile(tl, 4), 'not reused', 'FontSize', 6, 'FontWeight', 'normal');
xlabel(tl, 'Time from cue (s)', 'FontSize', 6);
ylabel(tl, 'z-score', 'FontSize', 6);

lg = legend([hL hH hM], {'learned', 'transfer hit', 'transfer miss'}, ...
	'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 5);
lg.Layout.Tile = 'north';

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS1K_LickExcluded_Samples.svg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== 取样细胞 ===\n');
wR = maskWin(maskTr);
for k = 1:6
	i = pick(k);
	if k <= 3, tag = 'reused'; else, tag = 'not reused'; end
	T = traces{k};
	vh = mean(T{1}(wR, :), 1, 'omitnan');
	vm = mean(T{2}(wR, :), 1, 'omitnan');
	ph = NaN; pm = NaN;
	if numel(vh) >= 3, ph = iT(vh); end
	if numel(vm) >= 3, pm = iT(vm); end
	fprintf('cell %d  Learned z=%.2f  Transfer z=%.2f | 窗内 hit=%.2f (p=%.3g, n=%d)  miss=%.2f (p=%.3g, n=%d)  (%s)\n', ...
		k, zAW(i), zLW(i), mean(vh, 'omitnan'), ph, numel(vh), mean(vm, 'omitnan'), pm, numel(vm), tag);
end

%% ========== local ==========
function p = iT(v)
v = v(isfinite(v));
if numel(v) < 3 || std(v) == 0
	p = NaN;
else
	[~, p] = ttest(v, 0);
end
end

function dt = iFirstSession(DS, m, ph, stim)
T = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus"]);
T.Mouse = string(T.Mouse); T.Phase = string(T.Phase); T.Stimulus = string(T.Stimulus);
sel = T.Mouse == string(m) & T.Phase == ph & T.Stimulus == stim;
if ~any(sel), dt = NaT; return; end
d = sort(unique(T.DateTime(sel))); dt = d(1);
end

function nts = iQuery(DS, m, dt, stim)
nts = DS.QueryNTS(struct('Mouse', m, 'DateTime', dt, 'Stimulus', stim), UniExp.Flags.ZScore, 1:24);
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
end

function z = iCellWinMean(nts, cells, maskWin)
cu = uint64(nts.CellUID); tu = uint64(nts.TrialUID);
sig = double(nts.TrialSignal);
Tu = unique(tu, 'stable');
z = nan(numel(cells), 1);
for i = 1:numel(cells)
	r = find(cu == cells(i));
	if isempty(r), continue; end
	v = nan(numel(Tu), 1);
	for t = 1:numel(Tu)
		rr = r(tu(r) == Tu(t));
		if isempty(rr), continue; end
		v(t) = mean(sig(rr, maskWin), 2);
	end
	z(i) = mean(v, 'omitnan');
end
end

function beh = iTrialBeh(DS, nts)
Tu = unique(uint64(nts.TrialUID), 'stable');
T = DS.TableQuery(["TrialUID","Behavior"]);
T.TrialUID = uint64(T.TrialUID);
[ok, idx] = ismember(Tu, T.TrialUID);
beh = nan(numel(Tu), 1);
beh(ok) = double(T.Behavior(idx(ok)));
end

function T = iTraceAll(nts, cellUID, maskTr)
cu = uint64(nts.CellUID); tu = uint64(nts.TrialUID);
sig = double(nts.TrialSignal);
Tu = unique(tu, 'stable');
nF = nnz(maskTr);
T = nan(nF, 0);
for j = 1:numel(Tu)
	r = find(cu == cellUID & tu == Tu(j), 1);
	if isempty(r), continue; end
	T(:, end+1) = sig(r, maskTr)'; %#ok<AGROW>
end
end

function T = iTraceByBeh(nts, cellUID, maskTr, hitIdx, missIdx)
cu = uint64(nts.CellUID); tu = uint64(nts.TrialUID);
sig = double(nts.TrialSignal);
Tu = unique(tu, 'stable');
nF = nnz(maskTr);
T = {nan(nF, 0), nan(nF, 0)};
sets = {hitIdx, missIdx};
for m = 1:2
	idx = sets{m};
	X = nan(nF, 0);
	for j = 1:numel(idx)
		r = find(cu == cellUID & tu == Tu(idx(j)), 1);
		if isempty(r), continue; end
		X(:, end+1) = sig(r, maskTr)'; %#ok<AGROW>
	end
	T{m} = X;
end
end
