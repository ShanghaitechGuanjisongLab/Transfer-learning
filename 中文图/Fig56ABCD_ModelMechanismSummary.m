% Fig56ABCD model mechanism summary for Naive vs Continual CueB training.

svgName = '中文图Fig56ABCD_ModelMechanismSummary.svg';
iEnsureTransferLearningProject();

run(fullfile(fileparts(mfilename('fullpath')), 'Fig5556_LoadSharedModelData.m'));
Params = Fig5556Data.Params;
Cond = Fig5556Data.Cond;

MechanismData = iBuildMechanismData(Params, Cond, Fig5556Data.ConditionNames, Fig5556Data.ConditionSeedValues);
[fig, Stats] = iPlotFig56ABCD(MechanismData);

svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig56ABCD_ModelMechanismData', MechanismData);
assignin('base', 'Fig56ABCD_ModelMechanismStats', Stats);
assignin('base', 'Fig56ABCD_ModelMechanismSvgPath', svgPath);

function Data = iBuildMechanismData(Params, Cond, conditionNames, conditionSeedValues)
conditionNames = string(conditionNames);
naiveSeedValues = conditionSeedValues(:, conditionNames == "Naive");
continualSeedValues = conditionSeedValues(:, conditionNames == "Transfer");
naiveCond = Cond(Cond.Name == "Naive", :);
continualCond = Cond(Cond.Name == "Transfer", :);
if height(naiveCond) ~= 1 || height(continualCond) ~= 1
	error('Fig56ABCD:MissingCondition', 'Expected one Naive and one Transfer condition row.');
end

iPrepareParallelWorkers();
numMice = Params.NumMice;
preFormalRows = cell(numMice, 1);
unitRows = cell(numMice, 1);
parfor mouseIndex = 1:numMice
	[preNaive, unitsNaive] = iRunConditionDiagnostics(Params, naiveCond, "Naive", naiveSeedValues(mouseIndex), mouseIndex, false);
	[preContinual, unitsContinual] = iRunConditionDiagnostics(Params, continualCond, "Continual", continualSeedValues(mouseIndex), mouseIndex, true);
	preFormalRows{mouseIndex} = [preNaive; preContinual];
	unitRows{mouseIndex} = [unitsNaive; unitsContinual];
end

Data = struct();
Data.Params = Params;
Data.PreFormalTable = vertcat(preFormalRows{:});
Data.UnitTable = vertcat(unitRows{:});
end

function [preFormalRow, unitRows] = iRunConditionDiagnostics(Params, condRow, displayCondition, seedValue, mouseIndex, doPretrain)
rng(seedValue, 'twister');
Mouse = TransferLearning.THModel.DrawMouse(Params);
if doPretrain
	[Mouse, pretrainResult] = TransferLearning.THModel.SimulatePretraining(Mouse, Params, condRow);
	if ~pretrainResult.Reached
		error('Fig56ABCD:PretrainDidNotReach', 'Mouse %d did not reach pretraining ceiling.', mouseIndex);
	end
end

preFormalRow = iPreFormalConnectionRow(Mouse, displayCondition, mouseIndex);
unitRows = iRunFirstThreeFormalUnits(Mouse, Params, condRow, displayCondition, mouseIndex);
end

function row = iPreFormalConnectionRow(Mouse, displayCondition, mouseIndex)
sharedInhibitoryMask = Mouse.PreCueL23InhibitoryPattern(:) > 0 & Mouse.CueL23InhibitoryPattern(:) > 0;
nonPositiveReadMask = Mouse.L5ReadoutPattern(:) <= 0;
weights = Mouse.WI23ToL5Read(nonPositiveReadMask, sharedInhibitoryMask);

row = table;
row.Condition = string(displayCondition);
row.Mouse = mouseIndex;
row.SharedInhibitoryCount = nnz(sharedInhibitoryMask);
row.NonPositiveReadCount = nnz(nonPositiveReadMask);
row.SharedIToNonPosReadStrength = mean(max(weights(:), 0), 'omitnan');
end

