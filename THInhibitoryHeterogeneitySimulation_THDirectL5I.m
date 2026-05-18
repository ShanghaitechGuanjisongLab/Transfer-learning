% THInhibitoryHeterogeneitySimulation_THDirectL5I branch
%
% Minimal rate-model simulation for three qualitative findings:
% 1) transfer starts from a higher first-session performance than naive,
% 2) reward-dependent L5 recruitment increases process-averaged response heterogeneity,
% 3) transfer has the highest L5 heterogeneity and fitted learning slope.
%
% The model contains:
% - excitatory populations in L2/3 and L5,
% - an explicit inhibitory population driven by cortical excitation,
% - an explicit cue-input pathway,
% - a reusable schema state acquired by pre-training on an alternate cue,
% - a TH-inhibited group implemented as reward-cell silence during the new task.
% Branch change: reward/TH input also directly drives the L5 inhibitory pools.

if evalin('base', 'exist(''THRandomSeed'', ''var'')')
	rng(evalin('base', 'THRandomSeed'));
else
	rng('shuffle');
end

networkOutputRoot = '\\Data-Server-2\个人数据\张天夫';
localOutputRoot = fullfile(fileparts(mfilename('fullpath')), 'resources');
if isfolder(networkOutputRoot)
	outDir = fullfile(networkOutputRoot, char(datetime('now', 'Format', 'yyyyMM')));
else
	outDir = fullfile(localOutputRoot, char(datetime('now', 'Format', 'yyyyMM')));
end
outputNameSuffix = iOutputNameSuffix();
svgName = iTaggedSvgName('TH_Branch_Direct_L5I_Inhibitory_Heterogeneity_Model.svg', outputNameSuffix);
preWeightDistributionSvgName = iTaggedSvgName('TH_Branch_Direct_L5I_PreFormal_Naive_Transfer_Connection_Weight_Distribution.svg', outputNameSuffix);
weightSvgName = iTaggedSvgName('TH_Branch_Direct_L5I_Formal_Training_Connection_Type_Weight_SD.svg', outputNameSuffix);
sigmoidSvgName = iTaggedSvgName('TH_Branch_Direct_L5I_Sigmoid_Fit_Slope.svg', outputNameSuffix);

Params = iDefaultParams();
Params = iApplyBaseParameterOverrides(Params);
if evalin('base', 'exist(''THRandomSeed'', ''var'')')
	Params.RandomSeed = evalin('base', 'THRandomSeed');
end
Cond = iConditionTable();
if evalin('base', 'exist(''THDebugNonnegativeFormalFailure'', ''var'') && THDebugNonnegativeFormalFailure')
	DebugReport = iRunNonnegativeFormalFailureDebug(Params, Cond);
	assignin('base', 'THNonnegativeFormalFailureDebug', DebugReport);
	return;
end
workspaceVarNames = iWorkspaceVariableNames(outputNameSuffix);
if iHasReusableWorkspaceSummary(workspaceVarNames, Params)
	Summary = evalin('base', workspaceVarNames.Summary);
	if evalin('base', sprintf('exist(''%s'', ''var'')', workspaceVarNames.Params)) == 1
		Params = evalin('base', workspaceVarNames.Params);
	end
	if evalin('base', sprintf('exist(''%s'', ''var'')', workspaceVarNames.Cond)) == 1
		Cond = evalin('base', workspaceVarNames.Cond);
	end
	fprintf('Using workspace variable %s for plotting; clear it to retrain.\n', workspaceVarNames.Summary);
else
	iPrepareParallelWorkers();
	Summary = iRunCohortModel(Params, Cond);
end
iStoreWorkspaceRun(Summary, Params, Cond, workspaceVarNames);

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
f = figure('Color', 'w', 'Name', 'TH direct L5 inhibitory input branch model');
f.Units = 'centimeters';
f.Position(3:4) = [18, 7];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 18, 7];
f.PaperSize = [18, 7];

tl = tiledlayout(f, 1, 3, 'TileSpacing', 'loose', 'Padding', 'compact');

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
iStripMeanSem(ax2, Summary.PerMouse, Cond, 'MeanH5');
iAnnotateMetricStats(ax2, Summary.PerMouse, Cond, 'MeanH5');
iStyleScatterPanel(ax2);
xlabel(ax2, '', 'FontSize', 12);
ylabel(ax2, 'Mean L5 heterogeneity', 'FontSize', 12);
title(ax2, 'L5 heterogeneity', 'FontSize', 12, 'FontWeight', 'normal');
ax2.XTickLabel = {};
ax2.XTickLabelRotation = 0;

ax3 = nexttile(tl, 3);
hold(ax3, 'on');
iStripMeanSem(ax3, Summary.PerMouse, Cond, 'Slope');
iAnnotateMetricStats(ax3, Summary.PerMouse, Cond, 'Slope');
iStyleScatterPanel(ax3);
xlabel(ax3, '', 'FontSize', 12);
ylabel(ax3, 'Learning slope', 'FontSize', 12);
title(ax3, 'Learning slope', 'FontSize', 12, 'FontWeight', 'normal');
ax3.XTickLabel = {};
ax3.XTickLabelRotation = 0;

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

preWeightDistributionFig = iPlotPreFormalConnectionWeightDistributions(Summary, Cond);
preWeightDistributionSvgPath = fullfile(outDir, preWeightDistributionSvgName);
print(preWeightDistributionFig, preWeightDistributionSvgPath, '-dsvg', '-painters');
fprintf('Wrote: %s\n', preWeightDistributionSvgPath);

weightFig = iPlotFormalTrainingConnectionWeightStats(Summary, Cond);
weightSvgPath = fullfile(outDir, weightSvgName);
print(weightFig, weightSvgPath, '-dsvg', '-painters');
fprintf('Wrote: %s\n', weightSvgPath);

[sigmoidFig, SigmoidStats] = iPlotSigmoidFitSlopeFigure(Summary, Cond);
sigmoidSvgPath = fullfile(outDir, sigmoidSvgName);
print(sigmoidFig, sigmoidSvgPath, '-dsvg', '-painters');
sigmoidWorkspaceName = char("THInhibitoryHeterogeneitySigmoidFitSlopeTHDirectL5I" + iWorkspaceNameSuffix(outputNameSuffix));
assignin('base', sigmoidWorkspaceName, SigmoidStats);
iCheckTransferSignificantlyHighest(Summary.PerMouse, SigmoidStats, Cond, Params);
fprintf('Wrote: %s\n', sigmoidSvgPath);

function outputNameSuffix = iOutputNameSuffix()
outputNameSuffix = "";
if evalin('base', 'exist(''THOutputNameSuffix'', ''var'')') == 1
	outputNameSuffix = string(evalin('base', 'THOutputNameSuffix'));
end
outputNameSuffix = strtrim(outputNameSuffix);
if strlength(outputNameSuffix) > 0
	outputNameSuffix = regexprep(outputNameSuffix, '[^A-Za-z0-9_\-]', '_');
	outputNameSuffix = regexprep(outputNameSuffix, '_+', '_');
end
end

function svgName = iTaggedSvgName(baseName, outputNameSuffix)
if strlength(outputNameSuffix) == 0
	svgName = baseName;
	return;
end
[~, fileStem, fileExt] = fileparts(baseName);
svgName = char(fileStem + "_" + outputNameSuffix + fileExt);
end

function workspaceVarNames = iWorkspaceVariableNames(outputNameSuffix)
workspaceSuffix = iWorkspaceNameSuffix(outputNameSuffix);
workspaceVarNames.Summary = char("THInhibitoryHeterogeneityModelTHDirectL5I" + workspaceSuffix);
workspaceVarNames.Params = char("THInhibitoryHeterogeneityParamsTHDirectL5I" + workspaceSuffix);
workspaceVarNames.Cond = char("THInhibitoryHeterogeneityConditionsTHDirectL5I" + workspaceSuffix);
end

function workspaceSuffix = iWorkspaceNameSuffix(outputNameSuffix)
if strlength(outputNameSuffix) == 0
	workspaceSuffix = "";
	return;
end
workspaceSuffix = "_" + regexprep(outputNameSuffix, '[^A-Za-z0-9_]', '_');
end

function tf = iHasReusableWorkspaceSummary(workspaceVarNames, Params)
if evalin('base', sprintf('exist(''%s'', ''var'')', workspaceVarNames.Summary)) ~= 1
	tf = false;
	return;
end
if evalin('base', sprintf('exist(''%s'', ''var'')', workspaceVarNames.Params)) ~= 1
	tf = false;
	return;
end
Summary = evalin('base', workspaceVarNames.Summary);
storedParams = evalin('base', workspaceVarNames.Params);
tf = isstruct(Summary) ...
	&& isstruct(storedParams) ...
	&& isequaln(storedParams, Params) ...
	&& isfield(Summary, 'Performance') ...
	&& isfield(Summary, 'PerMouse') ...
	&& isfield(Summary, 'CorrMouse') ...
	&& isfield(Summary, 'FormalTrainingConnectionWeights') ...
	&& isfield(Summary, 'FormalTrainingConnectionWeightMouseStd') ...
	&& isfield(Summary, 'FormalTrainingConnectionWeightStats') ...
	&& isfield(Summary, 'FormalTrainingConnectionWeightClassification') ...
	&& isfield(Summary.FormalTrainingConnectionWeightStats, 'EE') ...
	&& isfield(Summary.FormalTrainingConnectionWeightStats, 'II') ...
	&& string(Summary.FormalTrainingConnectionWeightClassification) == iFormalTrainingConnectionWeightClassification();
end

function iStoreWorkspaceRun(Summary, Params, Cond, workspaceVarNames)
assignin('base', workspaceVarNames.Summary, Summary);
assignin('base', workspaceVarNames.Params, Params);
assignin('base', workspaceVarNames.Cond, Cond);
end

function iPrepareParallelWorkers()
ParallelComputing.ParPool(20);
end

function classification = iFormalTrainingConnectionWeightClassification()
classification = "branch_TH-direct-L5I-pools_connection-type_EE-EI-IE-II_mouse-level-sd_random-plastic-wii_formal-hebb-mouse-var_itoi-v1";
end

function Params = iDefaultParams()
% Cue/reward inputs plus three modeled cortical populations:
%   CueIn    (sensory cue input vector, not counted as L2/3 activity)
%   L23      (L2/3 population receiving CueIn through a plastic afferent map)
%   Reward   (reward input cells, independent from L5)
%   L5RewardRecv (L5 cells receiving L2/3 and Reward input)
%   L5Read   (L5 behavioural readout cells with task-shaped I-pool)
% One plastic E-E matrix spans all L2/3 and L5 cells. It is structurally
% all-to-all except for the diagonal self-projections.
% Decision phase uses sensory cue input only; L2/3 receives this input,
% then all L2/3/L5 populations settle through the recurrent internal
% projection. During learning, reward and readout feedback are added to the
% settled cue-decision network state; Reward input drives L5RewardRecv through
% a plastic afferent map, and readout drive remains a one-way input to L5Read.
% Learning phase applies outer-product Hebbian updates on cue-to-L2/3,
% reward-to-L5RewardRecv, and recurrent internal matrices plus cell-specific
% inhibitory WIE/WEI plasticity in L23/L5RewardRecv/L5Read pathways.
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
Params.NIL5Read = 16;
Params.ResponseScale = 1.45;
Params.NoiseCue = 0.70;             % input + L2/3 pre-noise together roughly match cue signal scale
Params.NoiseRew = 0.15;
Params.NoiseRead = 0.12;
Params.Comp_Cue = 0.95;
Params.Comp_Rew = 1.00;
Params.Comp_Read = 1.20;
% Input gains
Params.CueInputGain = 1.00;          % sensory cue drive (decision + learning)
Params.CueInputGainPretrain = 1.40;  % pretraining cue gain
Params.RewInputGain = 1.45;          % reward pattern clamp amplitude (learning phase only)
Params.THRewardRecvInputGain = 1.50; % reward/TH-gated direct L5RewardRecv teaching drive
Params.THL5RewardRecvIInputGain = 0.20; % reward/TH-gated direct drive to the L5RewardRecv inhibitory pool
Params.THL5ReadIInputGain = 0.20; % reward/TH-gated direct drive to the L5Read inhibitory pool
Params.ReadInputGain = 0.00;         % baseline readout pattern clamp amplitude (learning phase only)
Params.THReadInputGain = 2.80;       % reward/TH-gated extra readout teaching amplitude
Params.THReadHeterogeneityGain = 2.50; % reward/TH-gated L5Read heterogeneity teaching amplitude
% Decision readout: initial input noise creates trial-to-trial variability,
% and a hit is emitted when the readout crosses HitThreshold.
Params.HitThreshold = 0.35;
Params.Ceiling = 1.00;
% Slope fit: drop sessions from the first 100%-hit session onward
% (that session and every subsequent one) so the plateau at 1.0 does
% not compress the slope of fast learners.
Params.SlopeHitPerfect = 1.00;
Params.TransferHighestAlpha = 0.05;
% Plastic weights: zero-mean init, symmetric caps.
Params.InitWStd = 0.03;
Params.WCap = 1.20;
Params.AfferentWCap = 1.20;
Params.RewardAfferentNorm = 1.00;
Params.ClampNegativePlasticWeightsToZero = true;
% Number of recurrent internal passes after external cue/reward/readout drive.
Params.InternalRecurrentPasses = 2;
% Per-trial Hebbian rate. With NumTrials=30 per session, total within-
% session increase ≈ 30 * HebbRate * mouse-level eta factor.
Params.HebbRate = 0.0085;
Params.RandomSeed = NaN;
Params.FormalHebbGainStd = 0.35;
Params.FormalHebbGainMin = 0.65;
Params.FormalHebbGainMax = 1.55;
% Inhibitory plasticity: InhGain is retired; WIE/WEI carry cell-specific plasticity.
Params.InhPlasticityRate = 0.0035;
Params.InhTargetAct = 0.00;
Params.InhWeightMin = 0.00;
Params.InhWeightMax = 3.00;
Params.InitWIIBase = 0.35;
Params.InitWIIStd = 0.08;
Params.IToIGain = 0.50;
Params.IToIPasses = 2;
% Cross-modality overlap between pretraining cue input (e.g. sound) and new
% cue input (e.g. light). Real sensory drives are never fully orthogonal;
% each cue-input dimension has a shared component plus a modality-unique
% component. The fixed CueIn->L23 map turns this sensory overlap into
% partially overlapping L2/3 responses.
% Correlation between CueInputPattern and PreCueInputPattern = CueModalityCorr.
Params.CueModalityCorr = 0.62;
% Overnight consolidation
Params.OvernightRetention = 0.96;
Params.OvernightNoise = 0.002;
% Pretraining
Params.MaxPretrainSessions = 150;
Params.PostCeilingSessions = 2;
end

