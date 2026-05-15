function Report = BatchEvaluateNaiveTransferSlopeTuning(BaseParams, CandidateTable, seedBases, numMice)
if nargin < 1 || isempty(BaseParams)
	BaseParams = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(CandidateTable)
	CandidateTable = table;
end
if nargin < 3 || isempty(seedBases)
	seedBases = 1;
end
if nargin < 4 || isempty(numMice)
	numMice = BaseParams.NumMice;
end
if isstruct(CandidateTable)
	CandidateTable = struct2table(CandidateTable);
end
if isempty(CandidateTable)
	CandidateTable = table("Base", 'VariableNames', {'Label'});
end

seedBases = double(seedBases(:));
numCandidates = height(CandidateTable);
numSeeds = numel(seedBases);
numTasks = numCandidates * numSeeds * numMice;
numSessions = BaseParams.NumSessions;
taskSeedValues = iTaskSeedValues(seedBases, numCandidates, numMice);

naivePerf = nan(numTasks, numSessions);
transferPerf = nan(numTasks, numSessions);
naiveSlope = nan(numTasks, 1);
transferSlope = nan(numTasks, 1);
naiveFirstPerfectSession = nan(numTasks, 1);
transferFirstPerfectSession = nan(numTasks, 1);
pretrainReached = false(numTasks, 1);
pretrainSessions = nan(numTasks, 1);
pretrainFinalHit = nan(numTasks, 1);
taskElapsedSeconds = nan(numTasks, 1);
taskWorkerID = nan(numTasks, 1);
taskUsedGPU = false(numTasks, 1);

useParallel = numTasks > 1 && ~isempty(gcp('nocreate'));
if useParallel
	parfor taskIndex = 1:numTasks
		taskTimer = tic;
		taskWorkerID(taskIndex) = iCurrentWorkerID();
		taskUsedGPU(taskIndex) = TransferLearning.THModel.UseGPU();
		[candidateIndex, ~, ~] = iTaskSubscripts(taskIndex, numCandidates, numSeeds, numMice);
		Params = iParamsForCandidate(BaseParams, CandidateTable, candidateIndex);
		seedValue = taskSeedValues(taskIndex);
		[naivePerfRow, transferPerfRow, naiveSlopeValue, transferSlopeValue, naiveFirstPerfectValue, transferFirstPerfectValue, pretrainReachedValue, pretrainSessionsValue, pretrainFinalHitValue] = iEvaluateOneMouse(Params, seedValue);
		naivePerf(taskIndex, :) = naivePerfRow;
		transferPerf(taskIndex, :) = transferPerfRow;
		naiveSlope(taskIndex) = naiveSlopeValue;
		transferSlope(taskIndex) = transferSlopeValue;
		naiveFirstPerfectSession(taskIndex) = naiveFirstPerfectValue;
		transferFirstPerfectSession(taskIndex) = transferFirstPerfectValue;
		pretrainReached(taskIndex) = pretrainReachedValue;
		pretrainSessions(taskIndex) = pretrainSessionsValue;
		pretrainFinalHit(taskIndex) = pretrainFinalHitValue;
		taskElapsedSeconds(taskIndex) = toc(taskTimer);
	end
else
	for taskIndex = 1:numTasks
		taskTimer = tic;
		taskWorkerID(taskIndex) = iCurrentWorkerID();
		taskUsedGPU(taskIndex) = TransferLearning.THModel.UseGPU();
		[candidateIndex, ~, ~] = iTaskSubscripts(taskIndex, numCandidates, numSeeds, numMice);
		Params = iParamsForCandidate(BaseParams, CandidateTable, candidateIndex);
		seedValue = taskSeedValues(taskIndex);
		[naivePerfRow, transferPerfRow, naiveSlopeValue, transferSlopeValue, naiveFirstPerfectValue, transferFirstPerfectValue, pretrainReachedValue, pretrainSessionsValue, pretrainFinalHitValue] = iEvaluateOneMouse(Params, seedValue);
		naivePerf(taskIndex, :) = naivePerfRow;
		transferPerf(taskIndex, :) = transferPerfRow;
		naiveSlope(taskIndex) = naiveSlopeValue;
		transferSlope(taskIndex) = transferSlopeValue;
		naiveFirstPerfectSession(taskIndex) = naiveFirstPerfectValue;
		transferFirstPerfectSession(taskIndex) = transferFirstPerfectValue;
		pretrainReached(taskIndex) = pretrainReachedValue;
		pretrainSessions(taskIndex) = pretrainSessionsValue;
		pretrainFinalHit(taskIndex) = pretrainFinalHitValue;
		taskElapsedSeconds(taskIndex) = toc(taskTimer);
	end
