% FigS2N（英文图）：有延迟数据的散度/反应异质性与学习斜率，对照无延迟原图（Fig1G/Fig1H）。
%
% 左列 = 原数据（Undelayed）：naive = LightAudioBaseline + LAInterspersed（Naive 期混入
% AudioWater 的鼠整只剔除），transfer = AudioLightBaseline；口径同
% 英文图/Fig1G_DivergenceVsSlope_Scatter.m 与 英文图/Fig1H_SlopeVsHeterogeneity.m。
% 右列 = 延迟数据（Delayed）：TransferLearning.ALDelayed 的光水学习（迁移阶段）。LADelayed
% （延迟 naive）每鼠只有 1 个 session，无法拟合 sigmoid slope，故不进入右列。
% 两组合并后的版本见 英文图/FigS2O_AllGroupsMerged_DivergenceHeterogeneityVsSlope.m。
%
% 指标定义（左右两列使用同一套函数，仅取样时刻不同）：
% - Divergence：首个光水 session，ZScore 基线 1:24，逐回合减 cue onset 值后，
%   div = sqrt(sum(var(cells)) / sum(mean(cells).^2))；无延迟取 cue +1 s，延迟取 cue +1.5 s
%   （延迟任务给水在 cue +2.5 s，+1.5 s 为回合内决策期，同英文图/ALDelayed_DivVsHitRate_Scatter.m）。
% - Response heterogeneity：每细胞每 session 在对应时刻的中位反应，跨 session 取均值，
%   再取细胞间 SD（仅保留 [-1,1] 内的细胞，≥3 个细胞）；session 截断到首次命中率=1 之前
%   （同 Fig1H）。
% - Sigmoid slope：每鼠对 block 序号拟合 sigmoid（上渐近线固定为 1，同 Fig1B）。
%
% 执行方式（硬性要求）：本文件保持为脚本，在 MATLAB Editor 中直接 Run/F5。

% --- 0) Ensure project loaded
if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

colorNaive = TransferLearning.NaiveColor;
colorTransfer = TransferLearning.TransferColor;
colorFit = TransferLearning.ColorA;

%% 1) 指标
U = TransferLearning.DelayComparison.CollectSlopeMetrics("Undelayed");
D = TransferLearning.DelayComparison.CollectSlopeMetrics("Delayed");
Undelayed = U.Divergence;
HetUndelayed = U.Heterogeneity;
Delayed = D.Divergence;
HetDelayed = D.Heterogeneity;

fprintf('Undelayed: divergence n=%d, L2/3 n=%d, L5 n=%d\n', height(Undelayed), ...
	nnz(HetUndelayed.Layer == "MOp2/3"), nnz(HetUndelayed.Layer == "MOp5"));
fprintf('Delayed: divergence n=%d, L2/3 n=%d, L5 n=%d\n', height(Delayed), ...
	nnz(HetDelayed.Layer == "MOp2/3"), nnz(HetDelayed.Layer == "MOp5"));

%% 2) 图 A：Divergence vs sigmoid slope（左=无延迟，右=延迟）
fA = figure('Color', 'w', 'Name', 'FigS2N divergence vs slope');
fA.Units = 'centimeters';
fA.Position(3:4) = [12, 7];
fA.PaperUnits = 'centimeters';
fA.PaperSize = [12, 7];
fA.PaperPositionMode = 'auto';

tlA = tiledlayout(fA, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tlA, 'Divergence', 'FontSize', 12);

axA1 = nexttile(tlA, 1);
iScatterPanel(axA1, Undelayed.Divergence, Undelayed.Slope, Undelayed.Group, ...
	colorNaive, colorTransfer, colorFit, "Undelayed");
ylabel(axA1, 'Sigmoid slope', 'FontSize', 12);

axA2 = nexttile(tlA, 2);
iScatterPanel(axA2, Delayed.Divergence, Delayed.Slope, Delayed.Group, ...
	colorNaive, colorTransfer, colorFit, "Delayed");

hLegA = [findobj(axA1, 'Type', 'Scatter', 'Tag', 'Naive'); findobj(axA1, 'Type', 'Scatter', 'Tag', 'Transfer')];
lgdA = legend(hLegA, {'Naive', 'Transfer'}, 'FontSize', 12, 'Box', 'off', 'Orientation', 'horizontal');
lgdA.Layout.Tile = 'south';

svgA = TransferLearning.ExportStandardFigure(fA, 2, 'English_FigS2N_DelayedVsUndelayed_DivergenceVsSlope.svg');
fprintf('Wrote: %s\n', svgA);

