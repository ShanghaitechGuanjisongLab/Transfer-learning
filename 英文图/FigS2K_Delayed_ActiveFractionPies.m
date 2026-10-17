% 英文图S2K：活跃细胞占比饼图（ALDelayed 延迟任务版，模仿英文图S1H）
%
% 左: Learned AudioLearnWater 活跃细胞占所有记录细胞比例
% 中: Transfer LightWater 首块（首个会话）活跃细胞占所有记录细胞比例
% 右: Learned 活跃细胞在 Transfer 首块中被重新激活的比例
%
% 数据源 TransferLearning.ALDelayed；Always 给水回合不取；会话定义同 FigS2H/S2I：
%   Learned  = AudioLearnWater 最后一个会话（声水学会）
%   Transfer = LightLearnWater 首个会话（声水学习后的首次光水 = Transfer 首块）
% 活跃判定：线索后 1.5 s 处 z-score > 基线(-3~0s)均值 + 3σ（S1H 用 1s；延迟任务
% 活跃判定点用 cue +1.5 s，即反应/名义给水时刻）
% 输出单个 SVG，横向三个饼图
%
% Execution:
%   run('英文图/FigS2K_Delayed_ActiveFractionPies.m')

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
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

baseMask = (xsSec >= -3) & (xsSec < 0);
[idx15, ok15] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~ok15
	error('FigS2K:No15', 'Cannot find sample close to 1.5 s.');
end

kSigma = 3;

%% --- 每鼠会话定义：Learned = 最后一个含 AudioLearnWater 的会话；Transfer = 首个含 LightLearnWater 的会话
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
mice = unique(T.Mouse);
QL_Mouse = strings(0, 1); QL_DT = NaT(0, 1);
QT_Mouse = strings(0, 1); QT_DT = NaT(0, 1);
for i = 1:numel(mice)
	m = mice(i);
	Tl = T(T.Mouse == m & T.Stimulus == "AudioLearnWater", :);
	Tt = T(T.Mouse == m & T.Stimulus == "LightLearnWater", :);
	if ~isempty(Tl)
		QL_Mouse(end + 1, 1) = m;
		QL_DT(end + 1, 1) = max(Tl.DateTime);
	end
	if ~isempty(Tt)
		QT_Mouse(end + 1, 1) = m;
		QT_DT(end + 1, 1) = min(Tt.DateTime);
	end
end

%% --- Learned 活跃比例
QL = table(QL_Mouse, QL_DT, repmat("AudioLearnWater", numel(QL_Mouse), 1), repmat("Learned", numel(QL_Mouse), 1), ...
	'VariableNames', {'Mouse', 'DateTime', 'Stimulus', 'GroupName'});