function Params = iApplyBaseParameterOverrides(Params)
if evalin('base', 'exist(''THParamOverrides'', ''var'')') ~= 1
	return;
end
paramOverrides = evalin('base', 'THParamOverrides');
if isempty(paramOverrides)
	return;
end
if ~isstruct(paramOverrides)
	error('THModel:InvalidParameterOverrides', 'THParamOverrides must be a scalar struct.');
end
protectedFieldNames = ["NumMice", "NumSessions", "NumTrials", "MaxPretrainSessions", "PostCeilingSessions", "HitThreshold", "Ceiling", "SlopeHitPerfect", "TransferHighestAlpha"];
fieldNames = fieldnames(paramOverrides);
for iField = 1:numel(fieldNames)
	fieldName = fieldNames{iField};
	if any(string(fieldName) == protectedFieldNames)
		error('THModel:ProtectedParameterOverride', 'THParamOverrides may not override gated/acceptance parameter: %s.', fieldName);
	end
	if ~isfield(Params, fieldName)
		error('THModel:UnknownParameterOverride', 'Unknown THParamOverrides field: %s.', fieldName);
	end
	fieldValue = paramOverrides.(fieldName);
	if ~isnumeric(fieldValue) || ~isscalar(fieldValue) || ~isfinite(fieldValue)
		error('THModel:InvalidParameterOverrideValue', 'THParamOverrides.%s must be a finite numeric scalar.', fieldName);
	end
	Params.(fieldName) = fieldValue;
end
if Params.HitThreshold >= Params.ResponseScale
	error('THModel:InvalidDecisionThreshold', 'HitThreshold must be below ResponseScale.');
end
end

function Cond = iConditionTable()
Cond = table;
Cond.Name = ["Naive"; "Transfer"; "THOff"];
Cond.Label = ["Naive"; "Transfer"; "TH inhibited"];
Cond.Color = [1, 0, 0; 0, 0, 1; 0, 0, 0];
Cond.RewardInputLevel = [1.00; 1.00; 0.00];
end

function iSeedMouseIfRequested(Params, condName, iMouse)
if ~isfield(Params, 'RandomSeed') || ~isfinite(Params.RandomSeed)
	return;
end
conditionNames = ["Naive", "Transfer", "THOff"];
conditionIdx = find(conditionNames == string(condName), 1);
if isempty(conditionIdx)
	conditionIdx = 0;
end
rng(Params.RandomSeed + 100000 * conditionIdx + iMouse);
end

function DebugReport = iRunNonnegativeFormalFailureDebug(Params, Cond)
numDebugMice = 1;
if evalin('base', 'exist(''THDebugNumMice'', ''var'')') == 1
	numDebugMice = evalin('base', 'THDebugNumMice');
end
numFormalDiagnosticSessions = Params.NumSessions;
if evalin('base', 'exist(''THDebugFormalSessions'', ''var'')') == 1
	numFormalDiagnosticSessions = evalin('base', 'THDebugFormalSessions');
end
debugConditionNames = Cond.Name;
if evalin('base', 'exist(''THDebugConditionNames'', ''var'')') == 1
	debugConditionNames = string(evalin('base', 'THDebugConditionNames'));
end
rows = struct([]);
fprintf('\n=== Nonnegative formal failure debug ===\n');
if numDebugMice > 1
	iPrepareParallelWorkers();
end
for iCond = 1:height(Cond)
	condRow = Cond(iCond, :);
	condName = Cond.Name(iCond);
	if ~any(condName == debugConditionNames)
		continue;
	end
	conditionRows = cell(numDebugMice, 1);
	if numDebugMice > 1
		parfor iMouse = 1:numDebugMice
			conditionRows{iMouse} = iRunNonnegativeFormalFailureMouse(Params, condRow, condName, iMouse, numFormalDiagnosticSessions);
		end
	else
		conditionRows{1} = iRunNonnegativeFormalFailureMouse(Params, condRow, condName, 1, numFormalDiagnosticSessions);
	end
	rows = [rows; vertcat(conditionRows{:})]; %#ok<AGROW>
end
DebugReport.MouseTable = struct2table(rows);
DebugReport.ConditionSummary = iNonnegativeFormalFailureConditionSummary(DebugReport.MouseTable, Cond);
disp(DebugReport.ConditionSummary);
end

function row = iRunNonnegativeFormalFailureMouse(Params, condRow, condName, iMouse, numFormalDiagnosticSessions)
iSeedMouseIfRequested(Params, condName, iMouse);
Mouse = iDrawMouse(Params);
pretrainPerf = NaN;
pretrainSessions = 0;
if condName ~= "Naive"
	[Mouse, pretrainPerfTrace] = iPretrainMouseWithTrace(Mouse, Params);
	pretrainSessions = numel(pretrainPerfTrace);
	pretrainPerf = pretrainPerfTrace(end);
end
preDiag = iDecisionProbeSet(Mouse, Params, condRow);
preWeights = iPlasticWeightDebugSummary(Mouse, Params);
formalPerf = nan(1, numFormalDiagnosticSessions);
sessionMeanL5 = nan(Params.NL5, numFormalDiagnosticSessions);
sessionMeanL5RewardRecv = nan(Params.NL5RewardRecv, numFormalDiagnosticSessions);
sessionMeanL5Read = nan(Params.NL5Read, numFormalDiagnosticSessions);
[formalPerf(1), Signals, ~, Mouse] = iSimulateSession(Mouse, Params, condRow, false);
sessionMeanL5(:, 1) = Signals.ProcessMeanL5;
sessionMeanL5RewardRecv(:, 1) = Signals.ProcessMeanL5RewardRecv;
sessionMeanL5Read(:, 1) = Signals.ProcessMeanL5Read;
afterFirstDiag = iDecisionProbeSet(Mouse, Params, condRow);
for iSess = 2:numFormalDiagnosticSessions
	Mouse = iOvernightConsolidate(Mouse, Params);
	[formalPerf(iSess), Signals, ~, Mouse] = iSimulateSession(Mouse, Params, condRow, false);
	sessionMeanL5(:, iSess) = Signals.ProcessMeanL5;
	sessionMeanL5RewardRecv(:, iSess) = Signals.ProcessMeanL5RewardRecv;
	sessionMeanL5Read(:, iSess) = Signals.ProcessMeanL5Read;
end
finalDiag = iDecisionProbeSet(Mouse, Params, condRow);
finalWeights = iPlasticWeightDebugSummary(Mouse, Params);
formalMeanH5 = iRestrictedStd(mean(sessionMeanL5, 2, 'omitnan'));
formalMeanH5RewardRecv = iRestrictedStd(mean(sessionMeanL5RewardRecv, 2, 'omitnan'));
formalMeanH5Read = iRestrictedStd(mean(sessionMeanL5Read, 2, 'omitnan'));
row = iNonnegativeFormalFailureRow(condName, iMouse, pretrainSessions, pretrainPerf, formalPerf, formalMeanH5, formalMeanH5RewardRecv, formalMeanH5Read, preDiag, afterFirstDiag, finalDiag, preWeights, finalWeights, Mouse);
end

function [Mouse, perfTrace] = iPretrainMouseWithTrace(Mouse, Params)
pretrainCond.RewardInputLevel = 1.00;
perfTrace = nan(Params.MaxPretrainSessions, 1);
postCeilingCount = 0;
for iSess = 1:Params.MaxPretrainSessions
	[perfObserved, ~, perfExpected, Mouse] = iSimulateSession(Mouse, Params, pretrainCond, true);
	perfTrace(iSess) = perfObserved;
	if perfObserved >= Params.Ceiling || perfExpected >= Params.Ceiling - 2 / Params.NumTrials
		postCeilingCount = postCeilingCount + 1;
		if postCeilingCount >= Params.PostCeilingSessions
			perfTrace = perfTrace(1:iSess);
			return;
		end
	end
	Mouse = iOvernightConsolidate(Mouse, Params);
end
error('THModel:PretrainDidNotReachCeiling', 'Debug pretraining did not reach ceiling within %d sessions. Final observed hit = %.3f.', Params.MaxPretrainSessions, perfTrace(end));
end

function row = iNonnegativeFormalFailureRow(condName, iMouse, pretrainSessions, pretrainPerf, formalPerf, formalMeanH5, formalMeanH5RewardRecv, formalMeanH5Read, preDiag, afterFirstDiag, finalDiag, preWeights, finalWeights, ~)
row.Condition = condName;
row.Mouse = iMouse;
row.PretrainSessions = pretrainSessions;
row.PretrainFinalPerf = pretrainPerf;
row.FormalPerfFirst = formalPerf(1);
row.FormalPerfAtNominalLast = formalPerf(min(numel(formalPerf), 8));
row.FormalPerfLast = formalPerf(end);
row.FormalPerfAUC = mean(formalPerf, 'omitnan');
row.FormalMeanH5 = formalMeanH5;
row.FormalMeanH5RewardRecv = formalMeanH5RewardRecv;
row.FormalMeanH5Read = formalMeanH5Read;
firstHitSession = find(formalPerf >= 0.5, 1, 'first');
if isempty(firstHitSession)
	firstHitSession = NaN;
end
row.FormalFirstSessionAboveHalf = firstHitSession;
row.PreCueDriveBeforeFormal = preDiag.PreCueDrive;
row.FormalCueDriveBeforeFormal = preDiag.FormalCueDrive;
row.FormalCueDriveAfterFirst = afterFirstDiag.FormalCueDrive;
row.FormalCueDriveFinal = finalDiag.FormalCueDrive;
row.FormalCueDriveNoInhBeforeFormal = preDiag.FormalCueDriveNoInh;
row.FormalCueDriveNoInhFinal = finalDiag.FormalCueDriveNoInh;
row.RewardDriveBeforeFormal = preDiag.RewardDrive;
row.RewardDriveFinal = finalDiag.RewardDrive;
row.RandomCueHitFractionBeforeFormal = preDiag.RandomCueHitFraction;
row.RandomCueMaxDriveBeforeFormal = preDiag.RandomCueMaxDrive;
row.CueWeightZeroFractionBeforeFormal = preWeights.CueZeroFraction;
row.CueWeightZeroFractionFinal = finalWeights.CueZeroFraction;
row.InternalWeightZeroFractionBeforeFormal = preWeights.InternalZeroFraction;
row.InternalWeightZeroFractionFinal = finalWeights.InternalZeroFraction;
row.InternalWeightCapFractionBeforeFormal = preWeights.InternalCapFraction;
row.InternalWeightCapFractionFinal = finalWeights.InternalCapFraction;
row.CueWeightMeanBeforeFormal = preWeights.CueMean;
row.CueWeightMeanFinal = finalWeights.CueMean;
row.InternalWeightMeanBeforeFormal = preWeights.InternalMean;
row.InternalWeightMeanFinal = finalWeights.InternalMean;
row.L5ReadWIEMeanBeforeFormal = preWeights.L5ReadWIEMean;
row.L5ReadWIEMeanFinal = finalWeights.L5ReadWIEMean;
row.L5ReadWEIMeanBeforeFormal = preWeights.L5ReadWEIMean;
row.L5ReadWEIMeanFinal = finalWeights.L5ReadWEIMean;
row.L5ReadWEIZeroFractionFinal = finalWeights.L5ReadWEIZeroFraction;
row.L5ReadWEICapFractionFinal = finalWeights.L5ReadWEICapFraction;
end

