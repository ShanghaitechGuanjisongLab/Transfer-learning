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

rng(20260330, 'twister');

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
	rewardReadoutDrive = Summary.PerMouse.(name).RewardReadoutFinal;
	fprintf('%s: first-session hit = %.3f, last-session hit = %.3f\n', name, mean(perf(:, 1), 'omitnan'), mean(perf(:, end), 'omitnan'));
	fprintf('%s: mean process L2/3 heterogeneity = %.3f, mean process L5 heterogeneity = %.3f\n', name, mean(Summary.PerMouse.(name).MeanH23, 'omitnan'), mean(Summary.PerMouse.(name).MeanH5, 'omitnan'));
	fprintf('%s: mean slope = %.3f, mean DeltaHit = %.3f\n', name, mean(slope, 'omitnan'), mean(dh, 'omitnan'));
	fprintf('%s: mean reward-to-readout drive = %.3f, below decision threshold = %d/%d\n', name, mean(rewardReadoutDrive, 'omitnan'), sum(rewardReadoutDrive < Params.HitThreshold | ~isfinite(rewardReadoutDrive)), numel(rewardReadoutDrive));
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
% Cue/reward inputs plus three modeled cortical populations:
%   CueIn    (sensory cue input vector, not counted as L2/3 activity)
%   L23      (L2/3 population receiving CueIn through a plastic afferent map)
%   Reward   (reward input cells, independent from L5)
%   L5RewardRecv (L5 cells receiving L2/3 and Reward input)
%   L5Read   (L5 behavioural readout cells; no plastic I-pool)
% One plastic E-E matrix spans all L2/3 and L5 cells. It is structurally
% all-to-all except for the diagonal self-projections.
% Decision phase uses sensory cue input only; L2/3 receives this input,
% then all L2/3/L5 populations settle through the recurrent internal
% projection. During learning, reward and readout feedback are added to the
% settled cue-decision network state; Reward input drives L5RewardRecv through
% a plastic afferent map, and readout drive remains a one-way input to L5Read.
% Learning phase applies outer-product Hebbian updates on cue-to-L2/3,
% reward-to-L5RewardRecv, and recurrent internal matrices plus the per-cell
% inhibitory gain in L23/L5RewardRecv areas.
Params.NumMice = 20;
Params.NumSessions = 8;
Params.NumTrials = 30;
Params.NCueInput = 96;
Params.NL23 = 96;
Params.NReward = 64;
Params.NL5Read = 64;
Params.NL5RewardRecv = 2 * Params.NL5Read;
Params.NL5 = Params.NL5RewardRecv + Params.NL5Read;
Params.NL23L5 = Params.NL23 + Params.NL5;
Params.NIL23 = 24;
Params.NIL5RewardRecv = 16;
Params.ResponseScale = 1.45;
Params.NoiseCue = 0.70;             % input + L2/3 pre-noise together roughly match cue signal scale
Params.NoiseRew = 0.15;
Params.NoiseRead = 0.12;
Params.Comp_Cue = 0.95;
Params.Comp_Rew = 1.00;
% Input gains
Params.CueInputGain = 1.00;          % sensory cue drive (decision + learning)
Params.CueInputGainPretrain = 1.40;  % pretraining cue gain
Params.RewInputGain = 1.45;          % reward pattern clamp amplitude (learning phase only)
Params.ReadInputGain = 1.45;         % readout pattern clamp amplitude (learning phase only)
% Decision readout: initial input noise creates trial-to-trial variability,
% and a hit is emitted when the readout crosses HitThreshold.
Params.HitThreshold = 0.35;
Params.Ceiling = 1.00;
% Slope fit: drop sessions from the first 100%-hit session onward
% (that session and every subsequent one) so the plateau at 1.0 does
% not compress the slope of fast learners.
Params.SlopeHitPerfect = 1.00;
% Plastic weights: zero-mean init, symmetric caps.
Params.InitWStd = 0.03;
Params.WCap = 1.20;
Params.AfferentWCap = 1.20;
Params.RewardAfferentNorm = 1.00;
% Number of recurrent internal passes after external cue/reward/readout drive.
Params.InternalRecurrentPasses = 2;
% Per-trial Hebbian rate. With NumTrials=30 per session, total within-
% session increase ≈ 30 * HebbRate * eta_factors.
Params.HebbRate = 0.0025;
% Inhibitory plasticity (per-E-cell gain, Vogels-Sprekeler style, per-trial).
Params.InhPlasticityRate = 0.002;
Params.InhTargetAct = 0.00;
Params.InhGainMin = 0.20;
Params.InhGainMax = 3.00;
% Cross-modality overlap between pretraining cue input (e.g. sound) and new
% cue input (e.g. light). Real sensory drives are never fully orthogonal;
% each cue-input dimension has a shared component plus a modality-unique
% component. The fixed CueIn->L23 map turns this sensory overlap into
% partially overlapping L2/3 responses.
% Correlation between CueInputPattern and PreCueInputPattern = CueModalityCorr.
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
Cond.RewardInputLevel = [1.00; 1.00; 0.00];
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
AllRewardReadoutPretrain = [];
AllRewardReadoutFinal = [];
AllCond = strings(0, 1);

