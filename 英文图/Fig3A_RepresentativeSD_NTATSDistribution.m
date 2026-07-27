% 英文图3B：代表性单会话的 3D 热图 + 细胞间 1s z-score 分布
%
% 先按原规则找出 Pair A / Pair B，共 4 个候选会话
% 再在这 4 个会话中挑选 response heterogeneity 最大的 1 个作为代表
% 约束: ΔHit(A) > ΔHit(B)
%
% 输出：
%   热图：1 个代表会话的 3D volshow PNG
%   直方图：同一会话的 1 个 SVG
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.B_RepresentativeSD_NTATSDistribution

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('EnglishFig3B:No1s', 'Cannot find sample close to 1s.');
end

%% ===== 1) Build session pairs =====
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iExcludeCeiling(Sess);

SessSpeed = iSessionDeltaNext(Sess);
nPairs = height(SessSpeed);
deltaHit = double(SessSpeed.Speed_DeltaNext);

%% ===== 2) Compute SD@1s per session pair (cells in [-1,1]) =====
sd1sMean = nan(nPairs, 1);
sd1sK    = nan(nPairs, 1);
sd1sK1   = nan(nPairs, 1);
nCellMin = nan(nPairs, 1);

for iP = 1:nPairs
	dtK  = SessSpeed.DateTime(iP);
	dtK1 = SessSpeed.DateTimeNext(iP);
	[~, ntatsK]  = iSessionNTATS(DS, dtK);
	[~, ntatsK1] = iSessionNTATS(DS, dtK1);
	if isempty(ntatsK) || isempty(ntatsK1), continue; end
	vK  = double(ntatsK(:, idx1s));
	vK1 = double(ntatsK1(:, idx1s));
	vK  = vK(isfinite(vK) & vK >= -1 & vK <= 1);
	vK1 = vK1(isfinite(vK1) & vK1 >= -1 & vK1 <= 1);
	nCellMin(iP) = min(numel(vK), numel(vK1));
	if numel(vK) >= 3 && numel(vK1) >= 3
		sd1sK(iP)  = std(vK);
		sd1sK1(iP) = std(vK1);
		sd1sMean(iP) = (sd1sK(iP) + sd1sK1(iP)) / 2;
	end
end

%% ===== 3) Select Pair A (max SD) and Pair B (min SD), ΔHit(A)>ΔHit(B) =====
valid = isfinite(deltaHit) & isfinite(sd1sMean) & (nCellMin >= 10);
validIdx = find(valid);

[~, sortDesc] = sort(sd1sMean(validIdx), 'descend');
sortedBySD = validIdx(sortDesc);

bestA = NaN;
bestB = NaN;
found = false;

for iA = 1:numel(sortedBySD)
	candA = sortedBySD(iA);
	minSD_A = min(sd1sK(candA), sd1sK1(candA));
	for iB = numel(sortedBySD):-1:1
		candB = sortedBySD(iB);
		if candB == candA, continue; end
		maxSD_B = max(sd1sK(candB), sd1sK1(candB));
		if sd1sMean(candA) > sd1sMean(candB) ...
				&& (deltaHit(candA) - deltaHit(candB)) >= 0.10 ...
				&& minSD_A > maxSD_B
			bestA = candA;
			bestB = candB;
			found = true;
			break;
		end
	end
	if found, break; end
end

if ~found
	error('EnglishFig3B:NoFeasible', ...
		'Cannot find Pair A & B satisfying all constraints.');
end

pairsIdx = [bestA; bestB];

%% ===== 4) Fetch full NTATS + per-cell 1s values for 4 sessions =====
vals = cell(2, 2);       % vals{pair, session}: per-cell z-score@1s (filtered [-1,1])
sdVals = nan(2, 2);
rawData  = cell(2, 2);   % rawData{pair, session}: (cells×time×trials) for volshow
dtVals = NaT(2, 2);

xMask = (xsSec >= 0) & (xsSec <= 2); % 0~2s for heatmap

