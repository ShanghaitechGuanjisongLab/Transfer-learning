function Report = DiagnoseTransferFirstSession(Params, numMice, numProbeTrials)
if nargin < 1 || isempty(Params)
	Params = TransferLearning.THModel.DefaultParams();
end
if nargin < 2 || isempty(numMice)
	numMice = 10;
end
if nargin < 3 || isempty(numProbeTrials)
	numProbeTrials = max(60, Params.NumTrials);
end

pretrainCond.RewardInputLevel = 1.00;
formalCond.RewardInputLevel = 1.00;
rows = struct([]);
formalTrialTables = cell(numMice, 1);

for iMouse = 1:numMice
	Mouse = TransferLearning.THModel.DrawMouse(Params);
	initialMouse = Mouse;
	pretrainReached = false;
	pretrainFinalHit = NaN;
	for iSession = 1:Params.MaxPretrainSessions
		[pretrainFinalHit, ~, ~, Mouse] = TransferLearning.THModel.SimulateSession(Mouse, Params, pretrainCond, true);
		if pretrainFinalHit >= Params.Ceiling
			pretrainReached = true;
			break;
		end
		Mouse = TransferLearning.THModel.OvernightConsolidate(Mouse, Params);
	end

	preFormalMouse = Mouse;
	preCueProbe = TransferLearning.THModel.CueDecisionDrive(preFormalMouse, Params, true);
	formalCueProbe = TransferLearning.THModel.CueDecisionDrive(preFormalMouse, Params, false);
	formalCueNoInhProbe = TransferLearning.THModel.CueDecisionDriveNoLocalInh(preFormalMouse, Params, false);
	initialFormalNoLearning = TransferLearning.THModel.SampleDecisionTrials(initialMouse, Params, "formalCue", Params.NumTrials, true);
	initialZeroNoLearning = TransferLearning.THModel.SampleDecisionTrials(initialMouse, Params, "zeroCue", numProbeTrials, true);
	initialFirstMouse = initialMouse;
	[initialFormalFirstHit, ~, ~, ~] = TransferLearning.THModel.SimulateSession(initialFirstMouse, Params, formalCond, false);
	formalNoLearning = TransferLearning.THModel.SampleDecisionTrials(preFormalMouse, Params, "formalCue", Params.NumTrials, true);
	randomNoLearning = TransferLearning.THModel.SampleDecisionTrials(preFormalMouse, Params, "randomCue", numProbeTrials, true);
	zeroNoLearning = TransferLearning.THModel.SampleDecisionTrials(preFormalMouse, Params, "zeroCue", numProbeTrials, true);
	randomDeterministic = TransferLearning.THModel.SampleDecisionTrials(preFormalMouse, Params, "randomCue", numProbeTrials, false);
	zeroDeterministic = TransferLearning.THModel.SampleDecisionTrials(preFormalMouse, Params, "zeroCue", numProbeTrials, false);
	initialFormalCueDrive = TransferLearning.THModel.CueDecisionDrive(initialMouse, Params, false);
	cueAfferentOnlyFormalDrive = NaN;
	noTrainedCueAfferentFormalDrive = NaN;

	formalMouse = preFormalMouse;
	[formalFirstHit, ~, ~, postFormalMouse, formalTrialTable] = TransferLearning.THModel.SimulateSession(formalMouse, Params, formalCond, false);
	formalTrialTables{iMouse} = formalTrialTable;

	unrelatedMouse = preFormalMouse;
	unrelatedMouse.CueInputPattern = TransferLearning.THModel.ClampPattern(TransferLearning.THModel.Standardize(TransferLearning.THModel.Randn([Params.NCueInput, 1])), Params);
	unrelatedNoLearning = TransferLearning.THModel.SampleDecisionTrials(unrelatedMouse, Params, "formalCue", Params.NumTrials, true);
	[unrelatedFirstHit, ~, ~, ~] = TransferLearning.THModel.SimulateSession(unrelatedMouse, Params, formalCond, false);

	rows(iMouse).Mouse = iMouse;
	rows(iMouse).PretrainReached = pretrainReached;
	rows(iMouse).PretrainSessions = iSession;
	rows(iMouse).PretrainFinalHit = pretrainFinalHit;
	rows(iMouse).InputCueCorr = iCueCorrelation(preFormalMouse.PreCueInputPattern, preFormalMouse.CueInputPattern);
	rows(iMouse).UnrelatedCueCorr = iCueCorrelation(preFormalMouse.PreCueInputPattern, unrelatedMouse.CueInputPattern);
	rows(iMouse).PreCueDrive = preCueProbe;
	rows(iMouse).FormalCueDrive = formalCueProbe;
	rows(iMouse).FormalCueNoInhDrive = formalCueNoInhProbe;
	rows(iMouse).InitialFormalCueDrive = initialFormalCueDrive;
	rows(iMouse).InitialFormalNoLearningHitRate = mean(initialFormalNoLearning.Hit, 'omitnan');
	rows(iMouse).InitialFormalFirstSessionHitRate = initialFormalFirstHit;
	rows(iMouse).InitialZeroCueHitRate = mean(initialZeroNoLearning.Hit, 'omitnan');
	rows(iMouse).CueAfferentOnlyFormalDrive = cueAfferentOnlyFormalDrive;
	rows(iMouse).NoTrainedCueAfferentFormalDrive = noTrainedCueAfferentFormalDrive;
	rows(iMouse).FormalNoLearningHitRate = mean(formalNoLearning.Hit, 'omitnan');
	rows(iMouse).FormalNoLearningMeanDrive = mean(formalNoLearning.Drive, 'omitnan');
	rows(iMouse).FormalNoLearningFirstDrive = formalNoLearning.Drive(1);
	rows(iMouse).RandomCueHitRate = mean(randomNoLearning.Hit, 'omitnan');
	rows(iMouse).RandomCueMeanDrive = mean(randomNoLearning.Drive, 'omitnan');
	rows(iMouse).RandomCueMaxDrive = max(randomNoLearning.Drive);
	rows(iMouse).RandomDeterministicHitRate = mean(randomDeterministic.Hit, 'omitnan');
	rows(iMouse).RandomDeterministicMeanDrive = mean(randomDeterministic.Drive, 'omitnan');
	rows(iMouse).ZeroCueHitRate = mean(zeroNoLearning.Hit, 'omitnan');
	rows(iMouse).ZeroCueMeanDrive = mean(zeroNoLearning.Drive, 'omitnan');
	rows(iMouse).ZeroDeterministicDrive = mean(zeroDeterministic.Drive, 'omitnan');
	rows(iMouse).UnrelatedNoLearningHitRate = mean(unrelatedNoLearning.Hit, 'omitnan');
	rows(iMouse).UnrelatedFirstSessionHitRate = unrelatedFirstHit;
	rows(iMouse).FormalFirstSessionHitRate = formalFirstHit;
	rows(iMouse).FormalFirstTrialHit = formalTrialTable.Hit(1);
	rows(iMouse).FormalFirstTrialDrive = formalTrialTable.DecisionDrive(1);
	rows(iMouse).FormalWithinSessionLift = formalFirstHit - mean(formalNoLearning.Hit, 'omitnan');
	rows(iMouse).PostFormalCueDrive = TransferLearning.THModel.CueDecisionDrive(postFormalMouse, Params, false);
