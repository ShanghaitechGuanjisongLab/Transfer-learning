% AudioWater initial learning: all-cell block-by-block divergence versus behavior.
% Same ZScore/cue-subtraction/+1 s divergence and statistical tests as the
% LightWater probe. Sources: ALB, ALInterspersed, Vacation7 and THInhibit.
% AudioOnly calibration is excluded. Begin after each mouse's last Naive
% session without AudioWater, then include AudioWater blocks through the last
% pre-transfer Learned block. Recall/Review/Final are never included.

if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
DSs = {TransferLearning.AudioLightBaseline(); TransferLearning.ALInterspersed(); ...
	TransferLearning.Vacation7(); TransferLearning.THInhibit()};
sourceNames = ["ALB"; "ALI"; "V7"; "TH"];
xsSec = seconds(TransferLearning.Xs);
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok0 || ~ok1s
	error('AudioBlockDivergence:TimeIndexMissing', 'Cannot locate cue onset or +1 s.');
end
Sess = table();
for i = 1:numel(DSs)
	Sess = [Sess; iAudioLearningSessions(DSs{i}, sourceNames(i))]; %#ok<AGROW>
end
if numel(unique(Sess.Mouse)) ~= sum(cellfun(@(D) numel(unique(string(D.DateTimes.Mouse))), DSs))
	error('AudioBlockDivergence:MouseAcrossSources', 'Duplicate mice across sources; do not count them independently.');
end
ResultAll = table();
for i = 1:numel(DSs)
	ResultAll = [ResultAll; iBlockDivergenceTable(Sess(Sess.Source == sourceNames(i), :), DSs{i}, idx0, idx1s)]; %#ok<AGROW>
end
ResultAll = sortrows(ResultAll, {'Mouse','DateTime'});
[MouseStats, Stats, Model] = iTestAssociation(ResultAll);
fprintf('\n=== AudioWater Naive -> Learned block coverage ===\n');
fprintf('Behavior blocks: %d; mice: %d; valid all-cell blocks: %d\n', ...
	height(ResultAll), numel(unique(ResultAll.Mouse)), nnz(isfinite(ResultAll.DivergenceAll)));
for source = sourceNames'
	R = ResultAll(ResultAll.Source == source, :);
	fprintf('Source %s: %d mice, %d behavior blocks, %d valid blocks\n', source, ...
		numel(unique(R.Mouse)), height(R), nnz(R.Status == "OK"));
end
if any(ResultAll.Status ~= "OK")
	disp(ResultAll(ResultAll.Status ~= "OK", {'Mouse','DateTime','Performance','Status'}));
end
fprintf('\n=== AudioWater divergence versus behavior ===\n');
disp(Stats);
disp(MouseStats);
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~exist(outDirUNC, 'dir')
	mkdir(outDirUNC);
end
blockCsv = fullfile(outDirUNC, 'Temp_AudioWater_BlockDivergence_Blocks.csv');
mouseCsv = fullfile(outDirUNC, 'Temp_AudioWater_BlockDivergence_MouseStats.csv');
statsCsv = fullfile(outDirUNC, 'Temp_AudioWater_BlockDivergence_Stats.csv');
writetable(ResultAll, blockCsv);
writetable(MouseStats, mouseCsv);
writetable(Stats, statsCsv);
fprintf('Wrote: %s\nWrote: %s\nWrote: %s\n', blockCsv, mouseCsv, statsCsv);
assignin('base', 'AudioWaterBlockDivergence', ResultAll);
assignin('base', 'AudioWaterBlockDivergenceMouseStats', MouseStats);
assignin('base', 'AudioWaterBlockDivergenceStats', Stats);
assignin('base', 'AudioWaterBlockDivergenceModel', Model);

function S = iAudioLearningSessions(DS, sourceName)
T = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior"]);
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
[G0, allMouse, allDT] = findgroups(T.Mouse, T.DateTime);
allPhase = splitapply(@iModalPhase, T.Phase, G0);
allStim = splitapply(@(x) {unique(x)}, T.Stimulus, G0);
Full = table(allMouse, allDT, allPhase, allStim, 'VariableNames', {'Mouse','DateTime','Phase','Stimuli'});
Audio = T(T.Stimulus == "AudioWater", :);
[G, mouseList, dtList] = findgroups(Audio.Mouse, Audio.DateTime);
performance = splitapply(@(x) mean(double(x), 'omitnan'), Audio.Behavior, G);
nBehavior = splitapply(@(x) nnz(isfinite(double(x))), Audio.Behavior, G);
phase = splitapply(@iModalPhase, Audio.Phase, G);
S = table(mouseList, dtList, performance, nBehavior, phase, ...
	'VariableNames', {'Mouse','DateTime','Performance','NBehaviorTrials','Phase'});
