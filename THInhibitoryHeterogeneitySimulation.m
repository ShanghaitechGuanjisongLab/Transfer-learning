% THInhibitoryHeterogeneitySimulation mainline
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
THForceRerun = true;
outputNameSuffix = iOutputNameSuffix();
svgName = iTaggedSvgName('TH_Mainline_Inhibitory_Heterogeneity_Model.svg', outputNameSuffix);
preWeightDistributionSvgName = iTaggedSvgName('TH_Mainline_PreFormal_Naive_Transfer_Connection_Weight_Distribution.svg', outputNameSuffix);
weightSvgName = iTaggedSvgName('TH_Mainline_Formal_Training_Connection_Type_Weight_SD.svg', outputNameSuffix);
sigmoidSvgName = iTaggedSvgName('TH_Mainline_Sigmoid_Fit_Slope.svg', outputNameSuffix);

Params = TransferLearning.THModel.DefaultParams();
Params = TransferLearning.THModel.ApplyBaseParameterOverrides(Params);
if evalin('base', 'exist(''THNoiseFirstStateCarryoverBranch'', ''var'') && THNoiseFirstStateCarryoverBranch')
	Params.NoiseFirstStateCarryover = 1;
	fprintf('Noise-first state-carryover branch enabled: each trial backtrains noise before cue training.\n');
end
Cond = TransferLearning.THModel.ConditionTable();
if evalin('base', 'exist(''THDebugNonnegativeFormalFailure'', ''var'') && THDebugNonnegativeFormalFailure')
	DebugReport = iRunNonnegativeFormalFailureDebug(Params, Cond);
	assignin('base', 'THNonnegativeFormalFailureDebug', DebugReport);
	return;
end
if evalin('base', 'exist(''THDebugPretrainTrace'', ''var'') && THDebugPretrainTrace')
	DebugReport = iRunPretrainTraceDebug(Params);
	assignin('base', 'THPretrainTraceDebug', DebugReport);
	return;
end
workspaceVarNames = iWorkspaceVariableNames(outputNameSuffix);
if ~THForceRerun && iHasReusableWorkspaceSummary(workspaceVarNames, Params)
	Summary = evalin('base', workspaceVarNames.Summary);
	if evalin('base', sprintf('exist(''%s'', ''var'')', workspaceVarNames.Params)) == 1
		Params = evalin('base', workspaceVarNames.Params);
	end
	if evalin('base', sprintf('exist(''%s'', ''var'')', workspaceVarNames.Cond)) == 1
		Cond = evalin('base', workspaceVarNames.Cond);
	end
	fprintf('Using workspace variable %s for plotting; set THForceRerun=true to retrain.\n', workspaceVarNames.Summary);
else
	if THForceRerun
		fprintf('THForceRerun=true; retraining instead of using workspace variable %s.\n', workspaceVarNames.Summary);
	end
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
	fprintf('%s: first-session hit = %.3f, last-session hit = %.3f\n', name, mean(perf(:, 1), 'omitnan'), mean(perf(:, end), 'omitnan'));
	fprintf('%s: mean process L2/3 heterogeneity = %.3f, mean process L5 heterogeneity = %.3f\n', name, mean(Summary.PerMouse.(name).MeanH23, 'omitnan'), mean(Summary.PerMouse.(name).MeanH5, 'omitnan'));
	fprintf('%s: mean slope = %.3f, mean DeltaHit = %.3f\n', name, mean(slope, 'omitnan'), mean(dh, 'omitnan'));
end

iCheckNaiveLastSessionExceedsFirst(Summary.Performance, Cond);
iCheckTransferTHOffFirstSessionHitBelowMax(Summary.Performance, Cond, Params.TransferTHOffFirstSessionHitMax);
iCheckTransferPerfectWithinSessions(Summary.Performance, Cond, Params.NumSessions, Params.Ceiling);
iCheckTransferMetricSignificantlyHighest(Summary.PerMouse, Cond, "MeanH5", "Mean L5 heterogeneity", Params.TransferHighestAlpha);

f = figure('Color', 'w', 'Name', 'TH inhibitory heterogeneity model');
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

