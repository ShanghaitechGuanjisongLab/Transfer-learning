% English Fig2M: 7-day homecage interval (Vacation7 vs Control)
%
% v6 Panel M: Vacation7 时间对照（学习曲线 + 首会话命中率）
% Shared behavior-session helpers: TransferLearning.BehaviorSessions
% Outputs (SVG):
%   - English_Fig2M_Vacation7_LearningCurve.svg
%   - English_Fig2M_Vacation7_FirstSessionHitRate.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.


% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- 1) Load datasets
CtrlDS = TransferLearning.AudioLightBaseline();
V7DS   = TransferLearning.Vacation7();

% --- 2) Query LightWater behavior blocks
BCtrl = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(CtrlDS, false);
BV7   = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(V7DS,   false);
if isempty(BCtrl) || isempty(BV7)
	error('English_Fig2M:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end

BCtrl.Group = repmat("Control",    height(BCtrl), 1);
BV7.Group   = repmat("Vacation7",  height(BV7),   1);

BCtrl.Mouse = string(BCtrl.Mouse);
BV7.Mouse   = string(BV7.Mouse);
BCtrl.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(BCtrl.DateTime);
BV7.DateTime   = TransferLearning.BehaviorSessions.iNormalizeDateTime(BV7.DateTime);

J = [BCtrl; BV7];
J.Group = string(J.Group);

% --- 3) Sessionize and add session index
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
Sess = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);
nControlMice = numel(unique(string(Sess.Mouse(Sess.Group == "Control"))));
nV7Mice = numel(unique(string(Sess.Mouse(Sess.Group == "Vacation7"))));

% --- 4) Learning curve summary
sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);

PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

grpOrder = ["Control","Vacation7"];

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

lmeTbl = table;
lmeTbl.Performance = double(Sess.Performance);
lmeTbl.Session = double(Sess.Session);
lmeTbl.Group = categorical(string(Sess.Group));
lmeTbl.Mouse = categorical(string(Sess.Mouse));
lmeModel = fitlme(lmeTbl, 'Performance ~ Session + Group + (1|Mouse)');
lmeAnova = anova(lmeModel);
rowGrp = find(string(lmeAnova.Term) == "Group", 1);
pCurve = NaN;
if ~isempty(rowGrp)
	pCurve = lmeAnova.pValue(rowGrp);
end
%% 

% --- 5) Plot learning curve (like English Fig2B)
f = figure('Color','w', 'Name', 'English Fig2M Gap Learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
try, f.PaperPositionMode = 'auto'; catch, end
ax = axes(f);
hold(ax,'on');

displayGroups = ["Control", "Gap"];
edgeColors = TransferLearning.GroupColors(displayGroups);
edgeColors(1, :) = TransferLearning.ContinualColor;

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));
for p = Patches(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 2;
	end
end
labels = cellstr(displayGroups);
try
	if numel(Patches) >= 2
		lg = legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2)));
	else
		lg = legend(ax, labels, 'Location', 'best');
	end
	lg.FontSize = 12;
	lg.Title.String = '💡💧';
	lg.Title.FontSize = 12;
	lg.Box = 'off';
catch
end

ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgLC = 'English_Fig2M_Vacation7_LearningCurve.svg';
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
	svgLC = TransferLearning.ExportStandardFigure(f, 2, svgLC);
	fprintf('Wrote: %s\n', svgLC);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% --- 6) First transfer session hit-rate bar compare
perMouse = TransferLearning.BehaviorSessions.iPerMouseTable(Sess);
perMouse = TransferLearning.BehaviorSessions.iAddFirstTransferPerf(perMouse, Sess);

xCtrl = perMouse.TransferFirstPerf(perMouse.Group=="Control");
xV7   = perMouse.TransferFirstPerf(perMouse.Group=="Vacation7");

