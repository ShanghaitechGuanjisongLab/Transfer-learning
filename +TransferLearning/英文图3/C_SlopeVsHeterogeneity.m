% English Fig3C: Per-mouse learning slope vs Response heterogeneity
%
% For each mouse, compute:
%   - Learning slope: linear fit to performance across the learning process
%   - Response heterogeneity: mean then SD
%       per-cell mean z@1s across sessions → filter [-1,1] → std
%
% Both cohorts combined:
%   - Naive   (LightAudioBaseline + LAInterspersed): Naive→Learned
%   - Transfer (AudioLightBaseline): Transfer→Final
%
% Execution:
%   TransferLearning.英文图3.C_SlopeVsHeterogeneity

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS_LAB      = TransferLearning.LightAudioBaseline();
DS_LAI      = TransferLearning.LAInterspersed();
DS_Transfer = TransferLearning.AudioLightBaseline();
CellLAB = iCellLayerTable(DS_LAB, "LAB");
CellLAI = iCellLayerTable(DS_LAI, "LAI");
CellTransfer = iCellLayerTable(DS_Transfer, "Transfer");

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig3C:No1s', 'Cannot find sample close to 1s in time axis.');
end

% --- 1) Layer-specific data (mean then SD)
layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];

f = figure('Color', 'w', 'Name', 'Fig3C Slope vs Response heterogeneity by layer');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4];

