% 中文图334G：cFos 与对照组 LightWater block learning curve sigmoid 拟合斜率

svgName = '中文图Fig45G_cFos_FirstTrainingUnitTrialFitSlope.svg';

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

datasetPath = "\\Data-Server-2\个人数据\张天夫\202601\cFos合集.v2.mat";
dataset = UniExp.DataSet(datasetPath);

groupOrder = ["Control", "MOp"];
displayGroup = ["Control", "cFos inhibited"];

allSessions = iBuildLightWaterBlockSessions(dataset, groupOrder);
if isempty(allSessions)
	error('Fig334G:EmptySessions', 'No LightWater block/session data found.');
end
allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = TransferLearning.BehaviorSessions.iAddSessionIndex(allSessions);

displayedControl = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == groupOrder(1), :));
displayedCFos = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == groupOrder(2), :));
nControlMice = numel(unique(string(displayedControl.Mouse)));
nCFosMice = numel(unique(string(displayedCFos.Mouse)));

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
[~, summaryLearning] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, blockNumbers] = iUnpackLearningSummarize(summaryLearning, groupOrder);
nMat = iComputeNBySession(allSessions, blockNumbers, groupOrder);

fitControl = iFitSigmoidCurve(displayedControl, displayGroup(1));
fitCFos = iFitSigmoidCurve(displayedCFos, displayGroup(2));
permResult = iPermutationTestSigmoidSlope(displayedControl, displayedCFos, displayGroup(1), displayGroup(2), 10000, 1);

xMax = max([max(fitControl.XObserved), max(fitCFos.XObserved), max(blockNumbers)]);
xFit = (1:xMax).';
xFitCurve = linspace(1, xMax, 200).';
controlFitCurve = iSigmoidFromParams(fitControl.ParamRaw, xFit);
cfosFitCurve = iSigmoidFromParams(fitCFos.ParamRaw, xFit);
controlFitCurvePlot = iSigmoidFromParams(fitControl.ParamRaw, xFitCurve);
cfosFitCurvePlot = iSigmoidFromParams(fitCFos.ParamRaw, xFitCurve);

meanMatOut = nan(numel(xFit), size(meanMat, 2));
semMatOut = nan(numel(xFit), size(semMat, 2));
nMatOut = nan(numel(xFit), size(nMat, 2));
meanMatOut(1:size(meanMat, 1), :) = meanMat;
semMatOut(1:size(semMat, 1), :) = semMat;
nMatOut(1:size(nMat, 1), :) = nMat;

fig = figure('Color', 'w', 'Name', 'Fig45G cFos block learning sigmoid');
fig.Units = 'centimeters';
fig.Position(3:4) = [12, 8];
fig.PaperUnits = 'centimeters';
fig.PaperSize = [12, 8];
fig.PaperPositionMode = 'auto';

curveColors = TransferLearning.GroupColors(displayGroup);
curveColors(1,:) = TransferLearning.ContinualColor;
axisHandle = axes(fig);
hold(axisHandle, 'on');
hControl = iPlotGroupMeanErrorbarsSingleAx(axisHandle, xFitCurve, meanMatOut(:,1), semMatOut(:,1), controlFitCurvePlot, curveColors(1, :));
hCFos = iPlotGroupMeanErrorbarsSingleAx(axisHandle, xFitCurve, meanMatOut(:,2), semMatOut(:,2), cfosFitCurvePlot, curveColors(2, :));

ylabel(axisHandle, 'Hit rate', 'FontSize', 12);
xlabel(axisHandle, 'Block', 'FontSize', 12);
ylim(axisHandle, [0 1.02]);
xlim(axisHandle, [0.5, xMax + 0.5]);
axisHandle.FontSize = 12;
axisHandle.LineWidth = 2;
axisHandle.Color = 'none';
axisHandle.YTick = 0:0.5:1;
axisHandle.XTick = unique([1, 5:5:ceil(xMax)]);
legend(axisHandle, [hControl(1), hControl(2), hCFos(1), hCFos(2)], ...
	{'Control Mean ± SEM', 'Control Sigmoid', 'cFos inhibited Mean ± SEM', 'cFos inhibited Sigmoid'}, ...
	'FontSize', 10, 'Location', 'southoutside', 'NumColumns', 2, 'Box', 'off');
