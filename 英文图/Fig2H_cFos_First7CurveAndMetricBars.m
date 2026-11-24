% English Fig2H（cFos 抑制 vs Control）补充面板
%   1) 前 7 个 block 的误差棒折线学习曲线（Control vs cFos）
%   2) Blocks to 50% 柱图（逐鼠一个值 + SEM + 秩和检验）
%   3) Sigmoid slope 柱图（逐 trial 惩罚 sigmoid，逐鼠一个值 + SEM + 秩和检验）
%
% 说明（为什么另起一个脚本）：
%   Fig2H_cFosInhibitVsControl_LearningCurve.m 画的是【全部 block】+ 阴影带；
%   这里按 Fig_ThreeCohorts_LearningCurve 的口径，改成【只展示 1–7 个 block】的
%   实心点 + 对称误差棒 + 连线（不画拟合、不加阴影带）。
%
% 配色（最新 Catppuccin）：
%   Control = #8C8C8C 中性灰；cFos = ColorcFos #B4BEFE
%   —— 柱用浅色；曲线用 ×0.65 压暗版（白底可读，同 Curve* 口径）
%
% 输出（SVG）：
%   English_Fig2H_cFos_LearningCurve_First7.svg
%   English_Fig2H_cFos_BlocksTo50_Bar.svg
%   English_Fig2H_cFos_SigmoidSlope_Bar.svg
%
% Execution (hard requirement): 保持为脚本（不要转成 function），在编辑器里 Run/F5。

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet', 'class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
		if exist(prjFile, 'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end

% --- 1) Load cFos database
matPath = "\\Data-Server-2\个人数据\张天夫\202611\cFos合集.v3.mat";
DS = UniExp.DataSet(matPath);

% --- 2) Build group table (Mouse -> Group)
S = DS.Mice;
if isempty(S)
	error('Fig2HcFos:EmptyMiceTable', 'DS.Mice is empty.');
end
if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
		error('Fig2HcFos:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
S.Mouse = string(S.Mouse);
needVars = ["ExpressedBrain", "MarkTimes"];
for k = 1:numel(needVars)
	if ~ismember(needVars(k), string(S.Properties.VariableNames))
		error('Fig2HcFos:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(k));
	end
end
S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";
try
	bad = arrayfun(@(g) nnz(char(g) == ' ') > 1, S.Group);
	S = S(~bad, :);
catch
end
S = S(ismember(S.Group, ["Control", "MOp"]), :);
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);
if isempty(S)
	error('Fig2HcFos:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end

% --- 3) Query LightWater behavior blocks -> session level
B = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false);
if isempty(B)
	error('Fig2HcFos:EmptyBehavior', 'No LightWater behavior rows found.');
end
B.Mouse = string(B.Mouse);
B.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(B.DateTime);
J = innerjoin(B, S(:, {'Mouse', 'Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);
vars = intersect(J.Properties.VariableNames, {'Mouse', 'DateTime', 'Performance', 'Group', 'Phase'}, 'stable');
Sess = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group', 'Mouse', 'DateTime'});
Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);

grpOrder = ["Control", "MOp"];      % 数据里的组名
grpLabel = ["Control", "cFos"];     % 图上的组名
nG = numel(grpOrder);
maxBlock = 7;                       % 只展示前 7 个 block

% --- 4) 配色
barColor = [[140, 140, 140] / 255; TransferLearning.ColorcFos / 255];   % 柱：浅色
lineColor = [[140, 140, 140] / 255; round(TransferLearning.ColorcFos * 0.65) / 255]; % 曲线：压暗版

% --- 5) 逐鼠逐 session 命中率 -> 组均值 ± SEM（只用前 7 个 block）
X = cell(1, nG); MU = cell(1, nG); SEM = cell(1, nG);
for g = 1:nG
	Sg = Sess(Sess.Group == grpOrder(g), :);
	mice = unique(string(Sg.Mouse), 'stable');
	M = nan(numel(mice), maxBlock);
	for i = 1:numel(mice)
		r = Sg(string(Sg.Mouse) == mice(i), :);
		[~, ord] = sort(double(r.Session));
		y = double(r.Performance(ord));
		n = min(numel(y), maxBlock);
		M(i, 1:n) = y(1:n).';
	end
	X{g} = 1:maxBlock;
	MU{g} = mean(M, 1, 'omitnan');
	SEM{g} = std(M, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(M), 1));
	SEM{g}(~isfinite(SEM{g})) = 0;
	fprintf('%s（%s）：n=%d 只鼠；前 %d block 均值 %s\n', ...
		grpLabel(g), grpOrder(g), numel(mice), maxBlock, mat2str(round(MU{g}, 3)));
