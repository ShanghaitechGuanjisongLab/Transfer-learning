%% Swarmchart: Naive merged vs Transfer (ACTIVE-CELLS only)
% 不依赖 CSV 回读；直接从 TransferLearning.m 的数据库工厂计算。
%
% Active cell definition (per-cell, QueryNTATS ZScore median):
%   max(0~1s) > mean(-3~0s) + 3*std(-3~0s)
% with baseline indices fixed to 1:24.

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

%% --- 1) Load datasets
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

%% --- 2) Find pure Naive LightWater mice (no AudioWater in same block)
labPure = iFindPureNaiveLightWaterMice(LAB, excludeMice);
laiPure = iFindPureNaiveLightWaterMice(LAI, excludeMice);

%% --- 3) Compute divergences (active-cell filtered)
rowsNaive = table();
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence_ActiveCells(LAB, labPure.Mouse, "LightAudioBaseline", baseIdx, respIdx)];
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence_ActiveCells(LAI, laiPure.Mouse, "LAInterspersed_v5", baseIdx, respIdx)];
rowsNaive = sortrows(rowsNaive, ["DataSet","Mouse"]);

rowsTransfer = iComputeTransferLightWaterDivergenceAllMice_ActiveCells(ALB, baseIdx, respIdx);

xNaive = rowsNaive.Divergence;
xTransfer = rowsTransfer.Divergence;
xNaive = xNaive(isfinite(xNaive));
xTransfer = xTransfer(isfinite(xTransfer));

%% --- 4) Plot swarmchart
f = figure('Color','w');
ax = axes(f);
hold(ax,'on');

try
    ax.Toolbar.Visible = 'off';
catch
end

x1 = ones(size(xNaive));
x2 = 2*ones(size(xTransfer));

swarmchart(ax, x1, xNaive, 18, 'filled');
swarmchart(ax, x2, xTransfer, 18, 'filled');

ax.XLim = [0.5 2.5];
ax.XTick = [1 2];
ax.XTickLabel = {sprintf('Naive merged (n=%d)', numel(xNaive)), sprintf('Transfer (n=%d)', numel(xTransfer))};
ylabel(ax, 'Divergence');
title(ax, 'Naive merged vs Transfer (ACTIVE cells, swarm)');
box(ax,'on');

%% --- 5) Export
try
    if ~isfolder(outDirUNC)
        mkdir(outDirUNC);
    end
catch
end

svgPath = fullfile(outDirUNC, 'NaiveMergedVsTransfer_Divergence_Swarmchart_ActiveCells.svg');
pngPath = fullfile(outDirUNC, 'NaiveMergedVsTransfer_Divergence_Swarmchart_ActiveCells.png');

try
    exportgraphics(f, svgPath, 'ContentType','vector');
    exportgraphics(f, pngPath, 'Resolution', 300);
    fprintf('Wrote: %s\n', svgPath);
    fprintf('Wrote: %s\n', pngPath);
catch ME
    warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local functions (copied from ActiveCells analysis script)
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

    ntsCell = DS.QueryNTS(struct('Phase','Naive','Stimulus','LightWater','Mouse',m,'BlockUID',bu), UniExp.Flags.ZScore, 1:24);
    nts = ntsCell{1};
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

    ntsCell = DS.QueryNTS(struct('Phase','Transfer','Design','LightWater','Stimulus','LightWater','Mouse',m,'BlockUID',b), UniExp.Flags.ZScore, 1:24);
    nts = ntsCell{1};
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

nCellsTotal = height(G);

nTime = size(A, 2);
if nTime < double(max(baseIdx))
    error('ActiveCells:NTATSLengthTooShort', 'NTATS length %d is shorter than baseline index max %d.', nTime, double(max(baseIdx)));
end

xs = linspace(-3, 3, nTime);
respMask = (xs >= 0) & (xs <= 1);
respIdx2 = find(respMask);
if isempty(respIdx2)
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
