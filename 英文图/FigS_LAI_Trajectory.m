% 补充图：LAInterspersed（光声穿插）的「未训练 → 训练后」响应时间过程
%
% 口径（与 Fig5(a) 对齐，⚠ 与 Fig5(e) 不同）：
%   · 取该阶段主线索（光）的**给水试次** LightWater —— 与 Fig5(a) 的
%     StimByStage 口径一致（ALB 用 AudioWater / LAB 用 LightWater）
%   · 因此 Naive 与 Transfer 两阶段刺激相同、均给水，只差学习状态
%   · 而 Fig5(e) 的 rel 用的是**无给水** LightOnly（机制排除实验）
%   ⇒ 两处数字不可混引，图注须分开陈述
%
% 为何不是 2D 轨迹：LAI 两阶段合并 PC 的 PC1+PC2 仅解释 ~13.8%，
%   2D 平面代表不了轨迹（试过 0–8/0–3/0–1.5 s 与归一化版本，均不可用）；
%   改为 PC 时间过程，稳健且能显示 SEM 带收窄（= 试次间一致性提高）。
%
% 输出：English_FigS_LAI_Trajectory.svg（5 × 5.5 cm）

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nOut = 13; nSeg = nOut - 1; smoothFrames = 1;
tWin = [0, 1.5]; tBase = [-3, 0];   % 与 rel 的时间窗一致（cue 后 1.5 s）
LayerKeep = "MOp2/3";
nTrialPer = 20;          % 两阶段各取固定试次数，保证对称
StimSel = "LightWater";   % 与 Fig5(a) 同口径：该阶段主线索（光）的给水试次

cNaive   = TransferLearning.ColorNaive   / 255;   % #F38BA8
cLearned = TransferLearning.ColorLearned / 255;   % #94E2D5

%% ---------- 1. 逐鼠提取两阶段的 0–8 s 响应 ----------
DS = TransferLearning.LAInterspersed();
trAll = DS.Trials;
mice = unique(iMouse(DS));

Part = struct('mouse', {}, 'uid', {}, 'A', {}, 'B', {});
for i = 1:numel(mice)
	m = mice(i);
	dtN = iFirst(DS, m, "Naive", StimSel);
	dtT = iFirst(DS, m, "Transfer", StimSel);
	if isnat(dtN) || isnat(dtT), continue; end
	nN = iQuery(DS, m, dtN, StimSel);
	nT = iQuery(DS, m, dtT, StimSel);
	if isempty(nN) || isempty(nT), continue; end
	uN = unique(uint64(nN.TrialUID), 'stable');
	uT = unique(uint64(nT.TrialUID), 'stable');
	trN = trAll(ismember(uint64(trAll.TrialUID), uN), :);
	trT = trAll(ismember(uint64(trAll.TrialUID), uT), :);
	[A, uA] = iExtract0to8s(DS, trN, LayerKeep, nOut, tWin, tBase);
	[B, uB] = iExtract0to8s(DS, trT, LayerKeep, nOut, tWin, tBase);
	if isempty(A) || isempty(B), continue; end
	[~, ia, ib] = intersect(uA, uB);
	if numel(ia) < 50, continue; end
	e = struct('mouse', string(m), 'uid', uA(ia), 'A', A(ia, :, :), 'B', B(ib, :, :));
	Part(end + 1) = e; %#ok<SAGROW>
	fprintf('%-9s 匹配细胞 %3d | 试次 naive %2d transfer %2d\n', ...
		string(m), numel(ia), size(e.A, 2), size(e.B, 2));
end

nPart = numel(Part);
if nPart < 3, error('FigS:TooFewMice', '可用鼠数只有 %d', nPart); end
nA = min(nTrialPer, min(arrayfun(@(s) size(s.A, 2), Part)));
nB = min(nTrialPer, min(arrayfun(@(s) size(s.B, 2), Part)));
nCellTot = sum(arrayfun(@(s) numel(s.uid), Part));
fprintf('\n合并：%d 只鼠，%d 个细胞，每阶段 %d / %d 试次\n', nPart, nCellTot, nA, nB);

%% ---------- 2. 两阶段合并 PCA（同一套基） ----------
data = nan(nCellTot, nOut, nA + nB);
mo = strings(nCellTot, 1);
p0 = 0;
for i = 1:nPart
	c = numel(Part(i).uid);
	data(p0 + (1:c), :, 1:nA)        = permute(Part(i).A(:, 1:nA, :), [1 3 2]);
	data(p0 + (1:c), :, nA + (1:nB)) = permute(Part(i).B(:, 1:nB, :), [1 3 2]);
	mo(p0 + (1:c)) = Part(i).mouse;
	p0 = p0 + c;
end
Tp = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), 2, true);
EXP = Tp.Explained(1:2);
co = double(Tp.Coeff);            % 2 × nCell
fprintf('PC1=%.2f%%, PC2=%.2f%%\n', EXP(1), EXP(2));

