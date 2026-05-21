function [fig, PlotData] = PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData)
arguments
	HeatmapData (1, 1) struct
end

if isfield(HeatmapData, 'ConditionData')
	laneData = cat(3, HeatmapData.ConditionData{1}.MedianZ, HeatmapData.ConditionData{2}.MedianZ);
else
	laneData = cat(3, HeatmapData.Naive.MedianZ, HeatmapData.Continual.MedianZ);
end
sortKey = squeeze(max(max(laneData, [], 2, 'omitnan'), [], 3, 'omitnan'));
sortKey(~isfinite(sortKey)) = -inf;
[~, sortIndex] = sort(sortKey, 'descend');
laneData = laneData(sortIndex, :, :);

negValue = min(laneData, [], 'all', 'omitnan');
posValue = max(laneData, [], 'all', 'omitnan');
if ~isfinite(negValue)
	negValue = -1;
end
if ~isfinite(posValue)
	posValue = 1;
end
climLowAbs = sqrt(abs(min(negValue, 0)));
climHighAbs = sqrt(abs(max(posValue, 0)));
colorLimits = [-climLowAbs, climHighAbs];

fig = figure('Color', 'w', 'Name', 'Model first formal unit decision heatmap');
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 9, 8];
fig.PaperSize = [9, 8];

layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
[~, axesList] = UniExp.LanearHeatmap( ...
	laneData, ...
	SubTitles=HeatmapData.DisplayNames, ...
	Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
	CLim=colorLimits, ...
	Layout=layout, ...
	ImagescStyle={'XData', [HeatmapData.Iterations(1), HeatmapData.Iterations(end)]}, ...
	LMHColor=[0,0,1; 1,1,1; 1,0,0]);

xlabel(layout, 'Recurrent iterations', 'FontSize', 12);
ylabel(layout, sprintf('%d cells', size(laneData, 1)), 'FontSize', 12);

colorbarHandle = colorbar;
colorbarHandle.Layout.Tile = 'east';
colorbarHandle.Label.String = 'z-score';
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
