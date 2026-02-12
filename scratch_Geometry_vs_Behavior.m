%% scratch_Geometry_vs_Behavior.m
% 两个目标：
% 1. 几何指标 vs 首会话命中率的 Spearman 相关（Naive + Transfer 分别验证）
% 2. Hit vs Miss 回合的几何指标配对比较
%
% 层: All, L2/3(MOp2/3), L5(MOp5)
% 细胞组: all, inherited, non-inherited (Transfer only)
% 几何指标: PR, EVC2, SNAlign, Div
% 时间点: 1s post-cue (idx=32)

cd('D:/Users/张天夫/Documents/MATLAB/Transfer-learning');

sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s = idxCue + sampleRate;

layers = ["All", "MOp2/3", "MOp5"];
layerLabels = ["All", "L2/3", "L5"];
nLay = numel(layers);

%% ===== Part 1: Transfer LW (ALB) =====
DS_ALB = TransferLearning.AudioLightBaseline();

CellTbl = DS_ALB.Cells;
CellTbl.ZLayer = string(CellTbl.ZLayer);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);

% 获取 Transfer LW 的 TrialUID + Behavior
Ttrans = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Transfer");
Ttrans.Mouse = string(Ttrans.Mouse);
Ttrans.Stimulus = string(Ttrans.Stimulus);
Ttrans = Ttrans(Ttrans.Stimulus == "LightWater", :);
Ttrans.DateTime = datetime(Ttrans.DateTime);
try Ttrans.DateTime.TimeZone = ''; catch, end

% Learned AW 数据（用于继承组定义）
TlearnAW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TlearnAW.Mouse = string(TlearnAW.Mouse);
TlearnAW.DateTime = datetime(TlearnAW.DateTime);
try TlearnAW.DateTime.TimeZone = ''; catch, end

trMice = unique(Ttrans.Mouse);
nT = numel(trMice);

% groups: all, inherited, non-inherited
groupNames = ["all", "inh", "non"];
nGrp = numel(groupNames);
% trial conditions: allTrials, hitTrials, missTrials
condNames = ["all", "hit", "miss"];
nCond = numel(condNames);

% 结果存储: [mouse, layer, group, trialCond]
T_PR   = nan(nT, nLay, nGrp, nCond);
T_EVC2 = nan(nT, nLay, nGrp, nCond);
T_SNA  = nan(nT, nLay, nGrp, nCond);
T_Div  = nan(nT, nLay, nGrp, nCond);
T_nC   = nan(nT, nLay, nGrp);
T_nTrialHit  = nan(nT, 1);
T_nTrialMiss = nan(nT, 1);
T_HitRate = nan(nT, 1);
T_Mouse = strings(nT, 1);

