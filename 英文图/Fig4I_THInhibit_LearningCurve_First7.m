% English Fig4I: TH 抑制组 vs 12 h 对照组 —— 光水学习曲线（只展示前 7 个 block）
%
% 版式照 英文图/Fig_ThreeCohorts_LearningCurve.m / Fig2H_cFos_First7CurveAndMetricBars.m：
%   逐鼠逐 block 命中率 → 组均值 ± SEM，实心点 + 手绘对称误差棒 + 连线（不画拟合、不加阴影带），
%   只展示 1–7 个 block；显著性用一条横线跨越 1–7，星号居中放在横线上方。
%
% 数据口径与英文图/Fig4G_THInhibit_MetricBars.m / Fig4E 完全一致：
%   12 h = BuildIntervalBehaviorCurves() 里 Group=="12h"（全部 12-h 行为队列，含纯行为鼠）
%   TH   = BuildTHInhibitTrialTable()（成像鼠）+ BuildPOBehaviorTrialTable()（纯行为鼠）
%   统计 = TransferLearning.Style.TwoWayAnovaGroupPValue（LMM: Response ~ Block + Group + (1|Mouse)），
%          只用 block 1–7
%
% 配色（最新 Catppuccin 曲线口径）：12 h = Curve12h（Color12h ×0.65），TH = CurveTH（ColorTH ×0.65）
%
% 输出（SVG）：English_Fig4I_THInhibit_LearningCurve_First7.svg（90×80 mm → 排版 45×40 mm、6 pt）

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

gName = ["12h", "THInhibit"];      % 数据里的组名
gLabel = ["12 h", "TH"];           % 图上的组名
maxBlock = 7;

% 逐鼠逐 block 命中率（每个 block 内所有 trial 的命中比例）
PerMouseBlock = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'Block', 'Performance'});
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
		bi = bi(bi <= maxBlock);
		for b = bi(:).'
			PerMouseBlock = [PerMouseBlock; table(gName(iG), mice(iM), b, ...
				mean(beh(blk == b), 'omitnan'), ...
				'VariableNames', {'Group', 'Mouse', 'Block', 'Performance'})]; %#ok<AGROW>
		end
	end
end

%% ---------- 组均值 ± SEM ----------
X = cell(1, 2); MU = cell(1, 2); SEM = cell(1, 2); N = zeros(1, 2);
for g = 1:2
	Sg = PerMouseBlock(PerMouseBlock.Group == gName(g), :);
	ms = unique(Sg.Mouse, 'stable');
	M = nan(numel(ms), maxBlock);
	for i = 1:numel(ms)
		r = Sg(Sg.Mouse == ms(i), :);
		M(i, double(r.Block).') = double(r.Performance).';
	end
	X{g} = 1:maxBlock;
	MU{g} = mean(M, 1, 'omitnan');
	SEM{g} = std(M, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(M), 1));
	SEM{g}(~isfinite(SEM{g})) = 0;
	N(g) = numel(ms);
	fprintf('%s（%s）：n=%d 只鼠；前 %d block 均值 %s\n', gLabel(g), gName(g), N(g), maxBlock, mat2str(round(MU{g}, 3)));
end

%% ---------- 统计（只用 block 1–7）----------
pGroup = TransferLearning.Style.TwoWayAnovaGroupPValue(PerMouseBlock, 'Performance', 'Block', 'Group', 'Mouse');
fprintf('组效应（LMM: Performance ~ Block + Group + (1|Mouse)，block 1-%d）p = %.4g\n', maxBlock, pGroup);

%% ---------- 画图 ----------
figScale = 2;          %导出倍率：90×80 mm、12 pt → 排版缩 1/2 得 45×40 mm、6 pt
figWmm = 45;
figHmm = 40;
f = figure('Color', 'w', 'Name', 'Fig4I TH learning curve (blocks 1-7)');
f.Units = 'centimeters';
f.Position(3:4) = [figWmm, figHmm] / 10 * figScale;
ax = axes(f, 'Position', [0.18 0.19 0.79 0.75]);
hold(ax, 'on');

lineColor = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;   % 直接用调色板原色：#FAB387 / #CBA6F7

%点大小：样式会把所有 LineWidth 设为 1 pt（导出体系下 2 pt），marker 描边也走 LineWidth，
%所以点要开得比线宽大一截才不会被描边吃掉
markerSize = 8;   %pt（导出尺寸）→ 排版后约 4 pt、直径 ≈1.4 mm
hPt = gobjects(2, 1);
for g = 1:2
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

%显著性：一条横线跨越 1–7，星号居中放在横线上方
if pGroup < 0.05
	upBoth = 0;
	for g = 1:2
		upBoth = max(upBoth, max(MU{g} + SEM{g}));
	end
	yPLine = upBoth + 0.08;   %对照组末段已到 1.0，留大一点免得起横线压住点
	plot(ax, [1, maxBlock], [yPLine, yPLine], 'k-', 'LineWidth', 1);
	text(ax, (1 + maxBlock) / 2, yPLine + 0.005, ...
		string(TransferLearning.Style.iFormatPStars(pGroup)), ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 6);
	ax.YLim = [0, max(1.10, yPLine + 0.11)];
end

lg = legend(ax, hPt, cellstr(gLabel), 'Location', 'southeast', 'NumColumns', 1);
lg.Box = 'off';

iExactPaper(f, figWmm / 10 * figScale, figHmm / 10 * figScale);
%先上标准样式（线宽统一成 1 pt），再单独把误差棒调细到 0.5 pt
TransferLearning.ApplyStandardExportStyle(f, figScale);
set(findall(f, 'Type', 'line', '-regexp', 'Tag', '^errBar'), 'LineWidth', 0.5 * figScale);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig4I_THInhibit_LearningCurve_First7.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig4I_TH_Curve', struct('MU', {MU}, 'SEM', {SEM}, 'N', N, ...
	'PGroup', pGroup, 'PerMouseBlock', PerMouseBlock));

%% ================= 局部函数 =================
function iErrorBar(ax, x, y, e, col, figWmm)
%mean±SEM 对称误差棒（竖线 + 上下两个横帽）。
%不用 errorbar：CapSize 以点为单位、不随字号/画布缩放，导出 12 pt 时会过短
drawnow;
apx = getpixelposition(ax);
fpx = getpixelposition(ancestor(ax, 'figure'));
xSpan = diff(ax.XLim);
axesWmm = apx(3) / fpx(3) * figWmm;
capHalf = 0.60 * xSpan / axesWmm;   %横帽半宽（mm）→ 总宽 ≈1.2 mm
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

function iExactPaper(f, wCm, hCm)
%固定画布尺寸：PaperPositionMode='auto' 会在小图上额外加边距
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end