preWeightDistributionFig = iPlotPreFormalConnectionWeightDistributions(Summary, Cond, Params);
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
sigmoidWorkspaceName = char("THInhibitoryHeterogeneitySigmoidFitSlopeMainline" + iWorkspaceNameSuffix(outputNameSuffix));
assignin('base', sigmoidWorkspaceName, SigmoidStats);
fprintf('Wrote: %s\n', sigmoidSvgPath);
iCheckTransferSigmoidSlopeSignificantlyHighest(SigmoidStats, Cond, Params.TransferHighestAlpha);

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
workspaceVarNames.Summary = char("THInhibitoryHeterogeneityModelMainline" + workspaceSuffix);
workspaceVarNames.Params = char("THInhibitoryHeterogeneityParamsMainline" + workspaceSuffix);
workspaceVarNames.Cond = char("THInhibitoryHeterogeneityConditionsMainline" + workspaceSuffix);
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
pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
end

function classification = iFormalTrainingConnectionWeightClassification()
classification = "mainline_connection-type_EE-EI-IE-II_raw-synaptic-weights_global-hebb_l23i-cue-l5-projection_l5i-readout_sync-recurrent-v1";
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

function DebugReport = iRunPretrainTraceDebug(Params)
numDebugMice = min(4, Params.NumMice);
if evalin('base', 'exist(''THDebugPretrainTraceNumMice'', ''var'')')
	numDebugMice = evalin('base', 'THDebugPretrainTraceNumMice');
end
conditionNames = ["Transfer", "THOff"];
pretrainCond.RewardInputLevel = 1.00;
rows = struct([]);
traceCells = cell(numel(conditionNames) * numDebugMice, 1);
diagnosticCells = cell(numel(conditionNames) * numDebugMice, 1);
rowIndex = 0;
for iCond = 1:numel(conditionNames)
	condName = conditionNames(iCond);
	for iMouse = 1:numDebugMice
		Mouse = TransferLearning.THModel.DrawMouse(Params);
		initialDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, true);
		initialDriveNoInh = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, true);
		initialWeights = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
		trace = nan(Params.MaxPretrainSessions, 1);
		driveTrace = nan(Params.MaxPretrainSessions + 1, 1);
		driveNoInhTrace = nan(Params.MaxPretrainSessions + 1, 1);
		cueMeanTrace = nan(Params.MaxPretrainSessions + 1, 1);
		internalMeanTrace = nan(Params.MaxPretrainSessions + 1, 1);
		l5ReadWIEMeanTrace = nan(Params.MaxPretrainSessions + 1, 1);
		l5ReadWEIMeanTrace = nan(Params.MaxPretrainSessions + 1, 1);
		driveTrace(1) = initialDrive;
		driveNoInhTrace(1) = initialDriveNoInh;
		cueMeanTrace(1) = initialWeights.CueMean;
		internalMeanTrace(1) = initialWeights.InternalMean;
		l5ReadWIEMeanTrace(1) = initialWeights.L5ReadWIEMean;
		l5ReadWEIMeanTrace(1) = initialWeights.L5ReadWEIMean;
		stopSession = Params.MaxPretrainSessions;
		for iSess = 1:Params.MaxPretrainSessions
			[perfObserved, ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, pretrainCond, true);
			trace(iSess) = perfObserved;
			postWeights = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
			driveTrace(iSess + 1) = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, true);
			driveNoInhTrace(iSess + 1) = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, true);
			cueMeanTrace(iSess + 1) = postWeights.CueMean;
			internalMeanTrace(iSess + 1) = postWeights.InternalMean;
			l5ReadWIEMeanTrace(iSess + 1) = postWeights.L5ReadWIEMean;
			l5ReadWEIMeanTrace(iSess + 1) = postWeights.L5ReadWEIMean;
			if perfObserved >= Params.Ceiling
				stopSession = iSess;
				trace(iSess) = Params.Ceiling;
				break;
			end
		end
		if stopSession < Params.MaxPretrainSessions
			trace(stopSession + 1:end) = Params.Ceiling;
			driveTrace(stopSession + 2:end) = driveTrace(stopSession + 1);
			driveNoInhTrace(stopSession + 2:end) = driveNoInhTrace(stopSession + 1);
			cueMeanTrace(stopSession + 2:end) = cueMeanTrace(stopSession + 1);
			internalMeanTrace(stopSession + 2:end) = internalMeanTrace(stopSession + 1);
			l5ReadWIEMeanTrace(stopSession + 2:end) = l5ReadWIEMeanTrace(stopSession + 1);
			l5ReadWEIMeanTrace(stopSession + 2:end) = l5ReadWEIMeanTrace(stopSession + 1);
		end
		rowIndex = rowIndex + 1;
		traceCells{rowIndex} = trace;
		diagnosticCells{rowIndex} = table((0:Params.MaxPretrainSessions)', [NaN; trace], driveTrace, driveNoInhTrace, cueMeanTrace, internalMeanTrace, l5ReadWIEMeanTrace, l5ReadWEIMeanTrace, ...
			'VariableNames', {'Session','Hit','Drive','DriveNoInh','CueMean','InternalMean','L5ReadWIEMean','L5ReadWEIMean'});
		rows(rowIndex).Condition = condName;
		rows(rowIndex).Mouse = iMouse;
		rows(rowIndex).InitialDrive = initialDrive;
		rows(rowIndex).InitialDriveNoInh = initialDriveNoInh;
		rows(rowIndex).FirstHit = trace(1);
		rows(rowIndex).MaxHit = max(trace, [], 'omitnan');
		rows(rowIndex).LastHit = trace(end);
		rows(rowIndex).NonzeroSessions = sum(trace > 0, 'omitnan');
		firstNonzero = find(trace > 0, 1, 'first');
		if isempty(firstNonzero)
			firstNonzero = NaN;
		end
		rows(rowIndex).FirstNonzeroSession = firstNonzero;
		rows(rowIndex).StopSession = stopSession;
		rows(rowIndex).FinalDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, true);
		rows(rowIndex).FinalDriveNoInh = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, true);
	end
