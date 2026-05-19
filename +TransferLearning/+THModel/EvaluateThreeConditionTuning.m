function Report = EvaluateThreeConditionTuning(BaseParams, CandidateTable, seedBases, numMice)
if nargin < 1 || isempty(BaseParams)
	BaseParams = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(CandidateTable)
	CandidateTable = table("Base", 'VariableNames', {'Label'});
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
numRuns = numCandidates * numSeeds;
numTasks = numRuns * numMice;
numSessions = BaseParams.NumSessions;
taskSeedValues = iTaskSeedValues(seedBases, numCandidates, numMice);

naivePerf = nan(numTasks, numSessions);
transferPerf = nan(numTasks, numSessions);
thOffPerf = nan(numTasks, numSessions);
naiveMeanH5 = nan(numTasks, 1);
transferMeanH5 = nan(numTasks, 1);
thOffMeanH5 = nan(numTasks, 1);
transferPretrainReached = false(numTasks, 1);
thOffPretrainReached = false(numTasks, 1);
errorIdentifier = strings(numTasks, 1);
errorMessage = strings(numTasks, 1);

useParallel = numTasks > 1 && ~isempty(gcp('nocreate'));
if useParallel
	parfor taskIndex = 1:numTasks
		[candidateIndex, ~, ~] = iTaskSubscripts(taskIndex, numCandidates, numSeeds, numMice);
		Params = iParamsForCandidate(BaseParams, CandidateTable, candidateIndex);
		[naivePerfRow, transferPerfRow, thOffPerfRow, naiveH5Value, transferH5Value, thOffH5Value, transferPretrainReachedValue, thOffPretrainReachedValue, errorIdentifierValue, errorMessageValue] = iEvaluateOneMouse(Params, taskSeedValues(taskIndex));
		naivePerf(taskIndex, :) = naivePerfRow;
		transferPerf(taskIndex, :) = transferPerfRow;
		thOffPerf(taskIndex, :) = thOffPerfRow;
		naiveMeanH5(taskIndex) = naiveH5Value;
		transferMeanH5(taskIndex) = transferH5Value;
		thOffMeanH5(taskIndex) = thOffH5Value;
		transferPretrainReached(taskIndex) = transferPretrainReachedValue;
		thOffPretrainReached(taskIndex) = thOffPretrainReachedValue;
		errorIdentifier(taskIndex) = errorIdentifierValue;
		errorMessage(taskIndex) = errorMessageValue;
	end
else
	for taskIndex = 1:numTasks
		[candidateIndex, ~, ~] = iTaskSubscripts(taskIndex, numCandidates, numSeeds, numMice);
		Params = iParamsForCandidate(BaseParams, CandidateTable, candidateIndex);
		[naivePerfRow, transferPerfRow, thOffPerfRow, naiveH5Value, transferH5Value, thOffH5Value, transferPretrainReachedValue, thOffPretrainReachedValue, errorIdentifierValue, errorMessageValue] = iEvaluateOneMouse(Params, taskSeedValues(taskIndex));
		naivePerf(taskIndex, :) = naivePerfRow;
		transferPerf(taskIndex, :) = transferPerfRow;
		thOffPerf(taskIndex, :) = thOffPerfRow;
		naiveMeanH5(taskIndex) = naiveH5Value;
		transferMeanH5(taskIndex) = transferH5Value;
		thOffMeanH5(taskIndex) = thOffH5Value;
		transferPretrainReached(taskIndex) = transferPretrainReachedValue;
		thOffPretrainReached(taskIndex) = thOffPretrainReachedValue;
		errorIdentifier(taskIndex) = errorIdentifierValue;
		errorMessage(taskIndex) = errorMessageValue;
	end
end

RunTable = iBuildRunTable(CandidateTable, seedBases, numMice, naivePerf, transferPerf, thOffPerf, naiveMeanH5, transferMeanH5, thOffMeanH5, transferPretrainReached, thOffPretrainReached, errorIdentifier);
CandidateSummary = iBuildCandidateSummary(CandidateTable, RunTable, numCandidates);

