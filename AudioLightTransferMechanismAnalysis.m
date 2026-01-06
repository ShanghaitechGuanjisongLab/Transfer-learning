%% AudioLight Transfer 机制：Performance × (cue后1s内 MOp2/3 vs MOp5) + Learned→Transfer 细胞复用
% 说明：
% - 只分析 Phase=="Transfer" 且 Design=="LightWater" 的 block
% - cue后1s：默认使用 TransferLearning.Xs 定义时间轴（ResampledSignal 为 48 点）
% - 指标：
%   1) 每个 trial 的 population response（每层：对所有细胞平均）
%   2) 每个 block 内 MOp2/3 与 MOp5 trial-by-trial 相关（Spearman）
%   3) 每个 block 的两层平均响应幅度（跨 trial 平均）
% - 假设检验：
%   a) Performance 与以上三类指标的相关
%   b) 用简单线性模型预测 Performance（样本少，主要看方向/效应量）
% - 复用率：Learned AudioWater 中“强响应”细胞（top 20%）在 Transfer LightWater 的再激活比例/强度

% 确保项目/路径已加载（避免 UniExp.* 类找不到）
try
    if ~exist('UniExp.DataSet','class')
        thisFile = mfilename('fullpath');
        thisDir = fileparts(thisFile);
        projFile = fullfile(thisDir, 'Transferlearning.prj');
        if exist(projFile,'file')
            try
                matlab.project.loadProject(projFile);
            catch
                % ignore
            end
        end

        % 兜底：如果项目加载失败，尝试把 Unified-Experimental-Analysis-and-Figuring 加到 path
        if ~exist('UniExp.DataSet','class')
            matlabRoot = fileparts(thisDir); % ...\Documents\MATLAB
            ueaaf = fullfile(matlabRoot, 'Unified-Experimental-Analysis-and-Figuring');
            if exist(ueaaf,'dir')
                addpath(genpath(ueaaf));
            end
        end
    end
catch
    % ignore: 若仍失败，后续会在真正用到时抛错
end

TransferLearning.Clear;
AL = TransferLearning.AudioLightBaseline;

%% 0) 基础表与 block 选择
DT = AL.DateTimes;
B = AL.Blocks;
T = AL.Trials;
C = AL.Cells;

% 把 Mouse/Phase 挂到 Blocks
[tfDT, locDT] = ismember(B.DateTime, DT.DateTime);
Mouse = strings(height(B),1);
Phase = strings(height(B),1);
Mouse(tfDT) = string(DT.Mouse(locDT(tfDT)));
Phase(tfDT) = string(DT.Phase(locDT(tfDT)));
Mouse(~tfDT) = missing;
Phase(~tfDT) = missing;

Blocks = B(:, {'BlockUID','DateTime','Design','Performance','TiffPath'});
Blocks.Mouse = Mouse;
Blocks.Phase = Phase;
Blocks = sortrows(Blocks, {'Mouse','DateTime'});

isTransferLightWaterBlock = (Blocks.Phase=="Transfer") & (string(Blocks.Design)=="LightWater");
TLWBlocks = Blocks(isTransferLightWaterBlock,:);

if isempty(TLWBlocks)
    error("未找到 Phase==Transfer 且 Design==LightWater 的 blocks");
end

%% 1) 时间窗定义（cue后1s + baseline）
xs = TransferLearning.Xs; % duration(1x48)
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);

if nnz(baseMask) == 0
    error('baseline window -3~0s 在 TransferLearning.Xs 中没有覆盖到任何采样点');
end

%% 2) Transfer LightWater：trial-by-trial 两层协同 与 Performance
transferTrialMask = ismember(T.BlockUID, TLWBlocks.BlockUID) & (string(T.Stimulus)=="LightWater");
transferTrials = T(transferTrialMask, {'TrialUID','BlockUID','Stimulus'});