for i = 1:nT
    m = trMice(i);
    T_Mouse(i) = m;

    Tm = Ttrans(Ttrans.Mouse == m, :);
    dt = min(Tm.DateTime);
    Ts = Tm(Tm.DateTime == dt, :);
    Ts = sortrows(Ts, "TrialIndex");

    % Hit Rate
    beh = double(Ts.Behavior);
    beh = beh(isfinite(beh));
    T_HitRate(i) = mean(beh);

    allUID = unique(uint64(Ts.TrialUID), 'stable');
    hitUID = unique(uint64(Ts.TrialUID(Ts.Behavior > 0.5)), 'stable');
    missUID = unique(uint64(Ts.TrialUID(Ts.Behavior <= 0.5 & isfinite(Ts.Behavior))), 'stable');
    T_nTrialHit(i) = numel(hitUID);
    T_nTrialMiss(i) = numel(missUID);

    % NTS
    ntsLW = DS_ALB.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsLW), ntsLW = ntsLW{1}; end
    if isempty(ntsLW), continue; end

    % Inherited definition
    ntsAW = DS_ALB.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsAW), ntsAW = ntsAW{1}; end

    inhUID = uint64([]);
    if ~isempty(ntsAW)
        Ta = TlearnAW(TlearnAW.Mouse == m, :);
        dtA = max(Ta.DateTime);
        Ta = sortrows(Ta(Ta.DateTime == dtA, :), "TrialIndex");
        trialA = unique(uint64(Ta.TrialUID), 'stable');
        [CTT_A, uidA] = iLocalBuildCTT(ntsAW, trialA, sampleRate, 0);
        if ~isempty(CTT_A) && size(CTT_A, 1) >= 3
            ntA = squeeze(mean(CTT_A, 2));
            bsl = ntA(:, 1:24);
            activeA = ntA(:, idx1s) > mean(bsl, 2) + 3 * std(bsl, [], 2);
            inhUID = uidA(activeA);
        end
    end

    % Build CTTs for all/hit/miss trial sets
    trialSets = {allUID, hitUID, missUID};

    for iC = 1:nCond
        tUID = trialSets{iC};
        if numel(tUID) < 2, continue; end

        [CTT, uidLW] = iLocalBuildCTT(ntsLW, tUID, sampleRate, 0);
        if isempty(CTT) || size(CTT, 1) < 3, continue; end

        % Layer info
        mCell = CellTbl(CellTbl.Mouse == m, :);
        [~, loc] = ismember(uidLW, mCell.CellUID);
        cLayers = strings(numel(uidLW), 1);
        cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

        isInh = ismember(uidLW, inhUID);

        for iL = 1:nLay
            if layers(iL) == "All"
                layMask = true(numel(uidLW), 1);
            else
                layMask = cLayers == layers(iL);
            end

            for iG = 1:nGrp
                switch groupNames(iG)
                    case "all"
                        mask = layMask;
                    case "inh"
                        mask = layMask & isInh;
                    case "non"
                        mask = layMask & ~isInh;
                end

                if sum(mask) < 3, continue; end
                [pr, evc2, ~, sn, div] = iComputeGeometry(CTT(mask, :, :), idx1s);

                T_PR(i, iL, iG, iC) = pr;
                T_EVC2(i, iL, iG, iC) = evc2;
                T_SNA(i, iL, iG, iC) = sn;
                T_Div(i, iL, iG, iC) = div;

                if iC == 1
                    T_nC(i, iL, iG) = sum(mask);
                end
            end
        end
    end

    fprintf('Transfer %s: HR=%.3f nHit=%d nMiss=%d | PR(all)=%.1f PR(hit)=%.1f PR(miss)=%.1f\n', ...
        m, T_HitRate(i), T_nTrialHit(i), T_nTrialMiss(i), ...
        T_PR(i,1,1,1), T_PR(i,1,1,2), T_PR(i,1,1,3));
end

fprintf('\nTransfer mice: n=%d\n\n', nT);

%% ===== Part 2: Naive LW (LAB + LAI) =====
naiveDSNames = ["LightAudioBaseline", "LAInterspersed"];

maxN = 30;
N_PR   = nan(maxN, nLay, nCond);
N_EVC2 = nan(maxN, nLay, nCond);
N_SNA  = nan(maxN, nLay, nCond);
N_Div  = nan(maxN, nLay, nCond);
N_nC   = nan(maxN, nLay);
N_nTrialHit  = nan(maxN, 1);
N_nTrialMiss = nan(maxN, 1);
N_HitRate = nan(maxN, 1);
N_Mouse = strings(maxN, 1);
nNaive = 0;

