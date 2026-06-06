function fig = PlotPreFormalConnectionWeightDistributions(WeightValues)
arguments
	WeightValues (1, 1) struct
end

classNames = ["EE", "EI", "IE", "II"];
classTitles = ["E→E", "E→I", "I→E", "I→I"];
legendLabels = {'Naive', 'After pretrain'};
groupColors = TransferLearning.GroupColors(["Naive", "Learned"]);
naiveColor = groupColors(1, :);
afterPretrainColor = groupColors(2, :);
binEdges = iSharedBinEdges(WeightValues, classNames);

fig = figure('Color', 'w', 'Name', 'Fig54A pre-formal connection weight distributions');
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 9, 8];
fig.PaperSize = [9, 8];

layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
axesGrid = gobjects(2, 2);
legendHandles = gobjects(2, 1);

for classIndex = 1:numel(classNames)
	rowIndex = ceil(classIndex / 2);
	columnIndex = mod(classIndex - 1, 2) + 1;
	ax = nexttile(layout, classIndex);
	axesGrid(rowIndex, columnIndex) = ax;
	hold(ax, 'on');
	className = classNames(classIndex);
	naiveValues = WeightValues.Naive.(className);
	afterPretrainValues = WeightValues.AfterPretrain.(className);
	hNaive = histogram(ax, naiveValues, binEdges, 'Normalization', 'probability', ...
		'DisplayStyle', 'bar', 'FaceColor', naiveColor, 'FaceAlpha', 0.48, ...
		'EdgeColor', 'none');
	hAfterPretrain = histogram(ax, afterPretrainValues, binEdges, 'Normalization', 'probability', ...
		'DisplayStyle', 'bar', 'FaceColor', afterPretrainColor, 'FaceAlpha', 0.48, ...
		'EdgeColor', 'none');
	ax.YScale = 'log';
	if classIndex == 1
		legendHandles = [hNaive; hAfterPretrain];
	end
	title(ax, classTitles(classIndex), 'FontWeight', 'normal');
	box(ax, 'off');
	grid(ax, 'off');
end

MATLAB.Graphics.UnifyAxesLims(axesGrid(:), @xlim, @ylim);

for columnIndex = 1:2
	axesGrid(1, columnIndex).XAxis.Visible = 'off';
end
for rowIndex = 1:2
	axesGrid(rowIndex, 2).YAxis.Visible = 'off';
end

xlabel(layout, 'Connection weight');
ylabel(layout, 'Probability');
legendObject = legend(axesGrid(1, 1), legendHandles, legendLabels, ...
	'Orientation', 'horizontal', 'Box', 'off');
legendObject.Layout.Tile = 'north';
end

function binEdges = iSharedBinEdges(WeightValues, classNames)
valueCells = cell(2 * numel(classNames), 1);
for classIndex = 1:numel(classNames)
	className = classNames(classIndex);
	valueCells{2 * classIndex - 1} = WeightValues.Naive.(className)(:);
	valueCells{2 * classIndex} = WeightValues.AfterPretrain.(className)(:);
end
allValues = vertcat(valueCells{:});
[~, binEdges] = histcounts(allValues);
end
