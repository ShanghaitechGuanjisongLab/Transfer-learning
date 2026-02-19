% 英文图3E：代表性相邻会话对（前后会话均值）两泳道热图
%
% 参考：英文图3 Z_* 探索代码（ΔHit / 1s SD）以及英文图1F 的热图样式。
%
% 目标：
% - 自动从 LightWater 相邻会话对中挑选两个代表性会话对（两对可不同鼠）。
% - 要求两对之间 ΔHit 差异尽可能大，且 1s inter-cell SD (前后会话均值) 差异尽可能大。
% - 约束：1s SD 较大的泳道，其 ΔHit 必须也更大。
% - 每个会话对取前后两个会话的共同细胞 NTATS 均值，做成两条泳道。
% - 不做细胞对齐；每条泳道内部按 1s 信号值降序排序。
% - 小标题标注 ΔHit。
% - SD 指标 = mean(SD_k, SD_{k+1})，即前后两个会话细胞间 SD 的均值。
%
% Execution:
%   TransferLearning.英文图3.E_RepresentativeSessionPairs_LWHeatmaps

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3E_RepresentativeSessionPairs_LWHeatmaps.svg";

% --- Preconditions (no try-catch)
if ~exist('UniExp.DataSet', 'class')
	error('EnglishFig3E:MissingUniExp', 'UniExp is not on path; load the project first.');
end

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('EnglishFig3E:No1s', 'Cannot find sample close to 1s.');
end

% --- Build session table (LightWater only)
% Note: MustWarn is a warning flag; do NOT automatically exclude sessions here.
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iExcludeCeiling(Sess);

if height(Sess) < 4
	error('EnglishFig3E:TooFewSessions', 'Too few valid LightWater sessions after filtering.');
end

SessSpeed = iSessionDeltaNext(Sess);
if isempty(SessSpeed)
	error('EnglishFig3E:NoPairs', 'No adjacent session pairs found.');
end

nPairs = height(SessSpeed);
deltaHit = double(SessSpeed.Speed_DeltaNext);

% --- Compute SD@1s: mean of inter-cell SD across sessions k and k+1
% Use per-cell median (NTATS) built from QueryNTS (ZScore), per session.
sd1sMean = nan(nPairs, 1);
nCellMin = nan(nPairs, 1);

for iP = 1:nPairs
	dtK  = SessSpeed.DateTime(iP);
	dtK1 = SessSpeed.DateTimeNext(iP);
	[~, ntatsK]  = iSessionNTATS_QueryNTATS(DS, dtK);
	[~, ntatsK1] = iSessionNTATS_QueryNTATS(DS, dtK1);
	if isempty(ntatsK) || isempty(ntatsK1)
		continue;
	end
	vK  = double(ntatsK(:, idx1s));
	vK1 = double(ntatsK1(:, idx1s));
	vK  = vK(isfinite(vK));
	vK1 = vK1(isfinite(vK1));
	nCellMin(iP) = min(numel(vK), numel(vK1));
	if numel(vK) >= 3 && numel(vK1) >= 3
		sd1sMean(iP) = (std(vK, 0, 1) + std(vK1, 0, 1)) / 2;
	end
end

% --- Pick two representative pairs
valid = isfinite(deltaHit) & isfinite(sd1sMean) & (nCellMin >= 10);
valid = valid & (deltaHit > 0); % focus on performance gains

if nnz(valid) < 2
	error('EnglishFig3E:NoValidPairs', 'Not enough valid session pairs with finite ΔHit and SD@1s.');
end

bestHigh = NaN;
bestLow = NaN;
bestSdDiff = -Inf;
bestDhDiff = -Inf;
epsTie = 1e-12;

for i = 1:nPairs
	if ~valid(i), continue; end
	for j = 1:nPairs
		if i == j || ~valid(j), continue; end
		% i is the high-SD lane; must also be higher ΔHit
		if ~(sd1sMean(i) > sd1sMean(j) && deltaHit(i) > deltaHit(j))
			continue;
		end
		sdDiff = sd1sMean(i) - sd1sMean(j);
		dhDiff = deltaHit(i) - deltaHit(j);
		if (sdDiff > bestSdDiff + epsTie) || (abs(sdDiff - bestSdDiff) <= epsTie && dhDiff > bestDhDiff)
			bestHigh = i;
			bestLow = j;
			bestSdDiff = sdDiff;
			bestDhDiff = dhDiff;
		end
	end
end

if ~isfinite(bestHigh) || ~isfinite(bestLow)
	error('EnglishFig3E:NoFeasibleSelection', 'Cannot find two pairs satisfying SD_high>SD_low and ΔHit_high>ΔHit_low.');
end

pairsIdx = [bestHigh; bestLow];

% --- Fetch heatmap data for the TWO selected k+1 sessions
laneX = cell(1,2);
laneN = zeros(2,1);
laneSub = strings(1,2);

