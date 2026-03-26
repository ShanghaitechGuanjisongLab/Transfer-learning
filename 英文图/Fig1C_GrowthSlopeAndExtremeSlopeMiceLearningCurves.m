% English Fig1C (merged from Fig1D + Fig1M): growth slope + extreme slope mice curves
%
% This script outputs TWO SVG figures, both labeled as panel C:
%   1) Growth slope comparison (formerly Fig1D)
%   2) Extreme slope mice learning curves (formerly Fig1M)
%
% Cohorts (consistent with Fig1B/D/M):
% - Naive 组：LightAudioBaseline + LAInterspersed + LAPureBehavior
% - Transfer 组：AudioLightBaseline + ALPureBehavior
%
% Hard constraints:
% - Session performance computed from Trials where Stimulus=="LightWater".
% - Trajectories span between Phase tags:
%     Naive:    Naive -> Learned
%     Transfer: Transfer -> Final
% - Exclude LAInterspersed mice whose Naive blocks mix AudioWater trials.
% - Export SVG only to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution (hard requirements):
% - This file MUST remain a SCRIPT.
% - Do NOT use run.
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
LAB  = TransferLearning.LightAudioBaseline();
LAI  = TransferLearning.LAInterspersed();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();

% --- 2) Build trajectories between phase tags (LightWater-only perf from Trials)
naiveA = iLightWaterTrajectoryBetweenPhases(LAB,  "LightAudioBaseline", true,  "Naive",    "Learned", strings(0,1));
naiveB = iLightWaterTrajectoryBetweenPhases_LAInterspersed(LAI, "LAInterspersed", true,  "Naive",    "Learned");
naiveC = iLightWaterTrajectoryBetweenPhases(LAPB, "LAPureBehavior",     false, "Naive",    "Learned", strings(0,1));

tranA  = iLightWaterTrajectoryBetweenPhases(ALB,  "AudioLightBaseline", true,  "Transfer", "Final",  strings(0,1));
tranB  = iLightWaterTrajectoryBetweenPhases(ALPB, "ALPureBehavior",     false, "Transfer", "Final",  strings(0,1));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");
allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);

if isempty(allSessions)
	warning('English_Fig1C:EmptyData', '%s', 'No LightWater sessions found.');
	return;
end

allSessions = sortrows(allSessions, {'Group','Mouse','DateTime'});
allSessions = iAddSessionIndex(allSessions);
allSessions = iAddBaselinePerf(allSessions);

%% --- C-1) Growth slope comparison (derived from D_GrowthSlope.m)
if ~exist('fitlme','file')
	warning('English_Fig1C:MissingFitLME', 'fitlme unavailable; skipping growth-slope mixed-effects model (still plotting residualized slopes).');
end

% Fit mixed-effects model (reference only; plot uses per-mouse slopes)
try
	mdlT = allSessions(:, {'Mouse','Group','Session','Performance','BaselinePerf'});
	mdlT.Mouse = categorical(string(mdlT.Mouse));
	mdlT.Group = categorical(string(mdlT.Group));
	mdlT.Session = double(mdlT.Session);
	mdlT.Performance = double(mdlT.Performance);
	mdlT.BaselinePerf = double(mdlT.BaselinePerf);
	keep = isfinite(mdlT.Session) & isfinite(mdlT.Performance) & isfinite(mdlT.BaselinePerf);
	mdlT = mdlT(keep, :);
	formula = 'Performance ~ 1 + Session + Group + Session:Group + BaselinePerf + Session:BaselinePerf + (1+Session|Mouse)';
	if exist('fitlme','file') && ~isempty(mdlT)
		lme = fitlme(mdlT, formula); %#ok<NASGU>
	end
catch
end

