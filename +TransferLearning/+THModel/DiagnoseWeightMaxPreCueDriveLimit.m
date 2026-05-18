function Report = DiagnoseWeightMaxPreCueDriveLimit(Params, weightMaxValues, numMice, seedBase)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(weightMaxValues)
	weightMaxValues = Params.WeightMax;
end
if nargin < 3 || isempty(numMice)
	numMice = Params.NumMice;
end
if nargin < 4 || isempty(seedBase)
	seedBase = NaN;
end

weightMaxValues = double(weightMaxValues(:));
numValues = numel(weightMaxValues);
resultCells = cell(numValues, 1);
useParallel = numMice > 1 && ~isempty(gcp('nocreate'));
for iValue = 1:numValues
	valueParams = Params;
	valueParams.WeightMax = weightMaxValues(iValue);
	mouseRows = cell(numMice, 1);
	if useParallel
		parfor iMouse = 1:numMice
			mouseRows{iMouse} = iRunOneMouse(valueParams, weightMaxValues(iValue), iMouse, seedBase);
		end
	else
		for iMouse = 1:numMice
			mouseRows{iMouse} = iRunOneMouse(valueParams, weightMaxValues(iValue), iMouse, seedBase);
		end
	end
	resultCells{iValue} = struct2table(vertcat(mouseRows{:}));
end
MouseTable = vertcat(resultCells{:});
Report.Params = Params;
Report.WeightMaxValues = weightMaxValues;
Report.MouseTable = MouseTable;
Report.Summary = iBuildSummary(MouseTable, weightMaxValues);
end

function row = iRunOneMouse(Params, weightMaxValue, mouseIndex, seedBase)
if isfinite(seedBase)
	rng(double(seedBase) + mouseIndex - 1, 'twister');
end
Mouse = TransferLearning.THModel.DrawMouse(Params);
pretrainCond.RewardInputLevel = 1.00;
[Mouse, preResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, pretrainCond);
row.WeightMax = weightMaxValue;
row.Mouse = mouseIndex;
row.Reached = preResult.Reached;
row.TrainingSessions = preResult.TrainingSessions;
row.EarlyStopPreCueDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, true);
row.FullPassPreCueDrive = iCueDriveFixedPasses(Mouse, Params, true);
row.EarlyStopFormalDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, false);
row.FullPassFormalDrive = iCueDriveFixedPasses(Mouse, Params, false);
row.PreCueDriveHiddenByEarlyStop = row.FullPassPreCueDrive - row.EarlyStopPreCueDrive;
row.FormalDriveHiddenByEarlyStop = row.FullPassFormalDrive - row.EarlyStopFormalDrive;
end

function Summary = iBuildSummary(MouseTable, weightMaxValues)
summaryRows = repmat(iEmptySummaryRow(), numel(weightMaxValues), 1);
for iValue = 1:numel(weightMaxValues)
	valueMask = MouseTable.WeightMax == weightMaxValues(iValue);
	subTable = MouseTable(valueMask, :);
	summaryRows(iValue).WeightMax = weightMaxValues(iValue);
	summaryRows(iValue).ReachRate = mean(subTable.Reached);
	summaryRows(iValue).MedianTrainingSessions = median(subTable.TrainingSessions, 'omitnan');
	summaryRows(iValue).MeanEarlyStopPreCueDrive = mean(subTable.EarlyStopPreCueDrive, 'omitnan');
	summaryRows(iValue).MeanFullPassPreCueDrive = mean(subTable.FullPassPreCueDrive, 'omitnan');
	summaryRows(iValue).MeanEarlyStopFormalDrive = mean(subTable.EarlyStopFormalDrive, 'omitnan');
	summaryRows(iValue).MeanFullPassFormalDrive = mean(subTable.FullPassFormalDrive, 'omitnan');
	summaryRows(iValue).MeanPreCueDriveHiddenByEarlyStop = mean(subTable.PreCueDriveHiddenByEarlyStop, 'omitnan');
	summaryRows(iValue).MeanFormalDriveHiddenByEarlyStop = mean(subTable.FormalDriveHiddenByEarlyStop, 'omitnan');
end
Summary = struct2table(summaryRows);
end

function drive = iCueDriveFixedPasses(Mouse, Params, usePreCue)
if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	l23InhibitoryCuePattern = Mouse.PreCueL23InhibitoryPattern;
else
	cueInputPattern = Mouse.CueInputPattern;
	l23InhibitoryCuePattern = Mouse.CueL23InhibitoryPattern;
end
inputToL23 = cueInputPattern;
inputToIL23 = l23InhibitoryCuePattern;
inputToL5RewardRecv = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
inputToL5Read = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);
externalPre = [inputToL23; inputToL5RewardRecv; inputToL5Read];
state.All = TransferLearning.THModel.Zeros([Params.NL23L5, 1]);
state.IL23 = TransferLearning.THModel.Zeros([Params.NIL23, 1]);
readoutInhibitionSource = TransferLearning.THModel.Zeros([Params.NL23 + Params.NL5RewardRecv, 1]);
l23InhibitoryProjectionSource = state.IL23;
for iPass = 0:Params.RecurrentPasses
	[l23Rec, l5RewardRecvRec, l5ReadRec] = TransferLearning.THModel.SplitInternalActivity(externalPre + max(Mouse.W_L23L5ToL23L5, 0) * state.All, Params);
	state = TransferLearning.THModel.RunInternalAreas(l23Rec, l5RewardRecvRec, l5ReadRec, Mouse, Params, true, readoutInhibitionSource, inputToIL23, l23InhibitoryProjectionSource);
	readoutInhibitionSource = [state.L23; state.L5RewardRecv];
	l23InhibitoryProjectionSource = state.IL23;
end
drive = TransferLearning.THModel.ReadoutDecisionDrive(Mouse, state.L5Read, state.IL5Read, Params);
end

function row = iEmptySummaryRow()
row.WeightMax = NaN;
row.ReachRate = NaN;
row.MedianTrainingSessions = NaN;
row.MeanEarlyStopPreCueDrive = NaN;
row.MeanFullPassPreCueDrive = NaN;
row.MeanEarlyStopFormalDrive = NaN;
row.MeanFullPassFormalDrive = NaN;
row.MeanPreCueDriveHiddenByEarlyStop = NaN;
row.MeanFormalDriveHiddenByEarlyStop = NaN;
end
