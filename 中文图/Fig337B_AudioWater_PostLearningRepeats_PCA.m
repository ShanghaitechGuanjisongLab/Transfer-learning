% 中文图337B：将图337A的四个声水会话合并为超级大鼠后的 1s z-score PCA

Data = Fig337_BuildAudioLearnedRepeatSummary();
points = Data.Points;
explained = Data.Explained;
labels = Data.SessionLabels;
palette2 = TransferLearning.FigurePalette(2);
baseColor = palette2(2, :);

f = figure('Color', 'w', 'Name', '中文图337B AudioWater post-learning repeats PCA');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 8];
f.PaperSize = [6, 8];

ax = axes(f);
hold(ax, 'on');

cmap = iTintRamp(baseColor, size(points, 1));
for i = 1:(size(points, 1) - 1)
	h = line(ax, points(i:(i+1), 1), points(i:(i+1), 2), 'Color', cmap(i+1, :), 'LineWidth', 2, 'HandleVisibility', 'off');
	setappdata(h, 'TransferLearningPreserveLineWidth', true);
end
s = scatter(ax, points(:,1), points(:,2), 20, cmap, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.2, 'HandleVisibility', 'off');
uistack(s, 'top');
for i = 1:size(points, 1)
	[dx, dy, hAlign] = iLabelOffset(labels(i));
	text(ax, points(i,1) + dx, points(i,2) + dy, labels(i), 'FontSize', 12, 'Color', 'k', 'HorizontalAlignment', hAlign, 'VerticalAlignment', 'middle');
end

ax.FontSize = 12;
ax.LineWidth = 2;
ax.TickDir = 'out';
ax.FontName = 'Arial';
box(ax, 'off');
grid(ax, 'off');
xRange = max(points(:,1)) - min(points(:,1));
yRange = max(points(:,2)) - min(points(:,2));
padX = max(4, 0.2 * xRange);
padY = max(2, 0.15 * yRange);
xlim(ax, [min(points(:,1)) - padX, max(points(:,1)) + padX]);
ylim(ax, [min(points(:,2)) - padY, max(points(:,2)) + padY]);
xlabel(ax, sprintf('PC1 (%.1f%%)', explained(1)), 'FontSize', 12);
ylabel(ax, sprintf('PC2 (%.1f%%)', explained(2)), 'FontSize', 12);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig337B_AudioWater_PostLearningRepeats_PCA.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig337B_Data', Data);

function cmap = iTintRamp(baseColor, n)
if n <= 1
	cmap = baseColor;
	return;
end
mix = linspace(0.35, 1.00, n)';
cmap = baseColor .* mix + 0.15 .* (1 - mix);
end

function [dx, dy, hAlign] = iLabelOffset(label)
switch string(label)
	case "Naive"
		dx = -0.8;
		dy = 0.2;
		hAlign = 'right';
	case "100%"
		dx = 0.8;
		dy = 0.3;
		hAlign = 'left';
	case "24h"
		dx = 0.8;
		dy = -0.5;
		hAlign = 'left';
	case "36h"
		dx = -0.9;
		dy = 0.0;
		hAlign = 'right';
	otherwise
		dx = 0.8;
		dy = 0;
		hAlign = 'left';
end
end