RespTransfer = iTrialCellResponses(AL, transferTrials.TrialUID, baseMask, winMask);
RespTransfer = innerjoin(RespTransfer, C(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
RespTransfer.ZKey = iZKey(RespTransfer.ZLayer);

% 每个 trial 每层：对细胞平均（population response）
[gTL, trialUID, zKey] = findgroups(RespTransfer.TrialUID, RespTransfer.ZKey);
trialLayerResp = table(trialUID, zKey, splitapply(@mean, RespTransfer.Resp, gTL), ...
    'VariableNames', {'TrialUID','ZKey','PopResp'});
trialLayerResp = innerjoin(trialLayerResp, transferTrials(:,{'TrialUID','BlockUID'}), 'Keys','TrialUID');

% pivot 成 TrialUID×BlockUID 一行，两列(MOp23/MOp5)
trialWide = unstack(trialLayerResp, "PopResp", "ZKey");

% 逐 block 计算：trial相关、均值响应
[gb, blockUID] = findgroups(trialWide.BlockUID);
blkCorr = splitapply(@(x23,x5) iSafeCorr(x23,x5), trialWide.MOp23, trialWide.MOp5, gb);
blkN = splitapply(@(x23,x5) sum(isfinite(x23) & isfinite(x5)), trialWide.MOp23, trialWide.MOp5, gb);
blkMean23 = splitapply(@(x) mean(x, 'omitnan'), trialWide.MOp23, gb);
blkMean5  = splitapply(@(x) mean(x, 'omitnan'), trialWide.MOp5, gb);

BlockSummary = table(blockUID, blkN, blkMean23, blkMean5, blkCorr, ...
    'VariableNames', {'BlockUID','NTrialsUsed','MeanResp_MOp23','MeanResp_MOp5','TrialCorr_Spearman'});
BlockSummary = innerjoin(BlockSummary, TLWBlocks(:,{'BlockUID','Mouse','DateTime','Performance','TiffPath'}), 'Keys','BlockUID');
BlockSummary = sortrows(BlockSummary, {'Mouse','DateTime'});

%% 3) 跨 block 统计：Performance × 指标
[statsPerf23] = iCorrReport(BlockSummary.Performance, BlockSummary.MeanResp_MOp23);
[statsPerf5]  = iCorrReport(BlockSummary.Performance, BlockSummary.MeanResp_MOp5);
[statsPerfC]  = iCorrReport(BlockSummary.Performance, BlockSummary.TrialCorr_Spearman);

fprintf("\n=== Transfer LightWater (n=%d blocks) ===\n", height(BlockSummary));
disp(BlockSummary(:,{'Mouse','BlockUID','DateTime','Performance','NTrialsUsed','MeanResp_MOp23','MeanResp_MOp5','TrialCorr_Spearman'}));

fprintf("\n[Spearman] Performance vs MeanResp_MOp23: rho=%.3f, p=%.4g (n=%d)\n", statsPerf23.rho, statsPerf23.p, statsPerf23.n);
fprintf("[Spearman] Performance vs MeanResp_MOp5 : rho=%.3f, p=%.4g (n=%d)\n", statsPerf5.rho,  statsPerf5.p,  statsPerf5.n);
fprintf("[Spearman] Performance vs TrialCorr     : rho=%.3f, p=%.4g (n=%d)\n", statsPerfC.rho,  statsPerfC.p,  statsPerfC.n);

% 简单线性回归（样本很少，主要给方向/效应量）
mdl = fitlm(BlockSummary, "Performance ~ MeanResp_MOp23 + MeanResp_MOp5 + TrialCorr_Spearman");
fprintf("\n=== Linear model: Performance ~ Resp23 + Resp5 + Corr ===\n");
disp(mdl);

%% 4) Learned→Transfer 细胞复用：以 Learned AudioWater 强响应细胞为基准
learnedBlockMask = (Blocks.Phase=="Learned") & (string(Blocks.Design)=="AudioWater");
LearnedBlocks = Blocks(learnedBlockMask,:);

learnedTrialMask = ismember(T.BlockUID, LearnedBlocks.BlockUID) & (string(T.Stimulus)=="AudioWater");
LearnedTrials = T(learnedTrialMask, {'TrialUID','BlockUID','Stimulus'});

