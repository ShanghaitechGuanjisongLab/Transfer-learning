% 英文图3B：代表性会话对的热图 + 细胞间 1s z-score 分布
%
% Pair A: 前后会话平均 inter-cell SD@1s（[-1,1] 细胞）尽可能大
% Pair B: 前后会话平均 inter-cell SD@1s（[-1,1] 细胞）尽可能小
% 约束: ΔHit(A) > ΔHit(B)
%
% 布局: 2×4 tiledlayout（2 行 = Pair A/B，每行：热图k|直方图k|热图k+1|直方图k+1）
%   热图：per-cell median z-score 按 @1s 排序，模仿 2B 风格
%   直方图：横向 (z-score on Y axis)，范围 [-2,2]
%   右侧标注 Moderates / Extremists
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.B_RepresentativeSD_NTATSDistribution

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

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

xMask = (xsSec >= 0) & (xsSec <= 2); % 0~2s for heatmap

for iP = 1:2
	idx = pairsIdx(iP);
	dtK  = SessSpeed.DateTime(idx);
	dtK1 = SessSpeed.DateTimeNext(idx);

	for iS = 1:2
		if iS == 1, dt = dtK; else, dt = dtK1; end
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
	fprintf('Pair %s: Mouse=%s, k=%s, k+1=%s, ΔHit=%+.1f%%, meanSD=%.3f\n', ...
		pLabel, string(SessSpeed.Mouse(idx)), ...
		datestr(dtK, 'yyyy-mm-dd HH:MM'), datestr(dtK1, 'yyyy-mm-dd HH:MM'), ...
		100 * deltaHit(idx), sd1sMean(idx));
	fprintf('  Session k:   n=%d cells, SD=%.3f\n', numel(vals{iP,1}), sdVals(iP,1));
	fprintf('  Session k+1: n=%d cells, SD=%.3f\n', numel(vals{iP,2}), sdVals(iP,2));
end

%% ===== 5) Export 4 volshow PNGs =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end

pairTags = ["PairA", "PairB"];
sessTags = ["SessionK", "SessionK1"];

% Compute true global min/max from all 4 volumes (no percentile, no clamping)
globalMin = Inf; globalMax = -Inf;
for iP2 = 1:2
	for iS2 = 1:2
		rd2 = rawData{iP2, iS2};
		if isempty(rd2), continue; end
		v2 = rd2(isfinite(rd2));
		globalMin = min(globalMin, min(v2));
		globalMax = max(globalMax, max(v2));
	end
end
fprintf('Global clim (true range): [%.3f, %.3f]\n', globalMin, globalMax);

% Compute minCells for uniform cell-axis scaling
minCells = min(cellfun(@(x) size(x,1), rawData(:)));

% ===== Volshow: cbrt clim scale (data unchanged, clim = cbrt of extremes) =====
vAbs = nthroot(max(abs([globalMin, globalMax])), 3);
fprintf('--- Cbrt clim (symmetric): [%.3f, %.3f] ---\n', -vAbs, vAbs);

nMap = 256;
nHalf = nMap / 2;
blueWhiteRed = [linspace(0,1,nHalf)', linspace(0,1,nHalf)', ones(nHalf,1); ...
                ones(nHalf,1), linspace(1,0,nHalf)', linspace(1,0,nHalf)'];
alphaVec = repmat(0.04, nMap, 1);

