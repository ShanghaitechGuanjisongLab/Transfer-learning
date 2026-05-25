% English Fig3J: cFos vs Control sigmoid learning curves
%
% Mouse inclusion follows Chinese Fig334G exactly:
% - dataset: cFos合集.v2.mat
% - groups: Control vs MOp
% - displayed mice: same filtering as Fig334G
%
% Plot style follows English Fig3O by using
% TransferLearning.PlotSigmoidLearningCurvePanels.

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "English_Fig3J_cFosVsCtrl_SigmoidCurve.svg";

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

datasetPath = "\\Data-Server-2\个人数据\张天夫\202601\cFos合集.v2.mat";
dataset = UniExp.DataSet(datasetPath);

groupOrder = ["Control", "MOp"];
displayGroup = ["Control", "cFos"];

allSessions = iBuildLightWaterBlockSessions(dataset, groupOrder);
if isempty(allSessions)
	error('English_Fig3J:EmptySessions', 'No LightWater block/session data found.');
end
allSessions = sortrows(allSessions, ["Group", "Mouse", "DateTime"]);
allSessions = iAddSessionIndex(allSessions);

displayedControl = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == groupOrder(1), :));
displayedCFos = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == groupOrder(2), :));

barSessions = [displayedControl; displayedCFos];
barSessions = sortrows(barSessions, {'Group', 'Mouse', 'DateTime'});
barSessions = iAddSessionIndex(barSessions);

ctrlSessions = barSessions(barSessions.Group == groupOrder(1), :);
cfosSessions = barSessions(barSessions.Group == groupOrder(2), :);
if isempty(ctrlSessions) || isempty(cfosSessions)
	error('English_Fig3J:MissingGroup', 'One or both groups are empty after displayed-mouse filtering.');
end

ctrlPerf = iSessionTableToMatrix(ctrlSessions);
cfosPerf = iSessionTableToMatrix(cfosSessions);
if isempty(ctrlPerf) || isempty(cfosPerf)
	error('English_Fig3J:EmptyMatrix', 'One or both sigmoid matrices are empty.');
end

[fig, stats] = TransferLearning.PlotSigmoidLearningCurvePanels( ...
	ctrlPerf, cfosPerf, displayGroup(1), displayGroup(2), displayGroup(1), displayGroup(2), ...
	FigureName="English Fig3J cFos vs Control sigmoid", ...
	FigureSizeCm=[9, 8], ...
	Scale=2, ...
	CurveColor=[0, 0, 0], ...
	ShowLegend=true, ...
	LegendPanel="B", ...
	NPermutation=10000, ...
	RngSeed=1);

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);

fprintf('Wrote: %s\n', svgPath);
fprintf('Control sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f\n', ...
	stats.FitA.Lower, stats.FitA.Upper, stats.FitA.Slope, stats.FitA.Midpoint);
fprintf('cFos sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f\n', ...
	stats.FitB.Lower, stats.FitB.Upper, stats.FitB.Slope, stats.FitB.Midpoint);
fprintf('Permutation slope difference p = %.4g\n', stats.ComparisonTable.PValueTwoSided(1));

assignin('base', 'English_Fig3J_AllSessions', allSessions);
assignin('base', 'English_Fig3J_DisplayedControl', displayedControl);
assignin('base', 'English_Fig3J_DisplayedCFos', displayedCFos);
assignin('base', 'English_Fig3J_BarSessions', barSessions);
assignin('base', 'English_Fig3J_ControlPerfMatrix', ctrlPerf);
assignin('base', 'English_Fig3J_CFosPerfMatrix', cfosPerf);
assignin('base', 'English_Fig3J_SigmoidStats', stats);

function sessions = iBuildLightWaterBlockSessions(dataset, groupOrder)
mouseGroup = iBuildMouseGroupTable(dataset, groupOrder);
blocks = iQueryLightWaterBlocks(dataset);
if isempty(blocks)
	sessions = iEmptySessionTable();
	return;
end
blocks.Mouse = string(blocks.Mouse);
blocks.DateTime = iNormalizeDateTime(blocks.DateTime);
joinedBlocks = innerjoin(blocks, mouseGroup(:, {'Mouse', 'Group'}), 'Keys', 'Mouse');
joinedBlocks.Group = string(joinedBlocks.Group);
joinedBlocks = joinedBlocks(ismember(joinedBlocks.Group, groupOrder), :);
if isempty(joinedBlocks)
	sessions = iEmptySessionTable();
	return;
