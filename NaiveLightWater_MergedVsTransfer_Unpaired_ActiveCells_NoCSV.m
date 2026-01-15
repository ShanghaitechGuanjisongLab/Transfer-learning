%% Merge Naive (LAInterspersed v5 + LightAudioBaseline) vs Transfer (AudioLightBaseline)
% Active-cell filtered divergence (no CSV readback).
%
% Active cell definition (per-cell, based on QueryNTATS ZScore median):
%   respMax(0~1s) > baseMean(-3~0s) + 3*baseStd(-3~0s)
% where baseline indices are fixed to 1:24 (per requirement).
%
% Divergence definition (per-mouse):
%   points = trials; dimensions = (active) cells
%   divergence = std( ||point - centroid||_2 ) / ||centroid||_2

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

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
excludeMice = string(["vtf0353"]);

% Active-cell criterion windows (8 Hz, -3~3 s => 48 samples)
baseIdx = uint16(1:24);        % -3~0 s
respIdx = uint16(25:32);       % 0~1 s

%% --- 1) Load datasets (from TransferLearning.m factories)
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

%% --- 2) Find pure Naive LightWater mice (no AudioWater in same block)
labPure = iFindPureNaiveLightWaterMice(LAB, excludeMice);
laiPure = iFindPureNaiveLightWaterMice(LAI, excludeMice);

%% --- 3) Compute divergence (active-cell filtered)
rowsNaive = table();
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence_ActiveCells(LAB, labPure.Mouse, "LightAudioBaseline", baseIdx, respIdx)];
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence_ActiveCells(LAI, laiPure.Mouse, "LAInterspersed_v5", baseIdx, respIdx)];
rowsNaive = sortrows(rowsNaive, ["DataSet","Mouse"]);

rowsTransfer = iComputeTransferLightWaterDivergenceAllMice_ActiveCells(ALB, baseIdx, respIdx);

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

assignin('base','NaiveMergedVsTransfer_ActiveCells_NoCSV_Summary', summary);
assignin('base','NaiveMerged_ActiveCells_NoCSV_Rows', rowsNaive);
assignin('base','Transfer_ActiveCells_NoCSV_Rows', rowsTransfer);

fprintf("Merged Naive vs Transfer (ACTIVE-CELLS, unpaired ranksum): p=%.6g (Naive n=%d, Transfer n=%d)\n", p, numel(x), numel(y));

%% --- 5) Export (results only)
iWriteTableUNC(summary, outDirUNC, 'NaiveMergedVsTransfer_Divergence_Unpaired_NoCSV_ActiveCells.csv');

%% --- local functions
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

function out = iComputeNaiveLightWaterDivergence_ActiveCells(DS, mice, dsName, baseIdx, respIdx)
out = table(string.empty(0,1), string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'DataSet','Mouse','NCellsTotal','NCellsActive','NCellsUsed','NTrials','StdDist','CentroidToOrigin','Divergence'});
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

    [activeUID, nCellsTotal, nCellsActive] = iFindActiveCellsByNTATS(DS, "Naive", "", m, bu, baseIdx, respIdx);

    % Query as narrowly as possible: Phase + Mouse + BlockUID + Stimulus
    ntsCell = DS.QueryNTS(struct('Phase','Naive','Stimulus','LightWater','Mouse',m,'BlockUID',bu), UniExp.Flags.ZScore, 1:24);
    nts = ntsCell{1};
    % Optional safety filter (should be a no-op if query is correct)
    nts = nts(ismember(uint64(nts.TrialUID), trialUID), :);
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

    keepActive = ismember(cellU, activeUID);
    Z = Z(keepActive, :);

    goodCell = all(isfinite(Z), 2);
    Z = Z(goodCell, :);

    [div, stdDist, dist0, nCellUsed, nTrial] = iDivergenceFromMatrix(Z);

    out = [out; table(string(dsName), string(m), nCellsTotal, nCellsActive, nCellUsed, nTrial, stdDist, dist0, div, ...
        'VariableNames', {'DataSet','Mouse','NCellsTotal','NCellsActive','NCellsUsed','NTrials','StdDist','CentroidToOrigin','Divergence'})]; %#ok<AGROW>