%% ---------- 3. 群体均值与逐鼠轨迹 ----------
Xm = nan(nOut, 2, 2);            % 帧 × PC × 阶段
uM = unique(mo, 'stable');
PMtraj = cell(numel(uM), 2);
for s = 1:2
	if s == 1, cols = 1:nA; else, cols = nA + (1:nB); end
	d = data(:, :, cols);
	Xm(:, :, s) = (co * mean(d, 3, 'omitnan'))';   % (nOut, 2)
	for i = 1:numel(uM)
		sel = mo == uM(i);
		Xi = mean(d(sel, :, :), 3, 'omitnan');       % (nCell_i, nOut)
		PMtraj{i, s} = (co(:, sel) * Xi)';           % (nOut, 2)
	end
end

% 归一化：各自中心化 + 单位范数 ⇒ 只比形状，不比幅度（与 iDNoRot 口径一致）
for s = 1:2
	M0 = Xm(:, :, s); M0 = M0 - mean(M0, 1);
	Xm(:, :, s) = M0 / norm(M0, 'fro');
	for i = 1:numel(uM)
		M1 = PMtraj{i, s}; M1 = M1 - mean(M1, 1, 'omitnan');
		PMtraj{i, s} = M1 / norm(M1, 'fro');
	end
end

% 描述性统计
cosNT = iCos(Xm(:, :, 1), Xm(:, :, 2));
dNT = iDNoRot(Xm(:, :, 1), Xm(:, :, 2));
fprintf('归一化轨迹: cos = %.3f | d(禁旋转 Procrustes) = %.3f  [⚠ 不可与 Fig5 的 d 直接比，基与窗口不同]\n', cosNT, dNT);

%% ---------- 4. 作图：PC 时间过程（比 2D 轨迹稳健）----------
tt = linspace(tWin(1), tWin(2), nOut);
f = figure('Color', 'w', 'Name', 'FigS LAI PC time courses');
f.Units = 'centimeters';
f.Position(3:4) = [5.0, 5.5];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 5.0, 5.5];
f.PaperSize = [5.0, 5.5];
tlo = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
cols2 = {cNaive, cLearned};
lab2 = {'Naive', 'Transfer'};
for k = 1:2
	axk = nexttile(tlo); hold(axk, 'on');
	for s = 1:2
	Mx = nan(numel(uM), nOut);
	for i = 1:numel(uM)
		Mx(i, :) = PMtraj{i, s}(:, k)';
	end
	m = mean(Mx, 1, 'omitnan');
	se = std(Mx, 0, 1, 'omitnan') / sqrt(sum(any(isfinite(Mx), 2)));
	fill(axk, [tt, fliplr(tt)], [m - se, fliplr(m + se)], cols2{s}, ...
		'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off');
	h1 = plot(axk, tt, m, '-', 'Color', cols2{s}, 'LineWidth', 1.6, 'DisplayName', lab2{s});
	setappdata(h1, 'TransferLearningPreserveLineWidth', true);
	end
	axk.Box = 'off'; axk.LineWidth = 1;
	yline(axk, 0, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.4, 'HandleVisibility', 'off');
	ylabel(axk, sprintf('PC%d', k));
	if k == 1, title(axk, '(a)', 'FontWeight', 'normal'); legend(axk, 'Location', 'northwest', 'Box', 'off'); end
	if k == 2, title(axk, '(b)', 'FontWeight', 'normal'); xlabel(axk, 'Time from cue (s)'); end
end
lg = [];

TransferLearning.ExportStandardFigure(f, 1, 'English_FigS_LAI_Trajectory.svg');
fprintf('Wrote: %s\n', TransferLearning.StandardFigureSvgPath('English_FigS_LAI_Trajectory.svg'));

%% ================= local functions =================
function iGradMean(ax, XYt, color)
% 群体均值轨迹：原色芯 + 同色相深描边，起点向白混 75% 表示时间进程
nT = size(XYt, 1); nSeg = nT - 1;
w = linspace(0, 1, nSeg)';
c0 = 0.75 + 0.25 * color(:)';
cv = c0 + w * (color(:)' - c0);
cv = [cv; cv(end, :)];
Cm = repmat(reshape(cv, [nT, 1, 3]), 1, 2, 1);
hd = plot(ax, XYt(:, 1), XYt(:, 2), '-', 'Color', color * 0.58, 'LineWidth', 2.2, ...
	'HandleVisibility', 'off');
setappdata(hd, 'TransferLearningPreserveLineWidth', true);
hc = patch(ax, [XYt(:, 1) XYt(:, 1)], [XYt(:, 2) XYt(:, 2)], Cm, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.5);
setappdata(hc, 'TransferLearningPreserveLineWidth', true);
end

function c = iCos(A, B)
a = A(:); b = B(:);
ok = isfinite(a) & isfinite(b);
a = a(ok) - mean(a(ok)); b = b(ok) - mean(b(ok));
c = (a' * b) / (norm(a) * norm(b));
end
function d = iDNoRot(A, B)
a = A - mean(A, 1); b = B - mean(B, 1);
a = a / norm(a, 'fro'); b = b / norm(b, 'fro');
d = 2 - 2 * sum(a(:) .* b(:));
end

function u = iMouse(DS)
Tq = DS.TableQuery(["Mouse", "DateTime"]);
u = unique(string(Tq.Mouse));
end

function dt = iFirst(DS, m, ph, stim)
Tq = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
Tq.Mouse = string(Tq.Mouse); Tq.Phase = string(Tq.Phase); Tq.Stimulus = string(Tq.Stimulus);
sel = Tq.Mouse == m & Tq.Phase == ph & Tq.Stimulus == stim;
if ~any(sel), dt = NaT; return; end
d = sort(unique(Tq.DateTime(sel))); dt = d(1);
end

function nts = iQuery(DS, mouse, dt, stim)
nts = [];
try
	nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), ...
		UniExp.Flags.ZScore, 1:24);
