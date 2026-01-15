%% All groups: DeltaF divergence + pairwise significance (paired if same DB)
% Groups requested:
%   - NaiveLight: pure-session Naive LightWater (merged from LightAudioBaseline + LAInterspersed)
%   - NaiveAudio: AudioLightBaseline, Phase=Naive,  Design=AudioWater, Stimulus=AudioWater
%   - LearnedAudio: AudioLightBaseline, Phase=Learned, Design=AudioWater, Stimulus=AudioWater
%   - TransferLight: AudioLightBaseline, Phase=Transfer, Design=LightWater, Stimulus=LightWater
%   - FinalLight: AudioLightBaseline, Phase=Final, Design=LightWater, Stimulus=LightWater
%
% Normalize: UniExp.Flags.DeltaF, F0Samples=1:24 (fixed)
%
% Divergence (current definition):
%   numerator = sqrt(mean_c( var_t( Z(c,t) ) ))
%   denominator = norm( mean_t(Z(:,t)) )
% where Z is cell×trial matrix at 1s.

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

%% --- 1) Load datasets
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

%% --- 2) Compute NaiveLight (merged LAB+LAI, pure session)
labPure = iFindPureNaiveLightWaterMice(LAB, excludeMice);
laiPure = iFindPureNaiveLightWaterMice(LAI, excludeMice);

rowsNaiveLight = table();
rowsNaiveLight = [rowsNaiveLight; iComputeNaiveLightWaterDivergence_DeltaF(LAB, labPure.Mouse, "LightAudioBaseline")];
rowsNaiveLight = [rowsNaiveLight; iComputeNaiveLightWaterDivergence_DeltaF(LAI, laiPure.Mouse, "LAInterspersed_v5")];
rowsNaiveLight = sortrows(rowsNaiveLight, ["DataSet","Mouse"]);

% Collapse to one row per mouse (if mouse appears in both DS, keep each as separate subject)
rowsNaiveLightOut = rowsNaiveLight;
rowsNaiveLightOut.Condition = repmat("NaiveLight", height(rowsNaiveLightOut), 1);
rowsNaiveLightOut.SourceDB = repmat("NaiveMerged", height(rowsNaiveLightOut), 1);

%% --- 3) Compute AudioLightBaseline groups (one row per mouse per condition)
conds = struct([]);
conds(1).Condition = "NaiveAudio";
conds(1).Phase = "Naive";
conds(1).Design = "AudioWater";
conds(1).Stimulus = "AudioWater";

conds(2).Condition = "LearnedAudio";
conds(2).Phase = "Learned";
conds(2).Design = "AudioWater";
conds(2).Stimulus = "AudioWater";

conds(3).Condition = "TransferLight";
conds(3).Phase = "Transfer";
conds(3).Design = "LightWater";
conds(3).Stimulus = "LightWater";

conds(4).Condition = "FinalLight";
conds(4).Phase = "Final";
conds(4).Design = "LightWater";
conds(4).Stimulus = "LightWater";

rowsALB = table();
for iC = 1:numel(conds)
    C = conds(iC);
    r = iComputeConditionDivergence_DeltaF(ALB, C.Condition, C.Phase, C.Design, C.Stimulus);
    rowsALB = [rowsALB; r]; %#ok<AGROW>
end
rowsALB.SourceDB = repmat("AudioLightBaseline", height(rowsALB), 1);

%% --- 4) Combine all rows
rowsNaiveLightOut = iNormalizeRows(rowsNaiveLightOut);
rowsALB = iNormalizeRows(rowsALB);
rowsAll = [rowsNaiveLightOut; rowsALB];
rowsAll = sortrows(rowsAll, ["Condition","Mouse"]);

assignin('base','AllGroups_DeltaF_Rows', rowsAll);

%% --- 5) Group summaries
summ = iSummarizeByCondition(rowsAll);
assignin('base','AllGroups_DeltaF_Summary', summ);

%% --- 6) Pairwise tests
pairs = [
    "NaiveLight"   "NaiveAudio";
    "NaiveLight"   "LearnedAudio";
    "NaiveLight"   "TransferLight";
    "NaiveLight"   "FinalLight";
    "NaiveAudio"   "LearnedAudio";
    "NaiveAudio"   "TransferLight";
    "NaiveAudio"   "FinalLight";
    "LearnedAudio" "TransferLight";
    "LearnedAudio" "FinalLight";
    "TransferLight" "FinalLight";
];

stats = table();
for iP = 1:size(pairs,1)
    a = pairs(iP,1);
    b = pairs(iP,2);
    stats = [stats; iPairwiseTest(rowsAll, a, b)]; %#ok<AGROW>
end
assignin('base','AllGroups_DeltaF_Pairwise', stats);