RespLearned = iTrialCellResponses(AL, LearnedTrials.TrialUID, baseMask, winMask);
RespLearned = innerjoin(RespLearned, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
RespLearned.ZKey = iZKey(RespLearned.ZLayer);

% 每个 mouse × 层 × cell：跨 learned trials 平均
[glc, mL, zL, cL] = findgroups(string(RespLearned.Mouse), string(RespLearned.ZKey), RespLearned.CellUID);
cellLearned = table(mL, zL, cL, splitapply(@mean, RespLearned.Resp, glc), ...
    'VariableNames', {'Mouse','ZKey','CellUID','LearnedResp'});

% Transfer per-cell mean（同样跨 transfer trials 平均）
RespTransfer2 = innerjoin(RespTransfer(:,{'TrialUID','CellUID','Resp'}), transferTrials(:,{'TrialUID','BlockUID'}), 'Keys','TrialUID');
RespTransfer2 = innerjoin(RespTransfer2, TLWBlocks(:,{'BlockUID','Mouse','Performance'}), 'Keys','BlockUID');
RespTransfer2 = innerjoin(RespTransfer2, C(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
RespTransfer2.ZKey = iZKey(RespTransfer2.ZLayer);

[gtc, mT, zT, cT] = findgroups(string(RespTransfer2.Mouse), string(RespTransfer2.ZKey), RespTransfer2.CellUID);
cellTransfer = table(mT, zT, cT, splitapply(@mean, RespTransfer2.Resp, gtc), ...
    'VariableNames', {'Mouse','ZKey','CellUID','TransferResp'});

% 兼容/稳健性：innerjoin 要求键变量类型一致
cellLearned.Mouse = string(cellLearned.Mouse);
cellTransfer.Mouse = string(cellTransfer.Mouse);
cellLearned.ZKey = string(cellLearned.ZKey);
cellTransfer.ZKey = string(cellTransfer.ZKey);
cellLearned.CellUID = uint64(cellLearned.CellUID);
cellTransfer.CellUID = uint64(cellTransfer.CellUID);

% 合并 learned/transfer（以 CellUID + 层 对齐；只保留两边都有的细胞）
cellLT = innerjoin(cellLearned, cellTransfer, 'Keys', {'Mouse','ZKey','CellUID'});

% 逐 mouse × 层 计算复用率：LearnedTop20 在 Transfer 中再激活(>0) 的比例；以及 learned↔transfer 响应相关
mouseZ = unique(cellLT(:,{'Mouse','ZKey'}));
MouseLayerSummary = table('Size',[0 9], ...
    'VariableTypes', {'string','string','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_Top20_Positive','ReuseRate_Top20_Top20','ReuseCorr_Spearman','LearnedTop20Threshold','TransferTop20Threshold'});

for i = 1:height(mouseZ)
    m = string(mouseZ.Mouse(i));
    z = string(mouseZ.ZKey(i));
    rows = (string(cellLT.Mouse)==m) & (string(cellLT.ZKey)==z);
    L = cellLT.LearnedResp(rows);
    R = cellLT.TransferResp(rows);

    if numel(L) < 10
        continue;
    end

    thrL = quantile(L, 0.8);
    thrR = quantile(R, 0.8);

    learnedTop = (L >= thrL);
    transferPos = (R > 0);
    transferTop = (R >= thrR);

    reuse1 = mean(transferPos(learnedTop));
    reuse2 = mean(transferTop(learnedTop));
    cc = iSafeCorr(L, R);

    perf = unique(RespTransfer2.Performance(string(RespTransfer2.Mouse)==m));
    if isempty(perf)
        perf = NaN;
    else
        perf = perf(1);
    end

    MouseLayerSummary(end+1,:) = {m, z, perf, numel(L), reuse1, reuse2, cc, thrL, thrR}; %#ok<SAGROW>
end

MouseLayerSummary = sortrows(MouseLayerSummary, {'ZKey','TransferPerformance'}, {'ascend','descend'});

fprintf("\n=== Learned(AudioWater)→Transfer(LightWater) reuse (per mouse × layer) ===\n");
disp(MouseLayerSummary(:,{'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_Top20_Positive','ReuseRate_Top20_Top20','ReuseCorr_Spearman'}));

% 分层：复用率/复用相关性 与 Transfer performance 的关系
rows23 = MouseLayerSummary.ZKey=="MOp23";
rows5  = MouseLayerSummary.ZKey=="MOp5";

rReuse1_23 = iCorrReport(MouseLayerSummary.TransferPerformance(rows23), MouseLayerSummary.ReuseRate_Top20_Positive(rows23));
rReuse2_23 = iCorrReport(MouseLayerSummary.TransferPerformance(rows23), MouseLayerSummary.ReuseRate_Top20_Top20(rows23));
rReuseC_23 = iCorrReport(MouseLayerSummary.TransferPerformance(rows23), MouseLayerSummary.ReuseCorr_Spearman(rows23));

rReuse1_5 = iCorrReport(MouseLayerSummary.TransferPerformance(rows5), MouseLayerSummary.ReuseRate_Top20_Positive(rows5));
rReuse2_5 = iCorrReport(MouseLayerSummary.TransferPerformance(rows5), MouseLayerSummary.ReuseRate_Top20_Top20(rows5));
rReuseC_5 = iCorrReport(MouseLayerSummary.TransferPerformance(rows5), MouseLayerSummary.ReuseCorr_Spearman(rows5));

fprintf("\n[MOp2/3 Spearman] Perf vs ReuseRate(Top20→Pos)  : rho=%.3f, p=%.4g (n=%d)\n", rReuse1_23.rho, rReuse1_23.p, rReuse1_23.n);
fprintf("[MOp2/3 Spearman] Perf vs ReuseRate(Top20→Top20): rho=%.3f, p=%.4g (n=%d)\n", rReuse2_23.rho, rReuse2_23.p, rReuse2_23.n);
fprintf("[MOp2/3 Spearman] Perf vs ReuseCorr(L vs T)     : rho=%.3f, p=%.4g (n=%d)\n", rReuseC_23.rho, rReuseC_23.p, rReuseC_23.n);

fprintf("\n[MOp5  Spearman] Perf vs ReuseRate(Top20→Pos)  : rho=%.3f, p=%.4g (n=%d)\n", rReuse1_5.rho, rReuse1_5.p, rReuse1_5.n);
fprintf("[MOp5  Spearman] Perf vs ReuseRate(Top20→Top20): rho=%.3f, p=%.4g (n=%d)\n", rReuse2_5.rho, rReuse2_5.p, rReuse2_5.n);
fprintf("[MOp5  Spearman] Perf vs ReuseCorr(L vs T)     : rho=%.3f, p=%.4g (n=%d)\n", rReuseC_5.rho, rReuseC_5.p, rReuseC_5.n);

%% 4b) 复用（阈值法）：win(0~1s) max > baseline mean + 3*baseline std 视为“活跃”
% cell×trial 的二值判定；随后对每个 cell 计算活跃率（active trials fraction）
kSigma = 3;

ActLearned = iTrialCellActive(AL, LearnedTrials.TrialUID, baseMask, winMask, kSigma);
ActLearned = innerjoin(ActLearned, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
ActLearned.ZKey = iZKey(ActLearned.ZLayer);

ActTransfer = iTrialCellActive(AL, transferTrials.TrialUID, baseMask, winMask, kSigma);
ActTransfer = innerjoin(ActTransfer, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
ActTransfer.ZKey = iZKey(ActTransfer.ZLayer);

% per cell：活跃率
[gLA, mLA, zLA, cLA] = findgroups(string(ActLearned.Mouse), string(ActLearned.ZKey), uint64(ActLearned.CellUID));
cellLearnedAct = table(mLA, zLA, cLA, splitapply(@mean, double(ActLearned.Active), gLA), ...
    'VariableNames', {'Mouse','ZKey','CellUID','LearnedActRate'});

[gTA, mTA, zTA, cTA] = findgroups(string(ActTransfer.Mouse), string(ActTransfer.ZKey), uint64(ActTransfer.CellUID));
cellTransferAct = table(mTA, zTA, cTA, splitapply(@mean, double(ActTransfer.Active), gTA), ...
    'VariableNames', {'Mouse','ZKey','CellUID','TransferActRate'});

cellLearnedAct.Mouse = string(cellLearnedAct.Mouse);
cellTransferAct.Mouse = string(cellTransferAct.Mouse);
cellLearnedAct.ZKey = string(cellLearnedAct.ZKey);
cellTransferAct.ZKey = string(cellTransferAct.ZKey);
cellLearnedAct.CellUID = uint64(cellLearnedAct.CellUID);
cellTransferAct.CellUID = uint64(cellTransferAct.CellUID);

cellActLT = innerjoin(cellLearnedAct, cellTransferAct, 'Keys', {'Mouse','ZKey','CellUID'});

% learned 的均值响应 top20%（与上面一致）定义“Learned 强响应细胞集合”
cellLearned.Mouse = string(cellLearned.Mouse);
cellLearned.ZKey = string(cellLearned.ZKey);
cellLearned.CellUID = uint64(cellLearned.CellUID);

mouseZ2 = unique(cellActLT(:,{'Mouse','ZKey'}));
MouseLayerActivitySummary = table('Size',[0 7], ...
    'VariableTypes', {'string','string','double','double','double','double','double'}, ...
    'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_Top20_ActiveAny','ReuseRate_Top20_ActiveTop20','ReuseCorr_ActRate'});

for i = 1:height(mouseZ2)
    m = string(mouseZ2.Mouse(i));
    z = string(mouseZ2.ZKey(i));

    rowsAct = (string(cellActLT.Mouse)==m) & (string(cellActLT.ZKey)==z);
    if ~any(rowsAct)
        continue;
    end
    LA = cellActLT.LearnedActRate(rowsAct);
    TA = cellActLT.TransferActRate(rowsAct);

    rowsResp = (string(cellLearned.Mouse)==m) & (string(cellLearned.ZKey)==z);
    if ~any(rowsResp)
        continue;
    end
    Lresp = cellLearned.LearnedResp(rowsResp);
    cidResp = uint64(cellLearned.CellUID(rowsResp));
    thrLresp = quantile(Lresp, 0.8);
    learnedTopCID = cidResp(Lresp >= thrLresp);

    cidAct = uint64(cellActLT.CellUID(rowsAct));
    isLearnedTop = ismember(cidAct, learnedTopCID);
    if nnz(isLearnedTop) < 5
        continue;
    end

    transferAny = (TA > 0);
    thrTA = quantile(TA, 0.8);
    transferTop = (TA >= thrTA);

    reuseAny = mean(double(transferAny(isLearnedTop)));
    reuseTop = mean(double(transferTop(isLearnedTop)));
    ccAct = iSafeCorr(LA, TA);

    perf = unique(RespTransfer2.Performance(string(RespTransfer2.Mouse)==m));
    if isempty(perf)
        perf = NaN;
    else
        perf = perf(1);
    end

    MouseLayerActivitySummary(end+1,:) = {m, z, perf, numel(cidAct), reuseAny, reuseTop, ccAct}; %#ok<SAGROW>
end

MouseLayerActivitySummary = sortrows(MouseLayerActivitySummary, {'ZKey','TransferPerformance'}, {'ascend','descend'});

fprintf("\n=== Activity-threshold reuse (per mouse × layer): max(0~1s) > mean(base)+%g*std(base) ===\n", kSigma);
disp(MouseLayerActivitySummary(:,{'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_Top20_ActiveAny','ReuseRate_Top20_ActiveTop20','ReuseCorr_ActRate'}));

rows23A = MouseLayerActivitySummary.ZKey=="MOp23";
rows5A  = MouseLayerActivitySummary.ZKey=="MOp5";

rActAny_23  = iCorrReport(MouseLayerActivitySummary.TransferPerformance(rows23A), MouseLayerActivitySummary.ReuseRate_Top20_ActiveAny(rows23A));
rActTop_23  = iCorrReport(MouseLayerActivitySummary.TransferPerformance(rows23A), MouseLayerActivitySummary.ReuseRate_Top20_ActiveTop20(rows23A));
rActCorr_23 = iCorrReport(MouseLayerActivitySummary.TransferPerformance(rows23A), MouseLayerActivitySummary.ReuseCorr_ActRate(rows23A));

rActAny_5  = iCorrReport(MouseLayerActivitySummary.TransferPerformance(rows5A), MouseLayerActivitySummary.ReuseRate_Top20_ActiveAny(rows5A));
rActTop_5  = iCorrReport(MouseLayerActivitySummary.TransferPerformance(rows5A), MouseLayerActivitySummary.ReuseRate_Top20_ActiveTop20(rows5A));
rActCorr_5 = iCorrReport(MouseLayerActivitySummary.TransferPerformance(rows5A), MouseLayerActivitySummary.ReuseCorr_ActRate(rows5A));

fprintf("\n[MOp2/3 Activity Spearman] Perf vs ReuseAny(active>0) : rho=%.3f, p=%.4g (n=%d)\n", rActAny_23.rho, rActAny_23.p, rActAny_23.n);
fprintf("[MOp2/3 Activity Spearman] Perf vs ReuseTop20(actRate): rho=%.3f, p=%.4g (n=%d)\n", rActTop_23.rho, rActTop_23.p, rActTop_23.n);
fprintf("[MOp2/3 Activity Spearman] Perf vs ActRateCorr(L,T)  : rho=%.3f, p=%.4g (n=%d)\n", rActCorr_23.rho, rActCorr_23.p, rActCorr_23.n);

fprintf("\n[MOp5  Activity Spearman] Perf vs ReuseAny(active>0) : rho=%.3f, p=%.4g (n=%d)\n", rActAny_5.rho, rActAny_5.p, rActAny_5.n);
fprintf("[MOp5  Activity Spearman] Perf vs ReuseTop20(actRate): rho=%.3f, p=%.4g (n=%d)\n", rActTop_5.rho, rActTop_5.p, rActTop_5.n);
fprintf("[MOp5  Activity Spearman] Perf vs ActRateCorr(L,T)  : rho=%.3f, p=%.4g (n=%d)\n", rActCorr_5.rho, rActCorr_5.p, rActCorr_5.n);

%% 4c) 复用（QueryNTATS 中位数轨迹阈值法）：先对所有回合取中位数，再判定 max(0~1s) > mean(base)+k*std(base)
% 说明：
% - 这里“所有回合的中位数”由 AL.QueryNTATS(..., UniExp.Flags.Median) 完成
% - Learned 也可使用同样阈值法定义“LearnedActive”（与 Transfer 同口径）
try
    GLearn = AL.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.dFdF0, 1:30, UniExp.Flags.Median);
    GTran  = AL.QueryNTATS(struct('Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.dFdF0, 1:30, UniExp.Flags.Median);

    XLearn = iNtatsData(GLearn.NTATS); % nCell x nTime
    XTran  = iNtatsData(GTran.NTATS);

    % Learned：同口径阈值法（基于中位数轨迹）
    learnedBaseMu = mean(XLearn(:, baseMask), 2);
    learnedBaseSd = std(XLearn(:, baseMask), 0, 2);
    learnedWinMx  = max(XLearn(:, winMask), [], 2);
    learnedActiveMed = learnedWinMx > (learnedBaseMu + kSigma .* learnedBaseSd);

    tranBaseMu = mean(XTran(:, baseMask), 2);
    tranBaseSd = std(XTran(:, baseMask), 0, 2);
    tranWinMx  = max(XTran(:, winMask), [], 2);
    tranActiveMed = tranWinMx > (tranBaseMu + kSigma .* tranBaseSd);

    learnedCell = table(uint64(GLearn.CellUID), double(learnedActiveMed), 'VariableNames', {'CellUID','LearnedActiveMed'});
    transferCell = table(uint64(GTran.CellUID), double(tranActiveMed), 'VariableNames', {'CellUID','TransferActiveMed'});

    learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
    transferCell = innerjoin(transferCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
    learnedCell.ZKey = iZKey(learnedCell.ZLayer);
    transferCell.ZKey = iZKey(transferCell.ZLayer);

    learnedCell.Mouse = string(learnedCell.Mouse);
    transferCell.Mouse = string(transferCell.Mouse);
    learnedCell.ZKey = string(learnedCell.ZKey);
    transferCell.ZKey = string(transferCell.ZKey);

    medLT = innerjoin(learnedCell(:,{'Mouse','ZKey','CellUID','LearnedActiveMed'}), ...
        transferCell(:,{'Mouse','ZKey','CellUID','TransferActiveMed'}), 'Keys', {'Mouse','ZKey','CellUID'});

    mouseZ3 = unique(medLT(:,{'Mouse','ZKey'}));
    MouseLayerMedianActivitySummary = table('Size',[0 7], ...
        'VariableTypes', {'string','string','double','double','double','double','double'}, ...
        'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','LearnedMedianActiveRate','ReuseRate_LearnedMedianActive','TransferMedianActiveRate'});

    for i = 1:height(mouseZ3)
        m = string(mouseZ3.Mouse(i));
        z = string(mouseZ3.ZKey(i));
        rows = (string(medLT.Mouse)==m) & (string(medLT.ZKey)==z);
        if nnz(rows) < 10
            continue;
        end
        LA = logical(medLT.LearnedActiveMed(rows));
        Ta = logical(medLT.TransferActiveMed(rows));

        if nnz(LA) < 5
            continue;
        end

        reuse = mean(double(Ta(LA)));
        learnedActRate = mean(double(LA));
        actRate = mean(double(Ta));

        perf = unique(RespTransfer2.Performance(string(RespTransfer2.Mouse)==m));
        if isempty(perf)
            perf = NaN;
        else
            perf = perf(1);
        end

        MouseLayerMedianActivitySummary(end+1,:) = {m, z, perf, nnz(rows), learnedActRate, reuse, actRate}; %#ok<SAGROW>
    end

    MouseLayerMedianActivitySummary = sortrows(MouseLayerMedianActivitySummary, {'ZKey','TransferPerformance'}, {'ascend','descend'});

    fprintf("\n=== Median-NTATS activity reuse (per mouse × layer) ===\n");
    disp(MouseLayerMedianActivitySummary(:,{'Mouse','ZKey','TransferPerformance','NCells','LearnedMedianActiveRate','ReuseRate_LearnedMedianActive','TransferMedianActiveRate'}));

    rows23M = MouseLayerMedianActivitySummary.ZKey=="MOp23";
    rows5M  = MouseLayerMedianActivitySummary.ZKey=="MOp5";
    rMed_23 = iCorrReport(MouseLayerMedianActivitySummary.TransferPerformance(rows23M), MouseLayerMedianActivitySummary.ReuseRate_LearnedMedianActive(rows23M));
    rMed_5  = iCorrReport(MouseLayerMedianActivitySummary.TransferPerformance(rows5M),  MouseLayerMedianActivitySummary.ReuseRate_LearnedMedianActive(rows5M));

    fprintf("\n[MOp2/3 MedianNTATS Spearman] Perf vs Reuse(LearnedMedianActive→TransferMedianActive): rho=%.3f, p=%.4g (n=%d)\n", rMed_23.rho, rMed_23.p, rMed_23.n);
    fprintf("[MOp5  MedianNTATS Spearman] Perf vs Reuse(LearnedMedianActive→TransferMedianActive): rho=%.3f, p=%.4g (n=%d)\n", rMed_5.rho,  rMed_5.p,  rMed_5.n);
catch ME
    warning('QueryNTATS 中位数阈值法失败：%s', ME.message);
    MouseLayerMedianActivitySummary = table();
    rMed_23 = struct('rho',NaN,'p',NaN,'n',0);
    rMed_5  = struct('rho',NaN,'p',NaN,'n',0);
end

%% 5) 作图：Transfer performance vs 复用指标（按 mouse × layer）
try
    f = figure('Name','AudioLight Reuse vs Performance (by layer)'); %#ok<NASGU>
    tl = tiledlayout(2,3,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>
    sgtitle(sprintf('Learned(AudioWater)→Transfer(LightWater) reuse vs performance by layer (baseline -3~0s)'));

    % Row 1: MOp2/3
    y = MouseLayerSummary.TransferPerformance(rows23);
    miceLbl = MouseLayerSummary.Mouse(rows23);

    nexttile;
    x = MouseLayerSummary.ReuseRate_Top20_Positive(rows23);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseRate: Top20 → Resp>0');
    ylabel('Perf');
    title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', rReuse1_23.rho, rReuse1_23.p, rReuse1_23.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerSummary.ReuseRate_Top20_Top20(rows23);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseRate: Top20 → Top20');
    ylabel('Perf');
    title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', rReuse2_23.rho, rReuse2_23.p, rReuse2_23.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerSummary.ReuseCorr_Spearman(rows23);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseCorr: Spearman(L,R)');
    ylabel('Perf');
    title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', rReuseC_23.rho, rReuseC_23.p, rReuseC_23.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    % Row 2: MOp5
    y = MouseLayerSummary.TransferPerformance(rows5);
    miceLbl = MouseLayerSummary.Mouse(rows5);

    nexttile;
    x = MouseLayerSummary.ReuseRate_Top20_Positive(rows5);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseRate: Top20 → Resp>0');
    ylabel('Perf');
    title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', rReuse1_5.rho, rReuse1_5.p, rReuse1_5.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerSummary.ReuseRate_Top20_Top20(rows5);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseRate: Top20 → Top20');
    ylabel('Perf');
    title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', rReuse2_5.rho, rReuse2_5.p, rReuse2_5.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerSummary.ReuseCorr_Spearman(rows5);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseCorr: Spearman(L,R)');
    ylabel('Perf');
    title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', rReuseC_5.rho, rReuseC_5.p, rReuseC_5.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;
