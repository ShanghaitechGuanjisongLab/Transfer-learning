%% scratch_PopulationGeometry_Unpaired.m
% 非配对比较：3数据集 Naive LO 几何指标 vs Transfer LW (ALB)
% 同时做时间分辨PR分析

% 确保项目已加载
cd('D:\Users\张天夫\Documents\MATLAB\Transfer-learning');

sampleRate = 8;
baselineSec = 0;
idxCue = 3*sampleRate;
idx1s  = idxCue + sampleRate;

%% PART 1: 收集3数据集 Naive LO 几何指标
DSNames = ["AudioLightBaseline","LightAudioBaseline","LAInterspersed"];

NaLO_PR = []; NaLO_EVC2 = []; NaLO_SNAlign = []; NaLO_Div = []; NaLO_NCells = [];
NaLO_Mouse = string([]); NaLO_DS = string([]);
% 时间分辨
timeIdxList = idxCue + (0:sampleRate*2); % 0s到2s post-cue, 每个时间点
NaLO_PR_t = [];

for d = 1:numel(DSNames)
    switch DSNames(d)
        case "AudioLightBaseline",  DS = TransferLearning.AudioLightBaseline();
        case "LightAudioBaseline",  DS = TransferLearning.LightAudioBaseline();
        case "LAInterspersed",      DS = TransferLearning.LAInterspersed();
    end
    dsName = DSNames(d);
    
    TnaiveLO = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Naive", Stimulus="LightOnly");
    TnaiveLO.Mouse = string(TnaiveLO.Mouse);
    TnaiveLO.DateTime = datetime(TnaiveLO.DateTime);
    try TnaiveLO.DateTime.TimeZone=''; catch, end
    
    loMice = unique(TnaiveLO.Mouse);
    for i = 1:numel(loMice)
        m = loMice(i);
        
        ntsLO = DS.QueryNTS(struct('Stimulus',"LightOnly",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
        if iscell(ntsLO), ntsLO=ntsLO{1}; end
        if isempty(ntsLO), continue; end
        
        Tn = TnaiveLO(TnaiveLO.Mouse==m,:);
        sessionDtN = min(Tn.DateTime);
        Tn = sortrows(Tn(Tn.DateTime==sessionDtN,:),"TrialIndex");
        trialUIDsN = unique(uint64(Tn.TrialUID),'stable');
        
        [CTT_LO, ~] = iLocalBuildCTT(ntsLO, trialUIDsN, sampleRate, baselineSec);
        if isempty(CTT_LO) || size(CTT_LO,1) < 3, continue; end
        
        [pr, evc2, ~, snA, div] = iComputeGeometry(CTT_LO, idx1s);
        
        NaLO_PR(end+1,1) = pr;
        NaLO_EVC2(end+1,1) = evc2;
        NaLO_SNAlign(end+1,1) = snA;
        NaLO_Div(end+1,1) = div;
        NaLO_NCells(end+1,1) = size(CTT_LO,1);
        NaLO_Mouse(end+1,1) = m;
        NaLO_DS(end+1,1) = dsName;
        
        % 时间分辨 PR
        pr_t = nan(1,numel(timeIdxList));
        for ti = 1:numel(timeIdxList)
            tIdx = timeIdxList(ti);
            if tIdx >= 1 && tIdx <= size(CTT_LO,3)
                [pr_t(ti),~,~,~,~] = iComputeGeometry(CTT_LO, tIdx);
            end
        end
        NaLO_PR_t(end+1,:) = pr_t;
        
        fprintf('NaLO %s %s: nCell=%d PR=%.1f EVC2=%.1f%% SNA=%.3f Div=%.3f\n', ...
            dsName, m, size(CTT_LO,1), pr, 100*evc2, snA, div);
    end
end

nNaLO = numel(NaLO_PR);
fprintf('\n共收集 %d 只 Naive LO 鼠\n\n', nNaLO);

%% PART 2: Transfer LW (ALB) 几何指标 - 全细胞、继承组、非继承组
DS_ALB = TransferLearning.AudioLightBaseline();

TlearnAW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TtransLW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TlearnAW.Mouse = string(TlearnAW.Mouse); TlearnAW.DateTime = datetime(TlearnAW.DateTime); try TlearnAW.DateTime.TimeZone=''; catch, end
TtransLW.Mouse = string(TtransLW.Mouse); TtransLW.DateTime = datetime(TtransLW.DateTime); try TtransLW.DateTime.TimeZone=''; catch, end

trMice = intersect(unique(TtransLW.Mouse), unique(TlearnAW.Mouse));

TrLW_PR_all = []; TrLW_EVC2_all = []; TrLW_SNAlign_all = []; TrLW_Div_all = [];
TrLW_PR_inh = []; TrLW_EVC2_inh = []; TrLW_SNAlign_inh = []; TrLW_Div_inh = [];
TrLW_PR_non = []; TrLW_EVC2_non = []; TrLW_SNAlign_non = []; TrLW_Div_non = [];
TrLW_Mouse = string([]);
TrLW_PR_t_all = []; TrLW_PR_t_inh = []; TrLW_PR_t_non = [];

for i = 1:numel(trMice)
    m = trMice(i);
    
    ntsAW = DS_ALB.QueryNTS(struct('Stimulus',"AudioWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsLW = DS_ALB.QueryNTS(struct('Stimulus',"LightWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsAW), ntsAW=ntsAW{1}; end
    if iscell(ntsLW), ntsLW=ntsLW{1}; end
    if isempty(ntsAW) || isempty(ntsLW), continue; end
    
    Ta = TlearnAW(TlearnAW.Mouse==m,:); sessionDtA = max(Ta.DateTime);
    Ta = sortrows(Ta(Ta.DateTime==sessionDtA,:),"TrialIndex");
    trialUIDsA = unique(uint64(Ta.TrialUID),'stable');
    
    Tt = TtransLW(TtransLW.Mouse==m,:); sessionDtT = min(Tt.DateTime);
    Tt = sortrows(Tt(Tt.DateTime==sessionDtT,:),"TrialIndex");
    trialUIDsT = unique(uint64(Tt.TrialUID),'stable');
    
    [CTT_AW, uid_AW] = iLocalBuildCTT(ntsAW, trialUIDsA, sampleRate, baselineSec);
    [CTT_LW, uid_LW] = iLocalBuildCTT(ntsLW, trialUIDsT, sampleRate, baselineSec);
    if isempty(CTT_AW) || isempty(CTT_LW), continue; end
    
    ntats_AW = squeeze(mean(CTT_AW,2));
    bsl = ntats_AW(:,1:24);
    activeAW = ntats_AW(:,idx1s) > mean(bsl,2) + 3*std(bsl,[],2);
    learnedActiveUIDs = uid_AW(activeAW);
    isInh = ismember(uid_LW, learnedActiveUIDs);
    
    % All cells
    [pr,evc2,~,snA,div] = iComputeGeometry(CTT_LW, idx1s);
    TrLW_PR_all(end+1,1) = pr;
    TrLW_EVC2_all(end+1,1) = evc2;
    TrLW_SNAlign_all(end+1,1) = snA;
    TrLW_Div_all(end+1,1) = div;
    TrLW_Mouse(end+1,1) = m;
    
    % Time-resolved all
    pr_t = nan(1,numel(timeIdxList));
    for ti = 1:numel(timeIdxList)
        tIdx = timeIdxList(ti);
        if tIdx>=1 && tIdx<=size(CTT_LW,3)
            [pr_t(ti),~,~,~,~] = iComputeGeometry(CTT_LW, tIdx);
        end
    end
    TrLW_PR_t_all(end+1,:) = pr_t;
    
    % Inherited
    if sum(isInh)>=3
        [pr,evc2,~,snA,div] = iComputeGeometry(CTT_LW(isInh,:,:), idx1s);
        TrLW_PR_inh(end+1,1) = pr;
        TrLW_EVC2_inh(end+1,1) = evc2;
        TrLW_SNAlign_inh(end+1,1) = snA;
        TrLW_Div_inh(end+1,1) = div;
        
        pr_t = nan(1,numel(timeIdxList));
        for ti = 1:numel(timeIdxList)
            tIdx = timeIdxList(ti);
            if tIdx>=1 && tIdx<=size(CTT_LW,3)
                [pr_t(ti),~,~,~,~] = iComputeGeometry(CTT_LW(isInh,:,:), tIdx);
            end
        end
        TrLW_PR_t_inh(end+1,:) = pr_t;
    end
    
    % Non-inherited
    if sum(~isInh)>=3
        [pr,evc2,~,snA,div] = iComputeGeometry(CTT_LW(~isInh,:,:), idx1s);
        TrLW_PR_non(end+1,1) = pr;
        TrLW_EVC2_non(end+1,1) = evc2;
        TrLW_SNAlign_non(end+1,1) = snA;
        TrLW_Div_non(end+1,1) = div;
        
        pr_t = nan(1,numel(timeIdxList));
        for ti = 1:numel(timeIdxList)
            tIdx = timeIdxList(ti);
            if tIdx>=1 && tIdx<=size(CTT_LW,3)
                [pr_t(ti),~,~,~,~] = iComputeGeometry(CTT_LW(~isInh,:,:), tIdx);
            end
        end
        TrLW_PR_t_non(end+1,:) = pr_t;
    end
    
    fprintf('TrLW %s: PR_all=%.1f PR_inh=%.1f PR_non=%.1f\n', m, ...
        TrLW_PR_all(end), TrLW_PR_inh(end), TrLW_PR_non(end));
end

nTr = numel(TrLW_PR_all);
fprintf('\n共 %d 只 Transfer LW 鼠\n\n', nTr);

%% PART 3: 非配对检验
fprintf('============================================================\n');
fprintf('  非配对检验 (ranksum): NaiveLO (3 datasets) vs TransferLW\n');
fprintf('============================================================\n\n');

iUnpairedTest(NaLO_PR, TrLW_PR_all, 'PR: NaLO(all) vs TrLW(all)');
iUnpairedTest(NaLO_EVC2, TrLW_EVC2_all, 'EVC2: NaLO(all) vs TrLW(all)');
iUnpairedTest(NaLO_SNAlign, TrLW_SNAlign_all, 'SNAlign: NaLO(all) vs TrLW(all)');
iUnpairedTest(NaLO_Div, TrLW_Div_all, 'Div: NaLO(all) vs TrLW(all)');
fprintf('\n');

iUnpairedTest(NaLO_PR, TrLW_PR_inh, 'PR: NaLO(all) vs TrLW(inherited)');
iUnpairedTest(NaLO_EVC2, TrLW_EVC2_inh, 'EVC2: NaLO(all) vs TrLW(inherited)');
iUnpairedTest(NaLO_SNAlign, TrLW_SNAlign_inh, 'SNAlign: NaLO(all) vs TrLW(inherited)');
iUnpairedTest(NaLO_Div, TrLW_Div_inh, 'Div: NaLO(all) vs TrLW(inherited)');
fprintf('\n');

iUnpairedTest(NaLO_PR, TrLW_PR_non, 'PR: NaLO(all) vs TrLW(non-inherited)');
iUnpairedTest(NaLO_EVC2, TrLW_EVC2_non, 'EVC2: NaLO(all) vs TrLW(non-inherited)');
iUnpairedTest(NaLO_SNAlign, TrLW_SNAlign_non, 'SNAlign: NaLO(all) vs TrLW(non-inherited)');
iUnpairedTest(NaLO_Div, TrLW_Div_non, 'Div: NaLO(all) vs TrLW(non-inherited)');

%% PART 3b: 排除ALB鼠的NaLO单独比较
isNonALB = NaLO_DS ~= "AudioLightBaseline";
fprintf('\n============================================================\n');
fprintf('  非配对(仅用nonALB NaLO n=%d) vs TrLW\n', sum(isNonALB));
fprintf('============================================================\n\n');

iUnpairedTest(NaLO_PR(isNonALB), TrLW_PR_all, 'PR: NaLO(nonALB) vs TrLW(all)');
iUnpairedTest(NaLO_EVC2(isNonALB), TrLW_EVC2_all, 'EVC2: NaLO(nonALB) vs TrLW(all)');
iUnpairedTest(NaLO_SNAlign(isNonALB), TrLW_SNAlign_all, 'SNAlign: NaLO(nonALB) vs TrLW(all)');
iUnpairedTest(NaLO_Div(isNonALB), TrLW_Div_all, 'Div: NaLO(nonALB) vs TrLW(all)');
fprintf('\n');
iUnpairedTest(NaLO_PR(isNonALB), TrLW_PR_inh, 'PR: NaLO(nonALB) vs TrLW(inh)');
iUnpairedTest(NaLO_SNAlign(isNonALB), TrLW_SNAlign_inh, 'SNAlign: NaLO(nonALB) vs TrLW(inh)');

%% PART 4: 时间分辨PR
fprintf('\n============================================================\n');
fprintf('  时间分辨 PR: 每个时间点上的 ranksum(NaLO vs TrLW)\n');
fprintf('============================================================\n\n');

timeSec = (0:numel(timeIdxList)-1)/sampleRate;
fprintf('Time(s)  NaLO_PR   TrLW_PR   p_all    TrInh_PR  p_inh\n');
for ti = 1:numel(timeIdxList)
    na_pr = NaLO_PR_t(:,ti);
    tr_pr_a = TrLW_PR_t_all(:,ti);
    tr_pr_i = TrLW_PR_t_inh(:,ti);
    
    ka = isfinite(na_pr); ka2 = isfinite(tr_pr_a); ki = isfinite(tr_pr_i);
    
    p_all = NaN; p_inh = NaN;
    if sum(ka)>=3 && sum(ka2)>=3
        p_all = ranksum(na_pr(ka), tr_pr_a(ka2));
    end
    if sum(ka)>=3 && sum(ki)>=3
        p_inh = ranksum(na_pr(ka), tr_pr_i(ki));
    end
    
    sig_a = ''; if p_all < 0.05, sig_a = ' *'; end; if p_all < 0.01, sig_a = ' **'; end
    sig_i = ''; if p_inh < 0.05, sig_i = ' *'; end; if p_inh < 0.01, sig_i = ' **'; end
    
    fprintf('%.2f     %.1f±%.1f  %.1f±%.1f  %.4g%s  %.1f±%.1f  %.4g%s\n', ...
        timeSec(ti), ...
        mean(na_pr(ka)), std(na_pr(ka))/sqrt(sum(ka)), ...
        mean(tr_pr_a(ka2)), std(tr_pr_a(ka2))/sqrt(sum(ka2)), p_all, sig_a, ...
        mean(tr_pr_i(ki)), std(tr_pr_i(ki))/sqrt(sum(ki)), p_inh, sig_i);
end

%% ===== LOCAL FUNCTIONS =====

function iUnpairedTest(a, b, label)
    ka = isfinite(a); kb = isfinite(b);
    na = sum(ka); nb = sum(kb);
    if na < 3 || nb < 3
        fprintf('  %s: insufficient (n=%d vs %d)\n', label, na, nb);
        return;
    end
    p = ranksum(a(ka), b(kb));
    ma = mean(a(ka)); mb = mean(b(kb));
    sea = std(a(ka))/sqrt(na); seb = std(b(kb))/sqrt(nb);
    if ma < mb, dir='<'; elseif ma > mb, dir='>'; else, dir='='; end
    sig = '';
    if p<0.05, sig=' *'; end
    if p<0.01, sig=' **'; end
    if p<0.001, sig=' ***'; end
    fprintf('  %s:\n    %.3f±%.3f (n=%d) vs %.3f±%.3f (n=%d)  p=%.4g%s (%s)\n', ...
        label, ma, sea, na, mb, seb, nb, p, sig, dir);
end

function [pr, evc2, evc3, snAlign, div] = iComputeGeometry(CTT, timeIdx)
nCell = size(CTT,1);
nTrial = size(CTT,2);
X = CTT(:,:,timeIdx);
C = cov(X');
eigvals = eig(C);
eigvals = max(eigvals, 0);
eigvals = sort(eigvals, 'descend');
trEig = sum(eigvals);
trEig2 = sum(eigvals.^2);
if trEig2 > 0 && trEig > 0
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
noiseCov = (noise * noise') / max(nTrial - 1, 1);
[V, D] = eig(noiseCov, 'vector');
[~, sortIdx] = sort(D, 'descend');
noisePC1 = V(:, sortIdx(1));
if sigNorm > 0
    cosAngle = abs(dot(signal/sigNorm, noisePC1));
    snAlign = 1 - cosAngle^2;
else
    snAlign = NaN;
end
div = sqrt(sum(var(X,[],2),1) ./ sum(mean(X,2).^2));
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
        traces{end+1,1} = so; keepU(end+1,1) = cid;
    end
    if isempty(traces), return; end
    nC = numel(traces); nTr = size(traces{1},1); nTi = size(traces{1},2);
    CTT = nan(nC,nTr,nTi);
    for c = 1:nC, CTT(c,:,:) = traces{c}; end
    idx0 = max(1,min(nTi, 3*sampleRate+round(baselineSec*sampleRate)));
    CTT = CTT - CTT(:,:,idx0);
    cellUIDs = uint64(keepU);
end
