function [HeatmapData, RunInfo] = FirstFormalUnitDecisionHeatmapData(Params, Cond, seedValues, conditionNames, displayNames)
arguments
	Params (1, 1) struct
	Cond table
	seedValues (:, 2) double {mustBeInteger, mustBePositive}
	conditionNames (1, 2) string = ["Naive", "Transfer"]
	displayNames (1, 2) string = ["Naive", "Continual"]
end

numMice = Params.NumMice;
numConditions = numel(conditionNames);
seedValues = iExpandSeedValues(seedValues, numMice, numConditions);
mouseConditionData = cell(numMice, 1);
mouseInfoRows = cell(numMice, 1);

iPrepareParallelWorkers();
parfor mouseIndex = 1:numMice
	localConditionData = cell(1, numConditions);
	localRows = struct([]);
	for conditionIndex = 1:numConditions
		conditionName = conditionNames(conditionIndex);
		condRow = Cond(Cond.Name == conditionName, :);
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
		[unitData, ~] = iCollectFirstFormalUnit(Mouse, Params, condRow);
		localConditionData{conditionIndex} = unitData;
		localRows(conditionIndex).Mouse = mouseIndex;
		localRows(conditionIndex).Condition = conditionName;
		localRows(conditionIndex).DisplayName = displayNames(conditionIndex);
		localRows(conditionIndex).Seed = seedValues(mouseIndex, conditionIndex);
		localRows(conditionIndex).PretrainReached = pretrainReached;
		localRows(conditionIndex).PretrainSessions = pretrainSessions;
		localRows(conditionIndex).PretrainFinalHit = pretrainFinalHit;
		localRows(conditionIndex).FirstUnitHitRate = mean(unitData.Hit, 'omitnan');
		localRows(conditionIndex).NumTrials = Params.NumTrials;
		localRows(conditionIndex).NumDecisionIterations = Params.RecurrentPasses + 1;
		localRows(conditionIndex).NumCells = Params.NL23L5;
	end
	mouseConditionData{mouseIndex} = localConditionData;
	mouseInfoRows{mouseIndex} = localRows;
end

conditionData = cell(numConditions, 1);
for conditionIndex = 1:numConditions
	medianDeltaCells = cell(numMice, 1);
	deltaHistoryCells = cell(numMice, 1);
	baselineMeanCells = cell(numMice, 1);
	decisionDriveCells = cell(numMice, 1);
	hitCells = cell(numMice, 1);
	trialTableCells = cell(numMice, 1);
	for mouseIndex = 1:numMice
		unitData = mouseConditionData{mouseIndex}{conditionIndex};
		medianDeltaCells{mouseIndex} = unitData.MedianDelta;
		deltaHistoryCells{mouseIndex} = unitData.DeltaHistory;
		baselineMeanCells{mouseIndex} = unitData.NoiseBaselineMean;
		decisionDriveCells{mouseIndex} = unitData.DecisionDrive;
		hitCells{mouseIndex} = unitData.Hit;
		trialTable = unitData.TrialTable;
		trialTable.Mouse = repmat(mouseIndex, height(trialTable), 1);
		trialTableCells{mouseIndex} = movevars(trialTable, 'Mouse', 'Before', 1);
	end
	conditionData{conditionIndex}.MedianDelta = vertcat(medianDeltaCells{:});
	conditionData{conditionIndex}.DeltaHistory = cat(1, deltaHistoryCells{:});
	conditionData{conditionIndex}.NoiseBaselineMean = vertcat(baselineMeanCells{:});
	conditionData{conditionIndex}.DecisionDrive = vertcat(decisionDriveCells{:});
	conditionData{conditionIndex}.Hit = vertcat(hitCells{:});
	conditionData{conditionIndex}.TrialTable = vertcat(trialTableCells{:});
end

HeatmapData = struct();
HeatmapData.ConditionNames = conditionNames;
HeatmapData.DisplayNames = displayNames;
HeatmapData.Iterations = 0:Params.RecurrentPasses;
HeatmapData.NumMice = numMice;
HeatmapData.NumCellsPerMouse = Params.NL23L5;
HeatmapData.NumCells = numMice * Params.NL23L5;
HeatmapData.ConditionData = conditionData;
HeatmapData.Naive = conditionData{1};
HeatmapData.Continual = conditionData{2};

