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
svgNameLC = "中文图Fig62A_THInhibitVsCtrl_LearningCurve.svg";
svgNameFS = "中文图Fig62A_THInhibitVsCtrl_FirstSessionHitRate.svg";

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
			poSess.Phase = repmat("", height(poSess), 1);
			poSess = unique(poSess(:, ["Group","Mouse","DateTime","Performance","Phase"]), 'rows');
			Sess = [Sess; poSess]; %#ok<AGROW>
		end
	end
catch
end

Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);
sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group','Session'});
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});

%% --- 4) Learning curve summary
PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end
pCurve = iScalarPValue(PValueLS);

[groupIdForCurve, groupNameForCurve] = findgroups(string(sessionForSummary.Group));
curveMouseN = splitapply(@(m) numel(unique(string(m))), sessionForSummary.Mouse, groupIdForCurve);
curveBlockN = splitapply(@numel, sessionForSummary.Performance, groupIdForCurve);

fprintf('\n=== English Fig3G / Chinese Fig343D learning curve ===\n');
for iGroup = 1:numel(groupNameForCurve)
	fprintf('%s: %d mice, %d blocks\n', groupNameForCurve(iGroup), curveMouseN(iGroup), curveBlockN(iGroup));
end
fprintf('Learning curve p = %.4g\n', pCurve);
fprintf('Learning curve panel: cell count and Spearman rho are not applicable.\n');

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

edgeColors = [TransferLearning.ContinualColor; TransferLearning.ColorA];

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

ax.FontSize = 12;
ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Block', 'FontSize', 12);

sessionForSummary = iCarryForwardSessions(sessionForSummary);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(sessionForSummary, 'Performance', 'Session', 'Group', 'Mouse');
sessions7 = sessionForSummary(sessionForSummary.Session <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Session', 'Group', 'Mouse');
max7Ctrl = max(meanCells{1}(1:min(7, end)), [], 'omitnan');
max7TH = max(meanCells{2}(1:min(7, end)), [], 'omitnan');
yTop7 = max(max7Ctrl, max7TH);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
if groupP7 < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP7); end
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

labels = {char(grpLabels(1)), char(grpLabels(2))};
lg = legend(ax, Patches(1:2), labels, 'Location','southeastoutside');


box(ax, 'off');
grid(ax, 'off');

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end

svgPath = TransferLearning.ExportStandardFigure(f, 2, svgNameLC);
fprintf('Wrote: %s\n', svgPath);
fprintf('Two-way ANOVA Group P (all blocks) = %.4g\n', groupP);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);

%% --- 7) First transfer session hit-rate bar compare (style: English Fig2J)
barSess = sessionForSummary;
barSess = sortrows(barSess, {'Group','Mouse','DateTime'});
barSess = iAddSessionIndex(barSess);

firstSess = sortrows(barSess(barSess.Session == 1, :), {'Group','Mouse'});
xCtrl = double(firstSess.Performance(firstSess.Group=="Ctrl"));
xTH   = double(firstSess.Performance(firstSess.Group=="TH"));

xCtrl = xCtrl(isfinite(xCtrl));
xTH   = xTH(isfinite(xTH));

fprintf('First Transfer session hit rate:\n');
fprintf('  Ctrl: %.3f ± %.3f (n=%d)\n', mean(xCtrl), std(xCtrl)/sqrt(numel(xCtrl)), numel(xCtrl));
fprintf('  TH:   %.3f ± %.3f (n=%d)\n', mean(xTH),   std(xTH)/sqrt(numel(xTH)),     numel(xTH));
fprintf('First-block panel: cell count and Spearman rho are not applicable.\n');

