% English Fig2O: Divergence（散度）——12 h vs 7 d，按皮层分层（MOp2/3 上、MOp5 下）
%
% 口径与 英文图/Fig2F_Undelayed_DivergenceBarsByLayer.m、Fig1E 完全一致：
%   会话 = 各队列【首个 Transfer 期的 LightWater 会话】
%   散度 div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )，X = cue+1 s 的 细胞×回合 矩阵
%   每层（MOp2/3、MOp5）独立计算，要求该层细胞数 >= 3；每鼠一个值
%   统计：同层内 12 h vs 7 d 非配对 ranksum
%
% 配色（最新 Catppuccin）：12 h = Color12h(#FAB387)，7 d = Color7d(#F5C2E7)
% 版式：与 Fig1 柱图同一口径 —— 上下两个固定矩形轴、共用 Y 轴范围、柱宽 3 mm、单向误差棒、
%       PLine 星号置于柱顶
%
% 输出（SVG）：English_Fig2O_Divergence_12hVs7d_ByLayer.svg（46×80 mm → 排版 23×40 mm、6 pt）

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ---------- 数据 ----------
cohName = ["12 h", "7 d"];
DSList = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
idxT = iFindTimeIndex(1.0);

D = cell(1, 2);
for k = 1:2
	sess = iFirstTransferLWSessions(DSList{k});
	rows = iSessionDivergenceByLayer(sess, "LightWater", idxT);
	D{k} = iCollapseByMouse(rows);
	fprintf('%s：%d 只鼠有散度\n', cohName(k), height(D{k}));
end

V = cell(2, 2);   % {layer, cohort}
layerName = ["L2/3", "L5"];
layerField = ["DivL23", "DivL5"];
P = nan(2, 1);
for iL = 1:2
	for k = 1:2
		v = D{k}.(layerField(iL));
		V{iL, k} = v(isfinite(v));
	end
	[P(iL), ~] = TransferLearning.BehaviorSessions.iRanksumSafe(V{iL, 1}, V{iL, 2});
	fprintf('%-5s 12 h %.3f ± %.3f (n=%d) | 7 d %.3f ± %.3f (n=%d) | ranksum p = %.4g\n', ...
		layerName(iL), mean(V{iL, 1}), iSEM(V{iL, 1}), numel(V{iL, 1}), ...
		mean(V{iL, 2}), iSEM(V{iL, 2}), numel(V{iL, 2}), P(iL));
end

%% ---------- 画图 ----------
c12 = TransferLearning.Color12h / 255;   %#FAB387 Peach  = 12 h
c7 = TransferLearning.Color7d / 255;     %#F5C2E7 Pink   = 7 d
pairCols = [c12; c7];

figScale = 2;
figW = 2.3;   %cm，排版宽度（最终 23 mm）
figH = 4.6;   %cm，排版高度（最终 46 mm）——比单指标柱图高，因为要上下排两层 + 各自的标题/x 标签
iAxesRectTop = [0.44 0.58 0.52 0.30];
iAxesRectBot = [0.44 0.10 0.52 0.30];

f = figure('Color', 'w', 'Name', 'English Fig2O divergence by layer 12h vs 7d');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH] * figScale;
axTop = axes(f, 'Position', iAxesRectTop);
axBot = axes(f, 'Position', iAxesRectBot);

iBarPair(axTop, V{1, 1}, V{1, 2}, pairCols, ["12 h", "7 d"], P(1));
iBarPair(axBot, V{2, 1}, V{2, 2}, pairCols, ["12 h", "7 d"], P(2));

%两层共用 Y 轴范围，上下直接可比
yBoth = max(axTop.YLim(2), axBot.YLim(2));
axTop.YLim = [0, yBoth];
axBot.YLim = [0, yBoth];

%整列共享的 Y 轴标题（旋转 90°，垂直居中于整张图）
text(axBot, -0.60, 1.09, 'Divergence', 'Units', 'normalized', ...
	'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
	'FontSize', 6, 'Clipping', 'off');

%层的标识用各 tile 的 title（放在轴外，不会被显著性横线压到）
title(axTop, 'L2/3', 'FontSize', 6, 'FontWeight', 'normal');
title(axBot, 'L5', 'FontSize', 6, 'FontWeight', 'normal');

