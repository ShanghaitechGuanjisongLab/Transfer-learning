function MouseReport = DiagnoseTransferFirstHighMechanismMouse(Params, mouseIndex, seedValue, numRandomProbeCues)
if nargin < 4 || isempty(numRandomProbeCues)
	numRandomProbeCues = max(30, Params.NumTrials);
end
if isfinite(seedValue)
	rng(seedValue, 'twister');
end

Mouse = TransferLearning.THModel.DrawMouse(Params);
pretrainCond.RewardInputLevel = 1.00;
sessionRows = repmat(iEmptySessionRow(), Params.MaxPretrainSessions + 1, 1);
firstPerfectSession = NaN;
reached = false;

sessionRows(1) = iProbeSessionState(Mouse, Params, mouseIndex, seedValue, 0, NaN, numRandomProbeCues);
for iSession = 1:Params.MaxPretrainSessions
	if reached
		pretrainHitObserved = Params.Ceiling;
	else
		[pretrainHitObserved, ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, pretrainCond, true);
		if pretrainHitObserved >= Params.Ceiling
			pretrainHitObserved = Params.Ceiling;
			firstPerfectSession = iSession;
			reached = true;
		end
	end
	sessionRows(iSession + 1) = iProbeSessionState(Mouse, Params, mouseIndex, seedValue, iSession, pretrainHitObserved, numRandomProbeCues);
end

SessionTable = struct2table(sessionRows);
finalRow = sessionRows(end);
MouseRow.Mouse = mouseIndex;
MouseRow.Seed = seedValue;
MouseRow.Reached = reached;
MouseRow.FirstPerfectSession = firstPerfectSession;
MouseRow.FinalPreCueDrive = finalRow.PreCueDrive;
MouseRow.FinalFormalDrive = finalRow.FormalDrive;
MouseRow.FinalFormalNoLearningHitRate = finalRow.FormalNoLearningHitRate;
MouseRow.FinalFormalFirstSessionHitRate = finalRow.FormalFirstSessionHitRate;
MouseRow.FinalRandomNoisyHitRate = finalRow.RandomNoisyHitRate;
MouseRow.FinalZeroNoisyHitRate = finalRow.ZeroNoisyHitRate;
MouseRow.FinalFormalNoRecurrentDrive = finalRow.FormalNoRecurrentDrive;
MouseRow.FinalFormalPreCueSourceOnlyDrive = finalRow.FormalPreCueSourceOnlyDrive;
MouseRow.FinalFormalNonPreCueSourceOnlyDrive = finalRow.FormalNonPreCueSourceOnlyDrive;
MouseRow.FinalFormalL23SourceOnlyDrive = finalRow.FormalL23SourceOnlyDrive;
MouseRow.FinalFormalL5SourceOnlyDrive = finalRow.FormalL5SourceOnlyDrive;
MouseRow.FinalTargetFromPreCueL23CapFraction = finalRow.TargetFromPreCueL23CapFraction;
MouseRow.FinalTargetFromNonPreCueSourceCapFraction = finalRow.TargetFromNonPreCueSourceCapFraction;

MouseReport.MouseRow = MouseRow;
MouseReport.SessionTable = SessionTable;
end

function row = iProbeSessionState(Mouse, Params, mouseIndex, seedValue, pretrainSession, pretrainHitObserved, numRandomProbeCues)
rngState = rng;
row = iEmptySessionRow();
row.Mouse = mouseIndex;
row.Seed = seedValue;
row.PretrainSession = pretrainSession;
row.PretrainHitObserved = pretrainHitObserved;

row.PreCueDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, true);
row.FormalDrive = TransferLearning.THModel.CueDecisionDrive(Mouse, Params, false);
formalProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "formalCue", Params.NumTrials, true);
randomProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "randomCue", numRandomProbeCues, true);
zeroProbe = TransferLearning.THModel.SampleDecisionTrials(Mouse, Params, "zeroCue", numRandomProbeCues, true);
row.FormalNoLearningHitRate = mean(formalProbe.Hit, 'omitnan');
row.FormalNoLearningMeanDrive = mean(formalProbe.Drive, 'omitnan');
row.RandomNoisyHitRate = mean(randomProbe.Hit, 'omitnan');
row.RandomNoisyMeanDrive = mean(randomProbe.Drive, 'omitnan');
row.ZeroNoisyHitRate = mean(zeroProbe.Hit, 'omitnan');
row.ZeroNoisyMeanDrive = mean(zeroProbe.Drive, 'omitnan');

formalCond.RewardInputLevel = 1.00;
formalMouse = Mouse;
[row.FormalFirstSessionHitRate, ~, ~, ~] = TransferLearning.THModel.SimulateSession(formalMouse, Params, formalCond, false);

preCueSourceMask = iInternalSourceMask(Params, Mouse.PreCueInputPattern > 0, false, false);
formalSourceMask = iInternalSourceMask(Params, Mouse.CueInputPattern > 0, false, false);
nonPreCueSourceMask = ~preCueSourceMask;
l23SourceMask = iInternalSourceMask(Params, true(Params.NL23, 1), false, false);
l5SourceMask = iInternalSourceMask(Params, false(Params.NL23, 1), true, true);

