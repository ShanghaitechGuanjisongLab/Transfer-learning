% 中文图334F/G：cFos 与对照组首个训练单元分回合命中率曲线及拟合斜率

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

matPath = "\\Data-Server-2\个人数据\张天夫\202601\cFos合集.v2.mat";
DS = UniExp.DataSet(matPath);

groupOrder = ["Control", "MOp"];
groupLabels = ["Control", "cFos"];
edgeColors = TransferLearning.FigurePalette(2);

trialRows = iBuildFirstTrainingUnitTrials(DS, groupOrder);
if isempty(trialRows)
	error('Fig334FG:EmptyTrials', 'No first training-unit LightWater trials found.');
end
trialRows = sortrows(trialRows, ["Group", "Mouse", "DateTime", "Trial"]);

[meanMat, semMat, x, nMat] = iSummarizeTrialCurve(trialRows, groupOrder);

%% Fig334F: first training-unit trial curve
f = figure('Color','w', 'Name', 'Fig334F cFos first training-unit trial curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end

[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=edgeColors(1:2,:));
for p = patches(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 2;
	end
end

curveP = iLearningCurvePValue(trialRows, groupOrder);

if numel(patches) >= 2
	lg = legend(ax, patches(1:2), cellstr(groupLabels), 'Location', 'southeastoutside');
else
	lg = legend(ax, cellstr(groupLabels), 'Location', 'southeastoutside');
end
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '💡💧';
lg.Title.FontSize = 12;

title(ax, 'cFos-specific inhibition', 'FontSize', 12, 'FontWeight', 'normal');
xlabel(ax, 'Trial', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPathF = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig334F_cFos_FirstTrainingUnitTrialCurve.svg');
fprintf('Wrote: %s\n', svgPathF);
fprintf('Fig334F trial curve mixed-effect p = %.4g\n', curveP);

summaryCurve = table;
summaryCurve.Trial = x(:);
summaryCurve.ControlMean = meanMat(:,1);
summaryCurve.CFosMean = meanMat(:,2);
summaryCurve.ControlSem = semMat(:,1);
summaryCurve.CFosSem = semMat(:,2);
summaryCurve.ControlN = nMat(:,1);
summaryCurve.CFosN = nMat(:,2);
summaryCurve.PMixedEffect(:) = curveP;

%% Fig334G: per-mouse first training-unit sigmoid slope
fitTable = iFitPerMouseSigmoidSlope(trialRows, groupOrder);
controlSlope = double(fitTable.Slope(fitTable.Group == groupOrder(1)));
cfosSlope = double(fitTable.Slope(fitTable.Group == groupOrder(2)));
controlSlope = controlSlope(isfinite(controlSlope));
cfosSlope = cfosSlope(isfinite(cfosSlope));
pSlope = iRanksumSafe(controlSlope, cfosSlope);

f2 = figure('Color','none', 'Name', 'Fig334G cFos first training-unit sigmoid slope');
set(f2, 'Units', 'centimeters', 'Position', [5 5 4 4]);
set(f2, 'PaperUnits', 'centimeters', 'PaperSize', [4 4], 'PaperPositionMode', 'auto');

compareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare({controlSlope(:), cfosSlope(:)}, false, compareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
ax2.FontSize = 12;
ax2.LineWidth = 2;
ax2.Color = 'none';
ax2.XAxis.Visible = 'off';
ax2.XTick = [];
legend(ax2, 'off');

iStyleBars(bars2, edgeColors(1,:), edgeColors(2,:));
for eb = errorBars2.Object(:)'
	eb.LineWidth = 2;
end
iStylePAnnotations(optional2);
ax2.XLim = [0.5, 2.5];
ylabel(ax2, 'Sigmoid slope', 'FontSize', 12);
title(ax2, 'Fitted slope', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end

svgPathG = TransferLearning.ExportStandardFigure(f2, 2, '中文图Fig334G_cFos_FirstTrainingUnitSigmoidSlope.svg');
fprintf('Wrote: %s\n', svgPathG);
fprintf('Fig334G ranksum p = %.4g\n', pSlope);
fprintf('Control slope: %.4f ± %.4f (n=%d)\n', mean(controlSlope, 'omitnan'), std(controlSlope, 'omitnan') / sqrt(numel(controlSlope)), numel(controlSlope));
fprintf('cFos slope: %.4f ± %.4f (n=%d)\n', mean(cfosSlope, 'omitnan'), std(cfosSlope, 'omitnan') / sqrt(numel(cfosSlope)), numel(cfosSlope));

assignin('base', 'Fig334FG_FirstTrainingUnitTrial_Raw', trialRows);
assignin('base', 'Fig334F_FirstTrainingUnitTrial_Summary', summaryCurve);
assignin('base', 'Fig334G_FirstTrainingUnitSigmoidSlope', fitTable);
assignin('base', 'Fig334G_FirstTrainingUnitSigmoidSlopeP', pSlope);

function trialRows = iBuildFirstTrainingUnitTrials(DS, groupOrder)
mouseGroup = iBuildMouseGroupTable(DS, groupOrder);
T = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialIndex"], Stimulus="LightWater");
if isempty(T)
	trialRows = iEmptyTrialTable();
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Behavior = double(T.Behavior);
T.TrialIndex = double(T.TrialIndex);
T = T(T.Stimulus == "LightWater", :);
J = innerjoin(T, mouseGroup(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);
J = J(ismember(J.Group, groupOrder), :);
if isempty(J)
	trialRows = iEmptyTrialTable();
	return;
end
Sess = iSessionizeByDateTime(J(:, {'Mouse','DateTime','Behavior','Group','Phase'}));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);
firstSessions = Sess(Sess.Session == 1, {'Mouse','DateTime','Group'});
trialRows = innerjoin(J(:, {'Mouse','DateTime','Behavior','TrialIndex','Group'}), firstSessions, 'Keys', {'Mouse','DateTime','Group'});
trialRows = sortrows(trialRows, {'Group','Mouse','DateTime','TrialIndex'});
trialRows.Trial = iTrialNumberWithinSession(trialRows);
trialRows = trialRows(:, {'Mouse','DateTime','Behavior','TrialIndex','Trial','Group'});
end

function S = iBuildMouseGroupTable(DS, groupOrder)
S = DS.Mice;
if isempty(S)
	error('Fig334FG:EmptyMiceTable', 'DS.Mice is empty.');
end
if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
		error('Fig334FG:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
needVars = ["ExpressedBrain","MarkTimes"];
for k = 1:numel(needVars)
	if ~ismember(needVars(k), string(S.Properties.VariableNames))
		error('Fig334FG:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(k));
	end
end
S.Mouse = string(S.Mouse);
S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";
bad = arrayfun(@(g) nnz(char(g) == ' ') > 1, S.Group);
S = S(~bad, :);
S = S(ismember(S.Group, groupOrder), :);
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);
if isempty(S)
	error('Fig334FG:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end
end

function S = iSessionizeByDateTime(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T.Phase = string(T.Phase);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, mouseNames, dateTimes, groupNames] = findgroups(T.Mouse, T.DateTime, T.Group);
performance = splitapply(@(x) mean(x, 'omitnan'), double(T.Behavior), G);
nTrials = splitapply(@(x) sum(isfinite(x)), double(T.Behavior), G);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
S = table(mouseNames, dateTimes, performance, groupNames, nTrials, phaseSession, ...
	'VariableNames', {'Mouse','DateTime','Performance','Group','NTrials','Phase'});
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
[~, ix] = max(counts);
ph = u(ix);
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
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

function p = iLearningCurvePValue(T, groupOrder)
p = NaN;
use = isfinite(double(T.Behavior)) & isfinite(double(T.Trial));
if nnz(use) < 10
	return;
end
Tbl = table(double(T.Behavior(use)), double(T.Trial(use)), categorical(string(T.Group(use)), groupOrder), categorical(string(T.Mouse(use))), ...
	'VariableNames', {'Behavior','Trial','Group','Mouse'});
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

function fitTable = iFitPerMouseSigmoidSlope(T, groupOrder)
T = T(ismember(string(T.Group), groupOrder), :);
T = sortrows(T, {'Group','Mouse','Trial'});
[G, mice, groups] = findgroups(string(T.Mouse), string(T.Group));
nGroup = max(G);
slope = nan(nGroup, 1);
lower = nan(nGroup, 1);
midpoint = nan(nGroup, 1);
rSquared = nan(nGroup, 1);
nTrial = nan(nGroup, 1);
for i = 1:nGroup
	rows = G == i;
	xObs = double(T.Trial(rows));
	yObs = double(T.Behavior(rows));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	nTrial(i) = numel(yObs);
	if numel(yObs) < 4
		continue;
	end
	fitOut = iFitSigmoidCurve(xObs, yObs);
	slope(i) = fitOut.Slope;
	lower(i) = fitOut.Lower;
	midpoint(i) = fitOut.Midpoint;
	rSquared(i) = fitOut.RSquared;
end
fitTable = table(mice, groups, slope, lower, midpoint, rSquared, nTrial, ...
	'VariableNames', {'Mouse','Group','Slope','Lower','Midpoint','RSquared','NTrials'});
fitTable.Group = categorical(fitTable.Group, groupOrder);
end

function fitOut = iFitSigmoidCurve(xObs, yObs)
p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.3); log(max(median(xObs), 1))];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off');
p = fminsearch(obj, p0, opt);
yHat = iSigmoidFromParams(p, xObs);
sse = sum((yObs - yHat).^2, 'omitnan');
sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if sst == 0
	rSquared = NaN;
else
	rSquared = 1 - sse / sst;
end
[lower, ~, slope, midpoint] = iDecodeSigmoidParams(p);
fitOut = struct('ParamRaw', p, 'Lower', lower, 'Slope', slope, 'Midpoint', midpoint, 'SSE', sse, 'RSquared', rSquared);
end

function y = iSigmoidFromParams(p, x)
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
lower = 1 ./ (1 + exp(-p(1)));
upper = 1;
slope = exp(p(2));
midpoint = exp(p(3));
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end

function p = iRanksumSafe(xA, xB)
xA = xA(isfinite(xA));
xB = xB(isfinite(xB));
if isempty(xA) || isempty(xB)
	p = NaN;
	return;
end
p = ranksum(xA, xB);
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

function iStyleBars(barsObj, colorControl, colorCFos)
if numel(barsObj) == 1
	barsObj.FaceColor = 'flat';
	nBars = numel(barsObj.YData);
	reps = ceil(nBars/2);
	barsObj.CData = repmat([colorControl; colorCFos], reps, 1);
	barsObj.CData = barsObj.CData(1:nBars, :);
	barsObj.BarWidth = 0.5;
	barsObj.LineWidth = 2;
	barsObj.BaseLine.LineWidth = 2;
	barsObj.EdgeColor = 'none';
	barsObj.FaceAlpha = 1/3;
else
	barsObj(1).FaceColor = colorControl;
	barsObj(2).FaceColor = colorCFos;
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

function iStylePAnnotations(optional)
if isfield(optional, 'MultiCompare') && istable(optional.MultiCompare) && ismember('PText', optional.MultiCompare.Properties.VariableNames)
	for pt = optional.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end
if isfield(optional, 'MultiCompare') && istable(optional.MultiCompare) && ismember('PLine', optional.MultiCompare.Properties.VariableNames)
	for pl = optional.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
	end
end
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function T = iEmptyTrialTable()
T = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
	'VariableNames', {'Mouse','DateTime','Behavior','TrialIndex','Trial','Group'});
end