colorN = [0.8500 0.3250 0.0980];
colorT = [0      0.4470 0.7410];
hLegend = gobjects(2, 1);
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for iL = 1:numel(layers)
	layerName = layers(iL);
	layerLabel = layerLabels(iL);
	[slopeN, sdN, miceN] = iNaiveCohortDataByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName);
	[slopeT, sdT, miceT] = iTransferCohortDataByLayer(DS_Transfer, CellTransfer, idx1s, "Transfer", "Final", layerName);

	fprintf('\n=== %s ===\n', layerLabel);
	fprintf('Naive cohort:    %d mice\n', numel(miceN));
	fprintf('Transfer cohort: %d mice\n', numel(miceT));

	slopeAll = [slopeN; slopeT];
	sdAll    = [sdN;    sdT];
	groupAll = [repmat("Naive", numel(miceN), 1); repmat("Transfer", numel(miceT), 1)];
	use = isfinite(sdAll) & isfinite(slopeAll);
	if nnz(use) >= 3 && std(sdAll(use)) > 0 && std(slopeAll(use)) > 0
		[rho, p] = corr(sdAll(use), slopeAll(use), 'Type', 'Spearman');
	else
		rho = NaN;
		p = NaN;
	end
	fprintf('Spearman rho=%.3f, p=%.4g, n=%d\n', rho, p, nnz(use));

	if p < 0.001
		pLabel = sprintf('p=%.1e', p);
	elseif p < 0.01
		pLabel = sprintf('p=%.4f', p);
	else
		pLabel = sprintf('p=%.2f', p);
	end

	ax = nexttile(tl, iL);
	hold(ax, 'on');
	ax.FontSize = 6;
	box(ax, 'off');

	maskN = use & (groupAll == "Naive");
	maskT = use & (groupAll == "Transfer");
	hN = scatter(ax, sdAll(maskN), slopeAll(maskN), 5, colorN, 'o', 'filled', 'LineWidth', 0.2);
	hT = scatter(ax, sdAll(maskT), slopeAll(maskT), 5, colorT, 's', 'filled', 'LineWidth', 0.2);
	if iL == 1
		hLegend = [hN; hT];
	end

	if nnz(use) >= 2 && std(sdAll(use)) > 0
		b = polyfit(sdAll(use), slopeAll(use), 1);
		xFit = [min(sdAll(use)), max(sdAll(use))];
		plot(ax, xFit, polyval(b, xFit), '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
	end

	title(ax, layerLabel, 'FontSize', 6);
	text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', ...
		'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);
	xlabel(ax, 'Response heterogeneity', 'FontSize', 6);
	if iL == 1
		ylabel(ax, 'Learning slope', 'FontSize', 6);
	end
end

lgd = legend(hLegend, {'Naive', 'Transfer'}, 'FontSize', 5, 'Box', 'off', 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';

% --- 4) Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3C_SlopeVsHeterogeneity.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function [slopeVec, sdVec, mice] = iNaiveCohortData(DS_LAB, DS_LAI, idx1s)
Sess = iGatherNaiveSessions(DS_LAB, DS_LAI);
Sess = iExcludeAudioWaterSessions(Sess, DS_LAB, DS_LAI);
Sess = iExcludeCeilingNaive(Sess);
[SessUsed, mice, slopeVec] = iPerMouseSlopeSessions(Sess);

if isempty(SessUsed)
	slopeVec = [];
	sdVec = [];
	mice = string.empty(0,1);
	return;
end

rawParts = {};
for dsName = ["LAB"; "LAI"]'
	dts = unique(SessUsed.DateTime(SessUsed.Source == dsName));
	if isempty(dts), continue; end
	if dsName == "LAB"
		DS = DS_LAB;
	else
		DS = DS_LAI;
	end
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
			UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	catch
		continue;
	end
	if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
	part = ntsCell{1};
	part.CellUID = uint64(part.CellUID);
	part.DateTime = iNormDT(datetime(part.DateTime));
	part.Source = repmat(dsName, height(part), 1);
	rawParts{end+1} = part; %#ok<AGROW>
end

if isempty(rawParts)
	sdVec = nan(numel(mice), 1);
	keep = isfinite(slopeVec);
	slopeVec = slopeVec(keep);
	sdVec = sdVec(keep);
	mice = mice(keep);
	return;
end

rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
[G1, cellU1, dtU1, srcU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouseMap = SessUsed(:, {'DateTime','Mouse','Source'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
dtMouseMap.Source = string(dtMouseMap.Source);
[~, iU] = unique(dtMouseMap(:, {'DateTime','Source'}), 'rows');
dtMouseMap = dtMouseMap(iU, :);

medTbl = table(cellU1, dtU1, srcU1, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', {'DateTime','Source'});

sdVec = nan(numel(mice), 1);
if ~isempty(medTbl)
	[G2, mouseU2] = findgroups(medTbl.Mouse, medTbl.CellUID);
	meanPerCell = splitapply(@mean, medTbl.Med1s, G2);
	for iM = 1:numel(mice)
		vals = meanPerCell(string(mouseU2) == mice(iM));
		vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
		if numel(vals) >= 3, sdVec(iM) = std(vals); end
	end
end

keep = isfinite(slopeVec) & isfinite(sdVec);
slopeVec = slopeVec(keep);
sdVec = sdVec(keep);
mice = mice(keep);
end

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

function [SessUsed, mice, slopeVec] = iPerMouseSlopeSessions(Sess)
if isempty(Sess)
	SessUsed = Sess;
	mice = string.empty(0,1);
	slopeVec = [];
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
mice = unique(string(Sess.Mouse));
nMice = numel(mice);
slopeVec = nan(nMice, 1);
keepRows = false(height(Sess), 1);
for iM = 1:nMice
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
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
	rows = string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime);
	if ismember('Source', Sess.Properties.VariableNames)
		rows = rows & ismember(string(Sess.Source), unique(string(R.Source)));
	end
	keepRows = keepRows | rows;
end
SessUsed = Sess(keepRows, :);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function S = iCellLayerTable(DS, sourceName)
S = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
S.Mouse = string(S.Mouse);
S.CellUID = uint64(S.CellUID);
S.ZLayer = string(S.ZLayer);
S.Source = repmat(string(sourceName), height(S), 1);
end

function [slopeVec, sdVec, miceKept] = iNaiveCohortDataByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName)
Sess = iGatherNaiveSessions(DS_LAB, DS_LAI);
Sess = iExcludeAudioWaterSessions(Sess, DS_LAB, DS_LAI);
Sess = iExcludeCeilingNaive(Sess);
[SessUsed, miceAll, slopeVecAll] = iPerMouseSlopeSessions(Sess);

if isempty(SessUsed)
	slopeVec = [];
	sdVec = [];
	miceKept = string.empty(0,1);
	return;
end

rawParts = {};
cellMaps = {CellLAB, CellLAI};
for iDS = 1:2
	if iDS == 1
		DS = DS_LAB;
		srcName = "LAB";
	else
		DS = DS_LAI;
		srcName = "LAI";
	end
	dts = unique(SessUsed.DateTime(SessUsed.Source == srcName));
	if isempty(dts), continue; end
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
			UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	catch
		continue;
	end
	if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
	part = ntsCell{1};
	part.CellUID = uint64(part.CellUID);
	part.DateTime = iNormDT(datetime(part.DateTime));
	part.Source = repmat(srcName, height(part), 1);
	part = iAttachLayer(part, cellMaps{iDS});
	rawParts{end+1} = part; %#ok<AGROW>
	end

	if isempty(rawParts)
		sdAll = nan(numel(miceAll), 1);
	else
		rawTbl = vertcat(rawParts{:});
		sig = double(rawTbl.TrialSignal);
		z1s = sig(:, idx1s);
		maskLayer = iLayerMask(rawTbl.ZLayer, layerName);
		rawTbl = rawTbl(maskLayer, :);
		z1s = z1s(maskLayer);
		if isempty(rawTbl)
			sdAll = nan(numel(miceAll), 1);
		else
			[G1, cellU1, dtU1, srcU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
			med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

			dtMouseMap = SessUsed(:, {'DateTime','Mouse','Source'});
			dtMouseMap.Mouse = string(dtMouseMap.Mouse);
			dtMouseMap.Source = string(dtMouseMap.Source);
			[~, iU] = unique(dtMouseMap(:, {'DateTime','Source'}), 'rows');
			dtMouseMap = dtMouseMap(iU, :);

			medTbl = table(cellU1, dtU1, srcU1, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
			medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', {'DateTime','Source'});

			sdAll = nan(numel(miceAll), 1);
			if ~isempty(medTbl)
				[G2, mouseU2] = findgroups(medTbl.Mouse, medTbl.CellUID);
				meanPerCell = splitapply(@mean, medTbl.Med1s, G2);
				for iM = 1:numel(miceAll)
					vals = meanPerCell(string(mouseU2) == miceAll(iM));
					vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
					if numel(vals) >= 3, sdAll(iM) = std(vals); end
				end
			end
		end
	end

	keep = isfinite(slopeVecAll) & isfinite(sdAll);
	slopeVec = slopeVecAll(keep);
	sdVec = sdAll(keep);
	miceKept = miceAll(keep);
end

function [slopeVec, sdVec, miceKept] = iTransferCohortDataByLayer(DS, CellMap, idx1s, phaseStart, phaseEnd, layerName)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);

if isempty(Sess)
	slopeVec = [];
	sdVec = [];
	miceKept = string.empty(0,1);
	return;
end

Sess = sortrows(Sess, {'Mouse','DateTime'});
[SessUsed, miceAll, slopeVecAll] = iPerMouseSlopeSessions(Sess);
if isempty(SessUsed)
	slopeVec = [];
	sdVec = [];
	miceKept = string.empty(0,1);
	return;
end

allUsedDTs = unique(SessUsed.DateTime);
try
	ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs), ...
		UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	ntsCell = {};
end

	if isempty(ntsCell) || isempty(ntsCell{1})
		sdAll = nan(numel(miceAll), 1);
	else
		rawTbl = ntsCell{1};
		rawTbl.CellUID = uint64(rawTbl.CellUID);
		rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
		rawTbl = iAttachLayer(rawTbl, CellMap);
		sig = double(rawTbl.TrialSignal);
		z1s = sig(:, idx1s);
		maskLayer = iLayerMask(rawTbl.ZLayer, layerName);
		rawTbl = rawTbl(maskLayer, :);
		z1s = z1s(maskLayer);
		if isempty(rawTbl)
			sdAll = nan(numel(miceAll), 1);
		else
			[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
			med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

			dtMouseMap = Sess(:, {'DateTime','Mouse'});
			dtMouseMap.Mouse = string(dtMouseMap.Mouse);
			[~, iU] = unique(dtMouseMap.DateTime);
			dtMouseMap = dtMouseMap(iU, :);

			medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
			medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');

			medTbl2 = medTbl(false, :);
			for iM = 1:numel(miceAll)
				sessRows = SessUsed(string(SessUsed.Mouse) == miceAll(iM), :);
				if isempty(sessRows), continue; end
				medTbl2 = [medTbl2; medTbl(string(medTbl.Mouse) == miceAll(iM) & ismember(medTbl.DateTime, sessRows.DateTime), :)]; %#ok<AGROW>
			end

			sdAll = nan(numel(miceAll), 1);
			if ~isempty(medTbl2)
				[G2, mouseU2] = findgroups(medTbl2.Mouse, medTbl2.CellUID);
				meanPerCell = splitapply(@mean, medTbl2.Med1s, G2);
				for iM = 1:numel(miceAll)
					vals = meanPerCell(string(mouseU2) == miceAll(iM));
					vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
					if numel(vals) >= 3, sdAll(iM) = std(vals); end
				end
			end
		end
	end

	keep = isfinite(slopeVecAll) & isfinite(sdAll);
	slopeVec = slopeVecAll(keep);
	sdVec = sdAll(keep);
	miceKept = miceAll(keep);
end

function T = iAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = cellMap.ZLayer(loc(has));
end

function mask = iLayerMask(zLayer, layerName)
mask = string(zLayer) == string(layerName);
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

function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});

for iDS = 1:2
	if iDS == 1
		DS = LAB;
		srcName = "LAB";
	else
		DS = LAI;
		srcName = "LAI";
	end

	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormDT(datetime(T.DateTime));
	T.Phase = string(T.Phase);
	Tr = DS.Trials;
	mice = unique(T.Mouse);

	for iM = 1:numel(mice)
		m = mice(iM);
		Tm = T(T.Mouse == m, :);
		phases = unique(Tm.Phase);
		if ~any(phases == "Naive"), continue; end

		hasLearned = any(phases == "Learned");
		hasTransfer = any(phases == "Transfer");
		sessDTs = sort(unique(Tm.DateTime));
		sessPhase = strings(numel(sessDTs), 1);
		for ii = 1:numel(sessDTs)
			ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
			ph = ph(ph ~= "" & ~ismissing(ph));
			if isempty(ph)
				sessPhase(ii) = "";
				continue;
			end
			[uPh, ~, ic] = unique(ph);
			counts = accumarray(ic, 1);
			[~, mx] = max(counts);
			sessPhase(ii) = uPh(mx);
		end

		idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
		if hasLearned
			idxEnd = find(sessPhase == "Learned", 1, 'last');
		elseif hasTransfer
			idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
			idxEnd = idxTransferStart - 1;
		else
			idxEnd = numel(sessDTs);
		end

		if isempty(idxNaiveStart) || idxEnd < idxNaiveStart, continue; end

		for k = idxNaiveStart:idxEnd
			dt = sessDTs(k);
			blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
			TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
			if isempty(TrSess), continue; end
			lwMask = string(TrSess.Stimulus) == "LightWater";
			if ~any(lwMask), continue; end
			perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
			if ~isfinite(perf), continue; end
			AllSess = [AllSess; table(m, dt, perf, srcName, ...
				'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
		end
	end
end

AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows');
AllSess = AllSess(ia, :);
end

function badMice = iFindBadMiceLAI(DS)
badMice = string.empty;
T = DS.TableQuery(["Mouse","DateTime","Phase"]);
T.Mouse = string(T.Mouse);
T.DateTime = iNormDT(datetime(T.DateTime));
T.Phase = string(T.Phase);
mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM);
	Tm = T(T.Mouse == m, :);
	dts = unique(Tm.DateTime);
	for iDT = 1:numel(dts)
		ph = Tm.Phase(Tm.DateTime == dts(iDT));
		if any(ph == "Naive" | ph == "Learned")
			if iHasStimulus(DS, m, dts(iDT), "AudioWater")
				badMice = [badMice; m]; %#ok<AGROW>
				break;
			end
		end
	end
end
badMice = unique(badMice);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess), 1);
for i = 1:height(AllSess)
	if AllSess.Source(i) == "LAB"
		DS = LAB;
	else
		DS = LAI;
	end
	if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
		keep(i) = false;
	end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
	rows = find(AllSess.Mouse == m);
	p = double(AllSess.Performance(rows));
	i100 = find(p >= 1 - 1e-12, 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus));
st = st(~ismissing(st));
tf = any(st == string(stim));
end

function iLabelPoints(ax, x, y, labels, color)
if isempty(x) || isempty(y) || isempty(labels), return; end
x = double(x(:));
y = double(y(:));
labels = string(labels(:));
keep = isfinite(x) & isfinite(y) & ~ismissing(labels);
if ~any(keep), return; end
x = x(keep);
y = y(keep);
labels = labels(keep);

xSpan = max(x) - min(x);
ySpan = max(y) - min(y);
if xSpan <= 0, xSpan = 1; end
if ySpan <= 0, ySpan = 1; end
xOff = 0.01 * xSpan;
yOff = 0.01 * ySpan;

for i = 1:numel(labels)
	text(ax, x(i) + xOff, y(i) + yOff, labels(i), ...
		'FontSize', 4.5, 'Color', color, 'Interpreter', 'none', ...
		'Clipping', 'off', 'HorizontalAlignment', 'left', ...
		'VerticalAlignment', 'bottom');
	end
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