catch
	return;
end
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
end

function s = iDtStr(x)
s = string(datestr(x, 'yyyymmddHHMMSS'));
end

function [Zout, uidOut] = iExtract0to8s(DS, trials, layerKeep, nOut, tWin, tBase)
% 从 BlockSignals 截取 cue 后 tWin 段，逐回合 z-score（基线 tBase）
cellsTbl = DS.Cells;
cellsTbl.CellUID = uint64(cellsTbl.CellUID);
cellsTbl.ZLayer = string(cellsTbl.ZLayer);
if strlength(layerKeep) > 0
	keepMask = cellsTbl.ZLayer == layerKeep;
else
	keepMask = true(height(cellsTbl), 1);
end
cellUIDset = cellsTbl.CellUID(keepMask);

trAll = DS.Trials;
[isIn, loc] = ismember(uint64(trials.TrialUID), uint64(trAll.TrialUID));
assert(all(isIn), 'FigS:MissingTrial', 'Some trials are not in DS.Trials.');
cue = double(trAll.SampleRange.Tag(loc));
blk = double(trAll.BlockUID(loc));
dates = DS.DateTimes;
dates.DateTime = iDtStr(dates.DateTime);
dtAll = seconds(dates.SeriesInterval);
dtMed = median(dtAll(isfinite(dtAll) & dtAll > 0));
blocksTbl = DS.Blocks;
dtOfBlock = containers.Map('KeyType', 'double', 'ValueType', 'double');
for iD = 1:height(dates)
	bIds = blocksTbl.BlockUID(iDtStr(blocksTbl.DateTime) == dates.DateTime(iD));
	dB = dtMed;
	if isfinite(dtAll(iD)) && dtAll(iD) > 0, dB = dtAll(iD); end
	for j = 1:numel(bIds)
		dtOfBlock(double(bIds(j))) = dB;
	end
end
bs = DS.BlockSignals;
bs.CellUID = uint64(bs.CellUID);
MapZ = containers.Map('KeyType', 'uint64', 'ValueType', 'any');
uB = unique(blk);
for iB = 1:numel(uB)
	b = uB(iB);
	rTrial = find(blk == b);
	cueB = cue(rTrial);
	if isKey(dtOfBlock, b), dtB = dtOfBlock(b); else, dtB = dtMed; end
	off = round(linspace(tWin(1), tWin(2), nOut) / dtB);
	idxWin = cueB(:) + off;
	nBase = max(1, round(diff(tBase) / dtB));
	baseOff = round(linspace(tBase(1), tBase(2) - dtB, nBase) / dtB);
	idxBase = cueB(:) + baseOff;
	rowsB = find(bs.BlockUID == b);
	if isempty(rowsB), continue; end
	lenB = numel(bs.BlockSignal{rowsB(1)});
	validTrial = all(idxWin >= 1, 2) & all(idxWin <= lenB, 2) & all(idxBase >= 1, 2);
	if ~any(validTrial), continue; end
	for r = 1:numel(rowsB)
		cid = bs.CellUID(rowsB(r));
		if ~any(cellUIDset == cid), continue; end
		fullSig = double(bs.BlockSignal{rowsB(r)});
		fullSig = fullSig(:)';
		okT = validTrial & all(idxWin <= numel(fullSig), 2);
		if ~any(okT), continue; end
		cellSd = std(fullSig(isfinite(fullSig)));
		if ~isfinite(cellSd) || cellSd < 1e-6, continue; end
		W = fullSig(idxWin(okT, :));
		B = fullSig(idxBase(okT, :));
		mu = mean(B, 2, 'omitnan');
		sd = std(B, 0, 2, 'omitnan');
		sd = max(sd, 0.5 * cellSd);
		sd(~isfinite(sd)) = cellSd;
		Z = (W - mu) ./ sd;
		if isKey(MapZ, cid)
			MapZ(cid) = [MapZ(cid); Z];
		else
			MapZ(cid) = Z;
		end
	end
end
ks = MapZ.keys;
n = numel(ks);
if n == 0, Zout = []; uidOut = uint64([]); return; end
nTrialMax = 0;
for i = 1:n, nTrialMax = max(nTrialMax, size(MapZ(ks{i}), 1)); end
Zout = nan(n, nTrialMax, nOut);
uidOut = zeros(n, 1, 'uint64');
for i = 1:n
	Zi = MapZ(ks{i});
	Zout(i, 1:size(Zi, 1), :) = Zi;
	uidOut(i) = ks{i};
end
end
