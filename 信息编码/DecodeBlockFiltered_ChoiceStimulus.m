%% DecodeBlockFiltered_ChoiceStimulus.m
% Two decoders on block-filtered data:
%   Decoder 1: choice (hit vs miss)
%   Decoder 2: stimulus (cue: LightWater vs AudioWater)
%
% Block filter: keep only blocks whose hit rate is in [30%, 85%],
% regardless of whether the stimulus is LightWater or AudioWater.
%
% Reference:
%   - EncodeHeatmap_ALB_HitMiss_vs_Cue.m
%     (cell sorting: by training-window peak time, descending)
%   - DecodeTransferOnly_HitMiss_MIHeatmap.m
%     (dual-decoder structure, Panzeri-Treves corrected MI, uncorrected p<0.05 significance)
%
% Output figures:
%   Fig 1: MI line plot (two subplots: choice, stimulus)
%   Fig 2: normalized MI heatmap (two panels, sig cells, sorted by peak time)
%   Fig 3: significant-cell raw MI heatmap (two panels, same cells/order)

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

%% 2. Time windows
tMaskFull  = (xs >= -1) & (xs <= 1);
tMaskTrain = (xs >= 0) & (xs <= 1);
tIdxFull   = find(tMaskFull);
tIdxTrain  = find(tMaskTrain);
tIdxTrainInFull = find(ismember(tIdxFull, tIdxTrain));
nTfull  = numel(tIdxFull);
nTtrain = numel(tIdxTrain);

