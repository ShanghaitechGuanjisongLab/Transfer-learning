% English Fig3C: Per-mouse learning slope vs Response heterogeneity
%
% For each mouse, compute:
%   - Learning slope: linear fit to performance across the learning process
%   - Response heterogeneity: per-cell mean z@1s across sessions → filter [-1,1] → std
%
% Both cohorts combined:
%   - Naive   (LightAudioBaseline): Naive→Learned
%   - Transfer (AudioLightBaseline): Transfer→Final
%
% Execution:
%   TransferLearning.英文图3.C_SlopeVsHeterogeneity

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS_Naive    = TransferLearning.LightAudioBaseline();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig3C:No1s', 'Cannot find sample close to 1s in time axis.');
end

% --- 1) Per-cohort data
[slopeN, sdN, miceN] = iCohortData(DS_Naive,    idx1s, "Naive",    "Learned");
[slopeT, sdT, miceT] = iCohortData(DS_Transfer, idx1s, "Transfer", "Final");

fprintf('Naive cohort:    %d mice\n', numel(miceN));
fprintf('Transfer cohort: %d mice\n', numel(miceT));

% --- 2) Pool
slopeAll = [slopeN; slopeT];
sdAll    = [sdN;    sdT];
groupAll = [repmat("Naive", numel(miceN), 1); repmat("Transfer", numel(miceT), 1)];

% --- 3) Figure
f = figure('Color', 'w', 'Name', 'Fig3C Slope vs Response heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

colorN = [0.8500 0.3250 0.0980];
colorT = [0      0.4470 0.7410];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 6;
box(ax, 'off');

use = isfinite(sdAll) & isfinite(slopeAll);
[rho, p] = corr(sdAll(use), slopeAll(use), 'Type', 'Spearman');
fprintf('Spearman rho=%.3f, p=%.4g, n=%d\n', rho, p, nnz(use));

if p < 0.001
	pLabel = sprintf('p=%.1e', p);
elseif p < 0.01
	pLabel = sprintf('p=%.4f', p);
else
	pLabel = sprintf('p=%.2f', p);
end

maskN = use & (groupAll == "Naive");
maskT = use & (groupAll == "Transfer");
hN = scatter(ax, sdAll(maskN), slopeAll(maskN), 5, colorN, 'o', 'filled', 'LineWidth', 0.2);
hT = scatter(ax, sdAll(maskT), slopeAll(maskT), 5, colorT, 's', 'filled', 'LineWidth', 0.2);

if nnz(use) >= 2 && std(sdAll(use)) > 0
	b = polyfit(sdAll(use), slopeAll(use), 1);
	xFit = [min(sdAll(use)), max(sdAll(use))];
	plot(ax, xFit, polyval(b, xFit), '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
end

legend(ax, [hN, hT], {'Naive', 'Transfer'}, 'FontSize', 5, 'Box', 'off', 'Location', 'best');

text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);

xlabel(ax, 'Response heterogeneity', 'FontSize', 6);
ylabel(ax, 'Learning slope', 'FontSize', 6);

% --- 4) Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3C_SlopeVsHeterogeneity.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function [slopeVec, sdVec, mice] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);

if isempty(Sess)
	slopeVec = []; sdVec = []; mice = string.empty(0,1); return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
nMice = numel(mice);
slopeVec = nan(nMice, 1);
sessUsed = cell(nMice, 1);

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

allUsedDTs = vertcat(sessUsed{:});
if isempty(allUsedDTs)
	sdVec = nan(nMice, 1);
	keep = isfinite(slopeVec); slopeVec = slopeVec(keep); sdVec = sdVec(keep); mice = mice(keep);
	return;
end
allUsedDTs = unique(allUsedDTs);

q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	sdVec = nan(nMice, 1);
	keep = isfinite(slopeVec); slopeVec = slopeVec(keep); sdVec = sdVec(keep); mice = mice(keep);
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
	sdVec = nan(nMice, 1);
	keep = isfinite(slopeVec); slopeVec = slopeVec(keep); sdVec = sdVec(keep); mice = mice(keep);
	return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID  = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

% Per-cell per-session median → per-cell mean across sessions → filter [-1,1] → SD
[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouseMap = Sess(:, {'DateTime','Mouse'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);

medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');
medTbl2 = medTbl(false, :);
for iM = 1:nMice
	if isempty(sessUsed{iM}), continue; end
	medTbl2 = [medTbl2; medTbl(string(medTbl.Mouse) == mice(iM) & ismember(medTbl.DateTime, sessUsed{iM}), :)]; %#ok
end

sdVec = nan(nMice, 1);
if ~isempty(medTbl2)
	[G2, mouseU2, cellU2] = findgroups(medTbl2.Mouse, medTbl2.CellUID);
	meanPerCell = splitapply(@mean, medTbl2.Med1s, G2);
	for iM = 1:nMice
		mask = string(mouseU2) == mice(iM);
		vals = meanPerCell(mask);
		vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
		if numel(vals) >= 3, sdVec(iM) = std(vals); end
	end
end

keep = isfinite(slopeVec) & isfinite(sdVec);
slopeVec = slopeVec(keep);
sdVec    = sdVec(keep);
mice     = mice(keep);
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
	rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
