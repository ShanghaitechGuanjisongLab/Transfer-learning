% Fig3.3A：三泳道热图（Median ZScore NTATS，0~1.5s）
%
% Lanes (share identical cell order):
% 1) Learned AudioWater
% 2) Transfer LightWater (assert: per-mouse only ONE session; and that session has NO AudioWater trials)
% 3) Final   LightWater
%
% Cell filter:
% - Exclude cells that are inactive at 1s in ALL 3 lanes.
%   Active@1s: NTATS(1s) > mean(-3~0s) + 3*std(-3~0s)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig33.A_LanearHeatmap_LearnedAudio_Transfer_Final

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3a_LanearHeatmap_LearnedAudio_Transfer_Final_0to1p5.svg";

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
	error('Fig3_3a:BadTimeMask', 'Too few samples in 0~1.5s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
respMask = (xsSec >= 0) & (xsSec <= 1);
if nnz(baseMask) < 5 || nnz(respMask) < 2
	error('Fig3_3a:BadActiveMasks', 'Too few samples in baseline/response window.');
end
kSigma = 3;

% --- 2) Assert Transfer LightWater session uniqueness & purity (per your requirement)
iAssertTransferLightWaterSingleSessionPure(DS);

% --- 3) Query 3 lanes (Median ZScore NTATS)
qLearnedAudio = struct('Phase','Learned', 'Stimulus','AudioWater');
qTransferLW   = struct('Phase','Transfer','Stimulus','LightWater');
qFinalLW      = struct('Phase','Final',   'Stimulus','LightWater');

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLight = DS.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.FinalLight = DS.QueryNTATS(qFinalLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 4) Unify cells across lanes
S = UniExp.NtatsCellStrip(G);
assignin('base','Fig3_3a_CellStrip', S);

laneOrder = ["LearnedAudio","TransferLight","FinalLight"];
X = iGetNtats3D(S, laneOrder);

% --- 5) Keep cells that are active at 1s in ANY lane
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig3_3a:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
end

activeByLane = false(size(X,1), size(X,3));
for iL = 1:size(X,3)
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma*baseSd));
end
activeMask = any(activeByLane, 2);

assignin('base','Fig3_3a_ActiveMask', activeMask);
assignin('base','Fig3_3a_ActiveByLane_1s', activeByLane);
if istable(S) && any(strcmp(S.Properties.VariableNames,'CellUID'))
	assignin('base','Fig3_3a_ActiveCellUID', uint64(S.CellUID(activeMask)));
end

X = X(activeMask, :, :);

% --- 6) Sorting by NTATS@1s difference (LearnedAudio - FinalLight)
XL = squeeze(X(:,:,1));
XF = squeeze(X(:,:,3));

vL1s = XL(:, idx1s);
vF1s = XF(:, idx1s);

delta1s = vL1s - vF1s;
delta1s(~(isfinite(vL1s) & isfinite(vF1s))) = NaN;

[~, sortIdx] = sort(delta1s, 'ascend', 'MissingPlacement','last');

% --- 7) Prepare lane data for LanearHeatmap (only 0~1.5s)
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
f = figure('Color','w', 'Name', 'Fig3.3A Lane heatmap (0~1.5s)');
try
	MATLAB.Graphics.FigureAspectRatio(73,48,3/4);
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

assignin('base','Fig3_3a_SortIdx', sortIdx);
assignin('base','Fig3_3a_SortDelta1s_LearnedMinusFinal', delta1s);

%% --- local helpers

function iAssertTransferLightWaterSingleSessionPure(DS)
% Requirement:
% - For each mouse, Transfer-phase LightWater trials belong to exactly ONE DateTime.
% - That DateTime must NOT contain any AudioWater trials.

T = DS.TableQuery(["Mouse","DateTime"], Phase="Transfer", Stimulus="LightWater");
if isempty(T)
	error('Fig3_3a:NoTransferLW', 'No Transfer LightWater trials found.');
end

T.Mouse = string(T.Mouse);
try
	T.DateTime = datetime(T.DateTime);
catch
end

mice = unique(T.Mouse);
badMulti = strings(0,1);
badEmpty = strings(0,1);
badMix = strings(0,1);

for i = 1:numel(mice)
	m = mice(i);
	dt = unique(T.DateTime(T.Mouse==m));
	dt = dt(~isnat(dt));
	if isempty(dt)
		badEmpty(end+1) = m; %#ok<AGROW>
		continue;
	end
	if numel(dt) ~= 1
		badMulti(end+1) = m; %#ok<AGROW>
		continue;
	end
	try
		Ts = DS.TableQuery("Stimulus", Mouse=m, DateTime=dt);
		st = string(Ts.Stimulus);
		if any(st == "AudioWater")
			badMix(end+1) = m; %#ok<AGROW>
		end
	catch
		% If we cannot query, treat as failure to satisfy the assertion.
		badMix(end+1) = m; %#ok<AGROW>
	end
end

if ~isempty(badEmpty)
	error('Fig3_3a:TransferLWBadDateTime', 'Some mice have Transfer LW trials but missing DateTime: %s', strjoin(badEmpty, ', '));
end
if ~isempty(badMulti)
	error('Fig3_3a:TransferLWMulitpleSessions', 'Transfer LightWater is not a single session for mice: %s', strjoin(badMulti, ', '));
end
if ~isempty(badMix)
	error('Fig3_3a:TransferLWMixedStim', 'Transfer LightWater session contains AudioWater trials for mice: %s', strjoin(unique(badMix), ', '));
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
		error('Fig3_3a:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_3a:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
