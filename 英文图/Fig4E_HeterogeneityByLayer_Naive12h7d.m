% English Fig4E: response heterogeneity across Naive / 12 h / 7 d cohorts, split by cortical layer.
% Mimics the 2-D grouped BarScatterCompare style used by Fig3E_DelayedVsUndelayed_DivergenceBarsByLayer.
% Data source / definition: AnalyzeLearningSpeedMetricsComplete.m and
% TransferLearning.Metrics.ResponseHeterogeneity (per-mouse SD of cell response z@cue+1s).
%
% 上下两个 tile 分别比较 Naive-12 h、12 h-7 d；每个二维表的行是层，列是该 tile 的两个队列。
% 每个 tile 独立使用 BarScatterCompare 默认的完整 ANOVA 与多重比较，不比较 Naive-7 d。
% Colors are semantic constants ColorNaive/Color12h/Color7d (RGB 0-255, scaled to [0,1]).
%
% Input: Heterogeneity_PerMouse.csv from AnalyzeLearningSpeedMetricsComplete.m, in monthly output dir.
% Output: English_Fig4E_HeterogeneityByLayer_Naive12h7d.svg
%
% Keep this as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

csvPath = fullfile('\\Data-Server-2\个人数据', getenv('USERNAME'), ...
	char(datetime('now', 'Format', 'yyyyMM')), 'Heterogeneity_PerMouse.csv');
if ~isfile(csvPath)
	error('Fig4E:MissingData', 'Missing %s. Run AnalyzeLearningSpeedMetricsComplete.m first.', csvPath);
end
H = readtable(csvPath, 'TextType', 'string');
H.Group = string(H.Group);
H.Layer = string(H.Layer);
cohorts = ["Naive", "12 h", "7 d"];
layers = ["MOp2/3", "MOp5"];
H = H(ismember(H.Group, cohorts) & ismember(H.Layer, layers) & isfinite(H.SD), :);

% Validate one per-mouse value per cohort × layer and require at least two mice per cell.
[G, gName, lName] = findgroups(H.Group, H.Layer);
nPerCell = splitapply(@numel, H.SD, G);
for iL = 1:numel(layers)
	for iG = 1:numel(cohorts)
		use = H.Group == cohorts(iG) & H.Layer == layers(iL);
		n = sum(use);
		if n < 2
			error('Fig4E:InsufficientData', '%s / %s has only %d valid mice.', layers(iL), cohorts(iG), n);
		end
		if numel(unique(H.Mouse(use))) ~= n
			error('Fig4E:DuplicateMouseRow', '%s / %s contains duplicate mouse rows.', layers(iL), cohorts(iG));
		end
	end
end

% Rows encode Layer; the single table row contains one vector per cohort.
dataCell = cell(numel(layers), numel(cohorts));
for iL = 1:numel(layers)
	for iG = 1:numel(cohorts)
		dataCell{iL, iG} = H.SD(H.Layer == layers(iL) & H.Group == cohorts(iG));
	end
end
dataTable = cell2table(dataCell, 'VariableNames', cellstr(cohorts), 'RowNames', cellstr(layers));
dataTable.Properties.DimensionNames = {'Layer', 'Cohort'};

% 每层内保留两项以 12 h 为参照的队列比较。
pairs = ["Naive", "12 h"; "12 h", "7 d"];
colors = [TransferLearning.ColorNaive; TransferLearning.Color12h; TransferLearning.Color7d] / 255;

fprintf('=== Response heterogeneity by layer: Naive / 12 h / 7 d ===\n');
for iL = 1:numel(layers)
	for iG = 1:numel(cohorts)
		x = H.SD(H.Layer == layers(iL) & H.Group == cohorts(iG));
		fprintf('%-7s %-6s n=%2d mean=%.3f median=%.3f\n', layers(iL), cohorts(iG), numel(x), mean(x), median(x));
	end
end
%% 

