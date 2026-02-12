%% 探索：Transfer LW 细胞分群散度
% 用 Learned AW 中的活跃细胞定义 "继承群"
% 看继承群 vs 非继承群在 Transfer LW 中的散度差异
% 以及：继承群在 Naive LO vs Transfer LW 的散度差异

DS = TransferLearning.AudioLightBaseline();
sampleRate = 8;
baselineSec = 0;

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

% Pre-allocate results
DivTrAll=nan(nM,1); DivTrInh=nan(nM,1); DivTrNon=nan(nM,1);
DivNaAll=nan(nM,1); DivNaInh=nan(nM,1); DivNaNon=nan(nM,1);
DivAWAll=nan(nM,1); DivAWInh=nan(nM,1); DivAWNon=nan(nM,1);
DivAOAll=nan(nM,1); DivAOInh=nan(nM,1); DivAONon=nan(nM,1);
NCellTotal=nan(nM,1); NInherited=nan(nM,1); NNonInherited=nan(nM,1);

for i = 1:nM
    m = mice(i);
    
    % NTS
    ntsLW = DS.QueryNTS(struct('Stimulus',"LightWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsAW = DS.QueryNTS(struct('Stimulus',"AudioWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsLO = DS.QueryNTS(struct('Stimulus',"LightOnly",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsAO = DS.QueryNTS(struct('Stimulus',"AudioOnly",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsLW), ntsLW=ntsLW{1}; end
    if iscell(ntsAW), ntsAW=ntsAW{1}; end
    if iscell(ntsLO), ntsLO=ntsLO{1}; end
    if iscell(ntsAO), ntsAO=ntsAO{1}; end
    if isempty(ntsLW) || isempty(ntsAW), continue; end
    
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
    
    % Build CTT for Learned AW
    [CTT_AW, uid_AW] = iLocalBuildCTT(ntsAW, trialUIDsA, sampleRate, baselineSec);
    if isempty(CTT_AW), continue; end
    
    % Define active cells via NTATS logic @ 1s (idx 32)
    ntats_AW = squeeze(mean(CTT_AW, 2));
    bsl = ntats_AW(:,1:24);
    activeAW = ntats_AW(:,32) > mean(bsl,2) + 3*std(bsl,[],2);
    learnedActiveUIDs = uid_AW(activeAW);
    
    % Transfer LW
    [CTT_LW, uid_LW] = iLocalBuildCTT(ntsLW, trialUIDsT, sampleRate, baselineSec);
    if isempty(CTT_LW), continue; end
    
    isInh = ismember(uid_LW, learnedActiveUIDs);
    NCellTotal(i) = numel(uid_LW);
    NInherited(i) = sum(isInh);
    NNonInherited(i) = sum(~isInh);
    
    DivTrAll(i) = TransferLearning.Divergence(CTT_LW);
    if sum(isInh)>=3, DivTrInh(i) = TransferLearning.Divergence(CTT_LW(isInh,:,:)); end
    if sum(~isInh)>=3, DivTrNon(i) = TransferLearning.Divergence(CTT_LW(~isInh,:,:)); end
    
    % Naive LO
    if ~isempty(ntsLO) && numel(trialUIDsN)>=2
        [CTT_LO, uid_LO] = iLocalBuildCTT(ntsLO, trialUIDsN, sampleRate, baselineSec);
        if ~isempty(CTT_LO)
            isInhLO = ismember(uid_LO, learnedActiveUIDs);
            DivNaAll(i) = TransferLearning.Divergence(CTT_LO);
            if sum(isInhLO)>=3, DivNaInh(i) = TransferLearning.Divergence(CTT_LO(isInhLO,:,:)); end
            if sum(~isInhLO)>=3, DivNaNon(i) = TransferLearning.Divergence(CTT_LO(~isInhLO,:,:)); end
        end
    end
    
    % Learned AW
    DivAWAll(i) = TransferLearning.Divergence(CTT_AW);
    if sum(activeAW)>=3, DivAWInh(i) = TransferLearning.Divergence(CTT_AW(activeAW,:,:)); end
    if sum(~activeAW)>=3, DivAWNon(i) = TransferLearning.Divergence(CTT_AW(~activeAW,:,:)); end
    
    % Naive AO
    if ~isempty(ntsAO) && numel(trialUIDsAO)>=2
        [CTT_AO, uid_AO] = iLocalBuildCTT(ntsAO, trialUIDsAO, sampleRate, baselineSec);
        if ~isempty(CTT_AO)
            isInhAO = ismember(uid_AO, learnedActiveUIDs);
            DivAOAll(i) = TransferLearning.Divergence(CTT_AO);
            if sum(isInhAO)>=3, DivAOInh(i) = TransferLearning.Divergence(CTT_AO(isInhAO,:,:)); end
            if sum(~isInhAO)>=3, DivAONon(i) = TransferLearning.Divergence(CTT_AO(~isInhAO,:,:)); end
        end
    end
    
    fprintf('%s: Total=%d Inh=%d Non=%d | TrLW: %.3f/%.3f/%.3f | NaLO: %.3f/%.3f/%.3f\n', ...
        m, NCellTotal(i), NInherited(i), NNonInherited(i), ...
        DivTrAll(i), DivTrInh(i), DivTrNon(i), ...
        DivNaAll(i), DivNaInh(i), DivNaNon(i));
end

%% GROUP STATS
fprintf('\n\n==================== GROUP STATISTICS ====================\n');

iTest(DivTrInh, DivTrNon, 1, 'Transfer LW: Inherited vs Non-inherited');
iTest(DivNaInh, DivNaNon, 2, 'Naive LO: Inherited vs Non-inherited (baseline ctrl)');
iTest(DivNaInh, DivTrInh, 3, '★ Inherited cells: Naive LO vs Transfer LW');
iTest(DivNaNon, DivTrNon, 4, 'Non-inherited cells: Naive LO vs Transfer LW');
iTest(DivAWInh, DivAWNon, 5, 'Learned AW: Active vs Inactive');
iTest(DivAOAll, DivAWAll, 6, 'All cells: Naive AO vs Learned AW (reference)');
iTest(DivAOInh, DivAWInh, 7, 'Inherited cells: Naive AO vs Learned AW');
iTest(DivNaAll, DivTrAll, 8, 'All cells: Naive LO vs Transfer LW (original bad test)');

% Trajectory
k8 = isfinite(DivAOInh) & isfinite(DivAWInh) & isfinite(DivTrInh);
if sum(k8) >= 3
    fprintf('\n★ Inherited cells trajectory (n=%d):\n', sum(k8));
    fprintf('  Naive AO:    %.4f±%.4f\n', mean(DivAOInh(k8)), std(DivAOInh(k8))/sqrt(sum(k8)));
    fprintf('  Learned AW:  %.4f±%.4f\n', mean(DivAWInh(k8)), std(DivAWInh(k8))/sqrt(sum(k8)));
    fprintf('  Transfer LW: %.4f±%.4f\n', mean(DivTrInh(k8)), std(DivTrInh(k8))/sqrt(sum(k8)));
    fprintf('  AO→AW p=%.4g | AW→TrLW p=%.4g | AO→TrLW p=%.4g\n', ...
        signrank(DivAOInh(k8),DivAWInh(k8)), signrank(DivAWInh(k8),DivTrInh(k8)), signrank(DivAOInh(k8),DivTrInh(k8)));
end

%% ===== LOCAL FUNCTIONS =====
function iTest(a, b, idx, label)
    k = isfinite(a) & isfinite(b);
    if sum(k) < 3
        fprintf('[%d] %s: insufficient data (n=%d)\n\n', idx, label, sum(k));
        return;
    end
    p = signrank(a(k), b(k));
    ma = mean(a(k)); mb = mean(b(k));
    sea = std(a(k))/sqrt(sum(k)); seb = std(b(k))/sqrt(sum(k));
    if ma < mb, dir = '<'; elseif ma > mb, dir = '>'; else, dir = '='; end
    fprintf('[%d] %s:\n    Left: %.4f±%.4f | Right: %.4f±%.4f | n=%d | p=%.4g (%s)\n\n', ...
        idx, label, ma, sea, mb, seb, sum(k), p, dir);
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
