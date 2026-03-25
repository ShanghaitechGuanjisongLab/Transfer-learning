% 英文图3E：代表性单会话 3D 热图 + 细胞间 1s z-score 分布
%
% Transfer: 选择响应异质性（SD@1s，[-1,1]细胞）最大的会话
% Naive:    选择响应异质性最小的会话
%
% 每个代表性会话输出：一个 volshow 3D 热图 PNG + 一个直方图 SVG
% 风格与 B 图一致
%
% Data scope:
% - Transfer: AudioLightBaseline，纯 LW 会话（ceiling excluded）
% - Naive: LightAudioBaseline + LAInterspersed，纯 LW 会话（ceiling excluded）
%
% Output: PNG + SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.E_SD1sVsDeltaHit_Moderates

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig3E:No1s', 'Cannot find a sample close to 1s.');
end

%% ===== 1) Gather Transfer sessions & compute per-session SD =====
DS_ALB = TransferLearning.AudioLightBaseline();
SessT = iLightWaterSessions(DS_ALB);
SessT = iKeepPureLW(DS_ALB, SessT);
SessT = iExcludeCeiling(SessT);
fprintf('Transfer LW: %d sessions\n', height(SessT));

allDTs_T = unique(SessT.DateTime);
rawTbl_T = iBatchQueryRawNTS(DS_ALB, allDTs_T);
sdT = iPerSessionSD(rawTbl_T, SessT.DateTime, idx1s);
globalSdT = iPerSessionGlobalSD(rawTbl_T, SessT.DateTime, xMask);

%% ===== 2) Gather Naive sessions & compute per-session SD =====
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();

allNaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
allNaiveSess = iExcludeAudioWaterSessions(allNaiveSess, DS_LAB, DS_LAI);
allNaiveSess = iExcludeCeilingNaive(allNaiveSess);
fprintf('Naive LW: %d sessions\n', height(allNaiveSess));

% Batch query per source dataset
rawParts = {};
naiveDSNames = ["LAB"; "LAI"];
naiveDSObjs  = {DS_LAB; DS_LAI};
for d = 1:numel(naiveDSObjs)
	dsName = naiveDSNames(d);
	dts = unique(allNaiveSess.DateTime(allNaiveSess.Source == dsName));
	if isempty(dts), continue; end
	part = iBatchQueryRawNTS(naiveDSObjs{d}, dts);
	if ~isempty(part) && height(part) > 0
		rawParts{end+1} = part; %#ok<AGROW>
	end
end
if isempty(rawParts), naiveRawTbl = table();
else, naiveRawTbl = vertcat(rawParts{:});
end
sdN = iPerSessionSD(naiveRawTbl, allNaiveSess.DateTime, idx1s);
globalSdN = iPerSessionGlobalSD(naiveRawTbl, allNaiveSess.DateTime, xMask);

%% ===== 3) Pick sessions with hard constraint: globalSD(Naive) > globalSD(Transfer) =====
idxT = NaN;
idxN = NaN;
validT = find(isfinite(sdT) & isfinite(globalSdT));
validN = find(isfinite(sdN) & isfinite(globalSdN));
if isempty(validT) || isempty(validN)
	error('Fig3E:NoValidSessions', 'No valid sessions for representative selection.');
end
[~, ordT] = sort(sdT(validT), 'descend');
[~, ordN] = sort(sdN(validN), 'ascend');
validT = validT(ordT);
validN = validN(ordN);
for iT = 1:numel(validT)
	for iN = 1:numel(validN)
		if globalSdN(validN(iN)) > globalSdT(validT(iT))
			idxT = validT(iT);
			idxN = validN(iN);
			break;
		end
	end
	if isfinite(idxT) && isfinite(idxN)
		break;
	end
end
if ~isfinite(idxT) || ~isfinite(idxN)
	error('Fig3E:NoFeasibleRepresentativePair', ...
		'Cannot find Naive/Transfer sessions satisfying globalSD(Naive) > globalSD(Transfer).');
end
maxSDT = sdT(idxT);
minSDN = sdN(idxN);
fprintf('\nSelected Transfer: Mouse=%s, DateTime=%s, Response heterogeneity=%.3f\n', ...
	SessT.Mouse(idxT), datestr(SessT.DateTime(idxT)), maxSDT);
