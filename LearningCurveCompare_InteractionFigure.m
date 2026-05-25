% LearningCurveCompare_InteractionFigure
%
% Companion script for LearningCurveCompare.m
% 从同目录下的 LearningCurveCompare_SessionTable.csv 读取 session-level 数据，
% 生成一张更便于解释交互项显著性的 SVG 图：
% - 上面板：Control vs TH inhibited 学习曲线（mean +- SEM）
% - 下面板：TH - Control 的逐 block 差值曲线（descriptive only）
%
% 输出目录：\\Data-Server-2\个人数据\杨青宁\202604\
% 输出文件：LearningCurveCompare_InteractionFigure.svg

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202604\';
sessionCsvName = 'LearningCurveCompare_SessionTable.csv';
svgName = 'LearningCurveCompare_InteractionFigure.svg';

%% --- 0) Ensure project loaded
try
	if ~exist('TransferLearning', 'class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, 'Transferlearning.prj');
		if exist(prjFile, 'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

%% --- 1) Load prior session table
sessionCsvPath = fullfile(outDirUNC, sessionCsvName);
if ~exist(sessionCsvPath, 'file')
	error('LearningCurveCompare:MissingSessionCsv', 'Missing session CSV: %s. Run LearningCurveCompare.m first.', sessionCsvPath);
end

Sess = readtable(sessionCsvPath, TextType='string');
requiredVars = {'Mouse','DateTime','Performance','Group','Session'};
if ~all(ismember(requiredVars, Sess.Properties.VariableNames))
	error('LearningCurveCompare:BadSessionCsv', 'Session CSV is missing required columns.');
end

Sess.Mouse = string(Sess.Mouse);
Sess.Group = string(Sess.Group);
if ~isdatetime(Sess.DateTime)
	try
		Sess.DateTime = datetime(Sess.DateTime);
	catch
	end
end
Sess.Performance = double(Sess.Performance);
Sess.Session = double(Sess.Session);
Sess = sortrows(Sess, {'Group','Mouse','Session','DateTime'});

%% --- 2) Refit the same mixed-effects model for annotation
lmeTbl = table;
lmeTbl.Performance = double(Sess.Performance);
lmeTbl.Block = double(Sess.Session);
lmeTbl.Group = categorical(string(Sess.Group), ["Ctrl", "TH"], ["Control", "TH inhibited"]);
lmeTbl.Mouse = categorical(string(Sess.Mouse));

use = isfinite(lmeTbl.Performance) & isfinite(lmeTbl.Block) & ~isundefined(lmeTbl.Group) & ~isundefined(lmeTbl.Mouse);
lmeTbl = lmeTbl(use, :);

modelFormula = 'Performance ~ 1 + Block*Group + (1|Mouse)';
lme = fitlme(lmeTbl, modelFormula);
A = anova(lme);
pGroup = iGetAnovaP(A, "Group");
pInteraction = iGetAnovaP(A, "Block:Group");

firstBlock = Sess(double(Sess.Session) == 1, :);
xCtrl = double(firstBlock.Performance(firstBlock.Group == "Ctrl"));
xTH = double(firstBlock.Performance(firstBlock.Group == "TH"));
[pFirstBlock, ~] = iRanksumSafe(xCtrl, xTH);

%% --- 3) Build summary curves and delta curve
summaryTbl = iBuildCurveSummary(Sess, ["Ctrl", "TH"], ["Control", "TH inhibited"]);
[meanMat, semMat, x] = iBuildMeanSemMatrices(summaryTbl, ["Control", "TH inhibited"]);
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat, x);

deltaMean = meanMat(:, 2) - meanMat(:, 1);
deltaSem = sqrt(semMat(:, 1).^2 + semMat(:, 2).^2);
okDelta = isfinite(deltaMean) & isfinite(deltaSem) & isfinite(x);

%% --- 4) Plot
f = figure('Color', 'w', 'Name', 'LearningCurveCompare Interaction Figure');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8.4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8.4];
f.PaperSize = [9, 8.4];

layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
palette2 = TransferLearning.FigurePalette(2);

ax1 = nexttile(layout, 1);
hold(ax1, 'on');
patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=palette2(1:2,:));
ax1.FontSize = 12;
ax1.LineWidth = 2;
ylabel(ax1, 'Hit rate', 'FontSize', 12);
xlabel(ax1, 'Block', 'FontSize', 12);
ylim(ax1, [0 1]);
xlim(ax1, [min(x)-0.2, max(x)+0.4]);
box(ax1, 'off');
grid(ax1, 'off');
title(ax1, 'Learning trajectory differs despite similar first block', 'FontSize', 12, 'FontWeight', 'normal');
legend(ax1, patches(1:2), {'Control', 'TH inhibited'}, 'Location', 'southeast');

txt = sprintf('First block p = %.3g\nGroup p = %.3g\nBlock x Group p = %.3g', pFirstBlock, pGroup, pInteraction);
text(ax1, max(x)-2.6, 0.18, txt, 'FontSize', 10, 'VerticalAlignment', 'bottom', 'BackgroundColor', 'w', 'Margin', 4);

