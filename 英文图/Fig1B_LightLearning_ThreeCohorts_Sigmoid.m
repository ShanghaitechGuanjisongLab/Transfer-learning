% English Fig1B: LightWater learning curves of three delay cohorts（7d / 12h / Naive），Fig31B 样式。
%
% 数据（均取光水学习会话的命中率逐会话曲线）：
%   7d   = TransferLearning.Vacation7 光水（声水学习后等待 7 天再迁移，Transfer→Final 会话窗）
%   12h  = TransferLearning.ALDelayedBehavior 光水（L2A_A+L2A_L 内存合并库的 LightLearnWater，
%          声水学习后 ~12 h 迁移；*Always 给水回合不取）
%   Naive = TransferLearning.LADelayedBehavior 光水（A2L_A+A2L_L 内存合并库的 LightLearnWater，
%          光水为首学任务；*Always 给水回合不取）
%
% 样式（仿 中文图/Fig31B_LearningCurve_Combined.m）：逐会话 mean±SEM 空心圆点误差条
% + 每组 sigmoid 拟合线；图例仅显示三组散点，单列置于 southeast。
% 斜率为 log-odds/会话：概率空间的每会话最大命中率增量 = k/4（见 Fig1D 头注释）。
%
% Outputs (SVG):
%   - English_Fig1B_LightLearning_ThreeCohorts.svg
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

% ---- 1. 三组会话表（每鼠每会话一行，Performance=光水命中率）----
s7   = iLightSessionsBetweenPhases(TransferLearning.Vacation7(), "LightWater", "Transfer", "Final");
s12  = iLightSessions(TransferLearning.ALDelayedBehavior(), "LightLearnWater");
sN   = iLightSessions(TransferLearning.LADelayedBehavior(), "LightLearnWater");

s7.Group(:)   = "7d";
s12.Group(:)  = "12h";
sN.Group(:)   = "Naive";

allSessions = [s7; s12; sN];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	error('Fig1B:EmptyData', 'No LightWater sessions found.');
end

allSessions = sortrows(allSessions, ["Group", "Mouse", "DateTime"]);
allSessions = iAddSessionIndex(allSessions);
summaryCurve = iSummarizeBySession(allSessions, ["12h", "7d", "Naive"]);

fit7  = iFitSigmoidCurve(allSessions(allSessions.Group == "7d", :),   "7d");
fit12 = iFitSigmoidCurve(allSessions(allSessions.Group == "12h", :),  "12h");
fitN  = iFitSigmoidCurve(allSessions(allSessions.Group == "Naive", :), "Naive");
%%

groupNames = ["12h", "7d", "Naive"];
groupColors = TransferLearning.Colors3 ./ 255;

f = figure('Color', 'w', 'Name', 'English Fig1B light learning three cohorts sigmoid');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax, 'on');

xMax = max(summaryCurve.Session, [], 'omitnan');
xFit = linspace(1, xMax, 200).';
fits = {fit12, fit7, fitN};
hMean = gobjects(3, 1);
hFit = gobjects(3, 1);
for i = 1:3
	g = groupNames(i);
	rows = summaryCurve.Group == g;
	hMean(i) = errorbar(ax, summaryCurve.Session(rows), summaryCurve.Mean(rows), summaryCurve.Sem(rows), ...
		'o', 'Color', groupColors(i, :), 'MarkerFaceColor', 'w', 'MarkerEdgeColor', groupColors(i, :), ...
		'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');
	hFit(i) = plot(ax, xFit, iSigmoidFromParams(fits{i}.ParamRaw, xFit), '-', 'Color', groupColors(i, :), 'LineWidth', 2.2);
end

xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
box(ax, 'off');
grid(ax, 'off');
title(ax, '');

yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

lg = legend(ax, hMean, {'12h', '7d', 'Naive'}, ...
	'Location', 'southeast', 'NumColumns', 1);
lg.Box = 'off';
lg.FontSize = 10;

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig1B_LightLearning_ThreeCohorts.svg');

fitTable = table(["12h"; "7d"; "Naive"], [fit12.Slope; fit7.Slope; fitN.Slope], ...
	[fit12.Slope; fit7.Slope; fitN.Slope] / 4, [fit12.Midpoint; fit7.Midpoint; fitN.Midpoint], ...
	[fit12.RSquared; fit7.RSquared; fitN.RSquared], ...
	'VariableNames', {'Group', 'SlopeLogOdds', 'SlopeProbMax', 'Midpoint', 'RSquared'});
assignin('base', 'Fig1B_ThreeCohorts_Raw', allSessions);
assignin('base', 'Fig1B_ThreeCohorts_Summary', summaryCurve);
assignin('base', 'Fig1B_ThreeCohorts_Fit', fitTable);

fprintf('Wrote: %s\n', svgPath);
fprintf('=== Fig1B 12h/7d/Naive 光水学习曲线 ===\n');
for i = 1:3
	g = groupNames(i);
	sg = summaryCurve(summaryCurve.Group == g, :);
	fprintf('%-6s mice n=%d, sessions=%d\n', char(g), ...
		numel(unique(string(allSessions.Mouse(allSessions.Group == g)))), height(sg));
end
disp(fitTable);

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
	error('Fig1B:MouseInMultipleGroups', 'Some mice appear in multiple groups:\n%s', char(strjoin(dup, newline)));
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

function fitOut = iFitSigmoidCurve(T, groupName)
T = sortrows(T, {'Mouse', 'DateTime'});
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('Fig1B:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
end
p0 = [log(1); median(xObs, 'omitnan')];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
yHat = iSigmoidFromParams(p, xObs);
sse = sum((yObs - yHat).^2, 'omitnan');
sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if sst == 0
	rSquared = NaN;
else
	rSquared = 1 - sse ./ sst;
end
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.ParamRaw = p;
fitOut.Lower = 0;
fitOut.Upper = 1;
fitOut.Slope = exp(p(1));
fitOut.Midpoint = p(2);
fitOut.SSE = sse;
fitOut.RSquared = rSquared;
end

function y = iSigmoidFromParams(p, x)
slope = exp(p(1));
midpoint = p(2);
z = -slope .* (double(x) - midpoint);
z = max(min(z, 60), -60);
y = 1 ./ (1 + exp(z));
end