end
vars = intersect(joinedBlocks.Properties.VariableNames, {'Mouse', 'DateTime', 'Behavior', 'Performance', 'Group', 'Phase'}, 'stable');
sessions = iSessionizeByDateTime(joinedBlocks(:, vars));
sessions = sortrows(sessions, {'Group', 'Mouse', 'DateTime'});
end

function mouseGroup = iBuildMouseGroupTable(dataset, groupOrder)
mouseGroup = dataset.Mice;
if isempty(mouseGroup)
	error('English_Fig3J:EmptyMiceTable', 'DS.Mice is empty.');
end
if ~ismember('Mouse', mouseGroup.Properties.VariableNames)
	if ~isempty(mouseGroup.Properties.RowNames)
		mouseGroup.Mouse = string(mouseGroup.Properties.RowNames);
	else
		error('English_Fig3J:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
needVars = ["ExpressedBrain", "MarkTimes"];
for varIndex = 1:numel(needVars)
	if ~ismember(needVars(varIndex), string(mouseGroup.Properties.VariableNames))
		error('English_Fig3J:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(varIndex));
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
	error('English_Fig3J:EmptyGroups', 'No mice left after filtering to Control/MOp.');
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

function perfMatrix = iSessionTableToMatrix(sessionTable)
sessionTable = sortrows(sessionTable, {'Mouse', 'Session'});
mice = unique(string(sessionTable.Mouse), 'stable');
maxSession = max(double(sessionTable.Session), [], 'omitnan');
perfMatrix = nan(numel(mice), maxSession);
for mouseIndex = 1:numel(mice)
	rows = string(sessionTable.Mouse) == mice(mouseIndex);
	sessIdx = double(sessionTable.Session(rows));
	perf = double(sessionTable.Performance(rows));
	valid = isfinite(sessIdx) & sessIdx >= 1 & isfinite(perf);
	perfMatrix(mouseIndex, sessIdx(valid)) = perf(valid);
	end
end

function T = iQueryLightWaterBlocks(dataset)
varsTry = ["Mouse", "DateTime", "Stimulus", "Phase", "Behavior"];
varsFallback = ["Mouse", "DateTime", "Stimulus", "Phase", "Performance"];
try
	T = dataset.TableQuery(varsTry, Stimulus="LightWater");
catch
	T = dataset.TableQuery(varsFallback, Stimulus="LightWater");
end
if isempty(T)
	return;
end
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "LightWater", :);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function sessionTable = iSessionizeByDateTime(T)
useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
if ~ismember('Phase', T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
if useBehavior
	T = T(:, {'Mouse', 'DateTime', 'Behavior', 'Phase', 'Group'});
else
	T = T(:, {'Mouse', 'DateTime', 'Performance', 'Phase', 'Group'});
end
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group', 'Mouse', 'DateTime'});
if useBehavior
	perf = double(T.Behavior);
else
	perf = double(T.Performance);
end
[groupIndex, groupNames, mouseNames, dateTimes] = findgroups(T.Group, T.Mouse, T.DateTime);
meanPerf = splitapply(@(x) mean(x, 'omitnan'), perf, groupIndex);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), groupIndex);
sessionTable = table(groupNames, mouseNames, dateTimes, meanPerf, phaseSession, 'VariableNames', {'Group', 'Mouse', 'DateTime', 'Performance', 'Phase'});
end

function phaseName = iPickSessionPhase(phases)
phases = string(phases);
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	phaseName = "";
	return;
end
[uniquePhases, ~, phaseIndex] = unique(phases);
counts = accumarray(phaseIndex, 1);
[~, maxIndex] = max(counts);
phaseName = uniquePhases(maxIndex);
end

function T = iAddSessionIndex(T)
T.Group = string(T.Group);
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group', 'Mouse', 'DateTime'});
[groupIndex, ~] = findgroups(T.Group, T.Mouse);
sessionCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, groupIndex);
T.Session = vertcat(sessionCell{:});
end

function sessions = iEmptySessionTable()
sessions = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Group', 'Mouse', 'DateTime', 'Performance', 'NBlocksInSession', 'Phase'});
end