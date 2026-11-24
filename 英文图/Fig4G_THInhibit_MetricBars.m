% English Fig4G: TH 抑制 vs 12 h 对照，三个行为指标的柱图（first block / blocks to 50% / sigmoid slope）
%
% 版式照 英文图/Fig1_MetricBars_Pairwise.m：每指标一张 18×40 mm 小图、6 pt、
%   柱宽 3 mm、单向手绘误差棒、PLine 星号置于柱顶。
%
% 数据口径与 英文图/Fig4E_THInhibitVs12h_PenalizedSigmoidSlopeHistogram.m 完全一致：
%   12 h = BuildIntervalBehaviorCurves() 里 Group=="12h"（全部 12-h 行为队列）
%   TH   = BuildTHInhibitTrialTable()（成像鼠）+ BuildPOBehaviorTrialTable()（纯行为鼠）
%   slope = 逐 trial 惩罚 sigmoid（FixLowerZero），ComparePenalizedSigmoidSlopes 每鼠 Slope
%   FirstPerf / BlocksToHalf 由逐鼠逐 block 命中率算（与 Metrics.PerMouseSessionSummary 同定义）
%   检验：非配对 ranksum（同 Fig1 柱图口径）
%
% 配色（最新 Catppuccin）：12 h = Color12h #FAB387，TH = ColorTH #CBA6F7（该配对 ΔHue 116°）
%
% 输出（SVG）：English_Fig4G_THInhibit_MetricBars_{FirstBlock, BlocksTo50, SigmoidSlope}.svg

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
[IntervalCurves, IntervalTrials] = TransferLearning.BuildIntervalBehaviorCurves();
controlTrials = IntervalTrials(IntervalTrials.Group == "12h", :);
controlCurves = IntervalCurves(IntervalCurves.Group == "12h", :);
controlTrials = innerjoin(controlTrials, ...
	controlCurves(:, {'Group', 'Mouse', 'DateTime', 'Block'}), ...
	'Keys', {'Group', 'Mouse', 'DateTime'});
thImagingTrials = TransferLearning.BuildTHInhibitTrialTable();
thBehaviorTrials = TransferLearning.BuildPOBehaviorTrialTable();
commonVariables = {'Group', 'Mouse', 'DateTime', 'Block', 'Behavior', 'Source'};
trialTable = [controlTrials(:, commonVariables); ...
	thImagingTrials(:, commonVariables); thBehaviorTrials(:, commonVariables)];

% slope（逐 trial 惩罚 sigmoid）
R = TransferLearning.ComparePenalizedSigmoidSlopes(50000, trialTable, FixLowerZero = true);
PM = R.PerMouse;
gName = ["12h", "THInhibit"];      % 数据里的组名
gLabel = ["12 h", "TH"];           % 图上的组名

% first block / blocks to 50%
perMouse = table(strings(0, 1), strings(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'});
mice = unique(string(trialTable.Mouse), 'stable');
for iG = 1:2
	for iM = 1:numel(mice)
		R1 = trialTable(string(trialTable.Group) == gName(iG) & string(trialTable.Mouse) == mice(iM), :);
		if isempty(R1)
			continue;
		end
		blk = double(R1.Block);
		beh = double(R1.Behavior);
		bi = unique(blk);
		rate = arrayfun(@(b) mean(beh(blk == b), 'omitnan'), bi);
		perMouse = [perMouse; table(gName(iG), mice(iM), rate(1), iBlocksToHalf(bi, rate), ...
			'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'})]; %#ok<AGROW>
	end
end

%% ---------- 三指标 ----------
V = cell(1, 3);
V{1} = {perMouse.FirstPerf(perMouse.Group == gName(1)), perMouse.FirstPerf(perMouse.Group == gName(2))};
V{2} = {perMouse.BlocksToHalf(perMouse.Group == gName(1)), perMouse.BlocksToHalf(perMouse.Group == gName(2))};
okElig = logical(PM.FitEligible);
V{3} = {PM.Slope(PM.Group == gName(1) & okElig), PM.Slope(PM.Group == gName(2) & okElig)};

metricTag = ["FirstBlock", "BlocksTo50", "SigmoidSlope"];
metricYlab = ["Hit rate", "Blocks to 50%", "Sigmoid slope"];
P = nan(1, 3);
fprintf('\n=== Fig4G TH 抑制 vs 12 h 三指标 ===\n');
for m = 1:3
	[P(m), ~] = TransferLearning.BehaviorSessions.iRanksumSafe(V{m}{1}, V{m}{2});
	fprintf('%-14s 12h %.3f ± %.3f (n=%d) | TH %.3f ± %.3f (n=%d) | ranksum p = %.4g\n', ...
		metricTag(m), mean(V{m}{1}(isfinite(V{m}{1}))), iSEM(V{m}{1}), nnz(isfinite(V{m}{1})), ...
		mean(V{m}{2}(isfinite(V{m}{2}))), iSEM(V{m}{2}), nnz(isfinite(V{m}{2})), P(m));
end

%% ---------- 画图（照 Fig1 柱图口径，两个指标上下排一张）----------
%上 = Sigmoid slope，下 = Blocks to 50%；First block 不显著，不出图
pairCols = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;   %#FAB387 / #CBA6F7
figScale = 2;
figW = 2.2;   %cm，排版宽度（最终 22 mm）
figH = 4.0;   %cm，排版高度（最终 40 mm）
iAxesRectTop = [0.44 0.605 0.52 0.335];
iAxesRectBot = [0.44 0.145 0.52 0.335];

f = figure('Color', 'w', 'Name', 'Fig4G TH metric bars slope over blocks-to-50');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH] * figScale;
axTop = axes(f, 'Position', iAxesRectTop);
axBot = axes(f, 'Position', iAxesRectBot);

