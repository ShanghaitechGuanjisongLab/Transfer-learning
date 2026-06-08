% Fig32E：光水初始/迁移首个训练单元的单试次学习曲线 + 首试次条形图

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
	error('Fig32E:EmptyData', 'No LightWater sessions found.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);
firstSessions = allSessions(allSessions.Session == 1, :);

trialRows = [
	iLightWaterTrialsForSessions(LAB,  "LightAudioBaseline", firstSessions);
	iLightWaterTrialsForSessions(LAPB, "LAPureBehavior",     firstSessions);
	iLightWaterTrialsForSessions(LAI,  "LAInterspersed",     firstSessions);
	iLightWaterTrialsForSessions(ALB,  "AudioLightBaseline", firstSessions);
	iLightWaterTrialsForSessions(ALPB, "ALPureBehavior",     firstSessions)];
if isempty(trialRows)
	error('Fig32E:EmptyTrials', 'No first training-unit LightWater trials found.');
end
trialRows = sortrows(trialRows, ["Group","Mouse","DateTime","Trial"]);

[meanMat, semMat, x, nMat] = iSummarizeTrialCurve(trialRows, ["Naive","Transfer"]);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(trialRows, 'Behavior', 'Trial', 'Group', 'Mouse');
trials7 = trialRows(trialRows.Trial <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(trials7, 'Behavior', 'Trial', 'Group', 'Mouse');

f = figure('Color','w', 'Name', 'Fig32E LightWater first training-unit trial curve');
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
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=edgeColors(1:2,:));
for p = patches(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 2;
	end
end

curveP = iLearningCurvePValue(trialRows);

% Horizontal P-value line spanning trials 1-7
max7Naive = max(meanMat(1:min(7, end), 1), [], 'omitnan');
max7Transfer = max(meanMat(1:min(7, end), 2), [], 'omitnan');
max7SemNaive = semMat(find(meanMat(1:min(7,end),1)==max7Naive,1,'first'),1);
max7SemTransfer = semMat(find(meanMat(1:min(7,end),2)==max7Transfer,1,'first'),2);
yTop7 = max(max7Naive + max7SemNaive, max7Transfer + max7SemTransfer);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
starStr = TransferLearning.Style.iFormatPText(groupP7);
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

labels = cellstr(displayGroups);
if numel(patches) >= 2
	lg = legend(ax, patches(1:2), labels, 'Location', 'southeastoutside');
else
	lg = legend(ax, labels, 'Location', 'southeastoutside');
end
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '💡💧';
lg.Title.FontSize = 12;

xlabel(ax, 'Trial', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig32E_LightWater_FirstTrainingUnitTrialCurve.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Two-way ANOVA Group P (all trials) = %.4g\n', groupP);
fprintf('Two-way ANOVA Group P (trials 1-7) = %.4g\n', groupP7);

summaryCurve = table;
summaryCurve.Trial = x(:);
summaryCurve.NaiveMean = meanMat(:,1);
summaryCurve.TransferMean = meanMat(:,2);
summaryCurve.NaiveSem = semMat(:,1);
summaryCurve.TransferSem = semMat(:,2);
summaryCurve.NaiveN = nMat(:,1);
summaryCurve.TransferN = nMat(:,2);
summaryCurve.PMixedEffect(:) = curveP;
assignin('base', 'Fig32E_LightWaterFirstTrainingUnitTrial_Raw', trialRows);
assignin('base', 'Fig32E_LightWaterFirstTrainingUnitTrial_Summary', summaryCurve);

firstTrial = trialRows(trialRows.Trial == 1, :);
naiveFirst = double(firstTrial.Behavior(firstTrial.Group == "Naive"));
tranFirst  = double(firstTrial.Behavior(firstTrial.Group == "Transfer"));
naiveFirst = naiveFirst(isfinite(naiveFirst));
tranFirst  = tranFirst(isfinite(tranFirst));

f2 = figure('Color','none', 'Name', 'Fig32E LightWater first-trial performance');
f2.Units = 'centimeters';
pos2 = f2.Position;
pos2(3:4) = [4,4];
f2.Position = pos2;
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4,4];
f2.PaperPositionMode = 'auto';

tiledlayout(1,1,'TileSpacing','tight','Padding','tight');
nexttile;
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare({naiveFirst, tranFirst}, UniExp.Flags.empty, table([1 2], 'VariableNames', {'GroupPair'}), 'AsteriskThreshold', 1);
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
if isfield(optional2, 'MultiCompare') && ismember('PLine', optional2.MultiCompare.Properties.VariableNames)
	for pl = optional2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
		pl.Tag = 'PLine';
	end
end
if isfield(optional2, 'MultiCompare') && ismember('PText', optional2.MultiCompare.Properties.VariableNames)
	for pt = optional2.MultiCompare.PText(:)'
		pt.Tag = 'PText';
	end
end
TransferLearning.Style.SetBarPValues(optional2);

iStyleBars(bars2, edgeColors(1,:), edgeColors(2,:));
iKeepUpperErrorBarOnly(ax2, errorBars2, bars2, edgeColors(1,:), edgeColors(2,:));
ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First trial', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end
svgPath2 = TransferLearning.ExportStandardFigureTransparent(f2, 2, '中文图Fig32E_LightWater_FirstTrialPerformance.svg');
fprintf('Wrote: %s\n', svgPath2);
fprintf('\n=== Fig32E first-trial bar ===\n');
fprintf('Naive mice n = %d\n', numel(naiveFirst));
fprintf('Continual mice n = %d\n', numel(tranFirst));
fprintf('First-trial bar P (BarScatterCompare): %s\n', ...
	TransferLearning.Style.iFormatPText(optional2.MultiCompare.PValue(1)));

nFirst = max(numel(naiveFirst), numel(tranFirst));
firstTrialTable = table(nan(nFirst,1), nan(nFirst,1), 'VariableNames', {'NaiveFirst','TransferFirst'});
firstTrialTable.NaiveFirst(1:numel(naiveFirst)) = naiveFirst(:);
firstTrialTable.TransferFirst(1:numel(tranFirst)) = tranFirst(:);
firstTrialTable.BarPValue = repmat(optional2.MultiCompare.PValue(1), nFirst, 1);
assignin('base', 'Fig32E_LightWater_FirstTrial', firstTrialTable);

function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
T = iQueryLightWaterTrialsAll(DS);
if isempty(T)
	out = iEmptySessionTable();
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
T = iQueryLightWaterTrialsAll(DS);
if isempty(T)
	out = iEmptySessionTable();
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

function T = iQueryLightWaterTrialsAll(DS)
T = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialIndex"], Stimulus="LightWater");
if isempty(T)
	return;
end
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "LightWater", :);
end

function out = iLightWaterTrialsForSessions(DS, sourceName, sessions)
out = iEmptyTrialTable();
sessions = sessions(sessions.Source == string(sourceName), :);
if isempty(sessions)
	return;
end
T = iQueryLightWaterTrialsAll(DS);
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Source = repmat(string(sourceName), height(T), 1);
T.Behavior = double(T.Behavior);
T.TrialIndex = double(T.TrialIndex);
S = sessions(:, {'Mouse','DateTime','Source','Group'});
S.Mouse = string(S.Mouse);
S.Source = string(S.Source);
S.Group = string(S.Group);
S.DateTime = iNormalizeDateTime(S.DateTime);
out = innerjoin(T(:, {'Mouse','DateTime','Behavior','TrialIndex','Source'}), S, 'Keys', {'Mouse','DateTime','Source'});
out = sortrows(out, {'Group','Mouse','DateTime','TrialIndex'});
out = out(:, {'Mouse','DateTime','Behavior','TrialIndex','Source','Group'});
out.Trial = iTrialNumberWithinSession(out);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function S = iSessionizeByDateTime(T)
T = T(:, {'Mouse','DateTime','Behavior','Phase'});
T.Mouse = string(T.Mouse);
if ~ismember('Phase', T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
T = sortrows(T, {'Mouse','DateTime'});
val = double(T.Behavior);
[G, mouseNames, dateTimes] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
S = table(mouseNames, dateTimes, perf, nBlocks, phaseSession, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
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
	error('Fig32E:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.', char(string(groupName)));
end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
[G, mice] = findgroups(T.Mouse);
nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
dup = mice(nG > 1);
if ~isempty(dup)
	error('Fig32E:MouseInMultipleGroups', 'Some mice appear in multiple groups.');
end
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

function trialNumber = iTrialNumberWithinSession(T)
[G, ~] = findgroups(T.Group, T.Mouse, T.DateTime);
trialCell = splitapply(@(x) {(1:numel(x))'}, T.TrialIndex, G);
trialNumber = vertcat(trialCell{:});
end

function [meanMat, semMat, x, nMat] = iSummarizeTrialCurve(T, groupOrder)
groupOrder = string(groupOrder);
maxTrial = max(double(T.Trial), [], 'omitnan');
x = (1:maxTrial).';
meanMat = nan(maxTrial, numel(groupOrder));
semMat = nan(maxTrial, numel(groupOrder));
nMat = zeros(maxTrial, numel(groupOrder));
for iGroup = 1:numel(groupOrder)
	for iTrial = 1:maxTrial
		rows = T.Group == groupOrder(iGroup) & double(T.Trial) == iTrial;
		vals = double(T.Behavior(rows));
		vals = vals(isfinite(vals));
		if isempty(vals)
			continue;
		end
		meanMat(iTrial, iGroup) = mean(vals);
		semMat(iTrial, iGroup) = std(vals) / sqrt(numel(vals));
		nMat(iTrial, iGroup) = numel(unique(string(T.Mouse(rows))));
	end
end
end

function p = iLearningCurvePValue(T)
p = NaN;
use = isfinite(double(T.Behavior)) & isfinite(double(T.Trial));
if nnz(use) < 10
	return;
end
Tbl = table(double(T.Behavior(use)), double(T.Trial(use)), categorical(string(T.Group(use)), ["Naive","Transfer"]), categorical(string(T.Mouse(use))), 'VariableNames', {'Behavior','Trial','Group','Mouse'});
lme = fitlme(Tbl, 'Behavior ~ Trial*Group + (1|Mouse)');
A = anova(lme);
rowG = find(string(A.Term) == "Group", 1, 'first');
rowI = find(string(A.Term) == "Trial:Group", 1, 'first');
if ~isempty(rowG)
	p = A.pValue(rowG);
end
if ~isfinite(p) && ~isempty(rowI)
	p = A.pValue(rowI);
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

function iKeepUpperErrorBarOnly(ax, errorBars, barsObj, colorNaive, colorTransfer)
spec = iBarSpecs(barsObj, colorNaive, colorTransfer);
for eb = errorBars.Object(:)'
	if ~isgraphics(eb)
		continue;
	end
	if ~isprop(eb, 'XData') || ~isprop(eb, 'YData') || ~isprop(eb, 'YPositiveDelta')
		continue;
	end
	x = eb.XData(:);
	y = eb.YData(:);
	up = eb.YPositiveDelta(:);
	delete(eb);
	capWidth = 0.32;
	valid = isfinite(x) & isfinite(y) & isfinite(up) & up > 0;
	for i = find(valid)'
		color = iColorForBarX(x(i), spec, colorNaive);
		v = line(ax, [x(i) x(i)], [y(i) y(i) + up(i)], 'Color', color, 'LineWidth', 2, 'HandleVisibility', 'off');
		h = line(ax, [x(i) - capWidth/2 x(i) + capWidth/2], [y(i) + up(i) y(i) + up(i)], 'Color', color, 'LineWidth', 2, 'HandleVisibility', 'off');
		setappdata(v, 'TransferLearningPreserveLineWidth', true);
		setappdata(h, 'TransferLearningPreserveLineWidth', true);
	end
end
end

function spec = iBarSpecs(barsObj, colorNaive, colorTransfer)
if isscalar(barsObj)
	if isprop(barsObj, 'XEndPoints')
		x = barsObj.XEndPoints(:);
	else
		x = (1:numel(barsObj.YData))';
	end
	nBar = numel(x);
	colors = repmat([colorNaive; colorTransfer], ceil(nBar / 2), 1);
	colors = colors(1:nBar, :);
else
	x = nan(numel(barsObj), 1);
	for i = 1:numel(barsObj)
		if isprop(barsObj(i), 'XEndPoints') && ~isempty(barsObj(i).XEndPoints)
			x(i) = barsObj(i).XEndPoints(1);
		else
			x(i) = i;
		end
	end
	colors = [colorNaive; colorTransfer];
	colors = colors(1:numel(x), :);
end
spec = table(x, colors, 'VariableNames', {'X', 'Color'});
end

function color = iColorForBarX(x, spec, fallback)
if isempty(spec)
	color = fallback;
	return;
end
[~, idx] = min(abs(spec.X - x));
color = spec.Color(idx, :);
end

function out = iEmptySessionTable()
out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
end

function out = iEmptyTrialTable()
out = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), strings(0,1), strings(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Behavior','TrialIndex','Source','Group','Trial'});
end
