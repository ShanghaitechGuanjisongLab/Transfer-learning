% Fig54C model-simulated Naive/Continual learning curve with sigmoid fits.

svgName = '中文图Fig54C_ModelNaiveContinualLearningCurve.svg';
iEnsureTransferLearningProject();

run(fullfile(fileparts(mfilename('fullpath')), 'Fig5556_LoadSharedModelData.m'));
Params = Fig5556Data.Params;
RunInfo = Fig5556Data.RunInfo;
naivePerformance = Fig5556Data.Performance.Naive;
continualPerformance = Fig5556Data.Performance.Transfer;
SigmoidStats = Fig5556Data.Sigmoid.Fig54C;

summary = iLearningCurveSummary(naivePerformance, continualPerformance);
xSummary = (1:size(summary.Mean, 1)).';
xFit = linspace(1, max(xSummary), 200).';
naiveFitCurve = iSigmoidFromFit(SigmoidStats.FitA, xFit);
continualFitCurve = iSigmoidFromFit(SigmoidStats.FitB, xFit);
curveColors = TransferLearning.GroupColors(["Naive", "Continual"]);
anovaTable = iBuildGroupAnovaTableFromMatrices(naivePerformance, continualPerformance, ["Naive", "Continual"]);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(anovaTable, 'Performance', 'Block', 'Group', 'Mouse');

fig = figure('Color', 'w', 'Name', 'Fig54C model Naive Continual sigmoid');
fig.Units = 'centimeters';
fig.Position(3:4) = [12, 8];
fig.PaperUnits = 'centimeters';
fig.PaperSize = [12, 8];
fig.PaperPositionMode = 'auto';
ax = axes(fig);
hold(ax, 'on');
hNaive = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, summary.Mean(:, 1), summary.Sem(:, 1), xFit, naiveFitCurve, curveColors(1, :));
hContinual = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, summary.Mean(:, 2), summary.Sem(:, 2), xFit, continualFitCurve, curveColors(2, :));

ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Block', 'FontSize', 12);
ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
box(ax, 'off');
grid(ax, 'off');
title(ax, '');
naiveLastIndex = find(isfinite(summary.Mean(:, 1)), 1, 'last');
continualLastIndex = find(isfinite(summary.Mean(:, 2)), 1, 'last');
naiveLast = summary.Mean(naiveLastIndex, 1);
continualLast = summary.Mean(continualLastIndex, 2);
yLow = min([naiveLast, continualLast], [], 'omitnan');
yHigh = max([naiveLast, continualLast], [], 'omitnan');
yBottom = yLow;
yTop = yHigh;
if yTop - yBottom < 0.2
	yMid = mean([yBottom, yTop], 'omitnan');
	yBottom = yMid - 0.1;
	yTop = yMid + 0.1;
end
TransferLearning.Style.AddRightSidePValueLine(ax, max(xSummary), yBottom, yTop, groupP);

lgd = legend(ax, [hNaive(1), hNaive(2), hContinual(1), hContinual(2)], ...
	{'Naive Mean ± SEM', 'Naive Sigmoid', 'Continual Mean ± SEM', 'Continual Sigmoid'}, ...
	'Location', 'southoutside', 'NumColumns', 2);
lgd.Box = 'off';
lgd.FontSize = 10;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

fprintf('Fig54C Two-way ANOVA Group P = %.4g\n', groupP);
iPrintPermutationResult('Fig54C', SigmoidStats);
iAssertSigmoidSlopeSignificant('Fig54C', SigmoidStats, Params.TransferHighestAlpha, fig);

svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig54C_ModelNaiveContinualPerformance', struct('Naive', naivePerformance, 'Continual', continualPerformance));
assignin('base', 'Fig54C_ModelNaiveContinualRunInfo', RunInfo);
assignin('base', 'Fig54C_ModelNaiveContinualSigmoidStats', SigmoidStats);

function summary = iLearningCurveSummary(performanceA, performanceB)
numSessions = max(size(performanceA, 2), size(performanceB, 2));
summary.Mean = nan(numSessions, 2);
summary.Sem = nan(numSessions, 2);
[summary.Mean(:, 1), summary.Sem(:, 1)] = iOneCurveSummary(performanceA, numSessions);
[summary.Mean(:, 2), summary.Sem(:, 2)] = iOneCurveSummary(performanceB, numSessions);
end

function [meanCurve, semCurve] = iOneCurveSummary(performanceMatrix, numSessions)
meanCurve = nan(numSessions, 1);
semCurve = nan(numSessions, 1);
for sessionIndex = 1:size(performanceMatrix, 2)
	values = performanceMatrix(:, sessionIndex);
	values = values(isfinite(values));
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

function hOut = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, meanVec, semVec, xFit, fitCurve, curveColor)
meanVec = double(meanVec);
semVec = double(semVec);
useObs = isfinite(meanVec);
xObs = xSummary(useObs);
meanObs = meanVec(useObs);
semObs = semVec(useObs);
semObs(~isfinite(semObs)) = 0;
hE = errorbar(ax, xObs, meanObs, semObs, 'o', 'Color', curveColor, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', curveColor, ...
	'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');
hP = plot(ax, xFit, fitCurve, '-', 'Color', curveColor, 'LineWidth', 2.2);
hOut = [hE, hP];
end

function iPrintPermutationResult(figureLabel, SigmoidStats)
comparison = SigmoidStats.ComparisonTable;
fprintf('%s permutation slope difference (%s): %.4f\n', figureLabel, comparison.Comparison(1), comparison.ObservedSlopeDifference(1));
fprintf('%s permutation two-sided p = %.4g (%d permutations)\n', figureLabel, comparison.PValueTwoSided(1), comparison.NPermutation(1));
end

function iAssertSigmoidSlopeSignificant(figureLabel, SigmoidStats, alpha, fig)
comparison = SigmoidStats.ComparisonTable;
observedDifference = comparison.ObservedSlopeDifference(1);
pValue = comparison.PValueTwoSided(1);
if observedDifference > 0 && pValue < alpha
	return;
end
if isgraphics(fig)
	close(fig);
end
error('Fig54C:SigmoidSlopeNotSignificant', ...
	'%s requires Transfer sigmoid slope to be significantly greater than Naive (alpha=%.3f). %s observed difference=%.4f, two-sided permutation p=%.4g.', ...
	figureLabel, alpha, char(comparison.Comparison(1)), observedDifference, pValue);
end

function iEnsureTransferLearningProject()
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end
end

function T = iBuildGroupAnovaTableFromMatrices(performanceA, performanceB, groupNames)
[mouseA, blockA] = ndgrid(1:size(performanceA, 1), 1:size(performanceA, 2));
[mouseB, blockB] = ndgrid(1:size(performanceB, 1), 1:size(performanceB, 2));
resp = [performanceA(:); performanceB(:)];
block = [blockA(:); blockB(:)];
group = [repmat(groupNames(1), numel(performanceA), 1); repmat(groupNames(2), numel(performanceB), 1)];
mouse = [compose("Naive%03d", mouseA(:)); compose("Continual%03d", mouseB(:))];
T = table(resp, block, group, mouse, 'VariableNames', {'Performance','Block','Group','Mouse'});
end
