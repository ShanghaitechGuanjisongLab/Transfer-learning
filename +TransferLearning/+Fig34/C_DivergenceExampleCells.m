% 图3.4C：两泳道热图（模仿 Fig3.3B），时间窗 1~2s；活跃判据用 NTATS@1.5s
%
% Lanes:
% 1) Naive  LightWater
% 2) Learned LightWater
%
% Cell filter:
% - Active@1.5s: NTATS(1.5s) > mean(-3~0s) + 3*std(-3~0s) (per lane)
% - Exclude cells that are inactive at 1.5s in ALL plotted lanes.
%
% Data sources:
% - LAInterspersed (exclude sessions/mice whose LightWater blocks mix AudioWater)
% - LightAudioBaseline
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig34.C_DivergenceExampleCells

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_4c_LaneHeatmap_NaiveLearned_LightWater_1to2_ActiveAt1p5.svg";

% --- ensure project loaded
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

% --- Time window 1~2s
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

xMask = (xsSec >= 1) & (xsSec <= 2);
if nnz(xMask) < 5
	error('Fig3_4c:BadTimeMask', 'Too few samples in 1~2s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 5
	error('Fig3_4c:BadBaseMask', 'Too few samples in baseline(-3~0).');
end

[idx1p5s, ok1p5s] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok1p5s
	error('Fig3_4c:No1p5s', 'Cannot find sample close to 1.5s in TransferLearning.Xs.');
end
kSigma = 3;

% --- Load datasets
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

% --- Build Naive/Learned LightWater lanes (merge two sources)
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

% --- Unify cells across lanes
S = UniExp.NtatsCellStrip(G);
assignin('base','Fig3_4c_CellStrip', S);
assignin('base','Fig3_4c_BadMiceLAI', badMiceLAI);

X = iGetNtats3D(S);

% --- Keep cells active at 1.5s in ANY plotted lane
nLane = size(X, 3);
activeByLane = false(size(X,1), nLane);
for iL = 1:nLane
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v = XL(:, idx1p5s);
	activeByLane(:, iL) = isfinite(v) & isfinite(baseMu) & isfinite(baseSd) & (v > (baseMu + kSigma*baseSd));
end
activeMask = any(activeByLane, 2);
assignin('base','Fig3_4c_ActiveMask', activeMask);
assignin('base','Fig3_4c_ActiveByLane_1p5s', activeByLane);

X = X(activeMask, :, :);

% --- Sorting by NTATS@1.5s difference (Learned - Naive)
XNaive = squeeze(X(:,:,1));
XLearn = squeeze(X(:,:,2));

delta = XLearn(:, idx1p5s) - XNaive(:, idx1p5s);
delta(~(isfinite(XNaive(:,idx1p5s)) & isfinite(XLearn(:,idx1p5s)))) = NaN;
[~, sortIdx] = sort(delta, 'ascend', 'MissingPlacement','last');
assignin('base','Fig3_4c_SortIdx', sortIdx);
assignin('base','Fig3_4c_SortDelta1p5_LearnedMinusNaive', delta);

% --- Prepare lane data (only 1~2s)
Xwin = X(:, xMask, :);
laneData = Xwin(sortIdx, :, :);

% CLim: mimic Fig3.3B (non-symmetric sqrt-scale, rounded)
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0, climLowAbs = 1; end
if climHighAbs <= 0, climHighAbs = 1; end
CLim = [-climLowAbs, climHighAbs];

% --- Plot
f = figure('Color','w', 'Name', 'Fig3.4C Lane heatmap (1~2s)');
try
	MATLAB.Graphics.FigureAspectRatio(1, 1, 2/3);
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
	ImagescStyle={'XData', seconds([1,2])}, ...
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
	xline(A, 1.5, '-k');
	A.TickDir = 'in';
	box(A, 'on');
	try
		if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
			A.Toolbar.Visible = 'off';
		end
	catch
	end
end

% --- Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	print(f, svgPath, '-dsvg', '-painters');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% local helpers (subset copied from Fig3.3B)

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
		error('Fig3_4c:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_4c:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[dtMin, idx] = min(abs(xsSec - double(targetSec)));
ok = ~isempty(idx) && isfinite(dtMin) && dtMin <= double(tolSec);
end

function lim = iNiceLimit(v)
if ~isfinite(v) || v <= 0
	lim = 1;
	return;
end
p = 10.^floor(log10(v));
lim = ceil(v / p) * p;
end

function T = iVcatNtatsTables(T1, T2)
if isempty(T1)
	T = T2;
	return;
end
if isempty(T2)
	T = T1;
	return;
end
try
	T = [T1; T2];
catch
	T = T1;
end
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
vars = ["Mouse","DateTime","Stimulus","Phase","BlockUID"];
try
	T = DS.TableQuery(vars, Phase=string(phaseName));
catch
	badMice = string.empty(0,1);
	return;
end
if isempty(T) || ~all(ismember(["Mouse","Stimulus"], string(T.Properties.VariableNames)))
	badMice = string.empty(0,1);
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "AudioWater", :);
badMice = unique(T.Mouse);
end

function mice = iMiceInPhaseStimulus(DS, phaseName, stimName, badMice)
try
	T = DS.TableQuery(["Mouse"], Phase=string(phaseName), Stimulus=string(stimName));
catch
	mice = string.empty(0,1);
	return;
end
if isempty(T)
	mice = string.empty(0,1);
	return;
end
mice = unique(string(T.Mouse));
if nargin >= 4 && ~isempty(badMice)
	mice = mice(~ismember(mice, string(badMice)));
end
end