fprintf('=== Block-filtered dual decoder: choice vs stimulus ===\n');
fprintf('Audio: all blocks, hit rate in [0.30, 0.85]; Light: Transfer phase only, hit rate in [0.30, 0.85]\n');
fprintf('Training window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxTrain(1)), xs(tIdxTrain(end)), nTtrain);
fprintf('Heatmap window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxFull(1)), xs(tIdxFull(end)), nTfull);

%% 3. Blocks table (BlockUID -> Performance / Design)
Blk = DS.Blocks;
Blk.BlockUID = uint64(Blk.BlockUID);
Blk.Design = string(Blk.Design);
Blk.Performance = double(Blk.Performance);

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
miceAll = unique(DT.Mouse);

%% 4. Block selection + data loading
% AudioWater: query WITHOUT a Phase, so all AW blocks are returned
% (including blocks with no phase annotation), then HR filter [30%,85%].
% LightWater: query Transfer phase only (single block per mouse), HR filter.
fprintf('\n========== Block selection (Audio: all; Light: Transfer) ==========\n');
selAll = cell(numel(miceAll), 1);
rawAllMouse = cell(numel(miceAll), 1);
nUsed = 0;
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    raw = table();
    % AudioWater: all blocks (incl. unannotated phase)
    try
        resp = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(resp) && ~isempty(resp{1})
            tbl = resp{1};
            tbl.Cue = zeros(height(tbl), 1);
            raw = [raw; tbl];
        end
    catch
    end
    % LightWater: Transfer phase only
    try
        resp = DS.QueryNTS(struct('Mouse',m,'Phase','Transfer','Stimulus','LightWater'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(resp) && ~isempty(resp{1})
            tbl = resp{1};
            tbl.Cue = ones(height(tbl), 1);
            raw = [raw; tbl];
        end
    catch
    end
    if isempty(raw) || ~ismember('BlockUID', string(raw.Properties.VariableNames))
        continue;
    end

    bu = unique(uint64(raw.BlockUID));
    qual = false(numel(bu), 1);
    for k = 1:numel(bu)
        hr = Blk.Performance(find(Blk.BlockUID == bu(k), 1));
        qual(k) = ~isnan(hr) && hr >= 0.30 && hr <= 0.85;
    end
    qualBU = bu(qual);
    if isempty(qualBU); continue; end

    rawQ = raw(ismember(uint64(raw.BlockUID), qualBU), :);
    nUsed = nUsed + 1;
    selAll{nUsed} = struct('Mouse', m, 'BlockUID', qualBU, ...
        'Stimulus', arrayfun(@(b) string(Blk.Design(find(Blk.BlockUID==b,1))), qualBU), ...
        'HitRate', arrayfun(@(b) Blk.Performance(find(Blk.BlockUID==b,1)), qualBU), ...
        'NTrials', arrayfun(@(b) sum(uint64(raw.BlockUID)==b), qualBU));
    rawAllMouse{nUsed} = rawQ;

    s = selAll{nUsed};
    fprintf('  %s: %d block(s) | HR=%s | stim=%s | trials=%s\n', ...
        m, numel(s.BlockUID), mat2str(round(s.HitRate(:)', 3)), ...
        strjoin(s.Stimulus, ','), mat2str(s.NTrials(:)'));
end
selAll = selAll(1:nUsed);
rawAllMouse = rawAllMouse(1:nUsed);
mice = cellfun(@(s) s.Mouse, selAll);
nMice = nUsed;
fprintf('Used mice: %d\n', nMice);
if nMice == 0
    fprintf('No qualifying blocks.\n');
    return;
end

% Export block selection details (per mouse per qualifying block)
blkTab = table();
for i = 1:nUsed
    s = selAll{i};
    nB = numel(s.BlockUID);
    blkTab = [blkTab; table(repmat(s.Mouse, nB, 1), uint64(s.BlockUID(:)), ...
        s.Stimulus(:), s.HitRate(:), s.NTrials(:), ...
        'VariableNames', {'Mouse','BlockUID','Stimulus','HitRate','NTrials'})];
end
blkFile = fullfile(thisDir, 'DecodeBlockFiltered_block_selection.csv');
fid = fopen(blkFile, 'w');
fprintf(fid, '# Hit-rate filter: 0.30 <= Performance <= 0.85. AudioWater: all blocks (incl. unannotated phase); LightWater: Transfer phase only.\n');
fclose(fid);
writetable(blkTab, blkFile, 'WriteMode', 'append');
fprintf('Exported block selection: %s\n', blkFile);

%% 5. Per-mouse analysis
resAll = cell(nMice, 1);
for iM = 1:nMice
    m = mice(iM);
    allRaw = rawAllMouse{iM};
    fprintf('\n========== Mouse %s (%d/%d) ==========\n', m, iM, nMice);

    cellUIDs = uint64(unique(allRaw.CellUID));
    nCell = numel(cellUIDs);
    if nCell < 5
        fprintf('  SKIP: %d cells\n', nCell); continue;
    end

    [X, yChoice, yCue] = iBuildTrialMatrixWithCue(allRaw, cellUIDs);
    if isempty(X)
        fprintf('  SKIP: empty matrix\n'); continue;
    end
    X = X(:, :, tIdxFull);
    nTr = size(X, 1);

    if sum(yChoice==1) < 2 || sum(yChoice==0) < 2 || sum(yCue==0) < 2 || sum(yCue==1) < 2
        fprintf('  SKIP: class imbalance (H=%d/M=%d, AW=%d/LW=%d)\n', ...
            sum(yChoice==1), sum(yChoice==0), sum(yCue==0), sum(yCue==1));
        continue;
    end
    fprintf('  Cells=%d  Trials=%d (H=%d/M=%d, AW=%d/LW=%d)\n', ...
        nCell, nTr, sum(yChoice==1), sum(yChoice==0), sum(yCue==0), sum(yCue==1));

    % Per-cell per-time-point MI (PT-corrected) + GLM p-values
    nBins = max(3, min(8, round(sqrt(nTr)/2)*2));
    miChoice = nan(nCell, nTfull);
    miCue    = nan(nCell, nTfull);
    pChoice  = nan(nCell, nTfull);
    pCue     = nan(nCell, nTfull);
    for iC = 1:nCell
        for iT = 1:nTfull
            act = squeeze(X(:, iC, iT));
            if all(isnan(act)) || range(act) == 0; continue; end
            try
                [~, ~, st] = glmfit(yChoice, act, 'normal'); pChoice(iC,iT) = st.p(2);
            catch, end
            try
                [~, ~, st] = glmfit(yCue, act, 'normal'); pCue(iC,iT) = st.p(2);
            catch, end
            miChoice(iC,iT) = iPtCorrectedMI(act, yChoice, nBins);
            miCue(iC,iT)    = iPtCorrectedMI(act, yCue, nBins);
        end
    end

    % Max-normalize MI within training window
    miChoiceNorm = nan(size(miChoice));
    miCueNorm    = nan(size(miCue));
    for iC = 1:nCell
        d = max(miChoice(iC, tIdxTrainInFull), [], 'omitnan');
        if ~isnan(d) && d > 0; miChoiceNorm(iC,:) = miChoice(iC,:) ./ d; end
        d = max(miCue(iC, tIdxTrainInFull), [], 'omitnan');
        if ~isnan(d) && d > 0; miCueNorm(iC,:) = miCue(iC,:) ./ d; end
    end

    % Significance: any training-window time point with p<0.05 (uncorrected)
    sigChoice = any(pChoice(:, tIdxTrainInFull) < 0.05, 2);
    sigCue    = any(pCue(:, tIdxTrainInFull) < 0.05, 2);

    res = struct();
    res.Mouse = m;
    res.CellUIDs = cellUIDs;
    res.NCells = nCell;
    res.NTrials = nTr;
    res.NHit = sum(yChoice==1);
    res.NMiss = sum(yChoice==0);
    res.NAudio = sum(yCue==0);
    res.NLight = sum(yCue==1);
    res.Blocks = selAll{iM};
    res.Choice.MiRaw = miChoice;
    res.Choice.MiNorm = miChoiceNorm;
    res.Choice.EncP = pChoice;
    res.Choice.Sig = sigChoice;
    res.Cue.MiRaw = miCue;
    res.Cue.MiNorm = miCueNorm;
    res.Cue.EncP = pCue;
    res.Cue.Sig = sigCue;
    res.TimeVec = xs(tIdxFull);
    resAll{iM} = res;

    fprintf('  Done. Sig cells (p<0.05): choice=%d/%d, stimulus=%d/%d\n', ...
        sum(sigChoice), nCell, sum(sigCue), nCell);
end

%% 6. Valid mice + figures
validIdx = find(~cellfun(@isempty, resAll));
nValid = numel(validIdx);
fprintf('\n========== Valid mice: %d ==========\n', nValid);
for i = 1:nValid
    r = resAll{validIdx(i)};
    fprintf('  %s: %d cells, %d trials (H%d/M%d, AW%d/LW%d), blocks=%d\n', ...
        r.Mouse, r.NCells, r.NTrials, r.NHit, r.NMiss, r.NAudio, r.NLight, ...
        numel(r.Blocks.BlockUID));
end
if nValid == 0
    fprintf('No valid mice.\n');
    return;
end

% Export per-mouse analysis summary
sumTab = table();
for i = 1:nValid
    r = resAll{validIdx(i)};
    sumTab = [sumTab; table(string(r.Mouse), r.NCells, r.NTrials, ...
        r.NHit, r.NMiss, r.NAudio, r.NLight, numel(r.Blocks.BlockUID), ...
        sum(r.Choice.Sig), sum(r.Cue.Sig), ...
        'VariableNames', {'Mouse','NCells','NTrials','NHit','NMiss','NAudio','NLight','NBlocks','SigChoice','SigStimulus'})];
end
sumFile = fullfile(thisDir, 'DecodeBlockFiltered_mouse_summary.csv');
fid = fopen(sumFile, 'w');
fprintf(fid, '# Analysis: choice (hit/miss) vs stimulus (cue: AW vs LW); significance = any p<0.05 across 0-1 s training window (uncorrected).\n');
fclose(fid);
writetable(sumTab, sumFile, 'WriteMode', 'append');
fprintf('Exported mouse summary: %s\n', sumFile);

% Audio vs Light proportion in the data actually used
totAW = 0; totLW = 0;
for i = 1:nValid
    r = resAll{validIdx(i)};
    totAW = totAW + r.NAudio;
    totLW = totLW + r.NLight;
end
totTr = totAW + totLW;
fprintf('Used trials: Audio=%d (%.1f%%), Light=%d (%.1f%%), total=%d\n', ...
    totAW, 100*totAW/totTr, totLW, 100*totLW/totTr, totTr);

% ---------------------------
% Decoder check: choice (hit/miss) — train on Audio, test on Transfer (Light)
% Variants: all cells vs Audio-significant cells; raw vs balanced accuracy.
% Linear readout on training-window (0-1 s) mean activity per cell.
% ---------------------------
decRaw = nan(nValid, 1); decBal = nan(nValid, 1);
decRawSig = nan(nValid, 1); decBalSig = nan(nValid, 1);
decLOOCV = nan(nValid, 1); decChance = nan(nValid, 1);
for i = 1:nValid
    r = resAll{validIdx(i)};
    [Xdec, yCh, yCu] = iBuildTrialMatrixWithCue(rawAllMouse{validIdx(i)}, r.CellUIDs);
    if isempty(Xdec); continue; end
    F = squeeze(mean(Xdec(:, :, tIdxTrainInFull), 3));   % nTr x nCell, training-window mean
    aw = yCu == 0;   % Audio
    lw = yCu == 1;   % Transfer Light
    if sum(aw) < 5 || sum(lw) < 5 || sum(yCh(aw)==1) < 2 || sum(yCh(aw)==0) < 2
        continue;
    end

    Ftr = F(aw, :); ytr = yCh(aw);
    Fte = F(lw, :); yte = yCh(lw);
    decChance(i) = max(mean(yte==1), mean(yte==0));

    % Variant A: all cells
    [a1, b1, ~, ~, ~] = iTrainTestLinear(Ftr, ytr, Fte, yte);
    decRaw(i) = a1; decBal(i) = b1;

    % Variant B: Audio-significant cells only (feature selection on training only)
    sigCell = false(1, size(F, 2));
    for c = 1:size(F, 2)
        try
            [~, ~, st] = glmfit(ytr, Ftr(:, c), 'normal');
            sigCell(c) = st.p(2) < 0.05;
        catch
        end
    end
    a2 = NaN; b2 = NaN;
    if sum(sigCell) >= 1
        [a2, b2, ~, ~, ~] = iTrainTestLinear(Ftr(:, sigCell), ytr, Fte(:, sigCell), yte);
        decRawSig(i) = a2; decBalSig(i) = b2;
    end

    % Within-Audio LOOCV (all cells) for reference
    nA = sum(aw); idxA = find(aw); accLOO = 0;
    for k = 1:nA
        trSet = true(nA, 1); trSet(k) = false;
        mtr = mean(Ftr(trSet,:), 1); str_ = std(Ftr(trSet,:), 0, 1); str_(str_==0) = 1;
        wk = pinv([ones(sum(trSet),1), (Ftr(trSet,:)-mtr)./str_]) * (2*ytr(trSet)-1);
        fk = (Ftr(k,:) - mtr) ./ str_;
        pk = sign([1, fk] * wk);
        accLOO = accLOO + (pk == (2*ytr(k)-1));
    end
    decLOOCV(i) = accLOO / nA;

    fprintf('  %s: raw=%.1f%% bal=%.1f%% | sigCells raw=%.1f%% bal=%.1f%% (nSig=%d) | LOOCV=%.1f%% | chance=%.1f%%\n', ...
        r.Mouse, 100*a1, 100*b1, 100*a2, 100*b2, sum(sigCell), 100*decLOOCV(i), 100*decChance(i));
end
validDec = ~isnan(decRaw);
fprintf('Choice transfer decoding (Audio->Transfer): raw=%.1f%%+-%.1f bal=%.1f%%+-%.1f | sigCells raw=%.1f%% bal=%.1f%% | within-AW LOOCV=%.1f%%+-%.1f | mean chance=%.1f%% (n=%d)\n', ...
    100*mean(decRaw(validDec)), 100*std(decRaw(validDec))/sqrt(sum(validDec)), ...
    100*mean(decBal(validDec)), 100*std(decBal(validDec))/sqrt(sum(validDec)), ...
    100*mean(decRawSig(validDec), 'omitnan'), 100*mean(decBalSig(validDec), 'omitnan'), ...
    100*mean(decLOOCV(validDec)), 100*std(decLOOCV(validDec))/sqrt(sum(validDec)), ...
    100*mean(decChance(validDec)), sum(validDec));

tVec = xs(tIdxFull);
tTrain = xs(tIdxTrain);

% ---------------------------
% Fig 1: MI line plot (two subplots)
% ---------------------------
miCurveChoice = nan(nValid, nTfull);
miCurveCue    = nan(nValid, nTfull);
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigC = r.Choice.Sig;
    sigS = r.Cue.Sig;
    if sum(sigC) > 0
        miCurveChoice(i, :) = mean(r.Choice.MiRaw(sigC, :), 1, 'omitnan');
    end
    if sum(sigS) > 0
        miCurveCue(i, :) = mean(r.Cue.MiRaw(sigS, :), 1, 'omitnan');
    end
end
mnC = mean(miCurveChoice, 1, 'omitnan'); seC = std(miCurveChoice, 0, 1, 'omitnan') / sqrt(nValid);
mnS = mean(miCurveCue,    1, 'omitnan'); seS = std(miCurveCue,    0, 1, 'omitnan') / sqrt(nValid);

f1 = figure('Name','Dual decoder MI curve','Color','w', 'Position',[180 180 1000 360]);
ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
errorbar(ax1, tVec, mnC, seC, '-o', 'Color', [0.85 0.33 0.10], ...
    'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', [0.85 0.33 0.10]);
hold(ax1, 'off');
xlabel(ax1, 'Time from stimulus (s)'); ylabel(ax1, 'MI (bits)');
title(ax1, 'Choice (hit/miss)', 'FontSize', 9, 'FontWeight', 'normal');
xline(ax1, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
box(ax1, 'off');

ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
errorbar(ax2, tVec, mnS, seS, '-o', 'Color', [0.10 0.45 0.70], ...
    'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', [0.10 0.45 0.70]);
hold(ax2, 'off');
xlabel(ax2, 'Time from stimulus (s)'); ylabel(ax2, 'MI (bits)');
title(ax2, 'Stimulus (cue)', 'FontSize', 9, 'FontWeight', 'normal');
xline(ax2, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
box(ax2, 'off');

% ---------------------------
% Collect significant cells per decoder (norm + raw), sorted by peak time
% ---------------------------
normChoice = []; rawChoice = []; mChoice = []; pkChoice = [];
normCue    = []; rawCue    = []; mCue    = []; pkCue    = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    % choice
    sig = r.Choice.Sig;
    if any(sig)
        mtxN = r.Choice.MiNorm(sig, :);
        mtxR = r.Choice.MiRaw(sig, :);
        [~, pk] = max(mtxN(:, tIdxTrainInFull), [], 2, 'omitnan');
        v = ~isnan(pk);
        normChoice = [normChoice; mtxN(v, :)];
        rawChoice  = [rawChoice;  mtxR(v, :)];
        mChoice    = [mChoice;    repmat(string(r.Mouse), sum(v), 1)];
        pkChoice   = [pkChoice;   tTrain(pk(v))];
    end
    % stimulus
    sig = r.Cue.Sig;
    if any(sig)
        mtxN = r.Cue.MiNorm(sig, :);
        mtxR = r.Cue.MiRaw(sig, :);
        [~, pk] = max(mtxN(:, tIdxTrainInFull), [], 2, 'omitnan');
        v = ~isnan(pk);
        normCue = [normCue; mtxN(v, :)];
        rawCue  = [rawCue;  mtxR(v, :)];
        mCue    = [mCue;    repmat(string(r.Mouse), sum(v), 1)];
        pkCue   = [pkCue;   tTrain(pk(v))];
    end
end

[~, oC] = sort(pkChoice, 'descend');
normChoice = normChoice(oC, :); rawChoice = rawChoice(oC, :); mChoice = mChoice(oC);
[~, oS] = sort(pkCue, 'descend');
normCue = normCue(oS, :); rawCue = rawCue(oS, :); mCue = mCue(oS);

% --- diagnostic: whole-line bright cells (pre-stim MI ~ peak MI) ---
preIdx = tVec < 0;
if ~isempty(rawChoice)
    preC = mean(rawChoice(:, preIdx), 2, 'omitnan');
    pkC  = max(rawChoice, [], 2, 'omitnan');
    flatC = (pkC > 0.05) & (preC ./ pkC > 0.7);
    fprintf('[diag] Choice raw heatmap: whole-line bright = %d/%d (%.1f%%)\n', ...
        sum(flatC), numel(flatC), 100 * mean(flatC));
end
if ~isempty(rawCue)
    preS = mean(rawCue(:, preIdx), 2, 'omitnan');
    pkS  = max(rawCue, [], 2, 'omitnan');
    flatS = (pkS > 0.05) & (preS ./ pkS > 0.7);
    fprintf('[diag] Stimulus raw heatmap: whole-line bright = %d/%d (%.1f%%)\n', ...
        sum(flatS), numel(flatS), 100 * mean(flatS));
end

% ---------------------------
% Fig 2: normalized MI heatmap (two panels)
% ---------------------------
f2 = figure('Name','Normalized MI heatmap','Color','w', 'Position',[260 260 1100 480]);
tl = tiledlayout(f2, 1, 2, 'TileSpacing','compact', 'Padding','compact');

ax = nexttile(tl);
imagesc(ax, tVec, 1:size(normChoice,1), normChoice);
colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 1]);
cb = colorbar(ax); cb.Label.String = 'Norm. MI';
xlabel(ax, 'Time (s)'); ylabel(ax, 'Cell #');
title(ax, sprintf('Choice (sig cells, N=%d)', size(normChoice,1)), 'FontSize', 9, 'FontWeight', 'normal');
xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.FontSize = 8; box(ax, 'off');
iMouseSeparators(ax, mChoice);

ax = nexttile(tl);
imagesc(ax, tVec, 1:size(normCue,1), normCue);
colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 1]);
cb = colorbar(ax); cb.Label.String = 'Norm. MI';
xlabel(ax, 'Time (s)');
title(ax, sprintf('Stimulus (sig cells, N=%d)', size(normCue,1)), 'FontSize', 9, 'FontWeight', 'normal');
xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.FontSize = 8; box(ax, 'off');
iMouseSeparators(ax, mCue);

% ---------------------------
% Fig 3: significant-cell raw MI heatmap (two panels)
% ---------------------------
maxRawC = max(rawChoice(:), [], 'omitnan'); if maxRawC <= 0; maxRawC = 0.05; end
maxRawS = max(rawCue(:),    [], 'omitnan'); if maxRawS <= 0; maxRawS = 0.05; end

f3 = figure('Name','Significant-cell MI heatmap','Color','w', 'Position',[320 320 1100 480]);
tl3 = tiledlayout(f3, 1, 2, 'TileSpacing','compact', 'Padding','compact');

ax = nexttile(tl3);
imagesc(ax, tVec, 1:size(rawChoice,1), rawChoice);
colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 maxRawC]);
cb = colorbar(ax); cb.Label.String = 'MI (bits)';
xlabel(ax, 'Time (s)'); ylabel(ax, 'Cell #');
title(ax, sprintf('Choice significant cells (N=%d, p<0.05)', size(rawChoice,1)), ...
    'FontSize', 9, 'FontWeight', 'normal');
xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.FontSize = 8; box(ax, 'off');
iMouseSeparators(ax, mChoice);

ax = nexttile(tl3);
imagesc(ax, tVec, 1:size(rawCue,1), rawCue);
colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 maxRawS]);
cb = colorbar(ax); cb.Label.String = 'MI (bits)';
xlabel(ax, 'Time (s)');
title(ax, sprintf('Stimulus significant cells (N=%d, p<0.05)', size(rawCue,1)), ...
    'FontSize', 9, 'FontWeight', 'normal');
xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
ax.FontSize = 8; box(ax, 'off');
iMouseSeparators(ax, mCue);

% ---------------------------
% Fig 4: combined heatmap for cells significant in BOTH decoders,
% sorted by primary/secondary peak time (descending).
% ---------------------------
allChMI = []; allCueMI = []; allMouse = []; allPk1 = []; allPk2 = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigCh = r.Choice.Sig;
    sigCu = r.Cue.Sig;
    sigBoth = sigCh & sigCu;
    if ~any(sigBoth); continue; end

    cellIdx = find(sigBoth);
    nJ = numel(cellIdx);
    chMI = nan(nJ, nTfull);
    cuMI = nan(nJ, nTfull);
    pk1 = nan(nJ, 1);
    pk2 = nan(nJ, 1);
    for iC = 1:nJ
        c = cellIdx(iC);
        chPk = max(r.Choice.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
        cuPk = max(r.Cue.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
        chPkTime = NaN; cuPkTime = NaN;
        [~, iCh] = max(r.Choice.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
        [~, iCu] = max(r.Cue.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
        if ~isnan(iCh); chPkTime = tTrain(iCh); end
        if ~isnan(iCu); cuPkTime = tTrain(iCu); end

        chMI(iC, :) = r.Choice.MiRaw(c, :);
        cuMI(iC, :) = r.Cue.MiRaw(c, :);
        if chPk >= cuPk
            pk1(iC) = chPkTime; pk2(iC) = cuPkTime;
        else
            pk1(iC) = cuPkTime; pk2(iC) = chPkTime;
        end
    end
    validRows = any(~isnan(chMI), 2) | any(~isnan(cuMI), 2);
    if ~any(validRows); continue; end
    allChMI = [allChMI; chMI(validRows, :)];
    allCueMI = [allCueMI; cuMI(validRows, :)];
    allMouse = [allMouse; repmat(string(r.Mouse), sum(validRows), 1)];
    allPk1 = [allPk1; pk1(validRows)];
    allPk2 = [allPk2; pk2(validRows)];
end
if ~isempty(allChMI)
    o1 = allPk1; o2 = allPk2;
    o1(isnan(o1)) = -inf; o2(isnan(o2)) = -inf;
    [~, so] = sortrows([(-o1), (-o2)], [1 2]);
    allChMI = allChMI(so, :);
    allCueMI = allCueMI(so, :);
    allMouse = allMouse(so);
    maxRawJ = max([allChMI(:); allCueMI(:)], [], 'omitnan');
    if maxRawJ <= 0; maxRawJ = 0.05; end

    fJ = figure('Name','Combined both-sig cell MI heatmap','Color','w', ...
        'Position',[380 380 1100 460]);
    ax = axes(fJ);
    imagesc(ax, 1:2*nTfull, 1:size(allChMI,1), [allChMI, allCueMI]);
    colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 maxRawJ]);
    cb = colorbar(ax); cb.Label.String = 'MI (bits)';
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Cell #');
    title(ax, sprintf('Cells significant in both decoders (N=%d)', size(allChMI,1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, nTfull + 0.5, '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
    text(ax, nTfull/2, size(allChMI,1) * 1.03, 'Choice', ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
    text(ax, 1.5*nTfull, size(allChMI,1) * 1.03, 'Stimulus', ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
    ax.XTick = [1:2:nTfull, nTfull+1:2:2*nTfull];
    ax.XTickLabel = string(round([tVec(1:2:end), tVec(1:2:end)], 2));
    ax.FontSize = 8; box(ax, 'off');
    iMouseSeparators(ax, allMouse);
    fprintf('Combined both-sig heatmap: %d cells\n', size(allChMI,1));
end

fprintf('\nDone. Block-filtered dual decoder analysis complete.\n');

% ==================== Local Functions ====================

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

function [acc, bal, w, mu, sd] = iTrainTestLinear(Ftr, ytr, Fte, yte)
% Standardize with training stats, fit a linear readout (pinv), evaluate on
% the test set. Returns raw accuracy and balanced accuracy (mean of per-class).
mu = mean(Ftr, 1); sd = std(Ftr, 0, 1); sd(sd == 0) = 1;
Ftrs = (Ftr - mu) ./ sd;
w = pinv([ones(size(Ftrs,1),1), Ftrs]) * (2*ytr - 1);
Ftes = (Fte - mu) ./ sd;
pred = sign([ones(size(Ftes,1),1), Ftes] * w);
tru = 2*yte - 1;
acc = mean(pred == tru);
hitAcc = mean(pred(tru == 1) == 1);
missAcc = mean(pred(tru == -1) == -1);
bal = mean([hitAcc, missAcc], 'omitnan');
end

function mi = iPtCorrectedMI(act, label, nBins)
% Panzeri-Treves bias-corrected mutual information (bits)
n = numel(act);
if n < 4 || range(act) == 0 || numel(unique(label)) < 2
    mi = 0; return;
end
[~, edges] = histcounts(act, nBins);
if numel(unique(edges)) < 2
    mi = 0; return;
end
actBin = discretize(act, edges);
if all(isnan(actBin)); mi = 0; return; end
joint = accumarray([actBin(:), label(:)+1], 1, [nBins 2]);
mi = iMIFromJoint(joint, n);
end

function mi = iMIFromJoint(joint, n)
% Mutual information (bits) from a joint count matrix (Mx x 2) with
% Panzeri-Treves bias correction. Empty activity rows are dropped.
joint(sum(joint, 2) == 0, :) = [];
if isempty(joint); mi = 0; return; end
pJoint = joint / sum(joint(:));
px = sum(pJoint, 2);
py = sum(pJoint, 1);
miRaw = 0;
for i = 1:size(pJoint, 1)
    for j = 1:2
        if pJoint(i, j) > 0 && px(i) > 0 && py(j) > 0
            miRaw = miRaw + pJoint(i, j) * log2(pJoint(i, j) / (px(i) * py(j)));
        end
    end
end
Mx = size(pJoint, 1);
bias = (Mx - 1) * (2 - 1) / (2 * n * log(2));
mi = max(0, miRaw - bias);
end

function sig = iFdrAnySig(pMat, alpha)
% Benjamini-Hochberg FDR across columns (time points) for each row (cell).
% Returns true where any adjusted p-value is < alpha.
nRow = size(pMat, 1);
sig = false(nRow, 1);
for i = 1:nRow
    p = pMat(i, :);
    p = p(~isnan(p));
    if isempty(p); continue; end
    m = numel(p);
    [ps, order] = sort(p);
    adj = ps .* (m ./ (1:m));
    adj = min(1, adj);
    for k = m-1:-1:1
        adj(k) = min(adj(k), adj(k+1));
    end
    q = zeros(1, m);
    q(order) = adj;
    sig(i) = any(q < alpha);
end
end

function [X, yBeh, yCue] = iBuildTrialMatrixWithCue(rawTbl, cellUIDs)
% Build trial matrix: rows = trials, columns = cells, 3rd dim = time.
% yBeh = behavior (0/1), yCue = stimulus (0=AudioWater, 1=LightWater).
sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), double(rawTbl.Cue), ...
    'VariableNames', {'CellUID','TrialUID','Behavior','Cue'});
sigCell = cell(size(sig, 1), 1);
for i = 1:size(sig, 1)
    sigCell{i} = sig(i, :);
end
ntsTbl.Signal = sigCell;
keepRows = ismember(ntsTbl.CellUID, cellUIDs);
ntsTbl = ntsTbl(keepRows, :);
if isempty(ntsTbl)
    X = []; yBeh = []; yCue = [];
    return;
end
trialUIDs = unique(ntsTbl.TrialUID);
nTrials = numel(trialUIDs);
nCells = numel(cellUIDs);
X = zeros(nTrials, nCells, nTime);
yBeh = nan(nTrials, 1);
yCue = nan(nTrials, 1);
for iT = 1:nTrials
    rows = ntsTbl(ntsTbl.TrialUID == trialUIDs(iT), :);
    [~, loc] = ismember(rows.CellUID, cellUIDs);
    for iR = 1:height(rows)
        ci = loc(iR);
        if ci > 0
            X(iT, ci, :) = rows.Signal{iR};
        end
    end
    beh = rows.Behavior(~isnan(rows.Behavior));
    cue = rows.Cue(~isnan(rows.Cue));
    if isempty(beh); yBeh(iT) = NaN; else; yBeh(iT) = mode(beh); end
    if isempty(cue); yCue(iT) = NaN; else; yCue(iT) = mode(cue); end
end
hasData = all(isfinite(X), [2 3]) & isfinite(yBeh) & isfinite(yCue);
X = X(hasData, :, :);
yBeh = yBeh(hasData);
yCue = yCue(hasData);
X(isnan(X)) = 0;
end

function map = iBlueBlackRedCmap()
n = 128;
map = [linspace(0.05,0.95,n)', linspace(0.05,0.40,n)', linspace(0.35,0.05,n)'];
map = map .^ 0.7;
map = max(0, min(1, map));
end
