% Temporary probe: LightWater block-by-block divergence versus behavior, Naive -> Learned.
% Divergence follows Fig1G: QueryNTS ZScore(1:24), subtract each trial's cue-onset
% value, use the +1 s sample, and compute sqrt(sum trial variance / sum mean response^2).
% The primary test respects repeated blocks within mice: per-mouse Spearman
% correlations followed by a two-sided Wilcoxon signed-rank test across mice.
% A random-intercept LME of log(divergence) is a complementary effect-size model.

if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
xsSec = seconds(TransferLearning.Xs);
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok0 || ~ok1s
	error('BlockDivergence:TimeIndexMissing', 'Cannot locate cue onset or +1 s.');
end

SessLAB = iLearningSessions(LAB, 'LAB');
SessLAI = iLearningSessions(LAI, 'LAI');
Sess = [SessLAB; SessLAI];
if isempty(Sess)
	error('BlockDivergence:NoSessions', 'No Naive-to-Learned LightWater sessions found.');
end
if numel(unique(Sess.Mouse)) ~= numel(unique(Sess.Mouse(Sess.Source == "LAB"))) + ...
		numel(unique(Sess.Mouse(Sess.Source == "LAI")))
	error('BlockDivergence:MouseAcrossSources', 'A mouse occurs in both sources.');
end

ResultAll = [iBlockDivergenceTable(SessLAB, LAB, idx0, idx1s); ...
	iBlockDivergenceTable(SessLAI, LAI, idx0, idx1s)];
ResultAll = sortrows(ResultAll, {'Mouse','DateTime'});
ResultAll.Properties.VariableNames{'Divergence'} = 'DivergenceAll';
ResultAll.Properties.VariableNames{'DivergenceL23'} = 'DivergenceMOp23';
ResultAll.Properties.VariableNames{'DivergenceL5'} = 'DivergenceMOp5';

measureNames = ["DivergenceAll","DivergenceMOp23","DivergenceMOp5"];
measureLabels = ["All cells","MOp2/3","MOp5"];
Stats = table();
MouseStats = table();
ModelStats = struct();
for iM = 1:numel(measureNames)
	[mouseStats, statsRow, modelRow] = iTestAssociation(ResultAll, measureNames(iM), measureLabels(iM));
	firstLast = iFirstLastStats(ResultAll, measureNames(iM));
	MouseStats = [MouseStats; mouseStats]; %#ok<AGROW>
	Stats = [Stats; [statsRow, firstLast]]; %#ok<AGROW>
	ModelStats.(measureNames(iM)) = modelRow.Model;
end

fprintf('\n=== LightWater Naive -> Learned block coverage ===\n');
fprintf('Behavior blocks: %d; mice: %d; blocks with valid all-cell divergence: %d\n', ...
	height(ResultAll), numel(unique(ResultAll.Mouse)), nnz(isfinite(ResultAll.DivergenceAll)));
for status = unique(ResultAll.Status)'
	R = ResultAll(ResultAll.Status == status, :);
	fprintf('Status %-18s: %d blocks\n', status, height(R));
end
fprintf('\nExcluded/no-divergence blocks:\n');
disp(ResultAll(ResultAll.Status ~= "OK", {'Mouse','Source','DateTime','Block','Performance','Status'}));
fprintf('\n=== Within-mouse divergence versus behavior ===\n');
disp(Stats);
fprintf('\nPer-mouse correlations:\n');
disp(MouseStats);

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~exist(outDirUNC, 'dir')
	mkdir(outDirUNC);
end
blockCsv = fullfile(outDirUNC, 'Temp_LightWater_BlockDivergence_Blocks.csv');
mouseCsv = fullfile(outDirUNC, 'Temp_LightWater_BlockDivergence_MouseStats.csv');
statsCsv = fullfile(outDirUNC, 'Temp_LightWater_BlockDivergence_Stats.csv');
writetable(ResultAll, blockCsv);
writetable(MouseStats, mouseCsv);
writetable(Stats, statsCsv);
fprintf('Wrote: %s\nWrote: %s\nWrote: %s\n', blockCsv, mouseCsv, statsCsv);
assignin('base', 'LightWaterBlockDivergence', ResultAll);
assignin('base', 'LightWaterBlockDivergenceMouseStats', MouseStats);
assignin('base', 'LightWaterBlockDivergenceStats', Stats);
assignin('base', 'LightWaterBlockDivergenceModels', ModelStats);

function S = iLearningSessions(DS, sourceName)
T = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior"]);
if isempty(T)
	S = table();
	return;
