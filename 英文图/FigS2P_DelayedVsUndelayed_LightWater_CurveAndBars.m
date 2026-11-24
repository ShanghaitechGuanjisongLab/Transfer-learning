% English FigS2P：延迟 vs 无延迟（dela(2)y / undelayed）—— 光水学习曲线 + 三指标柱图
%
% 分组（TransferLearning.DelayComparison.CohortBlocks，与 FigS2L/FigS2M/FigS2LM 完全同源）：
%   Undelayed = "UndelayedImagingTransfer"（AudioLightBaseline + ALPureBehavior，声→光即时迁移）
%   Delayed   = "DelayedBehaviorTransfer" （A2L_L_0928，声→光延迟迁移）
%
% 版式：
%   曲线 45×40 mm：逐 block 均值 ± SEM，**Undelayed 实线 / Delayed 虚线**，
%                  实心点 + 手绘对称误差棒，只展示 1–7，横线 + 星号（不显著标 n.s.）
%   柱图 30×40 mm ×3：first block / blocks to 50% / sigmoid slope，
%                  **Undelayed 实心柱 / Delayed 虚线描边柱**（同一基色，深浅区分）
%
% 统计：LMM `Performance ~ Block + Group + (1|Mouse)`（block 1–7）；柱图用非配对 ranksum；
%       不显著一律标 n.s.（TransferLearning.Style.iFormatPStars）
%
% 配色：两组同基色 Color12h #FAB387（延迟/无延迟只靠虚实区分，不靠色相）
%
% 输出（SVG）：
%   English_FigS2P_DelayedVsUndelayed_LightWaterLearningCurve.svg
%   English_FigS2P_DelayedVsUndelayed_MetricBars_FirstBlock.svg
%   English_FigS2P_DelayedVsUndelayed_MetricBars_BlocksTo50.svg
%   English_FigS2P_DelayedVsUndelayed_MetricBars_SigmoidSlope.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ---------- 会话表 ----------
% A 方案（纯行为 vs 纯行为）：
%   Undelayed = ALPureBehavior（声→光即时迁移，仅纯行为鼠，LightWater，Phase Transfer→Final）
%   Delayed   = A2L_L_0928（声→光延迟迁移，纯行为）
% 注：不把 AudioLightBaseline（成像队列）混进来，否则就变成"成像+纯行为" vs "纯行为" 的混合比较。
Tu = TransferLearning.DelayComparison.LightSessionTable(TransferLearning.ALPureBehavior(), ...
	"LightWater", "Transfer", "Final");
Tu = Tu(isfinite(Tu.Performance) & Tu.NTrial > 0, :);
Tu.Source = repmat("ALPureBehavior", height(Tu), 1);
Tu = Tu(:, {'Mouse', 'DateTime', 'Performance', 'Source'});   %与 CohortBlocks 的列对齐
Td = TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer");
Tu.Group = repmat("Undelayed", height(Tu), 1);
Td.Group = repmat("Delayed", height(Td), 1);
Tu = TransferLearning.DelayComparison.AddBlockIndex(Tu);
Td = TransferLearning.DelayComparison.AddBlockIndex(Td);
allSessions = [Tu; Td];
cohorts = ["Undelayed", "Delayed"];
maxBlock = 6;   %两组共同覆盖的 block 数：A2L_L 每鼠恰好 6 个，ALPB 多数也只有 6 个

