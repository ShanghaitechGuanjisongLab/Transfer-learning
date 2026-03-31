% THInhibitoryHeterogeneitySimulation
%
% Minimal rate-model simulation for three qualitative findings:
% 1) transfer starts from a higher first-session performance than naive,
% 2) TH-dependent inhibitory competition increases process-averaged response heterogeneity,
% 3) larger learning-process L2/3 heterogeneity accelerates subsequent learning.
%
% The model contains:
% - excitatory populations in L2/3 and L5,
% - an explicit inhibitory population driven by cortical excitation and TH,
% - an explicit cue-input pathway,
% - a reusable transfer prior inherited from pre-training,
% - separable TH effects on network-state expression versus plasticity gating.

rng(20260330, 'twister');

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = 'TH_Inhibitory_Heterogeneity_Model.svg';

Params = iDefaultParams();
Cond = iConditionTable();
Summary = iRunCohortModel(Params, Cond);

fprintf('\n=== Simulated cohort summary ===\n');
for iCond = 1:height(Cond)
	name = Cond.Name(iCond);
	perf = Summary.Performance.(name);
	slope = Summary.PerMouse.(name).Slope;
	dh = Summary.PerMouse.(name).MeanDeltaHit;
	fprintf('%s: first-session hit = %.3f, last-session hit = %.3f\n', name, mean(perf(:, 1), 'omitnan'), mean(perf(:, end), 'omitnan'));
	fprintf('%s: mean process L2/3 heterogeneity = %.3f, mean process L5 heterogeneity = %.3f\n', name, mean(Summary.PerMouse.(name).MeanH23, 'omitnan'), mean(Summary.PerMouse.(name).MeanH5, 'omitnan'));
	fprintf('%s: mean slope = %.3f, mean DeltaHit = %.3f\n', name, mean(slope, 'omitnan'), mean(dh, 'omitnan'));
end
[rhoL23, pL23] = corr(Summary.CorrMouse.MeanH23, Summary.CorrMouse.Slope, 'Type', 'Spearman', 'Rows', 'complete');
[rhoL5, pL5] = corr(Summary.CorrMouse.MeanH5, Summary.CorrMouse.Slope, 'Type', 'Spearman', 'Rows', 'complete');
fprintf('Slope vs L2/3 heterogeneity: rho = %.3f, p = %.4g\n', rhoL23, pL23);
fprintf('Slope vs L5 heterogeneity:   rho = %.3f, p = %.4g\n', rhoL5, pL5);

f = figure('Color', 'w', 'Name', 'TH inhibitory heterogeneity model');
f.Units = 'centimeters';
f.Position(3:4) = [24, 16];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 24, 16];
f.PaperSize = [24, 16];

tl = tiledlayout(f, 2, 3, 'TileSpacing', 'loose', 'Padding', 'compact');

colors = Cond.Color;
xSess = (1:Params.NumSessions)';

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
[perfMean, perfSem] = iCurveStats(Summary.Performance, Cond.Name);
perfCells = iMatrixColumnsToCell(perfMean);
perfSemCells = iMatrixColumnsToCell(perfSem);
perfXCells = repmat({xSess}, 1, width(perfMean));
perfLines = MATLAB.Graphics.MultiShadowedLines(perfCells, perfSemCells, X=perfXCells, EdgeColors=colors);
iStyleLinePanel(ax1);
xlabel(ax1, 'Session', 'FontSize', 12);
ylabel(ax1, 'Hit rate', 'FontSize', 12);
title(ax1, 'Learning curves', 'FontSize', 12, 'FontWeight', 'normal');
ylim(ax1, [0, 1]);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
[h23Mean, h23Sem] = iCurveStats(Summary.HeterogeneityL23, Cond.Name);
h23Cells = iMatrixColumnsToCell(h23Mean);
h23SemCells = iMatrixColumnsToCell(h23Sem);
h23XCells = repmat({xSess}, 1, width(h23Mean));
MATLAB.Graphics.MultiShadowedLines(h23Cells, h23SemCells, X=h23XCells, EdgeColors=colors);
iStyleLinePanel(ax2);
xlabel(ax2, 'Session', 'FontSize', 12);
ylabel(ax2, 'L2/3 heterogeneity', 'FontSize', 12);
title(ax2, 'Running L2/3 heterogeneity', 'FontSize', 12, 'FontWeight', 'normal');

