%% scratch_NaiveLW_vs_TransferLW_Unpaired.m
% 非配对比较：Naive LightWater vs Transfer LightWater
% 规范：
% - Naive LightWater: LightAudioBaseline + LAInterspersed，且Naive会话中不得掺杂AudioWater
% - Transfer LightWater: AudioLightBaseline (Transfer phase)

cd('D:/Users/张天夫/Documents/MATLAB/Transfer-learning');

sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s = idxCue + sampleRate;
timeIdxList = idxCue + (0:sampleRate*2); % cue后0~2s

%% ===== Part 1: 收集 Naive LW（LAB + LAI） =====
naiveDSNames = ["LightAudioBaseline","LAInterspersed"];

% 预分配上限
maxNaiveMouse = 200;
Naive_PR = nan(maxNaiveMouse,1);
Naive_EVC2 = nan(maxNaiveMouse,1);
Naive_SNAlign = nan(maxNaiveMouse,1);
Naive_Div = nan(maxNaiveMouse,1);
Naive_NCells = nan(maxNaiveMouse,1);
Naive_PR_t = nan(maxNaiveMouse, numel(timeIdxList));
Naive_Mouse = strings(maxNaiveMouse,1);
Naive_DS = strings(maxNaiveMouse,1);

nNaive = 0;

