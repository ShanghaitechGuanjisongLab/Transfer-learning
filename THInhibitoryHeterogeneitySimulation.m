% THInhibitoryHeterogeneitySimulation
%
% Minimal rate-model simulation for three qualitative findings:
% 1) transfer starts from a higher first-session performance than naive,
% 2) reward-dependent L5 recruitment increases process-averaged response heterogeneity,
% 3) larger learning-process L2/3 heterogeneity correlates with faster subsequent learning.
%
% The model contains:
% - excitatory populations in L2/3 and L5,
% - an explicit inhibitory population driven by cortical excitation,
% - an explicit cue-input pathway,
% - a reusable schema state acquired by pre-training on an alternate cue,
% - a TH-inhibited group implemented as reward-cell silence during the new task.

rng('shuffle');

networkOutputRoot = '\\Data-Server-2\个人数据\张天夫';
localOutputRoot = fullfile(fileparts(mfilename('fullpath')), 'resources');
if isfolder(networkOutputRoot)
	outDir = fullfile(networkOutputRoot, char(datetime('now', 'Format', 'yyyyMM')));
else
	outDir = fullfile(localOutputRoot, char(datetime('now', 'Format', 'yyyyMM')));
end
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
	rewardReadoutSimilarity = Summary.PerMouse.(name).RewardReadoutFinal;
	thAfferentDelta = Summary.PerMouse.(name).MeanTHAfferentDelta;
	fprintf('%s: first-session hit = %.3f, last-session hit = %.3f\n', name, mean(perf(:, 1), 'omitnan'), mean(perf(:, end), 'omitnan'));
	fprintf('%s: mean process L2/3 heterogeneity = %.3f, mean process L5 heterogeneity = %.3f\n', name, mean(Summary.PerMouse.(name).MeanH23, 'omitnan'), mean(Summary.PerMouse.(name).MeanH5, 'omitnan'));
	fprintf('%s: mean slope = %.3f, mean DeltaHit = %.3f\n', name, mean(slope, 'omitnan'), mean(dh, 'omitnan'));
	fprintf('%s: mean TH afferent delta = %.4f\n', name, mean(thAfferentDelta, 'omitnan'));
	fprintf('%s: mean reward-to-readout similarity = %.3f, below decision threshold = %d/%d\n', name, mean(rewardReadoutSimilarity, 'omitnan'), sum(rewardReadoutSimilarity < Params.HitThreshold | ~isfinite(rewardReadoutSimilarity)), numel(rewardReadoutSimilarity));
end
[rhoL23, pL23] = corr(Summary.CorrMouse.MeanH23, Summary.CorrMouse.Slope, 'Type', 'Spearman', 'Rows', 'complete');
fprintf('Slope vs L2/3 heterogeneity: rho = %.3f, p = %.4g\n', rhoL23, pL23);

f = figure('Color', 'w', 'Name', 'TH inhibitory heterogeneity model');
f.Units = 'centimeters';
f.Position(3:4) = [18, 16];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 18, 16];
f.PaperSize = [18, 16];

tl = tiledlayout(f, 2, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

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
for iCond = 1:height(Cond)
	mask = Summary.CorrMouse.Condition == Cond.Name(iCond);
	scatter(ax2, Summary.CorrMouse.MeanH23(mask), Summary.CorrMouse.Slope(mask), 20, colors(iCond, :), 'filled', ...
		'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', colors(iCond, :), 'LineWidth', 0.2);
end
allUse = isfinite(Summary.CorrMouse.MeanH23) & isfinite(Summary.CorrMouse.Slope);
fitP23 = polyfit(Summary.CorrMouse.MeanH23(allUse), Summary.CorrMouse.Slope(allUse), 1);
xFit23 = linspace(min(Summary.CorrMouse.MeanH23(allUse)), max(Summary.CorrMouse.MeanH23(allUse)), 50);
plot(ax2, xFit23, polyval(fitP23, xFit23), '-', 'Color', [0, 0.6809, 0], 'LineWidth', 2, 'HandleVisibility', 'off');
iStyleScatterPanel(ax2);
xlabel(ax2, 'Learning-process L2/3 heterogeneity', 'FontSize', 12);
ylabel(ax2, 'Subsequent learning slope', 'FontSize', 12);
title(ax2, 'Slope vs L2/3 heterogeneity', 'FontSize', 12, 'FontWeight', 'normal');
text(ax2, 0.97, 0.97, iPLabel(pL23, rhoL23), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
	'VerticalAlignment', 'top', 'FontSize', 12);

ax3 = nexttile(tl, 3);
hold(ax3, 'on');
iStripMeanSem(ax3, Summary.PerMouse, Cond, 'MeanH5');
iAnnotateMetricStats(ax3, Summary.PerMouse, Cond, 'MeanH5');
iStyleScatterPanel(ax3);
xlabel(ax3, '', 'FontSize', 12);
ylabel(ax3, 'Mean L5 heterogeneity', 'FontSize', 12);
title(ax3, 'L5 heterogeneity', 'FontSize', 12, 'FontWeight', 'normal');
ax3.XTickLabel = {};
ax3.XTickLabelRotation = 0;

ax4 = nexttile(tl, 4);
hold(ax4, 'on');
iStripMeanSem(ax4, Summary.PerMouse, Cond, 'Slope');
iAnnotateMetricStats(ax4, Summary.PerMouse, Cond, 'Slope');
iStyleScatterPanel(ax4);
xlabel(ax4, '', 'FontSize', 12);
ylabel(ax4, 'Learning slope', 'FontSize', 12);
title(ax4, 'Learning slope', 'FontSize', 12, 'FontWeight', 'normal');
ax4.XTickLabel = {};
ax4.XTickLabelRotation = 0;

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

if ~isfolder(outDir)
	mkdir(outDir);
end
svgPath = fullfile(outDir, svgName);
print(f, svgPath, '-dsvg', '-painters');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'THInhibitoryHeterogeneityModel', Summary);

function Params = iDefaultParams()
% Cue/TH inputs plus three modeled cortical populations:
%   L23      (L2/3 population with cue-tagged subgroups receiving direct drive)
%   TH       (post-decision reward-mode input cells, independent from L5)
%   L5RewardRecv (L5 cells receiving L2/3 and TH input)
%   L5Read   (L5 behavioural readout cells; no plastic I-pool)
% One plastic E-E matrix spans all L2/3 and L5 cells. It is structurally
% all-to-all except for the diagonal self-projections.
% Decision phase directly drives cue-tagged L2/3 cells, then all L2/3/L5
% populations settle through the recurrent internal
% projection. TH input is absent during baseline/decision and switches to
% reward mode during learning; TH input drives L5RewardRecv through
% a plastic afferent map, and readout drive remains a one-way input to L5Read.
% Learning phase applies outer-product Hebbian updates on reward-to-L5RewardRecv
% and recurrent internal matrices plus the per-cell
% inhibitory gain in L23/L5RewardRecv areas.
Params.UseGPU = gpuDeviceCount > 0;
Params.GPUPrecision = 'double';
Params.NumMice = 3;
Params.NumSessions = 8;
Params.NumTrials = 30;
Params.NL23 = 96;
Params.NReward = 64;
Params.NL5Read = 64;
Params.NL5RewardRecv = 2 * Params.NL5Read;
Params.NL5 = Params.NL5RewardRecv + Params.NL5Read;
Params.NL23L5 = Params.NL23 + Params.NL5;
Params.NIL23 = Params.NL23 / 4;
Params.NIL5RewardRecv = Params.NL5 / 4;
Params.NIInternal = Params.NIL23 + Params.NIL5RewardRecv;
Params.NInternal = Params.NL23L5 + Params.NIInternal;
Params.ResponseScale = 1.45;
Params.RateResponseSlope = 4.00;
Params.RateResponseMidpoint = 0.55;
Params.NoiseCue = 0.70;             % direct L2/3 cue-drive noise scale
Params.NoiseRew = 0.15;
Params.NoiseRead = 0.08;
Params.IterationNoise = 0.03;
Params.Comp_Cue = 0.95;
Params.Comp_Rew = 1.15;
% Input gains
Params.CueL23Gain = 1.00;           % direct L2/3 cue drive (decision + learning)
Params.CueL23GainPretrain = 1.60;   % direct L2/3 pretraining cue gain
Params.THRewardInputGain = 1.45;     % post-decision TH reward mode during learning phase
Params.THNoiseInputGain = 0.85;      % unstructured reward-mode TH input in the TH-inhibited group
Params.ReadInputGain = 1.45;         % readout pattern clamp amplitude (learning phase only)
% Decision readout: initial input noise creates trial-to-trial variability,
% and a hit is emitted when the readout pattern similarity crosses HitThreshold.
Params.HitThreshold = 0.67;
Params.Ceiling = 1.00;
Params.FirstCueTrainingNaiveMax = 0.40;
Params.FirstCueTrainingTransferMax = 0.80;
% Slope fit: drop sessions from the first 100%-hit session onward
% (that session and every subsequent one) so the plateau at 1.0 does
% not compress the slope of fast learners.
Params.SlopeHitPerfect = 1.00;
% Plastic synaptic accumulators are nonnegative outgoing allocation pools.
% Each active upstream cell sends a fixed total output scale, distributed to
% downstream cells in proportion to the downstream accumulator values.
Params.WCap = 1.20;
Params.AfferentWCap = 1.20;
Params.WeightMapSlope = 1.00;
Params.InitAfferentAccumulatorChiSquareDof = 1;
Params.InitAfferentAccumulatorScale = 1.00;
Params.InitRecurrentAccumulatorChiSquareDof = 1;
Params.InitRecurrentAccumulatorScale = 1.00;
Params.InhOutputWCap = 4 * Params.WCap;
Params.RewardAfferentNorm = 1.00;
% Number of recurrent internal passes after external cue/reward/readout drive.
Params.InternalRecurrentPasses = 4;
Params.TeacherReadoutPasses = 5;
Params.StateCarryover = 0.35;       % fraction of previous internal state retained across recurrent passes
% Global per-trial Hebbian learning rate used by reward pretraining, cue
% pretraining, and later task learning.
Params.HebbRate = 0.5;
Params.BaselineAntiHebbRate = 0.0300;
Params.BaselineAfferentAntiHebbRate = 0.0300;
Params.BaselineQuietIterations = 40;
Params.MaxBaselineIterations = 1500;
% Eligibility traces let current reward/readout feedback update recently
% experienced states; older states contribute less on each trial.
Params.EligibilityDecay = 0.95;
Params.EligibilityTraceScale = 1.00;
% Inhibitory plasticity (per-E-cell gain, Vogels-Sprekeler style, per-trial).
Params.InhPlasticityRate = 0.002;
Params.InhTargetAct = 0.00;
Params.InhGainMin = 0.20;
Params.InhGainMax = 3.00;
% Cross-modality latent correlation between pretraining cue-tagged L2/3 cells
% and new cue-tagged L2/3 cells. Positive cue cells are still forced to be
% disjoint; this correlation only shapes which inactive pre-cue L2/3 cells are
% most likely to become active for the new cue.
Params.CueModalityCorr = 0.50;
Params.CueL23ActiveFractionOfPreCue = 0.50;
% Overnight consolidation
Params.OvernightRetention = 0.96;
Params.OvernightNoise = 0.002;
% Pretraining
Params.RewardPretrainSuccessStreak = 10;
Params.RewardPretrainDecisionPasses = 64;
Params.MaxRewardPretrainTrials = 128;
Params.MaxPretrainSessions = 8;
Params.PostCeilingSessions = 1;
end

function Cond = iConditionTable()
Cond = table;
Cond.Name = ["Naive"; "Transfer"; "THOff"];
Cond.Label = ["Naive"; "Transfer"; "TH inhibited"];
Cond.Color = [1, 0, 0; 0, 0, 1; 0, 0, 0];
Cond.THInputIsNoise = [false; false; true];
end

function Params = iWithRunContext(Params, runContext)
Params.RunContext = string(runContext);
end

function contextText = iRunContextText(Params)
contextText = '';
if isfield(Params, 'RunContext')
	contextText = sprintf(' during %s', Params.RunContext);
end
end

function Summary = iRunCohortModel(Params, Cond)
Summary.Performance = struct();
Summary.HeterogeneityL23 = struct();
Summary.HeterogeneityL5 = struct();
Summary.THAfferentDelta = struct();
Summary.PerMouse = struct();
Summary.Representative = struct();
Summary.RewardPretrainDiagnostics = struct();
Summary.CuePretrainDiagnostics = struct();

AllSlope = [];
AllH23 = [];
AllH5 = [];
AllTHAfferentDelta = [];
AllRewardReadoutPretrain = [];
AllRewardReadoutFinal = [];
AllCond = strings(0, 1);

nCond = height(Cond);
nMouse = Params.NumMice;
nSess = Params.NumSessions;
nTask = nCond * nMouse;
[taskCondIndex, taskMouseIndex] = iMouseTaskIndex(nCond, nMouse);
taskCondName = Cond.Name(taskCondIndex);
taskCondRows = cell(nTask, 1);
for iTask = 1:nTask
	taskCondRows{iTask} = Cond(taskCondIndex(iTask), :);
end
perfAll = nan(nCond, nMouse, nSess);
h23All = nan(nCond, nMouse, nSess);
h5All = nan(nCond, nMouse, nSess);
thDeltaAll = nan(nCond, nMouse, nSess);

mouseCells = cell(nTask, 1);
sessionMeanL23Cells = cell(nTask, 1);
sessionMeanL5Cells = cell(nTask, 1);
parfor iTask = 1:nTask
	mouseCells{iTask} = iDrawMouse(Params);
	sessionMeanL23Cells{iTask} = nan(Params.NL23, Params.NumSessions);
	sessionMeanL5Cells{iTask} = nan(Params.NL5, Params.NumSessions);
end
MousePool = reshape(mouseCells, nCond, nMouse);
sessionMeanL23 = reshape(sessionMeanL23Cells, nCond, nMouse);
sessionMeanL5 = reshape(sessionMeanL5Cells, nCond, nMouse);

MousePool = iRunCuePretrainingUnits(MousePool, Params, Cond);

mouseCells = MousePool(:);
fullRewardCond = iFullRewardCondition();
rewardReadoutPretrainList = nan(nTask, 1);
parfor iTask = 1:nTask
	rewardReadoutPretrainList(iTask) = iRewardReadoutProbe(mouseCells{iTask}, Params, fullRewardCond);
end
rewardReadoutPretrainAll = reshape(rewardReadoutPretrainList, nCond, nMouse);

for iSess = 1:nSess
	mouseCells = MousePool(:);
	sessionMeanL23Cells = sessionMeanL23(:);
	sessionMeanL5Cells = sessionMeanL5(:);
	perfSession = nan(nTask, 1);
	h23Session = nan(nTask, 1);
	h5Session = nan(nTask, 1);
	thDeltaSession = nan(nTask, 1);
	firstSignalsSession = cell(nTask, 1);
	parfor iTask = 1:nTask
		iMouseTask = taskMouseIndex(iTask);
		Mouse = mouseCells{iTask};
		thAfferentBefore = [Mouse.W_RewardToL5RewardRecv; Mouse.W_RewardToIL5RewardRecv];
		sessionParams = iWithRunContext(Params, sprintf('%s formal training mouse %d session %d', taskCondName(iTask), iMouseTask, iSess));
		[perfTask, Signals, ~, Mouse] = iSimulateSession(Mouse, sessionParams, taskCondRows{iTask}, false);
		thAfferentAfter = [Mouse.W_RewardToL5RewardRecv; Mouse.W_RewardToIL5RewardRecv];
		sessionMeanL23Task = sessionMeanL23Cells{iTask};
		sessionMeanL5Task = sessionMeanL5Cells{iTask};
		sessionMeanL23Task(:, iSess) = Signals.ProcessMeanL23;
		sessionMeanL5Task(:, iSess) = Signals.ProcessMeanL5;
		perfSession(iTask) = perfTask;
		thDeltaSession(iTask) = iGatherScalar(norm(thAfferentAfter - thAfferentBefore, 'fro') / max(norm(thAfferentBefore, 'fro'), eps));
		h23Session(iTask) = iRestrictedStd(mean(sessionMeanL23Task(:, 1:iSess), 2, 'omitnan'));
		h5Session(iTask) = iRestrictedStd(mean(sessionMeanL5Task(:, 1:iSess), 2, 'omitnan'));
		if iSess == 1
			firstSignalsSession{iTask} = Signals;
		end
		mouseCells{iTask} = Mouse;
		sessionMeanL23Cells{iTask} = sessionMeanL23Task;
		sessionMeanL5Cells{iTask} = sessionMeanL5Task;
	end
	MousePool = reshape(mouseCells, nCond, nMouse);
	sessionMeanL23 = reshape(sessionMeanL23Cells, nCond, nMouse);
	sessionMeanL5 = reshape(sessionMeanL5Cells, nCond, nMouse);
	perfAll(:, :, iSess) = reshape(perfSession, nCond, nMouse);
	h23All(:, :, iSess) = reshape(h23Session, nCond, nMouse);
	h5All(:, :, iSess) = reshape(h5Session, nCond, nMouse);
	thDeltaAll(:, :, iSess) = reshape(thDeltaSession, nCond, nMouse);
	if iSess == 1
		firstCueTrainingSignals = reshape(firstSignalsSession, nCond, nMouse);
		iCheckFirstCueTrainingUnit(perfAll(:, :, iSess), firstCueTrainingSignals, MousePool, Cond, Params);
	end
	if iSess < nSess
		mouseCells = MousePool(:);
		parfor iTask = 1:nTask
			mouseCells{iTask} = iOvernightConsolidate(mouseCells{iTask}, Params);
		end
		MousePool = reshape(mouseCells, nCond, nMouse);
	end
end

for iCond = 1:nCond
	perf = nan(Params.NumMice, Params.NumSessions);
	h23 = nan(Params.NumMice, Params.NumSessions);
	h5 = nan(Params.NumMice, Params.NumSessions);
	thDelta = nan(Params.NumMice, Params.NumSessions);
	mouseSlope = nan(Params.NumMice, 1);
	mouseDeltaHit = nan(Params.NumMice, 1);
	mouseMeanH23 = nan(Params.NumMice, 1);
	mouseMeanH5 = nan(Params.NumMice, 1);
	mouseMeanTHAfferentDelta = nan(Params.NumMice, 1);
	rewardReadoutPretrain = nan(Params.NumMice, 1);
	rewardReadoutFinal = nan(Params.NumMice, 1);
	rewardPretrainDiagnostics = cell(Params.NumMice, 1);
	cuePretrainDiagnostics = cell(Params.NumMice, 1);
	repProcessL5 = cell(Params.NumMice, 1);
	condNow = Cond(iCond, :);
	for iMouse = 1:Params.NumMice
		Mouse = MousePool{iCond, iMouse};
		perf(iMouse, :) = reshape(perfAll(iCond, iMouse, :), 1, []);
		h23(iMouse, :) = reshape(h23All(iCond, iMouse, :), 1, []);
		h5(iMouse, :) = reshape(h5All(iCond, iMouse, :), 1, []);
		thDelta(iMouse, :) = reshape(thDeltaAll(iCond, iMouse, :), 1, []);
		MouseResult = iSummarizeMouseTraining(perf(iMouse, :), h23(iMouse, :), h5(iMouse, :), sessionMeanL23{iCond, iMouse}, sessionMeanL5{iCond, iMouse}, thDelta(iMouse, :), Params);
		perf(iMouse, :) = MouseResult.Performance;
		h23(iMouse, :) = MouseResult.H23;
		h5(iMouse, :) = MouseResult.H5;
		thDelta(iMouse, :) = MouseResult.THAfferentDelta;
		mouseSlope(iMouse) = MouseResult.Slope;
		mouseDeltaHit(iMouse) = MouseResult.MeanDeltaHit;
		mouseMeanH23(iMouse) = MouseResult.MeanH23;
		mouseMeanH5(iMouse) = MouseResult.MeanH5;
		mouseMeanTHAfferentDelta(iMouse) = MouseResult.MeanTHAfferentDelta;
		rewardReadoutPretrain(iMouse) = rewardReadoutPretrainAll(iCond, iMouse);
		rewardReadoutFinal(iMouse) = iRewardReadoutProbe(Mouse, Params, condNow);
		rewardPretrainDiagnostics{iMouse} = Mouse.RewardPretrainDiagnostics;
		if isfield(Mouse, 'CuePretrainDiagnostics')
			cuePretrainDiagnostics{iMouse} = Mouse.CuePretrainDiagnostics;
		end
		repProcessL5{iMouse} = MouseResult.ProcessMeanL5;
	end
	perMouse = table(mouseSlope, mouseDeltaHit, mouseMeanH23, mouseMeanH5, mouseMeanTHAfferentDelta, rewardReadoutPretrain, rewardReadoutFinal, ...
		'VariableNames', {'Slope','MeanDeltaHit','MeanH23','MeanH5','MeanTHAfferentDelta','RewardReadoutPretrain','RewardReadoutFinal'});
	Summary.Performance.(Cond.Name(iCond)) = perf;
	Summary.HeterogeneityL23.(Cond.Name(iCond)) = h23;
	Summary.HeterogeneityL5.(Cond.Name(iCond)) = h5;
	Summary.THAfferentDelta.(Cond.Name(iCond)) = thDelta;
	Summary.PerMouse.(Cond.Name(iCond)) = perMouse;
	Summary.RewardPretrainDiagnostics.(Cond.Name(iCond)) = rewardPretrainDiagnostics;
	Summary.CuePretrainDiagnostics.(Cond.Name(iCond)) = cuePretrainDiagnostics;
	if Cond.Name(iCond) == "Transfer" || Cond.Name(iCond) == "THOff"
		repIdx = iRepresentativeIndex(perMouse.MeanH5);
		Summary.Representative.(Cond.Name(iCond)).ProcessMeanL5 = repProcessL5{repIdx};
	end
	AllSlope = [AllSlope; perMouse.Slope]; %#ok<AGROW>
	AllH23 = [AllH23; perMouse.MeanH23]; %#ok<AGROW>
	AllH5 = [AllH5; perMouse.MeanH5]; %#ok<AGROW>
	AllTHAfferentDelta = [AllTHAfferentDelta; perMouse.MeanTHAfferentDelta]; %#ok<AGROW>
	AllRewardReadoutPretrain = [AllRewardReadoutPretrain; perMouse.RewardReadoutPretrain]; %#ok<AGROW>
	AllRewardReadoutFinal = [AllRewardReadoutFinal; perMouse.RewardReadoutFinal]; %#ok<AGROW>
	AllCond = [AllCond; repmat(Cond.Name(iCond), Params.NumMice, 1)]; %#ok<AGROW>
end

Summary.AllMouse = table(AllCond, AllSlope, AllH23, AllH5, AllTHAfferentDelta, AllRewardReadoutPretrain, AllRewardReadoutFinal, ...
	'VariableNames', {'Condition','Slope','MeanH23','MeanH5','MeanTHAfferentDelta','RewardReadoutPretrain','RewardReadoutFinal'});
Summary.CorrMouse = Summary.AllMouse;
end

