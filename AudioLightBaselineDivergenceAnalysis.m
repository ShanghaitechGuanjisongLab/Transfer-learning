%% AudioLightBaseline divergence analysis (trial-level z-score at 1s)
% 定义：
% 1) 基线：Learned AudioWater 的 -3~0s 信号值（跨所有回合、所有基线采样点）
%    对每个 cell 取 std 作为 baseline scale。
%    注：这里用的是 UniExp.Flags.DeltaF（通常已经是相对基线的信号），
%    因此 z-score 不再额外减 baseline median（避免重复中心化）。
% 2) 对每个 condition：取每回合 1s 处的信号值，按该 cell 的 baseline 做 z-score。
%    得到 cell × trial 的 z-score 矩阵（仅保留在该 condition 下每个 trial 都有值的 cells）。
% 3) 把每个 trial 当作高维空间中的一个点（维度=cell）。
%    计算 trial 点之间的两两欧氏距离的标准差 std(d)。
%    计算 trial 点的均值点（centroid）到原点距离 ||centroid||。
%    发散度 divergence = std(d) / ||centroid||。
%
% 结果：对 Naive AudioWater, Learned AudioWater, Transfer LightWater, Final LightWater
%      逐鼠输出 divergence，并进行配对统计（Friedman + pairwise signrank(Holm)）。

%% --- 0) Ensure project loaded
try
    if ~exist('UniExp.DataSet','class')
        thisFile = mfilename('fullpath');
        thisDir = fileparts(thisFile);
        prjFile = fullfile(thisDir, 'Transferlearning.prj');
        if exist(prjFile,'file')
            try
                matlab.project.loadProject(prjFile);
            catch
            end
        end
    end
catch
end

%% --- 1) Load dataset (cached)
if evalin('base', "exist('AudioLightBaselineDS','var')")
    AL = evalin('base', 'AudioLightBaselineDS');
else
    AL = TransferLearning.AudioLightBaseline;
    assignin('base', 'AudioLightBaselineDS', AL);
end

excludeMice = string(["vtf0353"]);

%% --- 2) Time axis and indices
xs = TransferLearning.Xs;
xsSec = seconds(xs);

% NTS 的点数可能与 xs 不一致；如果不一致则按 [-3,3] 均匀采样兜底
nT_ref = numel(xsSec);
baseMask_ref = (xsSec >= -3) & (xsSec < 0);

% 1s 点：取最接近 1 的采样
[~, idx1_ref] = min(abs(xsSec - 1));

%% --- 3) Select one block per mouse for each condition
condDef = [ ...
    struct('Name',"Naive AudioWater",   'Phase',"Naive",   'Design',"AudioWater", 'Stimulus',"AudioWater");
    struct('Name',"Learned AudioWater", 'Phase',"Learned", 'Design',"AudioWater", 'Stimulus',"AudioWater");
    struct('Name',"Transfer LightWater",'Phase',"Transfer",'Design',"LightWater", 'Stimulus',"LightWater");
    struct('Name',"Final LightWater",   'Phase',"Final",   'Design',"LightWater", 'Stimulus',"LightWater");
];

BT = AL.TableQuery(["Mouse","DateTime","BlockUID","Phase","Design"]);
BT.Mouse = string(BT.Mouse);
BT.Phase = string(BT.Phase);
BT.Design = string(BT.Design);
BT = BT(~ismember(BT.Mouse, excludeMice), :);

% 抽取 block 级别（TableQuery 有时会因为其它字段导致重复）
BTu = unique(BT(:, ["Mouse","DateTime","BlockUID","Phase","Design"]), 'rows');

mice = unique(BTu.Mouse);

%% --- 4) Main loop per mouse
rowsOut = table();
Trials = AL.Trials;
Trials.Stimulus = string(Trials.Stimulus);

