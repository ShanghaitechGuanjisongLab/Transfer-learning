% 英文图3C：代表性相邻会话对（后一个会话）两泳道热图
%
% 参考：英文图3 Z_* 探索代码（ΔHit / 1s SD）以及英文图1F 的热图样式。
%
% 目标：
% - 自动从 LightWater 相邻会话对中挑选两个代表性会话对（两对可不同鼠）。
% - 要求两对之间 ΔHit 差异尽可能大，且后一个会话的 1s inter-cell SD 差异尽可能大。
% - 约束：1s SD 较大的泳道，其 ΔHit 必须也更大。
% - 只画两个会话对的“后一个会话”(k+1) 的热图，做成两条泳道。
% - 不做细胞对齐；每条泳道内部按 1s 信号值降序排序。
% - 小标题标注 ΔHit。
%
% Execution:
%   TransferLearning.英文图3.C_RepresentativeSessionPairs_LWHeatmaps

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3C_RepresentativeSessionPairs_LWHeatmaps.svg";

% --- Preconditions (no try-catch)
if ~exist('UniExp.DataSet', 'class')
	error('EnglishFig3C:MissingUniExp', 'UniExp is not on path; load the project first.');
end

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('EnglishFig3C:No1s', 'Cannot find sample close to 1s.');
end

% --- Build session table (LightWater only)
% Note: MustWarn is a warning flag; do NOT automatically exclude sessions here.
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iExcludeCeiling(Sess);

if height(Sess) < 4
	error('EnglishFig3C:TooFewSessions', 'Too few valid LightWater sessions after filtering.');
end

SessSpeed = iSessionDeltaNext(Sess);
if isempty(SessSpeed)
	error('EnglishFig3C:NoPairs', 'No adjacent session pairs found.');
end

nPairs = height(SessSpeed);
deltaHit = double(SessSpeed.Speed_DeltaNext);

% --- Compute SD@1s in session k+1 (inter-cell SD)
% Use per-cell median (NTATS) built from QueryNTS (ZScore), per session.
sd1sK1 = nan(nPairs, 1);
nCellK1 = nan(nPairs, 1);

for iP = 1:nPairs
	dtK1 = SessSpeed.DateTimeNext(iP);
	[~, ntatsK1] = iSessionNTATS_QueryNTATS(DS, dtK1);
	if isempty(ntatsK1)
		continue;
	end
	v1 = double(ntatsK1(:, idx1s));
	v1 = v1(isfinite(v1));
	nCellK1(iP) = numel(v1);
	if numel(v1) >= 3
		sd1sK1(iP) = std(v1, 0, 1);
	end
end

% --- Pick two representative pairs
valid = isfinite(deltaHit) & isfinite(sd1sK1) & (nCellK1 >= 10);
valid = valid & (deltaHit > 0); % focus on performance gains

if nnz(valid) < 2
	error('EnglishFig3C:NoValidPairs', 'Not enough valid session pairs with finite ΔHit and SD@1s.');
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
		if ~(sd1sK1(i) > sd1sK1(j) && deltaHit(i) > deltaHit(j))
			continue;
		end
		sdDiff = sd1sK1(i) - sd1sK1(j);
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
	error('EnglishFig3C:NoFeasibleSelection', 'Cannot find two pairs satisfying SD_high>SD_low and ΔHit_high>ΔHit_low.');
end

pairsIdx = [bestHigh; bestLow];

% --- Fetch heatmap data for the TWO selected k+1 sessions
laneX = cell(1,2);
laneN = zeros(2,1);
laneSub = strings(1,2);

for k = 1:2
	iP = pairsIdx(k);
	dtK1 = SessSpeed.DateTimeNext(iP);
	[uid, ntats] = iSessionNTATS_QueryNTATS(DS, dtK1);
	if isempty(ntats)
		error('EnglishFig3C:MissingNTATS', 'Selected session has no calcium data: %s', datestr(dtK1));
	end

	X = double(ntats(:, xMask));
	v1 = double(ntats(:, idx1s));
	v1(~isfinite(v1)) = -Inf;
	[~, sIdx] = sort(v1, 'descend');
	X = X(sIdx, :);
	laneX{k} = X;
	laneN(k) = size(X, 1);
	laneSub(k) = sprintf('ΔHit=%+.0f%%\nSD=%.2f', 100 * double(deltaHit(iP)), double(sd1sK1(iP)));

	fprintf('Selected pair #%d: Mouse=%s, k=%s, k+1=%s, ΔHit=%+.3f, SD@1s(k+1)=%.4f, nCells=%d\n', ...
		k, string(SessSpeed.Mouse(iP)), ...
		datestr(SessSpeed.DateTime(iP), 'yyyy-mm-dd HH:MM:SS'), ...
		datestr(SessSpeed.DateTimeNext(iP), 'yyyy-mm-dd HH:MM:SS'), ...
		double(deltaHit(iP)), double(sd1sK1(iP)), laneN(k));

	assignin('base', sprintf('EnglishFig3C_UID_%d', k), uid(sIdx));
	assignin('base', sprintf('EnglishFig3C_SortKey1s_%d', k), v1(sIdx));
end

if any(laneN < 1)
	error('EnglishFig3C:EmptyHeatmap', 'Heatmap data is empty.');
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
f = figure('Color', 'w', 'Name', 'English Fig3C Representative Session Pairs (LW heatmaps)');
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

assignin('base', 'EnglishFig3C_SelectedPairIdx', pairsIdx);
assignin('base', 'EnglishFig3C_SessSpeed', SessSpeed);
assignin('base', 'EnglishFig3C_SD1s_K1', sd1sK1);

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
	error('EnglishFig3C:AmbiguousDesign', 'Expected exactly 1 LightWater Design in DateTime %s, got %d.', datestr(dt), numel(des));
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


