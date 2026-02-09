%% Z_FreshRankSum_AllCandidates
%  Compute fresh values for 13 candidate neural features (Transfer & Naive),
%  then run rank-sum tests and partial-Spearman cross-validation.
%
%  Workspace inputs required:
%    SessSpeedT              – 18-row table  (Transfer)
%    NaiveFeatures_SessSpeed – 66-row table  (Naive, with Source column)
%    sdT_fresh, sdN_fresh    – for verification of SD_K1

%% ---- 1. Load datasets ------------------------------------------------
ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

%% ---- 2. Time info -----------------------------------------------------
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);

timePoints = [0.3, 0.5, 1.0, 1.5];
idxTP = nan(size(timePoints));
for iT = 1:numel(timePoints)
    [dt, idx] = min(abs(xsSec - timePoints(iT)));
    if dt <= 0.25, idxTP(iT) = idx; end
end

kSigma = 3;
layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};

%% ---- 3. Candidate list ------------------------------------------------
candidates = {
    '1p0s_MOp23_ActFrac_K1'
    'DeltaDiv1s_MOp23'
    '1p0s_MOp5_SD_K1'
    '1p5s_All_SD_K1'
    '1p5s_MOp23_SD_K1'
    '1p5s_MOp23_DeltaSD'
    'Div1s_All_K1'
    '1p5s_All_ActFrac_K1'
    '0p5s_MOp5_DeltaMeanNTATS'
    '1p5s_MOp5_DeltaSD'
    '1p0s_MOp23_SD_K'
    '1p5s_MOp23_DeltaMeanNTATS'
    '1p5s_MOp5_DeltaActFrac'
};
nCand = numel(candidates);

%% ---- 4. Retrieve workspace variables ----------------------------------
SessSpeedT = evalin('base', 'SessSpeedT');
NaiveSS    = evalin('base', 'NaiveFeatures_SessSpeed');
sdT_fresh  = evalin('base', 'sdT_fresh');
sdN_fresh  = evalin('base', 'sdN_fresh');

%% ---- 5. Compute Transfer features (18 pairs) --------------------------
nT = height(SessSpeedT);
freshT      = nan(nT, nCand);
hitK_T      = nan(nT, 1);
deltaHit_T  = nan(nT, 1);

fprintf('\n=== Computing TRANSFER features (%d pairs) ===\n', nT);
for iP = 1:nT
    m   = string(SessSpeedT.Mouse(iP));
    dtK = SessSpeedT.DateTime(iP);
    dtK1 = SessSpeedT.DateTimeNext(iP);

    hitK_T(iP)     = SessSpeedT.Performance(iP);
    deltaHit_T(iP) = SessSpeedT.Speed_DeltaNext(iP);

    % --- Build cell-layer map from ALB.Cells ---
    cellLayer = iBuildCellLayerMap(ALB, m);

    % --- Query NTS for session K (LightWater) ---
    ntsK_cell = ALB.QueryNTS(struct('Mouse',char(m),'DateTime',dtK, ...
        'Stimulus','LightWater'), UniExp.Flags.ZScore, 1:24);
    [uidK, ntatsK, ntsK_tab] = iBuildNTATS(ntsK_cell);

    % --- Query NTS for session K+1 (LightWater) ---
    ntsK1_cell = ALB.QueryNTS(struct('Mouse',char(m),'DateTime',dtK1, ...
        'Stimulus','LightWater'), UniExp.Flags.ZScore, 1:24);
    [uidK1, ntatsK1, ntsK1_tab] = iBuildNTATS(ntsK1_cell);

    % --- Compute each candidate feature ---
    freshT(iP,:) = iComputeAllCandidates( ...
        ntatsK, uidK, ntsK_tab, ntatsK1, uidK1, ntsK1_tab, ...
        cellLayer, layerFilters, idxTP, baseMask, kSigma);

    if mod(iP,5)==0, fprintf('  Transfer %d/%d done\n', iP, nT); end
end
fprintf('  Transfer complete.\n');

%% ---- 6. Compute Naive features (66 pairs) -----------------------------
nN = height(NaiveSS);
freshN      = nan(nN, nCand);
hitK_N      = nan(nN, 1);
deltaHit_N  = nan(nN, 1);