for d = 1:numel(naiveDSNames)
    dsName = naiveDSNames(d);
    switch dsName
        case "LightAudioBaseline"
            DS = TransferLearning.LightAudioBaseline();
        case "LAInterspersed"
            DS = TransferLearning.LAInterspersed();
    end

    CellTbl2 = DS.Cells;
    CellTbl2.ZLayer = string(CellTbl2.ZLayer);
    CellTbl2.CellUID = uint64(CellTbl2.CellUID);
    CellTbl2.Mouse = string(CellTbl2.Mouse);

    TnaiveAll = DS.TableQuery(["Mouse","DateTime","Stimulus","TrialUID","TrialIndex","Behavior"], Phase="Naive");
    TnaiveAll.Mouse = string(TnaiveAll.Mouse);
    TnaiveAll.Stimulus = string(TnaiveAll.Stimulus);

    mice = unique(TnaiveAll.Mouse);
    for i = 1:numel(mice)
        m = mice(i);
        Tm = TnaiveAll(TnaiveAll.Mouse == m, :);
        if isempty(Tm), continue; end

        sess = unique(Tm.DateTime);
        sess = sort(sess, 'ascend');
        isValid = false(numel(sess), 1);
        for s = 1:numel(sess)
            Tss = Tm(Tm.DateTime == sess(s), :);
            if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
                isValid(s) = true;
            end
        end
        validSess = sess(isValid);
        if isempty(validSess), continue; end

        dt = validSess(1);
        Ts = Tm(Tm.DateTime == dt & Tm.Stimulus == "LightWater", :);
        Ts = sortrows(Ts, "TrialIndex");

        % Hit Rate
        beh = double(Ts.Behavior);
        beh = beh(isfinite(beh));
        hitRate = mean(beh);

        allUID  = unique(uint64(Ts.TrialUID), 'stable');
        hitUID  = unique(uint64(Ts.TrialUID(Ts.Behavior > 0.5)), 'stable');
        missUID = unique(uint64(Ts.TrialUID(Ts.Behavior <= 0.5 & isfinite(Ts.Behavior))), 'stable');

        if numel(allUID) < 2, continue; end

        ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
        if iscell(ntsLW), ntsLW = ntsLW{1}; end
        if isempty(ntsLW), continue; end

        trialSets = {allUID, hitUID, missUID};
        anyOk = false;

        tmpPR   = nan(nLay, nCond);
        tmpEVC2 = nan(nLay, nCond);
        tmpSNA  = nan(nLay, nCond);
        tmpDiv  = nan(nLay, nCond);
        tmpNC   = nan(nLay, 1);

        for iC = 1:nCond
            tUID = trialSets{iC};
            if numel(tUID) < 2, continue; end

            [CTT, uidLW] = iLocalBuildCTT(ntsLW, tUID, sampleRate, 0);
            if isempty(CTT) || size(CTT, 1) < 3, continue; end

            mCell = CellTbl2(CellTbl2.Mouse == m, :);
            [~, loc] = ismember(uidLW, mCell.CellUID);
            cLayers = strings(numel(uidLW), 1);
            cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

            for iL = 1:nLay
                if layers(iL) == "All"
                    mask = true(numel(uidLW), 1);
                else
                    mask = cLayers == layers(iL);
                end

                if sum(mask) < 3, continue; end
                [pr, evc2, ~, sn, div] = iComputeGeometry(CTT(mask, :, :), idx1s);
                tmpPR(iL, iC) = pr;
                tmpEVC2(iL, iC) = evc2;
                tmpSNA(iL, iC) = sn;
                tmpDiv(iL, iC) = div;
                if iC == 1
                    tmpNC(iL) = sum(mask);
                end
                anyOk = true;
            end
        end

        if anyOk
            nNaive = nNaive + 1;
            N_PR(nNaive, :, :) = tmpPR;
            N_EVC2(nNaive, :, :) = tmpEVC2;
            N_SNA(nNaive, :, :) = tmpSNA;
            N_Div(nNaive, :, :) = tmpDiv;
            N_nC(nNaive, :) = tmpNC;
            N_HitRate(nNaive) = hitRate;
            N_nTrialHit(nNaive) = numel(hitUID);
            N_nTrialMiss(nNaive) = numel(missUID);
            N_Mouse(nNaive) = m;
            fprintf('Naive %s %s: HR=%.3f nHit=%d nMiss=%d | PR(all)=%.1f\n', ...
                dsName, m, hitRate, numel(hitUID), numel(missUID), tmpPR(1,1));
        end
    end
end

