% 英文图2B：双泳道热图（Naive + Learned LightWater）
%
% Lanes:
% 1) Naive LightWater → 标题 "Naive 💡💧"
% 2) Learned LightWater → 标题 "💡💧100%"
%
% Data sources (same as Fig3.3B):
% - LAInterspersed (exclude sessions/mice whose LightWater blocks mix AudioWater)
% - LightAudioBaseline
%
% Cell filter: 两个泳道中至少一个 1s 活跃
% Pre-activation rate = Learned 1s 活跃细胞中，Naive 也活跃的比例
%
% Execution:
%   run('+TransferLearning/英文图2/B_LaneHeatmap.m')

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig2B_LaneHeatmap.svg";

% --- 0) Ensure project loaded
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
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

xMask = (xsSec >= -1) & (xsSec <= 2);
if nnz(xMask) < 5
	error('Fig2B:BadTimeMask', 'Too few samples in -1~2s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

% --- 2) Load datasets (same as Fig3.3B)
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

X = iGetNtats3D(S);

% --- 5) Find 1s index
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig2B:No1s', 'Cannot find sample close to 1s.');
end

% --- 6) Keep cells active at 1s in ANY lane
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

% Calculate Pre-activation rate: Learned active → Naive also active
naiveActive = activeByLane(:,1);
learnedActive = activeByLane(:,2);
nLearnedActive = nnz(learnedActive);
nPreactivated = nnz(learnedActive & naiveActive);
if nLearnedActive > 0
	preActivationRate = 100 * nPreactivated / nLearnedActive;
else
	preActivationRate = 0;
end
fprintf('Pre-activation rate: %.1f%% (%d / %d Learned-active cells also Naive-active)\n', ...
	preActivationRate, nPreactivated, nLearnedActive);

X = X(activeMask, :, :);
nCells = size(X, 1);
fprintf('Active cells (any lane): %d\n', nCells);

% --- 7) Sorting by min(Naive, Learned) at 1s
XNaive = squeeze(X(:,:,1));
XLearn = squeeze(X(:,:,2));
vN1s = XNaive(:, idx1s);
vL1s = XLearn(:, idx1s);
minVal1s = min(vN1s, vL1s);
minVal1s(~(isfinite(vN1s) & isfinite(vL1s))) = NaN;
[~, sortIdx] = sort(minVal1s, 'ascend', 'MissingPlacement','last');

% --- 8) Prepare lane data for LanearHeatmap (-1~2s)
X_plot = X(:, xMask, :);
laneData = X_plot(sortIdx, :, :);

% Non-symmetric sqrt-scale CLim
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0, climLowAbs = 1; end
if climHighAbs <= 0, climHighAbs = 1; end
CLim = [-climLowAbs, climHighAbs];

% --- 9) Plot
f = figure('Color','w', 'Name', 'English Fig2B Lane heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [12, 9]; % 120mm x 90mm

Layout = tiledlayout(f, 1, 2, 'TileSpacing','none', 'Padding','tight');
subTitles = ["Naive 💡💧", "💡💧100%"];

xsPlot = xsSec(xMask);
[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[0,0,1;1,1,1;1,0,0]);

xlabel(Layout, 'Time', 'FontSize', 12);
ylabel(Layout, sprintf('Overall pre-activation: %.1f%%', preActivationRate), 'FontSize', 12);


% xtick/xticklabel: 只保留 0→💡, 1→💧
for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A)
		continue;
	end
	A.FontSize = 12;
	xline(A, 0, ':k');
	xline(A, 1, '-k');
	A.TickDir = 'in';
	box(A, 'on');
	
	% Set xticks to only 0 and 1
	A.XTick = [0, 1];
	A.XTickLabel = {'💡', '💧'};
	
	try
		if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
			A.Toolbar.Visible = 'off';
		end
	catch
	end
end

% Title font size
for iA = 1:numel(Axes)
	A = Axes(iA);
	if isgraphics(A) && ~isempty(A.Title)
		A.Title.FontSize = 12;
	end
end

Layout.Title.FontSize = 12;

% --- 10) Export
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
		error('Fig2B:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig2B:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function lim = iNiceLimit(x)
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