f = figure('Color', 'w', 'Name', 'English Fig4E heterogeneity by layer Naive 12h 7d');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
axesHandles = gobjects(size(pairs, 1), 1);
barsByTile = cell(size(pairs, 1), 1);
errorsByTile = cell(size(pairs, 1), 1);
comparisonsByTile = cell(size(pairs, 1), 1);
for tileIndex = 1:size(pairs, 1)
	tileCohorts = pairs(tileIndex, :);
	[~, colorIndices] = ismember(tileCohorts, cohorts);
	tileColors = colors(colorIndices, :);
	tileData = dataTable(:, cellstr(tileCohorts));
	layerPair = [layers(:), layers(:)];
	cohortPair = repmat(tileCohorts, numel(layers), 1);
	GroupPair = table(layerPair, cohortPair, 'VariableNames', {'Layer', 'Cohort'});
	compareGroup = table(GroupPair);
	colorTable = array2table(tileColors, 'VariableNames', {'R', 'G', 'B'}, 'RowNames', cellstr(tileCohorts));
	ax = nexttile(layout, tileIndex);
	[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(tileData, compareGroup, colorTable, ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
	iStyleBars(ax, barHandles, errorBars, tileColors);
	box(ax, 'off');
	legendHandle = optional.Legend;
	legendHandle.String = cellstr(tileCohorts);
	legendHandle.Title.FontWeight = 'normal';
	legendHandle.Location = 'eastoutside';
	legendHandle.Box = 'off';
	if tileIndex == 1
		xticklabels(ax, {});
	end
	iRetunePValueLines(optional);
	axesHandles(tileIndex) = ax;
	barsByTile{tileIndex} = barHandles;
	errorsByTile{tileIndex} = errorBars;
	comparisonsByTile{tileIndex} = optional.MultiCompare;
	fprintf('\n%s - %s\n', tileCohorts(1), tileCohorts(2));
	disp(optional.MultiCompare(:, {'Layer', 'Cohort', 'PValue'}));
end
xlabel(layout, 'Layer');
ylabel(layout, 'Response heterogeneity');
title(layout, 'Transfer💡💧');
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(axesHandles, @xlim, @ylim);

% Keep error-bar caps visually consistent after standard styling / P-line layout.
iUnifyErrorBarCapSizes(axesHandles, barsByTile, errorsByTile, 0.5);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig4E_HeterogeneityByLayer_Naive12h7d.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ========== local functions ==========
function iStyleBars(ax, barHandles, errorBars, groupColors)
for iBar = 1:numel(barHandles)
	barHandles(iBar).LineStyle = 'none';
	barHandles(iBar).FaceColor = groupColors(iBar, :);
	if isprop(barHandles(iBar), 'BaseLine') && isgraphics(barHandles(iBar).BaseLine)
		barHandles(iBar).BaseLine.Visible = 'off';
	end
end
for iRow = 1:height(errorBars)
	eBar = errorBars.Object(iRow);
	if ~isgraphics(eBar), continue; end
	x = double(eBar.XData(1));
	bestDist = inf; bestColor = groupColors(1, :);
	for iBar = 1:numel(barHandles)
		xp = double(barHandles(iBar).XEndPoints(:));
		d = min(abs(xp - x));
		if d < bestDist
			bestDist = d; bestColor = barHandles(iBar).FaceColor;
		end
	end
	eBar.Color = bestColor;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end

function iUnifyErrorBarCapSizes(axList, barHandlesList, errorBarsList, capSizeRatio)
capSizes = nan(numel(axList), 1);
for tileIndex = 1:numel(axList)
	ax = axList(tileIndex);
	axUnits = ax.Units;
	ax.Units = 'points';
	axWidth = ax.Position(3);
	ax.Units = axUnits;
	barHandles = barHandlesList{tileIndex};
	barWidth = barHandles(1).BarWidth;
	groupWidth = barHandles(1).GroupWidth;
	xRange = diff(xlim(ax));
	nBars = numel(barHandles);
	capSizes(tileIndex) = axWidth * barWidth * groupWidth * capSizeRatio / (xRange * nBars);
end
capSize = mean(capSizes, 'omitnan');
for tileIndex = 1:numel(errorBarsList)
	errorBars = errorBarsList{tileIndex};
	for iRow = 1:height(errorBars)
		eBar = errorBars.Object(iRow);
		if isgraphics(eBar) && isprop(eBar, 'CapSize'), eBar.CapSize = capSize; end
	end
end
end

function iRetunePValueLines(optional)
if ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare) || ...
		~all(ismember({'PLine', 'PText'}, optional.MultiCompare.Properties.VariableNames))
	return;
end
MATLAB.Graphics.PLineRetune(optional.MultiCompare.PLine, optional.MultiCompare.PText);
for pLine = optional.MultiCompare.PLine(:)'
	if isgraphics(pLine)
		pLine.LineWidth = 1;
		pLine.Tag = 'PLine';
		setappdata(pLine, 'TransferLearningPreserveLineWidth', true);
	end
end
for pText = optional.MultiCompare.PText(:)'
	if isgraphics(pText), pText.Tag = 'PText'; end
end
end