DataCell = {double(xCtrl(:)), double(xTH(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
%% 

f2 = figure('Color', 'none', 'Name', 'English Fig3G TH First transfer session');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperPositionMode = 'auto';
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];

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
ax2.XAxis.Visible = 'on';
ax2.XTick = [1 2];
ax2.XTickLabel = {'Control', 'TH'};
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
	Bars2.BaseLine.Visible = 'off';
	try, Bars2.EdgeColor = 'none'; catch, end
	try, Bars2.FaceAlpha = 1; catch, end
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorA; Bars2(1).BarWidth = 0.5; Bars2(1).LineWidth = 2; Bars2(1).BaseLine.Visible = 'off'; try, Bars2(1).EdgeColor = 'none'; catch, end; try, Bars2(1).FaceAlpha = 1; catch, end
		Bars2(2).FaceColor = colorB; Bars2(2).BarWidth = 0.5; Bars2(2).LineWidth = 2; Bars2(2).BaseLine.Visible = 'off'; try, Bars2(2).EdgeColor = 'none'; catch, end; try, Bars2(2).FaceAlpha = 1; catch, end
	end
end
for iE = 1:height(ErrorBars2)
	eb = ErrorBars2.Object(iE);
	eb.LineWidth = 2;
	xData = double(eb.XData(:));
	[~, colorIndex] = min(abs((1:size(edgeColors, 1)).' - xData(1)));
	eb.Color = edgeColors(colorIndex, :);
end
TransferLearning.Style.SetBarPValues(Opt2);
fprintf('\n=== Figure caption (6.2A first block): %s ===\n', ...
	TransferLearning.Style.iFormatPText(Opt2.MultiCompare.PValue(1)));
if isfield(Opt2, 'MultiCompare') && ismember('PText', Opt2.MultiCompare.Properties.VariableNames)
	for pt = Opt2.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end
if isfield(Opt2, 'MultiCompare') && ismember('PLine', Opt2.MultiCompare.Properties.VariableNames)
	for pl = Opt2.MultiCompare.PLine(:)'
		pl.LineWidth = 1;
	end
end
ax2.XLim = [-0.05, 3.05];

ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');

try
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar), ax2.Toolbar.Visible = 'off'; end
catch
end
svgPathFS = TransferLearning.ExportStandardFigureTransparent(f2, 2, svgNameFS);
fprintf('Wrote: %s (p=%.4g)\n', svgPathFS, pFS);

assignin('base', 'English_Fig3G_Sessions', Sess);
assignin('base', 'English_Fig3G_BarSessions', barSess);
assignin('base', 'English_Fig3G_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig3G_LearningCurveP', pCurve);
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

function p = iScalarPValue(pIn)
p = NaN;
if isnumeric(pIn) || islogical(pIn)
	pVec = double(pIn(:));
	pVec = pVec(isfinite(pVec));
	if ~isempty(pVec), p = pVec(1); end
	return;
end
if istable(pIn)
	for iVar = 1:numel(pIn.Properties.VariableNames)
		v = pIn.(pIn.Properties.VariableNames{iVar});
		if isnumeric(v) || islogical(v)
			pVec = double(v(:));
			pVec = pVec(isfinite(pVec));
			if ~isempty(pVec)
				p = pVec(1);
				return;
			end
		end
	end
end
if isstruct(pIn)
	fieldList = fieldnames(pIn);
	for iField = 1:numel(fieldList)
		v = pIn.(fieldList{iField});
		if isnumeric(v) || islogical(v)
			pVec = double(v(:));
			pVec = pVec(isfinite(pVec));
			if ~isempty(pVec)
				p = pVec(1);
				return;
			end
		end
	end
end
end
function T = iCarryForwardSessions(T)
% Fill Performance=1 for all sessions after a mouse first reaches 100%.
if isempty(T)
	return;
end
T = sortrows(T, {'Mouse', 'Session'});
mice = unique(string(T.Mouse));
maxSession = max(double(T.Session));
outPieces = cell(numel(mice), 1);
for iM = 1:numel(mice)
	mM = T(string(T.Mouse) == mice(iM), :);
	xm = double(mM.Session);
	ym = double(mM.Performance);
	reached = find(ym >= 1.0, 1, 'first');
	if isempty(reached)
		outPieces{iM} = mM;
		continue;
	end
	sessReached = xm(reached);
	if sessReached >= maxSession
		outPieces{iM} = mM;
		continue;
	end
	fillBlocks = (sessReached + 1 : maxSession)';
	newRows = mM(1, :);
	newRows = repmat(newRows, numel(fillBlocks), 1);
	newRows.Session = fillBlocks;
	newRows.Performance = repmat(1, numel(fillBlocks), 1);
	outPieces{iM} = [mM; newRows];
end
T = sortrows(vertcat(outPieces{:}), {'Mouse', 'Session'});
end