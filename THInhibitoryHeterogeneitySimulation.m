%{
调参提示：
提高信噪比比较干净的指标是：响应中点和斜率、可塑性资格残留、线索强度、抑制性突触预算总量。但是这些参数各自都存在效应瓶颈，通常不能指望调其中一个就解决问题。
直接提高学习速度的指标包括：命中阈值、兴奋性突触预算总量、HebbRate、StateCarryover。调这些指标提高学习速度最有效，但可能降低信噪比，导致基线压不下去或者Transfer首个训练单元成功率过高。此外，HebbRate和StateCarryover还可能遇到兴奋性输出总量不足的瓶颈。
因此你需要在调参过程中积极诊断，根据当前的核心瓶颈，选择正确的调参方向。
但是，信噪比过高又可能导致Transfer学不会。除此之外，两种线索差异过大、初始权重分布过于奇异也是一种可能原因。
%}
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
% - a TH-inhibited group implemented as unstructured reward-mode L5 input during the new task.

CheckpointEnabled = true;
ResumeFromCheckpoint = false;       % false starts a fresh run and overwrites this tag's checkpoint.
CheckpointTag = 'direct_th_mid100_slope8_cuegain50_prehebb600_formhebb270_state030_wcap500_inh10_th220_thnoise035_thr060_noise014_iter006_elig085_ret094_initscale082_fixedcue_precue017_cue018_ov008_i12'; % change this to keep separate checkpoint lines.
PrintCuePretrainDebug = false;     % prints cue-specific vs non-cue L2/3 learning trajectories each pretrain session.

rng('shuffle');
ParallelComputing.ParPool(7);
spmd
	if spmdIndex<=gpuDeviceCount
		gpuDevice(spmdIndex);
	end
end
networkOutputRoot = '\\Data-Server-2\个人数据\张天夫';
localOutputRoot = fullfile(fileparts(mfilename('fullpath')), 'resources');
if isfolder(networkOutputRoot)
	outDir = fullfile(networkOutputRoot, char(datetime('now', 'Format', 'yyyyMM')));
else
	outDir = fullfile(localOutputRoot, char(datetime('now', 'Format', 'yyyyMM')));
end
svgName = 'TH_Inhibitory_Heterogeneity_Model.svg';

Params = iDefaultParams();
Params.CheckpointEnabled = CheckpointEnabled;
Params.CheckpointResume = ResumeFromCheckpoint;
Params.CheckpointTag = CheckpointTag;
Params.PrintCuePretrainDebug = PrintCuePretrainDebug;
Cond = iConditionTable();

Summary = iRunCohortModel(Params, Cond);

fprintf('\n=== Simulated cohort summary ===\n');
for iCond = 1:height(Cond)
	name = Cond.Name(iCond);
	perf = Summary.Performance.(name);
	slope = Summary.PerMouse.(name).Slope;
	dh = Summary.PerMouse.(name).MeanDeltaHit;
	rewardReadoutSimilarity = Summary.PerMouse.(name).RewardReadoutFinal;
	fprintf('%s: first-session hit = %.3f, last-session hit = %.3f\n', name, mean(perf(:, 1), 'omitnan'), mean(perf(:, end), 'omitnan'));
	fprintf('%s: mean process L2/3 heterogeneity = %.3f, mean process L5 heterogeneity = %.3f\n', name, mean(Summary.PerMouse.(name).MeanH23, 'omitnan'), mean(Summary.PerMouse.(name).MeanH5, 'omitnan'));
	fprintf('%s: mean slope = %.3f, mean DeltaHit = %.3f\n', name, mean(slope, 'omitnan'), mean(dh, 'omitnan'));
	fprintf('%s: mean reward-to-readout similarity = %.3f, below decision threshold = %d/%d\n', name, mean(rewardReadoutSimilarity, 'omitnan'), sum(rewardReadoutSimilarity < Params.HitThreshold | ~isfinite(rewardReadoutSimilarity)), numel(rewardReadoutSimilarity));
end
[rhoL23, pL23] = corr(Summary.CorrMouse.MeanH23, Summary.CorrMouse.Slope, 'Type', 'Spearman', 'Rows', 'complete');
fprintf('Slope vs L2/3 heterogeneity: rho = %.3f, p = %.4g\n', rhoL23, pL23);

f = figure('Color', 'w', 'Name', 'TH inhibitory heterogeneity model');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

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
%   L5RewardRecv (L5 cells receiving L2/3 and direct TH input)
%   L5Read   (L5 behavioural readout cells; no plastic I-pool)
% One plastic E-E matrix spans all L2/3 and L5 cells. It is structurally
% all-to-all except for the diagonal self-projections.
% Decision phase directly drives cue-tagged L2/3 cells, then all L2/3/L5
% populations settle through the recurrent internal
% projection. Structured TH input is absent during baseline/decision and switches to
% reward mode during learning; TH input is directly added to L5RewardRecv,
% and readout drive remains a one-way input to L5Read.
% Learning phase applies outer-product Hebbian updates on the recurrent
% internal matrix plus the per-cell
% inhibitory gain in L23/L5RewardRecv areas.
Params.UseGPU = gpuDeviceCount > 0;
Params.NumMice = 7;
Params.NumSessions = 8;
Params.NumTrials = 30;
Params.NL23 = 96;
Params.NL5Read = 64;
Params.NL5RewardRecv = 2 * Params.NL5Read;
Params.NL5 = Params.NL5RewardRecv + Params.NL5Read;
Params.NL23L5 = Params.NL23 + Params.NL5;
Params.NIL23 = Params.NL23 / 4;
Params.NIL5RewardRecv = Params.NL5 / 4;
Params.NIInternal = Params.NIL23 + Params.NIL5RewardRecv;
Params.NInternal = Params.NL23L5 + Params.NIInternal;
Params.RateResponseSlope = 8.00;
Params.RateResponseMidpoint = 1.00;
Params.NoiseInput = 0.14;           % shared cue/reward input noise scale
Params.NoiseRead = 0.08;
Params.IterationNoise = 0.06;
Params.Comp_Cue = 0.95;
Params.Comp_Rew = 1.15;
% Input gains
Params.CueL23Gain = 5.00;           % shared direct L2/3 cue drive (pretraining + formal task)
Params.THRewardInputGain = 2.20;     % post-decision TH reward mode during learning phase
Params.THNoiseInputGain = 0.35;      % unstructured reward-mode TH input in the TH-inhibited group
Params.ReadInputGain = 1.45;         % readout pattern clamp amplitude (learning phase only)
% Decision readout: initial input noise creates trial-to-trial variability,
% and a hit is emitted when the readout pattern similarity crosses HitThreshold.
Params.HitThreshold = 0.60;
Params.Ceiling = 1.00;
Params.FirstCueTrainingNaiveMax = 0.40;
Params.FirstCueTrainingTransferMax = 0.80;
% Process-window summaries drop sessions from the first 100%-hit session onward;
% reported Slope is the sigmoid rate fitted with the Chinese Fig313A method.
Params.SlopeHitPerfect = 1.00;
% Plastic synaptic accumulators are nonnegative outgoing allocation pools.
% Each active upstream cell sends a fixed total output scale, distributed to
% downstream cells in proportion to the downstream accumulator values.
Params.WCap = 5.00;
Params.WeightMapSlope = 1.00;
Params.InitRecurrentAccumulatorChiSquareDof = 1;
Params.InitRecurrentAccumulatorScale = 0.82;
Params.InhOutputWCap = 10 * Params.WCap;
% Number of recurrent internal passes after external cue/reward/readout drive.
Params.InternalRecurrentPasses = 4;
Params.TeacherReadoutPasses = 5;
Params.StateCarryover = 0.30;       % fraction of previous internal state retained across recurrent passes
% Stage-specific per-trial Hebbian learning rates. Pretraining remains faster
% than formal cue learning so the schema forms without making the first formal
% cue-training unit too high.
Params.HebbRate = 6.00;
Params.PretrainHebbRate = 6.00;
Params.FormalHebbRate = 2.70;
Params.BaselineQuietIterations = 40;
Params.MaxBaselineIterations = 500;
% Eligibility traces let current reward/readout feedback update recently
% experienced states; older states contribute less on each trial.
Params.EligibilityDecay = 0.85;
Params.EligibilityTraceScale = 1.00;
% Inhibitory plasticity (per-E-cell gain, Vogels-Sprekeler style, per-trial).
Params.InhPlasticityRate = 0.002;
Params.InhTargetAct = 0.00;
Params.InhGainMin = 0.20;
Params.InhGainMax = 3.00;
% Cue-tagged L2/3 direct-drive fractions. Masks use fixed-count sampling so
% small cohorts do not receive extreme Bernoulli active-fraction draws.
Params.PreCueL23ActiveFraction = 0.17;
Params.CueL23ActiveFraction = 0.18;
Params.CueL23OverlapFractionOfPreCue = 0.08;
% Overnight consolidation
Params.OvernightRetention = 0.94;
Params.OvernightNoise = 0.002;
% Pretraining
Params.MaxPretrainSessions = 8;
Params.PostCeilingSessions = 1;
% Checkpoints save complete stage boundaries so a failed run can restart
% from the last intact training state while future sessions use current Params.
Params.CheckpointEnabled = true;
Params.CheckpointResume = true;
Params.CheckpointTag = 'default';
Params.CheckpointDir = fullfile(fileparts(mfilename('fullpath')), 'resources', 'checkpoints');
Params.CheckpointVersion = 2;
Params.PrintCuePretrainDebug = false;
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

function [RunState, didResume] = iLoadRunCheckpoint(Params, Cond)
RunState = struct();
didResume = false;
if ~iCheckpointResumeEnabled(Params)
	return;
end
checkpointPath = iCheckpointPath(Params);
if isfile(checkpointPath)
	checkpointData = load(checkpointPath, 'RunState');
	RunState = checkpointData.RunState;
	iAssertCheckpointCompatible(RunState, Params, Cond, checkpointPath);
	didResume = true;
	fprintf('Loaded checkpoint: %s (stage=%s; cue sessions=%d; formal sessions=%d). Future training uses current Params.\n', ...
		checkpointPath, char(RunState.Stage), RunState.CompletedCuePretrainSessions, RunState.CompletedFormalSessions);
end
end

function RunState = iSaveRunCheckpoint(RunState, Params, Cond)
if ~iCheckpointEnabled(Params)
	return;
end
checkpointPath = iCheckpointPath(Params);
checkpointDir = fileparts(checkpointPath);
if ~isfolder(checkpointDir)
	mkdir(checkpointDir);
end
RunState.CheckpointVersion = Params.CheckpointVersion;
RunState.Topology = iCheckpointTopology(Params, Cond);
RunState.ParamsSnapshot = Params;
RunState.SavedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
save(checkpointPath, 'RunState');
fprintf('Saved checkpoint: %s (stage=%s; cue sessions=%d; formal sessions=%d).\n', ...
	checkpointPath, char(RunState.Stage), RunState.CompletedCuePretrainSessions, RunState.CompletedFormalSessions);
end

function enabled = iCheckpointEnabled(Params)
enabled = isfield(Params, 'CheckpointEnabled') && Params.CheckpointEnabled;
end

function enabled = iCheckpointResumeEnabled(Params)
enabled = iCheckpointEnabled(Params) && isfield(Params, 'CheckpointResume') && Params.CheckpointResume;
end

function checkpointPath = iCheckpointPath(Params)
checkpointTag = Params.CheckpointTag;
if isstring(checkpointTag)
	checkpointTag = char(checkpointTag);
