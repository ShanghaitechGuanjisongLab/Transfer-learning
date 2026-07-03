% 中文图45D：cFos 与对照组首个训练单元分回合命中率曲线

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
groupLabels = ["Control", "cFos"];
edgeColors = [TransferLearning.ContinualColor;TransferLearning.ColorA];

trialRows = iBuildFirstTrainingUnitTrials(dataset, groupOrder);
if isempty(trialRows)
	error('Fig45D:EmptyTrials', 'No first training-unit LightWater trials found.');
end
trialRows = sortrows(trialRows, ["Group", "Mouse", "DateTime", "Trial"]);
nControlMice = numel(unique(string(trialRows.Mouse(trialRows.Group == groupOrder(1)))));
nCFosMice = numel(unique(string(trialRows.Mouse(trialRows.Group == groupOrder(2)))));

[meanMat, semMat, trialNumbers, nMat] = iSummarizeTrialCurve(trialRows, groupOrder);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(trialRows, 'Behavior', 'Trial', 'Group', 'Mouse');
trials7 = trialRows(trialRows.Trial <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(trials7, 'Behavior', 'Trial', 'Group', 'Mouse');
curveP = iLearningCurvePValue(trialRows, groupOrder);
%% 

fig = figure('Color','w', 'Name', 'Fig45D cFos first training-unit trial curve');
fig.Units = 'centimeters';
fig.Position(3:4) = [9, 8];
axisHandle = axes(fig);
hold(axisHandle, 'on');
axisHandle.FontSize = 12;
axisHandle.LineWidth = 2;
if isprop(axisHandle.XAxis, 'LineWidth')
	axisHandle.XAxis.LineWidth = 2;
	axisHandle.YAxis.LineWidth = 2;
end

[meanCells, semCells, trialCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, X=trialCells, EdgeColors=edgeColors(1:2,:));
for patchObj = patches(:)'
	if isprop(patchObj, 'LineWidth')
		patchObj.LineWidth = 2;
	end
end

xlabel(axisHandle, 'Trial', 'FontSize', 12);
ylabel(axisHandle, 'Hit rate', 'FontSize', 12);

% Horizontal P-value line spanning trials 1-7
max7Ctrl = max(meanMat(1:min(7, end), 1), [], 'omitnan');
max7CFos = max(meanMat(1:min(7, end), 2), [], 'omitnan');
max7SemCtrl = semMat(find(meanMat(1:min(7,end),1)==max7Ctrl,1,'first'),1);
max7SemCFos = semMat(find(meanMat(1:min(7,end),2)==max7CFos,1,'first'),2);
yTop7 = max(max7Ctrl + max7SemCtrl, max7CFos + max7SemCFos);
yl = ylim(axisHandle); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(axisHandle, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
if groupP7 < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP7); end
text(axisHandle, 6, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);
yt = yticks(axisHandle);
yticks(axisHandle, yt(yt <= 1 + 1e-6));

if numel(patches) >= 2
	legendHandle = legend(axisHandle, patches(1:2), cellstr(groupLabels), 'Location', 'southeastoutside');
else
	legendHandle = legend(axisHandle, cellstr(groupLabels), 'Location', 'southeastoutside');
end
legendHandle.FontSize = 12;
legendHandle.Box = 'off';
legendHandle.Title.String = '💡💧';
legendHandle.Title.FontSize = 12;

box(axisHandle, 'off');
grid(axisHandle, 'off');
if isprop(axisHandle, 'Toolbar') && ~isempty(axisHandle.Toolbar)
	axisHandle.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(fig, 2, '中文图Fig45D_cFos_FirstTrainingUnitTrialCurve.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Two-way ANOVA Group P (all trials) = %.4g\n', groupP);
fprintf('Two-way ANOVA Group P (trials 1-7) = %.4g\n', groupP7);
fprintf('Fig45D mice: Control n = %d, cFos n = %d\n', nControlMice, nCFosMice);
fprintf('Fig45D trial curve mixed-effect p = %.4g\n', curveP);

summaryCurve = table;
summaryCurve.Trial = trialNumbers(:);
summaryCurve.ControlMean = meanMat(:,1);
summaryCurve.CFosMean = meanMat(:,2);
summaryCurve.ControlSem = semMat(:,1);
summaryCurve.CFosSem = semMat(:,2);
summaryCurve.ControlN = nMat(:,1);
summaryCurve.CFosN = nMat(:,2);
summaryCurve.PMixedEffect(:) = curveP;

assignin('base', 'Fig334F_FirstTrainingUnitTrial_Raw', trialRows);
assignin('base', 'Fig334F_FirstTrainingUnitTrial_Summary', summaryCurve);

function trialRows = iBuildFirstTrainingUnitTrials(dataset, groupOrder)
mouseGroup = iBuildMouseGroupTable(dataset, groupOrder);
trialTable = dataset.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialIndex"], Stimulus="LightWater");
if isempty(trialTable)
	trialRows = iEmptyTrialTable();
	return;
end
trialTable.Mouse = string(trialTable.Mouse);
trialTable.Stimulus = string(trialTable.Stimulus);
trialTable.Phase = string(trialTable.Phase);
trialTable.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(trialTable.DateTime);
trialTable.Behavior = double(trialTable.Behavior);
trialTable.TrialIndex = double(trialTable.TrialIndex);
trialTable = trialTable(trialTable.Stimulus == "LightWater", :);

joinedTrials = innerjoin(trialTable, mouseGroup(:, {'Mouse','Group'}), 'Keys', 'Mouse');
joinedTrials.Group = string(joinedTrials.Group);
joinedTrials = joinedTrials(ismember(joinedTrials.Group, groupOrder), :);
if isempty(joinedTrials)
	trialRows = iEmptyTrialTable();
	return;
end

sessions = TransferLearning.BehaviorSessions.iSessionizeByDateTime(joinedTrials(:, {'Mouse','DateTime','Behavior','Group','Phase'}));
sessions = sortrows(sessions, {'Group','Mouse','DateTime'});
sessions = TransferLearning.BehaviorSessions.iAddSessionIndex(sessions);
firstSessions = sessions(sessions.Session == 1, {'Mouse','DateTime','Group'});

trialRows = innerjoin(joinedTrials(:, {'Mouse','DateTime','Behavior','TrialIndex','Group'}), firstSessions, 'Keys', {'Mouse','DateTime','Group'});
trialRows = sortrows(trialRows, {'Group','Mouse','DateTime','TrialIndex'});
trialRows.Trial = iTrialNumberWithinSession(trialRows);
trialRows = trialRows(:, {'Mouse','DateTime','Behavior','TrialIndex','Trial','Group'});
end

function mouseGroup = iBuildMouseGroupTable(dataset, groupOrder)
mouseGroup = dataset.Mice;
if isempty(mouseGroup)
	error('Fig334F:EmptyMiceTable', 'DS.Mice is empty.');
end
if ~ismember('Mouse', mouseGroup.Properties.VariableNames)
	if ~isempty(mouseGroup.Properties.RowNames)
		mouseGroup.Mouse = string(mouseGroup.Properties.RowNames);
	else
		error('Fig334F:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
needVars = ["ExpressedBrain","MarkTimes"];
for iVar = 1:numel(needVars)
	if ~ismember(needVars(iVar), string(mouseGroup.Properties.VariableNames))
		error('Fig334F:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(iVar));
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
	error('Fig334F:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end
end

function trialNumber = iTrialNumberWithinSession(trialRows)
[groupNumber, ~] = findgroups(trialRows.Group, trialRows.Mouse, trialRows.DateTime);
trialCell = splitapply(@(trialIndex) {(1:numel(trialIndex))'}, trialRows.TrialIndex, groupNumber);
trialNumber = vertcat(trialCell{:});
end

function [meanMat, semMat, trialNumbers, nMat] = iSummarizeTrialCurve(trialRows, groupOrder)
groupOrder = string(groupOrder);
maxTrial = max(double(trialRows.Trial), [], 'omitnan');
trialNumbers = (1:maxTrial).';
meanMat = nan(maxTrial, numel(groupOrder));
semMat = nan(maxTrial, numel(groupOrder));
nMat = zeros(maxTrial, numel(groupOrder));
for iGroup = 1:numel(groupOrder)
	for iTrial = 1:maxTrial
		useRows = trialRows.Group == groupOrder(iGroup) & double(trialRows.Trial) == iTrial;
		values = double(trialRows.Behavior(useRows));
		values = values(isfinite(values));
		if isempty(values)
			continue;
		end
		meanMat(iTrial, iGroup) = mean(values);
		semMat(iTrial, iGroup) = std(values) / sqrt(numel(values));
		nMat(iTrial, iGroup) = numel(unique(string(trialRows.Mouse(useRows))));
	end
end
end

function pValue = iLearningCurvePValue(trialRows, groupOrder)
pValue = NaN;
useRows = isfinite(double(trialRows.Behavior)) & isfinite(double(trialRows.Trial));
if nnz(useRows) < 10
	return;
end
modelTable = table(double(trialRows.Behavior(useRows)), double(trialRows.Trial(useRows)), categorical(string(trialRows.Group(useRows)), groupOrder), categorical(string(trialRows.Mouse(useRows))), ...
	'VariableNames', {'Behavior','Trial','Group','Mouse'});
model = fitlme(modelTable, 'Behavior ~ Trial*Group + (1|Mouse)');
anovaTable = anova(model);
groupRow = find(string(anovaTable.Term) == "Group", 1, 'first');
interactionRow = find(string(anovaTable.Term) == "Trial:Group", 1, 'first');
if ~isempty(groupRow)
	pValue = anovaTable.pValue(groupRow);
end
if ~isfinite(pValue) && ~isempty(interactionRow)
	pValue = anovaTable.pValue(interactionRow);
end
end

function [meanCells, semCells, trialCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
nLines = size(meanMat, 2);
meanCells = cell(1, nLines);
semCells = cell(1, nLines);
trialCells = cell(1, nLines);
for iLine = 1:nLines
	meanValues = meanMat(:, iLine);
	semValues = semMat(:, iLine);
	lastValid = find(isfinite(meanValues) & isfinite(semValues), 1, 'last');
	if isempty(lastValid)
		meanCells{iLine} = nan(0,1);
		semCells{iLine} = nan(0,1);
		trialCells{iLine} = nan(0,1);
	else
		meanCells{iLine} = meanValues(1:lastValid);
		semCells{iLine} = semValues(1:lastValid);
		trialCells{iLine} = (1:lastValid).';
	end
end
end

function trialRows = iEmptyTrialTable()
trialRows = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
	'VariableNames', {'Mouse','DateTime','Behavior','TrialIndex','Trial','Group'});
end