Report = struct();
Report.BaseParams = BaseParams;
Report.CandidateTable = CandidateTable;
Report.SeedBases = seedBases;
Report.NumMice = numMice;
Report.NaivePerf = naivePerf;
Report.TransferPerf = transferPerf;
Report.THOffPerf = thOffPerf;
Report.NaiveMeanH5 = naiveMeanH5;
Report.TransferMeanH5 = transferMeanH5;
Report.THOffMeanH5 = thOffMeanH5;
Report.TransferPretrainReached = transferPretrainReached;
Report.THOffPretrainReached = thOffPretrainReached;
Report.ErrorIdentifier = errorIdentifier;
Report.ErrorMessage = errorMessage;
Report.RunTable = RunTable;
Report.CandidateSummary = CandidateSummary;
end

function [naivePerf, transferPerf, thOffPerf, naiveMeanH5, transferMeanH5, thOffMeanH5, transferPretrainReached, thOffPretrainReached, errorIdentifier, errorMessage] = iEvaluateOneMouse(Params, seedValue)
if isfinite(seedValue)
	rng(seedValue, 'twister');
end

numSessions = Params.NumSessions;
naivePerf = nan(1, numSessions);
transferPerf = nan(1, numSessions);
thOffPerf = nan(1, numSessions);
naiveMeanH5 = NaN;
transferMeanH5 = NaN;
thOffMeanH5 = NaN;
transferPretrainReached = false;
thOffPretrainReached = false;
errorIdentifier = "";
errorMessage = "";
Cond = TransferLearning.THModel.ConditionTable();

try
	naiveMouse = TransferLearning.THModel.DrawMouse(Params);
	[naiveResult, ~] = TransferLearning.THModel.SimulateFormalTraining(naiveMouse, Params, Cond(Cond.Name == "Naive", :));
	naivePerf = naiveResult.Performance;
	naiveMeanH5 = naiveResult.MeanH5;

	transferMouse = TransferLearning.THModel.DrawMouse(Params);
	[transferMouse, transferPretrainResult] = TransferLearning.THModel.SimulatePretraining(transferMouse, Params, Cond(Cond.Name == "Transfer", :));
	transferPretrainReached = transferPretrainResult.Reached;
	[transferResult, ~] = TransferLearning.THModel.SimulateFormalTraining(transferMouse, Params, Cond(Cond.Name == "Transfer", :));
	transferPerf = transferResult.Performance;
	transferMeanH5 = transferResult.MeanH5;

	thOffMouse = TransferLearning.THModel.DrawMouse(Params);
	[thOffMouse, thOffPretrainResult] = TransferLearning.THModel.SimulatePretraining(thOffMouse, Params, Cond(Cond.Name == "THOff", :));
	thOffPretrainReached = thOffPretrainResult.Reached;
	[thOffResult, ~] = TransferLearning.THModel.SimulateFormalTraining(thOffMouse, Params, Cond(Cond.Name == "THOff", :));
	thOffPerf = thOffResult.Performance;
	thOffMeanH5 = thOffResult.MeanH5;
catch ME
	if ~strcmp(ME.identifier, 'THModel:NoiseCueBacktrainMaxAttemptsReached')
		rethrow(ME);
	end
	errorIdentifier = string(ME.identifier);
	errorMessage = string(ME.message);
end
end