end
DebugReport.MouseTable = struct2table(rows);
DebugReport.Trace = traceCells(1:rowIndex);
DebugReport.Diagnostics = diagnosticCells(1:rowIndex);
disp(DebugReport.MouseTable(:, {'Condition','Mouse','FirstHit','MaxHit','LastHit','NonzeroSessions','FirstNonzeroSession','StopSession','InitialDrive','FinalDrive','InitialDriveNoInh','FinalDriveNoInh'}));
end

function row = iRunNonnegativeFormalFailureMouse(Params, condRow, condName, iMouse, numFormalDiagnosticSessions)
Mouse = TransferLearning.THModel.DrawMouse(Params);
pretrainPerf = NaN;
pretrainSessions = 0;
if condName ~= "Naive"
	[Mouse, pretrainPerfTrace, pretrainSessions] = iPretrainMouseWithTrace(Mouse, Params);
	pretrainPerf = pretrainPerfTrace(pretrainSessions);
end
preDiag = iDecisionProbeSet(Mouse, Params, condRow);
preWeights = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
formalPerf = nan(1, numFormalDiagnosticSessions);
sessionMeanL5 = nan(Params.NL5, numFormalDiagnosticSessions);
sessionMeanL5RewardRecv = nan(Params.NL5RewardRecv, numFormalDiagnosticSessions);
sessionMeanL5Read = nan(Params.NL5Read, numFormalDiagnosticSessions);
[formalPerf(1), Signals, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, condRow, false);
sessionMeanL5(:, 1) = Signals.ProcessMeanL5;
sessionMeanL5RewardRecv(:, 1) = Signals.ProcessMeanL5RewardRecv;
sessionMeanL5Read(:, 1) = Signals.ProcessMeanL5Read;
afterFirstDiag = iDecisionProbeSet(Mouse, Params, condRow);
firstPerfectSession = NaN;
if formalPerf(1) >= Params.Ceiling
	firstPerfectSession = 1;
	formalPerf(1) = Params.Ceiling;
end
for iSess = 2:numFormalDiagnosticSessions
	if isfinite(firstPerfectSession)
		formalPerf(iSess) = Params.Ceiling;
		sessionMeanL5(:, iSess) = sessionMeanL5(:, iSess - 1);
		sessionMeanL5RewardRecv(:, iSess) = sessionMeanL5RewardRecv(:, iSess - 1);
		sessionMeanL5Read(:, iSess) = sessionMeanL5Read(:, iSess - 1);
		continue;
	end
	[formalPerf(iSess), Signals, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, condRow, false);
	sessionMeanL5(:, iSess) = Signals.ProcessMeanL5;
	sessionMeanL5RewardRecv(:, iSess) = Signals.ProcessMeanL5RewardRecv;
	sessionMeanL5Read(:, iSess) = Signals.ProcessMeanL5Read;
	if formalPerf(iSess) >= Params.Ceiling
		firstPerfectSession = iSess;
		formalPerf(iSess) = Params.Ceiling;
	end
