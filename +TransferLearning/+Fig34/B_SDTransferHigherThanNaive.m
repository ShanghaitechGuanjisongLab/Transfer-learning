% 图3.4B：三泳道热图（模仿 Fig3.3A），时间窗 1~2s；活跃判据用 NTATS@1.5s
%
% Lanes (share identical cell order):
% 1) Learned AudioWater
% 2) Transfer LightWater (per mouse: only first session; pure LightWater)
% 3) Final   LightWater
%
% Cell filter:
% - Active@1.5s: NTATS(1.5s) > mean(-3~0s) + 3*std(-3~0s) (per lane)
% - Exclude cells that are inactive at 1.5s in ALL lanes.
%
% Time window:
% - Plot only 1~2s (still uses baseline -3~0 for activity threshold)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig34.B_SDTransferHigherThanNaive

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_4b_LaneHeatmap_LearnedAudioWater_TransferLW_FirstSession_FinalLW_1to2_ActiveAt1p5.svg";

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

DS = TransferLearning.AudioLightBaseline();

% --- Time window 1~2s
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

xMask = (xsSec >= 1) & (xsSec <= 2);
if nnz(xMask) < 5
	error('Fig3_4b:BadTimeMask', 'Too few samples in 1~2s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 5
	error('Fig3_4b:BadBaseMask', 'Too few samples in baseline(-3~0).');
end

[idx1p5s, ok1p5s] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok1p5s
	error('Fig3_4b:No1p5s', 'Cannot find sample close to 1.5s in TransferLearning.Xs.');
end
kSigma = 3;

% --- Assert transfer first LightWater session uniqueness & purity (reuse Fig3.3A convention)
iAssertTransferLightWaterSingleSessionPure(DS);

% --- Query 3 lanes (Median ZScore NTATS)
qLearnedAudio = struct('Phase','Learned', 'Stimulus','AudioWater');
qTransferLW   = struct('Phase','Transfer','Stimulus','LightWater');
qFinalLW      = struct('Phase','Final',   'Stimulus','LightWater');

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLight = DS.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.FinalLight = DS.QueryNTATS(qFinalLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- Unify cells across lanes
S = UniExp.NtatsCellStrip(G);
assignin('base','Fig3_4b_CellStrip', S);

laneOrder = ["LearnedAudio","TransferLight","FinalLight"];
X = iGetNtats3D(S, laneOrder);

% --- Keep cells active at 1.5s in ANY lane
activeByLane = false(size(X,1), size(X,3));
for iL = 1:size(X,3)
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v = XL(:, idx1p5s);
	activeByLane(:, iL) = isfinite(v) & isfinite(baseMu) & isfinite(baseSd) & (v > (baseMu + kSigma*baseSd));
end
activeMask = any(activeByLane, 2);
assignin('base','Fig3_4b_ActiveMask', activeMask);
assignin('base','Fig3_4b_ActiveByLane_1p5s', activeByLane);

X = X(activeMask, :, :);

% --- Sorting by NTATS@1.5s difference (LearnedAudio - FinalLight)
XL = squeeze(X(:,:,1));
XF = squeeze(X(:,:,3));

delta = XL(:, idx1p5s) - XF(:, idx1p5s);
delta(~(isfinite(XL(:,idx1p5s)) & isfinite(XF(:,idx1p5s)))) = NaN;
[~, sortIdx] = sort(delta, 'ascend', 'MissingPlacement','last');
assignin('base','Fig3_4b_SortIdx', sortIdx);
assignin('base','Fig3_4b_SortDelta1p5_LearnedMinusFinal', delta);

% --- Prepare lane data for LanearHeatmap (only 1~2s)
Xwin = X(:, xMask, :);
laneData = Xwin(sortIdx, :, :);

% CLim: mimic Fig3.3A (non-symmetric sqrt-scale, rounded)
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
f = figure('Color','w', 'Name', 'Fig3.4B Lane heatmap (1~2s)');
try
	MATLAB.Graphics.FigureAspectRatio(3, 2, 3/4);
catch
end

Layout = tiledlayout(f, 1, 3, 'TileSpacing','none', 'Padding','tight');
subTitles = ["Learned AudioWater", "Transfer LightWater", "Final LightWater"];

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

%% local helpers (copied from Fig3.3A)

function iAssertTransferLightWaterSingleSessionPure(DS)
T = DS.TableQuery(["Mouse","DateTime"], Phase="Transfer", Stimulus="LightWater");
if isempty(T)
	error('Fig3_4b:NoTransferLW', 'No Transfer LightWater trials found.');
end
T.Mouse = string(T.Mouse);
try
	T.DateTime = datetime(T.DateTime);
	T.DateTime.TimeZone = '';
catch
end

mice = unique(T.Mouse);
for m = mice(:)'
	dt = unique(T.DateTime(T.Mouse == m));
	if numel(dt) ~= 1
		error('Fig3_4b:TransferMultiSession', 'Mouse %s has %d Transfer LW sessions (expected 1).', m, numel(dt));
	end
	% Purity: that DateTime should not contain AudioWater
	Ta = DS.TableQuery(["Mouse","DateTime"], Mouse=m, DateTime=dt, Stimulus="AudioWater");
	if ~isempty(Ta)
		error('Fig3_4b:TransferNotPure', 'Mouse %s Transfer LW session contains AudioWater trials.', m);
	end
end
end

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
		error('Fig3_4b:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_4b:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
