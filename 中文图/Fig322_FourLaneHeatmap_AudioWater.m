% 中文图322：四泳道热图（AudioOnly、WaterOnly、NaiveAudioWater、LearnedAudioWater）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
xsSec = seconds(xs);

fullMask = (xsSec >= -2) & (xsSec <= 2);
xsPlot = xsSec(fullMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('中文图322:No1s', 'Cannot find sample close to 1s.');
end

G = struct();
G.AudioOnly = DS.QueryNTATS(struct('Stimulus', 'AudioOnly'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.WaterOnly = DS.QueryNTATS(struct('Stimulus', 'WaterOnly'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.NaiveAudioWater = DS.QueryNTATS(struct('Phase', 'Naive', 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudioWater = DS.QueryNTATS(struct('Phase', 'Learned', 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

nLanes = size(X, 3);
activeByLane = false(size(X, 1), nLanes);
for iL = 1:nLanes
	XL = squeeze(X(:, :, iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end
activeMask = any(activeByLane, 2);

X = X(activeMask, :, :);

vNaive1 = squeeze(X(:, idx1s, 3));
vLearned1 = squeeze(X(:, idx1s, 4));
sortKey = min(vNaive1, vLearned1);
sortKey(~isfinite(sortKey)) = -inf;
[~, sortIdx] = sort(sortKey, 'descend');

laneData = X(sortIdx, fullMask, :);

negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];

f = figure('Color', 'w', 'Name', '中文图322 四泳道热图');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

Layout = tiledlayout(f, 1, 4, 'TileSpacing', 'none', 'Padding', 'tight');
subTitles = ["", "", "Naive", "Learned"];

[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[0,0,1; 1,1,1; 1,0,0]);

xlabel(Layout, 'Time', 'FontSize', 12);
ylabel(Layout, sprintf('%d cells', size(laneData, 1)), 'FontSize', 12);

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.FontSize = 12;
CB.Label.FontSize = 12;

for iA = 1:numel(Axes)
	A = Axes(iA);
	A.FontSize = 12;
	A.FontName = 'Segoe UI Emoji';
	A.TickDir = 'in';
	box(A, 'on');
	xline(A, 0, ':k', 'LineWidth', 2);
	if iA >= 3
		xline(A, 1, '-k', 'LineWidth', 2);
	end
	if iA == 2
		xlim(A, [-2 1]);
	else
		xlim(A, [-1 2]);
	end
	switch iA
		case 1
			A.XTick = 0;
			A.XTickLabel = {"🔊"};
		case 2
			A.XTick = 0;
			A.XTickLabel = {"💧"};
		otherwise
			A.XTick = [0 1];
			A.XTickLabel = {"🔊", "💧"};
	end
	A.LineWidth = 2;
	if isprop(A, 'Title') && isgraphics(A.Title)
		A.Title.FontName = 'Segoe UI Emoji';
		A.Title.FontSize = 12;
	end
	if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
		A.Toolbar.Visible = 'off';
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = fullfile(outDirUNC, '中文图Fig322_FourLaneHeatmap_AudioWater.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig322_ActiveMask', activeMask);
assignin('base', 'Fig322_SortIdx', sortIdx);
assignin('base', 'Fig322_SortKey_Min1s', sortKey);

function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
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
		error('中文图322:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

	error('中文图322:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function y = iNiceLimit(x)
if ~isfinite(x) || x <= 0
	y = 1;
	return;
end
e = floor(log10(x));
f = x / 10^e;
if f <= 1
	f2 = 1;
elseif f <= 2
	f2 = 2;
elseif f <= 5
	f2 = 5;
else
	f2 = 10;
end
y = f2 * 10^e;
end