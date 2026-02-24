%% 图3修改方案 MATLAB 验算脚本
% 目标：验证所有统计结论，并探索"信号保留"新分析

%% 0) 加载数据集
DS_ALB = TransferLearning.AudioLightBaseline();
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_TH  = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

fprintf('\n========== 图3修改方案 统计验算 ==========\n\n');

%% 1) 验证：Transfer vs Naive SD (session pair 均值)
fprintf('--- 1. Transfer vs Naive SD (已有结论，验证) ---\n');
% 运行D脚本的核心逻辑
run('+TransferLearning/英文图3/D_SD1s_NaiveVsTransfer_ByLayer.m');
close all;

%% 2) 验证：SD vs ΔHit 散点 (已有结论)
fprintf('\n--- 2. SD vs ΔHit (已有结论，验证) ---\n');
run('+TransferLearning/英文图3/C_SD1sVsDeltaHit_ByLayer.m');
close all;

%% 3) 验证：TH 抑制 ΔHit 和 SD
fprintf('\n--- 3. TH inhibit ΔHit & SD (已有结论，验证) ---\n');
run('+TransferLearning/英文图3/G_THInhibitVsCtrl_DeltaHitAndSD.m');
close all;

%% 4) 验证：Reuse vs ΔHit
fprintf('\n--- 4. Reuse vs ΔHit (已有结论，验证) ---\n');
run('+TransferLearning/英文图3/H_ReuseRateVsDeltaHit.m');
close all;

%% 5) 验证：Divergence vs ΔHit
fprintf('\n--- 5. Divergence vs ΔHit (已有结论，验证) ---\n');
run('+TransferLearning/英文图3/I_DivergenceVsDeltaHit.m');
close all;

%% 6) 新分析：信号保留 — AW响应与LW响应的相关性
fprintf('\n--- 6. 新分析：AW → LW 信号保留 ---\n');
% 对每只Transfer鼠：
%   取 Learned AW 最后一个session的per-cell median ZScore@1s
%   取第一个纯LW session的per-cell median ZScore@1s
%   计算两者的Pearson/Spearman相关
%   如果显著正相关 → 信号保留存在

CellTbl = DS_ALB.Cells;
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);
CellTbl.ZLayer = string(CellTbl.ZLayer);

DT = DS_ALB.DateTimes;
DT.DateTime = datetime(DT.DateTime); DT.DateTime.TimeZone = '';
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Blocks = DS_ALB.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime); Blocks.DateTime.TimeZone = '';

Trials = DS_ALB.Trials;
Trials.BlockUID = uint64(Trials.BlockUID);

mice = unique(CellTbl.Mouse);

corrPerMouse = nan(numel(mice), 1);
pPerMouse = nan(numel(mice), 1);
nCellPerMouse = nan(numel(mice), 1);

for mi = 1:numel(mice)
    m = mice(mi);
    
    % 找 Learned AW 的最后一个session
    mouseDTs = DT(DT.Mouse == m, :);
    learnedDTs = mouseDTs.DateTime(mouseDTs.Phase == "Learned");
    if isempty(learnedDTs), continue; end
    
    % 验证这些session有AW trial
    awDTs = datetime.empty;
    for di = 1:numel(learnedDTs)
        dt = learnedDTs(di);
        blks = Blocks.BlockUID(Blocks.DateTime == dt);
        tr = Trials(ismember(Trials.BlockUID, blks), :);
        if any(string(tr.Stimulus) == "AudioWater")
            awDTs(end+1) = dt;
        end
    end
    if isempty(awDTs), continue; end
    lastAWdt = max(awDTs);
    
    % 找第一个纯LW session
    transferDTs = sort(mouseDTs.DateTime(mouseDTs.Phase == "Transfer" | mouseDTs.Phase == "Final"));
    lwDTs = datetime.empty;
    for di = 1:numel(transferDTs)
        dt = transferDTs(di);
        blks = Blocks.BlockUID(Blocks.DateTime == dt);
        tr = Trials(ismember(Trials.BlockUID, blks), :);
        stims = unique(string(tr.Stimulus));
        if any(stims == "LightWater") && ~any(stims == "AudioWater")
            lwDTs(end+1) = dt;
        end
    end
    if isempty(lwDTs), continue; end
    firstLWdt = min(lwDTs);
    
    % 取AW session的per-cell median ZScore@1s
    ntsAW = DS_ALB.QueryNTS(struct('Stimulus','AudioWater','DateTime',lastAWdt,'Mouse',char(m)), ...
        UniExp.Flags.ZScore, 1:24);
    if iscell(ntsAW), ntsAW = ntsAW{1}; end
    if isempty(ntsAW) || ~istable(ntsAW), continue; end
    
    awCells = unique(uint64(ntsAW.CellUID));
    awMedian = nan(numel(awCells), 1);
    for ci = 1:numel(awCells)
        rows = ntsAW(uint64(ntsAW.CellUID) == awCells(ci), :);
        med = median(double(rows.TrialSignal), 1, 'omitnan');
        if numel(med) >= idx1s, awMedian(ci) = med(idx1s); end
    end
    
    % 取LW session的per-cell median ZScore@1s
    ntsLW = DS_ALB.QueryNTS(struct('Stimulus','LightWater','DateTime',firstLWdt,'Mouse',char(m)), ...
        UniExp.Flags.ZScore, 1:24);
    if iscell(ntsLW), ntsLW = ntsLW{1}; end
    if isempty(ntsLW) || ~istable(ntsLW), continue; end
    
    lwCells = unique(uint64(ntsLW.CellUID));
    lwMedian = nan(numel(lwCells), 1);
    for ci = 1:numel(lwCells)
        rows = ntsLW(uint64(ntsLW.CellUID) == lwCells(ci), :);
        med = median(double(rows.TrialSignal), 1, 'omitnan');
        if numel(med) >= idx1s, lwMedian(ci) = med(idx1s); end
    end
    
    % 取交集细胞
    [commonCells, iAW, iLW] = intersect(awCells, lwCells);
    if numel(commonCells) < 10, continue; end
    
    awV = awMedian(iAW);
    lwV = lwMedian(iLW);
    valid = isfinite(awV) & isfinite(lwV);
    if sum(valid) < 10, continue; end
    
    [rho, p] = corr(awV(valid), lwV(valid), 'Type', 'Spearman');
    corrPerMouse(mi) = rho;
    pPerMouse(mi) = p;
    nCellPerMouse(mi) = sum(valid);
    
    fprintf('  Mouse %s: AW→LW Spearman ρ=%.3f p=%.4g n=%d cells\n', ...
        m, rho, p, sum(valid));