for k = 1:2
	iP = pairsIdx(k);
	dtK  = SessSpeed.DateTime(iP);
	dtK1 = SessSpeed.DateTimeNext(iP);
	[uidK,  ntatsK]  = iSessionNTATS_QueryNTATS(DS, dtK);
	[uidK1, ntatsK1] = iSessionNTATS_QueryNTATS(DS, dtK1);
	if isempty(ntatsK) || isempty(ntatsK1)
		error('EnglishFig3E:MissingNTATS', 'Selected session pair has no calcium data: %s / %s', datestr(dtK), datestr(dtK1));
	end

	% Find common cells and average NTATS
	[commonUID, locK, locK1] = intersect(uidK, uidK1);
	if numel(commonUID) < 3
		error('EnglishFig3E:TooFewCommon', 'Too few common cells (%d) in pair: %s / %s', numel(commonUID), datestr(dtK), datestr(dtK1));
	end
	ntatsAvg = (double(ntatsK(locK, :)) + double(ntatsK1(locK1, :))) / 2;

	X = ntatsAvg(:, xMask);
	v1 = ntatsAvg(:, idx1s);
	v1(~isfinite(v1)) = -Inf;
	[~, sIdx] = sort(v1, 'descend');
	X = X(sIdx, :);
	laneX{k} = X;
	laneN(k) = size(X, 1);
	laneSub(k) = sprintf('ΔHit=%+.0f%%\nSD=%.2f', 100 * double(deltaHit(iP)), double(sd1sMean(iP)));

	fprintf('Selected pair #%d: Mouse=%s, k=%s, k+1=%s, ΔHit=%+.3f, meanSD@1s=%.4f, nCommonCells=%d\n', ...
		k, string(SessSpeed.Mouse(iP)), ...
		datestr(SessSpeed.DateTime(iP), 'yyyy-mm-dd HH:MM:SS'), ...
		datestr(SessSpeed.DateTimeNext(iP), 'yyyy-mm-dd HH:MM:SS'), ...
		double(deltaHit(iP)), double(sd1sMean(iP)), laneN(k));

	assignin('base', sprintf('EnglishFig3E_UID_%d', k), commonUID(sIdx));
	assignin('base', sprintf('EnglishFig3E_SortKey1s_%d', k), v1(sIdx));
end

if any(laneN < 1)
	error('EnglishFig3E:EmptyHeatmap', 'Heatmap data is empty.');
end

% --- Shared CLim (sqrt of actual positive/negative range, asymmetric)
allVals = cellfun(@(D)D(:), laneX, 'UniformOutput', false);
allVals = vertcat(allVals{:});
negV = min(allVals, [], 'all', 'omitnan');
posV = max(allVals, [], 'all', 'omitnan');
if ~isfinite(negV) || negV >= 0, negV = -1; end
if ~isfinite(posV) || posV <= 0, posV = 1; end
CLim = [-sqrt(abs(negV)), sqrt(posV)];

%% 
% --- Plot
f = figure('Color', 'w', 'Name', 'English Fig3E Representative Session Pairs (LW heatmaps)');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];

Layout = tiledlayout(f, 1, 2, 'TileSpacing', 'none', 'Padding', 'tight');

[~, Axes] = UniExp.LanearHeatmap( ...
	laneX, ...
	SubTitles=laneSub, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[0,0,1; 1,1,1; 1,0,0]);

xlabel(Layout, 'Time', 'FontSize', 12);
ylabel(Layout, '', 'FontSize', 12);

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.FontSize = 12;

for iA = 1:numel(Axes)
	ax = Axes(iA);
	if ~isgraphics(ax), continue; end
	box(ax, 'off');
	grid(ax, 'off');
	ax.FontSize = 12;
	ax.FontName = 'Segoe UI Emoji';
	ax.TickDir = 'in';
	ax.XTick = [0 1];
	ax.XTickLabel = {"💡", "💧"};
	xline(ax, 0, ':k');
	xline(ax, 1, '-k');
	if isgraphics(ax.Title)
		ax.Title.FontSize = 12;
		ax.Title.FontWeight = 'normal';
	end
end

% --- Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'EnglishFig3E_SelectedPairIdx', pairsIdx);
assignin('base', 'EnglishFig3E_SessSpeed', SessSpeed);
assignin('base', 'EnglishFig3E_SD1s_Mean', sd1sMean);

%% --- Local helpers (NO try-catch)

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
% Build per-session LightWater performance by joining Trials->Blocks->DateTimes.

Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone)
	Blocks.DateTime.TimeZone = '';
end
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone)
	DT.DateTime.TimeZone = '';
end
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
% Exclude sessions (DateTime) that contain ANY AudioWater trials.

SessOut = SessIn;
if isempty(SessOut), return; end

Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone)
	Blocks.DateTime.TimeZone = '';
end

Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
Stim = string(Tr.Stimulus);

TrAW = Tr(Stim == "AudioWater", {'BlockUID'});
if isempty(TrAW)
	return;
end

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
	if numel(perf) < 2
		continue;
	end
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

function [uid, ntats] = iSessionNTATS_QueryNTATS(DS, dt)
% Build per-cell median trace for one session (DateTime) from QueryNTATS.
% Per project rule: NTATS must be retrieved via UniExp.DataSet.QueryNTATS.

T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T)
	uid = uint64.empty(0,1);
	ntats = [];
	return;
end

des = unique(string(T.Design));
des = des(~ismissing(des));
if numel(des) ~= 1
		error('EnglishFig3E:AmbiguousDesign', 'Expected exactly 1 LightWater Design in DateTime %s, got %d.', datestr(dt), numel(des));
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


