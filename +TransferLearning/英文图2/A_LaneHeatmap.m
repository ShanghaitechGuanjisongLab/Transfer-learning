% 英文图2A：双泳道热图（Transfer + Final LightWater）
%
% Lanes:
% 1) Transfer LightWater → 标题 "Transfer 💡💧"
% 2) Final LightWater → 标题 "💡💧100%"
%
% Cell filter: 两个泳道中至少一个 1s 活跃
% Pre-activation rate = Final 1s 活跃细胞中，Transfer 也活跃的比例
%
% Execution:
%   run('+TransferLearning/英文图2/A_LaneHeatmap.m')

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig2A_LaneHeatmap.svg";

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

DS = TransferLearning.AudioLightBaseline();

% --- 1) Time window 0~2s
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

xMask = (xsSec >= -1) & (xsSec <= 2);
if nnz(xMask) < 5
	error('Fig2A:BadTimeMask', 'Too few samples in -1~2s window.');
end

baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

% --- 2) Query 2 lanes (Median ZScore NTATS)
qTransferLW = struct('Phase','Transfer','Stimulus','LightWater');
qFinalLW    = struct('Phase','Final',   'Stimulus','LightWater');

G = struct();
G.TransferLight = DS.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.FinalLight = DS.QueryNTATS(qFinalLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 3) Unify cells across lanes
S = UniExp.NtatsCellStrip(G);

laneOrder = ["TransferLight","FinalLight"];
X = iGetNtats3D(S, laneOrder);

% --- 4) Find 1s index
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig2A:No1s', 'Cannot find sample close to 1s.');
end

% --- 5) Keep cells active at 1s in ANY lane
activeByLane = false(size(X,1), size(X,3));
for iL = 1:size(X,3)
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma*baseSd));
end
activeMask = any(activeByLane, 2);

% Calculate Pre-activation rate: Final active → Transfer also active
finalActive = activeByLane(:,2);
transferActive = activeByLane(:,1);
nFinalActive = nnz(finalActive);
nPreactivated = nnz(finalActive & transferActive);
if nFinalActive > 0
	preActivationRate = 100 * nPreactivated / nFinalActive;
else
	preActivationRate = 0;
end
fprintf('Pre-activation rate: %.1f%% (%d / %d Final-active cells also Transfer-active)\n', ...
	preActivationRate, nPreactivated, nFinalActive);

X = X(activeMask, :, :);
nCells = size(X, 1);
fprintf('Active cells (any lane): %d\n', nCells);

% --- 6) Sorting by min(Transfer, Final) at 1s
XT = squeeze(X(:,:,1));
XF = squeeze(X(:,:,2));
vT1s = XT(:, idx1s);
vF1s = XF(:, idx1s);
minVal1s = min(vT1s, vF1s);
minVal1s(~(isfinite(vT1s) & isfinite(vF1s))) = NaN;
[~, sortIdx] = sort(minVal1s, 'ascend', 'MissingPlacement','last');

% --- 7) Prepare lane data for LanearHeatmap (0~2s)
X0to2 = X(:, xMask, :);
laneData = X0to2(sortIdx, :, :);

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

% --- 8) Plot
f = figure('Color','w', 'Name', 'English Fig2A Lane heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4.5]; % 60mm x 45mm

Layout = tiledlayout(f, 1, 2, 'TileSpacing','none', 'Padding','tight');
subTitles = ["Transfer 💡💧", "💡💧100%"];

xsPlot = xsSec(xMask);
[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[0,0,1;1,1,1;1,0,0]);

xlabel(Layout, 'Time', 'FontSize', 6);
ylabel(Layout, sprintf('Overall pre-activation: %.1f%%', preActivationRate), 'FontSize', 6);

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.Label.FontSize = 6;
CB.FontSize = 6;

% xtick/xticklabel: 只保留 0→💡, 1→💧
for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A)
		continue;
	end
	A.FontSize = 6;
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
		A.Title.FontSize = 6;
	end
end

Layout.Title.FontSize = 6;

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

%% --- local helpers

function X = iGetNtats3D(S, ~)
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
		error('Fig2A:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig2A:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
