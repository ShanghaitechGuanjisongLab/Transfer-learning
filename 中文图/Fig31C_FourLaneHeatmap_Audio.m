% 英文图1F：四泳道热图（Naive AudioOnly、Naive AudioOnly、Learned AudioWater、Transfer AudioWater）
%
% 细胞排序：按1s处 Learned AudioWater 和 Transfer AudioWater 中较小值降序
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

% Plot window: will be dynamically set per lane
% Normal lanes: -1~2s, Water lane: -2~1s

% Baseline and response masks
kSigma = 3;

% Find 1s index
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1F:No1s', 'Cannot find sample close to 1s.');
end

% --- 2) Query 4 lanes (Median ZScore NTATS)
% Naive AudioOnly, Naive WaterOnly, AudioWater Block #1, Learned AudioWater
qNaiveAudioOnly = struct('Stimulus', 'AudioOnly');
qNaiveWaterOnly = struct('Stimulus', 'WaterOnly');
qFirstAudio   = struct('Phase', 'Naive', 'Stimulus', 'AudioWater', 'Session', 1);
qLearnedAudio   = struct('Phase', 'Learned',  'Stimulus', 'AudioWater');

G = struct();
try G.NaiveAudioOnly = DS.QueryNTATS(qNaiveAudioOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median); catch, G.NaiveAudioOnly = table(); end
try G.NaiveWaterOnly = DS.QueryNTATS(qNaiveWaterOnly, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median); catch, G.NaiveWaterOnly = table(); end
try G.FirstAudio     = iQueryFirstSession(DS, qFirstAudio); catch, G.FirstAudio = table(); end
try G.LearnedAudio   = DS.QueryNTATS(qLearnedAudio,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median); catch, G.LearnedAudio = table(); end

% --- 3) Unify cells
S = UniExp.NtatsCellStrip(G);
assignin('base', 'Fig31C_CellStrip', S);

laneOrder = ["NaiveAudioOnly", "NaiveWaterOnly", "FirstAudio", "LearnedAudio"];
X = iGetNtats3D(S, laneOrder); % [nCell x nTime x 4]

% --- 4) Active cell filtering: active at 1s in ANY lane
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

if istable(S) && any(strcmp(S.Properties.VariableNames, 'CellUID'))
	activeCellUID = uint64(S.CellUID(activeMask));
else
	activeCellUID = [];
end
assignin('base', 'Fig31C_ActiveMask', activeMask);
assignin('base', 'Fig31C_ActiveCellUID', activeCellUID);

X = X(activeMask, :, :);
activeMouseNames = iUniqueMouseNames(DS, S.CellUID(activeMask));
fprintf('\n=== 中文图31D / Fig31C ===\n');
fprintf('Mice: %d\n', numel(activeMouseNames));
fprintf('Active cells: %d / %d\n', sum(activeMask), numel(activeMask));

% --- 5) Sort by min(FirstAudio@1s, LearnedAudio@1s) descending
XFirst    = squeeze(X(:, :, 3)); 
XLearned  = squeeze(X(:, :, 4));

vFirst1s    = XFirst(:, idx1s);
vLearned1s  = XLearned(:, idx1s);

sortKey = min(vFirst1s, vLearned1s);
sortKey(~isfinite(sortKey)) = -inf;

[~, sortIdx] = sort(sortKey, 'descend');

% --- 6) Prepare lane data for heatmap
xMaskNormal = (xsSec >= -1) & (xsSec <= 2);
xMaskWater = (xsSec >= -2) & (xsSec <= 1);
xsPlotNormal = xsSec(xMaskNormal);
xsPlotWater = xsSec(xMaskWater);

laneData = nan(sum(activeMask), sum(xMaskNormal), 4);
laneData(:, :, 1) = X(sortIdx, xMaskNormal, 1);
laneData(:, :, 2) = X(sortIdx, xMaskWater, 2);
laneData(:, :, 3) = X(sortIdx, xMaskNormal, 3);
laneData(:, :, 4) = X(sortIdx, xMaskNormal, 4);