%% --- 7) Export
try
    if ~isfolder(outDirUNC)
        mkdir(outDirUNC);
    end
catch
end

iWriteTableUNC(summ, outDirUNC, 'AllGroups_DeltaF_Divergence_Summary.csv');
iWriteTableUNC(stats, outDirUNC, 'AllGroups_DeltaF_Divergence_Pairwise.csv');

fprintf('Wrote summary/pairwise CSVs to %s\n', outDirUNC);

%% --- local functions
function T = iNormalizeRows(T)
% Enforce a shared schema so we can concatenate across sources.
schema = [
    "SourceDB";
    "Condition";
    "DataSet";
    "Mouse";
    "BlockUID";
    "DateTime";
    "NCells";
    "NTrials";
    "StdCellTrial";
    "CentroidToOrigin";
    "Divergence"
];

for i = 1:numel(schema)
    v = schema(i);
    if ~ismember(v, string(T.Properties.VariableNames))
        switch v
            case {"SourceDB","Condition","DataSet","Mouse"}
                T.(v) = repmat("", height(T), 1);
            case "BlockUID"
                T.(v) = repmat(uint64(0), height(T), 1);
            case "DateTime"
                T.(v) = repmat(NaT, height(T), 1);
            otherwise
                T.(v) = nan(height(T), 1);
        end
    end
end

% Normalize types
T.SourceDB = string(T.SourceDB);
T.Condition = string(T.Condition);
T.DataSet = string(T.DataSet);
T.Mouse = string(T.Mouse);
if ~isa(T.BlockUID, 'uint64')
    T.BlockUID = uint64(T.BlockUID);
end
if ~isdatetime(T.DateTime)
    T.DateTime = datetime(T.DateTime);
end

T = T(:, cellstr(schema));
end

function out = iSummarizeByCondition(rowsAll)
conds = unique(string(rowsAll.Condition));
out = table();
for i = 1:numel(conds)
    c = conds(i);
    x = rowsAll.Divergence(string(rowsAll.Condition)==c);
    x = x(isfinite(x));
    out = [out; table(c, numel(x), mean(x), median(x), std(x), ...
        'VariableNames', {'Condition','N','Mean','Median','Std'})]; %#ok<AGROW>
end
out = sortrows(out, 'Condition');
end

function stat = iPairwiseTest(rowsAll, condA, condB)
A = rowsAll(string(rowsAll.Condition)==condA, :);
B = rowsAll(string(rowsAll.Condition)==condB, :);

% decide paired only if from same SourceDB (as requested)
sourceA = unique(string(A.SourceDB));
sourceB = unique(string(B.SourceDB));
canPair = (numel(sourceA)==1) && (numel(sourceB)==1) && (sourceA==sourceB);

x = A.Divergence;
y = B.Divergence;

method = "";
paired = false;
N = 0;
p = NaN;
z = NaN;
statistic = NaN;

if canPair
    % pair by Mouse
    [commonMice, ia, ib] = intersect(string(A.Mouse), string(B.Mouse), 'stable');
    xa = A.Divergence(ia);
    xb = B.Divergence(ib);
    ok = isfinite(xa) & isfinite(xb);
    xa = xa(ok);
    xb = xb(ok);
    N = numel(xa);
    if N > 0
        try
            [p, ~, s] = signrank(xa, xb);
            statistic = s.signedrank;
        catch
            p = NaN;
            statistic = NaN;
        end
        method = "signrank";
        paired = true;
    end
else
    xa = x(isfinite(x));
    xb = y(isfinite(y));
    N = min(numel(xa), numel(xb));
    if ~isempty(xa) && ~isempty(xb)
        try
            [p, ~, s] = ranksum(xa, xb);
            z = s.zval;
        catch
            p = NaN;
            z = NaN;
        end
        method = "ranksum";
        paired = false;
    end
end

stat = table(string(condA), string(condB), string(sourceA(1)), string(sourceB(1)), paired, N, method, p, z, statistic, ...
    'VariableNames', {'CondA','CondB','SourceA','SourceB','Paired','N','Test','P','RankSumZ','SignedRank'});
end

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

function out = iComputeNaiveLightWaterDivergence_DeltaF(DS, mice, dsName)
out = table(string.empty(0,1), string.empty(0,1), uint64.empty(0,1), datetime.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'DataSet','Mouse','BlockUID','DateTime','NCells','NTrials','StdCellTrial','CentroidToOrigin','Divergence'});
if isempty(mice)
    return;
end

xs = TransferLearning.Xs;
xsSec = seconds(xs);
[~, idx1_ref] = min(abs(xsSec - 1));
nT_ref = numel(xsSec);