function conditionSummary = iNonnegativeFormalFailureConditionSummary(mouseTable, Cond)
summaryRows = struct([]);
for iCond = 1:height(Cond)
	condName = Cond.Name(iCond);
	mask = mouseTable.Condition == condName;
	condTable = mouseTable(mask, :);
	summaryRow.Condition = condName;
	summaryRow.PretrainSessionsMean = mean(condTable.PretrainSessions, 'omitnan');
	summaryRow.PretrainFinalPerfMean = mean(condTable.PretrainFinalPerf, 'omitnan');
	summaryRow.FormalPerfFirstMean = mean(condTable.FormalPerfFirst, 'omitnan');
	summaryRow.FormalPerfAtNominalLastMean = mean(condTable.FormalPerfAtNominalLast, 'omitnan');
	summaryRow.FormalPerfLastMean = mean(condTable.FormalPerfLast, 'omitnan');
	summaryRow.FormalPerfAUCMean = mean(condTable.FormalPerfAUC, 'omitnan');
	summaryRow.FormalMeanH5Mean = mean(condTable.FormalMeanH5, 'omitnan');
	summaryRow.FormalMeanH5RewardRecvMean = mean(condTable.FormalMeanH5RewardRecv, 'omitnan');
	summaryRow.FormalMeanH5ReadMean = mean(condTable.FormalMeanH5Read, 'omitnan');
	summaryRow.FormalFirstSessionAboveHalfMean = mean(condTable.FormalFirstSessionAboveHalf, 'omitnan');
	summaryRow.PreCueDriveBeforeFormalMean = mean(condTable.PreCueDriveBeforeFormal, 'omitnan');
	summaryRow.FormalCueDriveBeforeFormalMean = mean(condTable.FormalCueDriveBeforeFormal, 'omitnan');
	summaryRow.FormalCueDriveAfterFirstMean = mean(condTable.FormalCueDriveAfterFirst, 'omitnan');
	summaryRow.FormalCueDriveFinalMean = mean(condTable.FormalCueDriveFinal, 'omitnan');
	summaryRow.FormalCueDriveNoInhBeforeFormalMean = mean(condTable.FormalCueDriveNoInhBeforeFormal, 'omitnan');
	summaryRow.FormalCueDriveNoInhFinalMean = mean(condTable.FormalCueDriveNoInhFinal, 'omitnan');
	summaryRow.RewardDriveBeforeFormalMean = mean(condTable.RewardDriveBeforeFormal, 'omitnan');
	summaryRow.RandomCueHitFractionBeforeFormalMean = mean(condTable.RandomCueHitFractionBeforeFormal, 'omitnan');
	summaryRow.CueWeightZeroFractionBeforeFormalMean = mean(condTable.CueWeightZeroFractionBeforeFormal, 'omitnan');
	summaryRow.CueWeightZeroFractionFinalMean = mean(condTable.CueWeightZeroFractionFinal, 'omitnan');
	summaryRow.InternalWeightZeroFractionBeforeFormalMean = mean(condTable.InternalWeightZeroFractionBeforeFormal, 'omitnan');
	summaryRow.InternalWeightZeroFractionFinalMean = mean(condTable.InternalWeightZeroFractionFinal, 'omitnan');
	summaryRow.InternalWeightCapFractionFinalMean = mean(condTable.InternalWeightCapFractionFinal, 'omitnan');
	summaryRow.L5ReadWIEMeanBeforeFormalMean = mean(condTable.L5ReadWIEMeanBeforeFormal, 'omitnan');
	summaryRow.L5ReadWIEMeanFinalMean = mean(condTable.L5ReadWIEMeanFinal, 'omitnan');
	summaryRow.L5ReadWEIMeanBeforeFormalMean = mean(condTable.L5ReadWEIMeanBeforeFormal, 'omitnan');
	summaryRow.L5ReadWEIMeanFinalMean = mean(condTable.L5ReadWEIMeanFinal, 'omitnan');
	summaryRow.L5ReadWEIZeroFractionFinalMean = mean(condTable.L5ReadWEIZeroFractionFinal, 'omitnan');
	summaryRow.L5ReadWEICapFractionFinalMean = mean(condTable.L5ReadWEICapFractionFinal, 'omitnan');
	summaryRows = [summaryRows; summaryRow]; %#ok<AGROW>
end
conditionSummary = struct2table(summaryRows);
end

function diag = iDecisionProbeSet(Mouse, Params, Cond)
diag.PreCueDrive = iCueDecisionProbe(Mouse, Params, true);
diag.FormalCueDrive = iCueDecisionProbe(Mouse, Params, false);
diag.FormalCueDriveNoInh = iCueDecisionProbeNoLocalInh(Mouse, Params, false);
diag.RewardDrive = iRewardReadoutProbe(Mouse, Params, Cond);
	[randomMean, randomMax, randomHitFraction] = iRandomCueDecisionStats(Mouse, Params, 30);
diag.RandomCueMeanDrive = randomMean;
diag.RandomCueMaxDrive = randomMax;
diag.RandomCueHitFraction = randomHitFraction;
end

function drive = iCueDecisionProbe(Mouse, Params, usePreCue)
ProbeParams = Params;
ProbeParams.NoiseCue = 0;
ProbeParams.NoiseRew = 0;
ProbeParams.NoiseRead = 0;
if usePreCue
	cueInputPat = Mouse.PreCueInputPattern;
	cueGain = ProbeParams.CueInputGainPretrain;
else
	cueInputPat = Mouse.CueInputPattern;
	cueGain = ProbeParams.CueInputGain;
end
cueInput = cueGain * cueInputPat;
preL23 = Mouse.W_CueInputToL23 * cueInput;
preL5RewardRecv = iZeros([ProbeParams.NL5RewardRecv, 1], ProbeParams);
preL5Read = iZeros([ProbeParams.NL5Read, 1], ProbeParams);
[~, ~, rL5Read] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, ProbeParams);
drive = iGatherScalar(mean(Mouse.L5ReadoutPattern .* rL5Read));
end

function drive = iCueDecisionProbeNoLocalInh(Mouse, Params, usePreCue)
MouseNoInh = Mouse;
MouseNoInh.WIE_L23 = iZeros(size(Mouse.WIE_L23), Params);
MouseNoInh.WEI_L23 = iZeros(size(Mouse.WEI_L23), Params);
MouseNoInh.WII_L23 = iZeros(size(Mouse.WII_L23), Params);
MouseNoInh.WIE_L5RewardRecv = iZeros(size(Mouse.WIE_L5RewardRecv), Params);
MouseNoInh.WEI_L5RewardRecv = iZeros(size(Mouse.WEI_L5RewardRecv), Params);
MouseNoInh.WII_L5RewardRecv = iZeros(size(Mouse.WII_L5RewardRecv), Params);
MouseNoInh.WIE_L5Read = iZeros(size(Mouse.WIE_L5Read), Params);
MouseNoInh.WEI_L5Read = iZeros(size(Mouse.WEI_L5Read), Params);
MouseNoInh.WII_L5Read = iZeros(size(Mouse.WII_L5Read), Params);
drive = iCueDecisionProbe(MouseNoInh, Params, usePreCue);
end

function [randomMean, randomMax, randomHitFraction] = iRandomCueDecisionStats(Mouse, Params, numSamples)
drives = nan(numSamples, 1);
ProbeParams = Params;
ProbeParams.NoiseCue = 0;
ProbeParams.NoiseRew = 0;
ProbeParams.NoiseRead = 0;
for iSample = 1:numSamples
	cueInput = ProbeParams.CueInputGain * iStandardize(iRandn([ProbeParams.NCueInput, 1], ProbeParams));
	preL23 = Mouse.W_CueInputToL23 * cueInput;
	preL5RewardRecv = iZeros([ProbeParams.NL5RewardRecv, 1], ProbeParams);
	preL5Read = iZeros([ProbeParams.NL5Read, 1], ProbeParams);
	[~, ~, rL5Read] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, ProbeParams);
	drives(iSample) = iGatherScalar(mean(Mouse.L5ReadoutPattern .* rL5Read));
end
randomMean = mean(drives, 'omitnan');
randomMax = max(drives);
randomHitFraction = mean(drives >= Params.HitThreshold, 'omitnan');
end

function weightSummary = iPlasticWeightDebugSummary(Mouse, Params)
cueWeights = iGatherValue(Mouse.W_CueInputToL23(:));
rewardWeights = iGatherValue(Mouse.W_RewardToL5RewardRecv(:));
internalWeights = iNonSelfInternalWeights(Mouse.W_L23L5ToL23L5);
weightSummary.CueMean = mean(cueWeights, 'omitnan');
weightSummary.CueZeroFraction = mean(cueWeights <= 0, 'omitnan');
weightSummary.CueCapFraction = mean(cueWeights >= 0.999 * Params.AfferentWCap, 'omitnan');
weightSummary.RewardMean = mean(rewardWeights, 'omitnan');
weightSummary.RewardZeroFraction = mean(rewardWeights <= 0, 'omitnan');
weightSummary.RewardCapFraction = mean(rewardWeights >= 0.999 * Params.AfferentWCap, 'omitnan');
weightSummary.InternalMean = mean(internalWeights, 'omitnan');
weightSummary.InternalZeroFraction = mean(internalWeights <= 0, 'omitnan');
weightSummary.InternalCapFraction = mean(internalWeights >= 0.999 * Params.WCap, 'omitnan');
readoutWIE = iGatherValue(Mouse.WIE_L5Read(:));
readoutWEI = iGatherValue(Mouse.WEI_L5Read(:));
weightSummary.L5ReadWIEMean = mean(readoutWIE, 'omitnan');
weightSummary.L5ReadWIEZeroFraction = mean(readoutWIE <= 0, 'omitnan');
weightSummary.L5ReadWIECapFraction = mean(readoutWIE >= 0.999 * Params.InhWeightMax, 'omitnan');
weightSummary.L5ReadWEIMean = mean(readoutWEI, 'omitnan');
weightSummary.L5ReadWEIZeroFraction = mean(readoutWEI <= 0, 'omitnan');
weightSummary.L5ReadWEICapFraction = mean(readoutWEI >= 0.999 * Params.InhWeightMax, 'omitnan');
end

function Summary = iRunCohortModel(Params, Cond)
Summary.Performance = struct();
Summary.HeterogeneityL23 = struct();
Summary.HeterogeneityL5 = struct();
Summary.PerMouse = struct();
Summary.Representative = struct();
Summary.FormalTrainingConnectionWeights = iInitFormalTrainingConnectionWeightValues();
Summary.FormalTrainingConnectionWeightMouseStd = iInitFormalTrainingConnectionWeightValues();

AllSlope = [];
AllH23 = [];
AllH5 = [];
AllH5RewardRecv = [];
AllH5Read = [];
AllRewardReadoutPretrain = [];
AllRewardReadoutFinal = [];
AllCond = strings(0, 1);
classNames = iConnectionClassNames();