ax3 = nexttile(tl, 3);
hold(ax3, 'on');
for iCond = 1:2
	mask = Summary.CorrMouse.Condition == Cond.Name(iCond);
	scatter(ax3, Summary.CorrMouse.MeanH23(mask), Summary.CorrMouse.Slope(mask), 20, colors(iCond, :), 'filled', ...
		'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', colors(iCond, :), 'LineWidth', 0.2);
end
allUse = isfinite(Summary.CorrMouse.MeanH23) & isfinite(Summary.CorrMouse.Slope);
fitP23 = polyfit(Summary.CorrMouse.MeanH23(allUse), Summary.CorrMouse.Slope(allUse), 1);
xFit23 = linspace(min(Summary.CorrMouse.MeanH23(allUse)), max(Summary.CorrMouse.MeanH23(allUse)), 50);
plot(ax3, xFit23, polyval(fitP23, xFit23), '-', 'Color', [0, 0.6809, 0], 'LineWidth', 2, 'HandleVisibility', 'off');
iStyleScatterPanel(ax3);
xlabel(ax3, 'Learning-process L2/3 heterogeneity', 'FontSize', 12);
ylabel(ax3, 'Subsequent learning slope', 'FontSize', 12);
title(ax3, 'Slope vs L2/3 heterogeneity', 'FontSize', 12, 'FontWeight', 'normal');
text(ax3, 0.97, 0.97, iPLabel(pL23, rhoL23), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
	'VerticalAlignment', 'top', 'FontSize', 12);

ax4 = nexttile(tl, 4);
hold(ax4, 'on');
iStripMeanSem(ax4, Summary.PerMouse, Cond, 'MeanH5');
iAnnotateH5Stats(ax4, Summary.PerMouse, Cond);
iStyleScatterPanel(ax4);
xlabel(ax4, '', 'FontSize', 12);
ylabel(ax4, 'Mean L5 heterogeneity', 'FontSize', 12);
title(ax4, 'L5 heterogeneity', 'FontSize', 12, 'FontWeight', 'normal');
ax4.XTickLabel = {};
ax4.XTickLabelRotation = 0;

ax5 = nexttile(tl, 5);
hold(ax5, 'on');
iStripMeanSem(ax5, Summary.PerMouse, Cond, 'MeanDeltaHit');
iStyleScatterPanel(ax5);
xlabel(ax5, '', 'FontSize', 12);
ylabel(ax5, 'Mean Delta Hit', 'FontSize', 12);
title(ax5, 'Mean Delta Hit', 'FontSize', 12, 'FontWeight', 'normal');
ax5.XTickLabel = {};
ax5.XTickLabelRotation = 0;

ax6 = nexttile(tl, 6);
hold(ax6, 'on');
edges = linspace(-1.5, 1.5, 25);
[xCtrl, yCtrl] = iDensityFromHist(Summary.Representative.Transfer.ProcessMeanL5, edges);
[xTH, yTH] = iDensityFromHist(Summary.Representative.THOff.ProcessMeanL5, edges);
plot(ax6, xCtrl, yCtrl, '-', 'Color', Cond.Color(Cond.Name == "Transfer", :), 'LineWidth', 2);
plot(ax6, xTH, yTH, '-', 'Color', Cond.Color(Cond.Name == "THOff", :), 'LineWidth', 2);
iStyleScatterPanel(ax6);
xlabel(ax6, 'Process-mean L5 response', 'FontSize', 12);
ylabel(ax6, 'Density', 'FontSize', 12);
title(ax6, 'Process-mean L5 density', 'FontSize', 12, 'FontWeight', 'normal');

lgd = legend(ax1, perfLines(1:height(Cond)), cellstr(Cond.Label), 'Location', 'north', 'Box', 'off', 'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', 3);
lgd.Layout.Tile = 'north';