catch ME
    warning('作图失败：%s', ME.message);
end

%% 5b) 作图：阈值法活跃复用（按 layer）
try
    f2 = figure('Name','AudioLight Activity-threshold reuse vs Performance (by layer)'); %#ok<NASGU>
    tl2 = tiledlayout(2,3,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>
    sgtitle(sprintf('Activity threshold: max(0~1s)>mean(base)+%g*std(base)', kSigma));

    % Row 1: MOp2/3
    y = MouseLayerActivitySummary.TransferPerformance(rows23A);
    miceLbl = MouseLayerActivitySummary.Mouse(rows23A);

    nexttile;
    x = MouseLayerActivitySummary.ReuseRate_Top20_ActiveAny(rows23A);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseAny: LearnedTop20 → (TransferActRate>0)');
    ylabel('Perf');
    title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', rActAny_23.rho, rActAny_23.p, rActAny_23.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerActivitySummary.ReuseRate_Top20_ActiveTop20(rows23A);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseTop20: LearnedTop20 → TransferActRateTop20');
    ylabel('Perf');
    title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', rActTop_23.rho, rActTop_23.p, rActTop_23.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerActivitySummary.ReuseCorr_ActRate(rows23A);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ActRateCorr: Spearman(LearnedActRate, TransferActRate)');
    ylabel('Perf');
    title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', rActCorr_23.rho, rActCorr_23.p, rActCorr_23.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    % Row 2: MOp5
    y = MouseLayerActivitySummary.TransferPerformance(rows5A);
    miceLbl = MouseLayerActivitySummary.Mouse(rows5A);

    nexttile;
    x = MouseLayerActivitySummary.ReuseRate_Top20_ActiveAny(rows5A);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseAny: LearnedTop20 → (TransferActRate>0)');
    ylabel('Perf');
    title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', rActAny_5.rho, rActAny_5.p, rActAny_5.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerActivitySummary.ReuseRate_Top20_ActiveTop20(rows5A);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseTop20: LearnedTop20 → TransferActRateTop20');
    ylabel('Perf');
    title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', rActTop_5.rho, rActTop_5.p, rActTop_5.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

    nexttile;
    x = MouseLayerActivitySummary.ReuseCorr_ActRate(rows5A);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ActRateCorr: Spearman(LearnedActRate, TransferActRate)');
    ylabel('Perf');
    title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', rActCorr_5.rho, rActCorr_5.p, rActCorr_5.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;
