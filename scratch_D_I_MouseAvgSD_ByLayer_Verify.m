% Verify Fig3D and Fig3I(v2) lower-tile significance when using
% mouse-level avg-first response heterogeneity, stratified by layer.

DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_ALB = TransferLearning.AudioLightBaseline();
DS_TH  = TransferLearning.THInhibit();

CellLAB = iCellLayerTable(DS_LAB, "LAB");
CellLAI = iCellLayerTable(DS_LAI, "LAI");
CellALB = iCellLayerTable(DS_ALB, "ALB");
CellTH  = iCellLayerTable(DS_TH,  "TH");

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('ScratchDIByLayer:No1s', 'Cannot find sample close to 1s.');
end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];

% D panel cohorts
[dNaive, dNaiveMice] = iNaiveMouseAvgSDByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layers);
[dTransfer, dTransferMice] = iTransferLikeMouseAvgSDByLayer(DS_ALB, CellALB, idx1s, "Transfer", "Final", layers);

% I v2 panel cohorts
[iCtrl, iCtrlMice] = iTransferLikeMouseAvgSDByLayer(DS_ALB, CellALB, idx1s, "Transfer", "Final", layers);
[iTH, iTHMice] = iTransferLikeMouseAvgSDByLayer(DS_TH, CellTH, idx1s, "Transfer", "Final", layers);

fprintf('=== Mouse-level avg-first response heterogeneity by layer ===\n');
for iL = 1:numel(layers)
	layerName = layers(iL);
	layerLabel = layerLabels(iL);

	vdN = dNaive.SD(dNaive.Layer == layerName);
	vdT = dTransfer.SD(dTransfer.Layer == layerName);
	pD = iRanksumSafe(vdN, vdT);
	fprintf('\n[Fig3D] %s\n', layerLabel);
	fprintf('  Naive:    %.4f ± %.4f (n=%d mice)\n', mean(vdN), std(vdN)/sqrt(numel(vdN)), numel(vdN));
	fprintf('  Transfer: %.4f ± %.4f (n=%d mice)\n', mean(vdT), std(vdT)/sqrt(numel(vdT)), numel(vdT));
	fprintf('  ranksum p = %.6g\n', pD);

	viC = iCtrl.SD(iCtrl.Layer == layerName);
	viT = iTH.SD(iTH.Layer == layerName);
	pI = iRanksumSafe(viC, viT);
	fprintf('[Fig3I v2] %s\n', layerLabel);
	fprintf('  Ctrl: %.4f ± %.4f (n=%d mice)\n', mean(viC), std(viC)/sqrt(numel(viC)), numel(viC));
	fprintf('  TH:   %.4f ± %.4f (n=%d mice)\n', mean(viT), std(viT)/sqrt(numel(viT)), numel(viT));
	fprintf('  ranksum p = %.6g\n', pI);
end

fprintf('\nNaive mice with layer values: %s\n', strjoin(cellstr(unique(dNaiveMice)), ', '));
fprintf('Transfer/Ctrl mice with layer values: %s\n', strjoin(cellstr(unique(dTransferMice)), ', '));
fprintf('TH mice with layer values: %s\n', strjoin(cellstr(unique(iTHMice)), ', '));

assignin('base', 'scratch_D_byLayer_mouseavg', dNaive);
assignin('base', 'scratch_D_transfer_byLayer_mouseavg', dTransfer);
assignin('base', 'scratch_I_ctrl_byLayer_mouseavg', iCtrl);
assignin('base', 'scratch_I_th_byLayer_mouseavg', iTH);

function S = iCellLayerTable(DS, sourceName)
S = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
S.Mouse = string(S.Mouse);
S.CellUID = uint64(S.CellUID);
S.ZLayer = string(S.ZLayer);
S.Source = repmat(string(sourceName), height(S), 1);
end

function [outTbl, miceOut] = iTransferLikeMouseAvgSDByLayer(DS, CellMap, idx1s, phaseStart, phaseEnd, layers)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
Sess = sortrows(Sess, {'Mouse','DateTime'});

[SessUsed, mice] = iUsedTransferLikeSessions(Sess);
[outTbl, miceOut] = iMouseAvgByLayerSingleSource(DS, CellMap, SessUsed, mice, idx1s, layers);
end

function [SessUsed, mice] = iUsedTransferLikeSessions(Sess)
if isempty(Sess)
	SessUsed = Sess;
	mice = string.empty(0,1);
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2, continue; end
	keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
	keepMice(iM) = true;
	end
SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function [outTbl, miceOut] = iNaiveMouseAvgSDByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layers)
AllSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
AllSess = iExcludeAudioWaterSessions(AllSess, DS_LAB, DS_LAI);
AllSess = iExcludeCeilingNaive(AllSess);
AllSess = sortrows(AllSess, {'Mouse','DateTime'});

[SessUsed, mice] = iUsedNaiveSessions(AllSess);
[outTbl, miceOut] = iMouseAvgByLayerMergedSources(DS_LAB, DS_LAI, CellLAB, CellLAI, SessUsed, mice, idx1s, layers);
end