end
finalDiag = iDecisionProbeSet(Mouse, Params, condRow);
finalWeights = TransferLearning.THModel.PlasticWeightDebugSummary(Mouse, Params);
formalMeanH5 = iRestrictedStd(mean(sessionMeanL5, 2, 'omitnan'));
formalMeanH5RewardRecv = iRestrictedStd(mean(sessionMeanL5RewardRecv, 2, 'omitnan'));
formalMeanH5Read = iRestrictedStd(mean(sessionMeanL5Read, 2, 'omitnan'));
row = iNonnegativeFormalFailureRow(condName, iMouse, pretrainSessions, pretrainPerf, formalPerf, formalMeanH5, formalMeanH5RewardRecv, formalMeanH5Read, preDiag, afterFirstDiag, finalDiag, preWeights, finalWeights, Mouse);
end

function [Mouse, perfTrace, firstPerfectSession] = iPretrainMouseWithTrace(Mouse, Params)
pretrainCond.RewardInputLevel = 1.00;
[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, pretrainCond);
perfTrace = pretrainResult.Performance(:);
firstPerfectSession = pretrainResult.FirstPerfectSession;
if pretrainResult.Reached
	return;
end
error('THModel:PretrainDidNotReachCeiling', 'Debug pretraining did not reach ceiling within %d sessions. Final observed hit = %.3f.', Params.MaxPretrainSessions, pretrainResult.FinalHit);
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

function diag = iDecisionProbeSet(Mouse, Params, ~)
diag.PreCueDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, true);
diag.FormalCueDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, false);
diag.FormalCueDriveNoInh = TransferLearning.THModel.CueDecisionDriveNoLocalInh(Mouse, Params, false);
	[randomMean, randomMax, randomHitFraction] = iRandomCueDecisionStats(Mouse, Params, 30);
diag.RandomCueMeanDrive = randomMean;
diag.RandomCueMaxDrive = randomMax;
diag.RandomCueHitFraction = randomHitFraction;
end

function [randomMean, randomMax, randomHitFraction] = iRandomCueDecisionStats(Mouse, Params, numSamples)
drives = nan(numSamples, 1);
ProbeParams = Params;
ProbeParams.NoiseScale = 0;
for iSample = 1:numSamples
	cueInput = ProbeParams.CueInputGain * iStandardize(iRandn([ProbeParams.NCueInput, 1], ProbeParams));
	inputIL23 = ProbeParams.CueInputGain * TransferLearning.THModel.BinaryPattern(iStandardize(iRandn([ProbeParams.NIL23, 1], ProbeParams)));
	preL23 = cueInput;
	preL5RewardRecv = iZeros([ProbeParams.NL5RewardRecv, 1], ProbeParams);
	preL5Read = iZeros([ProbeParams.NL5Read, 1], ProbeParams);
	[~, ~, rL5Read, ~, inhibitoryState] = TransferLearning.THModel.RunInternalNetwork(preL23, preL5RewardRecv, preL5Read, Mouse, ProbeParams, inputIL23);
	drives(iSample) = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5Read, inhibitoryState.L5Read, ProbeParams);
end
randomMean = mean(drives, 'omitnan');
randomMax = max(drives);
randomHitFraction = mean(drives >= Params.HitThreshold, 'omitnan');
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
AllCond = strings(0, 1);
classNames = iConnectionClassNames();