fprintf('\n=== Computing NAIVE features (%d pairs) ===\n', nN);
for iP = 1:nN
    m    = string(NaiveSS.Mouse(iP));
    dtK  = NaiveSS.DateTime(iP);
    dtK1 = NaiveSS.DateTimeNext(iP);
    src  = string(NaiveSS.Source(iP));

    hitK_N(iP)     = NaiveSS.Performance(iP);
    deltaHit_N(iP) = NaiveSS.Speed_DeltaNext(iP);

    % Choose dataset based on Source column
    if src == "LAB"
        DS = LAB;
    elseif src == "LAI"
        DS = LAI;
    else
        warning('Unknown source "%s" for pair %d, skipping.', src, iP);
        continue
    end

    % --- Build cell-layer map ---
    cellLayer = iBuildCellLayerMap(DS, m);

    % --- Query NTS for session K (LightWater) ---
    ntsK_cell = DS.QueryNTS(struct('Mouse',char(m),'DateTime',dtK, ...
        'Stimulus','LightWater'), UniExp.Flags.ZScore, 1:24);
    [uidK, ntatsK, ntsK_tab] = iBuildNTATS(ntsK_cell);

    % --- Query NTS for session K+1 (LightWater) ---
    ntsK1_cell = DS.QueryNTS(struct('Mouse',char(m),'DateTime',dtK1, ...
        'Stimulus','LightWater'), UniExp.Flags.ZScore, 1:24);
    [uidK1, ntatsK1, ntsK1_tab] = iBuildNTATS(ntsK1_cell);

    % --- Compute each candidate feature ---
    freshN(iP,:) = iComputeAllCandidates( ...
        ntatsK, uidK, ntsK_tab, ntatsK1, uidK1, ntsK1_tab, ...
        cellLayer, layerFilters, idxTP, baseMask, kSigma);

    if mod(iP,10)==0, fprintf('  Naive %d/%d done\n', iP, nN); end
end
fprintf('  Naive complete.\n');

%% ---- 7. Rank-sum tests ------------------------------------------------
fprintf('\n========== RANK-SUM  (Transfer vs Naive) ==========\n');
fprintf('%-35s %5s %8s   %5s %8s   %10s  %4s\n', ...
    'Feature','nT','medT','nN','medN','p_RS','Dir');
fprintf('%s\n', repmat('-',1,90));

pRS_all   = nan(nCand,1);
dir_all   = strings(nCand,1);
for iF = 1:nCand
    tV = freshT(:,iF); nV = freshN(:,iF);
    tVf = tV(isfinite(tV)); nVf = nV(isfinite(nV));
    if numel(tVf)>=2 && numel(nVf)>=2
        pRS_all(iF) = ranksum(tVf, nVf);
    end
    medT = median(tVf); medN = median(nVf);
    if medT >= medN, dir_all(iF) = "T>N"; else, dir_all(iF) = "T<N"; end
    fprintf('%-35s %5d %8.4f   %5d %8.4f   %10.2e  %s\n', ...
        candidates{iF}, numel(tVf), medT, numel(nVf), medN, ...
        pRS_all(iF), dir_all(iF));
end

%% ---- 8. Fresh Partial Spearman ----------------------------------------
fprintf('\n========== PARTIAL SPEARMAN  (fresh) ==========\n');

rhoT = nan(nCand,1); pT = nan(nCand,1);
rhoN = nan(nCand,1); pN = nan(nCand,1);

for iF = 1:nCand
    % Transfer
    xT = freshT(:,iF); yT = deltaHit_T; zT = hitK_T;
    ok = isfinite(xT) & isfinite(yT) & isfinite(zT);
    if sum(ok) >= 6
        [rhoT(iF), pT(iF)] = iPartialSpearman(xT(ok), yT(ok), zT(ok));
    end
    % Naive
    xN = freshN(:,iF); yN = deltaHit_N; zN = hitK_N;
    ok = isfinite(xN) & isfinite(yN) & isfinite(zN);
    if sum(ok) >= 6
        [rhoN(iF), pN(iF)] = iPartialSpearman(xN(ok), yN(ok), zN(ok));
    end
end

%% ---- 9. Comprehensive summary table -----------------------------------
fprintf('\n==================== COMPREHENSIVE RESULTS ====================\n');
fprintf('%-35s | %4s %7s %10s | %4s %7s %10s | %10s %4s %5s | %s\n', ...
    'Feature', 'nT','rhoT','pT', 'nN','rhoN','pN', ...
    'p_RS','Dir','DirOK','Verdict');
fprintf('%s\n', repmat('=',1,120));

