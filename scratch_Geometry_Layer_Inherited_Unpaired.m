%% scratch_Geometry_Layer_Inherited_Unpaired.m
% 非配对比较 Naive LW vs Transfer LW，按2/3层和5层 × 继承/非继承 分组
% 规范：
%   Naive LW: LightAudioBaseline + LAInterspersed，排除掺杂AudioWater的Naive会话
%   Transfer LW: AudioLightBaseline
%   层信息: DS.Cells.ZLayer → "MOp2/3" / "MOp5"
%   继承定义: Learned AW 末session active cells（仅ALB有Learned AW）

cd('D:/Users/张天夫/Documents/MATLAB/Transfer-learning');

sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s = idxCue + sampleRate;

layers = ["MOp2/3", "MOp5"];
layerLabels = ["L2/3", "L5"];

%% ===== Part 1: Naive LW (LAB + LAI) — 按层计算几何指标 =====
naiveDSNames = ["LightAudioBaseline", "LAInterspersed"];

maxN = 100;
nLayerN = numel(layers);
N_PR = nan(maxN, nLayerN);
N_EVC2 = nan(maxN, nLayerN);
N_SNA = nan(maxN, nLayerN);
N_Div = nan(maxN, nLayerN);
N_nCells = nan(maxN, nLayerN);
N_Mouse = strings(maxN, 1);
N_DS = strings(maxN, 1);
nNaive = 0;

for d = 1:numel(naiveDSNames)
    dsName = naiveDSNames(d);
    switch dsName
        case "LightAudioBaseline"
            DS = TransferLearning.LightAudioBaseline();
        case "LAInterspersed"
            DS = TransferLearning.LAInterspersed();
    end

    CellTbl = DS.Cells;
    CellTbl.ZLayer = string(CellTbl.ZLayer);
    CellTbl.CellUID = uint64(CellTbl.CellUID);
    CellTbl.Mouse = string(CellTbl.Mouse);

    TnaiveAll = DS.TableQuery(["Mouse","DateTime","Stimulus","TrialUID","TrialIndex"], Phase="Naive");
    TnaiveAll.Mouse = string(TnaiveAll.Mouse);
    TnaiveAll.Stimulus = string(TnaiveAll.Stimulus);

    mice = unique(TnaiveAll.Mouse);
    for i = 1:numel(mice)
        m = mice(i);
        Tm = TnaiveAll(TnaiveAll.Mouse == m, :);
        if isempty(Tm)
            continue;
        end

        sess = unique(Tm.DateTime);
        sess = sort(sess, 'ascend');
        isValid = false(numel(sess), 1);
        for s = 1:numel(sess)
            Ts = Tm(Tm.DateTime == sess(s), :);
            if any(Ts.Stimulus == "LightWater") && ~any(Ts.Stimulus == "AudioWater")
                isValid(s) = true;
            end
        end
        validSess = sess(isValid);
        if isempty(validSess)
            continue;
        end

        dt = validSess(1);
        Ts = Tm(Tm.DateTime == dt & Tm.Stimulus == "LightWater", :);
        Ts = sortrows(Ts, "TrialIndex");
        trialUIDs = unique(uint64(Ts.TrialUID), 'stable');
        if numel(trialUIDs) < 2
            continue;
        end

        ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
        if iscell(ntsLW)
            ntsLW = ntsLW{1};
        end
        if isempty(ntsLW)
            continue;
        end

        [CTT, cellUIDs] = iLocalBuildCTT(ntsLW, trialUIDs, sampleRate, 0);
        if isempty(CTT) || size(CTT, 1) < 3
            continue;
        end

        mouseCell = CellTbl(CellTbl.Mouse == m, :);
        [~, loc] = ismember(cellUIDs, mouseCell.CellUID);
        cellLayers = strings(numel(cellUIDs), 1);
        cellLayers(loc > 0) = mouseCell.ZLayer(loc(loc > 0));

        anyLayerOk = false;
        tmpPR = nan(1, nLayerN);
        tmpEVC2 = nan(1, nLayerN);
        tmpSNA = nan(1, nLayerN);
        tmpDiv = nan(1, nLayerN);
        tmpNC = nan(1, nLayerN);
        for iL = 1:nLayerN
            mask = cellLayers == layers(iL);
            if sum(mask) < 3
                continue;
            end
            [pr, evc2, ~, sn, div] = iComputeGeometry(CTT(mask, :, :), idx1s);
            tmpPR(iL) = pr;
            tmpEVC2(iL) = evc2;
            tmpSNA(iL) = sn;
            tmpDiv(iL) = div;
            tmpNC(iL) = sum(mask);
            anyLayerOk = true;
        end

        if anyLayerOk
            nNaive = nNaive + 1;
            N_PR(nNaive, :) = tmpPR;
            N_EVC2(nNaive, :) = tmpEVC2;
            N_SNA(nNaive, :) = tmpSNA;
            N_Div(nNaive, :) = tmpDiv;
            N_nCells(nNaive, :) = tmpNC;
            N_Mouse(nNaive) = m;
            N_DS(nNaive) = dsName;
            fprintf('NaiveLW %s %s: L2/3 nC=%d PR=%.1f | L5 nC=%d PR=%.1f\n', ...
                dsName, m, tmpNC(1), tmpPR(1), tmpNC(2), tmpPR(2));
        end
    end