end

MouseTable = struct2table(rows);
Report.MouseTable = MouseTable;
Report.FormalTrialTables = formalTrialTables;
Report.Summary = table( ...
	mean(MouseTable.PretrainReached), ...
	mean(MouseTable.PretrainSessions, 'omitnan'), ...
	mean(MouseTable.InputCueCorr, 'omitnan'), ...
	mean(MouseTable.UnrelatedCueCorr, 'omitnan'), ...
	mean(MouseTable.FormalFirstSessionHitRate, 'omitnan'), ...
	mean(MouseTable.FormalNoLearningHitRate, 'omitnan'), ...
	mean(MouseTable.FormalWithinSessionLift, 'omitnan'), ...
	mean(MouseTable.InitialFormalFirstSessionHitRate, 'omitnan'), ...
	mean(MouseTable.InitialFormalNoLearningHitRate, 'omitnan'), ...
	mean(MouseTable.InitialZeroCueHitRate, 'omitnan'), ...
	mean(MouseTable.UnrelatedFirstSessionHitRate, 'omitnan'), ...
	mean(MouseTable.UnrelatedNoLearningHitRate, 'omitnan'), ...
	mean(MouseTable.RandomCueHitRate, 'omitnan'), ...
	mean(MouseTable.ZeroCueHitRate, 'omitnan'), ...
	mean(MouseTable.FormalCueDrive, 'omitnan'), ...
	mean(MouseTable.InitialFormalCueDrive, 'omitnan'), ...
	mean(MouseTable.CueAfferentOnlyFormalDrive, 'omitnan'), ...
	mean(MouseTable.NoTrainedCueAfferentFormalDrive, 'omitnan'), ...
	mean(MouseTable.RandomCueMeanDrive, 'omitnan'), ...
	mean(MouseTable.ZeroCueMeanDrive, 'omitnan'), ...
	mean(MouseTable.PostFormalCueDrive, 'omitnan'), ...
	'VariableNames', {'PretrainReachRate','MeanPretrainSessions','MeanInputCueCorr','MeanUnrelatedCueCorr','MeanFormalFirstSessionHitRate','MeanFormalNoLearningHitRate','MeanFormalWithinSessionLift','MeanInitialFormalFirstSessionHitRate','MeanInitialFormalNoLearningHitRate','MeanInitialZeroCueHitRate','MeanUnrelatedFirstSessionHitRate','MeanUnrelatedNoLearningHitRate','MeanRandomCueHitRate','MeanZeroCueHitRate','MeanFormalCueDrive','MeanInitialFormalCueDrive','MeanCueAfferentOnlyFormalDrive','MeanNoTrainedCueAfferentFormalDrive','MeanRandomCueDrive','MeanZeroCueDrive','MeanPostFormalCueDrive'});
end

function rho = iCueCorrelation(a, b)
a = TransferLearning.THModel.GatherValue(a(:));
b = TransferLearning.THModel.GatherValue(b(:));
if std(a, 0) < eps || std(b, 0) < eps
	rho = NaN;
	return;
end
rho = corr(a, b);
end