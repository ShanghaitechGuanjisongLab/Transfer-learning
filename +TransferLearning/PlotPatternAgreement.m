function SvgPath = PlotPatternAgreement(Entries, Options)
% PlotPatternAgreement  绘制群体响应模式的一致性（文献Fig 1i口径）。
%
% 每个数据集一根柱：转移条件与训练条件之间、跨细胞的平均响应相关 R。
% 同时画出两条参考线：
%   虚线 —— 同条件自身重测一致性（拆分试次的 R，作为上界/ceiling）
%   点线 —— 细胞身份打乱后的 R（floor）
%
% Entries为cell数组，每行 {R值, 上界, 下界, 标签}。

arguments
	Entries cell
	Options.Title (1,1) string = "Population pattern agreement"
	Options.FileName (1,1) string
end

f = figure('Color','w','Name',char(Options.Title));
f.Units = 'centimeters';
f.Position(3:4) = [9.0, 4.0];
f.PaperUnits = 'centimeters';
f.PaperSize = [9.0, 4.0];
f.PaperPositionMode = 'auto';

ax = axes(f);
hold(ax, 'on');
nEntry = size(Entries, 1);
values = zeros(1, nEntry);
for iEntry = 1:nEntry
	values(iEntry) = Entries{iEntry, 1};
end
bar(ax, values, 0.6, 'FaceColor', TransferLearning.TransferColor, 'EdgeColor', 'none');
hold(ax, 'on');
for iEntry = 1:nEntry
	text(ax, iEntry, values(iEntry), sprintf('%.2f', values(iEntry)), 'FontSize', 6, ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

hCeiling = gobjects(1);
hFloor = gobjects(1);
for iEntry = 1:nEntry
	hCeiling = plot(ax, [iEntry - 0.42, iEntry + 0.42], repmat(Entries{iEntry, 2}, 1, 2), 'k--', 'LineWidth', 1);
	hFloor = plot(ax, [iEntry - 0.42, iEntry + 0.42], repmat(Entries{iEntry, 3}, 1, 2), 'k:', 'LineWidth', 1);
end
hold(ax, 'off');

ax.XTick = 1:nEntry;
ax.XTickLabel = string(cellfun(@(x) x, Entries(:, 4), UniformOutput=false));
ax.YLim = [0, 1.1];
ax.FontSize = 6;
ax.LineWidth = 0.5;
ax.Box = 'off';
ylabel(ax, 'Pattern r', 'FontSize', 6);
legend(ax, [hCeiling, hFloor], {'ceiling', 'floor'}, ...
	'FontSize', 6, 'Box', 'off', 'Location', 'northoutside', 'Orientation', 'horizontal');
if isprop(ax,'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

SvgPath = TransferLearning.ExportStandardFigure(f, 2, Options.FileName);
end