function unitRows = iRunFirstThreeFormalUnits(Mouse, Params, condRow, displayCondition, mouseIndex)
unitRows = table();
firstPerfectUnit = NaN;
for unitIndex = 1:min(3, Params.NumSessions)
	if isfinite(firstPerfectUnit)
		unitRows = [unitRows; iEmptyUnitRow(displayCondition, mouseIndex, unitIndex, false)]; %#ok<AGROW>
		continue;
	end
	[oneRow, Mouse] = iRunOneFormalUnit(Mouse, Params, condRow, displayCondition, mouseIndex, unitIndex);
	unitRows = [unitRows; oneRow]; %#ok<AGROW>
	if oneRow.HitRate >= Params.Ceiling
		firstPerfectUnit = unitIndex;
	end
end
end

function [row, Mouse] = iRunOneFormalUnit(Mouse, Params, condRow, displayCondition, mouseIndex, unitIndex)
preWeights = iCollectCueL23ToPositiveReadoutWeights(Mouse, Params);
numTrials = Params.NumTrials;
isHit = false(numTrials, 1);
noisePassAttempt = nan(numTrials, 1);
nonPositiveReadActivity = nan(numTrials, 1);

eta = Params.HebbRate;
teachingSignalScale = TransferLearning.THModel.TeachingSignalScale(condRow, Params, false);
l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
nonPositiveReadMask = Mouse.L5ReadoutPattern(:) <= 0;

for trialIndex = 1:numTrials
	[Mouse, noisePassState] = TransferLearning.THModel.RunNoiseCueBacktrainingUntilPass(Mouse, Params, eta);
	noisePassAttempt(trialIndex) = noisePassState.Attempt;

	cueInput = Mouse.CueInputPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NCueInput, 1]);
	inputIL23 = Mouse.CueL23InhibitoryPattern + Params.NoiseScale * TransferLearning.THModel.Randn([Params.NIL23, 1]);
	initialActivity = noisePassState.InternalActivity;
	l23Rows = 1:Params.NL23;
	initialActivity(l23Rows) = TransferLearning.THModel.ClampActivity(initialActivity(l23Rows) + cueInput, Params);
	zeroL5RewardRecvInput = TransferLearning.THModel.Zeros([Params.NL5RewardRecv, 1]);
	zeroL5ReadInput = TransferLearning.THModel.Zeros([Params.NL5Read, 1]);

	[Mouse, cueDecision] = TransferLearning.THModel.RunCueDecisionLearningFromState(Mouse, Params, initialActivity, noisePassState.InhibitoryState.L23, cueInput, zeroL5RewardRecvInput, zeroL5ReadInput, inputIL23, eta, teachingSignalScale, Params.RecurrentPasses, true);
	isHit(trialIndex) = cueDecision.Hit;
	internalHistory = TransferLearning.THModel.GatherValue(cueDecision.InternalHistory);
	l5ReadHistory = internalHistory(l5ReadRows, :);
	nonPositiveReadActivity(trialIndex) = mean(l5ReadHistory(nonPositiveReadMask, 2:end), 'all', 'omitnan');
end

postWeights = iCollectCueL23ToPositiveReadoutWeights(Mouse, Params);
row = iEmptyUnitRow(displayCondition, mouseIndex, unitIndex, true);
row.HitRate = mean(isHit, 'omitnan');
row.NoiseBacktrainFrequency = mean(noisePassAttempt > 1, 'omitnan');
row.NoiseExtraAttemptMean = mean(max(noisePassAttempt - 1, 0), 'omitnan');
row.NonPositiveReadActivity = mean(nonPositiveReadActivity, 'omitnan');
row.PositiveProjectionDelta = mean(max(postWeights.All(:), 0) - max(preWeights.All(:), 0), 'omitnan');
row.PositiveProjectionDeltaE = mean(max(postWeights.E(:), 0) - max(preWeights.E(:), 0), 'omitnan');
row.PositiveProjectionDeltaI = mean(max(postWeights.I(:), 0) - max(preWeights.I(:), 0), 'omitnan');
end

