%% Fig1G_DivergenceVsSlope_Scatter.m
% English Fig1G: per-mouse divergence vs sigmoid learning slope (pooled layers).
%
% Question: does inter-trial divergence explain learning SPEED? Expected
% answer: no (non-significant correlation), complementing panel F where
% divergence correlates with first-block hit rate (learning START).
%
% Divergence: identical pipeline to 英文图/Fig1F_DivVsHitRate_Scatter.m
%   (first pure-LightWater block per mouse, 1 s sample, all cells,
%   sqrt(trial-noise / signal), QueryNTS ZScore baseline 1:24).
%   Naive = LAB + LAI (LAI mice with AudioWater in Naive phase excluded),
%   Transfer = ALB.
% Slope: identical pipeline to 英文图/Fig1H_SlopeVsHeterogeneity.m
%   (per-mouse sigmoid fit of block hit rate over LightWater blocks;
%   naive anchors Naive->Learned, transfer anchors Transfer->Final).
%   Slopes are computed from the SAME mice's imaging-block behavior data.

if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok0 || ~ok1s
	error('Fig1G:TimeIndexMissing', 'Cannot find 0 s or 1 s sample in TransferLearning.Xs.');
end

%% 1. Per-mouse divergence (first LightWater block; same as Fig1F)
naiveA = iCollectNaiveFirstBlockData(LAB, "LightAudioBaseline", strings(0, 1), idx0, idx1s);
badNaiveLai = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
naiveB = iCollectNaiveFirstBlockData(LAI, "LAInterspersed", badNaiveLai, idx0, idx1s);
naive = [naiveA; naiveB];

transfer = iCollectTransferFirstBlockData(ALB, idx0, idx1s);

DivData = [naive; transfer];
DivData.Group = categorical(string(DivData.Group), ["Naive", "Transfer"]);

%% 2. Per-mouse sigmoid slope over LightWater blocks (same cohort as above)
naiveAnchors = ["Naive", "Learned"];
transferAnchors = ["Transfer", "Final"];
naiveSessA = iLightWaterBlocksByMouse(LAB, "LightAudioBaseline", naiveAnchors(1), naiveAnchors(2));
naiveSessB = iLightWaterBlocksByMouse_LAInterspersed(LAI, "LAInterspersed", naiveAnchors(1), naiveAnchors(2));
transferSess = iLightWaterBlocksByMouse(ALB, "AudioLightBaseline", transferAnchors(1), transferAnchors(2));
naiveSess = [naiveSessA; naiveSessB];
naiveSess.Group(:) = "Naive";
transferSess.Group(:) = "Transfer";
iAssertNoCrossSourceDuplicateMice(naiveSess, "Naive");
iAssertNoMouseAppearsInMultipleGroups([naiveSess; transferSess]);
allBlocks = [naiveSess; transferSess];
allBlocks = sortrows(allBlocks, ["Group", "Mouse", "DateTime"]);
allBlocks = iAddBlockIndex(allBlocks);
FitTbl = iFitSigmoidPerMouse(allBlocks);
if isempty(FitTbl)
	error('Fig1G:NoFits', 'No per-mouse sigmoid fit could be computed.');
end

%% 3. Join divergence + slope per mouse
DivData.Mouse = string(DivData.Mouse);
FitTbl.Mouse = string(FitTbl.Mouse);
[~, loc] = ismember(DivData.Mouse, FitTbl.Mouse);
DivData.Slope = nan(height(DivData), 1);
has = loc > 0;
DivData.Slope(has) = FitTbl.Slope(loc(has));
DivData = DivData(has & isfinite(DivData.Divergence) & isfinite(DivData.Slope), :);
if height(DivData) < 3
	error('Fig1G:TooFewMice', 'Fewer than 3 mice with both divergence and slope.');
end

%% 4. Correlation + figure
colorNaive = TransferLearning.NaiveColor;
colorTransfer = TransferLearning.TransferColor;
colorFit = TransferLearning.ColorA;

xAll = double(DivData.Divergence);
yAll = double(DivData.Slope);
if std(xAll) <= 0 || std(yAll) <= 0
	error('Fig1G:ZeroVariance', 'All mice have zero variance for correlation.');
end
[rho, p] = corr(xAll, yAll, 'Type', 'Spearman');
maskNaive = string(DivData.Group) == "Naive";
maskTran = string(DivData.Group) == "Transfer";
fprintf('\n=== Fig1G Divergence vs Sigmoid slope ===\n');
fprintf('Naive mice: %d | Transfer mice: %d | total: %d\n', nnz(maskNaive), nnz(maskTran), height(DivData));
fprintf('Spearman r=%.3f, p=%.4g\n', rho, p);
%% 