for iCond = 1:height(Cond)
	perf = nan(Params.NumMice, Params.NumSessions);
	h23 = nan(Params.NumMice, Params.NumSessions);
	h5 = nan(Params.NumMice, Params.NumSessions);
	perMouse = table('Size', [Params.NumMice, 9], 'VariableTypes', {'double','double','double','double','double','double','double','double','double'}, ...
		'VariableNames', {'Slope','MeanDeltaHit','MeanH23','MeanH5','MeanH5RewardRecv','MeanH5Read','RewardReadoutPretrain','RewardReadoutFinal','FormalHebbGain'});
	repProcessL5 = cell(Params.NumMice, 1);
	preWeightCells = struct();
	postWeightCells = struct();
	for iClass = 1:numel(classNames)
		className = classNames(iClass);
		preWeightCells.(className) = cell(Params.NumMice, 1);
		postWeightCells.(className) = cell(Params.NumMice, 1);
	end
	condRow = Cond(iCond, :);
	condName = Cond.Name(iCond);
	mouseResultCells = cell(Params.NumMice, 1);
	parfor iMouse = 1:Params.NumMice
		mouseResultCells{iMouse} = iRunOneMouseTask(Params, condRow, condName, iMouse);
	end
	for iMouse = 1:Params.NumMice
		mouseResult = mouseResultCells{iMouse};
		perf(iMouse, :) = mouseResult.Performance;
		h23(iMouse, :) = mouseResult.H23;
		h5(iMouse, :) = mouseResult.H5;
		perMouse.Slope(iMouse) = mouseResult.Slope;
		perMouse.MeanDeltaHit(iMouse) = mouseResult.MeanDeltaHit;
		perMouse.MeanH23(iMouse) = mouseResult.MeanH23;
		perMouse.MeanH5(iMouse) = mouseResult.MeanH5;
		perMouse.MeanH5RewardRecv(iMouse) = mouseResult.MeanH5RewardRecv;
		perMouse.MeanH5Read(iMouse) = mouseResult.MeanH5Read;
		perMouse.RewardReadoutPretrain(iMouse) = mouseResult.RewardReadoutPretrain;
		perMouse.RewardReadoutFinal(iMouse) = mouseResult.RewardReadoutFinal;
		perMouse.FormalHebbGain(iMouse) = mouseResult.FormalHebbGain;
		repProcessL5{iMouse} = mouseResult.ProcessMeanL5;
		for iClass = 1:numel(classNames)
			className = classNames(iClass);
			preWeightCells.(className){iMouse} = mouseResult.FormalTrainingConnectionWeights.Pre.(className);
			postWeightCells.(className){iMouse} = mouseResult.FormalTrainingConnectionWeights.Post.(className);
		end
	end
	Summary.Performance.(Cond.Name(iCond)) = perf;
	Summary.HeterogeneityL23.(Cond.Name(iCond)) = h23;
	Summary.HeterogeneityL5.(Cond.Name(iCond)) = h5;
	Summary.PerMouse.(Cond.Name(iCond)) = perMouse;
	for iClass = 1:numel(classNames)
		className = classNames(iClass);
		Summary.FormalTrainingConnectionWeights.Pre.(className).(Cond.Name(iCond)) = vertcat(preWeightCells.(className){:});
		Summary.FormalTrainingConnectionWeights.Post.(className).(Cond.Name(iCond)) = vertcat(postWeightCells.(className){:});
		Summary.FormalTrainingConnectionWeightMouseStd.Pre.(className).(Cond.Name(iCond)) = iWeightDistributionStdByMouse(preWeightCells.(className));
		Summary.FormalTrainingConnectionWeightMouseStd.Post.(className).(Cond.Name(iCond)) = iWeightDistributionStdByMouse(postWeightCells.(className));
	end
	if Cond.Name(iCond) == "Transfer" || Cond.Name(iCond) == "THOff"
		repIdx = iRepresentativeIndex(perMouse.MeanH5);
		Summary.Representative.(Cond.Name(iCond)).ProcessMeanL5 = repProcessL5{repIdx};
	end
	AllSlope = [AllSlope; perMouse.Slope]; %#ok<AGROW>
	AllH23 = [AllH23; perMouse.MeanH23]; %#ok<AGROW>
	AllH5 = [AllH5; perMouse.MeanH5]; %#ok<AGROW>
	AllH5RewardRecv = [AllH5RewardRecv; perMouse.MeanH5RewardRecv]; %#ok<AGROW>
	AllH5Read = [AllH5Read; perMouse.MeanH5Read]; %#ok<AGROW>
	AllRewardReadoutPretrain = [AllRewardReadoutPretrain; perMouse.RewardReadoutPretrain]; %#ok<AGROW>
	AllRewardReadoutFinal = [AllRewardReadoutFinal; perMouse.RewardReadoutFinal]; %#ok<AGROW>
	AllCond = [AllCond; repmat(Cond.Name(iCond), Params.NumMice, 1)]; %#ok<AGROW>
end

Summary.AllMouse = table(AllCond, AllSlope, AllH23, AllH5, AllH5RewardRecv, AllH5Read, AllRewardReadoutPretrain, AllRewardReadoutFinal, ...
	'VariableNames', {'Condition','Slope','MeanH23','MeanH5','MeanH5RewardRecv','MeanH5Read','RewardReadoutPretrain','RewardReadoutFinal'});
Summary.CorrMouse = Summary.AllMouse;
Summary.FormalTrainingConnectionWeightStats = iFormalTrainingConnectionWeightStats(Summary.FormalTrainingConnectionWeightMouseStd, Cond);
Summary.FormalTrainingConnectionWeightClassification = iFormalTrainingConnectionWeightClassification();
end

function weightValues = iInitFormalTrainingConnectionWeightValues()
classNames = iConnectionClassNames();
for iClass = 1:numel(classNames)
	className = classNames(iClass);
	weightValues.Pre.(className) = struct();
	weightValues.Post.(className) = struct();
end
end

function mouseResult = iRunOneMouseTask(Params, Cond, condName, iMouse)
iSeedMouseIfRequested(Params, condName, iMouse);
Mouse = iDrawMouse(Params);
rewardReadoutPretrain = NaN;
if condName ~= "Naive"
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
formalTrainingConnectionWeightsPre = iCollectConnectionTypeWeights(Mouse, Params);
[MouseResult, Mouse] = iSimulateMouse(Mouse, Params, Cond);
formalTrainingConnectionWeightsPost = iCollectConnectionTypeWeights(Mouse, Params);
mouseResult.Performance = iGatherValue(MouseResult.Performance);
mouseResult.H23 = iGatherValue(MouseResult.H23);
mouseResult.H5 = iGatherValue(MouseResult.H5);
mouseResult.Slope = iGatherScalar(MouseResult.Slope);
mouseResult.MeanDeltaHit = iGatherScalar(MouseResult.MeanDeltaHit);
mouseResult.MeanH23 = iGatherScalar(MouseResult.MeanH23);
mouseResult.MeanH5 = iGatherScalar(MouseResult.MeanH5);
mouseResult.MeanH5RewardRecv = iGatherScalar(MouseResult.MeanH5RewardRecv);
mouseResult.MeanH5Read = iGatherScalar(MouseResult.MeanH5Read);
mouseResult.ProcessMeanL5 = iGatherValue(MouseResult.ProcessMeanL5);
mouseResult.FormalTrainingConnectionWeights.Pre = formalTrainingConnectionWeightsPre;
mouseResult.FormalTrainingConnectionWeights.Post = formalTrainingConnectionWeightsPost;
mouseResult.RewardReadoutPretrain = iGatherScalar(rewardReadoutPretrain);
mouseResult.RewardReadoutFinal = iGatherScalar(iRewardReadoutProbe(Mouse, Params, Cond));
mouseResult.FormalHebbGain = iGatherScalar(Mouse.FormalHebbGain);
end

function Mouse = iDrawMouse(Params)
% Fixed input / target patterns (zero-mean, unit-std).
% PreCueInput and CueInput share a common component (cross-modal correlation a) so
% that a fraction of sensory input dimensions drive both modalities.
a = Params.CueModalityCorr;
sharedCue = iStandardize(iRandn([Params.NCueInput, 1], Params));
preCueU   = iStandardize(iRandn([Params.NCueInput, 1], Params));
cueU      = iStandardize(iRandn([Params.NCueInput, 1], Params));
Mouse.PreCueInputPattern = iStandardize(a * sharedCue + sqrt(1 - a^2) * preCueU);
Mouse.CueInputPattern    = iStandardize(a * sharedCue + sqrt(1 - a^2) * cueU);
Mouse.RewardPattern      = iStandardize(iRandn([Params.NReward, 1], Params) + 0.55 * sign(iRandn([Params.NReward, 1], Params)));
Mouse.L5ReadoutPattern   = iStandardize(iRandn([Params.NL5Read, 1], Params)   + 0.55 * sign(iRandn([Params.NL5Read, 1], Params)));
Mouse.FormalHebbGain = iMouseScalarGain(Params.FormalHebbGainStd, Params.FormalHebbGainMin, Params.FormalHebbGainMax, Params);
Mouse.L5RewardRecvTeachingPattern = iStandardize(iRandn([Params.NL5RewardRecv, 1], Params) + 0.55 * sign(iRandn([Params.NL5RewardRecv, 1], Params)));
readHeterogeneityPattern = iStandardize(iRandn([Params.NL5Read, 1], Params) + 0.55 * sign(iRandn([Params.NL5Read, 1], Params)));
readHeterogeneityPattern = readHeterogeneityPattern - (sum(readHeterogeneityPattern .* Mouse.L5ReadoutPattern) / sum(Mouse.L5ReadoutPattern .^ 2)) * Mouse.L5ReadoutPattern;
Mouse.L5ReadHeterogeneityPattern = iStandardize(readHeterogeneityPattern);

% Initial sensory afferent map. Cue input is not the L2/3 code itself;
% L2/3 activity is generated by this mouse-specific plastic projection.
Mouse.W_CueInputToL23 = iClampNegativeWeightsToZero(iRandn([Params.NL23, Params.NCueInput], Params) / sqrt(Params.NCueInput));
% Initial reward afferent map into L5 reward-receiving cells.
Mouse.W_RewardToL5RewardRecv = iClampNegativeWeightsToZero(iRandn([Params.NL5RewardRecv, Params.NReward], Params) / sqrt(Params.NReward));

% Plastic internal E-E matrix, W(post, pre). Every L2/3 or L5 cell projects
% to every other L2/3/L5 cell; the diagonal is fixed at zero.
sd = Params.InitWStd;
Mouse.W_L23L5ToL23L5 = iZeroSelfProjection(iClampNegativeWeightsToZero(sd * iRandn([Params.NL23L5, Params.NL23L5], Params)));

% Inhibitory pools in L2/3, L5RewardRecv, and a schema-driven L5Read pathway.
Mouse.WIE_L23 = abs(0.72 + 0.20 * iRandn([Params.NIL23, Params.NL23], Params));
Mouse.WEI_L23 = abs(0.88 + 0.26 * iRandn([Params.NL23,  Params.NIL23], Params));
Mouse.WII_L23 = iInitIToIWeights(Params.NIL23, Params);
Mouse.WIE_L5RewardRecv = abs(0.72 + 0.20 * iRandn([Params.NIL5RewardRecv, Params.NL5RewardRecv], Params));
Mouse.WEI_L5RewardRecv = abs(0.88 + 0.26 * iRandn([Params.NL5RewardRecv,  Params.NIL5RewardRecv], Params));
Mouse.WII_L5RewardRecv = iInitIToIWeights(Params.NIL5RewardRecv, Params);
Mouse.WIE_L5Read = abs(0.72 + 0.20 * iRandn([Params.NIL5Read, Params.NL23 + Params.NL5RewardRecv], Params));
Mouse.WEI_L5Read = abs(0.88 + 0.26 * iRandn([Params.NL5Read, Params.NIL5Read], Params));
Mouse.WII_L5Read = iInitIToIWeights(Params.NIL5Read, Params);

Mouse.L5RewardRecvIDirectTHPattern = max(iStandardize(iRandn([Params.NIL5RewardRecv, 1], Params) + 0.55 * sign(iRandn([Params.NIL5RewardRecv, 1], Params))), 0);
Mouse.L5ReadIDirectTHPattern = max(iStandardize(iRandn([Params.NIL5Read, 1], Params) + 0.55 * sign(iRandn([Params.NIL5Read, 1], Params))), 0);

end

function WII = iInitIToIWeights(numInhibitoryCells, Params)
if Params.InitWIIStd > 0
	weights = abs(Params.InitWIIBase + Params.InitWIIStd * iRandn([numInhibitoryCells, numInhibitoryCells], Params));
else
	weights = Params.InitWIIBase * iOnes([numInhibitoryCells, numInhibitoryCells], Params);
end
WII = iZeroSelfProjection(weights);
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

preL23 = iZeros([ProbeParams.NL23, 1], ProbeParams);
preReward = Cond.RewardInputLevel * ProbeParams.RewInputGain * Mouse.RewardPattern;
rReward = iRunArea(preReward, 'reward', Mouse, ProbeParams);
preL5RewardRecv = (Mouse.W_RewardToL5RewardRecv * rReward) / ProbeParams.RewardAfferentNorm;
preL5Read = iZeros([ProbeParams.NL5Read, 1], ProbeParams);
[~, ~, rL5Read] = iRunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, ProbeParams);
readoutDrive = iGatherScalar(mean(Mouse.L5ReadoutPattern .* rL5Read));
end

function [Result, Mouse] = iSimulateMouse(Mouse, Params, Cond)
perf = nan(1, Params.NumSessions);
h23 = nan(1, Params.NumSessions);
h5 = nan(1, Params.NumSessions);
sessionMeanL23 = nan(Params.NL23, Params.NumSessions);
sessionMeanL5  = nan(Params.NL5,  Params.NumSessions);
sessionMeanL5RewardRecv = nan(Params.NL5RewardRecv, Params.NumSessions);
sessionMeanL5Read = nan(Params.NL5Read, Params.NumSessions);

for iSess = 1:Params.NumSessions
	[perf(iSess), Signals, ~, Mouse] = iSimulateSession(Mouse, Params, Cond, false);
	sessionMeanL23(:, iSess) = Signals.ProcessMeanL23;
	sessionMeanL5(:, iSess)  = Signals.ProcessMeanL5;
	sessionMeanL5RewardRecv(:, iSess) = Signals.ProcessMeanL5RewardRecv;
	sessionMeanL5Read(:, iSess) = Signals.ProcessMeanL5Read;
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

