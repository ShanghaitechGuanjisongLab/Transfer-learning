% Fig382D model first formal training unit L5 response heatmap.

svgName = '中文图Fig382D_ModelFirstFormalUnitDecisionHeatmap.svg';
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
FormalFullCellHeatmapData = Fig382383Data.HeatmapData;
Params = Fig382383Data.Params;
Cond = Fig382383Data.Cond;
FormalRunInfo = Fig382383Data.HeatmapRunInfo;

[PretrainFullCellHeatmapData, PretrainRunInfo] = iBuildContinualPretrainCueAHeatmapData(Params, Cond, FormalRunInfo);
FullCellHeatmapData = iBuildThreeColumnFullCellHeatmapData(PretrainFullCellHeatmapData, FormalFullCellHeatmapData);
RunInfo = [PretrainRunInfo; iRelabelFormalRunInfo(FormalRunInfo)];

HeatmapData = iBuildL5RawResponseHeatmapData(FullCellHeatmapData, Params);
[fig, PlotData] = TransferLearning.PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData, ...
	YLabel=sprintf('L5 cells'), ...
	ColorbarLabel="Response", ...
	FigureName="Model first formal unit L5 response heatmap");
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382D_ModelDecisionHeatmapData', HeatmapData);
assignin('base', 'Fig382D_ModelDecisionHeatmapRunInfo', RunInfo);
assignin('base', 'Fig382D_ModelDecisionHeatmapPlotData', PlotData);
assignin('base', 'Fig382D_ModelDecisionHeatmapSvgPath', svgPath);

function HeatmapData = iBuildThreeColumnFullCellHeatmapData(PretrainFullCellHeatmapData, FormalFullCellHeatmapData)
HeatmapData = FormalFullCellHeatmapData;
HeatmapData.ConditionNames = ["TransferPretrainCueA", "NaiveFormalCueB", "TransferFormalCueB"];
HeatmapData.DisplayNames = ["Naive CueA", "Naive CueB", "Continual CueB"];
HeatmapData.ConditionData = {PretrainFullCellHeatmapData.ConditionData{1}; FormalFullCellHeatmapData.ConditionData{1}; FormalFullCellHeatmapData.ConditionData{2}};
HeatmapData.NaiveCueA = HeatmapData.ConditionData{1};
HeatmapData.NaiveCueB = HeatmapData.ConditionData{2};
HeatmapData.ContinualCueB = HeatmapData.ConditionData{3};
HeatmapData.Naive = HeatmapData.NaiveCueB;
HeatmapData.Continual = HeatmapData.ContinualCueB;
end

function RunInfo = iRelabelFormalRunInfo(FormalRunInfo)
RunInfo = FormalRunInfo;
RunInfo.Condition = string(RunInfo.Condition);
RunInfo.DisplayName = string(RunInfo.DisplayName);
naiveRows = RunInfo.Condition == "Naive";
transferRows = RunInfo.Condition == "Transfer";
RunInfo.Condition(naiveRows) = "NaiveFormalCueB";
RunInfo.DisplayName(naiveRows) = "Naive CueB";
RunInfo.Condition(transferRows) = "TransferFormalCueB";
RunInfo.DisplayName(transferRows) = "Continual CueB";
RunInfo = sortrows(RunInfo, {'Condition','Mouse'});
end

function [HeatmapData, RunInfo] = iBuildContinualPretrainCueAHeatmapData(Params, Cond, FormalRunInfo)
transferRows = FormalRunInfo(string(FormalRunInfo.Condition) == "Transfer", :);
transferRows = sortrows(transferRows, 'Mouse');
if height(transferRows) ~= Params.NumMice
	error('Fig382D:TransferHeatmapSeedCountMismatch', 'Expected %d Transfer heatmap seed rows, got %d.', Params.NumMice, height(transferRows));
end

condRow = Cond(Cond.Name == "Transfer", :);
if height(condRow) ~= 1
	error('Fig382D:MissingTransferCondition', 'Expected exactly one Transfer condition row.');
end

seedValues = double(transferRows.Seed);
numMice = Params.NumMice;
mouseConditionData = cell(numMice, 1);
mouseInfoRows = cell(numMice, 1);

iPrepareParallelWorkers();
parfor mouseIndex = 1:numMice
	rng(seedValues(mouseIndex), 'twister');
	Mouse = TransferLearning.THModel.DrawMouse(Params);
	[unitData, ~] = iCollectFirstTrainingUnit(Mouse, Params, condRow, true);
	firstUnitHitRate = mean(unitData.Hit, 'omitnan');
	mouseConditionData{mouseIndex} = unitData;
	mouseInfoRows{mouseIndex} = struct( ...
		'Mouse', mouseIndex, ...
		'Condition', "TransferPretrainCueA", ...
		'DisplayName', "Naive CueA", ...
		'Seed', seedValues(mouseIndex), ...
		'PretrainReached', firstUnitHitRate >= Params.Ceiling, ...
		'PretrainSessions', 1, ...
		'PretrainFinalHit', firstUnitHitRate, ...
		'FirstUnitHitRate', firstUnitHitRate, ...
		'NumTrials', Params.NumTrials, ...
		'NumDecisionIterations', Params.RecurrentPasses + 1, ...
		'NumCells', Params.NL23L5);