end
checkpointPath = fullfile(Params.CheckpointDir, sprintf('THInhibitoryHeterogeneitySimulation_%s.mat', checkpointTag));
end

function topology = iCheckpointTopology(Params, Cond)
topology.NumMice = Params.NumMice;
topology.NumSessions = Params.NumSessions;
topology.NumTrials = Params.NumTrials;
topology.NL23 = Params.NL23;
topology.NL5Read = Params.NL5Read;
topology.NL5RewardRecv = Params.NL5RewardRecv;
topology.NIL23 = Params.NIL23;
topology.NIL5RewardRecv = Params.NIL5RewardRecv;
topology.NInternal = Params.NInternal;
topology.MaxPretrainSessions = Params.MaxPretrainSessions;
topology.PostCeilingSessions = Params.PostCeilingSessions;
topology.ConditionName = cellstr(Cond.Name);
topology.ConditionTHInputIsNoise = Cond.THInputIsNoise;
end

function iAssertCheckpointCompatible(RunState, Params, Cond, checkpointPath)
if ~isfield(RunState, 'CheckpointVersion') || RunState.CheckpointVersion ~= Params.CheckpointVersion
	error('THModel:CheckpointVersionMismatch', 'Checkpoint %s uses a different checkpoint version. Set Params.CheckpointTag to a new value or disable resume for a fresh run.', checkpointPath);
end
if ~isfield(RunState, 'Topology') || ~isequaln(RunState.Topology, iCheckpointTopology(Params, Cond))
	error('THModel:CheckpointTopologyMismatch', 'Checkpoint %s is incompatible with the current model topology or stage limits. Set Params.CheckpointTag to a new value or disable resume for a fresh run.', checkpointPath);
end
end

function RunState = iInitializeRunState(Params, Cond)
nCond = height(Cond);
nMouse = Params.NumMice;
nSess = Params.NumSessions;
RunState = struct();
RunState.CheckpointVersion = Params.CheckpointVersion;
RunState.Topology = iCheckpointTopology(Params, Cond);
RunState.Stage = "new";
RunState.CompletedCuePretrainSessions = 0;
RunState.CuePretrainingComplete = false;
RunState.RewardProbeComplete = false;
RunState.CompletedFormalSessions = 0;
RunState.MousePool = cell(nCond, nMouse);
RunState.SessionMeanL23 = cell(nCond, nMouse);
RunState.SessionMeanL5 = cell(nCond, nMouse);
RunState.PerfAll = nan(nCond, nMouse, nSess);
RunState.H23All = nan(nCond, nMouse, nSess);
RunState.H5All = nan(nCond, nMouse, nSess);
RunState.RewardReadoutPretrainAll = nan(nCond, nMouse);
RunState.FormalTrainingDiagnostics = iEmptyFormalTrainingDiagnostics(nCond, nMouse, nSess);
RunState.CuePretrainState = iEmptyCuePretrainCheckpointState();
end

function RunState = iEnsureRunStateDiagnostics(RunState, Params, Cond)
if ~isfield(RunState, 'FormalTrainingDiagnostics') || isempty(RunState.FormalTrainingDiagnostics)
	RunState.FormalTrainingDiagnostics = iEmptyFormalTrainingDiagnostics(height(Cond), Params.NumMice, Params.NumSessions);
end
end

function formalDiagnostics = iEmptyFormalTrainingDiagnostics(nCond, nMouse, nSess)
template = nan(nCond, nMouse, nSess);
formalDiagnostics.DecisionDriveMean = template;
formalDiagnostics.DecisionDriveMax = template;
formalDiagnostics.BaselineFinalDriveMean = template;
formalDiagnostics.BaselineMaxDriveMean = template;
formalDiagnostics.CueCellCount = template;
formalDiagnostics.CueOverlapCount = template;
formalDiagnostics.CueTargetReadColumnSumMeanW = template;
formalDiagnostics.CueTargetReadColumnSumTotalW = template;
formalDiagnostics.PreCueTargetReadColumnSumMeanW = template;
formalDiagnostics.CueNewTargetReadColumnSumMeanW = template;
formalDiagnostics.CueOverlapTargetReadColumnSumMeanW = template;
formalDiagnostics.RewardRecvToTargetReadMeanW = template;
end

function formalDiagnostics = iRecordFormalTrainingDiagnostics(formalDiagnostics, sessionDiagnostics, taskCondIndex, taskMouseIndex, iSess)
fieldNames = fieldnames(formalDiagnostics);
for iTask = 1:numel(sessionDiagnostics)
	snapshot = sessionDiagnostics{iTask};
	for iField = 1:numel(fieldNames)
		fieldName = fieldNames{iField};
		formalDiagnostics.(fieldName)(taskCondIndex(iTask), taskMouseIndex(iTask), iSess) = snapshot.(fieldName);
	end
end
end

function snapshot = iFormalTrainingDiagnosticSnapshot(Mouse, Signals, Params)
preCueMask = iGatherValue(Mouse.PreCueL23Pattern(:) > 0);
cueMask = iGatherValue(Mouse.CueL23Pattern(:) > 0);
cueNewMask = cueMask & ~preCueMask;
cueOverlapMask = cueMask & preCueMask;
readPattern = iGatherValue(Mouse.L5ReadoutPattern(:));
readTargetMask = readPattern > 0;
readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
targetReadRows = readoutRows(readTargetMask);
l23ToTargetReadOutput = iGatherValue(sum(Mouse.W_InternalToInternal(targetReadRows, 1:Params.NL23), 1));
rewardRecvCols = Params.NL23 + (1:Params.NL5RewardRecv);
rewardRecvToTargetReadOutput = iGatherValue(sum(Mouse.W_InternalToInternal(targetReadRows, rewardRecvCols), 1));
snapshot.DecisionDriveMean = Signals.DecisionReadoutDriveMean;
snapshot.DecisionDriveMax = Signals.DecisionReadoutDriveMax;
snapshot.BaselineFinalDriveMean = Signals.BaselineFinalDriveMean;
snapshot.BaselineMaxDriveMean = Signals.BaselineMaxDriveMean;
snapshot.CueCellCount = nnz(cueMask);
snapshot.CueOverlapCount = nnz(cueOverlapMask);
snapshot.CueTargetReadColumnSumMeanW = iMeanFlat(l23ToTargetReadOutput(cueMask));
snapshot.CueTargetReadColumnSumTotalW = sum(l23ToTargetReadOutput(cueMask), 'omitnan');
snapshot.PreCueTargetReadColumnSumMeanW = iMeanFlat(l23ToTargetReadOutput(preCueMask));
snapshot.CueNewTargetReadColumnSumMeanW = iMeanFlat(l23ToTargetReadOutput(cueNewMask));
snapshot.CueOverlapTargetReadColumnSumMeanW = iMeanFlat(l23ToTargetReadOutput(cueOverlapMask));
snapshot.RewardRecvToTargetReadMeanW = iMeanFlat(rewardRecvToTargetReadOutput);
end

function cuePretrainState = iEmptyCuePretrainCheckpointState()
cuePretrainState.ActiveList = [];
cuePretrainState.StateCells = {};
cuePretrainState.CompletedSessions = 0;
end

function Summary = iRunCohortModel(Params, Cond)
Summary.Performance = struct();
Summary.HeterogeneityL23 = struct();
Summary.HeterogeneityL5 = struct();
Summary.PerMouse = struct();
Summary.Representative = struct();
Summary.CuePretrainDiagnostics = struct();

AllSlope = [];
AllH23 = [];
AllH5 = [];
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

[RunState, didResume] = iLoadRunCheckpoint(Params, Cond);
if ~didResume
	RunState = iInitializeRunState(Params, Cond);
	mouseCells = cell(nTask, 1);
	sessionMeanL23Cells = cell(nTask, 1);
	sessionMeanL5Cells = cell(nTask, 1);
	parfor iTask = 1:nTask
		mouseCells{iTask} = iDrawMouse(Params);
		sessionMeanL23Cells{iTask} = nan(Params.NL23, Params.NumSessions);
		sessionMeanL5Cells{iTask} = nan(Params.NL5, Params.NumSessions);
	end
	RunState.MousePool = reshape(mouseCells, nCond, nMouse);
	RunState.SessionMeanL23 = reshape(sessionMeanL23Cells, nCond, nMouse);
	RunState.SessionMeanL5 = reshape(sessionMeanL5Cells, nCond, nMouse);
	RunState.Stage = "initialized";
	RunState = iSaveRunCheckpoint(RunState, Params, Cond);
end
RunState = iEnsureRunStateDiagnostics(RunState, Params, Cond);

MousePool = RunState.MousePool;
sessionMeanL23 = RunState.SessionMeanL23;
sessionMeanL5 = RunState.SessionMeanL5;
perfAll = RunState.PerfAll;
h23All = RunState.H23All;
h5All = RunState.H5All;

if ~RunState.CuePretrainingComplete
	fprintf('Starting cue pretraining for %d non-naive tasks.\n', nnz(taskCondName ~= "Naive"));
	[MousePool, RunState] = iRunCuePretrainingUnits(MousePool, Params, Cond, RunState);
	if RunState.CuePretrainingComplete
		fprintf('Cue pretraining complete.\n');
	end
else
	fprintf('Cue pretraining already complete in checkpoint.\n');
end

if ~RunState.RewardProbeComplete
	fprintf('Probing reward-readout similarity.\n');
	mouseCells = MousePool(:);
	fullRewardCond = iFullRewardCondition();
	rewardReadoutPretrainList = nan(nTask, 1);
	parfor iTask = 1:nTask
		rewardReadoutPretrainList(iTask) = iRewardReadoutProbe(mouseCells{iTask}, Params, fullRewardCond);
	end
	RunState.RewardReadoutPretrainAll = reshape(rewardReadoutPretrainList, nCond, nMouse);
	RunState.RewardProbeComplete = true;
	RunState.Stage = "reward-probe-complete";
	RunState.MousePool = MousePool;
	RunState = iSaveRunCheckpoint(RunState, Params, Cond);
	fprintf('Reward-readout probe complete.\n');
else
	fprintf('Reward-readout probe already complete in checkpoint.\n');
end

rewardReadoutPretrainAll = RunState.RewardReadoutPretrainAll;
if RunState.CompletedFormalSessions < nSess
	fprintf('Starting formal training from session %d/%d.\n', RunState.CompletedFormalSessions + 1, nSess);
else
	fprintf('Formal training already complete in checkpoint.\n');
end

