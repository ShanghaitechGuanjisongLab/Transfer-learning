DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_T   = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
assert(ok1s, 'Cannot find sample close to 1s.');
xMask = (xsSec >= 0) & (xsSec <= 2);

% Current formal Fig3N logic: Naive from LAB only.
sessLAB = iGetSessionsSingle(DS_LAB, false);
[sdLAB, cellsLAB] = iComputeSessionSDSingle(DS_LAB, sessLAB, idx1s, xMask);
validLAB = find(isfinite(sdLAB) & cellfun(@(x) ~isempty(x), cellsLAB));
[minLAB, iMinLAB] = min(sdLAB(validLAB));
pickLAB = validLAB(iMinLAB);

% Merged Naive logic: LAB + LAI using the same session-level SD criterion.
allNaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
allNaiveSess = iExcludeAudioWaterSessions(allNaiveSess, DS_LAB, DS_LAI);
allNaiveSess = iExcludeCeilingNaive(allNaiveSess);
[sdMerged, cellsMerged] = iComputeSessionSDMerged(allNaiveSess, DS_LAB, DS_LAI, idx1s, xMask);
validMerged = find(isfinite(sdMerged) & cellfun(@(x) ~isempty(x), cellsMerged));
[minMerged, iMinMerged] = min(sdMerged(validMerged));
pickMerged = validMerged(iMinMerged);

% Transfer retained for context.
sessT = iGetSessionsSingle(DS_T, true);
[sdT, cellsT] = iComputeSessionSDSingle(DS_T, sessT, idx1s, xMask);
validT = find(isfinite(sdT) & cellfun(@(x) ~isempty(x), cellsT));
[maxT, iMaxT] = max(sdT(validT));
pickT = validT(iMaxT);

fprintf('\n=== Fig3N current LAB-only Naive ===\n');
fprintf('Mouse=%s | DateTime=%s | SD@1s=%.6f | nCells=%d\n', ...
    string(sessLAB.Mouse(pickLAB)), string(sessLAB.DateTime(pickLAB)), minLAB, numel(cellsLAB{pickLAB}));

fprintf('\n=== Fig3N merged LAB+LAI Naive ===\n');
fprintf('Mouse=%s | Source=%s | DateTime=%s | SD@1s=%.6f | nCells=%d\n', ...
    string(allNaiveSess.Mouse(pickMerged)), string(allNaiveSess.Source(pickMerged)), string(allNaiveSess.DateTime(pickMerged)), minMerged, numel(cellsMerged{pickMerged}));

fprintf('\n=== Transfer reference (unchanged) ===\n');
fprintf('Mouse=%s | DateTime=%s | SD@1s=%.6f | nCells=%d\n', ...
    string(sessT.Mouse(pickT)), string(sessT.DateTime(pickT)), maxT, numel(cellsT{pickT}));

fprintf('\n=== Comparison ===\n');
fprintf('Naive session changed: %d\n', ~(string(sessLAB.Mouse(pickLAB)) == string(allNaiveSess.Mouse(pickMerged)) && sessLAB.DateTime(pickLAB) == allNaiveSess.DateTime(pickMerged)));
fprintf('LAB-only valid sessions: %d\n', numel(validLAB));
fprintf('Merged valid sessions:   %d\n', numel(validMerged));

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iGetSessionsSingle(DS, isTransfer)
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
    Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), 'VariableNames',{'Mouse','DateTime','Performance'});
    return;