fprintf('Selected Naive:    Mouse=%s, DateTime=%s, Response heterogeneity=%.3f\n', ...
	allNaiveSess.Mouse(idxN), datestr(allNaiveSess.DateTime(idxN)), minSDN);
fprintf('Global SD constraint: Naive=%.3f > Transfer=%.3f\n', globalSdN(idxN), globalSdT(idxT));

%% ===== 4) Fetch full trial-level NTS for 2 selected sessions =====
xMask = (xsSec >= 0) & (xsSec <= 2);

sessInfo = struct('label', {"Transfer","Naive"}, ...
	'dt', {SessT.DateTime(idxT), allNaiveSess.DateTime(idxN)}, ...
	'mouse', {string(SessT.Mouse(idxT)), string(allNaiveSess.Mouse(idxN))}, ...
	'DS', {DS_ALB, []});

% Determine which DS for the Naive session
naiveSrc = allNaiveSess.Source(idxN);
if naiveSrc == "LAB", sessInfo(2).DS = DS_LAB;
else, sessInfo(2).DS = DS_LAI;
end

vals    = cell(1, 2);   % per-cell z@1s (filtered [-1,1], sorted)
sdVals  = nan(1, 2);
rawData = cell(1, 2);   % (cells × time × trials) for volshow

for iS = 1:2
	[~, ntats, ntsRaw] = iSessionNTATS(sessInfo(iS).DS, sessInfo(iS).dt);
	if isempty(ntats)
		fprintf('WARNING: no NTATS data for %s session\n', sessInfo(iS).label);
		continue;
	end
	v1s = double(ntats(:, idx1s));
	keepMask = isfinite(v1s) & v1s >= -1 & v1s <= 1;
	v1s_filt = v1s(keepMask);
	[~, sortIdx] = sort(v1s_filt, 'ascend');
	vals{iS} = v1s_filt(sortIdx);
	sdVals(iS) = std(vals{iS});

	if ~isempty(ntsRaw)
		raw_filt = ntsRaw(keepMask, :, :);
		rawData{iS} = raw_filt(sortIdx, xMask, :);
	end

	fprintf('  %s: n=%d cells, Response heterogeneity=%.3f\n', sessInfo(iS).label, numel(vals{iS}), sdVals(iS));
end

%% ===== 5) Export 2 volshow PNGs =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end

sessTags = ["Transfer", "Naive"];

% Compute global clim from both volumes
globalMin = Inf; globalMax = -Inf;
for iS = 1:2
	rd = rawData{iS};
	if isempty(rd), continue; end
	v2 = rd(isfinite(rd));
	globalMin = min(globalMin, min(v2));
	globalMax = max(globalMax, max(v2));
end
fprintf('Global clim (true range): [%.3f, %.3f]\n', globalMin, globalMax);

vAbs = 5.823;
fprintf('--- Shared cbrt clim with Fig3B: [%.3f, %.3f] ---\n', -vAbs, vAbs);

nMap = 256;
nHalf = nMap / 2;
blueWhiteRed = [linspace(0,1,nHalf)', linspace(0,1,nHalf)', ones(nHalf,1); ...
                ones(nHalf,1), linspace(1,0,nHalf)', linspace(1,0,nHalf)'];
alphaVec = repmat(1/30, nMap, 1);

