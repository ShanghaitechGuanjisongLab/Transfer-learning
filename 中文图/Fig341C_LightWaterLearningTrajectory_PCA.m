% 中文图341C：初始/迁移 💡💧 学习过程状态空间轨迹

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = TransferLearning.Fig341.BuildStateSpaceSummary(UniExp.Flags.No_special_operation);
Naive = Data.Representative.NaiveCell;
Transfer = Data.Representative.TransferCell;

f = figure('Color', 'w', 'Name', '中文图341C LightWater learning trajectory PCA');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
palette2 = TransferLearning.FigurePalette(2);

ax1 = nexttile(tlo, 1);
iPlotMouseTrajectory(ax1, Naive.Points, Naive.Explained, palette2(1, :), 'Naive');

ax2 = nexttile(tlo, 2);
iPlotMouseTrajectory(ax2, Transfer.Points, Transfer.Explained, palette2(2, :), 'Continual');

MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @xlim);
MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @ylim);

hSolid = plot(ax2, nan, nan, '-', 'Color', 'k', 'LineWidth', 2, 'DisplayName', 'Learning steps');
hDash = plot(ax2, nan, nan, '--', 'Color', 'k', 'LineWidth', 2, 'DisplayName', 'Direct distance');
lg = legend(ax2, [hSolid, hDash], {'Learning steps', 'Direct distance'}, 'Location', 'southoutside');
lg.FontSize = 12;
lg.Box = 'off';

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig341C_LightWaterLearningTrajectory_PCA.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig341C_NaiveTrajectory', Naive);
assignin('base', 'Fig341C_TransferTrajectory', Transfer);

function iPlotMouseTrajectory(ax, points, explained, baseColor, titleText)
hold(ax, 'on');
nSess = size(points, 1);
cmap = iTintRamp(baseColor, nSess);
	d = line(ax, [points(1,1) points(end,1)], [points(1,2) points(end,2)], 'Color', baseColor, 'LineStyle', '--', 'LineWidth', 2, 'HandleVisibility', 'off');
	setappdata(d, 'TransferLearningPreserveLineWidth', true);
for i = 1:(nSess - 1)
	h = line(ax, points(i:(i+1), 1), points(i:(i+1), 2), 'Color', cmap(i+1, :), 'LineWidth', 2, 'HandleVisibility', 'off');
	setappdata(h, 'TransferLearningPreserveLineWidth', true);
end
	s = scatter(ax, points(:,1), points(:,2), 16, cmap, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.2, 'HandleVisibility', 'off');
	uistack(s, 'top');
for i = 1:nSess
		text(ax, points(i,1), points(i,2), sprintf(' %d', i), 'FontSize', 6, 'Color', 'k', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
	end
	ax.FontSize = 12;
	ax.LineWidth = 2;
	ax.TickDir = 'out';
	ax.FontName = 'Arial';
	box(ax, 'off');
	grid(ax, 'off');
	xlabel(ax, sprintf('PC1 (%.1f%%)', explained(1)), 'FontSize', 12);
	ylabel(ax, sprintf('PC2 (%.1f%%)', explained(2)), 'FontSize', 12);
	title(ax, titleText, 'FontSize', 12, 'FontWeight', 'normal');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

function cmap = iTintRamp(baseColor, n)
if n <= 1
	cmap = baseColor;
	return;
end
mix = linspace(0.35, 1.00, n)';
cmap = baseColor .* mix + 0.15 .* (1 - mix);
end