allAxes = findall(f, 'Type', 'Axes');
for iAx = 1:numel(allAxes)
	allAxes(iAx).FontSize = 12;
	allAxes(iAx).LineWidth = 2;
	if isprop(allAxes(iAx), 'Toolbar') && ~isempty(allAxes(iAx).Toolbar)
		allAxes(iAx).Toolbar.Visible = 'off';
	end
	if isprop(allAxes(iAx).XAxis, 'LineWidth')
		allAxes(iAx).XAxis.LineWidth = 2;
		allAxes(iAx).YAxis.LineWidth = 2;
	end
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'THInhibitoryHeterogeneityModel', Summary);

function Params = iDefaultParams()
Params.NumMice = 20;
Params.NumSessions = 8;
Params.NumTrials = 72;
Params.NE23 = 96;
Params.NE5 = 64;
Params.NI = 24;
Params.ResponseScale = 1.45;
Params.Noise23 = 0.22;
Params.Noise5 = 0.12;
Params.NoiseI = 0.12;
Params.Comp23 = 0.95;
Params.Comp5 = 1.35;
Params.BaseLearnRate = 0.52;
Params.LearnNoise = 0.010;
Params.MaxLearnState = 1.80;
Params.ReadoutGain = 11.0;
Params.HitThreshold = 0.40;
Params.InitialLearnState = 0.00;
Params.Ceiling = 1.00;
Params.CueTo23 = 0.22;
Params.BaseTo23 = 0.08;
Params.LearnTo23 = 0.88;
Params.PriorTo23 = 0.30;
Params.Coupling23To5 = 0.24;
Params.CueTo5 = 0.06;
Params.BaseTo5 = 0.06;
Params.LearnTo5 = 0.54;
Params.PriorTo5 = 0.18;
Params.THPatternTo5 = 0.46;
Params.BaselinePenalty = 1.00;
Params.LearnFromH23 = 1.55;
Params.H23Threshold = 0.29;
Params.PriorThresholdShift = 0.14;
Params.EligibilityDecay = 0.58;
Params.MaxEligibilityTrace = 1.15;
Params.BaselineTHFraction = 0.55;
end

function Cond = iConditionTable()
Cond = table;
Cond.Name = ["Naive"; "Transfer"; "THOff"];
Cond.Label = ["Naive"; "Transfer"; "TH inhibited"];
Cond.Color = [1, 0, 0; 0, 0, 1; 0, 0, 0];
Cond.PriorGain = [0.00; 0.68; 0.68];
Cond.PriorBias = [0.00; 0.00; 0.00];
Cond.THNetworkLevel = [1.00; 1.00; 0.82];
Cond.THPlasticityLevel = [1.00; 1.00; 0.35];
end

function Summary = iRunCohortModel(Params, Cond)
Summary.Performance = struct();
Summary.HeterogeneityL23 = struct();
Summary.HeterogeneityL5 = struct();
Summary.PerMouse = struct();
Summary.Representative = struct();

AllSlope = [];
AllH23 = [];
AllH5 = [];
AllCond = strings(0, 1);

for iCond = 1:height(Cond)
	perf = nan(Params.NumMice, Params.NumSessions);
	h23 = nan(Params.NumMice, Params.NumSessions);
	h5 = nan(Params.NumMice, Params.NumSessions);
	perMouse = table('Size', [Params.NumMice, 4], 'VariableTypes', {'double','double','double','double'}, ...
		'VariableNames', {'Slope','MeanDeltaHit','MeanH23','MeanH5'});
	repProcessL5 = cell(Params.NumMice, 1);
	for iMouse = 1:Params.NumMice
		Mouse = iDrawMouse(Params);
		MouseResult = iSimulateMouse(Mouse, Params, Cond(iCond, :));
		perf(iMouse, :) = MouseResult.Performance;
		h23(iMouse, :) = MouseResult.H23;
		h5(iMouse, :) = MouseResult.H5;
		perMouse.Slope(iMouse) = MouseResult.Slope;
		perMouse.MeanDeltaHit(iMouse) = MouseResult.MeanDeltaHit;
		perMouse.MeanH23(iMouse) = MouseResult.MeanH23;
		perMouse.MeanH5(iMouse) = MouseResult.MeanH5;
		repProcessL5{iMouse} = MouseResult.ProcessMeanL5;
	end
	Summary.Performance.(Cond.Name(iCond)) = perf;
	Summary.HeterogeneityL23.(Cond.Name(iCond)) = h23;
	Summary.HeterogeneityL5.(Cond.Name(iCond)) = h5;
	Summary.PerMouse.(Cond.Name(iCond)) = perMouse;
	if Cond.Name(iCond) == "Transfer" || Cond.Name(iCond) == "THOff"
		repIdx = iRepresentativeIndex(perMouse.MeanH5);
		Summary.Representative.(Cond.Name(iCond)).ProcessMeanL5 = repProcessL5{repIdx};
	end
	AllSlope = [AllSlope; perMouse.Slope]; %#ok<AGROW>
	AllH23 = [AllH23; perMouse.MeanH23]; %#ok<AGROW>
	AllH5 = [AllH5; perMouse.MeanH5]; %#ok<AGROW>
	AllCond = [AllCond; repmat(Cond.Name(iCond), Params.NumMice, 1)]; %#ok<AGROW>
