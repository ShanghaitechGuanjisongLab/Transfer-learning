% English Fig3N: Naive vs Transfer representative session — heatmap + SD histogram
%
% Select one representative session from each cohort:
%   Naive    (LightAudioBaseline): session with lowest SD@1s
%   Transfer (AudioLightBaseline): session with highest SD@1s
% (maximises the SD contrast to illustrate the difference)
%
% Layout (matches Fig3B style, 1×2 columns):
%   Each column: 3D transparent heatmap (cells×time) + horizontal histogram (z-score @1s)
%
% Execution:
%   TransferLearning.英文图3.N_NaiveVsTransfer_SD_RepresentativeSession

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS_Naive    = TransferLearning.LightAudioBaseline();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('NaiveVsTransfer:No1s', 'Cannot find sample close to 1s.'); end

xMask = (xsSec >= 0) & (xsSec <= 2); % 0~2s for heatmap

%% ===== 1) Collect all LW sessions from each cohort =====
sessN = iGetSessions(DS_Naive,    false);
sessT = iGetSessions(DS_Transfer, true);

%% ===== 2) Compute SD@1s per session =====
[sdN, cellsN, heatN, rawN_all] = iComputeSessionSD(DS_Naive,    sessN, idx1s, xMask);
[sdT, cellsT, heatT, rawT_all] = iComputeSessionSD(DS_Transfer, sessT, idx1s, xMask);

%% ===== 3) Pick sessions: max SD from Transfer, min SD from Naive =====
validN = find(isfinite(sdN) & cellfun(@(x) ~isempty(x), cellsN));
validT = find(isfinite(sdT) & cellfun(@(x) ~isempty(x), cellsT));

if isempty(validN) || isempty(validT)
	error('NaiveVsTransfer:NoPair', 'No valid sessions found in one or both cohorts.');
end

[~, iMaxT] = max(sdT(validT));
[~, iMinN] = min(sdN(validN));
bestIT = validT(iMaxT);
bestIN = validN(iMinN);

fprintf('Naive:    %s Mouse=%s SD@1s=%.3f n=%d cells\n', ...
	datestr(sessN.DateTime(bestIN)), string(sessN.Mouse(bestIN)), sdN(bestIN), numel(cellsN{bestIN}));
fprintf('Transfer: %s Mouse=%s SD@1s=%.3f n=%d cells\n', ...
	datestr(sessT.DateTime(bestIT)), string(sessT.Mouse(bestIT)), sdT(bestIT), numel(cellsT{bestIT}));

%% ===== 4) Prepare data =====
v1s_N = cellsN{bestIN};  hd_N = heatN{bestIN};  sd_N = sdN(bestIN);  raw_N = rawN_all{bestIN};
v1s_T = cellsT{bestIT};  hd_T = heatT{bestIT};  sd_T = sdT(bestIT);  raw_T = rawT_all{bestIT};

%% ===== 5) Shared heatmap CLim =====
allHeat = [hd_N(:); hd_T(:)];
negV = min(allHeat); posV = max(allHeat);
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs  = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0, climLowAbs = 1; end
if climHighAbs <= 0, climHighAbs = 1; end
CLim = [-climLowAbs, climHighAbs];

%% ===== 6) Figure =====
f = figure('Color', 'w', 'Name', 'Naive vs Transfer Representative Session (Fig3N)');
f.Units = 'centimeters';
f.Position(3:4) = [10.5, 4.5];

colData  = {v1s_N,  v1s_T};
heatData = {hd_N,   hd_T};
rawData  = {raw_N,  raw_T};  % cells × time × trials
sdData   = [sd_N,   sd_T];
colLabels = ["Naive", "Transfer"];
colColors = {[0.8500 0.3250 0.0980]; [0 0.4470 0.7410]};  % orange-red / blue

nBins    = 40;
binEdges = linspace(-1, 1, nBins + 1);

leftMargin  = 0.06;
rightMargin = 0.06;
topMargin   = 0.10;
botMargin   = 0.18;
gapH    = 0.05;
gapHCol = 0.04;
heatFrac = 0.52;
histFrac = 0.48;

totalW    = 1 - leftMargin - rightMargin;
colGroupW = (totalW - gapHCol) / 2;
heatW     = colGroupW * heatFrac - gapH / 2;
histW     = colGroupW * histFrac - gapH / 2;
rowH      = 1 - topMargin - botMargin;

