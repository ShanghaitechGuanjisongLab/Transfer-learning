%% scratch_NaiveLW_vs_TransferLW_LAI.m
% 比较 LAInterspersed 数据集中 Naive LightWater vs Transfer LightWater
% 重点回答：是否有显著差异（1s后可比，因为两组均有给水）

cd('D:/Users/张天夫/Documents/MATLAB/Transfer-learning');

DS = TransferLearning.LAInterspersed();
sampleRate = 8;
idxCue = 3*sampleRate;
idx1s = idxCue + sampleRate;
timeIdxList = idxCue + (0:sampleRate*2); % 0-2s

TnaiveLW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Naive", Stimulus="LightWater");
TtransLW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TlearnAW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");

TnaiveLW.Mouse = string(TnaiveLW.Mouse); TnaiveLW.DateTime = datetime(TnaiveLW.DateTime); try TnaiveLW.DateTime.TimeZone=''; catch, end
TtransLW.Mouse = string(TtransLW.Mouse); TtransLW.DateTime = datetime(TtransLW.DateTime); try TtransLW.DateTime.TimeZone=''; catch, end
TlearnAW.Mouse = string(TlearnAW.Mouse); TlearnAW.DateTime = datetime(TlearnAW.DateTime); try TlearnAW.DateTime.TimeZone=''; catch, end

mice = intersect(unique(TnaiveLW.Mouse), unique(TtransLW.Mouse));
hasLearnedAW = ~isempty(TlearnAW);
fprintf('LAI: NaiveLW mice=%d, TransferLW mice=%d, overlap=%d\n', ...
    numel(unique(TnaiveLW.Mouse)), numel(unique(TtransLW.Mouse)), numel(mice));
if ~hasLearnedAW
    fprintf('注：LAI 中无 Learned-AudioWater，会跳过 inherited/non-inherited 分析，仅做 all-cells 比较。\n');
end

PR_N_all=[]; EVC2_N_all=[]; SN_N_all=[]; Div_N_all=[];
PR_T_all=[]; EVC2_T_all=[]; SN_T_all=[]; Div_T_all=[];
PR_N_inh=[]; EVC2_N_inh=[]; SN_N_inh=[]; Div_N_inh=[];
PR_T_inh=[]; EVC2_T_inh=[]; SN_T_inh=[]; Div_T_inh=[];
PR_N_non=[]; EVC2_N_non=[]; SN_N_non=[]; Div_N_non=[];
PR_T_non=[]; EVC2_T_non=[]; SN_T_non=[]; Div_T_non=[];

PRt_N_all=[]; PRt_T_all=[];

