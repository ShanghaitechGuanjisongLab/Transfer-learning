function [fig, PlotData] = PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData, options)
arguments
	HeatmapData (1, 1) struct
	options.YLabel {mustBeTextScalar} = ""
	options.ColorbarLabel {mustBeTextScalar} = "ΔF"
	options.FigureName {mustBeTextScalar} = "Model first formal unit decision heatmap"
end

if isfield(HeatmapData, 'ConditionData')
	laneData = cat(3, HeatmapData.ConditionData{1}.MedianDelta, HeatmapData.ConditionData{2}.MedianDelta);
else
	laneData = cat(3, HeatmapData.Naive.MedianDelta, HeatmapData.Continual.MedianDelta);
end
sortedLaneData = nan(size(laneData));
sortIndex = nan(size(laneData, 1), size(laneData, 3));
sortKey = nan(size(laneData, 1), size(laneData, 3));
for conditionIndex = 1:size(laneData, 3)
	conditionLaneData = laneData(:, :, conditionIndex);
	conditionLaneDataForSort = conditionLaneData;
	conditionLaneDataForSort(~isfinite(conditionLaneDataForSort)) = 0;
	conditionSortKey = trapz(HeatmapData.Iterations, conditionLaneDataForSort, 2);
	conditionSortKey(~isfinite(conditionSortKey)) = -inf;
	[~, conditionSortIndex] = sort(conditionSortKey, 'descend');
	sortedLaneData(:, :, conditionIndex) = conditionLaneData(conditionSortIndex, :);
	sortIndex(:, conditionIndex) = conditionSortIndex;
	sortKey(:, conditionIndex) = conditionSortKey;
end
laneData = sortedLaneData;

negativeValue = min(laneData, [], 'all', 'omitnan');
positiveValue = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negativeValue)
	negativeValue = -1;
end
if ~isfinite(positiveValue)
	positiveValue = 1;
end
colorLimitLowAbs = sqrt(abs(min(negativeValue, 0)));
colorLimitHighAbs = sqrt(abs(max(positiveValue, 0)));
colorLimits = [-colorLimitLowAbs, colorLimitHighAbs];

fig = figure('Color', 'w', 'Name', char(options.FigureName));
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 9, 8];
fig.PaperSize = [9, 8];

layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'none', 'Padding', 'tight');
[~, axesList] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=HeatmapData.DisplayNames, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=colorLimits, ...
	Layout=layout, ...
	ImagescStyle={'XData', [HeatmapData.Iterations(1), HeatmapData.Iterations(end)]}, ...
	LMHColor=[0,0,1; 1,1,1; 1,0,0]);

xlabel(layout, 'Recurrent iterations', 'FontSize', 12);
if strlength(string(options.YLabel)) == 0
	yLabelText = sprintf('%d cells', size(laneData, 1));
else
	yLabelText = char(options.YLabel);
end
ylabel(layout, yLabelText, 'FontSize', 12);

colorbarHandle = colorbar;
colorbarHandle.Layout.Tile = 'east';
colorbarHandle.Label.String = char(options.ColorbarLabel);
colorbarHandle.Label.Interpreter = 'none';
colorbarHandle.FontSize = 12;
colorbarHandle.Label.FontSize = 12;
colorbarHandle.Box = 'off';

for axesIndex = 1:numel(axesList)
	ax = axesList(axesIndex);
	ax.FontSize = 12;
	ax.TickDir = 'in';
	box(ax, 'on');
	xline(ax, 0, ':k', 'LineWidth', 2);
	iSetCueTickLabel(ax);
	ax.LineWidth = 2;
	if isprop(ax, 'Title') && isgraphics(ax.Title)
		ax.Title.FontSize = 12;
		ax.Title.FontWeight = 'normal';
	end
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

PlotData = struct();
PlotData.LaneData = laneData;
PlotData.SortIndex = sortIndex;
PlotData.SortKey = sortKey;
PlotData.CLim = colorLimits;
PlotData.YLabel = string(yLabelText);
PlotData.ColorbarLabel = string(options.ColorbarLabel);
PlotData.Axes = axesList;
end

function iSetCueTickLabel(ax)
tickValues = ax.XTick;
tickLabels = string(ax.XTickLabel);
if numel(tickLabels) ~= numel(tickValues)
	tickLabels = string(tickValues);
end
zeroTickIndex = find(abs(tickValues) <= 10 * eps(max(1, max(abs(tickValues)))), 1);
if isempty(zeroTickIndex)
	return;
end
tickLabels(zeroTickIndex) = "Cue";
ax.XTickLabel = cellstr(tickLabels);
end