function RunTable = iBuildRunTable(CandidateTable, seedBases, numMice, naivePerf, transferPerf, thOffPerf, naiveMeanH5, transferMeanH5, thOffMeanH5, transferPretrainReached, thOffPretrainReached, errorIdentifier)
numCandidates = height(CandidateTable);
numSeeds = numel(seedBases);
runRows = repmat(iEmptyRunRow(), numCandidates * numSeeds, 1);
for candidateIndex = 1:numCandidates
	for seedIndex = 1:numSeeds
		rowRange = iTaskRange(candidateIndex, seedIndex, numSeeds, numMice);
		validRows = errorIdentifier(rowRange) == "";
		runIndex = (candidateIndex - 1) * numSeeds + seedIndex;
		runRows(runIndex).CandidateIndex = candidateIndex;
		runRows(runIndex).Label = iCandidateLabel(CandidateTable, candidateIndex);
		runRows(runIndex).SeedBase = seedBases(seedIndex);
		runRows(runIndex).ErrorCount = sum(~validRows);
		runRows(runIndex).ValidMouseCount = sum(validRows);
		runRows(runIndex).TransferPretrainReachRate = mean(transferPretrainReached(rowRange(validRows)), 'omitnan');
		runRows(runIndex).THOffPretrainReachRate = mean(thOffPretrainReached(rowRange(validRows)), 'omitnan');
		if sum(validRows) < 3
			continue;
		end
		validRange = rowRange(validRows);
		naivePerfValid = naivePerf(validRange, :);
		transferPerfValid = transferPerf(validRange, :);
		thOffPerfValid = thOffPerf(validRange, :);
		runRows(runIndex).NaiveFirst = mean(naivePerfValid(:, 1), 'omitnan');
		runRows(runIndex).TransferFirst = mean(transferPerfValid(:, 1), 'omitnan');
		runRows(runIndex).THOffFirst = mean(thOffPerfValid(:, 1), 'omitnan');
		runRows(runIndex).PTransferVsNaiveFirst = iRanksumIfFinite(transferPerfValid(:, 1), naivePerfValid(:, 1));
		runRows(runIndex).PTransferVsTHOffFirst = iRanksumIfFinite(transferPerfValid(:, 1), thOffPerfValid(:, 1));
		runRows(runIndex).PNaiveVsTHOffFirst = iRanksumIfFinite(naivePerfValid(:, 1), thOffPerfValid(:, 1));
		runRows(runIndex).NaiveLast = mean(naivePerfValid(:, end), 'omitnan');
		runRows(runIndex).TransferLast = mean(transferPerfValid(:, end), 'omitnan');
		runRows(runIndex).THOffLast = mean(thOffPerfValid(:, end), 'omitnan');
		runRows(runIndex).NaiveImproveAll = all(naivePerfValid(:, end) > naivePerfValid(:, 1));
		runRows(runIndex).NaiveMeanH5 = mean(naiveMeanH5(validRange), 'omitnan');
		runRows(runIndex).TransferMeanH5 = mean(transferMeanH5(validRange), 'omitnan');
		runRows(runIndex).THOffMeanH5 = mean(thOffMeanH5(validRange), 'omitnan');
		runRows(runIndex).PTransferVsNaiveH5 = iRanksumIfFinite(transferMeanH5(validRange), naiveMeanH5(validRange));
		runRows(runIndex).PTransferVsTHOffH5 = iRanksumIfFinite(transferMeanH5(validRange), thOffMeanH5(validRange));
		fitNaiveTransfer = TransferLearning.THModel.CompareSigmoidSlope(naivePerfValid, transferPerfValid, "Naive", "Transfer", 0, []);
		fitTHOffTransfer = TransferLearning.THModel.CompareSigmoidSlope(thOffPerfValid, transferPerfValid, "THOff", "Transfer", 0, []);
		runRows(runIndex).NaiveSigmoidSlope = fitNaiveTransfer.FitA.Slope;
		runRows(runIndex).TransferSigmoidSlopeVsNaive = fitNaiveTransfer.FitB.Slope;
		runRows(runIndex).PTransferVsNaiveSigmoid = fitNaiveTransfer.ComparisonTable.PValueRight;
		runRows(runIndex).THOffSigmoidSlope = fitTHOffTransfer.FitA.Slope;
		runRows(runIndex).TransferSigmoidSlopeVsTHOff = fitTHOffTransfer.FitB.Slope;
		runRows(runIndex).PTransferVsTHOffSigmoid = fitTHOffTransfer.ComparisonTable.PValueRight;
	end