% Per-mouse slope and baseline-adjusted slope
perMouseFull = iPerMouseSlope(allSessions);
perMouseFull.SlopeAdj = nan(height(perMouseFull), 1);
okAdj = isfinite(perMouseFull.Slope) & isfinite(perMouseFull.BaselinePerf);
if any(okAdj)
	if exist('robustfit','file')
		b = robustfit(double(perMouseFull.BaselinePerf(okAdj)), double(perMouseFull.Slope(okAdj)));
		perMouseFull.SlopeAdj(okAdj) = double(perMouseFull.Slope(okAdj)) - (b(1) + b(2) * double(perMouseFull.BaselinePerf(okAdj)));
	else
		adjMdl = fitlm(perMouseFull(okAdj, :), 'Slope ~ 1 + BaselinePerf');
		perMouseFull.SlopeAdj(okAdj) = adjMdl.Residuals.Raw;
	end
end

% Use raw slopes for bar chart (always positive), ANCOVA p for significance
xNaiveRaw = perMouseFull.Slope(string(perMouseFull.Group) == "Naive");
xTranRaw  = perMouseFull.Slope(string(perMouseFull.Group) == "Transfer");
xNaiveRaw = xNaiveRaw(isfinite(xNaiveRaw));
xTranRaw  = xTranRaw(isfinite(xTranRaw));

% ANCOVA: Slope ~ 1 + Group + BaselinePerf (p-value for Group effect)
pAnnot = nan;
Tm = perMouseFull(:, {'Mouse','Group','Slope','BaselinePerf'});
Tm.Mouse = categorical(string(Tm.Mouse));
Tm.Group = categorical(string(Tm.Group));
Tm.Slope = double(Tm.Slope);
Tm.BaselinePerf = double(Tm.BaselinePerf);
okM = isfinite(Tm.Slope) & isfinite(Tm.BaselinePerf) & ~isundefined(Tm.Group);
Tm = Tm(okM, :);
if ~isempty(Tm)
	lmSimple = fitlm(Tm, 'Slope ~ 1 + Group + BaselinePerf');
	C = lmSimple.Coefficients;
	idx = find(strcmp(string(C.Properties.RowNames), 'Group_Transfer'), 1);
	if isempty(idx)
		idx = find(startsWith(string(C.Properties.RowNames), 'Group_'), 1);
	end
	if ~isempty(idx)
		pAnnot = C.pValue(idx);
	end
end

Groups = struct('Naive', {xNaiveRaw(:)}, 'Trans', {xTranRaw(:)});

%%
f1 = figure('Color','none', 'Name', 'English Fig1C Growth slope');
set(f1, 'InvertHardcopy', 'off');
set(f1, 'Units', 'centimeters', 'Position', [5 5 4 4]);
set(f1, 'PaperUnits', 'centimeters', 'PaperSize', [4 4], 'PaperPositionMode', 'auto');
[~, ~, Bars, ErrorBars] = UniExp.BarScatterCompare(Groups, false);
ax=gca;

ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
ax.XAxis.Visible = 'off';
ax.XTick = [];

for b = Bars(:)'
	b.LineWidth = 2;
	b.EdgeColor = 'none';
end
for eb = ErrorBars.Object(:)'
	eb.LineWidth = 2;
end

palette2 = TransferLearning.FigurePalette(2);
colorNaive = palette2(1,:);
colorTrans = palette2(2,:);
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = [colorNaive; colorTrans];
	Bars.BarWidth = 0.5;
	Bars.FaceAlpha = 1/3;
end
ax.XLim = [0.5, 2.5];
title('Learning slope', 'FontSize', 12, 'FontWeight', 'normal');


% P-line annotation (asterisk) using ANCOVA p-value
if isfinite(pAnnot) && pAnnot < 0.05 && height(ErrorBars) >= 1
	Descriptors = table(ErrorBars.Object(1), "*", ...
		'VariableNames', {'ObjectA','Text'});
	PL = MATLAB.Graphics.PLine(Descriptors);
	for pl = PL(:)'
		pl.LineWidth = 2;
	end
end
box off

% Export SVG
try
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end
svgPath1 = fullfile(outDirUNC, 'English_Fig1C_GrowthSlope.svg');
try
	TransferLearning.PrintFigure(f1, svgPath1, ForceLegendOrColorbar=true);
	fprintf('Wrote: %s\n', svgPath1);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- C-2) Extreme slope mice learning curves (derived from M_ExtremeSlopeMiceLearningCurves.m)

