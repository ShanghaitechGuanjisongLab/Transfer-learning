% 英文图1F：四泳道热图（Naive AudioOnly、Naive LightOnly、Learned AudioWater、Transfer LightWater）
%
% 细胞排序：按1s处 Learned AudioWater 和 Transfer LightWater 中较小值降序
% 活跃判定：在任一泳道（共4个）1s处 > baseline+3σ
%
% Execution:
%   TransferLearning.英文图1.F_LaneHeatmap


% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

DS = TransferLearning.AudioLightBaseline();

% --- 1) Time axis
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

% Plot window: -1~2s
xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

% Baseline and response masks
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

% Find 1s index
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1F:No1s', 'Cannot find sample close to 1s.');
end

% --- 2) Query 4 lanes (Median ZScore NTATS)
% Naive AudioOnly, Naive LightOnly, Learned AudioWater, Transfer LightWater
qNaiveAudioOnly = struct('Stimulus', 'AudioOnly');
qNaiveLightOnly = struct('Stimulus', 'LightOnly');
qLearnedAudio   = struct('Phase', 'Learned',  'Stimulus', 'AudioWater');
qTransferLight  = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');

G = struct();
G.NaiveAudioOnly = DS.QueryNTATS(qNaiveAudioOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.NaiveLightOnly = DS.QueryNTATS(qNaiveLightOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudio   = DS.QueryNTATS(qLearnedAudio,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLight  = DS.QueryNTATS(qTransferLight,  UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

% --- 3) Unify cells
S = UniExp.NtatsCellStrip(G);
assignin('base', 'Fig1F_CellStrip', S);

laneOrder = ["NaiveAudioOnly", "NaiveLightOnly", "LearnedAudio", "TransferLight"];
X = iGetNtats3D(S, laneOrder); % [nCell x nTime x 4]

% --- 4) Active cell filtering: active at 1s in BOTH Learned AudioWater AND Transfer LightWater
nLanes = size(X, 3);
activeByLane = false(size(X, 1), nLanes);
for iL = 1:nLanes
	XL = squeeze(X(:, :, iL));
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v1 = XL(:, idx1s);
	activeByLane(:, iL) = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end
activeMask = activeByLane(:, 3) & activeByLane(:, 4); % Learned AW AND Transfer LW both active

if istable(S) && any(strcmp(S.Properties.VariableNames, 'CellUID'))
	activeCellUID = uint64(S.CellUID(activeMask));
else
	activeCellUID = [];
end
assignin('base', 'Fig1F_ActiveMask', activeMask);
assignin('base', 'Fig1F_ActiveCellUID', activeCellUID);

X = X(activeMask, :, :);
fprintf('Active cells: %d / %d\n', sum(activeMask), numel(activeMask));

% --- 5) Sort by min(LearnedAudio@1s, TransferLight@1s) descending
XLearned  = squeeze(X(:, :, 3)); % LearnedAudio is lane 3
XTransfer = squeeze(X(:, :, 4)); % TransferLight is lane 4

vLearned1s  = XLearned(:, idx1s);
vTransfer1s = XTransfer(:, idx1s);

sortKey = min(vLearned1s, vTransfer1s);
sortKey(~isfinite(sortKey)) = -inf;

[~, sortIdx] = sort(sortKey, 'descend');

% --- 6) Prepare lane data for heatmap
X_plot = X(:, xMask, :);
laneData = X_plot(sortIdx, :, :); % [nCell x nTime x 4]

% Color limits
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];
%% 

% --- 7) Plot
f = figure('Color', 'w', 'Name', 'English Fig1F Lane Heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [12.0, 8.0]; % 120mm x 80mm

Layout = tiledlayout(f, 1, 4, 'TileSpacing', 'none', 'Padding', 'tight');
subTitles = ["", "", "100% hit", "Transfer"];

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

% Lane-specific xline and xtick settings
% Lane 1: AudioOnly - only 0s line, xticks(0), xticklabels = emoji speaker
% Lane 2: LightOnly - only 0s line, xticks(0), xticklabels = emoji light
% Lane 3: AudioWater - 0s and 1s lines, xticks([0,1]), xticklabels = emoji
% Lane 4: LightWater - 0s and 1s lines, xticks([0,1]), xticklabels = emoji
laneXTicks = {0, 0, [0 1], [0 1]};

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A), continue; end
	A.FontSize = 12;
	A.FontName = 'Segoe UI Emoji';
	A.LineWidth = 2;
	
	% xline: all lanes get 0s, lanes 3&4 also get 1s
	xline(A, 0, ':k', 'LineWidth', 2);
	if iA >= 3
		xline(A, 1, '-k', 'LineWidth', 2);
	end
	
	% xticks and xticklabels per lane
	A.XTick = laneXTicks{iA};
	switch iA
		case 1
			A.XTickLabel = {"🔊"};
		case 2
			A.XTickLabel = {"💡"};
		case 3
			A.XTickLabel = {"🔊", "💧"};
		case 4
			A.XTickLabel = {"💡", "💧"};
	end
	
	A.TickDir = 'in';
	box(A, 'on');
	try
		if isprop(A, 'Title') && isgraphics(A.Title)
			A.Title.FontName = 'Segoe UI Emoji';
			A.Title.FontSize = 12;
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

% --- 8) Export
try
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgName = "English_Fig1F_LaneHeatmap.svg";
svgPath = fullfile(outDirUNC, svgName);
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig1F_SortIdx', sortIdx);
assignin('base', 'Fig1F_SortKey_Min1s', sortKey);

%% --- Local helpers

function X = iGetNtats3D(S, ~)
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
		error('Fig1F:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig1F:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
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
if y < x
	y = 10 * (10^e);
end
end
