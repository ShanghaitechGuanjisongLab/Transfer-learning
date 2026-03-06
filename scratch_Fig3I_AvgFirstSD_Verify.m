% 验证：Fig3I 下半 tile 用"先平均后筛"细胞间SD的显著性
% 方法：对每对相邻会话，跨两会话对每只细胞取 median z@1s 的均值，
%       筛 [-1,1]，再算 std → 逐对 SD 值 → Ctrl vs TH ranksum
%
% 全程向量化：batch QueryNTS → splitapply 计算 per-cell-session 中位数
%
% Execution:
%   TransferLearning.scratch_Fig3I_AvgFirstSD_Verify (or run directly)

CtrlDS = TransferLearning.AudioLightBaseline();
THDS   = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));
minCells = 3;

[sdCtrl, pCtrl] = iGroupPairSDs(CtrlDS, idx1s, minCells);
[sdTH,   pTH  ] = iGroupPairSDs(THDS,   idx1s, minCells);

kC = isfinite(sdCtrl); kT = isfinite(sdTH);

fprintf('\n=== Fig3I 下半 tile: 先平均后筛 inter-cell SD@1s ===\n');
fprintf('Ctrl: n=%d pairs, %.4f ± %.4f\n', sum(kC), mean(sdCtrl(kC)), std(sdCtrl(kC))/sqrt(sum(kC)));
fprintf('TH:   n=%d pairs, %.4f ± %.4f\n', sum(kT), mean(sdTH(kT)),   std(sdTH(kT))/sqrt(sum(kT)));

xC = sdCtrl(kC); xT = sdTH(kT);
if numel(xC) >= 2 && numel(xT) >= 2
    p = ranksum(xC, xT);
    fprintf('ranksum p = %.4g\n', p);
else
    fprintf('样本量不足\n');
end

%% ===== Local functions =====

function [sdVec, nValidPairs] = iGroupPairSDs(DS, idx1s, minCells)
% Build sessions → pairs → batch QueryNTS → vectorized per-cell median → pair SD

Sess  = iLWSessions(DS);
Sess  = iExcludeCeiling(Sess);
Pairs = iSessionPairs(Sess);
nP    = height(Pairs);
sdVec = nan(nP, 1);
if nP == 0, nValidPairs = 0; return; end

allDTs = unique([Pairs.DateTime; Pairs.DateTimeNext]);

% --- Batch QueryNTS with ExtraColumns DateTime ---
q = struct('Stimulus', 'LightWater', 'DateTime', allDTs);
try
    ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
    nValidPairs = 0; return;
end
if isempty(ntsCell) || isempty(ntsCell{1}), nValidPairs = 0; return; end

rawTbl = ntsCell{1};
if ~istable(rawTbl) || height(rawTbl) == 0, nValidPairs = 0; return; end

rawTbl.CellUID  = uint64(rawTbl.CellUID);
rawTbl.DateTime = datetime(rawTbl.DateTime);
if ~isempty(rawTbl.DateTime.TimeZone), rawTbl.DateTime.TimeZone = ''; end

sig = double(rawTbl.TrialSignal);
if size(sig, 2) < idx1s, nValidPairs = 0; return; end

% --- Vectorized: per-cell per-session median at idx1s ---
col1s = sig(:, idx1s);
[G, cellUID_u, dt_u] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), col1s, G);
cellMedTbl = table(cellUID_u, dt_u, med1s, ...
    'VariableNames', {'CellUID', 'DateTime', 'Med1s'});

% --- Loop over pairs (n small), vectorized inner ops ---
for iP = 1:nP
    dt1 = Pairs.DateTime(iP);
    dt2 = Pairs.DateTimeNext(iP);

    mask = (cellMedTbl.DateTime == dt1) | (cellMedTbl.DateTime == dt2);
    rows = cellMedTbl(mask, :);
    if isempty(rows), continue; end

    % Per-cell mean across the two sessions
    [G2, ~] = findgroups(rows.CellUID);
    meanPerCell = splitapply(@mean, rows.Med1s, G2);

    keep = isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1;
    if nnz(keep) >= minCells
        sdVec(iP) = std(meanPerCell(keep));
    end
end
nValidPairs = nnz(isfinite(sdVec));
end

function Sess = iLWSessions(DS)
blkVars = string(DS.Blocks.Properties.VariableNames);
if ismember("MustWarn", blkVars)
    Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
    Blocks.MustWarn = string(Blocks.MustWarn);
else
    Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
    Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", :);
if isempty(TrLW)
    Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), ...
        'VariableNames', {'Mouse','DateTime','Performance'}); return;
end

[G, bu] = findgroups(TrLW.BlockUID);
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
P = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(P, Blocks, 'Keys', 'BlockUID');
T = T(ismissing(T.MustWarn) | (T.MustWarn == ""), :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
Sess = table(mouse, dt, perf2, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
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
    i100 = find(p >= 1 - 1e-12, 1, 'first');
    if ~isempty(i100), remove(rows(i100:end)) = true; end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function Pairs = iSessionPairs(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(Sess.Mouse);

nTotal = sum(arrayfun(@(m) max(0, nnz(Sess.Mouse==m)-1), mice));
outMouse = strings(nTotal, 1);
outDT    = NaT(nTotal, 1);
outDT2   = NaT(nTotal, 1);
outPerf  = nan(nTotal, 1);
outPerf2 = nan(nTotal, 1);

pos = 0;
for mi = 1:numel(mice)
    m = mice(mi);
    R = Sess(Sess.Mouse == m, :);
    ok = isfinite(double(R.Performance)) & ~ismissing(R.DateTime);
    R = R(ok, :);
    if height(R) < 2, continue; end
    n = height(R) - 1;
    idx = (pos+1):(pos+n);
    outMouse(idx) = repmat(m, n, 1);
    outDT(idx)    = R.DateTime(1:end-1);
    outDT2(idx)   = R.DateTime(2:end);
    outPerf(idx)  = double(R.Performance(1:end-1));
    outPerf2(idx) = double(R.Performance(2:end));
    pos = pos + n;
end
Pairs = table(outMouse(1:pos), outDT(1:pos), outPerf(1:pos), outDT2(1:pos), outPerf2(1:pos), ...
    'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext'});
end
