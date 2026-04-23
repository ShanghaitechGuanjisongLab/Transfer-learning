% THInhibitoryHeterogeneitySimulation
%
% Minimal rate-model simulation for three qualitative findings:
% 1) transfer starts from a higher first-session performance than naive,
% 2) TH-dependent inhibitory competition increases process-averaged response heterogeneity,
% 3) larger learning-process L2/3 heterogeneity correlates with faster subsequent learning.
%
% The model contains:
% - excitatory populations in L2/3 and L5,
% - an explicit inhibitory population driven by cortical excitation and TH,
% - an explicit cue-input pathway,
% - a reusable schema state acquired by pre-training on an alternate cue,
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

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'THInhibitoryHeterogeneityModel', Summary);

function Params = iDefaultParams()
% Three-population architecture:
%   Cue   (sensory cue population, size NCue, with plastic inhibitory pool)
%   Rew   (reward-coding population, size NRew, with plastic inhibitory pool)
%   Read  (behavioural readout population, size NRead; no plastic I-pool)
% Six directed plastic E-E pathways (all pairs of populations, both directions).
% Decision phase uses cue input only; readout receives direct (cue->read)
% + indirect (cue->rew->read) activity, summed, then thresholded to a hit.
% Learning phase clamps each population to its fixed input pattern and
% applies outer-product Hebbian updates on all six W matrices plus the
% per-cell inhibitory gain in Cue/Rew areas.
Params.NumMice = 20;
Params.NumSessions = 8;
Params.NumTrials = 72;
Params.NCue = 96;
Params.NRew = 64;
Params.NRead = 64;
Params.NICue = 24;
Params.NIRew = 16;
Params.ResponseScale = 1.45;
Params.NoiseCue = 0.22;
Params.NoiseRew = 0.15;
Params.NoiseRead = 0.12;
Params.NoiseI = 0.12;
Params.Comp_Cue = 0.95;
Params.Comp_Rew = 1.00;
% Input gains
Params.CueInputGain = 1.00;          % sensory cue drive (decision + learning)
Params.CueInputGainPretrain = 1.50;  % pretraining cue gain
Params.RewInputGain = 0.85;          % reward pattern clamp amplitude (learning phase only)
Params.ReadInputGain = 0.85;         % readout pattern clamp amplitude (learning phase only)
Params.BaseInputGain = 0.15;         % baseline trial drive on Cue area
% Decision readout: network noise creates trial-to-trial variability,
% and a hit is emitted when the readout crosses HitThreshold.
Params.HitThreshold = 0.35;
Params.BaselinePenalty = 1.00;
Params.Ceiling = 1.00;
% Slope fit: drop sessions from the first 100%-hit session onward
% (that session and every subsequent one) so the plateau at 1.0 does
% not compress the slope of fast learners.
Params.SlopeHitPerfect = 1.00;
% Plastic E-E weights (all pathways): zero-mean init, symmetric cap.
Params.InitWStd = 0.03;
Params.WCap = 1.20;
% Per-trial Hebbian rate. With NumTrials=72 per session, total within-
% session increase ≈ 72 * HebbRate * eta_factors.
Params.HebbRate = 0.0025;
% Inhibitory plasticity (per-E-cell gain, Vogels-Sprekeler style, per-trial).
Params.InhPlasticityRate = 0.002;
Params.InhTargetAct = 0.00;
Params.InhGainMin = 0.20;
Params.InhGainMax = 3.00;
% Cross-modality overlap between pretraining cue (e.g. sound) and new cue
% (e.g. light). Real cortical populations are never fully orthogonal; each
% Cue-area cell has a shared component plus a modality-unique component.
% Correlation between CuePattern and PreCuePattern = CueModalityCorr.
Params.CueModalityCorr = 0.50;
% Overnight consolidation
Params.OvernightRetention = 0.96;
Params.OvernightNoise = 0.002;
% Pretraining
Params.MaxPretrainSessions = 150;
Params.PostCeilingSessions = 2;
end