infoRows = vertcat(mouseInfoRows{:});
RunInfo = struct2table(infoRows(:));
end

function [UnitData, Mouse] = iCollectFirstFormalUnit(Mouse, Params, Cond)
numTrials = Params.NumTrials;
numCells = Params.NL23L5;
numDecisionIterations = Params.RecurrentPasses + 1;
eta = Params.HebbRate;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, false);

deltaHistory = nan(numCells, numDecisionIterations, numTrials);
noiseBaselineMean = nan(numCells, numTrials);
decisionDrive = nan(numTrials, 1);
isHit = false(numTrials, 1);
noisePassAttempt = nan(numTrials, 1);
noisePassDecisionDrive = nan(numTrials, 1);

for trialIndex = 1:numTrials
	[Mouse, noisePassState] = TransferLearning.THModel.RunNoiseCueBacktrainingUntilPass(Mouse, Params, eta);
	noisePassAttempt(trialIndex) = noisePassState.Attempt;
	noisePassDecisionDrive(trialIndex) = noisePassState.DecisionDrive;

	baselineHistory = TransferLearning.THModel.GatherValue(noisePassState.InternalHistory);
	baselineMean = mean(baselineHistory, 2, 'omitnan');
	noiseBaselineMean(:, trialIndex) = baselineMean;

	cueInput = Mouse.CueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23 = Mouse.CueL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	initialActivity = noisePassState.InternalActivity;
	l23Rows = 1:Params.NL23;
	initialActivity(l23Rows) = TransferLearning.THModel.ClampActivity(initialActivity(l23Rows) + cueInput, Params);
	zeroL5RewardRecvInput = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
	zeroL5ReadInput = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);

	[Mouse, cueDecision] = TransferLearning.THModel.RunCueDecisionLearningFromState(Mouse, Params, initialActivity, noisePassState.InhibitoryState.L23, cueInput, zeroL5RewardRecvInput, zeroL5ReadInput, inputIL23, eta, teachingSignalScale, Params.RecurrentPasses, true);
	decisionDrive(trialIndex) = cueDecision.DecisionDrive;
	isHit(trialIndex) = cueDecision.Hit;
	displayHistory = TransferLearning.THModel.GatherValue(cueDecision.InternalHistory);
	deltaHistory(:, :, trialIndex) = displayHistory - baselineMean;
end

UnitData = struct();
UnitData.MedianDelta = median(deltaHistory, 3, 'omitnan');
UnitData.DeltaHistory = deltaHistory;
UnitData.NoiseBaselineMean = noiseBaselineMean;
UnitData.DecisionDrive = decisionDrive;
UnitData.Hit = isHit(:);
UnitData.TrialTable = table((1:numTrials)', isHit(:), decisionDrive, noisePassAttempt, noisePassDecisionDrive, ...
	'VariableNames', {'Trial','Hit','DecisionDrive','NoisePassAttempt','NoisePassDecisionDrive'});
end

function seedValues = iExpandSeedValues(seedValues, numMice, numConditions)
if size(seedValues, 2) ~= numConditions
	error('THModel:DecisionHeatmapSeedConditionCountMismatch', 'seedValues must have one column per condition.');
end
if size(seedValues, 1) == numMice
	return;
end
if size(seedValues, 1) ~= 1
	error('THModel:DecisionHeatmapSeedMouseCountMismatch', 'seedValues must have either one row or Params.NumMice rows.');
end
baseSeedValues = seedValues;
seedValues = nan(numMice, numConditions);
for conditionIndex = 1:numConditions
	for mouseIndex = 1:numMice
		seedValues(mouseIndex, conditionIndex) = mod(baseSeedValues(conditionIndex) + (mouseIndex - 1) * 1009 - 1, 2^31 - 2) + 1;
	end
end
end

function iPrepareParallelWorkers()
pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
end
