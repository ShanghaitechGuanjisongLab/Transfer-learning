% English Fig3M: Per-mouse learning slope vs inter-cell SD@1s (two tiles)
%
% Top tile:  "Average-first" SD — per-cell mean z@1s across sessions → filter [-1,1] → std
% Bottom tile: "Per-trial" SD — each trial compute cells' SD → average all trials per mouse
%
% Both cohorts combined:
%   - Naive   (LightAudioBaseline): slope over Naive→Learned sessions
%   - Transfer (AudioLightBaseline): slope over Transfer→Final sessions
%
% Execution:
%   TransferLearning.英文图1.M_SlopeVsInterCellSD

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS_Naive    = TransferLearning.LightAudioBaseline();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('SlopeVsSD:No1s', 'Cannot find sample close to 1s in time axis.');
end

% --- 1) Per-cohort: sessions + slope + both SD methods
[slopeN, sdAvgN, sdTrialN, miceN] = iCohortData(DS_Naive,    idx1s, "Naive",    "Learned");
[slopeT, sdAvgT, sdTrialT, miceT] = iCohortData(DS_Transfer, idx1s, "Transfer", "Final");

fprintf('Naive cohort:    %d mice\n', numel(miceN));
fprintf('Transfer cohort: %d mice\n', numel(miceT));

% --- 2) Pool
slopeAll   = [slopeN;  slopeT];
sdAvgAll   = [sdAvgN;  sdAvgT];
sdTrialAll = [sdTrialN; sdTrialT];
groupAll   = [repmat("Naive", numel(miceN), 1); repmat("Transfer", numel(miceT), 1)];

% --- 3) Figure: 2 tiles (1 column)
f = figure('Color', 'w', 'Name', 'Fig3M Slope vs SD (two methods)');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 8];
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

colorN = [0.8500 0.3250 0.0980]; % orange-red
colorT = [0      0.4470 0.7410]; % blue

titles    = {"Avg-first SD", "Per-trial SD"};
sdArrays  = {sdAvgAll, sdTrialAll};
xlabs     = {"Mean inter-cell SD@1s (avg-first)", "Mean inter-cell SD@1s (per-trial)"};

for iTile = 1:2
	ax = nexttile(tl);
	hold(ax, 'on');
	ax.FontSize = 6;
	ax.Toolbar.Visible = 'off';
	box(ax, 'off');

	sd  = sdArrays{iTile};
	use = isfinite(sd) & isfinite(slopeAll);

	[rho, p] = corr(sd(use), slopeAll(use), 'Type', 'Spearman');
	fprintf('[%s] Spearman rho=%.3f, p=%.4g, n=%d\n', titles{iTile}, rho, p, nnz(use));

	if p < 0.001
		pLabel = sprintf('p=%.1e', p);
	elseif p < 0.01
		pLabel = sprintf('p=%.4f', p);
	else
		pLabel = sprintf('p=%.2f', p);
	end

	maskN = use & (groupAll == "Naive");
	maskT = use & (groupAll == "Transfer");
	hN = scatter(ax, sd(maskN), slopeAll(maskN), 14, colorN, 'o', 'filled', 'LineWidth', 0.3);
	hT = scatter(ax, sd(maskT), slopeAll(maskT), 14, colorT, 's', 'filled', 'LineWidth', 0.3);

	if nnz(use) >= 2 && std(sd(use)) > 0
		b = polyfit(sd(use), slopeAll(use), 1);
		xFit = [min(sd(use)), max(sd(use))];
		plot(ax, xFit, polyval(b, xFit), '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
	end

	if iTile == 1
		legend(ax, [hN, hT], {'Naive', 'Transfer'}, 'FontSize', 5, 'Box', 'off', 'Location', 'best');
	end

	text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', ...
		'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
		'FontSize', 6);

	xlabel(ax, xlabs{iTile}, 'FontSize', 6);
	ylabel(ax, 'Learning slope', 'FontSize', 6);
	title(ax, titles{iTile}, 'FontSize', 7);
end

% --- 4) Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3M_SlopeVsInterCellSD.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function [slopeVec, sdAvgVec, sdTrialVec, mice] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
% Returns per-mouse: slope, average-first SD, per-trial SD

Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);

if isempty(Sess)
	slopeVec = []; sdAvgVec = []; sdTrialVec = []; mice = string.empty(0,1); return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

% --- Slope per mouse (with ceiling exclusion) ---
mice = unique(string(Sess.Mouse));
nMice = numel(mice);
slopeVec = nan(nMice, 1);
sessUsed = cell(nMice, 1);  % DateTimes used per mouse (after ceiling exclusion)

for iM = 1:nMice
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	n = height(R);
	if n < 2, continue; end

	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	n = height(R);
	if n < 2, continue; end

	xi = (1:n)';
	yi = double(R.Performance);
	ok = isfinite(yi);
	if nnz(ok) < 2, continue; end
	pFit = polyfit(xi(ok), yi(ok), 1);
	slopeVec(iM) = pFit(1);
	sessUsed{iM} = R.DateTime;