allSessionsSlope = iTrimAtCeiling_ExcludeFirstCeiling(allSessions);
allSessionsPlot  = iTrimAfterCeiling_KeepFirstCeiling(allSessions);

if isempty(allSessionsSlope)
	warning('English_Fig1C:EmptySlopeAfterCeilingTrim', '%s', 'All sessions removed by slope ceiling-trim; skip extreme-mice plot.');
	return;
end
if isempty(allSessionsPlot)
	warning('English_Fig1C:EmptyPlotAfterCeilingTrim', '%s', 'All sessions removed by plot ceiling-trim; skip extreme-mice plot.');
	return;
end

allSessionsSlope = sortrows(allSessionsSlope, {'Group','Mouse','DateTime'});
allSessionsSlope = iAddSessionIndex(allSessionsSlope);
allSessionsSlope = iAddBaselinePerf(allSessionsSlope);

allSessionsPlot = sortrows(allSessionsPlot, {'Group','Mouse','DateTime'});
allSessionsPlot = iAddSessionIndex(allSessionsPlot);

perMouse = iPerMouseSlope(allSessionsSlope);
perMouse.SlopeAdj = nan(height(perMouse), 1);
okAdj = isfinite(perMouse.Slope) & isfinite(perMouse.BaselinePerf);
if any(okAdj)
	if exist('robustfit','file')
		b = robustfit(double(perMouse.BaselinePerf(okAdj)), double(perMouse.Slope(okAdj)));
		perMouse.SlopeAdj(okAdj) = double(perMouse.Slope(okAdj)) - (b(1) + b(2) * double(perMouse.BaselinePerf(okAdj)));
	else
		adjMdl = fitlm(perMouse(okAdj, :), 'Slope ~ 1 + BaselinePerf');
		perMouse.SlopeAdj(okAdj) = adjMdl.Residuals.Raw;
	end
end

ok = isfinite(perMouse.SlopeAdj);
if ~any(ok)
	warning('English_Fig1C:NoFiniteSlopeAdj', '%s', 'No finite SlopeAdj values after ceiling trim; skip extreme-mice plot.');
	return;
end

% Select two mice with identical first-session performance and max slope difference
okBase = isfinite(perMouse.BaselinePerf);
okSel = ok & okBase;
if nnz(okSel) < 2
	warning('English_Fig1C:NotEnoughMiceAfterBaselineFilter', 'Need >=2 mice with finite SlopeAdj and BaselinePerf, got %d.', nnz(okSel));
	return;
end

baseVals = double(perMouse.BaselinePerf(okSel));
slopeVals = double(perMouse.SlopeAdj(okSel));
idxOk = find(okSel);

uBase = unique(baseVals);
bestDiff = -inf;
bestPair = [];
for i = 1:numel(uBase)
	rows = find(baseVals == uBase(i));
	if numel(rows) < 2
		continue;
	end
	[~, iMinLocal] = min(slopeVals(rows));
	[~, iMaxLocal] = max(slopeVals(rows));
	idxMinLocal = rows(iMinLocal);
	idxMaxLocal = rows(iMaxLocal);
	diffLocal = slopeVals(idxMaxLocal) - slopeVals(idxMinLocal);
	if diffLocal > bestDiff
		bestDiff = diffLocal;
		bestPair = idxOk([idxMaxLocal idxMinLocal]);
	end
end

if isempty(bestPair)
	warning('English_Fig1C:NoBaselineMatchedPair', 'No baseline-matched pair found (need >=2 mice with identical first-session performance).');
	return;
end

mouseMax = string(perMouse.Mouse(bestPair(1)));
mouseMin = string(perMouse.Mouse(bestPair(2)));

f2 = figure('Color','w', 'Name', 'English Fig1C Extreme slope mice learning curves');
f2.Units = "centimeters";
f2.Position(3:4) = [12, 8];
ax2=gca;
hold(ax2, 'on');
cols = [colorTrans; colorNaive];