%试次级数据（用于逐 trial 惩罚 sigmoid）：无延迟 = ALPB；延迟 = A2L_L_0928
DSu = {TransferLearning.ALPureBehavior()};
DSd = {UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L"))};
for k = 1:2
	use = allSessions.Group == cohorts(k);
	fprintf('%s：%d 只鼠，%d 个会话\n', cohorts(k), numel(unique(allSessions.Mouse(use))), nnz(use));
end

% 配色：同基色，靠虚实区分
baseRGB = TransferLearning.Color12h;              %#FAB387
lineColor = baseRGB / 255;
barFill = [baseRGB / 255; round(baseRGB * 0.35 + 255 * 0.65) / 255];   % 实心 / 浅填充+虚线框
lineStyles = {'-', '--'};

%% ---------- 学习曲线（前 7 block）----------
MU = cell(1, 2); SEM = cell(1, 2); X = cell(1, 2);
for k = 1:2
	use = allSessions.Group == cohorts(k) & allSessions.Block <= maxBlock;
	Sg = allSessions(use, :);
	mu = nan(1, maxBlock); se = nan(1, maxBlock);
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
	fprintf('  %-10s 前 %d block 均值 %s\n', cohorts(k), maxBlock, mat2str(round(mu, 3)));
end

sessions7 = allSessions(allSessions.Block <= maxBlock, :);
pGroup = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Block', 'Group', 'Mouse');
pAll = TransferLearning.Style.TwoWayAnovaGroupPValue(allSessions, 'Performance', 'Block', 'Group', 'Mouse');
fprintf('LMM Group p：block 1-%d = %.4g；全部 block = %.4g\n', maxBlock, pGroup, pAll);

%% ---------- 三指标（逐鼠）----------
perMouse = table(strings(0, 1), strings(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'});
for k = 1:2
	Sg = allSessions(allSessions.Group == cohorts(k), :);
	ms = unique(Sg.Mouse, 'stable');
	for i = 1:numel(ms)
		r = sortrows(Sg(Sg.Mouse == ms(i), :), 'Block');
		y = double(r.Performance);
		b = double(r.Block);
		perMouse = [perMouse; table(cohorts(k), ms(i), y(1), iBlocksToHalf(b, y), ...
			'VariableNames', {'Group', 'Mouse', 'FirstPerf', 'BlocksToHalf'})]; %#ok<AGROW>
	end
end

% slope：两组统一用逐 trial 惩罚 sigmoid（下 0 上 1，Jeffreys + log-k 惩罚），
% 与正文 / Fig1C / Fig4G 完全同一算法
slopeTbl = iTrialLevelSlope(allSessions, DSu, DSd);
slope = table(slopeTbl.Group, slopeTbl.Mouse, slopeTbl.Slope, ...
	'VariableNames', {'Group', 'Mouse', 'Slope'});
for k = 1:2
	s = slopeTbl.Slope(slopeTbl.Group == cohorts(k));
	fprintf('  %-10s slope n=%d（共 %d 只鼠，其中 %d 只不足 2 个 block）\n', cohorts(k), ...
		numel(s), numel(unique(allSessions.Mouse(allSessions.Group == cohorts(k)))), ...
		numel(unique(allSessions.Mouse(allSessions.Group == cohorts(k)))) - numel(s));
end

V = cell(1, 3);
V{1} = {perMouse.FirstPerf(perMouse.Group == cohorts(1)), perMouse.FirstPerf(perMouse.Group == cohorts(2))};
V{2} = {perMouse.BlocksToHalf(perMouse.Group == cohorts(1)), perMouse.BlocksToHalf(perMouse.Group == cohorts(2))};
V{3} = {slope.Slope(slope.Group == cohorts(1)), slope.Slope(slope.Group == cohorts(2))};

metricTag = ["FirstBlock", "BlocksTo50", "SigmoidSlope"];
metricYlab = ["Hit rate", "Blocks to 50%", "Sigmoid slope"];
Pm = nan(1, 3);
fprintf('\n=== 三指标（Undelayed vs Delayed）===\n');
for m = 1:3
	a = V{m}{1}; b = V{m}{2};
	a = a(isfinite(a)); b = b(isfinite(b));
	Pm(m) = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
	fprintf('%-14s Undelayed %.3f ± %.3f (n=%d) | Delayed %.3f ± %.3f (n=%d) | ranksum p = %.4g %s\n', ...
		metricTag(m), mean(a), iSEM(a), numel(a), mean(b), iSEM(b), numel(b), Pm(m), ...
		string(TransferLearning.Style.iFormatPStars(Pm(m))));
end

%% ---------- 图 1：学习曲线 ----------
figScale = 2;
figWmm = 45; figHmm = 40;
f = figure('Color', 'w', 'Name', 'FigS2P delayed vs undelayed light-water learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [figWmm, figHmm] / 10 * figScale;
ax = axes(f, 'Position', [0.18 0.19 0.79 0.75]);
hold(ax, 'on');

markerSize = 8;
hPt = gobjects(2, 1);
hl = gobjects(2, 1);
for k = 1:2
	hl(k) = plot(ax, X{k}, MU{k}, lineStyles{k}, 'Color', lineColor, 'LineWidth', 1, 'Tag', 'connLine');
	iErrorBarCurve(ax, X{k}, MU{k}, SEM{k}, lineColor, figWmm);
	hPt(k) = plot(ax, X{k}, MU{k}, 'o', 'LineStyle', 'none', 'Tag', 'dataPt', ...
		'MarkerSize', markerSize, 'MarkerFaceColor', lineColor, 'MarkerEdgeColor', 'none');
end
%图例用连线句柄（并补上 marker），这样 legend 里能看出实线 / 虚线
for k = 1:2
	hl(k).Marker = 'o';
	hl(k).MarkerSize = markerSize;
	hl(k).MarkerFaceColor = lineColor;
	hl(k).MarkerEdgeColor = 'none';
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

%显著性：横线跨越 1–7，星号/ n.s. 居中放在横线上方
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

lg = legend(ax, hl, cellstr(cohorts), 'Location', 'southeast', 'NumColumns', 1);
lg.Box = 'off';

iExactPaper(f, figWmm / 10 * figScale, figHmm / 10 * figScale);
TransferLearning.ApplyStandardExportStyle(f, figScale);
set(findall(f, 'Type', 'line', '-regexp', 'Tag', '^errBar'), 'LineWidth', 0.5 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_FigS2P_DelayedVsUndelayed_LightWaterLearningCurve.svg');
print(f, svgPath, '-dsvg');
fprintf('\nWrote: %s\n', svgPath);

%% ---------- 图 2：First block 作为 inset（透明背景，22×22 mm，贴进曲线图左上/右上角）----------
%规范同 Fig2B / Fig3B / Fig3D：单独输出一张小透明图，内嵌由人工排版完成
insetScale = 2;
insetWcm = 2.2; insetHcm = 2.2;
fIn = figure('Color', 'none', 'Name', 'FigS2P first block inset');
fIn.Units = 'centimeters';
fIn.Position(3:4) = [insetWcm insetHcm] * insetScale;
axIn = axes(fIn, 'Position', [0.44 0.20 0.52 0.72]);
iBarPair(axIn, V{1}{1}, V{1}{2}, barFill, lineColor, ["", ""], Pm(1), 'Hit rate');
axIn.XTickLabel = {};   %色/虚实已由图例说明（实线=Undelayed，虚线=Delayed），inset 不重复标组名
iExactPaper(fIn, insetWcm * insetScale, insetHcm * insetScale);
TransferLearning.ApplyStandardExportStyle(fIn, insetScale);
iContainAnnotations(fIn);
iFixBarWidths(fIn, insetWcm * 10, 1 * insetScale);
fIn.Color = 'none';
for a = findall(fIn, 'Type', 'axes').'
	a.Color = 'none';
end
svgPath = TransferLearning.StandardFigureSvgPath('English_FigS2P_DelayedVsUndelayed_FirstBlock_Inset.svg');
exportgraphics(fIn, svgPath, 'ContentType', 'vector', 'BackgroundColor', 'none');
fprintf('\nWrote: %s\n', svgPath);

%% ---------- 图 3：Blocks to 50% + Sigmoid slope 一列两张 ----------
barScale = 2;
barWcm = 2.4; barHcm = 4.2;   %24×42 mm：对齐 Fig1 主图 bar 的观感（3 mm 柱 / 10 mm 量级的绘图区宽度）
iRectTop = [0.44 0.600 0.52 0.325];
iRectBot = [0.44 0.140 0.52 0.325];
barLabel = ["Undel.", "Delay"];   %24 mm 宽只能放短标签
fb = figure('Color', 'w', 'Name', 'FigS2P metric bars blocks-to-50 over slope');
fb.Units = 'centimeters';
fb.Position(3:4) = [barWcm barHcm] * barScale;
axT = axes(fb, 'Position', iRectTop);
axB = axes(fb, 'Position', iRectBot);
iBarPair(axT, V{2}{1}, V{2}{2}, barFill, lineColor, barLabel, Pm(2), metricYlab(2));
iBarPair(axB, V{3}{1}, V{3}{2}, barFill, lineColor, barLabel, Pm(3), metricYlab(3));
axT.XTickLabel = [];   %组名只在下面那张出现
iExactPaper(fb, barWcm * barScale, barHcm * barScale);
TransferLearning.ApplyStandardExportStyle(fb, barScale);
iContainAnnotations(fb);
iFixBarWidths(fb, barWcm * 10, 1 * barScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_FigS2P_DelayedVsUndelayed_MetricBars_BlocksTo50AndSlope.svg');
print(fb, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS2P_DelayData', struct('Sessions', allSessions, 'V', {V}, 'P', Pm, ...
	'PerMouse', perMouse, 'Slope', slope, 'PGroup', pGroup, 'PAll', pAll));

%% ================= 局部函数 =================
function T = iTrialLevelSlope(allSessions, dsUndelayed, dsDelayed)
%逐 trial 惩罚 sigmoid：每只鼠的 0/1 结果作二项似然，block 序号作自变量
T = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'NTrials', 'Slope', 'AtSlopeBoundary'});
cohortsU = unique(string(allSessions.Group), 'stable');
for ic = 1:numel(cohortsU)
	g = cohortsU(ic);
	if g == "Undelayed"
		dsList = dsUndelayed;
		stims = "LightWater";
	else
		dsList = dsDelayed;
		stims = ["LightLearnWater", "LightLearnWaterAlways"];
	end
	Sg = allSessions(allSessions.Group == g, :);
	ms = unique(string(Sg.Mouse), 'stable');
	for im = 1:numel(ms)
		m = ms(im);
		S = Sg(Sg.Mouse == m, :);
		dt = datetime(S.DateTime);
		if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
		blk = double(S.Block);
		best = [];
		bestN = 0;
		for j = 1:numel(dsList)
			Tq = iQueryTrials(dsList{j}, m, stims);
			if isempty(Tq), continue; end
			tDT = datetime(Tq.DateTime);
			if ~isempty(tDT.TimeZone), tDT.TimeZone = ''; end
			y = double(Tq.Behavior);
			[~, loc] = ismember(tDT, dt);
			ok = isfinite(y) & loc > 0;
			if nnz(ok) > bestN
				bestN = nnz(ok);
				best = struct('x', blk(loc(ok)), 'y', y(ok));
			end
		end
		if isempty(best) || bestN < 2 || numel(unique(best.x)) < 2
			continue;
		end
		fit = TransferLearning.FitPenalizedSigmoid(best.x, best.y, FixLowerZero = true);
		T = [T; table(g, m, bestN, fit.Slope, fit.AtSlopeBoundary, ...
			'VariableNames', {'Group', 'Mouse', 'NTrials', 'Slope', 'AtSlopeBoundary'})]; %#ok<AGROW>
	end
end
end

function Tq = iQueryTrials(DS, mouseName, stims)
Tq = table();
for s = stims
	t = table();
	try
		t = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], ...
			Mouse = mouseName, Stimulus = s);
	catch
		try
			t = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Performance"], ...
				Mouse = mouseName, Stimulus = s);
			if ~isempty(t)
				t.Behavior = t.Performance;
			end
		catch
			t = table();
		end
	end
	if ~isempty(t)
		Tq = [Tq; t]; %#ok<AGROW>
	end