end
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T = T(T.Stimulus == "LightWater", :);
[G, mouseList, dtList] = findgroups(T.Mouse, T.DateTime);
performance = splitapply(@(x) mean(double(x), 'omitnan'), T.Behavior, G);
nBehavior = splitapply(@(x) nnz(isfinite(double(x))), T.Behavior, G);
phase = splitapply(@iModalPhase, T.Phase, G);
S = table(mouseList, dtList, performance, nBehavior, phase, ...
	'VariableNames', {'Mouse','DateTime','Performance','NBehaviorTrials','Phase'});
S = sortrows(S, {'Mouse','DateTime'});
keep = false(height(S), 1);
for mouse = unique(S.Mouse)'
	idx = find(S.Mouse == mouse);
	ph = S.Phase(idx);
	firstNaive = find(ph == "Naive", 1, 'first');
	if isempty(firstNaive)
		continue;
	end
	lastLearned = find(ph == "Learned" & (1:numel(ph))' >= firstNaive, 1, 'first');
	if isempty(lastLearned)
		lastLearned = numel(ph);
	end
	keep(idx(firstNaive:lastLearned)) = true;
end
S = S(keep, :);
S = iExcludeAudioWaterSessions(S, DS);
S.Source = repmat(string(sourceName), height(S), 1);
S = sortrows(S, {'Mouse','DateTime'});
S.Block = zeros(height(S), 1);
for mouse = unique(S.Mouse)'
	idx = find(S.Mouse == mouse);
	S.Block(idx) = (1:numel(idx))';
end
end

function S = iExcludeAudioWaterSessions(S, DS)
Q = DS.TableQuery(["Mouse","DateTime","Stimulus"]);
Q.Mouse = string(Q.Mouse);
Q.DateTime = iNormalizeDateTime(Q.DateTime);
Q.Stimulus = string(Q.Stimulus);
Q = Q(Q.Stimulus == "AudioWater", {'Mouse','DateTime'});
if isempty(Q)
	return;
end
Q = unique(Q, 'rows');
keep = true(height(S), 1);
for i = 1:height(Q)
	keep = keep & ~(S.Mouse == Q.Mouse(i) & S.DateTime == Q.DateTime(i));
end
S = S(keep, :);
end

function R = iBlockDivergenceTable(S, DS, idx0, idx1s)
R = table();
CellTbl = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
CellTbl.Mouse = string(CellTbl.Mouse);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.ZLayer = string(CellTbl.ZLayer);
for i = 1:height(S)
	row = S(i, :);
	row.Divergence = NaN;
	row.DivergenceL23 = NaN;
	row.DivergenceL5 = NaN;
	row.NTrialsImaging = 0;
	row.NCells = 0;
	row.NCellsMOp23 = 0;
	row.NCellsMOp5 = 0;
	row.Status = "NoNTS";
	ntsCell = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', row.Mouse, ...
		'DateTime', row.DateTime), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
	if isempty(nts)
		R = [R; row]; %#ok<AGROW>
		continue;
	end
	[ctt, cellUIDs, status] = iBuildCTT(nts, idx0);
	row.Status = status;
	if isempty(ctt)
		R = [R; row]; %#ok<AGROW>
		continue;
	end
	row.NTrialsImaging = size(ctt, 2);
	row.NCells = size(ctt, 1);
	cellMeta = CellTbl(CellTbl.Mouse == row.Mouse, :);
	[tf, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs), 1);
	layers(tf) = cellMeta.ZLayer(loc(tf));
	X = ctt(:, :, idx1s);
	[row.Divergence, statusAll] = iDivergence(X);
	row.NCellsMOp23 = nnz(layers == "MOp2/3");
	row.NCellsMOp5 = nnz(layers == "MOp5");
	[row.DivergenceL23, status23] = iDivergence(X(layers == "MOp2/3", :));
	[row.DivergenceL5, status5] = iDivergence(X(layers == "MOp5", :));
	row.Status = iCombineStatus(statusAll, status23, status5);
	R = [R; row]; %#ok<AGROW>
end
end

function [ctt, cellUIDs, status] = iBuildCTT(nts, idx0)
ctt = [];
cellUIDs = uint64([]);
trialUIDs = unique(uint64(nts.TrialUID), 'stable');
if numel(trialUIDs) < 2
	status = "TooFewTrials";
	return;
end
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	rows = uint64(nts.CellUID) == allCells(iC);
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
	keepUID(nKeep) = allCells(iC);
end
if nKeep < 3
	status = "TooFewCells";
	return;
