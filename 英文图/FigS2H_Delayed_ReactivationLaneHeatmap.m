% 英文图S2H：三泳道热图（ALDelayed 延迟任务版，模仿英文图S1E）
%
% 泳道（数据源 TransferLearning.ALDelayed；Always 给水回合不取）：
%   1 🔊        Naive    = AudioPreTrainCueOnly 首个会话（初始只给声；同会话
%                          AudioPreTrainWaterOnly 只给水不给声，不取，同 FigS2A 口径）
%   2 🔊💧      Learned  = AudioLearnWater 最后一个会话（声水学会；本库无 Phase 列，
%                          同 iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer
%                          取 Learned 期最后会话、FigS2A 的"最后一个含 AudioLearnWater 的会话"）
%   3 💡💧      Transfer = LightLearnWater 首个会话（声水学习后的首次光水 = Transfer 首块，
%                          同 ALDelayed_DivergencePCA_L23 / FigS2C）
% ALDelayed 无光侧 cue-only 预训练泳道（S1E 的 💡 Naive 对应物不存在），故 4 泳道减为 3。
%
% 细胞排序：按 1.5s 处 Learned 和 Transfer 中较小值降序（S1E 用 1s；延迟任务活跃判定点
% 用 cue +1.5 s，即反应/名义给水时刻）
% 活跃判定：在 Learned 与 Transfer 两泳道 1.5s 处 > baseline(-3~0s)+3σ（同 S1E 的两任务泳道交集）
% 绘图时段 cue -1 → +2.5 s（= S1E 的 -1~2 平移到延迟任务的给水时刻 +1.5 s）；
% 泳道 2/3 画给水线 xline(1.5)（S1E 为 xline(1)）。
%
% Execution:
%   run('英文图/FigS2H_Delayed_ReactivationLaneHeatmap.m')

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.ALDelayed();

% --- 1) Time axis
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

xMask = (xsSec >= -1) & (xsSec <= 2.5);
xsPlot = xsSec(xMask);

baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[idx15, ok15] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok15
	error('FigS2H:No15', 'Cannot find sample close to 1.5 s.');
end

% --- 2) Query 3 lanes (Median ZScore NTATS)，每鼠按上述会话定义取数
Q = iLaneQueryTable(DS);
G = DS.QueryNTATS(Q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
% 各泳道会话不同、有效细胞集不同 → QueryNTATS 按组名返回 struct；统一取交集细胞对齐
laneOrder = ["Naive", "Learned", "Transfer"];
[cellUID, X] = iExtractAligned(G, laneOrder); % [nCell x nTime x 3]，dim3 = laneOrder

nLanes = numel(laneOrder);
fprintf('Cells: %d\n', size(X, 1));

% --- 3) Active cell filtering: active at 1.5s in BOTH Learned and Transfer
activeByLane = false(size(X, 1), nLanes);
for iL = 1:nLanes
	XL = X(:, :, iL);
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v15 = XL(:, idx15);
	activeByLane(:, iL) = isfinite(v15) & isfinite(baseMu) & isfinite(baseSd) & (v15 > (baseMu + kSigma * baseSd));
end
activeMask = activeByLane(:, 2) & activeByLane(:, 3); % Learned AND Transfer both active

activeCellUID = cellUID(activeMask);
assignin('base', 'FigS2H_CellUID', cellUID);
assignin('base', 'FigS2H_ActiveMask', activeMask);
assignin('base', 'FigS2H_ActiveCellUID', activeCellUID);

X = X(activeMask, :, :);
fprintf('Active cells: %d / %d\n', sum(activeMask), numel(activeMask));

% --- 4) Sort by min(Learned@1.5s, Transfer@1.5s) descending
vLearned15 = X(:, idx15, 2);
vTransfer15 = X(:, idx15, 3);
sortKey = min(vLearned15, vTransfer15);
sortKey(~isfinite(sortKey)) = -inf;
[~, sortIdx] = sort(sortKey, 'descend');

% --- 5) Prepare lane data for heatmap
X_plot = X(:, xMask, :);
laneData = X_plot(sortIdx, :, :);

negV = min(laneData, [], 'all', 'omitnan');
posV = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs = sqrt(abs(min(negV, 0)));
climHighAbs = sqrt(abs(max(posV, 0)));
CLim = [-climLowAbs, climHighAbs];
%%

% --- 6) Plot（模仿英文图S1E）
f = figure('Color', 'w', 'Name', 'English FigS2H Delayed Lane Heatmap');
f.Units = 'centimeters';
f.Position(3:4) = [12.0, 8.0]; % 120mm x 80mm

Layout = tiledlayout(f, 1, 3, 'TileSpacing', 'none', 'Padding', 'tight');
subTitles = ["", "Learned", "Transfer"];

[~, Axes] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=subTitles, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=CLim, ...
	Layout=Layout, ...
	ImagescStyle={'XData', [xsPlot(1), xsPlot(end)]}, ...
	LMHColor=[0, 0, 1; 1, 1, 1; 1, 0, 0]);

