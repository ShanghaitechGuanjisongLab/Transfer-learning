function SvgPath = PlotEarlyOnsetCells(RA, RL, Options)
% PlotEarlyOnsetCells  绘制两套数据的 early/late-onset 验证图。
%
% 左列：movement-active 细胞按活动起始时刻排序的 z 分数热图（横轴为相对运动起始）。
% 右列：early-onset 与 late-onset 的平均轨迹。
%
% 输出图通过TransferLearning.ExportStandardFigure以2倍缩放导出。

arguments
	RA
	RL
	Options.LabelA (1,1) string
	Options.LabelB (1,1) string
	Options.ModalityA (1,1) string
	Options.ModalityB (1,1) string
	Options.FileName (1,1) string
end

f = figure('Color','w','Name','Early-onset cells (paper definition)');
f.Units = 'centimeters';
f.Position(3:4) = [12.0, 8.0];
f.PaperUnits = 'centimeters';
f.PaperSize = [12.0, 8.0];
f.PaperPositionMode = 'auto';

t = tiledlayout(f, 2, 2, 'TileSpacing','compact','Padding','compact');

nColor = 128;
cmap = [[linspace(0,1,nColor).'; ones(nColor,1)], ...
	[linspace(0,1,nColor).'; linspace(1,0,nColor).'], ...
	[ones(nColor,1); linspace(1,0,nColor).']];

Results = {RA, Options.LabelA, Options.ModalityA; RL, Options.LabelB, Options.ModalityB};

for iSet = 1:2
	R = Results{iSet, 1};
	label = Results{iSet, 2};
	modality = Results{iSet, 3};

	isActive = R.Cells.Class == "movement-active";
	onset = R.Cells.Onset;
	isEarly = R.Cells.IsEarlyOnset;
	isLate = isActive & ~isEarly & ~isnan(onset);

	[~, order] = sort(onset, 'ascend', 'MissingPlacement', 'last');
	order = order(isActive(order));
	trace = R.Traces(order, :);
	trace = max(min(trace, 4), -2);

	ax = nexttile(t);
	imagesc(ax, R.Grid, 1:numel(order), trace);
	colormap(ax, cmap);
	clim(ax, prctile(trace(:), [5, 98]));
	hold(ax, 'on');
	xline(ax, 0, 'k-', 'LineWidth', 1);
	hold(ax, 'off');
	ax.YTick = [];
	ax.XLim = [R.Grid(1), R.Grid(end)];
	ax.FontSize = 6;
	ax.LineWidth = 0.5;
	ax.Box = 'off';
	xlabel(ax, 'Time from movement onset (s)', 'FontSize', 6);
	ylabel(ax, 'Neurons', 'FontSize', 6);
	title(ax, {label, sprintf('%s; n = %d', modality, numel(order))}, 'FontSize', 6);
	if isprop(ax,'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end

	ax2 = nexttile(t);
	hold(ax2, 'on');
	hEarly = plot(ax2, R.Grid, mean(R.Traces(isEarly,:), 1), '-', 'Color', TransferLearning.LearnedColor, 'LineWidth', 1);
	hLate = plot(ax2, R.Grid, mean(R.Traces(isLate,:), 1), '-', 'Color', TransferLearning.TransferColor, 'LineWidth', 1);
	xline(ax2, 0, 'k-', 'LineWidth', 0.5, 'HandleVisibility','off');
	hold(ax2, 'off');
	ax2.FontSize = 6;
	ax2.LineWidth = 0.5;
	ax2.Box = 'off';
	ax2.XLim = [R.Grid(1), R.Grid(end)];
	xlabel(ax2, 'Time from movement onset (s)', 'FontSize', 6);
	ylabel(ax2, 'z-scored \DeltaF/F', 'FontSize', 6);
	legend(ax2, [hEarly, hLate], {'early-onset', 'late-onset'}, ...
		'FontSize', 6, 'Box', 'off', 'Location', 'northwest');
	title(ax2, 'Average response', 'FontSize', 6);
	if isprop(ax2,'Toolbar') && ~isempty(ax2.Toolbar)
		ax2.Toolbar.Visible = 'off';
	end
end

SvgPath = TransferLearning.ExportStandardFigure(f, 2, Options.FileName);
end
