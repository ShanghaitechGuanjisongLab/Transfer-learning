% English Fig2J: 7-day homecage interval (Vacation7 vs Control)
%
% v6 Panel J: Vacation7 时间对照（学习曲线 + 首会话命中率）
% Data source: Fig3.5D (TransferLearning.Fig35.D_Vacation7VsCtrl)
% Outputs (SVG):
%   - English_Fig2J_Vacation7_LearningCurve.svg
%   - English_Fig2J_Vacation7_FirstSessionHitRate.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

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
BCtrl = TransferLearning.Fig35.iQueryLightWaterBlocks(CtrlDS, false);
BV7   = TransferLearning.Fig35.iQueryLightWaterBlocks(V7DS,   false);
if isempty(BCtrl) || isempty(BV7)
	error('English_Fig2J:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end

BCtrl.Group = repmat("Control",    height(BCtrl), 1);
BV7.Group   = repmat("Vacation7",  height(BV7),   1);

BCtrl.Mouse = string(BCtrl.Mouse);
BV7.Mouse   = string(BV7.Mouse);
BCtrl.DateTime = TransferLearning.Fig35.iNormalizeDateTime(BCtrl.DateTime);
BV7.DateTime   = TransferLearning.Fig35.iNormalizeDateTime(BV7.DateTime);

J = [BCtrl; BV7];
J.Group = string(J.Group);

% --- 3) Sessionize and add session index
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
Sess = TransferLearning.Fig35.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.Fig35.iAddSessionIndex(Sess);

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

% --- 5) Plot learning curve (like English Fig2B)
f = figure('Color','w', 'Name', 'English Fig2J Vacation7 Learning curve');
try
	f.Units = 'centimeters';
	f.Position(3:4) = [9, 8];
	try, f.PaperPositionMode = 'auto'; catch, end
catch
end
ax = axes(f);
hold(ax,'on');

try
	edgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
catch
	edgeColors = lines(2);
end

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));
labels = {char(grpOrder(1)), char(grpOrder(2))};
try
	if numel(Patches) >= 2
		lg = legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2)));
	else
		lg = legend(ax, labels, 'Location', 'best');
	end
	lg.FontSize = 12;
catch
end

ax.FontSize = 12;
xlabel(ax, 'Session', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');

svgLC = fullfile(outDirUNC, 'English_Fig2J_Vacation7_LearningCurve.svg');
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
	TransferLearning.PrintFigure(f, svgLC);
	fprintf('Wrote: %s\n', svgLC);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% --- 6) First transfer session hit-rate bar compare
perMouse = TransferLearning.Fig35.iPerMouseTable(Sess);
perMouse = TransferLearning.Fig35.iAddFirstTransferPerf(perMouse, Sess);

xCtrl = perMouse.TransferFirstPerf(perMouse.Group=="Control");
xV7   = perMouse.TransferFirstPerf(perMouse.Group=="Vacation7");

xCtrl = xCtrl(isfinite(xCtrl));
xV7   = xV7(isfinite(xV7));
[pFS, ~] = TransferLearning.Fig35.iRanksumSafe(xCtrl, xV7);

DataCell = {double(xCtrl(:)), double(xV7(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
%%

f2 = figure('Color','none', 'Name', 'English Fig2J Vacation7 First transfer session');
try
	f2.Units = 'centimeters';
	f2.Position(3:4) = [4, 3];
	try, f2.PaperPositionMode = 'auto'; catch, end
	try, f2.InvertHardcopy = 'off'; catch, end
catch
end

[~, ~, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
ax2.FontSize = 12/1.2;
ax2.Color = 'none';
ax2.XAxis.Visible = false;
ax2.XTick = [];
legend(ax2, 'off');

% Bar styling (match English Fig2B)
colorA = [1 0 0];
colorB = [0 0 1];
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nBars = numel(Bars2.YData);
	reps = ceil(nBars/2);
	Bars2.CData = repmat([colorA; colorB], reps, 1);
	Bars2.CData = Bars2.CData(1:nBars, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 0.5;
	try, Bars2.FaceAlpha = 1/3; catch, end
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorA;
		Bars2(2).FaceColor = colorB;
		Bars2(1).LineWidth = 0.5;
		Bars2(2).LineWidth = 0.5;
		try, Bars2(1).FaceAlpha = 1/3; catch, end
		try, Bars2(2).FaceAlpha = 1/3; catch, end
	end
end
for eb = ErrorBars2.Object(:)'
	eb.LineWidth = 0.5;
end
ax2.XLim = [0.5, 2.5];

ylabel(ax2, 'Hit rate', 'FontSize', 12 / 1.2);
title(ax2, 'First block');
box(ax2, 'off');

svgFS = fullfile(outDirUNC, 'English_Fig2J_Vacation7_FirstSessionHitRate.svg');
try
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar), ax2.Toolbar.Visible = 'off'; end
	TransferLearning.PrintFigure(f2, svgFS);
	fprintf('Wrote: %s (p=%.4g)\n', svgFS, pFS);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

assignin('base', 'English_Fig2J_Sessions', Sess);
assignin('base', 'English_Fig2J_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig2J_FirstSessionP', pFS);
