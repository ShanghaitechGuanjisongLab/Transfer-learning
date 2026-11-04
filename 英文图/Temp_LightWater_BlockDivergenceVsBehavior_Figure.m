% English Fig4C: LightWater and AudioWater initial learning, all-cell block divergence.
% Run the LightWater and AudioWater block-divergence probes first.
% Thin gray lines connect repeated blocks within each mouse. The dark lines
% and ribbons are population mixed-effects estimates and 95% CIs.

if ~exist('LightWaterBlockDivergence', 'var') || ~exist('LightWaterBlockDivergenceModels', 'var') || ...
		~exist('AudioWaterBlockDivergence', 'var') || ~exist('AudioWaterBlockDivergenceModel', 'var')
	error('BlockDivergenceFigure:MissingResults', ...
		'Run both LightWater and AudioWater block-divergence probes first.');
end
newX = linspace(0, 1, 101)';
[TrendL, CIL] = iPopulationTrend(LightWaterBlockDivergence, ...
	LightWaterBlockDivergenceModels.DivergenceAll, "LAB", newX);
[TrendA, CIA] = iPopulationTrend(AudioWaterBlockDivergence, ...
	AudioWaterBlockDivergenceModel, "ALB", newX);
assert(all(isfinite(TrendL)) && all(isfinite(CIL), 'all'), ...
	'LightWater trend prediction contains NaN or Inf.');
assert(all(isfinite(TrendA)) && all(isfinite(CIA), 'all'), ...
	'AudioWater trend prediction contains NaN or Inf.');
statL = LightWaterBlockDivergenceStats;
statL = statL(statL.Measure == "All cells", :);
statA = AudioWaterBlockDivergenceStats;

f = figure('Color', 'w', 'Name', 'English Fig4C LightWater and AudioWater learning divergence');
f.Units = 'centimeters';
f.Position(3:4) = [14, 8];
f.PaperPositionMode = 'auto';
f.PaperUnits = 'centimeters';
f.PaperSize = [14, 8];
tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tlo, 'Behavioral performance');
ylabel(tlo, 'All-cell divergence');
axL = nexttile(tlo);
iPlotTile(axL, LightWaterBlockDivergence, newX, TrendL, CIL, 'LightWater: Naive to Learned', ...
	statL.MedianWithinRho, statL.WilcoxonP);
axA = nexttile(tlo);
iPlotTile(axA, AudioWaterBlockDivergence, newX, TrendA, CIA, 'AudioWater: Naive to Learned', ...
	statA.MedianWithinRho, statA.WilcoxonP);
validL = LightWaterBlockDivergence.DivergenceAll(LightWaterBlockDivergence.Status == "OK");
validA = AudioWaterBlockDivergence.DivergenceAll(AudioWaterBlockDivergence.Status == "OK");
yMax = ceil(max([validL; validA; CIL(:); CIA(:)]));
yLimit = [0, yMax];
linkaxes([axL, axA], 'xy');
ylim([axL, axA], yLimit);
yticks([axL, axA], 0:2:yMax);
legend(axL, 'Location', 'southoutside', 'Box', 'off');
legend(axA, 'off');

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig4C_LightWater_AudioWater_BlockDivergence.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

function [yFit, yCI] = iPopulationTrend(T, model, referenceSource, newX)
use = isfinite(T.Performance) & isfinite(T.DivergenceAll) & T.DivergenceAll > 0;
T = T(use, :);
T.Mouse = categorical(T.Mouse);
T.Source = categorical(T.Source);
mouseLevels = categories(T.Mouse);
newTbl = table(newX, repmat(mouseLevels(1), numel(newX), 1), ...
	'VariableNames', {'Performance','Mouse'});
newTbl.Mouse = categorical(newTbl.Mouse, mouseLevels);
if strlength(referenceSource) > 0
	newTbl.Source = repmat(referenceSource, numel(newX), 1);
	newTbl.Source = categorical(newTbl.Source);
end
[yLog, yLogCI] = predict(model, newTbl, 'Conditional', false);
yFit = exp(yLog);
yCI = exp(yLogCI);
end

function iPlotTile(ax, T, newX, yFit, yCI, tileTitle, rho, p)
use = isfinite(T.Performance) & isfinite(T.DivergenceAll) & T.DivergenceAll > 0;
T = T(use, :);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
fill(ax, [newX; flipud(newX)], [yCI(:, 1); flipud(yCI(:, 2))], [0.35, 0.35, 0.35], ...
	'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
for mouse = unique(T.Mouse)'
	R = T(T.Mouse == mouse, :);
	R = sortrows(R, 'Performance');
	hLine = plot(ax, R.Performance, R.DivergenceAll, '-o', 'Color', [0.65, 0.65, 0.65], ...
		'MarkerFaceColor', 'w', 'MarkerSize', 2.6, 'LineWidth', 0.65, ...
		'HandleVisibility', 'off');
	setappdata(hLine, 'TransferLearningPreserveLineWidth', true);
end
hFit = plot(ax, newX, yFit, '-', 'Color', TransferLearning.ColorA, 'LineWidth', 2);
setappdata(hFit, 'TransferLearningPreserveLineWidth', true);
title(ax, tileTitle);
xticks(ax, 0:0.5:1);
xlim(ax, [0, 1]);
legend(ax, hFit, {'Mixed-effects trend'}, 'Location', 'southoutside', 'Box', 'off');
text(ax, 0.97, 0.97, sprintf('Within-mouse median \\rho = %.2f\nSigned-rank p = %.4f', ...
	rho, p), 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
end