nPass = 0;
verdicts = strings(nCand,1);
for iF = 1:nCand
    nTf = sum(isfinite(freshT(:,iF)));
    nNf = sum(isfinite(freshN(:,iF)));

    % Direction consistency: rho>0 requires T>N, rho<0 requires T<N
    dOK = false;
    if isfinite(rhoT(iF)) && isfinite(pRS_all(iF))
        if (rhoT(iF) > 0 && dir_all(iF) == "T>N") || ...
           (rhoT(iF) < 0 && dir_all(iF) == "T<N")
            dOK = true;
        end
    end
    dirOK_str = "No";
    if dOK, dirOK_str = "Yes"; end

    % Verdict: PASS requires ①②③ all satisfied
    %  ① pT < 0.05 (Partial Spearman Transfer)
    %  ② pN < 0.05 (Partial Spearman Naive)
    %  ③ pRS < 0.05 AND direction consistent
    c1 = isfinite(pT(iF)) && pT(iF) < 0.05;
    c2 = isfinite(pN(iF)) && pN(iF) < 0.05;
    c3 = isfinite(pRS_all(iF)) && pRS_all(iF) < 0.05 && dOK;

    failReasons = "";
    if ~c1, failReasons = failReasons + "①"; end
    if ~c2, failReasons = failReasons + "②"; end
    if ~c3
        if ~isfinite(pRS_all(iF)) || pRS_all(iF) >= 0.05
            failReasons = failReasons + "③RS";
        elseif ~dOK
            failReasons = failReasons + "③dir";
        end
    end

    if c1 && c2 && c3
        verdicts(iF) = "PASS";
        nPass = nPass + 1;
    else
        verdicts(iF) = "FAIL(" + failReasons + ")";
    end

    fprintf('%-35s | %4d %+7.3f %10.2e | %4d %+7.3f %10.2e | %10.2e %4s %5s | %s\n', ...
        candidates{iF}, ...
        nTf, rhoT(iF), pT(iF), ...
        nNf, rhoN(iF), pN(iF), ...
        pRS_all(iF), dir_all(iF), dirOK_str, ...
        verdicts(iF));
end
fprintf('%s\n', repmat('=',1,120));
fprintf('Total PASS: %d / %d\n\n', nPass, nCand);

%% ---- 10. Build & save results table -----------------------------------
results_table = table( ...
    string(candidates), ...
    rhoT, pT, rhoN, pN, pRS_all, dir_all, verdicts, ...
    'VariableNames', {'Feature','rhoT','pT','rhoN','pN', ...
                      'pRankSum','Direction','Verdict'});

assignin('base', 'FreshCandidateT',       freshT);
assignin('base', 'FreshCandidateN',       freshN);
assignin('base', 'FreshCandidateResults', results_table);
fprintf('Saved FreshCandidateT (%dx%d), FreshCandidateN (%dx%d), FreshCandidateResults to workspace.\n', ...
    size(freshT,1), size(freshT,2), size(freshN,1), size(freshN,2));

%% ---- 11. Verification against stored SD_K1 values ---------------------
fprintf('\n========== VERIFICATION: SD_K1 ==========\n');
% sdT_fresh is 18×3×2: dim1=pairs, dim2=[All,MOp23,MOp5], dim3=[1.0s,1.5s]
% sdN_fresh is 66×3×2

% Candidate #3: 1p0s_MOp5_SD_K1 → sdT_fresh(:,3,1), sdN_fresh(:,3,1)
v_new = freshT(:,3); v_ref = sdT_fresh(:,3,1);
ok = isfinite(v_new) & isfinite(v_ref);
errT3 = max(abs(v_new(ok)-v_ref(ok)));
fprintf('  1p0s_MOp5_SD_K1 Transfer: maxErr=%.2e (n=%d)\n', errT3, sum(ok));

v_new = freshN(:,3); v_ref = sdN_fresh(:,3,1);
ok = isfinite(v_new) & isfinite(v_ref);
errN3 = max(abs(v_new(ok)-v_ref(ok)));
fprintf('  1p0s_MOp5_SD_K1 Naive:    maxErr=%.2e (n=%d)\n', errN3, sum(ok));

% Candidate #4: 1p5s_All_SD_K1 → sdT_fresh(:,1,2), sdN_fresh(:,1,2)
v_new = freshT(:,4); v_ref = sdT_fresh(:,1,2);
ok = isfinite(v_new) & isfinite(v_ref);
errT4 = max(abs(v_new(ok)-v_ref(ok)));
fprintf('  1p5s_All_SD_K1 Transfer:  maxErr=%.2e (n=%d)\n', errT4, sum(ok));

v_new = freshN(:,4); v_ref = sdN_fresh(:,1,2);
ok = isfinite(v_new) & isfinite(v_ref);
errN4 = max(abs(v_new(ok)-v_ref(ok)));
fprintf('  1p5s_All_SD_K1 Naive:     maxErr=%.2e (n=%d)\n', errN4, sum(ok));