end

TaskTable = iBuildTaskTable(CandidateTable, seedBases, numMice, taskSeedValues, taskElapsedSeconds, taskWorkerID, taskUsedGPU, pretrainReached, pretrainSessions, pretrainFinalHit);
RunTable = iBuildRunTable(CandidateTable, seedBases, numMice, naivePerf, transferPerf, naiveSlope, transferSlope, naiveFirstPerfectSession, transferFirstPerfectSession, pretrainReached, pretrainSessions, pretrainFinalHit);
CandidateSummary = iBuildCandidateSummary(CandidateTable, RunTable, numCandidates);

Report = struct;
Report.BaseParams = BaseParams;
Report.CandidateTable = CandidateTable;
Report.SeedBases = seedBases;
Report.NumMice = numMice;
Report.TaskTable = TaskTable;
Report.RunTable = RunTable;
Report.CandidateSummary = CandidateSummary;
Report.NaivePerf = naivePerf;
Report.TransferPerf = transferPerf;
Report.NaiveSlope = naiveSlope;
Report.TransferSlope = transferSlope;
Report.NaiveFirstPerfectSession = naiveFirstPerfectSession;
Report.TransferFirstPerfectSession = transferFirstPerfectSession;
Report.PretrainReached = pretrainReached;
Report.PretrainSessions = pretrainSessions;
Report.PretrainFinalHit = pretrainFinalHit;
Report.TaskElapsedSeconds = taskElapsedSeconds;
Report.TaskWorkerID = taskWorkerID;
Report.TaskUsedGPU = taskUsedGPU;
end

function TaskTable = iBuildTaskTable(CandidateTable, seedBases, numMice, taskSeedValues, taskElapsedSeconds, taskWorkerID, taskUsedGPU, pretrainReached, pretrainSessions, pretrainFinalHit)
numTasks = numel(taskSeedValues);
numSeeds = numel(seedBases);
taskIndexValues = (1:numTasks)';
candidateIndexValues = nan(numTasks, 1);
seedIndexValues = nan(numTasks, 1);
mouseIndexValues = nan(numTasks, 1);
labelValues = strings(numTasks, 1);
for taskIndex = 1:numTasks
	[candidateIndex, seedIndex, mouseIndex] = iTaskSubscripts(taskIndex, 0, numSeeds, numMice);
	candidateIndexValues(taskIndex) = candidateIndex;
	seedIndexValues(taskIndex) = seedIndex;
	mouseIndexValues(taskIndex) = mouseIndex;
	labelValues(taskIndex) = iCandidateLabel(CandidateTable, candidateIndex);
end
TaskTable = table(taskIndexValues, candidateIndexValues, labelValues, seedIndexValues, mouseIndexValues, taskSeedValues(:), taskWorkerID(:), taskUsedGPU(:), taskElapsedSeconds(:), pretrainReached(:), pretrainSessions(:), pretrainFinalHit(:), ...
	'VariableNames', {'TaskIndex','CandidateIndex','Label','SeedIndex','MouseIndex','SeedValue','WorkerID','UsedGPU','ElapsedSeconds','PretrainReached','PretrainSessions','PretrainFinalHit'});
end

function workerID = iCurrentWorkerID()
taskInfo = getCurrentTask();
if isempty(taskInfo)
	workerID = 0;
else
	workerID = taskInfo.ID;
end
end

function taskSeedValues = iTaskSeedValues(seedBases, numCandidates, numMice)
numSeeds = numel(seedBases);
numTasks = numCandidates * numSeeds * numMice;
taskSeedValues = nan(numTasks, 1);
for taskIndex = 1:numTasks
	[~, seedIndex, mouseIndex] = iTaskSubscripts(taskIndex, numCandidates, numSeeds, numMice);
	taskSeedValues(taskIndex) = seedBases(seedIndex) + mouseIndex - 1;
end
end

function [candidateIndex, seedIndex, mouseIndex] = iTaskSubscripts(taskIndex, ~, numSeeds, numMice)
mouseIndex = mod(taskIndex - 1, numMice) + 1;
runIndex = floor((taskIndex - 1) / numMice) + 1;
seedIndex = mod(runIndex - 1, numSeeds) + 1;
candidateIndex = floor((runIndex - 1) / numSeeds) + 1;
end

