%% scratch_PopulationGeometry.m
% 基于 Wakhloo et al. (2026) 的神经群体几何理论
% 计算 Participation Ratio (PR), EVC, Signal-Noise Alignment
% 对比 4 个条件 × 继承/非继承 细胞群

DS = TransferLearning.AudioLightBaseline();
sampleRate = 8;
baselineSec = 0;
idxCue = 3*sampleRate;     % idx 24
idx1s  = idxCue + sampleRate; % idx 32 (cue后1s)

% Get trial tables
TlearnAW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TtransLW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TnaiveLO = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Naive", Stimulus="LightOnly");
TnaiveAO = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Naive", Stimulus="AudioOnly");

TlearnAW.Mouse = string(TlearnAW.Mouse); TlearnAW.DateTime = datetime(TlearnAW.DateTime); try TlearnAW.DateTime.TimeZone=''; catch, end
TtransLW.Mouse = string(TtransLW.Mouse); TtransLW.DateTime = datetime(TtransLW.DateTime); try TtransLW.DateTime.TimeZone=''; catch, end
TnaiveLO.Mouse = string(TnaiveLO.Mouse); TnaiveLO.DateTime = datetime(TnaiveLO.DateTime); try TnaiveLO.DateTime.TimeZone=''; catch, end
TnaiveAO.Mouse = string(TnaiveAO.Mouse); TnaiveAO.DateTime = datetime(TnaiveAO.DateTime); try TnaiveAO.DateTime.TimeZone=''; catch, end

mice = intersect(intersect(unique(TtransLW.Mouse), unique(TlearnAW.Mouse)), unique(TnaiveLO.Mouse));
nM = numel(mice);
fprintf('共 %d 只鼠\n', nM);

%% Condition labels
condNames = ["NaiveAO","LearnedAW","TransferLW","NaiveLO"];
nCond = numel(condNames);
% Groups: All, Inherited, Non-inherited
groupNames = ["All","Inherited","NonInherited"];
nGrp = 3;

% Result arrays: (nMice x nConditions x nGroups)
PR     = nan(nM, nCond, nGrp);
EVC2   = nan(nM, nCond, nGrp);  % top-2 PC explained variance
EVC3   = nan(nM, nCond, nGrp);  % top-3 PC explained variance
SNAlign = nan(nM, nCond, nGrp); % signal-noise alignment (1=perfect orthogonality)
Div    = nan(nM, nCond, nGrp);  % our divergence for comparison
NCells = nan(nM, nCond, nGrp);