heterogeneityIdx = 1:Params.NumSessions;
finalMeanL23 = mean(sessionMeanL23(:, heterogeneityIdx), 2, 'omitnan');
finalMeanL5 = mean(sessionMeanL5(:, heterogeneityIdx), 2, 'omitnan');
finalMeanL5RewardRecv = mean(sessionMeanL5RewardRecv(:, heterogeneityIdx), 2, 'omitnan');
finalMeanL5Read = mean(sessionMeanL5Read(:, heterogeneityIdx), 2, 'omitnan');
resultMeanH23 = iRestrictedStd(finalMeanL23);
resultMeanH5 = iRestrictedStd(finalMeanL5);
resultMeanH5RewardRecv = iRestrictedStd(finalMeanL5RewardRecv);
resultMeanH5Read = iRestrictedStd(finalMeanL5Read);

if numel(useIdx) >= 2
	fitX = (1:numel(useIdx))';
	fitY = perf(useIdx)';
	% Linear fit. Logit was tried but the logit(0.03)~-3.5 expansion at
	% the low end inflates Naive's apparent slope more than it boosts
	% Transfer's, which erases rather than reveals the N/T gap.
	fitP = polyfit(fitX, fitY, 1);
	dh = diff(fitY);
	resultSlope = fitP(1);
	resultDeltaHit = mean(dh, 'omitnan');
elseif ~isempty(useIdx)
	resultSlope = NaN;
	resultDeltaHit = NaN;
else
	resultSlope = NaN;
	resultDeltaHit = NaN;
end

Result.Performance = perf;
Result.H23 = h23;
Result.H5 = h5;
Result.Slope = resultSlope;
Result.MeanDeltaHit = resultDeltaHit;
Result.MeanH23 = resultMeanH23;
Result.MeanH5 = resultMeanH5;
Result.MeanH5RewardRecv = resultMeanH5RewardRecv;
Result.MeanH5Read = resultMeanH5Read;
Result.ProcessMeanL5 = finalMeanL5;
Result.ProcessMeanL5RewardRecv = finalMeanL5RewardRecv;
Result.ProcessMeanL5Read = finalMeanL5Read;
end

function weightClasses = iCollectConnectionTypeWeights(Mouse, Params)
weightClasses = iEmptyConnectionClassWeights();

weightClasses = iAppendConnectionClassWeights(weightClasses, "EE", Mouse.W_CueInputToL23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "EE", Mouse.W_RewardToL5RewardRecv / Params.RewardAfferentNorm);
weightClasses = iAppendConnectionClassWeights(weightClasses, "EE", iNonSelfInternalWeights(Mouse.W_L23L5ToL23L5) / Params.NL23L5);
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WIE_L23 / Params.NL23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Params.Comp_Cue * Mouse.WEI_L23 / Params.NIL23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", Params.IToIGain * Mouse.WII_L23 / Params.NIL23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WIE_L5RewardRecv / Params.NL5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Params.Comp_Rew * Mouse.WEI_L5RewardRecv / Params.NIL5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", Params.IToIGain * Mouse.WII_L5RewardRecv / Params.NIL5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WIE_L5Read / (Params.NL23 + Params.NL5RewardRecv));
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Params.Comp_Read * Mouse.WEI_L5Read / Params.NIL5Read);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", Params.IToIGain * Mouse.WII_L5Read / Params.NIL5Read);
end

function weightClasses = iEmptyConnectionClassWeights()
classNames = iConnectionClassNames();
for iClass = 1:numel(classNames)
	weightClasses.(classNames(iClass)) = [];
end
end

function weightClasses = iAppendConnectionClassWeights(weightClasses, className, weights)
weights = abs(iGatherValue(weights(:)));
weights = weights(isfinite(weights) & weights ~= 0);
weightClasses.(className) = [weightClasses.(className); weights];
end

function classNames = iConnectionClassNames()
classNames = ["EE", "EI", "IE", "II"];
end

function classLabels = iConnectionClassLabels()
classLabels = ["EE", "EI", "IE", "II"];
end

function weights = iNonSelfInternalWeights(weights)
weights = iGatherValue(weights);
numCells = size(weights, 1);
internalMask = true(size(weights));
internalMask(1:numCells+1:end) = false;
weights = weights(internalMask);
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
formalHebbGain = 1;
if ~usePreCue
	formalHebbGain = Mouse.FormalHebbGain;
end
eta = Params.HebbRate * formalHebbGain;

% Storage for session-level diagnostics.
rL23_cue_all = iZeros([Params.NL23, NT], Params);
rL5RewardRecv_cue_all = iZeros([Params.NL5RewardRecv, NT], Params);
rL5Read_cue_all = iZeros([Params.NL5Read, NT], Params);
rL23_L_all = iZeros([Params.NL23, NT], Params);
rReward_L_all = iZeros([Params.NReward, NT], Params);
rL5RewardRecv_L_all = iZeros([Params.NL5RewardRecv, NT], Params);
rL5Read_L_all = iZeros([Params.NL5Read, NT], Params);
isHit = false(1, NT);

for t = 1:NT
	% ===== Decision phase (cue input -> recurrent L2/3-L5 network) =====
	cueInput_cue  = cueGain              * cueInputPat            + Params.NoiseCue * iRandn([Params.NCueInput, 1], Params);
	preL23_cue  = Mouse.W_CueInputToL23 * cueInput_cue  + Params.NoiseCue * iRandn([Params.NL23, 1], Params);
	preL5RewardRecv_cue = Params.NoiseRew * iRandn([Params.NL5RewardRecv, 1], Params);
	preL5Read_cue = Params.NoiseRead * iRandn([Params.NL5Read, 1], Params);
	[rL23_cue, rL5RewardRecv_cue, rL5Read_cue, decisionActivityCue] = iRunInternalNetwork(preL23_cue, preL5RewardRecv_cue, preL5Read_cue, Mouse, Params);

	decCue  = mean(Mouse.L5ReadoutPattern .* rL5Read_cue);
	decision = iGatherScalar(decCue);
	isHit(t) = decision >= Params.HitThreshold;

	% ===== Learning phase (reward/readout feedback continues from cue-decision state) =====
	cueInput_L = cueInput_cue;
	preL23_L = preL23_cue;
	if rewardInputLevel > 0
		preReward_L = rewardInputLevel * Params.RewInputGain * Mouse.RewardPattern + Params.NoiseRew * iRandn([Params.NReward, 1], Params);
		rReward_L = iRunArea(preReward_L, 'reward', Mouse, Params);
	else
		rReward_L = iZeros([Params.NReward, 1], Params);
	end
	preL5RewardRecv_L = (Mouse.W_RewardToL5RewardRecv * rReward_L) / Params.RewardAfferentNorm ...
		+ rewardInputLevel * Params.THRewardRecvInputGain * Mouse.L5RewardRecvTeachingPattern ...
		+ Params.NoiseRew * iRandn([Params.NL5RewardRecv, 1], Params);
	readTeachingGain = Params.ReadInputGain + rewardInputLevel * Params.THReadInputGain;
	preL5Read_L = readTeachingGain * Mouse.L5ReadoutPattern ...
		+ rewardInputLevel * Params.THReadHeterogeneityGain * Mouse.L5ReadHeterogeneityPattern ...
		+ Params.NoiseRead * iRandn([Params.NL5Read, 1], Params);
	learningParams = iWithDirectTHToL5I(Params, Mouse, rewardInputLevel);
	[rL23_L, rL5RewardRecv_L, rL5Read_L] = iContinueInternalNetwork(preL23_L, preL5RewardRecv_L, preL5Read_L, decisionActivityCue, Mouse, learningParams);

	% Per-trial Hebbian updates on learned afferent maps and the recurrent L2/3-L5 matrix.
	Mouse.W_CueInputToL23 = iHebbAfferent(Mouse.W_CueInputToL23, rL23_L, cueInput_L, eta, Params.AfferentWCap);
	Mouse.W_RewardToL5RewardRecv = iHebbAfferent(Mouse.W_RewardToL5RewardRecv, rL5RewardRecv_L, rReward_L, eta, Params.AfferentWCap);
	internalActivity_L = [rL23_L; rL5RewardRecv_L; rL5Read_L];
	Mouse.W_L23L5ToL23L5 = iHebbInternalNoSelf(Mouse.W_L23L5ToL23L5, internalActivity_L, eta, Params.WCap);

	% Per-trial inhibitory plasticity protects the rewarded pattern from local over-inhibition.
	actL23Trial = (rL23_cue + rL23_L) / 2;
	actL5RewardRecvTrial = (rL5RewardRecv_cue + rL5RewardRecv_L) / 2;
	Mouse = iApplyInhibitoryCircuitPlasticity(Mouse, Params, actL23Trial, actL5RewardRecvTrial, Mouse.L5ReadoutPattern, "protect");

	% ===== Closed-loop noise Hebbian learning =====
	% Test a fresh random-noise cue. If it falsely activates the behavioural
	% readout, silence L5Read cells and train on that noise cue; then test a
	% new random-noise cue. Continue until one random cue fails to activate.
	while true
		cueInput_BL = cueGain * iStandardize(iRandn([Params.NCueInput, 1], Params)) + Params.NoiseCue * iRandn([Params.NCueInput, 1], Params);
		preL23_BLTest = Mouse.W_CueInputToL23 * cueInput_BL + Params.NoiseCue * iRandn([Params.NL23, 1], Params);
		preL5RewardRecv_BLTest = Params.NoiseRew * iRandn([Params.NL5RewardRecv, 1], Params);
		preL5Read_BLTest = Params.NoiseRead * iRandn([Params.NL5Read, 1], Params);
		[~, ~, rL5Read_BLTest] = iRunInternalNetwork(preL23_BLTest, preL5RewardRecv_BLTest, preL5Read_BLTest, Mouse, Params);

		decCue_BL = iGatherScalar(mean(Mouse.L5ReadoutPattern .* rL5Read_BLTest));
		if decCue_BL < Params.HitThreshold
			break;
		end

		preL23_BL = Mouse.W_CueInputToL23 * cueInput_BL + Params.NoiseCue * iRandn([Params.NL23, 1], Params);
		if rewardInputLevel > 0
			preReward_BL = Params.NoiseRew * iRandn([Params.NReward, 1], Params);
			rReward_BL = iRunArea(preReward_BL, 'reward', Mouse, Params);
		else
			rReward_BL = iZeros([Params.NReward, 1], Params);
		end
		preL5RewardRecv_BL = (Mouse.W_RewardToL5RewardRecv * rReward_BL) / Params.RewardAfferentNorm + Params.NoiseRew * iRandn([Params.NL5RewardRecv, 1], Params);
		preL5Read_BL = iZeros([Params.NL5Read, 1], Params);
		[rL23_BL, rL5RewardRecv_BL, rL5Read_BL] = iRunInternalNetworkReadoutSilent(preL23_BL, preL5RewardRecv_BL, preL5Read_BL, Mouse, Params);

		Mouse.W_CueInputToL23 = iHebbAfferent(Mouse.W_CueInputToL23, rL23_BL, cueInput_BL, eta, Params.AfferentWCap);
		Mouse.W_RewardToL5RewardRecv = iHebbAfferent(Mouse.W_RewardToL5RewardRecv, rL5RewardRecv_BL, rReward_BL, eta, Params.AfferentWCap);
		internalActivity_BL = [rL23_BL; rL5RewardRecv_BL; rL5Read_BL];
		Mouse.W_L23L5ToL23L5 = iHebbInternalNoSelf(Mouse.W_L23L5ToL23L5, internalActivity_BL, eta, Params.WCap);

		Mouse = iApplyInhibitoryCircuitPlasticity(Mouse, Params, rL23_BL, rL5RewardRecv_BL, Mouse.L5ReadoutPattern, "suppress");
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

Signals.mL23 = iGatherValue(mean(rL23_L_all, 2));
Signals.mReward = iGatherValue(mean(rReward_L_all, 2));
Signals.mL5RewardRecv = iGatherValue(mean(rL5RewardRecv_L_all, 2));
Signals.mL5Read = iGatherValue(mean(rL5Read_L_all, 2));
Signals.ProcessMeanL23 = iGatherValue(mean(rL23_cue_all, 2));
processMeanL5RewardRecv = mean(rL5RewardRecv_cue_all, 2);
processMeanL5Read = mean(rL5Read_cue_all, 2);
Signals.ProcessMeanL5 = iGatherValue([processMeanL5RewardRecv; processMeanL5Read]);
Signals.ProcessMeanL5RewardRecv = iGatherValue(processMeanL5RewardRecv);
Signals.ProcessMeanL5Read = iGatherValue(processMeanL5Read);
end