S = sortrows(S, {'Mouse','DateTime'});
keep = false(height(S), 1);
for mouse = unique(S.Mouse)'
	F = Full(Full.Mouse == mouse, :);
	F = sortrows(F, 'DateTime');
	lastNaive = 0;
	for j = 1:height(F)
		if F.Phase(j) ~= "Naive"
			continue;
		end
		if any(F.Stimuli{j} == "AudioWater") || ~any(ismember(F.Stimuli{j}, ["AudioOnly","AudioWater","LightOnly","LightWater","WaterOnly"]))
			lastNaive = j;
		end
	end
	if lastNaive == 0
		continue;
	end
	firstTransfer = find(F.Phase == "Transfer" & (1:height(F))' > lastNaive, 1, 'first');
	if isempty(firstTransfer)
		firstTransfer = height(F) + 1;
	end
	learned = find(F.Phase == "Learned" & (1:height(F))' > lastNaive & (1:height(F))' < firstTransfer, 1, 'last');
	if isempty(learned)
		endDT = F.DateTime(firstTransfer - 1);
	else
		endDT = F.DateTime(learned);
	end
	startDT = F.DateTime(lastNaive);
	keep = keep | (S.Mouse == mouse & S.DateTime >= startDT & S.DateTime <= endDT);
end
S = S(keep, :);
S.Source = repmat(string(sourceName), height(S), 1);
S.Block = zeros(height(S), 1);
for mouse = unique(S.Mouse)'
	idx = find(S.Mouse == mouse);
	S.Block(idx) = (1:numel(idx))';
end
end

function R = iBlockDivergenceTable(S, DS, idx0, idx1s)
R = table();
for i = 1:height(S)
	row = S(i, :);
	row.DivergenceAll = NaN;
	row.NTrialsImaging = 0;
	row.NCells = 0;
	row.Status = "NoNTS";
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', row.Mouse, ...
			'DateTime', row.DateTime), UniExp.Flags.ZScore, 1:24);
	catch ME
		% V7/vtf1005 Learned has insufficient valid baseline samples for the
		% package F0 interpolation; preserve the exclusion in the output table.
		if row.Source == "V7" && row.Mouse == "vtf1005" && ...
				row.DateTime == datetime('2025-11-28 07:53:00')
			row.Status = "NormalizationError";
			R = [R; row]; %#ok<AGROW>
			continue;
		end
		rethrow(ME);
	end
	if iscell(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
	if isempty(nts)
		R = [R; row]; %#ok<AGROW>
		continue;
	end
	[ctt, status] = iBuildCTT(nts, idx0);
	row.Status = status;
	if isempty(ctt)
		R = [R; row]; %#ok<AGROW>
		continue;
	end
	row.NTrialsImaging = size(ctt, 2);
	row.NCells = size(ctt, 1);
	X = ctt(:, :, idx1s);
	totalSignal = sum(mean(X, 2).^2, 'omitnan');
	totalNoise = sum(var(X, [], 2), 'omitnan');
	if isfinite(totalSignal) && totalSignal > 0 && isfinite(totalNoise)
		row.DivergenceAll = sqrt(totalNoise / totalSignal);
	else
		row.Status = "ZeroMeanSignal";
	end
	R = [R; row]; %#ok<AGROW>
end
end

function [ctt, status] = iBuildCTT(nts, idx0)
ctt = [];
trialUIDs = unique(uint64(nts.TrialUID), 'stable');
if numel(trialUIDs) < 2
	status = "TooFewTrials";
	return;
end
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = cell(numel(allCells), 1);
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
end
if nKeep < 3
	status = "TooFewCells";
	return;
end
traceCell = traceCell(1:nKeep);
nTrial = size(traceCell{1}, 1);
nTime = size(traceCell{1}, 2);
ctt = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	ctt(iC, :, :) = traceCell{iC};
end
ctt = ctt - ctt(:, :, idx0);
status = "OK";
end

function [MouseStats, Stats, Model] = iTestAssociation(T)
use = isfinite(T.DivergenceAll) & isfinite(T.Performance) & T.DivergenceAll > 0;
T = T(use, :);
MouseStats = table();
rhos = [];
for mouse = unique(T.Mouse)'
	R = T(T.Mouse == mouse, :);
	rho = NaN;
	pWithin = NaN;
	if height(R) >= 3 && numel(unique(R.Performance)) > 1 && numel(unique(R.DivergenceAll)) > 1
		[rho, pWithin] = corr(R.Performance, R.DivergenceAll, 'Type', 'Spearman');
		rhos(end+1, 1) = rho; %#ok<AGROW>
	end
	MouseStats = [MouseStats; table(mouse, string(R.Source(1)), height(R), min(R.Performance), max(R.Performance), rho, pWithin, ...
		'VariableNames', {'Mouse','Source','NBlocks','MinPerformance','MaxPerformance','SpearmanRho','PWithinDescriptive'})]; %#ok<AGROW>
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
T.LogDivergence = log(T.DivergenceAll);
T.Mouse = categorical(T.Mouse);
T.Source = categorical(T.Source);
Model = fitlme(T, 'LogDivergence ~ Performance + Source + (1|Mouse)', 'FitMethod', 'REML');
coef = Model.Coefficients;
idx = find(string(coef.Name) == "Performance", 1);
ci = coefCI(Model);
beta = coef.Estimate(idx);
Stats = table(height(T), numel(unique(T.Mouse)), numel(rhos), mean(rhos), median(rhos), ...
	nnz(rhos < 0), pWilcoxon, beta, 100 * (exp(beta) - 1), ...
	100 * (exp(ci(idx, 1)) - 1), 100 * (exp(ci(idx, 2)) - 1), coef.pValue(idx), ...
	'VariableNames', {'NBlocks','NMiceModel','NMiceRho','MeanWithinRho','MedianWithinRho', ...
	'NNegativeRho','WilcoxonP','LMELogSlopePerFullHitRange','LMEPercentChange0To1', ...
	'LMEPercentCI95Low','LMEPercentCI95High','LMEP'});
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