for i = 1:numel(mice)
    m = mice(i);

    ntsLW = DS.QueryNTS(struct('Stimulus',"LightWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsLW), ntsLW = ntsLW{1}; end
    if isempty(ntsLW), continue; end

    % Naive LW: first session
    Tn = TnaiveLW(TnaiveLW.Mouse==m,:);
    if isempty(Tn), continue; end
    dtN = min(Tn.DateTime);
    Tn = sortrows(Tn(Tn.DateTime==dtN,:), "TrialIndex");
    trialN = unique(uint64(Tn.TrialUID),'stable');

    % Transfer LW: first transfer session
    Tt = TtransLW(TtransLW.Mouse==m,:);
    if isempty(Tt), continue; end
    dtT = min(Tt.DateTime);
    Tt = sortrows(Tt(Tt.DateTime==dtT,:), "TrialIndex");
    trialT = unique(uint64(Tt.TrialUID),'stable');

    [CTT_N, uidN] = iLocalBuildCTT(ntsLW, trialN, sampleRate, 0);
    [CTT_T, uidT] = iLocalBuildCTT(ntsLW, trialT, sampleRate, 0);
    if isempty(CTT_N) || isempty(CTT_T), continue; end

    % inherited cells (only when Learned AW exists)
    isInhN = false(size(uidN));
    isInhT = false(size(uidT));
    if hasLearnedAW
        ntsAW = DS.QueryNTS(struct('Stimulus',"AudioWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
        if iscell(ntsAW), ntsAW = ntsAW{1}; end
        if ~isempty(ntsAW)
            Ta = TlearnAW(TlearnAW.Mouse==m,:);
            if ~isempty(Ta)
                dtA = max(Ta.DateTime);
                Ta = sortrows(Ta(Ta.DateTime==dtA,:), "TrialIndex");
                trialA = unique(uint64(Ta.TrialUID),'stable');
                [CTT_A, uidA] = iLocalBuildCTT(ntsAW, trialA, sampleRate, 0);
                if ~isempty(CTT_A)
                    ntA = squeeze(mean(CTT_A,2));
                    bsl = ntA(:,1:24);
                    activeA = ntA(:,idx1s) > mean(bsl,2) + 3*std(bsl,[],2);
                    inhUID = uidA(activeA);
                    isInhN = ismember(uidN, inhUID);
                    isInhT = ismember(uidT, inhUID);
                end
            end
        end
    end

    % all
    [pr,evc2,~,sn,div] = iComputeGeometry(CTT_N, idx1s);
    PR_N_all(end+1,1)=pr; EVC2_N_all(end+1,1)=evc2; SN_N_all(end+1,1)=sn; Div_N_all(end+1,1)=div;
    [pr,evc2,~,sn,div] = iComputeGeometry(CTT_T, idx1s);
    PR_T_all(end+1,1)=pr; EVC2_T_all(end+1,1)=evc2; SN_T_all(end+1,1)=sn; Div_T_all(end+1,1)=div;

    % inh
    if hasLearnedAW && sum(isInhN)>=3 && sum(isInhT)>=3
        [pr,evc2,~,sn,div] = iComputeGeometry(CTT_N(isInhN,:,:), idx1s);
        PR_N_inh(end+1,1)=pr; EVC2_N_inh(end+1,1)=evc2; SN_N_inh(end+1,1)=sn; Div_N_inh(end+1,1)=div;
        [pr,evc2,~,sn,div] = iComputeGeometry(CTT_T(isInhT,:,:), idx1s);
        PR_T_inh(end+1,1)=pr; EVC2_T_inh(end+1,1)=evc2; SN_T_inh(end+1,1)=sn; Div_T_inh(end+1,1)=div;
    end

    % non-inh
    if hasLearnedAW && sum(~isInhN)>=3 && sum(~isInhT)>=3
        [pr,evc2,~,sn,div] = iComputeGeometry(CTT_N(~isInhN,:,:), idx1s);
        PR_N_non(end+1,1)=pr; EVC2_N_non(end+1,1)=evc2; SN_N_non(end+1,1)=sn; Div_N_non(end+1,1)=div;
        [pr,evc2,~,sn,div] = iComputeGeometry(CTT_T(~isInhT,:,:), idx1s);
        PR_T_non(end+1,1)=pr; EVC2_T_non(end+1,1)=evc2; SN_T_non(end+1,1)=sn; Div_T_non(end+1,1)=div;
    end

    % time-resolved PR (all)
    prn = nan(1,numel(timeIdxList));
    prt = nan(1,numel(timeIdxList));
    for ti = 1:numel(timeIdxList)
        tIdx = timeIdxList(ti);
        [prn(ti),~,~,~,~] = iComputeGeometry(CTT_N, tIdx);
        [prt(ti),~,~,~,~] = iComputeGeometry(CTT_T, tIdx);
    end
    PRt_N_all(end+1,:) = prn;
    PRt_T_all(end+1,:) = prt;

    fprintf('Mouse %s: PR_N=%.1f PR_T=%.1f | PR_N_inh=%.1f PR_T_inh=%.1f\n', ...
        m, PR_N_all(end), PR_T_all(end), ...
        iLastOrNaN(PR_N_inh), iLastOrNaN(PR_T_inh));
end

fprintf('\n有效配对数: all=%d, inh=%d, non=%d\n\n', numel(PR_N_all), numel(PR_N_inh), numel(PR_N_non));

fprintf('===== 1s 几何指标配对检验 (Naive LW vs Transfer LW) =====\n');
iPair(PR_N_all, PR_T_all, 'PR all');
iPair(EVC2_N_all, EVC2_T_all, 'EVC2 all');
iPair(SN_N_all, SN_T_all, 'SNAlign all');
iPair(Div_N_all, Div_T_all, 'Divergence all');
fprintf('\n');
if hasLearnedAW
    iPair(PR_N_inh, PR_T_inh, 'PR inherited');
    iPair(EVC2_N_inh, EVC2_T_inh, 'EVC2 inherited');
    iPair(SN_N_inh, SN_T_inh, 'SNAlign inherited');
    iPair(Div_N_inh, Div_T_inh, 'Divergence inherited');
    fprintf('\n');
    iPair(PR_N_non, PR_T_non, 'PR non-inherited');
    iPair(EVC2_N_non, EVC2_T_non, 'EVC2 non-inherited');
    iPair(SN_N_non, SN_T_non, 'SNAlign non-inherited');
    iPair(Div_N_non, Div_T_non, 'Divergence non-inherited');
else
    fprintf('（LAI 无 Learned-AW，跳过 inherited/non-inherited 的统计）\n');
end

fprintf('\n===== 时间分辨 PR 配对检验 (all cells) =====\n');
sec = (0:numel(timeIdxList)-1)/sampleRate;
fprintf('Time(s)  NaiveLW_PR  TransferLW_PR  p\n');
if isempty(PRt_N_all) || isempty(PRt_T_all)
    fprintf('无有效配对数据，无法进行时间分辨分析。\n');
else
for ti = 1:numel(timeIdxList)
    a = PRt_N_all(:,ti); b = PRt_T_all(:,ti);
    k = isfinite(a) & isfinite(b);
    if sum(k) >= 3
        p = signrank(a(k), b(k));
        sig = ''; if p<0.05, sig=' *'; end; if p<0.01, sig=' **'; end
        fprintf('%.2f     %.2f±%.2f   %.2f±%.2f   %.4g%s\n', ...
            sec(ti), mean(a(k)), std(a(k))/sqrt(sum(k)), mean(b(k)), std(b(k))/sqrt(sum(k)), p, sig);
    end
end
end

%% local functions
function iPair(a,b,label)
k = isfinite(a) & isfinite(b);
n = sum(k);
if n < 3
    fprintf('%s: insufficient n=%d\n', label, n); return;
end
p = signrank(a(k), b(k));
ma = mean(a(k)); mb = mean(b(k));
sea = std(a(k))/sqrt(n); seb = std(b(k))/sqrt(n);
dir = '='; if ma < mb, dir = '<'; elseif ma > mb, dir = '>'; end
sig = ''; if p<0.05, sig=' *'; end; if p<0.01, sig=' **'; end; if p<0.001, sig=' ***'; end
fprintf('%s: %.3f±%.3f vs %.3f±%.3f  n=%d  p=%.4g%s (%s)\n', label, ma, sea, mb, seb, n, p, sig, dir);
end

function x = iLastOrNaN(a)
if isempty(a), x = NaN; else, x = a(end); end
end

function [pr, evc2, evc3, snAlign, div] = iComputeGeometry(CTT, timeIdx)
X = CTT(:,:,timeIdx);
C = cov(X');
eigvals = eig(C);
eigvals = max(eigvals,0);
eigvals = sort(eigvals,'descend');
trEig = sum(eigvals);
trEig2 = sum(eigvals.^2);
if trEig>0 && trEig2>0, pr = trEig^2/trEig2; else, pr = NaN; end
if trEig>0
    cumFrac = cumsum(eigvals)/trEig;
    evc2 = cumFrac(min(2,numel(cumFrac)));
    evc3 = cumFrac(min(3,numel(cumFrac)));
else
    evc2 = NaN; evc3 = NaN;
end
signal = mean(X,2);
sigNorm = norm(signal);
noise = X - signal;
nTrial = size(X,2);
noiseCov = (noise*noise')/max(nTrial-1,1);
[V,D] = eig(noiseCov,'vector');
[~,ix] = sort(D,'descend');
noisePC1 = V(:,ix(1));
if sigNorm>0
    c = abs(dot(signal/sigNorm, noisePC1));
    snAlign = 1 - c^2;
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
if numel(trialUIDs)<2, return; end
allC = unique(uint64(nts2.CellUID));
traces = {}; keepU = [];
for c = 1:numel(allC)
    cid = allC(c);
    rows = (uint64(nts2.CellUID)==cid);
    if sum(rows) < numel(trialUIDs), continue; end
    uid = uint64(nts2.TrialUID(rows));
    sig = double(nts2.TrialSignal(rows,:));
    [tf,loc] = ismember(trialUIDs, uid);
    if ~all(tf), continue; end
    so = sig(loc,:);
    if any(~isfinite(so),'all'), continue; end
    traces{end+1,1} = so; keepU(end+1,1) = cid;
end
if isempty(traces), return; end
nC = numel(traces); nTr = size(traces{1},1); nTi = size(traces{1},2);
CTT = nan(nC,nTr,nTi);
for c = 1:nC
    CTT(c,:,:) = traces{c};
end
idx0 = max(1,min(nTi,3*sampleRate+round(baselineSec*sampleRate)));
CTT = CTT - CTT(:,:,idx0);
cellUIDs = uint64(keepU);
end