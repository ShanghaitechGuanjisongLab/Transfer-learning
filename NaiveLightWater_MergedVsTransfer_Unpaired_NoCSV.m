%% Merge Naive (LAInterspersed v5 + LightAudioBaseline) vs Transfer (AudioLightBaseline)
% 不依赖 CSV 回读：直接从数据库对象计算 divergence 并做非配对 ranksum。
% divergence 口径：QueryNTS(..., UniExp.Flags.ZScore, 1:24) 取 1s 点；trial 为点、cell 为维度。

%% --- 0) Ensure project loaded (for UniExp)
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

outDirUNC = "\\\\Data-Server-2\\个人数据\\张天夫\\202601";
excludeMice = string(["vtf0353"]);

%% --- 1) Load datasets
LAB = TransferLearning.LightAudioBaseline();
ALB = TransferLearning.AudioLightBaseline();

% LAInterspersed must be v5 (do not depend on factory pointing to v4)
v5Path = "\\data-server-2\个人数据\张天夫\202601\光声迁移MOp成像有穿插.v5.mat";
if ~isfile(v5Path)
    error("Missing LAInterspersed v5: %s", v5Path);
end
S = load(v5Path, 'Interspersed');
LAI = S.Interspersed;

%% --- 2) Find pure Naive LightWater mice (no AudioWater in same block)
labPure = iFindPureNaiveLightWaterMice(LAB, excludeMice);
laiPure = iFindPureNaiveLightWaterMice(LAI, excludeMice);

%% --- 3) Compute divergence
rowsNaive = table();
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence(LAB, labPure.Mouse, "LightAudioBaseline")];
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence(LAI, laiPure.Mouse, "LAInterspersed_v5")];
rowsNaive = sortrows(rowsNaive, ["DataSet","Mouse"]);

rowsTransfer = iComputeTransferLightWaterDivergenceAllMice(ALB);

%% --- 4) Merge Naive groups and compare (unpaired)
x = rowsNaive.Divergence;
y = rowsTransfer.Divergence;
x = x(isfinite(x));
y = y(isfinite(y));

[p, ~, stats] = ranksum(x, y);

summary = table;
summary.NaiveN = numel(x);
summary.TransferN = numel(y);
summary.NaiveMean = mean(x);
summary.NaiveMedian = median(x);
summary.NaiveStd = std(x);
summary.TransferMean = mean(y);
summary.TransferMedian = median(y);
summary.TransferStd = std(y);
summary.RankSumP = p;
summary.RankSumZ = stats.zval;

assignin('base','NaiveMergedVsTransfer_NoCSV_Summary', summary);
assignin('base','NaiveMerged_NoCSV_Rows', rowsNaive);
assignin('base','Transfer_NoCSV_Rows', rowsTransfer);

fprintf("Merged Naive vs Transfer (unpaired ranksum): p=%.6g (Naive n=%d, Transfer n=%d)\n", p, numel(x), numel(y));

%% --- 5) Export (results only)
iWriteTableUNC(summary, outDirUNC, 'NaiveMergedVsTransfer_Divergence_Unpaired_NoCSV.csv');

%% --- local functions (copied from NaiveLightWaterPureSessionDivergence.m)
function out = iFindPureNaiveLightWaterMice(DS, excludeMice)
T = DS.TableQuery(["Mouse","BlockUID","DateTime","Design","Phase","Stimulus"], Phase="Naive", Stimulus="LightWater");
T.Mouse = string(T.Mouse);
T.Design = string(T.Design);
T = T(~ismember(T.Mouse, excludeMice), :);
if isempty(T)
    out = table(string.empty(0,1), string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','Designs','NBlocks'});
    return;
end

Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);

mice = unique(T.Mouse);
keep = false(size(mice));
designs = strings(size(mice));
nBlocks = nan(size(mice));

