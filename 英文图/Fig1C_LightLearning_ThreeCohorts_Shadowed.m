% English Fig1C: LightWater learning curves of three delay cohorts（7d / 12h / Naive），
% Fig32B 样式（mean±SEM 阴影带 + 首块命中率条形图）。
%
% 数据与分组同 英文图/Fig1B_LightLearning_ThreeCohorts_Sigmoid.m：
%   7d   = TransferLearning.Vacation7 光水（Transfer→Final 会话窗）
%   12h  = TransferLearning.ALDelayedBehavior 光水（LightLearnWater，*Always 不取）
%   Naive = TransferLearning.LADelayedBehavior 光水（LightLearnWater，*Always 不取）
%
% 样式（仿 中文图/Fig32B_LightWaterLearningCurveAndFirstSession.m）：
%   图1：三组 mean±SEM 阴影带学习曲线（MultiShadowedLines），blocks 1-7 上方横线+显著性；
%   图2：首块命中率条形图（BarScatterCompare 三组两两比较，星号阈 1 同模板），X 轴隐藏。
% 统计口径（2026-09-13 用户裁定）：组间差异只引 blocks 1-7 线性混合模型 Group 效应 p；
% 不做斜率置换检验。
%
% Outputs (SVG):
%   - English_Fig1C_LightLearning_ThreeCohorts.svg
%   - English_Fig1C_LightLearning_FirstBlock.svg
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
summaryCurve = iSummarizeBySession(allSessions, ["7d", "12h", "Naive"]);

groupP  = TransferLearning.Style.TwoWayAnovaGroupPValue(allSessions, 'Performance', 'Session', 'Group', 'Mouse');
sessions7 = allSessions(allSessions.Session <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Session', 'Group', 'Mouse');
%%

groupNames = ["7d", "12h", "Naive"];
groupColors = [TransferLearning.ColorB; TransferLearning.TransferColor; TransferLearning.NaiveColor];

f = figure('Color', 'w', 'Name', 'English Fig1C light learning three cohorts shadowed');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
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

% Horizontal P-value line spanning blocks 1-7（口径：blocks 1-7 LMM Group 效应 p）
yTop7 = 0;
for i = 1:3
	yTop7 = max(yTop7, max(meanMat(1:min(7, end), i) + semMat(1:min(7, end), i), [], 'omitnan'));
end
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
if groupP7 < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP7); end
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', FontName='Arial');
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
fprintf('LMM Group P (all blocks) = %.4g\n', groupP);
fprintf('LMM Group P (blocks 1-7) = %.4g\n', groupP7);

summaryOut = table;
summaryOut.Block = (1:size(meanMat, 1))';
for i = 1:3
	summaryOut.(groupNames(i) + "Mean") = meanMat(:, i);
	summaryOut.(groupNames(i) + "Sem") = semMat(:, i);
end
assignin('base', 'Fig1C_ThreeCohorts_Raw', allSessions);
assignin('base', 'Fig1C_ThreeCohorts_Summary', summaryOut);

%% ---- 2. 首块命中率条形图（Fig32B 样式）----
firstSess = allSessions(allSessions.Session == 1, :);
first7  = double(firstSess.Performance(string(firstSess.Group) == "7d"));   first7  = first7(isfinite(first7));
first12 = double(firstSess.Performance(string(firstSess.Group) == "12h"));  first12 = first12(isfinite(first12));
firstN  = double(firstSess.Performance(string(firstSess.Group) == "Naive")); firstN  = firstN(isfinite(firstN));
%%

f2 = figure('Color', 'none', 'Name', 'English Fig1C light first-block performance');
f2.Units = 'centimeters';
pos2 = f2.Position;
% 模板 Fig32B 为 4×3 cm（仅 1 对比较）；本图为 3 组 3 对比较，P 値线需堆叠三层，
% 故同宽加高到 4.5×4.5 cm，避免柱子被压缩成矮胖。
pos2(3:4) = [4.5, 4.5];
f2.Position = pos2;
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4.5, 4.5];
f2.PaperPositionMode = 'auto';

