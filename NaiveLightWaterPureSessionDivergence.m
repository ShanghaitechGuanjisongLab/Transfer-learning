%% Naive LightWater divergence for mice with pure LightWater sessions (no AudioWater in same block)
% 需求：
% 1) 在 LightAudioBaseline 和 LAInterspersed 数据库中，找出“Naive & LightWater trials 所属会话(block)
%    内不含任何 AudioWater trials”的鼠。
% 2) 对这些鼠的 Naive LightWater trials，使用 QueryNTS(..., UniExp.Flags.ZScore, 1:24)
%    取 1s 处的 z-score，构建 cell×trial 矩阵并计算 divergence：std(pdist)/||centroid||。
% 3) 对同一批鼠（能在 AudioLightBaseline 中找到的），计算 AudioLightBaseline 的 Transfer LightWater divergence。
% 4) 对比 Naive LightWater vs Transfer LightWater。

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

outDirUNC = "\\\\Data-Server-2\\个人数据\\张天夫\\202601";
excludeMice = string(["vtf0353"]);

%% --- 1) Load datasets (memoized handles are callable)
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

%% --- 2) Find mice whose Naive LightWater blocks contain no AudioWater trials
labPure = iFindPureNaiveLightWaterMice(LAB, excludeMice);
laiPure = iFindPureNaiveLightWaterMice(LAI, excludeMice);

% Audit: verify (block-level) that selected LAInterspersed pure blocks truly lack AudioWater
laiAudit = iAuditPureBlocks(LAI, laiPure.Mouse);
assignin('base','LAInterspersed_PureNaiveLightWater_Audit', laiAudit);

% Rule check: if a block lacks AudioWater, its Design should not contain "Auw"
labAudit = iAuditPureBlocks(LAB, labPure.Mouse);
labViol = iFindDesignViolationsNoAudioWater(LAB, labAudit);
laiViol = iFindDesignViolationsNoAudioWater(LAI, laiAudit);
assignin('base','LightAudioBaseline_PureNaiveLightWater_DesignViolations', labViol);
assignin('base','LAInterspersed_PureNaiveLightWater_DesignViolations', laiViol);

pureAll = [ ...
    addvars(labPure, repmat("LightAudioBaseline", height(labPure), 1), 'Before', 1, 'NewVariableNames', 'DataSet');
    addvars(laiPure, repmat("LAInterspersed", height(laiPure), 1), 'Before', 1, 'NewVariableNames', 'DataSet')
];

fprintf('\n=== Pure Naive LightWater mice (no AudioWater in same block) ===\n');
disp(pureAll);

fprintf('\n=== Audit (LAInterspersed): pure blocks stimulus check ===\n');
if ~isempty(laiAudit)
    disp(laiAudit(:, ["Mouse","BlockUID","HasAudioWater","Stimuli"]));
end

fprintf('\n=== Rule check: blocks without AudioWater but Design contains "Auw" ===\n');
if ~isempty(laiViol)
    disp(laiViol(:, ["Mouse","BlockUID","Design","Stimuli","HasAudioWater","ContainsAuw"]));
else
    fprintf('LAInterspersed: none.\n');
end
if ~isempty(labViol)
    disp(labViol(:, ["Mouse","BlockUID","Design","Stimuli","HasAudioWater","ContainsAuw"]));
else
    fprintf('LightAudioBaseline: none.\n');
end

%% --- 3) Compute Naive LightWater divergence in each dataset for these mice
rowsNaive = table();
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence(LAB, labPure.Mouse, "LightAudioBaseline")];
rowsNaive = [rowsNaive; iComputeNaiveLightWaterDivergence(LAI, laiPure.Mouse, "LAInterspersed")];

rowsNaive = sortrows(rowsNaive, ["DataSet","Mouse"]);
assignin('base','NaiveLightWater_PureSession_Divergence', rowsNaive);

%% --- 4) Compute Transfer LightWater divergence in AudioLightBaseline (all mice)
rowsTransfer = iComputeTransferLightWaterDivergenceAllMice(ALB);
assignin('base','TransferLightWater_Divergence_AudioLightBaseline_AllMice', rowsTransfer);

%% --- 5) Compare (unpaired)
joined = table(); % kept for backward compatibility; not used for unpaired stats
cmp = iUnpairedCompare(rowsNaive, rowsTransfer);
assignin('base','NaiveVsTransfer_Divergence_Unpaired', cmp);

fprintf('\n=== Naive LightWater divergence (pure session) ===\n');
if ~isempty(rowsNaive)
    grp = groupsummary(rowsNaive, 'DataSet', {@mean,@median,@numel}, 'Divergence');
    disp(grp);
end

fprintf('\n=== Transfer LightWater divergence (AudioLightBaseline; same mice) ===\n');
if ~isempty(rowsTransfer)
    fprintf('mean=%.4g, median=%.4g (n=%d mice)\n', mean(rowsTransfer.Divergence,'omitnan'), median(rowsTransfer.Divergence,'omitnan'), height(rowsTransfer));
end

fprintf('\n=== Unpaired comparison (ranksum) ===\n');
if ~isempty(cmp)
    disp(cmp);
end