end

Summary.AllMouse = table(AllCond, AllSlope, AllH23, AllH5, 'VariableNames', {'Condition','Slope','MeanH23','MeanH5'});
Summary.CorrMouse = Summary.AllMouse(Summary.AllMouse.Condition ~= "THOff", :);
end

function Mouse = iDrawMouse(Params)
Mouse.HeteroGain = max(0.35, 1 + 0.52 * randn());
Mouse.Cue23 = iStandardize(randn(Params.NE23, 1) + 0.55 * sign(randn(Params.NE23, 1)));
Mouse.Learn23 = Mouse.HeteroGain * iStandardize(0.80 * Mouse.Cue23 + 0.30 * randn(Params.NE23, 1));
Mouse.Prior23 = iStandardize(0.55 * Mouse.Cue23 + 0.18 * Mouse.Learn23 + 0.40 * randn(Params.NE23, 1));
Mouse.Base23 = iStandardize(0.35 * randn(Params.NE23, 1));
Mouse.WIE = abs(0.72 + 0.20 * randn(Params.NI, Params.NE23));
Mouse.WEI23 = abs(0.88 + 0.26 * randn(Params.NE23, Params.NI));
Mouse.WEI5 = abs(0.95 + 0.24 * randn(Params.NE5, Params.NI));
Mouse.W523 = 0.28 * randn(Params.NE5, Params.NE23);
Mouse.Cue5 = iStandardize(0.35 * (Mouse.W523 * Mouse.Cue23) + 0.80 * randn(Params.NE5, 1));
Mouse.Learn5 = Mouse.HeteroGain * iStandardize(0.25 * Mouse.Cue5 + 0.30 * (Mouse.W523 * Mouse.Learn23) + 0.75 * randn(Params.NE5, 1));
Mouse.Prior5 = iStandardize(0.55 * Mouse.Cue5 + 0.18 * Mouse.Learn5 + 0.55 * randn(Params.NE5, 1));
Mouse.Base5 = iStandardize(0.30 * randn(Params.NE5, 1));
Mouse.THToI = abs(0.72 + 0.18 * randn(Params.NI, 1));
Mouse.THL5Pattern = iStandardize(0.55 * (Mouse.WEI5 * iStandardize(Mouse.THToI)) + 0.45 * Mouse.Cue5);
Mouse.Readout = iStandardize(0.95 * Mouse.Cue5 + 0.30 * Mouse.Learn5 + 0.20 * randn(Params.NE5, 1));
end

function Result = iSimulateMouse(Mouse, Params, Cond)
learnState = Params.InitialLearnState;
eligibilityTrace = 0;
perf = nan(1, Params.NumSessions);
h23 = nan(1, Params.NumSessions);
h5 = nan(1, Params.NumSessions);
sessionMean23 = nan(Params.NE23, Params.NumSessions);
sessionMean5 = nan(Params.NE5, Params.NumSessions);

