% 英文图3C：代表性弱响应细胞的单回合示意
%
% 目的：展示弱响应细胞（|median z-score@1s| ≤ 1）的低中位活动并非噪音，
%       而是因为响应概率较低——在部分回合有明确响应，其余回合无响应。
%
% 选取标准：
%   - 与图 B 相同的 Pair A（最高 inter-cell SD）的 session k+1（右上 tile）
%   - 该会话细胞先按 z-score@1s 过滤到 [-1,1]，再取最大/中位/最小
%
% 布局：
%   单面板热图（行=回合，列=时间），与 B 图 heatmap 风格一致
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.C_SingleTrialResponseProbability

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
svgName  = "English_Fig3C_SingleTrialResponseProbability.svg";

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));

%% ===== 1) Replicate B's Pair A selection to get the same session =====
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iExcludeCeiling(Sess);

SessSpeed = iSessionDeltaNext(Sess);
nPairs = height(SessSpeed);
deltaHit = double(SessSpeed.Speed_DeltaNext);

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
	vK  = vK(isfinite(vK) & vK >= -2 & vK <= 2);
	vK1 = vK1(isfinite(vK1) & vK1 >= -2 & vK1 <= 2);
	nCellMin(iP) = min(numel(vK), numel(vK1));
	if numel(vK) >= 3 && numel(vK1) >= 3
		sd1sK(iP)  = std(vK);
		sd1sK1(iP) = std(vK1);
		sd1sMean(iP) = (sd1sK(iP) + sd1sK1(iP)) / 2;
	end
end

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
	error('Fig3C:NoFeasible', 'Cannot find Pair A (same as Fig3B).');
end

% Target session: Pair A, session k+1 (B's top-right tile)
targetDT = SessSpeed.DateTimeNext(bestA);
fprintf('Pair A session k+1 (B top-right tile): %s, Mouse=%s\n', ...
	datestr(targetDT, 'yyyy-mm-dd HH:MM'), string(SessSpeed.Mouse(bestA)));

%% ===== 2) Get all cells in this session, find min/median/max cells =====
[cellUIDs, ntats] = iSessionNTATS(DS, targetDT);
v1s = double(ntats(:, idx1s));

% Filter to finite values in [-1,1] (matching B's convention)
keepMask = isfinite(v1s) & v1s >= -1 & v1s <= 1;
cellUIDs_filt = cellUIDs(keepMask);
v1s_filt = v1s(keepMask);

% Sort by z-score@1s, pick max / median / min
[v1s_sorted, sortIdx] = sort(v1s_filt, 'ascend');
nCells = numel(v1s_sorted);
ranks = [nCells, ceil(nCells/2), 1];  % max, median, min
pickCells = cellUIDs_filt(sortIdx(ranks));
pickZ     = v1s_sorted(ranks);
rankLabels = {"Max", "Median", "Min"};

for iR = 1:3
	fprintf('  %s cell: CellUID=%d, rank=%d/%d, z@1s=%.3f\n', ...
		rankLabels{iR}, pickCells(iR), ranks(iR), nCells, pickZ(iR));
end

%% ===== 3) Extract trial-level data for the 3 selected cells =====
% CLim rule: global min/max across 3 panels, then signed sqrt
q = struct('Stimulus', 'LightWater', 'DateTime', targetDT);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["CellUID","DateTime"]);
ntsAll = ntsCell{1};
ntsAll.CellUID = uint64(ntsAll.CellUID);
timeMask = xsSec >= 0 & xsSec <= 2;
tDisp = xsSec(timeMask);

% Collect per-cell trial data
allSig = {};
for iR = 1:3
	selRows = ntsAll(ntsAll.CellUID == pickCells(iR), :);
	sig = double(selRows.TrialSignal);
	allSig{iR} = sig(:, timeMask);
end

% CLim: global min/max across 3 panels (raw, no sqrt transform)
% NOTE: signed sqrt was wrong here — it shrinks CLim relative to raw data,
%       causing large portions of extreme values to clip to pure blue/red.
%       Use ScaleColor flag in LanearHeatmap instead if sqrt scaling is desired.
allVals = cellfun(@(x) x(:), allSig, 'UniformOutput', false);
allVals = vertcat(allVals{:});
allVals = allVals(isfinite(allVals));
if isempty(allVals)
	CLim = [-1, 1];
else
	vMin = min(allVals);
	vMax = max(allVals);
	CLim = [vMin, vMax];
	if CLim(1) == CLim(2)
		CLim = [-1, 1];
	end
end

%% ===== Figure: 3 rows × 1 column =====
f = figure('Color', 'w', 'Name', 'English Fig3C Representative Cells');
f.Units = 'centimeters';
f.Position(3:4) = [3, 8];  % 30mm × 80mm

tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

laneData = cat(3, allSig{:});
[~, axAll] = UniExp.LanearHeatmap(laneData, ...
	'LMHColor', [0,0,1; 1,1,1; 1,0,0], ...
	'CLim', CLim, ...
	...'Flags', UniExp.Flags.SymmetricColormap, ...
	'XData', tDisp, ...
	'Layout', tl);

tl.YLabel.String = 'Trial #';
tl.YLabel.FontSize = 6;
tl.YLabel.FontName = 'Segoe UI';

% Style all axes
axAll = axAll(isgraphics(axAll));
if ~isempty(axAll)
	tiles = arrayfun(@(a) a.Layout.Tile, axAll);
	[~, ord] = sort(tiles);
	axAll = axAll(ord); % top to bottom = max, median, min
end

for iR = 1:3
	ax = axAll(iR);
	ax.YDir = 'normal';
	hold(ax, 'on');
	xline(ax, 0, ':k', 'LineWidth', 0.5);
	xline(ax, 1, '-k', 'LineWidth', 0.5);
	hold(ax, 'off');

	ax.FontSize = 6;
	ax.FontName = 'Segoe UI Emoji';
	box(ax, 'on');

	if iR == 3
		% Bottom panel: show x-axis labels
		ax.XTick = [0 1];
		ax.XTickLabel = {'💡','💧'};
		xlabel(ax, 'Time', 'FontSize', 6);
	else
		% Upper panels: hide x-axis
		ax.XTick = [0 1];
		ax.XTickLabel = {};
		xlabel(ax, '');
	end
end

%% ===== Export =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3C_CellUIDs', pickCells);
assignin('base', 'Fig3C_DateTime', targetDT);
assignin('base', 'Fig3C_Zscores', pickZ);

%% ===== Local functions =====

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

function [uid, ntats] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T)
	uid = uint64.empty(0,1); ntats = []; return;
end

des = unique(string(T.Design));
des = des(~ismissing(des));
if numel(des) ~= 1
	error('Fig3C:AmbiguousDesign', ...
		'Expected 1 LightWater Design in DateTime %s, got %d.', datestr(dt), numel(des));
end

G = DS.QueryNTATS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

uid = uint64(G.CellUID);
if isa(G.NTATS, 'MATLAB.DataTypes.NDTable')
	ntats = double(G.NTATS.Data);
else
	ntats = double(G.NTATS);
end
end