function rE = iRunArea(pre, areaSpec, Mouse, Params)
switch areaSpec
case 'l23'
	WIE = Mouse.WIE_L23; WEI = Mouse.WEI_L23; WII = Mouse.WII_L23;
	NI = Params.NIL23; NE = Params.NL23; Comp = Params.Comp_Cue;
case 'reward'
	% Reward cells are modeled as an independent input population.
	rE = Params.ResponseScale * tanh(pre);
	return;
case 'l5rewardrecv'
	WIE = Mouse.WIE_L5RewardRecv; WEI = Mouse.WEI_L5RewardRecv; WII = Mouse.WII_L5RewardRecv;
	NI = Params.NIL5RewardRecv; NE = Params.NL5RewardRecv; Comp = Params.Comp_Rew;
end
exc = max(pre, 0);
inhI = iRunInhibitoryPool(WIE * exc / NE + iExternalInhibitoryDrive(areaSpec, pre, Params), WII, Params, NI, true);
rE = Params.ResponseScale * tanh(pre - Comp * (WEI * inhI) / NI);
end

function Params = iWithDirectTHToL5I(Params, Mouse, rewardInputLevel)
Params.L5RewardRecvIExternalDrive = [];
Params.L5ReadIExternalDrive = [];
if rewardInputLevel > 0 && Params.THL5RewardRecvIInputGain ~= 0
	Params.L5RewardRecvIExternalDrive = rewardInputLevel * Params.THL5RewardRecvIInputGain * Mouse.L5RewardRecvIDirectTHPattern;
end
if rewardInputLevel > 0 && Params.THL5ReadIInputGain ~= 0
	Params.L5ReadIExternalDrive = rewardInputLevel * Params.THL5ReadIInputGain * Mouse.L5ReadIDirectTHPattern;
end
end

function drive = iExternalInhibitoryDrive(areaSpec, pre, Params)
drive = zeros(0, size(pre, 2), 'like', pre);
if strcmp(areaSpec, 'l5rewardrecv') && isfield(Params, 'L5RewardRecvIExternalDrive') && ~isempty(Params.L5RewardRecvIExternalDrive)
	drive = Params.L5RewardRecvIExternalDrive;
	if size(drive, 2) == 1 && size(pre, 2) > 1
		drive = repmat(drive, 1, size(pre, 2));
	end
end
if isempty(drive)
	if strcmp(areaSpec, 'l5rewardrecv')
		drive = zeros(Params.NIL5RewardRecv, size(pre, 2), 'like', pre);
	else
		drive = zeros(Params.NIL23, size(pre, 2), 'like', pre);
	end
end
end

function inhI = iRunInhibitoryPool(feedforwardInh, WII, Params, numInhibitoryCells, centerInh)
if nargin < 5
	centerInh = true;
end
inhFeedforward = max(0, feedforwardInh);
inhI = inhFeedforward;
for iPass = 1:Params.IToIPasses
	inhI = max(0, inhFeedforward - Params.IToIGain * (WII * inhI) / numInhibitoryCells);
end
if centerInh
	inhI = inhI - mean(inhI, 1);
end
end

function rL5Read = iRunReadoutArea(preL5Read, readoutInhibitorySource, Mouse, Params)
activeSource = max(readoutInhibitorySource, 0);
numSourceCells = size(activeSource, 1);
inhDrive = iRunInhibitoryPool(Mouse.WIE_L5Read * activeSource / numSourceCells + iReadoutExternalInhibitoryDrive(preL5Read, Params), Mouse.WII_L5Read, Params, Params.NIL5Read, false);
rL5Read = Params.ResponseScale * tanh(preL5Read - Params.Comp_Read * (Mouse.WEI_L5Read * inhDrive) / Params.NIL5Read);
end

function drive = iReadoutExternalInhibitoryDrive(preL5Read, Params)
drive = zeros(Params.NIL5Read, size(preL5Read, 2), 'like', preL5Read);
if isfield(Params, 'L5ReadIExternalDrive') && ~isempty(Params.L5ReadIExternalDrive)
	drive = Params.L5ReadIExternalDrive;
	if size(drive, 2) == 1 && size(preL5Read, 2) > 1
		drive = repmat(drive, 1, size(preL5Read, 2));
	end
end
end

function Mouse = iApplyInhibitoryCircuitPlasticity(Mouse, Params, activityL23, activityL5RewardRecv, readoutTargetPattern, plasticityMode)
[Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23] = iInhibitoryAreaPlasticity(Mouse.WIE_L23, Mouse.WEI_L23, Mouse.WII_L23, activityL23, Params, plasticityMode);
[Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv] = iInhibitoryAreaPlasticity(Mouse.WIE_L5RewardRecv, Mouse.WEI_L5RewardRecv, Mouse.WII_L5RewardRecv, activityL5RewardRecv, Params, plasticityMode);
readoutInhibitorySource = [activityL23; activityL5RewardRecv];
[Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read] = iReadoutInhibitoryPlasticity(Mouse.WIE_L5Read, Mouse.WEI_L5Read, Mouse.WII_L5Read, readoutInhibitorySource, readoutTargetPattern, Params, plasticityMode);
end

function [WIE, WEI, WII] = iInhibitoryAreaPlasticity(WIE, WEI, WII, activityE, Params, plasticityMode)
activeE = max(activityE(:) - Params.InhTargetAct, 0);
if ~any(iGatherValue(activeE > 0))
	return;
end
numExcCells = numel(activeE);
numInhibitoryCells = size(WII, 1);
inhDrive = iRunInhibitoryPool(WIE * activeE / numExcCells, WII, Params, numInhibitoryCells, false);
if ~any(iGatherValue(inhDrive > 0))
	return;
