function [fig, stats] = PlotSigmoidLearningCurvePanels(performanceA, performanceB, fitNameA, fitNameB, displayNameA, displayNameB, options)
arguments
	performanceA (:, :) double
	performanceB (:, :) double
	fitNameA {mustBeTextScalar} = "Naive"
	fitNameB {mustBeTextScalar} = "Transfer"
	displayNameA {mustBeTextScalar} = fitNameA
	displayNameB {mustBeTextScalar} = fitNameB
	options.FigureName {mustBeTextScalar} = "Sigmoid learning curve"
	options.FigureSizeCm (1, 2) double {mustBePositive} = [12, 8]
	options.Scale (1, 1) double {mustBePositive} = 2
	options.CurveColor (1, 3) double = [0, 0, 0]
	options.ShowLegend (1, 1) logical = true
	options.LegendPanel {mustBeTextScalar} = "B"
	options.NPermutation (1, 1) double {mustBeNonnegative, mustBeInteger} = 0
	options.RngSeed = []
end

stats = TransferLearning.THModel.CompareSigmoidSlope(performanceA, performanceB, fitNameA, fitNameB, options.NPermutation, options.RngSeed);
summary = iLearningCurveSummary(performanceA, performanceB);
xFit = (1:max([size(performanceA, 2), size(performanceB, 2)])).';
fitCurveA = iSigmoidFromFit(stats.FitA, xFit);
fitCurveB = iSigmoidFromFit(stats.FitB, xFit);

fig = figure('Color', 'w', 'Name', char(options.FigureName));
fig.Units = 'centimeters';
fig.Position(3:4) = options.FigureSizeCm;
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');

axA = nexttile(layout, 1);
iPlotPanel(axA, xFit, summary.Mean(:, 1), summary.Sem(:, 1), fitCurveA, options.CurveColor, displayNameA, stats.FitA, options.ShowLegend && strcmpi(string(options.LegendPanel), "A"));

axB = nexttile(layout, 2);
iPlotPanel(axB, xFit, summary.Mean(:, 2), summary.Sem(:, 2), fitCurveB, options.CurveColor, displayNameB, stats.FitB, options.ShowLegend && strcmpi(string(options.LegendPanel), "B"));

ylabel(axA, 'Hit rate', 'FontSize', 12);
xlabel(layout, 'Block', 'FontSize', 12);
ylabel(axB, '');
axB.YAxis.Visible = 'off';

iHideAxesToolbars(fig);
TransferLearning.Style.ApplyStandardFigureStyle(fig, options.Scale);
axB.YAxis.Visible = 'off';

stats.SummaryTable = table(xFit, summary.Mean(:, 1), summary.Mean(:, 2), summary.Sem(:, 1), summary.Sem(:, 2), summary.N(:, 1), summary.N(:, 2), fitCurveA, fitCurveB, ...
	'VariableNames', {'Block','MeanA','MeanB','SemA','SemB','NA','NB','SigmoidA','SigmoidB'});
stats.DisplayNames = string([displayNameA; displayNameB]);
end

function summary = iLearningCurveSummary(performanceA, performanceB)
numSessions = max(size(performanceA, 2), size(performanceB, 2));
summary.Mean = nan(numSessions, 2);
summary.Sem = nan(numSessions, 2);
summary.N = nan(numSessions, 2);
[summary.Mean(:, 1), summary.Sem(:, 1), summary.N(:, 1)] = iOneCurveSummary(performanceA, numSessions);
[summary.Mean(:, 2), summary.Sem(:, 2), summary.N(:, 2)] = iOneCurveSummary(performanceB, numSessions);
end

function [meanCurve, semCurve, nCurve] = iOneCurveSummary(performanceMatrix, numSessions)
meanCurve = nan(numSessions, 1);
semCurve = nan(numSessions, 1);
nCurve = nan(numSessions, 1);
for sessionIndex = 1:size(performanceMatrix, 2)
	values = performanceMatrix(:, sessionIndex);
	values = values(isfinite(values));
	nCurve(sessionIndex) = numel(values);
	if isempty(values)
		continue;
	end
	meanCurve(sessionIndex) = mean(values, 'omitnan');
	if numel(values) < 2
		semCurve(sessionIndex) = 0;
	else
		semCurve(sessionIndex) = std(values, 0, 'omitnan') / sqrt(numel(values));
	end
end
end

function y = iSigmoidFromFit(fitStruct, x)
y = fitStruct.Lower + (fitStruct.Upper - fitStruct.Lower) ./ (1 + exp(-fitStruct.Slope .* (x - fitStruct.Midpoint)));
end

function iPlotPanel(ax, blockX, meanCurve, semCurve, fitCurve, lineColor, groupName, fitStruct, showLegend)
hold(ax, 'on');
ax.FontSize = 12;
blockX = double(blockX(:));
meanCurve = double(meanCurve(:));
semCurve = double(semCurve(:));
rows = isfinite(blockX) & isfinite(meanCurve);
semCurve(~isfinite(semCurve)) = 0;
dataHandle = errorbar(ax, blockX(rows), meanCurve(rows), semCurve(rows), semCurve(rows), 'o', ...
	'LineStyle', 'none', ...
	'Color', lineColor, ...
	'MarkerEdgeColor', lineColor, ...
	'MarkerFaceColor', 'w', ...
	'MarkerSize', 3, ...
	'LineWidth', 0.5, ...
	'CapSize', 5);
fitHandle = plot(ax, blockX, fitCurve, '-', 'Color', lineColor, 'LineWidth', 2.8);
if showLegend && isgraphics(dataHandle)
	legendHandle = legend(ax, [dataHandle, fitHandle], {'Mean ± SEM', 'Sigmoid fit'}, 'Location', 'southwest');
	legendHandle.FontSize = 9;
	legendHandle.Box = 'off';
	legendHandle.NumColumns = 1;
else
	legend(ax, 'off');
end
box(ax, 'off');
grid(ax, 'off');
ylim(ax, [0, 1]);
xlim(ax, [min(blockX), max(blockX)]);
title(ax, {char(string(groupName)), sprintf('slope=%.3f', fitStruct.Slope)}, 'FontSize', 10, 'FontWeight', 'normal');
end

function iHideAxesToolbars(fig)
allAxes = findall(fig, 'Type', 'axes');
for ax = reshape(allAxes, 1, [])
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end
end
