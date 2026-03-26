% 英文图3H：TH 抑制组 vs 对照组 LightWater 学习曲线 + 首会话命中率
%
% 数据源（模仿 Fig3.5C）：
% - 对照组：TransferLearning.AudioLightBaseline
% - 抑制组：TransferLearning.THInhibit + PO 化学遗传抑制（纯行为）
%
% 绘图样式模仿英文图2J：
%   Figure 1: MultiShadowedLines 学习曲线
%   Figure 2: BarScatterCompare 首会话命中率
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.H_THInhibitVsCtrl_LearningCurve

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgNameLC = "English_Fig3H_THInhibitVsCtrl_LearningCurve.svg";
svgNameFS = "English_Fig3H_THInhibitVsCtrl_FirstSessionHitRate.svg";

%% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try, matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

%% --- 1) Load datasets (same as Fig3.5C)
CtrlDS = TransferLearning.AudioLightBaseline();
THDS   = TransferLearning.THInhibit();

%% --- 2) Query LightWater behavior blocks
Bc = TransferLearning.Fig35.iQueryLightWaterBlocks(CtrlDS, false);
Bt = TransferLearning.Fig35.iQueryLightWaterBlocks(THDS, false);
Bc.Group = repmat("Ctrl", height(Bc), 1);
Bt.Group = repmat("TH",   height(Bt), 1);

Bc.Mouse = string(Bc.Mouse);
Bt.Mouse = string(Bt.Mouse);
Bc.DateTime = TransferLearning.Fig35.iNormalizeDateTime(Bc.DateTime);
Bt.DateTime = TransferLearning.Fig35.iNormalizeDateTime(Bt.DateTime);

J = MATLAB.DataTypes.MergeTables(Bc, Bt);
J.Group = string(J.Group);

%% --- 3) Sessionize
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
Sess = TransferLearning.Fig35.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.Fig35.iAddSessionIndex(Sess);

sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});

%% --- 3b) Include PO chemogenetic inhibition into TH group (matching Fig3.5C)
poMatPath = "\\Data-Server-2\个人数据\张天夫\202505\化学遗传抑制PO.v1.mat";
try
	if exist(poMatPath, 'file')
		PO = UniExp.DataSet(poMatPath);
		POTable = PO.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater", Expression="溢出");
		if ~isempty(POTable)
			if ismember('Phase', POTable.Properties.VariableNames)
				POTable.Phase = string(POTable.Phase);
				POTable(POTable.Phase=="Recall", :) = [];
			end
			poSess = POTable(:, intersect(["Mouse","DateTime","Performance"], string(POTable.Properties.VariableNames), 'stable'));
			poSess.Mouse = string(poSess.Mouse);
			poSess.DateTime = TransferLearning.Fig35.iNormalizeDateTime(poSess.DateTime);
			poSess.Group = repmat("TH", height(poSess), 1);
			poSess = unique(poSess(:, ["Mouse","DateTime","Performance","Group"]), 'rows');
			sessionForSummary = [sessionForSummary; poSess]; %#ok<AGROW>
			sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});
		end
	end
catch
end

%% --- 4) Learning curve summary
PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

grpOrder = ["Ctrl","TH"];
grpLabels = ["Control","TH inhibited"];

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

if numel(meanCells) >= 2
	keepN = min(14, numel(meanCells{2}));
	meanCells{2} = meanCells{2}(1:keepN);
	semCells{2} = semCells{2}(1:keepN);
end

%% --- 5) Plot learning curve (style: English Fig2J)
f = figure('Color', 'w', 'Name', 'English Fig3G TH Learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperPositionMode = 'auto';

ax = axes(f);
hold(ax, 'on');

edgeColors = TransferLearning.FigurePalette(2);

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

labels = {char(grpLabels(1)), char(grpLabels(2))};
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
ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');

%% --- 6) Export
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
catch
end
svgPath = fullfile(outDirUNC, svgNameLC);
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

%% --- 7) First transfer session hit-rate bar compare (style: English Fig2J)
barSess = sessionForSummary;
barSess = sortrows(barSess, {'Group','Mouse','DateTime'});
barSess = TransferLearning.Fig35.iAddSessionIndex(barSess);

firstSess = sortrows(barSess(barSess.Session == 1, :), {'Group','Mouse'});
xCtrl = double(firstSess.Performance(firstSess.Group=="Ctrl"));
xTH   = double(firstSess.Performance(firstSess.Group=="TH"));

xCtrl = xCtrl(isfinite(xCtrl));
xTH   = xTH(isfinite(xTH));
[pFS, ~] = TransferLearning.Fig35.iRanksumSafe(xCtrl, xTH);

fprintf('First Transfer session hit rate:\n');
fprintf('  Ctrl: %.3f ± %.3f (n=%d)\n', mean(xCtrl), std(xCtrl)/sqrt(numel(xCtrl)), numel(xCtrl));
fprintf('  TH:   %.3f ± %.3f (n=%d)\n', mean(xTH),   std(xTH)/sqrt(numel(xTH)),     numel(xTH));
fprintf('  ranksum p = %.4g\n', pFS);

DataCell = {double(xCtrl(:)), double(xTH(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f2 = figure('Color', 'none', 'Name', 'English Fig3G TH First transfer session');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperPositionMode = 'auto';
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];
try, f2.InvertHardcopy = 'off'; catch, end

[~, Opt2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
ax2.FontSize = 12/1.2;
	ax2.LineWidth = 2;
ax2.Color = 'none';
ax2.XAxis.Visible = false;
ax2.XTick = [];
legend(ax2, 'off');

% Bar styling (match English Fig2J)
colorA = edgeColors(1,:);
colorB = edgeColors(2,:);
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nBars = numel(Bars2.YData);
	reps = ceil(nBars/2);
	Bars2.CData = repmat([colorA; colorB], reps, 1);
	Bars2.CData = Bars2.CData(1:nBars, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 2;
	try, Bars2.EdgeColor = 'none'; catch, end
	try, Bars2.FaceAlpha = 1/3; catch, end
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorA; Bars2(1).LineWidth = 2; try, Bars2(1).EdgeColor = 'none'; catch, end; try, Bars2(1).FaceAlpha = 1/3; catch, end
		Bars2(2).FaceColor = colorB; Bars2(2).LineWidth = 2; try, Bars2(2).EdgeColor = 'none'; catch, end; try, Bars2(2).FaceAlpha = 1/3; catch, end
	end
end
for eb = ErrorBars2.Object(:)'
	eb.LineWidth = 2;
end
if isfield(Opt2, 'MultiCompare') && ismember('PLine', Opt2.MultiCompare.Properties.VariableNames)
	for pl = Opt2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
	end
end
ax2.XLim = [0.5, 2.5];

ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block');
box(ax2, 'off');

try
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar), ax2.Toolbar.Visible = 'off'; end
catch
end
svgPathFS = fullfile(outDirUNC, svgNameFS);
TransferLearning.PrintFigure(f2, svgPathFS, ForceLegendOrColorbar=true);
fprintf('Wrote: %s (p=%.4g)\n', svgPathFS, pFS);

assignin('base', 'English_Fig3G_Sessions', Sess);
assignin('base', 'English_Fig3G_BarSessions', barSess);
assignin('base', 'English_Fig3G_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig3G_FirstSessionP', pFS);
