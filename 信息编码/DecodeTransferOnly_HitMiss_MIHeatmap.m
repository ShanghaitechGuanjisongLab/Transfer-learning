%% DecodeTransferOnly_HitMiss_MIHeatmap.m
% Two decoders: hit/miss (Transfer only) vs cue (Learned + Transfer)
%
% 目标:
%   1) 仅用 Transfer 阶段 LightWater 计算 hit vs miss 编码 MI
%   2) 用 Learned AudioWater + Transfer LightWater 合并计算 cue 编码 MI
%   3) 输出两个解码器的 MI 线图、MI 热图、显著细胞热图
%
% 参考:
%   - EncodeHeatmap_ALB_HitMiss_vs_Cue.m
%   - 细胞排序方式保持一致：按训练窗内峰值时间倒序展示

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

%% 2. Define time windows
tMaskFull  = (xs >= -1) & (xs <= 1);
tMaskTrain = (xs >= 0) & (xs <= 1);
tIdxFull   = find(tMaskFull);
tIdxTrain  = find(tMaskTrain);
tIdxTrainInFull = find(ismember(tIdxFull, tIdxTrain));
nTfull     = numel(tIdxFull);
nTtrain    = numel(tIdxTrain);

fprintf('=== Dual decoder: hit/miss vs cue MI heatmap ===\n');
fprintf('Training window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxTrain(1)), xs(tIdxTrain(end)), nTtrain);
fprintf('Heatmap window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxFull(1)), xs(tIdxFull(end)), nTfull);

%% 3. List mice
% Use a minimal TableQuery that only returns Mouse IDs from Transfer LightWater.
try
    TQ = DS.TableQuery("Mouse", Phase="Transfer", Stimulus="LightWater");
    TQ.Mouse = string(TQ.Mouse);
    mice = unique(TQ.Mouse);
catch
    mice = strings(0,1);
end
mice = sort(mice);
fprintf('Transfer mice: %d\n', numel(mice));

%% 4. Per-mouse analysis
nMice = numel(mice);
resAll = cell(nMice, 1);

for iM = 1:nMice
    m = mice(iM);
    fprintf('\n========== Mouse %s (%d/%d) ==========', m, iM, nMice);

    % ---------------------
    % Decoder 1: hit vs miss (Transfer only)
    % ---------------------
    rawTransfer = table();
    try
        resp = DS.QueryNTS(struct('Mouse',m,'Phase','Transfer','Stimulus','LightWater'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior","DateTime"]);
        if ~isempty(resp) && ~isempty(resp{1})
            rawTransfer = resp{1};
        end
    catch
    end

    if isempty(rawTransfer) || ~ismember('TrialSignal', string(rawTransfer.Properties.VariableNames))
        fprintf('  SKIP: no Transfer LightWater data\n');
        continue;
    end

    cellUIDs = uint64(unique(rawTransfer.CellUID));
    nCell = numel(cellUIDs);
    if nCell < 5
        fprintf('  SKIP: %d cells\n', nCell);
        continue;
    end

    [XHit, yHit] = iBuildTransferHitMissMatrix(rawTransfer, cellUIDs);
    if isempty(XHit)
        fprintf('  SKIP: empty hit/miss matrix\n');
        continue;
    end
    XHit = XHit(:, :, tIdxFull);
    nTr = size(XHit, 1);

    if sum(yHit == 1) < 2 || sum(yHit == 0) < 2
        fprintf('  SKIP: class imbalance (H=%d, M=%d)\n', sum(yHit==1), sum(yHit==0));
        continue;
    end

    fprintf('  Transfer cells=%d  trials=%d (H=%d, M=%d)\n', nCell, nTr, sum(yHit==1), sum(yHit==0));

    miHit = nan(nCell, nTfull);
    encPHit = nan(nCell, nTfull);
    nBins = max(3, min(8, round(sqrt(nTr)/2)*2));

    for iC = 1:nCell
        for iT = 1:nTfull
            act = squeeze(XHit(:, iC, iT));
            if all(isnan(act)) || range(act) == 0
                continue;
            end
            try
                [~, ~, stats] = glmfit(yHit, act, 'normal');
                encPHit(iC, iT) = stats.p(2);
            catch
            end
            miHit(iC, iT) = iPtCorrectedMI(act, yHit, nBins);
        end
    end

    miHitNorm = nan(size(miHit));
    for iC = 1:nCell
        denom = max(miHit(iC, tIdxTrainInFull), [], 'omitnan');
        if ~isnan(denom) && denom > 0
            miHitNorm(iC, :) = miHit(iC, :) ./ denom;
        end
    end

    % ---------------------
    % Decoder 2: cue (Learned + Transfer)
    % ---------------------
    allRaw = table();
    for phase = ["Learned", "Transfer"]
        stim = "AudioWater";
        if phase == "Transfer"; stim = "LightWater"; end
        try
            resp = DS.QueryNTS(struct('Mouse',m,'Phase',phase,'Stimulus',stim), ...
                UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior","DateTime"]);
            if ~isempty(resp) && ~isempty(resp{1})
                tbl = resp{1};
                tbl.Phase = repmat(phase, height(tbl), 1);
                tbl.Cue = repmat(double(stim == "LightWater"), height(tbl), 1);
                allRaw = [allRaw; tbl];
            end
        catch
        end
    end

    if isempty(allRaw) || ~ismember('TrialSignal', string(allRaw.Properties.VariableNames))
        fprintf('  SKIP: no cue data\n');
        continue;
    end

    [XCue, yBehCue, yCue] = iBuildTrialMatrixWithCue(allRaw, cellUIDs);
    if isempty(XCue)
        fprintf('  SKIP: empty cue matrix\n');
        continue;
    end
    XCue = XCue(:, :, tIdxFull);
    nTrCue = size(XCue, 1);

    if sum(yCue == 0) < 2 || sum(yCue == 1) < 2
        fprintf('  SKIP: cue imbalance (AW=%d, LW=%d)\n', sum(yCue==0), sum(yCue==1));
        continue;
    end

    fprintf('  Cue cells=%d  trials=%d (AW=%d, LW=%d)\n', nCell, nTrCue, sum(yCue==0), sum(yCue==1));

    miCue = nan(nCell, nTfull);
    encPCue = nan(nCell, nTfull);

    nBinsCue = max(3, min(8, round(sqrt(nTrCue)/2)*2));
    for iC = 1:nCell
        for iT = 1:nTfull
            act = squeeze(XCue(:, iC, iT));
            if all(isnan(act)) || range(act) == 0
                continue;
            end
            try
                [~, ~, stats] = glmfit(yCue, act, 'normal');
                encPCue(iC, iT) = stats.p(2);
            catch
            end
            miCue(iC, iT) = iPtCorrectedMI(act, yCue, nBinsCue);
        end
    end

    miCueNorm = nan(size(miCue));
    for iC = 1:nCell
        denom = max(miCue(iC, tIdxTrainInFull), [], 'omitnan');
        if ~isnan(denom) && denom > 0
            miCueNorm(iC, :) = miCue(iC, :) ./ denom;
        end
    end

    % FDR-corrected significance across training-window time points
    sigHitFdr = iFdrAnySig(encPHit(:, tIdxTrainInFull), 0.05);
    sigCueFdr = iFdrAnySig(encPCue(:, tIdxTrainInFull), 0.05);

    % Store per-mouse results
    res = struct();
    res.Mouse = m;
    res.CellUIDs = cellUIDs;
    res.NCells = nCell;
    res.NTrialsHit = nTr;
    res.NHit = sum(yHit==1);
    res.NMiss = sum(yHit==0);
    res.NTrialsCue = nTrCue;
    res.NAudio = sum(yCue==0);
    res.NLight = sum(yCue==1);
    res.Hit.MiRaw = miHit;
    res.Hit.MiNorm = miHitNorm;
    res.Hit.EncP = encPHit;
    res.Hit.SigFdr = sigHitFdr;
    res.Cue.MiRaw = miCue;
    res.Cue.MiNorm = miCueNorm;
    res.Cue.EncP = encPCue;
    res.Cue.SigFdr = sigCueFdr;
    res.TimeVec = xs(tIdxFull);
    resAll{iM} = res;

    fprintf('  Done. Sig cells (FDR q<0.05 in 0-1s): hit/miss=%d/%d, cue=%d/%d\n', ...
        sum(sigHitFdr), nCell, sum(sigCueFdr), nCell);
end

%% 5. Summary and figures
validIdx = find(~cellfun(@isempty, resAll));
nValid = numel(validIdx);
if nValid == 0
    fprintf('No valid mice.\n');
    return;
end

fprintf('\n========== Valid mice: %d =========\n', nValid);
for i = 1:nValid
    r = resAll{validIdx(i)};
    fprintf('  %s: %d cells, hit/miss trials=%d (H=%d, M=%d), cue trials=%d (AW=%d, LW=%d)\n', ...
        r.Mouse, r.NCells, r.NTrialsHit, r.NHit, r.NMiss, r.NTrialsCue, r.NAudio, r.NLight);
end

% --- diagnostic: both-side significant cells, uncorrected vs FDR ---
nBothUnc = 0; nEitherUnc = 0; nBothFdr = 0; nEitherFdr = 0;
for i = 1:nValid
    r = resAll{validIdx(i)};
    uncHit = any(r.Hit.EncP(:, tIdxTrainInFull) < 0.05, 2);
    uncCue = any(r.Cue.EncP(:, tIdxTrainInFull) < 0.05, 2);
    nBothUnc = nBothUnc + sum(uncHit & uncCue);
    nEitherUnc = nEitherUnc + sum(uncHit | uncCue);
    nBothFdr = nBothFdr + sum(r.Hit.SigFdr & r.Cue.SigFdr);
    nEitherFdr = nEitherFdr + sum(r.Hit.SigFdr | r.Cue.SigFdr);
end
fprintf('Both-side significant: uncorrected=%d, FDR=%d (reduced %d, %.1f%%)\n', ...
    nBothUnc, nBothFdr, nBothUnc - nBothFdr, ...
    100 * (nBothUnc - nBothFdr) / max(1, nBothUnc));
fprintf('Either-side significant: uncorrected=%d, FDR=%d\n', nEitherUnc, nEitherFdr);

tVec = xs(tIdxFull);
tTrain = xs(tIdxTrain);

% ---------------------------
% Fig A: MI line plots, one subplot per decoder
% Cells significant in BOTH decoders (FDR q<0.05).
% ---------------------------
miCurveHit = nan(nValid, nTfull);
miCurveCue = nan(nValid, nTfull);
nBothCells = 0;
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigHit = r.Hit.SigFdr;
    sigCue = r.Cue.SigFdr;
    sigBoth = sigHit & sigCue;
    if sum(sigBoth) > 0
        nBothCells = nBothCells + sum(sigBoth);
        miCurveHit(i, :) = mean(r.Hit.MiRaw(sigBoth, :), 1, 'omitnan');
        miCurveCue(i, :) = mean(r.Cue.MiRaw(sigBoth, :), 1, 'omitnan');
    end
end
fprintf('Fig A cells (significant in both decoders): %d\n', nBothCells);

mnHit = mean(miCurveHit, 1, 'omitnan');
seHit = std(miCurveHit, 0, 1, 'omitnan') / sqrt(nValid);
mnCue = mean(miCurveCue, 1, 'omitnan');
seCue = std(miCurveCue, 0, 1, 'omitnan') / sqrt(nValid);

fMI = figure('Name','Dual decoder MI curve','Color','w', ...
    'Position',[180 180 1000 360]);

ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
errorbar(ax1, tVec, mnHit, seHit, '-o', 'Color', [0.85 0.33 0.10], ...
    'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', [0.85 0.33 0.10]);
hold(ax1, 'off');
xlabel(ax1, 'Time from stimulus (s)'); ylabel(ax1, 'MI (bits)');
title(ax1, 'Hit/Miss', 'FontSize', 9, 'FontWeight', 'normal');
xline(ax1, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
box(ax1, 'off');

ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
errorbar(ax2, tVec, mnCue, seCue, '-o', 'Color', [0.10 0.45 0.70], ...
    'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', [0.10 0.45 0.70]);
hold(ax2, 'off');
xlabel(ax2, 'Time from stimulus (s)'); ylabel(ax2, 'MI (bits)');
title(ax2, 'Cue ', 'FontSize', 9, 'FontWeight', 'normal');
xline(ax2, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
box(ax2, 'off');

% ---------------------------
% Fig B: MI heatmap for hit/miss (normalized MI, sorted by peak time)
% ---------------------------
allHitMI = [];
allHitMouse = [];
allHitPeak = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigHit = r.Hit.SigFdr;
    if ~any(sigHit); continue; end

    sigCells = r.Hit.MiNorm(sigHit, :);
    [~, pk] = max(r.Hit.MiNorm(sigHit, tIdxTrainInFull), [], 2, 'omitnan');
    validPk = ~isnan(pk);
    allHitMI = [allHitMI; sigCells(validPk, :)];
    allHitMouse = [allHitMouse; repmat(string(r.Mouse), sum(validPk), 1)];
    allHitPeak = [allHitPeak; tTrain(pk(validPk))];
end
if ~isempty(allHitMI)
    [~, so] = sort(allHitPeak, 'descend');
    allHitMI = allHitMI(so, :);
    allHitMouse = allHitMouse(so);

    fHeatHit = figure('Name','Hit/miss MI heatmap','Color','w', ...
        'Position',[260 260 900 540]);
    ax = axes(fHeatHit);
    imagesc(ax, tVec, 1:size(allHitMI, 1), allHitMI);
    colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 1]);
    cb = colorbar(ax); cb.Label.String = 'Norm. MI';
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Hit/miss cell #');
    title(ax, sprintf('Hit/miss MI heatmap (Transfer-only, N=%d cells)', size(allHitMI, 1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    ax.FontSize = 8; box(ax, 'off');

    mouseList = unique(allHitMouse, 'stable');
    cumC = 0;
    for iM = 1:numel(mouseList)
        nThis = sum(allHitMouse == mouseList(iM));
        cumC = cumC + nThis;
        if cumC < size(allHitMI, 1)
            yline(ax, cumC + 0.5, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.3);
        end
    end
end

% ---------------------------
% Fig C: significant-cell heatmap for hit/miss (raw MI, sorted by peak time)
% ---------------------------
allHitSigMI = [];
allHitSigMouse = [];
allHitSigPeak = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigHit = r.Hit.SigFdr;
    if ~any(sigHit); continue; end

    sigCells = r.Hit.MiRaw(sigHit, :);
    [~, pk] = max(r.Hit.MiRaw(sigHit, tIdxTrainInFull), [], 2, 'omitnan');
    validPk = ~isnan(pk);
    allHitSigMI = [allHitSigMI; sigCells(validPk, :)];
    allHitSigMouse = [allHitSigMouse; repmat(string(r.Mouse), sum(validPk), 1)];
    allHitSigPeak = [allHitSigPeak; tTrain(pk(validPk))];
end
if ~isempty(allHitSigMI)
    [~, so] = sort(allHitSigPeak, 'descend');
    allHitSigMI = allHitSigMI(so, :);
    allHitSigMouse = allHitSigMouse(so);
    maxRaw = max(allHitSigMI(:), [], 'omitnan');
    if maxRaw <= 0; maxRaw = 0.05; end

    fSigHit = figure('Name','Hit/miss significant-cell MI heatmap','Color','w', ...
        'Position',[320 320 900 540]);
    ax = axes(fSigHit);
    imagesc(ax, tVec, 1:size(allHitSigMI, 1), allHitSigMI);
    colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 maxRaw]);
    cb = colorbar(ax); cb.Label.String = 'MI (bits)';
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Significant hit/miss cell #');
    title(ax, sprintf('Hit/miss significant cells (Transfer-only, N=%d cells, p<0.05)', size(allHitSigMI, 1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    ax.FontSize = 8; box(ax, 'off');

    mouseList = unique(allHitSigMouse, 'stable');
    cumC = 0;
    for iM = 1:numel(mouseList)
        nThis = sum(allHitSigMouse == mouseList(iM));
        cumC = cumC + nThis;
        if cumC < size(allHitSigMI, 1)
            yline(ax, cumC + 0.5, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.3);
        end
    end
end

% ---------------------------
% Fig D: MI heatmap for cue (normalized MI, sorted by peak time)
% ---------------------------
allCueMI = [];
allCueMouse = [];
allCuePeak = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigCue = r.Cue.SigFdr;
    if ~any(sigCue); continue; end

    sigCells = r.Cue.MiNorm(sigCue, :);
    [~, pk] = max(r.Cue.MiNorm(sigCue, tIdxTrainInFull), [], 2, 'omitnan');
    validPk = ~isnan(pk);
    allCueMI = [allCueMI; sigCells(validPk, :)];
    allCueMouse = [allCueMouse; repmat(string(r.Mouse), sum(validPk), 1)];
    allCuePeak = [allCuePeak; tTrain(pk(validPk))];
end
if ~isempty(allCueMI)
    [~, so] = sort(allCuePeak, 'descend');
    allCueMI = allCueMI(so, :);
    allCueMouse = allCueMouse(so);

    fHeatCue = figure('Name','Cue MI heatmap','Color','w', ...
        'Position',[340 340 900 540]);
    ax = axes(fHeatCue);
    imagesc(ax, tVec, 1:size(allCueMI, 1), allCueMI);
    colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 1]);
    cb = colorbar(ax); cb.Label.String = 'Norm. MI';
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Cue cell #');
    title(ax, sprintf('Cue MI heatmap (Learned+Transfer, N=%d cells)', size(allCueMI, 1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    ax.FontSize = 8; box(ax, 'off');

    mouseList = unique(allCueMouse, 'stable');
    cumC = 0;
    for iM = 1:numel(mouseList)
        nThis = sum(allCueMouse == mouseList(iM));
        cumC = cumC + nThis;
        if cumC < size(allCueMI, 1)
            yline(ax, cumC + 0.5, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.3);
        end
    end
end

% ---------------------------
% Fig E: significant-cell heatmap for cue (raw MI)
% ---------------------------
allCueSigMI = [];
allCueSigMouse = [];
allCueSigPeak = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigCue = r.Cue.SigFdr;
    if ~any(sigCue); continue; end

    sigCells = r.Cue.MiRaw(sigCue, :);
    [~, pk] = max(r.Cue.MiRaw(sigCue, tIdxTrainInFull), [], 2, 'omitnan');
    validPk = ~isnan(pk);
    allCueSigMI = [allCueSigMI; sigCells(validPk, :)];
    allCueSigMouse = [allCueSigMouse; repmat(string(r.Mouse), sum(validPk), 1)];
    allCueSigPeak = [allCueSigPeak; tTrain(pk(validPk))];
end
if ~isempty(allCueSigMI)
    [~, so] = sort(allCueSigPeak, 'descend');
    allCueSigMI = allCueSigMI(so, :);
    allCueSigMouse = allCueSigMouse(so);
    maxRaw = max(allCueSigMI(:), [], 'omitnan');
    if maxRaw <= 0; maxRaw = 0.05; end

    fSigCue = figure('Name','Cue significant-cell MI heatmap','Color','w', ...
        'Position',[360 360 900 540]);
    ax = axes(fSigCue);
    imagesc(ax, tVec, 1:size(allCueSigMI, 1), allCueSigMI);
    colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 maxRaw]);
    cb = colorbar(ax); cb.Label.String = 'MI (bits)';
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Significant cue cell #');
    title(ax, sprintf('Cue significant cells (Learned+Transfer, N=%d cells, p<0.05)', size(allCueSigMI, 1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xline(ax, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'HandleVisibility', 'off');
    ax.FontSize = 8; box(ax, 'off');

    mouseList = unique(allCueSigMouse, 'stable');
    cumC = 0;
    for iM = 1:numel(mouseList)
        nThis = sum(allCueSigMouse == mouseList(iM));
        cumC = cumC + nThis;
        if cumC < size(allCueSigMI, 1)
            yline(ax, cumC + 0.5, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.3);
        end
    end
end

% ---------------------------
% Fig F: joint significant-cell heatmap (hit/miss or cue)
% Cells enter this plot if either decoder is significant in the training window.
% For each cell, we keep both decoder traces so the joint figure can show the
% cue and hit/miss MI values on the same sorted cell order.
% ---------------------------
allJointHitMI = [];
allJointCueMI = [];
allJointMouse = [];
allJointPrimaryPeak = [];
allJointSecondaryPeak = [];
allJointHitFlag = [];
allJointCueFlag = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    sigHit = r.Hit.SigFdr;
    sigCue = r.Cue.SigFdr;
    sigEither = sigHit | sigCue;
    if ~any(sigEither); continue; end

    cellIdx = find(sigEither);
    nJoint = numel(cellIdx);
    jointHitMI = nan(nJoint, nTfull);
    jointCueMI = nan(nJoint, nTfull);
    primaryPeak = nan(nJoint, 1);
    secondaryPeak = nan(nJoint, 1);
    hitFlag = false(nJoint, 1);
    cueFlag = false(nJoint, 1);

    for iC = 1:nJoint
        c = cellIdx(iC);
        hitPeak = max(r.Hit.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
        cuePeak = max(r.Cue.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
        hitPkTime = NaN;
        cuePkTime = NaN;

        if sigHit(c)
            [~, pkHit] = max(r.Hit.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
            if ~isnan(pkHit)
                hitPkTime = tTrain(pkHit);
            end
        end
        if sigCue(c)
            [~, pkCue] = max(r.Cue.MiRaw(c, tIdxTrainInFull), [], 'omitnan');
            if ~isnan(pkCue)
                cuePkTime = tTrain(pkCue);
            end
        end

        % Show both decoders' raw MI for every joint cell; significance only
        % decides entry and primary/secondary ordering (no NaN halves).
        jointHitMI(iC, :) = r.Hit.MiRaw(c, :);
        jointCueMI(iC, :) = r.Cue.MiRaw(c, :);
        hitFlag(iC) = sigHit(c);
        cueFlag(iC) = sigCue(c);

        if sigHit(c) && sigCue(c)
            if hitPeak >= cuePeak
                primaryPeak(iC) = hitPkTime;
                secondaryPeak(iC) = cuePkTime;
            else
                primaryPeak(iC) = cuePkTime;
                secondaryPeak(iC) = hitPkTime;
            end
        elseif sigHit(c)
            primaryPeak(iC) = hitPkTime;
        elseif sigCue(c)
            primaryPeak(iC) = cuePkTime;
        end
    end

    validRows = any(~isnan(jointHitMI), 2) | any(~isnan(jointCueMI), 2);
    if ~any(validRows); continue; end

    allJointHitMI = [allJointHitMI; jointHitMI(validRows, :)];
    allJointCueMI = [allJointCueMI; jointCueMI(validRows, :)];
    allJointMouse = [allJointMouse; repmat(string(r.Mouse), sum(validRows), 1)];
    allJointPrimaryPeak = [allJointPrimaryPeak; primaryPeak(validRows)];
    allJointSecondaryPeak = [allJointSecondaryPeak; secondaryPeak(validRows)];
    allJointHitFlag = [allJointHitFlag; hitFlag(validRows)];
    allJointCueFlag = [allJointCueFlag; cueFlag(validRows)];
end
if ~isempty(allJointHitMI) || ~isempty(allJointCueMI)
    primaryOrder = allJointPrimaryPeak;
    secondaryOrder = allJointSecondaryPeak;
    primaryOrder(isnan(primaryOrder)) = -inf;
    secondaryOrder(isnan(secondaryOrder)) = -inf;
    [~, so] = sortrows([(-primaryOrder), (-secondaryOrder)], [1 2]);
    allJointHitMI = allJointHitMI(so, :);
    allJointCueMI = allJointCueMI(so, :);
    allJointMouse = allJointMouse(so);
    allJointPrimaryPeak = allJointPrimaryPeak(so);
    allJointSecondaryPeak = allJointSecondaryPeak(so);
    allJointHitFlag = allJointHitFlag(so);
    allJointCueFlag = allJointCueFlag(so);

    nHitOnly = sum(allJointHitFlag & ~allJointCueFlag);
    nCueOnly = sum(allJointCueFlag & ~allJointHitFlag);
    nBoth = sum(allJointHitFlag & allJointCueFlag);
    fprintf('Joint sig cells: hit-only=%d, cue-only=%d, both=%d (N=%d)\n', ...
        nHitOnly, nCueOnly, nBoth, size(allJointHitMI, 1));

    maxRaw = max([allJointHitMI(:); allJointCueMI(:)], [], 'omitnan');
    if maxRaw <= 0; maxRaw = 0.05; end

    fJoint = figure('Name','Joint significant-cell MI heatmap','Color','w', ...
        'Position',[380 380 1100 430]);
    ax = axes(fJoint);
    imagesc(ax, 1:2*nTfull, 1:size(allJointHitMI, 1), [allJointHitMI, allJointCueMI]);
    colormap(ax, iBlueBlackRedCmap()); caxis(ax, [0 maxRaw]);
    cb = colorbar(ax); cb.Label.String = 'MI (bits)';
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Joint sig cell #');
    title(ax, sprintf('Cells significant in hit/miss or cue (N=%d cells)', size(allJointHitMI, 1)), ...
        'FontSize', 9, 'FontWeight', 'normal');
    xline(ax, nTfull + 0.5, '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
    text(ax, nTfull/2, size(allJointHitMI, 1) * 1.03, 'Hit/Miss', ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
    text(ax, 1.5*nTfull, size(allJointHitMI, 1) * 1.03, 'Cue', ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
    ax.XTick = [1:2:nTfull, nTfull+1:2:2*nTfull];
    ax.XTickLabel = string(round([tVec(1:2:end), tVec(1:2:end)], 2));
    ax.FontSize = 8; box(ax, 'off');

    mouseList = unique(allJointMouse, 'stable');
    cumC = 0;
    for iM = 1:numel(mouseList)
        nThis = sum(allJointMouse == mouseList(iM));
        cumC = cumC + nThis;
        if cumC < size(allJointHitMI, 1)
            yline(ax, cumC + 0.5, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.3);
        end
    end
end

fprintf('\nDone. Dual decoder MI analysis complete.\n');

% ==================== Local Functions ====================

function mi = iPtCorrectedMI(act, label, nBins)
% Panzeri-Treves bias-corrected mutual information (bits)
% act: nTrials × 1 neural activity
% label: nTrials × 1 binary label (0/1)
% nBins: number of bins for activity discretization
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
if isempty(joint)
    mi = 0; return;
end
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
    if isempty(p)
        continue;
    end
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

function labShuf = iBuildShuffles(label, nShuf)
% Precompute nShuf random permutations of the label vector (nShuf x n).
n = numel(label);
labShuf = zeros(nShuf, n);
for s = 1:nShuf
    labShuf(s, :) = label(randperm(n));
end
end

function mi = iShuffleCorrectedMI(act, label, nBins, labShuf)
% Shuffle-bias-corrected mutual information (bits).
% mi = max(0, I(act; label) - mean_s I(act; label_shuffled(s)))
% labShuf: precomputed nShuf x n permutation matrix (see iBuildShuffles).
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

jointReal = accumarray([actBin(:), label(:)+1], 1, [nBins 2]);
miReal = iMIFromJoint(jointReal, n);

nShuf = size(labShuf, 1);
miShuf = zeros(nShuf, 1);
for s = 1:nShuf
    joint = accumarray([actBin(:), labShuf(s, :)' + 1], 1, [nBins 2]);
    miShuf(s) = iMIFromJoint(joint, n);
end
mi = max(0, miReal - mean(miShuf));
end

function [X, yHit] = iBuildTransferHitMissMatrix(rawTbl, cellUIDs)
% Build trial matrix for Transfer LightWater only.
% Each trace row is one trial; columns are cells; 3rd dimension is time.
sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);

ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), ...
    'VariableNames', {'CellUID','TrialUID','Behavior'});

sigCell = cell(size(sig, 1), 1);
for i = 1:size(sig, 1)
    sigCell{i} = sig(i, :);
end
ntsTbl.Signal = sigCell;
keepRows = ismember(ntsTbl.CellUID, cellUIDs);
ntsTbl = ntsTbl(keepRows, :);
if isempty(ntsTbl)
    X = [];
    yHit = [];
    return;
end

trialUIDs = unique(ntsTbl.TrialUID);
nTrials = numel(trialUIDs);
nCells = numel(cellUIDs);
X = zeros(nTrials, nCells, nTime);
yHit = nan(nTrials, 1);

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
    if isempty(beh)
        yHit(iT) = NaN;
    else
        yHit(iT) = mode(beh);
    end
end

hasData = all(isfinite(X), [2 3]) & isfinite(yHit);
X = X(hasData, :, :);
yHit = yHit(hasData);
X(isnan(X)) = 0;
end

function [X, yBeh, yCue] = iBuildTrialMatrixWithCue(rawTbl, cellUIDs)
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
    X = [];
    yBeh = [];
    yCue = [];
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
