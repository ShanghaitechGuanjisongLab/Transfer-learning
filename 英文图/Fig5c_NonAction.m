% Fig5c_NonAction.m —— 论点③：迁移期的表征相似性不能由动作（舔水）解释
%
% 1 行 × 3 列（20 × 4.6 cm，Scale 2）
%   (a) ALB Transfer 内 hit vs miss 的群体轨迹（±3 s）
%   (b) 未舔试次与 Learned 动作轴正交后的相关 r_⊥（2/3 与 L5 层）
%   (c) 未舔试次占全部 Transfer 试次的比例
%
% 口径：MOp2/3（(b) 另含 L5）；hit/miss 判定窗 1 s（AddBehavior ResponseWindow 仅保证 1 s 内无舔）

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

cHit  = TransferLearning.ColorHit  / 255;
cMiss = TransferLearning.ColorMiss / 255;
cL23  = TransferLearning.ColorLearned / 255;
cL5   = TransferLearning.Color12h     / 255;

LayerKeep = "MOp2/3";
nSeg = 30;

%% ---------- (a) hit / miss 轨迹（投影到 ALB 四阶段公共 PC 基）----------
cacheFile = fullfile(tempdir, 'PCAstage_G_MOp2-3.mat');
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));
iDS = find(dsNames == "ALB", 1);
nL = size(G{iDS, 1}.NTATS.Data, 3);
commonALB = G{iDS, 1}.CellUID;
for iS = 2:4, commonALB = intersect(commonALB, G{iDS, iS}.CellUID); end
commonALB = sort(unique(commonALB));
nOut = size(G{iDS, 1}.NTATS.Data, 2);
dataAll = nan(numel(commonALB), nOut, 4 * nL);
for iS = 1:4
	[~, loc] = ismember(commonALB, G{iDS, iS}.CellUID);
	dataAll(:, :, (iS - 1) * nL + (1:nL)) = double(G{iDS, iS}.NTATS.Data(loc, :, :));