end
    [G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if ~isempty(TrAW)
    blkAW = unique(uint64(TrAW.BlockUID));
    TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
    dtAW = unique(TAW.DateTime);
    T = T(~ismember(T.DateTime, dtAW), :);
end
    [G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2  = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
if isTransfer, phaseStart = "Transfer"; phaseEnd = "Final";
else,          phaseStart = "Naive";    phaseEnd = "Learned";
end
    mice = unique(string(Sess.Mouse));
keep = false(height(Sess), 1);
for iM = 1:numel(mice)
    m = mice(iM);
    dtM = DT(DT.Mouse == m, :);
    startDT = min(dtM.DateTime(dtM.Phase == phaseStart));
    endDT   = max(dtM.DateTime(dtM.Phase == phaseEnd));
    if isempty(startDT) || isempty(endDT) || any(ismissing([startDT endDT])), continue; end
    rows = (string(Sess.Mouse) == m) & Sess.DateTime >= startDT & Sess.DateTime <= endDT;
    keep = keep | rows;
end
Sess = Sess(keep, :);
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
remove = false(height(Sess), 1);
for m = unique(Sess.Mouse)'
    rows = find(Sess.Mouse == m);
    p = double(Sess.Performance(rows));
    i100 = find(p >= 1-1e-12, 1, 'first');
    if ~isempty(i100), remove(rows(i100:end)) = true; end
end
Sess(remove, :) = [];
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function [sdVec, cellVecs] = iComputeSessionSDSingle(DS, Sess, idx1s, xMask)
n = height(Sess);
sdVec = nan(n, 1);
cellVecs = cell(n, 1);
for iS = 1:n
    dt = Sess.DateTime(iS);
    [~, ntats] = iSessionNTATS(DS, dt);
    if isempty(ntats), continue; end
    v1s = double(ntats(:, idx1s));
    keepMask = isfinite(v1s) & v1s >= -1 & v1s <= 1;
    v1s_f = v1s(keepMask);
    if numel(v1s_f) < 5, continue; end
    [~, sortIdx] = sort(v1s_f, 'ascend');
    cellVecs{iS} = v1s_f(sortIdx); %#ok<NASGU>
    sdVec(iS) = std(v1s_f);
end
end

function [sdVec, cellVecs] = iComputeSessionSDMerged(Sess, DS_LAB, DS_LAI, idx1s, xMask)
n = height(Sess);
sdVec = nan(n, 1);
cellVecs = cell(n, 1);
for iS = 1:n
    dt = Sess.DateTime(iS);
    src = string(Sess.Source(iS));
    if src == "LAB", DS = DS_LAB; else, DS = DS_LAI; end
    [~, ntats] = iSessionNTATS(DS, dt);
    if isempty(ntats), continue; end
    v1s = double(ntats(:, idx1s));
    keepMask = isfinite(v1s) & v1s >= -1 & v1s <= 1;
    v1s_f = v1s(keepMask);
    if numel(v1s_f) < 5, continue; end
    [~, sortIdx] = sort(v1s_f, 'ascend');
    cellVecs{iS} = v1s_f(sortIdx); %#ok<NASGU>
    sdVec(iS) = std(v1s_f);
end
end

function [uid, ntats] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T), uid = uint64.empty(0,1); ntats = []; return; end
des = unique(string(T.Design)); des = des(~ismissing(des));
if numel(des) ~= 1, uid = uint64.empty(0,1); ntats = []; return; end
G = DS.QueryNTS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), UniExp.Flags.ZScore, 1:24);
if isempty(G), uid = uint64.empty(0,1); ntats = []; return; end
if iscell(G), G = G{1}; end
if isempty(G), uid = uint64.empty(0,1); ntats = []; return; end
cellUIDs  = uint64(G.CellUID);
if isa(G.TrialSignal, 'MATLAB.DataTypes.NDTable')
    ntsAll = double(G.TrialSignal.Data);
else
    ntsAll = double(G.TrialSignal);
end
uid = unique(cellUIDs, 'stable');
nCells = numel(uid);
nTime = size(ntsAll, 2);
ntats = nan(nCells, nTime);
for ic = 1:nCells
    rowsC = (cellUIDs == uid(ic));
    ntats(ic, :) = median(ntsAll(rowsC, :), 1, 'omitnan');
end
end

function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','DateTime','Performance','Source'});
for iDS = 1:2
    if iDS == 1
        DS = LAB; srcName = "LAB";
    else
        DS = LAI; srcName = "LAI";
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
    if AllSess.Source(i) == "LAB", DS = LAB; else, DS = LAI; end
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
try
    if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end