end

validMice = isfinite(corrPerMouse);
fprintf('\n  Summary: %d mice with valid AW→LW correlation\n', sum(validMice));
fprintf('  Mean ρ = %.3f ± %.3f\n', mean(corrPerMouse(validMice)), std(corrPerMouse(validMice))/sqrt(sum(validMice)));
fprintf('  signrank vs 0: ');
if sum(validMice) >= 3
    [pSR, ~] = signrank(corrPerMouse(validMice));
    fprintf('p = %.4g\n', pSR);
else
    fprintf('too few mice\n');
end

%% 7) 新分析：AW-active 细胞的 LW 响应绝对值 vs AW-inactive
fprintf('\n--- 7. AW-active vs AW-inactive 细胞在首LW的 abs(response) ---\n');
% 如果AW-active细胞在LW中有更大的|response|，说明信号保留
absResp_active = nan(numel(mice), 1);
absResp_inactive = nan(numel(mice), 1);

for mi = 1:numel(mice)
    m = mice(mi);
    
    mouseDTs = DT(DT.Mouse == m, :);
    learnedDTs = mouseDTs.DateTime(mouseDTs.Phase == "Learned");
    if isempty(learnedDTs), continue; end
    
    awDTs = datetime.empty;
    for di = 1:numel(learnedDTs)
        dt = learnedDTs(di);
        blks = Blocks.BlockUID(Blocks.DateTime == dt);
        tr = Trials(ismember(Trials.BlockUID, blks), :);
        if any(string(tr.Stimulus) == "AudioWater")
            awDTs(end+1) = dt;
        end
    end
    if isempty(awDTs), continue; end
    lastAWdt = max(awDTs);
    
    transferDTs = sort(mouseDTs.DateTime(mouseDTs.Phase == "Transfer" | mouseDTs.Phase == "Final"));
    lwDTs = datetime.empty;
    for di = 1:numel(transferDTs)
        dt = transferDTs(di);
        blks = Blocks.BlockUID(Blocks.DateTime == dt);
        tr = Trials(ismember(Trials.BlockUID, blks), :);
        stims = unique(string(tr.Stimulus));
        if any(stims == "LightWater") && ~any(stims == "AudioWater")
            lwDTs(end+1) = dt;
        end
    end
    if isempty(lwDTs), continue; end
    firstLWdt = min(lwDTs);
    
    % AW per-cell median
    ntsAW = DS_ALB.QueryNTS(struct('Stimulus','AudioWater','DateTime',lastAWdt,'Mouse',char(m)), ...
        UniExp.Flags.ZScore, 1:24);
    if iscell(ntsAW), ntsAW = ntsAW{1}; end
    if isempty(ntsAW) || ~istable(ntsAW), continue; end
    
    awCells = unique(uint64(ntsAW.CellUID));
    awMedian = nan(numel(awCells), 1);
    for ci = 1:numel(awCells)
        rows = ntsAW(uint64(ntsAW.CellUID) == awCells(ci), :);
        med = median(double(rows.TrialSignal), 1, 'omitnan');
        if numel(med) >= idx1s, awMedian(ci) = med(idx1s); end
    end
    
    % LW per-cell median
    ntsLW = DS_ALB.QueryNTS(struct('Stimulus','LightWater','DateTime',firstLWdt,'Mouse',char(m)), ...
        UniExp.Flags.ZScore, 1:24);
    if iscell(ntsLW), ntsLW = ntsLW{1}; end
    if isempty(ntsLW) || ~istable(ntsLW), continue; end
    
    lwCells = unique(uint64(ntsLW.CellUID));
    lwMedian = nan(numel(lwCells), 1);
    for ci = 1:numel(lwCells)
        rows = ntsLW(uint64(ntsLW.CellUID) == lwCells(ci), :);
        med = median(double(rows.TrialSignal), 1, 'omitnan');
        if numel(med) >= idx1s, lwMedian(ci) = med(idx1s); end
    end
    
    % 交集细胞，按AW abs(median) 分组
    [commonCells, iAW, iLW] = intersect(awCells, lwCells);
    if numel(commonCells) < 10, continue; end
    
    awV = awMedian(iAW);
    lwV = lwMedian(iLW);
    valid = isfinite(awV) & isfinite(lwV);
    awV = awV(valid); lwV = lwV(valid);
    if numel(awV) < 10, continue; end
    
    % 按 abs(AW response) 分 top/bottom 50%
    absAW = abs(awV);
    nHalf = ceil(numel(absAW)/2);
    [~, sortIdx] = sort(absAW, 'descend');
    activeIdx = sortIdx(1:nHalf);
    inactiveIdx = sortIdx(nHalf+1:end);
    
    absResp_active(mi) = mean(abs(lwV(activeIdx)));
    absResp_inactive(mi) = mean(abs(lwV(inactiveIdx)));
    
    fprintf('  Mouse %s: |LW resp| active=%.3f inactive=%.3f (n=%d/%d)\n', ...
        m, absResp_active(mi), absResp_inactive(mi), numel(activeIdx), numel(inactiveIdx));
