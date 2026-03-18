% English Fig2J: DREADD hM4D(Gi) non-specific inhibition vs mCherry control
%
% v6 Panel J: DREADD MOp 全局抑制（学习曲线 + 首会话命中率）
% Data source: Fig3.5B (TransferLearning.Fig35.B_MOpVsMCherry)
% Outputs (SVG):
%   - English_Fig2J_DREADD_LearningCurve.svg
%   - English_Fig2J_DREADD_FirstSessionHitRate.svg
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
inhibPath  = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制 声水转光水.v3.mat";
ctrlPath   = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.v2.mat";

DS_Inh  = UniExp.DataSet(inhibPath);
DS_Ctrl = UniExp.DataSet(ctrlPath);

% --- 2) Query LightWater behavior blocks
BInh  = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_Inh,  true);
BCtrl = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_Ctrl, true);
if isempty(BInh) || isempty(BCtrl)
	error('English_Fig2J:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end

BInh.Group  = repmat("Inhibited", height(BInh), 1);
BCtrl.Group = repmat("Control",   height(BCtrl), 1);

BInh.Mouse = string(BInh.Mouse);
BCtrl.Mouse = string(BCtrl.Mouse);
BInh.DateTime  = TransferLearning.Fig35.iNormalizeDateTime(BInh.DateTime);
BCtrl.DateTime = TransferLearning.Fig35.iNormalizeDateTime(BCtrl.DateTime);

J = [BCtrl; BInh];
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

grpOrder = ["Control","Inhibited"];

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

% n per group is intentionally NOT shown in legend (match request)

% --- 5) Plot learning curve (like English Fig1B)
f = figure('Color','w', 'Name', 'English Fig2J DREADD Learning curve');
try
	f.Units = 'centimeters';
	f.Position(3:4) = [9, 8]; % 90mm x 80mm (match English Fig1B)
	try, f.PaperPositionMode = 'auto'; catch, end
catch
	MATLAB.Graphics.FigureAspectRatio(90, 80, 1);
end
ax = axes(f);
hold(ax,'on');
title(ax, 'Non-specific MOp inhibition', 'FontSize', 8);

try
	edgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
catch
	edgeColors = lines(2);
end

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

% --- 5b) Stats: draw overall learning-curve significance (like English Fig1B)
% Use LME Group main effect (additive model): tests overall curve separation
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
if isfinite(pCurve)
	% Place annotation at the end of curves (X=6.5, Y = mean of both curves at session 6)
	lastSess = min(numel(meanCells{1}), numel(meanCells{2}));
	y1 = meanCells{1}(lastSess);
	y2 = meanCells{2}(lastSess);
	yMid = (y1 + y2) / 2;
	if pCurve < 0.001
		astStr = '***';
	elseif pCurve < 0.01
		astStr = '**';
	elseif pCurve < 0.05
		astStr = '*';
	else
		astStr = 'n.s.';
	end
	ht = text(ax, lastSess + 0.5, yMid, astStr, 'FontSize', 12, ...
		'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
		'HandleVisibility', 'off');
	ht.AffectAutoLimits = 'on';
end
fprintf('Learning curve overall p = %.4g\n', pCurve);

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

svgLC = fullfile(outDirUNC, 'English_Fig2J_DREADD_LearningCurve.svg');
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
xInh  = perMouse.TransferFirstPerf(perMouse.Group=="Inhibited");

xCtrl = xCtrl(isfinite(xCtrl));
xInh  = xInh(isfinite(xInh));
[pFS, ~] = TransferLearning.Fig35.iRanksumSafe(xCtrl, xInh);

DataCell = {double(xCtrl(:)), double(xInh(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
%% 

f2 = figure('Color','none', 'Name', 'English Fig2J DREADD First transfer session');
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

% Bar styling (match English Fig1B)
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

svgFS = fullfile(outDirUNC, 'English_Fig2J_DREADD_FirstSessionHitRate.svg');
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