ax2 = nexttile(layout, 2);
hold(ax2, 'on');
fillX = [x(okDelta); flipud(x(okDelta))];
fillY = [deltaMean(okDelta) + deltaSem(okDelta); flipud(deltaMean(okDelta) - deltaSem(okDelta))];
patch(ax2, fillX, fillY, palette2(2,:), 'FaceAlpha', 0.20, 'EdgeColor', 'none');
plot(ax2, x(okDelta), deltaMean(okDelta), 'Color', palette2(2,:), 'LineWidth', 2.5);
yline(ax2, 0, 'k:', 'LineWidth', 1.5);
ax2.FontSize = 12;
ax2.LineWidth = 2;
xlabel(ax2, 'Block', 'FontSize', 12);
ylabel(ax2, 'TH - Ctrl', 'FontSize', 12);
box(ax2, 'off');
grid(ax2, 'off');
xlim(ax2, [min(x)-0.2, max(x)+0.4]);

try
	if isprop(ax1, 'Toolbar') && ~isempty(ax1.Toolbar), ax1.Toolbar.Visible = 'off'; end
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar), ax2.Toolbar.Visible = 'off'; end
catch
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'LearningCurveCompare_InteractionFigure_Summary', summaryTbl);
assignin('base', 'LearningCurveCompare_InteractionFigure_LME', lme);
assignin('base', 'LearningCurveCompare_InteractionFigure_PGroup', pGroup);
assignin('base', 'LearningCurveCompare_InteractionFigure_PInteraction', pInteraction);
assignin('base', 'LearningCurveCompare_InteractionFigure_PFirstBlock', pFirstBlock);

function [p, h] = iRanksumSafe(x, y)
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if isempty(x) || isempty(y)
	p = NaN;
	h = NaN;
	return;
end
[p, h] = ranksum(x, y);
end

function pVal = iGetAnovaP(anovaTbl, termName)
pVal = NaN;
if isempty(anovaTbl)
	return;
end
idx = find(string(anovaTbl.Term) == string(termName), 1, 'first');
if ~isempty(idx)
	pVal = anovaTbl.pValue(idx);
	return;
end
idx = find(contains(string(anovaTbl.Term), string(termName)), 1, 'first');
if ~isempty(idx)
	pVal = anovaTbl.pValue(idx);
end
end

function summaryTbl = iBuildCurveSummary(T, groupOrder, groupLabels)
rows = table('Size', [0 6], ...
	'VariableTypes', {'string','string','double','double','double','double'}, ...
	'VariableNames', {'GroupCode','GroupLabel','Block','MeanHitRate','SemHitRate','NMouse'});
for g = 1:numel(groupOrder)
	groupCode = string(groupOrder(g));
	groupLabel = string(groupLabels(g));
	maskG = string(T.Group) == groupCode;
	if ~any(maskG)
		continue;
	end
	blocks = unique(double(T.Session(maskG)));
	blocks = sort(blocks(isfinite(blocks)));
	for b = 1:numel(blocks)
		mask = maskG & double(T.Session) == blocks(b) & isfinite(double(T.Performance));
		values = double(T.Performance(mask));
		mice = unique(string(T.Mouse(mask)));
		rows = [rows; {groupCode, groupLabel, blocks(b), mean(values, 'omitnan'), std(values, 'omitnan') / sqrt(numel(values)), numel(mice)}]; %#ok<AGROW>
	end
	end
	summaryTbl = rows;
end

function [meanMat, semMat, x] = iBuildMeanSemMatrices(summaryTbl, groupLabels)
x = unique(double(summaryTbl.Block));
x = sort(x(isfinite(x)));
meanMat = nan(numel(x), numel(groupLabels));
semMat = nan(numel(x), numel(groupLabels));
for g = 1:numel(groupLabels)
	maskG = string(summaryTbl.GroupLabel) == string(groupLabels(g));
	for i = 1:numel(x)
		row = find(maskG & double(summaryTbl.Block) == x(i), 1, 'first');
		if isempty(row)
			continue;
		end
		meanMat(i, g) = double(summaryTbl.MeanHitRate(row));
		semMat(i, g) = double(summaryTbl.SemHitRate(row));
	end
	end
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat, x)
nLines = size(meanMat, 2);
yCells = cell(1, nLines);
sCells = cell(1, nLines);
xCells = cell(1, nLines);
for j = 1:nLines
	y = meanMat(:, j);
	s = semMat(:, j);
	last = find(isfinite(y) & isfinite(s), 1, 'last');
	if isempty(last)
		yCells{j} = nan(0,1);
		sCells{j} = nan(0,1);
		xCells{j} = nan(0,1);
	else
		yCells{j} = y(1:last);
		sCells{j} = s(1:last);
		xCells{j} = x(1:last);
	end
	end
end