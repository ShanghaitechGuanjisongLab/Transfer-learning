% 图3.5b：Naive/Learned LightWater 两泳道热图（Median ZScore NTATS，0~3s）
%
% Lanes:
% 1) Naive  LightWater
% 2) Learned LightWater
%
% Data sources:
% - LAInterspersed (exclude sessions/mice whose LightWater blocks mix AudioWater)
% - LightAudioBaseline
%
% Cell unification:
% - Use UniExp.NtatsCellStrip to unify the cell set across lanes.
%
% Active-cell filter (Learned lane only):
% - max(0~1s) > mean(-3~0s) + 3*std(-3~0s)
%
% Cell sorting:
% - Within 0~3s, compute peak time in Learned and Naive.
% - Sort key: (tPeak_Learned - tPeak_Naive). (Ascending; NaNs go to bottom.)
%
% Plot:
% - UniExp.LanearHeatmap
% - SymmetricColormap flag enabled; CLim is NOT symmetric and uses sqrt-scale
%   magnitude (lower/upper computed separately, then rounded to 1-2-5 limits).
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig35.B_LanearHeatmap_NaiveLearned_LightWater_PureSessions

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2c_LanearHeatmap_NaiveLearned_LightWater_0to3_ActiveLearnedLW.svg";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- 1) Time window & active-cell masks
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

xMask = (xsSec >= 0) & (xsSec <= 3);
if nnz(xMask) < 5
	error('Fig3_5b:BadTimeMask', 'Too few samples in 0~3s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
respMask = (xsSec >= 0) & (xsSec <= 1);
if nnz(baseMask) < 5 || nnz(respMask) < 2
	error('Fig3_5b:BadActiveMasks', 'Too few samples in baseline/response window.');
end
kSigma = 3;

% --- 2) Load datasets
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

% --- 3) Build Naive/Learned LightWater lanes (merge two sources)
qNaiveLW = struct('Phase','Naive',  'Stimulus','LightWater');
qLearnLW = struct('Phase','Learned','Stimulus','LightWater');

% LAInterspersed purity: exclude mice whose LightWater blocks mix AudioWater
badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
badLearn = iFindMiceWithAudioWaterInPhase(LAI, "Learned");
badMiceLAI = unique([badNaive; badLearn]);

qNaiveLW_LAI = qNaiveLW;
qLearnLW_LAI = qLearnLW;
qNaiveLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badMiceLAI);
qLearnLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Learned", "LightWater", badMiceLAI);

G = struct();

% QueryNTATS: Median ZScore NTATS
G1_Naive = LAB.QueryNTATS(qNaiveLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Naive = LAI.QueryNTATS(qNaiveLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.NaiveLight = iVcatNtatsTables(G1_Naive, G2_Naive);

G1_Learn = LAB.QueryNTATS(qLearnLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Learn = LAI.QueryNTATS(qLearnLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedLight = iVcatNtatsTables(G1_Learn, G2_Learn);

% --- 4) Unify cells across lanes
S = UniExp.NtatsCellStrip(G);
assignin('base','Fig3_5b_CellStrip', S);
assignin('base','Fig3_5b_BadMiceLAI', badMiceLAI);

X = iGetNtats3D(S);

% --- 5) Learned-active cells only
XLearned = squeeze(X(:,:,2));
baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
respMax = max(XLearned(:, respMask), [], 2, 'omitnan');
activeMask = isfinite(respMax) & isfinite(baseMu) & isfinite(baseSd) & (respMax > (baseMu + kSigma*baseSd));

if istable(S) && any(strcmp(S.Properties.VariableNames,'CellUID'))
	activeCellUID = uint64(S.CellUID(activeMask));
else
	activeCellUID = [];
end
assignin('base','Fig3_5b_ActiveMask', activeMask);
assignin('base','Fig3_5b_ActiveCellUID', activeCellUID);

X = X(activeMask, :, :);

% --- 6) Sorting by delta peak time (Learned - Naive), peak computed only within 0~3s
XNaive = squeeze(X(:,:,1));
XLearn = squeeze(X(:,:,2));

[tPeakNaive, okN] = iPeakTime_0to3(XNaive, xsSec, xMask);
[tPeakLearn, okL] = iPeakTime_0to3(XLearn, xsSec, xMask);

deltaPeak = tPeakLearn - tPeakNaive;
deltaPeak(~(okN & okL)) = NaN;

[~, sortIdx] = sort(deltaPeak, 'ascend', 'MissingPlacement','last');

% --- 7) Prepare lane data (only 0~3s)
X0to3 = X(:, xMask, :);
laneData = X0to3(sortIdx, :, :);

