%[text] # FlareTransferAllCellsTrialsVideo
%[text] 说明：自动打开 Transferlearning.prj 工程（若未打开）。 功能：为 FLARE Transfer 阶段（DateTimes.Phase=="Transfer"）生成“所有细胞 + 所有回合”的视频。 输出：最终只生成两个视频，分别对应 MOp2/3 与 MOp5。 约束来自 UniExp.DataSet.CellTrialsVideo： - 同一次调用的 CellUID/TrialUID 必须来自同一个 TIFF（同一个 Block） - CellUID 必须来自同一只鼠、同一个解剖层（本项目中为 MOp2/3 或 MOp5） - TrialUID 必须来自同一个会话，且相对于 Tag 有相同的开始/结束偏移量
%[text] 实现：Transfer 阶段在数据库里由 Phase 明确记录；对 Transfer block 直接输出两层视频。
OutputRoot = "\\Data-Server-2\个人数据\张天夫\202512\Transfer阶段所有细胞回合视频";
mkdir(OutputRoot); %[output:593d4f39]

StimulusName = "LightWater"; % Transfer 阶段口径

% 只导出“热图上活动较强”的少数细胞（每层 Top-N）
TopCellsPerLayer = 10;

% 可选：用于快速试跑（在命令行先设置 MaxBlocksToRun=1 再运行脚本）
try
    MaxBlocksToRun = MaxBlocksToRun;
catch
    MaxBlocksToRun = inf;
end

% Z 层映射（用户确认）：MOp2/3 -> TIFF Z=0；MOp5 -> TIFF Z=1

iEnsureTransferLearningProjectLoaded();
F = TransferLearning.scFLARE;

% 用热图同口径的 NTATS(Transfer) 计算活动强度，并按层选 Top-N
activeCellUIDByLayer = iTopActiveCellsFromHeatmap(F, TopCellsPerLayer); %[output:81a0d524]

T = F.Trials;
Bsig = F.BlockSignals;
Blocks = F.Blocks;

transferBlockUIDs = iTransferBlockUIDs(F);
transferBlockUIDs = transferBlockUIDs(:);
transferBlockUIDs = transferBlockUIDs(1:min(numel(transferBlockUIDs), MaxBlocksToRun));

finalPaths = struct();
baseMOp23 = "FLARE_Transfer_光水_所有细胞所有回合_MOp2-3";
baseMOp5  = "FLARE_Transfer_光水_所有细胞所有回合_MOp5";
finalPaths.MOp23 = fullfile(OutputRoot, baseMOp23 + ".mp4");
finalPaths.MOp5  = fullfile(OutputRoot, baseMOp5  + ".mp4");

for iB = 1:numel(transferBlockUIDs)
    blockUID = transferBlockUIDs(iB);

    % 该 Transfer block 的 LightWater trials
    blockTrialMask = (T.BlockUID == blockUID) & (string(T.Stimulus) == StimulusName);
    trialUIDAll = T.TrialUID(blockTrialMask);
    if isempty(trialUIDAll)
        continue;
    end

    % 该 block 的 tiff
    blockRow = Blocks(Blocks.BlockUID == blockUID, :);
    if height(blockRow) ~= 1
        continue;
    end

    % 该 block 的 cells（从 BlockSignals 映射）
    cellUIDInBlock = unique(Bsig.CellUID(Bsig.BlockUID == blockUID));
    if isempty(cellUIDInBlock)
        continue;
    end

    % Transfer block 必须满足：所有回合相对 Tag 的 Start/End 偏移一致
    sr = T.SampleRange(blockTrialMask, :);
    offsets = sr{:, ["Start","End"]} - sr.Tag;
    uniqueOffsets = unique(offsets, 'rows');
    if size(uniqueOffsets, 1) ~= 1
        error('Transfer Block %d has multiple Start/End offset groups (n=%d).', blockUID, size(uniqueOffsets, 1));
    end

    % 分解剖层分别导出最终视频（每层一个）
    for layerName = ["MOp2/3","MOp5"]
        layerName = string(layerName);
        if layerName == "MOp2/3"
            zTiff = uint8(0);
            outPath = finalPaths.MOp23;
        elseif layerName == "MOp5"
            zTiff = uint8(1);
            outPath = finalPaths.MOp5;
        else
            continue;
        end

        % 按解剖层筛细胞（Cells.ZLayer 是 categorical）
        layerMask = string(F.Cells.ZLayer) == layerName;
        cellUIDLayer = F.Cells.CellUID(layerMask);
        cellUID = intersect(cellUIDInBlock, cellUIDLayer);
        % 再按热图“活动强”筛选，并保持按强度排序
        if layerName == "MOp2/3"
            rankedUID = activeCellUIDByLayer.MOp23;
        elseif layerName == "MOp5"
            rankedUID = activeCellUIDByLayer.MOp5;
        else
            rankedUID = [];
        end
        cellUID = rankedUID(ismember(rankedUID, cellUID));
        if isempty(cellUID)
            continue;
        end

        if isfile(outPath)
            delete(outPath);
        end

        cellUIDu16 = uint16(cellUID);
        trialUIDu16 = uint16(trialUIDAll);

        % 直接用 UniExp.DataSet.CellTrialsVideo（不要走底层 UniExp.CellTrialsVideo）
        F.CellTrialsVideo(cellUIDu16, trialUIDu16, string(outPath), zTiff);
    end
