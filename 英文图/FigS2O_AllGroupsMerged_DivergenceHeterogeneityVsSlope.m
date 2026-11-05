% FigS2O（英文图）：不区分 delay / undelay，全部合并为一组后重做 Fig1G、Fig1H 的两类散点。
%
% 合并的鼠：
% - 无延迟（原数据）：naive = LightAudioBaseline + LAInterspersed，transfer = AudioLightBaseline
%   （取样时刻 cue +1 s，同 FigS2N 左列）；
% - 延迟：TransferLearning.ALDelayed 的光水迁移阶段（取样时刻 cue +1.5 s，同 FigS2N 右列）。
% 指标定义与 FigS2N 完全一致（共用 TransferLearning.DelayComparison.CollectSlopeMetrics），
% 只是把两组点画在一起、只用一条拟合线和一组 Spearman 统计；点仍按 Naive/Transfer 配色
% （紫=naive，橙=transfer），延时与无延迟不再区分（延迟鼠全部属于 transfer 阶段）。
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

%% 1) 指标（两组合并）
U = TransferLearning.DelayComparison.CollectSlopeMetrics("Undelayed");
D = TransferLearning.DelayComparison.CollectSlopeMetrics("Delayed");
Div = [U.Divergence; D.Divergence];
Het = [U.Heterogeneity; D.Heterogeneity];

fprintf('Merged divergence: n=%d\n', height(Div));
fprintf('Merged heterogeneity: L2/3 n=%d, L5 n=%d\n', ...
	nnz(Het.Layer == "MOp2/3"), nnz(Het.Layer == "MOp5"));

%% 2) 图 A：Divergence vs sigmoid slope（全部合并）
fA = figure('Color', 'w', 'Name', 'FigS2O merged divergence vs slope');
fA.Units = 'centimeters';
fA.Position(3:4) = [6, 8];
fA.PaperUnits = 'centimeters';
fA.PaperSize = [6, 8];
fA.PaperPositionMode = 'auto';

tlA = tiledlayout(fA, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
xlA = xlabel(tlA, 'Divergence');
xlA.FontSize = 12;

axA = nexttile(tlA, 1);
iScatterPanel(axA, Div.Divergence, Div.Slope, Div.Group, colorNaive, colorTransfer, colorFit);
ylabel(axA, 'Sigmoid slope', 'FontSize', 12);

hLegA = [findobj(axA, 'Type', 'Scatter', 'Tag', 'Naive'); findobj(axA, 'Type', 'Scatter', 'Tag', 'Transfer')];
lgdA = legend(axA, hLegA, {'Naive', 'Transfer'}, 'Location', 'northoutside', ...
	'Orientation', 'horizontal', 'FontSize', 12);
lgdA.Box = 'off';
lgdA.AutoUpdate = 'off';

svgA = TransferLearning.ExportStandardFigure(fA, 2, 'English_FigS2O_AllGroupsMerged_DivergenceVsSlope.svg');
fprintf('Wrote: %s\n', svgA);

%% 3) 图 B：Response heterogeneity vs sigmoid slope（全部合并，按层）
fB = figure('Color', 'w', 'Name', 'FigS2O merged heterogeneity vs slope');
fB.Units = 'centimeters';
fB.Position(3:4) = [12, 8];
fB.PaperUnits = 'centimeters';
fB.PaperSize = [12, 8];
fB.PaperPositionMode = 'auto';

tlB = tiledlayout(fB, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xlB = xlabel(tlB, 'Response heterogeneity');
xlB.FontSize = 12;

layers = ["MOp2/3", "MOp5"];
layerLabels = ["L2/3", "L5"];
axB = gobjects(1, 2);
for iL = 1:numel(layers)
	axB(iL) = nexttile(tlB, iL);
	d = Het(Het.Layer == layers(iL), :);
	iScatterPanel(axB(iL), d.Heterogeneity, d.Slope, d.Group, colorNaive, colorTransfer, colorFit);
	title(axB(iL), layerLabels(iL), 'FontSize', 12, 'FontWeight', 'normal');
	if iL == 1
		ylabel(axB(iL), 'Sigmoid slope', 'FontSize', 12);
	end
end

hLegB = [findobj(axB(1), 'Type', 'Scatter', 'Tag', 'Naive'); findobj(axB(1), 'Type', 'Scatter', 'Tag', 'Transfer')];
lgdB = legend(hLegB, {'Naive', 'Transfer'}, 'FontSize', 12, 'Box', 'off', 'Orientation', 'horizontal');
lgdB.Layout.Tile = 'south';

svgB = TransferLearning.ExportStandardFigure(fB, 2, 'English_FigS2O_AllGroupsMerged_HeterogeneityVsSlope.svg');
fprintf('Wrote: %s\n', svgB);

assignin('base', 'FigS2O_Divergence', Div);
assignin('base', 'FigS2O_Heterogeneity', Het);

%% --- local functions
function iScatterPanel(ax, X, Y, Group, colorNaive, colorTransfer, colorFit)
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
else
	r = NaN;
end
label = iPLabel(p);
if isfinite(r) && r > 0
	text(ax, 0.03, 0.97, label, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
		'VerticalAlignment', 'top', 'FontSize', 10);
else
	text(ax, 0.97, 0.97, label, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
		'VerticalAlignment', 'top', 'FontSize', 10);
end
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