function Params = iParamsForCandidate(BaseParams, CandidateTable, candidateIndex)
Params = BaseParams;
candidateVariableNames = string(CandidateTable.Properties.VariableNames);
tunableFieldNames = TransferLearning.THModel.TunableParameterNames();
for iVariable = 1:numel(candidateVariableNames)
	fieldName = char(candidateVariableNames(iVariable));
	if string(fieldName) == "Label"
		continue;
	end
	if ~isfield(Params, fieldName)
		error('THModel:UnknownCandidateParameter', 'Unknown candidate parameter: %s.', fieldName);
	end
		if ~any(string(fieldName) == tunableFieldNames)
			error('THModel:LockedCandidateParameter', 'Candidate table may not override locked parameter: %s.', fieldName);
		end
	fieldValue = CandidateTable{candidateIndex, iVariable};
	if ~isnumeric(fieldValue) || ~isscalar(fieldValue) || ~isfinite(fieldValue)
		error('THModel:InvalidCandidateParameter', 'Candidate parameter %s must be a finite numeric scalar.', fieldName);
	end
	Params.(fieldName) = fieldValue;
end
Params = TransferLearning.THModel.RefreshDerivedCellCounts(Params);
if Params.HitThreshold >= Params.ResponseScale
	error('THModel:InvalidDecisionThreshold', 'HitThreshold must be below ResponseScale.');
end
TransferLearning.THModel.ValidateParameterGrouping(Params);
end

function [naivePerf, transferPerf, naiveSlope, transferSlope, naiveFirstPerfectSession, transferFirstPerfectSession, pretrainReached, pretrainSessions, pretrainFinalHit] = iEvaluateOneMouse(Params, seedValue)
if isfinite(seedValue)
	rng(seedValue, 'twister');
	if TransferLearning.THModel.UseGPU()
		parallel.gpu.rng(seedValue, 'Threefry');
	end
end

formalCond.RewardInputLevel = 1.00;
pretrainCond.RewardInputLevel = 1.00;

naiveMouse = TransferLearning.THModel.DrawMouse(Params);
[naiveResult, ~] = TransferLearning.THModel.SimulateFormalTraining(naiveMouse, Params, formalCond);
naivePerf = naiveResult.Performance;
naiveSlope = naiveResult.Slope;
naiveFirstPerfectSession = naiveResult.FirstPerfectSession;

transferMouse = TransferLearning.THModel.DrawMouse(Params);
pretrainReached = false;
pretrainSessions = Params.MaxPretrainSessions;
pretrainFinalHit = NaN;
for iPretrainSession = 1:Params.MaxPretrainSessions
	[pretrainFinalHit, ~, ~, transferMouse] = TransferLearning.THModel.SimulateSession(transferMouse, Params, pretrainCond, true);
	if pretrainFinalHit >= Params.Ceiling
		pretrainReached = true;
		pretrainSessions = iPretrainSession;
		break;
	end
	transferMouse = TransferLearning.THModel.OvernightConsolidate(transferMouse, Params);
end

[transferResult, ~] = TransferLearning.THModel.SimulateFormalTraining(transferMouse, Params, formalCond);
transferPerf = transferResult.Performance;
transferSlope = transferResult.Slope;
transferFirstPerfectSession = transferResult.FirstPerfectSession;
end