end
deltaWIE = Params.InhPlasticityRate * (inhDrive * activeE');
deltaWEI = Params.InhPlasticityRate * (activeE * inhDrive');
deltaWII = Params.InhPlasticityRate * (inhDrive * inhDrive');
switch plasticityMode
case "suppress"
	WIE = WIE + deltaWIE;
	WEI = WEI + deltaWEI;
	WII = WII - deltaWII;
case "protect"
	WIE = WIE - deltaWIE;
	WEI = WEI - deltaWEI;
	WII = WII + deltaWII;
otherwise
	error('THModel:UnknownInhibitoryPlasticityMode', 'Unknown inhibitory plasticity mode: %s.', plasticityMode);
end
WIE = iClamp(WIE, Params.InhWeightMin, Params.InhWeightMax);
WEI = iClamp(WEI, Params.InhWeightMin, Params.InhWeightMax);
WII = iZeroSelfProjection(iClamp(WII, Params.InhWeightMin, Params.InhWeightMax));
end

function [WIE, WEI, WII] = iReadoutInhibitoryPlasticity(WIE, WEI, WII, sourceActivity, targetPattern, Params, plasticityMode)
activeSource = max(sourceActivity(:) - Params.InhTargetAct, 0);
if ~any(iGatherValue(activeSource > 0))
	return;
end
numSourceCells = numel(activeSource);
numInhibitoryCells = size(WII, 1);
inhDrive = iRunInhibitoryPool(WIE * activeSource / numSourceCells, WII, Params, numInhibitoryCells, false);
if ~any(iGatherValue(inhDrive > 0))
	return;
end
targetPattern = targetPattern(:);
targetScale = abs(targetPattern);
targetScaleMean = iGatherScalar(mean(targetScale, 'omitnan'));
if ~isfinite(targetScaleMean) || targetScaleMean <= 0
	return;
end
targetScale = targetScale / targetScaleMean;
targetDirection = -sign(targetPattern) .* targetScale;
deltaWIE = Params.InhPlasticityRate * (inhDrive * activeSource');
deltaWEI = Params.InhPlasticityRate * (targetDirection * inhDrive');
deltaWII = Params.InhPlasticityRate * (inhDrive * inhDrive');
switch plasticityMode
case "suppress"
	WIE = WIE + deltaWIE;
	WEI = WEI - deltaWEI;
	WII = WII - deltaWII;
case "protect"
	WIE = WIE + deltaWIE;
	WEI = WEI + deltaWEI;
	WII = WII + deltaWII;
otherwise
	error('THModel:UnknownInhibitoryPlasticityMode', 'Unknown inhibitory plasticity mode: %s.', plasticityMode);
end
WIE = iClamp(WIE, Params.InhWeightMin, Params.InhWeightMax);
WEI = iClamp(WEI, Params.InhWeightMin, Params.InhWeightMax);
WII = iZeroSelfProjection(iClamp(WII, Params.InhWeightMin, Params.InhWeightMax));
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
	internalActivity = iRunInternalAreas(recurrentPre, Mouse, Params, false);
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

function internalActivity = iRunInternalAreas(internalPre, Mouse, Params, useReadoutInhibition)
if nargin < 4
	useReadoutInhibition = true;
end
[preL23, preL5RewardRecv, preL5Read] = iSplitInternalActivity(internalPre, Params);
rL23 = iRunArea(preL23, 'l23', Mouse, Params);
rL5RewardRecv = iRunArea(preL5RewardRecv, 'l5rewardrecv', Mouse, Params);
if useReadoutInhibition
	readoutInhibitorySource = [rL23; rL5RewardRecv];
	rL5Read = iRunReadoutArea(preL5Read, readoutInhibitorySource, Mouse, Params);
else
	rL5Read = Params.ResponseScale * tanh(preL5Read);
end
internalActivity = [rL23; rL5RewardRecv; rL5Read];
end

function internalActivity = iRunInternalAreasReadoutSilent(internalPre, Mouse, Params)
[preL23, preL5RewardRecv, ~] = iSplitInternalActivity(internalPre, Params);
rL23 = iRunArea(preL23, 'l23', Mouse, Params);
rL5RewardRecv = iRunArea(preL5RewardRecv, 'l5rewardrecv', Mouse, Params);
rL5Read = iZeros([Params.NL5Read, size(internalPre, 2)], Params);
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
W = iClampNegativeWeightsToZero(min(W, cap));
end

function W = iHebbAfferent(W, post, pre, eta, cap)
W = iHebb(W, post, pre, eta / numel(pre), cap);
end

function recurrentWeights = iHebbNoSelf(recurrentWeights, activity, eta, cap)
recurrentWeights = iHebb(recurrentWeights, activity, activity, eta, cap);
recurrentWeights = iZeroSelfProjection(recurrentWeights);
end

function recurrentWeights = iHebbInternalNoSelf(recurrentWeights, activity, eta, cap)
recurrentWeights = iHebb(recurrentWeights, activity, activity, eta, cap);
recurrentWeights = iZeroSelfProjection(recurrentWeights);
end

function recurrentWeights = iZeroSelfProjection(recurrentWeights)
numCells = size(recurrentWeights, 1);
recurrentWeights(1:numCells+1:end) = 0;
end

function Mouse = iOvernightConsolidate(Mouse, Params)
ret = Params.OvernightRetention;
sd = Params.OvernightNoise;
Mouse.W_CueInputToL23 = ret * Mouse.W_CueInputToL23 + sd * iRandn(size(Mouse.W_CueInputToL23), Params);
Mouse.W_RewardToL5RewardRecv = ret * Mouse.W_RewardToL5RewardRecv + sd * iRandn(size(Mouse.W_RewardToL5RewardRecv), Params);
Mouse.W_L23L5ToL23L5 = iZeroSelfProjection(ret * Mouse.W_L23L5ToL23L5 + sd * iRandn(size(Mouse.W_L23L5ToL23L5), Params));
Mouse.W_CueInputToL23 = iClampNegativeWeightsToZero(Mouse.W_CueInputToL23);
Mouse.W_RewardToL5RewardRecv = iClampNegativeWeightsToZero(Mouse.W_RewardToL5RewardRecv);
Mouse.W_L23L5ToL23L5 = iZeroSelfProjection(iClampNegativeWeightsToZero(Mouse.W_L23L5ToL23L5));
end

function W = iClampNegativeWeightsToZero(W)
W(W < 0) = 0;
end

function y = iClamp(x, lo, hi)
y = max(min(x, hi), lo);
end

function gain = iMouseScalarGain(stdValue, minValue, maxValue, Params)
if stdValue <= 0
	gain = 1;
	return;
end
gain = 1 + stdValue * iGatherScalar(iRandn([1, 1], Params));
gain = iClamp(gain, minValue, maxValue);
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
sd = std(v, 0);
sdValue = iGatherScalar(sd);
if ~isfinite(sdValue) || sdValue < eps
	sd = 1;
end
v = v ./ sd;
end

function values = iRandn(sz, ~)
if isscalar(sz)
	sz = [sz, 1];
end
values = randn(sz);
end

function values = iZeros(sz, ~)
if isscalar(sz)
	sz = [sz, 1];
end
values = zeros(sz);
end

function values = iOnes(sz, ~)
if isscalar(sz)
	sz = [sz, 1];
end
values = ones(sz);
end

function values = iGatherValue(values)
end

function value = iGatherScalar(value)
value = iGatherValue(value);
end

function stdValues = iWeightDistributionStdByMouse(weightCells)
stdValues = nan(numel(weightCells), 1);
for iMouse = 1:numel(weightCells)
	stdValues(iMouse) = iWeightDistributionStd(weightCells{iMouse});
end
end

function stats = iFormalTrainingConnectionWeightStats(mouseStdValues, Cond)
classNames = iConnectionClassNames();
stageNames = ["Pre", "Post"];
for iClass = 1:numel(classNames)
	className = classNames(iClass);
	stdMat = nan(numel(stageNames), height(Cond));
	stdSemMat = nan(numel(stageNames), height(Cond));
	nMat = nan(numel(stageNames), height(Cond));
	for iStage = 1:numel(stageNames)
		stageName = stageNames(iStage);
		for iCond = 1:height(Cond)
			condName = Cond.Name(iCond);
			values = mouseStdValues.(stageName).(className).(condName);
			[stdMat(iStage, iCond), stdSemMat(iStage, iCond), nMat(iStage, iCond)] = iMeanSemFinite(values);
		end
	end
	stats.(className).Std = stdMat;
	stats.(className).StdSem = stdSemMat;
	stats.(className).N = nMat;
end
stats.StageNames = stageNames;
stats.ConditionNames = Cond.Name;
stats.Unit = "mouse-level weight distribution SD";
end

function stdWeight = iWeightDistributionStd(weights)
weights = weights(:);
weights = weights(isfinite(weights));
if numel(weights) < 2
	stdWeight = NaN;
	return;
end
stdWeight = std(weights, 0, 'omitnan');
end

function [meanValue, semValue, nValues] = iMeanSemFinite(values)
values = values(:);
values = values(isfinite(values));
nValues = numel(values);
if nValues == 0
	meanValue = NaN;
	semValue = NaN;
	return;
end
meanValue = mean(values, 'omitnan');
if nValues < 2
	semValue = NaN;
else
	semValue = std(values, 0, 'omitnan') / sqrt(nValues);
end
end

function fDist = iPlotPreFormalConnectionWeightDistributions(Summary, Cond)
classNames = iConnectionClassNames();
classLabels = iConnectionClassLabels();
plotConditionNames = ["Naive", "Transfer"];

fDist = figure('Color', 'w', 'Name', 'Naive/Transfer pre-formal connection weight distributions');
fDist.Units = 'centimeters';
fDist.Position(3:4) = [18, 14];
fDist.PaperUnits = 'centimeters';
fDist.PaperPositionMode = 'manual';
fDist.PaperPosition = [0, 0, 18, 14];
fDist.PaperSize = [18, 14];

tlDist = tiledlayout(fDist, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
legendHandles = gobjects(numel(plotConditionNames), 1);

for iClass = 1:numel(classNames)
	className = classNames(iClass);
	ax = nexttile(tlDist, iClass);
	hold(ax, 'on');
	plotValuesByCondition = cell(numel(plotConditionNames), 1);
	allPlotValues = [];
	for iPlotCond = 1:numel(plotConditionNames)
		weights = iPreFormalWeightsForCondition(Summary, className, plotConditionNames(iPlotCond));
		plotValues = log10(weights(weights > 0));
		plotValues = plotValues(isfinite(plotValues));
		plotValuesByCondition{iPlotCond} = plotValues;
		allPlotValues = [allPlotValues; plotValues]; %#ok<AGROW>
	end
	allPlotValues = allPlotValues(isfinite(allPlotValues));
	if isempty(allPlotValues)
		allPlotValues = [0; 1];
	end
	displayRange = quantile(allPlotValues, [0.001, 0.999]);
	if ~all(isfinite(displayRange)) || displayRange(1) >= displayRange(2)
		displayRange = [min(allPlotValues, [], 'omitnan'), max(allPlotValues, [], 'omitnan')];
	end
	if ~all(isfinite(displayRange)) || displayRange(1) >= displayRange(2)
		displayRange = [0, 1];
	end
	edges = linspace(displayRange(1), displayRange(2), 80);
	for iPlotCond = 1:numel(plotConditionNames)
		condName = plotConditionNames(iPlotCond);
		condIdx = find(Cond.Name == condName, 1, 'first');
		plotValues = plotValuesByCondition{iPlotCond};
		plotValues = plotValues(plotValues >= displayRange(1) & plotValues <= displayRange(2));
		[xLine, yLine] = iDensityFromHist(plotValues, edges);
		legendHandles(iPlotCond) = plot(ax, xLine, yLine, '-', 'Color', Cond.Color(condIdx, :), 'LineWidth', 2);
	end
	iStyleLinePanel(ax);
	xlabel(ax, 'log10 absolute effective weight', 'FontSize', 12);
	ylabel(ax, 'Density', 'FontSize', 12);
	title(ax, classLabels(iClass), 'FontSize', 12, 'FontWeight', 'normal');
	ax.FontSize = 12;
	ax.LineWidth = 2;
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

legendLabels = cellstr(Cond.Label(ismember(Cond.Name, plotConditionNames)));
lgd = legend(legendHandles, legendLabels, 'Location', 'north', 'Box', 'off', ...
	'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', numel(plotConditionNames));
lgd.Layout.Tile = 'north';
end

function weights = iPreFormalWeightsForCondition(Summary, className, condName)
weights = Summary.FormalTrainingConnectionWeights.Pre.(className).(condName);
weights = weights(:);
weights = weights(isfinite(weights));
end

function fWeight = iPlotFormalTrainingConnectionWeightStats(Summary, Cond)
classNames = iConnectionClassNames();
classLabels = iConnectionClassLabels();
stageLabels = ["Before formal", "After formal"];

fWeight = figure('Color', 'w', 'Name', 'Formal training connection type weight SD');
fWeight.Units = 'centimeters';
fWeight.Position(3:4) = [18, 14];
fWeight.PaperUnits = 'centimeters';
fWeight.PaperPositionMode = 'manual';
fWeight.PaperPosition = [0, 0, 18, 14];
fWeight.PaperSize = [18, 14];

tlWeight = tiledlayout(fWeight, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
legendHandles = gobjects(height(Cond), 1);

for iClass = 1:numel(classNames)
	className = classNames(iClass);
	ax = nexttile(tlWeight, iClass);
	hold(ax, 'on');
	barValues = Summary.FormalTrainingConnectionWeightStats.(className).Std;
	barUpperError = Summary.FormalTrainingConnectionWeightStats.(className).StdSem;
	barHandles = bar(ax, barValues, 'grouped', 'LineStyle', 'none');
	for iCond = 1:height(Cond)
		barHandles(iCond).FaceColor = Cond.Color(iCond, :);
		barHandles(iCond).EdgeColor = 'none';
		barHandles(iCond).LineStyle = 'none';
		xBar = barHandles(iCond).XEndPoints;
		yBar = barHandles(iCond).YEndPoints;
		upperError = barUpperError(:, iCond)';
		errorbar(ax, xBar, yBar, zeros(size(upperError)), upperError, 'LineStyle', 'none', ...
			'Color', Cond.Color(iCond, :), 'LineWidth', 1.8, 'CapSize', 8, 'HandleVisibility', 'off');
	end
	yMax = iAnnotateFormalTrainingConnectionWeightComparisons(ax, Summary, Cond, className, barHandles, barValues, barUpperError);
	if iClass == 1
		legendHandles = barHandles;
	end
	iStyleScatterPanel(ax);
	ax.XTick = 1:numel(stageLabels);
	ax.XTickLabel = cellstr(stageLabels);
	ax.XTickLabelRotation = 0;
	xlabel(ax, '', 'FontSize', 12);
	ylabel(ax, 'Mouse-level weight SD', 'FontSize', 12);
	title(ax, classLabels(iClass), 'FontSize', 12, 'FontWeight', 'normal');
	ylim(ax, [0, yMax]);
	ax.FontSize = 12;
	ax.LineWidth = 2;
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

lgd = legend(legendHandles, cellstr(Cond.Label), 'Location', 'north', 'Box', 'off', ...
	'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', height(Cond));
lgd.Layout.Tile = 'north';
end

function yMax = iAnnotateFormalTrainingConnectionWeightComparisons(ax, Summary, Cond, className, barHandles, barValues, barUpperError)
stageNames = Summary.FormalTrainingConnectionWeightStats.StageNames;
comparisons = [1, 2; 2, 3];
barTop = barValues + barUpperError;
baseTop = max(barTop(:), [], 'omitnan');
if ~isfinite(baseTop) || baseTop <= 0
	baseTop = 1;
end
yRange = max(baseTop, 0.01);
yMaxUsed = baseTop;

for iStage = 1:numel(stageNames)
	stageName = stageNames(iStage);
	stageTop = max(barTop(iStage, :), [], 'omitnan');
	if ~isfinite(stageTop)
		stageTop = baseTop;
	end
	for iComparison = 1:size(comparisons, 1)
		condA = comparisons(iComparison, 1);
		condB = comparisons(iComparison, 2);
		xA = barHandles(condA).XEndPoints(iStage);
		xB = barHandles(condB).XEndPoints(iStage);
		mouseStdA = Summary.FormalTrainingConnectionWeightMouseStd.(stageName).(className).(Cond.Name(condA));
		mouseStdB = Summary.FormalTrainingConnectionWeightMouseStd.(stageName).(className).(Cond.Name(condB));
		pValue = iWeightDispersionPValue(mouseStdA, mouseStdB);
		label = iPairwisePLabel(pValue);
		yLine = stageTop + (0.10 + 0.13 * (iComparison - 1)) * yRange;
		iPValueLine(ax, xA, xB, yLine, label, yRange);
		yMaxUsed = max(yMaxUsed, yLine + 0.10 * yRange);
	end
end
yMax = yMaxUsed + 0.05 * yRange;
end

function pValue = iWeightDispersionPValue(mouseStdA, mouseStdB)
mouseStdA = mouseStdA(:);
mouseStdB = mouseStdB(:);
mouseStdA = mouseStdA(isfinite(mouseStdA));
mouseStdB = mouseStdB(isfinite(mouseStdB));
if numel(mouseStdA) < 2 || numel(mouseStdB) < 2
	pValue = NaN;
	return;
end
pValue = ranksum(mouseStdA, mouseStdB);
end

function label = iPairwisePLabel(pValue)
if isfinite(pValue) && pValue < 0.05
	label = '*';
else
	label = iFormatPValue(pValue);
end
end

function iPValueLine(ax, xA, xB, yLine, label, yRange)
tick = 0.035 * yRange;
plot(ax, [xA, xA, xB, xB], [yLine - tick, yLine, yLine, yLine - tick], '-', ...
	'Color', 'k', 'LineWidth', 1.5, 'HandleVisibility', 'off');
text(ax, mean([xA, xB]), yLine + 0.015 * yRange, label, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'FontSize', 10, 'Color', 'k');
end

function [fig, stats] = iPlotSigmoidFitSlopeFigure(Summary, Cond)
nPermutation = 10000;
rngSeed = 1;
stats = iComputeModelSigmoidFitSlopeStats(Summary, Cond, nPermutation, rngSeed);

fig = figure('Color', 'w', 'Name', 'TH model sigmoid fit slopes');
fig.Units = 'centimeters';
fig.Position(3:4) = [18, 12];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 18, 12];
fig.PaperSize = [18, 12];

tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
lineColor = [0, 0, 0];
for iCond = 1:height(Cond)
	ax = nexttile(tl, iCond);
	conditionName = Cond.Name(iCond);
	conditionField = char(conditionName);
	fitStruct = stats.Fit.(conditionField);
	yFit = iModelSigmoidFromParams(fitStruct.ParamRaw, stats.XFit);
	iPlotModelGroupMouseSigmoid(ax, stats.SessionTable.(conditionField), stats.XFit, yFit, lineColor, Cond.Label(iCond), fitStruct, iCond == height(Cond));
	xlabel(ax, 'Session', 'FontSize', 12);
	if iCond == 1 || iCond == 3
		ylabel(ax, 'Hit rate', 'FontSize', 12);
	else
		ylabel(ax, '', 'FontSize', 12);
	end
end

axSlope = nexttile(tl, 4);
iPlotModelSigmoidSlopeBars(axSlope, stats, Cond);

allAxes = findall(fig, 'Type', 'Axes');
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
end

function stats = iComputeModelSigmoidFitSlopeStats(Summary, Cond, nPermutation, rngSeed)
stats = struct;
stats.SessionTable = struct;
stats.Fit = struct;
maxSession = 0;

lower = nan(height(Cond), 1);
upper = nan(height(Cond), 1);
slope = nan(height(Cond), 1);
midpoint = nan(height(Cond), 1);
sse = nan(height(Cond), 1);
rSquared = nan(height(Cond), 1);
for iCond = 1:height(Cond)
	conditionName = Cond.Name(iCond);
	conditionField = char(conditionName);
	sessionTable = iPerformanceMatrixToSessionTable(Summary.Performance.(conditionField), conditionName);
	fitStruct = iFitModelSigmoidCurve(sessionTable, conditionName);
	stats.SessionTable.(conditionField) = sessionTable;
	stats.Fit.(conditionField) = fitStruct;
	maxSession = max(maxSession, max(sessionTable.Session, [], 'omitnan'));
	lower(iCond) = fitStruct.Lower;
	upper(iCond) = fitStruct.Upper;
	slope(iCond) = fitStruct.Slope;
	midpoint(iCond) = fitStruct.Midpoint;
	sse(iCond) = fitStruct.SSE;
	rSquared(iCond) = fitStruct.RSquared;
end
stats.XFit = (1:maxSession)';
stats.FitTable = table(Cond.Name(:), Cond.Label(:), lower, upper, slope, midpoint, sse, rSquared, ...
	'VariableNames', {'Condition','Label','Lower','Upper','Slope','Midpoint','SSE','RSquared'});

baselineIndex = [1; 3; 1];
testIndex = [2; 2; 3];
comparison = strings(numel(baselineIndex), 1);
observedDifference = nan(numel(baselineIndex), 1);
pValue = nan(numel(baselineIndex), 1);
nullMeanDifference = nan(numel(baselineIndex), 1);
nullStdDifference = nan(numel(baselineIndex), 1);
for iComparison = 1:numel(baselineIndex)
	baselineName = Cond.Name(baselineIndex(iComparison));
	testName = Cond.Name(testIndex(iComparison));
	baselineField = char(baselineName);
	testField = char(testName);
	permOut = iPermutationTestModelSigmoidSlope(stats.SessionTable.(baselineField), stats.SessionTable.(testField), nPermutation, rngSeed + iComparison, baselineName, testName);
	comparison(iComparison) = string(Cond.Label(testIndex(iComparison))) + " - " + string(Cond.Label(baselineIndex(iComparison)));
	observedDifference(iComparison) = permOut.ObservedDifference;
	pValue(iComparison) = permOut.PValue;
	nullMeanDifference(iComparison) = mean(permOut.PermutedDifference, 'omitnan');
	nullStdDifference(iComparison) = std(permOut.PermutedDifference, 0, 'omitnan');
end
stats.ComparisonTable = table(comparison, baselineIndex, testIndex, observedDifference, pValue, repmat(nPermutation, numel(baselineIndex), 1), nullMeanDifference, nullStdDifference, ...
	'VariableNames', {'Comparison','BaselineIndex','TestIndex','ObservedDifference','PValue','NPermutation','NullMeanDifference','NullStdDifference'});
end

function T = iPerformanceMatrixToSessionTable(performanceMatrix, conditionName)
[nMice, nSessions] = size(performanceMatrix);
[mouseIndex, sessionIndex] = ndgrid((1:nMice)', (1:nSessions)');
T = table;
T.Mouse = string(conditionName) + "_" + string(compose('%02d', mouseIndex(:)));
T.Session = sessionIndex(:);
T.Performance = performanceMatrix(:);
T.Group = repmat(string(conditionName), numel(T.Performance), 1);
end

function iPlotModelGroupMouseSigmoid(ax, T, xFit, yFit, lineColor, groupLabel, fitStruct, showLegend)
hold(ax, 'on');
T = sortrows(T, {'Mouse','Session'});
mice = unique(string(T.Mouse), 'stable');
lightColor = 1 - (1 - lineColor) * 0.35;
mouseHandles = gobjects(0, 1);
for iMouse = 1:numel(mice)
	rows = string(T.Mouse) == mice(iMouse) & isfinite(T.Session) & isfinite(T.Performance);
	if ~any(rows)
		continue;
	end
	h = plot(ax, T.Session(rows), T.Performance(rows), '-', ...
		'Color', lightColor, 'LineWidth', 0.5, 'Marker', 'none', 'Tag', 'SingleMouseSigmoidCurve');
	if isempty(mouseHandles)
		mouseHandles = h;
	end
end
fitHandle = plot(ax, xFit, yFit, '-', 'Color', lineColor, 'LineWidth', 2.8);
if showLegend && ~isempty(mouseHandles)
	lgd = legend(ax, [mouseHandles(1), fitHandle], {'Per-mouse', 'Sigmoid fit'}, 'Location', 'southeast');
	lgd.FontSize = 9;
	lgd.Box = 'off';
	lgd.NumColumns = 1;
else
	legend(ax, 'off');
end
box(ax, 'off');
grid(ax, 'off');
xlim(ax, [min(xFit), max(xFit)]);
ylim(ax, [0, 1]);
ax.XTick = xFit(:)';
title(ax, {char(groupLabel), sprintf('slope=%.3f', fitStruct.Slope)}, 'FontSize', 10, 'FontWeight', 'normal');
end

function iPlotModelSigmoidSlopeBars(ax, stats, Cond)
hold(ax, 'on');
slope = stats.FitTable.Slope;
barHandle = bar(ax, 1:height(Cond), slope, 0.72, 'FaceColor', 'flat', 'EdgeColor', 'none');
barHandle.CData = Cond.Color;
ax.XLim = [0.5, height(Cond) + 0.5];
ax.XTick = 1:height(Cond);
ax.XTickLabel = cellstr(Cond.Label);
ax.XTickLabelRotation = 20;
yTop = max(slope, [], 'omitnan');
yRange = max(yTop, 0.25);
for iComparison = 1:height(stats.ComparisonTable)
	xA = stats.ComparisonTable.BaselineIndex(iComparison);
	xB = stats.ComparisonTable.TestIndex(iComparison);
	yLine = yTop + (0.12 + 0.16 * (iComparison - 1)) * yRange;
	iPValueLine(ax, xA, xB, yLine, iFormatPValue(stats.ComparisonTable.PValue(iComparison)), yRange);
end
ylim(ax, [0, yTop + 0.72 * yRange]);
ylabel(ax, 'Sigmoid slope', 'FontSize', 12);
title(ax, 'Sigmoid slope', 'FontSize', 10, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
end

function fitOut = iFitModelSigmoidCurve(T, groupName)
T = sortrows(T, {'Mouse','Session'});
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('THModel:NoDataForSigmoidFit', 'No valid session data for group %s.', char(groupName));
end

p0 = [iSigmoidLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); log(max(median(xObs), 1))];
obj = @(p) sum((yObs - iModelSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
yHat = iModelSigmoidFromParams(p, xObs);
sse = sum((yObs - yHat).^2, 'omitnan');
sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if sst == 0
	rSquared = NaN;
else
	rSquared = 1 - sse / sst;
end
[lower, upper, slope, midpoint] = iDecodeModelSigmoidParams(p);
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.ParamRaw = p;
fitOut.Lower = lower;
fitOut.Upper = upper;
fitOut.Slope = slope;
fitOut.Midpoint = midpoint;
fitOut.SSE = sse;
fitOut.RSquared = rSquared;
fitOut.XObserved = xObs;
fitOut.YObserved = yObs;
end

function permOut = iPermutationTestModelSigmoidSlope(tableA, tableB, nPermutation, rngSeed, nameA, nameB)
if nargin < 3 || isempty(nPermutation)
	nPermutation = 2000;
end
if nargin >= 4 && ~isempty(rngSeed)
	rng(rngSeed);
end
tableA = sortrows(tableA, {'Mouse','Session'});
tableB = sortrows(tableB, {'Mouse','Session'});
miceA = unique(string(tableA.Mouse), 'stable');
miceB = unique(string(tableB.Mouse), 'stable');
allMouseTables = cell(numel(miceA) + numel(miceB), 1);
for iMouse = 1:numel(miceA)
	allMouseTables{iMouse} = tableA(string(tableA.Mouse) == miceA(iMouse), :);
end
for iMouse = 1:numel(miceB)
	allMouseTables{numel(miceA) + iMouse} = tableB(string(tableB.Mouse) == miceB(iMouse), :);
end
fitA = iFitModelSigmoidCurve(tableA, nameA);
fitB = iFitModelSigmoidCurve(tableB, nameB);
observedDiff = fitB.Slope - fitA.Slope;
permDiff = nan(nPermutation, 1);
nA = numel(miceA);
parfor iPerm = 1:nPermutation
	ord = randperm(numel(allMouseTables));
	idxA = ord(1:nA);
	idxB = ord(nA+1:end);
	permA = vertcat(allMouseTables{idxA});
	permB = vertcat(allMouseTables{idxB});
	fitPermA = iFitModelSigmoidCurve(permA, "ModelSigmoidPermA");
	fitPermB = iFitModelSigmoidCurve(permB, "ModelSigmoidPermB");
	permDiff(iPerm) = fitPermB.Slope - fitPermA.Slope;
end
permOut = struct;
permOut.ObservedDifference = observedDiff;
permOut.PermutedDifference = permDiff;
permOut.PValue = mean(abs(permDiff) >= abs(observedDiff));
permOut.NPermutation = nPermutation;
end

function y = iModelSigmoidFromParams(p, x)
[lower, upper, slope, midpoint] = iDecodeModelSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeModelSigmoidParams(p)
lower = 1 ./ (1 + exp(-p(1)));
upper = 1;
slope = exp(p(2));
midpoint = exp(p(3));
end

function y = iSigmoidLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
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

function iCheckTransferSignificantlyHighest(PerMouse, SigmoidStats, Cond, Params)
iCheckTransferMetricSignificantlyHighest(PerMouse, Cond, "MeanH5", "Mean L5 heterogeneity", Params.TransferHighestAlpha);
iCheckTransferSigmoidSlopeSignificantlyHighest(SigmoidStats, Cond, Params.TransferHighestAlpha);
end

function iCheckTransferMetricSignificantlyHighest(PerMouse, Cond, metricName, metricLabel, alpha)
metricName = char(metricName);
metricLabel = char(metricLabel);
transferIndex = find(Cond.Name == "Transfer", 1);
transferValues = PerMouse.(Cond.Name(transferIndex)).(metricName);
transferValues = transferValues(isfinite(transferValues));
failedComparisons = strings(0, 1);

for iCond = 1:height(Cond)
	if iCond == transferIndex
		continue;
	end
	otherValues = PerMouse.(Cond.Name(iCond)).(metricName);
	otherValues = otherValues(isfinite(otherValues));
	transferMean = mean(transferValues, 'omitnan');
	otherMean = mean(otherValues, 'omitnan');
	pValue = ranksum(transferValues, otherValues);
	if ~(transferMean > otherMean && pValue < alpha)
		failedComparisons(end + 1, 1) = sprintf('%s: Transfer mean=%.4f, %s mean=%.4f, ranksum p=%.4g', ...
			Cond.Name(iCond), transferMean, Cond.Label(iCond), otherMean, pValue); %#ok<AGROW>
	end
end

if ~isempty(failedComparisons)
	error('THModel:TransferNotSignificantlyHighest', ...
		'Transfer must be significantly highest for %s (alpha=%.3f). %s', ...
		metricLabel, alpha, strjoin(failedComparisons, '; '));
end
end

function iCheckTransferSigmoidSlopeSignificantlyHighest(SigmoidStats, Cond, alpha)
transferIndex = find(Cond.Name == "Transfer", 1);
fitConditionNames = string(SigmoidStats.FitTable.Condition);
transferFitIndex = find(fitConditionNames == "Transfer", 1);
transferSlope = SigmoidStats.FitTable.Slope(transferFitIndex);
failedComparisons = strings(0, 1);

for iCond = 1:height(Cond)
	if iCond == transferIndex
		continue;
	end
	otherFitIndex = find(fitConditionNames == Cond.Name(iCond), 1);
	otherSlope = SigmoidStats.FitTable.Slope(otherFitIndex);
	comparisonIndex = find((SigmoidStats.ComparisonTable.BaselineIndex == iCond & SigmoidStats.ComparisonTable.TestIndex == transferIndex) | ...
		(SigmoidStats.ComparisonTable.BaselineIndex == transferIndex & SigmoidStats.ComparisonTable.TestIndex == iCond), 1);
	pValue = SigmoidStats.ComparisonTable.PValue(comparisonIndex);
	observedDifference = SigmoidStats.ComparisonTable.ObservedDifference(comparisonIndex);
	if SigmoidStats.ComparisonTable.TestIndex(comparisonIndex) == transferIndex
		transferMinusOther = observedDifference;
	else
		transferMinusOther = -observedDifference;
	end
	if ~(transferSlope > otherSlope && transferMinusOther > 0 && pValue < alpha)
		failedComparisons(end + 1, 1) = sprintf('%s: Transfer slope=%.4f, %s slope=%.4f, permutation p=%.4g', ...
			Cond.Name(iCond), transferSlope, Cond.Label(iCond), otherSlope, pValue); %#ok<AGROW>
	end
end

if ~isempty(failedComparisons)
	error('THModel:TransferNotSignificantlyHighest', ...
		'Transfer must be significantly highest for sigmoid slope (alpha=%.3f). %s', ...
		alpha, strjoin(failedComparisons, '; '));
end
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