for iCond = 1:height(Cond)
	perf = nan(Params.NumMice, Params.NumSessions);
	h23 = nan(Params.NumMice, Params.NumSessions);
	h5 = nan(Params.NumMice, Params.NumSessions);
	perMouse = table('Size', [Params.NumMice, 6], 'VariableTypes', {'double','double','double','double','double','double'}, ...
		'VariableNames', {'Slope','MeanDeltaHit','MeanH23','MeanH5','RewardReadoutPretrain','RewardReadoutFinal'});
	repProcessL5 = cell(Params.NumMice, 1);
	for iMouse = 1:Params.NumMice
		Mouse = iDrawMouse(Params);
		rewardReadoutPretrain = NaN;
		if Cond.Name(iCond) ~= "Naive"
			% Pretraining shapes afferent/internal matrices + inhibitory gains.
			% No artificial pruning on task switch: the same M2 L2/3 and L5
			% populations carry both modalities, so synapses are fully inherited.
			% The "transfer advantage" emerges naturally because
			% (i) CueInputPattern and PreCueInputPattern share sensory input dimensions
			%     (cross-modal correlation = Params.CueModalityCorr), and
			% (ii) the all-to-all L2/3-L5 recurrent matrix encodes a task schema that is
			%     common to both cues.
			% OvernightRetention already models the small natural drift
			% between pretraining and the new task.
			Mouse = iPretrainMouse(Mouse, Params);
			rewardReadoutPretrain = iRewardReadoutProbe(Mouse, Params, iFullRewardCondition());
		end
		[MouseResult, Mouse] = iSimulateMouse(Mouse, Params, Cond(iCond, :));
		perf(iMouse, :) = MouseResult.Performance;
		h23(iMouse, :) = MouseResult.H23;
		h5(iMouse, :) = MouseResult.H5;
		perMouse.Slope(iMouse) = MouseResult.Slope;
		perMouse.MeanDeltaHit(iMouse) = MouseResult.MeanDeltaHit;
		perMouse.MeanH23(iMouse) = MouseResult.MeanH23;
		perMouse.MeanH5(iMouse) = MouseResult.MeanH5;
		perMouse.RewardReadoutPretrain(iMouse) = rewardReadoutPretrain;
		perMouse.RewardReadoutFinal(iMouse) = iRewardReadoutProbe(Mouse, Params, Cond(iCond, :));
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
	AllRewardReadoutPretrain = [AllRewardReadoutPretrain; perMouse.RewardReadoutPretrain]; %#ok<AGROW>
	AllRewardReadoutFinal = [AllRewardReadoutFinal; perMouse.RewardReadoutFinal]; %#ok<AGROW>
	AllCond = [AllCond; repmat(Cond.Name(iCond), Params.NumMice, 1)]; %#ok<AGROW>
end

Summary.AllMouse = table(AllCond, AllSlope, AllH23, AllH5, AllRewardReadoutPretrain, AllRewardReadoutFinal, ...
	'VariableNames', {'Condition','Slope','MeanH23','MeanH5','RewardReadoutPretrain','RewardReadoutFinal'});