tol = 1e-10;
if errT3<tol && errN3<tol && errT4<tol && errN4<tol
    fprintf('  => ALL SD_K1 values MATCH stored sdT_fresh / sdN_fresh.\n');
else
    warning('SD_K1 values DO NOT match stored fresh refs (tol %.0e). Check code.', tol);
end

fprintf('\nDone.\n');

%% ======================================================================
%  LOCAL FUNCTIONS
%  ======================================================================

function cellLayer = iBuildCellLayerMap(DS, m)
%iBuildCellLayerMap  Build uint64->char map of CellUID->ZLayer for mouse m.
    C = DS.Cells;
    C.CellUID = uint64(C.CellUID);
    C.Mouse   = string(C.Mouse);
    C.ZLayer  = string(C.ZLayer);
    cellLayer = containers.Map('KeyType','uint64','ValueType','char');
    idx = C.Mouse == m;
    uids = uint64(C.CellUID(idx));
    zls  = string(C.ZLayer(idx));
    for i = 1:numel(uids)
        cellLayer(uids(i)) = char(zls(i));
    end
end

function [uid, ntats, nts_tab] = iBuildNTATS(nts_cell)
%iBuildNTATS  From QueryNTS output (cell array), extract table and compute
%   per-cell median (NTATS). Returns the raw trial-level table too.
    uid     = uint64([]);
    ntats   = double([]);
    nts_tab = [];
    % QueryNTS returns a cell array; extract the first element
    if isempty(nts_cell), return; end
    if iscell(nts_cell)
        if isempty(nts_cell{1}), return; end
        nts = nts_cell{1};
    else
        nts = nts_cell;  % already a table
    end
    if ~istable(nts), return; end
    if ~all(ismember(["CellUID","TrialSignal"], ...
            string(nts.Properties.VariableNames)))
        return
    end
    nts_tab = nts;  % keep for divergence computation
    uid = unique(uint64(nts.CellUID));
    ntats = nan(numel(uid), size(nts.TrialSignal,2));
    for iC = 1:numel(uid)
        rows = uint64(nts.CellUID) == uid(iC);
        ntats(iC,:) = median(double(nts.TrialSignal(rows,:)), 1, 'omitnan');
    end
end

function vals = iComputeAllCandidates(ntatsK, uidK, ntsK, ...
        ntatsK1, uidK1, ntsK1, cellLayer, layerFilters, idxTP, baseMask, kSigma)
%iComputeAllCandidates  Return 1×13 row of feature values for one pair.
%
%   layerFilters: {All, MOp2/3, MOp5}
%   idxTP:        indices for [0.3, 0.5, 1.0, 1.5] s

    vals = nan(1, 13);

    % Pre-compute layer indices for K and K+1
    %  All=1, MOp23=2, MOp5=3
    idxLayK  = cell(1,3);
    idxLayK1 = cell(1,3);
    for iL = 1:3
        idxLayK{iL}  = iLayerCells(uidK,  cellLayer, layerFilters{iL});
        idxLayK1{iL} = iLayerCells(uidK1, cellLayer, layerFilters{iL});
    end

    tp03 = idxTP(1);  % 0.3 s   (unused in candidates but available)
    tp05 = idxTP(2);  % 0.5 s
    tp10 = idxTP(3);  % 1.0 s
    tp15 = idxTP(4);  % 1.5 s

    % 1. 1p0s_MOp23_ActFrac_K1
    vals(1)  = iActiveFrac(ntatsK1, idxLayK1{2}, baseMask, tp10, kSigma);

    % 2. DeltaDiv1s_MOp23
    divK1    = iDivergence(ntsK1, uidK1, cellLayer, layerFilters{2}, tp10);
    divK     = iDivergence(ntsK,  uidK,  cellLayer, layerFilters{2}, tp10);
    vals(2)  = divK1 - divK;

    % 3. 1p0s_MOp5_SD_K1
    vals(3)  = iInterCellSD(ntatsK1, idxLayK1{3}, tp10);

    % 4. 1p5s_All_SD_K1
    vals(4)  = iInterCellSD(ntatsK1, idxLayK1{1}, tp15);

    % 5. 1p5s_MOp23_SD_K1
    vals(5)  = iInterCellSD(ntatsK1, idxLayK1{2}, tp15);

    % 6. 1p5s_MOp23_DeltaSD
    vals(6)  = iInterCellSD(ntatsK1, idxLayK1{2}, tp15) ...
             - iInterCellSD(ntatsK,  idxLayK{2},  tp15);

    % 7. Div1s_All_K1
    vals(7)  = iDivergence(ntsK1, uidK1, cellLayer, layerFilters{1}, tp10);

    % 8. 1p5s_All_ActFrac_K1
    vals(8)  = iActiveFrac(ntatsK1, idxLayK1{1}, baseMask, tp15, kSigma);

    % 9. 0p5s_MOp5_DeltaMeanNTATS
    vals(9)  = iMeanNTATS(ntatsK1, idxLayK1{3}, tp05) ...
             - iMeanNTATS(ntatsK,  idxLayK{3},  tp05);

    % 10. 1p5s_MOp5_DeltaSD
    vals(10) = iInterCellSD(ntatsK1, idxLayK1{3}, tp15) ...
             - iInterCellSD(ntatsK,  idxLayK{3},  tp15);

    % 11. 1p0s_MOp23_SD_K
    vals(11) = iInterCellSD(ntatsK, idxLayK{2}, tp10);

    % 12. 1p5s_MOp23_DeltaMeanNTATS
    vals(12) = iMeanNTATS(ntatsK1, idxLayK1{2}, tp15) ...
             - iMeanNTATS(ntatsK,  idxLayK{2},  tp15);

    % 13. 1p5s_MOp5_DeltaActFrac
    vals(13) = iActiveFrac(ntatsK1, idxLayK1{3}, baseMask, tp15, kSigma) ...
             - iActiveFrac(ntatsK,  idxLayK{3},  baseMask, tp15, kSigma);
