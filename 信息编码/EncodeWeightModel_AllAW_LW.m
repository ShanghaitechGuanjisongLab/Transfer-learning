%% EncodeWeightModel_AllAW_LW.m
% GLM encoding model on ALL AudioWater + LightWater data (all blocks).
%
% Task variables (per trial):
%   1. choice : hit(1) vs miss(0)
%   2. cue    : LightWater(1) vs AudioWater(0)
%   3. perf   : current block hit rate (Performance, continuous 0-1)
%
% Model per cell per time point (Gaussian GLM / linear regression):
%   activity(t) = b0 + b_choice*choice + b_cue*cue + b_perf*perf
%
% Outputs (reference: Runyan et al. 2017, Nature, Fig 2b/c):
%   1. per-cell per-time-point regression weights for each task variable
%      (selectivity) -> weight heatmaps + mean weight time courses
%   2. model-predicted single-neuron activity time course vs actual,
%      split by condition (hit/miss) -> example-neuron PSTH fits

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
rng(42);

%% 1. Load dataset and time axis
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);

tMaskFull  = (xs >= -1) & (xs <= 1);
tMaskTrain = (xs >= 0) & (xs <= 1);
tIdxFull   = find(tMaskFull);
tIdxTrain  = find(tMaskTrain);
tIdxTrainInFull = find(ismember(tIdxFull, tIdxTrain));
nTfull  = numel(tIdxFull);
nTtrain = numel(tIdxTrain);