for iS = 1:2
	rd = rawData{iS};
	if isempty(rd), continue; end

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

	fig = uifigure('Name', sprintf('Volshow E %s', sessTags(iS)), ...
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
	elev = 25; side = 30;
	camOffset = [dist*cosd(elev)*cosd(side), dist*cosd(elev)*sind(side), dist*sind(elev)];
	viewer.CameraTarget = ct;
	viewer.CameraPosition = ct + camOffset;
	Vdir = -camOffset / norm(camOffset);
	Yaxis = [0, 1, 0];
	projY = Yaxis - dot(Yaxis, Vdir) * Vdir;
	upVec = cross(projY, Vdir);
	viewer.CameraUpVector = upVec / norm(upVec);
	viewer.CameraZoom = 1.4;

	uilabel(fig, 'Text', 'X: Time (0~2 s)', 'FontSize', 6, 'FontColor', [0.85 0.1 0.1], ...
		'Position', [5, 48, 200, 16], 'BackgroundColor', 'none');
	uilabel(fig, 'Text', 'Y: Cell (sorted by z@1s)', 'FontSize', 6, 'FontColor', [0.1 0.6 0.1], ...
		'Position', [5, 30, 200, 16], 'BackgroundColor', 'none');
	uilabel(fig, 'Text', 'Z: Trial', 'FontSize', 6, 'FontColor', [0.1 0.1 0.85], ...
		'Position', [5, 12, 200, 16], 'BackgroundColor', 'none');

	pause(1);
	pngName = sprintf('English_Fig3E_Volshow_%s.png', sessTags(iS));
	exportapp(fig, fullfile(outDirUNC, pngName));
	drawnow;
	close(fig);
	fprintf('Wrote: %s\n', pngName);
end

%% ===== 6) Export 2 histogram SVGs (60 mm × 16 mm) =====
nBins = 40;
binEdges = linspace(-1, 1, nBins + 1);
pairColors = {[0 0.4470 0.7410]; [0.8500 0.3250 0.0980]};  % Transfer=blue, Naive=orange
histTitles = ["Transfer", "Naive"];

histFigs = gobjects(1, 2);
histAxes = gobjects(1, 2);
for iS = 1:2
	v = vals{iS};

	fh = figure('Color', 'w');
	fh.Units = 'centimeters';
	fh.Position(3:4) = [5.8, 1.6];

	ax = axes(fh);
	disableDefaultInteractivity(ax);
	ax.Toolbar.Visible = 'off';
	hold(ax, 'on');

	histogram(ax, v, binEdges, 'Normalization', 'probability', ...
		'FaceColor', pairColors{iS}, 'FaceAlpha', 0.7, 'EdgeColor', 'none');
	xline(ax, mean(v), '--', 'Color', pairColors{iS}, 'LineWidth', 0.8);

	xlim(ax, [-1, 1]);
	ax.XTick = [-1, 0, 1];
	ax.FontSize = 6;
	box(ax, 'off');
	grid(ax, 'off');

	text(ax, 0.97, 0.95, sprintf('Resp. heterogeneity\n=%.2f', sdVals(iS)), ...
		'Units', 'normalized', 'HorizontalAlignment', 'right', ...
		'VerticalAlignment', 'top', 'FontSize', 6, 'FontWeight', 'bold');
	title(ax, histTitles(iS), 'FontSize', 6, 'FontWeight', 'normal');

	xlabel(ax, 'z-score', 'FontSize', 6);
	ylabel(ax, {'Prop. of'; 'cells'}, 'FontSize', 6);

	histFigs(iS) = fh;
	histAxes(iS) = ax;
end

MATLAB.Graphics.UnifyAxesLims(histAxes(:), @ylim);

for iS = 1:2
	svgN = sprintf('English_Fig3E_Hist_%s.svg', sessTags(iS));
	TransferLearning.PrintFigure(histFigs(iS), fullfile(outDirUNC, svgN));
	fprintf('Wrote: %s\n', svgN);
	close(histFigs(iS));
end

%% ===== Local functions =====

function rawTbl = iBatchQueryRawNTS(DS, dts)
% Batch query trial-level z-score NTS with DateTime column
q = struct('Stimulus', 'LightWater', 'DateTime', dts);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	rawTbl = table(); return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
	rawTbl = table(); return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = datetime(rawTbl.DateTime);
if ~isempty(rawTbl.DateTime.TimeZone), rawTbl.DateTime.TimeZone = ''; end
end

function sdVec = iPerSessionSD(rawTbl, dts, idx1s)
% Compute per-session SD of z-score@1s (cells in [-1,1])
sdVec = nan(numel(dts), 1);
if isempty(rawTbl), return; end
for iDT = 1:numel(dts)
	rows = rawTbl.DateTime == dts(iDT);
	if ~any(rows), continue; end
	sub = rawTbl(rows, :);
	sig = double(sub.TrialSignal);
	z1s = sig(:, idx1s);
	G = findgroups(sub.CellUID);
	med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
	v = med1s(isfinite(med1s) & med1s >= -1 & med1s <= 1);
	if numel(v) >= 3, sdVec(iDT) = std(v); end
end
end

