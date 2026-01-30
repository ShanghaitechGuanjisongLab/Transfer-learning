% Fig3.2B：声转光迁移热图（Median ZScore NTATS，0~1.5s）
%
% NOTE（论文排版口径更新）:
% - 去掉 Naive 泳道（不显示）。
% - 去掉“只在 Naive 活跃”的细胞：activeMask 只在被绘制泳道上判定。
%
% Available lanes (share identical cell order):
% 1) Naive  AudioWater (queried for unification only; NOT plotted)
% 2) Learned AudioWater
% 3) Transfer LightWater Hit
% 4) Transfer LightWater Miss
%
% Cell unification:
% - Use UniExp.NtatsCellStrip to unify the cell set across the 4 lanes.
%
% Plot:
% - UniExp.LanearHeatmap
% - Time window shown: 0~1.5s (cue at 0s, water at 1s)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig32.B_LanearHeatmap_Learned_TransferHit_TransferMiss

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2b_LanearHeatmap_Learned_TransferHit_TransferMiss_0to1p5.svg";

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

DS = TransferLearning.AudioLightBaseline();

% --- 1) Time window 0~1.5s
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
xMask = (xsSec >= 0) & (xsSec <= 1.5);
if nnz(xMask) < 5
	error('Fig3_2b:BadTimeMask', 'Too few samples in 0~1.5s window.');
end

% Active-cell criterion (plotted lanes only): NTATS(1s) > mean(-3~0s) + 3*std(-3~0s)
baseMask = (xsSec >= -3) & (xsSec < 0);
respMask = (xsSec >= 0) & (xsSec <= 1);
if nnz(baseMask) < 5 || nnz(respMask) < 2
	error('Fig3_2b:BadActiveMasks', 'Too few samples in baseline/response window for active-cell criterion.');
end
kSigma = 3;

% --- 2) Query 4 lanes (Median ZScore NTATS)
qNaiveAudio   = struct('Phase','Naive',   'Stimulus','AudioWater');
qLearnedAudio = struct('Phase','Learned', 'Stimulus','AudioWater');
qTHit         = struct('Phase','Transfer','Stimulus','LightWater','Behavior',1);
qTMiss        = struct('Phase','Transfer','Stimulus','LightWater','Behavior',0);

G = struct();
G.NaiveAudio   = DS.QueryNTATS(qNaiveAudio,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit  = DS.QueryNTATS(qTHit,         UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = DS.QueryNTATS(qTMiss,        UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 3) Unify cells across lanes
S = UniExp.NtatsCellStrip(G);
assignin('base','Fig3_2b_CellStrip', S);

laneOrder = ["NaiveAudio","LearnedAudio","TransferHit","TransferMiss"];
X = iGetNtats3D(S, laneOrder);

plotLaneIdx = [2, 3, 4]; % Learned, TransferHit, TransferMiss

% --- 3.5) Keep cells that are active at 1s in ANY plotted lane
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig3_2b:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
end

activeByLane = false(size(X,1), size(X,3));
for iL = plotLaneIdx
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma*baseSd));
end
activeMask = any(activeByLane(:, plotLaneIdx), 2);

if istable(S) && any(strcmp(S.Properties.VariableNames,'CellUID'))
	activeCellUID = uint64(S.CellUID(activeMask));
else
	activeCellUID = [];
end
assignin('base','Fig3_2b_ActiveMask', activeMask);
assignin('base','Fig3_2b_ActiveCellUID', activeCellUID);
assignin('base','Fig3_2b_ActiveByLane_1s', activeByLane);

X = X(activeMask, :, :);

% --- 4) Compute sort key using NTATS@1s difference
% Sort key: (LearnedAudio@1s - TransferMiss@1s)
XLearn = squeeze(X(:,:,2));
XMiss  = squeeze(X(:,:,4));

vLearn1s = XLearn(:, idx1s);
vMiss1s  = XMiss(:, idx1s);

delta1s = vLearn1s - vMiss1s;
delta1s(~(isfinite(vLearn1s) & isfinite(vMiss1s))) = NaN;

[~, sortIdx] = sort(delta1s, 'ascend', 'MissingPlacement','last');

% --- 5) Prepare lane data for LanearHeatmap (only 0~1.5s)
X0to3 = X(:, xMask, :);
laneData = X0to3(sortIdx, :, plotLaneIdx);

% Color limits (NON-symmetric): sqrt-scale magnitude for lower/upper separately
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

% --- 6) Plot
f = figure('Color','w', 'Name', 'Fig3.2b Lane heatmap (0~1.5s)');
try
	MATLAB.Graphics.FigureAspectRatio(71,46,3/4);
catch
end

Layout = tiledlayout(f, 1, 3, 'TileSpacing','none', 'Padding','tight');
subTitles = ["Learned 🔊💧", "Tr 💡💧 Hit", "Tr 💡💧 Miss"];

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
		% Ensure emoji glyphs render in exported SVG on Windows.
		if isprop(A, 'Title') && isgraphics(A.Title)
			A.Title.FontName = 'Segoe UI Emoji';
		end
	catch
	end
	try
		if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
			A.Toolbar.Visible = 'off';
		end
	catch
	end
end

% --- 7) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% diagnostics to base
assignin('base','Fig3_2b_SortIdx', sortIdx);
assignin('base','Fig3_2b_SortDelta1s_LearnedMinusMiss', delta1s);
assignin('base','Fig3_2b_Learned1s', vLearn1s);
assignin('base','Fig3_2b_TransferMiss1s', vMiss1s);

%% --- local helpers

function X = iGetNtats3D(S, ~)
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
		error('Fig3_2b:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_2b:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
% Find index closest to tSec within tolSec.
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end

[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
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

% ensure not below x (numerical safety)
if y < x
	y = 10 * (10^e);
end
end