for i = 1:nM
    m = mice(i);
    
    % ---- Load NTS ----
    ntsLW = DS.QueryNTS(struct('Stimulus',"LightWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsAW = DS.QueryNTS(struct('Stimulus',"AudioWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsLO = DS.QueryNTS(struct('Stimulus',"LightOnly",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsAO = DS.QueryNTS(struct('Stimulus',"AudioOnly",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsLW), ntsLW=ntsLW{1}; end
    if iscell(ntsAW), ntsAW=ntsAW{1}; end
    if iscell(ntsLO), ntsLO=ntsLO{1}; end
    if iscell(ntsAO), ntsAO=ntsAO{1}; end
    if isempty(ntsLW) || isempty(ntsAW), continue; end
    
    % ---- Session selection ----
    % Learned AW: last session
    Ta = TlearnAW(TlearnAW.Mouse==m,:); sessionDtA = max(Ta.DateTime);
    Ta = sortrows(Ta(Ta.DateTime==sessionDtA,:),"TrialIndex");
    trialUIDsA = unique(uint64(Ta.TrialUID),'stable');
    
    % Transfer LW: first session
    Tt = TtransLW(TtransLW.Mouse==m,:); sessionDtT = min(Tt.DateTime);
    Tt = sortrows(Tt(Tt.DateTime==sessionDtT,:),"TrialIndex");
    trialUIDsT = unique(uint64(Tt.TrialUID),'stable');
    
    % Naive LO: first session
    trialUIDsN = uint64([]);
    if ~isempty(ntsLO)
        Tn = TnaiveLO(TnaiveLO.Mouse==m,:);
        if ~isempty(Tn)
            sessionDtN = min(Tn.DateTime);
            Tn = sortrows(Tn(Tn.DateTime==sessionDtN,:),"TrialIndex");
            trialUIDsN = unique(uint64(Tn.TrialUID),'stable');
        end
    end
    
    % Naive AO: first session
    trialUIDsAO = uint64([]);
    if ~isempty(ntsAO)
        Tao = TnaiveAO(TnaiveAO.Mouse==m,:);
        if ~isempty(Tao)
            sessionDtAO = min(Tao.DateTime);
            Tao = sortrows(Tao(Tao.DateTime==sessionDtAO,:),"TrialIndex");
            trialUIDsAO = unique(uint64(Tao.TrialUID),'stable');
        end
    end
    
    if isempty(trialUIDsA) || isempty(trialUIDsT), continue; end
    
    % ---- Build CTT ----
    [CTT_AW, uid_AW] = iLocalBuildCTT(ntsAW, trialUIDsA, sampleRate, baselineSec);
    [CTT_LW, uid_LW] = iLocalBuildCTT(ntsLW, trialUIDsT, sampleRate, baselineSec);
    [CTT_LO, uid_LO] = iLocalBuildCTT(ntsLO, trialUIDsN, sampleRate, baselineSec);
    [CTT_AO, uid_AO] = iLocalBuildCTT(ntsAO, trialUIDsAO, sampleRate, baselineSec);
    
    if isempty(CTT_AW) || isempty(CTT_LW), continue; end
    
    % ---- Define inherited cells from Learned AW ----
    ntats_AW = squeeze(mean(CTT_AW, 2));
    bsl = ntats_AW(:,1:24);
    activeAW = ntats_AW(:,idx1s) > mean(bsl,2) + 3*std(bsl,[],2);
    learnedActiveUIDs = uid_AW(activeAW);
    
    % ---- Compute metrics for each condition ----
    cttList = {CTT_AO, CTT_AW, CTT_LW, CTT_LO};
    uidList = {uid_AO, uid_AW, uid_LW, uid_LO};
    
    for c = 1:nCond
        ctt = cttList{c};
        uid = uidList{c};
        if isempty(ctt), continue; end
        
        isInh = ismember(uid, learnedActiveUIDs);
        
        % For each group (All, Inherited, NonInherited)
        for g = 1:3
            switch g
                case 1, idx = true(size(uid));
                case 2, idx = isInh;
                case 3, idx = ~isInh;
            end
            if sum(idx) < 3, continue; end
            
            subCTT = ctt(idx,:,:);
            [pr, evc2, evc3, snAlign, div] = iComputeGeometry(subCTT, idx1s);
            
            PR(i,c,g)      = pr;
            EVC2(i,c,g)    = evc2;
            EVC3(i,c,g)    = evc3;
            SNAlign(i,c,g) = snAlign;
            Div(i,c,g)     = div;
            NCells(i,c,g)  = sum(idx);
        end
    end
    
    fprintf('Mouse %s: nCell AW=%d(inh=%d) LW=%d(inh=%d) | PR_AW=%.1f PR_LW_inh=%.1f PR_LW_non=%.1f\n', ...
        m, sum(~isnan(uid_AW)), sum(ismember(uid_AW,learnedActiveUIDs)), ...
        sum(~isnan(uid_LW)), sum(ismember(uid_LW,learnedActiveUIDs)), ...
        PR(i,2,1), PR(i,3,2), PR(i,3,3));
end

%% ==================== DISPLAY RESULTS ====================
fprintf('\n\n');
fprintf('====================================================================\n');
fprintf('  POPULATION GEOMETRY ANALYSIS (Wakhloo et al. 2026 framework)\n');
fprintf('====================================================================\n\n');

% Summary table per condition and group
for g = 1:3
    fprintf('--- %s cells ---\n', groupNames(g));
    fprintf('%-12s  %8s  %8s  %8s  %8s  %8s  %8s\n', ...
        'Condition', 'PR', 'EVC2%', 'EVC3%', 'SNAlign', 'Div', 'nCells');
    for c = 1:nCond
        k = isfinite(PR(:,c,g));
        if sum(k)<2, continue; end
        fprintf('%-12s  %5.1f±%.1f  %5.1f±%.1f  %5.1f±%.1f  %5.3f±%.3f  %5.3f±%.3f  %5.0f±%.0f\n', ...
            condNames(c), ...
            mean(PR(k,c,g)), std(PR(k,c,g))/sqrt(sum(k)), ...
            100*mean(EVC2(k,c,g)), 100*std(EVC2(k,c,g))/sqrt(sum(k)), ...
            100*mean(EVC3(k,c,g)), 100*std(EVC3(k,c,g))/sqrt(sum(k)), ...
            mean(SNAlign(k,c,g)), std(SNAlign(k,c,g))/sqrt(sum(k)), ...
            mean(Div(k,c,g)), std(Div(k,c,g))/sqrt(sum(k)), ...
            mean(NCells(k,c,g)), std(NCells(k,c,g))/sqrt(sum(k)));
    end
    fprintf('\n');
end

%% ==================== STATISTICAL TESTS ====================
fprintf('====================================================================\n');
fprintf('  STATISTICAL TESTS (Wilcoxon signed-rank, paired within mice)\n');
fprintf('====================================================================\n\n');

% --- PR tests ---
fprintf('--- Participation Ratio (PR) ---\n');
iPairedTest(PR(:,1,1), PR(:,2,1), 'PR: NaiveAO vs LearnedAW (All)');
iPairedTest(PR(:,2,1), PR(:,3,1), 'PR: LearnedAW vs TransferLW (All)');
iPairedTest(PR(:,3,2), PR(:,3,3), 'PR: TransferLW Inh vs Non-inh');
iPairedTest(PR(:,2,2), PR(:,3,2), 'PR: LearnedAW_Inh vs TransferLW_Inh');
iPairedTest(PR(:,4,1), PR(:,3,1), 'PR: NaiveLO vs TransferLW (All)');
iPairedTest(PR(:,4,2), PR(:,3,2), 'PR: NaiveLO_Inh vs TransferLW_Inh');
fprintf('\n');

% --- EVC2 tests ---
fprintf('--- Explained Variance Concentration (top-2 PCs) ---\n');
iPairedTest(EVC2(:,1,1), EVC2(:,2,1), 'EVC2: NaiveAO vs LearnedAW (All)');
iPairedTest(EVC2(:,2,1), EVC2(:,3,1), 'EVC2: LearnedAW vs TransferLW (All)');
iPairedTest(EVC2(:,3,2), EVC2(:,3,3), 'EVC2: TransferLW Inh vs Non-inh');
fprintf('\n');

% --- SNAlign tests ---
fprintf('--- Signal-Noise Alignment ---\n');
iPairedTest(SNAlign(:,1,1), SNAlign(:,2,1), 'SNAlign: NaiveAO vs LearnedAW (All)');
iPairedTest(SNAlign(:,2,1), SNAlign(:,3,1), 'SNAlign: LearnedAW vs TransferLW (All)');
iPairedTest(SNAlign(:,3,2), SNAlign(:,3,3), 'SNAlign: TransferLW Inh vs Non-inh');
iPairedTest(SNAlign(:,2,2), SNAlign(:,3,2), 'SNAlign: LearnedAW_Inh vs TransferLW_Inh');
fprintf('\n');

% --- Divergence (reference) ---
fprintf('--- Divergence (reference) ---\n');
iPairedTest(Div(:,3,2), Div(:,3,3), 'Div: TransferLW Inh vs Non-inh');
iPairedTest(Div(:,2,2), Div(:,3,2), 'Div: LearnedAW_Inh vs TransferLW_Inh');
fprintf('\n');

%% ==================== TRAJECTORY ANALYSIS ====================
fprintf('====================================================================\n');
fprintf('  TRAJECTORY: Naive AO → Learned AW → Transfer LW\n');
fprintf('====================================================================\n\n');

for g = 1:3
    k = isfinite(PR(:,1,g)) & isfinite(PR(:,2,g)) & isfinite(PR(:,3,g));
    if sum(k) < 3, continue; end
    fprintf('--- %s cells (n=%d) ---\n', groupNames(g), sum(k));
    fprintf('  PR:      NaiveAO=%.1f → LearnedAW=%.1f → TransferLW=%.1f  (AO→AW p=%.4g, AW→Tr p=%.4g)\n', ...
        mean(PR(k,1,g)), mean(PR(k,2,g)), mean(PR(k,3,g)), ...
        signrank(PR(k,1,g),PR(k,2,g)), signrank(PR(k,2,g),PR(k,3,g)));
    
    k2 = isfinite(EVC2(:,1,g)) & isfinite(EVC2(:,2,g)) & isfinite(EVC2(:,3,g));
    if sum(k2)>=3
        fprintf('  EVC2%%:   NaiveAO=%.1f → LearnedAW=%.1f → TransferLW=%.1f  (AO→AW p=%.4g, AW→Tr p=%.4g)\n', ...
            100*mean(EVC2(k2,1,g)), 100*mean(EVC2(k2,2,g)), 100*mean(EVC2(k2,3,g)), ...
            signrank(EVC2(k2,1,g),EVC2(k2,2,g)), signrank(EVC2(k2,2,g),EVC2(k2,3,g)));
    end
    
    k3 = isfinite(SNAlign(:,1,g)) & isfinite(SNAlign(:,2,g)) & isfinite(SNAlign(:,3,g));
    if sum(k3)>=3
        fprintf('  SNAlign: NaiveAO=%.3f → LearnedAW=%.3f → TransferLW=%.3f  (AO→AW p=%.4g, AW→Tr p=%.4g)\n', ...
            mean(SNAlign(k3,1,g)), mean(SNAlign(k3,2,g)), mean(SNAlign(k3,3,g)), ...
            signrank(SNAlign(k3,1,g),SNAlign(k3,2,g)), signrank(SNAlign(k3,2,g),SNAlign(k3,3,g)));
    end
    fprintf('\n');
end

%% ===== METRIC FUNCTIONS =====

function [pr, evc2, evc3, snAlign, div] = iComputeGeometry(CTT, timeIdx)
% CTT: Cell x Trial x Time
% timeIdx: time index for snapshot analysis (e.g. 32 = 1s post cue)

nCell = size(CTT,1);
nTrial = size(CTT,2);

% Extract Cell x Trial matrix at target timepoint
X = CTT(:,:,timeIdx);    % nCell x nTrial

% ---- 1. Participation Ratio ----
% Compute covariance across trials (each trial = one observation in N-cell space)
C = cov(X');  % nCell x nCell  (cells as variables, trials as observations → transposed)
% Actually: we want the covariance of trial vectors in cell-space
% X is nCell x nTrial, each column = one trial vector
% cov(X') treats rows of X' (=columns of X, i.e., trial vectors) as observations
% Dimensions: X' is nTrial x nCell → cov gives nCell x nCell ✓
eigvals = eig(C);
eigvals = max(eigvals, 0);  % numerical stability
eigvals = sort(eigvals, 'descend');

trEig = sum(eigvals);
trEig2 = sum(eigvals.^2);
if trEig2 > 0 && trEig > 0
    pr = trEig^2 / trEig2;
else
    pr = NaN;
end

% ---- 2. Explained Variance Concentration ----
if trEig > 0
    cumFrac = cumsum(eigvals) / trEig;
    evc2 = cumFrac(min(2, numel(cumFrac)));
    evc3 = cumFrac(min(3, numel(cumFrac)));
else
    evc2 = NaN;
    evc3 = NaN;
end

% ---- 3. Signal-Noise Alignment ----
% Signal direction: mean response vector across trials (at timeIdx)
signal = mean(X, 2);   % nCell x 1
sigNorm = norm(signal);

% Noise: trial-to-trial deviations
noise = X - signal;     % nCell x nTrial residuals
noiseCov = (noise * noise') / max(nTrial - 1, 1);  % nCell x nCell

% Top noise PC direction
[V, D] = eig(noiseCov, 'vector');
[~, sortIdx] = sort(D, 'descend');
noisePC1 = V(:, sortIdx(1));  % nCell x 1

% Alignment = 1 - cos²(angle between signal and noise PC1)
% Perfect orthogonality → alignment = 1
if sigNorm > 0
    cosAngle = abs(dot(signal/sigNorm, noisePC1));
    snAlign = 1 - cosAngle^2;
else
    snAlign = NaN;
end

% ---- 4. Divergence (our metric, for comparison) ----
div = sqrt(sum(var(X,[],2),1) ./ sum(mean(X,2).^2));

end

%% ===== HELPER FUNCTIONS =====

function iPairedTest(a, b, label)
    k = isfinite(a) & isfinite(b);
    n = sum(k);
    if n < 3
        fprintf('  %s: insufficient data (n=%d)\n', label, n);
        return;
    end
    p = signrank(a(k), b(k));
    ma = mean(a(k)); mb = mean(b(k));
    sea = std(a(k))/sqrt(n); seb = std(b(k))/sqrt(n);
    if ma < mb, dir = '<'; elseif ma > mb, dir = '>'; else, dir = '='; end
    sig = ''; if p < 0.05, sig = ' *'; end; if p < 0.01, sig = ' **'; end; if p < 0.001, sig = ' ***'; end
    fprintf('  %s:\n    %.3f±%.3f vs %.3f±%.3f  n=%d  p=%.4g%s (%s)\n', ...
        label, ma, sea, mb, seb, n, p, sig, dir);
end

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate, baselineSec)
    CTT = []; cellUIDs = uint64([]);
    if isempty(nts) || numel(trialUIDs)<2, return; end
    inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
    nts2 = nts(inTrial,:);
    if isempty(nts2), return; end
    uNts = unique(uint64(nts2.TrialUID));
    trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
    if numel(trialUIDs) < 2, return; end
    allC = unique(uint64(nts2.CellUID));
    traces = {}; keepU = [];
    for c = 1:numel(allC)
        cid = allC(c);
        rows = (uint64(nts2.CellUID)==cid);
        if sum(rows)<numel(trialUIDs), continue; end
        uid = uint64(nts2.TrialUID(rows)); sig = double(nts2.TrialSignal(rows,:));
        [tf,loc] = ismember(trialUIDs,uid);
        if ~all(tf), continue; end
        so = sig(loc,:);
        if any(~isfinite(so),'all'), continue; end
        traces{end+1,1} = so; keepU(end+1,1) = cid; %#ok<AGROW>
    end
    if isempty(traces), return; end
    nC = numel(traces); nTr = size(traces{1},1); nTi = size(traces{1},2);
    CTT = nan(nC,nTr,nTi);
    for c = 1:nC, CTT(c,:,:) = traces{c}; end
    idx0 = max(1,min(nTi, 3*sampleRate+round(baselineSec*sampleRate)));
    CTT = CTT - CTT(:,:,idx0);
    cellUIDs = uint64(keepU);
end