for d = 1:numel(naiveDSNames)
    dsName = naiveDSNames(d);
    if dsName == "LightAudioBaseline"
        DS = TransferLearning.LightAudioBaseline();
    else
        DS = TransferLearning.LAInterspersed();
    end

    % 先取 Naive phase 全表，用于筛“无AudioWater掺杂”的 LightWater 会话
    TnaiveAll = DS.TableQuery(["Mouse","DateTime","Stimulus","TrialUID","TrialIndex"], Phase="Naive");
    TnaiveAll.Mouse = string(TnaiveAll.Mouse);
    TnaiveAll.Stimulus = string(TnaiveAll.Stimulus);

    mice = unique(TnaiveAll.Mouse);
    for i = 1:numel(mice)
        m = mice(i);
        Tm = TnaiveAll(TnaiveAll.Mouse==m,:);
        if isempty(Tm)
            continue;
        end

        sess = unique(Tm.DateTime);
        sess = sort(sess,'ascend');

        isValidSess = false(numel(sess),1);
        for s = 1:numel(sess)
            Ts = Tm(Tm.DateTime==sess(s),:);
            hasLW = any(Ts.Stimulus=="LightWater");
            hasAW = any(Ts.Stimulus=="AudioWater");
            if hasLW && ~hasAW
                isValidSess(s) = true;
            end
        end

        validSess = sess(isValidSess);
        if isempty(validSess)
            continue;
        end

        % 用首个有效Naive-LW会话
        dt = validSess(1);
        Ts = Tm(Tm.DateTime==dt & Tm.Stimulus=="LightWater", :);
        Ts = sortrows(Ts, "TrialIndex");
        trialUIDs = unique(uint64(Ts.TrialUID), 'stable');
        if numel(trialUIDs) < 2
            continue;
        end

        ntsLW = DS.QueryNTS(struct('Stimulus',"LightWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
        if iscell(ntsLW)
            ntsLW = ntsLW{1};
        end
        if isempty(ntsLW)
            continue;
        end

        [CTT, ~] = iLocalBuildCTT(ntsLW, trialUIDs, sampleRate, 0);
        if isempty(CTT) || size(CTT,1) < 3
            continue;
        end

        [pr, evc2, ~, sn, div] = iComputeGeometry(CTT, idx1s);

        nNaive = nNaive + 1;
        Naive_PR(nNaive) = pr;
        Naive_EVC2(nNaive) = evc2;
        Naive_SNAlign(nNaive) = sn;
        Naive_Div(nNaive) = div;
        Naive_NCells(nNaive) = size(CTT,1);
        Naive_Mouse(nNaive) = m;
        Naive_DS(nNaive) = dsName;

        pr_t = nan(1,numel(timeIdxList));
        for ti = 1:numel(timeIdxList)
            [pr_t(ti),~,~,~,~] = iComputeGeometry(CTT, timeIdxList(ti));
        end
        Naive_PR_t(nNaive,:) = pr_t;

        fprintf('NaiveLW %s %s: nCell=%d PR=%.2f EVC2=%.1f%% SN=%.3f Div=%.3f\n', ...
            dsName, m, size(CTT,1), pr, 100*evc2, sn, div);
    end
end

Naive_PR = Naive_PR(1:nNaive);
Naive_EVC2 = Naive_EVC2(1:nNaive);
Naive_SNAlign = Naive_SNAlign(1:nNaive);
Naive_Div = Naive_Div(1:nNaive);
Naive_NCells = Naive_NCells(1:nNaive);
Naive_PR_t = Naive_PR_t(1:nNaive,:);
Naive_Mouse = Naive_Mouse(1:nNaive);
Naive_DS = Naive_DS(1:nNaive);

fprintf('\nNaive LW 总数: n=%d (LAB+LAI, 排除混入AudioWater会话)\n\n', nNaive);

%% ===== Part 2: 收集 Transfer LW（ALB） =====
DS = TransferLearning.AudioLightBaseline();
Ttrans = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
Ttrans.Mouse = string(Ttrans.Mouse);

mice = unique(Ttrans.Mouse);
maxTransMouse = numel(mice);
Trans_PR = nan(maxTransMouse,1);
Trans_EVC2 = nan(maxTransMouse,1);
Trans_SNAlign = nan(maxTransMouse,1);
Trans_Div = nan(maxTransMouse,1);
Trans_NCells = nan(maxTransMouse,1);
Trans_PR_t = nan(maxTransMouse, numel(timeIdxList));
Trans_Mouse = strings(maxTransMouse,1);

nTrans = 0;
for i = 1:numel(mice)
    m = mice(i);

    Tm = Ttrans(Ttrans.Mouse==m,:);
    if isempty(Tm)
        continue;
    end
    dt = min(Tm.DateTime); % 首个Transfer会话
    Ts = Tm(Tm.DateTime==dt,:);
    Ts = sortrows(Ts, "TrialIndex");
    trialUIDs = unique(uint64(Ts.TrialUID), 'stable');
    if numel(trialUIDs) < 2
        continue;
    end

    ntsLW = DS.QueryNTS(struct('Stimulus',"LightWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsLW)
        ntsLW = ntsLW{1};
    end
    if isempty(ntsLW)
        continue;
    end

    [CTT, ~] = iLocalBuildCTT(ntsLW, trialUIDs, sampleRate, 0);
    if isempty(CTT) || size(CTT,1) < 3
        continue;
    end

    [pr, evc2, ~, sn, div] = iComputeGeometry(CTT, idx1s);

    nTrans = nTrans + 1;
    Trans_PR(nTrans) = pr;
    Trans_EVC2(nTrans) = evc2;
    Trans_SNAlign(nTrans) = sn;
    Trans_Div(nTrans) = div;
    Trans_NCells(nTrans) = size(CTT,1);
    Trans_Mouse(nTrans) = m;

    pr_t = nan(1,numel(timeIdxList));
    for ti = 1:numel(timeIdxList)
        [pr_t(ti),~,~,~,~] = iComputeGeometry(CTT, timeIdxList(ti));
    end
    Trans_PR_t(nTrans,:) = pr_t;

    fprintf('TransferLW ALB %s: nCell=%d PR=%.2f EVC2=%.1f%% SN=%.3f Div=%.3f\n', ...
        m, size(CTT,1), pr, 100*evc2, sn, div);
end

Trans_PR = Trans_PR(1:nTrans);
Trans_EVC2 = Trans_EVC2(1:nTrans);
Trans_SNAlign = Trans_SNAlign(1:nTrans);
Trans_Div = Trans_Div(1:nTrans);
Trans_NCells = Trans_NCells(1:nTrans);
Trans_PR_t = Trans_PR_t(1:nTrans,:);
Trans_Mouse = Trans_Mouse(1:nTrans);

fprintf('\nTransfer LW 总数: n=%d (ALB)\n\n', nTrans);

%% ===== Part 3: 非配对统计 =====
fprintf('============================================================\n');
fprintf('  非配对比较: NaiveLW (LAB+LAI) vs TransferLW (ALB)\n');
fprintf('============================================================\n\n');

iUnpaired(Naive_PR, Trans_PR, 'PR');
iUnpaired(Naive_EVC2, Trans_EVC2, 'EVC2');
iUnpaired(Naive_SNAlign, Trans_SNAlign, 'SNAlign');
iUnpaired(Naive_Div, Trans_Div, 'Divergence');

fprintf('\n===== 时间分辨 PR 非配对比较 (ranksum) =====\n');
fprintf('Time(s)  NaiveLW_PR  TransferLW_PR  p\n');
sec = (0:numel(timeIdxList)-1)/sampleRate;
for ti = 1:numel(timeIdxList)
    a = Naive_PR_t(:,ti);
    b = Trans_PR_t(:,ti);
    ka = isfinite(a);
    kb = isfinite(b);
    if sum(ka)>=3 && sum(kb)>=3
        p = ranksum(a(ka), b(kb));
        sig = '';
        if p<0.05
            sig = ' *';
        end
        if p<0.01
            sig = ' **';
        end
        fprintf('%.2f     %.2f±%.2f   %.2f±%.2f   %.4g%s\n', ...
            sec(ti), mean(a(ka)), std(a(ka))/sqrt(sum(ka)), ...
            mean(b(kb)), std(b(kb))/sqrt(sum(kb)), p, sig);
    end
end

%% ===== local functions =====
function iUnpaired(a,b,label)
ka = isfinite(a);
kb = isfinite(b);
na = sum(ka);
nb = sum(kb);
if na < 3 || nb < 3
    fprintf('%s: insufficient n=%d vs %d\n', label, na, nb);
    return;
end
p = ranksum(a(ka), b(kb));
ma = mean(a(ka));
mb = mean(b(kb));
sea = std(a(ka))/sqrt(na);
seb = std(b(kb))/sqrt(nb);

dir = '=';
if ma < mb
    dir = '<';
elseif ma > mb
    dir = '>';
end
sig = '';
if p<0.05
    sig = ' *';
end
if p<0.01
    sig = ' **';
end
if p<0.001
    sig = ' ***';
end
fprintf('%s: %.3f±%.3f (n=%d) vs %.3f±%.3f (n=%d)  p=%.4g%s (%s)\n', ...
    label, ma, sea, na, mb, seb, nb, p, sig, dir);
end

function [pr, evc2, evc3, snAlign, div] = iComputeGeometry(CTT, timeIdx)
X = CTT(:,:,timeIdx);
C = cov(X');
eigvals = eig(C);
eigvals = max(eigvals,0);
eigvals = sort(eigvals,'descend');
trEig = sum(eigvals);
trEig2 = sum(eigvals.^2);
if trEig>0 && trEig2>0
    pr = trEig^2 / trEig2;
else
    pr = NaN;
end
if trEig>0
    cumFrac = cumsum(eigvals)/trEig;
    evc2 = cumFrac(min(2,numel(cumFrac)));
    evc3 = cumFrac(min(3,numel(cumFrac)));
else
    evc2 = NaN;
    evc3 = NaN;
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
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs)<2
    return;
end
inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial,:);
if isempty(nts2)
    return;
end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs,uNts));
if numel(trialUIDs)<2
    return;
end
allC = unique(uint64(nts2.CellUID));
traces = cell(numel(allC),1);
keepU = zeros(numel(allC),1,'uint64');
nKeep = 0;
for i = 1:numel(allC)
    cid = allC(i);
    rows = (uint64(nts2.CellUID)==cid);
    if sum(rows) < numel(trialUIDs)
        continue;
    end
    uid = uint64(nts2.TrialUID(rows));
    sig = double(nts2.TrialSignal(rows,:));
    [tf,loc] = ismember(trialUIDs, uid);
    if ~all(tf)
        continue;
    end
    so = sig(loc,:);
    if any(~isfinite(so),'all')
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
nC = nKeep;
nTr = size(traces{1},1);
nTi = size(traces{1},2);
CTT = nan(nC,nTr,nTi);
for i = 1:nC
    CTT(i,:,:) = traces{i};
end
idx0 = max(1,min(nTi,3*sampleRate+round(baselineSec*sampleRate)));
CTT = CTT - CTT(:,:,idx0);
cellUIDs = keepU;
end