Summary.CorrMouse = Summary.AllMouse;
end

function Mouse = iDrawMouse(Params)
% Fixed input / target patterns (zero-mean, unit-std).
% PreCueInput and CueInput share a common component (cross-modal correlation a) so
% that a fraction of sensory input dimensions drive both modalities.
a = Params.CueModalityCorr;
sharedCue = iStandardize(randn(Params.NCueInput, 1));
preCueU   = iStandardize(randn(Params.NCueInput, 1));
cueU      = iStandardize(randn(Params.NCueInput, 1));
Mouse.PreCueInputPattern = iStandardize(a * sharedCue + sqrt(1 - a^2) * preCueU);
Mouse.CueInputPattern    = iStandardize(a * sharedCue + sqrt(1 - a^2) * cueU);
Mouse.RewardPattern      = iStandardize(randn(Params.NReward, 1) + 0.55 * sign(randn(Params.NReward, 1)));
Mouse.L5ReadoutPattern   = iStandardize(randn(Params.NL5Read, 1)   + 0.55 * sign(randn(Params.NL5Read, 1)));

% Initial sensory afferent map. Cue input is not the L2/3 code itself;
% L2/3 activity is generated by this mouse-specific plastic projection.
Mouse.W_CueInputToL23 = randn(Params.NL23, Params.NCueInput) / sqrt(Params.NCueInput);
% Initial reward afferent map into L5 reward-receiving cells.
Mouse.W_RewardToL5RewardRecv = randn(Params.NL5RewardRecv, Params.NReward) / sqrt(Params.NReward);

% Plastic internal E-E matrix, W(post, pre). Every L2/3 or L5 cell projects
% to every other L2/3/L5 cell; the diagonal is fixed at zero.
sd = Params.InitWStd;
Mouse.W_L23L5ToL23L5 = iZeroSelfProjection(sd * randn(Params.NL23L5, Params.NL23L5));

% Inhibitory pools in L2/3 / L5RewardRecv areas (plastic via per-E-cell gain).
Mouse.WIE_L23 = abs(0.72 + 0.20 * randn(Params.NIL23, Params.NL23));
Mouse.WEI_L23 = abs(0.88 + 0.26 * randn(Params.NL23,  Params.NIL23));
Mouse.WIE_L5RewardRecv = abs(0.72 + 0.20 * randn(Params.NIL5RewardRecv, Params.NL5RewardRecv));
Mouse.WEI_L5RewardRecv = abs(0.88 + 0.26 * randn(Params.NL5RewardRecv,  Params.NIL5RewardRecv));
Mouse.InhGainL23 = ones(Params.NL23, 1);
Mouse.InhGainL5RewardRecv = ones(Params.NL5RewardRecv, 1);

end

function Mouse = iPretrainMouse(Mouse, Params)
% Pretraining uses PreCueInputPattern and keeps reward input intact.
pretrainCond.RewardInputLevel = 1.00;
lastPerfExpected = NaN;
postCeilingCount = 0;

for iSess = 1:Params.MaxPretrainSessions
	[perfObserved, ~, perfExpected, Mouse] = iSimulateSession(Mouse, Params, pretrainCond, true);
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

function Cond = iFullRewardCondition()
Cond.RewardInputLevel = 1.00;
end

function readoutDrive = iRewardReadoutProbe(Mouse, Params, Cond)
ProbeParams = Params;
ProbeParams.NoiseCue = 0;
ProbeParams.NoiseRew = 0;
ProbeParams.NoiseRead = 0;

preL23 = zeros(ProbeParams.NL23, 1);
preReward = Cond.RewardInputLevel * ProbeParams.RewInputGain * Mouse.RewardPattern;
rReward = iRunArea(preReward, 'reward', Mouse, ProbeParams);
preL5RewardRecv = (Mouse.W_RewardToL5RewardRecv * rReward) / ProbeParams.RewardAfferentNorm;
preL5Read = zeros(ProbeParams.NL5Read, 1);
[~, ~, rL5Read] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, ProbeParams);
readoutDrive = mean(Mouse.L5ReadoutPattern .* rL5Read, 'omitnan');
end