for iSess = 1:Params.NumSessions
	[perf(iSess), cellMean23, cellMean5] = iSimulateSession(Mouse, learnState, Params, Cond);
	sessionMean23(:, iSess) = cellMean23;
	sessionMean5(:, iSess) = cellMean5;
	sessionH23 = iRestrictedStd(cellMean23);
	h23(iSess) = iRestrictedStd(mean(sessionMean23(:, 1:iSess), 2, 'omitnan'));
	h5(iSess) = iRestrictedStd(mean(sessionMean5(:, 1:iSess), 2, 'omitnan'));
	eligibilityThreshold = max(0.05, Params.H23Threshold - Params.PriorThresholdShift * Cond.PriorGain);
	learnEligibility = Params.LearnFromH23 * max(sessionH23 - eligibilityThreshold, 0);
	eligibilityTrace = min(Params.MaxEligibilityTrace, Params.EligibilityDecay * eligibilityTrace + learnEligibility);
	learnGate = 0.20 + 0.80 * Cond.THPlasticityLevel;
	rewardSignal = max(perf(iSess), 0);
	learnState = min(Params.MaxLearnState, learnState + Params.BaseLearnRate * learnGate * eligibilityTrace * rewardSignal + Params.LearnNoise * randn());
	learnState = max(0, learnState);
end

first100 = find(perf >= Params.Ceiling, 1, 'first');
if isempty(first100)
	useIdx = 1:Params.NumSessions;
elseif first100 == 1
	useIdx = [];
else
	useIdx = 1:first100-1;
end

if numel(useIdx) >= 2
	fitX = (1:numel(useIdx))';
	fitY = perf(useIdx)';
	fitP = polyfit(fitX, fitY, 1);
	dh = diff(fitY);
	finalMean23 = mean(sessionMean23(:, useIdx), 2, 'omitnan');
	finalMean5 = mean(sessionMean5(:, useIdx), 2, 'omitnan');
	resultSlope = fitP(1);
	resultDeltaHit = mean(dh, 'omitnan');
	resultMeanH23 = iRestrictedStd(finalMean23);
	resultMeanH5 = iRestrictedStd(finalMean5);
elseif ~isempty(useIdx)
	finalMean5 = mean(sessionMean5(:, useIdx), 2, 'omitnan');
	resultSlope = NaN;
	resultDeltaHit = NaN;
	resultMeanH23 = NaN;
	resultMeanH5 = NaN;
else
	finalMean5 = nan(Params.NE5, 1);
	resultSlope = NaN;
	resultDeltaHit = NaN;
	resultMeanH23 = NaN;
	resultMeanH5 = NaN;
end

Result.Performance = perf;
Result.H23 = h23;
Result.H5 = h5;
Result.Slope = resultSlope;
Result.MeanDeltaHit = resultDeltaHit;
Result.MeanH23 = resultMeanH23;
Result.MeanH5 = resultMeanH5;
Result.ProcessMeanL5 = finalMean5;
end

function [perf, cueMean23, cueMean5] = iSimulateSession(Mouse, LearnState, Params, Cond)
cue23Drive = Params.CueTo23 * Mouse.Cue23 + Params.LearnTo23 * LearnState * Mouse.Learn23 + Params.PriorTo23 * Cond.PriorGain * Mouse.Prior23;
base23Drive = Params.BaseTo23 * Mouse.Base23;
pre23Cue = cue23Drive + Params.Noise23 * randn(Params.NE23, Params.NumTrials);
pre23Base = base23Drive + Params.Noise23 * randn(Params.NE23, Params.NumTrials);

exc23Cue = max(pre23Cue, 0);
exc23Base = max(pre23Base, 0);
inhCue = max(0, Mouse.WIE * exc23Cue / Params.NE23 + Cond.THNetworkLevel * Mouse.THToI + Params.NoiseI * randn(Params.NI, Params.NumTrials));
inhBase = max(0, Mouse.WIE * exc23Base / Params.NE23 + Params.BaselineTHFraction * Cond.THNetworkLevel * Mouse.THToI + Params.NoiseI * randn(Params.NI, Params.NumTrials));
inhCue = inhCue - mean(inhCue, 1);
inhBase = inhBase - mean(inhBase, 1);

r23Cue = Params.ResponseScale * tanh(pre23Cue - Params.Comp23 * (Mouse.WEI23 * inhCue) / Params.NI);
r23Base = Params.ResponseScale * tanh(pre23Base - Params.Comp23 * (Mouse.WEI23 * inhBase) / Params.NI);