end

medianDeltaCells = cell(numMice, 1);
deltaHistoryCells = cell(numMice, 1);
baselineMeanCells = cell(numMice, 1);
decisionDriveCells = cell(numMice, 1);
hitCells = cell(numMice, 1);
trialTableCells = cell(numMice, 1);
for mouseIndex = 1:numMice
	unitData = mouseConditionData{mouseIndex};
	medianDeltaCells{mouseIndex} = unitData.MedianDelta;
	deltaHistoryCells{mouseIndex} = unitData.DeltaHistory;
	baselineMeanCells{mouseIndex} = unitData.NoiseBaselineMean;
	decisionDriveCells{mouseIndex} = unitData.DecisionDrive;
	hitCells{mouseIndex} = unitData.Hit;
	trialTable = unitData.TrialTable;
	trialTable.Mouse = repmat(mouseIndex, height(trialTable), 1);
	trialTableCells{mouseIndex} = movevars(trialTable, 'Mouse', 'Before', 1);
end

conditionData = cell(1, 1);
conditionData{1}.MedianDelta = vertcat(medianDeltaCells{:});
conditionData{1}.DeltaHistory = cat(1, deltaHistoryCells{:});
conditionData{1}.NoiseBaselineMean = vertcat(baselineMeanCells{:});
conditionData{1}.DecisionDrive = vertcat(decisionDriveCells{:});
conditionData{1}.Hit = vertcat(hitCells{:});
conditionData{1}.TrialTable = vertcat(trialTableCells{:});

HeatmapData = struct();
HeatmapData.ConditionNames = "TransferPretrainCueA";
HeatmapData.DisplayNames = "Naive CueA";
HeatmapData.Iterations = 0:Params.RecurrentPasses;
HeatmapData.NumMice = numMice;
HeatmapData.NumCellsPerMouse = Params.NL23L5;
HeatmapData.NumCells = numMice * Params.NL23L5;
HeatmapData.ConditionData = conditionData;
HeatmapData.NaiveCueA = conditionData{1};

infoRows = vertcat(mouseInfoRows{:});
RunInfo = struct2table(infoRows(:));
end

function [UnitData, Mouse] = iCollectFirstTrainingUnit(Mouse, Params, Cond, usePreCue)
numTrials = Params.NumTrials;
numCells = Params.NL23L5;
numDecisionIterations = Params.RecurrentPasses + 1;
eta = Params.HebbRate;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(Cond, Params, usePreCue);

if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	l23InhibitoryCuePattern = Mouse.PreCueL23InhibitoryPattern;
else
	cueInputPattern = Mouse.CueInputPattern;
	l23InhibitoryCuePattern = Mouse.CueL23InhibitoryPattern;
end

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

	cueInput = cueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23 = l23InhibitoryCuePattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
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

function iPrepareParallelWorkers()
pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
end

function HeatmapData = iBuildL5RawResponseHeatmapData(HeatmapData, Params)
cellsPerMouse = HeatmapData.NumCellsPerMouse;
rowWithinMouse = mod((1:HeatmapData.NumCells)' - 1, cellsPerMouse) + 1;
l5Mask = rowWithinMouse > Params.NL23;

for conditionIndex = 1:numel(HeatmapData.ConditionData)
	conditionData = HeatmapData.ConditionData{conditionIndex};
	deltaHistory = conditionData.DeltaHistory(l5Mask, :, :);
	baselineMean = conditionData.NoiseBaselineMean(l5Mask, :);
	rawHistory = deltaHistory + reshape(baselineMean, size(baselineMean, 1), 1, size(baselineMean, 2));
	conditionData.MedianDelta = median(rawHistory, 3, 'omitnan');
	conditionData.DeltaHistory = rawHistory;
	conditionData.NoiseBaselineMean = baselineMean;
	HeatmapData.ConditionData{conditionIndex} = conditionData;
end

if numel(HeatmapData.ConditionData) == 2
	HeatmapData.Naive = HeatmapData.ConditionData{1};
	HeatmapData.Continual = HeatmapData.ConditionData{2};
elseif numel(HeatmapData.ConditionData) == 3
	HeatmapData.NaiveCueA = HeatmapData.ConditionData{1};
	HeatmapData.NaiveCueB = HeatmapData.ConditionData{2};
	HeatmapData.ContinualCueB = HeatmapData.ConditionData{3};
	HeatmapData.Naive = HeatmapData.NaiveCueB;
	HeatmapData.Continual = HeatmapData.ContinualCueB;
end
HeatmapData.NumCellsPerMouse = Params.NL5RewardRecv + Params.NL5Read;
HeatmapData.NumCells = sum(l5Mask);
HeatmapData.Layer = "L5";
HeatmapData.ResponseType = "Response";
end