end

N_PR = N_PR(1:nNaive, :);
N_EVC2 = N_EVC2(1:nNaive, :);
N_SNA = N_SNA(1:nNaive, :);
N_Div = N_Div(1:nNaive, :);
N_nCells = N_nCells(1:nNaive, :);
N_Mouse = N_Mouse(1:nNaive);
N_DS = N_DS(1:nNaive);
fprintf('\nNaive LW 有效鼠数: n=%d\n\n', nNaive);

%% ===== Part 2: Transfer LW (ALB) — 按层 × 继承/非继承 =====
DS_ALB = TransferLearning.AudioLightBaseline();
CellTbl_ALB = DS_ALB.Cells;
CellTbl_ALB.ZLayer = string(CellTbl_ALB.ZLayer);
CellTbl_ALB.CellUID = uint64(CellTbl_ALB.CellUID);
CellTbl_ALB.Mouse = string(CellTbl_ALB.Mouse);

TlearnAW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TtransLW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TlearnAW.Mouse = string(TlearnAW.Mouse); TlearnAW.DateTime = datetime(TlearnAW.DateTime);
TtransLW.Mouse = string(TtransLW.Mouse); TtransLW.DateTime = datetime(TtransLW.DateTime);
try TlearnAW.DateTime.TimeZone = ''; catch, end
try TtransLW.DateTime.TimeZone = ''; catch, end

trMice = intersect(unique(TtransLW.Mouse), unique(TlearnAW.Mouse));
nT = numel(trMice);

% groups: all, inherited, non-inherited for each layer
groupNames = ["all", "inh", "non"];
nGrp = numel(groupNames);
T_PR = nan(nT, nLayerN, nGrp);
T_EVC2 = nan(nT, nLayerN, nGrp);
T_SNA = nan(nT, nLayerN, nGrp);
T_Div = nan(nT, nLayerN, nGrp);
T_nC = nan(nT, nLayerN, nGrp);
T_Mouse = strings(nT, 1);

for i = 1:nT
    m = trMice(i);
    T_Mouse(i) = m;

    ntsAW = DS_ALB.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
    ntsLW = DS_ALB.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsAW), ntsAW = ntsAW{1}; end
    if iscell(ntsLW), ntsLW = ntsLW{1}; end
    if isempty(ntsAW) || isempty(ntsLW)
        continue;
    end

    Ta = TlearnAW(TlearnAW.Mouse == m, :);
    dtA = max(Ta.DateTime);
    Ta = sortrows(Ta(Ta.DateTime == dtA, :), "TrialIndex");
    trialA = unique(uint64(Ta.TrialUID), 'stable');

    Tt = TtransLW(TtransLW.Mouse == m, :);
    dtT = min(Tt.DateTime);
    Tt = sortrows(Tt(Tt.DateTime == dtT, :), "TrialIndex");
    trialT = unique(uint64(Tt.TrialUID), 'stable');

    [CTT_A, uidA] = iLocalBuildCTT(ntsAW, trialA, sampleRate, 0);
    [CTT_T, uidT] = iLocalBuildCTT(ntsLW, trialT, sampleRate, 0);
    if isempty(CTT_A) || isempty(CTT_T)
        continue;
    end

    % inherited definition
    ntA = squeeze(mean(CTT_A, 2));
    bsl = ntA(:, 1:24);
    activeA = ntA(:, idx1s) > mean(bsl, 2) + 3 * std(bsl, [], 2);
    inhUID = uidA(activeA);
    isInh = ismember(uidT, inhUID);

    % layer info
    mCell = CellTbl_ALB(CellTbl_ALB.Mouse == m, :);
    [~, loc] = ismember(uidT, mCell.CellUID);
    cLayers = strings(numel(uidT), 1);
    cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

    for iL = 1:nLayerN
        layMask = cLayers == layers(iL);

        % all
        if sum(layMask) >= 3
            [pr, evc2, ~, sn, div] = iComputeGeometry(CTT_T(layMask, :, :), idx1s);
            T_PR(i, iL, 1) = pr;
            T_EVC2(i, iL, 1) = evc2;
            T_SNA(i, iL, 1) = sn;
            T_Div(i, iL, 1) = div;
            T_nC(i, iL, 1) = sum(layMask);
        end

        % inherited
        inhMask = layMask & isInh;
        if sum(inhMask) >= 3
            [pr, evc2, ~, sn, div] = iComputeGeometry(CTT_T(inhMask, :, :), idx1s);
            T_PR(i, iL, 2) = pr;
            T_EVC2(i, iL, 2) = evc2;
            T_SNA(i, iL, 2) = sn;
            T_Div(i, iL, 2) = div;
            T_nC(i, iL, 2) = sum(inhMask);
        end

        % non-inherited
        nonMask = layMask & ~isInh;
        if sum(nonMask) >= 3
            [pr, evc2, ~, sn, div] = iComputeGeometry(CTT_T(nonMask, :, :), idx1s);
            T_PR(i, iL, 3) = pr;
            T_EVC2(i, iL, 3) = evc2;
            T_SNA(i, iL, 3) = sn;
            T_Div(i, iL, 3) = div;
            T_nC(i, iL, 3) = sum(nonMask);
        end
    end

    fprintf('TrLW %s: L2/3 all=%.1f inh=%.1f non=%.1f | L5 all=%.1f inh=%.1f non=%.1f\n', ...
        m, T_PR(i, 1, 1), T_PR(i, 1, 2), T_PR(i, 1, 3), ...
        T_PR(i, 2, 1), T_PR(i, 2, 2), T_PR(i, 2, 3));