for i = 1:numel(mice)
    m = mice(i);
    rowsM = T.Mouse == m;
    bu = unique(uint64(T.BlockUID(rowsM)));
    nBlocks(i) = numel(bu);

    hasAudio = false;
    for j = 1:numel(bu)
        b = bu(j);
        trB = (uint64(Tr.BlockUID) == b);
        if any(Tr.Stimulus(trB) == "AudioWater")
            hasAudio = true;
            break;
        end
    end

    keep(i) = ~hasAudio;
    designs(i) = strjoin(unique(T.Design(rowsM)), ",");
end

out = table(mice(keep), designs(keep), nBlocks(keep), 'VariableNames', {'Mouse','Designs','NBlocks'});
end

function iWriteTableUNC(T, outDirUNC, fileName)
try
    writetable(T, fullfile(outDirUNC, fileName));
catch ME
    msg = string(ME.message);
    if contains(lower(msg), "permission denied") || contains(lower(msg), "access")
        [p, n, e] = fileparts(fileName);
        ts = datestr(datetime('now'), 'yyyymmdd_HHMMSS');
        alt = fullfile(p, n + "_" + ts + e);
        try
            writetable(T, fullfile(outDirUNC, alt));
            warning('UniExp:Export:Retry', 'CSV locked; wrote alternative: %s', alt);
            return;
        catch ME2
            warning(ME2.identifier, 'CSV export failed (retry): %s', ME2.message);
        end
    end
    warning(ME.identifier, 'CSV export failed: %s', ME.message);
end
end

function out = iComputeNaiveLightWaterDivergence(DS, mice, dsName)
out = table(string.empty(0,1), string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'DataSet','Mouse','NCells','NTrials','StdPairwiseDist','CentroidToOrigin','Divergence'});
if isempty(mice)
    return;
end

xs = TransferLearning.Xs;
xsSec = seconds(xs);
[~, idx1_ref] = min(abs(xsSec - 1));
nT_ref = numel(xsSec);

BT = DS.TableQuery(["Mouse","DateTime","BlockUID","Phase","Design"], Phase="Naive");
BT.Mouse = string(BT.Mouse);
BT.Phase = string(BT.Phase);
BT.Design = string(BT.Design);
BTu = unique(BT(:, ["Mouse","DateTime","BlockUID","Phase","Design"]), 'rows');

Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);

for iM = 1:numel(mice)
    m = mice(iM);

    rowsB = (BTu.Mouse==m) & (BTu.Phase=="Naive");
    if ~any(rowsB)
        continue;
    end
    bu = unique(uint64(BTu.BlockUID(rowsB)));

    trialUID = uint64([]);
    for j = 1:numel(bu)
        b = bu(j);
        trRows = (uint64(Tr.BlockUID)==b) & (Tr.Stimulus=="LightWater");
        trialUID = [trialUID; uint64(Tr.TrialUID(trRows))]; %#ok<AGROW>
    end
    trialUID = unique(trialUID);
    if isempty(trialUID)
        continue;
    end

    ntsCell = DS.QueryNTS(struct('Stimulus','LightWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
    nts = ntsCell{1};
    inBlock = ismember(uint64(nts.TrialUID), trialUID);
    nts = nts(inBlock, :);
    if isempty(nts)
        continue;
    end

    nT = size(nts.TrialSignal, 2);
    if nT == nT_ref
        idx1 = idx1_ref;
    else
        xs2 = linspace(-3, 3, nT);
        [~, idx1] = min(abs(xs2 - 1));
    end

    v1 = nts.TrialSignal(:, idx1);

    cellU = unique(uint64(nts.CellUID));
    trialU = unique(uint64(nts.TrialUID));
    [~, cellIdx] = ismember(uint64(nts.CellUID), cellU);
    [~, trialIdx] = ismember(uint64(nts.TrialUID), trialU);

    Z = nan(numel(cellU), numel(trialU));
    lin = sub2ind(size(Z), cellIdx, trialIdx);
    Z = iAccumMean(Z, lin, v1);

    goodCell = all(isfinite(Z), 2);
    Z = Z(goodCell, :);

    [div, stdDist, dist0, nCell, nTrial] = iDivergenceFromMatrix(Z);

    out = [out; table(string(dsName), string(m), nCell, nTrial, stdDist, dist0, div, ...
        'VariableNames', {'DataSet','Mouse','NCells','NTrials','StdPairwiseDist','CentroidToOrigin','Divergence'})]; %#ok<AGROW>
end
end

function out = iComputeTransferLightWaterDivergenceAllMice(DS)
out = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'Mouse','NCells','NTrials','StdPairwiseDist','CentroidToOrigin','Divergence'});