f = figure('Color', 'w', 'Name', 'English Fig1G Divergence vs Sigmoid slope');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];

tl = tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
xl = xlabel(tl, 'Divergence');
xl.FontSize = 12;

ax = nexttile(tl, 1);
hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
hN = scatter(ax, DivData.Divergence(maskNaive), DivData.Slope(maskNaive), 5, colorNaive, 'o', 'filled', 'LineWidth', 0.2);
hT = scatter(ax, DivData.Divergence(maskTran), DivData.Slope(maskTran), 5, colorTransfer, 'o', 'Filled', 'LineWidth', 0.2);
ylabel(ax, 'Sigmoid slope', 'FontSize', 12);
fitP = polyfit(xAll, yAll, 1);
xFit = [min(xAll), max(xAll)];
plot(ax, xFit, polyval(fitP, xFit), '-', 'Color', colorFit, 'LineWidth', 2);
lgd = legend(ax, [hN, hT], {'Naive', 'Transfer'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
lgd.FontSize = 12;
lgd.Box = 'off';
text(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
	'VerticalAlignment', 'top', 'FontSize', 12);

svgPath = 'English_Fig1G_DivergenceVsSlope_Scatter.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);

% ==================== Local Functions (divergence; from Fig44G pipeline) ====================

function out = iCollectTransferFirstBlockData(DS, idx0, idx1s)
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"], Phase="Transfer");
if isempty(T)
	out = iEmptyOutputTable();
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = T(T.Stimulus == "LightWater", :);
mice = unique(T.Mouse);
Rows = cell(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	if isempty(Tm)
		Rows{i} = iEmptyOutputTable();
		continue;
	end
	dt = min(Tm.DateTime);
	Ts = sortrows(Tm(Tm.DateTime == dt, :), 'TrialIndex');
	Rows{i} = iBlockRowsFn(DS, m, dt, Ts, "Transfer", idx0, idx1s);
end
out = vertcat(Rows{:});
end

function out = iCollectNaiveFirstBlockData(DS, sourceName, badMice, idx0, idx1s)
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"], Phase="Naive");
if isempty(T)
	out = iEmptyOutputTable();
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T.DateTime = iNormalizeDateTime(T.DateTime);
if ~isempty(badMice)
	T = T(~ismember(T.Mouse, string(badMice)), :);
end
mice = unique(T.Mouse);
Rows = cell(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	if isempty(Tm)
		Rows{i} = iEmptyOutputTable();
		continue;
	end
	sess = sort(unique(Tm.DateTime), 'ascend');
	chosenDt = NaT;
	chosenTbl = table();
	for s = 1:numel(sess)
		Tss = Tm(Tm.DateTime == sess(s), :);
		if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
			chosenDt = sess(s);
			chosenTbl = sortrows(Tss(Tss.Stimulus == "LightWater", :), 'TrialIndex');
			break;
		end
	end
	if ismissing(chosenDt) || isempty(chosenTbl)
		Rows{i} = iEmptyOutputTable();
		continue;
	end
	Rows{i} = iBlockRowsFn(DS, m, chosenDt, chosenTbl, "Naive", idx0, idx1s);
	Rows{i}.Source(:) = string(sourceName);
end
out = vertcat(Rows{:});
end

function out = iBlockRowsFn(DS, mouseName, dt, SessTbl, groupName, idx0, idx1s)
out = iEmptyOutputTable();
trialUIDs = unique(uint64(SessTbl.TrialUID), 'stable');
if numel(trialUIDs) < 2
	return;
end
beh = double(SessTbl.Behavior);
beh = beh(isfinite(beh));
if isempty(beh)
	return;
end
hitRate = mean(beh);
nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', mouseName, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
if iscell(nts)
	nts = nts{1};
end
if isempty(nts)
	return;
end
[ctt, ~] = iBuildCTT(nts, trialUIDs, idx0);
if isempty(ctt) || size(ctt, 2) < 2
	return;
end
xAt1 = ctt(:, :, idx1s);
divValue = iAllCellDivergence(xAt1);
out = iOneRow(mouseName, groupName, hitRate, divValue, dt);
end

function row = iOneRow(mouseName, groupName, hitRate, divValue, dt)
row = table(string(mouseName), string(groupName), double(hitRate), double(divValue), iNormalizeDateTime(dt), "", ...
	'VariableNames', {'Mouse','Group','HitRate','Divergence','DateTime','Source'});
end

function div = iAllCellDivergence(xAt1)
if size(xAt1, 1) < 3
	div = NaN;
	return;
end
X = xAt1;
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function [ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0)
ctt = [];
cellUIDs = uint64([]);
keepTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts = nts(keepTrial, :);
if isempty(nts)
	return;
end
trialUIDs = trialUIDs(ismember(trialUIDs, unique(uint64(nts.TrialUID), 'stable')));
if numel(trialUIDs) < 2
	return;
end
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rows = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rows));
	sig = double(nts.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	ordered = sig(loc, :);
	if any(~isfinite(ordered), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traceCell{nKeep} = ordered;
	keepUID(nKeep) = cid;
end
if nKeep < 1
	return;
end
traceCell = traceCell(1:nKeep);
keepUID = keepUID(1:nKeep);
nTrial = size(traceCell{1}, 1);
nTime = size(traceCell{1}, 2);
ctt = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	ctt(iC, :, :) = traceCell{iC};
end
ctt = ctt - ctt(:, :, idx0);
cellUIDs = keepUID;
end

function T = iEmptyOutputTable()
T = table(string.empty(0, 1), string.empty(0, 1), nan(0, 1), nan(0, 1), NaT(0, 1), string.empty(0, 1), ...
	'VariableNames', {'Mouse','Group','HitRate','Divergence','DateTime','Source'});
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
T = DS.TableQuery(["Mouse", "Stimulus", "Phase"], Phase=phaseName);
if isempty(T)
	badMice = strings(0, 1);
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
badMice = unique(T.Mouse(T.Stimulus == "AudioWater"));
end

function txt = iPLabel(p)
if ~isfinite(p)
	txt = 'p = NaN';
elseif p < 0.001
	txt = 'p < 0.001';
elseif p < 0.01
	txt = sprintf('p = %.3f', p);
else
	txt = sprintf('p = %.2f', p);
end
end

% ==================== Local Functions (sigmoid slope; from Fig1J pipeline) ====================

function fitTable = iFitSigmoidPerMouse(T)
T = sortrows(T, {'Group','Mouse','DateTime'});
mice = unique(string(T.Mouse), 'stable');
groupPerMouse = strings(numel(mice), 1);
lowerVec = nan(numel(mice), 1);
upperVec = nan(numel(mice), 1);
slopeVec = nan(numel(mice), 1);
midpointVec = nan(numel(mice), 1);
rSquaredVec = nan(numel(mice), 1);
keep = false(numel(mice), 1);
for iMouse = 1:numel(mice)
	mouseRows = string(T.Mouse) == mice(iMouse);
	mouseTable = T(mouseRows, :);
	mouseTable = sortrows(mouseTable, 'DateTime');
	groupPerMouse(iMouse) = string(mouseTable.Group(1));
	finiteRows = isfinite(double(mouseTable.Block)) & isfinite(double(mouseTable.Performance));
	mouseTable = mouseTable(finiteRows, :);
	if height(mouseTable) < 2
		continue;
	end
	if numel(unique(double(mouseTable.Performance))) < 2
		continue;
	end
	fitMouse = iFitSigmoidCurve(mouseTable, mice(iMouse));
	lowerVec(iMouse) = fitMouse.Lower;
	upperVec(iMouse) = fitMouse.Upper;
	slopeVec(iMouse) = fitMouse.Slope;
	midpointVec(iMouse) = fitMouse.Midpoint;
	rSquaredVec(iMouse) = fitMouse.RSquared;
	keep(iMouse) = true;
end
fitTable = table;
fitTable.Group = groupPerMouse(keep);
fitTable.Mouse = mice(keep);
fitTable.Lower = lowerVec(keep);
fitTable.Upper = upperVec(keep);
fitTable.Slope = slopeVec(keep);
fitTable.Midpoint = midpointVec(keep);
fitTable.RSquared = rSquaredVec(keep);
fitTable = sortrows(fitTable, {'Group','Mouse'});
end

function fitOut = iFitSigmoidCurve(T, groupName)
T = sortrows(T, {'Mouse','DateTime'});
xObs = double(T.Block(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('Fig1G:NoDataForGroup', 'No valid block data for group %s.', char(groupName));
end
% midpoint 不作约束（可为负），故用恒等而非 log/exp
p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); max(median(xObs), 1)];
obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
yHat = iSigmoidFromParams(p, xObs);
SSE = sum((yObs - yHat).^2, 'omitnan');
SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if SST == 0
	rSquared = NaN;
else
	rSquared = 1 - SSE / SST;
end
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.ParamRaw = p;
fitOut.Lower = lower;
fitOut.Upper = upper;
fitOut.Slope = slope;
fitOut.Midpoint = midpoint;
fitOut.SSE = SSE;
fitOut.RSquared = rSquared;
fitOut.XObserved = xObs;
fitOut.YObserved = yObs;
end

function y = iSigmoidFromParams(p, x)
[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
lower = 1 ./ (1 + exp(-p(1)));
upper = 1;
slope = exp(p(2));
midpoint = p(3);
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end

function out = iLightWaterBlocksByMouse(DS, sourceName, startPhase, endPhase)
T = iQueryLightWaterBehaviorAll(DS);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','NBlocksInBlock'});
	return;
end
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = iBlockizeByDateTime(T);
T = iSelectBlocksBetweenPhases(T, startPhase, endPhase);
T.Source = repmat(string(sourceName), height(T), 1);
out = T(:, {'Mouse','DateTime','Performance','Source','NBlocksInBlock'});
end

function out = iLightWaterBlocksByMouse_LAInterspersed(DS, sourceName, startPhase, endPhase)
if string(startPhase) == "Naive" || string(endPhase) == "Naive"
	badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
else
	badMice = string.empty(0,1);
end
T = iQueryLightWaterBehaviorAll(DS);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','NBlocksInBlock'});
	return;
end
T.Mouse = string(T.Mouse);
if ~isempty(badMice)
	T = T(~ismember(T.Mouse, badMice), :);
end
T.DateTime = iNormalizeDateTime(T.DateTime);
T = iBlockizeByDateTime(T);
T = iSelectBlocksBetweenPhases(T, startPhase, endPhase);
T.Source = repmat(string(sourceName), height(T), 1);
out = T(:, {'Mouse','DateTime','Performance','Source','NBlocksInBlock'});
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

function S = iSelectBlocksBetweenPhases(S, startPhase, endPhase)
startPhase = string(startPhase);
endPhase = string(endPhase);
if isempty(S)
	return;
end
S.Mouse = string(S.Mouse);
S.Phase = string(S.Phase);
S = sortrows(S, {'Mouse','DateTime'});
mice = unique(S.Mouse);
keepRows = false(height(S), 1);
for i = 1:numel(mice)
	m = mice(i);
	idx = find(S.Mouse == m);
	ph = S.Phase(idx);
	st = find(ph == startPhase, 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == endPhase & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keepRows(idx(st:ed)) = true;
end
S = S(keepRows, :);
end

function S = iBlockizeByDateTime(T)
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
[G, mouseList, dtList] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
phaseBlock = splitapply(@(x) iPickBlockPhase(x), string(T.Phase), G);
S = table(mouseList, dtList, perf, nBlocks, phaseBlock, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInBlock','Phase'});
end

function ph = iPickBlockPhase(phases)
phases = string(phases);
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	ph = "";
	return;
end
[u, ~, ic] = unique(phases);
counts = accumarray(ic, 1);
[~, ix] = max(counts);
ph = u(ix);
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Source = string(T.Source);
[G, mice] = findgroups(T.Mouse);
nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
dup = mice(nSrc > 1);
if ~isempty(dup)
	msgLines = strings(numel(dup), 1);
	for i = 1:numel(dup)
		m = dup(i);
		srcs = unique(T.Source(T.Mouse == m));
		msgLines(i) = m + ": " + strjoin(srcs, ",");
	end
	error('Fig1G:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
[G, mice] = findgroups(T.Mouse);
nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
dup = mice(nG > 1);
if ~isempty(dup)
	msgLines = strings(numel(dup), 1);
	for i = 1:numel(dup)
		m = dup(i);
		gs = unique(T.Group(T.Mouse == m));
		msgLines(i) = m + ": " + strjoin(gs, ",");
	end
	error('Fig1G:MouseInMultipleGroups', 'Some mice appear in multiple groups.\n%s', char(strjoin(msgLines, newline)));
end
end

function T = iAddBlockIndex(T)
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Block = vertcat(sessCell{:});
end

function dt = iNormalizeDateTime(dt)
if isdatetime(dt)
	if ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
	return;
end
if isduration(dt)
	dt = datetime(dt);
else
	dt = datetime(dt, 'ConvertFrom', 'datenum');
end
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end