for iCond = 1:height(Cond)
	perf = nan(Params.NumMice, Params.NumSessions);
	h23 = nan(Params.NumMice, Params.NumSessions);
	h5 = nan(Params.NumMice, Params.NumSessions);
		perMouse = table('Size', [Params.NumMice, 6], 'VariableTypes', {'double','double','double','double','double','double'}, ...
			'VariableNames', {'Slope','MeanDeltaHit','MeanH23','MeanH5','MeanH5RewardRecv','MeanH5Read'});
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
	if condName == "Transfer"
		firstTrainingUnitCells = cell(Params.NumMice, 1);
		parfor iMouse = 1:Params.NumMice
			firstTrainingUnitCells{iMouse} = iRunOneMouseFirstTrainingUnit(Params, condRow, condName);
		end
		firstSessionHit = nan(Params.NumMice, 1);
		for iMouse = 1:Params.NumMice
			firstSessionHit(iMouse) = firstTrainingUnitCells{iMouse}.FirstSessionHit;
		end
		iCheckTransferFirstTrainingUnitMeanHit(firstSessionHit, Params.TransferTHOffFirstSessionHitMax);
		parfor iMouse = 1:Params.NumMice
			mouseResultCells{iMouse} = iFinishOneMouseTaskFromFirstTrainingUnit(Params, condRow, firstTrainingUnitCells{iMouse});
		end
	else
		parfor iMouse = 1:Params.NumMice
			mouseResultCells{iMouse} = iRunOneMouseTask(Params, condRow, condName);
		end
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
	AllCond = [AllCond; repmat(Cond.Name(iCond), Params.NumMice, 1)]; %#ok<AGROW>
end

Summary.AllMouse = table(AllCond, AllSlope, AllH23, AllH5, AllH5RewardRecv, AllH5Read, ...
	'VariableNames', {'Condition','Slope','MeanH23','MeanH5','MeanH5RewardRecv','MeanH5Read'});
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

function mouseResult = iRunOneMouseTask(Params, Cond, condName)
Mouse = TransferLearning.THModel.DrawMouse(Params);
if condName ~= "Naive"
	% Pretraining shapes internal matrices + inhibitory gains.
	% No artificial pruning on task switch: the same M2 L2/3 and L5
	% populations carry both modalities, so synapses are fully inherited.
	% The "transfer advantage" emerges naturally because
	% (i) CueInputPattern and PreCueInputPattern share sensory input dimensions
	%     (cross-modal correlation = Params.CueModalityCorr), and
	% (ii) the all-to-all L2/3-L5 recurrent matrix encodes a task schema that is
	%     common to both cues.
	% between pretraining and the new task.
	Mouse = iPretrainMouse(Mouse, Params);
end
formalTrainingConnectionWeightsPre = iCollectConnectionTypeWeights(Mouse, Params);
[MouseResult, Mouse] = TransferLearning.THModel.SimulateFormalTraining(Mouse, Params, Cond);
formalTrainingConnectionWeightsPost = iCollectConnectionTypeWeights(Mouse, Params);
mouseResult = iBuildMouseTaskResult(MouseResult, formalTrainingConnectionWeightsPre, formalTrainingConnectionWeightsPost);
end

function firstTrainingUnit = iRunOneMouseFirstTrainingUnit(Params, Cond, condName)
Mouse = TransferLearning.THModel.DrawMouse(Params);
if condName ~= "Naive"
	Mouse = iPretrainMouse(Mouse, Params);
end
formalTrainingConnectionWeightsPre = iCollectConnectionTypeWeights(Mouse, Params);
[MouseResult, Mouse, FormalTrainingState] = TransferLearning.THModel.SimulateFormalTraining(Mouse, Params, Cond, 1);
firstTrainingUnit.Mouse = Mouse;
firstTrainingUnit.FormalTrainingState = FormalTrainingState;
firstTrainingUnit.FormalTrainingConnectionWeightsPre = formalTrainingConnectionWeightsPre;
firstTrainingUnit.FirstSessionHit = iGatherScalar(MouseResult.Performance(1));
end

function mouseResult = iFinishOneMouseTaskFromFirstTrainingUnit(Params, Cond, firstTrainingUnit)
[MouseResult, Mouse] = TransferLearning.THModel.SimulateFormalTraining(firstTrainingUnit.Mouse, Params, Cond, Params.NumSessions, firstTrainingUnit.FormalTrainingState);
formalTrainingConnectionWeightsPost = iCollectConnectionTypeWeights(Mouse, Params);
mouseResult = iBuildMouseTaskResult(MouseResult, firstTrainingUnit.FormalTrainingConnectionWeightsPre, formalTrainingConnectionWeightsPost);
end

