% English Fig5C: first-formal-training-unit L5 response heatmap in the model.
% Caliber copied from Chinese Fig54D: three lanes - Naive CueA (first pretrain
% training unit responding to Cue A, re-simulated per Transfer seed with
% pre-cue teaching), Naive CueB (first formal training unit of Naive mice
% responding to Cue B), Transfer CueB (first formal training unit of Transfer
% mice responding to Cue B). L5 raw response (baseline added back) over the
% first two decision iterations, per-mouse median across trials, 50 mice x 128
% L5 cells per lane. Rows sorted by within-lane descending response integral.
%
% Claim: the inherited Cue A ensemble responds to Cue B only in the Transfer
% lane, i.e. reactivation instead of de-novo recruitment.
%
% Outputs (SVG):
%   - English_Fig5C_ModelFirstFormalUnitDecisionHeatmap.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

svgName = "English_Fig5C_ModelFirstFormalUnitDecisionHeatmap.svg";

thisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

% 正式两泳道直接从共享缓存取；Naive CueA 泳道按 Transfer 种子重模拟一次，
% 结果缓存在 base 变量，重跑脚本时不重复仿真。
if evalin('base', "exist('Fig5C_PretrainCueAHeatmapData', 'var') == 1")
	PretrainFullCellHeatmapData = evalin('base', 'Fig5C_PretrainCueAHeatmapData');
	PretrainRunInfo = evalin('base', 'Fig5C_PretrainCueARunInfo');
else
	run(fullfile(thisDir, '..', '中文图', 'Fig5556_LoadSharedModelData.m'));
	[PretrainFullCellHeatmapData, PretrainRunInfo] = iBuildTransferPretrainCueAHeatmapData(Fig5556Data.Params, Fig5556Data.Cond, Fig5556Data.HeatmapRunInfo);
	assignin('base', 'Fig5C_PretrainCueAHeatmapData', PretrainFullCellHeatmapData);
	assignin('base', 'Fig5C_PretrainCueARunInfo', PretrainRunInfo);
end
if evalin('base', "exist('Fig5556_ModelData', 'var') ~= 1")
	run(fullfile(thisDir, '..', '中文图', 'Fig5556_LoadSharedModelData.m'));
end
FormalFullCellHeatmapData = Fig5556Data.HeatmapData;
Params = Fig5556Data.Params;
FormalRunInfo = Fig5556Data.HeatmapRunInfo;

FullCellHeatmapData = iBuildThreeColumnFullCellHeatmapData(PretrainFullCellHeatmapData, FormalFullCellHeatmapData);
RunInfo = [PretrainRunInfo; iRelabelFormalRunInfo(FormalRunInfo)];

HeatmapData = iBuildL5RawResponseHeatmapData(FullCellHeatmapData, Params);
HeatmapData = iKeepFirstTwoTimePoints(HeatmapData);
[fig, PlotData] = TransferLearning.PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData, ...
	YLabel=sprintf('L5 cells'), ...
	ColorbarLabel="Response", ...
	FigureName="English Fig5C model first formal unit L5 response heatmap");
layout = PlotData.Axes(1).Parent;
xlabel(layout, 'Recurrent iterations');
axesList = PlotData.Axes(:);
for axisIndex = 1:numel(axesList)
	ax = axesList(axisIndex);
	ax.XTick = [0, 1];
	ax.XTickLabelMode = 'auto';
end
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig5C_HeatmapData', HeatmapData);
assignin('base', 'Fig5C_HeatmapRunInfo', RunInfo);
assignin('base', 'Fig5C_PlotData', PlotData);

%% ========== local functions (copied from Chinese Fig54D) ==========
function HeatmapData = iBuildThreeColumnFullCellHeatmapData(PretrainFullCellHeatmapData, FormalFullCellHeatmapData)
HeatmapData = FormalFullCellHeatmapData;
HeatmapData.ConditionNames = ["TransferPretrainCueA", "NaiveFormalCueB", "TransferFormalCueB"];
HeatmapData.DisplayNames = ["Naive CueA", "Naive CueB", "Transfer CueB"];
HeatmapData.ConditionData = {PretrainFullCellHeatmapData.ConditionData{1}; FormalFullCellHeatmapData.ConditionData{1}; FormalFullCellHeatmapData.ConditionData{2}};
HeatmapData.NaiveCueA = HeatmapData.ConditionData{1};
HeatmapData.NaiveCueB = HeatmapData.ConditionData{2};
HeatmapData.TransferCueB = HeatmapData.ConditionData{3};
HeatmapData.Naive = HeatmapData.NaiveCueB;
HeatmapData.Transfer = HeatmapData.TransferCueB;
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
RunInfo.DisplayName(transferRows) = "Transfer CueB";
RunInfo = sortrows(RunInfo, {'Condition','Mouse'});
end

function [HeatmapData, RunInfo] = iBuildTransferPretrainCueAHeatmapData(Params, Cond, FormalRunInfo)
transferRows = FormalRunInfo(string(FormalRunInfo.Condition) == "Transfer", :);
transferRows = sortrows(transferRows, 'Mouse');
if height(transferRows) ~= Params.NumMice
	error('Fig5C:TransferHeatmapSeedCountMismatch', 'Expected %d Transfer heatmap seed rows, got %d.', Params.NumMice, height(transferRows));
end

condRow = Cond(Cond.Name == "Transfer", :);
if height(condRow) ~= 1
	error('Fig5C:MissingTransferCondition', 'Expected exactly one Transfer condition row.');
end

seedValues = double(transferRows.Seed);
numMice = Params.NumMice;
mouseConditionData = cell(numMice, 1);
mouseInfoRows = cell(numMice, 1);

pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
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

HeatmapData.NaiveCueA = HeatmapData.ConditionData{1};
HeatmapData.NaiveCueB = HeatmapData.ConditionData{2};
HeatmapData.TransferCueB = HeatmapData.ConditionData{3};
HeatmapData.Naive = HeatmapData.NaiveCueB;
HeatmapData.Transfer = HeatmapData.TransferCueB;
HeatmapData.NumCellsPerMouse = Params.NL5RewardRecv + Params.NL5Read;
HeatmapData.NumCells = sum(l5Mask);
HeatmapData.Layer = "L5";
HeatmapData.ResponseType = "Response";
end

function HeatmapData = iKeepFirstTwoTimePoints(HeatmapData)
if numel(HeatmapData.Iterations) < 2
	error('Fig5C:InsufficientIterations', 'Expected at least two iterations for display.');
end

for conditionIndex = 1:numel(HeatmapData.ConditionData)
	conditionData = HeatmapData.ConditionData{conditionIndex};
	conditionData.MedianDelta = conditionData.MedianDelta(:, 1:2);
	if isfield(conditionData, 'DeltaHistory') && ndims(conditionData.DeltaHistory) >= 2
		conditionData.DeltaHistory = conditionData.DeltaHistory(:, 1:2, :);
	end
	HeatmapData.ConditionData{conditionIndex} = conditionData;
end

HeatmapData.Iterations = [0, 1];

HeatmapData.NaiveCueA = HeatmapData.ConditionData{1};
HeatmapData.NaiveCueB = HeatmapData.ConditionData{2};
HeatmapData.TransferCueB = HeatmapData.ConditionData{3};
HeatmapData.Naive = HeatmapData.NaiveCueB;
HeatmapData.Transfer = HeatmapData.TransferCueB;
end
