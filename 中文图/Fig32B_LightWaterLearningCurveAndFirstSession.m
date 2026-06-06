% Fig32B：光水初始/迁移学习曲线 + 首会话条形图

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

LAB  = TransferLearning.LightAudioBaseline();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();
LAI  = TransferLearning.LAInterspersed();

naiveAnchors = ["Naive","Learned"];
tranAnchors  = ["Transfer","Final"];

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2));

tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");

allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	error('Fig32B:EmptyData', 'No LightWater blocks found.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);

PValueLS = nan;
[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);

f = figure('Color','w', 'Name', 'Fig32B LightWater learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
ax = axes(f);
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
hold(ax,'on');

displayGroups = ["Naive","Continual"];
edgeColors = TransferLearning.GroupColors(displayGroups);
cueTitleColor = TransferLearning.ColorB;
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=edgeColors(1:2,:));
for p = patches(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 2;
	end
end

curveP = iLearningCurvePValue(allSessions, PValueLS);

labels = cellstr(displayGroups);
if numel(patches) >= 2
	lg = legend(ax, patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(patches(1:2)));
else
	lg = legend(ax, labels, 'Location', 'best');
end
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '💡💧';
lg.Title.FontSize = 12;
lg.Title.Color = cueTitleColor;

xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig32B_LightWater_LearningCurve.svg');
fprintf('Wrote: %s\n', svgPath);

summaryCurve = table;
summaryCurve.Block = x(:);
summaryCurve.NaiveMean = meanMat(:,1);
summaryCurve.TransferMean = meanMat(:,2);
summaryCurve.NaiveSem = semMat(:,1);
summaryCurve.TransferSem = semMat(:,2);
summaryCurve.NaiveN = nMat(:,1);
summaryCurve.TransferN = nMat(:,2);
summaryCurve.PLearningSummarize(:) = curveP;
assignin('base', 'Fig32B_LightWaterLearningCurve_Raw', allSessions);
assignin('base', 'Fig32B_LightWaterLearningCurve_Summary', summaryCurve);

firstSess = allSessions(allSessions.Session == 1, :);
naiveFirst = double(firstSess.Performance(string(firstSess.Group) == "Naive"));
tranFirst  = double(firstSess.Performance(string(firstSess.Group) == "Transfer"));
naiveFirst = naiveFirst(isfinite(naiveFirst));
tranFirst  = tranFirst(isfinite(tranFirst));
firstBarPValue = ranksum(naiveFirst, tranFirst);

f2 = figure('Color','none', 'Name', 'Fig32B LightWater first-session performance');
f2.Units = 'centimeters';
pos2 = f2.Position;
pos2(3:4) = [4,4];
f2.Position = pos2;
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4,4];
f2.PaperPositionMode = 'auto';

tiledlayout(1,1,'TileSpacing','tight','Padding','tight');
nexttile;
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare({naiveFirst, tranFirst}, table([1 2], 'VariableNames', {'GroupPair'}), 'AsteriskThreshold', 0.05);
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
ax2.XTick = [];
legend(ax2, 'off');
if isfield(optional2, 'MultiCompare') && ismember('PText', optional2.MultiCompare.Properties.VariableNames)
	for pt = optional2.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end
if isfield(optional2, 'MultiCompare') && ismember('PLine', optional2.MultiCompare.Properties.VariableNames)
	for pl = optional2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
	end
end
iStyleBars(bars2, edgeColors(1,:), edgeColors(2,:));
iStyleErrorBars(errorBars2, edgeColors);
ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end
svgPath2 = TransferLearning.ExportStandardFigureTransparent(f2, 2, '中文图Fig32B_LightWater_FirstSessionPerformance.svg');
fprintf('Wrote: %s\n', svgPath2);
fprintf('\n=== Fig32B first-block bar ===\n');
fprintf('Naive mice n = %d\n', numel(naiveFirst));
fprintf('Continual mice n = %d\n', numel(tranFirst));
fprintf('First-block bar ranksum p = %.6g\n', firstBarPValue);

nFirst = max(numel(naiveFirst), numel(tranFirst));
firstSessionTable = table(nan(nFirst,1), nan(nFirst,1), 'VariableNames', {'NaiveFirst','TransferFirst'});
firstSessionTable.NaiveFirst(1:numel(naiveFirst)) = naiveFirst(:);
firstSessionTable.TransferFirst(1:numel(tranFirst)) = tranFirst(:);
firstSessionTable.BarRanksumPValue = repmat(firstBarPValue, nFirst, 1);
assignin('base', 'Fig32B_LightWater_FirstSession', firstSessionTable);

function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
T = iQueryLightWaterBehaviorAll(DS);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
	return;
end
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = iSessionizeByDateTime(T);
T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
T.Source = repmat(string(sourceName), height(T), 1);
T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
T = iQueryLightWaterBehaviorAll(DS);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
	return;
end
T.Mouse = string(T.Mouse);
if ~isempty(badMice)
	T = T(~ismember(T.Mouse, badMice), :);
end
T.DateTime = iNormalizeDateTime(T.DateTime);
T = iSessionizeByDateTime(T);
T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
T.Source = repmat(string(sourceName), height(T), 1);
T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
end

function T = iQueryLightWaterBehaviorAll(DS)
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
	T = T(:, {'Mouse','DateTime','Behavior','Phase'});
else
	T = T(:, {'Mouse','DateTime','Performance','Phase'});
end
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse','DateTime'});
if useBehavior
	val = double(T.Behavior);
else
	val = double(T.Performance);
end
[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
S = table(mouseKeys, dtKeys, perf, nBlocks, phaseSession, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
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

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
S.Mouse = string(S.Mouse);
S.Phase = string(S.Phase);
S = sortrows(S, {'Mouse','DateTime'});
mice = unique(S.Mouse);
keepRows = false(height(S),1);
for i = 1:numel(mice)
	idx = find(S.Mouse == mice(i));
	ph = S.Phase(idx);
	st = find(ph == string(startPhase), 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == string(endPhase) & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keepRows(idx(st:ed)) = true;
end
S = S(keepRows, :);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
if isempty(Ta)
	badMice = string.empty(0,1);
else
	badMice = unique(string(Ta.Mouse));
end
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
T.Mouse = string(T.Mouse);
T.Source = string(T.Source);
[G, mice] = findgroups(T.Mouse);
nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
dup = mice(nSrc > 1);
if ~isempty(dup)
	error('Fig32B:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.', char(string(groupName)));
end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
[G, mice] = findgroups(T.Mouse);
nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
dup = mice(nG > 1);
if ~isempty(dup)
	error('Fig32B:MouseInMultipleGroups', 'Some mice appear in multiple groups.');
end
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, groupOrder)
groupOrder = string(groupOrder);
meanCells = SummaryL.MeanCurve(:);
semCells = SummaryL.SemCurve(:);
if ~isempty(SummaryL.Properties.RowNames)
	rn = string(SummaryL.Properties.RowNames);
else
	rn = strings(numel(meanCells),1);
end
idx = nan(1, numel(groupOrder));
for k = 1:numel(groupOrder)
	ix = find(rn == groupOrder(k), 1, 'first');
	if isempty(ix) && k <= numel(meanCells)
		ix = k;
	end
	idx(k) = ix;
end
maxLen = 0;
for k = 1:numel(groupOrder)
	if isfinite(idx(k))
		maxLen = max(maxLen, numel(meanCells{idx(k)}));
	end
end
meanMat = nan(maxLen, numel(groupOrder));
semMat = nan(maxLen, numel(groupOrder));
for k = 1:numel(groupOrder)
	if isfinite(idx(k))
		mv = double(meanCells{idx(k)}(:));
		sv = double(semCells{idx(k)}(:));
		meanMat(1:numel(mv),k) = mv;
		semMat(1:numel(sv),k) = sv;
	end
end
x = (1:maxLen).';
end

function nMat = iComputeNBySession(T, x, groups)
nMat = zeros(numel(x), numel(groups));
for g = 1:numel(groups)
	rowsG = string(T.Group) == string(groups(g));
	for s = 1:numel(x)
		rowsS = rowsG & (double(T.Session) == s) & isfinite(double(T.Performance));
		if any(rowsS)
			nMat(s,g) = numel(unique(string(T.Mouse(rowsS))));
		end
	end
end
end

function stats = iFitMixedEffectPValue(T)
stats = struct('PGroup', nan, 'PInteraction', nan);
use = isfinite(double(T.Performance)) & isfinite(double(T.Session));
if nnz(use) < 10
	return;
end
Tbl = table(double(T.Performance(use)), double(T.Session(use)), categorical(string(T.Group(use)), ["Naive","Transfer"]), categorical(string(T.Mouse(use))), 'VariableNames', {'Performance','Session','Group','Mouse'});
lme = fitlme(Tbl, 'Performance ~ Session*Group + (1|Mouse)');
A = anova(lme);
rowG = find(string(A.Term) == "Group", 1, 'first');
rowI = find(string(A.Term) == "Session:Group", 1, 'first');
if ~isempty(rowG)
	stats.PGroup = A.pValue(rowG);
end
if ~isempty(rowI)
	stats.PInteraction = A.pValue(rowI);
end
end

function p = iLearningCurvePValue(T, pFromSummary)
p = pFromSummary;
if ~isfinite(p)
	stats = iFitMixedEffectPValue(T);
	p = stats.PGroup;
	if ~isfinite(p)
		p = stats.PInteraction;
	end
end
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
		yCells{j} = nan(0,1);
		sCells{j} = nan(0,1);
		xCells{j} = nan(0,1);
	else
		yCells{j} = y(1:last);
		sCells{j} = s(1:last);
		xCells{j} = (1:last).';
	end
end
end

function iStyleBars(barsObj, colorNaive, colorTrans)
if isscalar(barsObj)
	barsObj.FaceColor = 'flat';
	nBars = numel(barsObj.YData);
	reps = ceil(nBars/2);
	barsObj.CData = repmat([colorNaive; colorTrans], reps, 1);
	barsObj.CData = barsObj.CData(1:nBars, :);
	barsObj.BarWidth = 0.5;
	barsObj.LineWidth = 2;
	barsObj.BaseLine.LineWidth = 2;
	barsObj.EdgeColor = 'none';
	barsObj.FaceAlpha = 1;
else
	barsObj(1).FaceColor = colorNaive;
	barsObj(2).FaceColor = colorTrans;
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