for iP = 1:2
	idx = pairsIdx(iP);
	dtK  = SessSpeed.DateTime(idx);
	dtK1 = SessSpeed.DateTimeNext(idx);

	for iS = 1:2
		if iS == 1, dt = dtK; else, dt = dtK1; end
		dtVals(iP, iS) = dt;
		[~, ntats, ntsRaw] = iSessionNTATS(DS, dt);
		v1s = double(ntats(:, idx1s));

		% Filter to cells in [-1,1]
		keepMask = isfinite(v1s) & v1s >= -1 & v1s <= 1;
		v1s_filt = v1s(keepMask);
		ntats_filt = double(ntats(keepMask, :));

		% Sort by z-score@1s ascending
		[~, sortIdx] = sort(v1s_filt, 'ascend');
		v1s_sorted = v1s_filt(sortIdx);

		vals{iP, iS} = v1s_sorted;
		sdVals(iP, iS) = std(v1s_sorted);

		% Raw per-trial data: (filteredCells × timeMask × trials)
		if ~isempty(ntsRaw)
			raw_filt   = ntsRaw(keepMask, :, :);
			rawData{iP, iS} = raw_filt(sortIdx, xMask, :);
		else
			rawData{iP, iS} = [];
		end
	end

	pLabel = char('A' + iP - 1);
	fprintf('Pair %s: Mouse=%s, k=%s, k+1=%s, ΔHit=%+.1f%%, mean response heterogeneity=%.3f\n', ...
		pLabel, string(SessSpeed.Mouse(idx)), ...
		datestr(dtK, 'yyyy-mm-dd HH:MM'), datestr(dtK1, 'yyyy-mm-dd HH:MM'), ...
		100 * deltaHit(idx), sd1sMean(idx));
	fprintf('  Session k:   n=%d cells, Response heterogeneity=%.3f\n', numel(vals{iP,1}), sdVals(iP,1));
	fprintf('  Session k+1: n=%d cells, Response heterogeneity=%.3f\n', numel(vals{iP,2}), sdVals(iP,2));
end

repPairIdx = 1;
repSessIdx = 1;
repSD = -Inf;
excludeDt = iERepresentativeTransferDate(DS, idx1s);
for iP = 1:2
	for iS = 1:2
		if ~isnat(excludeDt) && dtVals(iP, iS) == excludeDt
			continue;
		end
		if isfinite(sdVals(iP, iS)) && sdVals(iP, iS) > repSD
			repSD = sdVals(iP, iS);
			repPairIdx = iP;
			repSessIdx = iS;
		end
	end
end

pairTags = ["PairA", "PairB"];
sessTags = ["SessionK", "SessionK1"];
repDt = dtVals(repPairIdx, repSessIdx);
fprintf('\nRepresentative session: %s %s, DateTime=%s, Response heterogeneity=%.3f\n', ...
	pairTags(repPairIdx), sessTags(repSessIdx), datestr(repDt, 'yyyy-mm-dd HH:MM'), repSD);
repMouse = string(SessSpeed.Mouse(pairsIdx(repPairIdx)));
repNCells = numel(vals{repPairIdx, repSessIdx});
fprintf('Fig342A stats: representative n=1 mouse (%s), %d cells, Response heterogeneity=%.3f; correlation/significance test not applicable.\n', ...
	repMouse, repNCells, repSD);

%% ===== 5) Export representative volshow PNG =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end

rd2 = rawData{repPairIdx, repSessIdx};
v2 = rd2(isfinite(rd2));
globalMin = min(v2);
globalMax = max(v2);
fprintf('Global clim (true range): [%.3f, %.3f]\n', globalMin, globalMax);

% ===== Volshow: symmetric cbrt clim from data range =====
vAbs = sqrt(max(abs(globalMin), abs(globalMax)));
fprintf('--- Symmetric cbrt clim from data range: [%.3f, %.3f] ---\n', -vAbs, vAbs);

nMap = 256;
nHalf = nMap / 2;
blueWhiteRed = [linspace(0,1,nHalf)', linspace(0,1,nHalf)', ones(nHalf,1); ...
                ones(nHalf,1), linspace(1,0,nHalf)', linspace(1,0,nHalf)'];
alphaVec = repmat(1/30, nMap, 1);

rd = rawData{repPairIdx, repSessIdx};
V = single(rd);
V_clamp = max(-vAbs, min(vAbs, V));
V_norm = iSymmetricNormalize(V_clamp, vAbs);
V_norm(isnan(V_norm)) = 0.5;
V_norm(1,1,1) = 0;
V_norm(end,end,end) = 1;

nCellsHere = size(V, 1);
nTime = size(V, 2);
nTrials = size(V, 3);
targetUnit = 30;
sX = 0.8 * targetUnit / nTime;
sY = 3 * targetUnit / nCellsHere;
sZ = targetUnit / nTrials;
tform = affinetform3d(diag([sX, sY, sZ, 1]));

fig = uifigure('Name', sprintf('Volshow %s %s', pairTags(repPairIdx), sessTags(repSessIdx)), ...
	'Color', 'w', 'Position', [100 100 800 320]);