end

fprintf('\nTransfer LW 有效鼠数: n=%d\n\n', nT);

%% ===== Part 3: 非配对统计 =====
fprintf('================================================================\n');
fprintf('  非配对比较 NaiveLW vs TransferLW  [层 × 继承/非继承]\n');
fprintf('================================================================\n');

metrics = struct( ...
    'name', {"PR","EVC2","SNAlign","Div"}, ...
    'N', {N_PR, N_EVC2, N_SNA, N_Div}, ...
    'T', {T_PR, T_EVC2, T_SNA, T_Div});

for iM = 1:numel(metrics)
    fprintf('\n--- %s ---\n', metrics(iM).name);
    for iL = 1:nLayerN
        fprintf('[%s]\n', layerLabels(iL));
        nVec = metrics(iM).N(:, iL);
        for iG = 1:nGrp
            tVec = metrics(iM).T(:, iL, iG);
            lab = sprintf('NaiveLW(%s) vs TrLW-%s(%s)', layerLabels(iL), groupNames(iG), layerLabels(iL));
            iUnpaired(nVec, tVec, lab);
        end
    end
end

%% ===== Part 4: Transfer LW 内配对 (继承 vs 非继承, 按层) =====
fprintf('\n================================================================\n');
fprintf('  Transfer LW 内配对: Inherited vs Non-inherited (per layer)\n');
fprintf('================================================================\n');

for iM = 1:numel(metrics)
    fprintf('\n--- %s ---\n', metrics(iM).name);
    for iL = 1:nLayerN
        inhVec = metrics(iM).T(:, iL, 2);
        nonVec = metrics(iM).T(:, iL, 3);
        lab = sprintf('TrLW-%s: Inh vs Non', layerLabels(iL));
        iPaired(inhVec, nonVec, lab);
    end
end

%% ===== Part 5: 层间比较 (同一组在不同层) =====
fprintf('\n================================================================\n');
fprintf('  层间比较: L2/3 vs L5 (同一分组内)\n');
fprintf('================================================================\n');

fprintf('\n--- Naive LW ---\n');
for iM = 1:numel(metrics)
    lab = sprintf('%s NaiveLW: L2/3 vs L5', metrics(iM).name);
    iPaired(metrics(iM).N(:,1), metrics(iM).N(:,2), lab);
end

fprintf('\n--- Transfer LW ---\n');
for iM = 1:numel(metrics)
    for iG = 1:nGrp
        lab = sprintf('%s TrLW-%s: L2/3 vs L5', metrics(iM).name, groupNames(iG));
        iPaired(metrics(iM).T(:,1,iG), metrics(iM).T(:,2,iG), lab);
    end
end

%% ===== local functions =====