end

function idx = iLayerCells(allUID, cellLayer, layerFilter)
%iLayerCells  Return indices into allUID that pass layerFilter.
    zl = strings(numel(allUID), 1);
    for i = 1:numel(allUID)
        if cellLayer.isKey(allUID(i))
            zl(i) = string(cellLayer(allUID(i)));
        end
    end
    idx = find(layerFilter(zl));
end

function sd = iInterCellSD(ntats, idx, tp)
%iInterCellSD  Cross-cell standard deviation at time-point tp.
    sd = NaN;
    if isempty(idx) || isnan(tp), return; end
    v = double(ntats(idx, tp));
    v = v(isfinite(v));
    if numel(v) < 3, return; end
    sd = std(v, 0, 1);
end

function af = iActiveFrac(ntats, idx, baseMask, tp, kSigma)
%iActiveFrac  Fraction of cells active (above baseline + k*sigma) at tp.
    af = NaN;
    if isempty(idx) || isnan(tp), return; end
    base = ntats(idx, baseMask);
    thr  = mean(base, 2, 'omitnan') + kSigma * std(base, 0, 2, 'omitnan');
    act  = ntats(idx, tp) > thr;
    af   = mean(double(act), 'omitnan');
end

function mn = iMeanNTATS(ntats, idx, tp)
%iMeanNTATS  Mean NTATS across cells at time-point tp.
    mn = NaN;
    if isempty(idx) || isnan(tp), return; end
    mn = mean(double(ntats(idx, tp)), 'omitnan');
end

function div = iDivergence(nts, uidAll, cellLayer, layerFilter, tp)
%iDivergence  Trial-to-trial divergence across cells at time-point tp.
    div = NaN;
    if isempty(nts) || ~istable(nts) || isempty(uidAll), return; end
    if ~all(ismember(["CellUID","TrialSignal"], ...
            string(nts.Properties.VariableNames)))
        return
    end
    if isnan(tp), return; end

    zl = strings(numel(uidAll), 1);
    for i = 1:numel(uidAll)
        if cellLayer.isKey(uidAll(i))
            zl(i) = string(cellLayer(uidAll(i)));
        end
    end
    keep     = layerFilter(zl);
    layerUID = uidAll(keep);
    if isempty(layerUID), return; end

    varSum = 0; meanSqSum = 0; nCells = 0;
    for iC = 1:numel(layerUID)
        rows = uint64(nts.CellUID) == layerUID(iC);
        if nnz(rows) < 2, continue; end
        vals = double(nts.TrialSignal(rows, tp));
        vals = vals(isfinite(vals));
        if numel(vals) < 2, continue; end
        varSum    = varSum    + var(vals);
        meanSqSum = meanSqSum + mean(vals)^2;
        nCells    = nCells + 1;
    end
    if nCells < 3 || meanSqSum == 0, return; end
    div = sqrt(varSum) / sqrt(meanSqSum);
end

function [rho, p] = iPartialSpearman(x, y, z)
%iPartialSpearman  Partial Spearman correlation between x and y,
%   controlling for z, via rank-regression projection.
    rx = tiedrank(x);
    ry = tiedrank(y);
    rz = tiedrank(z);
    rx_res = rx - rz * (rz \ rx);
    ry_res = ry - rz * (rz \ ry);
    [rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end