% Color limits
negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];
if isempty(CLim) || sum(abs(CLim)) == 0
	CLim = [-1, 1];
end
%% 

% --- 7) Plot
f = figure('Color', 'w', 'Name', '中文图31D Lane Heatmap Light');
f.Units = 'centimeters';
f.Position(3:4) = [12.0, 8.0]; % 120mm x 80mm

Layout = tiledlayout(f, 1, 4, 'TileSpacing', 'none', 'Padding', 'tight');
subTitles = ["", "", "Block #1", "Learned"];

[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={}, ...
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
% Lane 1: AudioOnly - only 0s line, xticks(0), xticklabels = emoji light
% Lane 2: WaterOnly - only 0s line, xticks(0), xticklabels = emoji drop
% Lane 3: FirstAudio - 0s and 1s lines, xticks([0,1]), xticklabels = emoji
% Lane 4: LearnedAudio - 0s and 1s lines, xticks([0,1]), xticklabels = emoji
laneXTicks = {0, 0, [0 1], [0 1]};

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A), continue; end
	A.FontSize = 12;
	A.FontName = 'Segoe UI Emoji';
	A.LineWidth = 2;
	
	% xline: 虚线
	xline(A, 0, '--k', 'LineWidth', 2);
	if iA >= 3
		xline(A, 1, '--k', 'LineWidth', 2);
	end
	
	if iA == 2
		A.XLim = [xsPlotWater(1), xsPlotWater(end)];
	else
		A.XLim = [xsPlotNormal(1), xsPlotNormal(end)];
	end
	
	% xticks and xticklabels per lane
	A.XTick = laneXTicks{iA};
	switch iA
		case 1
			A.XTickLabel = {"🔊"};
		case 2
			A.XTickLabel = {"💧"};
		case 3
			A.XTickLabel = {"🔊", "💧"};
		case 4
			A.XTickLabel = {"🔊", "💧"};
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

svgName = "中文图Fig31C_FourLaneHeatmap_Audio.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);
fprintf('Correlation / Significance test is not applicable for representative heatmaps.\n');

assignin('base', 'Fig31C_SortIdx', sortIdx);
assignin('base', 'Fig31C_SortKey_Min1s', sortKey);

%% --- Local helpers

function cellMouse = iGetCellMouse(DS, cellUID)
	cellMeta = DS.Cells(:, ["CellUID", "Mouse"]);
	cellMeta.Mouse = string(cellMeta.Mouse);
	[matched, loc] = ismember(uint64(cellUID), uint64(cellMeta.CellUID));
	if any(~matched)
		error("Cannot map cells to mice.");
	end
	cellMouse = strings(size(cellUID));
	cellMouse(matched) = cellMeta.Mouse(loc(matched));
end

function mouseNames = iUniqueMouseNames(DS, cellUID)
	cellMouse = iGetCellMouse(DS, cellUID);
	cellMouse = string(cellMouse(:));
	validMouse = ~ismissing(cellMouse) & strlength(cellMouse) > 0;
	mouseNames = unique(cellMouse(validMouse), 'stable');
end

function G = iQueryFirstSession(DS, queryParams)
	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"], Phase=queryParams.Phase, Stimulus=queryParams.Stimulus);
	T.Mouse = string(T.Mouse);
	mice = unique(T.Mouse);
	dtToKeep = NaT(0, 1);
	for iM = 1:numel(mice)
		m = mice(iM);
		Tm = T(T.Mouse == m, :);
		dts = unique(datetime(Tm.DateTime));
		dts = sort(dts);
		if ~isempty(dts)
			dtToKeep(end+1, 1) = dts(1); %#ok<AGROW>
		end
	end
	q = struct('Stimulus', queryParams.Stimulus, 'DateTime', dtToKeep);
	try
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = table();
	end
end

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







