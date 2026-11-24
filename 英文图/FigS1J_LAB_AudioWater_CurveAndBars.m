% English FigS1J：声水（LAB 方向，光→声）行为学 —— 学习曲线 + 三指标柱图
%
% 会话口径与 英文图/Fig1L_AudioWater_NaiveVsTransfer_LearningCurve.m 完全一致：
%   Naive    = AudioLightBaseline（成像）+ ALPureBehavior（纯行为），Phase Naive→Learned
%   Transfer = LightAudioBaseline（成像）+ LAPureBehavior（纯行为），Phase Transfer→Final
%   只取 AudioWater 回合；每个 Mouse×DateTime 先算命中率，再跨鼠汇总。
%
% 版式照 Fig1 最新口径：
%   曲线 45×40 mm：逐 block 均值 ± SEM，实心点 + 手绘对称误差棒 + 连线（无拟合、无阴影带），
%                  只展示 1–7；显著性 = 横跨 1–7 的横线 + 上方星号（LMM Group 效应）
%   柱图 30×40 mm：上 = first block，下 = blocks to 50%；3 mm 柱、单向误差棒、PLine 星号
% 注：不算 sigmoid slope —— 两组前 2–3 个 block 就饱和，斜率不可辨识（且 3 只鼠只有 1 个 block），
%     正文只用 first block 与 blocks to 50%。
%
% 配色（最新 Catppuccin 原色）：Naive = ColorNaive #F38BA8，Transfer = Color12h #FAB387
%
% 输出（SVG）：
%   English_FigS1J_AudioWater_NaiveVsTransfer_LearningCurve.svg
%   English_FigS1J_AudioWater_MetricBars_FirstBlockAndBlocksTo50.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%注意：TransferLearning.<属性>() 一被调用，+TransferLearning 包就无法再用类名解析，
%所以包函数必须在取色之前全部用完。
DSnaive1 = TransferLearning.AudioLightBaseline();
DSnaive2 = TransferLearning.ALPureBehavior();
DStran1 = TransferLearning.LightAudioBaseline();
DStran2 = TransferLearning.LAPureBehavior();
groupColor = [TransferLearning.ColorNaive; TransferLearning.Color12h] / 255;

%% ---------- 会话表 ----------
sessionParts = {
	iAudioSessions(DSnaive1, "AudioLightBaseline", "Naive", "Learned", "Naive", true)
	iAudioSessions(DSnaive2, "ALPureBehavior", "Naive", "Learned", "Naive", false)
	iAudioSessions(DStran1, "LightAudioBaseline", "Transfer", "Final", "Transfer", true)
	iAudioSessions(DStran2, "LAPureBehavior", "Transfer", "Final", "Transfer", false)
};
allSessions = vertcat(sessionParts{:});
if isempty(allSessions), error('FigS1J:EmptyData', '没有有效的声水学习会话。'); end
allSessions = TransferLearning.DelayComparison.AddBlockIndex(allSessions);
cohorts = ["Naive", "Transfer"];
maxBlock = 7;

for k = 1:2
	use = allSessions.Group == cohorts(k);
	fprintf('%s：%d 只鼠，%d 个会话\n', cohorts(k), numel(unique(allSessions.Mouse(use))), nnz(use));
end

%% ---------- 曲线（前 7 block）----------
MU = cell(1, 2); SEM = cell(1, 2); X = cell(1, 2);
for k = 1:2
	use = allSessions.Group == cohorts(k) & allSessions.Block <= maxBlock;
	Sg = allSessions(use, :);
	mu = nan(1, maxBlock);
	se = nan(1, maxBlock);
	for b = 1:maxBlock
		y = double(Sg.Performance(Sg.Block == b));
		if isempty(y), continue; end
		mu(b) = mean(y, 'omitnan');
		se(b) = std(y, 'omitnan') / sqrt(numel(y));
	end
	X{k} = 1:maxBlock;
	MU{k} = mu;
	SEM{k} = se;
	SEM{k}(~isfinite(SEM{k})) = 0;
	fprintf('  %s 前 %d block 均值 %s\n', cohorts(k), maxBlock, mat2str(round(mu, 3)));
end

sessions7 = allSessions(allSessions.Block <= maxBlock, :);
pGroup = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Block', 'Group', 'Mouse');
pAll = TransferLearning.Style.TwoWayAnovaGroupPValue(allSessions, 'Performance', 'Block', 'Group', 'Mouse');
fprintf('LMM Group p：block 1-%d = %.4g；全部 block = %.4g\n', maxBlock, pGroup, pAll);