function weights = iCollectCueL23ToPositiveReadoutWeights(Mouse, Params)
cueL23Columns = find(Mouse.CueInputPattern(:) > 0);
positiveReadE = Mouse.L5ReadoutPattern(:) > 0;
positiveReadI = Mouse.L5ReadInhibitoryReadoutPattern(:) > 0;
l5ReadRows = Params.NL23 + Params.NL5RewardRecv + (1:Params.NL5Read);
eRows = l5ReadRows(positiveReadE);
iRows = find(positiveReadI);
weights = struct();
weights.E = Mouse.W_L23L5ToL23L5(eRows, cueL23Columns);
weights.I = Mouse.WEI_L5Read(iRows, cueL23Columns);
weights.All = [weights.E(:); weights.I(:)];
end

function row = iEmptyUnitRow(displayCondition, mouseIndex, unitIndex, didSimulate)
row = table;
row.Condition = string(displayCondition);
row.Mouse = mouseIndex;
row.Unit = unitIndex;
row.DidSimulate = didSimulate;
row.HitRate = NaN;
row.NoiseBacktrainFrequency = NaN;
row.NoiseExtraAttemptMean = NaN;
row.NonPositiveReadActivity = NaN;
row.PositiveProjectionDelta = NaN;
row.PositiveProjectionDeltaE = NaN;
row.PositiveProjectionDeltaI = NaN;
end

function [fig, Stats] = iPlotFig56ABCD(Data)
palette = TransferLearning.GroupColors(["Naive", "Continual"]);
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});
preFormalTable = Data.PreFormalTable;
unitTable = Data.UnitTable;

fig = figure('Color', 'w', 'Name', 'Fig56ABCD model mechanism summary');
fig.Units = 'centimeters';
fig.Position(3:4) = [5, 22.2];
fig.PaperUnits = 'centimeters';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0, 0, 5, 22.2];
fig.PaperSize = [5, 22.2];

layout = tiledlayout(fig, 4, 1, 'TileSpacing', 'tight', 'Padding', 'tight');

axConnection = nexttile(layout, 1);
connectionNaive = iFiniteValues(preFormalTable.SharedIToNonPosReadStrength(preFormalTable.Condition == "Naive"));
connectionContinual = iFiniteValues(preFormalTable.SharedIToNonPosReadStrength(preFormalTable.Condition == "Continual"));
[connectionPValue, connectionStats, ~] = iPlotBarComparison(axConnection, {connectionNaive, connectionContinual}, compareGroup, palette, "Weight", ["Shared inh. cue", "→ L5E non-RO"]);

axActivity = nexttile(layout, 2);
firstUnitTable = unitTable(unitTable.Unit == 1 & unitTable.DidSimulate, :);
activityNaive = iFiniteValues(firstUnitTable.NonPositiveReadActivity(firstUnitTable.Condition == "Naive"));
activityContinual = iFiniteValues(firstUnitTable.NonPositiveReadActivity(firstUnitTable.Condition == "Continual"));
[activityPValue, activityStats, ~] = iPlotBarComparison(axActivity, {activityNaive, activityContinual}, compareGroup, palette, "Activity", ["L5E", "non-readout"]);

axNoise = nexttile(layout, 3);
noiseLabelPosition = [0.96, 0.91; 0.96, 0.74];
noiseLabelAlignment = ["right", "right"];
noiseStats = iPlotLineComparison(axNoise, unitTable, "NoiseBacktrainFrequency", palette, "Frequency", ["Noise", "anti-Hebb"], true, 3.75, 0.16, noiseLabelPosition, noiseLabelAlignment);

axProjection = nexttile(layout, 4);
projectionLabelPosition = [0.96, 0.25; 0.96, 0.91];
projectionLabelAlignment = ["right", "right"];
projectionStats = iPlotLineComparison(axProjection, unitTable, "PositiveProjectionDelta", palette, "Δweight", ["Excit. cue neurons", "→ L5 readout"], true, 3.75, 0.18, projectionLabelPosition, projectionLabelAlignment);

Stats = struct();
Stats.Connection = struct('Summary', connectionStats, 'PValue', connectionPValue);
Stats.Activity = struct('Summary', activityStats, 'PValue', activityPValue);
Stats.Noise = noiseStats;
Stats.Projection = projectionStats;