function [taskCondIndex, taskMouseIndex] = iMouseTaskIndex(nCond, nMouse)
taskCondIndex = repmat((1:nCond)', nMouse, 1);
taskMouseIndex = repelem((1:nMouse)', nCond);
end

function MousePool = iRunRewardPretrainingUnits(MousePool, Params, Cond)
nCond = height(Cond);
nMouse = Params.NumMice;
nTask = nCond * nMouse;
[taskCondIndex, taskMouseIndex] = iMouseTaskIndex(nCond, nMouse);
mouseCells = MousePool(:);
taskCondName = Cond.Name(taskCondIndex);
parfor iTask = 1:nTask
	iMouseTask = taskMouseIndex(iTask);
	mouseCells{iTask} = iPretrainRewardReadout(mouseCells{iTask}, Params, taskCondName(iTask), iMouseTask);
end
MousePool = reshape(mouseCells, nCond, nMouse);
end

function MousePool = iRunCuePretrainingUnits(MousePool, Params, Cond)
nCond = height(Cond);
nMouse = Params.NumMice;
nTask = nCond * nMouse;
[taskCondIndex, taskMouseIndex] = iMouseTaskIndex(nCond, nMouse);
pretrainParams = Params;
mouseCells = MousePool(:);
taskCondName = Cond.Name(taskCondIndex);
activeList = false(nTask, 1);
stateCells = cell(nTask, 1);
for iTask = 1:nTask
	if taskCondName(iTask) ~= "Naive"
		activeList(iTask) = true;
		stateCells{iTask} = iInitCuePretrainState(pretrainParams);
	end
end

for iSess = 1:pretrainParams.MaxPretrainSessions
	nextMouseCells = cell(nTask, 1);
	nextStateCells = cell(nTask, 1);
	nextActiveList = false(nTask, 1);
	parfor iTask = 1:nTask
		Mouse = mouseCells{iTask};
		cueState = stateCells{iTask};
		activeNow = activeList(iTask);
		if activeNow
			iMouseTask = taskMouseIndex(iTask);
			[Mouse, cueState] = iStepCuePretrain(Mouse, cueState, pretrainParams, iSess, taskCondName(iTask), iMouseTask);
			if cueState.Complete
				activeNow = false;
			elseif iSess >= pretrainParams.MaxPretrainSessions
				iCuePretrainFailureError(cueState, pretrainParams, taskCondName(iTask), iMouseTask);
			end
		end
		nextMouseCells{iTask} = Mouse;
		nextStateCells{iTask} = cueState;
		nextActiveList(iTask) = activeNow;
	end
	mouseCells = nextMouseCells;
	stateCells = nextStateCells;
	activeList = nextActiveList;
	if ~any(activeList)
		MousePool = reshape(mouseCells, nCond, nMouse);
		return;
	end
end
MousePool = reshape(mouseCells, nCond, nMouse);
end

function cueState = iInitCuePretrainState(pretrainParams)
cueState.LastPerfObserved = NaN;
cueState.LastPerfExpected = NaN;
cueState.PostCeilingCount = 0;
cueState.Diagnostics = iInitCuePretrainDiagnostics(pretrainParams);
cueState.Complete = false;
end

function [Mouse, cueState] = iStepCuePretrain(Mouse, cueState, pretrainParams, iSess, condName, iMouse)
pretrainCond.THInputIsNoise = false;
pretrainParams = iWithRunContext(pretrainParams, sprintf('%s cue pretrain mouse %d session %d', condName, iMouse, iSess));
[perfObserved, Signals, perfExpected, Mouse] = iSimulateSession(Mouse, pretrainParams, pretrainCond, true);
cueState.LastPerfObserved = perfObserved;
cueState.LastPerfExpected = perfExpected;
cueState.Diagnostics = iRecordCuePretrainDiagnostics(cueState.Diagnostics, iSess, Mouse, Signals, perfObserved, perfExpected, pretrainParams);

if perfObserved >= pretrainParams.Ceiling || perfExpected >= pretrainParams.Ceiling
	cueState.PostCeilingCount = cueState.PostCeilingCount + 1;
	if cueState.PostCeilingCount >= pretrainParams.PostCeilingSessions
		cueState.Complete = true;
		Mouse.CuePretrainDiagnostics = cueState.Diagnostics;
		return;
	end
end

if iSess < pretrainParams.MaxPretrainSessions
	Mouse = iOvernightConsolidate(Mouse, pretrainParams);
end
end

function iCuePretrainFailureError(cueState, pretrainParams, condName, iMouse)
diagMessage = iCuePretrainDiagnosticMessage(cueState.Diagnostics);
error('THModel:PretrainDidNotReachCeiling', ...
	'%s mouse %d cue pretraining did not reach ceiling within %d sessions. Final observed hit = %.3f, final expected hit = %.3f. %s', ...
	condName, iMouse, pretrainParams.MaxPretrainSessions, cueState.LastPerfObserved, cueState.LastPerfExpected, diagMessage);
end

function iCheckFirstCueTrainingUnit(firstUnitPerf, firstCueTrainingSignals, MousePool, Cond, Params)
for iCond = 1:height(Cond)
	condName = Cond.Name(iCond);
	groupPerf = mean(firstUnitPerf(iCond, :), 'omitnan');
	if condName == "Naive"
		limit = Params.FirstCueTrainingNaiveMax;
	else
		limit = Params.FirstCueTrainingTransferMax;
	end
	if groupPerf > limit
		diagMessage = iFirstCueTrainingDiagnosticMessage(firstUnitPerf(iCond, :), firstCueTrainingSignals(iCond, :), MousePool(iCond, :), Params);
		error('THModel:FirstCueTrainingUnitTooHigh', ...
			'%s first cue-training unit hit rate %.3f exceeded the allowed %.3f. Stopping before later training units. %s', ...
			condName, groupPerf, limit, diagMessage);
	end
end
end

function diagMessage = iFirstCueTrainingDiagnosticMessage(firstUnitPerf, firstCueTrainingSignals, MousePool, Params)
numMouse = numel(firstCueTrainingSignals);
decisionDriveMean = nan(numMouse, 1);
decisionDriveMax = nan(numMouse, 1);
baselineCorrectionMean = nan(numMouse, 1);
baselineCorrectionMax = nan(numMouse, 1);
baselineMaxDriveMean = nan(numMouse, 1);
baselineMaxDriveMax = nan(numMouse, 1);
baselineFinalDriveMean = nan(numMouse, 1);
baselineFinalDriveMax = nan(numMouse, 1);
baselineTargetL23PreMean = nan(numMouse, 1);
baselineTargetRewardRecvPreMean = nan(numMouse, 1);
baselineTargetReadRecurrentPreMean = nan(numMouse, 1);
baselineTargetIL23PreMean = nan(numMouse, 1);
baselineTargetIL5RewardRecvIPreMean = nan(numMouse, 1);
baselineTargetL2NetPreMean = nan(numMouse, 1);
baselineTargetL5NetPreMean = nan(numMouse, 1);
baselineTargetNetPreMean = nan(numMouse, 1);
cueL23PatternCorrelation = nan(numMouse, 1);
baselineToDecisionSimilarityRatio = nan(numMouse, 1);
cueIL23Mean = nan(numMouse, 1);
cueIL23Max = nan(numMouse, 1);
cueIL5RewardRecvIMean = nan(numMouse, 1);
cueIL5RewardRecvIMax = nan(numMouse, 1);
thToIL5RewardRecvIPreMean = nan(numMouse, 1);
thToIL5RewardRecvIPreMax = nan(numMouse, 1);
il23ToIL5RewardRecvIPreMean = nan(numMouse, 1);
il23ToIL5RewardRecvIPreMin = nan(numMouse, 1);
il23ToIL5RewardRecvIPreMeanAbs = nan(numMouse, 1);
il23ToIL5RewardRecvIPreMaxAbs = nan(numMouse, 1);
il23ToReadMeanAbsW = nan(numMouse, 1);
il23ToReadMaxAbsW = nan(numMouse, 1);
il5RewardRecvIToReadMeanAbsW = nan(numMouse, 1);
il5RewardRecvIToReadMaxAbsW = nan(numMouse, 1);
il23ToIL5RewardRecvIMeanAbsW = nan(numMouse, 1);
il23ToIL5RewardRecvIMaxAbsW = nan(numMouse, 1);
for iMouse = 1:numMouse
	Signals = firstCueTrainingSignals{iMouse};
	Mouse = MousePool{iMouse};
	decisionDriveMean(iMouse) = Signals.DecisionReadoutDriveMean;
	decisionDriveMax(iMouse) = Signals.DecisionReadoutDriveMax;
	baselineCorrectionMean(iMouse) = Signals.BaselineCorrectionMean;
	baselineCorrectionMax(iMouse) = Signals.BaselineCorrectionMax;
	baselineMaxDriveMean(iMouse) = Signals.BaselineMaxDriveMean;
	baselineMaxDriveMax(iMouse) = Signals.BaselineMaxDriveMax;
	baselineFinalDriveMean(iMouse) = Signals.BaselineFinalDriveMean;
	baselineFinalDriveMax(iMouse) = Signals.BaselineFinalDriveMax;
	baselineTargetL23PreMean(iMouse) = Signals.BaselineTargetL23PreMean;
	baselineTargetRewardRecvPreMean(iMouse) = Signals.BaselineTargetRewardRecvPreMean;
	baselineTargetReadRecurrentPreMean(iMouse) = Signals.BaselineTargetReadRecurrentPreMean;
	baselineTargetIL23PreMean(iMouse) = Signals.BaselineTargetIL23PreMean;
	baselineTargetIL5RewardRecvIPreMean(iMouse) = Signals.BaselineTargetIL5RewardRecvIPreMean;
	baselineTargetL2NetPreMean(iMouse) = Signals.BaselineTargetL2NetPreMean;
	baselineTargetL5NetPreMean(iMouse) = Signals.BaselineTargetL5NetPreMean;
	baselineTargetNetPreMean(iMouse) = Signals.BaselineTargetNetPreMean;
	cueL23PatternCorrelation(iMouse) = iGatherScalar(corr(Mouse.PreCueL23Pattern, Mouse.CueL23Pattern));
	baselineToDecisionSimilarityRatio(iMouse) = baselineFinalDriveMean(iMouse) / max(decisionDriveMean(iMouse), eps);
	cueIL23Mean(iMouse) = iMeanFlat(Signals.ProcessMeanIL23);
	cueIL23Max(iMouse) = iMaxFlat(Signals.ProcessMeanIL23);
	cueIL5RewardRecvIMean(iMouse) = iMeanFlat(Signals.ProcessMeanIL5RewardRecvI);
	cueIL5RewardRecvIMax(iMouse) = iMaxFlat(Signals.ProcessMeanIL5RewardRecvI);
	thToIL5RewardRecvIPreMean(iMouse) = Signals.THToIL5RewardRecvIPreMean;
	thToIL5RewardRecvIPreMax(iMouse) = Signals.THToIL5RewardRecvIPreMax;
	il23ToIL5RewardRecvIPreMean(iMouse) = Signals.IL23ToIL5RewardRecvIRecurrentPreMean;
	il23ToIL5RewardRecvIPreMin(iMouse) = Signals.IL23ToIL5RewardRecvIRecurrentPreMin;
	il23ToIL5RewardRecvIPreMeanAbs(iMouse) = Signals.IL23ToIL5RewardRecvIRecurrentPreMeanAbs;
	il23ToIL5RewardRecvIPreMaxAbs(iMouse) = Signals.IL23ToIL5RewardRecvIRecurrentPreMaxAbs;
	[il23ToReadMeanAbsW(iMouse), il23ToReadMaxAbsW(iMouse), il5RewardRecvIToReadMeanAbsW(iMouse), il5RewardRecvIToReadMaxAbsW(iMouse), il23ToIL5RewardRecvIMeanAbsW(iMouse), il23ToIL5RewardRecvIMaxAbsW(iMouse)] = iInhibitoryCircuitWeightSummary(Mouse, Params);
end
inputAccumulatorText = iRewardAfferentAccumulatorDistributionText(MousePool);
diagMessage = sprintf(['First cue-training diagnostics: per-mouse perf=%s; decision similarity mean=%s, max=%s; ', ...
	'baseline corrections mean=%s, max=%s; baseline max-similarity mean=%s, max=%s; baseline final-similarity mean=%s, max=%s; cue L23 pattern corr=%s; baseline-final/decision similarity ratio=%s; ', ...
	'baseline trigger target Read pre mean: L23=%s, RewardRecv=%s, Read recurrent=%s, IL23=%s, IL5RewardRecvI=%s, L2 net=%s, L5 net=%s, total=%s; ', ...
	'cue IL23 mean=%s, max=%s; cue IL5RewardRecvI mean=%s, max=%s; ', ...
	'IL5RewardRecvI drive TH pre mean=%s, max=%s; IL23 recurrent pre mean=%s, min=%s, |pre| mean=%s, max=%s; ', ...
	'|IL23->Read| mean=%s, max=%s; |IL5RewardRecvI->Read| mean=%s, max=%s; |IL23->IL5RewardRecvI| mean=%s, max=%s. %s'], ...
	iFormatNumberSeries(firstUnitPerf), iFormatNumberSeries(decisionDriveMean), iFormatNumberSeries(decisionDriveMax), ...
	iFormatNumberSeries(baselineCorrectionMean), iFormatNumberSeries(baselineCorrectionMax), iFormatNumberSeries(baselineMaxDriveMean), iFormatNumberSeries(baselineMaxDriveMax), ...
	iFormatNumberSeries(baselineFinalDriveMean), iFormatNumberSeries(baselineFinalDriveMax), ...
	iFormatNumberSeries(cueL23PatternCorrelation), iFormatNumberSeries(baselineToDecisionSimilarityRatio), ...
	iFormatNumberSeries(baselineTargetL23PreMean), iFormatNumberSeries(baselineTargetRewardRecvPreMean), iFormatNumberSeries(baselineTargetReadRecurrentPreMean), ...
	iFormatNumberSeries(baselineTargetIL23PreMean), iFormatNumberSeries(baselineTargetIL5RewardRecvIPreMean), iFormatNumberSeries(baselineTargetL2NetPreMean), iFormatNumberSeries(baselineTargetL5NetPreMean), iFormatNumberSeries(baselineTargetNetPreMean), ...
	iFormatNumberSeries(cueIL23Mean), iFormatNumberSeries(cueIL23Max), iFormatNumberSeries(cueIL5RewardRecvIMean), iFormatNumberSeries(cueIL5RewardRecvIMax), ...
	iFormatNumberSeries(thToIL5RewardRecvIPreMean), iFormatNumberSeries(thToIL5RewardRecvIPreMax), iFormatNumberSeries(il23ToIL5RewardRecvIPreMean), iFormatNumberSeries(il23ToIL5RewardRecvIPreMin), ...
	iFormatNumberSeries(il23ToIL5RewardRecvIPreMeanAbs), iFormatNumberSeries(il23ToIL5RewardRecvIPreMaxAbs), iFormatNumberSeries(il23ToReadMeanAbsW), iFormatNumberSeries(il23ToReadMaxAbsW), ...
	iFormatNumberSeries(il5RewardRecvIToReadMeanAbsW), iFormatNumberSeries(il5RewardRecvIToReadMaxAbsW), iFormatNumberSeries(il23ToIL5RewardRecvIMeanAbsW), iFormatNumberSeries(il23ToIL5RewardRecvIMaxAbsW), inputAccumulatorText);
end

function inputAccumulatorText = iRewardAfferentAccumulatorDistributionText(MousePool)
numMouse = numel(MousePool);
textParts = strings(1, numMouse);
for iMouse = 1:numMouse
	Mouse = MousePool{iMouse};
	textParts(iMouse) = sprintf('mouse %d Z distributions: Reward->RewardRecv %s; Reward->IL5RewardRecv %s', ...
		iMouse, ...
		iDistributionText(Mouse.Z_RewardToL5RewardRecv), iDistributionText(Mouse.Z_RewardToIL5RewardRecv));
end
inputAccumulatorText = char("reward afferent accumulator " + strjoin(textParts, "; ") + ".");
end

function [il23ToReadMeanAbsW, il23ToReadMaxAbsW, il5RewardRecvIToReadMeanAbsW, il5RewardRecvIToReadMaxAbsW, il23ToIL5RewardRecvIMeanAbsW, il23ToIL5RewardRecvIMaxAbsW] = iInhibitoryCircuitWeightSummary(Mouse, Params)
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
iL23Cols = Params.NL23L5 + (1:Params.NIL23);
iL5RewardRecvICols = Params.NL23L5 + Params.NIL23 + (1:Params.NIL5RewardRecv);
iL5RewardRecvIRows = iL5RewardRecvICols;
il23ToReadW = Mouse.W_InternalToInternal(readoutRows, iL23Cols);
il5RewardRecvIToReadW = Mouse.W_InternalToInternal(readoutRows, iL5RewardRecvICols);
il23ToIL5RewardRecvIW = Mouse.W_InternalToInternal(iL5RewardRecvIRows, iL23Cols);
il23ToReadMeanAbsW = iMeanFlat(abs(il23ToReadW));
il23ToReadMaxAbsW = iMaxFlat(abs(il23ToReadW));
il5RewardRecvIToReadMeanAbsW = iMeanFlat(abs(il5RewardRecvIToReadW));
il5RewardRecvIToReadMaxAbsW = iMaxFlat(abs(il5RewardRecvIToReadW));
il23ToIL5RewardRecvIMeanAbsW = iMeanFlat(abs(il23ToIL5RewardRecvIW));
il23ToIL5RewardRecvIMaxAbsW = iMaxFlat(abs(il23ToIL5RewardRecvIW));
end

function Result = iSummarizeMouseTraining(perf, h23, h5, sessionMeanL23, sessionMeanL5, thAfferentDelta, Params)
first100 = find(perf >= Params.SlopeHitPerfect, 1, 'first');
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
	finalMeanL23 = mean(sessionMeanL23(:, useIdx), 2, 'omitnan');
	finalMeanL5  = mean(sessionMeanL5(:,  useIdx), 2, 'omitnan');
	resultSlope = fitP(1);
	resultDeltaHit = mean(dh, 'omitnan');
	resultMeanH23 = iRestrictedStd(finalMeanL23);
	resultMeanH5  = iRestrictedStd(finalMeanL5);
elseif ~isempty(useIdx)
	finalMeanL5 = mean(sessionMeanL5(:, useIdx), 2, 'omitnan');
	resultSlope = NaN;
	resultDeltaHit = NaN;
	resultMeanH23 = NaN;
	resultMeanH5 = NaN;
else
	finalMeanL5 = nan(Params.NL5, 1);
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
Result.ProcessMeanL5 = finalMeanL5;
Result.THAfferentDelta = thAfferentDelta;
Result.MeanTHAfferentDelta = mean(thAfferentDelta, 'omitnan');
end

function Mouse = iDrawMouse(Params)
% Fixed input / target patterns.
% Cue patterns are binary direct-drive masks on L2/3 cells: full response or 0.
% PreCue and Cue share a common latent component, while their positive L2/3
% cue-tagged cells are forced to be disjoint.
a = Params.CueModalityCorr;
sharedCue = iRandn(Params.NL23, Params);
preCueU   = iRandn(Params.NL23, Params);
cueU      = iRandn(Params.NL23, Params);
preCueLatent = a * sharedCue + sqrt(1 - a^2) * preCueU;
cueLatent = a * sharedCue + sqrt(1 - a^2) * cueU;
Mouse.PreCueL23Pattern = iVertexPattern(preCueLatent, Params.ResponseScale);
preCuePositiveMask = Mouse.PreCueL23Pattern > 0;
nCueL23Active = round(Params.CueL23ActiveFractionOfPreCue * nnz(preCuePositiveMask));
cueLatent(preCuePositiveMask) = -inf;
Mouse.CueL23Pattern = iFixedActiveVertexPattern(cueLatent, Params.ResponseScale, nCueL23Active);
Mouse.THRewardPattern    = iStandardize(iRandn(Params.NReward, Params) + 0.55 * sign(iRandn(Params.NReward, Params)));
Mouse.L5ReadoutPattern   = iVertexPattern(iRandn(Params.NL5Read, Params) + 0.55 * sign(iRandn(Params.NL5Read, Params)), Params.ResponseScale);
% Initial reward afferent map into L5 reward-receiving cells.
Mouse.Z_RewardToL5RewardRecv = iInitChiSquareAccumulator([Params.NL5RewardRecv, Params.NReward], Params.InitAfferentAccumulatorScale, Params.InitAfferentAccumulatorChiSquareDof, Params);
Mouse.Z_RewardToIL5RewardRecv = iInitChiSquareAccumulator([Params.NIL5RewardRecv, Params.NReward], Params.InitAfferentAccumulatorScale, Params.InitAfferentAccumulatorChiSquareDof, Params);
[Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv] = iShiftPairedColumnsToNonnegative(Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv);
[Mouse.W_RewardToL5RewardRecv, Mouse.W_RewardToIL5RewardRecv] = iPairedAccumulatorToExcitatoryWeight(Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, Params.AfferentWCap, Params.WeightMapSlope);

% Plastic internal recurrent matrix, W(post, pre). E presynaptic columns are
% nonnegative; I presynaptic columns are nonpositive. Thus the matrix contains
% EE, EI, IE, and II connections under Dale's law.
Mouse.Z_InternalToInternal = iInitChiSquareAccumulator([Params.NInternal, Params.NInternal], Params.InitRecurrentAccumulatorScale, Params.InitRecurrentAccumulatorChiSquareDof, Params);
Mouse.Z_InternalToInternal = iShiftRecurrentColumnsToNonnegative(Mouse.Z_InternalToInternal);
Mouse.W_InternalToInternal = iAccumulatorToInternalWeight(Mouse.Z_InternalToInternal, Params);
Mouse.RewardPretrainDiagnostics = struct();

end

function Mouse = iPretrainMouse(Mouse, Params)
% Pretraining uses PreCueL23Pattern and keeps structured TH input intact.
pretrainCond.THInputIsNoise = false;
pretrainParams = Params;
lastPerfObserved = NaN;
lastPerfExpected = NaN;
postCeilingCount = 0;
cuePretrainDiag = iInitCuePretrainDiagnostics(pretrainParams);

for iSess = 1:pretrainParams.MaxPretrainSessions
	[perfObserved, Signals, perfExpected, Mouse] = iSimulateSession(Mouse, pretrainParams, pretrainCond, true);
	lastPerfObserved = perfObserved;
	lastPerfExpected = perfExpected;
	cuePretrainDiag = iRecordCuePretrainDiagnostics(cuePretrainDiag, iSess, Mouse, Signals, perfObserved, perfExpected, pretrainParams);

	if perfObserved >= pretrainParams.Ceiling || perfExpected >= pretrainParams.Ceiling
		postCeilingCount = postCeilingCount + 1;
		if postCeilingCount >= pretrainParams.PostCeilingSessions
			Mouse.CuePretrainDiagnostics = cuePretrainDiag;
			return;
		end
	end
	Mouse = iOvernightConsolidate(Mouse, pretrainParams);
end

diagMessage = iCuePretrainDiagnosticMessage(cuePretrainDiag);
error('THModel:PretrainDidNotReachCeiling', 'Pretraining did not reach ceiling within %d sessions. Final observed hit = %.3f, final expected hit = %.3f. %s', ...
	pretrainParams.MaxPretrainSessions, lastPerfObserved, lastPerfExpected, diagMessage);
end

function Cond = iFullRewardCondition()
Cond.THInputIsNoise = false;
end

function Mouse = iPretrainRewardReadout(Mouse, Params, condName, iMouse)
rewardCond = iFullRewardCondition();
rewardParams = Params;
rewardParams.InternalRecurrentPasses = Params.RewardPretrainDecisionPasses;
eligRewardAfferent = iZeroCellEligibility(Params.NReward, Params.NL5RewardRecv + Params.NIL5RewardRecv, Params);
eligInternal = iZeroCellEligibility(Params.NInternal, Params.NInternal, Params);
consecutiveHits = 0;
lastReadoutDrive = NaN;
rewardPretrainDiag = iInitRewardPretrainDiagnostics(Params);

for iTrial = 1:Params.MaxRewardPretrainTrials
	[isHit, activityHistory, rReward, lastReadoutDrive] = iRewardSignalDecisionTrial(Mouse, rewardParams, rewardCond);
	naturalActivityHistory = activityHistory;
	if isHit
		consecutiveHits = consecutiveHits + 1;
	else
		consecutiveHits = 0;
		activityHistory = iOverwriteReadoutHistory(activityHistory, Mouse, Params);
	end
	[eligRewardAfferent, eligInternal] = iUpdateRewardHistoryEligibility(eligRewardAfferent, eligInternal, activityHistory, rReward, Params);
	[eligRewardToL5RewardRecv, eligRewardToIL5RewardRecv] = iPairedCellEligibilityToSynapseEligibility(eligRewardAfferent, Params.NL5RewardRecv);
	eligInternalToInternal = iRecurrentCellEligibilityToSynapseEligibility(eligInternal, Params);
	traceEta = Params.HebbRate * Params.EligibilityTraceScale;
	isPunishment = false;
	[Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, Mouse.W_RewardToL5RewardRecv, Mouse.W_RewardToIL5RewardRecv] = iApplyLatentPairedHebbTrace(Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, eligRewardToL5RewardRecv, eligRewardToIL5RewardRecv, traceEta, Params.AfferentWCap, Params.WeightMapSlope, isPunishment);
	[Mouse.Z_InternalToInternal, Mouse.W_InternalToInternal] = iApplyLatentInternalTrace(Mouse.Z_InternalToInternal, eligInternalToInternal, traceEta, Params, isPunishment);
	rewardPretrainDiag = iRecordRewardPretrainDiagnostics(rewardPretrainDiag, iTrial, Mouse, Params, isHit, naturalActivityHistory, activityHistory, lastReadoutDrive, eligInternalToInternal);
	if consecutiveHits >= Params.RewardPretrainSuccessStreak
		Mouse.RewardPretrainDiagnostics = rewardPretrainDiag;
		fprintf('%s mouse %d reward-signal pretraining reached %d consecutive hits at trial %d. %s\n', ...
			condName, iMouse, Params.RewardPretrainSuccessStreak, iTrial, iRewardPretrainDiagnosticMessage(rewardPretrainDiag));
		return;
	end
end

diagMessage = iRewardPretrainDiagnosticMessage(rewardPretrainDiag);
error('THModel:RewardPretrainDidNotReachStreak', ...
	'%s mouse %d reward-signal pretraining did not reach %d consecutive hits within %d trials. Last readout similarity = %.3f, threshold = %.3f. %s', ...
	condName, iMouse, Params.RewardPretrainSuccessStreak, Params.MaxRewardPretrainTrials, lastReadoutDrive, Params.HitThreshold, diagMessage);
end

function [isHit, activityHistory, rReward, readoutDrive] = iRewardSignalDecisionTrial(Mouse, Params, Cond)
[preL23, preIL23] = iNoCueL23Pre(Params);
rReward = iRunTHInput(Mouse, Params, Cond, "reward");
[preL5RewardRecv, preIL5RewardRecv] = iRewardAfferentPre(Mouse, rReward, Params);
preL5Read = Params.NoiseRead * iRandn(Params.NL5Read, Params);
[~, ~, ~, ~, readoutDriveTrace, activityHistory] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, Params, preIL23, preIL5RewardRecv);
readoutDrive = max(readoutDriveTrace);
isHit = any(readoutDriveTrace >= Params.HitThreshold);
end

function activityHistory = iOverwriteReadoutHistory(activityHistory, Mouse, Params)
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
for iState = 1:size(activityHistory, 2)
	activityHistory(readoutRows, iState) = Mouse.L5ReadoutPattern;
end
end

function [internalActivity, rL5Read] = iReplaceReadoutWithPerfectPattern(internalActivity, Mouse, Params)
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
rL5Read = Mouse.L5ReadoutPattern;
internalActivity(readoutRows, :) = rL5Read;
end

function learningActivityHistory = iRunTeacherReadoutIterations(decisionActivity, rewardActivity, Mouse, Params)
learningActivityHistory = iZeros([Params.NInternal, Params.TeacherReadoutPasses], Params);
internalActivity = decisionActivity;
[preL5RewardRecv, preIL5RewardRecv] = iRewardAfferentPre(Mouse, rewardActivity, Params);
externalPre = iBuildInternalPre(iZeros(Params.NL23, Params), preL5RewardRecv, iZeros(Params.NL5Read, Params), Params, iZeros(Params.NIL23, Params), preIL5RewardRecv);
for iPass = 1:Params.TeacherReadoutPasses
	internalActivity = iSetReadoutToTeacher(internalActivity, Mouse, Params);
	recurrentPre = externalPre + Mouse.W_InternalToInternal * internalActivity;
	recurrentPre = iAddIterationNoise(recurrentPre, Params);
	nextActivity = iRunInternalAreas(recurrentPre, Mouse, Params);
	internalActivity = iCarryInternalState(internalActivity, nextActivity, Params);
	internalActivity = iSetReadoutToTeacher(internalActivity, Mouse, Params);
	learningActivityHistory(:, iPass) = internalActivity;
end
end

function internalActivity = iSetReadoutToTeacher(internalActivity, Mouse, Params)
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
internalActivity(readoutRows, :) = Mouse.L5ReadoutPattern;
end

function [eligRewardAfferent, eligInternal] = iUpdateRewardHistoryEligibility(eligRewardAfferent, eligInternal, activityHistory, rReward, Params)
rewardHistory = repmat(rReward, 1, size(activityHistory, 2));
eligRewardAfferent = iUpdateRewardAfferentHistoryEligibility(eligRewardAfferent, activityHistory, rewardHistory, Params);
eligInternal = iUpdateInternalHistoryEligibility(eligInternal, activityHistory, Params);
end

function cuePretrainDiag = iInitCuePretrainDiagnostics(Params)
nSess = Params.MaxPretrainSessions;
cuePretrainDiag.PerfObserved = nan(nSess, 1);
cuePretrainDiag.PerfExpected = nan(nSess, 1);
cuePretrainDiag.DecisionDriveMean = nan(nSess, 1);
cuePretrainDiag.DecisionDriveMax = nan(nSess, 1);
cuePretrainDiag.BaselineCorrectionMean = nan(nSess, 1);
cuePretrainDiag.BaselineCorrectionMax = nan(nSess, 1);
cuePretrainDiag.BaselineMaxDriveMean = nan(nSess, 1);
cuePretrainDiag.BaselineMaxDriveMax = nan(nSess, 1);
cuePretrainDiag.BaselineFinalDriveMean = nan(nSess, 1);
cuePretrainDiag.BaselineFinalDriveMax = nan(nSess, 1);
cuePretrainDiag.BaselineTargetL23PreMean = nan(nSess, 1);
cuePretrainDiag.BaselineTargetRewardRecvPreMean = nan(nSess, 1);
cuePretrainDiag.BaselineTargetReadRecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.BaselineTargetIL23PreMean = nan(nSess, 1);
cuePretrainDiag.BaselineTargetIL5RewardRecvIPreMean = nan(nSess, 1);
cuePretrainDiag.BaselineTargetL2NetPreMean = nan(nSess, 1);
cuePretrainDiag.BaselineTargetL5NetPreMean = nan(nSess, 1);
cuePretrainDiag.BaselineTargetNetPreMean = nan(nSess, 1);
cuePretrainDiag.CueL23Mean = nan(nSess, 1);
cuePretrainDiag.CueL23Max = nan(nSess, 1);
cuePretrainDiag.CueRewardRecvMean = nan(nSess, 1);
cuePretrainDiag.CueRewardRecvMax = nan(nSess, 1);
cuePretrainDiag.CueReadMean = nan(nSess, 1);
cuePretrainDiag.CueReadMax = nan(nSess, 1);
cuePretrainDiag.CueReadTargetMean = nan(nSess, 1);
cuePretrainDiag.CueReadTargetMax = nan(nSess, 1);
cuePretrainDiag.CueReadNonTargetMean = nan(nSess, 1);
cuePretrainDiag.CueReadNonTargetMax = nan(nSess, 1);
cuePretrainDiag.CueIL23Mean = nan(nSess, 1);
cuePretrainDiag.CueIL23Max = nan(nSess, 1);
cuePretrainDiag.CueIL5RewardRecvIMean = nan(nSess, 1);
cuePretrainDiag.CueIL5RewardRecvIMax = nan(nSess, 1);
cuePretrainDiag.LearnL23Mean = nan(nSess, 1);
cuePretrainDiag.LearnL23Max = nan(nSess, 1);
cuePretrainDiag.LearnL23Sum = nan(nSess, 1);
cuePretrainDiag.LearnRewardRecvMean = nan(nSess, 1);
cuePretrainDiag.LearnRewardRecvMax = nan(nSess, 1);
cuePretrainDiag.LearnRewardRecvSum = nan(nSess, 1);
cuePretrainDiag.RewardRecvCueLearnCorr = nan(nSess, 1);
cuePretrainDiag.RewardRecvCueLearnMeanDelta = nan(nSess, 1);
cuePretrainDiag.RewardRecvCueLearnRMSDelta = nan(nSess, 1);
cuePretrainDiag.RewardRecvCueLearnHigherFraction = nan(nSess, 1);
cuePretrainDiag.RewardRecvCueLearnTopQuartileOverlap = nan(nSess, 1);
cuePretrainDiag.LearnReadMean = nan(nSess, 1);
cuePretrainDiag.LearnReadMax = nan(nSess, 1);
cuePretrainDiag.LearnReadTargetCount = nan(nSess, 1);
cuePretrainDiag.LearnReadTargetMean = nan(nSess, 1);
cuePretrainDiag.LearnReadTargetSum = nan(nSess, 1);
cuePretrainDiag.LearnReadNonTargetMean = nan(nSess, 1);
cuePretrainDiag.LearnReadNonTargetSum = nan(nSess, 1);
cuePretrainDiag.RewardToRewardRecvZDistribution = strings(nSess, 1);
cuePretrainDiag.RewardToIL5RewardRecvZDistribution = strings(nSess, 1);
cuePretrainDiag.RewardToRewardRecvMeanW = nan(nSess, 1);
cuePretrainDiag.RewardToRewardRecvMaxW = nan(nSess, 1);
cuePretrainDiag.RewardToIL5RewardRecvMeanW = nan(nSess, 1);
cuePretrainDiag.RewardToIL5RewardRecvMaxW = nan(nSess, 1);
cuePretrainDiag.L23ToRewardRecvMeanW = nan(nSess, 1);
cuePretrainDiag.L23ToRewardRecvMaxW = nan(nSess, 1);
cuePretrainDiag.L23ToReadMeanW = nan(nSess, 1);
cuePretrainDiag.L23ToReadMaxW = nan(nSess, 1);
cuePretrainDiag.L23ToTargetReadMeanW = nan(nSess, 1);
cuePretrainDiag.L23ToTargetReadMaxW = nan(nSess, 1);
cuePretrainDiag.L23ToNonTargetReadMeanW = nan(nSess, 1);
cuePretrainDiag.L23ToNonTargetReadMaxW = nan(nSess, 1);
cuePretrainDiag.L23ToTargetReadEligibilityMean = nan(nSess, 1);
cuePretrainDiag.L23ToNonTargetReadEligibilityMean = nan(nSess, 1);
cuePretrainDiag.L23OutL23ZShareMean = nan(nSess, 1);
cuePretrainDiag.L23OutRewardRecvZShareMean = nan(nSess, 1);
cuePretrainDiag.L23OutTargetReadZShareMean = nan(nSess, 1);
cuePretrainDiag.L23OutNonTargetReadZShareMean = nan(nSess, 1);
cuePretrainDiag.L23OutIL23ZShareMean = nan(nSess, 1);
cuePretrainDiag.L23OutIL5RewardRecvIZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvToReadMeanW = nan(nSess, 1);
cuePretrainDiag.RewardRecvToReadMaxW = nan(nSess, 1);
cuePretrainDiag.RewardRecvToTargetReadMeanW = nan(nSess, 1);
cuePretrainDiag.RewardRecvToTargetReadMaxW = nan(nSess, 1);
cuePretrainDiag.RewardRecvToNonTargetReadMeanW = nan(nSess, 1);
cuePretrainDiag.RewardRecvToNonTargetReadMaxW = nan(nSess, 1);
cuePretrainDiag.RewardRecvToTargetReadEligibilityMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvToNonTargetReadEligibilityMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutL23ZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutRewardRecvZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutTargetReadZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutNonTargetReadZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutIL23ZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutIL5RewardRecvIZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutL23PerCellZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutRewardRecvPerCellZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutTargetReadPerCellZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutNonTargetReadPerCellZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutIL23PerCellZShareMean = nan(nSess, 1);
cuePretrainDiag.RewardRecvOutIL5RewardRecvIPerCellZShareMean = nan(nSess, 1);
cuePretrainDiag.ExcToReadMeanW = nan(nSess, 1);
cuePretrainDiag.ExcToReadMaxW = nan(nSess, 1);
cuePretrainDiag.InhToReadMeanAbsW = nan(nSess, 1);
cuePretrainDiag.InhToReadMaxAbsW = nan(nSess, 1);
cuePretrainDiag.IL23ToReadMeanAbsW = nan(nSess, 1);
cuePretrainDiag.IL23ToReadMaxAbsW = nan(nSess, 1);
cuePretrainDiag.IL5RewardRecvIToReadMeanAbsW = nan(nSess, 1);
cuePretrainDiag.IL5RewardRecvIToReadMaxAbsW = nan(nSess, 1);
cuePretrainDiag.IL23ToIL5RewardRecvIMeanAbsW = nan(nSess, 1);
cuePretrainDiag.IL23ToIL5RewardRecvIMaxAbsW = nan(nSess, 1);
cuePretrainDiag.IL23ToIL5RewardRecvIPreMean = nan(nSess, 1);
cuePretrainDiag.IL23ToIL5RewardRecvIPreMin = nan(nSess, 1);
cuePretrainDiag.IL23ToIL5RewardRecvIPreMeanAbs = nan(nSess, 1);
cuePretrainDiag.IL23ToIL5RewardRecvIPreMaxAbs = nan(nSess, 1);
cuePretrainDiag.THToIL5RewardRecvIPreMean = nan(nSess, 1);
cuePretrainDiag.THToIL5RewardRecvIPreMax = nan(nSess, 1);
cuePretrainDiag.ReadTargetL23PreMean = nan(nSess, 1);
cuePretrainDiag.ReadTargetRewardRecvPreMean = nan(nSess, 1);
cuePretrainDiag.ReadTargetReadPreMean = nan(nSess, 1);
cuePretrainDiag.ReadTargetExcPreMean = nan(nSess, 1);
cuePretrainDiag.ReadTargetIL23PreMean = nan(nSess, 1);
cuePretrainDiag.ReadTargetIL5RewardRecvIPreMean = nan(nSess, 1);
cuePretrainDiag.ReadTargetInhPreMean = nan(nSess, 1);
cuePretrainDiag.ReadTargetNetRecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.ReadNonTargetExcPreMean = nan(nSess, 1);
cuePretrainDiag.ReadNonTargetInhPreMean = nan(nSess, 1);
cuePretrainDiag.ReadNonTargetNetRecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.IL5RewardRecvIExcRecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.IL5RewardRecvIInhRecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.IL5RewardRecvINetRecurrentPreMean = nan(nSess, 1);
end

function cuePretrainDiag = iRecordCuePretrainDiagnostics(cuePretrainDiag, iSess, Mouse, Signals, perfObserved, perfExpected, Params)
l23Cols = 1:Params.NL23;
rewardRecvRows = Params.NL23 + (1:Params.NL5RewardRecv);
rewardRecvCols = rewardRecvRows;
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
allExcCols = 1:Params.NL23L5;
hiddenECols = 1:(Params.NL23 + Params.NL5RewardRecv);
hiddenICols = Params.NL23L5 + (1:Params.NIInternal);
iL23Cols = Params.NL23L5 + (1:Params.NIL23);
iL5RewardRecvICols = Params.NL23L5 + Params.NIL23 + (1:Params.NIL5RewardRecv);
iL5RewardRecvIRows = iL5RewardRecvICols;
cueRewardRecv = Signals.ProcessMeanL5(1:Params.NL5RewardRecv);
cueRead = Signals.ProcessMeanL5(Params.NL5RewardRecv + (1:Params.NL5Read));
internalWeight = iGatherValue(Mouse.W_InternalToInternal);
internalAccumulator = iGatherValue(Mouse.Z_InternalToInternal);
internalEligibility = iGatherValue(Signals.InternalEligibility);
cueInternalMean = [iGatherValue(Signals.ProcessMeanL23(:)); iGatherValue(cueRewardRecv(:)); iGatherValue(cueRead(:)); iGatherValue(Signals.ProcessMeanIL23(:)); iGatherValue(Signals.ProcessMeanIL5RewardRecvI(:))];
readPattern = iGatherValue(Mouse.L5ReadoutPattern(:));
readTargetMask = readPattern > 0;
readNonTargetMask = ~readTargetMask;
targetReadRows = readoutRows(readTargetMask);
nonTargetReadRows = readoutRows(readNonTargetMask);
l23OutputShare = iColumnDistribution(internalAccumulator(:, l23Cols));
rewardRecvOutputShare = iColumnDistribution(internalAccumulator(:, rewardRecvCols));
l23ToReadPre = internalWeight(readoutRows, l23Cols) * cueInternalMean(l23Cols);
rewardRecvToReadPre = internalWeight(readoutRows, rewardRecvCols) * cueInternalMean(rewardRecvCols);
readToReadPre = internalWeight(readoutRows, readoutRows) * cueInternalMean(readoutRows);
excToReadPre = internalWeight(readoutRows, allExcCols) * cueInternalMean(allExcCols);
il23ToReadPre = internalWeight(readoutRows, iL23Cols) * cueInternalMean(iL23Cols);
il5RewardRecvIToReadPre = internalWeight(readoutRows, iL5RewardRecvICols) * cueInternalMean(iL5RewardRecvICols);
inhToReadPre = internalWeight(readoutRows, hiddenICols) * cueInternalMean(hiddenICols);
netReadRecurrentPre = excToReadPre + inhToReadPre;
il5RewardRecvIExcPre = internalWeight(iL5RewardRecvIRows, allExcCols) * cueInternalMean(allExcCols);
il5RewardRecvIInhPre = internalWeight(iL5RewardRecvIRows, hiddenICols) * cueInternalMean(hiddenICols);
il5RewardRecvINetRecurrentPre = il5RewardRecvIExcPre + il5RewardRecvIInhPre;
l23ToRewardRecvW = Mouse.W_InternalToInternal(rewardRecvRows, l23Cols);
l23ToReadW = Mouse.W_InternalToInternal(readoutRows, l23Cols);
rewardRecvToReadW = Mouse.W_InternalToInternal(readoutRows, rewardRecvCols);
excToReadW = Mouse.W_InternalToInternal(readoutRows, hiddenECols);
inhToReadW = Mouse.W_InternalToInternal(readoutRows, hiddenICols);
il23ToReadW = Mouse.W_InternalToInternal(readoutRows, iL23Cols);
il5RewardRecvIToReadW = Mouse.W_InternalToInternal(readoutRows, iL5RewardRecvICols);
il23ToIL5RewardRecvIW = Mouse.W_InternalToInternal(iL5RewardRecvIRows, iL23Cols);

cuePretrainDiag.PerfObserved(iSess) = perfObserved;
cuePretrainDiag.PerfExpected(iSess) = perfExpected;
cuePretrainDiag.DecisionDriveMean(iSess) = Signals.DecisionReadoutDriveMean;
cuePretrainDiag.DecisionDriveMax(iSess) = Signals.DecisionReadoutDriveMax;
cuePretrainDiag.BaselineCorrectionMean(iSess) = Signals.BaselineCorrectionMean;
cuePretrainDiag.BaselineCorrectionMax(iSess) = Signals.BaselineCorrectionMax;
cuePretrainDiag.BaselineMaxDriveMean(iSess) = Signals.BaselineMaxDriveMean;
cuePretrainDiag.BaselineMaxDriveMax(iSess) = Signals.BaselineMaxDriveMax;
cuePretrainDiag.BaselineFinalDriveMean(iSess) = Signals.BaselineFinalDriveMean;
cuePretrainDiag.BaselineFinalDriveMax(iSess) = Signals.BaselineFinalDriveMax;
cuePretrainDiag.BaselineTargetL23PreMean(iSess) = Signals.BaselineTargetL23PreMean;
cuePretrainDiag.BaselineTargetRewardRecvPreMean(iSess) = Signals.BaselineTargetRewardRecvPreMean;
cuePretrainDiag.BaselineTargetReadRecurrentPreMean(iSess) = Signals.BaselineTargetReadRecurrentPreMean;
cuePretrainDiag.BaselineTargetIL23PreMean(iSess) = Signals.BaselineTargetIL23PreMean;
cuePretrainDiag.BaselineTargetIL5RewardRecvIPreMean(iSess) = Signals.BaselineTargetIL5RewardRecvIPreMean;
cuePretrainDiag.BaselineTargetL2NetPreMean(iSess) = Signals.BaselineTargetL2NetPreMean;
cuePretrainDiag.BaselineTargetL5NetPreMean(iSess) = Signals.BaselineTargetL5NetPreMean;
cuePretrainDiag.BaselineTargetNetPreMean(iSess) = Signals.BaselineTargetNetPreMean;
cuePretrainDiag.CueL23Mean(iSess) = iMeanFlat(Signals.ProcessMeanL23);
cuePretrainDiag.CueL23Max(iSess) = iMaxFlat(Signals.ProcessMeanL23);
cuePretrainDiag.CueRewardRecvMean(iSess) = iMeanFlat(cueRewardRecv);
cuePretrainDiag.CueRewardRecvMax(iSess) = iMaxFlat(cueRewardRecv);
cuePretrainDiag.CueReadMean(iSess) = iMeanFlat(cueRead);
cuePretrainDiag.CueReadMax(iSess) = iMaxFlat(cueRead);
cuePretrainDiag.CueReadTargetMean(iSess) = iMeanFlat(cueRead(readTargetMask));
cuePretrainDiag.CueReadTargetMax(iSess) = iMaxFlat(cueRead(readTargetMask));
cuePretrainDiag.CueReadNonTargetMean(iSess) = iMeanFlat(cueRead(readNonTargetMask));
cuePretrainDiag.CueReadNonTargetMax(iSess) = iMaxFlat(cueRead(readNonTargetMask));
cuePretrainDiag.CueIL23Mean(iSess) = iMeanFlat(Signals.ProcessMeanIL23);
cuePretrainDiag.CueIL23Max(iSess) = iMaxFlat(Signals.ProcessMeanIL23);
cuePretrainDiag.CueIL5RewardRecvIMean(iSess) = iMeanFlat(Signals.ProcessMeanIL5RewardRecvI);
cuePretrainDiag.CueIL5RewardRecvIMax(iSess) = iMaxFlat(Signals.ProcessMeanIL5RewardRecvI);
cuePretrainDiag.LearnL23Mean(iSess) = iMeanFlat(Signals.mL23);
cuePretrainDiag.LearnL23Max(iSess) = iMaxFlat(Signals.mL23);
cuePretrainDiag.LearnL23Sum(iSess) = sum(iGatherValue(Signals.mL23(:)), 'omitnan');
cuePretrainDiag.LearnRewardRecvMean(iSess) = iMeanFlat(Signals.mL5RewardRecv);
cuePretrainDiag.LearnRewardRecvMax(iSess) = iMaxFlat(Signals.mL5RewardRecv);
cuePretrainDiag.LearnRewardRecvSum(iSess) = sum(iGatherValue(Signals.mL5RewardRecv(:)), 'omitnan');
learnRewardRecv = iGatherValue(Signals.mL5RewardRecv(:));
cueRewardRecvNow = iGatherValue(cueRewardRecv(:));
rewardRecvDelta = learnRewardRecv - cueRewardRecvNow;
nTopRewardRecv = max(1, round(0.25 * Params.NL5RewardRecv));
[~, cueRewardRecvOrder] = sort(cueRewardRecvNow, 'descend');
[~, learnRewardRecvOrder] = sort(learnRewardRecv, 'descend');
cuePretrainDiag.RewardRecvCueLearnCorr(iSess) = iGatherScalar(corr(cueRewardRecvNow, learnRewardRecv));
cuePretrainDiag.RewardRecvCueLearnMeanDelta(iSess) = iMeanFlat(rewardRecvDelta);
cuePretrainDiag.RewardRecvCueLearnRMSDelta(iSess) = iRootMeanSquareFlat(rewardRecvDelta);
cuePretrainDiag.RewardRecvCueLearnHigherFraction(iSess) = mean(learnRewardRecv > cueRewardRecvNow);
cuePretrainDiag.RewardRecvCueLearnTopQuartileOverlap(iSess) = numel(intersect(cueRewardRecvOrder(1:nTopRewardRecv), learnRewardRecvOrder(1:nTopRewardRecv))) / nTopRewardRecv;
cuePretrainDiag.LearnReadMean(iSess) = iMeanFlat(Signals.mL5Read);
cuePretrainDiag.LearnReadMax(iSess) = iMaxFlat(Signals.mL5Read);
learnRead = iGatherValue(Signals.mL5Read(:));
cuePretrainDiag.LearnReadTargetCount(iSess) = nnz(readTargetMask);
cuePretrainDiag.LearnReadTargetMean(iSess) = iMeanFlat(learnRead(readTargetMask));
cuePretrainDiag.LearnReadTargetSum(iSess) = sum(learnRead(readTargetMask), 'omitnan');
cuePretrainDiag.LearnReadNonTargetMean(iSess) = iMeanFlat(learnRead(readNonTargetMask));
cuePretrainDiag.LearnReadNonTargetSum(iSess) = sum(learnRead(readNonTargetMask), 'omitnan');
cuePretrainDiag.RewardToRewardRecvZDistribution(iSess) = string(iDistributionText(Mouse.Z_RewardToL5RewardRecv));
cuePretrainDiag.RewardToIL5RewardRecvZDistribution(iSess) = string(iDistributionText(Mouse.Z_RewardToIL5RewardRecv));
cuePretrainDiag.RewardToRewardRecvMeanW(iSess) = iMeanFlat(Mouse.W_RewardToL5RewardRecv);
cuePretrainDiag.RewardToRewardRecvMaxW(iSess) = iMaxFlat(Mouse.W_RewardToL5RewardRecv);
cuePretrainDiag.RewardToIL5RewardRecvMeanW(iSess) = iMeanFlat(Mouse.W_RewardToIL5RewardRecv);
cuePretrainDiag.RewardToIL5RewardRecvMaxW(iSess) = iMaxFlat(Mouse.W_RewardToIL5RewardRecv);
cuePretrainDiag.L23ToRewardRecvMeanW(iSess) = iMeanFlat(l23ToRewardRecvW);
cuePretrainDiag.L23ToRewardRecvMaxW(iSess) = iMaxFlat(l23ToRewardRecvW);
cuePretrainDiag.L23ToReadMeanW(iSess) = iMeanFlat(l23ToReadW);
cuePretrainDiag.L23ToReadMaxW(iSess) = iMaxFlat(l23ToReadW);
cuePretrainDiag.L23ToTargetReadMeanW(iSess) = iMeanFlat(l23ToReadW(readTargetMask, :));
cuePretrainDiag.L23ToTargetReadMaxW(iSess) = iMaxFlat(l23ToReadW(readTargetMask, :));
cuePretrainDiag.L23ToNonTargetReadMeanW(iSess) = iMeanFlat(l23ToReadW(readNonTargetMask, :));
cuePretrainDiag.L23ToNonTargetReadMaxW(iSess) = iMaxFlat(l23ToReadW(readNonTargetMask, :));
cuePretrainDiag.L23ToTargetReadEligibilityMean(iSess) = iMeanFlat(internalEligibility(targetReadRows, l23Cols));
cuePretrainDiag.L23ToNonTargetReadEligibilityMean(iSess) = iMeanFlat(internalEligibility(nonTargetReadRows, l23Cols));
cuePretrainDiag.L23OutL23ZShareMean(iSess) = iMeanFlat(sum(l23OutputShare(l23Cols, :), 1));
cuePretrainDiag.L23OutRewardRecvZShareMean(iSess) = iMeanFlat(sum(l23OutputShare(rewardRecvRows, :), 1));
cuePretrainDiag.L23OutTargetReadZShareMean(iSess) = iMeanFlat(sum(l23OutputShare(targetReadRows, :), 1));
cuePretrainDiag.L23OutNonTargetReadZShareMean(iSess) = iMeanFlat(sum(l23OutputShare(nonTargetReadRows, :), 1));
cuePretrainDiag.L23OutIL23ZShareMean(iSess) = iMeanFlat(sum(l23OutputShare(iL23Cols, :), 1));
cuePretrainDiag.L23OutIL5RewardRecvIZShareMean(iSess) = iMeanFlat(sum(l23OutputShare(iL5RewardRecvICols, :), 1));
cuePretrainDiag.RewardRecvToReadMeanW(iSess) = iMeanFlat(rewardRecvToReadW);
cuePretrainDiag.RewardRecvToReadMaxW(iSess) = iMaxFlat(rewardRecvToReadW);
cuePretrainDiag.RewardRecvToTargetReadMeanW(iSess) = iMeanFlat(rewardRecvToReadW(readTargetMask, :));
cuePretrainDiag.RewardRecvToTargetReadMaxW(iSess) = iMaxFlat(rewardRecvToReadW(readTargetMask, :));
cuePretrainDiag.RewardRecvToNonTargetReadMeanW(iSess) = iMeanFlat(rewardRecvToReadW(readNonTargetMask, :));
cuePretrainDiag.RewardRecvToNonTargetReadMaxW(iSess) = iMaxFlat(rewardRecvToReadW(readNonTargetMask, :));
cuePretrainDiag.RewardRecvToTargetReadEligibilityMean(iSess) = iMeanFlat(internalEligibility(targetReadRows, rewardRecvCols));
cuePretrainDiag.RewardRecvToNonTargetReadEligibilityMean(iSess) = iMeanFlat(internalEligibility(nonTargetReadRows, rewardRecvCols));
cuePretrainDiag.RewardRecvOutL23ZShareMean(iSess) = iMeanFlat(sum(rewardRecvOutputShare(l23Cols, :), 1));
cuePretrainDiag.RewardRecvOutRewardRecvZShareMean(iSess) = iMeanFlat(sum(rewardRecvOutputShare(rewardRecvRows, :), 1));
cuePretrainDiag.RewardRecvOutTargetReadZShareMean(iSess) = iMeanFlat(sum(rewardRecvOutputShare(targetReadRows, :), 1));
cuePretrainDiag.RewardRecvOutNonTargetReadZShareMean(iSess) = iMeanFlat(sum(rewardRecvOutputShare(nonTargetReadRows, :), 1));
cuePretrainDiag.RewardRecvOutIL23ZShareMean(iSess) = iMeanFlat(sum(rewardRecvOutputShare(iL23Cols, :), 1));
cuePretrainDiag.RewardRecvOutIL5RewardRecvIZShareMean(iSess) = iMeanFlat(sum(rewardRecvOutputShare(iL5RewardRecvICols, :), 1));
cuePretrainDiag.RewardRecvOutL23PerCellZShareMean(iSess) = iMeanFlat(rewardRecvOutputShare(l23Cols, :));
cuePretrainDiag.RewardRecvOutRewardRecvPerCellZShareMean(iSess) = iMeanFlat(rewardRecvOutputShare(rewardRecvRows, :));
cuePretrainDiag.RewardRecvOutTargetReadPerCellZShareMean(iSess) = iMeanFlat(rewardRecvOutputShare(targetReadRows, :));
cuePretrainDiag.RewardRecvOutNonTargetReadPerCellZShareMean(iSess) = iMeanFlat(rewardRecvOutputShare(nonTargetReadRows, :));
cuePretrainDiag.RewardRecvOutIL23PerCellZShareMean(iSess) = iMeanFlat(rewardRecvOutputShare(iL23Cols, :));
cuePretrainDiag.RewardRecvOutIL5RewardRecvIPerCellZShareMean(iSess) = iMeanFlat(rewardRecvOutputShare(iL5RewardRecvICols, :));
cuePretrainDiag.ExcToReadMeanW(iSess) = iMeanFlat(excToReadW);
cuePretrainDiag.ExcToReadMaxW(iSess) = iMaxFlat(excToReadW);
cuePretrainDiag.InhToReadMeanAbsW(iSess) = iMeanFlat(abs(inhToReadW));
cuePretrainDiag.InhToReadMaxAbsW(iSess) = iMaxFlat(abs(inhToReadW));
cuePretrainDiag.IL23ToReadMeanAbsW(iSess) = iMeanFlat(abs(il23ToReadW));
cuePretrainDiag.IL23ToReadMaxAbsW(iSess) = iMaxFlat(abs(il23ToReadW));
cuePretrainDiag.IL5RewardRecvIToReadMeanAbsW(iSess) = iMeanFlat(abs(il5RewardRecvIToReadW));
cuePretrainDiag.IL5RewardRecvIToReadMaxAbsW(iSess) = iMaxFlat(abs(il5RewardRecvIToReadW));
cuePretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(iSess) = iMeanFlat(abs(il23ToIL5RewardRecvIW));
cuePretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(iSess) = iMaxFlat(abs(il23ToIL5RewardRecvIW));
cuePretrainDiag.IL23ToIL5RewardRecvIPreMean(iSess) = Signals.IL23ToIL5RewardRecvIRecurrentPreMean;
cuePretrainDiag.IL23ToIL5RewardRecvIPreMin(iSess) = Signals.IL23ToIL5RewardRecvIRecurrentPreMin;
cuePretrainDiag.IL23ToIL5RewardRecvIPreMeanAbs(iSess) = Signals.IL23ToIL5RewardRecvIRecurrentPreMeanAbs;
cuePretrainDiag.IL23ToIL5RewardRecvIPreMaxAbs(iSess) = Signals.IL23ToIL5RewardRecvIRecurrentPreMaxAbs;
cuePretrainDiag.THToIL5RewardRecvIPreMean(iSess) = Signals.THToIL5RewardRecvIPreMean;
cuePretrainDiag.THToIL5RewardRecvIPreMax(iSess) = Signals.THToIL5RewardRecvIPreMax;
cuePretrainDiag.ReadTargetL23PreMean(iSess) = iMeanFlat(l23ToReadPre(readTargetMask));
cuePretrainDiag.ReadTargetRewardRecvPreMean(iSess) = iMeanFlat(rewardRecvToReadPre(readTargetMask));
cuePretrainDiag.ReadTargetReadPreMean(iSess) = iMeanFlat(readToReadPre(readTargetMask));
cuePretrainDiag.ReadTargetExcPreMean(iSess) = iMeanFlat(excToReadPre(readTargetMask));
cuePretrainDiag.ReadTargetIL23PreMean(iSess) = iMeanFlat(il23ToReadPre(readTargetMask));
cuePretrainDiag.ReadTargetIL5RewardRecvIPreMean(iSess) = iMeanFlat(il5RewardRecvIToReadPre(readTargetMask));
cuePretrainDiag.ReadTargetInhPreMean(iSess) = iMeanFlat(inhToReadPre(readTargetMask));
cuePretrainDiag.ReadTargetNetRecurrentPreMean(iSess) = iMeanFlat(netReadRecurrentPre(readTargetMask));
cuePretrainDiag.ReadNonTargetExcPreMean(iSess) = iMeanFlat(excToReadPre(readNonTargetMask));
cuePretrainDiag.ReadNonTargetInhPreMean(iSess) = iMeanFlat(inhToReadPre(readNonTargetMask));
cuePretrainDiag.ReadNonTargetNetRecurrentPreMean(iSess) = iMeanFlat(netReadRecurrentPre(readNonTargetMask));
cuePretrainDiag.IL5RewardRecvIExcRecurrentPreMean(iSess) = iMeanFlat(il5RewardRecvIExcPre);
cuePretrainDiag.IL5RewardRecvIInhRecurrentPreMean(iSess) = iMeanFlat(il5RewardRecvIInhPre);
cuePretrainDiag.IL5RewardRecvINetRecurrentPreMean(iSess) = iMeanFlat(il5RewardRecvINetRecurrentPre);
end

function diagMessage = iCuePretrainDiagnosticMessage(cuePretrainDiag)
lastSess = find(isfinite(cuePretrainDiag.PerfObserved), 1, 'last');
if isempty(lastSess)
	diagMessage = 'No cue-pretrain diagnostic samples were recorded.';
	return;
end
firstSess = find(isfinite(cuePretrainDiag.PerfObserved), 1, 'first');
useSess = firstSess:lastSess;
growthText = sprintf(['growth deltas per session: decision mean d=%s, target Read mean d=%s, target net pre d=%s, L23 target-Read Z-share d=%s; ', ...
	'early/late mean delta: decision=%.4f/%.4f, target Read=%.4f/%.4f, target net=%.4f/%.4f, L23 target-share=%.4f/%.4f; '], ...
	iFormatDeltaSeries4(cuePretrainDiag.DecisionDriveMean(useSess)), ...
	iFormatDeltaSeries4(cuePretrainDiag.CueReadTargetMean(useSess)), ...
	iFormatDeltaSeries4(cuePretrainDiag.ReadTargetNetRecurrentPreMean(useSess)), ...
	iFormatDeltaSeries4(cuePretrainDiag.L23OutTargetReadZShareMean(useSess)), ...
	iEarlyDeltaMean(cuePretrainDiag.DecisionDriveMean(useSess)), iLateDeltaMean(cuePretrainDiag.DecisionDriveMean(useSess)), ...
	iEarlyDeltaMean(cuePretrainDiag.CueReadTargetMean(useSess)), iLateDeltaMean(cuePretrainDiag.CueReadTargetMean(useSess)), ...
	iEarlyDeltaMean(cuePretrainDiag.ReadTargetNetRecurrentPreMean(useSess)), iLateDeltaMean(cuePretrainDiag.ReadTargetNetRecurrentPreMean(useSess)), ...
	iEarlyDeltaMean(cuePretrainDiag.L23OutTargetReadZShareMean(useSess)), iLateDeltaMean(cuePretrainDiag.L23OutTargetReadZShareMean(useSess)));
trajectoryText = sprintf(['session trajectories: target Read mean=%s, non-target Read mean=%s; ', ...
	'target Read pre L23=%s, RewardRecv=%s, Read recurrent=%s, E total=%s, I total=%s, net=%s; ', ...
	'non-target Read pre E total=%s, I total=%s, net=%s; ', ...
	'L23->target Read W mean/max=%s/%s, L23->non-target Read W mean/max=%s/%s; ', ...
	'L23->target/non-target Read eligibility mean=%s/%s; ', ...
	'L23 outgoing Z-share L23/RewardRecv/targetRead/nonTargetRead/IL23/IL5RewardRecvI=%s/%s/%s/%s/%s/%s; '], ...
	iFormatNumberSeries(cuePretrainDiag.CueReadTargetMean(useSess)), iFormatNumberSeries(cuePretrainDiag.CueReadNonTargetMean(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.ReadTargetL23PreMean(useSess)), iFormatNumberSeries(cuePretrainDiag.ReadTargetRewardRecvPreMean(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.ReadTargetReadPreMean(useSess)), iFormatNumberSeries(cuePretrainDiag.ReadTargetExcPreMean(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.ReadTargetInhPreMean(useSess)), iFormatNumberSeries(cuePretrainDiag.ReadTargetNetRecurrentPreMean(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.ReadNonTargetExcPreMean(useSess)), iFormatNumberSeries(cuePretrainDiag.ReadNonTargetInhPreMean(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.ReadNonTargetNetRecurrentPreMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.L23ToTargetReadMeanW(useSess)), iFormatNumberSeries4(cuePretrainDiag.L23ToTargetReadMaxW(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.L23ToNonTargetReadMeanW(useSess)), iFormatNumberSeries4(cuePretrainDiag.L23ToNonTargetReadMaxW(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.L23ToTargetReadEligibilityMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.L23ToNonTargetReadEligibilityMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.L23OutL23ZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.L23OutRewardRecvZShareMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.L23OutTargetReadZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.L23OutNonTargetReadZShareMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.L23OutIL23ZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.L23OutIL5RewardRecvIZShareMean(useSess)));
rewardRecvCompetitionText = sprintf(['RewardRecv competition: RewardRecv->target Read W mean/max=%s/%s, RewardRecv->non-target Read W mean/max=%s/%s; ', ...
	'RewardRecv->target/non-target Read eligibility mean=%s/%s; ', ...
	'RewardRecv outgoing Z-share L23/RewardRecv/targetRead/nonTargetRead/IL23/IL5RewardRecvI=%s/%s/%s/%s/%s/%s; ', ...
	'RewardRecv outgoing per-cell Z-share L23/RewardRecv/targetRead/nonTargetRead/IL23/IL5RewardRecvI=%s/%s/%s/%s/%s/%s; '], ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvToTargetReadMeanW(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvToTargetReadMaxW(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvToNonTargetReadMeanW(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvToNonTargetReadMaxW(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvToTargetReadEligibilityMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvToNonTargetReadEligibilityMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutL23ZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutRewardRecvZShareMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutTargetReadZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutNonTargetReadZShareMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutIL23ZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutIL5RewardRecvIZShareMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutL23PerCellZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutRewardRecvPerCellZShareMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutTargetReadPerCellZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutNonTargetReadPerCellZShareMean(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutIL23PerCellZShareMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.RewardRecvOutIL5RewardRecvIPerCellZShareMean(useSess)));
cueActivityText = sprintf(['cue activity first/last: L23 mean/max=%.3f/%.3f -> %.3f/%.3f, ', ...
	'RewardRecv mean/max=%.3f/%.3f -> %.3f/%.3f, Read mean/max=%.3f/%.3f -> %.3f/%.3f, ', ...
	'IL23 mean/max=%.3f/%.3f -> %.3f/%.3f, IL5RewardRecvI mean/max=%.3f/%.3f -> %.3f/%.3f; '], ...
	cuePretrainDiag.CueL23Mean(firstSess), cuePretrainDiag.CueL23Max(firstSess), cuePretrainDiag.CueL23Mean(lastSess), cuePretrainDiag.CueL23Max(lastSess), ...
	cuePretrainDiag.CueRewardRecvMean(firstSess), cuePretrainDiag.CueRewardRecvMax(firstSess), cuePretrainDiag.CueRewardRecvMean(lastSess), cuePretrainDiag.CueRewardRecvMax(lastSess), ...
	cuePretrainDiag.CueReadMean(firstSess), cuePretrainDiag.CueReadMax(firstSess), cuePretrainDiag.CueReadMean(lastSess), cuePretrainDiag.CueReadMax(lastSess), ...
	cuePretrainDiag.CueIL23Mean(firstSess), cuePretrainDiag.CueIL23Max(firstSess), cuePretrainDiag.CueIL23Mean(lastSess), cuePretrainDiag.CueIL23Max(lastSess), ...
	cuePretrainDiag.CueIL5RewardRecvIMean(firstSess), cuePretrainDiag.CueIL5RewardRecvIMax(firstSess), cuePretrainDiag.CueIL5RewardRecvIMean(lastSess), cuePretrainDiag.CueIL5RewardRecvIMax(lastSess));
learningActivityText = sprintf(['learning activity first/last: L23 mean/max=%.3f/%.3f -> %.3f/%.3f, ', ...
	'RewardRecv mean/max=%.3f/%.3f -> %.3f/%.3f, Read mean/max=%.3f/%.3f -> %.3f/%.3f; ', ...
	'learning activity sums L23/RewardRecv/targetRead/nonTargetRead=%.3f/%.3f/%.3f/%.3f -> %.3f/%.3f/%.3f/%.3f, target Read count=%.0f -> %.0f; '], ...
	cuePretrainDiag.LearnL23Mean(firstSess), cuePretrainDiag.LearnL23Max(firstSess), cuePretrainDiag.LearnL23Mean(lastSess), cuePretrainDiag.LearnL23Max(lastSess), ...
	cuePretrainDiag.LearnRewardRecvMean(firstSess), cuePretrainDiag.LearnRewardRecvMax(firstSess), cuePretrainDiag.LearnRewardRecvMean(lastSess), cuePretrainDiag.LearnRewardRecvMax(lastSess), ...
	cuePretrainDiag.LearnReadMean(firstSess), cuePretrainDiag.LearnReadMax(firstSess), cuePretrainDiag.LearnReadMean(lastSess), cuePretrainDiag.LearnReadMax(lastSess), ...
	cuePretrainDiag.LearnL23Sum(firstSess), cuePretrainDiag.LearnRewardRecvSum(firstSess), cuePretrainDiag.LearnReadTargetSum(firstSess), cuePretrainDiag.LearnReadNonTargetSum(firstSess), ...
	cuePretrainDiag.LearnL23Sum(lastSess), cuePretrainDiag.LearnRewardRecvSum(lastSess), cuePretrainDiag.LearnReadTargetSum(lastSess), cuePretrainDiag.LearnReadNonTargetSum(lastSess), ...
	cuePretrainDiag.LearnReadTargetCount(firstSess), cuePretrainDiag.LearnReadTargetCount(lastSess));
rewardRecvPatternText = sprintf(['RewardRecv cue-vs-reward pattern: corr=%s, mean delta=%s, RMS delta=%s, ', ...
	'learn>cue fraction=%s, top-quartile overlap=%s; '], ...
	iFormatNumberSeries(cuePretrainDiag.RewardRecvCueLearnCorr(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.RewardRecvCueLearnMeanDelta(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.RewardRecvCueLearnRMSDelta(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.RewardRecvCueLearnHigherFraction(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.RewardRecvCueLearnTopQuartileOverlap(useSess)));
inhibitoryDriveText = sprintf(['IL5RewardRecvI drive first/last: TH afferent pre mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'IL23 recurrent pre mean/min=%.4f/%.4f -> %.4f/%.4f, IL23 recurrent |pre| mean/max=%.4f/%.4f -> %.4f/%.4f; '], ...
	cuePretrainDiag.THToIL5RewardRecvIPreMean(firstSess), cuePretrainDiag.THToIL5RewardRecvIPreMax(firstSess), cuePretrainDiag.THToIL5RewardRecvIPreMean(lastSess), cuePretrainDiag.THToIL5RewardRecvIPreMax(lastSess), ...
	cuePretrainDiag.IL23ToIL5RewardRecvIPreMean(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIPreMin(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIPreMean(lastSess), cuePretrainDiag.IL23ToIL5RewardRecvIPreMin(lastSess), ...
	cuePretrainDiag.IL23ToIL5RewardRecvIPreMeanAbs(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIPreMaxAbs(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIPreMeanAbs(lastSess), cuePretrainDiag.IL23ToIL5RewardRecvIPreMaxAbs(lastSess));
baselineSourceText = sprintf(['baseline trigger target Read pre first/last: L23=%.3f -> %.3f, RewardRecv=%.3f -> %.3f, ', ...
	'Read recurrent=%.3f -> %.3f, IL23=%.3f -> %.3f, IL5RewardRecvI=%.3f -> %.3f, ', ...
	'L2 net=%.3f -> %.3f, L5 net=%.3f -> %.3f, total=%.3f -> %.3f; '], ...
	cuePretrainDiag.BaselineTargetL23PreMean(firstSess), cuePretrainDiag.BaselineTargetL23PreMean(lastSess), ...
	cuePretrainDiag.BaselineTargetRewardRecvPreMean(firstSess), cuePretrainDiag.BaselineTargetRewardRecvPreMean(lastSess), ...
	cuePretrainDiag.BaselineTargetReadRecurrentPreMean(firstSess), cuePretrainDiag.BaselineTargetReadRecurrentPreMean(lastSess), ...
	cuePretrainDiag.BaselineTargetIL23PreMean(firstSess), cuePretrainDiag.BaselineTargetIL23PreMean(lastSess), ...
	cuePretrainDiag.BaselineTargetIL5RewardRecvIPreMean(firstSess), cuePretrainDiag.BaselineTargetIL5RewardRecvIPreMean(lastSess), ...
	cuePretrainDiag.BaselineTargetL2NetPreMean(firstSess), cuePretrainDiag.BaselineTargetL2NetPreMean(lastSess), ...
	cuePretrainDiag.BaselineTargetL5NetPreMean(firstSess), cuePretrainDiag.BaselineTargetL5NetPreMean(lastSess), ...
	cuePretrainDiag.BaselineTargetNetPreMean(firstSess), cuePretrainDiag.BaselineTargetNetPreMean(lastSess));
readoutCircuitText = sprintf(['readout split first/last: target Read mean/max=%.3f/%.3f -> %.3f/%.3f, ', ...
	'non-target Read mean/max=%.3f/%.3f -> %.3f/%.3f; target Read pre: L23=%.3f -> %.3f, RewardRecv=%.3f -> %.3f, ', ...
	'Read recurrent=%.3f -> %.3f, E total=%.3f -> %.3f, IL23=%.3f -> %.3f, IL5RewardRecvI=%.3f -> %.3f, ', ...
	'I total=%.3f -> %.3f, net recurrent=%.3f -> %.3f; non-target Read pre: E total=%.3f -> %.3f, I total=%.3f -> %.3f, net recurrent=%.3f -> %.3f; '], ...
	cuePretrainDiag.CueReadTargetMean(firstSess), cuePretrainDiag.CueReadTargetMax(firstSess), cuePretrainDiag.CueReadTargetMean(lastSess), cuePretrainDiag.CueReadTargetMax(lastSess), ...
	cuePretrainDiag.CueReadNonTargetMean(firstSess), cuePretrainDiag.CueReadNonTargetMax(firstSess), cuePretrainDiag.CueReadNonTargetMean(lastSess), cuePretrainDiag.CueReadNonTargetMax(lastSess), ...
	cuePretrainDiag.ReadTargetL23PreMean(firstSess), cuePretrainDiag.ReadTargetL23PreMean(lastSess), ...
	cuePretrainDiag.ReadTargetRewardRecvPreMean(firstSess), cuePretrainDiag.ReadTargetRewardRecvPreMean(lastSess), ...
	cuePretrainDiag.ReadTargetReadPreMean(firstSess), cuePretrainDiag.ReadTargetReadPreMean(lastSess), ...
	cuePretrainDiag.ReadTargetExcPreMean(firstSess), cuePretrainDiag.ReadTargetExcPreMean(lastSess), ...
	cuePretrainDiag.ReadTargetIL23PreMean(firstSess), cuePretrainDiag.ReadTargetIL23PreMean(lastSess), ...
	cuePretrainDiag.ReadTargetIL5RewardRecvIPreMean(firstSess), cuePretrainDiag.ReadTargetIL5RewardRecvIPreMean(lastSess), ...
	cuePretrainDiag.ReadTargetInhPreMean(firstSess), cuePretrainDiag.ReadTargetInhPreMean(lastSess), ...
	cuePretrainDiag.ReadTargetNetRecurrentPreMean(firstSess), cuePretrainDiag.ReadTargetNetRecurrentPreMean(lastSess), ...
	cuePretrainDiag.ReadNonTargetExcPreMean(firstSess), cuePretrainDiag.ReadNonTargetExcPreMean(lastSess), ...
	cuePretrainDiag.ReadNonTargetInhPreMean(firstSess), cuePretrainDiag.ReadNonTargetInhPreMean(lastSess), ...
	cuePretrainDiag.ReadNonTargetNetRecurrentPreMean(firstSess), cuePretrainDiag.ReadNonTargetNetRecurrentPreMean(lastSess));
il5InhibitoryCircuitText = sprintf('IL5RewardRecvI recurrent split first/last: E pre=%.3f -> %.3f, I pre=%.3f -> %.3f, net recurrent=%.3f -> %.3f; ', ...
	cuePretrainDiag.IL5RewardRecvIExcRecurrentPreMean(firstSess), cuePretrainDiag.IL5RewardRecvIExcRecurrentPreMean(lastSess), ...
	cuePretrainDiag.IL5RewardRecvIInhRecurrentPreMean(firstSess), cuePretrainDiag.IL5RewardRecvIInhRecurrentPreMean(lastSess), ...
	cuePretrainDiag.IL5RewardRecvINetRecurrentPreMean(firstSess), cuePretrainDiag.IL5RewardRecvINetRecurrentPreMean(lastSess));
weightText = sprintf(['weights first/last: Reward->RewardRecv mean/max=%.4f/%.4f -> %.4f/%.4f, Reward->IL5RewardRecv mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'L23->RewardRecv mean/max=%.4f/%.4f -> %.4f/%.4f, L23->Read mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'RewardRecv->Read mean/max=%.4f/%.4f -> %.4f/%.4f, Exc->Read mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'|I->Read| mean/max=%.4f/%.4f -> %.4f/%.4f, |IL23->Read| mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'|IL5RewardRecvI->Read| mean/max=%.4f/%.4f -> %.4f/%.4f, |IL23->IL5RewardRecvI| mean/max=%.4f/%.4f -> %.4f/%.4f.'], ...
	cuePretrainDiag.RewardToRewardRecvMeanW(firstSess), cuePretrainDiag.RewardToRewardRecvMaxW(firstSess), cuePretrainDiag.RewardToRewardRecvMeanW(lastSess), cuePretrainDiag.RewardToRewardRecvMaxW(lastSess), ...
	cuePretrainDiag.RewardToIL5RewardRecvMeanW(firstSess), cuePretrainDiag.RewardToIL5RewardRecvMaxW(firstSess), cuePretrainDiag.RewardToIL5RewardRecvMeanW(lastSess), cuePretrainDiag.RewardToIL5RewardRecvMaxW(lastSess), ...
	cuePretrainDiag.L23ToRewardRecvMeanW(firstSess), cuePretrainDiag.L23ToRewardRecvMaxW(firstSess), cuePretrainDiag.L23ToRewardRecvMeanW(lastSess), cuePretrainDiag.L23ToRewardRecvMaxW(lastSess), ...
	cuePretrainDiag.L23ToReadMeanW(firstSess), cuePretrainDiag.L23ToReadMaxW(firstSess), cuePretrainDiag.L23ToReadMeanW(lastSess), cuePretrainDiag.L23ToReadMaxW(lastSess), ...
	cuePretrainDiag.RewardRecvToReadMeanW(firstSess), cuePretrainDiag.RewardRecvToReadMaxW(firstSess), cuePretrainDiag.RewardRecvToReadMeanW(lastSess), cuePretrainDiag.RewardRecvToReadMaxW(lastSess), ...
	cuePretrainDiag.ExcToReadMeanW(firstSess), cuePretrainDiag.ExcToReadMaxW(firstSess), cuePretrainDiag.ExcToReadMeanW(lastSess), cuePretrainDiag.ExcToReadMaxW(lastSess), ...
	cuePretrainDiag.InhToReadMeanAbsW(firstSess), cuePretrainDiag.InhToReadMaxAbsW(firstSess), cuePretrainDiag.InhToReadMeanAbsW(lastSess), cuePretrainDiag.InhToReadMaxAbsW(lastSess), ...
	cuePretrainDiag.IL23ToReadMeanAbsW(firstSess), cuePretrainDiag.IL23ToReadMaxAbsW(firstSess), cuePretrainDiag.IL23ToReadMeanAbsW(lastSess), cuePretrainDiag.IL23ToReadMaxAbsW(lastSess), ...
	cuePretrainDiag.IL5RewardRecvIToReadMeanAbsW(firstSess), cuePretrainDiag.IL5RewardRecvIToReadMaxAbsW(firstSess), cuePretrainDiag.IL5RewardRecvIToReadMeanAbsW(lastSess), cuePretrainDiag.IL5RewardRecvIToReadMaxAbsW(lastSess), ...
	cuePretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(lastSess), cuePretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(lastSess));
inputAccumulatorText = sprintf('reward afferent accumulator Z distributions first/last: Reward->RewardRecv %s -> %s; Reward->IL5RewardRecv %s -> %s.', ...
	cuePretrainDiag.RewardToRewardRecvZDistribution(firstSess), cuePretrainDiag.RewardToRewardRecvZDistribution(lastSess), ...
	cuePretrainDiag.RewardToIL5RewardRecvZDistribution(firstSess), cuePretrainDiag.RewardToIL5RewardRecvZDistribution(lastSess));
diagMessage = sprintf(['Cue pretrain diagnostics: perf=%s; decision similarity mean=%s, max=%s; ', ...
	'baseline corrections mean=%s, max=%s; baseline max-similarity mean=%s, max=%s; baseline final-similarity mean=%s, max=%s; %s%s%s%s%s%s%s%s%s%s%s%s'], ...
	iFormatNumberSeries(cuePretrainDiag.PerfObserved(useSess)), iFormatNumberSeries(cuePretrainDiag.DecisionDriveMean(useSess)), iFormatNumberSeries(cuePretrainDiag.DecisionDriveMax(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.BaselineCorrectionMean(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineCorrectionMax(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineMaxDriveMean(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineMaxDriveMax(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.BaselineFinalDriveMean(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineFinalDriveMax(useSess)), ...
	growthText, trajectoryText, rewardRecvCompetitionText, cueActivityText, learningActivityText, rewardRecvPatternText, inhibitoryDriveText, baselineSourceText, readoutCircuitText, il5InhibitoryCircuitText, weightText, inputAccumulatorText);
end

function rewardPretrainDiag = iInitRewardPretrainDiagnostics(Params)
nTrial = Params.MaxRewardPretrainTrials;
rewardPretrainDiag.Hit = false(nTrial, 1);
rewardPretrainDiag.ReadoutDrive = nan(nTrial, 1);
rewardPretrainDiag.NaturalL23Mean = nan(nTrial, 1);
rewardPretrainDiag.NaturalL23Max = nan(nTrial, 1);
rewardPretrainDiag.TrainingL23Mean = nan(nTrial, 1);
rewardPretrainDiag.TrainingL23Max = nan(nTrial, 1);
rewardPretrainDiag.NaturalRewardRecvMean = nan(nTrial, 1);
rewardPretrainDiag.NaturalRewardRecvMax = nan(nTrial, 1);
rewardPretrainDiag.NaturalReadMean = nan(nTrial, 1);
rewardPretrainDiag.NaturalReadMax = nan(nTrial, 1);
rewardPretrainDiag.NaturalReadTargetMean = nan(nTrial, 1);
rewardPretrainDiag.NaturalReadNonTargetMean = nan(nTrial, 1);
rewardPretrainDiag.NaturalIL23Mean = nan(nTrial, 1);
rewardPretrainDiag.NaturalIL23Max = nan(nTrial, 1);
rewardPretrainDiag.NaturalIL5RewardRecvIMean = nan(nTrial, 1);
rewardPretrainDiag.NaturalIL5RewardRecvIMax = nan(nTrial, 1);
rewardPretrainDiag.TrainingReadMean = nan(nTrial, 1);
rewardPretrainDiag.TrainingReadMax = nan(nTrial, 1);
rewardPretrainDiag.TrainingReadTargetMean = nan(nTrial, 1);
rewardPretrainDiag.TrainingReadNonTargetMean = nan(nTrial, 1);
rewardPretrainDiag.RewardToRewardRecvMeanW = nan(nTrial, 1);
rewardPretrainDiag.RewardToRewardRecvMaxW = nan(nTrial, 1);
rewardPretrainDiag.RewardToIL5RewardRecvMeanW = nan(nTrial, 1);
rewardPretrainDiag.RewardToIL5RewardRecvMaxW = nan(nTrial, 1);
rewardPretrainDiag.RewardRecvToReadMeanW = nan(nTrial, 1);
rewardPretrainDiag.RewardRecvToReadMaxW = nan(nTrial, 1);
rewardPretrainDiag.RewardRecvToTargetReadMeanW = nan(nTrial, 1);
rewardPretrainDiag.RewardRecvToNonTargetReadMeanW = nan(nTrial, 1);
rewardPretrainDiag.L23ToReadMeanW = nan(nTrial, 1);
rewardPretrainDiag.L23ToReadMaxW = nan(nTrial, 1);
rewardPretrainDiag.L23ToTargetReadMeanW = nan(nTrial, 1);
rewardPretrainDiag.L23ToNonTargetReadMeanW = nan(nTrial, 1);
rewardPretrainDiag.L23ToTargetReadColumnSumMeanW = nan(nTrial, 1);
rewardPretrainDiag.L23ToNonTargetReadColumnSumMeanW = nan(nTrial, 1);
rewardPretrainDiag.L23ToTargetReadNaturalPreMean = nan(nTrial, 1);
rewardPretrainDiag.L23ToNonTargetReadNaturalPreMean = nan(nTrial, 1);
rewardPretrainDiag.L23ToTargetReadTrainingPreMean = nan(nTrial, 1);
rewardPretrainDiag.L23ToNonTargetReadTrainingPreMean = nan(nTrial, 1);
rewardPretrainDiag.L23ToTargetReadEligibilityMean = nan(nTrial, 1);
rewardPretrainDiag.L23ToNonTargetReadEligibilityMean = nan(nTrial, 1);
rewardPretrainDiag.L23ToTargetReadAccumulatorMean = nan(nTrial, 1);
rewardPretrainDiag.L23ToNonTargetReadAccumulatorMean = nan(nTrial, 1);
rewardPretrainDiag.InhToReadMeanAbsW = nan(nTrial, 1);
rewardPretrainDiag.InhToReadMaxAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL23ToReadMeanAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL23ToReadMaxAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToReadMeanAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToReadMaxAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadMeanAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadMeanAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadNaturalPreMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadNaturalPreMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadTrainingPreMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadTrainingPreMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadEligibilityMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMax = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityPositiveFrac = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadAccumulatorMean = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMin = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMax = nan(nTrial, 1);
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorPositiveFrac = nan(nTrial, 1);
rewardPretrainDiag.IL23ToIL5RewardRecvIMeanAbsW = nan(nTrial, 1);
rewardPretrainDiag.IL23ToIL5RewardRecvIMaxAbsW = nan(nTrial, 1);
end

function rewardPretrainDiag = iRecordRewardPretrainDiagnostics(rewardPretrainDiag, iTrial, Mouse, Params, isHit, naturalActivityHistory, trainingActivityHistory, readoutDrive, eligInternalToInternal)
[naturalL23, naturalRewardRecv, naturalRead, naturalIL23, naturalIL5RewardRecvI] = iSplitInternalActivity(naturalActivityHistory, Params);
[trainingL23, ~, trainingRead] = iSplitInternalActivity(trainingActivityHistory, Params);
readPattern = iGatherValue(Mouse.L5ReadoutPattern(:));
readTargetMask = readPattern > 0;
readNonTargetMask = ~readTargetMask;
l23Cols = 1:Params.NL23;
rewardRecvCols = Params.NL23 + (1:Params.NL5RewardRecv);
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
hiddenICols = Params.NL23L5 + (1:Params.NIInternal);
iL23Cols = Params.NL23L5 + (1:Params.NIL23);
iL5RewardRecvICols = Params.NL23L5 + Params.NIL23 + (1:Params.NIL5RewardRecv);
iL5RewardRecvIRows = iL5RewardRecvICols;
l23ToReadW = Mouse.W_InternalToInternal(readoutRows, l23Cols);
l23ToReadZ = Mouse.Z_InternalToInternal(readoutRows, l23Cols);
l23ToReadEligibility = eligInternalToInternal(readoutRows, l23Cols);
rewardRecvToReadW = Mouse.W_InternalToInternal(readoutRows, rewardRecvCols);
inhToReadW = Mouse.W_InternalToInternal(readoutRows, hiddenICols);
il23ToReadW = Mouse.W_InternalToInternal(readoutRows, iL23Cols);
il5RewardRecvIToReadW = Mouse.W_InternalToInternal(readoutRows, iL5RewardRecvICols);
il5RewardRecvIToReadZ = Mouse.Z_InternalToInternal(readoutRows, iL5RewardRecvICols);
il5RewardRecvIToReadEligibility = eligInternalToInternal(readoutRows, iL5RewardRecvICols);
il23ToIL5RewardRecvIW = Mouse.W_InternalToInternal(iL5RewardRecvIRows, iL23Cols);
naturalInternalMean = mean(iGatherValue(naturalActivityHistory), 2, 'omitnan');
trainingInternalMean = mean(iGatherValue(trainingActivityHistory), 2, 'omitnan');
l23ToReadNaturalPre = l23ToReadW * naturalInternalMean(l23Cols);
l23ToReadTrainingPre = l23ToReadW * trainingInternalMean(l23Cols);
naturalIL5RewardRecvIToReadPre = il5RewardRecvIToReadW * naturalInternalMean(iL5RewardRecvICols);
trainingIL5RewardRecvIToReadPre = il5RewardRecvIToReadW * trainingInternalMean(iL5RewardRecvICols);

rewardPretrainDiag.Hit(iTrial) = isHit;
rewardPretrainDiag.ReadoutDrive(iTrial) = readoutDrive;
rewardPretrainDiag.NaturalL23Mean(iTrial) = iMeanFlat(naturalL23);
rewardPretrainDiag.NaturalL23Max(iTrial) = iMaxFlat(naturalL23);
rewardPretrainDiag.TrainingL23Mean(iTrial) = iMeanFlat(trainingL23);
rewardPretrainDiag.TrainingL23Max(iTrial) = iMaxFlat(trainingL23);
rewardPretrainDiag.NaturalRewardRecvMean(iTrial) = iMeanFlat(naturalRewardRecv);
rewardPretrainDiag.NaturalRewardRecvMax(iTrial) = iMaxFlat(naturalRewardRecv);
rewardPretrainDiag.NaturalReadMean(iTrial) = iMeanFlat(naturalRead);
rewardPretrainDiag.NaturalReadMax(iTrial) = iMaxFlat(naturalRead);
rewardPretrainDiag.NaturalReadTargetMean(iTrial) = iMeanFlat(naturalRead(readTargetMask, :));
rewardPretrainDiag.NaturalReadNonTargetMean(iTrial) = iMeanFlat(naturalRead(readNonTargetMask, :));
rewardPretrainDiag.NaturalIL23Mean(iTrial) = iMeanFlat(naturalIL23);
rewardPretrainDiag.NaturalIL23Max(iTrial) = iMaxFlat(naturalIL23);
rewardPretrainDiag.NaturalIL5RewardRecvIMean(iTrial) = iMeanFlat(naturalIL5RewardRecvI);
rewardPretrainDiag.NaturalIL5RewardRecvIMax(iTrial) = iMaxFlat(naturalIL5RewardRecvI);
rewardPretrainDiag.TrainingReadMean(iTrial) = iMeanFlat(trainingRead);
rewardPretrainDiag.TrainingReadMax(iTrial) = iMaxFlat(trainingRead);
rewardPretrainDiag.TrainingReadTargetMean(iTrial) = iMeanFlat(trainingRead(readTargetMask, :));
rewardPretrainDiag.TrainingReadNonTargetMean(iTrial) = iMeanFlat(trainingRead(readNonTargetMask, :));
rewardPretrainDiag.RewardToRewardRecvMeanW(iTrial) = iMeanFlat(Mouse.W_RewardToL5RewardRecv);
rewardPretrainDiag.RewardToRewardRecvMaxW(iTrial) = iMaxFlat(Mouse.W_RewardToL5RewardRecv);
rewardPretrainDiag.RewardToIL5RewardRecvMeanW(iTrial) = iMeanFlat(Mouse.W_RewardToIL5RewardRecv);
rewardPretrainDiag.RewardToIL5RewardRecvMaxW(iTrial) = iMaxFlat(Mouse.W_RewardToIL5RewardRecv);
rewardPretrainDiag.RewardRecvToReadMeanW(iTrial) = iMeanFlat(rewardRecvToReadW);
rewardPretrainDiag.RewardRecvToReadMaxW(iTrial) = iMaxFlat(rewardRecvToReadW);
rewardPretrainDiag.RewardRecvToTargetReadMeanW(iTrial) = iMeanFlat(rewardRecvToReadW(readTargetMask, :));
rewardPretrainDiag.RewardRecvToNonTargetReadMeanW(iTrial) = iMeanFlat(rewardRecvToReadW(readNonTargetMask, :));
rewardPretrainDiag.L23ToReadMeanW(iTrial) = iMeanFlat(l23ToReadW);
rewardPretrainDiag.L23ToReadMaxW(iTrial) = iMaxFlat(l23ToReadW);
rewardPretrainDiag.L23ToTargetReadMeanW(iTrial) = iMeanFlat(l23ToReadW(readTargetMask, :));
rewardPretrainDiag.L23ToNonTargetReadMeanW(iTrial) = iMeanFlat(l23ToReadW(readNonTargetMask, :));
rewardPretrainDiag.L23ToTargetReadColumnSumMeanW(iTrial) = iMeanFlat(sum(l23ToReadW(readTargetMask, :), 1));
rewardPretrainDiag.L23ToNonTargetReadColumnSumMeanW(iTrial) = iMeanFlat(sum(l23ToReadW(readNonTargetMask, :), 1));
rewardPretrainDiag.L23ToTargetReadNaturalPreMean(iTrial) = iMeanFlat(l23ToReadNaturalPre(readTargetMask));
rewardPretrainDiag.L23ToNonTargetReadNaturalPreMean(iTrial) = iMeanFlat(l23ToReadNaturalPre(readNonTargetMask));
rewardPretrainDiag.L23ToTargetReadTrainingPreMean(iTrial) = iMeanFlat(l23ToReadTrainingPre(readTargetMask));
rewardPretrainDiag.L23ToNonTargetReadTrainingPreMean(iTrial) = iMeanFlat(l23ToReadTrainingPre(readNonTargetMask));
rewardPretrainDiag.L23ToTargetReadEligibilityMean(iTrial) = iMeanFlat(l23ToReadEligibility(readTargetMask, :));
rewardPretrainDiag.L23ToNonTargetReadEligibilityMean(iTrial) = iMeanFlat(l23ToReadEligibility(readNonTargetMask, :));
rewardPretrainDiag.L23ToTargetReadAccumulatorMean(iTrial) = iMeanFlat(l23ToReadZ(readTargetMask, :));
rewardPretrainDiag.L23ToNonTargetReadAccumulatorMean(iTrial) = iMeanFlat(l23ToReadZ(readNonTargetMask, :));
rewardPretrainDiag.InhToReadMeanAbsW(iTrial) = iMeanFlat(abs(inhToReadW));
rewardPretrainDiag.InhToReadMaxAbsW(iTrial) = iMaxFlat(abs(inhToReadW));
rewardPretrainDiag.IL23ToReadMeanAbsW(iTrial) = iMeanFlat(abs(il23ToReadW));
rewardPretrainDiag.IL23ToReadMaxAbsW(iTrial) = iMaxFlat(abs(il23ToReadW));
rewardPretrainDiag.IL5RewardRecvIToReadMeanAbsW(iTrial) = iMeanFlat(abs(il5RewardRecvIToReadW));
rewardPretrainDiag.IL5RewardRecvIToReadMaxAbsW(iTrial) = iMaxFlat(abs(il5RewardRecvIToReadW));
rewardPretrainDiag.IL5RewardRecvIToTargetReadMeanAbsW(iTrial) = iMeanFlat(abs(il5RewardRecvIToReadW(readTargetMask, :)));
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadMeanAbsW(iTrial) = iMeanFlat(abs(il5RewardRecvIToReadW(readNonTargetMask, :)));
rewardPretrainDiag.IL5RewardRecvIToTargetReadNaturalPreMean(iTrial) = iMeanFlat(naturalIL5RewardRecvIToReadPre(readTargetMask));
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadNaturalPreMean(iTrial) = iMeanFlat(naturalIL5RewardRecvIToReadPre(readNonTargetMask));
rewardPretrainDiag.IL5RewardRecvIToTargetReadTrainingPreMean(iTrial) = iMeanFlat(trainingIL5RewardRecvIToReadPre(readTargetMask));
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadTrainingPreMean(iTrial) = iMeanFlat(trainingIL5RewardRecvIToReadPre(readNonTargetMask));
rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMean(iTrial) = iMeanFlat(il5RewardRecvIToReadEligibility(readTargetMask, :));
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadEligibilityMean(iTrial) = iMeanFlat(il5RewardRecvIToReadEligibility(readNonTargetMask, :));
rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMax(iTrial) = iMaxFlat(il5RewardRecvIToReadEligibility(readTargetMask, :));
rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityPositiveFrac(iTrial) = iMeanFlat(il5RewardRecvIToReadEligibility(readTargetMask, :) > 0);
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMean(iTrial) = iMeanFlat(il5RewardRecvIToReadZ(readTargetMask, :));
rewardPretrainDiag.IL5RewardRecvIToNonTargetReadAccumulatorMean(iTrial) = iMeanFlat(il5RewardRecvIToReadZ(readNonTargetMask, :));
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMin(iTrial) = iMinFlat(il5RewardRecvIToReadZ(readTargetMask, :));
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMax(iTrial) = iMaxFlat(il5RewardRecvIToReadZ(readTargetMask, :));
rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorPositiveFrac(iTrial) = iMeanFlat(il5RewardRecvIToReadZ(readTargetMask, :) > 0);
rewardPretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(iTrial) = iMeanFlat(abs(il23ToIL5RewardRecvIW));
rewardPretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(iTrial) = iMaxFlat(abs(il23ToIL5RewardRecvIW));
end

function diagMessage = iRewardPretrainDiagnosticMessage(rewardPretrainDiag)
lastTrial = find(isfinite(rewardPretrainDiag.ReadoutDrive), 1, 'last');
if isempty(lastTrial)
	diagMessage = 'No reward-pretrain diagnostic samples were recorded.';
	return;
end
firstTrial = find(isfinite(rewardPretrainDiag.ReadoutDrive), 1, 'first');
recentIdx = max(firstTrial, lastTrial - 9):lastTrial;
l23ReadoutText = sprintf(['natural/training L23 mean first/last=%.3f/%.3f and %.3f/%.3f, max first/last=%.3f/%.3f and %.3f/%.3f; ', ...
	'L23->Read W mean/max first/last=%.4f/%.4f -> %.4f/%.4f; ', ...
	'L23->target/non-target Read W mean first/last=%.4f/%.4f vs %.4f/%.4f; ', ...
	'L23->target/non-target Read column-sum W mean first/last=%.4f/%.4f vs %.4f/%.4f; ', ...
	'L23->target/non-target Read natural pre mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'L23->target/non-target Read training pre mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'L23->target/non-target Read eligibility mean first/last=%.5f/%.5f vs %.5f/%.5f; ', ...
	'L23->target/non-target Read accumulator mean first/last=%.3f/%.3f vs %.3f/%.3f.'], ...
	rewardPretrainDiag.NaturalL23Mean(firstTrial), rewardPretrainDiag.NaturalL23Mean(lastTrial), rewardPretrainDiag.TrainingL23Mean(firstTrial), rewardPretrainDiag.TrainingL23Mean(lastTrial), ...
	rewardPretrainDiag.NaturalL23Max(firstTrial), rewardPretrainDiag.NaturalL23Max(lastTrial), rewardPretrainDiag.TrainingL23Max(firstTrial), rewardPretrainDiag.TrainingL23Max(lastTrial), ...
	rewardPretrainDiag.L23ToReadMeanW(firstTrial), rewardPretrainDiag.L23ToReadMaxW(firstTrial), rewardPretrainDiag.L23ToReadMeanW(lastTrial), rewardPretrainDiag.L23ToReadMaxW(lastTrial), ...
	rewardPretrainDiag.L23ToTargetReadMeanW(firstTrial), rewardPretrainDiag.L23ToTargetReadMeanW(lastTrial), rewardPretrainDiag.L23ToNonTargetReadMeanW(firstTrial), rewardPretrainDiag.L23ToNonTargetReadMeanW(lastTrial), ...
	rewardPretrainDiag.L23ToTargetReadColumnSumMeanW(firstTrial), rewardPretrainDiag.L23ToTargetReadColumnSumMeanW(lastTrial), rewardPretrainDiag.L23ToNonTargetReadColumnSumMeanW(firstTrial), rewardPretrainDiag.L23ToNonTargetReadColumnSumMeanW(lastTrial), ...
	rewardPretrainDiag.L23ToTargetReadNaturalPreMean(firstTrial), rewardPretrainDiag.L23ToTargetReadNaturalPreMean(lastTrial), rewardPretrainDiag.L23ToNonTargetReadNaturalPreMean(firstTrial), rewardPretrainDiag.L23ToNonTargetReadNaturalPreMean(lastTrial), ...
	rewardPretrainDiag.L23ToTargetReadTrainingPreMean(firstTrial), rewardPretrainDiag.L23ToTargetReadTrainingPreMean(lastTrial), rewardPretrainDiag.L23ToNonTargetReadTrainingPreMean(firstTrial), rewardPretrainDiag.L23ToNonTargetReadTrainingPreMean(lastTrial), ...
	rewardPretrainDiag.L23ToTargetReadEligibilityMean(firstTrial), rewardPretrainDiag.L23ToTargetReadEligibilityMean(lastTrial), rewardPretrainDiag.L23ToNonTargetReadEligibilityMean(firstTrial), rewardPretrainDiag.L23ToNonTargetReadEligibilityMean(lastTrial), ...
	rewardPretrainDiag.L23ToTargetReadAccumulatorMean(firstTrial), rewardPretrainDiag.L23ToTargetReadAccumulatorMean(lastTrial), rewardPretrainDiag.L23ToNonTargetReadAccumulatorMean(firstTrial), rewardPretrainDiag.L23ToNonTargetReadAccumulatorMean(lastTrial));
diagMessage = sprintf(['Reward pretrain diagnostics: trials=%d, hit count=%d, recent hit count=%d; ', ...
	'readout similarity first/last/recent mean=%.3f/%.3f/%.3f; ', ...
	'natural RewardRecv mean first/last=%.3f/%.3f, max first/last=%.3f/%.3f; ', ...
	'natural L5Read mean first/last=%.3f/%.3f, max first/last=%.3f/%.3f; ', ...
	'natural target/non-target Read mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'natural IL23 mean first/last=%.3f/%.3f, max first/last=%.3f/%.3f; ', ...
	'natural IL5RewardRecvI mean first/last=%.3f/%.3f, max first/last=%.3f/%.3f; ', ...
	'training L5Read mean first/last=%.3f/%.3f, max first/last=%.3f/%.3f; ', ...
	'training target/non-target Read mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'Reward->RewardRecv W mean first/last=%.4f/%.4f, max first/last=%.4f/%.4f; ', ...
	'Reward->IL5RewardRecv W mean first/last=%.4f/%.4f, max first/last=%.4f/%.4f; ', ...
	'RewardRecv->Read W mean first/last=%.4f/%.4f, max first/last=%.4f/%.4f; ', ...
	'RewardRecv->target/non-target Read W mean first/last=%.4f/%.4f vs %.4f/%.4f; ', ...
	'|I->Read| W mean first/last=%.4f/%.4f, max first/last=%.4f/%.4f; ', ...
	'|IL23->Read| W mean first/last=%.4f/%.4f, max first/last=%.4f/%.4f; ', ...
	'|IL5RewardRecvI->Read| W mean first/last=%.4f/%.4f, max first/last=%.4f/%.4f; ', ...
	'|IL5RewardRecvI->target/non-target Read| W mean first/last=%.4f/%.4f vs %.4f/%.4f; ', ...
	'IL5RewardRecvI->target/non-target Read natural pre mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'IL5RewardRecvI->target/non-target Read training pre mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'IL5RewardRecvI->target/non-target Read eligibility mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'IL5RewardRecvI->target Read eligibility max/positive-frac first/last=%.3f/%.3f and %.3f/%.3f; ', ...
	'IL5RewardRecvI->target/non-target Read accumulator mean first/last=%.3f/%.3f vs %.3f/%.3f; ', ...
	'IL5RewardRecvI->target Read accumulator min/max/positive-frac first/last=%.3f/%.3f/%.3f and %.3f/%.3f/%.3f; ', ...
	'|IL23->IL5RewardRecvI| W mean first/last=%.4f/%.4f, max first/last=%.4f/%.4f. %s'], ...
	lastTrial, sum(rewardPretrainDiag.Hit(1:lastTrial)), sum(rewardPretrainDiag.Hit(recentIdx)), ...
	rewardPretrainDiag.ReadoutDrive(firstTrial), rewardPretrainDiag.ReadoutDrive(lastTrial), iMeanFlat(rewardPretrainDiag.ReadoutDrive(recentIdx)), ...
	rewardPretrainDiag.NaturalRewardRecvMean(firstTrial), rewardPretrainDiag.NaturalRewardRecvMean(lastTrial), rewardPretrainDiag.NaturalRewardRecvMax(firstTrial), rewardPretrainDiag.NaturalRewardRecvMax(lastTrial), ...
	rewardPretrainDiag.NaturalReadMean(firstTrial), rewardPretrainDiag.NaturalReadMean(lastTrial), rewardPretrainDiag.NaturalReadMax(firstTrial), rewardPretrainDiag.NaturalReadMax(lastTrial), ...
	rewardPretrainDiag.NaturalReadTargetMean(firstTrial), rewardPretrainDiag.NaturalReadTargetMean(lastTrial), rewardPretrainDiag.NaturalReadNonTargetMean(firstTrial), rewardPretrainDiag.NaturalReadNonTargetMean(lastTrial), ...
	rewardPretrainDiag.NaturalIL23Mean(firstTrial), rewardPretrainDiag.NaturalIL23Mean(lastTrial), rewardPretrainDiag.NaturalIL23Max(firstTrial), rewardPretrainDiag.NaturalIL23Max(lastTrial), ...
	rewardPretrainDiag.NaturalIL5RewardRecvIMean(firstTrial), rewardPretrainDiag.NaturalIL5RewardRecvIMean(lastTrial), rewardPretrainDiag.NaturalIL5RewardRecvIMax(firstTrial), rewardPretrainDiag.NaturalIL5RewardRecvIMax(lastTrial), ...
	rewardPretrainDiag.TrainingReadMean(firstTrial), rewardPretrainDiag.TrainingReadMean(lastTrial), rewardPretrainDiag.TrainingReadMax(firstTrial), rewardPretrainDiag.TrainingReadMax(lastTrial), ...
	rewardPretrainDiag.TrainingReadTargetMean(firstTrial), rewardPretrainDiag.TrainingReadTargetMean(lastTrial), rewardPretrainDiag.TrainingReadNonTargetMean(firstTrial), rewardPretrainDiag.TrainingReadNonTargetMean(lastTrial), ...
	rewardPretrainDiag.RewardToRewardRecvMeanW(firstTrial), rewardPretrainDiag.RewardToRewardRecvMeanW(lastTrial), rewardPretrainDiag.RewardToRewardRecvMaxW(firstTrial), rewardPretrainDiag.RewardToRewardRecvMaxW(lastTrial), ...
	rewardPretrainDiag.RewardToIL5RewardRecvMeanW(firstTrial), rewardPretrainDiag.RewardToIL5RewardRecvMeanW(lastTrial), rewardPretrainDiag.RewardToIL5RewardRecvMaxW(firstTrial), rewardPretrainDiag.RewardToIL5RewardRecvMaxW(lastTrial), ...
	rewardPretrainDiag.RewardRecvToReadMeanW(firstTrial), rewardPretrainDiag.RewardRecvToReadMeanW(lastTrial), rewardPretrainDiag.RewardRecvToReadMaxW(firstTrial), rewardPretrainDiag.RewardRecvToReadMaxW(lastTrial), ...
	rewardPretrainDiag.RewardRecvToTargetReadMeanW(firstTrial), rewardPretrainDiag.RewardRecvToTargetReadMeanW(lastTrial), rewardPretrainDiag.RewardRecvToNonTargetReadMeanW(firstTrial), rewardPretrainDiag.RewardRecvToNonTargetReadMeanW(lastTrial), ...
	rewardPretrainDiag.InhToReadMeanAbsW(firstTrial), rewardPretrainDiag.InhToReadMeanAbsW(lastTrial), rewardPretrainDiag.InhToReadMaxAbsW(firstTrial), rewardPretrainDiag.InhToReadMaxAbsW(lastTrial), ...
	rewardPretrainDiag.IL23ToReadMeanAbsW(firstTrial), rewardPretrainDiag.IL23ToReadMeanAbsW(lastTrial), rewardPretrainDiag.IL23ToReadMaxAbsW(firstTrial), rewardPretrainDiag.IL23ToReadMaxAbsW(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToReadMeanAbsW(firstTrial), rewardPretrainDiag.IL5RewardRecvIToReadMeanAbsW(lastTrial), rewardPretrainDiag.IL5RewardRecvIToReadMaxAbsW(firstTrial), rewardPretrainDiag.IL5RewardRecvIToReadMaxAbsW(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToTargetReadMeanAbsW(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadMeanAbsW(lastTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadMeanAbsW(firstTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadMeanAbsW(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToTargetReadNaturalPreMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadNaturalPreMean(lastTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadNaturalPreMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadNaturalPreMean(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToTargetReadTrainingPreMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadTrainingPreMean(lastTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadTrainingPreMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadTrainingPreMean(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMean(lastTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadEligibilityMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadEligibilityMean(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMax(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityMax(lastTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityPositiveFrac(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadEligibilityPositiveFrac(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMean(lastTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadAccumulatorMean(firstTrial), rewardPretrainDiag.IL5RewardRecvIToNonTargetReadAccumulatorMean(lastTrial), ...
	rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMin(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMax(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorPositiveFrac(firstTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMin(lastTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorMax(lastTrial), rewardPretrainDiag.IL5RewardRecvIToTargetReadAccumulatorPositiveFrac(lastTrial), ...
	rewardPretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(firstTrial), rewardPretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(lastTrial), rewardPretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(firstTrial), rewardPretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(lastTrial), ...
	l23ReadoutText);
end

function flatMean = iMeanFlat(values)
values = iGatherValue(values(:));
flatMean = mean(values, 'omitnan');
end

function flatRms = iRootMeanSquareFlat(values)
values = iGatherValue(values(:));
values = values(isfinite(values));
if isempty(values)
	flatRms = NaN;
else
	flatRms = sqrt(mean(values.^2));
end
end

function flatMax = iMaxFlat(values)
values = iGatherValue(values(:));
values = values(isfinite(values));
if isempty(values)
	flatMax = NaN;
else
	flatMax = max(values);
end
end

function flatMin = iMinFlat(values)
values = iGatherValue(values(:));
values = values(isfinite(values));
if isempty(values)
	flatMin = NaN;
else
	flatMin = min(values);
end
end

function formatted = iFormatNumberSeries(values)
values = iGatherValue(values(:));
values = values(isfinite(values));
if isempty(values)
	formatted = '[]';
else
	formatted = char("[" + strjoin(compose('%.3f', values), " ") + "]");
end
end

function formatted = iFormatNumberSeries4(values)
values = iGatherValue(values(:));
values = values(isfinite(values));
if isempty(values)
	formatted = '[]';
else
	formatted = char("[" + strjoin(compose('%.4f', values), " ") + "]");
end
end

function formatted = iFormatDeltaSeries4(values)
values = iGatherValue(values(:));
values = values(isfinite(values));
if numel(values) < 2
	formatted = '[]';
else
	formatted = char("[" + strjoin(compose('%.4f', diff(values)), " ") + "]");
end
end

function earlyDeltaMean = iEarlyDeltaMean(values)
deltaValues = diff(iGatherValue(values(:)));
deltaValues = deltaValues(isfinite(deltaValues));
if isempty(deltaValues)
	earlyDeltaMean = NaN;
	return;
end
nEarly = max(1, floor(numel(deltaValues) / 2));
earlyDeltaMean = mean(deltaValues(1:nEarly), 'omitnan');
end

function lateDeltaMean = iLateDeltaMean(values)
deltaValues = diff(iGatherValue(values(:)));
deltaValues = deltaValues(isfinite(deltaValues));
if isempty(deltaValues)
	lateDeltaMean = NaN;
	return;
end
nEarly = max(1, floor(numel(deltaValues) / 2));
lateDeltaMean = mean(deltaValues(nEarly+1:end), 'omitnan');
end

function text = iDistributionText(values)
values = iGatherValue(values(:));
values = sort(values(isfinite(values)));
if isempty(values)
	text = '[]';
	return;
end
nValue = numel(values);
p10 = values(max(1, min(nValue, round(0.10 * (nValue - 1) + 1))));
p50 = values(max(1, min(nValue, round(0.50 * (nValue - 1) + 1))));
p90 = values(max(1, min(nValue, round(0.90 * (nValue - 1) + 1))));
text = sprintf('mean/std/min/p10/median/p90/max=%.3f/%.3f/%.3f/%.3f/%.3f/%.3f/%.3f', ...
	mean(values, 'omitnan'), std(values, 0, 'omitnan'), values(1), p10, p50, p90, values(end));
end

function readoutDrive = iRewardReadoutProbe(Mouse, Params, Cond)
ProbeParams = Params;
ProbeParams.NoiseCue = 0;
ProbeParams.NoiseRew = 0;
ProbeParams.NoiseRead = 0;

preL23 = iZeros(ProbeParams.NL23, ProbeParams);
preIL23 = iZeros(ProbeParams.NIL23, ProbeParams);
rReward = iRunTHInput(Mouse, ProbeParams, Cond, "reward");
[preL5RewardRecv, preIL5RewardRecv] = iRewardAfferentPre(Mouse, rReward, ProbeParams);
preL5Read = iZeros(ProbeParams.NL5Read, ProbeParams);
[~, ~, rL5Read] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, ProbeParams, preIL23, preIL5RewardRecv);
readoutDrive = iReadoutPatternSimilarity(rL5Read, Mouse.L5ReadoutPattern, ProbeParams);
end

function [Result, Mouse] = iSimulateMouse(Mouse, Params, Cond)
perf = nan(1, Params.NumSessions);
h23 = nan(1, Params.NumSessions);
h5 = nan(1, Params.NumSessions);
sessionMeanL23 = nan(Params.NL23, Params.NumSessions);
sessionMeanL5  = nan(Params.NL5,  Params.NumSessions);
thAfferentDelta = nan(1, Params.NumSessions);

for iSess = 1:Params.NumSessions
	thAfferentBefore = [Mouse.W_RewardToL5RewardRecv; Mouse.W_RewardToIL5RewardRecv];
	[perf(iSess), Signals, ~, Mouse] = iSimulateSession(Mouse, Params, Cond, false);
	thAfferentAfter = [Mouse.W_RewardToL5RewardRecv; Mouse.W_RewardToIL5RewardRecv];
	thAfferentDelta(iSess) = iGatherScalar(norm(thAfferentAfter - thAfferentBefore, 'fro') / max(norm(thAfferentBefore, 'fro'), eps));
	sessionMeanL23(:, iSess) = Signals.ProcessMeanL23;
	sessionMeanL5(:, iSess)  = Signals.ProcessMeanL5;
	h23(iSess) = iRestrictedStd(mean(sessionMeanL23(:, 1:iSess), 2, 'omitnan'));
	h5(iSess)  = iRestrictedStd(mean(sessionMeanL5(:,  1:iSess), 2, 'omitnan'));

	if iSess < Params.NumSessions
		Mouse = iOvernightConsolidate(Mouse, Params);
	end
end

first100 = find(perf >= Params.SlopeHitPerfect, 1, 'first');
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
	% Linear fit. Logit was tried but the logit(0.03)~-3.5 expansion at
	% the low end inflates Naive's apparent slope more than it boosts
	% Transfer's, which erases rather than reveals the N/T gap.
	fitP = polyfit(fitX, fitY, 1);
	dh = diff(fitY);
	finalMeanL23 = mean(sessionMeanL23(:, useIdx), 2, 'omitnan');
	finalMeanL5  = mean(sessionMeanL5(:,  useIdx), 2, 'omitnan');
	resultSlope = fitP(1);
	resultDeltaHit = mean(dh, 'omitnan');
	resultMeanH23 = iRestrictedStd(finalMeanL23);
	resultMeanH5  = iRestrictedStd(finalMeanL5);
elseif ~isempty(useIdx)
	finalMeanL5 = mean(sessionMeanL5(:, useIdx), 2, 'omitnan');
	resultSlope = NaN;
	resultDeltaHit = NaN;
	resultMeanH23 = NaN;
	resultMeanH5 = NaN;
else
	finalMeanL5 = nan(Params.NL5, 1);
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
Result.ProcessMeanL5 = finalMeanL5;
Result.THAfferentDelta = thAfferentDelta;
Result.MeanTHAfferentDelta = mean(thAfferentDelta, 'omitnan');
end

function [perf, Signals, perfExpected, Mouse] = iSimulateSession(Mouse, Params, Cond, usePreCue)
% Per-trial loop. Each trial has a decision phase (cue input -> L2/3 -> L5)
% followed by direct supervised training on the settled cue-decision state
% after replacing L5Read with the perfect readout pattern. Hebbian
% and inhibitory plasticity are applied AFTER EACH TRIAL so that within-session
% learning accumulates.
NT = Params.NumTrials;

if usePreCue
	cueL23Pattern = Mouse.PreCueL23Pattern;
	cueGain = Params.CueL23GainPretrain;
else
	cueL23Pattern = Mouse.CueL23Pattern;
	cueGain = Params.CueL23Gain;
end
eta = Params.HebbRate;
traceEta = eta * Params.EligibilityTraceScale;

% Storage for session-level diagnostics.
rL23_cue_all = iZeros([Params.NL23, NT], Params);
rL5RewardRecv_cue_all = iZeros([Params.NL5RewardRecv, NT], Params);
rL5Read_cue_all = iZeros([Params.NL5Read, NT], Params);
rIL23_cue_all = iZeros([Params.NIL23, NT], Params);
rIL5RewardRecvI_cue_all = iZeros([Params.NIL5RewardRecv, NT], Params);
il23ToIL5RewardRecvIPre_all = iZeros([Params.NIL5RewardRecv, NT], Params);
thToIL5RewardRecvIPre_all = iZeros([Params.NIL5RewardRecv, NT], Params);
rL23_L_all = iZeros([Params.NL23, NT], Params);
rReward_L_all = iZeros([Params.NReward, NT], Params);
rL5RewardRecv_L_all = iZeros([Params.NL5RewardRecv, NT], Params);
rL5Read_L_all = iZeros([Params.NL5Read, NT], Params);
isHit = false(1, NT);
decisionReadoutDriveAll = nan(1, NT);
baselineCorrectionCount = nan(1, NT);
baselineMaxDriveAll = nan(1, NT);
baselineFinalDriveAll = nan(1, NT);
baselineTargetL23PreAll = nan(1, NT);
baselineTargetRewardRecvPreAll = nan(1, NT);
baselineTargetReadRecurrentPreAll = nan(1, NT);
baselineTargetIL23PreAll = nan(1, NT);
baselineTargetIL5RewardRecvIPreAll = nan(1, NT);
baselineTargetL2NetPreAll = nan(1, NT);
baselineTargetL5NetPreAll = nan(1, NT);
baselineTargetNetPreAll = nan(1, NT);

eligRewardAfferent = iZeroCellEligibility(Params.NReward, Params.NL5RewardRecv + Params.NIL5RewardRecv, Params);
eligInternal = iZeroCellEligibility(Params.NInternal, Params.NInternal, Params);

for t = 1:NT
	% ===== Continuous rest/no-cue baseline gate =====
	[Mouse, baselineCorrectionCount(t), baselineMaxDriveAll(t), baselineFinalDriveAll(t), baselineReadoutSource] = iRunContinuousBaselineRest(Mouse, Params, Cond, t);
	baselineTargetL23PreAll(t) = baselineReadoutSource.TargetL23;
	baselineTargetRewardRecvPreAll(t) = baselineReadoutSource.TargetRewardRecv;
	baselineTargetReadRecurrentPreAll(t) = baselineReadoutSource.TargetReadRecurrent;
	baselineTargetIL23PreAll(t) = baselineReadoutSource.TargetIL23;
	baselineTargetIL5RewardRecvIPreAll(t) = baselineReadoutSource.TargetIL5RewardRecvI;
	baselineTargetL2NetPreAll(t) = baselineReadoutSource.TargetL2Net;
	baselineTargetL5NetPreAll(t) = baselineReadoutSource.TargetL5Net;
	baselineTargetNetPreAll(t) = baselineReadoutSource.TargetNet;

	% ===== Decision phase (direct cue drive -> recurrent L2/3-L5 network) =====
	cueL23Drive = cueGain * cueL23Pattern + Params.NoiseCue * iRandn(Params.NL23, Params);
	nDecisionState = Params.InternalRecurrentPasses + 1;
	cueL23DriveHistory = iRunCueL23DriveHistory(cueL23Drive, Params, nDecisionState);
	preL5Read_cue = Params.NoiseRead * iRandn(Params.NL5Read, Params);
	[rL23_cue, rL5RewardRecv_cue, rL5Read_cue, decisionActivityCue, decisionTraceCue, ~, ~, decisionActivityHistory, preIL5RewardRecvHistory] = iRunDecisionNetwork(cueL23DriveHistory, preL5Read_cue, Mouse, Params, Cond);
	[~, ~, ~, rIL23_cue, rIL5RewardRecvI_cue] = iSplitInternalActivity(decisionActivityCue, Params);
	il23ToIL5RewardRecvIPre = iIL23ToIL5RewardRecvIContribution(Mouse, decisionActivityHistory, Params);

	isHit(t) = any(decisionTraceCue >= Params.HitThreshold);
	decisionReadoutDriveAll(t) = max(decisionTraceCue);

	% ===== Learning phase (teacher readout + sustained reward-mode TH input) =====
	rReward_L = iRunTHInput(Mouse, Params, Cond, "reward");
	learningActivityHistory = iRunTeacherReadoutIterations(decisionActivityCue, rReward_L, Mouse, Params);
	[rL23_L_history, rL5RewardRecv_L_history, rL5Read_L_history] = iSplitInternalActivity(learningActivityHistory, Params);
	rL23_L = mean(rL23_L_history, 2);
	rL5RewardRecv_L = mean(rL5RewardRecv_L_history, 2);
	rL5Read_L = mean(rL5Read_L_history, 2);
	decisionTrainingHistory = decisionActivityHistory;

	% Per-trial updates on decaying before/after iteration eligibility traces of learned afferent maps and the recurrent L2/3-L5 matrix.
	[eligRewardAfferent, eligInternal] = iUpdateTaskLearningHistoryEligibility(...
		eligRewardAfferent, eligInternal, decisionTrainingHistory, learningActivityHistory, rReward_L, Params);
	[eligRewardToL5RewardRecv, eligRewardToIL5RewardRecv] = iPairedCellEligibilityToSynapseEligibility(eligRewardAfferent, Params.NL5RewardRecv);
	eligInternalToInternal = iRecurrentCellEligibilityToSynapseEligibility(eligInternal, Params);
	isPunishment = false;
	[Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, Mouse.W_RewardToL5RewardRecv, Mouse.W_RewardToIL5RewardRecv] = iApplyLatentPairedHebbTrace(Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, eligRewardToL5RewardRecv, eligRewardToIL5RewardRecv, traceEta, Params.AfferentWCap, Params.WeightMapSlope, isPunishment);
	[Mouse.Z_InternalToInternal, Mouse.W_InternalToInternal] = iApplyLatentInternalTrace(Mouse.Z_InternalToInternal, eligInternalToInternal, traceEta, Params, isPunishment);

	rL23_cue_all(:, t) = rL23_cue;
	rL5RewardRecv_cue_all(:, t) = rL5RewardRecv_cue;
	rL5Read_cue_all(:, t) = rL5Read_cue;
	rIL23_cue_all(:, t) = rIL23_cue;
	rIL5RewardRecvI_cue_all(:, t) = rIL5RewardRecvI_cue;
	il23ToIL5RewardRecvIPre_all(:, t) = mean(il23ToIL5RewardRecvIPre, 2);
	thToIL5RewardRecvIPre_all(:, t) = mean(preIL5RewardRecvHistory, 2);
	rL23_L_all(:, t) = rL23_L;
	rReward_L_all(:, t) = rReward_L;
	rL5RewardRecv_L_all(:, t) = rL5RewardRecv_L;
	rL5Read_L_all(:, t) = rL5Read_L;
end

perf = mean(isHit);
% Kept for interface compatibility with pretraining logic. With hard-
% threshold decisions and no extra Bernoulli sampling, expected and
% observed session hit rates are identical under the realized noise.
perfExpected = perf;

Signals.mL23 = iGatherValue(mean(rL23_L_all, 2));
Signals.mReward = iGatherValue(mean(rReward_L_all, 2));
Signals.mL5RewardRecv = iGatherValue(mean(rL5RewardRecv_L_all, 2));
Signals.mL5Read = iGatherValue(mean(rL5Read_L_all, 2));
Signals.ProcessMeanL23 = iGatherValue(mean(rL23_cue_all, 2));
processMeanL5RewardRecv = mean(rL5RewardRecv_cue_all, 2);
processMeanL5Read = mean(rL5Read_cue_all, 2);
Signals.ProcessMeanL5 = iGatherValue([processMeanL5RewardRecv; processMeanL5Read]);
Signals.ProcessMeanIL23 = iGatherValue(mean(rIL23_cue_all, 2));
Signals.ProcessMeanIL5RewardRecvI = iGatherValue(mean(rIL5RewardRecvI_cue_all, 2));
Signals.IL23ToIL5RewardRecvIRecurrentPreMean = iMeanFlat(il23ToIL5RewardRecvIPre_all);
Signals.IL23ToIL5RewardRecvIRecurrentPreMin = iMinFlat(il23ToIL5RewardRecvIPre_all);
Signals.IL23ToIL5RewardRecvIRecurrentPreMeanAbs = iMeanFlat(abs(il23ToIL5RewardRecvIPre_all));
Signals.IL23ToIL5RewardRecvIRecurrentPreMaxAbs = iMaxFlat(abs(il23ToIL5RewardRecvIPre_all));
Signals.THToIL5RewardRecvIPreMean = iMeanFlat(thToIL5RewardRecvIPre_all);
Signals.THToIL5RewardRecvIPreMax = iMaxFlat(thToIL5RewardRecvIPre_all);
Signals.DecisionReadoutDriveMean = iMeanFlat(decisionReadoutDriveAll);
Signals.DecisionReadoutDriveMax = iMaxFlat(decisionReadoutDriveAll);
Signals.BaselineCorrectionMean = iMeanFlat(baselineCorrectionCount);
Signals.BaselineCorrectionMax = iMaxFlat(baselineCorrectionCount);
Signals.BaselineMaxDriveMean = iMeanFlat(baselineMaxDriveAll);
Signals.BaselineMaxDriveMax = iMaxFlat(baselineMaxDriveAll);
Signals.BaselineFinalDriveMean = iMeanFlat(baselineFinalDriveAll);
Signals.BaselineFinalDriveMax = iMaxFlat(baselineFinalDriveAll);
Signals.BaselineTargetL23PreMean = iMeanFlat(baselineTargetL23PreAll);
Signals.BaselineTargetRewardRecvPreMean = iMeanFlat(baselineTargetRewardRecvPreAll);
Signals.BaselineTargetReadRecurrentPreMean = iMeanFlat(baselineTargetReadRecurrentPreAll);
Signals.BaselineTargetIL23PreMean = iMeanFlat(baselineTargetIL23PreAll);
Signals.BaselineTargetIL5RewardRecvIPreMean = iMeanFlat(baselineTargetIL5RewardRecvIPreAll);
Signals.BaselineTargetL2NetPreMean = iMeanFlat(baselineTargetL2NetPreAll);
Signals.BaselineTargetL5NetPreMean = iMeanFlat(baselineTargetL5NetPreAll);
Signals.BaselineTargetNetPreMean = iMeanFlat(baselineTargetNetPreAll);
Signals.InternalEligibility = iGatherValue(eligInternalToInternal);
end

function rE = iRunArea(pre, areaSpec, Mouse, Params)
switch areaSpec
case {'l23', 'reward', 'l5rewardrecv', 'l5read', 'il23', 'il5rewardrecv'}
	rE = iRateResponse(pre, Params);
end
end

function r = iRateResponse(pre, Params)
r = Params.ResponseScale * (0.5 + atan(Params.RateResponseSlope * (pre - Params.RateResponseMidpoint)) / pi);
end

function [preL23, preIL23] = iNoCueL23Pre(Params)
preL23 = Params.NoiseCue * iRandn(Params.NL23, Params);
preIL23 = Params.NoiseCue * iRandn(Params.NIL23, Params);
end

function cueL23DriveHistory = iRunCueL23DriveHistory(cueL23DriveInitial, Params, nState)
cueL23DriveHistory = iZeros([numel(cueL23DriveInitial), nState], Params);
cueL23DriveState = cueL23DriveInitial;
cueL23DriveHistory(:, 1) = cueL23DriveState;
for iState = 2:nState
	noiseState = Params.IterationNoise * iRandn(numel(cueL23DriveInitial), Params);
	cueL23DriveState = Params.StateCarryover * cueL23DriveState + (1 - Params.StateCarryover) * noiseState;
	cueL23DriveHistory(:, iState) = cueL23DriveState;
end
end

function [preL5RewardRecv, preIL5RewardRecv] = iRewardAfferentPre(Mouse, rReward, Params)
preL5RewardRecv = (Mouse.W_RewardToL5RewardRecv * rReward) / Params.RewardAfferentNorm + Params.NoiseRew * iRandn(Params.NL5RewardRecv, Params);
preIL5RewardRecv = (Mouse.W_RewardToIL5RewardRecv * rReward) / Params.RewardAfferentNorm + Params.NoiseRew * iRandn(Params.NIL5RewardRecv, Params);
end

function rTH = iRunTHInput(Mouse, Params, Cond, thMode)
	switch thMode
	case {"rest", "lick"}
		rTH = iZeros(Params.NReward, Params);
		return;
	case "reward"
		if Cond.THInputIsNoise
			preTH = Params.THNoiseInputGain * iStandardize(iRandn(Params.NReward, Params)) + Params.NoiseRew * iRandn(Params.NReward, Params);
		else
			preTH = Params.THRewardInputGain * Mouse.THRewardPattern + Params.NoiseRew * iRandn(Params.NReward, Params);
		end
	end
rTH = iRunArea(preTH, 'reward', Mouse, Params);
end

function [Mouse, nBaselineCorrections, maxBaselineDrive, finalBaselineDrive, baselineReadoutSource] = iRunContinuousBaselineRest(Mouse, Params, Cond, iTrial)
quietCount = 0;
nBaselineCorrections = 0;
maxBaselineDrive = -Inf;
finalBaselineDrive = NaN;
baselineReadoutSourceSum = iZeroBaselineReadoutSource();
baselineReadoutSource = iAverageBaselineReadoutSource(baselineReadoutSourceSum, nBaselineCorrections);
baselineSuppressionDiagSum = iZeroBaselineSuppressionDiagnostic();
internalActivity = [];
previousTH = iZeros(Params.NReward, Params);
previousRewardRecvActivity = iZeros(Params.NL5RewardRecv, Params);
previousIRewardRecvActivity = iZeros(Params.NIL5RewardRecv, Params);
preL23 = iZeros(Params.NL23, Params);
preL5Read = iZeros(Params.NL5Read, Params);

for iBaselineIteration = 1:Params.MaxBaselineIterations
	if isempty(internalActivity)
		internalActivityBefore = iZeros(Params.NInternal, Params);
	else
		internalActivityBefore = internalActivity;
	end
	rTH = iRunTHInput(Mouse, Params, Cond, "rest");
	[preL5RewardRecv, preIL5RewardRecv] = iRewardAfferentPre(Mouse, rTH, Params);
	externalPre = iBuildInternalPre(preL23, preL5RewardRecv, preL5Read, Params, [], preIL5RewardRecv);
	if isempty(internalActivity)
		networkPre = externalPre;
	else
		networkPre = externalPre + Mouse.W_InternalToInternal * internalActivity;
	end
	networkPre = iAddIterationNoise(networkPre, Params);
	nextActivity = iRunInternalAreas(networkPre, Mouse, Params);
	if isempty(internalActivity)
		internalActivity = nextActivity;
	else
		internalActivity = iCarryInternalState(internalActivity, nextActivity, Params);
	end
	readoutDrive = iReadoutDrive(internalActivity, Mouse, Params);
	maxBaselineDrive = max(maxBaselineDrive, readoutDrive);
	[~, rewardRecvActivity, ~, ~, iRewardRecvActivity] = iSplitInternalActivity(internalActivity, Params);
	if readoutDrive >= Params.HitThreshold
		nBaselineCorrections = nBaselineCorrections + 1;
		baselineReadoutSourceSum = iAddBaselineReadoutSource(baselineReadoutSourceSum, iReadoutSourceContribution(Mouse, Params, internalActivity));
		[Mouse, suppressionDiag] = iSuppressFalseReadout(Mouse, internalActivityBefore, internalActivity, readoutDrive, Params, previousTH, rTH, previousRewardRecvActivity, rewardRecvActivity, previousIRewardRecvActivity, iRewardRecvActivity);
		baselineSuppressionDiagSum = iAddBaselineSuppressionDiagnostic(baselineSuppressionDiagSum, suppressionDiag);
		quietCount = 0;
	else
		quietCount = quietCount + 1;
		if quietCount >= Params.BaselineQuietIterations
			finalBaselineDrive = readoutDrive;
			baselineReadoutSource = iAverageBaselineReadoutSource(baselineReadoutSourceSum, nBaselineCorrections);
			return;
		end
	end
	previousTH = rTH;
	previousRewardRecvActivity = rewardRecvActivity;
	previousIRewardRecvActivity = iRewardRecvActivity;
end

contextText = iRunContextText(Params);
baselineReadoutSource = iAverageBaselineReadoutSource(baselineReadoutSourceSum, nBaselineCorrections);
baselineSuppressionDiag = iAverageBaselineSuppressionDiagnostic(baselineSuppressionDiagSum, nBaselineCorrections);
diagMessage = iBaselineFailureDiagnosticMessage(Mouse, Params, internalActivity, rTH, baselineReadoutSource, baselineSuppressionDiag);
error('THModel:BaselineTrainingIneffective', ...
	['Continuous rest baseline failed%s to reach %d consecutive no-behaviour iterations within %d iterations before trial %d. ', ...
	'Corrections = %d, final quiet streak = %d, last decision similarity = %.3f, max decision similarity = %.3f, threshold = %.3f. %s'], ...
	contextText, Params.BaselineQuietIterations, Params.MaxBaselineIterations, iTrial, nBaselineCorrections, quietCount, readoutDrive, maxBaselineDrive, Params.HitThreshold, diagMessage);
end

function diagMessage = iBaselineFailureDiagnosticMessage(Mouse, Params, internalActivity, thActivity, baselineReadoutSource, baselineSuppressionDiag)
[l23Activity, rewardRecvActivity, readActivity, iL23Activity, iRewardRecvActivity] = iSplitInternalActivity(internalActivity, Params);
inhibitoryActivity = [iL23Activity; iRewardRecvActivity];
rewardRecvCols = Params.NL23 + (1:Params.NL5RewardRecv);
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
hiddenICols = Params.NL23L5 + (1:Params.NIInternal);
iL23Cols = Params.NL23L5 + (1:Params.NIL23);
iL5RewardRecvICols = Params.NL23L5 + Params.NIL23 + (1:Params.NIL5RewardRecv);
iL5RewardRecvIRows = iL5RewardRecvICols;
rewardRecvToReadW = Mouse.W_InternalToInternal(readoutRows, rewardRecvCols);
excToReadW = Mouse.W_InternalToInternal(readoutRows, 1:Params.NL23L5);
inhToReadW = Mouse.W_InternalToInternal(readoutRows, hiddenICols);
il23ToReadW = Mouse.W_InternalToInternal(readoutRows, iL23Cols);
il5RewardRecvIToReadW = Mouse.W_InternalToInternal(readoutRows, iL5RewardRecvICols);
il23ToIL5RewardRecvIW = Mouse.W_InternalToInternal(iL5RewardRecvIRows, iL23Cols);
il23ToIL5RewardRecvIPre = iIL23ToIL5RewardRecvIContribution(Mouse, internalActivity, Params);
thToIL5RewardRecvIPre = (Mouse.W_RewardToIL5RewardRecv * thActivity) / Params.RewardAfferentNorm;
readPattern = Mouse.L5ReadoutPattern(:);
readActivityNow = readActivity(:);
positiveReadoutMask = readPattern > 0;
zeroReadoutMask = readPattern <= 0;
positiveReadoutActivity = readActivityNow(positiveReadoutMask);
zeroReadoutActivity = readActivityNow(zeroReadoutMask);
positiveReadoutError = positiveReadoutActivity / Params.ResponseScale - 1;
zeroReadoutError = zeroReadoutActivity / Params.ResponseScale;
positiveReadoutDistance = sqrt(sum(iGatherValue(positiveReadoutError(:)).^2));
zeroReadoutDistance = sqrt(sum(iGatherValue(zeroReadoutError(:)).^2));
totalReadoutDistance = sqrt(positiveReadoutDistance^2 + zeroReadoutDistance^2);
readoutSplitText = sprintf(['readout match split: nPositive=%d, nZero=%d, positive-target Read mean/max=%.3f/%.3f, zero-target Read mean/max=%.3f/%.3f, ', ...
	'positive-target RMS error=%.3f, zero-target RMS error=%.3f, distance positive/zero/total=%.3f/%.3f/%.3f; '], ...
	nnz(iGatherValue(positiveReadoutMask)), nnz(iGatherValue(zeroReadoutMask)), ...
	iMeanFlat(positiveReadoutActivity), iMaxFlat(positiveReadoutActivity), iMeanFlat(zeroReadoutActivity), iMaxFlat(zeroReadoutActivity), ...
	iRootMeanSquareFlat(positiveReadoutError), iRootMeanSquareFlat(zeroReadoutError), positiveReadoutDistance, zeroReadoutDistance, totalReadoutDistance);
sourceText = sprintf(['baseline trigger target Read pre mean: L23=%.3f, RewardRecv=%.3f, Read recurrent=%.3f, ', ...
	'IL23=%.3f, IL5RewardRecvI=%.3f, L2 net=%.3f, L5 net=%.3f, total=%.3f; '], ...
	baselineReadoutSource.TargetL23, baselineReadoutSource.TargetRewardRecv, baselineReadoutSource.TargetReadRecurrent, ...
	baselineReadoutSource.TargetIL23, baselineReadoutSource.TargetIL5RewardRecvI, baselineReadoutSource.TargetL2Net, baselineReadoutSource.TargetL5Net, baselineReadoutSource.TargetNet);
suppressionText = sprintf(['baseline suppression correction mean: excess=%.4f, state |delta|=%.4g, Read |delta|=%.4g, TH |delta|=%.4g, RewardRecv |delta|=%.4g, IL5RewardRecvI |delta|=%.4g; ', ...
	'eligibility |all recurrent|=%.4g, target Read |E|=%.4g, target Read |I|=%.4g, Reward aff |elig|=%.4g, I aff |elig|=%.4g; ', ...
	'post-share allocation: Read columns targetRead/nonTargetRead/nonRead=%.3f/%.3f/%.3f, I columns targetRead/nonTargetRead/nonRead=%.3f/%.3f/%.3f; pre-column activity mean Read/I=%.3f/%.3f; ', ...
	'directed target Read dZ mean: RewardRecv=%.4g, Read recurrent=%.4g, E total=%.4g, I total=%.4g; ', ...
	'directed target Read |dZ|: E=%.4g, I=%.4g; Read recurrent punishment pre before/after/delta=%.4g/%.4g/%+.4g; ', ...
	'Read-column W allocation delta per pre cell: targetRead=%+.4g, allRead=%+.4g, nonRead=%+.4g; ', ...
	'I-column W allocation delta per pre cell: targetRead=%+.4g, allRead=%+.4g, nonRead=%+.4g; target Read I pre before/after/delta=%.4g/%.4g/%+.4g; ', ...
	'directed afferent dZ mean/|dZ|: RewardRecv=%.4g/%.4g, IL5RewardRecvI=%.4g/%.4g. '], ...
	baselineSuppressionDiag.ExcessDriveMean, baselineSuppressionDiag.StateDeltaMeanAbs, baselineSuppressionDiag.ReadDeltaMeanAbs, ...
	baselineSuppressionDiag.THDeltaMeanAbs, baselineSuppressionDiag.RewardRecvDeltaMeanAbs, baselineSuppressionDiag.IRewardRecvDeltaMeanAbs, ...
	baselineSuppressionDiag.RecurrentEligibilityMeanAbs, baselineSuppressionDiag.ReadTargetExcEligibilityMeanAbs, baselineSuppressionDiag.ReadTargetInhEligibilityMeanAbs, ...
	baselineSuppressionDiag.RewardAfferentEligibilityMeanAbs, baselineSuppressionDiag.IRewardAfferentEligibilityMeanAbs, ...
	baselineSuppressionDiag.ReadColumnTargetReadPostShare, baselineSuppressionDiag.ReadColumnNonTargetReadPostShare, baselineSuppressionDiag.ReadColumnNonReadPostShare, ...
	baselineSuppressionDiag.InhColumnTargetReadPostShare, baselineSuppressionDiag.InhColumnNonTargetReadPostShare, baselineSuppressionDiag.InhColumnNonReadPostShare, ...
	baselineSuppressionDiag.ReadColumnBeforeMean, baselineSuppressionDiag.InhColumnBeforeMean, ...
	baselineSuppressionDiag.ReadTargetRewardRecvDeltaZMean, baselineSuppressionDiag.ReadTargetReadRecurrentDeltaZMean, ...
	baselineSuppressionDiag.ReadTargetExcDeltaZMean, baselineSuppressionDiag.ReadTargetInhDeltaZMean, ...
	baselineSuppressionDiag.ReadTargetExcDeltaZMeanAbs, baselineSuppressionDiag.ReadTargetInhDeltaZMeanAbs, ...
	baselineSuppressionDiag.ReadTargetReadRecurrentPreBefore, baselineSuppressionDiag.ReadTargetReadRecurrentPreAfter, baselineSuppressionDiag.ReadTargetReadRecurrentPreDelta, ...
	baselineSuppressionDiag.ReadColumnToTargetReadWeightDelta, baselineSuppressionDiag.ReadColumnToReadWeightDelta, baselineSuppressionDiag.ReadColumnToNonReadWeightDelta, ...
	baselineSuppressionDiag.InhColumnToTargetReadWeightDelta, baselineSuppressionDiag.InhColumnToReadWeightDelta, baselineSuppressionDiag.InhColumnToNonReadWeightDelta, ...
	baselineSuppressionDiag.TargetReadInhPreBefore, baselineSuppressionDiag.TargetReadInhPreAfter, baselineSuppressionDiag.TargetReadInhPreDelta, ...
	baselineSuppressionDiag.RewardAfferentDeltaZMean, baselineSuppressionDiag.RewardAfferentDeltaZMeanAbs, ...
	baselineSuppressionDiag.IRewardAfferentDeltaZMean, baselineSuppressionDiag.IRewardAfferentDeltaZMeanAbs);
diagMessage = sprintf(['Baseline diagnostics: rest TH mean/max=%.3f/%.3f; ', ...
	'L23 mean/max=%.3f/%.3f, RewardRecv mean/max=%.3f/%.3f, Read mean/max=%.3f/%.3f, ', ...
	'I mean/max=%.3f/%.3f, IL23 mean/max=%.3f/%.3f, IL5RewardRecvI mean/max=%.3f/%.3f; ', ...
	'IL5RewardRecvI drive: TH afferent pre mean/max=%.4f/%.4f, IL23 recurrent pre mean/min=%.4f/%.4f, IL23 recurrent |pre| mean/max=%.4f/%.4f; ', ...
	'%s%s%s', ...
	'weights: Reward->RewardRecv mean/max=%.4f/%.4f, Reward->IL5RewardRecv mean/max=%.4f/%.4f, RewardRecv->Read mean/max=%.4f/%.4f, ', ...
	'Exc->Read mean/max=%.4f/%.4f, |I->Read| mean/max=%.4f/%.4f, |IL23->Read| mean/max=%.4f/%.4f, ', ...
	'|IL5RewardRecvI->Read| mean/max=%.4f/%.4f, |IL23->IL5RewardRecvI| mean/max=%.4f/%.4f.'], ...
	iMeanFlat(thActivity), iMaxFlat(thActivity), ...
	iMeanFlat(l23Activity), iMaxFlat(l23Activity), iMeanFlat(rewardRecvActivity), iMaxFlat(rewardRecvActivity), ...
	iMeanFlat(readActivity), iMaxFlat(readActivity), iMeanFlat(inhibitoryActivity), iMaxFlat(inhibitoryActivity), ...
	iMeanFlat(iL23Activity), iMaxFlat(iL23Activity), iMeanFlat(iRewardRecvActivity), iMaxFlat(iRewardRecvActivity), ...
	iMeanFlat(thToIL5RewardRecvIPre), iMaxFlat(thToIL5RewardRecvIPre), iMeanFlat(il23ToIL5RewardRecvIPre), iMinFlat(il23ToIL5RewardRecvIPre), ...
	iMeanFlat(abs(il23ToIL5RewardRecvIPre)), iMaxFlat(abs(il23ToIL5RewardRecvIPre)), ...
	readoutSplitText, sourceText, suppressionText, ...
	iMeanFlat(Mouse.W_RewardToL5RewardRecv), iMaxFlat(Mouse.W_RewardToL5RewardRecv), ...
	iMeanFlat(Mouse.W_RewardToIL5RewardRecv), iMaxFlat(Mouse.W_RewardToIL5RewardRecv), ...
	iMeanFlat(rewardRecvToReadW), iMaxFlat(rewardRecvToReadW), iMeanFlat(excToReadW), iMaxFlat(excToReadW), ...
	iMeanFlat(abs(inhToReadW)), iMaxFlat(abs(inhToReadW)), iMeanFlat(abs(il23ToReadW)), iMaxFlat(abs(il23ToReadW)), ...
	iMeanFlat(abs(il5RewardRecvIToReadW)), iMaxFlat(abs(il5RewardRecvIToReadW)), iMeanFlat(abs(il23ToIL5RewardRecvIW)), iMaxFlat(abs(il23ToIL5RewardRecvIW)));
end

function source = iZeroBaselineReadoutSource()
source.TargetL23 = 0;
source.TargetRewardRecv = 0;
source.TargetReadRecurrent = 0;
source.TargetIL23 = 0;
source.TargetIL5RewardRecvI = 0;
source.TargetL2Net = 0;
source.TargetL5Net = 0;
source.TargetNet = 0;
end

function sourceSum = iAddBaselineReadoutSource(sourceSum, sourceNow)
sourceSum.TargetL23 = sourceSum.TargetL23 + sourceNow.TargetL23;
sourceSum.TargetRewardRecv = sourceSum.TargetRewardRecv + sourceNow.TargetRewardRecv;
sourceSum.TargetReadRecurrent = sourceSum.TargetReadRecurrent + sourceNow.TargetReadRecurrent;
sourceSum.TargetIL23 = sourceSum.TargetIL23 + sourceNow.TargetIL23;
sourceSum.TargetIL5RewardRecvI = sourceSum.TargetIL5RewardRecvI + sourceNow.TargetIL5RewardRecvI;
sourceSum.TargetL2Net = sourceSum.TargetL2Net + sourceNow.TargetL2Net;
sourceSum.TargetL5Net = sourceSum.TargetL5Net + sourceNow.TargetL5Net;
sourceSum.TargetNet = sourceSum.TargetNet + sourceNow.TargetNet;
end

function source = iAverageBaselineReadoutSource(sourceSum, nBaselineCorrections)
source = sourceSum;
if nBaselineCorrections <= 0
	source.TargetL23 = NaN;
	source.TargetRewardRecv = NaN;
	source.TargetReadRecurrent = NaN;
	source.TargetIL23 = NaN;
	source.TargetIL5RewardRecvI = NaN;
	source.TargetL2Net = NaN;
	source.TargetL5Net = NaN;
	source.TargetNet = NaN;
	return;
end
source.TargetL23 = source.TargetL23 / nBaselineCorrections;
source.TargetRewardRecv = source.TargetRewardRecv / nBaselineCorrections;
source.TargetReadRecurrent = source.TargetReadRecurrent / nBaselineCorrections;
source.TargetIL23 = source.TargetIL23 / nBaselineCorrections;
source.TargetIL5RewardRecvI = source.TargetIL5RewardRecvI / nBaselineCorrections;
source.TargetL2Net = source.TargetL2Net / nBaselineCorrections;
source.TargetL5Net = source.TargetL5Net / nBaselineCorrections;
source.TargetNet = source.TargetNet / nBaselineCorrections;
end

function diag = iZeroBaselineSuppressionDiagnostic()
diag.ExcessDriveMean = 0;
diag.StateDeltaMeanAbs = 0;
diag.ReadDeltaMeanAbs = 0;
diag.THDeltaMeanAbs = 0;
diag.RewardRecvDeltaMeanAbs = 0;
diag.IRewardRecvDeltaMeanAbs = 0;
diag.RecurrentEligibilityMeanAbs = 0;
diag.ReadTargetExcEligibilityMeanAbs = 0;
diag.ReadTargetInhEligibilityMeanAbs = 0;
diag.ReadColumnTargetReadPostShare = 0;
diag.ReadColumnNonTargetReadPostShare = 0;
diag.ReadColumnNonReadPostShare = 0;
diag.InhColumnTargetReadPostShare = 0;
diag.InhColumnNonTargetReadPostShare = 0;
diag.InhColumnNonReadPostShare = 0;
diag.ReadColumnBeforeMean = 0;
diag.InhColumnBeforeMean = 0;
diag.RewardAfferentEligibilityMeanAbs = 0;
diag.IRewardAfferentEligibilityMeanAbs = 0;
diag.ReadTargetRewardRecvDeltaZMean = 0;
diag.ReadTargetReadRecurrentDeltaZMean = 0;
diag.ReadTargetExcDeltaZMean = 0;
diag.ReadTargetInhDeltaZMean = 0;
diag.ReadTargetExcDeltaZMeanAbs = 0;
diag.ReadTargetInhDeltaZMeanAbs = 0;
diag.ReadTargetReadRecurrentPreBefore = 0;
diag.ReadTargetReadRecurrentPreAfter = 0;
diag.ReadTargetReadRecurrentPreDelta = 0;
diag.ReadColumnToTargetReadWeightDelta = 0;
diag.ReadColumnToReadWeightDelta = 0;
diag.ReadColumnToNonReadWeightDelta = 0;
diag.InhColumnToTargetReadWeightDelta = 0;
diag.InhColumnToReadWeightDelta = 0;
diag.InhColumnToNonReadWeightDelta = 0;
diag.TargetReadInhPreBefore = 0;
diag.TargetReadInhPreAfter = 0;
diag.TargetReadInhPreDelta = 0;
diag.RewardAfferentDeltaZMean = 0;
diag.RewardAfferentDeltaZMeanAbs = 0;
diag.IRewardAfferentDeltaZMean = 0;
diag.IRewardAfferentDeltaZMeanAbs = 0;
end

function diagSum = iAddBaselineSuppressionDiagnostic(diagSum, diagNow)
fieldNames = fieldnames(diagSum);
for iField = 1:numel(fieldNames)
	fieldName = fieldNames{iField};
	diagSum.(fieldName) = diagSum.(fieldName) + diagNow.(fieldName);
end
end

function diag = iAverageBaselineSuppressionDiagnostic(diagSum, nBaselineCorrections)
diag = diagSum;
fieldNames = fieldnames(diag);
for iField = 1:numel(fieldNames)
	fieldName = fieldNames{iField};
	if nBaselineCorrections <= 0
		diag.(fieldName) = NaN;
	else
		diag.(fieldName) = diag.(fieldName) / nBaselineCorrections;
	end
end
end

function source = iReadoutSourceContribution(Mouse, Params, internalActivity)
[l23Activity, rewardRecvActivity, readActivity, iL23Activity, iRewardRecvActivity] = iSplitInternalActivity(internalActivity, Params);
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
l23Cols = 1:Params.NL23;
rewardRecvCols = Params.NL23 + (1:Params.NL5RewardRecv);
readoutCols = readoutRows;
iL23Cols = Params.NL23L5 + (1:Params.NIL23);
iL5RewardRecvICols = Params.NL23L5 + Params.NIL23 + (1:Params.NIL5RewardRecv);
readPattern = iGatherValue(Mouse.L5ReadoutPattern(:));
targetMask = readPattern > 0;
l23Pre = Mouse.W_InternalToInternal(readoutRows, l23Cols) * l23Activity;
rewardRecvPre = Mouse.W_InternalToInternal(readoutRows, rewardRecvCols) * rewardRecvActivity;
readRecurrentPre = Mouse.W_InternalToInternal(readoutRows, readoutCols) * readActivity;
iL23Pre = Mouse.W_InternalToInternal(readoutRows, iL23Cols) * iL23Activity;
iL5RewardRecvIPre = Mouse.W_InternalToInternal(readoutRows, iL5RewardRecvICols) * iRewardRecvActivity;
l2Net = l23Pre + iL23Pre;
l5Net = rewardRecvPre + readRecurrentPre + iL5RewardRecvIPre;
source.TargetL23 = iMeanFlat(l23Pre(targetMask));
source.TargetRewardRecv = iMeanFlat(rewardRecvPre(targetMask));
source.TargetReadRecurrent = iMeanFlat(readRecurrentPre(targetMask));
source.TargetIL23 = iMeanFlat(iL23Pre(targetMask));
source.TargetIL5RewardRecvI = iMeanFlat(iL5RewardRecvIPre(targetMask));
source.TargetL2Net = iMeanFlat(l2Net(targetMask));
source.TargetL5Net = iMeanFlat(l5Net(targetMask));
source.TargetNet = iMeanFlat(l2Net(targetMask) + l5Net(targetMask));
end

function [rL23, rL5RewardRecv, rL5Read, internalActivity, readoutDriveTrace, thActivityHistory, rewardRecvActivityHistory, internalActivityHistory, preIL5RewardRecvHistory] = iRunDecisionNetwork(cueL23DriveHistory, preL5Read, Mouse, Params, Cond)
readoutDriveTrace = zeros(Params.InternalRecurrentPasses + 1, 1);
thActivityHistory = iZeros([Params.NReward, Params.InternalRecurrentPasses + 1], Params);
rewardRecvActivityHistory = iZeros([Params.NL5RewardRecv, Params.InternalRecurrentPasses + 1], Params);
internalActivityHistory = iZeros([Params.NInternal, Params.InternalRecurrentPasses + 1], Params);
preIL5RewardRecvHistory = iZeros([Params.NIL5RewardRecv, Params.InternalRecurrentPasses + 1], Params);
lickTriggered = false;
internalActivity = [];

for iState = 1:Params.InternalRecurrentPasses + 1
	if lickTriggered
		thMode = "lick";
	else
		thMode = "rest";
	end
	rTH = iRunTHInput(Mouse, Params, Cond, thMode);
	thActivityHistory(:, iState) = rTH;
	[preL5RewardRecv, preIL5RewardRecv] = iRewardAfferentPre(Mouse, rTH, Params);
	preIL5RewardRecvHistory(:, iState) = preIL5RewardRecv;
	preL23Now = cueL23DriveHistory(:, iState);
	preIL23Now = Params.NoiseCue * iRandn(Params.NIL23, Params);
	externalPre = iBuildInternalPre(preL23Now, preL5RewardRecv, preL5Read, Params, preIL23Now, preIL5RewardRecv);
	if iState == 1
		networkPre = externalPre;
	else
		networkPre = externalPre + Mouse.W_InternalToInternal * internalActivity;
	end
	networkPre = iAddIterationNoise(networkPre, Params);
	nextActivity = iRunInternalAreas(networkPre, Mouse, Params);
	if iState == 1
		internalActivity = nextActivity;
	else
		internalActivity = iCarryInternalState(internalActivity, nextActivity, Params);
	end
	readoutDriveTrace(iState) = iReadoutDrive(internalActivity, Mouse, Params);
	internalActivityHistory(:, iState) = internalActivity;
	[~, rewardRecvActivityNow] = iSplitInternalActivity(internalActivity, Params);
	rewardRecvActivityHistory(:, iState) = rewardRecvActivityNow;
	lickTriggered = lickTriggered || readoutDriveTrace(iState) >= Params.HitThreshold;
end

[rL23, rL5RewardRecv, rL5Read] = iSplitInternalActivity(internalActivity, Params);
end

function il23ToIL5RewardRecvIPre = iIL23ToIL5RewardRecvIContribution(Mouse, activityHistory, Params)
iL23Cols = Params.NL23L5 + (1:Params.NIL23);
iL5RewardRecvIRows = Params.NL23L5 + Params.NIL23 + (1:Params.NIL5RewardRecv);
iL23Activity = activityHistory(iL23Cols, :);
il23ToIL5RewardRecvIPre = Mouse.W_InternalToInternal(iL5RewardRecvIRows, iL23Cols) * iL23Activity;
end

function [rL23, rL5RewardRecv, rL5Read, internalActivity, readoutDriveTrace, activityHistory] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, Params, preIL23, preIL5RewardRecv)
if nargin < 6
	preIL23 = [];
end
if nargin < 7
	preIL5RewardRecv = [];
end
externalPre = iBuildInternalPre(preL23, preL5RewardRecv, preL5Read, Params, preIL23, preIL5RewardRecv);
internalActivity = iRunInternalAreas(iAddIterationNoise(externalPre, Params), Mouse, Params);
readoutDriveTrace = zeros(Params.InternalRecurrentPasses + 1, 1);
readoutDriveTrace(1) = iReadoutDrive(internalActivity, Mouse, Params);
activityHistory = iZeros([Params.NInternal, Params.InternalRecurrentPasses + 1], Params);
activityHistory(:, 1) = internalActivity;
for iPass = 1:Params.InternalRecurrentPasses
	recurrentPre = externalPre + Mouse.W_InternalToInternal * internalActivity;
	recurrentPre = iAddIterationNoise(recurrentPre, Params);
	nextActivity = iRunInternalAreas(recurrentPre, Mouse, Params);
	internalActivity = iCarryInternalState(internalActivity, nextActivity, Params);
	readoutDriveTrace(iPass + 1) = iReadoutDrive(internalActivity, Mouse, Params);
	activityHistory(:, iPass + 1) = internalActivity;
end
[rL23, rL5RewardRecv, rL5Read] = iSplitInternalActivity(internalActivity, Params);
end

function readoutDrive = iReadoutDrive(internalActivity, Mouse, Params)
[~, ~, rL5Read] = iSplitInternalActivity(internalActivity, Params);
readoutDrive = iReadoutPatternSimilarity(rL5Read, Mouse.L5ReadoutPattern, Params);
end

function similarity = iReadoutPatternSimilarity(readoutActivity, readoutPattern, Params)
normalizedActivity = readoutActivity(:) ./ Params.ResponseScale;
normalizedPattern = readoutPattern(:) ./ Params.ResponseScale;
rootMeanSquaredError = iGatherScalar(sqrt(mean((normalizedActivity - normalizedPattern).^2)));
similarity = 1 - rootMeanSquaredError;
end

function internalActivity = iCarryInternalState(previousActivity, nextActivity, Params)
internalActivity = Params.StateCarryover * previousActivity + (1 - Params.StateCarryover) * nextActivity;
end

function internalPre = iAddIterationNoise(internalPre, Params)
internalPre = internalPre + Params.IterationNoise * iRandn(size(internalPre), Params);
end

function [rL23, rL5RewardRecv, rL5Read] = iRunInternalNetworkReadoutSilent(preL23, preL5RewardRecv, preL5Read, Mouse, Params, preIL23, preIL5RewardRecv)
if nargin < 6
	preIL23 = [];
end
if nargin < 7
	preIL5RewardRecv = [];
end
externalPre = iBuildInternalPre(preL23, preL5RewardRecv, preL5Read, Params, preIL23, preIL5RewardRecv);
internalActivity = iRunInternalAreasReadoutSilent(iAddIterationNoise(externalPre, Params), Mouse, Params);
for iPass = 1:Params.InternalRecurrentPasses
	recurrentPre = externalPre + Mouse.W_InternalToInternal * internalActivity;
	recurrentPre = iAddIterationNoise(recurrentPre, Params);
	nextActivity = iRunInternalAreasReadoutSilent(recurrentPre, Mouse, Params);
	internalActivity = iCarryInternalState(internalActivity, nextActivity, Params);
end
[rL23, rL5RewardRecv, rL5Read] = iSplitInternalActivity(internalActivity, Params);
end

function internalActivity = iRunInternalAreas(internalPre, Mouse, Params)
[preL23, preL5RewardRecv, preL5Read, preIL23, preIL5RewardRecv] = iSplitInternalActivity(internalPre, Params);
rL23 = iRunArea(preL23, 'l23', Mouse, Params);
rL5RewardRecv = iRunArea(preL5RewardRecv, 'l5rewardrecv', Mouse, Params);
rL5Read = iRunArea(preL5Read, 'l5read', Mouse, Params);
rIL23 = iRunArea(preIL23, 'il23', Mouse, Params);
rIL5RewardRecv = iRunArea(preIL5RewardRecv, 'il5rewardrecv', Mouse, Params);
internalActivity = [rL23; rL5RewardRecv; rL5Read; rIL23; rIL5RewardRecv];
end

function internalActivity = iRunInternalAreasReadoutSilent(internalPre, Mouse, Params)
[preL23, preL5RewardRecv, ~, preIL23, preIL5RewardRecv] = iSplitInternalActivity(internalPre, Params);
rL23 = iRunArea(preL23, 'l23', Mouse, Params);
rL5RewardRecv = iRunArea(preL5RewardRecv, 'l5rewardrecv', Mouse, Params);
rL5Read = zeros(Params.NL5Read, size(internalPre, 2), 'like', internalPre);
rIL23 = iRunArea(preIL23, 'il23', Mouse, Params);
rIL5RewardRecv = iRunArea(preIL5RewardRecv, 'il5rewardrecv', Mouse, Params);
internalActivity = [rL23; rL5RewardRecv; rL5Read; rIL23; rIL5RewardRecv];
end

function internalPre = iBuildInternalPre(preL23, preL5RewardRecv, preL5Read, Params, preIL23, preIL5RewardRecv)
if nargin < 5 || isempty(preIL23)
	preIL23 = zeros(Params.NIL23, size(preL23, 2), 'like', preL23);
end
if nargin < 6 || isempty(preIL5RewardRecv)
	preIL5RewardRecv = zeros(Params.NIL5RewardRecv, size(preL5RewardRecv, 2), 'like', preL5RewardRecv);
end
internalPre = [preL23; preL5RewardRecv; preL5Read; preIL23; preIL5RewardRecv];
end

function [l23Part, l5RewardRecvPart, l5ReadPart, iL23Part, iL5RewardRecvPart] = iSplitInternalActivity(internalActivity, Params)
l23End = Params.NL23;
l5RewardRecvEnd = Params.NL23 + Params.NL5RewardRecv;
l5ReadEnd = l5RewardRecvEnd + Params.NL5Read;
iL23End = l5ReadEnd + Params.NIL23;
l23Part = internalActivity(1:l23End, :);
l5RewardRecvPart = internalActivity(l23End+1:l5RewardRecvEnd, :);
l5ReadPart = internalActivity(l5RewardRecvEnd+1:l5ReadEnd, :);
iL23Part = internalActivity(l5ReadEnd+1:iL23End, :);
iL5RewardRecvPart = internalActivity(iL23End+1:end, :);
end

function [eligRewardAfferent, eligInternal] = iUpdateTaskLearningHistoryEligibility(...
	eligRewardAfferent, eligInternal, decisionActivityHistory, learningActivityHistory, rReward, Params)
trialActivityHistory = [decisionActivityHistory, learningActivityHistory];
rewardLearningActivityHistory = [decisionActivityHistory(:, end), learningActivityHistory];
rewardHistory = repmat(rReward, 1, size(rewardLearningActivityHistory, 2));
eligRewardAfferent = iUpdateRewardAfferentHistoryEligibility(eligRewardAfferent, rewardLearningActivityHistory, rewardHistory, Params);
eligInternal = iUpdateInternalHistoryEligibility(eligInternal, trialActivityHistory, Params);
end

function eligRewardAfferent = iUpdateRewardAfferentHistoryEligibility(eligRewardAfferent, activityHistory, rewardHistory, Params)
for iState = 2:size(activityHistory, 2)
	[~, rL5RewardRecvAfter, ~, ~, rIL5RewardRecvAfter] = iSplitInternalActivity(activityHistory(:, iState), Params);
	eligRewardAfferent = iUpdateCellEligibility(eligRewardAfferent, rewardHistory(:, iState - 1), [rL5RewardRecvAfter; rIL5RewardRecvAfter], Params.EligibilityDecay);
end
end

function eligInternal = iUpdateInternalHistoryEligibility(eligInternal, activityHistory, Params)
for iState = 2:size(activityHistory, 2)
	eligInternal = iUpdateRecurrentEligibility(eligInternal, activityHistory(:, iState - 1), activityHistory(:, iState), Params.EligibilityDecay, Params);
end
end

function cellEligibility = iUpdateRecurrentEligibility(cellEligibility, activityBefore, activityAfter, decay, ~)
cellEligibility = iUpdateCellEligibility(cellEligibility, activityBefore, activityAfter, decay);
end

function cellEligibility = iZeroCellEligibility(nBeforeCells, nAfterCells, Params)
cellEligibility.Before = iZeros(nBeforeCells, Params);
cellEligibility.After = iZeros(nAfterCells, Params);
end

function cellEligibility = iUpdateCellEligibility(cellEligibility, beforeActivity, afterActivity, decay)
cellEligibility.Before = decay * cellEligibility.Before + max(beforeActivity(:), 0);
cellEligibility.After = decay * cellEligibility.After + max(afterActivity(:), 0);
end

function [eligibilityTraceA, eligibilityTraceB] = iPairedCellEligibilityToSynapseEligibility(cellEligibility, nPostA)
eligibilityTrace = iCellEligibilityToSynapseEligibility(cellEligibility);
eligibilityTraceA = eligibilityTrace(1:nPostA, :);
eligibilityTraceB = eligibilityTrace(nPostA+1:end, :);
end

function eligibilityTrace = iCellEligibilityToSynapseEligibility(cellEligibility)
postShare = cellEligibility.After(:) / sum(cellEligibility.After(:));
eligibilityTrace = postShare * cellEligibility.Before(:)';
end

function eligibilityTrace = iRecurrentCellEligibilityToSynapseEligibility(cellEligibility, Params)
postNumerator = repmat(cellEligibility.After(:), 1, Params.NInternal);
postNumerator = iZeroSelfProjection(postNumerator);
postShare = postNumerator ./ sum(postNumerator, 1);
eligibilityTrace = postShare .* cellEligibility.Before(:)';
eligibilityTrace = iZeroSelfProjection(eligibilityTrace);
end

function [accumulatorA, accumulatorB, effectiveWeightsA, effectiveWeightsB] = iApplyLatentPairedHebbTrace(accumulatorA, accumulatorB, eligibilityTraceA, eligibilityTraceB, eta, cap, slope, isPunishment)
eligibilityTraceA = iLearningDirectedAfferentEligibility(eligibilityTraceA, isPunishment);
eligibilityTraceB = iLearningDirectedAfferentEligibility(eligibilityTraceB, isPunishment);
[accumulatorA, accumulatorB] = iShiftPairedColumnsToNonnegative(accumulatorA + eta * eligibilityTraceA, accumulatorB + eta * eligibilityTraceB);
[effectiveWeightsA, effectiveWeightsB] = iPairedAccumulatorToExcitatoryWeight(accumulatorA, accumulatorB, cap, slope);
end

function [accumulator, effectiveWeights] = iApplyLatentInternalTrace(accumulator, eligibilityTrace, eta, Params, isPunishment)
eligibilityTrace = iLearningDirectedInternalEligibility(eligibilityTrace, Params, isPunishment);
accumulator = iShiftRecurrentColumnsToNonnegative(accumulator + eta * eligibilityTrace);
effectiveWeights = iAccumulatorToInternalWeight(accumulator, Params);
end

function eligibilityTrace = iLearningDirectedAfferentEligibility(eligibilityTrace, isPunishment)
if isPunishment
	eligibilityTrace = -eligibilityTrace;
end
end

function eligibilityTrace = iLearningDirectedInternalEligibility(eligibilityTrace, Params, isPunishment)
inhCols = Params.NL23L5 + (1:Params.NIInternal);
eligibilityTrace(:, inhCols) = -eligibilityTrace(:, inhCols);
if isPunishment
	eligibilityTrace = -eligibilityTrace;
end
end

function [Mouse, correctionDiag] = iSuppressFalseReadout(Mouse, internalActivityBefore, internalActivityAfter, falseDrive, Params, thActivityBefore, thActivityAfter, rewardRecvActivityBefore, rewardRecvActivityAfter, iRewardRecvActivityBefore, iRewardRecvActivityAfter)
excessDrive = max(falseDrive - Params.HitThreshold, 0);
eta = Params.BaselineAntiHebbRate * (1 + excessDrive);
isPunishment = true;
eligInternal = iZeroCellEligibility(Params.NInternal, Params.NInternal, Params);
eligInternal = iUpdateRecurrentEligibility(eligInternal, internalActivityBefore, internalActivityAfter, Params.EligibilityDecay, Params);
eligInternalToInternal = iRecurrentCellEligibilityToSynapseEligibility(eligInternal, Params);

etaAfferent = Params.BaselineAfferentAntiHebbRate * (1 + excessDrive);
eligRewardAfferent = iZeroCellEligibility(Params.NReward, Params.NL5RewardRecv + Params.NIL5RewardRecv, Params);
eligRewardAfferent = iUpdateCellEligibility(eligRewardAfferent, thActivityBefore, [rewardRecvActivityAfter; iRewardRecvActivityAfter], Params.EligibilityDecay);
[afferentEligibility, iAfferentEligibility] = iPairedCellEligibilityToSynapseEligibility(eligRewardAfferent, Params.NL5RewardRecv);
correctionDiag = iBaselineSuppressionCorrectionDiagnostic(Mouse, Params, falseDrive, internalActivityBefore, internalActivityAfter, thActivityBefore, thActivityAfter, rewardRecvActivityBefore, rewardRecvActivityAfter, iRewardRecvActivityBefore, iRewardRecvActivityAfter, eligInternalToInternal, afferentEligibility, iAfferentEligibility, eta, etaAfferent, isPunishment);
[Mouse.Z_InternalToInternal, Mouse.W_InternalToInternal] = iApplyLatentInternalTrace(Mouse.Z_InternalToInternal, eligInternalToInternal, eta, Params, isPunishment);
[Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, Mouse.W_RewardToL5RewardRecv, Mouse.W_RewardToIL5RewardRecv] = iApplyLatentPairedHebbTrace(Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, afferentEligibility, iAfferentEligibility, etaAfferent, Params.AfferentWCap, Params.WeightMapSlope, isPunishment);
end

function correctionDiag = iBaselineSuppressionCorrectionDiagnostic(Mouse, Params, falseDrive, internalActivityBefore, internalActivityAfter, thActivityBefore, thActivityAfter, rewardRecvActivityBefore, rewardRecvActivityAfter, iRewardRecvActivityBefore, iRewardRecvActivityAfter, eligInternalToInternal, afferentEligibility, iAfferentEligibility, eta, etaAfferent, isPunishment)
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
rewardRecvCols = Params.NL23 + (1:Params.NL5RewardRecv);
readoutCols = readoutRows;
hiddenECols = 1:Params.NL23L5;
hiddenICols = Params.NL23L5 + (1:Params.NIInternal);
nonReadRows = setdiff(1:Params.NInternal, readoutRows);
readPattern = iGatherValue(Mouse.L5ReadoutPattern(:));
targetRows = readoutRows(readPattern > 0);
nonTargetReadRows = setdiff(readoutRows, targetRows);
[internalAccumulatorAfter, internalWeightsAfter] = iApplyLatentInternalTrace(Mouse.Z_InternalToInternal, eligInternalToInternal, eta, Params, isPunishment);
[rewardAccumulatorAfter, iRewardAccumulatorAfter, ~, ~] = iApplyLatentPairedHebbTrace(Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, afferentEligibility, iAfferentEligibility, etaAfferent, Params.AfferentWCap, Params.WeightMapSlope, isPunishment);
directedInternalDeltaZ = internalAccumulatorAfter - Mouse.Z_InternalToInternal;
directedAfferentDeltaZ = rewardAccumulatorAfter - Mouse.Z_RewardToL5RewardRecv;
directedIAfferentDeltaZ = iRewardAccumulatorAfter - Mouse.Z_RewardToIL5RewardRecv;
[~, ~, readBefore] = iSplitInternalActivity(internalActivityBefore, Params);
[~, ~, readAfter] = iSplitInternalActivity(internalActivityAfter, Params);
postNumerator = repmat(max(internalActivityAfter(:), 0), 1, Params.NInternal);
postNumerator = iZeroSelfProjection(postNumerator);
postShare = postNumerator ./ sum(postNumerator, 1);
readTargetRecurrentPreBefore = Mouse.W_InternalToInternal(targetRows, readoutCols) * readAfter;
readTargetRecurrentPreAfter = internalWeightsAfter(targetRows, readoutCols) * readAfter;
readColumnToTargetReadBefore = sum(Mouse.W_InternalToInternal(targetRows, readoutCols), 1);
readColumnToTargetReadAfter = sum(internalWeightsAfter(targetRows, readoutCols), 1);
readColumnToReadBefore = sum(Mouse.W_InternalToInternal(readoutRows, readoutCols), 1);
readColumnToReadAfter = sum(internalWeightsAfter(readoutRows, readoutCols), 1);
readColumnToNonReadBefore = sum(Mouse.W_InternalToInternal(nonReadRows, readoutCols), 1);
readColumnToNonReadAfter = sum(internalWeightsAfter(nonReadRows, readoutCols), 1);
inhColumnToTargetReadBefore = sum(Mouse.W_InternalToInternal(targetRows, hiddenICols), 1);
inhColumnToTargetReadAfter = sum(internalWeightsAfter(targetRows, hiddenICols), 1);
inhColumnToReadBefore = sum(Mouse.W_InternalToInternal(readoutRows, hiddenICols), 1);
inhColumnToReadAfter = sum(internalWeightsAfter(readoutRows, hiddenICols), 1);
inhColumnToNonReadBefore = sum(Mouse.W_InternalToInternal(nonReadRows, hiddenICols), 1);
inhColumnToNonReadAfter = sum(internalWeightsAfter(nonReadRows, hiddenICols), 1);
inhActivityAfter = internalActivityAfter(hiddenICols);
targetReadInhPreBefore = Mouse.W_InternalToInternal(targetRows, hiddenICols) * inhActivityAfter;
targetReadInhPreAfter = internalWeightsAfter(targetRows, hiddenICols) * inhActivityAfter;
correctionDiag.ExcessDriveMean = iGatherScalar(falseDrive - Params.HitThreshold);
correctionDiag.StateDeltaMeanAbs = iMeanFlat(abs(internalActivityAfter - internalActivityBefore));
correctionDiag.ReadDeltaMeanAbs = iMeanFlat(abs(readAfter - readBefore));
correctionDiag.THDeltaMeanAbs = iMeanFlat(abs(thActivityAfter - thActivityBefore));
correctionDiag.RewardRecvDeltaMeanAbs = iMeanFlat(abs(rewardRecvActivityAfter - rewardRecvActivityBefore));
correctionDiag.IRewardRecvDeltaMeanAbs = iMeanFlat(abs(iRewardRecvActivityAfter - iRewardRecvActivityBefore));
correctionDiag.RecurrentEligibilityMeanAbs = iMeanFlat(abs(eligInternalToInternal));
correctionDiag.ReadTargetExcEligibilityMeanAbs = iMeanFlat(abs(eligInternalToInternal(targetRows, hiddenECols)));
correctionDiag.ReadTargetInhEligibilityMeanAbs = iMeanFlat(abs(eligInternalToInternal(targetRows, hiddenICols)));
correctionDiag.ReadColumnTargetReadPostShare = iMeanFlat(sum(postShare(targetRows, readoutCols), 1));
correctionDiag.ReadColumnNonTargetReadPostShare = iMeanFlat(sum(postShare(nonTargetReadRows, readoutCols), 1));
correctionDiag.ReadColumnNonReadPostShare = iMeanFlat(sum(postShare(nonReadRows, readoutCols), 1));
correctionDiag.InhColumnTargetReadPostShare = iMeanFlat(sum(postShare(targetRows, hiddenICols), 1));
correctionDiag.InhColumnNonTargetReadPostShare = iMeanFlat(sum(postShare(nonTargetReadRows, hiddenICols), 1));
correctionDiag.InhColumnNonReadPostShare = iMeanFlat(sum(postShare(nonReadRows, hiddenICols), 1));
correctionDiag.ReadColumnBeforeMean = iMeanFlat(max(internalActivityBefore(readoutCols), 0));
correctionDiag.InhColumnBeforeMean = iMeanFlat(max(internalActivityBefore(hiddenICols), 0));
correctionDiag.RewardAfferentEligibilityMeanAbs = iMeanFlat(abs(afferentEligibility));
correctionDiag.IRewardAfferentEligibilityMeanAbs = iMeanFlat(abs(iAfferentEligibility));
correctionDiag.ReadTargetRewardRecvDeltaZMean = iMeanFlat(directedInternalDeltaZ(targetRows, rewardRecvCols));
correctionDiag.ReadTargetReadRecurrentDeltaZMean = iMeanFlat(directedInternalDeltaZ(targetRows, readoutCols));
correctionDiag.ReadTargetExcDeltaZMean = iMeanFlat(directedInternalDeltaZ(targetRows, hiddenECols));
correctionDiag.ReadTargetInhDeltaZMean = iMeanFlat(directedInternalDeltaZ(targetRows, hiddenICols));
correctionDiag.ReadTargetExcDeltaZMeanAbs = iMeanFlat(abs(directedInternalDeltaZ(targetRows, hiddenECols)));
correctionDiag.ReadTargetInhDeltaZMeanAbs = iMeanFlat(abs(directedInternalDeltaZ(targetRows, hiddenICols)));
correctionDiag.ReadTargetReadRecurrentPreBefore = iMeanFlat(readTargetRecurrentPreBefore);
correctionDiag.ReadTargetReadRecurrentPreAfter = iMeanFlat(readTargetRecurrentPreAfter);
correctionDiag.ReadTargetReadRecurrentPreDelta = iMeanFlat(readTargetRecurrentPreAfter - readTargetRecurrentPreBefore);
correctionDiag.ReadColumnToTargetReadWeightDelta = iMeanFlat(readColumnToTargetReadAfter - readColumnToTargetReadBefore);
correctionDiag.ReadColumnToReadWeightDelta = iMeanFlat(readColumnToReadAfter - readColumnToReadBefore);
correctionDiag.ReadColumnToNonReadWeightDelta = iMeanFlat(readColumnToNonReadAfter - readColumnToNonReadBefore);
correctionDiag.InhColumnToTargetReadWeightDelta = iMeanFlat(inhColumnToTargetReadAfter - inhColumnToTargetReadBefore);
correctionDiag.InhColumnToReadWeightDelta = iMeanFlat(inhColumnToReadAfter - inhColumnToReadBefore);
correctionDiag.InhColumnToNonReadWeightDelta = iMeanFlat(inhColumnToNonReadAfter - inhColumnToNonReadBefore);
correctionDiag.TargetReadInhPreBefore = iMeanFlat(targetReadInhPreBefore);
correctionDiag.TargetReadInhPreAfter = iMeanFlat(targetReadInhPreAfter);
correctionDiag.TargetReadInhPreDelta = iMeanFlat(targetReadInhPreAfter - targetReadInhPreBefore);
correctionDiag.RewardAfferentDeltaZMean = iMeanFlat(directedAfferentDeltaZ);
correctionDiag.RewardAfferentDeltaZMeanAbs = iMeanFlat(abs(directedAfferentDeltaZ));
correctionDiag.IRewardAfferentDeltaZMean = iMeanFlat(directedIAfferentDeltaZ);
correctionDiag.IRewardAfferentDeltaZMeanAbs = iMeanFlat(abs(directedIAfferentDeltaZ));
end

function effectiveWeights = iAccumulatorToInternalWeight(accumulator, Params)
effectiveWeights = zeros(size(accumulator), 'like', accumulator);
excCols = 1:Params.NL23L5;
inhCols = Params.NL23L5 + (1:Params.NIInternal);
effectiveWeights(:, excCols) = iAccumulatorToExcitatoryWeight(accumulator(:, excCols), Params.WCap, Params.WeightMapSlope);
effectiveWeights(:, inhCols) = iAccumulatorToInhibitoryOutputWeight(accumulator(:, inhCols), Params.InhOutputWCap, Params.WeightMapSlope);
effectiveWeights = iZeroSelfProjection(effectiveWeights);
end

function effectiveWeights = iAccumulatorToExcitatoryWeight(accumulator, cap, ~)
effectiveWeights = cap * iColumnDistribution(accumulator);
end

function [effectiveWeightsA, effectiveWeightsB] = iPairedAccumulatorToExcitatoryWeight(accumulatorA, accumulatorB, cap, ~)
nPostA = size(accumulatorA, 1);
combinedWeights = cap * iColumnDistribution([accumulatorA; accumulatorB]);
effectiveWeightsA = combinedWeights(1:nPostA, :);
effectiveWeightsB = combinedWeights(nPostA+1:end, :);
end

function effectiveWeights = iAccumulatorToInhibitoryOutputWeight(accumulator, cap, ~)
effectiveWeights = -cap * iColumnDistribution(accumulator);
end

function distribution = iColumnDistribution(accumulator)
distribution = accumulator ./ sum(accumulator, 1);
end

function accumulator = iShiftColumnsToNonnegative(accumulator)
accumulator = accumulator - min(accumulator, [], 1);
end

function [accumulatorA, accumulatorB] = iShiftPairedColumnsToNonnegative(accumulatorA, accumulatorB)
nPostA = size(accumulatorA, 1);
combinedAccumulator = iShiftColumnsToNonnegative([accumulatorA; accumulatorB]);
accumulatorA = combinedAccumulator(1:nPostA, :);
accumulatorB = combinedAccumulator(nPostA+1:end, :);
end

function accumulator = iShiftRecurrentColumnsToNonnegative(accumulator)
accumulator = iZeroSelfProjection(accumulator);
for iCol = 1:size(accumulator, 2)
	downstreamRows = [1:iCol-1, iCol+1:size(accumulator, 1)];
	columnMinimum = min(accumulator(downstreamRows, iCol));
	accumulator(downstreamRows, iCol) = accumulator(downstreamRows, iCol) - columnMinimum;
end
accumulator = iZeroSelfProjection(accumulator);
end

function recurrentWeights = iZeroSelfProjection(recurrentWeights)
numCells = size(recurrentWeights, 1);
recurrentWeights(1:numCells+1:end) = 0;
end

function Mouse = iOvernightConsolidate(Mouse, Params)
ret = Params.OvernightRetention;
sd = Params.OvernightNoise;
[Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv] = iShiftPairedColumnsToNonnegative(...
	ret * Mouse.Z_RewardToL5RewardRecv + sd * iRandn(size(Mouse.Z_RewardToL5RewardRecv), Params), ...
	ret * Mouse.Z_RewardToIL5RewardRecv + sd * iRandn(size(Mouse.Z_RewardToIL5RewardRecv), Params));
Mouse.Z_InternalToInternal = iShiftRecurrentColumnsToNonnegative(ret * Mouse.Z_InternalToInternal + sd * iRandn(size(Mouse.Z_InternalToInternal), Params));
[Mouse.W_RewardToL5RewardRecv, Mouse.W_RewardToIL5RewardRecv] = iPairedAccumulatorToExcitatoryWeight(Mouse.Z_RewardToL5RewardRecv, Mouse.Z_RewardToIL5RewardRecv, Params.AfferentWCap, Params.WeightMapSlope);
Mouse.W_InternalToInternal = iAccumulatorToInternalWeight(Mouse.Z_InternalToInternal, Params);
end

function tf = iUseGPU(Params)
tf = isfield(Params, 'UseGPU') && Params.UseGPU;
end

function accumulator = iInitChiSquareAccumulator(sz, scale, dof, Params)
accumulator = scale * iRandChiSquare(sz, dof, Params);
end

function values = iRandChiSquare(sz, dof, Params)
values = iZeros(sz, Params);
for iDof = 1:dof
	randValues = iRandn(sz, Params);
	values = values + randValues.^2;
end
end

function values = iRandn(sz, Params)
if isscalar(sz)
	sz = [sz, 1];
end
if iUseGPU(Params)
	values = gpuArray.randn(sz(1), sz(2), Params.GPUPrecision);
else
	values = randn(sz);
end
end

function values = iZeros(sz, Params)
if isscalar(sz)
	sz = [sz, 1];
end
if iUseGPU(Params)
	values = gpuArray.zeros(sz(1), sz(2), Params.GPUPrecision);
else
	values = zeros(sz);
end
end

function values = iGatherValue(values)
if isa(values, 'gpuArray')
	values = gather(values);
end
end

function value = iGatherScalar(value)
value = iGatherValue(value);
end

function y = iClamp(x, lo, hi)
y = max(min(x, hi), lo);
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

function c = iPositiveCoactivity(x, axisVector)
x = x(:);
axisVector = axisVector(:);
coactivity = x .* axisVector;
c = mean(max(coactivity, 0), 'omitnan');
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
v = v - mean(v);
sd = iGatherScalar(std(v, 0));
if ~isfinite(sd) || sd < eps
	sd = 1;
end
v = v ./ sd;
end

function pattern = iVertexPattern(patternSeed, highValue)
pattern = highValue * (patternSeed(:) > 0);
end

function pattern = iFixedActiveVertexPattern(patternSeed, highValue, nActive)
patternSeed = patternSeed(:);
[~, sortedIndices] = sort(patternSeed, 'descend');
pattern = zeros(size(patternSeed), 'like', patternSeed);
pattern(sortedIndices(1:nActive)) = highValue;
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

function iAnnotateMetricStats(ax, PerMouse, Cond, fieldName)
naive = PerMouse.(Cond.Name(1)).(fieldName);
transfer = PerMouse.(Cond.Name(2)).(fieldName);
thOff = PerMouse.(Cond.Name(3)).(fieldName);

naive = naive(isfinite(naive));
transfer = transfer(isfinite(transfer));
thOff = thOff(isfinite(thOff));

p12 = ranksum(naive, transfer);
p23 = ranksum(transfer, thOff);
p13 = ranksum(naive, thOff);
pAll = kruskalwallis([naive; transfer; thOff], ...
	[repmat(cellstr(Cond.Label(1)), numel(naive), 1); repmat(cellstr(Cond.Label(2)), numel(transfer), 1); repmat(cellstr(Cond.Label(3)), numel(thOff), 1)], 'off');

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