end
traceCell = traceCell(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = size(traceCell{1}, 1);
nTime = size(traceCell{1}, 2);
ctt = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	ctt(iC, :, :) = traceCell{iC};
end
ctt = ctt - ctt(:, :, idx0);
status = "OK";
end

function [value, status] = iDivergence(X)
value = NaN;
if size(X, 1) < 3 || size(X, 2) < 2
	status = "TooFewCells";
	return;
end
totalSignal = sum(mean(X, 2).^2, 'omitnan');
totalNoise = sum(var(X, [], 2), 'omitnan');
if ~(isfinite(totalSignal) && totalSignal > 0 && isfinite(totalNoise))
	status = "ZeroMeanSignal";
	return;
end
value = sqrt(totalNoise / totalSignal);
status = "OK";
end

function status = iCombineStatus(statusAll, status23, status5)
if statusAll == "OK"
	status = "OK";
elseif status23 == "OK" || status5 == "OK"
	status = "LayerOnly";
else
	status = statusAll;
end
end

function [MouseStats, Stats, ModelStats] = iTestAssociation(T, measure, label)
use = isfinite(T.(measure)) & isfinite(T.Performance) & T.(measure) > 0;
T = T(use, :);
MouseStats = table();
rhos = [];
for mouse = unique(T.Mouse)'
	R = T(T.Mouse == mouse, :);
	rho = NaN;
	pWithin = NaN;
	if height(R) >= 3 && numel(unique(R.Performance)) > 1 && numel(unique(R.(measure))) > 1
		[rho, pWithin] = corr(R.Performance, R.(measure), 'Type', 'Spearman');
		rhos(end+1, 1) = rho; %#ok<AGROW>
	end
	MouseStats = [MouseStats; table(string(label), mouse, string(R.Source(1)), height(R), ...
		min(R.Performance), max(R.Performance), rho, pWithin, ...
		'VariableNames', {'Measure','Mouse','Source','NBlocks','MinPerformance','MaxPerformance','SpearmanRho','PWithinDescriptive'})]; %#ok<AGROW>
end
if numel(rhos) >= 3
	if numel(rhos) <= 15
		pWilcoxon = signrank(rhos, 0, 'tail', 'both', 'method', 'exact');
	else
		pWilcoxon = signrank(rhos, 0, 'tail', 'both');
	end
else
	pWilcoxon = NaN;
end
T.LogDivergence = log(T.(measure));
T.Mouse = categorical(T.Mouse);
T.Source = categorical(T.Source);
lme = fitlme(T, 'LogDivergence ~ Performance + Source + (1|Mouse)', 'FitMethod', 'REML');
coef = lme.Coefficients;
idx = find(string(coef.Name) == "Performance", 1);
if isempty(idx)
	error('BlockDivergence:MissingLMECoefficient', 'Performance coefficient not found.');
end
ci = coefCI(lme);
beta = coef.Estimate(idx);
Stats = table(string(label), height(T), numel(unique(T.Mouse)), numel(rhos), ...
	mean(rhos), median(rhos), nnz(rhos < 0), pWilcoxon, beta, ...
	100 * (exp(beta) - 1), 100 * (exp(ci(idx, 1)) - 1), 100 * (exp(ci(idx, 2)) - 1), ...
	coef.pValue(idx), 'VariableNames', {'Measure','NBlocks','NMiceModel','NMiceRho', ...
	'MeanWithinRho','MedianWithinRho','NNegativeRho','WilcoxonP', ...
	'LMELogSlopePerFullHitRange','LMEPercentChange0To1','LMEPercentCI95Low', ...
	'LMEPercentCI95High','LMEP'});
ModelStats = table(string(label), lme, 'VariableNames', {'Measure','Model'});
end

function S = iFirstLastStats(T, measure)
firstD = [];
lastD = [];
for mouse = unique(T.Mouse)'
	R = T(T.Mouse == mouse & isfinite(T.(measure)) & isfinite(T.Performance), :);
	R = sortrows(R, 'DateTime');
	if height(R) < 2
		continue;
	end
	firstD(end+1, 1) = R.(measure)(1); %#ok<AGROW>
	lastD(end+1, 1) = R.(measure)(end); %#ok<AGROW>
end
if numel(firstD) < 3
	S = table(numel(firstD), NaN, NaN, NaN, ...
		'VariableNames', {'NFirstLast','NFirstLastDecline','FirstLastWilcoxonP','FirstLastMedianPercentChange'});
	return;
end
delta = lastD - firstD;
if numel(delta) <= 15
	p = signrank(delta, 0, 'tail', 'both', 'method', 'exact');
else
	p = signrank(delta, 0, 'tail', 'both');
end
medianPercent = 100 * median(lastD ./ firstD - 1);
S = table(numel(delta), nnz(delta < 0), p, medianPercent, ...
	'VariableNames', {'NFirstLast','NFirstLastDecline','FirstLastWilcoxonP','FirstLastMedianPercentChange'});
end

function phase = iModalPhase(phases)
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	phase = "";
	return;
end
[u, ~, ic] = unique(phases);
counts = accumarray(ic, 1);
[~, idx] = max(counts);
phase = u(idx);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[distance, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(distance) && distance <= tolSec;
end
