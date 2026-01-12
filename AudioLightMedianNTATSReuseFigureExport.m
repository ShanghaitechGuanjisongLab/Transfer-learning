%% AudioLight Median-NTATS 阈值复用图（最简版）
% 目标：生成“LearnedMedianActive → TransferMedianActive 的复用率 vs Transfer Performance”
% 并导出 SVG 到：\\Data-Server-2\个人数据\张天夫\202601

%% --- Run config（避免每次改一点就全量重跑）
% 你可以在 base 里提前设：AudioLightReuseExportCfg = struct(...);
% 例如：AudioLightReuseExportCfg = struct('RecomputeCtrl',false,'ExportHitMiss',false);

defaultCfg = struct(...
    'RecomputeCtrl', true, ...          % 重新 QueryNTATS + 计算 Ctrl Summary
    'RecomputeOverlays', true, ...      % 重新计算 scFLARE/Vacation7/THInhibit summary
    'ExportAllOverlayScatter', true, ...% 导出“全叠加散点图”（Ctrl + 所有 overlay）
    'ExportCtrlOnlyAnd3Compare', true, ... % 导出 Ctrl-only 与 3 张 Ctrl-vs-单组散点图
    'ExportReverse', true, ...
    'ExportHitMiss', true, ...
    'ExportHeatmap', true);

cfg = defaultCfg;
try
    if evalin('base', "exist('AudioLightReuseExportCfg','var')")
        userCfg = evalin('base', 'AudioLightReuseExportCfg');
        if isstruct(userCfg)
            cfg = iMergeStruct(defaultCfg, userCfg);
        end
    end
catch
end

% --- 0) 兜底：确保项目/路径已加载（避免 UniExp.* 类找不到）
try
    if ~exist('UniExp.DataSet','class')
        thisFile = mfilename('fullpath');
        thisDir = fileparts(thisFile);
        projFile = fullfile(thisDir, 'Transferlearning.prj');
        if exist(projFile,'file')
            try
                matlab.project.loadProject(projFile);
            catch
            end
        end
        if ~exist('UniExp.DataSet','class')
            matlabRoot = fileparts(thisDir); % ...\Documents\MATLAB
            ueaaf = fullfile(matlabRoot, 'Unified-Experimental-Analysis-and-Figuring');
            if exist(ueaaf,'dir')
                addpath(genpath(ueaaf));
            end
        end
    end
catch
end

% 重大性能点：不要每次都 TransferLearning.Clear。
% Clear 会清掉 memoized cache，导致 DataSet 每次都从文件重新加载。
% 这里优先复用 base 工作区里已存在的 DataSet 对象。
if evalin('base', "exist('AudioLightBaselineDS','var')")
    AL = evalin('base', 'AudioLightBaselineDS');
else
    AL = TransferLearning.AudioLightBaseline;
    assignin('base', 'AudioLightBaselineDS', AL);
end

% --- 1) 时间窗与阈值
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);
kSigma = 3;

% 若不重算，优先从 base 读取（加速调图）
haveCtrlSummary = false;
try
    haveCtrlSummary = evalin('base', "exist('AudioLight_MedianNTATSReuse_Summary','var')") ~= 0;
catch
end

if cfg.RecomputeCtrl || ~haveCtrlSummary
    % --- 2) 取 Learned/Transfer 的“所有回合中位数”轨迹（每 cell 一条 48 点）
    % 注意：不要用 dFdF0（当 F0 可能为负时会崩）；统一用 z-score。
    GLearn = AL.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
    GTran  = AL.QueryNTATS(struct('Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

    XLearn = iNtatsData(GLearn.NTATS);
    XTran  = iNtatsData(GTran.NTATS);

% Transfer：按行为拆分（Behavior=1 命中，Behavior=0 错失）
% 注意：AL.QueryNTATS(struct(...,'Behavior',1)) 会触发 Empty_group；
% 这里用 QueryTable 方式一次性查询 Hit/Miss 两组。
QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), {1;0}, 'VariableNames', {'GroupName','Phase','Stimulus','Behavior'});
try
    GTranHM = AL.QueryNTATS(QT_HM, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
catch ME
    if ME.identifier == "UniExp:Exception:Empty_group"
        warning(ME.identifier, 'QueryNTATS Hit/Miss 为空：%s', ME.message);
        GTranHM = [];
    else
        rethrow(ME);
    end
end

XTranHit = nan(size(XTran));
XTranMiss = nan(size(XTran));
cellUIDTranHM = uint64([]);
if ~isempty(GTranHM) && height(GTranHM) > 0
    XTranHM = iNtatsData(GTranHM.NTATS);
    if ndims(XTranHM) ~= 3 || size(XTranHM,3) < 2
        error('Unexpected NTATS dimension for Hit/Miss QueryTable result.');
    end
    XTranHit = XTranHM(:,:,1);
    XTranMiss = XTranHM(:,:,2);
    cellUIDTranHM = uint64(GTranHM.CellUID);
end

% Learned：中位数轨迹阈值活跃
learnedBaseMu = mean(XLearn(:, baseMask), 2, 'omitnan');
learnedBaseSd = std(XLearn(:, baseMask), 0, 2, 'omitnan');
learnedWinMx  = max(XLearn(:, winMask), [], 2, 'omitnan');
learnedActiveMed = learnedWinMx > (learnedBaseMu + kSigma .* learnedBaseSd);

% Transfer：中位数轨迹阈值活跃
tranBaseMu = mean(XTran(:, baseMask), 2, 'omitnan');
tranBaseSd = std(XTran(:, baseMask), 0, 2, 'omitnan');
tranWinMx  = max(XTran(:, winMask), [], 2, 'omitnan');
tranActiveMed = tranWinMx > (tranBaseMu + kSigma .* tranBaseSd);

% Transfer Hit：中位数轨迹阈值活跃
tranHitBaseMu = mean(XTranHit(:, baseMask), 2, 'omitnan');
tranHitBaseSd = std(XTranHit(:, baseMask), 0, 2, 'omitnan');
tranHitWinMx  = max(XTranHit(:, winMask), [], 2, 'omitnan');
tranActiveMedHit = tranHitWinMx > (tranHitBaseMu + kSigma .* tranHitBaseSd);

% Transfer Miss：中位数轨迹阈值活跃
tranMissBaseMu = mean(XTranMiss(:, baseMask), 2, 'omitnan');
tranMissBaseSd = std(XTranMiss(:, baseMask), 0, 2, 'omitnan');
tranMissWinMx  = max(XTranMiss(:, winMask), [], 2, 'omitnan');
tranActiveMedMiss = tranMissWinMx > (tranMissBaseMu + kSigma .* tranMissBaseSd);

    % --- 3) 组装 per mouse × layer 的复用率，并关联 Transfer performance
    C = AL.Cells;

% Performance：统一用 UniExp.DataSet.TableQuery（这里直接用 DataSet 对象的 TableQuery 方法）
PerfT = AL.TableQuery(["Mouse","Performance"], Design="LightWater", Phase="Transfer");
PerfT.Mouse = string(PerfT.Mouse);
[gM, mKeys] = findgroups(PerfT.Mouse);
perfByMouse = table(mKeys, splitapply(@(p) mean(p, 'omitnan'), PerfT.Performance, gM), ...
    'VariableNames', {'Mouse','TransferPerformance'});

learnedCell = table(uint64(GLearn.CellUID), double(learnedActiveMed), 'VariableNames', {'CellUID','LearnedActiveMed'});
transferCell = table(uint64(GTran.CellUID), double(tranActiveMed), 'VariableNames', {'CellUID','TransferActiveMed'});

transferCellHit = table(cellUIDTranHM, double(tranActiveMedHit), 'VariableNames', {'CellUID','TransferActiveMedHit'});
transferCellMiss = table(cellUIDTranHM, double(tranActiveMedMiss), 'VariableNames', {'CellUID','TransferActiveMedMiss'});

learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
transferCell = innerjoin(transferCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');

if ~isempty(transferCellHit)
    transferCellHit = innerjoin(transferCellHit, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
end
if ~isempty(transferCellMiss)
    transferCellMiss = innerjoin(transferCellMiss, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
end

learnedCell.ZKey = iZKey(learnedCell.ZLayer);
transferCell.ZKey = iZKey(transferCell.ZLayer);

transferCellHit.ZKey = iZKey(transferCellHit.ZLayer);
transferCellMiss.ZKey = iZKey(transferCellMiss.ZLayer);

learnedCell.Mouse = string(learnedCell.Mouse);
transferCell.Mouse = string(transferCell.Mouse);
learnedCell.ZKey = string(learnedCell.ZKey);
transferCell.ZKey = string(transferCell.ZKey);

transferCellHit.Mouse = string(transferCellHit.Mouse);
transferCellMiss.Mouse = string(transferCellMiss.Mouse);
transferCellHit.ZKey = string(transferCellHit.ZKey);
transferCellMiss.ZKey = string(transferCellMiss.ZKey);

medLT = innerjoin(learnedCell(:,{'Mouse','ZKey','CellUID','LearnedActiveMed'}), ...
    transferCell(:,{'Mouse','ZKey','CellUID','TransferActiveMed'}), 'Keys', {'Mouse','ZKey','CellUID'});

medLT = outerjoin(medLT, transferCellHit(:,{'Mouse','ZKey','CellUID','TransferActiveMedHit'}), ...
    'Keys', {'Mouse','ZKey','CellUID'}, 'MergeKeys', true, 'Type', 'left');
medLT = outerjoin(medLT, transferCellMiss(:,{'Mouse','ZKey','CellUID','TransferActiveMedMiss'}), ...
    'Keys', {'Mouse','ZKey','CellUID'}, 'MergeKeys', true, 'Type', 'left');

mouseZ = unique(medLT(:,{'Mouse','ZKey'}));
maxRows = height(mouseZ);
sumMouse = strings(maxRows,1);
sumZKey = strings(maxRows,1);
sumPerf = nan(maxRows,1);
sumNCells = nan(maxRows,1);
sumLearnedRate = nan(maxRows,1);
sumReuse = nan(maxRows,1);
sumTransferRate = nan(maxRows,1);
sumReuseRev = nan(maxRows,1);
sumReuseHit = nan(maxRows,1);
sumReuseMiss = nan(maxRows,1);
sumReuseRevHit = nan(maxRows,1);
sumReuseRevMiss = nan(maxRows,1);
rowN = 0;

for i = 1:height(mouseZ)
    m = string(mouseZ.Mouse(i));
    z = string(mouseZ.ZKey(i));
    rows = (string(medLT.Mouse)==m) & (string(medLT.ZKey)==z);
    if nnz(rows) < 10
        continue;
    end

    LA = logical(medLT.LearnedActiveMed(rows));
    TA = logical(medLT.TransferActiveMed(rows));

    learnedRate = mean(double(LA));
    transferRate = mean(double(TA));

    % 复用率（正向）：在 Learned 中活跃的细胞，有多少在 Transfer 中也活跃
    reuse = NaN;
    if nnz(LA) >= 5
        reuse = mean(double(TA(LA)));
    end

    % 复用率（反向）：在 Transfer 中活跃的细胞，有多少在 Learned 中也活跃
    reuseRev = NaN;
    if nnz(TA) >= 5
        reuseRev = mean(double(LA(TA)));
    end

    % 复用率（按行为拆分，正向）：Hit/Miss 回合下的 TransferActive
    reuseHit = NaN;
    if ismember('TransferActiveMedHit', medLT.Properties.VariableNames)
        taHit = medLT.TransferActiveMedHit(rows);
        denom = LA & isfinite(taHit);
        if nnz(denom) >= 5
            reuseHit = mean(taHit(denom), 'omitnan');
        end
    end

    reuseMiss = NaN;
    if ismember('TransferActiveMedMiss', medLT.Properties.VariableNames)
        taMiss = medLT.TransferActiveMedMiss(rows);
        denom = LA & isfinite(taMiss);
        if nnz(denom) >= 5
            reuseMiss = mean(taMiss(denom), 'omitnan');
        end
    end

    % 复用率（按行为拆分，反向）：Hit/Miss 回合下的 TransferActive → LearnedActive
    reuseRevHit = NaN;
    if ismember('TransferActiveMedHit', medLT.Properties.VariableNames)
        taHit = medLT.TransferActiveMedHit(rows);
        denom = (taHit == 1);
        if nnz(denom) >= 5
            reuseRevHit = mean(double(LA(denom)), 'omitnan');
        end
    end

    reuseRevMiss = NaN;
    if ismember('TransferActiveMedMiss', medLT.Properties.VariableNames)
        taMiss = medLT.TransferActiveMedMiss(rows);
        denom = (taMiss == 1);
        if nnz(denom) >= 5
            reuseRevMiss = mean(double(LA(denom)), 'omitnan');
        end
    end

    perf = perfByMouse.TransferPerformance(perfByMouse.Mouse==m);
    if isempty(perf)
        perf = NaN;
    else
        perf = perf(1);
    end

    rowN = rowN + 1;
    sumMouse(rowN) = m;
    sumZKey(rowN) = z;
    sumPerf(rowN) = perf;
    sumNCells(rowN) = nnz(rows);
    sumLearnedRate(rowN) = learnedRate;
    sumReuse(rowN) = reuse;
    sumTransferRate(rowN) = transferRate;
    sumReuseRev(rowN) = reuseRev;
    sumReuseHit(rowN) = reuseHit;
    sumReuseMiss(rowN) = reuseMiss;
    sumReuseRevHit(rowN) = reuseRevHit;
    sumReuseRevMiss(rowN) = reuseRevMiss;
end

    Summary = table(sumMouse(1:rowN), sumZKey(1:rowN), sumPerf(1:rowN), sumNCells(1:rowN), sumLearnedRate(1:rowN), sumTransferRate(1:rowN), sumReuse(1:rowN), sumReuseRev(1:rowN), ...
        sumReuseHit(1:rowN), sumReuseMiss(1:rowN), sumReuseRevHit(1:rowN), sumReuseRevMiss(1:rowN), ...
        'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','LearnedMedianActiveRate','TransferMedianActiveRate','ReuseRate_LearnedMedianActive','ReuseRate_TransferMedianActive','ReuseRate_LearnedMedianActive_Hit','ReuseRate_LearnedMedianActive_Miss','ReuseRate_TransferMedianActive_Hit','ReuseRate_TransferMedianActive_Miss'});

    Summary = sortrows(Summary, {'ZKey','TransferPerformance'}, {'ascend','descend'});

    rows23 = Summary.ZKey=="MOp23";
    rows5  = Summary.ZKey=="MOp5";

    r23 = iCorrReport(Summary.TransferPerformance(rows23), Summary.ReuseRate_LearnedMedianActive(rows23));
    r5  = iCorrReport(Summary.TransferPerformance(rows5),  Summary.ReuseRate_LearnedMedianActive(rows5));

    r23Rev = iCorrReport(Summary.TransferPerformance(rows23), Summary.ReuseRate_TransferMedianActive(rows23));
    r5Rev  = iCorrReport(Summary.TransferPerformance(rows5),  Summary.ReuseRate_TransferMedianActive(rows5));

fprintf("\n=== Median-NTATS threshold reuse (LearnedActive→TransferActive) ===\n");
disp(Summary);
fprintf("\n[MOp2/3 Spearman] rho=%.3f, p=%.4g (n=%d)\n", r23.rho, r23.p, r23.n);
fprintf("[MOp5  Spearman] rho=%.3f, p=%.4g (n=%d)\n", r5.rho,  r5.p,  r5.n);

fprintf("\n=== Reverse reuse (TransferActive→LearnedActive) ===\n");
fprintf("[MOp2/3 Spearman] rho=%.3f, p=%.4g (n=%d)\n", r23Rev.rho, r23Rev.p, r23Rev.n);
fprintf("[MOp5  Spearman] rho=%.3f, p=%.4g (n=%d)\n", r5Rev.rho,  r5Rev.p,  r5Rev.n);

% Hit vs Miss：同一只鼠同一层的配对比较（正向复用率）
    p23 = iPairedHitMissP(Summary.ReuseRate_LearnedMedianActive_Hit(rows23), Summary.ReuseRate_LearnedMedianActive_Miss(rows23));
    p5  = iPairedHitMissP(Summary.ReuseRate_LearnedMedianActive_Hit(rows5),  Summary.ReuseRate_LearnedMedianActive_Miss(rows5));

    % 同步把 Summary 留到 base，方便你后续直接用
    assignin('base','AudioLight_MedianNTATSReuse_Summary',Summary);
else
    Summary = evalin('base','AudioLight_MedianNTATSReuse_Summary');
    rows23 = Summary.ZKey=="MOp23";
    rows5  = Summary.ZKey=="MOp5";
    r23 = iCorrReport(Summary.TransferPerformance(rows23), Summary.ReuseRate_LearnedMedianActive(rows23));
    r5  = iCorrReport(Summary.TransferPerformance(rows5),  Summary.ReuseRate_LearnedMedianActive(rows5));
    r23Rev = iCorrReport(Summary.TransferPerformance(rows23), Summary.ReuseRate_TransferMedianActive(rows23));
    r5Rev  = iCorrReport(Summary.TransferPerformance(rows5),  Summary.ReuseRate_TransferMedianActive(rows5));
    p23 = iPairedHitMissP(Summary.ReuseRate_LearnedMedianActive_Hit(rows23), Summary.ReuseRate_LearnedMedianActive_Miss(rows23));
    p5  = iPairedHitMissP(Summary.ReuseRate_LearnedMedianActive_Hit(rows5),  Summary.ReuseRate_LearnedMedianActive_Miss(rows5));
end

fprintf("\n=== Hit vs Miss (forward reuse: LearnedActive→TransferActive) ===\n");
fprintf("[MOp2/3 signrank hit>miss] p=%.4g (n=%d)\n", p23.p, p23.n);
fprintf("[MOp5  signrank hit>miss] p=%.4g (n=%d)\n", p5.p,  p5.n);

%% --- 3.5) 叠加 scFLARE 数据库的鼠：作在“基本声光迁移相关性图”上
% 目标：用同一套定义（median NTATS + z-score + baseline+3σ）计算 scFLARE 的复用率与光水表现
% 然后叠加到本图中，查看是否符合基本声光迁移的相关性规律。

haveFlareSummary = false;
try
    haveFlareSummary = evalin('base', "exist('scFLARE_MedianNTATSReuse_Summary','var')") ~= 0;
catch
end

if cfg.RecomputeOverlays || ~haveFlareSummary
    if evalin('base', "exist('scFLAREDS','var')")
        FL = evalin('base', 'scFLAREDS');
    else
        FL = TransferLearning.scFLARE;
        assignin('base', 'scFLAREDS', FL);
    end

% scFLARE 的 NTATS 时间点数可能与 TransferLearning.Xs 不同（例如 49 点）；
% 这里假设其时间窗覆盖 [-3,3] 秒并均匀采样，用 linspace 构建时间轴以生成 base/win mask。
% 关键修正：scFLARE 的 LightWater 有多次 session。
% 这里定义“Transfer LightWater”为显式标记的 Transfer 会话：Phase="Transfer"（来自 DateTimes 表）。
% 行为（Performance）取该 block 的 Performance；神经活动用 QueryNTS 拉取 trial-level 信号，
% 通过 TrialUID→BlockUID 过滤到该 block，再对每个 cell 做 trial median。

TLW_FL = FL.TableQuery(["Mouse","DateTime","Performance","BlockUID","Phase"], Design="LightWater", Phase="Transfer");
TLW_FL.Mouse = string(TLW_FL.Mouse);

TAW_FL = FL.TableQuery(["Mouse","DateTime","BlockUID","Phase"], Design="AudioWater", Phase="Learned");
TAW_FL.Mouse = string(TAW_FL.Mouse);

% 49 点时间轴（由 QueryNTS 返回的 TrialSignal 列数决定）；默认覆盖 [-3,3] 秒
% 先用任意一个 mouse 的 LightWater QueryNTS 取到 nT
tmpNTS = FL.QueryNTS(struct('Stimulus','LightWater','Design','LightWater','Mouse', TLW_FL.Mouse(1)), UniExp.Flags.ZScore, 1:24);
tmpT = tmpNTS{1};
nT_FL = size(tmpT.TrialSignal, 2);
xsSecFL = linspace(-3, 3, nT_FL);
baseMaskFL = (xsSecFL >= -3) & (xsSecFL < 0);
winMaskFL  = (xsSecFL >= 0) & (xsSecFL <= 1);

C_FL = FL.Cells;
Tr_FL = FL.Trials;

miceFL = unique(TLW_FL.Mouse);

sumMouse_FL = strings(0,1);
sumZKey_FL = strings(0,1);
sumPerf_FL = nan(0,1);
sumNCells_FL = nan(0,1);
sumReuse_FL = nan(0,1);

for iM = 1:numel(miceFL)
    m = miceFL(iM);

    % Transfer LightWater session: explicit Phase="Transfer" row
    rowsLW = TLW_FL.Mouse == m;
    if nnz(rowsLW) ~= 1
        % 防御：若数据异常（0 或 >1 行），直接跳过，避免误选。
        continue;
    end
    idxTrans = find(rowsLW, 1, 'first');
    transRow = TLW_FL(idxTrans, :);
    transBlockUID = uint64(transRow.BlockUID);
    transPerf = double(transRow.Performance);
    transDT = transRow.DateTime;

    % Learned session: explicit Phase="Learned" AudioWater（与会话标记一致）
    rowsAW = TAW_FL.Mouse == m;
    if ~any(rowsAW)
        continue;
    end
    if nnz(rowsAW) ~= 1
        % 防御：若 Learned 标记异常（0 或 >1 行），跳过
        continue;
    end
    idxLearn = find(rowsAW, 1, 'first');
    learnRow = TAW_FL(idxLearn, :);
    learnBlockUID = uint64(learnRow.BlockUID);

    % TrialUID 列表（用于过滤到指定 block）
    trLearn = (uint64(Tr_FL.BlockUID) == learnBlockUID) & (string(Tr_FL.Stimulus) == "AudioWater");
    trTran  = (uint64(Tr_FL.BlockUID) == transBlockUID) & (string(Tr_FL.Stimulus) == "LightWater");
    trialUIDLearn = uint64(Tr_FL.TrialUID(trLearn));
    trialUIDTran  = uint64(Tr_FL.TrialUID(trTran));
    if isempty(trialUIDLearn) || isempty(trialUIDTran)
        continue;
    end

    % Learned trial-level NTS → block-filter → per-cell median trace
    ntsLearnCell = FL.QueryNTS(struct('Stimulus','AudioWater','Design','AudioWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
    ntsLearn = ntsLearnCell{1};
    inLearn = ismember(uint64(ntsLearn.TrialUID), trialUIDLearn);
    ntsLearn = ntsLearn(inLearn, :);
    if isempty(ntsLearn)
        continue;
    end
    [gL, cellL] = findgroups(uint64(ntsLearn.CellUID));
    medLearn = splitapply(@(x) median(x, 1, 'omitnan'), ntsLearn.TrialSignal, gL);

    learnedBaseMuFL = mean(medLearn(:, baseMaskFL), 2, 'omitnan');
    learnedBaseSdFL = std(medLearn(:, baseMaskFL), 0, 2, 'omitnan');
    learnedWinMxFL  = max(medLearn(:, winMaskFL), [], 2, 'omitnan');
    learnedActive = learnedWinMxFL > (learnedBaseMuFL + kSigma .* learnedBaseSdFL);

    % Transfer trial-level NTS → block-filter → per-cell median trace
    ntsTranCell = FL.QueryNTS(struct('Stimulus','LightWater','Design','LightWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
    ntsTran = ntsTranCell{1};
    inTran = ismember(uint64(ntsTran.TrialUID), trialUIDTran);
    ntsTran = ntsTran(inTran, :);
    if isempty(ntsTran)
        continue;
    end
    [gT, cellT] = findgroups(uint64(ntsTran.CellUID));
    medTran = splitapply(@(x) median(x, 1, 'omitnan'), ntsTran.TrialSignal, gT);

    tranBaseMuFL = mean(medTran(:, baseMaskFL), 2, 'omitnan');
    tranBaseSdFL = std(medTran(:, baseMaskFL), 0, 2, 'omitnan');
    tranWinMxFL  = max(medTran(:, winMaskFL), [], 2, 'omitnan');
    tranActive = tranWinMxFL > (tranBaseMuFL + kSigma .* tranBaseSdFL);

    % 合并 Learned/Transfer（只用两个 session 都有的 cell）
    learnedCellFL = table(cellL, double(learnedActive), 'VariableNames', {'CellUID','LearnedActiveMed'});
    transferCellFL = table(cellT, double(tranActive), 'VariableNames', {'CellUID','TransferActiveMed'});
    medLT_FL = innerjoin(learnedCellFL, transferCellFL, 'Keys', 'CellUID');
    if isempty(medLT_FL)
        continue;
    end

    medLT_FL = innerjoin(medLT_FL, C_FL(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
    medLT_FL.ZKey = iZKey(medLT_FL.ZLayer);
    medLT_FL.ZKey = string(medLT_FL.ZKey);

    % 每层复用率
    for z = ["MOp23","MOp5"]
        rowsZ = medLT_FL.ZKey == z;
        if nnz(rowsZ) < 10
            continue;
        end
        LA = logical(medLT_FL.LearnedActiveMed(rowsZ));
        TA = logical(medLT_FL.TransferActiveMed(rowsZ));
        reuse = NaN;
        if nnz(LA) >= 5
            reuse = mean(double(TA(LA)));
        end

        sumMouse_FL(end+1,1) = m;
        sumZKey_FL(end+1,1) = z;
        sumPerf_FL(end+1,1) = transPerf;
        sumNCells_FL(end+1,1) = nnz(rowsZ);
        sumReuse_FL(end+1,1) = reuse;
    end
end

    FlareSummary = table(sumMouse_FL, sumZKey_FL, sumPerf_FL, sumNCells_FL, sumReuse_FL, ...
        'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_LearnedMedianActive'});

    assignin('base','scFLARE_MedianNTATSReuse_Summary',FlareSummary);
else
    FlareSummary = evalin('base','scFLARE_MedianNTATSReuse_Summary');
end

%% --- 3.6) 叠加 Vacation7 数据库的鼠：作在“基本声光迁移相关性图”上
% 目标：与 scFLARE 同样的 session 语义与算法
%   - Learned：Design="AudioWater", Phase="Learned"
%   - Transfer：Design="LightWater", Phase="Transfer"
%   - 神经：trial-level QueryNTS → TrialUID→BlockUID 过滤到对应 session → per-cell trial median
%   - 活跃：max(0~1s) > mean(-3~0s) + kSigma*std(-3~0s)（z-score 上做）

haveV7Summary = false;
try
    haveV7Summary = evalin('base', "exist('Vacation7_MedianNTATSReuse_Summary','var')") ~= 0;
catch
end

Vacation7Summary = table(strings(0,1), strings(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_LearnedMedianActive'});

if cfg.RecomputeOverlays || ~haveV7Summary
    try
        if evalin('base', "exist('Vacation7DS','var')")
            V7 = evalin('base', 'Vacation7DS');
        else
            V7 = TransferLearning.Vacation7;
            assignin('base', 'Vacation7DS', V7);
        end

        TLW_V7 = V7.TableQuery(["Mouse","DateTime","Performance","BlockUID","Phase"], Design="LightWater", Phase="Transfer");
        TLW_V7.Mouse = string(TLW_V7.Mouse);
        TAW_V7 = V7.TableQuery(["Mouse","DateTime","BlockUID","Phase"], Design="AudioWater", Phase="Learned");
        TAW_V7.Mouse = string(TAW_V7.Mouse);

        if ~isempty(TLW_V7) && ~isempty(TAW_V7)
            tmpNTS = V7.QueryNTS(struct('Stimulus','LightWater','Design','LightWater','Mouse', TLW_V7.Mouse(1)), UniExp.Flags.ZScore, 1:24);
            tmpT = tmpNTS{1};
            nT_V7 = size(tmpT.TrialSignal, 2);
            xsSecV7 = linspace(-3, 3, nT_V7);
            baseMaskV7 = (xsSecV7 >= -3) & (xsSecV7 < 0);
            winMaskV7  = (xsSecV7 >= 0) & (xsSecV7 <= 1);

            C_V7 = V7.Cells;
            Tr_V7 = V7.Trials;
            miceV7 = intersect(unique(TLW_V7.Mouse), unique(TAW_V7.Mouse));

            sumMouse_V7 = strings(0,1);
            sumZKey_V7 = strings(0,1);
            sumPerf_V7 = nan(0,1);
            sumNCells_V7 = nan(0,1);
            sumReuse_V7 = nan(0,1);

            for iM = 1:numel(miceV7)
                m = miceV7(iM);

                rowsLW = TLW_V7.Mouse == m;
                if ~any(rowsLW)
                    continue;
                end
                tlwM = TLW_V7(rowsLW, :);
                [~, idxMax] = max(tlwM.DateTime);
                transRow = tlwM(idxMax, :);
                transBlockUID = uint64(transRow.BlockUID);
                transPerf = double(transRow.Performance);

                rowsAW = TAW_V7.Mouse == m;
                if ~any(rowsAW)
                    continue;
                end
                tawM = TAW_V7(rowsAW, :);
                [~, idxMax] = max(tawM.DateTime);
                learnRow = tawM(idxMax, :);
                learnBlockUID = uint64(learnRow.BlockUID);

                trLearn = (uint64(Tr_V7.BlockUID) == learnBlockUID) & (string(Tr_V7.Stimulus) == "AudioWater");
                trTran  = (uint64(Tr_V7.BlockUID) == transBlockUID) & (string(Tr_V7.Stimulus) == "LightWater");
                trialUIDLearn = uint64(Tr_V7.TrialUID(trLearn));
                trialUIDTran  = uint64(Tr_V7.TrialUID(trTran));
                if isempty(trialUIDLearn) || isempty(trialUIDTran)
                    continue;
                end

                ntsLearnCell = V7.QueryNTS(struct('Stimulus','AudioWater','Design','AudioWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
                ntsLearn = ntsLearnCell{1};
                inLearn = ismember(uint64(ntsLearn.TrialUID), trialUIDLearn);
                ntsLearn = ntsLearn(inLearn, :);
                if isempty(ntsLearn)
                    continue;
                end
                [gL, cellL] = findgroups(uint64(ntsLearn.CellUID));
                medLearn = splitapply(@(x) median(x, 1, 'omitnan'), ntsLearn.TrialSignal, gL);

                learnedBaseMuV7 = mean(medLearn(:, baseMaskV7), 2, 'omitnan');
                learnedBaseSdV7 = std(medLearn(:, baseMaskV7), 0, 2, 'omitnan');
                learnedWinMxV7  = max(medLearn(:, winMaskV7), [], 2, 'omitnan');
                learnedActiveV7 = learnedWinMxV7 > (learnedBaseMuV7 + kSigma .* learnedBaseSdV7);

                ntsTranCell = V7.QueryNTS(struct('Stimulus','LightWater','Design','LightWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
                ntsTran = ntsTranCell{1};
                inTran = ismember(uint64(ntsTran.TrialUID), trialUIDTran);
                ntsTran = ntsTran(inTran, :);
                if isempty(ntsTran)
                    continue;
                end
                [gT, cellT] = findgroups(uint64(ntsTran.CellUID));
                medTran = splitapply(@(x) median(x, 1, 'omitnan'), ntsTran.TrialSignal, gT);

                tranBaseMuV7 = mean(medTran(:, baseMaskV7), 2, 'omitnan');
                tranBaseSdV7 = std(medTran(:, baseMaskV7), 0, 2, 'omitnan');
                tranWinMxV7  = max(medTran(:, winMaskV7), [], 2, 'omitnan');
                tranActiveV7 = tranWinMxV7 > (tranBaseMuV7 + kSigma .* tranBaseSdV7);

                learnedCellV7 = table(cellL, double(learnedActiveV7), 'VariableNames', {'CellUID','LearnedActiveMed'});
                transferCellV7 = table(cellT, double(tranActiveV7), 'VariableNames', {'CellUID','TransferActiveMed'});
                medLT_V7 = innerjoin(learnedCellV7, transferCellV7, 'Keys', 'CellUID');
                if isempty(medLT_V7)
                    continue;
                end

                medLT_V7 = innerjoin(medLT_V7, C_V7(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
                medLT_V7.ZKey = iZKey(medLT_V7.ZLayer);
                medLT_V7.ZKey = string(medLT_V7.ZKey);

                for z = ["MOp23","MOp5"]
                    rowsZ = medLT_V7.ZKey == z;
                    if nnz(rowsZ) < 10
                        continue;
                    end
                    LA = logical(medLT_V7.LearnedActiveMed(rowsZ));
                    TA = logical(medLT_V7.TransferActiveMed(rowsZ));
                    reuse = NaN;
                    if nnz(LA) >= 5
                        reuse = mean(double(TA(LA)));
                    end

                    sumMouse_V7(end+1,1) = m;
                    sumZKey_V7(end+1,1) = z;
                    sumPerf_V7(end+1,1) = transPerf;
                    sumNCells_V7(end+1,1) = nnz(rowsZ);
                    sumReuse_V7(end+1,1) = reuse;
                end
            end

            Vacation7Summary = table(sumMouse_V7, sumZKey_V7, sumPerf_V7, sumNCells_V7, sumReuse_V7, ...
                'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_LearnedMedianActive'});
        end
    catch ME
        warning(ME.identifier, '%s', ME.message);
    end

    assignin('base','Vacation7_MedianNTATSReuse_Summary',Vacation7Summary);
else
    Vacation7Summary = evalin('base','Vacation7_MedianNTATSReuse_Summary');
end

%% --- 3.7) 叠加 THInhibit 数据库的鼠：作在“基本声光迁移相关性图”上
% 目标：与 Vacation7 同样的 session 语义与算法
%   - Learned：Design="AudioWater", Phase="Learned", Stimulus="AudioWater"
%   - Transfer：Design="LightWater", Phase="Transfer", Stimulus="LightWater"

haveTHSummary = false;
try
    haveTHSummary = evalin('base', "exist('THInhibit_MedianNTATSReuse_Summary','var')") ~= 0;
catch
end

THInhibitSummary = table(strings(0,1), strings(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_LearnedMedianActive'});

if cfg.RecomputeOverlays || ~haveTHSummary
    try
        if evalin('base', "exist('THInhibitDS','var')")
            TH = evalin('base', 'THInhibitDS');
        else
            TH = TransferLearning.THInhibit;
            assignin('base', 'THInhibitDS', TH);
        end

        TLW_TH = TH.TableQuery(["Mouse","DateTime","Performance","BlockUID","Phase","Stimulus"], Design="LightWater", Phase="Transfer", Stimulus="LightWater");
        TLW_TH.Mouse = string(TLW_TH.Mouse);
        TAW_TH = TH.TableQuery(["Mouse","DateTime","BlockUID","Phase","Stimulus"], Design="AudioWater", Phase="Learned", Stimulus="AudioWater");
        TAW_TH.Mouse = string(TAW_TH.Mouse);

        if ~isempty(TLW_TH) && ~isempty(TAW_TH)
            tmpNTS = TH.QueryNTS(struct('Stimulus','LightWater','Design','LightWater','Mouse', TLW_TH.Mouse(1)), UniExp.Flags.ZScore, 1:24);
            tmpT = tmpNTS{1};
            nT_TH = size(tmpT.TrialSignal, 2);
            xsSecTH = linspace(-3, 3, nT_TH);
            baseMaskTH = (xsSecTH >= -3) & (xsSecTH < 0);
            winMaskTH  = (xsSecTH >= 0) & (xsSecTH <= 1);

            C_TH = TH.Cells;
            Tr_TH = TH.Trials;
            miceTH = intersect(unique(TLW_TH.Mouse), unique(TAW_TH.Mouse));

            sumMouse_TH = strings(0,1);
            sumZKey_TH = strings(0,1);
            sumPerf_TH = nan(0,1);
            sumNCells_TH = nan(0,1);
            sumReuse_TH = nan(0,1);

            for iM = 1:numel(miceTH)
                m = miceTH(iM);

                rowsLW = TLW_TH.Mouse == m;
                if ~any(rowsLW)
                    continue;
                end
                tlwM = TLW_TH(rowsLW, :);
                [~, idxMax] = max(tlwM.DateTime);
                transRow = tlwM(idxMax, :);
                transBlockUID = uint64(transRow.BlockUID);
                transPerf = double(transRow.Performance);

                rowsAW = TAW_TH.Mouse == m;
                if ~any(rowsAW)
                    continue;
                end
                tawM = TAW_TH(rowsAW, :);
                [~, idxMax] = max(tawM.DateTime);
                learnRow = tawM(idxMax, :);
                learnBlockUID = uint64(learnRow.BlockUID);

                trLearn = (uint64(Tr_TH.BlockUID) == learnBlockUID) & (string(Tr_TH.Stimulus) == "AudioWater");
                trTran  = (uint64(Tr_TH.BlockUID) == transBlockUID) & (string(Tr_TH.Stimulus) == "LightWater");
                trialUIDLearn = uint64(Tr_TH.TrialUID(trLearn));
                trialUIDTran  = uint64(Tr_TH.TrialUID(trTran));
                if isempty(trialUIDLearn) || isempty(trialUIDTran)
                    continue;
                end

                ntsLearnCell = TH.QueryNTS(struct('Stimulus','AudioWater','Design','AudioWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
                ntsLearn = ntsLearnCell{1};
                inLearn = ismember(uint64(ntsLearn.TrialUID), trialUIDLearn);
                ntsLearn = ntsLearn(inLearn, :);
                if isempty(ntsLearn)
                    continue;
                end
                [gL, cellL] = findgroups(uint64(ntsLearn.CellUID));
                medLearn = splitapply(@(x) median(x, 1, 'omitnan'), ntsLearn.TrialSignal, gL);

                learnedBaseMuTH = mean(medLearn(:, baseMaskTH), 2, 'omitnan');
                learnedBaseSdTH = std(medLearn(:, baseMaskTH), 0, 2, 'omitnan');
                learnedWinMxTH  = max(medLearn(:, winMaskTH), [], 2, 'omitnan');
                learnedActiveTH = learnedWinMxTH > (learnedBaseMuTH + kSigma .* learnedBaseSdTH);

                ntsTranCell = TH.QueryNTS(struct('Stimulus','LightWater','Design','LightWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
                ntsTran = ntsTranCell{1};
                inTran = ismember(uint64(ntsTran.TrialUID), trialUIDTran);
                ntsTran = ntsTran(inTran, :);
                if isempty(ntsTran)
                    continue;
                end
                [gT, cellT] = findgroups(uint64(ntsTran.CellUID));
                medTran = splitapply(@(x) median(x, 1, 'omitnan'), ntsTran.TrialSignal, gT);

                tranBaseMuTH = mean(medTran(:, baseMaskTH), 2, 'omitnan');
                tranBaseSdTH = std(medTran(:, baseMaskTH), 0, 2, 'omitnan');
                tranWinMxTH  = max(medTran(:, winMaskTH), [], 2, 'omitnan');
                tranActiveTH = tranWinMxTH > (tranBaseMuTH + kSigma .* tranBaseSdTH);

                learnedCellTH = table(cellL, double(learnedActiveTH), 'VariableNames', {'CellUID','LearnedActiveMed'});
                transferCellTH = table(cellT, double(tranActiveTH), 'VariableNames', {'CellUID','TransferActiveMed'});
                medLT_TH = innerjoin(learnedCellTH, transferCellTH, 'Keys', 'CellUID');
                if isempty(medLT_TH)
                    continue;
                end

                medLT_TH = innerjoin(medLT_TH, C_TH(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
                medLT_TH.ZKey = iZKey(medLT_TH.ZLayer);
                medLT_TH.ZKey = string(medLT_TH.ZKey);

                for z = ["MOp23","MOp5"]
                    rowsZ = medLT_TH.ZKey == z;
                    if nnz(rowsZ) < 10
                        continue;
                    end
                    LA = logical(medLT_TH.LearnedActiveMed(rowsZ));
                    TA = logical(medLT_TH.TransferActiveMed(rowsZ));
                    reuse = NaN;
                    if nnz(LA) >= 5
                        reuse = mean(double(TA(LA)));
                    end

                    sumMouse_TH(end+1,1) = m;
                    sumZKey_TH(end+1,1) = z;
                    sumPerf_TH(end+1,1) = transPerf;
                    sumNCells_TH(end+1,1) = nnz(rowsZ);
                    sumReuse_TH(end+1,1) = reuse;
                end
            end

            THInhibitSummary = table(sumMouse_TH, sumZKey_TH, sumPerf_TH, sumNCells_TH, sumReuse_TH, ...
                'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','ReuseRate_LearnedMedianActive'});
        end
    catch ME
        warning(ME.identifier, '%s', ME.message);
    end

    assignin('base','THInhibit_MedianNTATSReuse_Summary',THInhibitSummary);
else
    THInhibitSummary = evalin('base','THInhibit_MedianNTATSReuse_Summary');
end

outDirUNC = "\\\\Data-Server-2\\个人数据\\张天夫\\202601";

% --- 4) 画图并导出 SVG（全叠加散点图）
if cfg.ExportAllOverlayScatter
    figure('Name','AudioLight Median-NTATS threshold reuse vs Performance (by layer)');
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    sgtitle(sprintf('Median NTATS threshold: max(0~1s)>mean(base)+%g*std(base)', kSigma));

nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows23);
y = Summary.TransferPerformance(rows23);
miceLbl = Summary.Mouse(rows23);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
ylabel('Perf');
title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', r23.rho, r23.p, r23.n));
hold on;
text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
% overlay scFLARE points
rows23FL = FlareSummary.ZKey=="MOp23";
rows23V7 = Vacation7Summary.ZKey=="MOp23";
rows23TH = THInhibitSummary.ZKey=="MOp23";
if any(rows23FL)
    xFL = FlareSummary.ReuseRate_LearnedMedianActive(rows23FL);
    yFL = FlareSummary.TransferPerformance(rows23FL);
    lblFL = "FL-" + FlareSummary.Mouse(rows23FL);
    scatter(xFL, yFL, 70, '^', 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
    text(xFL, yFL, lblFL, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
end
% overlay Vacation7 points
if any(rows23V7)
    xV7 = Vacation7Summary.ReuseRate_LearnedMedianActive(rows23V7);
    yV7 = Vacation7Summary.TransferPerformance(rows23V7);
    lblV7 = "V7-" + Vacation7Summary.Mouse(rows23V7);
    scatter(xV7, yV7, 70, 'v', 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
    text(xV7, yV7, lblV7, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
end
% overlay THInhibit points
if any(rows23TH)
    xTH = THInhibitSummary.ReuseRate_LearnedMedianActive(rows23TH);
    yTH = THInhibitSummary.TransferPerformance(rows23TH);
    lblTH = "TH-" + THInhibitSummary.Mouse(rows23TH);
    scatter(xTH, yTH, 70, 's', 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
    text(xTH, yTH, lblTH, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
end

labels = {"Ctrl"};
if any(rows23FL)
    labels{end+1} = "scFLARE";
end
if any(rows23V7)
    labels{end+1} = "Vacation7";
end
if any(rows23TH)
    labels{end+1} = "THInhibit";
end
if numel(labels) > 1
    legend(labels, 'Location','best');
end
hold off;
ax = gca;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
    ax.Toolbar.Visible = 'off';
end

nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows5);
y = Summary.TransferPerformance(rows5);
miceLbl = Summary.Mouse(rows5);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
ylabel('Perf');
title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', r5.rho, r5.p, r5.n));
hold on;
text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
% overlay scFLARE points
rows5FL = FlareSummary.ZKey=="MOp5";
rows5V7 = Vacation7Summary.ZKey=="MOp5";
rows5TH = THInhibitSummary.ZKey=="MOp5";
if any(rows5FL)
    xFL = FlareSummary.ReuseRate_LearnedMedianActive(rows5FL);
    yFL = FlareSummary.TransferPerformance(rows5FL);
    lblFL = "FL-" + FlareSummary.Mouse(rows5FL);
    scatter(xFL, yFL, 70, '^', 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
    text(xFL, yFL, lblFL, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
end
% overlay Vacation7 points
if any(rows5V7)
    xV7 = Vacation7Summary.ReuseRate_LearnedMedianActive(rows5V7);
    yV7 = Vacation7Summary.TransferPerformance(rows5V7);
    lblV7 = "V7-" + Vacation7Summary.Mouse(rows5V7);
    scatter(xV7, yV7, 70, 'v', 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
    text(xV7, yV7, lblV7, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
end
% overlay THInhibit points
if any(rows5TH)
    xTH = THInhibitSummary.ReuseRate_LearnedMedianActive(rows5TH);
    yTH = THInhibitSummary.TransferPerformance(rows5TH);
    lblTH = "TH-" + THInhibitSummary.Mouse(rows5TH);
    scatter(xTH, yTH, 70, 's', 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
    text(xTH, yTH, lblTH, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
end

labels = {"Ctrl"};
if any(rows5FL)
    labels{end+1} = "scFLARE";
end
if any(rows5V7)
    labels{end+1} = "Vacation7";
end
if any(rows5TH)
    labels{end+1} = "THInhibit";
end
if numel(labels) > 1
    legend(labels, 'Location','best');
end
hold off;
ax = gca;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
    ax.Toolbar.Visible = 'off';
end

    fileName = sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_k%g.svg', kSigma);

    outFile = fullfile(outDirUNC, fileName);
    exportgraphics(gcf, outFile, 'ContentType','vector');
    fprintf("\nSVG exported: %s\n", outFile);

% 同图另存一份：包含 scFLARE 叠加点
    fileNameWithFlare = sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_WITH_scFLARE_k%g.svg', kSigma);
    outFileWithFlare = fullfile(outDirUNC, fileNameWithFlare);
    exportgraphics(gcf, outFileWithFlare, 'ContentType','vector');
    fprintf("\nSVG exported (with scFLARE overlay): %s\n", outFileWithFlare);

% 同图另存一份：包含 Vacation7 叠加点（若有）
    if ~isempty(Vacation7Summary) && height(Vacation7Summary) > 0
        fileNameWithV7 = sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_WITH_Vacation7_k%g.svg', kSigma);
        outFileWithV7 = fullfile(outDirUNC, fileNameWithV7);
        exportgraphics(gcf, outFileWithV7, 'ContentType','vector');
        fprintf("\nSVG exported (with Vacation7 overlay): %s\n", outFileWithV7);
    end

% 同图另存一份：包含 THInhibit 叠加点（若有）
    if ~isempty(THInhibitSummary) && height(THInhibitSummary) > 0
        fileNameWithTH = sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_WITH_THInhibit_k%g.svg', kSigma);
        outFileWithTH = fullfile(outDirUNC, fileNameWithTH);
        exportgraphics(gcf, outFileWithTH, 'ContentType','vector');
        fprintf("\nSVG exported (with THInhibit overlay): %s\n", outFileWithTH);
    end
end

% --- 4.2) 额外导出：Ctrl-only + 三张对比图（Ctrl vs scFLARE/Vacation7/THInhibit）
% 说明：单独开新 figure 导出，避免复用当前图导致 legend/标注混杂。
if cfg.ExportCtrlOnlyAnd3Compare
    % Ctrl only
    iExportCtrlOverlay(outDirUNC, sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_CTRLONLY_k%g.svg', kSigma), ...
        Summary, rows23, rows5, r23, r5, kSigma, table(), "", '', "");

    % Ctrl vs scFLARE
    if ~isempty(FlareSummary) && height(FlareSummary) > 0
        iExportCtrlOverlay(outDirUNC, sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_Ctrl_vs_scFLARE_k%g.svg', kSigma), ...
            Summary, rows23, rows5, r23, r5, kSigma, FlareSummary, "scFLARE", '^', "FL-");
    else
        warning('scFLARE summary empty; skip Ctrl vs scFLARE export.');
    end

    % Ctrl vs Vacation7
    if ~isempty(Vacation7Summary) && height(Vacation7Summary) > 0
        iExportCtrlOverlay(outDirUNC, sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_Ctrl_vs_Vacation7_k%g.svg', kSigma), ...
            Summary, rows23, rows5, r23, r5, kSigma, Vacation7Summary, "Vacation7", 'v', "V7-");
    else
        warning('Vacation7 summary empty; skip Ctrl vs Vacation7 export.');
    end

    % Ctrl vs THInhibit
    if ~isempty(THInhibitSummary) && height(THInhibitSummary) > 0
        iExportCtrlOverlay(outDirUNC, sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_Ctrl_vs_THInhibit_k%g.svg', kSigma), ...
            Summary, rows23, rows5, r23, r5, kSigma, THInhibitSummary, "THInhibit", 's', "TH-");
    else
        warning('THInhibit summary empty; skip Ctrl vs THInhibit export.');
    end
end

% --- 5) 反向复用率：同款图（TransferActive → LearnedActive）
if cfg.ExportReverse
    figure('Name','AudioLight Reverse reuse vs Performance (by layer)');
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    sgtitle(sprintf('Reverse reuse: P(LearnedActive | TransferActive), k=%g', kSigma));

    nexttile;
    x = Summary.ReuseRate_TransferMedianActive(rows23);
    y = Summary.TransferPerformance(rows23);
    miceLbl = Summary.Mouse(rows23);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('Reuse: TransferMedianActive → LearnedMedianActive');
    ylabel('Perf');
    title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', r23Rev.rho, r23Rev.p, r23Rev.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;
    ax = gca;
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end

    nexttile;
    x = Summary.ReuseRate_TransferMedianActive(rows5);
    y = Summary.TransferPerformance(rows5);
    miceLbl = Summary.Mouse(rows5);
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('Reuse: TransferMedianActive → LearnedMedianActive');
    ylabel('Perf');
    title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', r5Rev.rho, r5Rev.p, r5Rev.n));
    hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;
    ax = gca;
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end

    fileNameRev = sprintf('AudioLight_MedianNTATS_Reuse_TransferActive_to_LearnedActive_k%g.svg', kSigma);
    outFileRev = fullfile(outDirUNC, fileNameRev);
    exportgraphics(gcf, outFileRev, 'ContentType','vector');
    fprintf("\nSVG exported (reverse): %s\n", outFileRev);
end

% --- 6) Hit vs Miss：用 UniExp.BarScatterCompare 作图示意（按 layer）
if cfg.ExportHitMiss
    figure('Name','AudioLight Hit vs Miss reuse (BarScatterCompare)');
    tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
    sgtitle(sprintf('Hit vs Miss forward reuse (2D groups): P(TransferActive | LearnedActive), k=%g', kSigma));

    nexttile;
    hit23 = Summary.ReuseRate_LearnedMedianActive_Hit(rows23);
    miss23 = Summary.ReuseRate_LearnedMedianActive_Miss(rows23);
    mask23 = isfinite(hit23) & isfinite(miss23);

    hit5 = Summary.ReuseRate_LearnedMedianActive_Hit(rows5);
    miss5 = Summary.ReuseRate_LearnedMedianActive_Miss(rows5);
    mask5 = isfinite(hit5) & isfinite(miss5);

    colHit = {hit23(mask23); hit5(mask5)};
    colMiss = {miss23(mask23); miss5(mask5)};
    Groups = table(colHit, colMiss, ...
        'VariableNames', {'Hit','Miss'}, ...
        'RowNames', {'MOp2/3','MOp5'});
    Groups.Properties.DimensionNames = {'Layer','Outcome'};

    layerNames = string(Groups.Properties.RowNames);
    layerPairs = [layerNames, layerNames];
    outcomePairs = repmat(["Hit","Miss"], numel(layerNames), 1);
    groupPair2D = table(layerPairs, outcomePairs, 'VariableNames', Groups.Properties.DimensionNames);
    CompareGroup = table(groupPair2D, 'VariableNames', {'GroupPair'});

    UniExp.BarScatterCompare(Groups, false, CompareGroup);
    ylabel('Reuse');
    title('Forward reuse (Hit vs Miss)');
    ax = gca;
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end

    fileNameHM = sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_HitMiss_2D_k%g.svg', kSigma);
    outFileHM = fullfile(outDirUNC, fileNameHM);
    exportgraphics(gcf, outFileHM, 'ContentType','vector');
    fprintf("\nSVG exported (hit-miss 2D): %s\n", outFileHM);

    % ---- Reverse reuse Hit/Miss（同一张子图 4 条）----
    if all(ismember({'ReuseRate_TransferMedianActive_Hit','ReuseRate_TransferMedianActive_Miss'}, Summary.Properties.VariableNames))
        figure('Name','AudioLight Reverse Hit vs Miss reuse (BarScatterCompare)');
        tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
        sgtitle(sprintf('Reverse reuse (2D groups): P(LearnedActive | TransferActive), k=%g', kSigma));

        nexttile;
        hit23r = Summary.ReuseRate_TransferMedianActive_Hit(rows23);
        miss23r = Summary.ReuseRate_TransferMedianActive_Miss(rows23);
        mask23r = isfinite(hit23r) & isfinite(miss23r);

        hit5r = Summary.ReuseRate_TransferMedianActive_Hit(rows5);
        miss5r = Summary.ReuseRate_TransferMedianActive_Miss(rows5);
        mask5r = isfinite(hit5r) & isfinite(miss5r);

        colHitR = {hit23r(mask23r); hit5r(mask5r)};
        colMissR = {miss23r(mask23r); miss5r(mask5r)};
        GroupsR = table(colHitR, colMissR, ...
            'VariableNames', {'Hit','Miss'}, ...
            'RowNames', {'MOp2/3','MOp5'});
        GroupsR.Properties.DimensionNames = {'Layer','Outcome'};

        layerNamesR = string(GroupsR.Properties.RowNames);
        layerPairsR = [layerNamesR, layerNamesR];
        outcomePairsR = repmat(["Hit","Miss"], numel(layerNamesR), 1);
        groupPair2DR = table(layerPairsR, outcomePairsR, 'VariableNames', GroupsR.Properties.DimensionNames);
        CompareGroupR = table(groupPair2DR, 'VariableNames', {'GroupPair'});

        UniExp.BarScatterCompare(GroupsR, false, CompareGroupR);
        ylabel('Reuse');
        title('Reverse reuse (Hit vs Miss)');
        ax = gca;
        if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
            ax.Toolbar.Visible = 'off';
        end

        fileNameHMR = sprintf('AudioLight_MedianNTATS_Reuse_TransferActive_to_LearnedActive_HitMiss_2D_k%g.svg', kSigma);
        outFileHMR = fullfile(outDirUNC, fileNameHMR);
        exportgraphics(gcf, outFileHMR, 'ContentType','vector');
        fprintf("\nSVG exported (reverse hit-miss 2D): %s\n", outFileHMR);
    else
        warning('Reverse Hit/Miss reuse columns missing; skip reverse bar export. Set RecomputeCtrl=true once to regenerate Summary.');
    end
end

% --- 7) 三泳道热图：Learned 声水 / TransferHit 光水 / TransferMiss 光水（仅 -1~1s）
if cfg.ExportHeatmap && exist('cellUIDTranHM','var') && ~isempty(cellUIDTranHM) && exist('GLearn','var') && exist('XLearn','var') && exist('XTranHit','var') && exist('XTranMiss','var')
    [cellUIDCommon, idxLearn, idxTran] = intersect(uint64(GLearn.CellUID), cellUIDTranHM, 'stable');
    if numel(cellUIDCommon) >= 10
        xMask = (xsSec >= -1) & (xsSec <= 1);

        XLearnC = XLearn(idxLearn, xMask);
        XHitC   = XTranHit(idxTran, xMask);
        XMissC  = XTranMiss(idxTran, xMask);

        % 按 AUC 差值排序：AUC_{0~1s}(Learned) - AUC_{0~1s}(TransferMiss)
        tLocal = xsSec(xMask);
        winLocal = (tLocal >= 0) & (tLocal <= 1);
        tWin = tLocal(winLocal);
        if isempty(tWin) || numel(tWin) < 2
            error('No enough points in 0~1s window for AUC sorting.');
        end

        aucLearn = trapz(tWin, XLearnC(:, winLocal), 2);
        aucMiss  = trapz(tWin, XMissC(:,  winLocal), 2);
        aucDiff = aucLearn - aucMiss;
        [~, sortIdx] = sort(aucDiff, 'descend', 'MissingPlacement', 'last');

        laneData = cat(3, XLearnC(sortIdx,:), XHitC(sortIdx,:), XMissC(sortIdx,:));

        % CLim（带符号平方根变换）：先取当前数据范围，再对上下限做 sqrt 变换
        oldNeg = min(laneData, [], 'all', 'omitnan');
        oldPos = max(laneData, [], 'all', 'omitnan');
        sqrtCLim = [ -sqrt(abs(oldNeg)), sqrt(abs(oldPos)) ];

        figure('Name','AudioLight NTATS lane heatmap (-1~1s)');
        Layout = tiledlayout(1,3,'TileSpacing','none','Padding','tight');
        [~, Axes] = UniExp.LanearHeatmap( ...
            laneData, ...
            SubTitles=["🔊💧Learned","💡💧Hit","💡💧Miss"], ...
            Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
            CLim=sqrtCLim, ...
            Layout=Layout, ...
            ImagescStyle={'XData', seconds([-1,1])}, ...
            LMHColor=[0,0,1;1,1,1;1,0,0]);

        xlabel(Layout,'Time (s)');
        ylabel(Layout,sprintf('%u cells', size(laneData,1)));
        CB = colorbar;
        CB.Layout.Tile = 'east';
        CB.Label.String = 'z-score';
        for iA = 1:numel(Axes)
            A = Axes(iA);
            if ~isgraphics(A)
                continue;
            end
            xline(A,0,':k');
            xline(A,1,'-k');
            A.TickDir = 'in';
            box(A,'on');
            if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
                A.Toolbar.Visible = 'off';
            end
        end

        fileNameLane = sprintf('AudioLight_MedianNTATS_LanearHeatmap_Learned_TransferHit_TransferMiss_-1to1_k%g.svg', kSigma);
        outFileLane = fullfile(outDirUNC, fileNameLane);
        exportgraphics(gcf, outFileLane, 'ContentType','vector');
        fprintf("\nSVG exported (lanes heatmap): %s\n", outFileLane);
    else
        warning('Too few common cells for lane heatmap: n=%d', numel(cellUIDCommon));
    end
end

if cfg.ExportHeatmap && (~exist('cellUIDTranHM','var') || isempty(cellUIDTranHM) || ~exist('XLearn','var'))
    warning('Skip heatmap: requires RecomputeCtrl=true (need trial-level Hit/Miss traces).');
end

% 同步把 Summary 留到 base，方便你后续直接用
assignin('base','AudioLight_MedianNTATSReuse_Summary',Summary);

%% ---- local functions ----
function iExportCtrlOverlay(outDirUNC, fileName, Summary, rows23, rows5, r23, r5, kSigma, OverlaySummary, overlayName, overlayMarker, overlayPrefix)
% 导出：Ctrl-only 或 Ctrl vs 单一 overlay 的两层散点图

if nargin < 11
    overlayName = "";
end

figTitle = sprintf('Median NTATS threshold reuse vs Performance (Ctrl%s)', ...
    ternary(strlength(string(overlayName))>0, " + " + string(overlayName), " only"));

figure('Name', figTitle);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
if strlength(string(overlayName))>0
    sgtitle(sprintf('Median NTATS threshold (k=%g): Ctrl vs %s', kSigma, string(overlayName)));
else
    sgtitle(sprintf('Median NTATS threshold (k=%g): Ctrl only', kSigma));
end

% ---- MOp2/3 ----
nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows23);
y = Summary.TransferPerformance(rows23);
miceLbl = Summary.Mouse(rows23);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
ylabel('Perf');
title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', r23.rho, r23.p, r23.n));
hold on;
text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');

if ~isempty(OverlaySummary) && height(OverlaySummary) > 0 && strlength(string(overlayName))>0
    rowsO = OverlaySummary.ZKey=="MOp23";
    if any(rowsO)
        xO = OverlaySummary.ReuseRate_LearnedMedianActive(rowsO);
        yO = OverlaySummary.TransferPerformance(rowsO);
        lblO = string(overlayPrefix) + OverlaySummary.Mouse(rowsO);
        scatter(xO, yO, 70, overlayMarker, 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
        text(xO, yO, lblO, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
        legend({"Ctrl", string(overlayName)}, 'Location','best');
    end
end
hold off;
ax = gca;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
    ax.Toolbar.Visible = 'off';
end

% ---- MOp5 ----
nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows5);
y = Summary.TransferPerformance(rows5);
miceLbl = Summary.Mouse(rows5);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
ylabel('Perf');
title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', r5.rho, r5.p, r5.n));
hold on;
text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');

if ~isempty(OverlaySummary) && height(OverlaySummary) > 0 && strlength(string(overlayName))>0
    rowsO = OverlaySummary.ZKey=="MOp5";
    if any(rowsO)
        xO = OverlaySummary.ReuseRate_LearnedMedianActive(rowsO);
        yO = OverlaySummary.TransferPerformance(rowsO);
        lblO = string(overlayPrefix) + OverlaySummary.Mouse(rowsO);
        scatter(xO, yO, 70, overlayMarker, 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
        text(xO, yO, lblO, 'FontSize', 8, 'VerticalAlignment','top', 'HorizontalAlignment','left', 'Interpreter','none');
        legend({"Ctrl", string(overlayName)}, 'Location','best');
    end
end
hold off;
ax = gca;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
    ax.Toolbar.Visible = 'off';
end

outFile = fullfile(outDirUNC, fileName);
exportgraphics(gcf, outFile, 'ContentType','vector');
fprintf("\nSVG exported (Ctrl compare): %s\n", outFile);
end

function y = ternary(cond, a, b)
if cond
    y = a;
else
    y = b;
end
end

function zKey = iZKey(zLayer)
zl = string(zLayer);
zKey = strings(size(zl));
zKey(zl=="MOp2/3") = "MOp23";
zKey(zl=="MOp5") = "MOp5";
end

function out = iCorrReport(x, y)
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

function out = iPairedHitMissP(hit, miss)
hit = hit(:);
miss = miss(:);
mask = isfinite(hit) & isfinite(miss);
hit = hit(mask);
miss = miss(mask);
out = struct('p', NaN, 'n', numel(hit));
if numel(hit) < 4
    return;
end
out.p = signrank(hit, miss, 'tail', 'right');
end

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable')
    X = NT.Data;
else
    X = NT;
end
end

function out = iMergeStruct(base, override)
out = base;
if ~isstruct(override)
    return;
end
f = fieldnames(override);
for i = 1:numel(f)
    out.(f{i}) = override.(f{i});
end
end