function [Result, Mouse] = iSimulateMouse(Mouse, Params, Cond)
perf = nan(1, Params.NumSessions);
h23 = nan(1, Params.NumSessions);
h5 = nan(1, Params.NumSessions);
sessionMeanL23 = nan(Params.NL23, Params.NumSessions);
sessionMeanL5  = nan(Params.NL5,  Params.NumSessions);

for iSess = 1:Params.NumSessions
	[perf(iSess), Signals, ~, Mouse] = iSimulateSession(Mouse, Params, Cond, false);
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
end

function [perf, Signals, perfExpected, Mouse] = iSimulateSession(Mouse, Params, Cond, usePreCue)
% Per-trial loop. Each trial has a decision phase (cue input -> L2/3 -> L5)
% followed by a learning phase that continues from the settled cue-decision
% state while adding Reward input to the L5 reward-receiving group. Hebbian
% and inhibitory plasticity are applied AFTER EACH TRIAL so that within-session
% learning accumulates.
NT = Params.NumTrials;

if usePreCue
	cueInputPat = Mouse.PreCueInputPattern;
	cueGain = Params.CueInputGainPretrain;
else
	cueInputPat = Mouse.CueInputPattern;
	cueGain = Params.CueInputGain;
end
rewardInputLevel = Cond.RewardInputLevel;
eta = Params.HebbRate;

% Storage for session-level diagnostics.
rL23_cue_all = zeros(Params.NL23, NT);
rL5RewardRecv_cue_all = zeros(Params.NL5RewardRecv, NT);
rL5Read_cue_all = zeros(Params.NL5Read, NT);
rL23_L_all = zeros(Params.NL23, NT);
rReward_L_all = zeros(Params.NReward, NT);
rL5RewardRecv_L_all = zeros(Params.NL5RewardRecv, NT);
rL5Read_L_all = zeros(Params.NL5Read, NT);
isHit = false(1, NT);

