% Fig382D draft: L5 response heatmap averaged across all formal training units.

svgName = '中文图Fig382D_ModelFormalTrainingMeanUnitDecisionHeatmap_Draft.svg';
conditionNames = ["Naive", "Transfer"];
displayNames = ["Naive", "Continual"];
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
Params = Fig382383Data.Params;
Cond = Fig382383Data.Cond;
seedBase = Fig382383Data.SeedBase;
seedValues = iConditionSeedValues(Params.NumMice, conditionNames, seedBase);

[HeatmapData, RunInfo] = iBuildFormalTrainingMeanUnitL5ResponseHeatmapData(Params, Cond, seedValues, conditionNames, displayNames);
[fig, PlotData] = TransferLearning.PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData, ...
	YLabel=sprintf('%d L5 cells; %d units averaged', HeatmapData.NumCells, HeatmapData.NumUnits), ...
	ColorbarLabel="Response", ...
	FigureName="Draft model all formal units mean L5 response heatmap");
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote draft: %s\n', svgPath);

assignin('base', 'Fig382D_ModelFormalTrainingMeanUnitDraftData', HeatmapData);
assignin('base', 'Fig382D_ModelFormalTrainingMeanUnitDraftRunInfo', RunInfo);
assignin('base', 'Fig382D_ModelFormalTrainingMeanUnitDraftPlotData', PlotData);
assignin('base', 'Fig382D_ModelFormalTrainingMeanUnitDraftSvgPath', svgPath);

function [HeatmapData, RunInfo] = iBuildFormalTrainingMeanUnitL5ResponseHeatmapData(Params, Cond, seedValues, conditionNames, displayNames)
numMice = Params.NumMice;
numConditions = numel(conditionNames);
mouseConditionData = cell(numMice, 1);
mouseInfoRows = cell(numMice, 1);

iPrepareParallelWorkers();
parfor mouseIndex = 1:numMice
	localConditionData = cell(1, numConditions);
	localRows = struct([]);
	for conditionIndex = 1:numConditions
		conditionName = conditionNames(conditionIndex);
		condRow = Cond(Cond.Name == conditionName, :);
		if height(condRow) ~= 1
			error('THModel:UnknownConditionName', 'Expected exactly one condition named %s.', conditionName);
		end

		rng(seedValues(mouseIndex, conditionIndex), 'twister');
		Mouse = TransferLearning.THModel.DrawMouse(Params);
		pretrainReached = true;
		pretrainSessions = 0;
		pretrainFinalHit = NaN;
		if conditionName ~= "Naive"
			[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, condRow);
			pretrainReached = pretrainResult.Reached;
			pretrainSessions = pretrainResult.TrainingSessions;
			pretrainFinalHit = pretrainResult.FinalHit;
			if ~pretrainResult.Reached
				error('THModel:PretrainDidNotReachCeiling', '%s mouse %d pretraining did not reach ceiling within %d sessions. Final observed hit = %.3f.', displayNames(conditionIndex), mouseIndex, Params.MaxPretrainSessions, pretrainResult.FinalHit);
			end
		end

		unitData = iCollectFormalTrainingMeanUnits(Mouse, Params, condRow);
		localConditionData{conditionIndex} = unitData;
		localRows(conditionIndex).Mouse = mouseIndex;
		localRows(conditionIndex).Condition = conditionName;
		localRows(conditionIndex).DisplayName = displayNames(conditionIndex);
		localRows(conditionIndex).Seed = seedValues(mouseIndex, conditionIndex);
		localRows(conditionIndex).PretrainReached = pretrainReached;
		localRows(conditionIndex).PretrainSessions = pretrainSessions;
		localRows(conditionIndex).PretrainFinalHit = pretrainFinalHit;
		localRows(conditionIndex).MeanUnitHitRate = mean(unitData.UnitHitRate, 'omitnan');
		localRows(conditionIndex).FirstUnitHitRate = unitData.UnitHitRate(1);
		localRows(conditionIndex).LastUnitHitRate = unitData.UnitHitRate(end);
		localRows(conditionIndex).FirstPerfectUnit = unitData.FirstPerfectUnit;
		localRows(conditionIndex).NumFormalUnits = Params.NumSessions;
		localRows(conditionIndex).NumTrialsPerUnit = Params.NumTrials;
		localRows(conditionIndex).NumDecisionIterations = Params.RecurrentPasses + 1;
		localRows(conditionIndex).NumCells = Params.NL5;
	end
	mouseConditionData{mouseIndex} = localConditionData;
	mouseInfoRows{mouseIndex} = localRows;
end