iPrintBarStats('Shared inhibitory cue neurons → L5 excitatory non-readout weight', connectionStats, connectionPValue);
iPrintBarStats('L5 excitatory non-readout activity', activityStats, activityPValue);
iPrintLineStats('Noise anti-Hebb frequency', noiseStats);
iPrintLineStats('Excitatory cue neurons → L5 readout Δweight', projectionStats);
iSetAllTextTo12Pt(fig);
end

function [pValue, stats, optional] = iPlotBarComparison(ax, dataCell, compareGroup, palette, yLabelText, titleText)
axes(ax);
naiveValues = dataCell{1};
continualValues = dataCell{2};
pValue = ranksum(naiveValues, continualValues);
[~, optional, bars, errorBars] = UniExp.BarScatterCompare(dataCell, compareGroup, 'AsteriskThreshold', 0.05);
iStyleBarTile(ax, bars, errorBars, optional, palette, titleText, pValue);
ylabel(ax, yLabelText);
stats = table(["Naive"; "Continual"], [numel(naiveValues); numel(continualValues)], [mean(naiveValues, 'omitnan'); mean(continualValues, 'omitnan')], [iSem(naiveValues); iSem(continualValues)], ...
	'VariableNames', {'Condition','N','Mean','Sem'});
end

function stats = iPlotLineComparison(ax, unitTable, metricName, palette, yLabelText, titleText, showXLabel, xLimitMax, yLimitMax, labelPosition, labelAlignment)
[meanMat, semMat, countMat] = iUnitMeanSem(unitTable, metricName);
[yCells, semCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
axes(ax);
lineHandles = MATLAB.Graphics.MultiShadowedLines(yCells, semCells, X=xCells, EdgeColors=palette);
iStyleLineTile(ax, lineHandles, titleText, yLabelText, showXLabel, xLimitMax, yLimitMax);
iAddLineEndLabels(ax, meanMat, palette, labelPosition, labelAlignment);

pValues = nan(3, 1);
for unitIndex = 1:3
	naiveValues = iFiniteValues(unitTable.(metricName)(unitTable.Condition == "Naive" & unitTable.Unit == unitIndex & unitTable.DidSimulate));
	continualValues = iFiniteValues(unitTable.(metricName)(unitTable.Condition == "Continual" & unitTable.Unit == unitIndex & unitTable.DidSimulate));
	if numel(naiveValues) >= 2 && numel(continualValues) >= 2
		pValues(unitIndex) = ranksum(naiveValues, continualValues);
	end
end
stats = table((1:3)', countMat(:, 1), countMat(:, 2), meanMat(:, 1), meanMat(:, 2), semMat(:, 1), semMat(:, 2), meanMat(:, 2) - meanMat(:, 1), pValues, ...
	'VariableNames', {'Unit','NaiveN','ContinualN','NaiveMean','ContinualMean','NaiveSem','ContinualSem','ContinualMinusNaive','PValue'});
end

function [meanMat, semMat, countMat] = iUnitMeanSem(unitTable, metricName)
conditionList = ["Naive", "Continual"];
meanMat = nan(3, numel(conditionList));
semMat = nan(3, numel(conditionList));
countMat = zeros(3, numel(conditionList));
for conditionIndex = 1:numel(conditionList)
	conditionName = conditionList(conditionIndex);
	for unitIndex = 1:3
		values = iFiniteValues(unitTable.(metricName)(unitTable.Condition == conditionName & unitTable.Unit == unitIndex & unitTable.DidSimulate));
		countMat(unitIndex, conditionIndex) = numel(values);
		meanMat(unitIndex, conditionIndex) = mean(values, 'omitnan');
		semMat(unitIndex, conditionIndex) = iSem(values);
	end
end
end

function [yCells, semCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
numLines = size(meanMat, 2);
yCells = cell(1, numLines);
semCells = cell(1, numLines);
xCells = cell(1, numLines);
for lineIndex = 1:numLines
	yCells{lineIndex} = meanMat(:, lineIndex);
	semCells{lineIndex} = semMat(:, lineIndex);
	xCells{lineIndex} = (1:size(meanMat, 1))';
end
end

function iStyleBarTile(ax, bars, errorBars, optional, palette, titleText, pValue)
ax.FontSize = 12;
ax.LineWidth = 0.5;
ax.TickDir = 'out';
ax.XTick = [1 2];
ax.XTickLabel = {'Naive', 'Continual'};
ax.XTickLabelRotation = 25;
iSetTitle(ax, titleText);
box(ax, 'off');
grid(ax, 'off');
legend(ax, 'off');
iHideToolbar(ax);
iStyleBars(bars, palette);
iStyleErrorBars(errorBars, palette);
iStyleScatter(ax);
iApplyPText(optional, pValue);
end

function iStyleLineTile(ax, ~, titleText, yLabelText, showXLabel, xLimitMax, yLimitMax)
ax.FontSize = 12;
ax.LineWidth = 0.5;
ax.TickDir = 'out';
ax.XLim = [0.75, xLimitMax];
ax.XTick = 1:3;
ax.XTickLabel = {'1', '2', '3'};
if showXLabel
	xlabel(ax, 'Block');
end
ylabel(ax, yLabelText);
iSetTitle(ax, titleText);
box(ax, 'off');
grid(ax, 'off');
iHideToolbar(ax);
for lineObject = findobj(ax, 'Type', 'Line')'
	lineObject.Marker = 'o';
	lineObject.MarkerSize = 2;
	lineObject.LineWidth = 1;
end
currentYLim = ylim(ax);
ylim(ax, [0, max([currentYLim(2), yLimitMax, eps])]);
end

function iAddLineEndLabels(ax, meanMat, palette, labelPosition, labelAlignment)
conditionLabels = ["Naive", "Continual"];
for conditionIndex = 1:numel(conditionLabels)
	y = meanMat(:, conditionIndex);
	lastIndex = find(isfinite(y), 1, 'last');
	if isempty(lastIndex)
		continue;
	end
	text(ax, labelPosition(conditionIndex, 1), labelPosition(conditionIndex, 2), conditionLabels(conditionIndex), ...
		'Units', 'normalized', ...
		'Color', palette(conditionIndex, :), ...
		'HorizontalAlignment', char(labelAlignment(conditionIndex)), ...
		'VerticalAlignment', 'middle', ...
		'BackgroundColor', 'w', ...
		'Margin', 0.5, ...
		'FontSize', 12, ...
		'Clipping', 'on');
end
end

function iStyleBars(bars, palette)
if isscalar(bars)
	bars.FaceColor = 'flat';
	numBars = numel(bars.YData);
	bars.CData = repmat(palette, ceil(numBars / size(palette, 1)), 1);
	bars.CData = bars.CData(1:numBars, :);
	bars.BarWidth = 0.5;
	bars.LineWidth = 1;
	bars.EdgeColor = 'none';
	bars.FaceAlpha = 1;
else
	for barIndex = 1:min(numel(bars), size(palette, 1))
		bars(barIndex).FaceColor = palette(barIndex, :);
		bars(barIndex).LineWidth = 1;
		bars(barIndex).EdgeColor = 'none';
		bars(barIndex).FaceAlpha = 1;
	end
end
end

function iSetTitle(ax, titleText)
title(ax, cellstr(titleText), 'FontWeight', 'normal', 'FontSize', 12);
end

function iStyleErrorBars(errorBars, palette)
if istable(errorBars) && ismember('Object', errorBars.Properties.VariableNames)
	errorBarObjects = errorBars.Object(:);
elseif isstruct(errorBars) && isfield(errorBars, 'Object')
	errorBarObjects = errorBars.Object(:);
else
	return;
end
for errorBarObject = errorBarObjects'
	if ~isgraphics(errorBarObject)
		continue;
	end
	if isprop(errorBarObject, 'YNegativeDelta')
		errorBarObject.YNegativeDelta(:) = 0;
	end
	errorBarObject.LineWidth = 1;
	errorBarObject.LineStyle = 'none';
	errorBarObject.HandleVisibility = 'off';
	xData = double(errorBarObject.XData(:));
	[~, colorIndex] = min(abs((1:size(palette, 1)).' - xData(1)));
	errorBarObject.Color = palette(colorIndex, :);
end
end

function iStyleScatter(ax)
scatterObjects = findobj(ax, '-isa', 'matlab.graphics.chart.primitive.Scatter');
for scatterObject = scatterObjects(:)'
	scatterObject.LineWidth = 0.2;
	if isprop(scatterObject, 'MarkerEdgeAlpha')
		scatterObject.MarkerEdgeAlpha = 0.5;
	end
	if isprop(scatterObject, 'MarkerFaceAlpha')
		scatterObject.MarkerFaceAlpha = 0.6;
	end
end
end

function iApplyPText(optional, pValue)
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
if ismember('PText', optional.MultiCompare.Properties.VariableNames)
	for textObject = optional.MultiCompare.PText(:)'
		if isgraphics(textObject)
			textObject.FontSize = 12;
			textObject.String = iFormatPValue(pValue);
			textObject.Tag = 'PText';
		end
	end
end
if ismember('PLine', optional.MultiCompare.Properties.VariableNames)
	for lineObject = optional.MultiCompare.PLine(:)'
		if isgraphics(lineObject)
			lineObject.LineWidth = 0.5;
			lineObject.Tag = 'PLine';
		end
	end
end
end

function iSetAllTextTo12Pt(fig)
textHandles = findall(fig, '-property', 'FontSize');
for handleIndex = 1:numel(textHandles)
	textHandles(handleIndex).FontSize = 12;
end
layouts = findall(fig, '-isa', 'matlab.graphics.layout.TiledChartLayout');
for layoutIndex = 1:numel(layouts)
	for propertyName = ["Title", "XLabel", "YLabel"]
		if isprop(layouts(layoutIndex), propertyName) && isprop(layouts(layoutIndex).(propertyName), 'FontSize')
			layouts(layoutIndex).(propertyName).FontSize = 12;
		end
	end
end
end

function values = iFiniteValues(values)
values = double(values(:));
values = values(isfinite(values));
end

function semValue = iSem(values)
values = iFiniteValues(values);
if isempty(values)
	semValue = NaN;
else
	semValue = std(values, 0, 'omitnan') ./ sqrt(numel(values));
end
end

function iPrintBarStats(labelText, stats, pValue)
fprintf('\n=== Fig56ABCD %s ===\n', labelText);
for rowIndex = 1:height(stats)
	fprintf('%s: %.6g ± %.6g (n=%d)\n', stats.Condition(rowIndex), stats.Mean(rowIndex), stats.Sem(rowIndex), stats.N(rowIndex));
end
fprintf('ranksum p = %.6g\n', pValue);
end

function iPrintLineStats(labelText, stats)
fprintf('\n=== Fig56ABCD %s ===\n', labelText);
for rowIndex = 1:height(stats)
	fprintf('unit %d: Naive %.6g ± %.6g (n=%d), Continual %.6g ± %.6g (n=%d), diff %.6g, p %.6g\n', ...
		stats.Unit(rowIndex), stats.NaiveMean(rowIndex), stats.NaiveSem(rowIndex), stats.NaiveN(rowIndex), ...
		stats.ContinualMean(rowIndex), stats.ContinualSem(rowIndex), stats.ContinualN(rowIndex), ...
		stats.ContinualMinusNaive(rowIndex), stats.PValue(rowIndex));
end
end

function textValue = iFormatPValue(pValue)
if ~isfinite(pValue)
	textValue = 'p = NaN';
elseif pValue < 0.001
	textValue = 'p < 0.001';
elseif pValue < 0.01
	textValue = sprintf('p = %.3f', pValue);
else
	textValue = sprintf('p = %.2f', pValue);
end
end

function iHideToolbar(ax)
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iPrepareParallelWorkers()
pool = gcp('nocreate');
if isempty(pool)
	parpool('local', 20);
end
end

function iEnsureTransferLearningProject()
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end
end