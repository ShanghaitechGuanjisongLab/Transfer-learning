% English Fig4E: response heterogeneity across Naive / 12 h / 7 d cohorts, split by cortical layer.
% Mimics the 2-D grouped BarScatterCompare style used by Fig3E_DelayedVsUndelayed_DivergenceBarsByLayer.
% Data source / definition: AnalyzeLearningSpeedMetricsComplete.m and
% TransferLearning.Metrics.ResponseHeterogeneity (per-mouse SD of cell response z@cue+1s).
%
% Layout: one 2-D grouped table; rows = layer (MOp2/3, MOp5), columns = cohort (Naive, 12 h, 7 d).
% Within each layer, BarScatterCompare tests all three pairwise cohort contrasts by Mann-Whitney rank-sum.
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

% For each layer compare Naive-12h, Naive-7d and 12h-7d.
pairs = ["Naive", "12 h"; "Naive", "7 d"; "12 h", "7 d"];
layerPair = [repmat(layers(1), 3, 2); repmat(layers(2), 3, 2)];
cohortPair = [pairs; pairs];
GroupPair = table(layerPair, cohortPair, 'VariableNames', {'Layer', 'Cohort'});
compareGroup = table(GroupPair);
colors = [TransferLearning.ColorNaive; TransferLearning.Color12h; TransferLearning.Color7d] / 255;
colorTable = array2table(colors, 'VariableNames', {'R', 'G', 'B'}, 'RowNames', cellstr(cohorts));

fprintf('=== Response heterogeneity by layer: Naive / 12 h / 7 d ===\n');
for iL = 1:numel(layers)
	for iG = 1:numel(cohorts)
		x = H.SD(H.Layer == layers(iL) & H.Group == cohorts(iG));
		fprintf('%-7s %-6s n=%2d mean=%.3f median=%.3f\n', layers(iL), cohorts(iG), numel(x), mean(x), median(x));
	end
end

f = figure('Color', 'w', 'Name', 'English Fig4E heterogeneity by layer Naive 12h 7d');
f.Units = 'centimeters';
f.Position(3:4) = [11, 7];
ax = axes(f);
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, ...
	colorTable, ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iStyleBars(ax, barHandles, errorBars, colors);

legendHandle = optional.Legend;
legendHandle.String = cellstr(cohorts);
legendHandle.Title.String = 'Cohort';
legendHandle.Title.FontWeight = 'normal';
legendHandle.Location = 'northoutside';
legendHandle.Orientation = 'horizontal';
legendHandle.Box = 'off';
xlabel(ax, 'Layer');
ylabel(ax, 'Response heterogeneity (SD)');
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end

iRetunePValueLines(optional);
TransferLearning.ApplyStandardExportStyle(f, 2);

% Keep error-bar caps visually consistent after standard styling / P-line layout.
iUnifyErrorBarCapSizes(ax, barHandles, errorBars, 0.5);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig4E_HeterogeneityByLayer_Naive12h7d.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

% Export exact plotted values and pairwise p-values for reproducibility.
assignin('base', 'Fig4E_HeterogeneityPerMouse', H);
assignin('base', 'Fig4E_HeterogeneityGroupTests', optional.MultiCompare);

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

function iUnifyErrorBarCapSizes(ax, barHandles, errorBars, capSizeRatio)
axUnits = ax.Units;
ax.Units = 'points';
axWidth = ax.Position(3);
ax.Units = axUnits;
barWidth = barHandles(1).BarWidth;
groupWidth = barHandles(1).GroupWidth;
xRange = diff(xlim(ax));
nBars = numel(barHandles);
capSize = axWidth * barWidth * groupWidth * capSizeRatio / (xRange * nBars);
for iRow = 1:height(errorBars)
	eBar = errorBars.Object(iRow);
	if isgraphics(eBar) && isprop(eBar, 'CapSize'), eBar.CapSize = capSize; end
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