fprintf('=== GLM encoding model: all AudioWater + LightWater ===\n');
fprintf('Training window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxTrain(1)), xs(tIdxTrain(end)), nTtrain);
fprintf('Heatmap window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxFull(1)), xs(tIdxFull(end)), nTfull);

%% 2. Blocks table (BlockUID -> Performance)
Blk = DS.Blocks;
Blk.BlockUID = uint64(Blk.BlockUID);
Blk.Design = string(Blk.Design);
Blk.Performance = double(Blk.Performance);

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
miceAll = unique(DT.Mouse);

%% 3. Per-mouse data loading (all AW / LW blocks, no phase filter)
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n========== Data loading ==========\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    allRaw = table();
    for stim = ["AudioWater", "LightWater"]
        try
            resp = DS.QueryNTS(struct('Mouse',m,'Stimulus',stim), ...
                UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
            if ~isempty(resp) && ~isempty(resp{1})
                tbl = resp{1};
                tbl.Cue = repmat(double(stim == "LightWater"), height(tbl), 1);
                bu = uint64(tbl.BlockUID);
                perf = arrayfun(@(b) Blk.Performance(find(Blk.BlockUID == b, 1)), bu);
                tbl.Perf = perf;
                allRaw = [allRaw; tbl];
            end
        catch
        end
    end
    if isempty(allRaw) || ~ismember('TrialSignal', string(allRaw.Properties.VariableNames))
        continue;
    end
    % keep trials with valid behavior and performance
    allRaw = allRaw(~isnan(allRaw.Behavior) & ~isnan(allRaw.Perf), :);
    if isempty(allRaw); continue; end

    cellUIDs = uint64(unique(allRaw.CellUID));
    nCell = numel(cellUIDs);
    if nCell < 5; continue; end

    [X, yChoice, yCue, yPerf] = iBuildTrialMatrixFull(allRaw, cellUIDs);
    if isempty(X); continue; end
    X = X(:, :, tIdxFull);
    nTr = size(X, 1);
    if sum(yChoice==1) < 2 || sum(yChoice==0) < 2 || sum(yCue==0) < 2 || sum(yCue==1) < 2
        continue;
    end

    % ---- GLM weights per cell per time point ----
    W0 = nan(nCell, nTfull);
    WChoice = nan(nCell, nTfull);
    WCue    = nan(nCell, nTfull);
    WPerf   = nan(nCell, nTfull);
    PChoice = nan(nCell, nTfull);
    PCue    = nan(nCell, nTfull);
    PPerf   = nan(nCell, nTfull);
    MiChoice = nan(nCell, nTfull);
    MiCue    = nan(nCell, nTfull);
    MiPerf   = nan(nCell, nTfull);
    nBinsMi = max(3, min(8, round(sqrt(nTr)/2)*2));
    yPerfBin = double(yPerf >= median(yPerf));   % median split for MI
    for iC = 1:nCell
        for iT = 1:nTfull
            act = squeeze(X(:, iC, iT));
            if all(isnan(act)) || range(act) == 0; continue; end
            MiChoice(iC,iT) = iPtCorrectedMI(act, yChoice, nBinsMi);
            MiCue(iC,iT)    = iPtCorrectedMI(act, yCue, nBinsMi);
            MiPerf(iC,iT)   = iPtCorrectedMI(act, yPerfBin, nBinsMi);
            try
                [b, ~, st] = glmfit([yChoice, yCue, yPerf], act, 'normal');
                W0(iC,iT) = b(1);
                WChoice(iC,iT) = b(2);
                WCue(iC,iT)    = b(3);
                WPerf(iC,iT)   = b(4);
                PChoice(iC,iT) = st.p(2);
                PCue(iC,iT)    = st.p(3);
                PPerf(iC,iT)   = st.p(4);
            catch
            end
        end
    end

    nUsed = nUsed + 1;
    res = struct();
    res.Mouse = m;
    res.CellUIDs = cellUIDs;
    res.NCells = nCell;
    res.NTrials = nTr;
    res.X = X;                       % nTr x nCell x nTfull (training-window mean for pred)
    res.yChoice = yChoice;
    res.yCue = yCue;
    res.yPerf = yPerf;
    res.W0 = W0; res.WChoice = WChoice; res.WCue = WCue; res.WPerf = WPerf;
    res.PChoice = PChoice; res.PCue = PCue; res.PPerf = PPerf;
    res.MiChoice = MiChoice; res.MiCue = MiCue; res.MiPerf = MiPerf;
    res.TimeVec = xs(tIdxFull);
    resAll{nUsed} = res;
    fprintf('  %s: %d cells, %d trials (H%d/M%d, AW%d/LW%d, %d blocks)\n', ...
        m, nCell, nTr, sum(yChoice==1), sum(yChoice==0), ...
        sum(yCue==0), sum(yCue==1), numel(unique(uint64(allRaw.BlockUID))));
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 4. Output 1: weight heatmaps (selectivity) + mean weight time courses
tVec = xs(tIdxFull);
tTrain = xs(tIdxTrain);

% --- pooled weight matrices (cells x time), sorted by peak |weight| time ---
% Only keep cells with a significant weight (uncorrected p<0.05 at any
% training-window time point) for the corresponding task variable.
% choice weights
allWc = []; allWcMouse = []; allWcPk = [];
allWu = []; allWuMouse = []; allWuPk = [];   % cue
allWp = []; allWpMouse = []; allWpPk = [];   % perf
for i = 1:nValid
    r = resAll{i};
    for c = 1:r.NCells
        wc = r.WChoice(c, :); wu = r.WCue(c, :); wp = r.WPerf(c, :);
        sc = any(r.PChoice(c, tIdxTrainInFull) < 0.05, 2);
        su = any(r.PCue(c,    tIdxTrainInFull) < 0.05, 2);
        sp = any(r.PPerf(c,   tIdxTrainInFull) < 0.05, 2);
        [~, pc] = max(abs(wc(tIdxTrainInFull)), [], 'omitnan');
        [~, pu] = max(abs(wu(tIdxTrainInFull)), [], 'omitnan');
        [~, pp] = max(abs(wp(tIdxTrainInFull)), [], 'omitnan');
        if sc && ~isnan(pc); allWc = [allWc; wc]; allWcMouse = [allWcMouse; string(r.Mouse)]; allWcPk = [allWcPk; tTrain(pc)]; end %#ok<AGROW>
        if su && ~isnan(pu); allWu = [allWu; wu]; allWuMouse = [allWuMouse; string(r.Mouse)]; allWuPk = [allWuPk; tTrain(pu)]; end %#ok<AGROW>
        if sp && ~isnan(pp); allWp = [allWp; wp]; allWpMouse = [allWpMouse; string(r.Mouse)]; allWpPk = [allWpPk; tTrain(pp)]; end %#ok<AGROW>
    end
end
fprintf('Significant cells in heatmap (uncorrected p<0.05): Choice=%d, Cue=%d, Performance=%d\n', ...
    size(allWc,1), size(allWu,1), size(allWp,1));
[~, oc] = sort(allWcPk, 'descend'); allWc = allWc(oc,:); allWcMouse = allWcMouse(oc);
[~, ou] = sort(allWuPk, 'descend'); allWu = allWu(ou,:); allWuMouse = allWuMouse(ou);
[~, op] = sort(allWpPk, 'descend'); allWp = allWp(op,:); allWpMouse = allWpMouse(op);

fW = figure('Name','Task-variable regression weights (peak-sign split)','Color','w', ...
    'Position',[80 60 1500 920]);
tl = tiledlayout(fW, 3, 2, 'TileSpacing','compact', 'Padding','compact');
vars = {allWc, 'Choice'; allWp, 'Performance'; allWu, 'Cue'};
posName = {'hit','high perf','Light '};
negName = {'miss','low perf','Audio '};
for p = 1:3
    M = vars{p,1}; lab = vars{p,2};
    nC = size(M,1);
    % Split cells by the sign of the weight at the time of max |weight|
    % (training window). Peak-positive cells -> red panel, peak-negative -> blue.
    [~, pk] = max(abs(M(:, tIdxTrainInFull)), [], 2);
    lin = sub2ind(size(M), (1:nC)', tIdxTrainInFull(pk));
    pkVal = M(lin);
    redCells = pkVal > 0;
    Mred = M(redCells, :);
    Mblu = M(~redCells, :);
    mx = max(abs(M(:)), [], 'omitnan'); if mx <= 0; mx = 0.05; end
    % --- red panel: cells whose peak |weight| is positive (full signed trace) ---
    ax = nexttile(tl);
    imagesc(ax, tVec, 1:size(Mred,1), Mred);
    colormap(ax, iDivergingCmap()); caxis(ax, [-mx mx]);
    cb = colorbar(ax); cb.FontSize = 9; cb.Label.String = 'Regression weight';
    cb.Label.FontSize = 10; cb.Label.FontWeight = 'bold';
    ylabel(ax, 'Cell #');
    title(ax, sprintf('%s: %s  (N=%d)', lab, posName{p}, size(Mred,1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, 0, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    ax.FontSize = 8; box(ax, 'off');
    % --- blue panel: cells whose peak |weight| is negative (full signed trace) ---
    ax2 = nexttile(tl);
    imagesc(ax2, tVec, 1:size(Mblu,1), Mblu);
    colormap(ax2, iDivergingCmap()); caxis(ax2, [-mx mx]);
    cb2 = colorbar(ax2); cb2.FontSize = 9; cb2.Label.String = 'Regression weight';
    cb2.Label.FontSize = 10; cb2.Label.FontWeight = 'bold';
    if p == 3; xlabel(ax2, 'Time (s)'); end
    title(ax2, sprintf('%s: %s  (N=%d)', lab, negName{p}, size(Mblu,1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax2, 0, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    ax2.FontSize = 8; box(ax2, 'off');
end

% --- mean weight time course +/- SEM ---
meanWc = zeros(nValid, nTfull); meanWu = zeros(nValid, nTfull); meanWp = zeros(nValid, nTfull);
for i = 1:nValid
    r = resAll{i};
    meanWc(i,:) = mean(r.WChoice, 1, 'omitnan');
    meanWu(i,:) = mean(r.WCue,    1, 'omitnan');
    meanWp(i,:) = mean(r.WPerf,   1, 'omitnan');
end
fM = figure('Name','Mean task weights','Color','w', 'Position',[200 200 620 380]);
ax = axes(fM); hold(ax,'on');
cols = {[0.85 0.33 0.10], [0.10 0.45 0.70], [0.30 0.60 0.20]};
labs = {'Choice','Cue','Performance'};
mnC = mean(meanWc,1); seC = std(meanWc,0,1)/sqrt(nValid);
mnU = mean(meanWu,1); seU = std(meanWu,0,1)/sqrt(nValid);
mnP = mean(meanWp,1); seP = std(meanWp,0,1)/sqrt(nValid);
errorbar(ax, tVec, mnC, seC, '-o', 'Color', cols{1}, 'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', cols{1});
errorbar(ax, tVec, mnU, seU, '-o', 'Color', cols{2}, 'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', cols{2});
errorbar(ax, tVec, mnP, seP, '-o', 'Color', cols{3}, 'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', cols{3});
hold(ax,'off');
xlabel(ax, 'Time from stimulus (s)'); ylabel(ax, 'Regression weight');
title(ax, 'Mean GLM weights (choice / cue / performance)', 'FontSize', 9, 'FontWeight', 'normal');
legend(ax, labs, 'Location', 'northwest', 'Box', 'off');
xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
box(ax, 'off');

% --- mean |weight| time course over significant cells (+/- SEM across mice) ---
absWc = zeros(nValid, nTfull); absWu = zeros(nValid, nTfull); absWp = zeros(nValid, nTfull);
for i = 1:nValid
    r = resAll{i};
    ti = tIdxTrainInFull;
    sc = any(r.PChoice(:, ti) < 0.05, 2);
    su = any(r.PCue(:,    ti) < 0.05, 2);
    sp = any(r.PPerf(:,   ti) < 0.05, 2);
    absWc(i,:) = mean(abs(r.WChoice(sc,:)), 1, 'omitnan');
    absWu(i,:) = mean(abs(r.WCue(su,:)),    1, 'omitnan');
    absWp(i,:) = mean(abs(r.WPerf(sp,:)),   1, 'omitnan');
end
fAbs = figure('Name','Mean |weight| time courses','Color','w', 'Position',[220 200 1020 320]);
tleA = tiledlayout(fAbs, 1, 3, 'TileSpacing','compact', 'Padding','compact');
colsA = {[0.85 0.33 0.10], [0.30 0.60 0.20], [0.10 0.45 0.70]};  % Choice, Performance, Cue
labsA = {'Choice','Performance','Cue'};
mnA = {mean(absWc,1), mean(absWp,1), mean(absWu,1)};
seA = {std(absWc,0,1)/sqrt(nValid), std(absWp,0,1)/sqrt(nValid), std(absWu,0,1)/sqrt(nValid)};
for q = 1:3
    ax = nexttile(tleA); hold(ax,'on');
    errorbar(ax, tVec, mnA{q}, seA{q}, '-o', 'Color', colsA{q}, 'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', colsA{q});
    hold(ax,'off');
    xlabel(ax, 'Time from stimulus (s)');
    ylabel(ax, 'Mean |regression weight|');
    title(ax, labsA{q}, 'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
    box(ax, 'off'); ax.FontSize = 8;
end

% --- mean MI time course over significant cells (+/- SEM across mice) ---
miC = zeros(nValid, nTfull); miU = zeros(nValid, nTfull); miP = zeros(nValid, nTfull);
for i = 1:nValid
    r = resAll{i};
    ti = tIdxTrainInFull;
    sc = any(r.PChoice(:, ti) < 0.05, 2);
    su = any(r.PCue(:,    ti) < 0.05, 2);
    sp = any(r.PPerf(:,   ti) < 0.05, 2);
    miC(i,:) = mean(r.MiChoice(sc,:), 1, 'omitnan');
    miU(i,:) = mean(r.MiCue(su,:),    1, 'omitnan');
    miP(i,:) = mean(r.MiPerf(sp,:),   1, 'omitnan');
end
fMi = figure('Name','Mean MI time courses','Color','w', 'Position',[220 200 1020 320]);
tleMi = tiledlayout(fMi, 1, 3, 'TileSpacing','compact', 'Padding','compact');
colsMi = {[0.85 0.33 0.10], [0.30 0.60 0.20], [0.10 0.45 0.70]};  % Choice, Performance, Cue
labsMi = {'Choice','Performance','Cue'};
mnMi = {mean(miC,1), mean(miP,1), mean(miU,1)};
seMi = {std(miC,0,1)/sqrt(nValid), std(miP,0,1)/sqrt(nValid), std(miU,0,1)/sqrt(nValid)};
for q = 1:3
    ax = nexttile(tleMi); hold(ax,'on');
    errorbar(ax, tVec, mnMi{q}, seMi{q}, '-o', 'Color', colsMi{q}, 'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', colsMi{q});
    hold(ax,'off');
    xlabel(ax, 'Time from stimulus (s)');
    ylabel(ax, 'Mean MI (bits)');
    title(ax, labsMi{q}, 'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
    box(ax, 'off'); ax.FontSize = 8;
    yt = get(ax, 'YTick');
    ax.YTickLabel = arrayfun(@(v) sprintf('%.3f', v), yt, 'UniformOutput', false);
end

% Save weights (output 1) to a .mat
wtSave = fullfile(thisDir, 'EncodeWeightModel_weights.mat');
WChoicePool = allWc; WCuePool = allWu; WPerfPool = allWp;
WCue = []; WPerf = []; WChoice = [];  % avoid confusion in saved file
WChoice = WChoicePool; WCue = WCuePool; WPerf = WPerfPool;
MouseChoice = allWcMouse; MouseCue = allWuMouse; MousePerf = allWpMouse;
TimeVec = tVec; TrainTime = tTrain;
save(wtSave, 'WChoice','WCue','WPerf','MouseChoice','MouseCue','MousePerf','TimeVec','TrainTime');
fprintf('Saved weights: %s\n', wtSave);

%% 5. Output 2: example neurons — actual vs predicted PSTH (Runyan Fig 2b style)
% Pick the cell with the largest training-window |weight| per variable.
ex = struct('Mouse', {}, 'Cell', {}, 'Var', {});
for v = 1:3
    best = -Inf; bi = 0; bm = '';
    for i = 1:nValid
        r = resAll{i};
        if v == 1; W = r.WChoice; elseif v == 2; W = r.WCue; else; W = r.WPerf; end
        mxv = max(abs(W(:, tIdxTrainInFull)), [], 'omitnan');
        [mm, ci] = max(mxv, [], 'omitnan');
        if mm > best; best = mm; bi = ci; bm = r.Mouse; end
    end
    ex(end+1) = struct('Mouse', bm, 'Cell', bi, 'Var', v); %#ok<AGROW>
end

fEx = figure('Name','Example neurons: actual vs predicted (Runyan 2017 Fig 2b)','Color','w', ...
    'Position',[160 100 980 760]);
tle = tiledlayout(fEx, 3, 2, 'TileSpacing','compact', 'Padding','compact');
varNames = {'Choice','Cue','Performance'};
miceNames = cellfun(@(s) s.Mouse, resAll);
kCorrect = [0 0 0];            % correct (hit)  -> black
kError   = [0.55 0.55 0.55];   % error (miss)   -> grey
for k = 1:3
    r = resAll{find(miceNames == ex(k).Mouse, 1)};
    c = ex(k).Cell;
    [actHit, actMiss, actHitSE, actMissSE, predHit, predMiss, predHitSE, predMissSE] = ...
        iCellPSTH(r, c, tVec);
    % --- left column: actual trial-averaged response ---
    ax = nexttile(tle); hold(ax,'on');
    iShadedErr(ax, tVec, actHit,  actHitSE,  kCorrect, 0.25);
    iShadedErr(ax, tVec, actMiss, actMissSE, kError,   0.25);
    plot(ax, tVec, actHit,  '-', 'Color', kCorrect, 'LineWidth', 1.3);
    plot(ax, tVec, actMiss, '-', 'Color', kError,   'LineWidth', 1.3);
    xline(ax, 0, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8, 'HandleVisibility','off');
    if k == 1; legend(ax, {'Correct','Error'}, 'Location','northwest','Box','off','FontSize',8); end
    ylabel(ax, 'Activity (z)');
    title(ax, sprintf('%s: %s cell #%d', ex(k).Mouse, varNames{k}, c), ...
        'FontSize', 9, 'FontWeight', 'normal');
    box(ax,'off'); ax.FontSize = 8;
    % --- right column: model prediction ---
    ax2 = nexttile(tle); hold(ax2,'on');
    iShadedErr(ax2, tVec, predHit,  predHitSE,  kCorrect, 0.20);
    iShadedErr(ax2, tVec, predMiss, predMissSE, kError,   0.20);
    plot(ax2, tVec, predHit,  '-', 'Color', kCorrect, 'LineWidth', 1.3);
    plot(ax2, tVec, predMiss, '-', 'Color', kError,   'LineWidth', 1.3);
    xline(ax2, 0, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8, 'HandleVisibility','off');
    ylabel(ax2, 'Predicted (z)');
    if k == 3; xlabel(ax2, 'Time (s)'); end
    box(ax2,'off'); ax2.FontSize = 8;
end

fprintf('\nDone. GLM weight model complete.\n');

% ==================== Local Functions ====================

function [X, yChoice, yCue, yPerf] = iBuildTrialMatrixFull(rawTbl, cellUIDs)
% Build trial matrix: rows = trials, cols = cells, 3rd dim = time.
% Also return per-trial choice (behavior), cue, and block performance.
sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);
nts = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), double(rawTbl.Cue), double(rawTbl.Perf), ...
    'VariableNames', {'CellUID','TrialUID','Behavior','Cue','Perf'});
sigCell = cell(size(sig, 1), 1);
for i = 1:size(sig, 1); sigCell{i} = sig(i, :); end
nts.Signal = sigCell;
nts = nts(ismember(nts.CellUID, cellUIDs), :);
if isempty(nts); X=[]; yChoice=[]; yCue=[]; yPerf=[]; return; end
trialUIDs = unique(nts.TrialUID);
nTrials = numel(trialUIDs);
nCells = numel(cellUIDs);
X = zeros(nTrials, nCells, nTime);
yChoice = nan(nTrials, 1); yCue = nan(nTrials, 1); yPerf = nan(nTrials, 1);
for iT = 1:nTrials
    rows = nts(nts.TrialUID == trialUIDs(iT), :);
    [~, loc] = ismember(rows.CellUID, cellUIDs);
    for iR = 1:height(rows)
        ci = loc(iR);
        if ci > 0; X(iT, ci, :) = rows.Signal{iR}; end
    end
    yChoice(iT) = mode(rows.Behavior);
    yCue(iT) = mode(rows.Cue);
    yPerf(iT) = mode(rows.Perf);
end
hasData = all(isfinite(X), [2 3]) & isfinite(yChoice) & isfinite(yCue) & isfinite(yPerf);
X = X(hasData, :, :);
yChoice = yChoice(hasData); yCue = yCue(hasData); yPerf = yPerf(hasData);
X(isnan(X)) = 0;
end

function [actHit, actMiss, actHitSE, actMissSE, predHit, predMiss, predHitSE, predMissSE] = iCellPSTH(r, c, tVec)
% Actual vs model-predicted PSTH for cell c, split by hit/miss (mean +/- SEM).
act = squeeze(r.X(:, c, :));          % nTr x nTfull
hit = r.yChoice == 1; miss = r.yChoice == 0;
nH = sum(hit); nM = sum(miss);
actHit = mean(act(hit, :), 1);
actMiss = mean(act(miss, :), 1);
actHitSE = std(act(hit, :), 0, 1)/sqrt(nH);
actMissSE = std(act(miss, :), 0, 1)/sqrt(nM);
predM = zeros(size(act));
for iT = 1:size(act, 2)
    predM(:, iT) = r.W0(c, iT) + r.WChoice(c,iT)*r.yChoice + r.WCue(c,iT)*r.yCue + r.WPerf(c,iT)*r.yPerf;
end
predHit = mean(predM(hit, :), 1);
predMiss = mean(predM(miss, :), 1);
predHitSE = std(predM(hit, :), 0, 1)/sqrt(nH);
predMissSE = std(predM(miss, :), 0, 1)/sqrt(nM);
end

function iShadedErr(ax, x, y, se, col, alpha)
% Filled mean +/- SEM band around a line.
x = x(:).'; y = y(:).'; se = se(:).';
xx = [x, fliplr(x)];
yy = [y + se, fliplr(y - se)];
fill(ax, xx, yy, col, 'FaceAlpha', alpha, 'EdgeColor', 'none');
end

function iMouseSeparators(ax, mouseIds)
% Draw dotted separators between mice in a heatmap axis.
mouseList = unique(mouseIds, 'stable');
cumC = 0;
for iM = 1:numel(mouseList)
    nThis = sum(mouseIds == mouseList(iM));
    cumC = cumC + nThis;
    if cumC < numel(mouseIds)
        yline(ax, cumC + 0.5, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.3);
    end
end
end

function map = iBlueBlackRedCmap()
n = 128;
map = [linspace(0.05,0.95,n)', linspace(0.05,0.40,n)', linspace(0.35,0.05,n)'];
map = map .^ 0.7;
map = max(0, min(1, map));
end

function map = iRedCmap()
% White-to-red colormap for positive weights (0 -> white, max -> red).
n = 128;
map = [ones(n,1), linspace(1,0,n)', linspace(1,0,n)'];
end

function map = iBlueCmap()
% Deep-blue-to-white colormap for negative weights (min -> blue, 0 -> white).
n = 128;
map = [linspace(0,1,n)', linspace(0,1,n)', ones(n,1)];
end

function map = iDivergingCmap()
% Blue-white-red diverging colormap centered at zero (Runyan 2017 Fig 2c style).
n = 128; h = n/2;
blu = [0.10 0.32 0.82]; wht = [1 1 1]; red = [0.85 0.18 0.14];
map = [linspace(blu(1),wht(1),h)', linspace(blu(2),wht(2),h)', linspace(blu(3),wht(3),h)';
       linspace(wht(1),red(1),h)', linspace(wht(2),red(2),h)', linspace(wht(3),red(3),h)'];
end

function mi = iPtCorrectedMI(act, label, nBins)
% Panzeri-Treves bias-corrected mutual information (bits)
% act: nTrials x 1 neural activity; label: nTrials x 1 binary (0/1); nBins: activity bins.
n = numel(act);
if n < 4 || range(act) == 0 || numel(unique(label)) < 2
    mi = 0; return;
end
[~, edges] = histcounts(act, nBins);
if numel(unique(edges)) < 2; mi = 0; return; end
actBin = discretize(act, edges);
if all(isnan(actBin)); mi = 0; return; end
joint = zeros(nBins, 2);
for i = 1:n
    if ~isnan(actBin(i))
        joint(actBin(i), label(i)+1) = joint(actBin(i), label(i)+1) + 1;
    end
end
joint(sum(joint,2)==0, :) = [];
pJoint = joint / sum(joint(:));
px = sum(pJoint, 2);
py = sum(pJoint, 1);
miRaw = 0;
for i = 1:size(pJoint,1)
    for j = 1:2
        if pJoint(i,j) > 0 && px(i) > 0 && py(j) > 0
            miRaw = miRaw + pJoint(i,j) * log2(pJoint(i,j) / (px(i) * py(j)));
        end
    end
end
Mx = size(pJoint, 1);
My = 2;
bias = (Mx - 1) * (My - 1) / (2 * n * log(2));
mi = max(0, miRaw - bias);
end