end
Tp = UniExp.LinearPca(MATLAB.DataTypes.NDTable(dataAll), 2, true);
COALB = double(Tp.Coeff);
MUALB = mean(reshape(dataAll, numel(commonALB), []), 2);
tWin0 = [0, 8]; tBase0 = [-3, 0];
DS = TransferLearning.AudioLightBaseline();
trAll = DS.Trials;
trH_acc = []; trM_acc = []; nHitTot = 0; nMissTot = 0;
for m = unique(iMouse(DS))'
	dtT = iFirst(DS, m, "Transfer", "LightWater");
	if isnat(dtT), continue; end
	nts = iQuery(DS, m, dtT, "LightWater");
	if isempty(nts), continue; end
	Tu = unique(uint64(nts.TrialUID), 'stable');
	Tb = DS.TableQuery(["TrialUID", "Behavior"]);
	[okb, ib] = ismember(Tu, uint64(Tb.TrialUID));
	beh = nan(numel(Tu), 1); beh(okb) = double(Tb.Behavior(ib(okb)));
	uH = Tu(beh == 1); uM = Tu(beh == 0);
	if numel(uH) < 2 || numel(uM) < 2, continue; end
	nHitTot = nHitTot + numel(uH); nMissTot = nMissTot + numel(uM);
	trH = trAll(ismember(uint64(trAll.TrialUID), uH), :);
	trM = trAll(ismember(uint64(trAll.TrialUID), uM), :);
	[H, uidH] = iExtract0to8s(DS, trH, LayerKeep, nOut, tWin0, tBase0);
	[MM, uidM] = iExtract0to8s(DS, trM, LayerKeep, nOut, tWin0, tBase0);
	if isempty(H) || isempty(MM), continue; end
	[~, ia, ib2] = intersect(uidH, uidM);
	cellsM = uidH(ia);
	[okc, pos] = ismember(cellsM, commonALB);
	if sum(okc) < 50, continue; end
	Xh = reshape(mean(H(ia(okc), :, :), 2, 'omitnan'), sum(okc), []);
	Xm = reshape(mean(MM(ib2(okc), :, :), 2, 'omitnan'), sum(okc), []);
	mc = MUALB(pos(okc))';
	cc = COALB(:, pos(okc))';
	trH_acc = cat(3, trH_acc, ((Xh' - mc) * cc)');
	trM_acc = cat(3, trM_acc, ((Xm' - mc) * cc)');
end
assert(~isempty(trH_acc), 'Fig5c:NoHitMiss', '没有取到 hit/miss');
TRh = sum(trH_acc, 3, 'omitnan');
TRm = sum(trM_acc, 3, 'omitnan');

%% ---------- (b) r_⊥ ----------
PA1 = readtable(fullfile(thisDir, 'RepresentationReuse_PartialActionClaim_MOp2-3.csv'), 'TextType', 'string');
PA2 = readtable(fullfile(thisDir, 'RepresentationReuse_PartialActionClaim_MOp5.csv'), 'TextType', 'string');
rA = PA1.r2_orthA_raw(PA1.Cohort == "ALB"); rA = rA(isfinite(rA));
rB = PA2.r2_orthA_raw(PA2.Cohort == "ALB"); rB = rB(isfinite(rB));

%% ================= 画布 =================
f = figure('Color', 'w', 'Name', 'Fig5c non-action');
f.Units = 'centimeters';
f.Position = [2, 2, 20, 5.6];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 20, 5.6];
f.PaperSize = [20, 5.6];
tlo = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

axA = nexttile(tlo);
iGrad(axA, trH_acc, cHit, nSeg);
iGrad(axA, trM_acc, cMiss, nSeg);
axA.Box = 'off'; axA.XTick = []; axA.YTick = []; axA.LineWidth = 1;
ylabel(axA, 'PC2'); xlabel(axA, 'PC1');
title(axA, '(a)', 'FontWeight', 'normal');
hold(axA, 'on');
h1 = plot(axA, nan, nan, '-', 'Color', cHit,  'LineWidth', 1.5, 'DisplayName', 'hit');
h2 = plot(axA, nan, nan, '-', 'Color', cMiss, 'LineWidth', 1.5, 'DisplayName', 'miss');
setappdata(h1, 'TransferLearningPreserveLineWidth', true);
setappdata(h2, 'TransferLearningPreserveLineWidth', true);
lgd = legend(axA, [h1 h2], 'Box', 'off', 'Location', 'northeast');
lgd.NumColumns = 1; lgd.FontSize = 5;

axB = nexttile(tlo);
iBar(axB, {rA, rB}, {cL23, cL5}, {'2/3', 'L5'});
ylabel(axB, 'r_\perp (unlicked)');
title(axB, '(b)', 'FontWeight', 'normal');

axC = nexttile(tlo);
pH = 100 * nHitTot / (nHitTot + nMissTot);
hold(axC, 'on');
bar(axC, 1, pH, 0.5, 'FaceColor', cHit, 'EdgeColor', 'none');
bar(axC, 2, 100 - pH, 0.5, 'FaceColor', cMiss, 'EdgeColor', 'none');
axC.XTick = [1 2]; axC.XTickLabel = {'hit', 'miss'};
xlim(axC, [0.5 2.5]);
ylabel(axC, 'trials (%)');
title(axC, '(c)', 'FontWeight', 'normal');
axC.Box = 'off'; axC.LineWidth = 1;

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig5c_NonAction.svg');
fprintf('Wrote: %s\n', svgPath);
exportgraphics(f, fullfile(thisDir, '_fig5c_check.png'), 'Resolution', 400, 'BackgroundColor', 'white');
fprintf('hit %d / miss %d trials\n', nHitTot, nMissTot);

%% ================= 局部函数 =================
function iGrad(ax, X, color, nSeg)
nL = size(X, 3); nT = size(X, 2);
tt = linspace(1, nT, nSeg + 1);
w = linspace(0, 1, nSeg + 1)';
c0 = 0.75 + 0.25 * color(:)';
cv = c0 + w * (color(:)' - c0);
Xp = nan(nSeg + 2, nL); Yp = nan(nSeg + 2, nL);
for j = 1:nL
	xy = squeeze(X(:, :, j));
	Xp(1:nSeg + 1, j) = interp1(1:nT, xy(1, :), tt);
	Yp(1:nSeg + 1, j) = interp1(1:nT, xy(2, :), tt);
end
C = repmat(reshape(cv, [nSeg + 1, 1, 3]), 1, nL, 1);
C(end + 1, :, :) = repmat(reshape(cv(end, :), [1, 1, 3]), 1, nL, 1);
hold(ax, 'on');
hi = patch(ax, Xp, Yp, C, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.0, 'EdgeAlpha', 0.26, 'HandleVisibility', 'off');
setappdata(hi, 'TransferLearningPreserveLineWidth', true);
Xm = mean(Xp, 2, 'omitnan'); Ym = mean(Yp, 2, 'omitnan');
Cm = reshape(cv, [nSeg + 1, 1, 3]);
Cm(end + 1, :, :) = reshape(cv(end, :), [1, 1, 3]);
hd = patch(ax, Xm, Ym, Cm * 0.58, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 2.2, 'HandleVisibility', 'off');
setappdata(hd, 'TransferLearningPreserveLineWidth', true);
hc = patch(ax, Xm, Ym, Cm, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.5, 'HandleVisibility', 'off');
setappdata(hc, 'TransferLearningPreserveLineWidth', true);
end

function iBar(ax, D, C, lab)
hold(ax, 'on');
for k = 1:numel(D)
	v = D{k}(:); v = v(isfinite(v));
	if isempty(v), continue; end
	m = mean(v); s = std(v) / sqrt(numel(v));
	bar(ax, k, m, 0.55, 'FaceColor', C{k}, 'EdgeColor', 'none', 'HandleVisibility', 'off');
	errorbar(ax, k, m, s, 'Color', C{k}, 'LineStyle', 'none', 'LineWidth', 1, ...
		'CapSize', 3, 'HandleVisibility', 'off');
	plot(ax, k + (rand(numel(v), 1) - 0.5) * 0.26, v, 'o', 'MarkerSize', 2.2, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', C{k}, 'LineWidth', 0.4, ...
		'HandleVisibility', 'off');
	text(ax, k, max(m, 0) + 0.02, sprintf('%.2f', m), 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end
xlim(ax, [0.5 numel(D) + 0.5]); ax.XTick = 1:numel(D); ax.XTickLabel = lab;
yline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.Box = 'off'; ax.LineWidth = 1;
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


function dtStr = iDtStr(x)
x = datetime(x);
if ~isempty(x.TimeZone), x.TimeZone = ''; end
dtStr = string(x);
end

function [Zout, uidOut] = iExtract0to8s(DS, trials, layerKeep, nOut, tWin, tBase)
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
assert(all(isIn), 'Fig5c:MissingTrial', 'Some trials are not in DS.Trials.');
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
	for j = 1:numel(bIds), dtOfBlock(double(bIds(j))) = dB; end
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
		full = double(bs.BlockSignal{rowsB(r)});
		full = full(:)';
		ok = validTrial & all(idxWin <= numel(full), 2);
		if ~any(ok), continue; end
		cellSd = std(full(isfinite(full)));
		if ~isfinite(cellSd) || cellSd < 1e-6, continue; end
		W = full(idxWin(ok, :));
		B = full(idxBase(ok, :));
		mu = mean(B, 2, 'omitnan');
		sd = std(B, 0, 2, 'omitnan');
		sd = max(sd, 0.5 * cellSd);
		sd(~isfinite(sd)) = cellSd;
		Z = (W - mu) ./ sd;
		if isKey(MapZ, cid), MapZ(cid) = [MapZ(cid); Z]; else, MapZ(cid) = Z; end
	end
end
ks = MapZ.keys; n = numel(ks);
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