function Cond = iConditionTable()
Cond = table;
Cond.Name = ["Naive"; "Transfer"; "THOff"];
Cond.Label = ["Naive"; "Transfer"; "TH inhibited"];
Cond.Color = [1, 0, 0; 0, 0, 1; 0, 0, 0];
Cond.THNetworkLevel = [1.00; 1.00; 0.70];
Cond.THPlasticityLevel = [1.00; 1.00; 0.25];
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
		if Cond.Name(iCond) ~= "Naive"
			% Pretraining shapes all six E-E matrices + inhibitory gains.
			% No artificial pruning on task switch: the same M2 population
			% carries both modalities, so synapses are fully inherited.
			% The "transfer advantage" emerges naturally because
			% (i) CuePattern and PreCuePattern share a subpopulation
			%     (cross-modal correlation = Params.CueModalityCorr), and
			% (ii) Rew<->Read pathways encode a task schema that is
			%     common to both cues.
			% OvernightRetention already models the small natural drift
			% between pretraining and the new task.
			Mouse = iPretrainMouse(Mouse, Params);
		end
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
Summary.CorrMouse = Summary.AllMouse;
end

function Mouse = iDrawMouse(Params)
% Per-mouse Hebbian learning-rate scaling (individual variability).
Mouse.HeteroGain = max(0.30, 1 + 0.72 * randn());

% Fixed input / target patterns (zero-mean, unit-std).
% PreCue and Cue share a common component (cross-modal correlation a) so
% that a fraction of Cue-area cells respond to both modalities, matching
% the fact that sensory cortical populations are never fully orthogonal.
a = Params.CueModalityCorr;
sharedCue = iStandardize(randn(Params.NCue, 1));
preCueU   = iStandardize(randn(Params.NCue, 1));
cueU      = iStandardize(randn(Params.NCue, 1));
Mouse.PreCuePattern = iStandardize(a * sharedCue + sqrt(1 - a^2) * preCueU);
Mouse.CuePattern    = iStandardize(a * sharedCue + sqrt(1 - a^2) * cueU);
Mouse.BasePattern   = iStandardize(0.35 * randn(Params.NCue, 1));
Mouse.RewardPattern = iStandardize(randn(Params.NRew,  1) + 0.55 * sign(randn(Params.NRew,  1)));
Mouse.ReadoutPattern= iStandardize(randn(Params.NRead, 1) + 0.55 * sign(randn(Params.NRead, 1)));

% Six plastic E-E matrices, W(post, pre). Output = W * pre.
sd = Params.InitWStd;
Mouse.W_CueToRew  = sd * randn(Params.NRew,  Params.NCue);
Mouse.W_RewToCue  = sd * randn(Params.NCue,  Params.NRew);
Mouse.W_CueToRead = sd * randn(Params.NRead, Params.NCue);
Mouse.W_ReadToCue = sd * randn(Params.NCue,  Params.NRead);
Mouse.W_RewToRead = sd * randn(Params.NRead, Params.NRew);
Mouse.W_ReadToRew = sd * randn(Params.NRew,  Params.NRead);

% Inhibitory pools in Cue / Rew areas (plastic via per-E-cell gain).
Mouse.WIE_Cue = abs(0.72 + 0.20 * randn(Params.NICue, Params.NCue));
Mouse.WEI_Cue = abs(0.88 + 0.26 * randn(Params.NCue,  Params.NICue));
Mouse.WIE_Rew = abs(0.72 + 0.20 * randn(Params.NIRew, Params.NRew));
Mouse.WEI_Rew = abs(0.88 + 0.26 * randn(Params.NRew,  Params.NIRew));
Mouse.InhGainCue = ones(Params.NCue, 1);
Mouse.InhGainRew = ones(Params.NRew, 1);

% TH drive onto each area's inhibitory pool.
Mouse.THToICue = abs(0.72 + 0.18 * randn(Params.NICue, 1));
Mouse.THToIRew = abs(0.72 + 0.18 * randn(Params.NIRew, 1));
end

function Mouse = iPretrainMouse(Mouse, Params)
% Pretraining with full TH. Uses PreCuePattern.
pretrainTH.THNetworkLevel = 1.00;
pretrainTH.THPlasticityLevel = 1.00;
lastPerfExpected = NaN;
postCeilingCount = 0;

for iSess = 1:Params.MaxPretrainSessions
	[perfObserved, ~, perfExpected, Mouse] = iSimulateSession(Mouse, Params, pretrainTH, true);
	lastPerfExpected = perfExpected;

	if perfObserved >= Params.Ceiling || perfExpected >= Params.Ceiling - 2 / Params.NumTrials
		postCeilingCount = postCeilingCount + 1;
		if postCeilingCount >= Params.PostCeilingSessions
			return;
		end
	end
	Mouse = iOvernightConsolidate(Mouse, Params);
