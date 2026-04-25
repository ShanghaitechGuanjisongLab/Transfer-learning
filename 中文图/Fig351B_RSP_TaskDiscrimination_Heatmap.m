% 中文图351B：RSP 声水学会与光水迁移命中/错失三列热图
%
% 图意对应英文图4B：RSP 对视觉线索响应强于听觉线索，
% 且对迁移命中/错失区分不强。
% 仅排除三列都不活跃的细胞。

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

RSP = TransferLearning.RSPd();
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
	error('中文图351B:No1s', 'Cannot find sample close to 1s.');
end

qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater', 'Design', 'AudioWater');
qTHit = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Design', 'LightWater', 'Behavior', 1);
qTMiss = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Design', 'LightWater', 'Behavior', 0);

G = struct();
G.LearnedAudio = RSP.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit = RSP.QueryNTATS(qTHit, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = RSP.QueryNTATS(qTMiss, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

activeByLane = false(size(X, 1), size(X, 3));
for iL = 1:size(X, 3)
	XL = squeeze(X(:, :, iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & ...
		(v1 > (baseMu + kSigma * baseSd));
end
activeMask = any(activeByLane, 2);

if istable(S) && any(strcmp(S.Properties.VariableNames, 'CellUID'))
	activeCellUID = uint64(S.CellUID(activeMask));
else
	activeCellUID = uint64([]);
end

X = X(activeMask, :, :);

vLearn1s = squeeze(X(:, idx1s, 1));
vHit1s = squeeze(X(:, idx1s, 2));
vMiss1s = squeeze(X(:, idx1s, 3));
vVisualMean = mean([vHit1s, vMiss1s], 2, 'omitnan');
sortKey = vVisualMean - vLearn1s;
sortKey(~(isfinite(vLearn1s) & isfinite(vVisualMean))) = -inf;
[~, sortIdx] = sort(sortKey, 'descend');

laneData = X(sortIdx, xMask, :);

negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];

f = figure('Color', 'w', 'Name', '中文图351B RSP 三列热图');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

Layout = tiledlayout(f, 1, 3, 'TileSpacing', 'none', 'Padding', 'tight');
subTitles = ["100% hit", "Hit", "Miss"];

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
CB.Box = 'off';

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A)
		continue;
	end
	A.FontSize = 12;
	A.FontName = 'Segoe UI Emoji';
	A.TickDir = 'in';
	A.LineWidth = 2;
	box(A, 'on');
	xline(A, 0, ':k', 'LineWidth', 2);
	xline(A, 1, '-k', 'LineWidth', 2);
	if iA == 1
		A.XTick = [0 1];
		A.XTickLabel = {"🔊", "💧"};
	else
		A.XTick = [0 1];
		A.XTickLabel = {"💡", "💧"};
	end
	if isprop(A, 'Title') && isgraphics(A.Title)
		A.Title.FontName = 'Segoe UI Emoji';
		A.Title.FontSize = 12;
	end
	if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
		A.Toolbar.Visible = 'off';
	end
end

svgPath = '中文图Fig351B_RSP_TaskDiscrimination_Heatmap.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig351B_ActiveMask', activeMask);
assignin('base', 'Fig351B_ActiveCellUID', activeCellUID);
assignin('base', 'Fig351B_SortIdx', sortIdx);
assignin('base', 'Fig351B_SortKey_VisualMinusAudio', sortKey);

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
		error('中文图351B:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('中文图351B:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