end

% --- 6) 组效应（前 7 个 block 的 two-way ANOVA）
Sess7 = Sess(Sess.Session <= maxBlock, :);
pGroup = TransferLearning.Style.TwoWayAnovaGroupPValue(Sess7, 'Performance', 'Session', 'Group', 'Mouse');
fprintf('组效应 two-way ANOVA（block 1-%d）p = %.4g\n', maxBlock, pGroup);

%% ================= 图 1：误差棒折线学习曲线（前 7 个 block）=================
figScale = 2;          %导出倍率：90×80 mm、12 pt → 排版缩 1/2 得 45×40 mm、6 pt
figWmm = 45;
figHmm = 40;
f = figure('Color', 'w', 'Name', 'Fig2H cFos learning curve (blocks 1-7)');
f.Units = 'centimeters';
f.Position(3:4) = [figWmm, figHmm] / 10 * figScale;
ax = axes(f, 'Position', [0.18 0.19 0.79 0.75]);
hold(ax, 'on');

%点大小：样式会把所有 LineWidth 设为 1 pt（导出体系下 2 pt），marker 描边也走 LineWidth，
%所以点要开得比线宽大一截才不会被描边吃掉
markerSize = 8;   %pt（导出尺寸）→ 排版后约 4 pt、直径 ≈1.4 mm
hPt = gobjects(nG, 1);
for g = 1:nG
	%绘制顺序：连接线在最下、误差棒居中、实心点在最上
	plot(ax, X{g}, MU{g}, '-', 'Color', lineColor(g, :), 'LineWidth', 1, 'Tag', 'connLine');
	iErrorBar(ax, X{g}, MU{g}, SEM{g}, lineColor(g, :), figWmm);
	hPt(g) = plot(ax, X{g}, MU{g}, 'o', 'LineStyle', 'none', 'Tag', 'dataPt', ...
		'MarkerSize', markerSize, 'MarkerFaceColor', lineColor(g, :), 'MarkerEdgeColor', 'none');
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

%显著性：一条横线跨越要对比的 block 区间，星号居中放在横线上方（原 Fig2H 标法）
if pGroup < 0.05
	upBoth = 0;
	for g = 1:nG
		upBoth = max(upBoth, max(MU{g} + SEM{g}));
	end
	yPLine = upBoth + 0.05;
	plot(ax, [1, maxBlock], [yPLine, yPLine], 'k-', 'LineWidth', 1);
	text(ax, (1 + maxBlock) / 2, yPLine + 0.005, ...
		string(TransferLearning.Style.iFormatPStars(pGroup)), ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 6);
	ax.YLim = [0, max(1.05, yPLine + 0.12)];
end

lg = legend(ax, hPt, cellstr(grpLabel), 'Location', 'southeast', 'NumColumns', 1);
lg.Box = 'off';