function iCheckTransferFirstTrainingUnitMeanHit(firstSessionHit, maxFirstSessionMeanHit)
firstSessionMeanHit = mean(firstSessionHit, 'omitnan');
if isfinite(firstSessionMeanHit) && firstSessionMeanHit <= maxFirstSessionMeanHit
	return;
end
error('THModel:TransferFirstSessionMeanHitTooHigh', ...
	'Transfer first training unit mean hit rate across all mice must be <= %.3f. Observed %.3f.', ...
	maxFirstSessionMeanHit, firstSessionMeanHit);
end

function mouseResult = iBuildMouseTaskResult(MouseResult, formalTrainingConnectionWeightsPre, formalTrainingConnectionWeightsPost)
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
end

function Mouse = iPretrainMouse(Mouse, Params)
% Pretraining uses PreCueInputPattern and keeps reward input intact.
pretrainCond.RewardInputLevel = 1.00;
[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, pretrainCond);
if pretrainResult.Reached
	return;
end

error('THModel:PretrainDidNotReachCeiling', 'Pretraining did not reach ceiling within %d sessions. Final observed hit = %.3f.', Params.MaxPretrainSessions, pretrainResult.FinalHit);
end

function weightClasses = iCollectConnectionTypeWeights(Mouse, ~)
weightClasses = iEmptyConnectionClassWeights();

weightClasses = iAppendConnectionClassWeights(weightClasses, "EE", TransferLearning.THModel.NonSelfInternalWeights(Mouse.W_L23L5ToL23L5));
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WEI_L23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WIE_L23);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", TransferLearning.THModel.NonSelfInternalWeights(Mouse.WII_L23));
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WEI_L5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WIE_L5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", TransferLearning.THModel.NonSelfInternalWeights(Mouse.WII_L5RewardRecv));
weightClasses = iAppendConnectionClassWeights(weightClasses, "EI", Mouse.WEI_L5Read);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WIE_L5Read);
weightClasses = iAppendConnectionClassWeights(weightClasses, "II", TransferLearning.THModel.NonSelfInternalWeights(Mouse.WII_L5Read));
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WI23ToL5RewardRecv);
weightClasses = iAppendConnectionClassWeights(weightClasses, "IE", Mouse.WI23ToL5Read);
end

function weightClasses = iEmptyConnectionClassWeights()
classNames = iConnectionClassNames();
for iClass = 1:numel(classNames)
	weightClasses.(classNames(iClass)) = [];
end
end

function weightClasses = iAppendConnectionClassWeights(weightClasses, className, weights)
weights = iGatherValue(weights(:));
weights = weights(isfinite(weights) & weights > 0);
weightClasses.(className) = [weightClasses.(className); weights];
end

function classNames = iConnectionClassNames()
classNames = ["EE", "EI", "IE", "II"];
end

function classLabels = iConnectionClassLabels()
classLabels = ["EE", "EI", "IE", "II"];
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

function fDist = iPlotPreFormalConnectionWeightDistributions(Summary, Cond, Params)
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
		plotValues = weights(weights > 0);
		plotValues = plotValues(isfinite(plotValues));
		plotValuesByCondition{iPlotCond} = plotValues;
		allPlotValues = [allPlotValues; plotValues]; %#ok<AGROW>
	end
	allPlotValues = allPlotValues(isfinite(allPlotValues));
	if isempty(allPlotValues)
		allPlotValues = [eps; Params.WeightMax];
	end
	displayMin = min([eps; allPlotValues], [], 'omitnan');
	displayMax = max([Params.WeightMax; allPlotValues], [], 'omitnan');
	edges = linspace(displayMin, displayMax, 90);
	for iPlotCond = 1:numel(plotConditionNames)
		condName = plotConditionNames(iPlotCond);
		condIdx = find(Cond.Name == condName, 1, 'first');
		plotValues = plotValuesByCondition{iPlotCond};
		legendHandles(iPlotCond) = histogram(ax, plotValues, edges, 'Normalization', 'probability', ...
			'DisplayStyle', 'stairs', 'EdgeColor', Cond.Color(condIdx, :), 'LineWidth', 1.8);
	end
	iStyleLinePanel(ax);
	xlabel(ax, 'Positive connection weight', 'FontSize', 12);
	ylabel(ax, 'Bin probability', 'FontSize', 12);
	title(ax, classLabels(iClass), 'FontSize', 12, 'FontWeight', 'normal');
	xlim(ax, [displayMin, displayMax]);
	ax.FontSize = 12;
	ax.LineWidth = 2;
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

