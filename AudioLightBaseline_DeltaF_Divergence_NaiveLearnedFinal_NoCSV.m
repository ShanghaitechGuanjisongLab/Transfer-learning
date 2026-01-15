%% AudioLightBaseline: DeltaF divergence for Naive AudioWater / Learned AudioWater / Final LightWater
% 使用当前“全细胞 DeltaF 散度算法”：
%   numerator = sqrt(mean_c( var_t( Z(c,t) ) ))
%   denominator = norm( mean_t(Z(:,t)) )
% 其中 Z 为 cell×trial，在 1s 采样点的信号值矩阵。
%
% 显著性：优先做配对（同鼠）比较：Friedman（三组）+ pairwise signrank。

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

%% --- 1) Load dataset
DS = TransferLearning.AudioLightBaseline();

conds = struct([]);
conds(1).Name = "Naive_AudioWater";
conds(1).Phase = "Naive";
conds(1).Stimulus = "AudioWater";
conds(1).Design = "AudioWater";

conds(2).Name = "Learned_AudioWater";
conds(2).Phase = "Learned";
conds(2).Stimulus = "AudioWater";
conds(2).Design = "AudioWater";

conds(3).Name = "Final_LightWater";
conds(3).Phase = "Final";
conds(3).Stimulus = "LightWater";
conds(3).Design = "LightWater";

%% --- 2) Compute per-mouse divergence for each condition (latest block per mouse)
rows = table();
for iC = 1:numel(conds)
    C = conds(iC);
    r = iComputeConditionDivergence(DS, C.Name, C.Phase, C.Design, C.Stimulus);
    rows = [rows; r]; %#ok<AGROW>
end
rows = sortrows(rows, ["Condition","Mouse"]);

assignin('base','AudioLightBaseline_DeltaF_NaiveLearnedFinal_Rows', rows);

%% --- 3) Paired stats across mice
wide = unstack(rows(:, ["Mouse","Condition","Divergence"]), "Divergence", "Condition");
assignin('base','AudioLightBaseline_DeltaF_NaiveLearnedFinal_Wide', wide);

cNames = string({conds.Name});

% Collect matrix for mice with all three conditions
hasAll = true(height(wide),1);
for k = 1:numel(cNames)
    if ~ismember(cNames(k), string(wide.Properties.VariableNames))
        hasAll(:) = false;
    else
        hasAll = hasAll & isfinite(wide.(cNames(k)));
    end
end

stats = table();
stats.Test = strings(0,1);
stats.N = nan(0,1);
stats.P = nan(0,1);

if any(hasAll)
    X = [wide.(cNames(1))(hasAll), wide.(cNames(2))(hasAll), wide.(cNames(3))(hasAll)];
    nSubj = size(X,1);

    % Friedman (paired, 3 conditions)
    try
        pF = friedman(X, 1, 'off');
    catch
        pF = NaN;
    end
    stats = [stats; table("Friedman_3groups", nSubj, pF, 'VariableNames', {'Test','N','P'})]; %#ok<AGROW>

    % Pairwise signrank (paired)
    pairs = [1 2; 1 3; 2 3];
    for iP = 1:size(pairs,1)
        a = pairs(iP,1);
        b = pairs(iP,2);
        xa = X(:,a);
        xb = X(:,b);
        try
            pSR = signrank(xa, xb);
        catch
            pSR = NaN;
        end
        stats = [stats; table("signrank_"+cNames(a)+"_vs_"+cNames(b), nSubj, pSR, 'VariableNames', {'Test','N','P'})]; %#ok<AGROW>
    end
else
    stats = [stats; table("Friedman_3groups", 0, NaN, 'VariableNames', {'Test','N','P'})]; %#ok<AGROW>
end

assignin('base','AudioLightBaseline_DeltaF_NaiveLearnedFinal_Stats', stats);

%% --- 4) Export
iWriteTableUNC(rows, outDirUNC, 'AudioLightBaseline_DeltaF_Divergence_NaiveLearnedFinal.csv');
iWriteTableUNC(stats, outDirUNC, 'AudioLightBaseline_DeltaF_Divergence_NaiveLearnedFinal_stats.csv');

fprintf('Wrote CSVs to %s\n', outDirUNC);

%% --- local functions
function out = iComputeConditionDivergence(DS, condName, phase, design, stimulus)
% Build block table (unique blocks), then pick latest block per mouse.
BT = DS.TableQuery(["Mouse","DateTime","BlockUID","Phase","Design"], Phase=phase, Design=design, Stimulus=stimulus);
BT.Mouse = string(BT.Mouse);
BT.Phase = string(BT.Phase);
BT.Design = string(BT.Design);
BTu = unique(BT(:, ["Mouse","DateTime","BlockUID","Phase","Design"]), 'rows');

Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);

xs = TransferLearning.Xs;
xsSec = seconds(xs);
[~, idx1_ref] = min(abs(xsSec - 1));
nT_ref = numel(xsSec);

out = table(string.empty(0,1), string.empty(0,1), uint64.empty(0,1), datetime.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
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
