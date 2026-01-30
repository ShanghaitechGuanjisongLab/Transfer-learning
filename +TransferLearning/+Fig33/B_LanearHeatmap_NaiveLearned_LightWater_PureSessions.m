% Fig3.3B：Naive/Learned LightWater 两泳道热图（Median ZScore NTATS，0~1.5s）
%
% Lanes:
% 1) Naive  LightWater
% 2) Learned LightWater
%
% Data sources:
% - LAInterspersed (exclude sessions/mice whose LightWater blocks mix AudioWater)
% - LightAudioBaseline
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig33.B_LanearHeatmap_NaiveLearned_LightWater_PureSessions

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3b_LanearHeatmap_NaiveLearned_LightWater_0to1p5_ActiveLearnedLW.svg";

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

xMask = (xsSec >= 0) & (xsSec <= 1.5);
if nnz(xMask) < 5
	error('Fig3_3b:BadTimeMask', 'Too few samples in 0~1.5s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
respMask = (xsSec >= 0) & (xsSec <= 1);
if nnz(baseMask) < 5 || nnz(respMask) < 2
	error('Fig3_3b:BadActiveMasks', 'Too few samples in baseline/response window.');
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

G1_Naive = LAB.QueryNTATS(qNaiveLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Naive = LAI.QueryNTATS(qNaiveLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.NaiveLight = iVcatNtatsTables(G1_Naive, G2_Naive);

G1_Learn = LAB.QueryNTATS(qLearnLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Learn = LAI.QueryNTATS(qLearnLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedLight = iVcatNtatsTables(G1_Learn, G2_Learn);

% --- 4) Unify cells across lanes
S = UniExp.NtatsCellStrip(G);
assignin('base','Fig3_3b_CellStrip', S);
assignin('base','Fig3_3b_BadMiceLAI', badMiceLAI);

X = iGetNtats3D(S);

% --- 5) Keep cells that are active at 1s in ANY plotted lane
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig3_3b:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
end

nLane = size(X, 3);
activeByLane = false(size(X,1), nLane);
for iL = 1:nLane
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma*baseSd));
end
activeMask = any(activeByLane, 2);

assignin('base','Fig3_3b_ActiveMask', activeMask);
assignin('base','Fig3_3b_ActiveByLane_1s', activeByLane);

X = X(activeMask, :, :);

% --- 6) Sorting by NTATS@1s difference (Learned - Naive)
XNaive = squeeze(X(:,:,1));
XLearn = squeeze(X(:,:,2));

vNaive1s = XNaive(:, idx1s);
vLearn1s = XLearn(:, idx1s);

delta1s = vLearn1s - vNaive1s;
delta1s(~(isfinite(vNaive1s) & isfinite(vLearn1s))) = NaN;

[~, sortIdx] = sort(delta1s, 'ascend', 'MissingPlacement','last');

% --- 7) Prepare lane data (only 0~1.5s)
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
f = figure('Color','w', 'Name', 'Fig3.3B Lane heatmap (0~1.5s)');
try
		MATLAB.Graphics.FigureAspectRatio(73, 48, 3/4);
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
	ImagescStyle={'XData', seconds([0,1.5])}, ...
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
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% diagnostics to base
assignin('base','Fig3_3b_SortIdx', sortIdx);
assignin('base','Fig3_3b_SortDelta1s_LearnedMinusNaive', delta1s);
assignin('base','Fig3_3b_Naive1s', vNaive1s);
assignin('base','Fig3_3b_Learned1s', vLearn1s);

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
		continue;
	end
	if any(TrStim(rows) == "AudioWater")
		bad(i) = true;
	end
end
badMice = mice(bad);
end

function G = iVcatNtatsTables(G1, G2)
if isempty(G1)
	G = G2;
	return;
end
if isempty(G2)
	G = G1;
	return;
end
G = [G1; G2];
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
	if ndims(nt) ~= 3
		error('Fig3_3b:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_3b:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
% Find index closest to tSec within tolSec.
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function lim = iNiceLimit(x)
% Round x to a "nice" axis limit.
if ~isfinite(x) || x <= 0
	lim = 1;
	return;
end
pow = 10^floor(log10(x));
mant = x / pow;
if mant <= 1
	m = 1;
elseif mant <= 2
	m = 2;
elseif mant <= 5
	m = 5;
else
	m = 10;
end
lim = m * pow;
end