legendLabels = cellstr(Cond.Label(ismember(Cond.Name, plotConditionNames)));
lgd = legend(legendHandles, legendLabels, 'Location', 'north', 'Box', 'off', ...
	'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', numel(legendLabels));
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

function [fig, stats] = iPlotSigmoidFitSlopeFigure(Summary, Cond, stats)
if nargin < 3 || isempty(stats)
	nPermutation = 10000;
	rngSeed = 1;
	stats = iComputeModelSigmoidFitSlopeStats(Summary, Cond, nPermutation, rngSeed);
end

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

function iCheckNaiveLastSessionExceedsFirst(Performance, Cond)
naiveIndex = find(Cond.Name == "Naive", 1);
naivePerformance = Performance.(Cond.Name(naiveIndex));
firstSessionHit = naivePerformance(:, 1);
lastSessionHit = naivePerformance(:, end);
failedMouseIndex = find(~(lastSessionHit > firstSessionHit));
if ~isempty(failedMouseIndex)
	failureText = strings(numel(failedMouseIndex), 1);
	for iFailure = 1:numel(failedMouseIndex)
		iMouse = failedMouseIndex(iFailure);
		failureText(iFailure) = sprintf('mouse %d: first=%.4f, last=%.4f', iMouse, firstSessionHit(iMouse), lastSessionHit(iMouse));
	end
	error('THModel:NaiveLastSessionNotAboveFirst', ...
		'Every Naive mouse must have last-session hit rate above first-session hit rate. %s', ...
		strjoin(failureText, '; '));
end
end

function iCheckTransferTHOffFirstSessionHitBelowMax(Performance, Cond, maxFirstSessionHit)
conditionNamesToCheck = ["Transfer", "THOff"];
failedConditions = strings(0, 1);
for iCondition = 1:numel(conditionNamesToCheck)
	condName = conditionNamesToCheck(iCondition);
	condIndex = find(Cond.Name == condName, 1);
	if isempty(condIndex)
		error('THModel:MissingFirstSessionCapCondition', ...
			'Condition %s is required for first-session hit-rate acceptance.', condName);
	end
	conditionPerformance = Performance.(Cond.Name(condIndex));
	firstSessionMean = mean(conditionPerformance(:, 1), 'omitnan');
	if ~(isfinite(firstSessionMean) && firstSessionMean <= maxFirstSessionHit)
		failedConditions(end + 1, 1) = sprintf('%s first-session mean=%.4f, max allowed=%.4f', ...
			condName, firstSessionMean, maxFirstSessionHit); %#ok<AGROW>
	end
end

if ~isempty(failedConditions)
	error('THModel:TransferTHOffFirstSessionHitTooHigh', ...
		'Transfer and THOff first-session mean hit rates must be <= %.3f. %s', ...
		maxFirstSessionHit, strjoin(failedConditions, '; '));
end
end

function iCheckTransferPerfectWithinSessions(Performance, Cond, maxSession, ceilingHit)
conditionName = "Transfer";
condIndex = find(Cond.Name == conditionName, 1);
if isempty(condIndex)
	error('THModel:MissingTransferPerfectCondition', ...
		'Condition %s is required for perfect-hit acceptance.', conditionName);
end
transferPerf = Performance.(Cond.Name(condIndex));
windowPerf = transferPerf(:, 1:maxSession);
reachedPerfect = any(windowPerf >= ceilingHit, 2);
if all(reachedPerfect)
	return;
end
failedMouse = find(~reachedPerfect);
bestHit = max(windowPerf(failedMouse, :), [], 2, 'omitnan');
failureText = strings(numel(failedMouse), 1);
for iFail = 1:numel(failedMouse)
	failureText(iFail) = sprintf('mouse %d max=%.3f', failedMouse(iFail), bestHit(iFail));
end
error('THModel:TransferDidNotReachPerfectHitWithinWindow', ...
	'Every Transfer mouse must reach %.3f hit within %d training units. %s', ...
	ceilingHit, maxSession, strjoin(failureText, '; '));
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