end

error('THModel:PretrainDidNotReachCeiling', 'Pretraining did not reach ceiling within %d sessions. Final expected hit = %.3f.', Params.MaxPretrainSessions, lastPerfExpected);
end

function Result = iSimulateMouse(Mouse, Params, Cond)
perf = nan(1, Params.NumSessions);
h23 = nan(1, Params.NumSessions);
h5 = nan(1, Params.NumSessions);
sessionMeanCue  = nan(Params.NCue,  Params.NumSessions);
sessionMeanRead = nan(Params.NRead, Params.NumSessions);

for iSess = 1:Params.NumSessions
	[perf(iSess), Signals, ~, Mouse] = iSimulateSession(Mouse, Params, Cond, false);
	sessionMeanCue(:, iSess)  = Signals.ProcessMeanCue;
	sessionMeanRead(:, iSess) = Signals.ProcessMeanRead;
	h23(iSess) = iRestrictedStd(mean(sessionMeanCue(:,  1:iSess), 2, 'omitnan'));
	h5(iSess)  = iRestrictedStd(mean(sessionMeanRead(:, 1:iSess), 2, 'omitnan'));

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
	finalMeanCue  = mean(sessionMeanCue(:,  useIdx), 2, 'omitnan');
	finalMeanRead = mean(sessionMeanRead(:, useIdx), 2, 'omitnan');
	resultSlope = fitP(1);
	resultDeltaHit = mean(dh, 'omitnan');
	resultMeanH23 = iRestrictedStd(finalMeanCue);
	resultMeanH5  = iRestrictedStd(finalMeanRead);
elseif ~isempty(useIdx)
	finalMeanRead = mean(sessionMeanRead(:, useIdx), 2, 'omitnan');
	resultSlope = NaN;
	resultDeltaHit = NaN;
	resultMeanH23 = NaN;
	resultMeanH5 = NaN;
else
	finalMeanRead = nan(Params.NRead, 1);
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
Result.ProcessMeanL5 = finalMeanRead;
end

function [perf, Signals, perfExpected, Mouse] = iSimulateSession(Mouse, Params, Cond, usePreCue)
% Per-trial loop. Each trial has a decision phase (cue only, dual-pathway
% readout) followed by a learning phase (Cue/Rew/Read clamped to their
% fixed patterns). Hebbian and inhibitory plasticity are applied AFTER
% EACH TRIAL so that within-session learning accumulates.
NT = Params.NumTrials;
if usePreCue
	cuePat = Mouse.PreCuePattern;
	cueGain = Params.CueInputGainPretrain;
else
	cuePat = Mouse.CuePattern;
	cueGain = Params.CueInputGain;
end
hebbGate = 0.20 + 0.80 * Cond.THPlasticityLevel;
eta = Params.HebbRate * Mouse.HeteroGain * hebbGate;

% Storage for session-level diagnostics.
rCue_cue_all  = zeros(Params.NCue,  NT);
rCue_base_all = zeros(Params.NCue,  NT);
rRead_cue_all = zeros(Params.NRead, NT);
rRead_base_all= zeros(Params.NRead, NT);
rCue_L_all    = zeros(Params.NCue,  NT);
rRew_L_all    = zeros(Params.NRew,  NT);
rRead_L_all   = zeros(Params.NRead, NT);
isHit = false(1, NT);

% Activity accumulators for inhibitory plasticity (per-E-cell).
actCueSum = zeros(Params.NCue, 1);
actRewSum = zeros(Params.NRew, 1);
actNorm = 0;

