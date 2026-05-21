function [HeatmapData, RunInfo] = FirstFormalUnitDecisionHeatmapData(Params, Cond, seedValues, conditionNames, displayNames)
arguments
	Params (1, 1) struct
	Cond table
	seedValues (1, 2) double {mustBeInteger, mustBePositive}
	conditionNames (1, 2) string = ["Naive", "Transfer"]
	displayNames (1, 2) string = ["Naive", "Continual"]
end

conditionData = cell(numel(conditionNames), 1);
pretrainReached = false(numel(conditionNames), 1);
pretrainSessions = nan(numel(conditionNames), 1);
firstUnitHitRate = nan(numel(conditionNames), 1);

for conditionIndex = 1:numel(conditionNames)
	conditionName = conditionNames(conditionIndex);
	condRow = Cond(Cond.Name == conditionName, :);
	rng(seedValues(conditionIndex), 'twister');
	Mouse = TransferLearning.THModel.DrawMouse(Params);
	if conditionName ~= "Naive"
		[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, condRow);
		pretrainReached(conditionIndex) = pretrainResult.Reached;
		pretrainSessions(conditionIndex) = pretrainResult.TrainingSessions;
		if ~pretrainResult.Reached
			error('THModel:PretrainDidNotReachCeiling', '%s pretraining did not reach ceiling within %d sessions. Final observed hit = %.3f.', displayNames(conditionIndex), Params.MaxPretrainSessions, pretrainResult.FinalHit);
		end
	else
		pretrainReached(conditionIndex) = true;
		pretrainSessions(conditionIndex) = 0;
	end
	[conditionData{conditionIndex}, ~] = iCollectFirstFormalUnit(Mouse, Params, condRow);
	firstUnitHitRate(conditionIndex) = mean(conditionData{conditionIndex}.Hit, 'omitnan');
end

HeatmapData = struct();
HeatmapData.ConditionNames = conditionNames;
HeatmapData.DisplayNames = displayNames;
HeatmapData.Iterations = 0:Params.RecurrentPasses;
HeatmapData.NumCells = Params.NL23L5;
HeatmapData.ConditionData = conditionData;
HeatmapData.Naive = conditionData{1};
HeatmapData.Continual = conditionData{2};

RunInfo = table(conditionNames(:), displayNames(:), seedValues(:), pretrainReached, pretrainSessions, firstUnitHitRate, repmat(Params.NumTrials, numel(conditionNames), 1), repmat(Params.RecurrentPasses + 1, numel(conditionNames), 1), repmat(Params.NL23L5, numel(conditionNames), 1), ...
	'VariableNames', {'Condition','DisplayName','Seed','PretrainReached','PretrainSessions','FirstUnitHitRate','NumTrials','NumDecisionIterations','NumCells'});
end

function [UnitData, Mouse] = iCollectFirstFormalUnit(Mouse, Params, Cond)
numTrials = Params.NumTrials;
numCells = Params.NL23L5;
numDecisionIterations = Params.RecurrentPasses + 1;
eta = Params.FormalHebbRate;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, false);

zHistory = nan(numCells, numDecisionIterations, numTrials);
noiseBaselineMean = nan(numCells, numTrials);
noiseBaselineStd = nan(numCells, numTrials);
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
	baselineStd = std(baselineHistory, 0, 2, 'omitnan');
	baselineStd(~isfinite(baselineStd) | baselineStd <= 0) = NaN;
	noiseBaselineMean(:, trialIndex) = baselineMean;
	noiseBaselineStd(:, trialIndex) = baselineStd;

	cueInput = Mouse.CueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23 = Mouse.CueL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	initialActivity = noisePassState.InternalActivity;
	l23Rows = 1:Params.NL23;
	initialActivity(l23Rows) = TransferLearning.THModel.ClampActivity(initialActivity(l23Rows) + cueInput, Params);
	zeroL5RewardRecvInput = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
	zeroL5ReadInput = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);

	[rL23Cue, rL5RewardRecvCue, rL5ReadCue, decisionActivityCue, inhibitoryStateCue, internalHistoryCue] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivity, noisePassState.InhibitoryState.L23, cueInput, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23, Params.RecurrentPasses, true);
	[~, ~, ~, ~, ~, fullDecisionHistory] = TransferLearning.THModel.RunInternalNetworkFromState(initialActivity, noisePassState.InhibitoryState.L23, cueInput, zeroL5RewardRecvInput, zeroL5ReadInput, Mouse, Params, inputIL23, Params.RecurrentPasses, true, false);
	fullDecisionHistory = TransferLearning.THModel.GatherValue(fullDecisionHistory);
	zHistory(:, :, trialIndex) = (fullDecisionHistory - baselineMean) ./ baselineStd;

	decisionDrive(trialIndex) = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, rL5ReadCue, inhibitoryStateCue.L5Read, Params);
	isHit(trialIndex) = decisionDrive(trialIndex) >= Params.HitThreshold;
	[Mouse, ~] = TransferLearning.THModel.ApplyTeachingSignalLearning(Mouse, Params, cueInput, decisionActivityCue, rL23Cue, rL5RewardRecvCue, rL5ReadCue, teachingSignalScale, eta, 1, inhibitoryStateCue.L23, inhibitoryStateCue.L5Read, internalHistoryCue);
end

UnitData = struct();
UnitData.MedianZ = median(zHistory, 3, 'omitnan');
UnitData.ZHistory = zHistory;
UnitData.NoiseBaselineMean = noiseBaselineMean;
UnitData.NoiseBaselineStd = noiseBaselineStd;
UnitData.DecisionDrive = decisionDrive;
UnitData.Hit = isHit(:);
UnitData.TrialTable = table((1:numTrials)', isHit(:), decisionDrive, noisePassAttempt, noisePassDecisionDrive, ...
	'VariableNames', {'Trial','Hit','DecisionDrive','NoisePassAttempt','NoisePassDecisionDrive'});
end
