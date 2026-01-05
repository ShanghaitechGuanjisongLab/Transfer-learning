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
RespLearned = innerjoin(RespLearned, C(:,{'CellUID','Mouse'}), 'Keys','CellUID');

% 每个 mouse 每个 cell：跨 learned trials 平均
[glc, mL, cL] = findgroups(RespLearned.Mouse, RespLearned.CellUID);
cellLearned = table(mL, cL, splitapply(@mean, RespLearned.Resp, glc), ...
    'VariableNames', {'Mouse','CellUID','LearnedResp'});

% Transfer per-cell mean（同样跨 transfer trials 平均）
RespTransfer2 = innerjoin(RespTransfer(:,{'TrialUID','CellUID','Resp'}), transferTrials(:,{'TrialUID','BlockUID'}), 'Keys','TrialUID');
RespTransfer2 = innerjoin(RespTransfer2, TLWBlocks(:,{'BlockUID','Mouse','Performance'}), 'Keys','BlockUID');

[gtc, mT, cT] = findgroups(RespTransfer2.Mouse, RespTransfer2.CellUID);
cellTransfer = table(mT, cT, splitapply(@mean, RespTransfer2.Resp, gtc), ...
    'VariableNames', {'Mouse','CellUID','TransferResp'});

% 兼容/稳健性：innerjoin 要求键变量类型一致
cellLearned.Mouse = string(cellLearned.Mouse);
cellTransfer.Mouse = string(cellTransfer.Mouse);
cellLearned.CellUID = uint64(cellLearned.CellUID);
cellTransfer.CellUID = uint64(cellTransfer.CellUID);

% 合并 learned/transfer（以 CellUID 对齐；只保留两边都有的细胞）
cellLT = innerjoin(cellLearned, cellTransfer, 'Keys', {'Mouse','CellUID'});

% 逐 mouse 计算复用率：LearnedTop20 在 Transfer 中再激活(>0) 的比例；以及 learned↔transfer 响应相关
mice = unique(string(cellLT.Mouse));
MouseSummary = table('Size',[0 8], ...
    'VariableTypes', {'string','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'Mouse','TransferPerformance','NCells','ReuseRate_Top20_Positive','ReuseRate_Top20_Top20','ReuseCorr_Spearman','LearnedTop20Threshold','TransferTop20Threshold'});

for i = 1:numel(mice)
    m = mice(i);
    rows = string(cellLT.Mouse)==m;
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

    MouseSummary(end+1,:) = {m, perf, numel(L), reuse1, reuse2, cc, thrL, thrR}; %#ok<SAGROW>
end

    MouseSummary = sortrows(MouseSummary, 'TransferPerformance', 'descend');

fprintf("\n=== Learned(AudioWater)→Transfer(LightWater) reuse (per mouse) ===\n");
disp(MouseSummary(:,{'Mouse','TransferPerformance','NCells','ReuseRate_Top20_Positive','ReuseRate_Top20_Top20','ReuseCorr_Spearman'}));

% 复用率/复用相关性 与 Transfer performance 的关系
rReuse1 = iCorrReport(MouseSummary.TransferPerformance, MouseSummary.ReuseRate_Top20_Positive);
rReuse2 = iCorrReport(MouseSummary.TransferPerformance, MouseSummary.ReuseRate_Top20_Top20);
rReuseC = iCorrReport(MouseSummary.TransferPerformance, MouseSummary.ReuseCorr_Spearman);

fprintf("\n[Spearman] TransferPerformance vs ReuseRate(Top20→Pos): rho=%.3f, p=%.4g (n=%d)\n", rReuse1.rho, rReuse1.p, rReuse1.n);
fprintf("[Spearman] TransferPerformance vs ReuseRate(Top20→Top20): rho=%.3f, p=%.4g (n=%d)\n", rReuse2.rho, rReuse2.p, rReuse2.n);
fprintf("[Spearman] TransferPerformance vs ReuseCorr(L vs T): rho=%.3f, p=%.4g (n=%d)\n", rReuseC.rho, rReuseC.p, rReuseC.n);

%% 5) 作图：Transfer performance vs 复用指标（按 mouse）
try
    f = figure('Name','AudioLight Reuse vs Performance'); %#ok<NASGU>
    tl = tiledlayout(1,3,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>
    sgtitle(sprintf('Learned(AudioWater)→Transfer(LightWater) reuse vs performance (baseline -3~0s)'));

    y = MouseSummary.TransferPerformance;
    miceLbl = MouseSummary.Mouse;

    % (1) Top20→Positive
    nexttile;
    x = MouseSummary.ReuseRate_Top20_Positive;
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseRate: LearnedTop20 → TransferResp>0');
    ylabel('Transfer Performance');
    title(sprintf('\rho=%.3f, p=%.3g (n=%d)', rReuse1.rho, rReuse1.p, rReuse1.n));
    hold on;
    text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
    hold off;

    % (2) Top20→Top20（你关心的这张）
    nexttile;
    x = MouseSummary.ReuseRate_Top20_Top20;
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseRate: LearnedTop20 → TransferTop20');
    ylabel('Transfer Performance');
    title(sprintf('\rho=%.3f, p=%.3g (n=%d)', rReuse2.rho, rReuse2.p, rReuse2.n));
    hold on;
    text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
    hold off;

    % (3) Learned↔Transfer per-cell correlation
    nexttile;
    x = MouseSummary.ReuseCorr_Spearman;
    scatter(x, y, 50, 'filled');
    grid on; box off;
    xlabel('ReuseCorr: Spearman(LearnedResp, TransferResp)');
    ylabel('Transfer Performance');
    title(sprintf('\rho=%.3f, p=%.3g (n=%d)', rReuseC.rho, rReuseC.p, rReuseC.n));
    hold on;
    text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
    hold off;
catch ME
    warning('作图失败：%s', ME.message);
end

%% 输出变量（方便你后续画图/做更复杂模型）
assignin('base','AudioLight_BlockSummary',BlockSummary);
assignin('base','AudioLight_MouseSummary',MouseSummary);

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