end
end

function out = iComputeTransferLightWaterDivergenceAllMice_ActiveCells(DS, baseIdx, respIdx)
out = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'Mouse','NCellsTotal','NCellsActive','NCellsUsed','NTrials','StdDist','CentroidToOrigin','Divergence'});

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
    trialUID = unique(trialUID);
    if isempty(trialUID)
        continue;
    end

    [activeUID, nCellsTotal, nCellsActive] = iFindActiveCellsByNTATS(DS, "Transfer", "LightWater", m, b, baseIdx, respIdx);

    % Query as narrowly as possible: Phase + Design + Mouse + BlockUID + Stimulus
    ntsCell = DS.QueryNTS(struct('Phase','Transfer','Design','LightWater','Stimulus','LightWater','Mouse',m,'BlockUID',b), UniExp.Flags.ZScore, 1:24);
    nts = ntsCell{1};
    % Optional safety filter (should be a no-op if query is correct)
    nts = nts(ismember(uint64(nts.TrialUID), trialUID), :);
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

    keepActive = ismember(cellU, activeUID);
    Z = Z(keepActive, :);

    goodCell = all(isfinite(Z), 2);
    Z = Z(goodCell, :);

    [div, stdDist, dist0, nCellUsed, nTrial] = iDivergenceFromMatrix(Z);

    out = [out; table(string(m), nCellsTotal, nCellsActive, nCellUsed, nTrial, stdDist, dist0, div, ...
        'VariableNames', {'Mouse','NCellsTotal','NCellsActive','NCellsUsed','NTrials','StdDist','CentroidToOrigin','Divergence'})]; %#ok<AGROW>
end
end

function [activeUID, nCellsTotal, nCellsActive] = iFindActiveCellsByNTATS(DS, phase, design, mouse, blockUID, baseIdx, respIdx)
% Active cells are computed from QueryNTATS ZScore median within the selected block(s).
% Baseline indices are fixed to 1:24 as required. Response window is 0~1s.

q = struct('Phase',string(phase),'Stimulus','LightWater','Mouse',string(mouse),'BlockUID',blockUID);
if strlength(string(design))>0
    q.Design = string(design);
end
G = DS.QueryNTATS(q, UniExp.Flags.ZScore, uint16(1:24), UniExp.Flags.Median);
nt = G.NTATS;
if isa(nt, 'MATLAB.DataTypes.NDTable')
    A = nt.Data;
else
    A = nt;
end

% A: nCell x nTime
nCellsTotal = height(G);

nTime = size(A, 2);
if nTime < double(max(baseIdx))
    error('ActiveCells:NTATSLengthTooShort', 'NTATS length %d is shorter than baseline index max %d.', nTime, double(max(baseIdx)));
end

% Response indices: map 0~1 s within the NTATS time axis.
xs = linspace(-3, 3, nTime);
respMask = (xs >= 0) & (xs <= 1);
respIdx2 = find(respMask);
if isempty(respIdx2)
    % Fallback: use nearest samples to [0,1]
    [~, i0] = min(abs(xs - 0));
    [~, i1] = min(abs(xs - 1));
    respIdx2 = min(i0,i1):max(i0,i1);
end

baseMean = mean(A(:, double(baseIdx)), 2, 'omitnan');
baseStd = std(A(:, double(baseIdx)), 0, 2, 'omitnan');
respMax = max(A(:, respIdx2), [], 2, 'omitnan');

activeMask = respMax > (baseMean + 3*baseStd);
activeUID = uint64(G.CellUID(activeMask));
nCellsActive = numel(activeUID);
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

cellVar = var(Z, 0, 2, 'omitnan');
stdDist = sqrt(mean(cellVar, 'omitnan'));

centroid = mean(Z, 2, 'omitnan');
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