tiledlayout(1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
nexttile;
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare({first7, first12, firstN}, ...
	table([1 2; 1 3; 2 3], 'VariableNames', {'GroupPair'}), 'AsteriskThreshold', 1);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
ax2.FontSize = 12;
ax2.LineWidth = 2;
if isprop(ax2.XAxis, 'LineWidth')
	ax2.XAxis.LineWidth = 2;
	ax2.YAxis.LineWidth = 2;
end
ax2.Color = 'none';
ax2.XAxis.Visible = 'off';
legend(ax2, 'off');
if isfield(optional2, 'MultiCompare') && ismember('PLine', optional2.MultiCompare.Properties.VariableNames)
	for pl = optional2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
		pl.Tag = 'PLine';
	end
end
if isfield(optional2, 'MultiCompare') && ismember('PText', optional2.MultiCompare.Properties.VariableNames)
	for pt = optional2.MultiCompare.PText(:)'
		pt.Tag = 'PText';
	end
end
TransferLearning.Style.SetBarPValues(optional2);
iStyleBars(bars2, groupColors);
iStyleErrorBars(errorBars2, groupColors);
ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');
% 三对 P 値线手动错落排布在柱顶上方（同旧 Fig1B 教训：PLineRetune 不会把线下移，
% 初始位置决定最终布局；排好后即使 retune 提前返回也不受影响）。
% 层级分配：跨度最宽的 (1,3) 放最高，(1,2) 最低、(2,3) 中间。
yTopBar = max([mean(first7) + std(first7)/sqrt(numel(first7)), ...
	mean(first12) + std(first12)/sqrt(numel(first12)), ...
	mean(firstN) + std(firstN)/sqrt(numel(firstN))], [], 'omitnan');
mc = optional2.MultiCompare;
levelFor = [1 3 2];   % MultiCompare 行序 [(1,2);(1,3);(2,3)] → 层级低/高/中
levels = yTopBar * [1.15, 1.55, 1.95];
for r = 1:height(mc)
	lv = levels(levelFor(r));
	mc.PLine(r).YData(:) = lv;
	mc.PText(r).Position(1) = mean(double(mc.PLine(r).XData));
	mc.PText(r).Position(2) = lv + 0.02 * yTopBar;
end
ax2.YLim = [0, yTopBar * 2.35];
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end
svgPath2 = TransferLearning.ExportStandardFigureTransparent(f2, 2, 'English_Fig1C_LightLearning_FirstBlock.svg');
fprintf('Wrote: %s\n', svgPath2);

fprintf('\n=== Fig1C first-block bar ===\n');
fprintf('7d n=%d, 12h n=%d, Naive n=%d\n', numel(first7), numel(first12), numel(firstN));
if isfield(optional2, 'MultiCompare') && ismember('PValue', optional2.MultiCompare.Properties.VariableNames)
	for r = 1:height(optional2.MultiCompare)
		fprintf('First-block P (%s): %s\n', mat2str(optional2.MultiCompare.GroupPair(r, :)), ...
			TransferLearning.Style.iFormatPText(optional2.MultiCompare.PValue(r)));
	end
end

firstTable = table;
nFirst = max([numel(first7), numel(first12), numel(firstN)]);
firstTable.First7d = nan(nFirst, 1);
firstTable.First7d(1:numel(first7)) = first7(:);
firstTable.First12h = nan(nFirst, 1);
firstTable.First12h(1:numel(first12)) = first12(:);
firstTable.FirstNaive = nan(nFirst, 1);
firstTable.FirstNaive(1:numel(firstN)) = firstN(:);
assignin('base', 'Fig1C_FirstBlock', firstTable);

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

function iStyleBars(barsObj, colors)
if isscalar(barsObj)
	barsObj.FaceColor = 'flat';
	nBars = numel(barsObj.YData);
	cData = nan(nBars, 3);
	for k = 1:nBars
		cData(k, :) = colors(min(k, size(colors, 1)), :);
	end
	barsObj.CData = cData;
	barsObj.BarWidth = 0.5;
	barsObj.LineWidth = 2;
	barsObj.BaseLine.LineWidth = 1;
	barsObj.EdgeColor = 'none';
	barsObj.FaceAlpha = 1;
else
	for k = 1:numel(barsObj)
		barsObj(k).FaceColor = colors(min(k, size(colors, 1)), :);
		barsObj(k).BarWidth = 0.5;
		barsObj(k).LineWidth = 2;
		barsObj(k).BaseLine.LineWidth = 2;
		barsObj(k).EdgeColor = 'none';
		barsObj(k).FaceAlpha = 1;
	end
end
end

function iStyleErrorBars(errorBars, colors)
for iE = 1:height(errorBars)
	errorBar = errorBars.Object(iE);
	errorBar.LineWidth = 2;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1))' - x(1)));
	errorBar.Color = colors(colorIndex, :);
end
end