GLearned = DS.QueryNTATS(QL, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
learnedTable = iBuildActiveCellTable(GLearned, idx15, baseMask, kSigma);
[learnedActiveN, learnedTotalN] = iUniqueCounts(learnedTable);

%% --- Transfer 首块活跃比例
QT = table(QT_Mouse, QT_DT, repmat("LightLearnWater", numel(QT_Mouse), 1), repmat("Transfer", numel(QT_Mouse), 1), ...
	'VariableNames', {'Mouse', 'DateTime', 'Stimulus', 'GroupName'});
GTransfer = DS.QueryNTATS(QT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
transferTable = iBuildActiveCellTable(GTransfer, idx15, baseMask, kSigma);
[transferActiveN, transferTotalN] = iUniqueCounts(transferTable);

%% --- 复用比例（Learned 活跃细胞在 Transfer 首块被重新激活）
learnedActiveIDs = unique(uint64(learnedTable.CellUID(logical(learnedTable.IsActive))));
transferActiveIDs = unique(uint64(transferTable.CellUID(logical(transferTable.IsActive))));
reuseIDs = intersect(learnedActiveIDs, transferActiveIDs);
nReuse = numel(reuseIDs);
[learnedActiveNDedup, ~] = iUniqueCounts(learnedTable(learnedTable.IsActive, :));
nLearnedActiveDenom = learnedActiveNDedup;

%% --- Plot: 3 pies side by side（同 S1H 布局：槽宽 4.9 cm、轴 3.36×3.12 cm、高 4.0 cm）
slotCm = 4;
axWCm = 3.36;
axLeft0Cm = 0.3;
figWCm = 3 * slotCm;
figHCm = 4.0;

f = figure('Color', 'none', 'Name', 'English FigS2K Delayed Active Fraction Pies');
f.Units = 'centimeters';
f.Position(3:4) = [figWCm, figHCm];

specs = { ...
	learnedActiveN, learnedTotalN, sprintf('🔊💧\nactive cells'), 'fraction'; ...
	transferActiveN, transferTotalN, sprintf('💡💧\nactive cells'), 'fraction'; ...
	nReuse, nLearnedActiveDenom, sprintf('💡💧\nreactivated'), 'reuse'};
for iP = 1:3
	axLeftCm = (iP - 1) * slotCm + axLeft0Cm;
	ax = axes(f, 'Units', 'normalized', ...
		'Position', [axLeftCm / figWCm, 0.12, axWCm / figWCm, 0.78]);
	iPlotOnePie(ax, specs{iP, 1}, specs{iP, 2}, specs{iP, 3}, specs{iP, 4});
end

set(findobj(f, 'Type', 'text'), 'FontSize', 6);

% --- Export
svgName = "English_FigS2K_Delayed_ActiveFractionPies.svg";
svgPath = TransferLearning.ExportStandardFigureTransparent(f, 1, svgName);

%% ========== Local helpers ==========

function activeTable = iBuildActiveCellTable(G, idx15, baseMask, kSigma)
if isempty(G)
	activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
	return;
end
if istable(G)
	cellUID = uint64(G.CellUID);
	X = iNtatsToNumeric(G.NTATS);
else
	fn = fieldnames(G);
	sub = G.(fn{1});
	cellUID = uint64(sub.CellUID);
	X = iNtatsToNumeric(sub.NTATS);
end
if ndims(X) == 3
	X = squeeze(X(:, :, 1));
end
if isempty(X)
	activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
	return;
end

baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v15 = X(:, idx15);
isActive = isfinite(v15) & isfinite(baseMu) & isfinite(baseSd) & (v15 > (baseMu + kSigma * baseSd));
activeTable = table(cellUID, logical(isActive), 'VariableNames', {'CellUID', 'IsActive'});
end

function Xg = iNtatsToNumeric(nt)
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

function [activeN, totalN] = iUniqueCounts(activeTable)
if isempty(activeTable)
	activeN = 0;
	totalN = 0;
	return;
end
[cellUID, idx] = unique(uint64(activeTable.CellUID), 'stable');
isActive = logical(activeTable.IsActive(idx));
activeN = nnz(isActive);
totalN = numel(cellUID);
end

function iPlotOnePie(ax, activeN, totalN, smallSliceLabel, pieMode)
% 照抄英文图S1H / 中文图43FG 的 iPlotOnePie 绘图逻辑
if totalN > 0
	frac = activeN / totalN;
else
	frac = NaN;
end

majorColor = 0.7922 .* [1 1 1];
minorColor = [0, 0.6275, 0.9137];

if strcmp(pieMode, 'reuse')
	valueVec = [1 - frac, frac];
	wedgeColors = [majorColor; minorColor];
	titleText = sprintf('🔊💧\nactive cells');
	sideText = smallSliceLabel;
	sideWedge = 2;
else
	valueVec = [frac, 1 - frac];
	if valueVec(1) >= valueVec(2)
		wedgeColors = [majorColor; minorColor];
	else
		wedgeColors = [minorColor; majorColor];
	end
	labelTexts = [string(smallSliceLabel), "all cells"];
	[~, majorIdx] = max(valueVec);
	[~, minorIdx] = min(valueVec);
	titleText = iCapitalizeLeadingLetter(labelTexts(majorIdx));
	sideText = labelTexts(1);
	sideWedge = minorIdx;
end

MATLAB.Graphics.NestedPie( ...
	{valueVec}, ...
	WedgeColors={wedgeColors}, ...
	LabelText=strings(1, 2), ...
	PercentStatus="on", ...
	PercentFontColor='k', ...
	RhoLower=0.4, ...
	LineWidth=0.5, ...
	LabelOffset=0.16, ...
	AxesHandle=ax);
title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');

if all(isfinite(valueVec)) && sum(valueVec) > 0
	startAngleDeg = [0, 360 * valueVec(1) / sum(valueVec)];
	endAngleDeg = [startAngleDeg(2), 360];
	thetaDeg = 0.5 * (startAngleDeg(sideWedge) + endAngleDeg(sideWedge));
	theta = deg2rad(thetaDeg);
	labelRadius = 1.12;
	tx = labelRadius * cos(theta);
	ty = labelRadius * sin(theta);
	if tx >= 0
		hAlign = 'left';
		tx = tx + 0.005;
	else
		hAlign = 'right';
		tx = tx - 0.005;
	end
	text(ax, tx, ty, sideText, 'FontSize', 6, 'FontWeight', 'normal', ...
		'Color', minorColor, 'HorizontalAlignment', hAlign, ...
		'VerticalAlignment', 'middle', 'Clipping', 'off');
end
end

function outText = iCapitalizeLeadingLetter(inText)
outText = string(inText);
chars = char(outText);
idx = regexp(chars, '[A-Za-z]', 'once');
if isempty(idx)
	return;
end
chars(idx) = upper(chars(idx));
outText = string(chars);
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