for t = 1:NT
	% ===== Decision phase (cue input -> recurrent L2/3-L5 network) =====
	cueInput_cue  = cueGain              * cueInputPat            + Params.NoiseCue * randn(Params.NCueInput, 1);
	preL23_cue  = Mouse.W_CueInputToL23 * cueInput_cue  + Params.NoiseCue * randn(Params.NL23, 1);
	preL5RewardRecv_cue = Params.NoiseRew * randn(Params.NL5RewardRecv, 1);
	preL5Read_cue = Params.NoiseRead * randn(Params.NL5Read, 1);
	[rL23_cue, rL5RewardRecv_cue, rL5Read_cue, decisionActivityCue] = iRunInternalNetwork(preL23_cue, preL5RewardRecv_cue, preL5Read_cue, Mouse, Params);

	decCue  = mean(Mouse.L5ReadoutPattern .* rL5Read_cue);
	decision = decCue;
	isHit(t) = decision >= Params.HitThreshold;

	% ===== Learning phase (reward/readout feedback continues from cue-decision state) =====
	cueInput_L = cueInput_cue;
	preL23_L = preL23_cue;
	if rewardInputLevel > 0
		preReward_L = rewardInputLevel * Params.RewInputGain * Mouse.RewardPattern + Params.NoiseRew * randn(Params.NReward, 1);
		rReward_L = iRunArea(preReward_L, 'reward', Mouse, Params);
	else
		rReward_L = zeros(Params.NReward, 1);
	end
	preL5RewardRecv_L = (Mouse.W_RewardToL5RewardRecv * rReward_L) / Params.RewardAfferentNorm + Params.NoiseRew * randn(Params.NL5RewardRecv, 1);
	preL5Read_L = Params.ReadInputGain * Mouse.L5ReadoutPattern + Params.NoiseRead * randn(Params.NL5Read, 1);
	[rL23_L, rL5RewardRecv_L, rL5Read_L] = iContinueInternalNetwork(preL23_L, preL5RewardRecv_L, preL5Read_L, decisionActivityCue, Mouse, Params);

	% Per-trial Hebbian updates on learned afferent maps and the recurrent L2/3-L5 matrix.
	Mouse.W_CueInputToL23 = iHebbAfferent(Mouse.W_CueInputToL23, rL23_L, cueInput_L, eta, Params.AfferentWCap);
	Mouse.W_RewardToL5RewardRecv = iHebbAfferent(Mouse.W_RewardToL5RewardRecv, rL5RewardRecv_L, rReward_L, eta, Params.AfferentWCap);
	internalActivity_L = [rL23_L; rL5RewardRecv_L; rL5Read_L];
	Mouse.W_L23L5ToL23L5 = iHebbNoSelf(Mouse.W_L23L5ToL23L5, internalActivity_L, eta, Params.WCap);

	% Per-trial inhibitory plasticity (per-E-cell gain homeostasis).
	actL23Trial = (rL23_cue + rL23_L) / 2;
	actL5RewardRecvTrial = (rL5RewardRecv_cue + rL5RewardRecv_L) / 2;
	Mouse.InhGainL23 = iClamp(Mouse.InhGainL23 + Params.InhPlasticityRate * (actL23Trial - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
	Mouse.InhGainL5RewardRecv = iClamp(Mouse.InhGainL5RewardRecv + Params.InhPlasticityRate * (actL5RewardRecvTrial - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);

	% ===== Closed-loop noise Hebbian learning =====
	% Test a fresh random-noise cue. If it falsely activates the behavioural
	% readout, silence L5Read cells and train on that noise cue; then test a
	% new random-noise cue. Continue until one random cue fails to activate.
	while true
		cueInput_BL = cueGain * iStandardize(randn(Params.NCueInput, 1)) + Params.NoiseCue * randn(Params.NCueInput, 1);
		preL23_BLTest = Mouse.W_CueInputToL23 * cueInput_BL + Params.NoiseCue * randn(Params.NL23, 1);
		preL5RewardRecv_BLTest = Params.NoiseRew * randn(Params.NL5RewardRecv, 1);
		preL5Read_BLTest = Params.NoiseRead * randn(Params.NL5Read, 1);
		[~, ~, rL5Read_BLTest] = iRunInternalNetwork(preL23_BLTest, preL5RewardRecv_BLTest, preL5Read_BLTest, Mouse, Params);

		decCue_BL = mean(Mouse.L5ReadoutPattern .* rL5Read_BLTest);
		if decCue_BL < Params.HitThreshold
			break;
		end

		preL23_BL = Mouse.W_CueInputToL23 * cueInput_BL + Params.NoiseCue * randn(Params.NL23, 1);
		if rewardInputLevel > 0
			preReward_BL = Params.NoiseRew * randn(Params.NReward, 1);
			rReward_BL = iRunArea(preReward_BL, 'reward', Mouse, Params);
		else
			rReward_BL = zeros(Params.NReward, 1);
		end
		preL5RewardRecv_BL = (Mouse.W_RewardToL5RewardRecv * rReward_BL) / Params.RewardAfferentNorm + Params.NoiseRew * randn(Params.NL5RewardRecv, 1);
		preL5Read_BL = zeros(Params.NL5Read, 1);
		[rL23_BL, rL5RewardRecv_BL, rL5Read_BL] = iRunInternalNetworkReadoutSilent(preL23_BL, preL5RewardRecv_BL, preL5Read_BL, Mouse, Params);

		Mouse.W_CueInputToL23 = iHebbAfferent(Mouse.W_CueInputToL23, rL23_BL, cueInput_BL, eta, Params.AfferentWCap);
		Mouse.W_RewardToL5RewardRecv = iHebbAfferent(Mouse.W_RewardToL5RewardRecv, rL5RewardRecv_BL, rReward_BL, eta, Params.AfferentWCap);
		internalActivity_BL = [rL23_BL; rL5RewardRecv_BL; rL5Read_BL];
		Mouse.W_L23L5ToL23L5 = iHebbNoSelf(Mouse.W_L23L5ToL23L5, internalActivity_BL, eta, Params.WCap);

		Mouse.InhGainL23 = iClamp(Mouse.InhGainL23 + Params.InhPlasticityRate * (rL23_BL - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
		Mouse.InhGainL5RewardRecv = iClamp(Mouse.InhGainL5RewardRecv + Params.InhPlasticityRate * (rL5RewardRecv_BL - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
	end

	rL23_cue_all(:, t) = rL23_cue;
	rL5RewardRecv_cue_all(:, t) = rL5RewardRecv_cue;
	rL5Read_cue_all(:, t) = rL5Read_cue;
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

Signals.mL23 = mean(rL23_L_all, 2);
Signals.mReward = mean(rReward_L_all, 2);
Signals.mL5RewardRecv = mean(rL5RewardRecv_L_all, 2);
Signals.mL5Read = mean(rL5Read_L_all, 2);
Signals.ProcessMeanL23 = mean(rL23_cue_all, 2, 'omitnan');
processMeanL5RewardRecv = mean(rL5RewardRecv_cue_all, 2, 'omitnan');
processMeanL5Read = mean(rL5Read_cue_all, 2, 'omitnan');
Signals.ProcessMeanL5 = [processMeanL5RewardRecv; processMeanL5Read];
end

function rE = iRunArea(pre, areaSpec, Mouse, Params)
switch areaSpec
case 'l23'
	WIE = Mouse.WIE_L23; WEI = Mouse.WEI_L23; InhGain = Mouse.InhGainL23;
	NI = Params.NIL23; NE = Params.NL23; Comp = Params.Comp_Cue;
case 'reward'
	% Reward cells are modeled as an independent input population.
	rE = Params.ResponseScale * tanh(pre);
	return;
case 'l5rewardrecv'
	WIE = Mouse.WIE_L5RewardRecv; WEI = Mouse.WEI_L5RewardRecv; InhGain = Mouse.InhGainL5RewardRecv;
	NI = Params.NIL5RewardRecv; NE = Params.NL5RewardRecv; Comp = Params.Comp_Rew;
case 'l5read'
	% L5 readout subclass: no plastic I-pool in this simplified model.
	rE = Params.ResponseScale * tanh(pre);
	return;
end
exc = max(pre, 0);
inhI = max(0, WIE * exc / NE);
inhI = inhI - mean(inhI, 1);
rE = Params.ResponseScale * tanh(pre - Comp * InhGain .* (WEI * inhI) / NI);
end

function [rL23, rL5RewardRecv, rL5Read, internalActivity] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, Params)
externalPre = [preL23; preL5RewardRecv; preL5Read];
internalActivity = iRunInternalAreas(externalPre, Mouse, Params);
for iPass = 1:Params.InternalRecurrentPasses
	recurrentPre = externalPre + (Mouse.W_L23L5ToL23L5 * internalActivity) / Params.NL23L5;
	internalActivity = iRunInternalAreas(recurrentPre, Mouse, Params);
end
[rL23, rL5RewardRecv, rL5Read] = iSplitInternalActivity(internalActivity, Params);
end

function [rL23, rL5RewardRecv, rL5Read] = iContinueInternalNetwork(preL23, preL5RewardRecv, preL5Read, initialActivity, Mouse, Params)
externalPre = [preL23; preL5RewardRecv; preL5Read];
internalActivity = initialActivity;
for iPass = 1:Params.InternalRecurrentPasses
	recurrentPre = externalPre + (Mouse.W_L23L5ToL23L5 * internalActivity) / Params.NL23L5;
	internalActivity = iRunInternalAreas(recurrentPre, Mouse, Params);
end
[rL23, rL5RewardRecv, rL5Read] = iSplitInternalActivity(internalActivity, Params);
end

function [rL23, rL5RewardRecv, rL5Read] = iRunInternalNetworkReadoutSilent(preL23, preL5RewardRecv, preL5Read, Mouse, Params)
externalPre = [preL23; preL5RewardRecv; preL5Read];
internalActivity = iRunInternalAreasReadoutSilent(externalPre, Mouse, Params);
for iPass = 1:Params.InternalRecurrentPasses
	recurrentPre = externalPre + (Mouse.W_L23L5ToL23L5 * internalActivity) / Params.NL23L5;
	internalActivity = iRunInternalAreasReadoutSilent(recurrentPre, Mouse, Params);
end
[rL23, rL5RewardRecv, rL5Read] = iSplitInternalActivity(internalActivity, Params);
end

function internalActivity = iRunInternalAreas(internalPre, Mouse, Params)
[preL23, preL5RewardRecv, preL5Read] = iSplitInternalActivity(internalPre, Params);
rL23 = iRunArea(preL23, 'l23', Mouse, Params);
rL5RewardRecv = iRunArea(preL5RewardRecv, 'l5rewardrecv', Mouse, Params);
rL5Read = iRunArea(preL5Read, 'l5read', Mouse, Params);
internalActivity = [rL23; rL5RewardRecv; rL5Read];
end

function internalActivity = iRunInternalAreasReadoutSilent(internalPre, Mouse, Params)
[preL23, preL5RewardRecv, ~] = iSplitInternalActivity(internalPre, Params);
rL23 = iRunArea(preL23, 'l23', Mouse, Params);
rL5RewardRecv = iRunArea(preL5RewardRecv, 'l5rewardrecv', Mouse, Params);
rL5Read = zeros(Params.NL5Read, size(internalPre, 2));
internalActivity = [rL23; rL5RewardRecv; rL5Read];
end

function [l23Part, l5RewardRecvPart, l5ReadPart] = iSplitInternalActivity(internalActivity, Params)
l23End = Params.NL23;
l5RewardRecvEnd = Params.NL23 + Params.NL5RewardRecv;
l23Part = internalActivity(1:l23End, :);
l5RewardRecvPart = internalActivity(l23End+1:l5RewardRecvEnd, :);
l5ReadPart = internalActivity(l5RewardRecvEnd+1:end, :);
end

function Mouse = iApplyHebbianUpdates(Mouse, Params, Signals)
eta = Params.HebbRate;
internalActivity = [Signals.mL23; Signals.mL5RewardRecv; Signals.mL5Read];
Mouse.W_L23L5ToL23L5 = iHebbNoSelf(Mouse.W_L23L5ToL23L5, internalActivity, eta, Params.WCap);
end

function W = iHebb(W, post, pre, eta, cap)
W = W + eta * (post * pre');
W = max(min(W, cap), -cap);
end

function W = iHebbAfferent(W, post, pre, eta, cap)
W = iHebb(W, post, pre, eta / numel(pre), cap);
end

function recurrentWeights = iHebbNoSelf(recurrentWeights, activity, eta, cap)
recurrentWeights = iHebb(recurrentWeights, activity, activity, eta, cap);
recurrentWeights = iZeroSelfProjection(recurrentWeights);
end

function recurrentWeights = iZeroSelfProjection(recurrentWeights)
numCells = size(recurrentWeights, 1);
recurrentWeights(1:numCells+1:end) = 0;
end

function Mouse = iApplyInhibitoryPlasticity(Mouse, Params, SessionStats)
Mouse.InhGainL23 = iClamp(Mouse.InhGainL23 + Params.InhPlasticityRate * (SessionStats.ActLevelL23 - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
Mouse.InhGainL5RewardRecv = iClamp(Mouse.InhGainL5RewardRecv + Params.InhPlasticityRate * (SessionStats.ActLevelL5RewardRecv - Params.InhTargetAct), Params.InhGainMin, Params.InhGainMax);
end

function Mouse = iOvernightConsolidate(Mouse, Params)
ret = Params.OvernightRetention;
sd = Params.OvernightNoise;
Mouse.W_CueInputToL23 = ret * Mouse.W_CueInputToL23 + sd * randn(size(Mouse.W_CueInputToL23));
Mouse.W_RewardToL5RewardRecv = ret * Mouse.W_RewardToL5RewardRecv + sd * randn(size(Mouse.W_RewardToL5RewardRecv));
Mouse.W_L23L5ToL23L5 = iZeroSelfProjection(ret * Mouse.W_L23L5ToL23L5 + sd * randn(size(Mouse.W_L23L5ToL23L5)));
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