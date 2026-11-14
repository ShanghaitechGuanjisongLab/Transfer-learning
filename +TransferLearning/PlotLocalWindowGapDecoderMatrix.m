function Stats = PlotLocalWindowGapDecoderMatrix(PlotData, SvgName)
% 只根据预计算数据作图和导出，不读取计算缓存或运行解码、shuffle统计。
arguments
	PlotData (1,1) struct
	SvgName (1,1) string = "English_Fig3B_LocalWindow_GapDecoderTransfer.svg"
end
assert(isfield(PlotData, 'PlotDataVersion') && PlotData.PlotDataVersion == 1, 'Fig3BMatrix:InvalidPlotData', '绘图数据版本不一致，请重新运行计算节。');
Stats = PlotData;
[Fig, Axes, StarHandles, SvgPath, LegendHandle, LineHandles] = PlotMatrix(PlotData.tVec, PlotData.rows, PlotData.rowSpecs, PlotData.columnLabels, PlotData.Summary, SvgName, PlotData.DisplayedColumns);
Stats.figure = Fig;
Stats.axes = Axes;
Stats.svgPath = SvgPath;
Stats.StarHandles = StarHandles;
Stats.Legend = LegendHandle;
Stats.LineHandles = LineHandles;
fprintf('\n3B作图完成：复用预计算结果，未重新解码、shuffle或计算群体统计。\n');
disp(PlotData.Summary);
fprintf('图已导出：%s\n', SvgPath);
end

function [Fig, Axes, Stars, SvgPath, LegendHandle, LineHandles] = PlotMatrix(Time, RowStats, RowSpecs, ColumnLabels, Summary, SvgName, DisplayedColumns)
NColumns = numel(DisplayedColumns);
Fig = figure('Color', 'w', 'Name', '英文图3B：1 s局部均值1×3训练集叠加图');
Fig.Units = 'centimeters';
Fig.Position(3:4) = [9, 8];
Layout = tiledlayout(Fig, 1, NColumns, 'TileSpacing', 'tight', 'Padding', 'tight');
Axes = gobjects(1, NColumns);
Stars = gobjects(1, NColumns);
LineHandles = gobjects(2, NColumns);
Colors = [TransferLearning.CurveNaive; TransferLearning.CurveLearned] / 255;
LegendLabels = RowSpecs(:, 3)';
for PlotColumn = 1:NColumns
	Column = DisplayedColumns(PlotColumn);
	Ax = nexttile(Layout, PlotColumn);
	hold(Ax, 'on');
	UpperCurves = nan(2, numel(Time));
	for Row = 1:2
		MeanCurve = RowStats{Row}.MeanCurves{Column};
		SEMCurve = RowStats{Row}.SEMCurves{Column};
		UpperCurves(Row, :) = MeanCurve + SEMCurve;
		fill(Ax, [Time, fliplr(Time)], [MeanCurve + SEMCurve, fliplr(MeanCurve - SEMCurve)], Colors(Row, :), 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
		LineHandles(Row, PlotColumn) = plot(Ax, Time, MeanCurve, 'Color', Colors(Row, :), 'LineWidth', 1.2, 'DisplayName', LegendLabels(Row));
	end
	yline(Ax, 0.5, ':', 'Color', [0.75, 0.75, 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
	xline(Ax, 0, '--', 'Color', [0.35, 0.35, 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
	SummaryRows = Summary.TestColumn == Column;
	Significant = Summary.PValueHolm(SummaryRows) < 0.05;
	assert(nnz(SummaryRows) == 2 && (all(Significant) || ~any(Significant)), 'Fig3BMatrix:DifferentSignificance', '同列两种训练的显著性不一致，不能共用星号。');
	if all(Significant)
		AnchorY = max(interp1(Time, UpperCurves', 1, 'linear'));
		Stars(PlotColumn) = text(Ax, 1, AnchorY, '*', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', [0, 0, 0], 'Interpreter', 'none', 'Tag', 'ShuffleSignificance');
		Stars(PlotColumn).UserData = struct('PValue', Summary.PValue(SummaryRows), 'PValueHolm', Summary.PValueHolm(SummaryRows), 'Metric', "PostMinusPrePPost", 'AnchorTime', 1, 'SharedAcrossTraining', true);
	end
	title(Ax, ColumnLabels(Column), 'FontWeight', 'normal');
	if PlotColumn > 1
		Ax.YAxis.Visible = 'off';
	end
	legend(Ax, 'off');
	box(Ax, 'off');
	Ax.Color = 'none';
	Axes(PlotColumn) = Ax;
end
LegendHandle = legend(Axes(1), LineHandles(:, 1), LegendLabels, 'Orientation', 'horizontal', 'NumColumns', 2, 'Box', 'off');
title(LegendHandle,'Trained from');
title(Layout,'Tested with')
xlabel(Layout, 'Time from cue onset (s)');
ylabel(Layout, 'P(cued)');
LegendHandle.Layout.Tile = 'south';
TransferLearning.ApplyStandardExportStyle(Fig, 2);
MATLAB.Graphics.UnifyAxesLims(Axes(:), @xlim, @ylim);
for PlotColumn = 1:NColumns
	Column = DisplayedColumns(PlotColumn);
	if ~isgraphics(Stars(PlotColumn))
		continue;
	end
	UpperCurves = nan(2, numel(Time));
	for Row = 1:2
		UpperCurves(Row, :) = RowStats{Row}.MeanCurves{Column} + RowStats{Row}.SEMCurves{Column};
	end
	Extent = Stars(PlotColumn).Extent;
	Span = [max(Time(1), Extent(1)), min(Time(end), Extent(1) + Extent(3))];
	Support = [Span, Time(Time >= Span(1) & Time <= Span(2))];
	Stars(PlotColumn).Position(2) = max(interp1(Time, UpperCurves', Support, 'linear'), [], 'all');
	plot(Axes(PlotColumn), 1, Stars(PlotColumn).Position(2) + Extent(4), 'LineStyle', 'none', 'Marker', 'none', 'HandleVisibility', 'off', 'Tag', 'ShuffleSignificanceBounds');
	Axes(PlotColumn).YLimMode = 'auto';
end
MATLAB.Graphics.UnifyAxesLims(Axes(:), @xlim, @ylim);
for Ax = Axes
	Ax.YTick = Ax.YTick(Ax.YTick <= 1.1);
end
SvgPath = TransferLearning.StandardFigureSvgPath(SvgName);
print(Fig, SvgPath, '-dsvg');
end