for iM = 1:numel(mice)
    m = mice(iM);

    % 4.1 Find Learned baseline block
    baseRow = iPickBlock(BTu, m, "Learned", "AudioWater");
    if isempty(baseRow)
        continue;
    end

    % 4.2 Load Learned trial-level signals (DeltaF) and compute baseline stats per cell
    trialUIDLearn = iTrialUIDByBlock(Trials, baseRow.BlockUID, "AudioWater");
    if isempty(trialUIDLearn)
        continue;
    end

    ntsLearnCell = AL.QueryNTS(struct('Stimulus','AudioWater','Design','AudioWater','Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsLearn = ntsLearnCell{1};
    inLearn = ismember(uint64(ntsLearn.TrialUID), uint64(trialUIDLearn));
    ntsLearn = ntsLearn(inLearn, :);
    if isempty(ntsLearn)
        continue;
    end

    % 确定 NTS 时间轴（按 TrialSignal 列数）
    nT = size(ntsLearn.TrialSignal, 2);
    [baseCols, idx1] = iTimeIndices(nT, nT_ref, baseMask_ref, idx1_ref);

    [gB, cellB] = findgroups(uint64(ntsLearn.CellUID));
    baseStd = splitapply(@(x) std(x(:, baseCols), 0, 'all', 'omitnan'), ntsLearn.TrialSignal, gB);

    % 防御：std=0 的 cell 无法做 z-score
    baseStd(baseStd <= 0 | ~isfinite(baseStd)) = NaN;

    % 4.3 For each condition compute divergence
    for iC = 1:numel(condDef)
        c = condDef(iC);
        blockRow = iPickBlock(BTu, m, c.Phase, c.Design);
        if isempty(blockRow)
            continue;
        end

        trialUID = iTrialUIDByBlock(Trials, blockRow.BlockUID, c.Stimulus);
        if isempty(trialUID)
            continue;
        end

        ntsCell = AL.QueryNTS(struct('Stimulus',c.Stimulus,'Design',c.Design,'Mouse',m), UniExp.Flags.DeltaF, 1:24);
        nts = ntsCell{1};
        inBlock = ismember(uint64(nts.TrialUID), uint64(trialUID));
        nts = nts(inBlock, :);
        if isempty(nts)
            continue;
        end

        % 只对 Learned baseline 里出现过的 cell 计算（baseline 才有定义）
        inBaseCell = ismember(uint64(nts.CellUID), cellB);
        nts = nts(inBaseCell, :);
        if isempty(nts)
            continue;
        end

        % 映射 baseline 参数到每条记录
        [tf, loc] = ismember(uint64(nts.CellUID), cellB);
        if ~all(tf)
            nts = nts(tf,:);
            loc = loc(tf);
        end

        v1 = nts.TrialSignal(:, idx1);
        z1 = v1 ./ baseStd(loc);

        % Pivot: cell × trial
        cellU = cellB; % baseline cell list
        trialU = unique(uint64(nts.TrialUID));
        [~, cellIdx] = ismember(uint64(nts.CellUID), cellU);
        [~, trialIdx] = ismember(uint64(nts.TrialUID), trialU);

        Z = nan(numel(cellU), numel(trialU));
        lin = sub2ind(size(Z), cellIdx, trialIdx);
        % 如果重复，取 mean
        Z = iAccumMean(Z, lin, z1);

        % 只保留在该 condition 下所有 trial 都有值的 cells
        goodCell = all(isfinite(Z), 2);
        Z = Z(goodCell, :);

        % 至少要有 2 个 trial 和 2 个 cell 才能定义距离分布
        nCell = size(Z,1);
        nTrial = size(Z,2);
        if nCell < 2 || nTrial < 2
            div = NaN;
            stdDist = NaN;
            dist0 = NaN;
        else
            d = pdist(Z', 'euclidean');
            stdDist = std(d, 0, 'omitnan');
            centroid = mean(Z', 1, 'omitnan');
            dist0 = norm(centroid, 2);
            if dist0 <= 0 || ~isfinite(dist0)
                div = NaN;
            else
                div = stdDist / dist0;
            end
        end

        rowsOut = [rowsOut; table(m, string(c.Name), string(c.Phase), string(c.Design), uint64(blockRow.BlockUID), blockRow.DateTime, nCell, nTrial, stdDist, dist0, div, ...
            'VariableNames', {'Mouse','Condition','Phase','Design','BlockUID','DateTime','NCells','NTrials','StdPairwiseDist','CentroidToOrigin','Divergence'})];
    end
end

if isempty(rowsOut)
    error('No results produced. Check phase/design filters and data availability.');
end

rowsOut = sortrows(rowsOut, {'Mouse','Condition'});
assignin('base','AudioLightBaseline_Divergence_ByMouse', rowsOut);

%% --- 5) Summary + stats
condNames = string({condDef.Name});

% Pivot to nMice × nCond
miceU = unique(rowsOut.Mouse);
D = nan(numel(miceU), numel(condNames));
Ncell = nan(size(D));
Ntrial = nan(size(D));

for iM = 1:numel(miceU)
    m = miceU(iM);
    for iC = 1:numel(condNames)
        c = condNames(iC);
        r = rowsOut.Mouse==m & rowsOut.Condition==c;
        if any(r)
            D(iM,iC) = rowsOut.Divergence(find(r,1,'first'));
            Ncell(iM,iC) = rowsOut.NCells(find(r,1,'first'));
            Ntrial(iM,iC) = rowsOut.NTrials(find(r,1,'first'));
        end
    end
end

complete = all(isfinite(D), 2);
D2 = D(complete, :);
mice2 = miceU(complete);

fprintf('\n=== AudioLightBaseline Divergence (std(pairwise euclid dist) / ||centroid||) ===\n');
for iC = 1:numel(condNames)
    x = D2(:,iC);
    fprintf('%-20s: mean=%.4g, median=%.4g (n=%d mice)\n', condNames(iC), mean(x,'omitnan'), median(x,'omitnan'), numel(x));
end

if size(D2,1) >= 3
    pF = friedman(D2, 1, 'off');
    fprintf('\n[Friedman across 4 conditions] p=%.4g (n=%d mice)\n', pF, size(D2,1));

    % pairwise signrank with Holm correction
    pairs = nchoosek(1:numel(condNames), 2);
    pRaw = nan(size(pairs,1),1);
    for iP = 1:size(pairs,1)
        a = pairs(iP,1);
        b = pairs(iP,2);
        pRaw(iP) = signrank(D2(:,a), D2(:,b));
    end
    [pAdj, order] = iHolmAdjust(pRaw);

    fprintf('\nPairwise signrank (Holm-adjusted)\n');
    for k = 1:numel(order)
        iP = order(k);
        a = pairs(iP,1);
        b = pairs(iP,2);
        fprintf('  %s vs %s: p=%.4g (raw %.4g)\n', condNames(a), condNames(b), pAdj(iP), pRaw(iP));
    end
else
    fprintf('\nNot enough mice with complete 4-condition data for stats (need >=3).\n');
end

%% --- 6) Export table
outDirUNC = "\\\\Data-Server-2\\个人数据\\张天夫\\202601";
outCsv = fullfile(outDirUNC, 'AudioLightBaseline_Divergence_ByMouse.csv');
try
    writetable(rowsOut, outCsv);
    fprintf('\nCSV exported: %s\n', outCsv);
catch ME
    warning(ME.identifier, 'Failed to export CSV: %s', ME.message);
end

%% --- local helpers
function row = iPickBlock(BTu, mouse, phase, design)
rows = (BTu.Mouse==mouse) & (BTu.Phase==phase) & (BTu.Design==design);
T = BTu(rows, :);
if isempty(T)
    row = [];
    return;
end
% 选择该 Phase/Design 下最新的一次
[~, idx] = max(T.DateTime);
row = T(idx, :);
end

function trialUID = iTrialUIDByBlock(Trials, blockUID, stimulus)
rows = (uint64(Trials.BlockUID) == uint64(blockUID)) & (string(Trials.Stimulus) == stimulus);
trialUID = uint64(Trials.TrialUID(rows));
end

function [baseCols, idx1] = iTimeIndices(nT, nT_ref, baseMask_ref, idx1_ref)
if nT == nT_ref
    baseCols = find(baseMask_ref);
    idx1 = idx1_ref;
else
    xs = linspace(-3, 3, nT);
    baseCols = find((xs >= -3) & (xs < 0));
    [~, idx1] = min(abs(xs - 1));
end
end

function Z = iAccumMean(Z, linIdx, values)
% 把 values 按 linIdx 写入 Z；若重复则取 mean
[linU, ~, g] = unique(linIdx);
mu = splitapply(@(x) mean(x, 'omitnan'), values, g);
Z(linU) = mu;
end

function [pAdj, order] = iHolmAdjust(p)
% Holm–Bonferroni
p = p(:);
[ps, order] = sort(p, 'ascend');
m = numel(p);
psAdj = nan(size(ps));
for i = 1:m
    psAdj(i) = min(1, (m - i + 1) * ps(i));
end
% 保证单调不减
for i = 2:m
    psAdj(i) = max(psAdj(i), psAdj(i-1));
end
pAdj = nan(size(p));
pAdj(order) = psAdj;
end