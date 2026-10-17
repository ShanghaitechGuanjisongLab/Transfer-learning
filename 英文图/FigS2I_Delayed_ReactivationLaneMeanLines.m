% 英文图S2I：三泳道平均线图（ALDelayed 延迟任务版，模仿英文图S1F；与 S2H 相同细胞集）
%
% 三条线（数据源 TransferLearning.ALDelayed；Always 给水回合不取）：
%   1 🔊   Naive    = AudioPreTrainCueOnly 首个会话（初始只给声；AudioPreTrainWaterOnly
%                     只给水不给声不取，同 FigS2A 口径）
%   2 🔊💧 Learned  = AudioLearnWater 最后一个会话（声水学会；同 iBuildProb 取 Learned 期
%                     最后会话、FigS2A 的"最后一个含 AudioLearnWater 的会话"）
%   3 💡💧 Transfer = LightLearnWater 首个会话（声水学习后的首次光水 = Transfer 首块）
% ALDelayed 无光侧 cue-only 预训练泳道（S1F 的 💡 Naive 对应物不存在），故 4 泳道减为 3。
%
% 细胞筛选：与 S2H 相同，仅保留在 Learned 与 Transfer 两泳道 1.5s 处均活跃的细胞
% （S1F 用 1s；延迟任务活跃判定点用 cue +1.5 s，即反应/名义给水时刻）
% 使用 MATLAB.Graphics.MultiShadowedLines 画 mean ± SEM
% Naive 泳道用虚线以区分阶段（红=声侧、蓝=光侧，同 S1F 配色语义）
%
% Execution:
%   run('英文图/FigS2I_Delayed_ReactivationLaneMeanLines.m')

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
	error('FigS2I:No15', 'Cannot find sample close to 1.5 s.');
end

% --- 2) Query 3 lanes (Median ZScore NTATS)，每鼠按上述会话定义取数
Q = iLaneQueryTable(DS);
G = DS.QueryNTATS(Q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
laneOrder = ["Naive", "Learned", "Transfer"];
[cellUID, X] = iExtractAligned(G, laneOrder); % [nCell x nTime x 3]
nLanes = numel(laneOrder);

% --- 3) Active cell filtering: BOTH Learned and Transfer active at 1.5s
activeByLane = false(size(X, 1), nLanes);
for iL = 1:nLanes
	XL = X(:, :, iL);
	baseMu = mean(XL(:, baseMask), 2, 'omitnan');
	baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
	v15 = XL(:, idx15);
	activeByLane(:, iL) = isfinite(v15) & isfinite(baseMu) & isfinite(baseSd) & (v15 > (baseMu + kSigma * baseSd));
end
activeMask = activeByLane(:, 2) & activeByLane(:, 3);
X = X(activeMask, :, :);
fprintf('Active cells (both Learned & Transfer): %d / %d\n', sum(activeMask), numel(activeMask));

% --- 4) Compute mean ± SEM per lane (plot window only)
X_plot = X(:, xMask, :);
nCells = size(X_plot, 1);
nT = size(X_plot, 2);

Y = nan(nT, nLanes);
E = nan(nT, nLanes);
for iL = 1:nLanes
	D = X_plot(:, :, iL);
	Y(:, iL) = mean(D, 1, 'omitnan')';
	E(:, iL) = std(D, 0, 1, 'omitnan')' / sqrt(nCells);
end
%%

% --- 5) Plot（模仿英文图S1F）
f = figure('Color', 'w', 'Name', 'English FigS2I Delayed Lane Mean Lines');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;

laneColors2 = [230, 0, 18; 0, 112, 192] ./ 255;
laneColors = laneColors2([1; 1; 2], :); % 红=声侧（Naive/Learned），蓝=光侧（Transfer）
lineStyles = ["--"; "-"; "-"]; % Naive 虚线

hMain = MATLAB.Graphics.MultiShadowedLines(Y, E, 0.18, ...
	Ax=ax, ...
	X=xsPlot(:), ...
	EdgeColors=laneColors, ...
	LineStyles=lineStyles);
set(hMain, 'LineWidth', 2);
for iHandle = 1:numel(hMain)
	setappdata(hMain(iHandle), 'TransferLearningPreserveLineWidth', true);
end

xl0 = xline(ax, 0, ':k', 'LineWidth', 2);
xl1 = xline(ax, 1.5, '-k', 'LineWidth', 2);
setappdata(xl0, 'TransferLearningPreserveLineWidth', true);
setappdata(xl1, 'TransferLearningPreserveLineWidth', true);

box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time (s)', 'FontSize', 12);
ylabel(ax, 'z-score', 'FontSize', 12);

laneLabels = ["🔊", "🔊💧", "💡💧Trans."];
lg = legend(hMain, laneLabels, 'Location', 'northwest', 'Box', 'off');
lg.FontSize = 12;
lg.FontName = 'Segoe UI Emoji';

ax.Toolbar.Visible = 'off';

% --- 6) Export
title(ax, '🔊💡 reactive cells', 'FontSize', 12, 'FontWeight', 'normal');
svgName = "English_FigS2I_Delayed_ReactivationLaneMeanLines.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS2I_MeanLines_Y', Y);
assignin('base', 'FigS2I_MeanLines_SEM', E);
assignin('base', 'FigS2I_nCells', nCells);

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
		error('FigS2I:BadNTATS', 'Expected 3-D NTATS, got %s.', mat2str(size(X)));
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