end
end

function iBarPair(ax, va, vb, fills, edgeCol, grpLabels, pVal, ylab)
%Undelayed = 实心柱（无描边）；Delayed = 浅填充 + 虚线描边
hold(ax, 'on');
y = [mean(va), mean(vb)];
e = [iSEM(va), iSEM(vb)];
h1 = bar(ax, 1, y(1), 0.5, 'FaceColor', fills(1, :), 'EdgeColor', 'none', 'LineWidth', 0.5);
h2 = bar(ax, 2, y(2), 0.5, 'FaceColor', fills(2, :), 'EdgeColor', edgeCol, 'LineWidth', 1);
try
	h2.LineStyle = '--';   %延迟组：虚线描边，对应曲线的虚线
catch
end
setappdata(ax, 'BarPairData', struct('y', y, 'e', e, 'cols', [edgeCol; edgeCol]));
ax.XTick = 1:2;
ax.XTickLabel = cellstr(grpLabels);
ax.XTickLabelRotation = 0;
ax.FontSize = 6;
ax.LineWidth = 0.5;
xlim(ax, [0.5 2.5]);
ylabel(ax, ylab);
yTop = max([y + e, eps]) * 1.16;   %只给 PLine 留必要余量，避免上方大片空白
ax.YLim = [0, yTop];
iDrawErrorBars(ax, y, e, [edgeCol; edgeCol], 0.16);
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

function iErrorBarCurve(ax, x, y, e, col, figWmm)
drawnow;
apx = getpixelposition(ax);
fpx = getpixelposition(ancestor(ax, 'figure'));
xSpan = diff(ax.XLim);
axesWmm = apx(3) / fpx(3) * figWmm;
capHalf = 0.60 * xSpan / axesWmm;
for k = 1:numel(x)
	if ~(e(k) > 0), continue; end
	yLo = y(k) - e(k);
	yHi = y(k) + e(k);
	xs = [x(k) - capHalf, x(k) + capHalf, x(k), x(k), x(k) - capHalf, x(k) + capHalf];
	ys = [yHi, yHi, yHi, yLo, yLo, yLo];
	plot(ax, xs, ys, '-', 'Color', col, 'LineWidth', 1, 'Tag', 'errBar');
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
x = x(use); y = y(use);
if isempty(y)
	half = NaN; return;
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