viewer = viewer3d(fig, 'BackgroundColor', [1 1 1], 'BackgroundGradient', 'off', 'Lighting', 'off');

volshow(V_norm, 'Parent', viewer, ...
	'RenderingStyle', 'VolumeRendering', ...
	'Colormap', blueWhiteRed, ...
	'Alphamap', alphaVec, ...
	'Transformation', tform);

wX = nTime * sX;
wY = nCellsHere * sY;
wZ = nTrials * sZ;
ct = [(1+nTime)/2*sX, (1+nCellsHere)/2*sY, (1+nTrials)/2*sZ];
dist = max([wX, wY, wZ]) * 2.0;
elev = 25;
side = 30;
camOffset = [dist*cosd(elev)*cosd(side), dist*cosd(elev)*sind(side), dist*sind(elev)];
viewer.CameraTarget = ct;
viewer.CameraPosition = ct + camOffset;
Vcam = -camOffset / norm(camOffset);
Yaxis = [0, 1, 0];
projY = Yaxis - dot(Yaxis, Vcam) * Vcam;
upVec = cross(projY, Vcam);
viewer.CameraUpVector = upVec / norm(upVec);
viewer.CameraZoom = 1.4;

uilabel(fig, 'Text', 'X: Time (0~2 s)', 'FontSize', 6, 'FontColor', [0.85 0.1 0.1], ...
	'Position', [5, 48, 200, 16], 'BackgroundColor', 'none');
uilabel(fig, 'Text', 'Y: Cell (sorted by z@1s)', 'FontSize', 6, 'FontColor', [0.1 0.6 0.1], ...
	'Position', [5, 30, 200, 16], 'BackgroundColor', 'none');
uilabel(fig, 'Text', 'Z: Trial', 'FontSize', 6, 'FontColor', [0.1 0.1 0.85], ...
	'Position', [5, 12, 200, 16], 'BackgroundColor', 'none');

pause(1);
pngName = 'English_Fig3A_Volshow_Representative.png';
exportapp(fig, fullfile(outDirUNC, pngName));
fprintf('Wrote: %s\n', pngName);

cbSvgName = 'English_Fig3A_Volshow_Colorbar.svg';
iExportVolshowColorbarSVG(vAbs, blueWhiteRed, cbSvgName);
fprintf('Wrote: %s\n', cbSvgName);

%% ===== 6) Export representative histogram SVG (57 mm × 16 mm) =====
nBins = 40;
binEdges = linspace(-1, 1, nBins + 1);
v = vals{repPairIdx, repSessIdx};

fh = figure('Color', 'w');
fh.Units = 'centimeters';
fh.Position(3:4) = [5.7, 1.6]; % 57 mm × 16 mm

ax = axes(fh);
hold(ax, 'on');

histogram(ax, v, binEdges, 'Normalization', 'probability', ...
	'FaceColor', TransferLearning.TransferColor, 'EdgeColor', 'none');

xlim(ax, [-1, 1]);
ax.XTick = [-1, 0, 1];
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
box(ax, 'off');
grid(ax, 'off');

text(ax, 0.97, 0.95, sprintf('RH=%.2f', sdVals(repPairIdx, repSessIdx)), ...
	'Units', 'normalized', 'HorizontalAlignment', 'right', ...
	'VerticalAlignment', 'top', 'FontWeight', 'bold');
title(ax, 'A representative transfer block');

xlabel(ax, 'z-score');
ylabel(ax, {'Prop. of'; 'cells'});

svgN = 'English_Fig3A_Hist_Representative.svg';
TransferLearning.ExportStandardFigure(fh, 1, svgN);
fprintf('Wrote: %s\n', svgN);

%% ===== Local functions =====

function Vn = iSymmetricNormalize(V, vAbs)
% SymmetricColormap style: shared magnitude on both sides, zero maps to center.
if ~isfinite(vAbs) || vAbs <= 0
	Vn = 0.5 * ones(size(V), 'like', V);
	return;
end
Vn = 0.5 + 0.5 * (V / vAbs);
Vn = max(0, min(1, Vn));
end

function iExportVolshowColorbarSVG(vAbs, cmap, svgName)
cbFig = figure('Color', 'none');
cbFig.Units = 'centimeters';
cbFig.Position(3:4) = [1.2, 7.0];

ax = axes(cbFig, 'Position', [0.10, 0.05, 0.10, 0.90]);
axis(ax, 'off');
colormap(ax, cmap);
clim(ax, [-vAbs, vAbs]);