iPlotMouseCurve(ax2, allSessionsPlot, mouseMax, cols(1,:), "A transfer mouse");
iPlotMouseCurve(ax2, allSessionsPlot, mouseMin, cols(2,:), "A naive mouse");

xlabel(ax2, 'Block');
ylabel(ax2, 'Hit rate');
box(ax2, 'off');
grid(ax2, 'off');
ax2.FontSize = 12;
xlabel(ax2, 'Block', 'FontSize', 12);
ylabel(ax2, 'Hit rate', 'FontSize', 12);
legend(ax2, 'Location','northeastoutside', 'FontSize', 12);

svgPath2 = fullfile(outDirUNC, 'English_Fig1C_ExtremeSlopeMiceLearningCurves.svg');
try
	TransferLearning.PrintFigure(f2, svgPath2, ForceLegendOrColorbar=true);
	fprintf('Wrote: %s\n', svgPath2);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers (merged minimally from Fig1D/Fig1M)
function iPlotMouseCurve(ax, allSessions, mouseId, col, displayName)
rows = string(allSessions.Mouse) == string(mouseId);
Sm = allSessions(rows, :);
Sm = sortrows(Sm, 'Session');
if nargin < 5 || strlength(string(displayName)) == 0
	displayName = string(mouseId);
end
plot(ax, double(Sm.Session), double(Sm.Performance), '-o', 'Color', col, 'LineWidth', 1, 'MarkerSize', 4, 'DisplayName', char(displayName));
end

function out = iLightWaterTrajectoryBetweenPhases(DS, sourceName, imagingCohort, startPhase, endPhase, excludeMice)
if nargin < 6 || isempty(excludeMice)
	excludeMice = strings(0,1);
end
excludeMice = string(excludeMice);
startPhase = string(startPhase);
endPhase = string(endPhase);

Tblk = iQueryAllBlocksWithLWPerf(DS);
if isempty(Tblk)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
	return;
end

Tblk.Mouse = string(Tblk.Mouse);
Tblk.Phase = string(Tblk.Phase);
Tblk.DateTime = iNormalizeDateTime(Tblk.DateTime);
Tblk = Tblk(~ismember(Tblk.Mouse, excludeMice), :);
if isempty(Tblk)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
	return;
end

Sess = iSessionizeByDateTime(Tblk(:, {'Mouse','DateTime','Performance','BlockUID'}));
Sess.Mouse = string(Sess.Mouse);
Sess.DateTime = iNormalizeDateTime(Sess.DateTime);

mice = unique(Tblk.Mouse);
keepRows = false(height(Sess), 1);
for i = 1:numel(mice)
	m = mice(i);
	blkM = Tblk(Tblk.Mouse == m, :);
	startDT = min(blkM.DateTime(blkM.Phase == startPhase));
	endDT = max(blkM.DateTime(blkM.Phase == endPhase));
	if isempty(startDT) || isempty(endDT) || any(ismissing([startDT endDT]))
		continue;
	end
	if endDT < startDT
		continue;
	end
	rows = (Sess.Mouse == m) & (Sess.DateTime >= startDT) & (Sess.DateTime <= endDT);
	keepRows = keepRows | rows;
end

