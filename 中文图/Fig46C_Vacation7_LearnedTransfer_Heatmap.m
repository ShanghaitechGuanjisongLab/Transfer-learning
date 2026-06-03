% 中文图46C：7天间隔声水Learned+光水Continual两泳道热图（不分hit/miss）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.Vacation7();

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('中文图46C:No1s', 'Cannot find sample close to 1s.');
end

qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTransfer = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.Transfer = DS.QueryNTATS(qTransfer, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

laneData3D = X(:, xMask, :);

% Active cell: 1s response > baseline + 3*sigma in either lane
activeByLane = false(size(X, 1), size(X, 3));
for iL = 1:size(X, 3)
	XL = squeeze(X(:, :, iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end
activeMask = any(activeByLane, 2);
laneData3D = laneData3D(activeMask, :, :);

% Sort by Learned@1s
vLearn1s = squeeze(X(activeMask, idx1s, 1));
vLearn1s(~isfinite(vLearn1s)) = -inf;
[~, sortIdx] = sort(vLearn1s, 'descend');

laneData = laneData3D(sortIdx, :, :);

% Symmetric color limits
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];

% Panel sample counts
panelNames = ["Learned"; "Continual"];
sampleMasks = [activeMask, activeMask];
if istable(S) && any(strcmp(S.Properties.VariableNames, 'CellUID'))
	activeCellUID = uint64(S.CellUID(activeMask));
else
	activeCellUID = uint64([]);
end
sampleCounts = TransferLearning.PanelSampleCountTable(S, panelNames, sampleMasks, DS.Cells);
%% 

f = figure('Color', 'w', 'Name', '中文图46C Vacation7声水Learned+光水Transfer热图');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];

Layout = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
subTitles = ["Learned", "Continual"];

[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[TransferLearning.HeatmapNegative; 1,1,1; TransferLearning.HeatmapPositive]);

xlabel(Layout, 'Time', 'FontSize', 12);
ylabel(Layout, sprintf('%d cells', size(laneData, 1)), 'FontSize', 12);

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.Box = 'off';

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A)
		continue;
	end
	A.FontName = 'Segoe UI Emoji';
	xline(A, 0, '--');
	xline(A, 1, '--');
	ticks = A.XTick;
	labels = string(A.XTickLabel);
	for iT = 1:numel(ticks)
		if abs(ticks(iT) - 0) < 0.05
			if iA == 1; labels(iT) = "🔊"; else; labels(iT) = "💡"; end
		end
		if abs(ticks(iT) - 1) < 0.05
			labels(iT) = "💧";
		end
	end
	A.XTickLabel = cellstr(labels);	A.TickDir = 'in';
	A.LineWidth = 2;
	box(A, 'on');
	if isprop(A, 'Title') && isgraphics(A.Title)
		A.Title.FontName = 'Segoe UI Emoji';
	end
	if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
		A.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig46C_Vacation7_LearnedTransfer_Heatmap.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== Fig46C sample counts ===\n');
disp(sampleCounts);

assignin('base', 'Fig46C_ActiveMask', activeMask);
assignin('base', 'Fig46C_ActiveCellUID', activeCellUID);
assignin('base', 'Fig46C_SortIdx', sortIdx);
assignin('base', 'Fig46C_SampleCounts', sampleCounts);

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
		error('中文图46C:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('中文图46C:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