thPatternCue = Params.THPatternTo5 * Cond.THNetworkLevel * Mouse.THL5Pattern * ones(1, Params.NumTrials);
thPatternBase = 0.12 * Params.THPatternTo5 * Cond.THNetworkLevel * Mouse.THL5Pattern * ones(1, Params.NumTrials);
pre5Cue = Params.CueTo5 * Mouse.Cue5 + Params.Coupling23To5 * (Mouse.W523 * r23Cue) / sqrt(Params.NE23) + Params.LearnTo5 * LearnState * Mouse.Learn5 + Params.PriorTo5 * Cond.PriorGain * Mouse.Prior5 + thPatternCue + Params.Noise5 * randn(Params.NE5, Params.NumTrials);
pre5Base = Params.BaseTo5 * Mouse.Base5 + 0.65 * Params.Coupling23To5 * (Mouse.W523 * r23Base) / sqrt(Params.NE23) + thPatternBase + Params.Noise5 * randn(Params.NE5, Params.NumTrials);
r5Cue = Params.ResponseScale * tanh(pre5Cue - Params.Comp5 * (Mouse.WEI5 * inhCue) / Params.NI);
r5Base = Params.ResponseScale * tanh(pre5Base - Params.Comp5 * (Mouse.WEI5 * inhBase) / Params.NI);

readoutCue = mean(Mouse.Readout .* r5Cue, 1);
readoutBase = mean(Mouse.Readout .* r5Base, 1);
decision = readoutCue - Params.BaselinePenalty * readoutBase + Cond.PriorBias;
pHit = 1 ./ (1 + exp(-Params.ReadoutGain * (decision - Params.HitThreshold)));
perf = mean(rand(1, Params.NumTrials) < pHit);

cueMean23 = mean(r23Cue - r23Base, 2, 'omitnan');
cueMean5 = mean(r5Cue - r5Base, 2, 'omitnan');
end

function s = iRestrictedStd(x)
x = x(isfinite(x) & x >= -1 & x <= 1);
if numel(x) < 3
	x = x(isfinite(x));
end
if numel(x) < 3
	s = NaN;
else
	s = std(x, 0, 'omitnan');
end
end

function idx = iRepresentativeIndex(x)
finiteIdx = find(isfinite(x));
if isempty(finiteIdx)
	idx = 1;
	return;
end
[~, localIdx] = min(abs(x(finiteIdx) - median(x(finiteIdx), 'omitnan')));
idx = finiteIdx(localIdx);
end

function v = iStandardize(v)
v = v(:);
v = v - mean(v, 'omitnan');
sd = std(v, 0, 'omitnan');
if ~isfinite(sd) || sd < eps
	sd = 1;
end
v = v ./ sd;
end

function [MeanTbl, SemTbl] = iCurveStats(DataStruct, order)
nCond = numel(order);
nSess = size(DataStruct.(order(1)), 2);
meanMat = nan(nSess, nCond);
semMat = nan(nSess, nCond);
for iCond = 1:nCond
	X = DataStruct.(order(iCond));
	meanMat(:, iCond) = mean(X, 1, 'omitnan')';
	semMat(:, iCond) = std(X, 0, 1, 'omitnan')' ./ sqrt(sum(isfinite(X), 1)');
end
MeanTbl = array2table(meanMat, 'VariableNames', cellstr(order));
SemTbl = array2table(semMat, 'VariableNames', cellstr(order));
end

function cells = iMatrixColumnsToCell(T)
cells = cell(1, width(T));
for i = 1:width(T)
	cells{i} = T{:, i};
end
end

function iStripMeanSem(ax, PerMouse, Cond, fieldName)
for iCond = 1:height(Cond)
	x = PerMouse.(Cond.Name(iCond)).(fieldName);
	x = x(isfinite(x));
	xj = iCond + 0.22 * (rand(size(x)) - 0.5);
	scatter(ax, xj, x, 20, Cond.Color(iCond, :), 'filled', 'MarkerFaceAlpha', 0.55, ...
		'MarkerEdgeColor', Cond.Color(iCond, :), 'LineWidth', 0.2);
	m = mean(x, 'omitnan');
	se = std(x, 0, 'omitnan') / sqrt(numel(x));
	plot(ax, [iCond - 0.18, iCond + 0.18], [m, m], '-', 'Color', Cond.Color(iCond, :), 'LineWidth', 2);
	plot(ax, [iCond, iCond], [m - se, m + se], '-', 'Color', Cond.Color(iCond, :), 'LineWidth', 2, 'HandleVisibility', 'off');
	text(ax, iCond, max(x) + 0.06 * range([x; 0]), sprintf('n=%d', numel(x)), 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'bottom', 'FontSize', 12, 'Color', Cond.Color(iCond, :));
