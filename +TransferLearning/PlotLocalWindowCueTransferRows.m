function Stats = PlotLocalWindowCueTransferRows(rowSpecs, figureLabel, svgName, PostDuration)
% 每行指定训练阶段、训练刺激和行标签；三列分别为合并OOF自测、12 h迁移、7 d迁移。
arguments
	rowSpecs (:,3) string
	figureLabel (1,1) string
	svgName (1,1) string
	PostDuration (1,1) double {mustBeMember(PostDuration, [0.3, 1])} = 1
end
nRows = size(rowSpecs, 1);
rowStats = cell(nRows, 1);
tVec = [];
for rowIndex = 1:nRows
	S = TransferLearning.LoadLocalWindowCueTransferResults(rowSpecs(rowIndex, 1), rowSpecs(rowIndex, 2), PostDuration);
	if isempty(tVec), tVec = S.tVec; elseif ~isequal(tVec, S.tVec), error('LocalWindowCueTransfer:DifferentGrids', '各行缓存的时间网格不一致。'); end
	curves = cell(1, 3); nulls = cell(1, 3);
	accuracy = cell(2, 2); mouseNames = cell(2, 1);
	for datasetIndex = 1:2
		selfRows = []; transferRows = []; selfNulls = []; transferNulls = [];
		selfAccuracy = []; transferAccuracy = []; mice = strings(0, 1);
		for resultIndex = 1:numel(S.res)
			result = S.res{resultIndex};
			if result.DS ~= datasetIndex, continue; end
			selfRows = [selfRows; result.pPostS1T(:)'];
			transferRows = [transferRows; result.pPostByT(:)'];
			selfNulls = [selfNulls; result.null95S1(:)'];
			transferNulls = [transferNulls; result.null95(:)'];
			selfAccuracy(end+1) = result.s1Acc;
			transferAccuracy(end+1) = result.s2Acc;
			mice(end+1, 1) = string(result.Mouse);
		end
		if isempty(mice), error('LocalWindowCueTransfer:EmptyCohort', '第%d行的第%d队列没有有效鼠。', rowIndex, datasetIndex); end
		curves{1} = [curves{1}; selfRows]; curves{datasetIndex+1} = transferRows;
		nulls{1} = [nulls{1}; selfNulls]; nulls{datasetIndex+1} = transferNulls;
		accuracy(:, datasetIndex) = {selfAccuracy; transferAccuracy};
		mouseNames{datasetIndex} = mice;
	end
	pTransferAccuracy = ranksum(accuracy{2,1}, accuracy{2,2});
	rowStats{rowIndex} = struct('trainPhase', rowSpecs(rowIndex,1), 'trainStimulus', rowSpecs(rowIndex,2), 'curves', {curves}, 'nulls', {nulls}, 'accuracy', {accuracy}, 'mouseNames', {mouseNames}, 'pTransferAccuracy', pTransferAccuracy, 'halfWindow', S.halfWindow, 'nPermutation', S.nPermutation);
	fprintf('%s训练 %s %s：自测%d只鼠，12 h测试%d只鼠，7 d测试%d只鼠。\n', figureLabel, rowSpecs(rowIndex,1), rowSpecs(rowIndex,2), size(curves{1},1), size(curves{2},1), size(curves{3},1));
	fprintf('  自测平均准确率=%.4f；12 h=%.4f；7 d=%.4f；迁移组间秩和p=%.6g。\n', mean([accuracy{1,1},accuracy{1,2}]), mean(accuracy{2,1}), mean(accuracy{2,2}), pTransferAccuracy);
end

fig = figure('Color', 'w', 'Name', char("English Fig" + figureLabel + " local-window cue transfer"));
fig.Units = 'centimeters'; fig.Position(3:4) = [6, 4*nRows];
layout = tiledlayout(fig, nRows, 3, 'TileSpacing', 'tight', 'Padding', 'tight');
axesHandles = gobjects(nRows, 3);
columnNames = ["Self-test", "12 h", "7 d"];
for rowIndex = 1:nRows
	if rowSpecs(rowIndex,1) == "Naive", selfColor = TransferLearning.CurveNaive; else, selfColor = TransferLearning.CurveLearned; end
	rowColors = [selfColor; TransferLearning.Curve12h; TransferLearning.Curve7d] / 255;
	for columnIndex = 1:3
		ax = nexttile(layout, (rowIndex-1)*3 + columnIndex); hold(ax, 'on');
		values = rowStats{rowIndex}.curves{columnIndex};
		meanCurve = mean(values, 1, 'omitnan');
		semCurve = std(values, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(values), 1));
		iShadedError(ax, tVec, meanCurve, semCurve, rowColors(columnIndex,:));
		yline(ax, 0.5, ':', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
		xline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
		if rowIndex == 1, title(ax, columnNames(columnIndex), 'FontWeight', 'normal'); end
		if columnIndex == 1, ylabel(ax, rowSpecs(rowIndex,3)); else, ax.YAxis.Visible = 'off'; end
		if rowIndex < nRows, ax.XAxis.Visible = 'off'; end
		legend(ax, 'off'); ax.Color = 'none'; box(ax, 'off');
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
		axesHandles(rowIndex, columnIndex) = ax;
	end
end
xlabel(layout, 'Time from cue onset (s)'); ylabel(layout, 'P(post)');
TransferLearning.ApplyStandardExportStyle(fig, 1);
MATLAB.Graphics.UnifyAxesLims(axesHandles(:), @xlim, @ylim);
svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(fig, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);
Stats = struct('rows', {rowStats}, 'rowSpecs', rowSpecs, 'tVec', tVec, 'figure', fig, 'axes', axesHandles, 'svgPath', svgPath, 'PostDuration', PostDuration);
end

function iShadedError(ax, x, meanCurve, semCurve, color)
x = x(:)'; meanCurve = meanCurve(:)'; semCurve = semCurve(:)';
valid = isfinite(meanCurve) & isfinite(semCurve);
x = x(valid); meanCurve = meanCurve(valid); semCurve = semCurve(valid);
fill(ax, [x fliplr(x)], [meanCurve+semCurve fliplr(meanCurve-semCurve)], color, 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, meanCurve, '-', 'Color', color, 'LineWidth', 1.2, 'DisplayName', 'P(post)');
end