function [SessUsed, mice] = iUsedNaiveSessions(Sess)
if isempty(Sess)
	SessUsed = Sess;
	mice = string.empty(0,1);
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	perf = double(R.Performance);
	if any(~isfinite(perf)), continue; end
	keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
	keepMice(iM) = true;
	end
SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function [outTbl, miceOut] = iMouseAvgByLayerSingleSource(DS, CellMap, SessUsed, miceIn, idx1s, layers)
outTbl = table(strings(0,1), strings(0,1), nan(0,1), 'VariableNames', {'Mouse','Layer','SD'});
miceOut = string.empty(0,1);
if isempty(SessUsed) || isempty(miceIn), return; end

dts = unique(SessUsed.DateTime);
try
	ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
		UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
rawTbl = iAttachLayer(rawTbl, CellMap);
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

[G1, cellU1, dtU1, zLayer1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.ZLayer));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouse = SessUsed(:, {'DateTime','Mouse'});
dtMouse.Mouse = string(dtMouse.Mouse);
[~, iU] = unique(dtMouse.DateTime);
dtMouse = dtMouse(iU, :);

medTbl = table(cellU1, dtU1, zLayer1, med1s, 'VariableNames', {'CellUID','DateTime','ZLayer','Med1s'});
medTbl = innerjoin(medTbl, dtMouse, 'Keys', 'DateTime');

rows = [];
for iM = 1:numel(miceIn)
	for iL = 1:numel(layers)
		layerName = layers(iL);
		R = medTbl(string(medTbl.Mouse) == miceIn(iM) & string(medTbl.ZLayer) == layerName, :);
		if isempty(R), continue; end
		[~, ~, cellID] = unique(R.CellUID);
		meanPerCell = accumarray(cellID, R.Med1s, [], @mean);
		vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
		if numel(vals) >= 3
			rows = [rows; {miceIn(iM), layerName, std(vals)}]; %#ok<AGROW>
		end
	end
	end

if isempty(rows), return; end
outTbl = cell2table(rows, 'VariableNames', {'Mouse','Layer','SD'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
miceOut = unique(outTbl.Mouse);
end

function [outTbl, miceOut] = iMouseAvgByLayerMergedSources(DS_LAB, DS_LAI, CellLAB, CellLAI, SessUsed, miceIn, idx1s, layers)
outTbl = table(strings(0,1), strings(0,1), nan(0,1), 'VariableNames', {'Mouse','Layer','SD'});
miceOut = string.empty(0,1);
if isempty(SessUsed) || isempty(miceIn), return; end

rawParts = {};
for iDS = 1:2
	if iDS == 1
		DS = DS_LAB;
		srcName = "LAB";
		cellMap = CellLAB;
	else
		DS = DS_LAI;
		srcName = "LAI";
		cellMap = CellLAI;
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
	part = iAttachLayer(part, cellMap);
	rawParts{end+1} = part; %#ok<AGROW>
	end
if isempty(rawParts), return; end

rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

[G1, cellU1, dtU1, srcU1, zLayer1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source), string(rawTbl.ZLayer));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

mapTbl = SessUsed(:, {'DateTime','Source','Mouse'});
mapTbl.Source = string(mapTbl.Source);
mapTbl.Mouse = string(mapTbl.Mouse);
[~, iU] = unique(mapTbl(:, {'DateTime','Source'}), 'rows');
mapTbl = mapTbl(iU, :);

medTbl = table(cellU1, dtU1, srcU1, zLayer1, med1s, 'VariableNames', {'CellUID','DateTime','Source','ZLayer','Med1s'});
medTbl = innerjoin(medTbl, mapTbl, 'Keys', {'DateTime','Source'});

rows = [];
for iM = 1:numel(miceIn)
	for iL = 1:numel(layers)
		layerName = layers(iL);
		R = medTbl(string(medTbl.Mouse) == miceIn(iM) & string(medTbl.ZLayer) == layerName, :);
		if isempty(R), continue; end
		cellKeys = strcat(string(R.Source), "__", string(R.CellUID));
		[~, ~, cellID] = unique(cellKeys);
		meanPerCell = accumarray(cellID, R.Med1s, [], @mean);
		vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
		if numel(vals) >= 3
			rows = [rows; {miceIn(iM), layerName, std(vals)}]; %#ok<AGROW>
		end
	end
	end

if isempty(rows), return; end
outTbl = cell2table(rows, 'VariableNames', {'Mouse','Layer','SD'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
miceOut = unique(outTbl.Mouse);
end

function T = iAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = string(cellMap.ZLayer(loc(has)));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function p = iRanksumSafe(x, y)
p = NaN;
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if numel(x) >= 2 && numel(y) >= 2
	try, p = ranksum(x, y); catch, end
end
end

function Sess = iLightWaterSessions(DS)
blkCols = DS.Blocks.Properties.VariableNames;
hasMustWarn = ismember('MustWarn', blkCols);
if hasMustWarn
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		'VariableNames',{'Mouse','DateTime','Phase','Performance'});
	return;
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
	endDT = max(endDates);
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
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
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

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end