title(axisHandle, '');
box(axisHandle, 'off');
grid(axisHandle, 'off');

allAxes = findall(fig, 'Type', 'axes');
for axisItem = reshape(allAxes, 1, [])
	if isprop(axisItem, 'Toolbar') && ~isempty(axisItem.Toolbar)
		axisItem.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);

fitTable = table;
fitTable.Group = displayGroup(:);
fitTable.Lower = [fitControl.Lower; fitCFos.Lower];
fitTable.Upper = [fitControl.Upper; fitCFos.Upper];
fitTable.Slope = [fitControl.Slope; fitCFos.Slope];
fitTable.Midpoint = [fitControl.Midpoint; fitCFos.Midpoint];
fitTable.SSE = [fitControl.SSE; fitCFos.SSE];
fitTable.RSquared = [fitControl.RSquared; fitCFos.RSquared];

permTable = table;
permTable.ObservedControlSlope = permResult.ObservedGroupASlope;
permTable.ObservedCFosSlope = permResult.ObservedGroupBSlope;
permTable.ObservedDifference = permResult.ObservedDifference;
permTable.PermutationPValue = permResult.PValue;
permTable.PermutationCount = permResult.NPermutation;
permTable.NullMeanDifference = mean(permResult.PermutedDifference, 'omitnan');
permTable.NullStdDifference = std(permResult.PermutedDifference, 'omitnan');
permTable.NullCI_Low = prctile(permResult.PermutedDifference, 2.5);
permTable.NullCI_High = prctile(permResult.PermutedDifference, 97.5);

summaryTable = table;
summaryTable.Block = xFit(:);
summaryTable.ControlLearningCurve = meanMatOut(:,1);
summaryTable.CFosLearningCurve = meanMatOut(:,2);
summaryTable.ControlSem = semMatOut(:,1);
summaryTable.CFosSem = semMatOut(:,2);
summaryTable.ControlN = nMatOut(:,1);
summaryTable.CFosN = nMatOut(:,2);
summaryTable.ControlSigmoid = controlFitCurve(:);
summaryTable.CFosSigmoid = cfosFitCurve(:);

