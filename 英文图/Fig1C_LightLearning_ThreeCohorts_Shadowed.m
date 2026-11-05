% English Fig1C: LightWater learning curves of three delay cohorts（7d / 12h / Naive），
% Fig32B 样式（mean±SEM 阴影带学习曲线）。
%
% 数据与分组同 英文图/Fig1B_LightLearning_ThreeCohorts_Sigmoid.m：
%   7d   = TransferLearning.Vacation7 光水（Transfer→Final 会话窗）
%   12h  = TransferLearning.ALDelayedBehavior 光水（LightLearnWater，*Always 不取）
%   Naive = TransferLearning.LADelayedBehavior 光水（LightLearnWater，*Always 不取）
%
% 样式（仿 中文图/Fig32B_LightWaterLearningCurveAndFirstSession.m）：
%   三组 mean±SEM 阴影带学习曲线（MultiShadowedLines）。
%
% Outputs (SVG):
%   - English_Fig1C_LightLearning_ThreeCohorts.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

% ---- 三组会话表（每鼠每会话一行，Performance=光水命中率）----
s7  = iLightSessionsBetweenPhases(TransferLearning.Vacation7(), "LightWater", "Transfer", "Final");
s12 = iLightSessions(TransferLearning.ALDelayedBehavior(), "LightLearnWater");
sN  = iLightSessions(TransferLearning.LADelayedBehavior(), "LightLearnWater");

s7.Group(:)  = "7d";
s12.Group(:) = "12h";
sN.Group(:)  = "Naive";

allSessions = [s7; s12; sN];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	error('Fig1C:EmptyData', 'No LightWater sessions found.');
end

allSessions = sortrows(allSessions, ["Group", "Mouse", "DateTime"]);
allSessions = iAddSessionIndex(allSessions);
summaryCurve = iSummarizeBySession(allSessions, ["12h", "7d", "Naive"]);
%%

groupNames = ["12h", "7d", "Naive"];
groupColors = TransferLearning.Colors3 ./ 255;

f = figure('Color', 'w', 'Name', 'English Fig1C light learning three cohorts shadowed');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
ax = axes(f);
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
hold(ax, 'on');

meanMat = nan(max(summaryCurve.Session), 3);
semMat = nan(max(summaryCurve.Session), 3);
for i = 1:3
	rows = summaryCurve.Group == groupNames(i);
	meanMat(summaryCurve.Session(rows), i) = summaryCurve.Mean(rows);
	semMat(summaryCurve.Session(rows), i) = summaryCurve.Sem(rows);
end
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=groupColors);
for p = patches(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 2;
	end
end

yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

labels = cellstr(groupNames);
if numel(patches) >= 3
	lg = legend(ax, patches(1:3), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(patches(1:3)));
else
	lg = legend(ax, labels, 'Location', 'best');
end
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '💡💧';
lg.Title.FontSize = 12;

xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig1C_LightLearning_ThreeCohorts.svg');
fprintf('Wrote: %s\n', svgPath);

summaryOut = table;
summaryOut.Block = (1:size(meanMat, 1))';
for i = 1:3
	summaryOut.(groupNames(i) + "Mean") = meanMat(:, i);
	summaryOut.(groupNames(i) + "Sem") = semMat(:, i);
end
assignin('base', 'Fig1C_ThreeCohorts_Raw', allSessions);
assignin('base', 'Fig1C_ThreeCohorts_Summary', summaryOut);

%% ========== local functions ==========

function S = iLightSessions(DS, stimulusName)
% 每鼠每会话一行：Performance = 指定刺激回合命中率均值（*Always 与 NaN 回合不取）
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == string(stimulusName) & isfinite(double(T.Behavior)), :);
if isempty(T)
	S = iEmptySessionTable();
	return;
end
[G, mu, dt] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Behavior, G);
S = table(mu, dt, perf, 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
end

function S = iLightSessionsBetweenPhases(DS, stimulusName, startPhase, endPhase)
% 同 iLightSessions，但每鼠只保留 startPhase 首个会话至 endPhase 首个会话的窗（同 Fig32B 口径）
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Phase", "Behavior"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T = T(T.Stimulus == string(stimulusName) & isfinite(double(T.Behavior)), :);
T = sortrows(T, {'Mouse', 'DateTime'});
keep = false(height(T), 1);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	r = find(T.Mouse == mice(i));
	ph = T.Phase(r);
	st = find(ph == string(startPhase), 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == string(endPhase) & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keep(r(st:ed)) = true;
end
T = T(keep, :);
if isempty(T)
	S = iEmptySessionTable();
	return;
end
[G, mu, dt] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Behavior, G);
S = table(mu, dt, perf, 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
end

function T = iEmptySessionTable()
T = table(string.empty(0, 1), NaT(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
end

function iAssertNoMouseAppearsInMultipleGroups(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
[G, mice] = findgroups(T.Mouse);
nGroups = splitapply(@(x) numel(unique(x)), T.Group, G);
dup = mice(nGroups > 1);
if ~isempty(dup)
	error('Fig1C:MouseInMultipleGroups', 'Some mice appear in multiple groups:\n%s', char(strjoin(dup, newline)));
end
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group', 'Mouse', 'DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

function summary = iSummarizeBySession(T, groupOrder)
groupOrder = string(groupOrder);
maxSession = max(double(T.Session), [], 'omitnan');
rows = cell(numel(groupOrder), 1);
for iGroup = 1:numel(groupOrder)
	groupName = groupOrder(iGroup);
	sessions = (1:maxSession).';
	meanValue = nan(numel(sessions), 1);
	semValue = nan(numel(sessions), 1);
	nMice = zeros(numel(sessions), 1);
	for iSession = 1:numel(sessions)
		use = T.Group == groupName & T.Session == sessions(iSession) & isfinite(double(T.Performance));
		values = double(T.Performance(use));
		nMice(iSession) = numel(unique(string(T.Mouse(use))));
		if isempty(values)
			continue;
		end
		meanValue(iSession) = mean(values, 'omitnan');
		if isscalar(values)
			semValue(iSession) = 0;
		else
			semValue(iSession) = std(values, 'omitnan') ./ sqrt(numel(values));
		end
	end
	rows{iGroup} = table(repmat(groupName, numel(sessions), 1), sessions, meanValue, semValue, nMice, ...
		'VariableNames', {'Group', 'Session', 'Mean', 'Sem', 'NMice'});
end
summary = vertcat(rows{:});
summary = summary(isfinite(summary.Mean), :);
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
nLines = size(meanMat, 2);
yCells = cell(1, nLines);
sCells = cell(1, nLines);
xCells = cell(1, nLines);
for j = 1:nLines
	y = meanMat(:, j);
	s = semMat(:, j);
	last = find(isfinite(y) & isfinite(s), 1, 'last');
	if isempty(last)
		yCells{j} = nan(0, 1);
		sCells{j} = nan(0, 1);
		xCells{j} = nan(0, 1);
	else
		yCells{j} = y(1:last);
		sCells{j} = s(1:last);
		xCells{j} = (1:last)';
	end
end
end
