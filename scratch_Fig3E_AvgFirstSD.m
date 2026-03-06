% 验证 Fig3E: 会话对信号先平均再算SD vs 原始k+1 SD
% 对每个会话对(k, k+1)：
%   原始: session k+1 per-cell median z@1s → 筛[-1,1] → SD
%   Avg-first: 两个session共有细胞的median取平均 → 筛[-1,1] → SD

DS_T   = TransferLearning.AudioLightBaseline();
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));
minCells = 3;

%% === Transfer ===
SessT = iBuildSess(DS_T);
SessT = iExcludeCeiling(SessT);
PairsT = iPairs(SessT);
allDTsT = unique([PairsT.DT_k; PairsT.DT_k1]);
medT = iQueryMed(DS_T, allDTsT, idx1s);
[sdK1_T, sdAvg_T, dH_T] = iPairSD(PairsT, medT, minCells);
fprintf('Transfer: %d pairs\n', numel(dH_T));

%% === Naive ===
SessLAB = iBuildSess(DS_LAB);
SessLAB = iExcludeAW(DS_LAB, SessLAB);
SessLAB = iExcludeCeiling(SessLAB);
SessLAB.Source = repmat("LAB", height(SessLAB), 1);

SessLAI = iBuildSess(DS_LAI);
SessLAI = iExcludeAW(DS_LAI, SessLAI);
SessLAI = iExcludeCeiling(SessLAI);
SessLAI.Source = repmat("LAI", height(SessLAI), 1);

AllN = [SessLAB; SessLAI];
AllN = sortrows(AllN, {'Mouse','DateTime'});
[~, ia] = unique(AllN(:, {'Mouse','DateTime'}), 'rows', 'first');
AllN = AllN(ia, :);

PairsN = iPairs(AllN);

% QueryNTS per source
medN = table(uint64.empty(0,1), datetime.empty(0,1), nan(0,1), 'VariableNames', {'CellUID','DateTime','Med1s'});
for iDS = 1:2
    if iDS==1, DS=DS_LAB; else, DS=DS_LAI; end
    allDTs = unique([PairsN.DT_k; PairsN.DT_k1]);
    medPart = iQueryMed(DS, allDTs, idx1s);
    medN = [medN; medPart]; %#ok
end
[~, iu] = unique(medN(:, {'CellUID','DateTime'}), 'rows', 'first');
medN = medN(iu, :);

[sdK1_N, sdAvg_N, dH_N] = iPairSD(PairsN, medN, minCells);
fprintf('Naive: %d pairs\n', numel(dH_N));

%% === Merged ===
all_sdK1  = [sdK1_T;  sdK1_N];
all_sdAvg = [sdAvg_T; sdAvg_N];
all_dH    = [dH_T;    dH_N];

kO = isfinite(all_sdK1) & isfinite(all_dH);
[rO, pO] = corr(all_sdK1(kO), all_dH(kO), 'Type', 'Spearman');

kA = isfinite(all_sdAvg) & isfinite(all_dH);
[rA, pA] = corr(all_sdAvg(kA), all_dH(kA), 'Type', 'Spearman');

fprintf('\n=== Merged N+T ===\n');
fprintf('Original (k+1 only):  rho=%.3f p=%.4g n=%d\n', rO, pO, nnz(kO));
fprintf('Avg-first (pair avg): rho=%.3f p=%.4g n=%d\n', rA, pA, nnz(kA));

%% ===== Local functions =====

function [sdK1, sdAvg, deltaH] = iPairSD(Pairs, medTbl, minCells)
nP = height(Pairs);
sdK1 = nan(nP, 1);
sdAvg = nan(nP, 1);
deltaH = nan(nP, 1);
for iP = 1:nP
    dtK  = Pairs.DT_k(iP);
    dtK1 = Pairs.DT_k1(iP);
    deltaH(iP) = Pairs.Perf_k1(iP) - Pairs.Perf_k(iP);
    
    tK  = medTbl(medTbl.DateTime == dtK, :);
    tK1 = medTbl(medTbl.DateTime == dtK1, :);
    
    % Original: k+1 only
    vK1 = tK1.Med1s;
    vK1 = vK1(isfinite(vK1) & vK1 >= -1 & vK1 <= 1);
    if numel(vK1) >= minCells, sdK1(iP) = std(vK1); end
    
    % Avg-first: common cells averaged
    [~, ia, ib] = intersect(tK.CellUID, tK1.CellUID);
    if numel(ia) < minCells, continue; end
    avgVals = (tK.Med1s(ia) + tK1.Med1s(ib)) / 2;
    filt = avgVals(isfinite(avgVals) & avgVals >= -1 & avgVals <= 1);
    if numel(filt) >= minCells, sdAvg(iP) = std(filt); end
end
end

function medTbl = iQueryMed(DS, dts, idx1s)
medTbl = table(uint64.empty(0,1), datetime.empty(0,1), nan(0,1), 'VariableNames', {'CellUID','DateTime','Med1s'});
if isempty(dts), return; end
q = struct('Stimulus', 'LightWater', 'DateTime', dts);
try
    nc = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
    return;
end
if isempty(nc) || isempty(nc{1}), return; end
rt = nc{1};
rt.CellUID = uint64(rt.CellUID);
rt.DateTime = datetime(rt.DateTime);
if ~isempty(rt.DateTime.TimeZone), rt.DateTime.TimeZone = ''; end
sig = double(rt.TrialSignal);
z1s = sig(:, idx1s);
[G, cU, dU] = findgroups(rt.CellUID, rt.DateTime);
med = splitapply(@(x) median(x, 'omitnan'), z1s, G);
medTbl = table(cU, dU, med, 'VariableNames', {'CellUID','DateTime','Med1s'});
end

function Pairs = iPairs(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(Sess.Mouse);
rows = {};
for mi = 1:numel(mice)
    m = mice(mi);
    R = Sess(Sess.Mouse == m, :);
    if height(R) < 2, continue; end
    for j = 1:height(R)-1
        rows{end+1} = {m, R.DateTime(j), R.Performance(j), R.DateTime(j+1), R.Performance(j+1)}; %#ok
    end
end
if isempty(rows)
    Pairs = table(strings(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), ...
        'VariableNames', {'Mouse','DT_k','Perf_k','DT_k1','Perf_k1'});
    return;
end
C = vertcat(rows{:});
Pairs = table(string(C(:,1)), [C{:,2}]', [C{:,3}]', [C{:,4}]', [C{:,5}]', ...
    'VariableNames', {'Mouse','DT_k','Perf_k','DT_k1','Perf_k1'});
end

function Sess = iBuildSess(DS)
Blocks = DS.Blocks; blkVars = string(Blocks.Properties.VariableNames);
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
if ismember("MustWarn", blkVars), Blocks.MustWarn = string(Blocks.MustWarn);
else, Blocks.MustWarn = repmat("", height(Blocks), 1); end
Blocks = Blocks(:, {'BlockUID','DateTime','MustWarn'});
DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", :);
if isempty(TrLW)
    Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Performance'});
    return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwP = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
P = table(uint64(bu), lwP, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(P, Blocks, 'Keys', 'BlockUID');
T = T(ismissing(T.MustWarn) | (T.MustWarn == ""), :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
Sess = table(mouse, dt, perf, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iExcludeAW(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", :);
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
    rows = find(SessOut.Mouse == m);
    p = double(SessOut.Performance(rows));
    i100 = find(p >= 1-1e-12, 1, 'first');
    if ~isempty(i100), remove(rows(i100:end)) = true; end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end
