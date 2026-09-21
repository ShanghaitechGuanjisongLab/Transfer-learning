% English Fig5F: model-simulated Normal (Transfer) vs TH-inhibited learning
% curve with group-level sigmoid fits. Caliber copied from Chinese Fig63D: same
% shared model data, Transfer condition = Normal, THOff condition = simulated
% thalamic inhibition (TeachingSignalScale reduced). Group-level sigmoid fits +
% precomputed permutation slope comparison; reported statistic is the two-way
% ANOVA group effect over blocks 1-7.
%
% Claim: simulated thalamic inhibition lowers the learning slope, reproducing
% the in-vivo TH-inhibition result (Figure 4C).
%
% Outputs (SVG):
%   - English_Fig5F_ModelNormalTHInhibitedLearningCurve.svg   (legend -> Scale = 2)
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

svgName = "English_Fig5F_ModelNormalTHInhibitedLearningCurve.svg";

thisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

run(fullfile(thisDir, '..', '中文图', 'Fig5556_LoadSharedModelData.m'));
normalPerformance = Fig5556Data.Performance.Transfer;
thInhibitedPerformance = Fig5556Data.Performance.THOff;
SigmoidStats = Fig5556Data.Sigmoid.Fig383D;

summary = iLearningCurveSummary(normalPerformance, thInhibitedPerformance);
xSummary = (1:size(summary.Mean, 1)).';
xFit = linspace(max(0, min(xSummary) - 1), max(xSummary) + 1, 200).';
normalFitCurve = iSigmoidFromFit(SigmoidStats.FitA, xFit);
thInhibitedFitCurve = iSigmoidFromFit(SigmoidStats.FitB, xFit);
curveColors = [TransferLearning.TransferColor; TransferLearning.ColorB];
anovaTable = iBuildGroupAnovaTableFromMatrices(normalPerformance, thInhibitedPerformance, ["Normal", "TH"]);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(anovaTable, 'Performance', 'Block', 'Group', 'Mouse');
anovaTable7 = anovaTable(anovaTable.Block <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(anovaTable7, 'Performance', 'Block', 'Group', 'Mouse');

% ---------- figure ----------
% 规范：基础高 4 cm；有 legend 放大 ×2 → 8 cm；宽 12 cm（同 Fig5B/4C 英文样式）
f = figure('Color', 'w', 'Name', 'English Fig5F model Normal TH sigmoid');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax, 'on');
hNormal = iPlotGroupMeanErrorbars(ax, xSummary, summary.Mean(:, 1), summary.Sem(:, 1), xFit, normalFitCurve, curveColors(1, :));
hTH = iPlotGroupMeanErrorbars(ax, xSummary, summary.Mean(:, 2), summary.Sem(:, 2), xFit, thInhibitedFitCurve, curveColors(2, :));

ylabel(ax, 'Hit rate');
xlabel(ax, 'Block');
ax.Color = 'none';
box(ax, 'off');
grid(ax, 'off');

% blocks 1-7 组效应 P 值线（PLine_1/PText_1 tag 供导出重调线宽）
max7Normal = max(summary.Mean(1:min(7, end), 1), [], 'omitnan');
max7TH = max(summary.Mean(1:min(7, end), 2), [], 'omitnan');
yPLine = max(max7Normal, max7TH);
yl = ylim(ax);
yrange = yl(2) - yl(1);
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1, 'Tag', 'PLine_1', 'HandleVisibility', 'off');
textY = yPLine + 0.2 * yrange;
starStr = TransferLearning.Style.iFormatPText(groupP7);
text(ax, 4, textY, starStr, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Tag', 'PText_1', AffectAutoLimits = true);

xlim(ax, [0, size(summary.Mean, 1) + 1]);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

lgd = legend(ax, [hNormal(1), hTH(1)], {'Normal', 'TH inhibited'}, 'Location', 'southeast');
lgd.Box = 'off';
lgd.AutoUpdate = false;

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('=== English Fig5F model Normal vs TH-inhibited learning curve ===\n');
fprintf('Normal sigmoid:    slope=%.4f, midpoint=%.4f, R^2=%.4f, n=%d mice\n', ...
	SigmoidStats.FitA.Slope, SigmoidStats.FitA.Midpoint, SigmoidStats.FitA.RSquared, SigmoidStats.FitA.NMouse);
fprintf('TH-inhibited sigmoid: slope=%.4f, midpoint=%.4f, R^2=%.4f, n=%d mice\n', ...
	SigmoidStats.FitB.Slope, SigmoidStats.FitB.Midpoint, SigmoidStats.FitB.RSquared, SigmoidStats.FitB.NMouse);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);
fprintf('Two-way ANOVA Group P (all blocks) = %.4g\n', groupP);
iPrintPermutationResult('Fig5F', SigmoidStats);

assignin('base', 'Fig5F_ModelSigmoidStats', SigmoidStats.FitTable);
assignin('base', 'Fig5F_ANOVA', struct('p7', groupP7, 'pAll', groupP));

%% ========== local functions (copied from Chinese Fig63D) ==========
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

function hOut = iPlotGroupMeanErrorbars(ax, xSummary, meanCurve, semCurve, xFit, fitCurve, lineColor)
hold(ax, 'on');
xSummary = double(xSummary(:));
meanCurve = double(meanCurve(:));
semCurve = double(semCurve(:));
rows = isfinite(xSummary) & isfinite(meanCurve);
semCurve(~isfinite(semCurve)) = 0;
dataHandle = errorbar(ax, xSummary(rows), meanCurve(rows), semCurve(rows), 'o', ...
	'Color', lineColor, 'MarkerFaceColor', lineColor, 'MarkerEdgeColor', lineColor, ...
	'MarkerSize', 4, 'LineWidth', 1, 'CapSize', 4, 'LineStyle', 'none');
fitHandle = plot(ax, xFit, fitCurve, '-', 'Color', lineColor, 'LineWidth', 1, 'Tag', 'TransferLearningSupplementalLine');
hOut = [dataHandle, fitHandle];
end

function iPrintPermutationResult(figureLabel, SigmoidStats)
comparison = SigmoidStats.ComparisonTable;
fprintf('%s permutation slope difference (%s): %.4f\n', figureLabel, comparison.Comparison(1), comparison.ObservedSlopeDifference(1));
fprintf('%s permutation two-sided p = %.4g (%d permutations)\n', figureLabel, comparison.PValueTwoSided(1), comparison.NPermutation(1));
end

function T = iBuildGroupAnovaTableFromMatrices(performanceA, performanceB, groupNames)
[mouseA, blockA] = ndgrid(1:size(performanceA, 1), 1:size(performanceA, 2));
[mouseB, blockB] = ndgrid(1:size(performanceB, 1), 1:size(performanceB, 2));
resp = [performanceA(:); performanceB(:)];
block = [blockA(:); blockB(:)];
group = [repmat(groupNames(1), numel(performanceA), 1); repmat(groupNames(2), numel(performanceB), 1)];
mouse = [compose("Normal%03d", mouseA(:)); compose("TH%03d", mouseB(:))];
T = table(resp, block, group, mouse, 'VariableNames', {'Performance','Block','Group','Mouse'});
end