for iSess = RunState.CompletedFormalSessions + 1:nSess
	fprintf('Starting formal session %d/%d.\n', iSess, nSess);
	mouseCells = MousePool(:);
	sessionMeanL23Cells = sessionMeanL23(:);
	sessionMeanL5Cells = sessionMeanL5(:);
	perfSession = nan(nTask, 1);
	h23Session = nan(nTask, 1);
	h5Session = nan(nTask, 1);
	firstSignalsSession = cell(nTask, 1);
	formalDiagnosticsSession = cell(nTask, 1);
	parfor iTask = 1:nTask
		iMouseTask = taskMouseIndex(iTask);
		Mouse = mouseCells{iTask};
		sessionParams = iWithRunContext(Params, sprintf('%s formal training mouse %d session %d', taskCondName(iTask), iMouseTask, iSess));
		sessionParams.HebbRate = sessionParams.FormalHebbRate;
		[perfTask, Signals, ~, Mouse] = iSimulateSession(Mouse, sessionParams, taskCondRows{iTask}, false);
		formalDiagnosticsSession{iTask} = iFormalTrainingDiagnosticSnapshot(Mouse, Signals, Params);
		sessionMeanL23Task = sessionMeanL23Cells{iTask};
		sessionMeanL5Task = sessionMeanL5Cells{iTask};
		sessionMeanL23Task(:, iSess) = Signals.ProcessMeanL23;
		sessionMeanL5Task(:, iSess) = Signals.ProcessMeanL5;
		perfSession(iTask) = perfTask;
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
	currentPerf = reshape(perfSession, nCond, nMouse);
	perfAll(:, :, iSess) = currentPerf;
	h23All(:, :, iSess) = reshape(h23Session, nCond, nMouse);
	h5All(:, :, iSess) = reshape(h5Session, nCond, nMouse);
	RunState.FormalTrainingDiagnostics = iRecordFormalTrainingDiagnostics(RunState.FormalTrainingDiagnostics, formalDiagnosticsSession, taskCondIndex, taskMouseIndex, iSess);
	fprintf('Completed formal session %d/%d:', iSess, nSess);
	for iCond = 1:nCond
		fprintf(' %s hit=%.3f', Cond.Name(iCond), mean(currentPerf(iCond, :), 'omitnan'));
	end
	fprintf('\n');
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
	RunState.MousePool = MousePool;
	RunState.SessionMeanL23 = sessionMeanL23;
	RunState.SessionMeanL5 = sessionMeanL5;
	RunState.PerfAll = perfAll;
	RunState.H23All = h23All;
	RunState.H5All = h5All;
	RunState.CompletedFormalSessions = iSess;
	RunState.Stage = sprintf("formal-session-%02d-complete", iSess);
	RunState = iSaveRunCheckpoint(RunState, Params, Cond);
end

iCheckFormalTrainingSuccess(RunState.PerfAll, Cond, Params);

MousePool = RunState.MousePool;
sessionMeanL23 = RunState.SessionMeanL23;
sessionMeanL5 = RunState.SessionMeanL5;
perfAll = RunState.PerfAll;
h23All = RunState.H23All;
h5All = RunState.H5All;

for iCond = 1:nCond
	perf = nan(Params.NumMice, Params.NumSessions);
	h23 = nan(Params.NumMice, Params.NumSessions);
	h5 = nan(Params.NumMice, Params.NumSessions);
	mouseSlope = nan(Params.NumMice, 1);
	mouseDeltaHit = nan(Params.NumMice, 1);
	mouseMeanH23 = nan(Params.NumMice, 1);
	mouseMeanH5 = nan(Params.NumMice, 1);
	rewardReadoutPretrain = nan(Params.NumMice, 1);
	rewardReadoutFinal = nan(Params.NumMice, 1);
	cuePretrainDiagnostics = cell(Params.NumMice, 1);
	repProcessL5 = cell(Params.NumMice, 1);
	condNow = Cond(iCond, :);
	for iMouse = 1:Params.NumMice
		Mouse = MousePool{iCond, iMouse};
		perf(iMouse, :) = reshape(perfAll(iCond, iMouse, :), 1, []);
		h23(iMouse, :) = reshape(h23All(iCond, iMouse, :), 1, []);
		h5(iMouse, :) = reshape(h5All(iCond, iMouse, :), 1, []);
		MouseResult = iSummarizeMouseTraining(perf(iMouse, :), h23(iMouse, :), h5(iMouse, :), sessionMeanL23{iCond, iMouse}, sessionMeanL5{iCond, iMouse}, Params);
		perf(iMouse, :) = MouseResult.Performance;
		h23(iMouse, :) = MouseResult.H23;
		h5(iMouse, :) = MouseResult.H5;
		mouseSlope(iMouse) = MouseResult.Slope;
		mouseDeltaHit(iMouse) = MouseResult.MeanDeltaHit;
		mouseMeanH23(iMouse) = MouseResult.MeanH23;
		mouseMeanH5(iMouse) = MouseResult.MeanH5;
		rewardReadoutPretrain(iMouse) = rewardReadoutPretrainAll(iCond, iMouse);
		rewardReadoutFinal(iMouse) = iRewardReadoutProbe(Mouse, Params, condNow);
		if isfield(Mouse, 'CuePretrainDiagnostics')
			cuePretrainDiagnostics{iMouse} = Mouse.CuePretrainDiagnostics;
		end
		repProcessL5{iMouse} = MouseResult.ProcessMeanL5;
	end
	perMouse = table(mouseSlope, mouseDeltaHit, mouseMeanH23, mouseMeanH5, rewardReadoutPretrain, rewardReadoutFinal, ...
		'VariableNames', {'Slope','MeanDeltaHit','MeanH23','MeanH5','RewardReadoutPretrain','RewardReadoutFinal'});
	Summary.Performance.(Cond.Name(iCond)) = perf;
	Summary.HeterogeneityL23.(Cond.Name(iCond)) = h23;
	Summary.HeterogeneityL5.(Cond.Name(iCond)) = h5;
	Summary.PerMouse.(Cond.Name(iCond)) = perMouse;
	Summary.CuePretrainDiagnostics.(Cond.Name(iCond)) = cuePretrainDiagnostics;
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