cb = colorbar(ax, 'eastoutside');
cb.Position = [0.50, 0.08, 0.22, 0.84];
cb.Label.String = 'z-score';
cb.FontSize = 6;
cb.Box = 'off';

TransferLearning.ExportStandardFigureTransparent(cbFig, 3, svgName);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function dtSel = iERepresentativeTransferDate(DS, idx1s)
dtSel = NaT;
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iExcludeCeiling(Sess);
if isempty(Sess), return; end

allDTs = unique(Sess.DateTime);
bestSD = -Inf;
for i = 1:numel(allDTs)
	[~, ntats] = iSessionNTATS(DS, allDTs(i));
	if isempty(ntats), continue; end
	v = double(ntats(:, idx1s));
	v = v(isfinite(v) & v >= -1 & v <= 1);
	if numel(v) < 3, continue; end
	s = std(v);
	if isfinite(s) && s > bestSD
		bestSD = s;
		dtSel = allDTs(i);
	end
	end
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
Stim = string(Tr.Stimulus);

TrLW = Tr(Stim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Phase','Performance','NBlocksInSession'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});

T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');

[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perfSess = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
nBlocks = splitapply(@numel, T.LWPerf, G2);
phase = splitapply(@(x) string(x(1)), T.Phase, G2);

Sess = table(mouse, dt, phase, perfSess, nBlocks, ...
	'VariableNames', {'Mouse','DateTime','Phase','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end

Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
Stim = string(Tr.Stimulus);

TrAW = Tr(Stim == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end

blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end

function SessSpeed = iSessionDeltaNext(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(Sess.Mouse);

nTotal = 0;
for mi = 1:numel(mice)
	R = Sess(Sess.Mouse == mice(mi), :);
	perf = double(R.Performance);
	use = isfinite(perf) & ~ismissing(R.DateTime);
	nTotal = nTotal + max(0, nnz(use) - 1);
end

outM = strings(nTotal, 1);
outDT = NaT(nTotal, 1);
outP = nan(nTotal, 1);
outDT2 = NaT(nTotal, 1);
outP2 = nan(nTotal, 1);
outDN = nan(nTotal, 1);

pos = 0;
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance);
	dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	perf = perf(use);
	dt = dt(use);
	if numel(perf) < 2, continue; end
	dn = diff(perf);
	n = numel(dn);
	idx = (pos + 1):(pos + n);
	outM(idx) = repmat(m, n, 1);
	outDT(idx) = dt(1:end-1);
	outP(idx) = perf(1:end-1);
	outDT2(idx) = dt(2:end);
	outP2(idx) = perf(2:end);
	outDN(idx) = dn(:);
	pos = pos + n;
end

if pos < nTotal
	outM(pos+1:end) = [];
	outDT(pos+1:end) = [];
	outP(pos+1:end) = [];
	outDT2(pos+1:end) = [];
	outP2(pos+1:end) = [];
	outDN(pos+1:end) = [];
end

SessSpeed = table(outM, outDT, outP, outDT2, outP2, outDN, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end

function [uid, ntats, ntsRaw] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T)
	uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return;
end

des = unique(string(T.Design));
des = des(~ismissing(des));
if numel(des) ~= 1
	uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return;
end

G = DS.QueryNTS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), ...
	UniExp.Flags.ZScore, 1:24);
if isempty(G), uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return; end
if iscell(G), G = G{1}; end
if isempty(G), uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return; end

cellUIDs  = uint64(G.CellUID);
trialUIDs = uint64(G.TrialUID);
if isa(G.TrialSignal, 'MATLAB.DataTypes.NDTable')
	ntsAll = double(G.TrialSignal.Data);
else
	ntsAll = double(G.TrialSignal);
end

uid   = unique(cellUIDs,  'stable');
tids  = unique(trialUIDs, 'stable');
nCells  = numel(uid);
nTrials = numel(tids);
nTime   = size(ntsAll, 2);

% per-cell median (for histogram)
ntats  = nan(nCells, nTime);
% per-cell per-trial (for 3D surf): cells × time × trials
ntsRaw = nan(nCells, nTime, nTrials);

for ic = 1:nCells
	rowsC = (cellUIDs == uid(ic));
	ntats(ic, :) = median(ntsAll(rowsC, :), 1, 'omitnan');
	for it = 1:nTrials
		rowsCT = rowsC & (trialUIDs == tids(it));
		if any(rowsCT)
			ntsRaw(ic, :, it) = mean(ntsAll(rowsCT, :), 1, 'omitnan');
		end
	end
end
end

