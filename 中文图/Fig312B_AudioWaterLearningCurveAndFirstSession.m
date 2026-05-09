% Fig312B：声水初始/迁移学习曲线 + 首会话条形图

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

ALB  = TransferLearning.AudioLightBaseline();
LAB  = TransferLearning.LightAudioBaseline();
ALPB = TransferLearning.ALPureBehavior();
LAPB = TransferLearning.LAPureBehavior();

naiveAnchors = ["Naive","Learned"];
tranAnchors  = ["Transfer","Final"];

naiveA = iAudioWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iAudioWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
tranA  = iAudioWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iAudioWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");

allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	error('Fig32B:EmptyData', 'No AudioWater sessions found.');
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

f = figure('Color','w', 'Name', 'Fig312B AudioWater learning curve');
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

edgeColors = TransferLearning.FigurePalette(2);
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=edgeColors(1:2,:));
for p = patches(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 2;
	end
end

curveP = iLearningCurvePValue(allSessions, PValueLS);

labels = {'Naive', 'Continual'};
if numel(patches) >= 2
	lg = legend(ax, patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(patches(1:2)));
else
	lg = legend(ax, labels, 'Location', 'best');
end
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '🔊💧';
lg.Title.FontSize = 12;

xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig312B_AudioWater_LearningCurve.svg');
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
assignin('base', 'Fig32B_AudioWaterLearningCurve_Raw', allSessions);
assignin('base', 'Fig32B_AudioWaterLearningCurve_Summary', summaryCurve);

firstSess = allSessions(allSessions.Session == 1, :);
naiveFirst = double(firstSess.Performance(string(firstSess.Group) == "Naive"));
tranFirst  = double(firstSess.Performance(string(firstSess.Group) == "Transfer"));
naiveFirst = naiveFirst(isfinite(naiveFirst));
tranFirst  = tranFirst(isfinite(tranFirst));

f2 = figure('Color','none', 'Name', 'Fig312B AudioWater first-session performance');
f2.Units = 'centimeters';
pos2 = f2.Position;
pos2(3:4) = [4,4];
f2.Position = pos2;
f2.InvertHardcopy = 'off';
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4,4];
f2.PaperPositionMode = 'auto';

tiledlayout(1,1,'TileSpacing','normal','Padding','normal');
nexttile;
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare({naiveFirst, tranFirst}, false, table([1 2], 'VariableNames', {'GroupPair'}), 'AsteriskThreshold', 0.05);
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
for eb = errorBars2.Object(:)'
	eb.LineWidth = 2;
end

iStyleBars(bars2, edgeColors(1,:), edgeColors(2,:));
ax2.XLim = [0.5, 2.5];
ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end
svgPath2 = TransferLearning.ExportStandardFigure(f2, 2, '中文图Fig312B_AudioWater_FirstSessionPerformance.svg');
fprintf('Wrote: %s\n', svgPath2);

nFirst = max(numel(naiveFirst), numel(tranFirst));
firstSessionTable = table(nan(nFirst,1), nan(nFirst,1), 'VariableNames', {'NaiveFirst','TransferFirst'});
firstSessionTable.NaiveFirst(1:numel(naiveFirst)) = naiveFirst(:);
firstSessionTable.TransferFirst(1:numel(tranFirst)) = tranFirst(:);
assignin('base', 'Fig32B_AudioWater_FirstSession', firstSessionTable);

function out = iAudioWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
T = iQueryAudioWaterBehaviorAll(DS);
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

function T = iQueryAudioWaterBehaviorAll(DS)
varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
try
	T = DS.TableQuery(varsTry, Stimulus="AudioWater");
catch
	T = DS.TableQuery(varsFallback, Stimulus="AudioWater");
end
if isempty(T)
	return;
end
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "AudioWater", :);
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
if numel(barsObj) == 1
	barsObj.FaceColor = 'flat';
	nBars = numel(barsObj.YData);
	reps = ceil(nBars/2);
	barsObj.CData = repmat([colorNaive; colorTrans], reps, 1);
	barsObj.CData = barsObj.CData(1:nBars, :);
	barsObj.BarWidth = 0.5;
	barsObj.LineWidth = 2;
	barsObj.BaseLine.LineWidth = 2;
	barsObj.EdgeColor = 'none';
	barsObj.FaceAlpha = 1/3;
else
	barsObj(1).FaceColor = colorNaive;
	barsObj(2).FaceColor = colorTrans;
	barsObj(1).LineWidth = 2;
	barsObj(2).LineWidth = 2;
	barsObj(1).BaseLine.LineWidth = 2;
	barsObj(2).BaseLine.LineWidth = 2;
	barsObj(1).EdgeColor = 'none';
	barsObj(2).EdgeColor = 'none';
	barsObj(1).FaceAlpha = 1/3;
	barsObj(2).FaceAlpha = 1/3;
end
end