Sess = Sess(keepRows, :);
Sess.Source = repmat(string(sourceName), height(Sess), 1);
Sess.ImagingCohort = repmat(logical(imagingCohort), height(Sess), 1);
out = Sess(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function out = iLightWaterTrajectoryBetweenPhases_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
badMice = iFindMiceWithAudioWaterInPhase(DS, startPhase);
if ~isempty(badMice)
	fprintf('English Fig1C: LAInterspersed excluded %d mice with AudioWater mixed into %s phase.\n', numel(badMice), char(string(startPhase)));
end
out = iLightWaterTrajectoryBetweenPhases(DS, sourceName, imagingCohort, startPhase, endPhase, badMice);
end

function dt = iNormalizeDateTime(dt)
try
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end

function Tblk = iQueryAllBlocksWithLWPerf(DS)
vars = ["Mouse","DateTime","BlockUID","Phase"];
try
	Tblk = DS.TableQuery(vars);
catch ME
	error('English_Fig1C:BlockQueryFailed', 'Block query failed for %s: %s', class(DS), ME.message);
end
if isempty(Tblk)
	Tblk = table();
	return;
end
if ~isprop(DS, 'Trials')
	error('English_Fig1C:MissingTrials', 'DataSet %s has no Trials; cannot compute LightWater-only performance.', class(DS));
end
Tr = DS.Trials;
need = {'BlockUID','Stimulus','Behavior'};
if ~all(ismember(need, Tr.Properties.VariableNames))
	error('English_Fig1C:TrialsMissingFields', 'Trials table for %s lacks required fields: %s', class(DS), strjoin(setdiff(need, Tr.Properties.VariableNames), ','));
end

TrStim = string(Tr.Stimulus);
TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Tblk = table();
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

blkUID64 = uint64(Tblk.BlockUID);
[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
Tblk = Tblk(tf, :);
if isempty(Tblk)
	Tblk = table();
	return;
end
Tblk.Performance = perfByBlock.LWPerf(loc(tf));
end

function T = iSessionizeByDateTime(T)
T.DateTime = datetime(T.DateTime);
T.DateTime.TimeZone = '';
[G, mouse, dt] = findgroups(string(T.Mouse), T.DateTime);
perf = splitapply(@(x) mean(x,'omitnan'), double(T.Performance), G);
nBlocks = splitapply(@numel, double(T.Performance), G);
T = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
try
	T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
catch ME
	error('English_Fig1C:PurePhaseQueryFailed', 'Query failed for %s: %s', class(DS), ME.message);
end
if isempty(T)
	badMice = strings(0,1);
	return;
end
if ~isprop(DS, 'Trials')
	error('English_Fig1C:MissingTrials', 'DataSet %s has no Trials; cannot detect AudioWater mixing.', class(DS));
end
Tr = DS.Trials;
if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
	error('English_Fig1C:TrialsMissingFields', 'Trials table for %s lacks Stimulus/BlockUID.', class(DS));
end
Tr.Stimulus = string(Tr.Stimulus);

T.Mouse = string(T.Mouse);
mice = unique(T.Mouse);
bad = false(size(mice));

for i = 1:numel(mice)
	m = mice(i);
	rowsM = (T.Mouse == m);
	bu = unique(uint64(T.BlockUID(rowsM)));
	hasAudio = false;
	for bi = 1:numel(bu)
		b = bu(bi);
		trB = (uint64(Tr.BlockUID) == b);
		stimB = Tr.Stimulus(trB);
		if ~any(stimB == "LightWater")
			continue;
		end
		if any(stimB == "AudioWater")
			hasAudio = true;
			break;
		end
	end
	bad(i) = hasAudio;
end

badMice = mice(bad);
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
T.Session = zeros(height(T), 1);
ug = unique(G);
for gi = 1:numel(ug)
	rows = (G == ug(gi));
	T.Session(rows) = (1:sum(rows)).';
end
end

function T = iAddBaselinePerf(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','Session'});
T.BaselinePerf = nan(height(T), 1);
[G, ~] = findgroups(T.Group, T.Mouse);
ug = unique(G);
for gi = 1:numel(ug)
	rows = (G == ug(gi));
	p = double(T.Performance(rows));
	b0 = p(1);
	if ~isfinite(b0)
		b0 = mean(p, 'omitnan');
	end
	T.BaselinePerf(rows) = b0;
end
end

function perMouse = iPerMouseSlope(allSessions)
T = allSessions;
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','Session'});

[mice, ~, g] = unique(T.Mouse);
group = strings(numel(mice), 1);
slope = nan(numel(mice), 1);
nSess = nan(numel(mice), 1);
baselinePerf = nan(numel(mice), 1);

for i = 1:numel(mice)
	rows = (g == i);
	group(i) = string(T.Group(find(rows, 1, 'first')));
	x = double(T.Session(rows));
	y = double(T.Performance(rows));
	b0 = y(1);
	if ~isfinite(b0)
		b0 = mean(y, 'omitnan');
	end
	baselinePerf(i) = b0;
	ok = isfinite(x) & isfinite(y);
	x = x(ok);
	y = y(ok);
	nSess(i) = numel(x);
	if numel(x) < 2
		continue;
	end
	p = polyfit(x, y, 1);
	slope(i) = p(1);
end

perMouse = table(mice, group, slope, nSess, baselinePerf, 'VariableNames', {'Mouse','Group','Slope','NSessions','BaselinePerf'});
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Source = string(T.Source);

U = unique(T(:, {'Mouse','Source'}));
[mice, ~, g] = unique(string(U.Mouse));
nSrc = splitapply(@(x) numel(unique(x)), string(U.Source), g);
bad = mice(nSrc > 1);
if isempty(bad)
	return;
end

msgLines = strings(numel(bad), 1);
for idx = 1:numel(bad)
	m = bad(idx);
	src = unique(string(U.Source(string(U.Mouse) == m)));
	msgLines(idx) = m + " -> " + strjoin(src, ", ");
end

error('English_Fig1C:DuplicateMouseAcrossSources', ...
	'Duplicate mouse IDs across sources in group %s:\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
end

function iAssertNoMouseAppearsInMultipleGroups(T)
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);

[mice, ~, g] = unique(T.Mouse);
ng = splitapply(@(x) numel(unique(x)), T.Group, g);
bad = mice(ng > 1);
if isempty(bad)
	return;
end
msgLines = strings(numel(bad), 1);
for i = 1:numel(bad)
	m = bad(i);
	gs = unique(T.Group(T.Mouse == m));
	msgLines(i) = m + " -> " + strjoin(gs, ", ");
end
error('English_Fig1C:MouseInMultipleGroups', 'Some mice appear in multiple groups (Naive/Transfer):\n%s', char(strjoin(msgLines, newline)));
end

function T = iTrimAtCeiling_ExcludeFirstCeiling(T)
% For slope calculation:
% For each mouse, exclude the first Performance==1 session and any later sessions.
if isempty(T)
	return;
end

oneTol = 1 - 1e-12;

T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Performance = double(T.Performance);
T = sortrows(T, {'Group','Mouse','DateTime'});

[G, ~] = findgroups(T.Group, T.Mouse);
ug = unique(G);
out = cell(numel(ug), 1);

for gi = 1:numel(ug)
	rows = (G == ug(gi));
	S = T(rows, :);
	S = sortrows(S, 'DateTime');
	p = double(S.Performance);
	if isempty(p)
		continue;
	end
	i100 = find(isfinite(p) & (p >= oneTol), 1, 'first');
	if ~isempty(i100)
		S = S(1:i100-1, :);
	end
	if height(S) < 2
		continue;
	end
	out{gi} = S;
end

out = out(~cellfun('isempty', out));
if isempty(out)
	T = table();
	return;
end
T = vertcat(out{:});
T = sortrows(T, {'Group','Mouse','DateTime'});
end

function T = iTrimAfterCeiling_KeepFirstCeiling(T)
% For plotting:
% For each mouse, keep sessions up to and including the first Performance==1 session,
% but exclude any sessions after it.
if isempty(T)
	return;
end

oneTol = 1 - 1e-12;

T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Performance = double(T.Performance);
T = sortrows(T, {'Group','Mouse','DateTime'});

[G, ~] = findgroups(T.Group, T.Mouse);
ug = unique(G);
out = cell(numel(ug), 1);

for gi = 1:numel(ug)
	rows = (G == ug(gi));
	S = T(rows, :);
	S = sortrows(S, 'DateTime');
	p = double(S.Performance);
	if isempty(p)
		continue;
	end
	i100 = find(isfinite(p) & (p >= oneTol), 1, 'first');
	if ~isempty(i100)
		S = S(1:i100, :);
	end
	if height(S) < 1
		continue;
	end
	out{gi} = S;
end

out = out(~cellfun('isempty', out));
if isempty(out)
	T = table();
	return;
end
T = vertcat(out{:});
T = sortrows(T, {'Group','Mouse','DateTime'});
end
