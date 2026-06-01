% Fig63D model-simulated Normal/TH inhibited learning curve with sigmoid fits.

svgName = '中文图Fig63D_ModelContinualTHInhibitedLearningCurve.svg';
iEnsureTransferLearningProject();

run(fullfile(fileparts(mfilename('fullpath')), 'Fig5556_LoadSharedModelData.m'));
RunInfo = Fig5556Data.RunInfo;
normalPerformance = Fig5556Data.Performance.Transfer;
thInhibitedPerformance = Fig5556Data.Performance.THOff;
SigmoidStats = Fig5556Data.Sigmoid.Fig383D;
summary = iLearningCurveSummary(normalPerformance, thInhibitedPerformance);
xSummary = (1:size(summary.Mean, 1)).';
xFit = linspace(1, max(xSummary), 200).';
normalFitCurve = iSigmoidFromFit(SigmoidStats.FitA, xFit);
thInhibitedFitCurve = iSigmoidFromFit(SigmoidStats.FitB, xFit);
curveColors = [TransferLearning.ContinualColor; TransferLearning.ColorB];

fig = figure('Color', 'w', 'Name', 'Fig63D model Normal TH inhibited sigmoid');
fig.Units = 'centimeters';
fig.Position(3:4) = [12, 8];
fig.PaperUnits = 'centimeters';
fig.PaperSize = [12, 8];
fig.PaperPositionMode = 'auto';
ax = axes(fig);
hold(ax, 'on');
hNormal = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, summary.Mean(:, 1), summary.Sem(:, 1), xFit, normalFitCurve, curveColors(1, :));
hTH = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, summary.Mean(:, 2), summary.Sem(:, 2), xFit, thInhibitedFitCurve, curveColors(2, :));

ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Block', 'FontSize', 12);
xlim(ax, [0.5, max(xSummary) + 0.5]);
ylim(ax, [0, 1.02]);
ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
ax.YTick = 0:0.5:1;
ax.XTick = unique([1, 5:5:ceil(max(xSummary))]);
box(ax, 'off');
grid(ax, 'off');
title(ax, '');

lgd = legend(ax, [hNormal(1), hNormal(2), hTH(1), hTH(2)], ...
	{'Normal Mean ± SEM', 'Normal Sigmoid', 'TH inhibited Mean ± SEM', 'TH inhibited Sigmoid'}, ...
	'Location', 'southoutside', 'NumColumns', 2);
lgd.Box = 'off';
lgd.FontSize = 10;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

iPrintPermutationResult('Fig63D', SigmoidStats);

svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig63D_ModelNormalTHInhibitedPerformance', struct('Normal', normalPerformance, 'THInhibited', thInhibitedPerformance));
assignin('base', 'Fig63D_ModelNormalTHInhibitedRunInfo', RunInfo);
assignin('base', 'Fig63D_ModelNormalTHInhibitedSigmoidStats', SigmoidStats);
assignin('base', 'Fig63D_ModelNormalTHInhibitedSvgPath', svgPath);

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