iExactPaper(f, figWmm / 10 * figScale, figHmm / 10 * figScale);
%先上标准样式（所有线宽统一成 1 pt），再单独把误差棒调细到 0.5 pt
TransferLearning.ApplyStandardExportStyle(f, figScale);
set(findall(f, 'Type', 'line', '-regexp', 'Tag', '^errBar'), 'LineWidth', 0.5 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig2H_cFos_LearningCurve_First7.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ================= 图 2/3：Blocks to 50% 与 slope 柱图 =================
% 逐鼠指标
PerMouse = TransferLearning.Metrics.PerMouseSessionSummary(Sess);   % FirstPerf | BlocksToHalf
SlopeT = iTrialLevelSlope(DS, Sess);                                % Slope | AtSlopeBoundary

vHalf = cell(1, nG);
vSlope = cell(1, nG);
for g = 1:nG
	vHalf{g} = double(PerMouse.BlocksToHalf(PerMouse.Group == grpOrder(g)));
	vHalf{g} = vHalf{g}(isfinite(vHalf{g}));
	vSlope{g} = double(SlopeT.Slope(SlopeT.Group == grpOrder(g)));
	vSlope{g} = vSlope{g}(isfinite(vSlope{g}));
end

pHalf = iRanksum(vHalf{1}, vHalf{2});
pSlope = iRanksum(vSlope{1}, vSlope{2});
fprintf('Blocks to 50%%：Control %.2f±%.2f (n=%d) | cFos %.2f±%.2f (n=%d) | p=%.4g\n', ...
	mean(vHalf{1}), iSEM(vHalf{1}), numel(vHalf{1}), mean(vHalf{2}), iSEM(vHalf{2}), numel(vHalf{2}), pHalf);
fprintf('Slope        ：Control %.3f±%.3f (n=%d) | cFos %.3f±%.3f (n=%d) | p=%.4g\n', ...
	mean(vSlope{1}), iSEM(vSlope{1}), numel(vSlope{1}), mean(vSlope{2}), iSEM(vSlope{2}), numel(vSlope{2}), pSlope);

iMetricBar(vHalf, barColor, 'Blocks to 50%', pHalf, ...
	'English_Fig2H_cFos_BlocksTo50_Bar.svg');
iMetricBar(vSlope, barColor, 'Sigmoid slope', pSlope, ...
	'English_Fig2H_cFos_SigmoidSlope_Bar.svg');

assignin('base', 'Fig2H_cFos_Sessions', Sess);
assignin('base', 'Fig2H_cFos_PerMouse', PerMouse);
assignin('base', 'Fig2H_cFos_Slope', SlopeT);
assignin('base', 'Fig2H_cFos_P', struct('Group', pGroup, 'BlocksTo50', pHalf, 'Slope', pSlope));

%% ================= 局部函数 =================
function iErrorBar(ax, x, y, e, col, figWmm)
%mean±SEM 对称误差棒（竖线 + 上下两个横帽）。
%不用 errorbar 的原因：CapSize 以点为单位、不随字号/画布缩放，导出 12 pt 时会过短
drawnow;
apx = getpixelposition(ax);
fpx = getpixelposition(ancestor(ax, 'figure'));
xSpan = diff(ax.XLim);
axesWmm = apx(3) / fpx(3) * figWmm;
capHalf = 0.60 * xSpan / axesWmm;   %横帽半宽（mm）→ 总宽 ≈ 1.2 mm
for k = 1:numel(x)
	if ~(e(k) > 0)
		continue;   %SEM=0 时横帽会正好压在点上，像一条粗线，干脆不画
	end
	yLo = y(k) - e(k);
	yHi = y(k) + e(k);
	%一条折线画完「上横—竖线—下横」：保证三段线宽完全一致
	xs = [x(k) - capHalf, x(k) + capHalf, x(k), x(k), x(k) - capHalf, x(k) + capHalf];
	ys = [yHi, yHi, yHi, yLo, yLo, yLo];
	plot(ax, xs, ys, '-', 'Color', col, 'LineWidth', 1, 'Tag', 'errBar');
end
end

function iMetricBar(vals, barColor, ylab, pVal, outName)
%两柱对比图：22×40 mm、6 pt、柱宽 3 mm、单向误差棒 + 星号（同 Fig1 柱图口径）
barScale = 2;
barWcm = 2.2;
barHcm = 4.0;
fb = figure('Color', 'w', 'Name', outName);
fb.Units = 'centimeters';
fb.Position(3:4) = [barWcm barHcm] * barScale;
axb = axes(fb, 'Position', [0.44 0.13 0.52 0.82]);
iBarPair(axb, vals{1}, vals{2}, barColor, ["Ctrl", "cFos"], pVal, ylab);
iExactPaper(fb, barWcm * barScale, barHcm * barScale);
TransferLearning.ApplyStandardExportStyle(fb, barScale);
iFixBarWidths(fb, barWcm * 10, 1 * barScale);
svgBar = TransferLearning.StandardFigureSvgPath(outName);
print(fb, svgBar, '-dsvg');
fprintf('Wrote: %s\n', svgBar);
end

function iBarPair(ax, va, vb, cols, grpLabels, pVal, ylab)
hold(ax, 'on');
y = [mean(va), mean(vb)];
e = [iSEM(va), iSEM(vb)];
h = bar(ax, 1:2, y, 0.5, 'FaceColor', 'flat');   %宽度先给占位值，最后由 iFixBarWidths 统一校正
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
yTop = max([y + e, eps]) * 1.20;   %只给 PLine 留 20% 余量，避免上半幅全空
if yTop <= 0
	yTop = 1;
end
ax.YLim = [0, yTop];
%DONE 误差棒先按占位宽度画，打印前由 iFixBarWidths 重绘
iDrawErrorBars(ax, y, e, cols, 0.16);
%用一个不可见的两点 errorbar 作为定位对象，PLine 按误差条顶端放线
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
end

function iFixBarWidths(f, figWmm, lw)
%柱宽/横帽按【物理 mm】固定，而不是数据单位（同 Fig1 柱图口径）
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

function T = iTrialLevelSlope(DS, Sess)
%逐 trial 惩罚 sigmoid（会话序号作 block），与 Fig1C / Metrics.TrialLevelSlopePerMouse 同口径
T = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'NTrials', 'Slope', 'AtSlopeBoundary'});
mice = unique(string(Sess.Mouse), 'stable');
for m = mice.'
	Sm = Sess(string(Sess.Mouse) == m, :);
	dt = datetime(Sm.DateTime);
	if ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
	blk = double(Sm.Session);
	Tq = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], ...
		Mouse = m, Stimulus = "LightWater");
	if isempty(Tq)
		continue;
	end
	tDT = datetime(Tq.DateTime);
	if ~isempty(tDT.TimeZone)
		tDT.TimeZone = '';
	end
	y = double(Tq.Behavior);
	[~, loc] = ismember(tDT, dt);
	ok = isfinite(y) & loc > 0;
	if nnz(ok) < 2 || numel(unique(blk(loc(ok)))) < 2
		continue;
	end
	x = blk(loc(ok));
	fit = TransferLearning.FitPenalizedSigmoid(x, y(ok), FixLowerZero = true);
	T = [T; table(string(Sm.Group(1)), m, nnz(ok), fit.Slope, fit.AtSlopeBoundary, ...
		'VariableNames', {'Group', 'Mouse', 'NTrials', 'Slope', 'AtSlopeBoundary'})]; %#ok<AGROW>
	fprintf('  斜率 %-10s %-3s trials=%4d k=%.3f%s\n', m, string(Sm.Group(1)), nnz(ok), ...
		fit.Slope, repmat(' ★触上界', 1, fit.AtSlopeBoundary));
end
end

function iExactPaper(f, wCm, hCm)
%固定画布尺寸：PaperPositionMode='auto' 会在小图上额外加边距
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end

function p = iRanksum(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
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