conditionData = cell(numConditions, 1);
for conditionIndex = 1:numConditions
	medianResponseCells = cell(numMice, 1);
	unitMedianResponseCells = cell(numMice, 1);
	unitHitRateCells = cell(numMice, 1);
	unitTableCells = cell(numMice, 1);
	trialTableCells = cell(numMice, 1);
	for mouseIndex = 1:numMice
		unitData = mouseConditionData{mouseIndex}{conditionIndex};
		medianResponseCells{mouseIndex} = unitData.MeanUnitResponse;
		unitMedianResponseCells{mouseIndex} = unitData.UnitMedianResponse;
		unitHitRateCells{mouseIndex} = unitData.UnitHitRate;
		unitTable = unitData.UnitTable;
		unitTable.Mouse = repmat(mouseIndex, height(unitTable), 1);
		unitTableCells{mouseIndex} = movevars(unitTable, 'Mouse', 'Before', 1);
		trialTable = unitData.TrialTable;
		trialTable.Mouse = repmat(mouseIndex, height(trialTable), 1);
		trialTableCells{mouseIndex} = movevars(trialTable, 'Mouse', 'Before', 1);
	end
	conditionData{conditionIndex}.MedianDelta = vertcat(medianResponseCells{:});
	conditionData{conditionIndex}.UnitMedianResponse = cat(1, unitMedianResponseCells{:});
	conditionData{conditionIndex}.UnitHitRate = vertcat(unitHitRateCells{:});
	conditionData{conditionIndex}.UnitTable = vertcat(unitTableCells{:});
	conditionData{conditionIndex}.TrialTable = vertcat(trialTableCells{:});
end

HeatmapData = struct();
HeatmapData.ConditionNames = conditionNames;
HeatmapData.DisplayNames = displayNames;
HeatmapData.Iterations = 0:Params.RecurrentPasses;
HeatmapData.NumMice = numMice;
HeatmapData.NumUnits = Params.NumSessions;
HeatmapData.NumCellsPerMouse = Params.NL5;
HeatmapData.NumCells = numMice * Params.NL5;
HeatmapData.Layer = "L5";
HeatmapData.ResponseType = "Response";
HeatmapData.UnitAggregation = "Mean of per-unit trial medians";
HeatmapData.ConditionData = conditionData;
HeatmapData.Naive = conditionData{1};
HeatmapData.Continual = conditionData{2};

infoRows = vertcat(mouseInfoRows{:});
RunInfo = struct2table(infoRows(:));
end

function UnitData = iCollectFormalTrainingMeanUnits(Mouse, Params, Cond)
numUnits = Params.NumSessions;
numL5Cells = Params.NL5;
numDecisionIterations = Params.RecurrentPasses + 1;
unitMedianResponse = nan(numL5Cells, numDecisionIterations, numUnits);
unitHitRate = nan(1, numUnits);
unitMeanDecisionDrive = nan(1, numUnits);
isRepeatedCeilingUnit = false(1, numUnits);
trialTableCells = cell(numUnits, 1);
firstPerfectUnit = NaN;
lastUnitData = [];

for unitIndex = 1:numUnits
	if isfinite(firstPerfectUnit)
		unitMedianResponse(:, :, unitIndex) = lastUnitData.MedianResponse;
		unitHitRate(unitIndex) = Params.Ceiling;
		unitMeanDecisionDrive(unitIndex) = lastUnitData.MeanDecisionDrive;
		isRepeatedCeilingUnit(unitIndex) = true;
		trialTable = iEmptyTrialTable();
		trialTable.Unit = zeros(0, 1);
		trialTableCells{unitIndex} = movevars(trialTable, 'Unit', 'Before', 1);
		continue;
	end

	[oneUnitData, Mouse] = iCollectOneFormalUnitL5Response(Mouse, Params, Cond);
	unitMedianResponse(:, :, unitIndex) = oneUnitData.MedianResponse;
	unitHitRate(unitIndex) = oneUnitData.HitRate;
	unitMeanDecisionDrive(unitIndex) = oneUnitData.MeanDecisionDrive;
	trialTable = oneUnitData.TrialTable;
	trialTable.Unit = repmat(unitIndex, height(trialTable), 1);
	trialTableCells{unitIndex} = movevars(trialTable, 'Unit', 'Before', 1);
	lastUnitData = oneUnitData;
	if oneUnitData.HitRate >= Params.Ceiling
		firstPerfectUnit = unitIndex;
		unitHitRate(unitIndex) = Params.Ceiling;
	end
end

UnitData = struct();
UnitData.MeanUnitResponse = mean(unitMedianResponse, 3, 'omitnan');
UnitData.UnitMedianResponse = unitMedianResponse;
UnitData.UnitHitRate = unitHitRate;
UnitData.UnitMeanDecisionDrive = unitMeanDecisionDrive;
UnitData.FirstPerfectUnit = firstPerfectUnit;
UnitData.TrialTable = vertcat(trialTableCells{:});
UnitData.UnitTable = table((1:numUnits)', unitHitRate(:), unitMeanDecisionDrive(:), isRepeatedCeilingUnit(:), ...
	'VariableNames', {'Unit','HitRate','MeanDecisionDrive','IsRepeatedCeilingUnit'});