N_PR   = N_PR(1:nNaive, :, :);
N_EVC2 = N_EVC2(1:nNaive, :, :);
N_SNA  = N_SNA(1:nNaive, :, :);
N_Div  = N_Div(1:nNaive, :, :);
N_nC   = N_nC(1:nNaive, :);
N_HitRate = N_HitRate(1:nNaive);
N_nTrialHit = N_nTrialHit(1:nNaive);
N_nTrialMiss = N_nTrialMiss(1:nNaive);
N_Mouse = N_Mouse(1:nNaive);

fprintf('\nNaive mice: n=%d\n\n', nNaive);

%% ===== Part 3: Spearman correlations with hit rate =====
fprintf('================================================================\n');
fprintf('  Spearman 相关: 几何指标 vs 首会话命中率\n');
fprintf('================================================================\n');

metricNames = ["PR", "EVC2", "SNAlign", "Div"];

% Transfer: all trials, 3 layers × 3 groups
fprintf('\n--- Transfer (n=%d) ---\n', nT);
for iM = 1:4
    fprintf('\n[%s]\n', metricNames(iM));
    for iL = 1:nLay
        for iG = 1:nGrp
            switch iM
                case 1, vec = T_PR(:, iL, iG, 1);
                case 2, vec = T_EVC2(:, iL, iG, 1);
                case 3, vec = T_SNA(:, iL, iG, 1);
                case 4, vec = T_Div(:, iL, iG, 1);
            end
            lab = sprintf('%s-%s', layerLabels(iL), groupNames(iG));
            iSpearman(vec, T_HitRate, lab);
        end
    end
end

% Naive: all trials, 3 layers (no cell group split)
fprintf('\n--- Naive (n=%d) ---\n', nNaive);
for iM = 1:4
    fprintf('\n[%s]\n', metricNames(iM));
    for iL = 1:nLay
        switch iM
            case 1, vec = N_PR(:, iL, 1);
            case 2, vec = N_EVC2(:, iL, 1);
            case 3, vec = N_SNA(:, iL, 1);
            case 4, vec = N_Div(:, iL, 1);
        end
        lab = sprintf('%s-all', layerLabels(iL));
        iSpearman(vec, N_HitRate, lab);
    end
end

%% ===== Part 4: 非配对比较 (如果相关方向一致) =====
fprintf('\n================================================================\n');
fprintf('  Rank-sum: Transfer vs Naive (全试次几何指标)\n');
fprintf('================================================================\n');

for iM = 1:4
    fprintf('\n[%s]\n', metricNames(iM));
    for iL = 1:nLay
        switch iM
            case 1, tVec = T_PR(:, iL, 1, 1); nVec = N_PR(:, iL, 1);
            case 2, tVec = T_EVC2(:, iL, 1, 1); nVec = N_EVC2(:, iL, 1);
            case 3, tVec = T_SNA(:, iL, 1, 1); nVec = N_SNA(:, iL, 1);
            case 4, tVec = T_Div(:, iL, 1, 1); nVec = N_Div(:, iL, 1);
        end
        lab = sprintf('%s T(n=%d) vs N(n=%d)', layerLabels(iL), sum(isfinite(tVec)), sum(isfinite(nVec)));
        iRanksum(tVec, nVec, lab);
    end
end

%% ===== Part 5: Hit vs Miss 几何指标配对比较 =====
fprintf('\n================================================================\n');
fprintf('  Hit vs Miss 回合几何指标 (配对 signed-rank)\n');
fprintf('================================================================\n');

fprintf('\n--- Transfer (需 nHit>=3 且 nMiss>=3) ---\n');
for iM = 1:4
    fprintf('\n[%s]\n', metricNames(iM));
    for iL = 1:nLay
        for iG = 1:nGrp
            switch iM
                case 1, hVec = T_PR(:, iL, iG, 2); mVec = T_PR(:, iL, iG, 3);
                case 2, hVec = T_EVC2(:, iL, iG, 2); mVec = T_EVC2(:, iL, iG, 3);
                case 3, hVec = T_SNA(:, iL, iG, 2); mVec = T_SNA(:, iL, iG, 3);
                case 4, hVec = T_Div(:, iL, iG, 2); mVec = T_Div(:, iL, iG, 3);
            end
            lab = sprintf('Transfer %s-%s: Hit vs Miss', layerLabels(iL), groupNames(iG));
            iPaired(hVec, mVec, lab);
        end
    end