iExactPaper(f, figW * figScale, figH * figScale);
TransferLearning.ApplyStandardExportStyle(f, figScale);
iFixBarWidths(f, figW * 10, 1 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig2O_Divergence_12hVs7d_ByLayer.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2O_Divergence', struct('V', {V}, 'P', P, 'Layer', layerName, 'Cohort', cohName));

%% ================= 局部函数 =================
function iBarPair(ax, va, vb, cols, grpLabels, pVal)
hold(ax, 'on');
y = [mean(va), mean(vb)];
e = [iSEM(va), iSEM(vb)];
h = bar(ax, 1:2, y, 0.5, 'FaceColor', 'flat');   %宽度先给占位值，最后统一校正成 3 mm
h.CData = cols;
h.EdgeColor = 'none';
h.LineWidth = 0.5;
setappdata(ax, 'BarPairData', struct('y', y, 'e', e, 'cols', cols));
ax.XTick = 1:2;
ax.XTickLabel = cellstr(grpLabels);
ax.XTickLabelRotation = 0;
ax.FontSize = 6;
ax.LineWidth = 0.5;
xlim(ax, [0.5 2.5]);
yMax = max(y + e);
yLine = yMax * 1.04;                 %显著性横线：略高于较高那根误差棒
%星号（导出 12 pt）约占轴高的 15%，所以横线之上至少要留 20% 余量，否则星号会被顶出框外
ax.YLim = [0, yLine * 1.20];
%误差棒先按占位宽度画，最后统一校正成物理 mm
iDrawErrorBars(ax, y, e, cols, 0.16);
%显著性：一条横线跨越两根柱，星号居中放在横线上方
plot(ax, [1, 2], [yLine, yLine], 'k-', 'LineWidth', 1);
text(ax, 1.5, yLine + 0.01 * ax.YLim(2), ...
	string(TransferLearning.Style.iFormatPStars(pVal)), ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 6);
box(ax, 'off');
grid(ax, 'off');
end

function iFixBarWidths(f, figWmm, lw)
%柱宽/横帽按【物理 mm】固定，而不是数据单位
iAxesLeft = 0.44;
iAxesWidth = 0.52;
drawnow;
fpx = getpixelposition(f);
xSpan = 2;
barWmm = 3.0;
capHalfMm = 0.95;
for ax = findall(f, 'Type', 'axes').'
	p = ax.Position;
	ax.Position = [iAxesLeft, p(2), iAxesWidth, p(4)];
end
drawnow;
for ax = findall(f, 'Type', 'axes').'
	apx = getpixelposition(ax);
	axesWmm = apx(3) / fpx(3) * figWmm;
	set(findall(ax, 'Type', 'bar'), 'BarWidth', barWmm * xSpan / axesWmm);
	delete(findall(ax, 'Type', 'line', '-regexp', 'Tag', '^barWhisker|^barCap'));
	D = getappdata(ax, 'BarPairData');
	iDrawErrorBars(ax, D.y, D.e, D.cols, capHalfMm * xSpan / axesWmm, lw);
end
drawnow;
end

function iDrawErrorBars(ax, y, e, cols, capHalf, lw)
%单向误差棒（只向上）：不用 errorbar，避免下误差为 0 时在柱顶多画一条横帽
if nargin < 6
	lw = 1;
end
for k = 1:2
	yTopBar = y(k) + e(k);
	plot(ax, [k k k], [y(k) yTopBar yTopBar], '-', 'Color', cols(k, :), ...
		'LineWidth', lw, 'Tag', 'barWhisker');
	plot(ax, [k - capHalf, k, k + capHalf], [yTopBar yTopBar yTopBar], '-', ...
		'Color', cols(k, :), 'LineWidth', lw, 'Tag', 'barCap');
end
end

function iExactPaper(f, wCm, hCm)
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end

% ---------- 分层散度（Fig2F / Fig1E 口径）----------
function rows = iSessionDivergenceByLayer(sessTable, stimNames, idxT)
rows = table(strings(0, 1), nan(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
for iS = 1:height(sessTable)
	DS = sessTable.DS(iS);
	m = sessTable.Mouse(iS);
	dt = sessTable.DateTime(iS);
	ntsCell = DS.QueryNTS(struct('Stimulus', stimNames, 'Mouse', m, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
	if isempty(nts)
		continue;
	end
	trialUIDs = unique(uint64(nts.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	[CTT, cellUIDs] = iBuildCtt(nts, trialUIDs);
	if isempty(CTT) || size(CTT, 1) < 3
		continue;
	end
	X = CTT(:, :, idxT);
	CellTbl = DS.Cells;
	CellTbl.CellUID = uint64(CellTbl.CellUID);
	CellTbl.Mouse = string(CellTbl.Mouse);
	CellTbl.ZLayer = string(CellTbl.ZLayer);
	cellMeta = CellTbl(CellTbl.Mouse == m, {'CellUID', 'ZLayer'});
	[tf, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs), 1);
	layers(tf) = cellMeta.ZLayer(loc(tf));
	mask23 = layers == "MOp2/3";
	mask5 = layers == "MOp5";
	d23 = NaN;
	d5 = NaN;
	if sum(mask23) >= 3
		d23 = iDivFromX(X(mask23, :));
	end
	if sum(mask5) >= 3
		d5 = iDivFromX(X(mask5, :));
	end
	rows = [rows; table(string(m), d23, d5, 'VariableNames', {'Mouse', 'DivL23', 'DivL5'})]; %#ok<AGROW>
end
end

function [CTT, cellUIDs] = iBuildCtt(nts, trialUIDs)
allCells = unique(uint64(nts.CellUID));
traces = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rowsC = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rowsC));
	sig = double(nts.TrialSignal(rowsC, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	so = sig(loc, :);
	if any(~isfinite(so), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepUID(nKeep) = cid;
end
if nKeep < 3
	CTT = [];
	cellUIDs = uint64([]);
	return;
end
traces = traces(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = numel(trialUIDs);
nTime = size(traces{1}, 2);
CTT = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, nTrial, nTime);
end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function rows = iCollapseByMouse(rows)
if isempty(rows)
	return;
end
[G, mouseU] = findgroups(rows.Mouse);
d23 = splitapply(@(v) mean(v, 'omitnan'), rows.DivL23, G);
d5 = splitapply(@(v) mean(v, 'omitnan'), rows.DivL5, G);
rows = table(mouseU, d23, d5, 'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
end

function idx = iFindTimeIndex(targetSec)
xsSec = seconds(TransferLearning.Xs);
[~, idx] = min(abs(xsSec(:) - targetSec));
end

function sess = iFirstTransferLWSessions(DS)
sess = iEmptySessTable(DS);
T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex", "Behavior", "Stimulus"], Phase = "Transfer");
if isempty(T)
	return;
end
T = iTidyTrialTable(T);
T = T(T.Stimulus == "LightWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS', 'Mouse', 'DateTime'})]; %#ok<AGROW>
end
end

function sess = iEmptySessTable(DS)
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS', 'Mouse', 'DateTime'});
end

function T = iTidyTrialTable(T)
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
if ismember('Phase', T.Properties.VariableNames)
	T.Phase = string(T.Phase);
end
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
end

function s = iSEM(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end