row.FormalNoRecurrentDrive = iFormalDriveWithSourceMask(Mouse, Params, false(Params.NL23L5, 1));
row.FormalPreCueSourceOnlyDrive = iFormalDriveWithSourceMask(Mouse, Params, preCueSourceMask);
row.FormalFormalCueSourceOnlyDrive = iFormalDriveWithSourceMask(Mouse, Params, formalSourceMask);
row.FormalNonPreCueSourceOnlyDrive = iFormalDriveWithSourceMask(Mouse, Params, nonPreCueSourceMask);
row.FormalL23SourceOnlyDrive = iFormalDriveWithSourceMask(Mouse, Params, l23SourceMask);
row.FormalL5SourceOnlyDrive = iFormalDriveWithSourceMask(Mouse, Params, l5SourceMask);
row.FormalRemovePreCueSourceDrive = iFormalDriveRemovingSourceMask(Mouse, Params, preCueSourceMask);
row.FormalRemoveNonPreCueSourceDrive = iFormalDriveRemovingSourceMask(Mouse, Params, nonPreCueSourceMask);

weightStats = iTargetWeightStats(Mouse, Params, preCueSourceMask, formalSourceMask, nonPreCueSourceMask, l5SourceMask);
fieldNames = fieldnames(weightStats);
for iField = 1:numel(fieldNames)
	fieldName = fieldNames{iField};
	row.(fieldName) = weightStats.(fieldName);
end
rng(rngState);
end

function sourceMask = iInternalSourceMask(Params, l23Mask, includeL5RewardRecv, includeL5Read)
sourceMask = false(Params.NL23L5, 1);
sourceMask(1:Params.NL23) = l23Mask(:);
if includeL5RewardRecv
	sourceMask(Params.NL23 + (1:Params.NL5RewardRecv)) = true;
end
if includeL5Read
	sourceMask(Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read)) = true;
end
end

function drive = iFormalDriveWithSourceMask(Mouse, Params, sourceMask)
maskedMouse = Mouse;
maskedMouse.W_L23L5ToL23L5(:, ~sourceMask(:)) = 0;
drive = TransferLearning.THModel.CueDecisionDrive(maskedMouse, Params, false);
end

function drive = iFormalDriveRemovingSourceMask(Mouse, Params, sourceMask)
maskedMouse = Mouse;
maskedMouse.W_L23L5ToL23L5(:, sourceMask(:)) = 0;
drive = TransferLearning.THModel.CueDecisionDrive(maskedMouse, Params, false);
end

function weightStats = iTargetWeightStats(Mouse, Params, preCueSourceMask, formalSourceMask, nonPreCueSourceMask, l5SourceMask)
targetRows = Params.NL23 + Params.NL5RewardRecv + find(Mouse.L5ReadoutPattern(:) > 0);
W = Mouse.W_L23L5ToL23L5;
weightStats.TargetFromPreCueL23Mean = iMeanEffectiveWeight(W(targetRows, preCueSourceMask));
weightStats.TargetFromFormalL23Mean = iMeanEffectiveWeight(W(targetRows, formalSourceMask));
weightStats.TargetFromNonPreCueSourceMean = iMeanEffectiveWeight(W(targetRows, nonPreCueSourceMask));
weightStats.TargetFromL5SourceMean = iMeanEffectiveWeight(W(targetRows, l5SourceMask));
weightStats.TargetFromPreCueL23CapFraction = iCapFraction(W(targetRows, preCueSourceMask), Params);
weightStats.TargetFromFormalL23CapFraction = iCapFraction(W(targetRows, formalSourceMask), Params);
weightStats.TargetFromNonPreCueSourceCapFraction = iCapFraction(W(targetRows, nonPreCueSourceMask), Params);
weightStats.TargetFromL5SourceCapFraction = iCapFraction(W(targetRows, l5SourceMask), Params);
end

function value = iMeanEffectiveWeight(weights)
weights = TransferLearning.THModel.GatherValue(weights(:));
weights = max(weights, 0);
value = mean(weights, 'omitnan');
end

function value = iCapFraction(weights, Params)
weights = TransferLearning.THModel.GatherValue(weights(:));
value = mean(weights >= 0.999 * Params.WeightMax, 'omitnan');
end

function row = iEmptySessionRow()
row.Mouse = NaN;
row.Seed = NaN;
row.PretrainSession = NaN;
row.PretrainHitObserved = NaN;
row.PreCueDrive = NaN;
row.FormalDrive = NaN;
row.FormalNoLearningHitRate = NaN;
row.FormalNoLearningMeanDrive = NaN;
row.FormalFirstSessionHitRate = NaN;
row.RandomNoisyHitRate = NaN;
row.RandomNoisyMeanDrive = NaN;
row.ZeroNoisyHitRate = NaN;
row.ZeroNoisyMeanDrive = NaN;
row.FormalNoRecurrentDrive = NaN;
row.FormalPreCueSourceOnlyDrive = NaN;
row.FormalFormalCueSourceOnlyDrive = NaN;
row.FormalNonPreCueSourceOnlyDrive = NaN;
row.FormalL23SourceOnlyDrive = NaN;
row.FormalL5SourceOnlyDrive = NaN;
row.FormalRemovePreCueSourceDrive = NaN;
row.FormalRemoveNonPreCueSourceDrive = NaN;
row.TargetFromPreCueL23Mean = NaN;
row.TargetFromFormalL23Mean = NaN;
row.TargetFromNonPreCueSourceMean = NaN;
row.TargetFromL5SourceMean = NaN;
row.TargetFromPreCueL23CapFraction = NaN;
row.TargetFromFormalL23CapFraction = NaN;
row.TargetFromNonPreCueSourceCapFraction = NaN;
row.TargetFromL5SourceCapFraction = NaN;
end