%% ---------- 两个指标（逐鼠）----------
% first block / blocks to 50%：会话级
perMouse = table(strings(0, 1), strings(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'});
for k = 1:2
	Sg = allSessions(allSessions.Group == cohorts(k), :);
	ms = unique(Sg.Mouse, 'stable');
	for i = 1:numel(ms)
		r = sortrows(Sg(Sg.Mouse == ms(i), :), 'Block');
		y = double(r.Performance);
		b = double(r.Block);
		half = iBlocksToHalf(b, y);
		perMouse = [perMouse; table(cohorts(k), ms(i), y(1), half, ...
			'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'})]; %#ok<AGROW>
	end
end

V = cell(1, 2);
V{1} = {perMouse.FirstPerf(perMouse.Group == cohorts(1)), perMouse.FirstPerf(perMouse.Group == cohorts(2))};
V{2} = {perMouse.BlocksToHalf(perMouse.Group == cohorts(1)), perMouse.BlocksToHalf(perMouse.Group == cohorts(2))};

metricTag = ["FirstBlock", "BlocksTo50"];
metricYlab = ["Hit rate", "Blocks to 50%"];
Pm = nan(1, 2);
fprintf('\n=== 两个指标（Naive vs Transfer）===\n');
for m = 1:2
	a = V{m}{1}; b = V{m}{2};
	a = a(isfinite(a)); b = b(isfinite(b));
	Pm(m) = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
	fprintf('%-14s Naive %.3f ± %.3f (n=%d) | Transfer %.3f ± %.3f (n=%d) | ranksum p = %.4g\n', ...
		metricTag(m), mean(a), iSEM(a), numel(a), mean(b), iSEM(b), numel(b), Pm(m));
end

%% ---------- 图 1：学习曲线 ----------
figScale = 2;
figWmm = 45; figHmm = 40;
f = figure('Color', 'w', 'Name', 'FigS1J AudioWater learning curve (blocks 1-7)');
f.Units = 'centimeters';
f.Position(3:4) = [figWmm, figHmm] / 10 * figScale;
ax = axes(f, 'Position', [0.18 0.19 0.79 0.75]);
hold(ax, 'on');

markerSize = 8;   %pt（导出尺寸）→ 排版后约 4 pt
hPt = gobjects(2, 1);
for k = 1:2
	plot(ax, X{k}, MU{k}, '-', 'Color', groupColor(k, :), 'LineWidth', 1, 'Tag', 'connLine');
	iErrorBarCurve(ax, X{k}, MU{k}, SEM{k}, groupColor(k, :), figWmm);
	hPt(k) = plot(ax, X{k}, MU{k}, 'o', 'LineStyle', 'none', 'Tag', 'dataPt', ...
		'MarkerSize', markerSize, 'MarkerFaceColor', groupColor(k, :), 'MarkerEdgeColor', 'none');
end

ax.XLim = [0.4, maxBlock + 0.6];
ax.XTick = 1:maxBlock;
ax.YLim = [0, 1.05];
xlabel(ax, 'Block');
ylabel(ax, 'Hit rate');
ax.FontSize = 6;
ax.LineWidth = 0.5;
box(ax, 'off');
grid(ax, 'off');

if pGroup < 0.05
	upBoth = 0;
	for k = 1:2
		upBoth = max(upBoth, max(MU{k} + SEM{k}));
	end
	yPLine = upBoth + 0.08;
	plot(ax, [1, maxBlock], [yPLine, yPLine], 'k-', 'LineWidth', 1);
	text(ax, (1 + maxBlock) / 2, yPLine + 0.005, ...
		string(TransferLearning.Style.iFormatPStars(pGroup)), ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 6);
	ax.YLim = [0, max(1.10, yPLine + 0.11)];
end

lg = legend(ax, hPt, cellstr(cohorts), 'Location', 'southeast', 'NumColumns', 1);
lg.Box = 'off';

iExactPaper(f, figWmm / 10 * figScale, figHmm / 10 * figScale);
TransferLearning.ApplyStandardExportStyle(f, figScale);
set(findall(f, 'Type', 'line', '-regexp', 'Tag', '^errBar'), 'LineWidth', 0.5 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_FigS1J_AudioWater_NaiveVsTransfer_LearningCurve.svg');
print(f, svgPath, '-dsvg');
fprintf('\nWrote: %s\n', svgPath);

%% ---------- 图 2：first block / blocks to 50% 一列两张 ----------
barScale = 2;
barWcm = 3.0; barHcm = 4.0;   %30×40 mm：22 mm 下 "Naive"/"Transfer" 两个 x 标签会重叠
iAxesRectTopB = [0.44 0.605 0.52 0.335];
iAxesRectBotB = [0.44 0.145 0.52 0.335];

fb = figure('Color', 'w', 'Name', 'FigS1J AudioWater metric bars first block over blocks to 50');
fb.Units = 'centimeters';
fb.Position(3:4) = [barWcm barHcm] * barScale;
axT = axes(fb, 'Position', iAxesRectTopB);
axB = axes(fb, 'Position', iAxesRectBotB);
iBarPair(axT, V{1}{1}, V{1}{2}, groupColor, cohorts, Pm(1), metricYlab(1));
iBarPair(axB, V{2}{1}, V{2}{2}, groupColor, cohorts, Pm(2), metricYlab(2));
%两组名只在下面那张图出现，上面那张去掉 x 轴刻度标签
axT.XTickLabel = [];

iExactPaper(fb, barWcm * barScale, barHcm * barScale);
TransferLearning.ApplyStandardExportStyle(fb, barScale);
iContainAnnotations(fb);
iFixBarWidths(fb, barWcm * 10, 1 * barScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_FigS1J_AudioWater_MetricBars_FirstBlockAndBlocksTo50.svg');
print(fb, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS1J_AudioWaterSessions', allSessions);
assignin('base', 'FigS1J_AudioWaterMetrics', struct('V', {V}, 'P', Pm, 'PerMouse', perMouse, ...
	'PGroup', pGroup, 'PAll', pAll));

%% ================= 局部函数 =================
function sessions = iAudioSessions(DS, source, startPhase, endPhase, group, imagingCohort)
sessions = TransferLearning.DelayComparison.LightSessionTable(DS, "AudioWater", startPhase, endPhase);
sessions = sessions(isfinite(sessions.Performance) & sessions.NTrial > 0, :);
sessions.Source = repmat(source, height(sessions), 1);
sessions.Group = repmat(group, height(sessions), 1);
sessions.ImagingCohort = repmat(imagingCohort, height(sessions), 1);
end

function iErrorBarCurve(ax, x, y, e, col, figWmm)
%mean±SEM 对称误差棒（竖线 + 上下横帽）；一条折线画完保证三段线宽一致
drawnow;
apx = getpixelposition(ax);
fpx = getpixelposition(ancestor(ax, 'figure'));
xSpan = diff(ax.XLim);
axesWmm = apx(3) / fpx(3) * figWmm;
capHalf = 0.60 * xSpan / axesWmm;
for k = 1:numel(x)
	if ~(e(k) > 0)
		continue;
	end
	yLo = y(k) - e(k);
	yHi = y(k) + e(k);
	xs = [x(k) - capHalf, x(k) + capHalf, x(k), x(k), x(k) - capHalf, x(k) + capHalf];
	ys = [yHi, yHi, yHi, yLo, yLo, yLo];
	plot(ax, xs, ys, '-', 'Color', col, 'LineWidth', 1, 'Tag', 'errBar');
end
end

function iBarPair(ax, va, vb, cols, grpLabels, pVal, ylab)
hold(ax, 'on');
y = [mean(va), mean(vb)];
e = [iSEM(va), iSEM(vb)];
h = bar(ax, 1:2, y, 0.5, 'FaceColor', 'flat');
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
ylabel(ax, ylab);
yTop = max([y + e, eps]) * 1.30;
ax.YLim = [0, yTop];
iDrawErrorBars(ax, y, e, cols, 0.16);
EB = errorbar(ax, 1:2, y, [0 0], e, 'LineStyle', 'none', 'Color', 'none', 'CapSize', 0.01);
D = table(repmat(EB, 1, 1), repmat(EB, 1, 1), 1, 2, ...
	string(TransferLearning.Style.iFormatPStars(pVal)), ...
	'VariableNames', ["ObjectA", "ObjectB", "IndexA", "IndexB", "Text"]);
MATLAB.Graphics.PLine(D);
tx = findall(ax, 'Type', 'text');
if ~isempty(tx)
	set(tx, 'VerticalAlignment', 'bottom');
end
box(ax, 'off');
grid(ax, 'off');
end

function iContainAnnotations(f)
for ax = findall(f, 'Type', 'axes').'
	drawnow;
	tx = findall(ax, 'Type', 'text');
	top = -inf;
	for k = 1:numel(tx)
		e = tx(k).Extent;
		if numel(e) < 4 || any(isnan(e)), continue; end
		top = max(top, e(2) + e(4));
	end
	if isfinite(top) && top > ax.YLim(2)
		ax.YLim = [ax.YLim(1), top + 0.04 * (top - ax.YLim(1))];
	end
end
drawnow;
end

function iFixBarWidths(f, figWmm, lw)
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

function half = iBlocksToHalf(x, y)
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