xs = TransferLearning.Xs;
xsSec = seconds(xs);
[~, idx1_ref] = min(abs(xsSec - 1));
nT_ref = numel(xsSec);

BT = DS.TableQuery(["Mouse","DateTime","BlockUID","Phase","Design"], Phase="Transfer", Design="LightWater");
BT.Mouse = string(BT.Mouse);
BTu = unique(BT(:, ["Mouse","DateTime","BlockUID","Phase","Design"]), 'rows');

Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);

allMice = unique(BTu.Mouse);
for iM = 1:numel(allMice)
    m = string(allMice(iM));

    rowsM = (BTu.Mouse==m);
    if ~any(rowsM)
        continue;
    end

    Tm = BTu(rowsM, :);
    [~, idx] = max(Tm.DateTime);
    b = uint64(Tm.BlockUID(idx));

    trialUID = uint64(Tr.TrialUID((uint64(Tr.BlockUID)==b) & (Tr.Stimulus=="LightWater")));
    if isempty(trialUID)
        continue;
    end

    ntsCell = DS.QueryNTS(struct('Stimulus','LightWater','Design','LightWater','Mouse',m), UniExp.Flags.ZScore, 1:24);
    nts = ntsCell{1};
    inBlock = ismember(uint64(nts.TrialUID), trialUID);
    nts = nts(inBlock, :);
    if isempty(nts)
        continue;
    end

    nT = size(nts.TrialSignal, 2);
    if nT == nT_ref
        idx1 = idx1_ref;
    else
        xs2 = linspace(-3, 3, nT);
        [~, idx1] = min(abs(xs2 - 1));
    end

    v1 = nts.TrialSignal(:, idx1);

    cellU = unique(uint64(nts.CellUID));
    trialU = unique(uint64(nts.TrialUID));
    [~, cellIdx] = ismember(uint64(nts.CellUID), cellU);
    [~, trialIdx] = ismember(uint64(nts.TrialUID), trialU);

    Z = nan(numel(cellU), numel(trialU));
    lin = sub2ind(size(Z), cellIdx, trialIdx);
    Z = iAccumMean(Z, lin, v1);

    goodCell = all(isfinite(Z), 2);
    Z = Z(goodCell, :);

    [div, stdDist, dist0, nCell, nTrial] = iDivergenceFromMatrix(Z);

    out = [out; table(string(m), nCell, nTrial, stdDist, dist0, div, ...
        'VariableNames', {'Mouse','NCells','NTrials','StdPairwiseDist','CentroidToOrigin','Divergence'})]; %#ok<AGROW>
end
end

function [div, stdDist, dist0, nCell, nTrial] = iDivergenceFromMatrix(Z)
Z = double(Z);
Z = Z(:, all(isfinite(Z), 1));
nCell = size(Z,1);
nTrial = size(Z,2);
if nCell < 2 || nTrial < 2
    div = NaN;
    stdDist = NaN;
    dist0 = NaN;
    return;
end

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

function Z = iAccumMean(Z, linIdx, values)
[linU, ~, g] = unique(linIdx);
mu = splitapply(@(x) mean(x, 'omitnan'), values, g);
Z(linU) = mu;
end