catch ME
    warning('阈值法作图失败：%s', ME.message);
end

%% 5c) 作图：QueryNTATS 中位数阈值法（按 layer）
try
    if exist('MouseLayerMedianActivitySummary','var') && ~isempty(MouseLayerMedianActivitySummary)
        rows23M = MouseLayerMedianActivitySummary.ZKey=="MOp23";
        rows5M  = MouseLayerMedianActivitySummary.ZKey=="MOp5";

        rMed_23 = iCorrReport(MouseLayerMedianActivitySummary.TransferPerformance(rows23M), MouseLayerMedianActivitySummary.ReuseRate_LearnedMedianActive(rows23M));
        rMed_5  = iCorrReport(MouseLayerMedianActivitySummary.TransferPerformance(rows5M),  MouseLayerMedianActivitySummary.ReuseRate_LearnedMedianActive(rows5M));

        f3 = figure('Name','AudioLight Median-NTATS threshold reuse vs Performance (by layer)'); %#ok<NASGU>
        tl3 = tiledlayout(2,1,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>
        sgtitle(sprintf('Median NTATS threshold: max(0~1s)>mean(base)+%g*std(base)', kSigma));

        nexttile;
        x = MouseLayerMedianActivitySummary.ReuseRate_LearnedMedianActive(rows23M);
        y = MouseLayerMedianActivitySummary.TransferPerformance(rows23M);
        miceLbl = MouseLayerMedianActivitySummary.Mouse(rows23M);
        scatter(x, y, 50, 'filled');
        grid on; box off;
        xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
        ylabel('Perf');
        title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', rMed_23.rho, rMed_23.p, rMed_23.n));
        hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

        nexttile;
        x = MouseLayerMedianActivitySummary.ReuseRate_LearnedMedianActive(rows5M);
        y = MouseLayerMedianActivitySummary.TransferPerformance(rows5M);
        miceLbl = MouseLayerMedianActivitySummary.Mouse(rows5M);
        scatter(x, y, 50, 'filled');
        grid on; box off;
        xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
        ylabel('Perf');
        title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', rMed_5.rho, rMed_5.p, rMed_5.n));
        hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;
    end
catch ME
    warning('中位数阈值法作图失败：%s', ME.message);
end

%% 输出变量（方便你后续画图/做更复杂模型）
assignin('base','AudioLight_BlockSummary',BlockSummary);
assignin('base','AudioLight_MouseLayerSummary',MouseLayerSummary);
assignin('base','AudioLight_MouseLayerActivitySummary',MouseLayerActivitySummary);
if exist('MouseLayerMedianActivitySummary','var')
    assignin('base','AudioLight_MouseLayerMedianActivitySummary',MouseLayerMedianActivitySummary);
end

%% -------- local functions --------
function Resp = iTrialCellResponses(AL, trialUIDs, baseMask, winMask)
Ts = AL.TrialSignals;
sel = ismember(Ts.TrialUID, trialUIDs);

sig = Ts.ResampledSignal(sel, :);
base = mean(sig(:, baseMask), 2);
win = mean(sig(:, winMask), 2);
resp = win - base;

Resp = table(Ts.TrialUID(sel), Ts.CellUID(sel), resp, ...
    'VariableNames', {'TrialUID','CellUID','Resp'});
end

function Act = iTrialCellActive(AL, trialUIDs, baseMask, winMask, kSigma)
Ts = AL.TrialSignals;
sel = ismember(Ts.TrialUID, trialUIDs);

sig = Ts.ResampledSignal(sel, :);
baseMu = mean(sig(:, baseMask), 2);
baseSd = std(sig(:, baseMask), 0, 2);
winMx = max(sig(:, winMask), [], 2);

act = winMx > (baseMu + kSigma .* baseSd);
Act = table(Ts.TrialUID(sel), Ts.CellUID(sel), act, ...
    'VariableNames', {'TrialUID','CellUID','Active'});
end

function zKey = iZKey(zLayer)
zl = string(zLayer);
zKey = strings(size(zl));
zKey(zl=="MOp2/3") = "MOp23";
zKey(zl=="MOp5") = "MOp5";
end

function rho = iSafeCorr(x, y)
% Spearman 相关；若有效点太少或常数向量，返回 NaN
x = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask); y = y(mask);
if numel(x) < 4
    rho = NaN;
    return;
end
if std(x)==0 || std(y)==0
    rho = NaN;
    return;
end
rho = corr(x, y, 'type','Spearman');
end

function out = iCorrReport(x, y)
% Spearman + p 值
x = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask); y = y(mask);
out = struct('rho', NaN, 'p', NaN, 'n', numel(x));
if numel(x) < 4
    return;
end
if std(x)==0 || std(y)==0
    return;
end
[r,p] = corr(x, y, 'type','Spearman');
out.rho = r;
out.p = p;
end

function X = iNtatsData(NT)
% 兼容 MATLAB.DataTypes.NDTable 与普通数值矩阵
if isa(NT, 'MATLAB.DataTypes.NDTable')
    X = NT.Data;
else
    X = NT;
end
end