axHistArr = gobjects(1, 2);  % track histogram axes for xlim unification

for iC = 1:2
	xBase  = leftMargin + (iC - 1) * (colGroupW + gapHCol);
	nCells = size(heatData{iC}, 1);
	hd     = heatData{iC};

	% --- 3D voxel block: one translucent surf per trial ---
	% X = time (s), Y = cell index (sorted @1s), Z = trial number
	heatPos = [xBase, botMargin, heatW, rowH];
	axH = axes(f, 'Units', 'normalized', 'Position', heatPos); %#ok<LAXES>
	hold(axH, 'on');
	rd = rawData{iC};
	xtHeat = xsSec(xMask);
	[XG, YG] = meshgrid(xtHeat, 1:nCells);
	nTrials3D = size(rd, 3);
	for kt = 1:nTrials3D
		ZG = kt * ones(size(XG));
		surf(axH, XG, YG, ZG, rd(:, :, kt), ...
			'EdgeColor', 'none', 'FaceColor', 'flat', 'FaceAlpha', 0.05);
	end
	axH.YDir = 'normal';
	xlim(axH, [xtHeat(1), xtHeat(end)]);
	ylim(axH, [0.5, nCells + 0.5]);
	zlim(axH, [0.5, max(nTrials3D, 1) + 0.5]);
	clim(axH, CLim);
	view(axH, [-40, 25]);  % tilted 3D perspective
	zlabel(axH, 'Trial', 'FontSize', 6);

	% Blue-white-red colormap
	nMap = 256;
	aFrac  = climLowAbs / (climLowAbs + climHighAbs);
	nBelow = max(round(nMap * aFrac), 1);
	nAbove = max(nMap - nBelow, 1);
	cmapBelow = [linspace(0,1,nBelow)', linspace(0,1,nBelow)', ones(nBelow,1)];
	cmapAbove = [ones(nAbove,1), linspace(1,0,nAbove)', linspace(1,0,nAbove)'];
	colormap(axH, [cmapBelow; cmapAbove]);

	axH.FontSize = 6;
	axH.FontName = 'Segoe UI Emoji';
	axH.TickDir = 'in';
	box(axH, 'off');
	axH.Toolbar.Visible = 'off';

	% X ticks at 0s (💡) and 1s (💧★)
	axH.XTick = [0, 1];
	axH.XTickLabel = {'💡', '💧★'};
	xlabel(axH, 'Time (s)', 'FontSize', 6);

	xline(axH, 0, ':k', 'LineWidth', 0.5);
	xline(axH, 1, '-k', 'LineWidth', 0.5);

	% Column title
	title(axH, colLabels(iC), 'FontSize', 7, 'FontWeight', 'bold', 'Color', colColors{iC});

	% Y label on left column only
	if iC == 1
		ylabel(axH, sprintf('Cells (n=%d)', nCells), 'FontSize', 6);
		axH.YTick = [];
	else
		axH.YAxis.Visible = 'off';
	end

	% --- Histogram (horizontal) ---
	histPos = [xBase + heatW + gapH, botMargin, histW, rowH];
	axHist = axes(f, 'Units', 'normalized', 'Position', histPos); %#ok<LAXES>
	axHistArr(iC) = axHist;
	hold(axHist, 'on');

	v = colData{iC};
	histogram(axHist, v, binEdges, 'Normalization', 'probability', ...
		'Orientation', 'horizontal', ...
		'FaceColor', colColors{iC}, 'FaceAlpha', 0.7, 'EdgeColor', 'none');
	yline(axHist, mean(v), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);
	yline(axHist, 0,  ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
	yline(axHist, -1, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
	yline(axHist, 1,  ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);

	axHist.FontSize = 6;
	box(axHist, 'off');
	grid(axHist, 'off');
	axHist.Toolbar.Visible = 'off';

	ylim(axHist, [-1, 1]);
	axHist.YTick = [-1, 0, 1];

	if iC == 1
		axHist.YTickLabel = {'-1', '0', '1'};
		ylabel(axHist, 'z-score @1s', 'FontSize', 6);
	else
		axHist.YTickLabel = [];
	end

	xlabel(axHist, 'Cell proportion', 'FontSize', 6);

	% ★ SD annotation
	text(axHist, 0.05, 0.97, sprintf('★ SD=%.2f', sdData(iC)), ...
		'Units', 'normalized', 'HorizontalAlignment', 'left', ...
		'VerticalAlignment', 'top', 'FontSize', 6, 'FontWeight', 'bold', ...
		'Color', colColors{iC});

	% Moderates annotation on right-column histogram only
	if iC == 2
		text(axHist, 1.06, 0.5, 'Moderates', 'Units', 'normalized', ...
			'FontSize', 6, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
			'FontWeight', 'bold', 'Rotation', 90, 'Clipping', 'off');
	end
end

% --- Unify histogram x limits (use only histogram axes, not heatmap axes) ---
xMaxH = max(arrayfun(@(a) a.XLim(2), axHistArr));
for a = axHistArr
	xlim(a, [0, xMaxH]);
end

%% ===== 7) Export =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3N_NaiveVsTransfer_RepresentativeSession.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iGetSessions(DS, isTransfer)
% Build per-session LW hit rate, keep pure LW, exclude ceiling, keep relevant phase range
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), 'VariableNames',{'Mouse','DateTime','Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');