end

fprintf("Saved: %s\n", finalPaths.MOp23); %[output:70f5d118]
fprintf("Saved: %s\n", finalPaths.MOp5); %[output:94da1c84]


function iEnsureTransferLearningProjectLoaded()
p = matlab.project.currentProject;
if isempty(p)
    openProject("Transferlearning.prj");
    return;
end

root = string(p.RootFolder);
if ~endsWith(lower(root), lower("Transfer-learning"))
    openProject("Transferlearning.prj");
end
end


function blockUIDs = iTransferBlockUIDs(F)
DT = F.DateTimes;
B = F.Blocks;
transferDT = DT.DateTime(string(DT.Phase) == "Transfer");
blockUIDs = unique(B.BlockUID(ismember(B.DateTime, transferDT)));
blockUIDs = sort(blockUIDs(:));
end


function activeCellUIDByLayer = iTopActiveCellsFromHeatmap(F, TopCellsPerLayer)
% 按与热图一致的 QueryNTATS 口径，使用 Transfer 列的 NTATS 强度挑选细胞。

QueryTablePath = TransferLearning.ProjectPath('查询表.xlsx');
QueryTable = UniExp.ReadQueryTable(QueryTablePath, 'FlareNtatsHeatmap');

GroupNtatsRaw = F.QueryNTATS(QueryTable, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GroupNtats = UniExp.NtatsCellStrip(GroupNtatsRaw);

Sorted = UniExp.HeatmapSort(GroupNtats, ["Learned","Transfer"]);
TransferData = Sorted.NTATS{:,:, "Transfer"};
TransferData = squeeze(TransferData);
if ~ismatrix(TransferData)
    error('Unexpected NTATS TransferData dimension.');
end

score = max(abs(TransferData), [], 2, 'omitnan');
cellUID = Sorted.CellUID;

[tfCell, locCell] = ismember(cellUID, F.Cells.CellUID);
if ~all(tfCell)
    missingN = nnz(~tfCell);
    error('Some CellUID in NTATS are missing from F.Cells (n=%d).', missingN);
end

zLayer = string(F.Cells.ZLayer(locCell));

activeCellUIDByLayer = struct();
activeCellUIDByLayer.MOp23 = iTopN(cellUID(zLayer == "MOp2/3"), score(zLayer == "MOp2/3"), TopCellsPerLayer);
activeCellUIDByLayer.MOp5  = iTopN(cellUID(zLayer == "MOp5"),  score(zLayer == "MOp5"),  TopCellsPerLayer);
end


function uidTop = iTopN(uid, score, n)
uid = uid(:);
score = score(:);
if isempty(uid)
    uidTop = uid;
    return;
end
[~, idx] = sort(score, 'descend', 'MissingPlacement', 'last');
uid = uid(idx);
n = min(n, numel(uid));
uidTop = uid(1:n);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:593d4f39]
%   data: {"dataType":"warning","outputData":{"text":"警告: 目录已存在。"}}
%---
%[output:81a0d524]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Numbers_of_cells_differ_among_groups：\n每组的细胞数不同，不同组之间可能不具有可比性，请确认筛选条件正确？分别有 689(Learned) 673(Transfer) 个细胞\n使用<a href=\"matlab:groupsummary(DataSet.Cells,'Mouse')\">groupsummary(DataSet.Cells,'Mouse')<\/a>查看每只鼠的细胞数"}}
%---
%[output:70f5d118]
%   data: {"dataType":"text","outputData":{"text":"Saved: \\\\Data-Server-2\\个人数据\\张天夫\\202512\\Transfer阶段所有细胞回合视频\\FLARE_Transfer_光水_所有细胞所有回合_MOp2-3.mp4\n","truncated":false}}
%---
%[output:94da1c84]
%   data: {"dataType":"text","outputData":{"text":"Saved: \\\\Data-Server-2\\个人数据\\张天夫\\202512\\Transfer阶段所有细胞回合视频\\FLARE_Transfer_光水_所有细胞所有回合_MOp5.mp4\n","truncated":false}}
%---