for t = 1:NT
	% ===== Decision phase (cue only) =====
	preCue_cue  = cueGain              * cuePat             + Params.NoiseCue * randn(Params.NCue, 1);
	preCue_base = Params.BaseInputGain * Mouse.BasePattern  + Params.NoiseCue * randn(Params.NCue, 1);
	rCue_cue  = iRunArea(preCue_cue,  'cue', Mouse, Params, Cond);
	rCue_base = iRunArea(preCue_base, 'cue', Mouse, Params, Cond);
	% Indirect route: cue -> Rew area.
	preRew_indCue  = (Mouse.W_CueToRew * rCue_cue)  / Params.NCue + Params.NoiseRew * randn(Params.NRew, 1);
	preRew_indBase = (Mouse.W_CueToRew * rCue_base) / Params.NCue + Params.NoiseRew * randn(Params.NRew, 1);
	rRew_indCue  = iRunArea(preRew_indCue,  'rew', Mouse, Params, Cond);
	rRew_indBase = iRunArea(preRew_indBase, 'rew', Mouse, Params, Cond);
	% Readout = direct + indirect.
	preRead_cue  = (Mouse.W_CueToRead * rCue_cue)  / Params.NCue + (Mouse.W_RewToRead * rRew_indCue)  / Params.NRew + Params.NoiseRead * randn(Params.NRead, 1);
	preRead_base = (Mouse.W_CueToRead * rCue_base) / Params.NCue + (Mouse.W_RewToRead * rRew_indBase) / Params.NRew + Params.NoiseRead * randn(Params.NRead, 1);
	rRead_cue  = iRunArea(preRead_cue,  'read', Mouse, Params, Cond);
	rRead_base = iRunArea(preRead_base, 'read', Mouse, Params, Cond);

	decCue  = mean(Mouse.ReadoutPattern .* rRead_cue);
	decBase = mean(Mouse.ReadoutPattern .* rRead_base);
	decision = decCue - Params.BaselinePenalty * decBase;
	isHit(t) = decision >= Params.HitThreshold;

	% ===== Learning phase (all three populations clamped) =====
	preCue_L  = cueGain              * cuePat              + Params.NoiseCue  * randn(Params.NCue,  1);
	preRew_L  = Params.RewInputGain  * Mouse.RewardPattern + Params.NoiseRew  * randn(Params.NRew,  1);
	preRead_L = Params.ReadInputGain * Mouse.ReadoutPattern+ Params.NoiseRead * randn(Params.NRead, 1);
	rCue_L  = iRunArea(preCue_L,  'cue',  Mouse, Params, Cond);
	rRew_L  = iRunArea(preRew_L,  'rew',  Mouse, Params, Cond);
	rRead_L = iRunArea(preRead_L, 'read', Mouse, Params, Cond);

	% Per-trial Hebbian updates on all six E-E pathways.
	Mouse.W_CueToRew  = iHebb(Mouse.W_CueToRew,  rRew_L,  rCue_L,  eta, Params.WCap);
	Mouse.W_RewToCue  = iHebb(Mouse.W_RewToCue,  rCue_L,  rRew_L,  eta, Params.WCap);
	Mouse.W_CueToRead = iHebb(Mouse.W_CueToRead, rRead_L, rCue_L,  eta, Params.WCap);
	Mouse.W_ReadToCue = iHebb(Mouse.W_ReadToCue, rCue_L,  rRead_L, eta, Params.WCap);
	Mouse.W_RewToRead = iHebb(Mouse.W_RewToRead, rRead_L, rRew_L,  eta, Params.WCap);
	Mouse.W_ReadToRew = iHebb(Mouse.W_ReadToRew, rRew_L,  rRead_L, eta, Params.WCap);

	% Per-trial inhibitory plasticity (per-E-cell gain homeostasis).
	actCueTrial = (rCue_cue + rCue_base + rCue_L) / 3;
	actRewTrial = (rRew_indCue + rRew_indBase + rRew_L) / 3;
	Mouse.InhGainCue = iClamp(Mouse.InhGainCue + Params.InhPlasticityRate * (actCueTrial - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
	Mouse.InhGainRew = iClamp(Mouse.InhGainRew + Params.InhPlasticityRate * (actRewTrial - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);

	actCueSum = actCueSum + actCueTrial;
	actRewSum = actRewSum + actRewTrial;
	actNorm = actNorm + 1;

	rCue_cue_all(:, t)   = rCue_cue;
	rCue_base_all(:, t)  = rCue_base;
	rRead_cue_all(:, t)  = rRead_cue;
	rRead_base_all(:, t) = rRead_base;
	rCue_L_all(:, t)  = rCue_L;
	rRew_L_all(:, t)  = rRew_L;
	rRead_L_all(:, t) = rRead_L;
end

perf = mean(isHit);
% Kept for interface compatibility with pretraining logic. With hard-
% threshold decisions and no extra Bernoulli sampling, expected and
% observed session hit rates are identical under the realized noise.
perfExpected = perf;

Signals.mCue  = mean(rCue_L_all,  2);
Signals.mRew  = mean(rRew_L_all,  2);
Signals.mRead = mean(rRead_L_all, 2);
Signals.ProcessMeanCue  = mean(rCue_cue_all  - rCue_base_all,  2, 'omitnan');
Signals.ProcessMeanRead = mean(rRead_cue_all - rRead_base_all, 2, 'omitnan');
end

function rE = iRunArea(pre, areaSpec, Mouse, Params, Cond)
switch areaSpec
case 'cue'
	WIE = Mouse.WIE_Cue; WEI = Mouse.WEI_Cue; InhGain = Mouse.InhGainCue;
	THToI = Mouse.THToICue; NI = Params.NICue; NE = Params.NCue; Comp = Params.Comp_Cue;
case 'rew'
	WIE = Mouse.WIE_Rew; WEI = Mouse.WEI_Rew; InhGain = Mouse.InhGainRew;
	THToI = Mouse.THToIRew; NI = Params.NIRew; NE = Params.NRew; Comp = Params.Comp_Rew;
case 'read'
	% Readout area: no plastic I-pool in this simplified model.
	rE = Params.ResponseScale * tanh(pre);
	return;
end
exc = max(pre, 0);
inhI = max(0, WIE * exc / NE + Cond.THNetworkLevel * THToI + Params.NoiseI * randn(NI, size(pre, 2)));
inhI = inhI - mean(inhI, 1);
rE = Params.ResponseScale * tanh(pre - Comp * InhGain .* (WEI * inhI) / NI);
end

function Mouse = iApplyHebbianUpdates(Mouse, Params, Signals, hebbGate)
eta = Params.HebbRate * Mouse.HeteroGain * hebbGate;
Mouse.W_CueToRew  = iHebb(Mouse.W_CueToRew,  Signals.mRew,  Signals.mCue,  eta, Params.WCap);
Mouse.W_RewToCue  = iHebb(Mouse.W_RewToCue,  Signals.mCue,  Signals.mRew,  eta, Params.WCap);
Mouse.W_CueToRead = iHebb(Mouse.W_CueToRead, Signals.mRead, Signals.mCue,  eta, Params.WCap);
Mouse.W_ReadToCue = iHebb(Mouse.W_ReadToCue, Signals.mCue,  Signals.mRead, eta, Params.WCap);
Mouse.W_RewToRead = iHebb(Mouse.W_RewToRead, Signals.mRead, Signals.mRew,  eta, Params.WCap);
Mouse.W_ReadToRew = iHebb(Mouse.W_ReadToRew, Signals.mRew,  Signals.mRead, eta, Params.WCap);
end

function W = iHebb(W, post, pre, eta, cap)
W = W + eta * (post * pre');
W = max(min(W, cap), -cap);
end

function Mouse = iApplyInhibitoryPlasticity(Mouse, Params, SessionStats)
Mouse.InhGainCue = iClamp(Mouse.InhGainCue + Params.InhPlasticityRate * (SessionStats.ActLevelCue - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
Mouse.InhGainRew = iClamp(Mouse.InhGainRew + Params.InhPlasticityRate * (SessionStats.ActLevelRew - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
end

function Mouse = iOvernightConsolidate(Mouse, Params)
ret = Params.OvernightRetention;
sd = Params.OvernightNoise;
Mouse.W_CueToRew  = ret * Mouse.W_CueToRew  + sd * randn(size(Mouse.W_CueToRew));
Mouse.W_RewToCue  = ret * Mouse.W_RewToCue  + sd * randn(size(Mouse.W_RewToCue));
Mouse.W_CueToRead = ret * Mouse.W_CueToRead + sd * randn(size(Mouse.W_CueToRead));
Mouse.W_ReadToCue = ret * Mouse.W_ReadToCue + sd * randn(size(Mouse.W_ReadToCue));
Mouse.W_RewToRead = ret * Mouse.W_RewToRead + sd * randn(size(Mouse.W_RewToRead));
Mouse.W_ReadToRew = ret * Mouse.W_ReadToRew + sd * randn(size(Mouse.W_ReadToRew));
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