function sdVec = iPerSessionGlobalSD(rawTbl, dts, xMask)
sdVec = nan(numel(dts), 1);
if isempty(rawTbl), return; end
for iDT = 1:numel(dts)
	rows = rawTbl.DateTime == dts(iDT);
	if ~any(rows), continue; end
	sub = rawTbl(rows, :);
	sig = double(sub.TrialSignal);
	if ndims(sig) < 2 || size(sig, 2) < nnz(xMask), continue; end
	v = sig(:, xMask);
	v = v(isfinite(v));
	if numel(v) >= 10
		sdVec(iDT) = std(v);
	end
end
end

function AllSess = iGatherNaiveSessions(LAB, LAI)
% Gather Naive learning sessions from LAB + LAI (phase-based range selection).
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});

for iDS = 1:2
	if iDS == 1, DS = LAB; srcName = "LAB"; else, DS = LAI; srcName = "LAI"; end

	if iDS == 2
		badMice = iFindBadMiceLAI(DS);
	else
		badMice = string.empty;
	end

	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
	T.Phase = string(T.Phase);
	Tr = DS.Trials;
	mice = unique(T.Mouse);

	for iM = 1:numel(mice)
		m = mice(iM);
		if iDS == 2 && any(m == badMice), continue; end
		Tm = T(T.Mouse == m, :);
		phases = unique(Tm.Phase);
		if ~any(phases == "Naive"), continue; end

		hasLearned = any(phases == "Learned");
		hasTransfer = any(phases == "Transfer");
		sessDTs = sort(unique(Tm.DateTime));

		sessPhase = strings(numel(sessDTs), 1);
		for ii = 1:numel(sessDTs)
			ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
			ph = ph(ph ~= "" & ~ismissing(ph));
			if isempty(ph), sessPhase(ii) = ""; continue; end
			[uPh,~,ic] = unique(ph); counts = accumarray(ic,1);
			[~,mx] = max(counts); sessPhase(ii) = uPh(mx);
		end

		idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
		if hasLearned
			idxEnd = find(sessPhase == "Learned", 1, 'last');
		elseif hasTransfer
			idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
			idxEnd = idxTransferStart - 1;
		else
			idxEnd = numel(sessDTs);
		end

		if isempty(idxNaiveStart) || idxEnd < idxNaiveStart, continue; end

		for k = idxNaiveStart:idxEnd
			dt = sessDTs(k);
			blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
			TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
			if isempty(TrSess), continue; end
			lwMask = string(TrSess.Stimulus) == "LightWater";
			if ~any(lwMask), continue; end
			perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
			if ~isfinite(perf), continue; end
			AllSess = [AllSess; table(m, dt, perf, srcName, ...
				'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
		end
	end
end
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows', 'first');
AllSess = AllSess(ia, :);
end

function badMice = iFindBadMiceLAI(DS)
badMice = string.empty;
T = DS.TableQuery(["Mouse","DateTime","Phase"]);
T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
T.Phase = string(T.Phase);
mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM);
	Tm = T(T.Mouse == m, :);
	dts = unique(Tm.DateTime);
	for iDT = 1:numel(dts)
		ph = Tm.Phase(Tm.DateTime == dts(iDT));
		if any(ph == "Naive" | ph == "Learned")
			if iHasStimulus(DS, m, dts(iDT), "AudioWater")
				badMice = [badMice; m]; %#ok<AGROW>
				break;
			end
		end
	end
end
badMice = unique(badMice);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess), 1);
for i = 1:height(AllSess)
	if AllSess.Source(i) == "LAB", DS = LAB; else, DS = LAI; end
	if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
		keep(i) = false;
	end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
	rows = find(AllSess.Mouse == m);
	p = double(AllSess.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus)); st = st(~ismissing(st));
tf = any(st == string(stim));
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks;
blkVars = string(Blocks.Properties.VariableNames);
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
if ismember("MustWarn", blkVars)
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks = Blocks(:, {'BlockUID','DateTime','MustWarn'});
DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", :);
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance'});
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
Sess = table(mouse, dt, perfSess, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", :);
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
	i100 = find(p >= 1 - 1e-12, 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
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
ntats  = nan(nCells, nTime);
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

function Vn = iSymmetricNormalize(V, vAbs)
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