end

% --- Collect all used DateTimes for batch QueryNTS ---
allUsedDTs = vertcat(sessUsed{:});
if isempty(allUsedDTs)
	sdAvgVec = nan(nMice, 1); sdTrialVec = nan(nMice, 1);
	keep = isfinite(slopeVec); slopeVec = slopeVec(keep); sdAvgVec = sdAvgVec(keep); sdTrialVec = sdTrialVec(keep); mice = mice(keep);
	return;
end
allUsedDTs = unique(allUsedDTs);

% Batch QueryNTS (per-trial level, no Median)
q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	sdAvgVec = nan(nMice, 1); sdTrialVec = nan(nMice, 1);
	keep = isfinite(slopeVec); slopeVec = slopeVec(keep); sdAvgVec = sdAvgVec(keep); sdTrialVec = sdTrialVec(keep); mice = mice(keep);
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
	sdAvgVec = nan(nMice, 1); sdTrialVec = nan(nMice, 1);
	keep = isfinite(slopeVec); slopeVec = slopeVec(keep); sdAvgVec = sdAvgVec(keep); sdTrialVec = sdTrialVec(keep); mice = mice(keep);
	return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID  = uint64(rawTbl.CellUID);
rawTbl.TrialUID = uint64(rawTbl.TrialUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

% === Method 1: Average-first SD ===
% Per-cell per-session median → per-cell mean across sessions → filter [-1,1] → SD
[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

% Build DateTime→Mouse map
dtMouseMap = Sess(:, {'DateTime','Mouse'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);

medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');
% Keep only sessions used by each mouse
medTbl2 = medTbl(false, :);
for iM = 1:nMice
	if isempty(sessUsed{iM}), continue; end
	medTbl2 = [medTbl2; medTbl(string(medTbl.Mouse) == mice(iM) & ismember(medTbl.DateTime, sessUsed{iM}), :)]; %#ok
end

sdAvgVec = nan(nMice, 1);
if ~isempty(medTbl2)
	[G2, mouseU2, cellU2] = findgroups(medTbl2.Mouse, medTbl2.CellUID);
	meanPerCell = splitapply(@mean, medTbl2.Med1s, G2);
	for iM = 1:nMice
		mask = string(mouseU2) == mice(iM);
		vals = meanPerCell(mask);
		vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
		if numel(vals) >= 3, sdAvgVec(iM) = std(vals); end
	end
end

% === Method 2: Per-trial SD ===
% Each trial: cells' z@1s filter [-1,1] → SD; then mean per mouse
valid = isfinite(z1s) & z1s >= -1 & z1s <= 1;
rawTblV = rawTbl(valid, :);
z1sV    = z1s(valid);

[G3, dtG3, trG3] = findgroups(rawTblV.DateTime, rawTblV.TrialUID);
trialSD = splitapply(@(x) iTrialSD(x, 3), z1sV, G3);

trialTbl = table(dtG3, trG3, trialSD, 'VariableNames', {'DateTime','TrialUID','TrialSD'});
trialTbl = innerjoin(trialTbl, dtMouseMap, 'Keys', 'DateTime');
trialTbl = trialTbl(isfinite(trialTbl.TrialSD), :);

sdTrialVec = nan(nMice, 1);
if ~isempty(trialTbl)
	% Keep only sessions used by each mouse
	trialTbl2 = trialTbl(false, :);
	for iM = 1:nMice
		if isempty(sessUsed{iM}), continue; end
		trialTbl2 = [trialTbl2; trialTbl(string(trialTbl.Mouse) == mice(iM) & ismember(trialTbl.DateTime, sessUsed{iM}), :)]; %#ok
	end
	if ~isempty(trialTbl2)
		[G4, mouseU4] = findgroups(trialTbl2.Mouse);
		sdTrialVec2 = splitapply(@mean, trialTbl2.TrialSD, G4);
		for i = 1:numel(mouseU4)
			idx = find(mice == string(mouseU4(i)), 1);
			if ~isempty(idx), sdTrialVec(idx) = sdTrialVec2(i); end
		end
	end
end

keep = isfinite(slopeVec) & (isfinite(sdAvgVec) | isfinite(sdTrialVec));
slopeVec   = slopeVec(keep);
sdAvgVec   = sdAvgVec(keep);
sdTrialVec = sdTrialVec(keep);
mice       = mice(keep);
end

function s = iTrialSD(x, minCells)
if numel(x) >= minCells, s = std(x); else, s = NaN; end
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		'VariableNames',{'Mouse','DateTime','Phase','Performance'}); return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks, 'Keys','BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	dtM = DT(DT.Mouse == m, :);
	phDates = dtM.DateTime(dtM.Phase == phaseStart);
	endDates = dtM.DateTime(dtM.Phase == phaseEnd);
	if isempty(phDates) || isempty(endDates), continue; end
	startDT = min(phDates);
	endDT   = max(endDates);
	if ismissing(startDT) || ismissing(endDT), continue; end
	rows = (string(SessOut.Mouse) == m) & ...
		(SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