end
RunTable = struct2table(runRows);
end

function row = iEmptyRunRow()
row.CandidateIndex = NaN;
row.Label = "";
row.SeedBase = NaN;
row.ErrorCount = NaN;
row.ValidMouseCount = NaN;
row.TransferPretrainReachRate = NaN;
row.THOffPretrainReachRate = NaN;
row.NaiveFirst = NaN;
row.TransferFirst = NaN;
row.THOffFirst = NaN;
row.PTransferVsNaiveFirst = NaN;
row.PTransferVsTHOffFirst = NaN;
row.PNaiveVsTHOffFirst = NaN;
row.NaiveLast = NaN;
row.TransferLast = NaN;
row.THOffLast = NaN;
row.NaiveImproveAll = false;
row.NaiveMeanH5 = NaN;
row.TransferMeanH5 = NaN;
row.THOffMeanH5 = NaN;
row.PTransferVsNaiveH5 = NaN;
row.PTransferVsTHOffH5 = NaN;
row.NaiveSigmoidSlope = NaN;
row.TransferSigmoidSlopeVsNaive = NaN;
row.PTransferVsNaiveSigmoid = NaN;
row.THOffSigmoidSlope = NaN;
row.TransferSigmoidSlopeVsTHOff = NaN;
row.PTransferVsTHOffSigmoid = NaN;
end

