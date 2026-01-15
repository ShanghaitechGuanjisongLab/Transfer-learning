%% AudioLightBaseline divergence analysis (DeltaF only at 1s; no z-score)
% 与 AudioLightBaselineDivergenceAnalysis.m 相同的 divergence 定义，但不做 z-score：
% - 直接用每回合 1s 的 DeltaF 作为高维点坐标。
% - 仍然用 Learned AudioWater 的 trial-level QueryNTS 来确定 baseline cell 列表，
%   并且对每个 condition 只保留“该 condition 下每个 trial 都有值”的 cells。

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

nT_ref = numel(xsSec);
baseMask_ref = (xsSec >= -3) & (xsSec < 0);
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
BTu = unique(BT(:, ["Mouse","DateTime","BlockUID","Phase","Design"]), 'rows');

mice = unique(BTu.Mouse);

%% --- 4) Main loop per mouse
rowsOut = table();
Trials = AL.Trials;
Trials.Stimulus = string(Trials.Stimulus);

for iM = 1:numel(mice)
    m = mice(iM);

    % 4.1 Find Learned block to define baseline cell list
    baseRow = iPickBlock(BTu, m, "Learned", "AudioWater");
    if isempty(baseRow)
        continue;
    end

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

    nT = size(ntsLearn.TrialSignal, 2);
    [~, idx1] = iTimeIndices(nT, nT_ref, baseMask_ref, idx1_ref);

    % baseline cell list
    [~, cellB] = findgroups(uint64(ntsLearn.CellUID));

    % 4.2 For each condition compute divergence using DeltaF@1s
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

        % only cells that exist in learned baseline list
        inBaseCell = ismember(uint64(nts.CellUID), cellB);
        nts = nts(inBaseCell, :);
        if isempty(nts)
            continue;
        end

        v1 = nts.TrialSignal(:, idx1);

        % Pivot: cell × trial
        cellU = cellB;
        trialU = unique(uint64(nts.TrialUID));
        [~, cellIdx] = ismember(uint64(nts.CellUID), cellU);
        [~, trialIdx] = ismember(uint64(nts.TrialUID), trialU);

        Z = nan(numel(cellU), numel(trialU));
        lin = sub2ind(size(Z), cellIdx, trialIdx);
        Z = iAccumMean(Z, lin, v1);

        goodCell = all(isfinite(Z), 2);
        Z = Z(goodCell, :);

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
assignin('base','AudioLightBaseline_Divergence_ByMouse_DeltaFOnly', rowsOut);

%% --- 5) Summary + stats
condNames = string({condDef.Name});

miceU = unique(rowsOut.Mouse);
D = nan(numel(miceU), numel(condNames));

for iM = 1:numel(miceU)
    m = miceU(iM);
    for iC = 1:numel(condNames)
        c = condNames(iC);
        r = rowsOut.Mouse==m & rowsOut.Condition==c;
        if any(r)
            D(iM,iC) = rowsOut.Divergence(find(r,1,'first'));
        end
    end
end

complete = all(isfinite(D), 2);
D2 = D(complete, :);

fprintf('\n=== AudioLightBaseline Divergence (DeltaF@1s; std(pairwise euclid dist) / ||centroid||) ===\n');
for iC = 1:numel(condNames)
    x = D2(:,iC);
    fprintf('%-20s: mean=%.4g, median=%.4g (n=%d mice)\n', condNames(iC), mean(x,'omitnan'), median(x,'omitnan'), numel(x));
end

if size(D2,1) >= 3
    pF = friedman(D2, 1, 'off');
    fprintf('\n[Friedman across 4 conditions] p=%.4g (n=%d mice)\n', pF, size(D2,1));

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
outCsv = fullfile(outDirUNC, 'AudioLightBaseline_Divergence_ByMouse_DeltaFOnly.csv');
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
[~, idx] = max(T.DateTime);
row = T(idx, :);
end

function trialUID = iTrialUIDByBlock(Trials, blockUID, stimulus)
rows = (uint64(Trials.BlockUID) == uint64(blockUID)) & (string(Trials.Stimulus) == stimulus);
trialUID = uint64(Trials.TrialUID(rows));
end

function [baseCols, idx1] = iTimeIndices(nT, nT_ref, baseMask_ref, idx1_ref)
if nT == nT_ref
    baseCols = find(baseMask_ref); %#ok<NASGU>
    idx1 = idx1_ref;
else
    xs = linspace(-3, 3, nT);
    baseCols = find((xs >= -3) & (xs < 0)); %#ok<NASGU>
    [~, idx1] = min(abs(xs - 1));
end
end

function Z = iAccumMean(Z, linIdx, values)
[linU, ~, g] = unique(linIdx);
mu = splitapply(@(x) mean(x, 'omitnan'), values, g);
Z(linU) = mu;
end

function [pAdj, order] = iHolmAdjust(p)
p = p(:);
[ps, order] = sort(p, 'ascend');
m = numel(p);
psAdj = nan(size(ps));
for i = 1:m
    psAdj(i) = min(1, (m - i + 1) * ps(i));
end
for i = 2:m
    psAdj(i) = max(psAdj(i), psAdj(i-1));
end
pAdj = nan(size(p));
pAdj(order) = psAdj;
end