function RunTable = iBuildRunTable(CandidateTable, seedBases, numMice, naivePerf, transferPerf, naiveSlope, transferSlope, naiveFirstPerfectSession, transferFirstPerfectSession, pretrainReached, pretrainSessions, pretrainFinalHit)
numCandidates = height(CandidateTable);
numSeeds = numel(seedBases);
runRows = struct([]);
for candidateIndex = 1:numCandidates
	for seedIndex = 1:numSeeds
		rowRange = iTaskRange(candidateIndex, seedIndex, numSeeds, numMice);
		fitStats = TransferLearning.THModel.CompareSigmoidSlope(naivePerf(rowRange, :), transferPerf(rowRange, :), "Naive", "Transfer", 0, []);
		runIndex = (candidateIndex - 1) * numSeeds + seedIndex;
		runRows(runIndex).CandidateIndex = candidateIndex;
		runRows(runIndex).Label = iCandidateLabel(CandidateTable, candidateIndex);
		runRows(runIndex).SeedBase = seedBases(seedIndex);
		runRows(runIndex).PretrainReachRate = mean(pretrainReached(rowRange));
		runRows(runIndex).MedianPretrainSessions = median(pretrainSessions(rowRange), 'omitnan');
		runRows(runIndex).MeanPretrainFinalHit = mean(pretrainFinalHit(rowRange), 'omitnan');
		runRows(runIndex).NaiveFirst = mean(naivePerf(rowRange, 1), 'omitnan');
		runRows(runIndex).TransferFirst = mean(transferPerf(rowRange, 1), 'omitnan');
		runRows(runIndex).NaiveFinal = mean(naivePerf(rowRange, end), 'omitnan');
		runRows(runIndex).TransferFinal = mean(transferPerf(rowRange, end), 'omitnan');
		runRows(runIndex).NaivePerfectCount = sum(isfinite(naiveFirstPerfectSession(rowRange)));
		runRows(runIndex).TransferPerfectCount = sum(isfinite(transferFirstPerfectSession(rowRange)));
		runRows(runIndex).NaiveMedianPerfectSession = median(naiveFirstPerfectSession(rowRange), 'omitnan');
		runRows(runIndex).TransferMedianPerfectSession = median(transferFirstPerfectSession(rowRange), 'omitnan');
		runRows(runIndex).NaiveLinearSlope = mean(naiveSlope(rowRange), 'omitnan');
		runRows(runIndex).TransferLinearSlope = mean(transferSlope(rowRange), 'omitnan');
		runRows(runIndex).NaiveSigmoidSlope = fitStats.FitA.Slope;
		runRows(runIndex).TransferSigmoidSlope = fitStats.FitB.Slope;
		runRows(runIndex).SigmoidSlopeDiff = fitStats.ComparisonTable.ObservedSlopeDifference;
		runRows(runIndex).NaiveSigmoidMidpoint = fitStats.FitA.Midpoint;
		runRows(runIndex).TransferSigmoidMidpoint = fitStats.FitB.Midpoint;
	end
end
RunTable = struct2table(runRows);
end

function CandidateSummary = iBuildCandidateSummary(CandidateTable, RunTable, numCandidates)
summaryRows = struct([]);
for candidateIndex = 1:numCandidates
	rows = RunTable.CandidateIndex == candidateIndex;
	seedSlopeDiff = RunTable.SigmoidSlopeDiff(rows);
	summaryRows(candidateIndex).CandidateIndex = candidateIndex;
	summaryRows(candidateIndex).Label = iCandidateLabel(CandidateTable, candidateIndex);
	summaryRows(candidateIndex).NumSeeds = sum(rows);
	summaryRows(candidateIndex).MeanSlopeDiff = mean(seedSlopeDiff, 'omitnan');
	summaryRows(candidateIndex).MedianSlopeDiff = median(seedSlopeDiff, 'omitnan');
	summaryRows(candidateIndex).MinSlopeDiff = min(seedSlopeDiff, [], 'omitnan');
	summaryRows(candidateIndex).PositiveSlopeSeedCount = sum(seedSlopeDiff > 0);
	summaryRows(candidateIndex).MeanTransferFirst = mean(RunTable.TransferFirst(rows), 'omitnan');
	summaryRows(candidateIndex).MaxSeedTransferFirst = max(RunTable.TransferFirst(rows), [], 'omitnan');
	summaryRows(candidateIndex).MinTransferPerfectCount = min(RunTable.TransferPerfectCount(rows), [], 'omitnan');
	summaryRows(candidateIndex).MeanTransferPerfectCount = mean(RunTable.TransferPerfectCount(rows), 'omitnan');
	summaryRows(candidateIndex).MeanNaiveSigmoidSlope = mean(RunTable.NaiveSigmoidSlope(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTransferSigmoidSlope = mean(RunTable.TransferSigmoidSlope(rows), 'omitnan');
end
CandidateSummary = struct2table(summaryRows);
end

function rowRange = iTaskRange(candidateIndex, seedIndex, numSeeds, numMice)
runIndex = (candidateIndex - 1) * numSeeds + seedIndex;
rowRange = (runIndex - 1) * numMice + (1:numMice);
end

function label = iCandidateLabel(CandidateTable, candidateIndex)
if any(string(CandidateTable.Properties.VariableNames) == "Label")
	label = string(CandidateTable.Label(candidateIndex));
else
	label = "Candidate" + string(candidateIndex);
end
end