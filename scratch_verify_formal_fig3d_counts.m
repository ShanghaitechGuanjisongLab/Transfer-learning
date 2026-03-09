DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[d, idx1s] = min(abs(xsSec(:) - 1));
assert(isfinite(d) && d <= 0.25, 'No sample close to 1s.');

% Old formal Fig3D logic: LAB only.
SessLAB = iLightWaterSessions(DS_LAB);
SessLAB = iKeepPureLW_NoMustWarn(DS_LAB, SessLAB);
SessLAB = iKeepPhaseRange(DS_LAB, SessLAB, "Naive", "Learned");
[dhOld, sdOld, miceOld] = iCohortDataWithMice(DS_LAB, SessLAB, idx1s);

% New merged Naive logic: LAB + LAI.
AllSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
AllSess = iExcludeAudioWaterSessions(AllSess, DS_LAB, DS_LAI);
AllSess = iExcludeCeilingNaive(AllSess);
[dhNew, usedNew, miceNew] = iNaiveDeltaHitSessions(AllSess);
sdNew = iNaiveSessionSD(usedNew, DS_LAB, DS_LAI, idx1s);

fprintf('\nOLD_FORMAL_LAB_ONLY\n');
fprintf('mice=%d, pairs=%d, sessions=%d\n', numel(miceOld), numel(dhOld), numel(sdOld));
disp(miceOld');
fprintf('meanDeltaHit=%.6f, meanSD=%.6f\n', mean(dhOld), mean(sdOld));

fprintf('\nNEW_MERGED_LAB_LAI\n');
fprintf('mice=%d, pairs=%d, sessions=%d\n', numel(miceNew), numel(dhNew), numel(sdNew));
disp(miceNew');
fprintf('meanDeltaHit=%.6f, meanSD=%.6f\n', mean(dhNew), mean(sdNew));

fprintf('\nADDED_MICE\n');
disp(setdiff(miceNew, miceOld, 'stable')');
fprintf('REMOVED_MICE\n');
disp(setdiff(miceOld, miceNew, 'stable')');

function [dhVec, sdVec, miceUsed] = iCohortDataWithMice(DS, Sess, idx1s)
if isempty(Sess)
    dhVec = [];
    sdVec = [];
    miceUsed = string.empty(0,1);
    return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
mice = unique(string(Sess.Mouse));
dhVec = [];
allUsedDTs = datetime.empty(0,1);
miceKeep = false(numel(mice),1);
for iM = 1:numel(mice)
    m = mice(iM);
    R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
    if height(R) < 2, continue; end
    first100 = find(double(R.Performance) >= 1.0, 1, 'first');
    if ~isempty(first100) && first100 > 1
        R = R(1:first100-1, :);
    elseif ~isempty(first100) && first100 == 1
        continue;
    end
    if height(R) < 2, continue; end
    perf = double(R.Performance);
    dhVec = [dhVec; diff(perf)]; %#ok<AGROW>
    allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
    miceKeep(iM) = true;
end
miceUsed = mice(miceKeep);
allUsedDTs = unique(allUsedDTs);
sdVec = [];
if isempty(allUsedDTs), return; end
q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
rawTbl = ntsCell{1};
rawTbl.CellUID  = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
[G1, ~, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);
uDTs = unique(dtU1);
sdVec = nan(numel(uDTs),1);
for iDT = 1:numel(uDTs)
    vals = med1s(dtU1 == uDTs(iDT));
    vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
    if numel(vals) >= 3, sdVec(iDT) = std(vals); end
end
sdVec = sdVec(isfinite(sdVec));
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
    Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
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
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','DateTime','Performance','Source'});
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
            AllSess = [AllSess; table(m, dt, perf, srcName, 'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
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

function [dhVec, SessUsed, mice] = iNaiveDeltaHitSessions(Sess)
if isempty(Sess)
    SessUsed = Sess;
    dhVec = [];
    mice = string.empty(0,1);
    return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
dhVec = [];
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
    if height(R) < 2, continue; end
    perf = double(R.Performance);
    if any(~isfinite(perf)), continue; end
    dhVec = [dhVec; diff(perf)]; %#ok<AGROW>
    keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
    keepMice(iM) = true;
end
SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function sdVec = iNaiveSessionSD(SessUsed, DS_LAB, DS_LAI, idx1s)
sdVec = [];
if isempty(SessUsed), return; end
rawParts = {};
for srcName = ["LAB"; "LAI"]'
    dts = unique(SessUsed.DateTime(SessUsed.Source == srcName));
    if isempty(dts), continue; end
    if srcName == "LAB"
        DS = DS_LAB;
    else
        DS = DS_LAI;
    end
    ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
    if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
    part = ntsCell{1};
    part.CellUID = uint64(part.CellUID);
    part.DateTime = iNormDT(datetime(part.DateTime));
    part.Source = repmat(srcName, height(part), 1);
    rawParts{end+1} = part; %#ok<AGROW>
end
if isempty(rawParts), return; end
rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
[G1, ~, dtU1, srcU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);
mapTbl = SessUsed(:, {'DateTime','Source'});
mapTbl.Source = string(mapTbl.Source);
[~, iU] = unique(mapTbl(:, {'DateTime','Source'}), 'rows');
mapTbl = mapTbl(iU, :);
medTbl = table(dtU1, srcU1, med1s, 'VariableNames', {'DateTime','Source','Med1s'});
medTbl = innerjoin(medTbl, mapTbl, 'Keys', {'DateTime','Source'});
[G2, ~, ~] = findgroups(medTbl.DateTime, medTbl.Source);
sdPerSess = splitapply(@iSessionBoundedSD, medTbl.Med1s, G2);
sdVec = sdPerSess(isfinite(sdPerSess));
end

function out = iSessionBoundedSD(vals)
vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
if numel(vals) >= 3
    out = std(vals);
else
    out = NaN;
end
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
    if isdatetime(dt) && ~isempty(dt.TimeZone)
        dt.TimeZone = '';
    end
catch
end
end