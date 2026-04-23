% 英文图3G：TH 抑制组 vs 对照组 LightWater 学习曲线 + 首会话命中率
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
%   TransferLearning.英文图3.G_THInhibitVsCtrl_LearningCurve

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgNameLC = "English_Fig3G_THInhibitVsCtrl_LearningCurve.svg";
svgNameFS = "English_Fig3G_THInhibitVsCtrl_FirstSessionHitRate.svg";

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
Bc = iQueryLightWaterBlocks(CtrlDS);
Bt = iQueryLightWaterBlocks(THDS);
Bc.Group = repmat("Ctrl", height(Bc), 1);
Bt.Group = repmat("TH",   height(Bt), 1);

Bc.Mouse = string(Bc.Mouse);
Bt.Mouse = string(Bt.Mouse);
Bc.DateTime = iNormalizeDateTime(Bc.DateTime);
Bt.DateTime = iNormalizeDateTime(Bt.DateTime);

J = MATLAB.DataTypes.MergeTables(Bc, Bt);
J.Group = string(J.Group);

%% --- 3) Sessionize
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Behavior','Performance','Group','Phase'}, 'stable');
Sess = iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);

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
			poSess.DateTime = iNormalizeDateTime(poSess.DateTime);
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
ax.LineWidth = 2;

edgeColors = [1, 0, 0; 0, 0, 1];

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
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgNameLC);
fprintf('Wrote: %s\n', svgPath);
close(f);

%% --- 7) First transfer session hit-rate bar compare (style: English Fig2J)
barSess = sessionForSummary;
barSess = sortrows(barSess, {'Group','Mouse','DateTime'});
barSess = iAddSessionIndex(barSess);

firstSess = sortrows(barSess(barSess.Session == 1, :), {'Group','Mouse'});
xCtrl = double(firstSess.Performance(firstSess.Group=="Ctrl"));
xTH   = double(firstSess.Performance(firstSess.Group=="TH"));

xCtrl = xCtrl(isfinite(xCtrl));
xTH   = xTH(isfinite(xTH));
[pFS, ~] = iRanksumSafe(xCtrl, xTH);

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

[~, Opt2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
ax2.FontSize = 12;
	ax2.LineWidth = 2;
ax2.Color = 'none';
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

ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');

try
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar), ax2.Toolbar.Visible = 'off'; end
catch
end
if isfield(Opt2, 'MultiCompare') && all(ismember({'PLine','PText'}, Opt2.MultiCompare.Properties.VariableNames))
	MATLAB.Graphics.PLineRetune(Opt2.MultiCompare.PLine, Opt2.MultiCompare.PText);
end
svgPathFS = TransferLearning.ExportStandardFigure(f2, 2, svgNameFS);
fprintf('Wrote: %s (p=%.4g)\n', svgPathFS, pFS);
close(f2);

assignin('base', 'English_Fig3G_Sessions', Sess);
assignin('base', 'English_Fig3G_BarSessions', barSess);
assignin('base', 'English_Fig3G_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig3G_FirstSessionP', pFS);

function T = iQueryLightWaterBlocks(DS)
varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
try
	T = DS.TableQuery(varsTry, Stimulus="LightWater");
catch
	T = DS.TableQuery(varsFallback, Stimulus="LightWater");
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

function S = iSessionizeByDateTime(T)
useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
if ~ismember('Phase', T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
if useBehavior
	T = T(:, {'Mouse','DateTime','Behavior','Phase','Group'});
else
	T = T(:, {'Mouse','DateTime','Performance','Phase','Group'});
end
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','DateTime'});
if useBehavior
	val = double(T.Behavior);
else
	val = double(T.Performance);
end
[G, groupKeys, mouseKeys, dtKeys] = findgroups(T.Group, T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
S = table(groupKeys, mouseKeys, dtKeys, perf, phaseSession, 'VariableNames', {'Group','Mouse','DateTime','Performance','Phase'});
end

function ph = iPickSessionPhase(phases)
phases = string(phases);
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	ph = "";
	return;
end
[u,~,ic] = unique(phases);
counts = accumarray(ic, 1);
[~,ix] = max(counts);
ph = u(ix);
end

function T = iAddSessionIndex(T)
T.Group = string(T.Group);
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

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
