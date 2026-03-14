function EnglishFig4B_TaskDiscrimination()
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

RSP = TransferLearning.RSPd();

xs = TransferLearning.Xs;
if ~isduration(xs), xs = seconds(xs); end
xsSec = seconds(xs);
xMask = (xsSec >= 0) & (xsSec <= 3);
if nnz(xMask) < 5
	error('EnglishFig4B:BadTimeMask', 'Too few samples in 0~3s window.');
end

kSigma = 3;
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('EnglishFig4B:BadBaselineMask', 'Baseline window (-3~0s) has too few samples.');
end

[idx1, ok1] = TransferLearning.Fig36.iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1
	error('EnglishFig4B:No1s', 'Cannot find sample close to 1s.');
end

qLearnedAudio = struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater');
QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), ...
	categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
	'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});

G = struct();
G.LearnedAudio = RSP.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit  = RSP.QueryNTATS(QT_HM(1,:), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = RSP.QueryNTATS(QT_HM(2,:), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
XFull = iGetNtats3D(S);

act = false(size(XFull,1), size(XFull,3));
for iLane = 1:size(XFull,3)
	Xi = double(XFull(:,:,iLane));
	baseMu = mean(Xi(:, baseMask), 2, 'omitnan');
	baseSd = std(Xi(:, baseMask), 0, 2, 'omitnan');
	val1 = Xi(:, idx1);
	act(:, iLane) = val1 > (baseMu + kSigma .* baseSd);
end
keepCell = any(act, 2) & any(isfinite(XFull(:, idx1, :)), 3);
XFull = XFull(keepCell, :, :);

XL = squeeze(XFull(:,:,1));
XMiss = squeeze(XFull(:,:,3));
diffLM = double(XL(:, idx1)) - double(XMiss(:, idx1));
diffLM(~isfinite(diffLM)) = NaN;
[~, sortIdx] = sort(diffLM, 'descend', 'MissingPlacement','last');

laneData = XFull(sortIdx, xMask, :);

negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0, climLowAbs = 1; end
if climHighAbs <= 0, climHighAbs = 1; end
CLim = [-climLowAbs, climHighAbs];

svgName = "English_Fig4B_RSPd_TaskDiscrimination.svg";
f = figure('Color','w', 'Name','English Fig4B RSPd Heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [12.0, 8.0];

Layout = tiledlayout(f, 1, 3, 'TileSpacing','none', 'Padding','tight');
subTitles = ["🔊💧 Learned", "💡💧 Tr Hit", "💡💧 Tr Miss"];

[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [0, 3]}, ...
	LMHColor=[0,0,1;1,1,1;1,0,0]);

xlabel(Layout, 'Time (s)', 'FontSize', 6);
ylabel(Layout, sprintf('%d cells', size(laneData,1)), 'FontSize', 6);

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.FontSize = 6;
CB.Label.FontSize = 6;

laneXTicks = {[0 1], [0 1], [0 1]};
laneXTickLabels = {{"🔊","💧"}, {"💡","💧"}, {"💡","💧"}};

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A), continue; end
	A.FontSize = 6;
	xline(A, 0, ':k');
	xline(A, 1, '-k');
	A.XTick = laneXTicks{iA};
	A.XTickLabel = laneXTickLabels{iA};
	A.TickDir = 'in';
	box(A, 'on');
	if isprop(A, 'Title') && isgraphics(A.Title)
		A.Title.FontSize = 6;
	end
	if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
		A.Toolbar.Visible = 'off';
	end
end

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'English_Fig4B_SortIdx', sortIdx);
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
if isnumeric(nt) && ndims(nt) == 3
	X = nt;
	return;
end
error('EnglishFig4B:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function y = iNiceLimit(x)
if ~isfinite(x) || x <= 0
	y = 1;
	return;
end
e = floor(log10(x));
f = x / (10^e);
if f <= 1, n = 1;
elseif f <= 2, n = 2;
elseif f <= 5, n = 5;
else, n = 10;
end
y = n * (10^e);
if y < x, y = 10 * (10^e); end
end