iBarPair(axTop, V{3}{1}, V{3}{2}, pairCols, gLabel, P(3), 'Sigmoid slope');
iBarPair(axBot, V{2}{1}, V{2}{2}, pairCols, gLabel, P(2), 'Blocks to 50%');
%两组名只在下面那张图出现，上面那张去掉 x 轴刻度标签
axTop.XTickLabel = [];

iExactPaper(f, figW * figScale, figH * figScale);
%先应用标准样式（字号/线宽），再校正柱宽，最后 print
TransferLearning.ApplyStandardExportStyle(f, figScale);
%样式会把字号改大并重排 PLine，重排后星号可能又顶出框外 —— 这里统一再抬一次 YLim
iContainAnnotations(f);
iFixBarWidths(f, figW * 10, 1 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig4G_THInhibit_MetricBars_SlopeAndBlocksTo50.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig4G_TH_MetricBars', struct('V', {V}, 'P', P, 'PerMouse', perMouse, 'PenalizedFit', R));

%% ================= 局部函数 =================
function iBarPair(ax, va, vb, cols, grpLabels, pVal, ylab)
hold(ax, 'on');
y = [mean(va), mean(vb)];
e = [iSEM(va), iSEM(vb)];
h = bar(ax, 1:2, y, 0.5, 'FaceColor', 'flat');   %宽度先给占位值，最后由 iFixBarWidths 校正
h.CData = cols;
h.EdgeColor = 'none';
h.LineWidth = 0.5;
setappdata(ax, 'BarPairData', struct('y', y, 'e', e, 'cols', cols));
ax.XTick = 1:2;
ax.XTickLabel = cellstr(grpLabels);
ax.XTickLabelRotation = 0;
ax.FontSize = 6;
ax.LineWidth = 0.5;
xlim(ax, [0.5 2.5]);   %柱子左右各留白，不贴 y 轴/右边框
ylabel(ax, ylab);
%同一张图里两柱共用一个上限；先定好 ylim，PLine 才好放星号
yTop = max([y + e, eps]) * 1.30;
ax.YLim = [0, yTop];
iDrawErrorBars(ax, y, e, cols, 0.16);
%不可见的两点 errorbar 作为定位对象，PLine 按误差条顶端放线
EB = errorbar(ax, 1:2, y, [0 0], e, 'LineStyle', 'none', 'Color', 'none', 'CapSize', 0.01);
D = table(repmat(EB, 1, 1), repmat(EB, 1, 1), 1, 2, ...
	string(TransferLearning.Style.iFormatPStars(pVal)), ...
	'VariableNames', ["ObjectA", "ObjectB", "IndexA", "IndexB", "Text"]);
MATLAB.Graphics.PLine(D);
%PLine 默认把文字垂直居中压在括号线上，改成底对齐让文字整体落在线上方；
%底对齐后文字顶边可能顶出框外，所以再按文字实际范围把 YLim 抬高一点
tx = findall(ax, 'Type', 'text');
if ~isempty(tx)
	set(tx, 'VerticalAlignment', 'bottom');
	drawnow;
	top = -inf;
	for k = 1:numel(tx)
		e = tx(k).Extent;
		top = max(top, e(2) + e(4));
	end
	if isfinite(top) && top > ax.YLim(2)
		ax.YLim = [ax.YLim(1), top + 0.04 * (top - ax.YLim(1))];
	end
end
box(ax, 'off');
grid(ax, 'off');
end

function iContainAnnotations(f)
%把每个轴的 YLim 抬到能完整装下所有 text（字号改大后星号容易被顶出框外）
for ax = findall(f, 'Type', 'axes').'
	drawnow;
	tx = findall(ax, 'Type', 'text');
	top = -inf;
	for k = 1:numel(tx)
		e = tx(k).Extent;
		if numel(e) < 4 || any(isnan(e))
			continue;
		end
		top = max(top, e(2) + e(4));
	end
	if isfinite(top) && top > ax.YLim(2)
		ax.YLim = [ax.YLim(1), top + 0.04 * (top - ax.YLim(1))];
	end
end
drawnow;
end

function iFixBarWidths(f, figWmm, lw)
%柱宽/横帽按【物理 mm】固定，而不是数据单位（同 Fig1 柱图）
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
%单向误差棒（只向上）。不用 errorbar：下误差给 0 时会在柱顶多画一条横帽，
%且 CapSize 以点为单位、不随字号/画布缩放。
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
%固定画布尺寸：PaperPositionMode='auto' 会在小图上额外加边距
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end

function half = iBlocksToHalf(x, y)
%首个 >=0.5 的 block，相邻两点线性插值；始终未达到记 max(block)+1
x = double(x(:));
y = double(y(:));
use = isfinite(y);
x = x(use);
y = y(use);
if isempty(y)
	half = NaN;
	return;
end
ic = find(y >= 0.5, 1, 'first');
if isempty(ic)
	half = max(x) + 1;
elseif ic == 1
	half = x(1);
else
	half = x(ic - 1) + (0.5 - y(ic - 1)) / (y(ic) - y(ic - 1));
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