% Non-symmetric sqrt-scale CLim (rounded)
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV)
	negV = -1;
end
if ~isfinite(posV)
	posV = 1;
end
climLowAbs = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0
	climLowAbs = 1;
end
if climHighAbs <= 0
	climHighAbs = 1;
end
CLim = [-climLowAbs, climHighAbs];

% --- 8) Plot
f = figure('Color','w', 'Name', 'Fig3.5b Lane heatmap (0~3s)');
try
	MATLAB.Graphics.FigureAspectRatio(8, 5, 1/2);
catch
end

Layout = tiledlayout(f, 1, 2, 'TileSpacing','none', 'Padding','tight');
subTitles = ["Naive LightWater", "Learned LightWater"];

[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', seconds([0,3])}, ...
	LMHColor=[0,0,1;1,1,1;1,0,0]);

xlabel(Layout, 'Time (s)');
ylabel(Layout, sprintf('%d cells', size(laneData,1)));

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A)
		continue;
	end
	xline(A, 0, ':k');
	xline(A, 1, '-k');
	A.TickDir = 'in';
	box(A, 'on');
	try
		if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
			A.Toolbar.Visible = 'off';
		end
	catch
	end
end

% --- 9) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% diagnostics to base
assignin('base','Fig3_5b_SortIdx', sortIdx);
assignin('base','Fig3_5b_PeakTimeNaive', tPeakNaive);
assignin('base','Fig3_5b_PeakTimeLearned', tPeakLearn);
assignin('base','Fig3_5b_DeltaPeak', deltaPeak);

%% --- local helpers

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
excludeMice = string(excludeMice(:));
try
	T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
	if isempty(T)
		mice = string.empty(0,1);
		return;
	end
	mice = unique(string(T.Mouse));
	mice = mice(~ismember(mice, excludeMice));
catch
	mice = string.empty(0,1);
end
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
try
	T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
catch
	badMice = strings(0,1);
	return;
end
if isempty(T)
	badMice = strings(0,1);
	return;
end
if ~isprop(DS, 'Trials')
	badMice = strings(0,1);
	return;
end
Tr = DS.Trials;
if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
	badMice = strings(0,1);
	return;
end

TrStim = string(Tr.Stimulus);
TrBU = uint64(Tr.BlockUID);
T.Mouse = string(T.Mouse);
blkBU = uint64(T.BlockUID);

mice = unique(T.Mouse);
bad = false(size(mice));
for i = 1:numel(mice)
	m = mice(i);
	bu = blkBU(T.Mouse == m);
	rows = ismember(TrBU, bu);
	if ~any(rows)
		bad(i) = false;
		continue;
	end
	st = TrStim(rows);
	bad(i) = any(st == "AudioWater") && any(st == "LightWater");
end
badMice = mice(bad);
end

function T = iVcatNtatsTables(A, B)
if isempty(A)
	T = B;
	return;
end
if isempty(B)
	T = A;
	return;
end

try
	T = [A; B];
catch
	% fail safe: keep the one with more rows
	if height(A) >= height(B)
		T = A;
	else
		T = B;
	end
end
end

function X = iGetNtats3D(S)
% Return numeric [nCell x nTime x nLane] NTATS.
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S,'NTATS')
	nt = S.NTATS;
else
	nt = S;
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end

if isnumeric(nt)
	X = nt;
	return;
end

error('Fig3_5b:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [tPeak, ok] = iPeakTime_0to3(X, xsSec, xMask)
Xw = X(:, xMask);
finiteRow = any(isfinite(Xw), 2);
[~, idxRel] = max(Xw, [], 2, 'omitnan');
idxRel(~finiteRow) = 1;
xsW = xsSec(xMask);
	tPeak = xsW(idxRel);
tPeak(~finiteRow) = NaN;
ok = finiteRow;
end

function y = iNiceLimit(x)
% Round x up to a "nice" limit using 1-2-5 scaling.
if ~isfinite(x) || x <= 0
	y = 1;
	return;
end

e = floor(log10(x));
f = x / (10^e);

if f <= 1
	n = 1;
elseif f <= 2
	n = 2;
elseif f <= 5
	n = 5;
else
	n = 10;
end

y = n * (10^e);
if y < x
	y = 10 * (10^e);
end
end