for iP = 1:2
	for iS = 1:2
		rd = rawData{iP, iS};
		if isempty(rd), continue; end

		V = single(rd);
		V_clamp = max(-vAbs, min(vAbs, V));
		V_norm = iSymmetricNormalize(V_clamp, vAbs);
		V_norm(isnan(V_norm)) = 0.5;
		% V_norm 保持 (cells, time, trials)
		% volshow: dim1→X=cells, dim2→Y=time, dim3→Z=trials
		% 锚点体素：强制volshow的自动归一化范围为[0,1]
		V_norm(1,1,1) = 0;
		V_norm(end,end,end) = 1;

		nCellsHere = size(V, 1);
		nTime = size(V, 2);
		nTrials = size(V, 3);
		% volshow: dim1→intrinsicY, dim2→intrinsicX, dim3→intrinsicZ
		% 变换矩阵 diag 顺序: [scaleX(=dim2=time), scaleY(=dim1=cells), scaleZ(=dim3=trials)]
		targetUnit = 30;
		sX = 0.3 * targetUnit / nTime;       % time → world X (薄)
		sY = 3 * targetUnit / nCellsHere;    % cells → world Y (最长)
		sZ = targetUnit / nTrials;            % trials → world Z
		tform = affinetform3d(diag([sX, sY, sZ, 1]));

		fig = uifigure('Name', sprintf('Volshow %s %s', pairTags(iP), sessTags(iS)), ...
			'Color', 'w', 'Position', [100 100 800 320]);
		viewer = viewer3d(fig, 'BackgroundColor', [1 1 1], 'BackgroundGradient', 'off', 'Lighting', 'off');

		volshow(V_norm, 'Parent', viewer, ...
			'RenderingStyle', 'VolumeRendering', ...
			'Colormap', blueWhiteRed, ...
			'Alphamap', alphaVec, ...
			'Transformation', tform);

		% 物理尺寸: worldX=time*sX, worldY=cells*sY, worldZ=trials*sZ
		wX = nTime * sX;    % ≈9
		wY = nCellsHere * sY;  % ≈90
		wZ = nTrials * sZ;  % =30
		ct = [(1+nTime)/2*sX, (1+nCellsHere)/2*sY, (1+nTrials)/2*sZ];
		dist = max([wX, wY, wZ]) * 2.0;
		elev = 20;  % 俯角
		side = 5;   % 微侧，使time厚度可见
		% 从+X方向看：Y(cells)水平，Z(trials)部分垂直
		viewer.CameraTarget = ct;
		viewer.CameraPosition = ct + [dist*cosd(elev)*cosd(side), dist*cosd(elev)*sind(side), dist*sind(elev)];
		viewer.CameraUpVector = [0, 0, 1];
		viewer.CameraZoom = 1.5;

		uilabel(fig, 'Text', 'X: Time (0~2 s)', 'FontSize', 7, 'FontColor', [0.85 0.1 0.1], ...
			'Position', [5, 48, 200, 16], 'BackgroundColor', 'none');
		uilabel(fig, 'Text', 'Y: Cell (sorted by z@1s)', 'FontSize', 7, 'FontColor', [0.1 0.6 0.1], ...
			'Position', [5, 30, 200, 16], 'BackgroundColor', 'none');
		uilabel(fig, 'Text', 'Z: Trial', 'FontSize', 7, 'FontColor', [0.1 0.1 0.85], ...
			'Position', [5, 12, 200, 16], 'BackgroundColor', 'none');

		pause(1);
		pngName = sprintf('English_Fig3B_Volshow_%s_%s.png', pairTags(iP), sessTags(iS));
		exportapp(fig, fullfile(outDirUNC, pngName));
		fprintf('Wrote: %s\n', pngName);
	end
end

%% ===== 6) Export 4 histogram SVGs (15 mm × 40 mm) =====
nBins = 40;
binEdges = linspace(-1, 1, nBins + 1);
pairColors = {[0.8500 0.3250 0.0980]; [0 0.4470 0.7410]};

for iP = 1:2
	for iS = 1:2
		v = vals{iP, iS};

		fh = figure('Color', 'w');
		fh.Units = 'centimeters';
		fh.Position(3:4) = [1.5, 4]; % 15 mm × 40 mm

		ax = axes(fh);
		hold(ax, 'on');

		histogram(ax, v, binEdges, 'Normalization', 'probability', ...
			'Orientation', 'horizontal', ...
			'FaceColor', pairColors{iP}, 'FaceAlpha', 0.7, 'EdgeColor', 'none');
		yline(ax, mean(v), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

		ylim(ax, [-1, 1]);
		ax.YTick = [-1, 0, 1];
		yline(ax, -1, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
		yline(ax, 1, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);

		ax.FontSize = 6;
		box(ax, 'off');
		grid(ax, 'off');

		text(ax, 0.05, 0.97, sprintf('SD=%.2f', sdVals(iP, iS)), ...
			'Units', 'normalized', 'HorizontalAlignment', 'left', ...
			'VerticalAlignment', 'top', 'FontSize', 5, 'FontWeight', 'bold');

		ylabel(ax, 'z-score', 'FontSize', 6);
		xlabel(ax, 'Prop.', 'FontSize', 6);

		svgN = sprintf('English_Fig3B_Hist_%s_%s.svg', pairTags(iP), sessTags(iS));
		TransferLearning.PrintFigure(fh, fullfile(outDirUNC, svgN));
		fprintf('Wrote: %s\n', svgN);
		close(fh);
	end
end

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

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
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
