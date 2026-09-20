% English Fig3B: 7-day homecage interval lowers light-water learning
%
% Main: block-wise learning curve, Control (no gap) vs Vacation7 (7-day gap),
%   mean +/- SEM with group-level summary from UniExp.LearningSummarize;
%   significance line over blocks 1-7 from two-way ANOVA group effect.
% Inset (规范: 4x4 cm, transparent, Scale=2): first-block hit rate per mouse,
%   UniExp.BarScatterCompare with IndividualErrorbars (one-sided SEM, per-bar
%   matching colors), internal PLine.
%
% Outputs (SVG):
%   - English_Fig3B_GapLearningCurve.svg
%   - English_Fig3B_GapFirstBlock_Inset.svg
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

CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();

BCtrl = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(CtrlDS, false);
BV7 = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(V7DS, false);
if isempty(BCtrl) || isempty(BV7)
	error('English_Fig3B:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end
BCtrl.Group = repmat("Control", height(BCtrl), 1);
BV7.Group = repmat("Vacation7", height(BV7), 1);
BCtrl.Mouse = string(BCtrl.Mouse);
BV7.Mouse = string(BV7.Mouse);
BCtrl.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(BCtrl.DateTime);
BV7.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(BV7.DateTime);

J = [BCtrl; BV7];
J.Group = string(J.Group);
vars = intersect(J.Properties.VariableNames, {'Mouse', 'DateTime', 'Performance', 'Group', 'Phase'}, 'stable');
Sess = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group', 'Mouse', 'DateTime'});
Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);
nControlMice = numel(unique(string(Sess.Mouse(Sess.Group == "Control"))));
nV7Mice = numel(unique(string(Sess.Mouse(Sess.Group == "Vacation7"))));

sessionForSummary = Sess(:, {'Mouse', 'DateTime', 'Performance', 'Group'});
sessionForSummary.Group = string(sessionForSummary.Group);
try
	[SummaryL, ~] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end
grpOrder = ["Control", "Vacation7"];
SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end
meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve, 'UniformOutput', false);

colorCtrl = TransferLearning.TransferColor;
colorGap = TransferLearning.ColorB;

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

% ---------- 主图：学习曲线（有 legend → Scale=2，高 4×2 cm，宽 9 cm） ----------
f = figure('Color', 'w', 'Name', 'English Fig3B gap learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax, 'on');
Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1 / (numel(grpOrder) + 1), EdgeColors = [colorCtrl; colorGap]);
xlabel(ax, 'Block');
ylabel(ax, 'Hit rate');

groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(Sess(Sess.Session <= 7, :), 'Performance', 'Session', 'Group', 'Mouse');
max7Ctrl = max(meanCells{1}(1:min(7, end)), [], 'omitnan');
max7Gap = max(meanCells{2}(1:min(7, end)), [], 'omitnan');
yTop7 = max(max7Ctrl, max7Gap);
yl = ylim(ax);
yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
if groupP7 < 0.001
	starStr = '＊＊＊＊';
else
	starStr = TransferLearning.Style.iFormatPText(groupP7);
end
text(ax, 4, yPLine + 0.1 * yrange, starStr, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'HandleVisibility', 'off');
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));
lg = legend(ax, Patches(1:2), {'No gap', '7-day gap'}, 'Location', 'southeast');
lg.Box = 'off';
box(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig3B_GapLearningCurve.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Learning curve mice: Control n = %d, 7-day gap n = %d\n', nControlMice, nV7Mice);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);

% ---------- Inset：首 block 命中率（规范: 4×4 cm，透明，Scale=2） ----------
perMouse = TransferLearning.BehaviorSessions.iPerMouseTable(Sess);
perMouse = TransferLearning.BehaviorSessions.iAddFirstTransferPerf(perMouse, Sess);
xCtrl = perMouse.TransferFirstPerf(perMouse.Group == "Control");
xV7 = perMouse.TransferFirstPerf(perMouse.Group == "Vacation7");
xCtrl = xCtrl(isfinite(xCtrl));
xV7 = xV7(isfinite(xV7));
[pFS, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(xCtrl, xV7);

f2 = figure('Color', 'w', 'Name', 'English Fig3B gap first block inset');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];
f2.PaperPositionMode = 'auto';
ax2 = axes(f2);
DataCell = {double(xCtrl(:)), double(xV7(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Opt2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax2.XTick = 1:2;
ax2.XTickLabel = {};
ax2.Color = 'none';
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB = numel(Bars2.YData);
	Bars2.CData = repmat([colorCtrl; colorGap], ceil(nB / 2), 1);
	Bars2.CData = Bars2.CData(1:nB, :);
else
	Bars2(1).FaceColor = colorCtrl;
	Bars2(2).FaceColor = colorGap;
end
for kB = 1:numel(Bars2)
	Bars2(kB).BarWidth = 0.5;
	Bars2(kB).EdgeColor = 'none';
	Bars2(kB).FaceAlpha = 1;
end
if istable(ErrorBars2) && ~isempty(ErrorBars2) && ismember('Object', ErrorBars2.Properties.VariableNames)
	barColors = [colorCtrl; colorGap];
	for kE = 1:height(ErrorBars2)
		eb = ErrorBars2.Object(kE);
		if isgraphics(eb) && kE <= size(barColors, 1)
			eb.Color = barColors(kE, :);
		end
	end
end
% anova/multcompare 不感知非配对口径，PText 覆盖为 rank-sum p（与 Fig3C/F 一致）
if isfield(Opt2, 'MultiCompare') && istable(Opt2.MultiCompare)
	mc2 = Opt2.MultiCompare;
	if ismember('PText', mc2.Properties.VariableNames)
		for ip = 1:height(mc2)
			pt = mc2.PText(ip);
			if isgraphics(pt)
				pt.String = TransferLearning.Style.iFormatPText(pFS);
				pt.Tag = 'PText';
			end
		end
	end
end
ylabel(ax2, 'Hit rate');
title(ax2, 'First block', 'FontWeight', 'normal');
legend(ax2, 'off');
box(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end
svgInset = TransferLearning.ExportStandardFigureTransparent(f2, 2, 'English_Fig3B_GapFirstBlock_Inset.svg');
fprintf('Wrote: %s\n', svgInset);
fprintf('First-block mice: Control n = %d, gap n = %d; ranksum p = %.4g\n', numel(xCtrl), numel(xV7), pFS);

assignin('base', 'Fig3B_GapStats', struct('nCtrl', nControlMice, 'nV7', nV7Mice, ...
	'groupP7', groupP7, 'firstCtrl', xCtrl, 'firstV7', xV7, 'pFirst', pFS));