%% --- 6) Export CSVs
iWriteTableUNC(rowsNaive, outDirUNC, 'NaiveLightWater_PureSession_Divergence.csv');
iWriteTableUNC(rowsTransfer, outDirUNC, 'TransferLightWater_Divergence_AudioLightBaseline_AllMice.csv');
iWriteTableUNC(laiAudit, outDirUNC, 'LAInterspersed_PureNaiveLightWater_Audit.csv');
iWriteTableUNC(laiViol, outDirUNC, 'LAInterspersed_PureNaiveLightWater_DesignViolations.csv');
iWriteTableUNC(labViol, outDirUNC, 'LightAudioBaseline_PureNaiveLightWater_DesignViolations.csv');
iWriteTableUNC(cmp, outDirUNC, 'NaiveVsTransfer_Divergence_Unpaired.csv');
fprintf('\nCSV export attempted to: %s\n', outDirUNC);

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

    % check each block for AudioWater trials
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

function audit = iAuditPureBlocks(DS, mice)
audit = table(string.empty(0,1), uint64.empty(0,1), false(0,1), string.empty(0,1), ...
    'VariableNames', ["Mouse","BlockUID","HasAudioWater","Stimuli"]);
if isempty(mice)
    return;
end

T = DS.TableQuery(["Mouse","BlockUID","Phase","Stimulus"], Phase="Naive", Stimulus="LightWater");
T.Mouse = string(T.Mouse);
Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);

for iM = 1:numel(mice)
    m = string(mice(iM));
    rowsM = (T.Mouse == m);
    if ~any(rowsM)
        continue;
    end
    bu = unique(uint64(T.BlockUID(rowsM)));
    for j = 1:numel(bu)
        b = bu(j);
        trB = (uint64(Tr.BlockUID) == b);
        stimU = unique(Tr.Stimulus(trB));
        hasAudio = any(stimU == "AudioWater");
        audit = [audit; table(string(m), uint64(b), hasAudio, strjoin(stimU, ","), ...
            'VariableNames', ["Mouse","BlockUID","HasAudioWater","Stimuli"])]; %#ok<AGROW>
    end
end

audit = sortrows(audit, ["Mouse","BlockUID"]);
end

function viol = iFindDesignViolationsNoAudioWater(DS, audit)
viol = table(string.empty(0,1), uint64.empty(0,1), string.empty(0,1), false(0,1), false(0,1), string.empty(0,1), ...
    'VariableNames', ["Mouse","BlockUID","Design","HasAudioWater","ContainsAuw","Stimuli"]);

if isempty(audit)
    return;
end

% Get Design per (Mouse, BlockUID) for Naive blocks
T = DS.TableQuery(["Mouse","BlockUID","Design","Phase"], Phase="Naive");
T.Mouse = string(T.Mouse);
T.Design = string(T.Design);
Tu = unique(T(:, ["Mouse","BlockUID","Design"]), 'rows');

keys = audit(:, ["Mouse","BlockUID"]);
keys.Mouse = string(keys.Mouse);
keys.BlockUID = uint64(keys.BlockUID);

J = innerjoin(keys, Tu, 'Keys', ["Mouse","BlockUID"]);
J = innerjoin(J, audit(:, ["Mouse","BlockUID","HasAudioWater","Stimuli"]), 'Keys', ["Mouse","BlockUID"]);

J.ContainsAuw = contains(string(J.Design), "Auw", 'IgnoreCase', true);
viol = J(~J.HasAudioWater & J.ContainsAuw, :);
viol = sortrows(viol, ["Mouse","BlockUID"]);
end

function iWriteTableUNC(T, outDirUNC, fileName)
% Best-effort writer: avoids failing whole script if a file is locked on UNC.
try
    writetable(T, fullfile(outDirUNC, fileName));
catch ME
    % If locked/permission denied, retry with a timestamped filename.
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

    % all Naive blocks for this mouse (we will include all LightWater trials across these blocks)
    rowsB = (BTu.Mouse==m) & (BTu.Phase=="Naive");
    if ~any(rowsB)
        continue;
    end
    bu = unique(uint64(BTu.BlockUID(rowsB)));

    % collect trialUID for LightWater in these blocks
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

    % time index
    nT = size(nts.TrialSignal, 2);
    if nT == nT_ref
        idx1 = idx1_ref;
    else
        xs2 = linspace(-3, 3, nT);
        [~, idx1] = min(abs(xs2 - 1));
    end

    v1 = nts.TrialSignal(:, idx1);

    % pivot cell × trial
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

    % use latest Transfer LightWater block
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

function cmp = iUnpairedCompare(rowsNaive, rowsTransfer)
cmp = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', ["Group","N_Naive","N_Transfer","Mean_Naive","Mean_Transfer","P_RankSum"]);
if isempty(rowsNaive) || isempty(rowsTransfer)
    return;
end

groups = unique(rowsNaive.DataSet);
for iG = 1:numel(groups)
    g = string(groups(iG));
    x = rowsNaive.Divergence(rowsNaive.DataSet==g);
    y = rowsTransfer.Divergence;
    x = x(isfinite(x));
    y = y(isfinite(y));
    if isempty(x) || isempty(y)
        p = NaN;
    else
        p = ranksum(x, y);
    end
    cmp = [cmp; table(string(g), numel(x), numel(y), mean(x,'omitnan'), mean(y,'omitnan'), p, ...
        'VariableNames', ["Group","N_Naive","N_Transfer","Mean_Naive","Mean_Transfer","P_RankSum"])]; %#ok<AGROW>
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