xlabel(Layout, 'Time', 'FontSize', 12);
ylabel(Layout, sprintf('%d cells', size(laneData, 1)), 'FontSize', 12);

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';
CB.FontSize = 12;
CB.Label.FontSize = 12;
CB.Box = 'off';

% 泳道 xline/xtick：泳道 1 只有 cue 0s；泳道 2/3 加给水 1.5s（S1E 为 1s）
laneXTicks = {0, [0 1.5], [0 1.5]};

for iA = 1:numel(Axes)
	A = Axes(iA);
	if ~isgraphics(A), continue; end
	A.FontSize = 12;
	A.FontName = 'Segoe UI Emoji';
	A.LineWidth = 2;

	xline(A, 0, ':k', 'LineWidth', 2);
	if iA >= 2
		xline(A, 1.5, '-k', 'LineWidth', 2);
	end

	A.XTick = laneXTicks{iA};
	switch iA
		case 1
			A.XTickLabel = {"🔊"};
		case 2
			A.XTickLabel = {"🔊", "💧"};
		case 3
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

% --- 7) Export
svgName = "English_FigS2H_Delayed_ReactivationLaneHeatmap.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS2H_SortIdx', sortIdx);
assignin('base', 'FigS2H_SortKey_Min15', sortKey);

%% --- Local helpers

function Q = iLaneQueryTable(DS)
% 每鼠三个泳道的查询表：Naive=首个 AudioPreTrainCueOnly 会话；Learned=最后一个
% AudioLearnWater 会话；Transfer=首个 LightLearnWater 会话。Always 回合不取。
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
mice = unique(T.Mouse);
Mouse = strings(0, 1);
DateTime = NaT(0, 1);
Stimulus = strings(0, 1);
GroupName = strings(0, 1);
for i = 1:numel(mice)
	m = mice(i);
	Tn = T(T.Mouse == m & T.Stimulus == "AudioPreTrainCueOnly", :);
	if ~isempty(Tn)
		Mouse(end + 1, 1) = m;
		DateTime(end + 1, 1) = min(Tn.DateTime);
		Stimulus(end + 1, 1) = "AudioPreTrainCueOnly";
		GroupName(end + 1, 1) = "Naive";
	end
	Tl = T(T.Mouse == m & T.Stimulus == "AudioLearnWater", :);
	if ~isempty(Tl)
		Mouse(end + 1, 1) = m;
		DateTime(end + 1, 1) = max(Tl.DateTime);
		Stimulus(end + 1, 1) = "AudioLearnWater";
		GroupName(end + 1, 1) = "Learned";
	end
	Tt = T(T.Mouse == m & T.Stimulus == "LightLearnWater", :);
	if ~isempty(Tt)
		Mouse(end + 1, 1) = m;
		DateTime(end + 1, 1) = min(Tt.DateTime);
		Stimulus(end + 1, 1) = "LightLearnWater";
		GroupName(end + 1, 1) = "Transfer";
	end
end
Q = table(Mouse, DateTime, Stimulus, GroupName);
end

function [cellUID, X] = iExtractAligned(G, groupNames)
% QueryNTATS 输出两种形态：各组细胞集一致时为 [CellUID,NTATS] 表（NTATS 为
% [nCell x nTime x nGroup] 数组）；不一致时为按组名分字段的 struct，每字段
% [NTATS,CellUID] 表。这里统一取各组细胞交集，返回 [nCommon x nTime x nGroup]。
nG = numel(groupNames);
if istable(G)
	cellUID = uint64(G.CellUID);
	X = iNtatsToNumeric(G.NTATS);
	if ndims(X) ~= 3
		error('FigS2H:BadNTATS', 'Expected 3-D NTATS, got %s.', mat2str(size(X)));
	end
	return;
end
Xs = cell(nG, 1);
U = cell(nG, 1);
for k = 1:nG
	sub = G.(groupNames(k));
	U{k} = uint64(sub.CellUID);
	Xg = iNtatsToNumeric(sub.NTATS);
	if ndims(Xg) == 3
		Xg = squeeze(Xg(:, :, 1));
	end
	Xs{k} = Xg;
end
cellUID = U{1};
for k = 2:nG
	cellUID = intersect(cellUID, U{k}, 'stable');
end
X = nan(numel(cellUID), size(Xs{1}, 2), nG);
for k = 1:nG
	[tf, loc] = ismember(cellUID, U{k});
	X(tf, :, k) = Xs{k}(loc(tf), :);
end
end

function Xg = iNtatsToNumeric(nt)
% NTATS 列可能是 numeric 矩阵、NDTable 数组或 NDTable；统一转 double 数组
if isnumeric(nt)
	Xg = double(nt);
	return;
end
try
	Xg = double(nt.Data);
catch
	Xg = reshape(double([nt.Data]), size(nt));
end
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