end
ax.XLim = [0.5, height(Cond) + 0.5];
ax.XTick = 1:height(Cond);
ax.XTickLabel = cellstr(Cond.Label);
ax.XTickLabelRotation = 20;
end

function iAnnotateH5Stats(ax, PerMouse, Cond)
naive = PerMouse.(Cond.Name(1)).MeanH5;
transfer = PerMouse.(Cond.Name(2)).MeanH5;
thOff = PerMouse.(Cond.Name(3)).MeanH5;

naive = naive(isfinite(naive));
transfer = transfer(isfinite(transfer));
thOff = thOff(isfinite(thOff));

p12 = ranksum(naive, transfer);
p23 = ranksum(transfer, thOff);
p13 = ranksum(naive, thOff);
pAll = kruskalwallis([naive; transfer; thOff], ...
	[repmat({'Naive'}, numel(naive), 1); repmat({'Transfer'}, numel(transfer), 1); repmat({'TH inhibited'}, numel(thOff), 1)], 'off');

yAll = [naive; transfer; thOff];
yMin = min(yAll, [], 'omitnan');
yMax = max(yAll, [], 'omitnan');
yRange = max(yMax - yMin, 0.02);

	yLine12 = yMax + 0.08 * yRange;
	yLine23 = yMax + 0.20 * yRange;
	yLine13 = yMax + 0.32 * yRange;

	iStatLine(ax, 1, 2, yLine12, iPStars(p12));
	iStatLine(ax, 2, 3, yLine23, iPStars(p23));
	iStatLine(ax, 1, 3, yLine13, iPStars(p13));
	text(ax, 0.96, 0.98, sprintf('KW %s', iFormatPValue(pAll)), 'Units', 'normalized', ...
		'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12, 'Color', 'k');
	ylim(ax, [yMin - 0.06 * yRange, yMax + 0.56 * yRange]);
end

function iStatLine(ax, x1, x2, y, label)
tick = 0.035 * range(ax.YLim);
if ~isfinite(tick) || tick <= 0
	tick = 0.01;
end
	plot(ax, [x1, x1, x2, x2], [y - tick, y, y, y - tick], '-', 'Color', 'k', 'LineWidth', 2, 'HandleVisibility', 'off');
	text(ax, mean([x1, x2]), y + 0.02 * range(ax.YLim), label, 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'bottom', 'FontSize', 12, 'Color', 'k');
end

function txt = iFormatPValue(p)
if ~isfinite(p)
	txt = 'p=NaN';
	return;
end

if p < 0.001
	txt = 'p<0.001';
else
	txt = sprintf('p=%.3f', p);
end
end

function txt = iPStars(p)
if ~isfinite(p)
	txt = 'n.s.';
	return;
end

if p < 0.001
	txt = '***';
elseif p < 0.01
	txt = '**';
elseif p < 0.05
	txt = '*';
else
	txt = 'n.s.';
end
end

function [xLine, yLine] = iDensityFromHist(x, edges)
counts = histcounts(x, edges, 'Normalization', 'pdf');
centers = edges(1:end-1) + diff(edges) / 2;
xLine = centers(:);
yLine = counts(:);
end

function txt = iPLabel(p, rho)
if ~isfinite(p)
	txt = sprintf('rho = %.2f\np = NaN', rho);
	return;
end
if p < 0.001
	pTxt = 'p < 0.001';
elseif p < 0.01
	pTxt = sprintf('p = %.3f', p);
else
	pTxt = sprintf('p = %.2f', p);
end
txt = sprintf('rho = %.2f\n%s', rho, pTxt);
end

function iStyleLinePanel(ax)
box(ax, 'off');
grid(ax, 'off');
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
for obj = findobj(ax, 'Type', 'Line')'
	obj.LineWidth = 2;
end
end

function iStyleScatterPanel(ax)
box(ax, 'off');
grid(ax, 'off');
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
for obj = findobj(ax, 'Type', 'Line')'
	obj.LineWidth = 2;
end
end