fprintf('Wrote: %s\n', svgPath);
fprintf('Mouse count: Control n = %d, cFos n = %d\n', nControlMice, nCFosMice);
fprintf('Control sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitControl.Lower, fitControl.Upper, fitControl.Slope, fitControl.Midpoint, fitControl.RSquared);
fprintf('cFos sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitCFos.Lower, fitCFos.Upper, fitCFos.Slope, fitCFos.Midpoint, fitCFos.RSquared);
fprintf('Permutation slope difference (cFos - Control): %.4f\n', permResult.ObservedDifference);
fprintf('Permutation significance p-value (two-sided) = %.4g (%d permutations)\n', permResult.PValue, permResult.NPermutation);

assignin('base', 'Fig334G_BlockSigmoid_AllSessions', allSessions);
assignin('base', 'Fig334G_BlockSigmoid_FitTable', fitTable);
assignin('base', 'Fig334G_BlockSigmoid_Summary', summaryTable);
assignin('base', 'Fig334G_BlockSigmoid_Permutation', permResult);

function sessions = iBuildLightWaterBlockSessions(dataset, groupOrder)
mouseGroup = iBuildMouseGroupTable(dataset, groupOrder);
blocks = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(dataset, false);
if isempty(blocks)
	sessions = iEmptySessionTable();
	return;
end
blocks.Mouse = string(blocks.Mouse);
blocks.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(blocks.DateTime);
joinedBlocks = innerjoin(blocks, mouseGroup(:, {'Mouse','Group'}), 'Keys', 'Mouse');
joinedBlocks.Group = string(joinedBlocks.Group);
joinedBlocks = joinedBlocks(ismember(joinedBlocks.Group, groupOrder), :);
if isempty(joinedBlocks)
	sessions = iEmptySessionTable();
	return;
end
vars = intersect(joinedBlocks.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
sessions = TransferLearning.BehaviorSessions.iSessionizeByDateTime(joinedBlocks(:, vars));
sessions = sortrows(sessions, {'Group','Mouse','DateTime'});
end

function mouseGroup = iBuildMouseGroupTable(dataset, groupOrder)
mouseGroup = dataset.Mice;
if isempty(mouseGroup)
	error('Fig334G:EmptyMiceTable', 'DS.Mice is empty.');
end
if ~ismember('Mouse', mouseGroup.Properties.VariableNames)
	if ~isempty(mouseGroup.Properties.RowNames)
		mouseGroup.Mouse = string(mouseGroup.Properties.RowNames);
	else
		error('Fig334G:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
needVars = ["ExpressedBrain","MarkTimes"];
for iVar = 1:numel(needVars)
	if ~ismember(needVars(iVar), string(mouseGroup.Properties.VariableNames))
		error('Fig334G:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(iVar));
	end
end
mouseGroup.Mouse = string(mouseGroup.Mouse);
mouseGroup.Group = string(mouseGroup.ExpressedBrain);
mouseGroup.Group(~logical(mouseGroup.MarkTimes)) = "Control";
badGroup = arrayfun(@(groupName) nnz(char(groupName) == ' ') > 1, mouseGroup.Group);
mouseGroup = mouseGroup(~badGroup, :);
mouseGroup = mouseGroup(ismember(mouseGroup.Group, groupOrder), :);
[~, firstRow] = unique(mouseGroup.Mouse, 'stable');
mouseGroup = mouseGroup(firstRow, :);
if isempty(mouseGroup)
	error('Fig334G:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end
end

function [meanMat, semMat, blockNumbers] = iUnpackLearningSummarize(summaryLearning, groupOrder)
groupOrder = string(groupOrder);
if ~istable(summaryLearning)
	if isstruct(summaryLearning)
		summaryLearning = struct2table(summaryLearning);
	else
		error('Fig334G:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
	end
end

meanCurve = summaryLearning.MeanCurve;
semCurve = summaryLearning.SemCurve;
meanCells = meanCurve(:);
semCells = semCurve(:);
if ~isempty(summaryLearning.Properties.RowNames)
	rowNames = string(summaryLearning.Properties.RowNames);
else
	rowNames = strings(numel(meanCells),1);
end

idx = nan(1, numel(groupOrder));
for iGroup = 1:numel(groupOrder)
	if all(rowNames == "")
		if iGroup <= numel(meanCells)
			idx(iGroup) = iGroup;
		end
	else
		matchRow = find(rowNames == groupOrder(iGroup), 1, 'first');
		if ~isempty(matchRow)
			idx(iGroup) = matchRow;
		end
	end
end

maxLen = 0;
for iGroup = 1:numel(groupOrder)
	if ~isfinite(idx(iGroup))
		continue;
	end
	meanValues = meanCells{idx(iGroup)};
	semValues = semCells{idx(iGroup)};
	maxLen = max(maxLen, max(numel(meanValues), numel(semValues)));
end
meanMat = nan(maxLen, numel(groupOrder));
semMat = nan(maxLen, numel(groupOrder));
for iGroup = 1:numel(groupOrder)
	if ~isfinite(idx(iGroup))
		continue;
	end
	meanValues = double(meanCells{idx(iGroup)}(:));
	semValues = double(semCells{idx(iGroup)}(:));
	meanMat(1:numel(meanValues), iGroup) = meanValues;
	semMat(1:numel(semValues), iGroup) = semValues;
end
blockNumbers = (1:maxLen).';
end

function nMat = iComputeNBySession(sessionTable, blockNumbers, groupOrder)
groupOrder = string(groupOrder);
blockNumbers = double(blockNumbers(:));
nMat = zeros(numel(blockNumbers), numel(groupOrder));
sessionTable.Group = string(sessionTable.Group);
sessionTable.Session = double(sessionTable.Session);
for iGroup = 1:numel(groupOrder)
	rowsGroup = sessionTable.Group == groupOrder(iGroup);
	for iBlock = 1:numel(blockNumbers)
		rowsBlock = rowsGroup & sessionTable.Session == blockNumbers(iBlock) & isfinite(double(sessionTable.Performance));
		if any(rowsBlock)
			nMat(iBlock, iGroup) = numel(unique(string(sessionTable.Mouse(rowsBlock))));
		end
	end
end
end

function sessionTable = iFilterToDisplayedMice(sessionTable)
if isempty(sessionTable)
	return;
end
rows = isfinite(double(sessionTable.Session)) & isfinite(double(sessionTable.Performance));
shownMice = unique(string(sessionTable.Mouse(rows)), 'stable');
sessionTable = sessionTable(ismember(string(sessionTable.Mouse), shownMice), :);
end

function hOut = iPlotGroupMeanErrorbarsSingleAx(axisHandle, xFit, meanCurve, semCurve, yFit, lineColor)
meanCurve = double(meanCurve);
semCurve = double(semCurve);
xObserved = find(isfinite(meanCurve));
meanObserved = meanCurve(xObserved);
semObserved = semCurve(xObserved);
semObserved(~isfinite(semObserved)) = 0;
hError = errorbar(axisHandle, xObserved, meanObserved, semObserved, 'o-', 'Color', lineColor, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', lineColor, 'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4);
hFit = plot(axisHandle, xFit, yFit, '-', 'Color', lineColor, 'LineWidth', 2.2);
hOut = [hError, hFit];
end

function fitOut = iFitSigmoidCurve(sessionTable, groupName)
sessionTable = sortrows(sessionTable, {'Mouse','DateTime'});
xObs = double(sessionTable.Session(:));
yObs = double(sessionTable.Performance(:));
useRows = isfinite(xObs) & isfinite(yObs);
xObs = xObs(useRows);
yObs = yObs(useRows);
if isempty(xObs)
	error('Fig334G:NoDataForGroup', 'No valid block/session data for group %s.', char(groupName));
end

p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); log(max(median(xObs), 1))];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
yHat = iSigmoidFromParams(p, xObs);
sse = sum((yObs - yHat).^2, 'omitnan');
sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if sst == 0
	rSquared = NaN;
else
	rSquared = 1 - sse / sst;
end
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.ParamRaw = p;
fitOut.Lower = lower;
fitOut.Upper = upper;
fitOut.Slope = slope;
fitOut.Midpoint = midpoint;
fitOut.SSE = sse;
fitOut.RSquared = rSquared;
fitOut.XObserved = xObs;
fitOut.YObserved = yObs;
end

function permOut = iPermutationTestSigmoidSlope(groupA, groupB, groupAName, groupBName, nPermutation, rngSeed)
if nargin < 5 || isempty(nPermutation)
	nPermutation = 2000;
end
if nargin >= 6 && ~isempty(rngSeed)
	rng(rngSeed);
end
groupA = sortrows(groupA, {'Mouse','DateTime'});
groupB = sortrows(groupB, {'Mouse','DateTime'});
miceA = unique(string(groupA.Mouse), 'stable');
miceB = unique(string(groupB.Mouse), 'stable');
allMouseTables = cell(numel(miceA) + numel(miceB), 1);
for iMouse = 1:numel(miceA)
	allMouseTables{iMouse} = groupA(string(groupA.Mouse) == miceA(iMouse), :);
end
for iMouse = 1:numel(miceB)
	allMouseTables{numel(miceA) + iMouse} = groupB(string(groupB.Mouse) == miceB(iMouse), :);
end
fitA = iFitSigmoidCurve(groupA, groupAName);
fitB = iFitSigmoidCurve(groupB, groupBName);
observedDiff = fitB.Slope - fitA.Slope;
permDiff = nan(nPermutation, 1);
nGroupA = numel(miceA);
parfor iPerm = 1:nPermutation
	order = randperm(numel(allMouseTables));
	idxA = order(1:nGroupA);
	idxB = order(nGroupA+1:end);
	permA = vertcat(allMouseTables{idxA});
	permB = vertcat(allMouseTables{idxB});
	fitPermA = iFitSigmoidCurve(permA, groupAName + "Perm");
	fitPermB = iFitSigmoidCurve(permB, groupBName + "Perm");
	permDiff(iPerm) = fitPermB.Slope - fitPermA.Slope;
end
pValue = mean(abs(permDiff) >= abs(observedDiff));
permOut = struct;
permOut.ObservedGroupASlope = fitA.Slope;
permOut.ObservedGroupBSlope = fitB.Slope;
permOut.ObservedDifference = observedDiff;
permOut.PermutedDifference = permDiff;
permOut.PValue = pValue;
permOut.NPermutation = nPermutation;
end

function y = iSigmoidFromParams(p, x)
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
lower = 1 ./ (1 + exp(-p(1)));
upper = 1;
slope = exp(p(2));
midpoint = exp(p(3));
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end

function sessions = iEmptySessionTable()
sessions = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Group','Mouse','DateTime','Performance','NBlocksInSession','Phase'});
end