function CandidateSummary = iBuildCandidateSummary(CandidateTable, RunTable, numCandidates)
summaryRows = repmat(iEmptySummaryRow(), numCandidates, 1);
for candidateIndex = 1:numCandidates
	rows = RunTable.CandidateIndex == candidateIndex;
	summaryRows(candidateIndex).CandidateIndex = candidateIndex;
	summaryRows(candidateIndex).Label = iCandidateLabel(CandidateTable, candidateIndex);
	summaryRows(candidateIndex).NumRuns = sum(rows);
	summaryRows(candidateIndex).TotalErrorCount = sum(RunTable.ErrorCount(rows), 'omitnan');
	summaryRows(candidateIndex).MinValidMouseCount = min(RunTable.ValidMouseCount(rows), [], 'omitnan');
	summaryRows(candidateIndex).MinTransferPretrainReachRate = min(RunTable.TransferPretrainReachRate(rows), [], 'omitnan');
	summaryRows(candidateIndex).MinTHOffPretrainReachRate = min(RunTable.THOffPretrainReachRate(rows), [], 'omitnan');
	summaryRows(candidateIndex).MeanNaiveFirst = mean(RunTable.NaiveFirst(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTransferFirst = mean(RunTable.TransferFirst(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTHOffFirst = mean(RunTable.THOffFirst(rows), 'omitnan');
	summaryRows(candidateIndex).MaxTransferFirst = max(RunTable.TransferFirst(rows), [], 'omitnan');
	summaryRows(candidateIndex).MaxTHOffFirst = max(RunTable.THOffFirst(rows), [], 'omitnan');
	summaryRows(candidateIndex).FirstRankPassCount = sum(RunTable.TransferFirst(rows) > RunTable.THOffFirst(rows) & RunTable.TransferFirst(rows) > RunTable.NaiveFirst(rows) & RunTable.NaiveFirst(rows) < RunTable.THOffFirst(rows));
	summaryRows(candidateIndex).MeanNaiveLast = mean(RunTable.NaiveLast(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTransferLast = mean(RunTable.TransferLast(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTHOffLast = mean(RunTable.THOffLast(rows), 'omitnan');
	summaryRows(candidateIndex).NaiveImprovePassCount = sum(RunTable.NaiveImproveAll(rows));
	summaryRows(candidateIndex).MeanNaiveH5 = mean(RunTable.NaiveMeanH5(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTransferH5 = mean(RunTable.TransferMeanH5(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTHOffH5 = mean(RunTable.THOffMeanH5(rows), 'omitnan');
	summaryRows(candidateIndex).MinTransferMinusNaiveH5 = min(RunTable.TransferMeanH5(rows) - RunTable.NaiveMeanH5(rows), [], 'omitnan');
	summaryRows(candidateIndex).MinTransferMinusTHOffH5 = min(RunTable.TransferMeanH5(rows) - RunTable.THOffMeanH5(rows), [], 'omitnan');
	summaryRows(candidateIndex).MeanNaiveSigmoidSlope = mean(RunTable.NaiveSigmoidSlope(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTransferSigmoidSlope = mean(RunTable.TransferSigmoidSlopeVsNaive(rows), 'omitnan');
	summaryRows(candidateIndex).MeanTHOffSigmoidSlope = mean(RunTable.THOffSigmoidSlope(rows), 'omitnan');
	summaryRows(candidateIndex).MinTransferMinusNaiveSigmoidSlope = min(RunTable.TransferSigmoidSlopeVsNaive(rows) - RunTable.NaiveSigmoidSlope(rows), [], 'omitnan');
	summaryRows(candidateIndex).MinTransferMinusTHOffSigmoidSlope = min(RunTable.TransferSigmoidSlopeVsTHOff(rows) - RunTable.THOffSigmoidSlope(rows), [], 'omitnan');
end
CandidateSummary = struct2table(summaryRows);
end

function row = iEmptySummaryRow()
row.CandidateIndex = NaN;
row.Label = "";
row.NumRuns = NaN;
row.TotalErrorCount = NaN;
row.MinValidMouseCount = NaN;
row.MinTransferPretrainReachRate = NaN;
row.MinTHOffPretrainReachRate = NaN;
row.MeanNaiveFirst = NaN;
row.MeanTransferFirst = NaN;
row.MeanTHOffFirst = NaN;
row.MaxTransferFirst = NaN;
row.MaxTHOffFirst = NaN;
row.FirstRankPassCount = NaN;
row.MeanNaiveLast = NaN;
row.MeanTransferLast = NaN;
row.MeanTHOffLast = NaN;
row.NaiveImprovePassCount = NaN;
row.MeanNaiveH5 = NaN;
row.MeanTransferH5 = NaN;
row.MeanTHOffH5 = NaN;
row.MinTransferMinusNaiveH5 = NaN;
row.MinTransferMinusTHOffH5 = NaN;
row.MeanNaiveSigmoidSlope = NaN;
row.MeanTransferSigmoidSlope = NaN;
row.MeanTHOffSigmoidSlope = NaN;
row.MinTransferMinusNaiveSigmoidSlope = NaN;
row.MinTransferMinusTHOffSigmoidSlope = NaN;
end

function pValue = iRanksumIfFinite(valuesA, valuesB)
valuesA = valuesA(isfinite(valuesA));
valuesB = valuesB(isfinite(valuesB));
if isempty(valuesA) || isempty(valuesB)
	pValue = NaN;
	return;
end
pValue = ranksum(valuesA, valuesB);
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

function rowRange = iTaskRange(candidateIndex, seedIndex, numSeeds, numMice)
runIndex = (candidateIndex - 1) * numSeeds + seedIndex;
rowRange = (runIndex - 1) * numMice + (1:numMice);
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
TransferLearning.THModel.ValidateCueFractionParameters(Params);
TransferLearning.THModel.ValidateDecisionIterationWeighting(Params);
TransferLearning.THModel.ValidateParameterGrouping(Params);
end

function label = iCandidateLabel(CandidateTable, candidateIndex)
if any(string(CandidateTable.Properties.VariableNames) == "Label")
	label = string(CandidateTable.Label(candidateIndex));
else
	label = "Candidate" + string(candidateIndex);
end
end