xCtrl = xCtrl(isfinite(xCtrl));
xV7   = xV7(isfinite(xV7));
nFirstControlMice = numel(xCtrl);
nFirstV7Mice = numel(xV7);
[pFS, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(xCtrl, xV7);

DataCell = {double(xCtrl(:)), double(xV7(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
%%

f2 = figure('Color','none', 'Name', 'English Fig2M Gap First transfer session');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
try, f2.PaperPositionMode = 'auto'; catch, end
try, f2.PaperUnits = 'centimeters'; f2.PaperSize = [4, 4]; catch, end
try, f2.InvertHardcopy = 'off'; catch, end

tiledlayout(1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
nexttile;
[~, Opt2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
ax2.FontSize = 12;
ax2.LineWidth = 2;
if isprop(ax2.XAxis, 'LineWidth')
	ax2.XAxis.LineWidth = 2;
	ax2.YAxis.LineWidth = 2;
end
ax2.Color = 'none';
ax2.XAxis.Visible = false;
ax2.XTick = [];
legend(ax2, 'off');
if isfield(Opt2, 'MultiCompare') && ismember('PText', Opt2.MultiCompare.Properties.VariableNames)
	for pt = Opt2.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end
if isfield(Opt2, 'MultiCompare') && ismember('PLine', Opt2.MultiCompare.Properties.VariableNames)
	for pl = Opt2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
	end
end
ax2.XLim = [0.5, 2.5];

iStyleBars(Bars2, edgeColors(1,:), edgeColors(2,:));
iStyleErrorBars(ErrorBars2, edgeColors);

ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');

svgFS = 'English_Fig2M_Vacation7_FirstSessionHitRate.svg';
try
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar), ax2.Toolbar.Visible = 'off'; end
	svgFS = TransferLearning.ExportStandardFigureTransparent(f2, 2, svgFS);
	fprintf('Wrote: %s (p=%.4g)\n', svgFS, pFS);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

sampleCounts = table(["Control"; "Gap"], [nControlMice; nV7Mice], [nFirstControlMice; nFirstV7Mice], ...
	'VariableNames', {'Group','NLearningCurveMice','NFirstBlockMice'});

fprintf('\n=== Fig335B / English Fig2M sample counts and statistics ===\n');
fprintf('Learning curve mice: Control n = %d, Gap n = %d\n', nControlMice, nV7Mice);
fprintf('First-block mice: Control n = %d, Gap n = %d\n', nFirstControlMice, nFirstV7Mice);
fprintf('Cells n = N/A (behavior-only panel)\n');
fprintf('Learning curve LME Group p = %.6g\n', pCurve);
fprintf('First-block hit-rate ranksum p = %.6g\n', pFS);

assignin('base', 'English_Fig2M_Sessions', Sess);
assignin('base', 'English_Fig2M_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig2M_LearningCurveP', pCurve);
assignin('base', 'English_Fig2M_FirstSessionP', pFS);
assignin('base', 'English_Fig2M_SampleCounts', sampleCounts);

function iStyleBars(barsObj, colorControl, colorGap)
if isscalar(barsObj)
	barsObj.FaceColor = 'flat';
	nBars = numel(barsObj.YData);
	barsObj.CData = repmat([colorControl; colorGap], ceil(nBars/2), 1);
	barsObj.CData = barsObj.CData(1:nBars, :);
	barsObj.BarWidth = 0.5;
	barsObj.LineWidth = 2;
	barsObj.BaseLine.LineWidth = 2;
	barsObj.EdgeColor = 'none';
	barsObj.FaceAlpha = 1;
	return;
end
barsObj(1).FaceColor = colorControl;
barsObj(2).FaceColor = colorGap;
barsObj(1).BarWidth = 0.5;
barsObj(2).BarWidth = 0.5;
barsObj(1).LineWidth = 2;
barsObj(2).LineWidth = 2;
barsObj(1).BaseLine.LineWidth = 2;
barsObj(2).BaseLine.LineWidth = 2;
barsObj(1).EdgeColor = 'none';
barsObj(2).EdgeColor = 'none';
barsObj(1).FaceAlpha = 1;
barsObj(2).FaceAlpha = 1;
end

function iStyleErrorBars(errorBars, colors)
for iE = 1:height(errorBars)
	errorBar = errorBars.Object(iE);
	errorBar.LineWidth = 2;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
end
end