end

fprintf('\n--- Naive (需 nHit>=3 且 nMiss>=3) ---\n');
for iM = 1:4
    fprintf('\n[%s]\n', metricNames(iM));
    for iL = 1:nLay
        switch iM
            case 1, hVec = N_PR(:, iL, 2); mVec = N_PR(:, iL, 3);
            case 2, hVec = N_EVC2(:, iL, 2); mVec = N_EVC2(:, iL, 3);
            case 3, hVec = N_SNA(:, iL, 2); mVec = N_SNA(:, iL, 3);
            case 4, hVec = N_Div(:, iL, 2); mVec = N_Div(:, iL, 3);
        end
        lab = sprintf('Naive %s-all: Hit vs Miss', layerLabels(iL));
        iPaired(hVec, mVec, lab);
    end
end

%% ===== Part 6: 三重筛选总结 =====
fprintf('\n================================================================\n');
fprintf('  三重筛选总结\n');
fprintf('  ① Transfer Spearman p<0.05\n');
fprintf('  ② Naive Spearman p<0.05\n');
fprintf('  ③ Rank-sum p<0.05 + 方向一致\n');
fprintf('================================================================\n\n');

for iM = 1:4
    for iL = 1:nLay
        for iG = 1:nGrp
            % 只有 all group 可以 naive vs transfer
            if iG > 1, continue; end

            switch iM
                case 1
                    tVec = T_PR(:, iL, 1, 1); nVec = N_PR(:, iL, 1);
                case 2
                    tVec = T_EVC2(:, iL, 1, 1); nVec = N_EVC2(:, iL, 1);
                case 3
                    tVec = T_SNA(:, iL, 1, 1); nVec = N_SNA(:, iL, 1);
                case 4
                    tVec = T_Div(:, iL, 1, 1); nVec = N_Div(:, iL, 1);
            end

            % ① Transfer Spearman
            kt = isfinite(tVec) & isfinite(T_HitRate);
            if sum(kt) < 5, continue; end
            [rhoT, pT] = corr(tVec(kt), T_HitRate(kt), 'type', 'Spearman');

            % ② Naive Spearman
            kn = isfinite(nVec) & isfinite(N_HitRate);
            if sum(kn) < 5, continue; end
            [rhoN, pN] = corr(nVec(kn), N_HitRate(kn), 'type', 'Spearman');

            % ③ Rank-sum + direction
            kkt = isfinite(tVec); kkn = isfinite(nVec);
            pRS = ranksum(tVec(kkt), nVec(kkn));
            mt = mean(tVec(kkt)); mn = mean(nVec(kkn));

            pass1 = pT < 0.05;
            pass2 = pN < 0.05;
            dirOk = sign(rhoT) == sign(rhoN);
            rsDir = (rhoT > 0 && mt > mn) || (rhoT < 0 && mt < mn);
            pass3 = pRS < 0.05 && dirOk && rsDir;

            sig = '';
            if pass1, sig = [sig, '①']; end %#ok<AGROW>
            if pass2, sig = [sig, '②']; end %#ok<AGROW>
            if pass3, sig = [sig, '③']; end %#ok<AGROW>
            if isempty(sig), sig = '—'; end

            fprintf('%s %s: T ρ=%+.3f(p=%.3g) N ρ=%+.3f(p=%.3g) RS p=%.3g  [%s]\n', ...
                metricNames(iM), layerLabels(iL), rhoT, pT, rhoN, pN, pRS, sig);
        end
    end
end

