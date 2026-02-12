% 英文图2B：三泳道热图（Learned AW / Transfer Hit / Transfer Miss）
%
% 按 Learned-Miss delta@1s 排序，展示"哪些细胞被复用决定了行为结局"。
% 数据来源：AudioLightBaseline, Median ZScore NTATS, 0~1.5s
%
% 输出 SVG: English_Fig2B_LanearHeatmap.svg
%
% Execution:
%   TransferLearning.英文图2.B_LanearHeatmap_Learned_TransferHit_TransferMiss

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig2B_LanearHeatmap.svg";

DS = TransferLearning.AudioLightBaseline();

% --- 1) Time window 0~1.5s
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
xMask = (xsSec >= 0) & (xsSec <= 1.5);

% Active-cell criterion: NTATS(1s) > mean(-3~0s) + 3*std(-3~0s)
baseMask = (xsSec >= -3) & (xsSec < 0);
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

laneOrder = ["NaiveAudio","LearnedAudio","TransferHit","TransferMiss"];
X = iGetNtats3D(S, laneOrder);

plotLaneIdx = [2, 3, 4]; % Learned, TransferHit, TransferMiss

% --- 4) Keep cells active at 1s in ANY plotted lane
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig2B:No1s', 'Cannot find sample close to 1s.');
end

activeByLane = false(size(X,1), size(X,3));
for iL = plotLaneIdx
	XL = squeeze(X(:,:,iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & ...
		(v1 > (baseMu + kSigma*baseSd));
end
activeMask = any(activeByLane(:, plotLaneIdx), 2);
X = X(activeMask, :, :);

fprintf('Active cells (3σ in any plotted lane): %d / %d\n', sum(activeMask), numel(activeMask));

% --- 5) Sort by (Learned@1s - TransferMiss@1s)
XLearn = squeeze(X(:,:,2));
XMiss  = squeeze(X(:,:,4));
vLearn1s = XLearn(:, idx1s);
vMiss1s  = XMiss(:, idx1s);
delta1s = vLearn1s - vMiss1s;
delta1s(~(isfinite(vLearn1s) & isfinite(vMiss1s))) = NaN;
[~, sortIdx] = sort(delta1s, 'ascend', 'MissingPlacement','last');

% --- 6) Prepare lane data (only 0~1.5s)
X0to1p5 = X(:, xMask, :);
laneData = X0to1p5(sortIdx, :, plotLaneIdx);

% Color limits (symmetric colormap, sqrt-scale)
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0, climLowAbs = 1; end
if climHighAbs <= 0, climHighAbs = 1; end
CLim = [-climLowAbs, climHighAbs];

% --- 7) Plot
f = figure('Color','w', 'Name', 'English Fig2B Lane Heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];

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
	if isgraphics(Axes(iA))
		Axes(iA).FontSize = 12;
		Axes(iA).FontName = 'Segoe UI Emoji';
		xline(Axes(iA), 0, ':k');
		xline(Axes(iA), 1, '-k');
		Axes(iA).TickDir = 'in';
		box(Axes(iA), 'on');
		Axes(iA).Toolbar.Visible = 'off';
		if isprop(Axes(iA), 'Title') && isgraphics(Axes(iA).Title)
			Axes(iA).Title.FontName = 'Segoe UI Emoji';
			Axes(iA).Title.FontSize = 12;
		end
	end
end
CB.FontSize = 12;

% --- 8) Export
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('Cells plotted: %d\n', size(laneData, 1));

%% --- Local helpers

function X = iGetNtats3D(S, ~)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S,'NTATS')
	nt = S.NTATS;
else
	nt = S;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data.Data;
	return;
end
if isnumeric(nt)
	X = nt;
	return;
end
error('Fig2B:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function y = iNiceLimit(x)
if ~isfinite(x) || x <= 0
	y = 1; return;
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