end

function [OneUnitData, Mouse] = iCollectOneFormalUnitL5Response(Mouse, Params, Cond)
numTrials = Params.NumTrials;
numL5Cells = Params.NL5;
numDecisionIterations = Params.RecurrentPasses + 1;
eta = Params.FormalHebbRate;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, false);

responseHistory = nan(numL5Cells, numDecisionIterations, numTrials);
decisionDrive = nan(numTrials, 1);
isHit = false(numTrials, 1);
noisePassAttempt = nan(numTrials, 1);
noisePassDecisionDrive = nan(numTrials, 1);

for trialIndex = 1:numTrials
	[Mouse, noisePassState] = TransferLearning.THModel.RunNoiseCueBacktrainingUntilPass(Mouse, Params, eta);
	noisePassAttempt(trialIndex) = noisePassState.Attempt;
	noisePassDecisionDrive(trialIndex) = TransferLearning.THModel.GatherScalar(noisePassState.DecisionDrive);

	cueInput = Mouse.CueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23 = Mouse.CueL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	initialActivity = noisePassState.InternalActivity;
	l23Rows = 1:Params.NL23;
	initialActivity(l23Rows) = TransferLearning.THModel.ClampActivity(initialActivity(l23Rows) + cueInput, Params);
	zeroL5RewardRecvInput = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
	zeroL5ReadInput = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);

	[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue, inhibitoryStateCue, internalHistoryCue, inhibitoryHistoryCue] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivity, noisePassState.InhibitoryState.L23, cueInput, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23, Params.RecurrentPasses, true);
	[~, ~, ~, ~, ~, fullDecisionHistory] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivity, noisePassState.InhibitoryState.L23, cueInput, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23, Params.RecurrentPasses, true, false);

	decisionDrive(trialIndex) = TransferLearning.THModel.GatherScalar(TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadCue, inhibitoryStateCue.L5Read, Params));
	isHit(trialIndex) = decisionDrive(trialIndex) >= Params.HitThreshold;
	displayHistory = TransferLearning.THModel.GatherValue(fullDecisionHistory);
	if isHit(trialIndex)
		displayHistory = iApplyOldHitTeachingToDisplayHistory(displayHistory, Mouse, Params, teachingSignalScale);
	end
	l5Rows = Params.NL23 + (1:Params.NL5);
	responseHistory(:, :, trialIndex) = displayHistory(l5Rows, :);

	[Mouse, ~] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, cueInput, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, teachingSignalScale, eta, 1, inhibitoryStateCue.L23, inhibitoryStateCue.L5Read, internalHistoryCue, inhibitoryHistoryCue);
end

OneUnitData = struct();
OneUnitData.MedianResponse = median(responseHistory, 3, 'omitnan');
OneUnitData.HitRate = mean(isHit, 'omitnan');
OneUnitData.MeanDecisionDrive = mean(decisionDrive, 'omitnan');
OneUnitData.TrialTable = table((1:numTrials)', isHit(:), decisionDrive, noisePassAttempt, noisePassDecisionDrive, ...
	'VariableNames', {'Trial','Hit','DecisionDrive','NoisePassAttempt','NoisePassDecisionDrive'});
end

function displayHistory = iApplyOldHitTeachingToDisplayHistory(displayHistory, Mouse, Params, teachingSignalScale)
l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
l5ReadTeachingActivity = TransferLearning.THModel.PatternActivity(Mouse.L5ReadoutPattern, Params);
displayHistory(l5ReadRows, 2:end) = displayHistory(l5ReadRows, 2:end) + teachingSignalScale * (repmat(l5ReadTeachingActivity(:), 1, Params.RecurrentPasses) - displayHistory(l5ReadRows, 2:end));
end

function TrialTable = iEmptyTrialTable()
TrialTable = table(zeros(0, 1), false(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
	'VariableNames', {'Trial','Hit','DecisionDrive','NoisePassAttempt','NoisePassDecisionDrive'});
end

function seedValues = iConditionSeedValues(numMice, conditionNames, seedBase)
seedValues = nan(numMice, numel(conditionNames));
for conditionIndex = 1:numel(conditionNames)
	conditionOffset = iConditionSeedOffset(conditionNames(conditionIndex));
	for mouseIndex = 1:numMice
		seedValues(mouseIndex, conditionIndex) = mod(seedBase + conditionOffset + mouseIndex * 1009, 2^31 - 2) + 1;
	end
end
end

function conditionOffset = iConditionSeedOffset(conditionName)
switch conditionName
	case "Naive"
		conditionOffset = 101000000;
	case "Transfer"
		conditionOffset = 202000000;
	case "THOff"
		conditionOffset = 303000000;
	otherwise
		conditionOffset = 404000000 + sum(double(char(conditionName))) * 1009;
end
end

function iPrepareParallelWorkers()
pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
end