function [taskCondIndex, taskMouseIndex] = iMouseTaskIndex(nCond, nMouse)
taskCondIndex = repmat((1:nCond)', nMouse, 1);
taskMouseIndex = repelem((1:nMouse)', nCond);
end

function [MousePool, RunState] = iRunCuePretrainingUnits(MousePool, Params, Cond, RunState)
nCond = height(Cond);
nMouse = Params.NumMice;
nTask = nCond * nMouse;
[taskCondIndex, taskMouseIndex] = iMouseTaskIndex(nCond, nMouse);
pretrainParams = Params;
mouseCells = MousePool(:);
taskCondName = Cond.Name(taskCondIndex);
if nargin < 4 || isempty(RunState)
	RunState = iInitializeRunState(Params, Cond);
	RunState.MousePool = MousePool;
end

if ~isempty(RunState.CuePretrainState.StateCells)
	activeList = RunState.CuePretrainState.ActiveList;
	stateCells = RunState.CuePretrainState.StateCells;
	startSess = RunState.CompletedCuePretrainSessions + 1;
	fprintf('Resuming cue pretraining after session %d/%d: active=%d/%d.\n', ...
		RunState.CompletedCuePretrainSessions, pretrainParams.MaxPretrainSessions, nnz(activeList), nnz(taskCondName ~= "Naive"));
else
	activeList = false(nTask, 1);
	stateCells = cell(nTask, 1);
	for iTask = 1:nTask
		if taskCondName(iTask) ~= "Naive"
			activeList(iTask) = true;
			stateCells{iTask} = iInitCuePretrainState(pretrainParams);
		end
	end
	startSess = 1;
end

for iSess = startSess:pretrainParams.MaxPretrainSessions
	fprintf('Starting cue pretrain session %d/%d: active=%d/%d.\n', iSess, pretrainParams.MaxPretrainSessions, nnz(activeList), nnz(taskCondName ~= "Naive"));
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
	pretrainPerf = nan(nTask, 1);
	for iTask = 1:nTask
		if ~isempty(stateCells{iTask})
			pretrainPerf(iTask) = stateCells{iTask}.LastPerfObserved;
		end
	end
	fprintf('Completed cue pretrain session %d/%d: active=%d/%d', iSess, pretrainParams.MaxPretrainSessions, nnz(activeList), nnz(taskCondName ~= "Naive"));
	for iCond = 1:nCond
		if Cond.Name(iCond) ~= "Naive"
			condMask = taskCondIndex == iCond & isfinite(pretrainPerf);
			fprintf(' %s hit=%.3f', Cond.Name(iCond), mean(pretrainPerf(condMask), 'omitnan'));
		end
	end
	fprintf('\n');
	iPrintCuePretrainDebug(stateCells, taskCondIndex, Cond, iSess, Params);
	RunState.MousePool = reshape(mouseCells, nCond, nMouse);
	RunState.CuePretrainState.ActiveList = activeList;
	RunState.CuePretrainState.StateCells = stateCells;
	RunState.CuePretrainState.CompletedSessions = iSess;
	RunState.CompletedCuePretrainSessions = iSess;
	RunState.CuePretrainingComplete = ~any(activeList);
	if RunState.CuePretrainingComplete
		RunState.Stage = "cue-pretrain-complete";
	else
		RunState.Stage = "cue-pretrain";
	end
	RunState = iSaveRunCheckpoint(RunState, Params, Cond);
	if ~any(activeList)
		MousePool = reshape(mouseCells, nCond, nMouse);
		return;
	end
end
MousePool = reshape(mouseCells, nCond, nMouse);
end

function iPrintCuePretrainDebug(stateCells, taskCondIndex, Cond, iSess, Params)
if ~isfield(Params, 'PrintCuePretrainDebug') || ~Params.PrintCuePretrainDebug
	return;
end
for iCond = 1:height(Cond)
	if Cond.Name(iCond) ~= "Naive"
		condStateCells = stateCells(taskCondIndex == iCond);
		fprintf('Cue pretrain debug session %d %s: %s\n', iSess, Cond.Name(iCond), iCuePretrainDebugText(condStateCells, iSess));
	end
end
end

function debugText = iCuePretrainDebugText(stateCells, iSess)
preCueActivity = iCuePretrainDiagFieldMean(stateCells, 'PreCueL23CueMean', iSess);
cueNewActivity = iCuePretrainDiagFieldMean(stateCells, 'CueNewL23CueMean', iSess);
nonPreCueActivity = iCuePretrainDiagFieldMean(stateCells, 'NonPreCueL23CueMean', iSess);
preCueLearn = iCuePretrainDiagFieldMean(stateCells, 'PreCueL23LearnMean', iSess);
cueNewLearn = iCuePretrainDiagFieldMean(stateCells, 'CueNewL23LearnMean', iSess);
nonPreCueLearn = iCuePretrainDiagFieldMean(stateCells, 'NonPreCueL23LearnMean', iSess);
preCueRecurrent = iCuePretrainDiagFieldMean(stateCells, 'PreCueL23RecurrentPreMean', iSess);
cueNewRecurrent = iCuePretrainDiagFieldMean(stateCells, 'CueNewL23RecurrentPreMean', iSess);
nonPreCueRecurrent = iCuePretrainDiagFieldMean(stateCells, 'NonPreCueL23RecurrentPreMean', iSess);
preCueRecurrentToDirect = iCuePretrainDiagFieldMean(stateCells, 'PreCueL23RecurrentToDirectRatio', iSess);
preCueTargetW = iCuePretrainDiagFieldMean(stateCells, 'PreCueToTargetReadColumnSumMeanW', iSess);
cueNewTargetW = iCuePretrainDiagFieldMean(stateCells, 'CueNewToTargetReadColumnSumMeanW', iSess);
nonPreCueTargetW = iCuePretrainDiagFieldMean(stateCells, 'NonPreCueToTargetReadColumnSumMeanW', iSess);
preCueTargetEligibility = iCuePretrainDiagFieldMean(stateCells, 'PreCueToTargetReadEligibilityColumnSumMean', iSess);
cueNewTargetEligibility = iCuePretrainDiagFieldMean(stateCells, 'CueNewToTargetReadEligibilityColumnSumMean', iSess);
nonPreCueTargetEligibility = iCuePretrainDiagFieldMean(stateCells, 'NonPreCueToTargetReadEligibilityColumnSumMean', iSess);
debugText = sprintf(['cue L23 preCue/formal-new/non-preCue=%.3f/%.3f/%.3f; ', ...
	'learn L23=%.3f/%.3f/%.3f; L23 recurrent pre=%.3f/%.3f/%.3f, recurrent/direct(preCue)=%.3f; ', ...
	'target Read W columns=%.4f/%.4f/%.4f, formal-new/preCue=%.3f; ', ...
	'target Read eligibility columns=%.4f/%.4f/%.4f, formal-new/preCue=%.3f'], ...
	preCueActivity, cueNewActivity, nonPreCueActivity, ...
	preCueLearn, cueNewLearn, nonPreCueLearn, ...
	preCueRecurrent, cueNewRecurrent, nonPreCueRecurrent, preCueRecurrentToDirect, ...
	preCueTargetW, cueNewTargetW, nonPreCueTargetW, cueNewTargetW / max(preCueTargetW, eps), ...
	preCueTargetEligibility, cueNewTargetEligibility, nonPreCueTargetEligibility, cueNewTargetEligibility / max(preCueTargetEligibility, eps));
end

function fieldMean = iCuePretrainDiagFieldMean(stateCells, fieldName, iSess)
values = nan(numel(stateCells), 1);
for iStateCell = 1:numel(stateCells)
	cueState = stateCells{iStateCell};
	if ~isempty(cueState) && isfield(cueState, 'Diagnostics') && isfield(cueState.Diagnostics, fieldName)
		fieldValues = cueState.Diagnostics.(fieldName);
		if numel(fieldValues) >= iSess
			values(iStateCell) = fieldValues(iSess);
		end
	end
end
fieldMean = mean(values, 'omitnan');
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
pretrainParams.HebbRate = pretrainParams.PretrainHebbRate;
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

function iCheckFormalTrainingSuccess(perfAll, Cond, Params)
targetCondMask = Cond.Name == "Transfer";
targetCondNames = Cond.Name(targetCondMask);
targetPerf = perfAll(targetCondMask, :, :);
finalPerf = targetPerf(:, :, Params.NumSessions);
failedMask = ~isfinite(finalPerf) | finalPerf < Params.Ceiling;
if any(failedMask(:))
	diagMessage = iFormalTrainingFailureDiagnosticMessage(targetPerf, finalPerf, failedMask, targetCondNames, Params);
	error('THModel:FormalTrainingDidNotReachCeiling', ...
		'Transfer must reach %.0f%% hit in every mouse within %d formal training units. %s', ...
		100 * Params.Ceiling, Params.NumSessions, diagMessage);
end
iCheckFormalTrainingNonzeroFloor(perfAll, Cond, Params);
end

function iCheckFormalTrainingNonzeroFloor(perfAll, Cond, Params)
floorCondMask = Cond.Name == "Naive" | Cond.Name == "THOff";
floorCondNames = Cond.Name(floorCondMask);
floorPerf = perfAll(floorCondMask, :, 1:Params.NumSessions);
allZeroMask = all(floorPerf == 0, 3);
if any(allZeroMask(:))
	diagMessage = iFormalAllZeroDiagnosticMessage(floorPerf, allZeroMask, floorCondNames);
	error('THModel:FormalTrainingAllZero', ...
		'Naive and THOff mice must not have zero hits across all %d formal training units. %s', ...
		Params.NumSessions, diagMessage);
end
end

function diagMessage = iFormalTrainingFailureDiagnosticMessage(targetPerf, finalPerf, failedMask, targetCondNames, Params)
condText = strings(numel(targetCondNames), 1);
failedCurveText = strings(nnz(failedMask), 1);
iFailed = 0;
for iCond = 1:numel(targetCondNames)
	condFinalPerf = reshape(finalPerf(iCond, :), 1, []);
	failedMice = find(reshape(failedMask(iCond, :), 1, []));
	condText(iCond) = sprintf('%s final hits=%s, failed mice=%s', ...
		targetCondNames(iCond), iFormatNumberSeries(condFinalPerf), mat2str(failedMice));
	for iMouse = failedMice
		iFailed = iFailed + 1;
		mouseCurve = reshape(targetPerf(iCond, iMouse, :), 1, []);
		failedCurveText(iFailed) = sprintf('%s mouse %d curve=%s', targetCondNames(iCond), iMouse, iFormatNumberSeries(mouseCurve));
	end
end
diagMessage = sprintf('Final-session threshold %.3f. %s. Failed curves: %s.', ...
	Params.Ceiling, strjoin(condText, '; '), strjoin(failedCurveText, '; '));
end

function diagMessage = iFormalAllZeroDiagnosticMessage(floorPerf, allZeroMask, floorCondNames)
condText = strings(numel(floorCondNames), 1);
failedCurveText = strings(nnz(allZeroMask), 1);
iFailed = 0;
for iCond = 1:numel(floorCondNames)
	failedMice = find(reshape(allZeroMask(iCond, :), 1, []));
	condText(iCond) = sprintf('%s all-zero mice=%s', floorCondNames(iCond), mat2str(failedMice));
	for iMouse = failedMice
		iFailed = iFailed + 1;
		mouseCurve = reshape(floorPerf(iCond, iMouse, :), 1, []);
		failedCurveText(iFailed) = sprintf('%s mouse %d curve=%s', floorCondNames(iCond), iMouse, iFormatNumberSeries(mouseCurve));
	end
end
diagMessage = sprintf('%s. All-zero curves: %s.', strjoin(condText, '; '), strjoin(failedCurveText, '; '));
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
preCueL23ActiveFraction = nan(numMouse, 1);
cueL23ActiveFraction = nan(numMouse, 1);
cueL23OverlapFractionOfPreCue = nan(numMouse, 1);
preCueTargetReadOutputMean = nan(numMouse, 1);
cueNewTargetReadOutputMean = nan(numMouse, 1);
cueOverlapTargetReadOutputMean = nan(numMouse, 1);
preOnlyTargetReadOutputMean = nan(numMouse, 1);
cueNewVsPreCueTargetReadOutputRatio = nan(numMouse, 1);
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
	preCueMask = iGatherValue(Mouse.PreCueL23Pattern > 0);
	cueMask = iGatherValue(Mouse.CueL23Pattern > 0);
	preCueL23ActiveFraction(iMouse) = mean(preCueMask);
	cueL23ActiveFraction(iMouse) = mean(cueMask);
	cueL23OverlapFractionOfPreCue(iMouse) = nnz(preCueMask & cueMask) / nnz(preCueMask);
	readPattern = iGatherValue(Mouse.L5ReadoutPattern(:));
	readTargetMask = readPattern > 0;
	readoutRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
	targetReadRows = readoutRows(readTargetMask);
	l23ToTargetReadOutput = iGatherValue(sum(Mouse.W_InternalToInternal(targetReadRows, 1:Params.NL23), 1));
	cueNewMask = cueMask & ~preCueMask;
	cueOverlapMask = cueMask & preCueMask;
	preOnlyMask = preCueMask & ~cueMask;
	preCueTargetReadOutputMean(iMouse) = iMeanFlat(l23ToTargetReadOutput(preCueMask));
	cueNewTargetReadOutputMean(iMouse) = iMeanFlat(l23ToTargetReadOutput(cueNewMask));
	cueOverlapTargetReadOutputMean(iMouse) = iMeanFlat(l23ToTargetReadOutput(cueOverlapMask));
	preOnlyTargetReadOutputMean(iMouse) = iMeanFlat(l23ToTargetReadOutput(preOnlyMask));
	cueNewVsPreCueTargetReadOutputRatio(iMouse) = cueNewTargetReadOutputMean(iMouse) / max(preCueTargetReadOutputMean(iMouse), eps);
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
diagMessage = sprintf(['First cue-training diagnostics: per-mouse perf=%s; decision similarity mean=%s, max=%s; ', ...
	'baseline corrections mean=%s, max=%s; baseline max-similarity mean=%s, max=%s; baseline final-similarity mean=%s, max=%s; cue L23 pattern corr=%s; ', ...
	'cue L23 active fractions: pre=%s, formal=%s, overlap/pre=%s; target Read output by L23 group: pre=%s, cue-new=%s, overlap=%s, pre-only=%s, cue-new/pre=%s; baseline-final/decision similarity ratio=%s; ', ...
	'baseline trigger target Read pre mean: L23=%s, RewardRecv=%s, Read recurrent=%s, IL23=%s, IL5RewardRecvI=%s, L2 net=%s, L5 net=%s, total=%s; ', ...
	'cue IL23 mean=%s, max=%s; cue IL5RewardRecvI mean=%s, max=%s; ', ...
	'IL5RewardRecvI drive TH pre mean=%s, max=%s; IL23 recurrent pre mean=%s, min=%s, |pre| mean=%s, max=%s; ', ...
	'|IL23->Read| mean=%s, max=%s; |IL5RewardRecvI->Read| mean=%s, max=%s; |IL23->IL5RewardRecvI| mean=%s, max=%s.'], ...
	iFormatNumberSeries(firstUnitPerf), iFormatNumberSeries(decisionDriveMean), iFormatNumberSeries(decisionDriveMax), ...
	iFormatNumberSeries(baselineCorrectionMean), iFormatNumberSeries(baselineCorrectionMax), iFormatNumberSeries(baselineMaxDriveMean), iFormatNumberSeries(baselineMaxDriveMax), ...
	iFormatNumberSeries(baselineFinalDriveMean), iFormatNumberSeries(baselineFinalDriveMax), ...
	iFormatNumberSeries(cueL23PatternCorrelation), iFormatNumberSeries(preCueL23ActiveFraction), iFormatNumberSeries(cueL23ActiveFraction), iFormatNumberSeries(cueL23OverlapFractionOfPreCue), ...
	iFormatNumberSeries4(preCueTargetReadOutputMean), iFormatNumberSeries4(cueNewTargetReadOutputMean), iFormatNumberSeries4(cueOverlapTargetReadOutputMean), iFormatNumberSeries4(preOnlyTargetReadOutputMean), iFormatNumberSeries(cueNewVsPreCueTargetReadOutputRatio), iFormatNumberSeries(baselineToDecisionSimilarityRatio), ...
	iFormatNumberSeries(baselineTargetL23PreMean), iFormatNumberSeries(baselineTargetRewardRecvPreMean), iFormatNumberSeries(baselineTargetReadRecurrentPreMean), ...
	iFormatNumberSeries(baselineTargetIL23PreMean), iFormatNumberSeries(baselineTargetIL5RewardRecvIPreMean), iFormatNumberSeries(baselineTargetL2NetPreMean), iFormatNumberSeries(baselineTargetL5NetPreMean), iFormatNumberSeries(baselineTargetNetPreMean), ...
	iFormatNumberSeries(cueIL23Mean), iFormatNumberSeries(cueIL23Max), iFormatNumberSeries(cueIL5RewardRecvIMean), iFormatNumberSeries(cueIL5RewardRecvIMax), ...
	iFormatNumberSeries(thToIL5RewardRecvIPreMean), iFormatNumberSeries(thToIL5RewardRecvIPreMax), iFormatNumberSeries(il23ToIL5RewardRecvIPreMean), iFormatNumberSeries(il23ToIL5RewardRecvIPreMin), ...
	iFormatNumberSeries(il23ToIL5RewardRecvIPreMeanAbs), iFormatNumberSeries(il23ToIL5RewardRecvIPreMaxAbs), iFormatNumberSeries(il23ToReadMeanAbsW), iFormatNumberSeries(il23ToReadMaxAbsW), ...
	iFormatNumberSeries(il5RewardRecvIToReadMeanAbsW), iFormatNumberSeries(il5RewardRecvIToReadMaxAbsW), iFormatNumberSeries(il23ToIL5RewardRecvIMeanAbsW), iFormatNumberSeries(il23ToIL5RewardRecvIMaxAbsW));
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

function Result = iSummarizeMouseTraining(perf, h23, h5, sessionMeanL23, sessionMeanL5, Params)
resultSlope = iSigmoidSlopeFromPerformance(perf);
first100 = find(perf >= Params.SlopeHitPerfect, 1, 'first');
if isempty(first100)
	useIdx = 1:Params.NumSessions;
elseif first100 == 1
	useIdx = [];
else
	useIdx = 1:first100-1;
end

if numel(useIdx) >= 2
	fitY = perf(useIdx)';
	dh = diff(fitY);
	finalMeanL23 = mean(sessionMeanL23(:, useIdx), 2, 'omitnan');
	finalMeanL5  = mean(sessionMeanL5(:,  useIdx), 2, 'omitnan');
	resultDeltaHit = mean(dh, 'omitnan');
	resultMeanH23 = iRestrictedStd(finalMeanL23);
	resultMeanH5  = iRestrictedStd(finalMeanL5);
elseif ~isempty(useIdx)
	finalMeanL5 = mean(sessionMeanL5(:, useIdx), 2, 'omitnan');
	resultDeltaHit = NaN;
	resultMeanH23 = NaN;
	resultMeanH5 = NaN;
else
	finalMeanL5 = nan(Params.NL5, 1);
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

function slope = iSigmoidSlopeFromPerformance(perf)
xObs = (1:numel(perf))';
yObs = double(perf(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); log(max(median(xObs), 1))];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
[~, ~, slope, ~] = iDecodeSigmoidParams(p);
end

function y = iSigmoidFromParams(p, x)
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
lower = 1 ./ (1 + exp(-p(1)));
upper = 1;
slope = exp(p(2));
midpoint = exp(p(3));
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end

function Mouse = iDrawMouse(Params)
% Fixed input / target patterns.
% Cue patterns are binary direct-drive masks on L2/3 cells: full response or 0.
% Cue and PreCue use fixed-count masks. Formal cue cells include a fixed
% overlap count among pre-cue cells plus newly active cells drawn from the
% remaining L2/3 population.
[preCuePositiveMask, cueMask] = iDrawFixedCountCueMasks(Params);
Mouse.PreCueL23Pattern = iMaskToVertexPattern(preCuePositiveMask, Params);
Mouse.CueL23Pattern = iMaskToVertexPattern(cueMask, Params);
Mouse.THRewardPattern    = iVertexPattern(iRandn(Params.NL5RewardRecv, Params) + 0.55 * sign(iRandn(Params.NL5RewardRecv, Params)));
Mouse.L5ReadoutPattern   = iVertexPattern(iRandn(Params.NL5Read, Params) + 0.55 * sign(iRandn(Params.NL5Read, Params)));

% Plastic internal recurrent matrix, W(post, pre). E presynaptic columns are
% nonnegative; I presynaptic columns are nonpositive. Thus the matrix contains
% EE, EI, IE, and II connections under Dale's law.
Mouse.Z_InternalToInternal = iInitChiSquareAccumulator([Params.NInternal, Params.NInternal], Params.InitRecurrentAccumulatorScale, Params.InitRecurrentAccumulatorChiSquareDof, Params);
Mouse.Z_InternalToInternal = iShiftRecurrentColumnsToNonnegative(Mouse.Z_InternalToInternal);
Mouse.W_InternalToInternal = iAccumulatorToInternalWeight(Mouse.Z_InternalToInternal, Params);

end

function [preCueMask, cueMask] = iDrawFixedCountCueMasks(Params)
numL23 = Params.NL23;
preCueCount = round(numL23 * Params.PreCueL23ActiveFraction);
cueCount = round(numL23 * Params.CueL23ActiveFraction);
overlapCount = round(preCueCount * Params.CueL23OverlapFractionOfPreCue);
overlapCount = min(overlapCount, cueCount);

preCueIdx = randperm(numL23, preCueCount);
remainingIdx = setdiff(1:numL23, preCueIdx);
overlapIdx = preCueIdx(randperm(preCueCount, overlapCount));
newCueCount = cueCount - overlapCount;
newCueIdx = remainingIdx(randperm(numel(remainingIdx), newCueCount));

preCueMask = iLogicalMaskFromIndices(numL23, preCueIdx, Params);
cueMask = iLogicalMaskFromIndices(numL23, [overlapIdx, newCueIdx], Params);
end

function mask = iLogicalMaskFromIndices(numCells, selectedIdx, Params)
mask = false(numCells, 1);
mask(selectedIdx) = true;
if iUseGPU(Params)
	mask = gpuArray(mask);
end
end

function Mouse = iPretrainMouse(Mouse, Params)
% Pretraining uses PreCueL23Pattern and keeps structured TH input intact.
pretrainCond.THInputIsNoise = false;
pretrainParams = Params;
pretrainParams.HebbRate = pretrainParams.PretrainHebbRate;
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

function learningActivityHistory = iRunTeacherReadoutIterations(decisionActivity, preL5RewardRecv, preIL5RewardRecv, Mouse, Params)
learningActivityHistory = iZeros([Params.NInternal, Params.TeacherReadoutPasses], Params);
internalActivity = decisionActivity;
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
cuePretrainDiag.PreCueL23CueMean = nan(nSess, 1);
cuePretrainDiag.CueNewL23CueMean = nan(nSess, 1);
cuePretrainDiag.NonPreCueL23CueMean = nan(nSess, 1);
cuePretrainDiag.PreCueL23DirectDriveMean = nan(nSess, 1);
cuePretrainDiag.CueNewL23DirectDriveMean = nan(nSess, 1);
cuePretrainDiag.NonPreCueL23DirectDriveMean = nan(nSess, 1);
cuePretrainDiag.PreCueL23RecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.CueNewL23RecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.NonPreCueL23RecurrentPreMean = nan(nSess, 1);
cuePretrainDiag.PreCueL23RecurrentToDirectRatio = nan(nSess, 1);
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
cuePretrainDiag.PreCueL23LearnMean = nan(nSess, 1);
cuePretrainDiag.CueNewL23LearnMean = nan(nSess, 1);
cuePretrainDiag.NonPreCueL23LearnMean = nan(nSess, 1);
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
cuePretrainDiag.PreCueToTargetReadEligibilityColumnSumMean = nan(nSess, 1);
cuePretrainDiag.CueNewToTargetReadEligibilityColumnSumMean = nan(nSess, 1);
cuePretrainDiag.NonPreCueToTargetReadEligibilityColumnSumMean = nan(nSess, 1);
cuePretrainDiag.PreCueToTargetReadColumnSumMeanW = nan(nSess, 1);
cuePretrainDiag.CueNewToTargetReadColumnSumMeanW = nan(nSess, 1);
cuePretrainDiag.NonPreCueToTargetReadColumnSumMeanW = nan(nSess, 1);
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
preCueMask = iGatherValue(Mouse.PreCueL23Pattern(:) > 0);
formalCueMask = iGatherValue(Mouse.CueL23Pattern(:) > 0);
cueNewMask = formalCueMask & ~preCueMask;
nonPreCueMask = ~preCueMask;
l23OutputShare = iColumnDistribution(internalAccumulator(:, l23Cols));
rewardRecvOutputShare = iColumnDistribution(internalAccumulator(:, rewardRecvCols));
l23DirectCueDrive = Params.CueL23Gain * iGatherValue(Mouse.PreCueL23Pattern(:));
l23RecurrentPre = internalWeight(l23Cols, :) * cueInternalMean;
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
l23ToTargetReadColumnSum = sum(l23ToReadW(readTargetMask, :), 1);
l23ToTargetReadEligibilityColumnSum = sum(internalEligibility(targetReadRows, l23Cols), 1);

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
cuePretrainDiag.PreCueL23CueMean(iSess) = iMeanFlat(Signals.ProcessMeanL23(preCueMask));
cuePretrainDiag.CueNewL23CueMean(iSess) = iMeanFlat(Signals.ProcessMeanL23(cueNewMask));
cuePretrainDiag.NonPreCueL23CueMean(iSess) = iMeanFlat(Signals.ProcessMeanL23(nonPreCueMask));
cuePretrainDiag.PreCueL23DirectDriveMean(iSess) = iMeanFlat(l23DirectCueDrive(preCueMask));
cuePretrainDiag.CueNewL23DirectDriveMean(iSess) = iMeanFlat(l23DirectCueDrive(cueNewMask));
cuePretrainDiag.NonPreCueL23DirectDriveMean(iSess) = iMeanFlat(l23DirectCueDrive(nonPreCueMask));
cuePretrainDiag.PreCueL23RecurrentPreMean(iSess) = iMeanFlat(l23RecurrentPre(preCueMask));
cuePretrainDiag.CueNewL23RecurrentPreMean(iSess) = iMeanFlat(l23RecurrentPre(cueNewMask));
cuePretrainDiag.NonPreCueL23RecurrentPreMean(iSess) = iMeanFlat(l23RecurrentPre(nonPreCueMask));
cuePretrainDiag.PreCueL23RecurrentToDirectRatio(iSess) = cuePretrainDiag.PreCueL23RecurrentPreMean(iSess) / max(cuePretrainDiag.PreCueL23DirectDriveMean(iSess), eps);
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
cuePretrainDiag.PreCueL23LearnMean(iSess) = iMeanFlat(Signals.mL23(preCueMask));
cuePretrainDiag.CueNewL23LearnMean(iSess) = iMeanFlat(Signals.mL23(cueNewMask));
cuePretrainDiag.NonPreCueL23LearnMean(iSess) = iMeanFlat(Signals.mL23(nonPreCueMask));
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
cuePretrainDiag.PreCueToTargetReadEligibilityColumnSumMean(iSess) = iMeanFlat(l23ToTargetReadEligibilityColumnSum(preCueMask));
cuePretrainDiag.CueNewToTargetReadEligibilityColumnSumMean(iSess) = iMeanFlat(l23ToTargetReadEligibilityColumnSum(cueNewMask));
cuePretrainDiag.NonPreCueToTargetReadEligibilityColumnSumMean(iSess) = iMeanFlat(l23ToTargetReadEligibilityColumnSum(nonPreCueMask));
cuePretrainDiag.PreCueToTargetReadColumnSumMeanW(iSess) = iMeanFlat(l23ToTargetReadColumnSum(preCueMask));
cuePretrainDiag.CueNewToTargetReadColumnSumMeanW(iSess) = iMeanFlat(l23ToTargetReadColumnSum(cueNewMask));
cuePretrainDiag.NonPreCueToTargetReadColumnSumMeanW(iSess) = iMeanFlat(l23ToTargetReadColumnSum(nonPreCueMask));
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
targetReadL23Pre = cuePretrainDiag.ReadTargetL23PreMean(useSess);
targetReadRewardRecvPre = cuePretrainDiag.ReadTargetRewardRecvPreMean(useSess);
targetReadRecurrentPre = cuePretrainDiag.ReadTargetReadPreMean(useSess);
targetReadAmplifierPre = targetReadRewardRecvPre + targetReadRecurrentPre;
targetReadSourceTotalPre = targetReadL23Pre + targetReadAmplifierPre;
targetReadAmplifierToL23Ratio = targetReadAmplifierPre ./ max(targetReadL23Pre, eps);
targetReadL23SourceShare = targetReadL23Pre ./ max(targetReadSourceTotalPre, eps);
targetReadAmplifierSourceShare = targetReadAmplifierPre ./ max(targetReadSourceTotalPre, eps);
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
sourceTimingText = sprintf(['target Read source timing: L23 direct d=%s, RewardRecv d=%s, Read recurrent d=%s, amplifier d=%s, amplifier/L23=%s; ', ...
	'early/late mean delta L23=%.4f/%.4f, RewardRecv=%.4f/%.4f, Read recurrent=%.4f/%.4f, amplifier=%.4f/%.4f; ', ...
	'first/last source share L23=%.3f -> %.3f, amplifier=%.3f -> %.3f; '], ...
	iFormatDeltaSeries4(targetReadL23Pre), iFormatDeltaSeries4(targetReadRewardRecvPre), iFormatDeltaSeries4(targetReadRecurrentPre), iFormatDeltaSeries4(targetReadAmplifierPre), iFormatNumberSeries(targetReadAmplifierToL23Ratio), ...
	iEarlyDeltaMean(targetReadL23Pre), iLateDeltaMean(targetReadL23Pre), ...
	iEarlyDeltaMean(targetReadRewardRecvPre), iLateDeltaMean(targetReadRewardRecvPre), ...
	iEarlyDeltaMean(targetReadRecurrentPre), iLateDeltaMean(targetReadRecurrentPre), ...
	iEarlyDeltaMean(targetReadAmplifierPre), iLateDeltaMean(targetReadAmplifierPre), ...
	targetReadL23SourceShare(1), targetReadL23SourceShare(end), targetReadAmplifierSourceShare(1), targetReadAmplifierSourceShare(end));
l23SpecificityText = sprintf(['L23 specificity trajectories: cue activity preCue/formal-new/non-preCue=%s/%s/%s; ', ...
	'learning activity preCue/formal-new/non-preCue=%s/%s/%s; recurrent pre preCue/formal-new/non-preCue=%s/%s/%s, recurrent/direct(preCue)=%s; ', ...
	'target Read W columns preCue/formal-new/non-preCue=%s/%s/%s; target Read eligibility columns preCue/formal-new/non-preCue=%s/%s/%s; '], ...
	iFormatNumberSeries(cuePretrainDiag.PreCueL23CueMean(useSess)), iFormatNumberSeries(cuePretrainDiag.CueNewL23CueMean(useSess)), iFormatNumberSeries(cuePretrainDiag.NonPreCueL23CueMean(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.PreCueL23LearnMean(useSess)), iFormatNumberSeries(cuePretrainDiag.CueNewL23LearnMean(useSess)), iFormatNumberSeries(cuePretrainDiag.NonPreCueL23LearnMean(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.PreCueL23RecurrentPreMean(useSess)), iFormatNumberSeries(cuePretrainDiag.CueNewL23RecurrentPreMean(useSess)), iFormatNumberSeries(cuePretrainDiag.NonPreCueL23RecurrentPreMean(useSess)), iFormatNumberSeries(cuePretrainDiag.PreCueL23RecurrentToDirectRatio(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.PreCueToTargetReadColumnSumMeanW(useSess)), iFormatNumberSeries4(cuePretrainDiag.CueNewToTargetReadColumnSumMeanW(useSess)), iFormatNumberSeries4(cuePretrainDiag.NonPreCueToTargetReadColumnSumMeanW(useSess)), ...
	iFormatNumberSeries4(cuePretrainDiag.PreCueToTargetReadEligibilityColumnSumMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.CueNewToTargetReadEligibilityColumnSumMean(useSess)), iFormatNumberSeries4(cuePretrainDiag.NonPreCueToTargetReadEligibilityColumnSumMean(useSess)));
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
inhibitoryDriveText = sprintf(['IL5RewardRecvI drive first/last: direct TH/noise pre mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
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
weightText = sprintf(['weights first/last: L23->RewardRecv mean/max=%.4f/%.4f -> %.4f/%.4f, L23->Read mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'RewardRecv->Read mean/max=%.4f/%.4f -> %.4f/%.4f, Exc->Read mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'|I->Read| mean/max=%.4f/%.4f -> %.4f/%.4f, |IL23->Read| mean/max=%.4f/%.4f -> %.4f/%.4f, ', ...
	'|IL5RewardRecvI->Read| mean/max=%.4f/%.4f -> %.4f/%.4f, |IL23->IL5RewardRecvI| mean/max=%.4f/%.4f -> %.4f/%.4f.'], ...
	cuePretrainDiag.L23ToRewardRecvMeanW(firstSess), cuePretrainDiag.L23ToRewardRecvMaxW(firstSess), cuePretrainDiag.L23ToRewardRecvMeanW(lastSess), cuePretrainDiag.L23ToRewardRecvMaxW(lastSess), ...
	cuePretrainDiag.L23ToReadMeanW(firstSess), cuePretrainDiag.L23ToReadMaxW(firstSess), cuePretrainDiag.L23ToReadMeanW(lastSess), cuePretrainDiag.L23ToReadMaxW(lastSess), ...
	cuePretrainDiag.RewardRecvToReadMeanW(firstSess), cuePretrainDiag.RewardRecvToReadMaxW(firstSess), cuePretrainDiag.RewardRecvToReadMeanW(lastSess), cuePretrainDiag.RewardRecvToReadMaxW(lastSess), ...
	cuePretrainDiag.ExcToReadMeanW(firstSess), cuePretrainDiag.ExcToReadMaxW(firstSess), cuePretrainDiag.ExcToReadMeanW(lastSess), cuePretrainDiag.ExcToReadMaxW(lastSess), ...
	cuePretrainDiag.InhToReadMeanAbsW(firstSess), cuePretrainDiag.InhToReadMaxAbsW(firstSess), cuePretrainDiag.InhToReadMeanAbsW(lastSess), cuePretrainDiag.InhToReadMaxAbsW(lastSess), ...
	cuePretrainDiag.IL23ToReadMeanAbsW(firstSess), cuePretrainDiag.IL23ToReadMaxAbsW(firstSess), cuePretrainDiag.IL23ToReadMeanAbsW(lastSess), cuePretrainDiag.IL23ToReadMaxAbsW(lastSess), ...
	cuePretrainDiag.IL5RewardRecvIToReadMeanAbsW(firstSess), cuePretrainDiag.IL5RewardRecvIToReadMaxAbsW(firstSess), cuePretrainDiag.IL5RewardRecvIToReadMeanAbsW(lastSess), cuePretrainDiag.IL5RewardRecvIToReadMaxAbsW(lastSess), ...
	cuePretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(firstSess), cuePretrainDiag.IL23ToIL5RewardRecvIMeanAbsW(lastSess), cuePretrainDiag.IL23ToIL5RewardRecvIMaxAbsW(lastSess));
diagMessage = sprintf(['Cue pretrain diagnostics: perf=%s; decision similarity mean=%s, max=%s; ', ...
	'baseline corrections mean=%s, max=%s; baseline max-similarity mean=%s, max=%s; baseline final-similarity mean=%s, max=%s; %s%s%s%s%s%s%s%s%s%s%s%s%s'], ...
	iFormatNumberSeries(cuePretrainDiag.PerfObserved(useSess)), iFormatNumberSeries(cuePretrainDiag.DecisionDriveMean(useSess)), iFormatNumberSeries(cuePretrainDiag.DecisionDriveMax(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.BaselineCorrectionMean(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineCorrectionMax(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineMaxDriveMean(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineMaxDriveMax(useSess)), ...
	iFormatNumberSeries(cuePretrainDiag.BaselineFinalDriveMean(useSess)), iFormatNumberSeries(cuePretrainDiag.BaselineFinalDriveMax(useSess)), ...
	growthText, sourceTimingText, l23SpecificityText, trajectoryText, rewardRecvCompetitionText, cueActivityText, learningActivityText, rewardRecvPatternText, inhibitoryDriveText, baselineSourceText, readoutCircuitText, il5InhibitoryCircuitText, weightText);
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

function readoutDrive = iRewardReadoutProbe(Mouse, Params, Cond)
ProbeParams = Params;
ProbeParams.NoiseInput = 0;
ProbeParams.NoiseRead = 0;

preL23 = iZeros(ProbeParams.NL23, ProbeParams);
preIL23 = iZeros(ProbeParams.NIL23, ProbeParams);
[preL5RewardRecv, preIL5RewardRecv] = iRunTHInput(Mouse, ProbeParams, Cond, "reward");
preL5Read = iZeros(ProbeParams.NL5Read, ProbeParams);
[~, ~, rL5Read] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, ProbeParams, preIL23, preIL5RewardRecv);
readoutDrive = iReadoutPatternSimilarity(rL5Read, Mouse.L5ReadoutPattern, ProbeParams);
end

function [Result, Mouse] = iSimulateMouse(Mouse, Params, Cond)
Params.HebbRate = Params.FormalHebbRate;
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

resultSlope = iSigmoidSlopeFromPerformance(perf);
first100 = find(perf >= Params.SlopeHitPerfect, 1, 'first');
if isempty(first100)
	useIdx = 1:Params.NumSessions;
elseif first100 == 1
	useIdx = [];
else
	useIdx = 1:first100-1;
end

if numel(useIdx) >= 2
	fitY = perf(useIdx)';
	dh = diff(fitY);
	finalMeanL23 = mean(sessionMeanL23(:, useIdx), 2, 'omitnan');
	finalMeanL5  = mean(sessionMeanL5(:,  useIdx), 2, 'omitnan');
	resultDeltaHit = mean(dh, 'omitnan');
	resultMeanH23 = iRestrictedStd(finalMeanL23);
	resultMeanH5  = iRestrictedStd(finalMeanL5);
elseif ~isempty(useIdx)
	finalMeanL5 = mean(sessionMeanL5(:, useIdx), 2, 'omitnan');
	resultDeltaHit = NaN;
	resultMeanH23 = NaN;
	resultMeanH5 = NaN;
else
	finalMeanL5 = nan(Params.NL5, 1);
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
% followed by direct supervised training on the settled cue-decision state
% after replacing L5Read with the perfect readout pattern. Hebbian
% and inhibitory plasticity are applied AFTER EACH TRIAL so that within-session
% learning accumulates.
NT = Params.NumTrials;

if usePreCue
	cueL23Pattern = Mouse.PreCueL23Pattern;
else
	cueL23Pattern = Mouse.CueL23Pattern;
end
cueGain = Params.CueL23Gain;
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

eligInternal = iZeroCellEligibility(Params.NInternal, Params.NInternal, Params);

for t = 1:NT
	% ===== Continuous rest/no-cue baseline gate =====
	[Mouse, baselineCorrectionCount(t), baselineMaxDriveAll(t), baselineFinalDriveAll(t), baselineReadoutSource, baselineInternalActivity] = iRunContinuousBaselineRest(Mouse, Params, Cond, t);
	baselineTargetL23PreAll(t) = baselineReadoutSource.TargetL23;
	baselineTargetRewardRecvPreAll(t) = baselineReadoutSource.TargetRewardRecv;
	baselineTargetReadRecurrentPreAll(t) = baselineReadoutSource.TargetReadRecurrent;
	baselineTargetIL23PreAll(t) = baselineReadoutSource.TargetIL23;
	baselineTargetIL5RewardRecvIPreAll(t) = baselineReadoutSource.TargetIL5RewardRecvI;
	baselineTargetL2NetPreAll(t) = baselineReadoutSource.TargetL2Net;
	baselineTargetL5NetPreAll(t) = baselineReadoutSource.TargetL5Net;
	baselineTargetNetPreAll(t) = baselineReadoutSource.TargetNet;

	% ===== Decision phase (direct cue drive -> recurrent L2/3-L5 network) =====
	cueL23Drive = cueGain * cueL23Pattern + Params.NoiseInput * iRandn(Params.NL23, Params);
	nDecisionState = Params.InternalRecurrentPasses + 1;
	cueL23DriveHistory = iRunCueL23DriveHistory(cueL23Drive, Params, nDecisionState);
	preL5Read_cue = Params.NoiseRead * iRandn(Params.NL5Read, Params);
	[rL23_cue, rL5RewardRecv_cue, rL5Read_cue, decisionActivityCue, decisionTraceCue, ~, ~, decisionActivityHistory, preIL5RewardRecvHistory] = iRunDecisionNetwork(cueL23DriveHistory, preL5Read_cue, Mouse, Params, Cond, baselineInternalActivity);
	[~, ~, ~, rIL23_cue, rIL5RewardRecvI_cue] = iSplitInternalActivity(decisionActivityCue, Params);
	il23ToIL5RewardRecvIPre = iIL23ToIL5RewardRecvIContribution(Mouse, decisionActivityHistory, Params);

	isHit(t) = any(decisionTraceCue >= Params.HitThreshold);
	decisionReadoutDriveAll(t) = max(decisionTraceCue);

	% ===== Learning phase (teacher readout + sustained direct reward-mode TH input) =====
	[preL5RewardRecv_L, preIL5RewardRecv_L] = iRunTHInput(Mouse, Params, Cond, "reward");
	learningActivityHistory = iRunTeacherReadoutIterations(decisionActivityCue, preL5RewardRecv_L, preIL5RewardRecv_L, Mouse, Params);
	[rL23_L_history, rL5RewardRecv_L_history, rL5Read_L_history] = iSplitInternalActivity(learningActivityHistory, Params);
	rL23_L = mean(rL23_L_history, 2);
	rL5RewardRecv_L = mean(rL5RewardRecv_L_history, 2);
	rL5Read_L = mean(rL5Read_L_history, 2);
	decisionTrainingHistory = decisionActivityHistory;

	% Per-trial updates on decaying before/after iteration eligibility traces of the recurrent L2/3-L5 matrix.
	eligInternal = iUpdateTaskLearningHistoryEligibility(eligInternal, decisionTrainingHistory, learningActivityHistory, Params);
	eligInternalToInternal = iRecurrentCellEligibilityToSynapseEligibility(eligInternal, Params);
	isPunishment = false;
	[Mouse.Z_InternalToInternal, Mouse.W_InternalToInternal] = iApplyLatentInternalTrace(Mouse.Z_InternalToInternal, eligInternalToInternal, traceEta, Params, isPunishment);

	rL23_cue_all(:, t) = rL23_cue;
	rL5RewardRecv_cue_all(:, t) = rL5RewardRecv_cue;
	rL5Read_cue_all(:, t) = rL5Read_cue;
	rIL23_cue_all(:, t) = rIL23_cue;
	rIL5RewardRecvI_cue_all(:, t) = rIL5RewardRecvI_cue;
	il23ToIL5RewardRecvIPre_all(:, t) = mean(il23ToIL5RewardRecvIPre, 2);
	thToIL5RewardRecvIPre_all(:, t) = mean(preIL5RewardRecvHistory, 2);
	rL23_L_all(:, t) = rL23_L;
	rL5RewardRecv_L_all(:, t) = rL5RewardRecv_L;
	rL5Read_L_all(:, t) = rL5Read_L;
end

perf = mean(isHit);
% Kept for interface compatibility with pretraining logic. With hard-
% threshold decisions and no extra Bernoulli sampling, expected and
% observed session hit rates are identical under the realized noise.
perfExpected = perf;

Signals.mL23 = iGatherValue(mean(rL23_L_all, 2));
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

function rE = iRunArea(pre, areaSpec, ~, Params)
switch areaSpec
case {'l23', 'l5rewardrecv', 'l5read', 'il23', 'il5rewardrecv'}
	rE = iRateResponse(pre, Params);
end
end

function r = iRateResponse(pre, Params)
r = 0.5 + atan(Params.RateResponseSlope * (pre - Params.RateResponseMidpoint)) / pi;
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

function [preL5RewardRecv, preIL5RewardRecv] = iRunTHInput(Mouse, Params, Cond, thMode)
	switch thMode
	case {"rest", "lick"}
		preL5RewardRecv = Params.NoiseInput * iRandn(Params.NL5RewardRecv, Params);
		preIL5RewardRecv = Params.NoiseInput * iRandn(Params.NIL5RewardRecv, Params);
		return;
	case "reward"
		if Cond.THInputIsNoise
			preL5RewardRecv = Params.THNoiseInputGain * iStandardize(iRandn(Params.NL5RewardRecv, Params)) + Params.NoiseInput * iRandn(Params.NL5RewardRecv, Params);
		else
			preL5RewardRecv = Params.THRewardInputGain * Mouse.THRewardPattern + Params.NoiseInput * iRandn(Params.NL5RewardRecv, Params);
		end
	end
preIL5RewardRecv = Params.NoiseInput * iRandn(Params.NIL5RewardRecv, Params);
end

function [Mouse, nBaselineCorrections, maxBaselineDrive, finalBaselineDrive, baselineReadoutSource, baselineInternalActivity] = iRunContinuousBaselineRest(Mouse, Params, Cond, iTrial)
quietCount = 0;
nBaselineCorrections = 0;
maxBaselineDrive = -Inf;
finalBaselineDrive = NaN;
baselineInternalActivity = iZeros(Params.NInternal, Params);
baselineReadoutSourceSum = iZeroBaselineReadoutSource();
baselineReadoutSource = iAverageBaselineReadoutSource(baselineReadoutSourceSum, nBaselineCorrections);
baselineSuppressionDiagSum = iZeroBaselineSuppressionDiagnostic();
internalActivity = [];
previousL5RewardInput = iZeros(Params.NL5RewardRecv, Params);
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
	[preL5RewardRecv, preIL5RewardRecv] = iRunTHInput(Mouse, Params, Cond, "rest");
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
		[Mouse, suppressionDiag] = iSuppressFalseReadout(Mouse, internalActivityBefore, internalActivity, readoutDrive, Params, previousL5RewardInput, preL5RewardRecv, previousRewardRecvActivity, rewardRecvActivity, previousIRewardRecvActivity, iRewardRecvActivity);
		baselineSuppressionDiagSum = iAddBaselineSuppressionDiagnostic(baselineSuppressionDiagSum, suppressionDiag);
		quietCount = 0;
	else
		quietCount = quietCount + 1;
		if quietCount >= Params.BaselineQuietIterations
			finalBaselineDrive = readoutDrive;
			baselineReadoutSource = iAverageBaselineReadoutSource(baselineReadoutSourceSum, nBaselineCorrections);
			baselineInternalActivity = internalActivity;
			return;
		end
	end
	previousL5RewardInput = preL5RewardRecv;
	previousRewardRecvActivity = rewardRecvActivity;
	previousIRewardRecvActivity = iRewardRecvActivity;
end

contextText = iRunContextText(Params);
baselineReadoutSource = iAverageBaselineReadoutSource(baselineReadoutSourceSum, nBaselineCorrections);
baselineSuppressionDiag = iAverageBaselineSuppressionDiagnostic(baselineSuppressionDiagSum, nBaselineCorrections);
diagMessage = iBaselineFailureDiagnosticMessage(Mouse, Params, internalActivity, preL5RewardRecv, baselineReadoutSource, baselineSuppressionDiag);
error('THModel:BaselineTrainingIneffective', ...
	['Continuous rest baseline failed%s to reach %d consecutive no-behaviour iterations within %d iterations before trial %d. ', ...
	'Corrections = %d, final quiet streak = %d, last decision similarity = %.3f, max decision similarity = %.3f, threshold = %.3f. %s'], ...
	contextText, Params.BaselineQuietIterations, Params.MaxBaselineIterations, iTrial, nBaselineCorrections, quietCount, readoutDrive, maxBaselineDrive, Params.HitThreshold, diagMessage);
end

function diagMessage = iBaselineFailureDiagnosticMessage(Mouse, Params, internalActivity, directL5RewardInput, baselineReadoutSource, baselineSuppressionDiag)
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
readPattern = Mouse.L5ReadoutPattern(:);
readActivityNow = readActivity(:);
positiveReadoutMask = readPattern > 0;
zeroReadoutMask = readPattern <= 0;
positiveReadoutActivity = readActivityNow(positiveReadoutMask);
zeroReadoutActivity = readActivityNow(zeroReadoutMask);
positiveReadoutError = positiveReadoutActivity - 1;
zeroReadoutError = zeroReadoutActivity;
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
	'eligibility |all recurrent|=%.4g, target Read |E|=%.4g, target Read |I|=%.4g; ', ...
	'post-share allocation: Read columns targetRead/nonTargetRead/nonRead=%.3f/%.3f/%.3f, I columns targetRead/nonTargetRead/nonRead=%.3f/%.3f/%.3f; pre-column activity mean Read/I=%.3f/%.3f; ', ...
	'directed target Read dZ mean: RewardRecv=%.4g, Read recurrent=%.4g, E total=%.4g, I total=%.4g; ', ...
	'directed target Read |dZ|: E=%.4g, I=%.4g; Read recurrent punishment pre before/after/delta=%.4g/%.4g/%+.4g; ', ...
	'Read-column W allocation delta per pre cell: targetRead=%+.4g, allRead=%+.4g, nonRead=%+.4g; ', ...
	'I-column W allocation delta per pre cell: targetRead=%+.4g, allRead=%+.4g, nonRead=%+.4g; target Read I pre before/after/delta=%.4g/%.4g/%+.4g. '], ...
	baselineSuppressionDiag.ExcessDriveMean, baselineSuppressionDiag.StateDeltaMeanAbs, baselineSuppressionDiag.ReadDeltaMeanAbs, ...
	baselineSuppressionDiag.THDeltaMeanAbs, baselineSuppressionDiag.RewardRecvDeltaMeanAbs, baselineSuppressionDiag.IRewardRecvDeltaMeanAbs, ...
	baselineSuppressionDiag.RecurrentEligibilityMeanAbs, baselineSuppressionDiag.ReadTargetExcEligibilityMeanAbs, baselineSuppressionDiag.ReadTargetInhEligibilityMeanAbs, ...
	baselineSuppressionDiag.ReadColumnTargetReadPostShare, baselineSuppressionDiag.ReadColumnNonTargetReadPostShare, baselineSuppressionDiag.ReadColumnNonReadPostShare, ...
	baselineSuppressionDiag.InhColumnTargetReadPostShare, baselineSuppressionDiag.InhColumnNonTargetReadPostShare, baselineSuppressionDiag.InhColumnNonReadPostShare, ...
	baselineSuppressionDiag.ReadColumnBeforeMean, baselineSuppressionDiag.InhColumnBeforeMean, ...
	baselineSuppressionDiag.ReadTargetRewardRecvDeltaZMean, baselineSuppressionDiag.ReadTargetReadRecurrentDeltaZMean, ...
	baselineSuppressionDiag.ReadTargetExcDeltaZMean, baselineSuppressionDiag.ReadTargetInhDeltaZMean, ...
	baselineSuppressionDiag.ReadTargetExcDeltaZMeanAbs, baselineSuppressionDiag.ReadTargetInhDeltaZMeanAbs, ...
	baselineSuppressionDiag.ReadTargetReadRecurrentPreBefore, baselineSuppressionDiag.ReadTargetReadRecurrentPreAfter, baselineSuppressionDiag.ReadTargetReadRecurrentPreDelta, ...
	baselineSuppressionDiag.ReadColumnToTargetReadWeightDelta, baselineSuppressionDiag.ReadColumnToReadWeightDelta, baselineSuppressionDiag.ReadColumnToNonReadWeightDelta, ...
	baselineSuppressionDiag.InhColumnToTargetReadWeightDelta, baselineSuppressionDiag.InhColumnToReadWeightDelta, baselineSuppressionDiag.InhColumnToNonReadWeightDelta, ...
	baselineSuppressionDiag.TargetReadInhPreBefore, baselineSuppressionDiag.TargetReadInhPreAfter, baselineSuppressionDiag.TargetReadInhPreDelta);
diagMessage = sprintf(['Baseline diagnostics: rest direct L5 TH input mean/max=%.3f/%.3f; ', ...
	'L23 mean/max=%.3f/%.3f, RewardRecv mean/max=%.3f/%.3f, Read mean/max=%.3f/%.3f, ', ...
	'I mean/max=%.3f/%.3f, IL23 mean/max=%.3f/%.3f, IL5RewardRecvI mean/max=%.3f/%.3f; ', ...
	'IL5RewardRecvI drive: IL23 recurrent pre mean/min=%.4f/%.4f, IL23 recurrent |pre| mean/max=%.4f/%.4f; ', ...
	'%s%s%s', ...
	'weights: RewardRecv->Read mean/max=%.4f/%.4f, ', ...
	'Exc->Read mean/max=%.4f/%.4f, |I->Read| mean/max=%.4f/%.4f, |IL23->Read| mean/max=%.4f/%.4f, ', ...
	'|IL5RewardRecvI->Read| mean/max=%.4f/%.4f, |IL23->IL5RewardRecvI| mean/max=%.4f/%.4f.'], ...
	iMeanFlat(directL5RewardInput), iMaxFlat(directL5RewardInput), ...
	iMeanFlat(l23Activity), iMaxFlat(l23Activity), iMeanFlat(rewardRecvActivity), iMaxFlat(rewardRecvActivity), ...
	iMeanFlat(readActivity), iMaxFlat(readActivity), iMeanFlat(inhibitoryActivity), iMaxFlat(inhibitoryActivity), ...
	iMeanFlat(iL23Activity), iMaxFlat(iL23Activity), iMeanFlat(iRewardRecvActivity), iMaxFlat(iRewardRecvActivity), ...
	iMeanFlat(il23ToIL5RewardRecvIPre), iMinFlat(il23ToIL5RewardRecvIPre), ...
	iMeanFlat(abs(il23ToIL5RewardRecvIPre)), iMaxFlat(abs(il23ToIL5RewardRecvIPre)), ...
	readoutSplitText, sourceText, suppressionText, ...
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

function [rL23, rL5RewardRecv, rL5Read, internalActivity, readoutDriveTrace, thActivityHistory, rewardRecvActivityHistory, internalActivityHistory, preIL5RewardRecvHistory] = iRunDecisionNetwork(cueL23DriveHistory, preL5Read, Mouse, Params, Cond, initialInternalActivity)
if nargin < 6
	initialInternalActivity = [];
end
nDecisionState = size(cueL23DriveHistory, 2);
readoutDriveTrace = zeros(nDecisionState, 1);
thActivityHistory = iZeros([Params.NL5RewardRecv, nDecisionState], Params);
rewardRecvActivityHistory = iZeros([Params.NL5RewardRecv, nDecisionState], Params);
internalActivityHistory = iZeros([Params.NInternal, nDecisionState], Params);
preIL5RewardRecvHistory = iZeros([Params.NIL5RewardRecv, nDecisionState], Params);
internalActivity = initialInternalActivity;
lastDecisionState = nDecisionState;

for iState = 1:nDecisionState
	[preL5RewardRecv, preIL5RewardRecv] = iRunTHInput(Mouse, Params, Cond, "rest");
	thActivityHistory(:, iState) = preL5RewardRecv;
	preIL5RewardRecvHistory(:, iState) = preIL5RewardRecv;
	preL23Now = cueL23DriveHistory(:, iState);
	preIL23Now = Params.NoiseInput * iRandn(Params.NIL23, Params);
	externalPre = iBuildInternalPre(preL23Now, preL5RewardRecv, preL5Read, Params, preIL23Now, preIL5RewardRecv);
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
	readoutDriveTrace(iState) = iReadoutDrive(internalActivity, Mouse, Params);
	internalActivityHistory(:, iState) = internalActivity;
	[~, rewardRecvActivityNow] = iSplitInternalActivity(internalActivity, Params);
	rewardRecvActivityHistory(:, iState) = rewardRecvActivityNow;
	if readoutDriveTrace(iState) >= Params.HitThreshold
		lastDecisionState = iState;
		break;
	end
end

readoutDriveTrace = readoutDriveTrace(1:lastDecisionState);
thActivityHistory = thActivityHistory(:, 1:lastDecisionState);
rewardRecvActivityHistory = rewardRecvActivityHistory(:, 1:lastDecisionState);
internalActivityHistory = internalActivityHistory(:, 1:lastDecisionState);
preIL5RewardRecvHistory = preIL5RewardRecvHistory(:, 1:lastDecisionState);

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

function similarity = iReadoutPatternSimilarity(readoutActivity, readoutPattern, ~)
rootMeanSquaredError = iGatherScalar(sqrt(mean((readoutActivity(:) - readoutPattern(:)).^2)));
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

function eligInternal = iUpdateTaskLearningHistoryEligibility(eligInternal, decisionActivityHistory, learningActivityHistory, Params)
trialActivityHistory = [decisionActivityHistory, learningActivityHistory];
eligInternal = iUpdateInternalHistoryEligibility(eligInternal, trialActivityHistory, Params);
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

function eligibilityTrace = iRecurrentCellEligibilityToSynapseEligibility(cellEligibility, Params)
postNumerator = repmat(cellEligibility.After(:), 1, Params.NInternal);
postNumerator = iZeroSelfProjection(postNumerator);
postShare = postNumerator ./ sum(postNumerator, 1);
eligibilityTrace = postShare .* cellEligibility.Before(:)';
eligibilityTrace = iZeroSelfProjection(eligibilityTrace);
end

function [accumulator, effectiveWeights] = iApplyLatentInternalTrace(accumulator, eligibilityTrace, eta, Params, isPunishment)
eligibilityTrace = iLearningDirectedInternalEligibility(eligibilityTrace, Params, isPunishment);
accumulator = iShiftRecurrentColumnsToNonnegative(accumulator + eta * eligibilityTrace);
effectiveWeights = iAccumulatorToInternalWeight(accumulator, Params);
end

function eligibilityTrace = iLearningDirectedInternalEligibility(eligibilityTrace, Params, isPunishment)
inhCols = Params.NL23L5 + (1:Params.NIInternal);
eligibilityTrace(:, inhCols) = -eligibilityTrace(:, inhCols);
if isPunishment
	eligibilityTrace = -eligibilityTrace;
end
end

function [Mouse, correctionDiag] = iSuppressFalseReadout(Mouse, internalActivityBefore, internalActivityAfter, falseDrive, Params, thActivityBefore, thActivityAfter, rewardRecvActivityBefore, rewardRecvActivityAfter, iRewardRecvActivityBefore, iRewardRecvActivityAfter)
eta = Params.HebbRate * Params.EligibilityTraceScale;
isPunishment = true;
eligInternal = iZeroCellEligibility(Params.NInternal, Params.NInternal, Params);
eligInternal = iUpdateRecurrentEligibility(eligInternal, internalActivityBefore, internalActivityAfter, Params.EligibilityDecay, Params);
eligInternalToInternal = iRecurrentCellEligibilityToSynapseEligibility(eligInternal, Params);

correctionDiag = iBaselineSuppressionCorrectionDiagnostic(Mouse, Params, falseDrive, internalActivityBefore, internalActivityAfter, thActivityBefore, thActivityAfter, rewardRecvActivityBefore, rewardRecvActivityAfter, iRewardRecvActivityBefore, iRewardRecvActivityAfter, eligInternalToInternal, eta, isPunishment);
[Mouse.Z_InternalToInternal, Mouse.W_InternalToInternal] = iApplyLatentInternalTrace(Mouse.Z_InternalToInternal, eligInternalToInternal, eta, Params, isPunishment);
end

function correctionDiag = iBaselineSuppressionCorrectionDiagnostic(Mouse, Params, falseDrive, internalActivityBefore, internalActivityAfter, thActivityBefore, thActivityAfter, rewardRecvActivityBefore, rewardRecvActivityAfter, iRewardRecvActivityBefore, iRewardRecvActivityAfter, eligInternalToInternal, eta, isPunishment)
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
directedInternalDeltaZ = internalAccumulatorAfter - Mouse.Z_InternalToInternal;
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

function effectiveWeights = iAccumulatorToInhibitoryOutputWeight(accumulator, cap, ~)
effectiveWeights = -cap * iColumnDistribution(accumulator);
end

function distribution = iColumnDistribution(accumulator)
distribution = accumulator ./ sum(accumulator, 1);
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
Mouse.Z_InternalToInternal = iShiftRecurrentColumnsToNonnegative(ret * Mouse.Z_InternalToInternal + sd * iRandn(size(Mouse.Z_InternalToInternal), Params));
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
	values = gpuArray.randn(sz(1), sz(2));
else
	values = randn(sz);
end
end

function values = iRand(sz, Params)
if isscalar(sz)
	sz = [sz, 1];
end
if iUseGPU(Params)
	values = gpuArray.rand(sz(1), sz(2));
else
	values = rand(sz);
end
end

function values = iZeros(sz, Params)
if isscalar(sz)
	sz = [sz, 1];
end
if iUseGPU(Params)
	values = gpuArray.zeros(sz(1), sz(2));
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

function pattern = iVertexPattern(patternSeed)
pattern = 1.0 * (patternSeed(:) > 0);
end

function pattern = iMaskToVertexPattern(mask, Params)
pattern = iZeros(size(mask), Params);
pattern(mask(:)) = 1;
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
	if isempty(x)
		text(ax, iCond, 0, 'n=0', 'HorizontalAlignment', 'center', ...
			'VerticalAlignment', 'bottom', 'FontSize', 12, 'Color', Cond.Color(iCond, :));
		continue;
	end
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

p12 = NaN;
p23 = NaN;
p13 = NaN;
pAll = NaN;
if ~isempty(naive) && ~isempty(transfer)
	p12 = ranksum(naive, transfer);
end
if ~isempty(transfer) && ~isempty(thOff)
	p23 = ranksum(transfer, thOff);
end
if ~isempty(naive) && ~isempty(thOff)
	p13 = ranksum(naive, thOff);
end
groupValues = [naive; transfer; thOff];
groupLabels = [repmat(cellstr(Cond.Label(1)), numel(naive), 1); repmat(cellstr(Cond.Label(2)), numel(transfer), 1); repmat(cellstr(Cond.Label(3)), numel(thOff), 1)];
if numel(unique(groupLabels)) >= 2
	pAll = kruskalwallis(groupValues, groupLabels, 'off');
end

yAll = [naive; transfer; thOff];
if isempty(yAll)
	return;
end
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