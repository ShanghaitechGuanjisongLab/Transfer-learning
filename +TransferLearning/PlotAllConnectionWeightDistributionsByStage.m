function fig = PlotAllConnectionWeightDistributionsByStage(StageWeightValues)
arguments
	StageWeightValues (1, 1) struct
end

if ~all(isfield(StageWeightValues, {'Naive', 'PretrainFirstBlock', 'AfterPretrain'}))
	error('TransferLearning:MissingStageField', 'StageWeightValues must contain Naive, PretrainFirstBlock, and AfterPretrain fields.');
end

naiveColor = TransferLearning.NaiveColor;
afterPretrainColor = TransferLearning.LearnedColor;
pretrainFirstBlockColor = (naiveColor + afterPretrainColor) / 2;
stageNames = ["Naive", "After 1 block", "After 8 blocks"];
stageFields = ["Naive", "PretrainFirstBlock", "AfterPretrain"];
stageColors = [naiveColor; pretrainFirstBlockColor; afterPretrainColor];

allValues = [StageWeightValues.Naive(:); StageWeightValues.PretrainFirstBlock(:); StageWeightValues.AfterPretrain(:)];
allValues = allValues(isfinite(allValues));
if isempty(allValues)
	error('TransferLearning:NoFiniteWeightValues', 'No finite weight values are available for plotting.');
end
robustRange = prctile(allValues, [0.5, 99.5]);
xLow = robustRange(1);
xHigh = robustRange(2);
if ~(isfinite(xLow) && isfinite(xHigh) && xLow < xHigh)
	xLow = min(allValues);
	xHigh = max(allValues);
end
binEdges = xLow:0.25:xHigh;
if binEdges(end) < xHigh
	binEdges(end + 1) = binEdges(end) + 0.25;
end

fig = figure('Color', 'w', 'Name', 'Fig54 all-connection weight distributions by stage');
fig.Units = 'centimeters';
fig.Position(3:4) = [6, 4];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 6, 4];
fig.PaperSize = [6, 4];

layout = tiledlayout(fig, 1, 3, 'TileSpacing', 'none', 'Padding', 'tight');
axesArray = gobjects(3, 1);

for stageIndex = 1:3
	ax = nexttile(layout, stageIndex);
	axesArray(stageIndex) = ax;
	hold(ax, 'on');
	stageField = stageFields(stageIndex);
	stageValues = StageWeightValues.(stageField);
	stageValues = stageValues(isfinite(stageValues));
	% Keep all values in the histogram while preventing a few outliers from collapsing the x-axis.
	stageValues = min(max(stageValues, xLow), xHigh);
	[allCounts, ~] = histcounts(stageValues, binEdges);
	negValues = stageValues(stageValues < 0);
	nonNegValues = stageValues(stageValues >= 0);
	negCounts = histcounts(negValues, binEdges);
	nonNegCounts = histcounts(nonNegValues, binEdges);
	denom = sum(allCounts);
	binCenters = binEdges(1:end-1) + diff(binEdges) / 2;
	if denom > 0
		if ~isempty(negValues)
			bar(ax, binCenters, negCounts / denom, 1, 'FaceColor', stageColors(stageIndex, :), ...
				'FaceAlpha', 0.4, 'EdgeColor', 'none');
		end
		if ~isempty(nonNegValues)
			bar(ax, binCenters, nonNegCounts / denom, 1, 'FaceColor', stageColors(stageIndex, :), ...
				'FaceAlpha', 1, 'EdgeColor', 'none');
		end
	end
	xline(ax, 0, '--', 'LineWidth', 0.5, 'Color', [0.4 0.4 0.4]);
	ax.YScale = 'linear';
	title(ax, stageNames(stageIndex), 'FontWeight', 'normal');
	box(ax, 'off');
	grid(ax, 'off');
end

MATLAB.Graphics.UnifyAxesLims(axesArray, @xlim, @ylim);
for stageIndex = 2:3
	axesArray(stageIndex).YAxis.Visible = 'off';
end

xlabel(layout, 'Connection weight (negative: not connected)');
ylabel(layout, 'Probability');
title(layout,'Weight update example');
end