function iUnpaired(a, b, label)
ka = isfinite(a);
kb = isfinite(b);
na = sum(ka);
nb = sum(kb);
if na < 3 || nb < 3
    fprintf('  %s: insufficient n=%d vs %d\n', label, na, nb);
    return;
end
p = ranksum(a(ka), b(kb));
ma = mean(a(ka));
mb = mean(b(kb));
sea = std(a(ka)) / sqrt(na);
seb = std(b(kb)) / sqrt(nb);
dir = '=';
if ma < mb
    dir = '<';
elseif ma > mb
    dir = '>';
end
sig = '';
if p < 0.05
    sig = ' *';
end
if p < 0.01
    sig = ' **';
end
if p < 0.001
    sig = ' ***';
end
fprintf('  %s:\n    %.3f±%.3f(n=%d) vs %.3f±%.3f(n=%d) p=%.4g%s (%s)\n', ...
    label, ma, sea, na, mb, seb, nb, p, sig, dir);
end

function iPaired(a, b, label)
k = isfinite(a) & isfinite(b);
n = sum(k);
if n < 3
    fprintf('  %s: insufficient n=%d\n', label, n);
    return;
end
p = signrank(a(k), b(k));
ma = mean(a(k));
mb = mean(b(k));
sea = std(a(k)) / sqrt(n);
seb = std(b(k)) / sqrt(n);
dir = '=';
if ma < mb
    dir = '<';
elseif ma > mb
    dir = '>';
end
sig = '';
if p < 0.05
    sig = ' *';
end
if p < 0.01
    sig = ' **';
end
if p < 0.001
    sig = ' ***';
end
fprintf('  %s:\n    %.3f±%.3f vs %.3f±%.3f n=%d p=%.4g%s (%s)\n', ...
    label, ma, sea, mb, seb, n, p, sig, dir);
end

function [pr, evc2, evc3, snAlign, div] = iComputeGeometry(CTT, timeIdx)
X = CTT(:, :, timeIdx);
C = cov(X');
eigvals = eig(C);
eigvals = max(eigvals, 0);
eigvals = sort(eigvals, 'descend');
trEig = sum(eigvals);
trEig2 = sum(eigvals.^2);
if trEig > 0 && trEig2 > 0
    pr = trEig^2 / trEig2;
else
    pr = NaN;
end
if trEig > 0
    cumFrac = cumsum(eigvals) / trEig;
    evc2 = cumFrac(min(2, numel(cumFrac)));
    evc3 = cumFrac(min(3, numel(cumFrac)));
else
    evc2 = NaN;
    evc3 = NaN;
end
signal = mean(X, 2);
sigNorm = norm(signal);
noise = X - signal;
nTrial = size(X, 2);
noiseCov = (noise * noise') / max(nTrial - 1, 1);
[V, D] = eig(noiseCov, 'vector');
[~, ix] = sort(D, 'descend');
noisePC1 = V(:, ix(1));
if sigNorm > 0
    c = abs(dot(signal / sigNorm, noisePC1));
    snAlign = 1 - c^2;
else
    snAlign = NaN;
end
div = sqrt(sum(var(X, [], 2), 1) ./ sum(mean(X, 2).^2));
end

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate, baselineSec)
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs) < 2
    return;
end
inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial, :);
if isempty(nts2)
    return;
end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2
    return;
end
allC = unique(uint64(nts2.CellUID));
nAllC = numel(allC);
traces = cell(nAllC, 1);
keepU = zeros(nAllC, 1, 'uint64');
nKeep = 0;
for ci = 1:nAllC
    cid = allC(ci);
    rows = (uint64(nts2.CellUID) == cid);
    if sum(rows) < numel(trialUIDs)
        continue;
    end
    uid = uint64(nts2.TrialUID(rows));
    sig = double(nts2.TrialSignal(rows, :));
    [tf, loc] = ismember(trialUIDs, uid);
    if ~all(tf)
        continue;
    end
    so = sig(loc, :);
    if any(~isfinite(so), 'all')
        continue;
    end
    nKeep = nKeep + 1;
    traces{nKeep} = so;
    keepU(nKeep) = cid;
end
if nKeep < 1
    return;
end
traces = traces(1:nKeep);
keepU = keepU(1:nKeep);
nTr = size(traces{1}, 1);
nTi = size(traces{1}, 2);
CTT = nan(nKeep, nTr, nTi);
for ci = 1:nKeep
    CTT(ci, :, :) = traces{ci};
end
idx0 = max(1, min(nTi, 3 * sampleRate + round(baselineSec * sampleRate)));
CTT = CTT - CTT(:, :, idx0);
cellUIDs = keepU;
end