BT = DS.TableQuery(["Mouse","DateTime","BlockUID","Phase","Design"], Phase="Naive");
BT.Mouse = string(BT.Mouse);
BTu = unique(BT(:, ["Mouse","DateTime","BlockUID","Phase","Design"]), 'rows');

Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);

for iM = 1:numel(mice)
    m = mice(iM);

    rowsB = (BTu.Mouse==m);
    if ~any(rowsB)
        continue;
    end
    bu = unique(uint64(BTu.BlockUID(rowsB)));

    % collect trialUIDs for all naive blocks for this mouse (LightWater only)
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

    q = struct('Phase','Naive','Stimulus','LightWater','Mouse',m,'BlockUID',bu);
    ntsCell = DS.QueryNTS(q, UniExp.Flags.DeltaF, 1:24);
    nts = ntsCell{1};
    nts = nts(ismember(uint64(nts.TrialUID), trialUID), :); % safety
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

    [div, stdCellTrial, dist0, nCell, nTrial] = iDivergenceFromMatrix(Z);

    % For merged-naive we don't have a single representative block.
    % Use placeholders that don't break integer/datetime types.
    out = [out; table(string(dsName), string(m), uint64(0), NaT, nCell, nTrial, stdCellTrial, dist0, div, ...
        'VariableNames', {'DataSet','Mouse','BlockUID','DateTime','NCells','NTrials','StdCellTrial','CentroidToOrigin','Divergence'})]; %#ok<AGROW>
end
end

function out = iComputeConditionDivergence_DeltaF(DS, condName, phase, design, stimulus)
BT = DS.TableQuery(["Mouse","DateTime","BlockUID","Phase","Design"], Phase=phase, Design=design, Stimulus=stimulus);
BT.Mouse = string(BT.Mouse);
BTu = unique(BT(:, ["Mouse","DateTime","BlockUID","Phase","Design"]), 'rows');

Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);

xs = TransferLearning.Xs;
xsSec = seconds(xs);
[~, idx1_ref] = min(abs(xsSec - 1));
nT_ref = numel(xsSec);

out = table(repmat(string(condName),0,1), string.empty(0,1), uint64.empty(0,1), datetime.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'Condition','Mouse','BlockUID','DateTime','NCells','NTrials','StdCellTrial','CentroidToOrigin','Divergence'});

if isempty(BTu)
    return;
end

mice = unique(BTu.Mouse);
for iM = 1:numel(mice)
    m = mice(iM);
    rowsM = (BTu.Mouse==m);
    if ~any(rowsM)
        continue;
    end
    Tm = BTu(rowsM, :);
    [~, idx] = max(Tm.DateTime);
    b = uint64(Tm.BlockUID(idx));
    dt = Tm.DateTime(idx);

    trialUID = uint64(Tr.TrialUID((uint64(Tr.BlockUID)==b) & (Tr.Stimulus==stimulus)));
    trialUID = unique(trialUID);
    if isempty(trialUID)
        continue;
    end

    q = struct('Phase',phase,'Design',design,'Stimulus',stimulus,'Mouse',m,'BlockUID',b);
    ntsCell = DS.QueryNTS(q, UniExp.Flags.DeltaF, 1:24);
    nts = ntsCell{1};
    nts = nts(ismember(uint64(nts.TrialUID), trialUID), :); % safety
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

    [div, stdCellTrial, dist0, nCell, nTrial] = iDivergenceFromMatrix(Z);

    out = [out; table(string(condName), string(m), b, dt, nCell, nTrial, stdCellTrial, dist0, div, ...
        'VariableNames', {'Condition','Mouse','BlockUID','DateTime','NCells','NTrials','StdCellTrial','CentroidToOrigin','Divergence'})]; %#ok<AGROW>
end
end

function [div, stdCellTrial, dist0, nCell, nTrial] = iDivergenceFromMatrix(Z)
Z = double(Z);
Z = Z(:, all(isfinite(Z), 1));
nCell = size(Z,1);
nTrial = size(Z,2);
if nCell < 2 || nTrial < 2
    div = NaN;
    stdCellTrial = NaN;
    dist0 = NaN;
    return;
end

cellVar = var(Z, 0, 2, 'omitnan');
stdCellTrial = sqrt(mean(cellVar, 'omitnan'));

centroid = mean(Z, 2, 'omitnan');
dist0 = norm(centroid, 2);
if dist0 <= 0 || ~isfinite(dist0)
    div = NaN;
else
    div = stdCellTrial / dist0;
end
end

function Z = iAccumMean(Z, linIdx, values)
[linU, ~, g] = unique(linIdx);
mu = splitapply(@(x) mean(x, 'omitnan'), values, g);
Z(linU) = mu;
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
