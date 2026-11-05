function SvgPath = PlotTransferOnsetCells(Entries, Options)
% PlotTransferOnsetCells  绘制训练模态与转移模态活动起始时刻的配对比较图。
%
% Entries为N×3 cell，每行 {TransferOnsetCells结果, 标签, 模态箭头}。
%
% 左列：训练模态 vs 转移模态的 onset 散点，虚线为 y=x。
% 右列：转移模态中判为 early-onset 的比例；柱顶数字为"转移态early细胞数/该组细胞数"，
%       标题内为鼠内分层置换检验p值。
%
% 输出图通过TransferLearning.ExportStandardFigure以2倍缩放导出。

arguments
	Entries cell
	Options.FileName (1,1) string
end

nRow = size(Entries, 1);
f = figure('Color','w','Name','Transfer-condition onset of early-onset cells');
f.Units = 'centimeters';
f.Position(3:4) = [12.0, 4.0 * nRow];
f.PaperUnits = 'centimeters';
f.PaperSize = [12.0, 4.0 * nRow];
f.PaperPositionMode = 'auto';

t = tiledlayout(f, nRow, 2, 'TileSpacing','compact','Padding','compact');
edges = -0.2:0.05:1.0;

for iSet = 1:nRow
	P = Entries{iSet, 1};
	label = Entries{iSet, 2};
	arrow = Entries{iSet, 3};
	C = P.Cells;

	paired = C.ActiveBoth & ~isnan(C.TrainedOnset) & ~isnan(C.TransferOnset);

	ax = nexttile(t);
	scatter(ax, C.TrainedOnset(paired), C.TransferOnset(paired), 3, 'k', 'filled', ...
		'MarkerFaceAlpha', 0.35, 'MarkerEdgeAlpha', 0.35);
	hold(ax, 'on');
	plot(ax, edges([1 end]), edges([1 end]), 'k--', 'LineWidth', 0.5, 'HandleVisibility','off');
	hold(ax, 'off');
	ax.XLim = [edges(1), edges(end)];
	ax.YLim = [edges(1), edges(end)];
	ax.FontSize = 6;
	ax.LineWidth = 0.5;
	ax.Box = 'off';
	xlabel(ax, 'Trained onset (s)', 'FontSize', 6);
	ylabel(ax, 'Transfer onset (s)', 'FontSize', 6);
	title(ax, {label, sprintf('%d cells, %d mice', sum(paired), P.Stats.NMouse)}, 'FontSize', 6);
	if isprop(ax,'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end

	ax2 = nexttile(t);
	values = 100 * [P.Stats.FracTransferEarlyGivenTrainedEarly, P.Stats.FracTransferEarlyGivenTrainedNotEarly];
	countsBar = [P.Stats.NTrainedEarly, P.Stats.NTrainedNotEarly];
	numerators = [P.Stats.NTrainedEarlyTransferEarly, P.Stats.NTrainedNotEarlyTransferEarly];
	bar(ax2, values, 0.6, 'FaceColor', TransferLearning.TransferColor, 'EdgeColor', 'none');
	hold(ax2, 'on');
	for k = 1:2
		text(ax2, k, values(k), sprintf('%d/%d', numerators(k), countsBar(k)), 'FontSize', 6, ...
			'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
	end
	hold(ax2, 'off');
	ax2.XTick = [1, 2];
	ax2.XTickLabel = {'trained early', 'trained other'};
	ax2.YLim = [0, max(values) * 1.35];
	ax2.FontSize = 6;
	ax2.LineWidth = 0.5;
	ax2.Box = 'off';
	ylabel(ax2, 'Early in transfer (%)', 'FontSize', 6);
	title(ax2, {label, sprintf('perm p = %.1e', P.Stats.MousePermP)}, 'FontSize', 6);
	if isprop(ax2,'Toolbar') && ~isempty(ax2.Toolbar)
		ax2.Toolbar.Visible = 'off';
	end
end

SvgPath = TransferLearning.ExportStandardFigure(f, 2, Options.FileName);
end