% Also check inherited subgroups for Transfer-only Spearman
fprintf('\n--- Transfer-only Spearman (inherited / non-inherited subgroups) ---\n');
for iM = 1:4
    for iL = 1:nLay
        for iG = 2:3
            switch iM
                case 1, vec = T_PR(:, iL, iG, 1);
                case 2, vec = T_EVC2(:, iL, iG, 1);
                case 3, vec = T_SNA(:, iL, iG, 1);
                case 4, vec = T_Div(:, iL, iG, 1);
            end
            k = isfinite(vec) & isfinite(T_HitRate);
            if sum(k) < 5, continue; end
            [rho, p] = corr(vec(k), T_HitRate(k), 'type', 'Spearman');
            sig = '';
            if p < 0.05, sig = ' *'; end
            if p < 0.01, sig = ' **'; end
            fprintf('%s %s-%s: ρ=%+.3f p=%.4g n=%d%s\n', ...
                metricNames(iM), layerLabels(iL), groupNames(iG), rho, p, sum(k), sig);
        end
    end
end

%% ===== local functions =====

function iSpearman(metric, hitRate, label)
k = isfinite(metric) & isfinite(hitRate);
n = sum(k);
if n < 5
    fprintf('  %s: insufficient n=%d\n', label, n);
    return;
end
[rho, p] = corr(metric(k), hitRate(k), 'type', 'Spearman');
sig = '';
if p < 0.05, sig = ' *'; end
if p < 0.01, sig = ' **'; end
if p < 0.001, sig = ' ***'; end
fprintf('  %s: ρ=%+.3f p=%.4g n=%d%s\n', label, rho, p, n, sig);
end

function iRanksum(a, b, label)
ka = isfinite(a); kb = isfinite(b);
na = sum(ka); nb = sum(kb);
if na < 3 || nb < 3
    fprintf('  %s: insufficient n\n', label);
    return;
end
p = ranksum(a(ka), b(kb));
ma = mean(a(ka)); mb = mean(b(kb));
sig = '';
if p < 0.05, sig = ' *'; end
if p < 0.01, sig = ' **'; end
dir = '=';
if ma > mb, dir = '>'; elseif ma < mb, dir = '<'; end
fprintf('  %s: %.3f vs %.3f p=%.4g%s (%s)\n', label, ma, mb, p, sig, dir);
end

function iPaired(a, b, label)
k = isfinite(a) & isfinite(b);
n = sum(k);
if n < 4
    fprintf('  %s: insufficient n=%d\n', label, n);
    return;
end
p = signrank(a(k), b(k));
ma = mean(a(k)); mb = mean(b(k));
sea = std(a(k))/sqrt(n); seb = std(b(k))/sqrt(n);
sig = '';
if p < 0.05, sig = ' *'; end
if p < 0.01, sig = ' **'; end
if p < 0.001, sig = ' ***'; end
dir = '=';
if ma > mb, dir = '>'; elseif ma < mb, dir = '<'; end
fprintf('  %s: %.3f±%.3f vs %.3f±%.3f n=%d p=%.4g%s (%s)\n', ...
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
    evc2 = NaN; evc3 = NaN;
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

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate, ~)
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs) < 2
    return;
end
inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial, :);
if isempty(nts2), return; end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2, return; end
allC = unique(uint64(nts2.CellUID));
nAllC = numel(allC);
traces = cell(nAllC, 1);
keepU = zeros(nAllC, 1, 'uint64');
nKeep = 0;
for ci = 1:nAllC
    cid = allC(ci);
    rows = (uint64(nts2.CellUID) == cid);
    if sum(rows) < numel(trialUIDs), continue; end
    uid = uint64(nts2.TrialUID(rows));
    sig = double(nts2.TrialSignal(rows, :));
    [tf, loc] = ismember(trialUIDs, uid);
    if ~all(tf), continue; end
    so = sig(loc, :);
    if any(~isfinite(so), 'all'), continue; end
    nKeep = nKeep + 1;
    traces{nKeep} = so;
    keepU(nKeep) = cid;
end
if nKeep < 1, return; end
traces = traces(1:nKeep);
keepU = keepU(1:nKeep);
nTr = size(traces{1}, 1);
nTi = size(traces{1}, 2);
CTT = nan(nKeep, nTr, nTi);
for ci = 1:nKeep
    CTT(ci, :, :) = traces{ci};
end
idx0 = 3 * sampleRate;
CTT = CTT - CTT(:, :, idx0);
cellUIDs = keepU;
end