%% 3) 图 B：Response heterogeneity vs sigmoid slope（列=队列，行=层）
fB = figure('Color', 'w', 'Name', 'FigS2N heterogeneity vs slope');
fB.Units = 'centimeters';
fB.Position(3:4) = [12, 12];
fB.PaperUnits = 'centimeters';
fB.PaperSize = [12, 12];
fB.PaperPositionMode = 'auto';

tlB = tiledlayout(fB, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tlB, 'Response heterogeneity', 'FontSize', 12);

layers = ["MOp2/3", "MOp5"];
layerLabels = ["L2/3", "L5"];
axB = gobjects(2, 2);
for iL = 1:numel(layers)
	axB(iL, 1) = nexttile(tlB, (iL - 1) * 2 + 1);
	d = HetUndelayed(HetUndelayed.Layer == layers(iL), :);
	iScatterPanel(axB(iL, 1), d.Heterogeneity, d.Slope, d.Group, colorNaive, colorTransfer, colorFit, ...
		sprintf('Undelayed — %s', layerLabels(iL)));
	if iL == 1
		ylabel(axB(iL, 1), 'Sigmoid slope', 'FontSize', 12);
	end

	axB(iL, 2) = nexttile(tlB, (iL - 1) * 2 + 2);
	d = HetDelayed(HetDelayed.Layer == layers(iL), :);
	iScatterPanel(axB(iL, 2), d.Heterogeneity, d.Slope, d.Group, colorNaive, colorTransfer, colorFit, ...
		sprintf('Delayed — %s', layerLabels(iL)));
end

hLegB = [findobj(axB(1, 1), 'Type', 'Scatter', 'Tag', 'Naive'); findobj(axB(1, 1), 'Type', 'Scatter', 'Tag', 'Transfer')];
lgdB = legend(hLegB, {'Naive', 'Transfer'}, 'FontSize', 12, 'Box', 'off', 'Orientation', 'horizontal');
lgdB.Layout.Tile = 'south';

svgB = TransferLearning.ExportStandardFigure(fB, 2, 'English_FigS2N_DelayedVsUndelayed_HeterogeneityVsSlope.svg');
fprintf('Wrote: %s\n', svgB);

assignin('base', 'FigS2N_Undelayed', Undelayed);
assignin('base', 'FigS2N_Delayed', Delayed);
assignin('base', 'FigS2N_HeterogeneityUndelayed', HetUndelayed);
assignin('base', 'FigS2N_HeterogeneityDelayed', HetDelayed);

%% --- local functions
function iScatterPanel(ax, X, Y, Group, colorNaive, colorTransfer, colorFit, panelTitle)
hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
isNaive = string(Group) == "Naive";
isTransfer = string(Group) == "Transfer";
scatter(ax, X(isNaive), Y(isNaive), 10, colorNaive, 'o', 'filled', ...
	'LineWidth', 0.2, 'Tag', 'Naive');
scatter(ax, X(isTransfer), Y(isTransfer), 10, colorTransfer, 's', 'filled', ...
	'LineWidth', 0.2, 'Tag', 'Transfer');

x = double(X);
y = double(Y);
[r, p] = corr(x, y, 'Type', 'Spearman');
if numel(x) >= 3 && std(x) > 0 && std(y) > 0
	f = polyfit(x, y, 1);
	xLine = [min(x), max(x)];
	plot(ax, xLine, polyval(f, xLine), '-', 'Color', colorFit, 'LineWidth', 2);
	label = sprintf('n = %d\nr_s = %.2f\n%s', numel(x), r, iPLabel(p));
else
	r = NaN;
	label = sprintf('n = %d', numel(x));
end
% Positive relationships leave the upper-left corner free, negative ones the
% upper-right corner.
if isfinite(r) && r > 0
	text(ax, 0.03, 0.97, label, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
		'VerticalAlignment', 'top', 'FontSize', 10);
else
	text(ax, 0.97, 0.97, label, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
		'VerticalAlignment', 'top', 'FontSize', 10);
end
title(ax, panelTitle, 'FontSize', 12, 'FontWeight', 'normal');
end

function txt = iPLabel(p)
if ~isfinite(p)
	txt = 'p = NaN';
elseif p < 0.001
	txt = 'p < 0.001';
elseif p < 0.01
	txt = sprintf('p = %.3f', p);
else
	txt = sprintf('p = %.2f', p);
end
end
