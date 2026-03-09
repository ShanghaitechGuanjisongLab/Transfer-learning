xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[d, idx1s] = min(abs(xsSec(:) - 1));
assert(isfinite(d) && d <= 0.25, 'No sample close to 1s.');

DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();

[miceC, ~, ~] = iCohortDataLABOnly(DS_LAB, idx1s, "Naive", "Learned");

allNaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
allNaiveSess = iExcludeAudioWaterSessions(allNaiveSess, DS_LAB, DS_LAI);
allNaiveSess = iExcludeCeilingNaive(allNaiveSess);
[miceNT, ~, ~] = iCohortDataMergedNaive(allNaiveSess, DS_LAB, DS_LAI, idx1s);

fprintf('Original C naive mice (%d):\n', numel(miceC));
disp(miceC');
fprintf('Merged LAB+LAI naive mice (%d):\n', numel(miceNT));
disp(miceNT');

added = setdiff(miceNT, miceC, 'stable');
removed = setdiff(miceC, miceNT, 'stable');

fprintf('Added mice (%d):\n', numel(added));
disp(added');
fprintf('Removed mice (%d):\n', numel(removed));
disp(removed');

function [mice, slopeVec, sdVec] = iCohortDataLABOnly(DS, idx1s, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
[SessUsed, mice, slopeVec] = iPerMouseSlopeSessions(Sess);
if isempty(SessUsed)
	sdVec = [];
	mice = string.empty(0,1);
	slopeVec = [];
	return;
end
allUsedDTs = unique(SessUsed.DateTime);
ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs), ...
	UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sdVec = iPerMouseSD(rawTbl, SessUsed, mice, idx1s);
keep = isfinite(slopeVec) & isfinite(sdVec);
mice = mice(keep);
slopeVec = slopeVec(keep);
sdVec = sdVec(keep);
end

function [mice, slopeVec, sdVec] = iCohortDataMergedNaive(AllSess, DS_LAB, DS_LAI, idx1s)
[SessUsed, mice, slopeVec] = iPerMouseSlopeSessions(AllSess);
if isempty(SessUsed)
	sdVec = [];
	mice = string.empty(0,1);
	slopeVec = [];
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
	ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
		UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
	part = ntsCell{1};
	part.CellUID = uint64(part.CellUID);
	part.DateTime = iNormDT(datetime(part.DateTime));
	part.Source = repmat(dsName, height(part), 1);
	rawParts{end+1} = part; %#ok<AGROW>
end
rawTbl = vertcat(rawParts{:});
sdVec = iPerMouseSDMerged(rawTbl, SessUsed, mice, idx1s);
keep = isfinite(slopeVec) & isfinite(sdVec);
mice = mice(keep);
slopeVec = slopeVec(keep);
sdVec = sdVec(keep);
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

function sdVec = iPerMouseSD(rawTbl, SessUsed, mice, idx1s)
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);
dtMouseMap = SessUsed(:, {'DateTime','Mouse'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);
medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');
sdVec = nan(numel(mice), 1);
if isempty(medTbl), return; end
[G2, mouseU2] = findgroups(medTbl.Mouse, medTbl.CellUID);
meanPerCell = splitapply(@mean, medTbl.Med1s, G2);
for iM = 1:numel(mice)
	vals = meanPerCell(string(mouseU2) == mice(iM));
	vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
	if numel(vals) >= 3, sdVec(iM) = std(vals); end
end
end

function sdVec = iPerMouseSDMerged(rawTbl, SessUsed, mice, idx1s)
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
[G1, cellU1, dtU1, srcU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);
mapTbl = SessUsed(:, {'DateTime','Mouse','Source'});
mapTbl.Mouse = string(mapTbl.Mouse);
mapTbl.Source = string(mapTbl.Source);
[~, iU] = unique(mapTbl(:, {'DateTime','Source'}), 'rows');
mapTbl = mapTbl(iU, :);
medTbl = table(cellU1, dtU1, srcU1, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
medTbl = innerjoin(medTbl, mapTbl, 'Keys', {'DateTime','Source'});
sdVec = nan(numel(mice), 1);
if isempty(medTbl), return; end
[G2, mouseU2] = findgroups(medTbl.Mouse, medTbl.CellUID);
meanPerCell = splitapply(@mean, medTbl.Med1s, G2);
for iM = 1:numel(mice)
	vals = meanPerCell(string(mouseU2) == mice(iM));
	vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
	if numel(vals) >= 3, sdVec(iM) = std(vals); end
end
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
	if iDS == 2
		badMice = iFindBadMiceLAI(DS);
	else
		badMice = string.empty;
	end
	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormDT(datetime(T.DateTime));
	T.Phase = string(T.Phase);
	Tr = DS.Trials;
	mice = unique(T.Mouse);
	for iM = 1:numel(mice)
		m = mice(iM);
		if iDS == 2 && any(m == badMice), continue; end
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
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
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
		'VariableNames', {'Mouse','DateTime','Phase','Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
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
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
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

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus));
st = st(~ismissing(st));
tf = any(st == string(stim));
end

function dt = iNormDT(dt)
try
	if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end