end

vm = isfinite(absResp_active) & isfinite(absResp_inactive);
if sum(vm) >= 3
    [pAI] = signrank(absResp_active(vm), absResp_inactive(vm));
    fprintf('\n  Summary: active |LW resp| = %.3f ± %.3f, inactive = %.3f ± %.3f\n', ...
        mean(absResp_active(vm)), std(absResp_active(vm))/sqrt(sum(vm)), ...
        mean(absResp_inactive(vm)), std(absResp_inactive(vm))/sqrt(sum(vm)));
    fprintf('  signrank p = %.4g (n=%d mice)\n', pAI, sum(vm));
end

%% 8) 新分析：AW→LW 信号保留与 ΔHit 的关系
fprintf('\n--- 8. 信号保留强度 vs ΔHit ---\n');
% 用每只鼠 AW→LW 相关系数 vs 该鼠平均 ΔHit
% 这个分析看信号保留是否预测学习速度

% 需要per-mouse的平均ΔHit
SessT = iLightWaterSessions_simple(DS_ALB);
SessT = iExcludeCeiling_simple(SessT);
SessT = iKeepPureLW_simple(DS_ALB, SessT);
SessT = sortrows(SessT, {'Mouse','DateTime'});

meanDeltaHit = nan(numel(mice), 1);
for mi = 1:numel(mice)
    m = mice(mi);
    R = SessT(SessT.Mouse == m, :);
    perf = double(R.Performance);
    if numel(perf) < 2, continue; end
    dh = diff(perf);
    meanDeltaHit(mi) = mean(dh, 'omitnan');
end

bothValid = isfinite(corrPerMouse) & isfinite(meanDeltaHit);
if sum(bothValid) >= 4
    [rho_ret_dh, p_ret_dh] = corr(corrPerMouse(bothValid), meanDeltaHit(bothValid), 'Type', 'Spearman');
    fprintf('  AW→LW retention ρ vs mean ΔHit: Spearman ρ=%.3f p=%.4g n=%d\n', ...
        rho_ret_dh, p_ret_dh, sum(bothValid));
else
    fprintf('  Too few mice for this analysis\n');
end

%% 9) 新分析：TH抑制对 AW→LW 信号保留的影响
fprintf('\n--- 9. TH inhibit: SD in early vs late LW sessions ---\n');
% TH组没有AW imaging，所以不能直接做信号保留分析
% 但可以看TH组的SD是否随学习进展变化与Ctrl不同
fprintf('  (TH组无AW成像数据，无法直接验证信号保留)\n');
fprintf('  TH抑制的因果证据依赖已有的 ΔHit 和 SD 组间比较\n');

fprintf('\n========== 验算完毕 ==========\n');

%% Local helper functions
function Sess = iLightWaterSessions_simple(DS)
Blocks = DS.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime); Blocks.DateTime.TimeZone = '';
DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime); DT.DateTime.TimeZone = '';
DT.Mouse = string(DT.Mouse);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", :);
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks(:,{'BlockUID','DateTime'}), 'Keys', 'BlockUID');
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perfSess = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
Sess = table(mouse, dt, perfSess, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iExcludeCeiling_simple(SessIn)
SessOut = SessIn;
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

function SessOut = iKeepPureLW_simple(DS, SessIn)
SessOut = SessIn;
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime); Blocks.DateTime.TimeZone = '';
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", :);
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end