% Exclude AudioWater-mixed sessions
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if ~isempty(TrAW)
	blkAW = unique(uint64(TrAW.BlockUID));
	TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
	dtAW = unique(TAW.DateTime);
	T = T(~ismember(T.DateTime, dtAW), :);
end

[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2  = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});

% Filter to relevant phases
if isTransfer, phaseStart = "Transfer"; phaseEnd = "Final";
else,          phaseStart = "Naive";    phaseEnd = "Learned";
end
mice = unique(string(Sess.Mouse));
keep = false(height(Sess), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	dtM = DT(DT.Mouse == m, :);
	startDT = min(dtM.DateTime(dtM.Phase == phaseStart));
	endDT   = max(dtM.DateTime(dtM.Phase == phaseEnd));
	if isempty(startDT) || isempty(endDT) || any(ismissing([startDT endDT])), continue; end
	rows = (string(Sess.Mouse) == m) & Sess.DateTime >= startDT & Sess.DateTime <= endDT;
	keep = keep | rows;
end
Sess = Sess(keep, :);

% Exclude ceiling sessions
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
remove = false(height(Sess), 1);
for m = unique(Sess.Mouse)'
	rows = find(Sess.Mouse == m);
	p = double(Sess.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
Sess(remove, :) = [];
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function [sdVec, cellVecs, heatVecs, rawVecs] = iComputeSessionSD(DS, Sess, idx1s, xMask)
n = height(Sess);
sdVec    = nan(n, 1);
cellVecs = cell(n, 1);
heatVecs = cell(n, 1);
rawVecs  = cell(n, 1);
for iS = 1:n
	dt = Sess.DateTime(iS);
	[~, ntats, ntsRaw] = iSessionNTATS(DS, dt);
	if isempty(ntats), continue; end
	v1s = double(ntats(:, idx1s));
	keepMask = isfinite(v1s) & v1s >= -1 & v1s <= 1;
	v1s_f = v1s(keepMask);
	if numel(v1s_f) < 5, continue; end
	[~, sortIdx] = sort(v1s_f, 'ascend');
	cellVecs{iS} = v1s_f(sortIdx);
	heatVecs{iS} = double(ntats(keepMask, xMask));
	heatVecs{iS} = heatVecs{iS}(sortIdx, :);
	sdVec(iS) = std(v1s_f);
	if ~isempty(ntsRaw)
		raw_f = ntsRaw(keepMask, :, :);
		rawVecs{iS} = raw_f(sortIdx, xMask, :);  % cells × timeMask × trials
	end
end
end

function [uid, ntats, ntsRaw] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T), uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return; end
des = unique(string(T.Design)); des = des(~ismissing(des));
if numel(des) ~= 1, uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return; end
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

function y = iNiceLimit(x)
if ~isfinite(x) || x <= 0, y = 1; return; end
e = floor(log10(x));
f = x / (10^e);
if f <= 1, n = 1; elseif f <= 2, n = 2; elseif f <= 5, n = 5; else, n = 10; end
y = n * (10^e);
if y < x, y = 10 * (10^e); end
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
