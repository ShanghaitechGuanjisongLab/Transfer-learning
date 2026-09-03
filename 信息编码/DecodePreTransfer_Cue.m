%% DecodePreTransfer_Cue.m
% Cue decoder (Light vs Audio) trained on PRE-TRANSFER data
% (Naive + Learned + unannotated-phase AudioWater, plus AudioOnly / LightOnly
% trials from LAu/LAuW blocks; NO Recall), tested on Stage-1 (pre-Transfer)
% and Stage-2 (Transfer LightWater) trial subsets.
%
% Methods: (A) linear readout, (B) GLM naive-Gaussian (Bayes).
% Stage-1 performance: 5-fold CV (out-of-fold); Stage-2: held-out (Transfer).
% Metrics (per time point): decoded MI (bits), balanced accuracy,
% mean decoder output per trial subset (control curves).
%
% Split out from DecodePreTransfer_ChoiceCuePerf.m for standalone adjustment.

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
doBaselineNorm = true;   % subtract pre-stimulus baseline per trial-cell

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);

fprintf('=== Pre-Transfer CUE decoder ===\n');
fprintf('Time window: %.2f-%.2f s (%d pts)\n', tVec(1), tVec(end), nTfull);

%% 1. Blocks with phase; define training / test blocks
Blk = DS.Blocks;
Blk.Design = string(Blk.Design);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
blkDT = datetime(Blk.DateTime);
if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
ph = repmat("<missing>", height(Blk), 1);
for i = 1:height(Blk)
    idx = find(DT.DateTime == blkDT(i), 1);
    if ~isempty(idx); ph(i) = DT.Phase(idx); end
end
Blk.Phase = ph;

trainAW  = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
testLW   = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
fprintf('Train blocks: AW=%d; Test blocks (Transfer LW)=%d\n', numel(trainAW), numel(testLW));

%% 2. Per-mouse trial data (cue labels: Audio=0, Light=1)
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n========== Data loading ==========\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    allTbl = table();
    % AudioWater (train, cue1=audio)
    try
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            t = r{1};
            t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
            if ~isempty(t); t.Cue = zeros(height(t),1); t.Src = ones(height(t),1); allTbl = [allTbl; t]; end %#ok<AGROW>  % Src=1 AudioWater
        end
    catch
    end
    % AudioOnly (LAu/LAuW, train cue1=audio)
    try
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            t = r{1};
            if ~isempty(t); t.Cue = zeros(height(t),1); t.Src = 2*ones(height(t),1); allTbl = [allTbl; t]; end %#ok<AGROW>  % Src=2 AudioOnly
        end
    catch
    end
    % LightOnly (LAu/LAuW, train cue2=light)
    try
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            t = r{1};
            if ~isempty(t); t.Cue = ones(height(t),1); t.Src = 3*ones(height(t),1); allTbl = [allTbl; t]; end %#ok<AGROW>  % Src=3 LightOnly
        end
    catch
    end
    if isempty(allTbl) || ~ismember('TrialSignal', string(allTbl.Properties.VariableNames))
        continue;
    end
    bu = uint64(allTbl.BlockUID);
    allTbl.Perf = arrayfun(@(b) Blk.Performance(find(Blk.BlockUID == b, 1)), bu);
    allTbl = allTbl(~isnan(allTbl.Behavior) & ~isnan(allTbl.Perf), :);
    if isempty(allTbl); continue; end
    % Transfer LightWater (test stage2, cue2=light)
    testTbl = table();
    try
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            testTbl = r{1};
            testTbl = testTbl(ismember(uint64(testTbl.BlockUID), uint64(testLW)), :);
        end
    catch
    end
    if isempty(testTbl) || ~ismember('TrialSignal', string(testTbl.Properties.VariableNames))
        continue;
    end
    testTbl.Cue = ones(height(testTbl),1);
    tbu = uint64(testTbl.BlockUID);
    testTbl.Perf = arrayfun(@(b) Blk.Performance(find(Blk.BlockUID == b, 1)), tbu);
    testTbl = testTbl(~isnan(testTbl.Behavior) & ~isnan(testTbl.Perf), :);
    if isempty(testTbl); continue; end

    cellUIDs = uint64(unique([allTbl.CellUID; testTbl.CellUID]));
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    Xtr = iBuildTrialMatrix(allTbl, cellUIDs, tIdxFull);
    Xte = iBuildTrialMatrix(testTbl, cellUIDs, tIdxFull);
    if isempty(Xtr) || isempty(Xte); continue; end
    if doBaselineNorm
        baseIdx = find(tVec < 0);
        Xtr = iBaselineNorm(Xtr, baseIdx);
        Xte = iBaselineNorm(Xte, baseIdx);
    end
    nTr = size(Xtr,1); nTe = size(Xte,1);

    yCueTr = iTrialLabel(allTbl, 'Cue');   % cue label (train)
    yCueTe = iTrialLabel(testTbl, 'Cue');  % cue label (test, all =1)
    yBehTr = iTrialLabel(allTbl, 'Behavior');   % per-trial hit/miss
    if sum(yCueTr==1) < 3 || sum(yCueTr==0) < 3; continue; end

    [sub1, sub1Name] = iTagStage1(allTbl);   % per-trial subset index (0 = none)
    [sub2, sub2Name] = iTagStage2(testTbl);

    nUsed = nUsed + 1;
    res = struct();
    res.Mouse = m;
    res.NCells = nCell;
    res.Xtr = Xtr; res.Xte = Xte;
    res.yCueTr = yCueTr; res.yCueTe = yCueTe;
    res.cueTr = yCueTr; res.behTr = yBehTr;
    res.srcTr = iTrialLabel(allTbl, 'Src');   % 1=AudioWater, 2=AudioOnly, 3=LightOnly
    res.behTe = iTrialLabel(testTbl, 'Behavior');   % per-trial behavior (Transfer)
    res.sub1 = sub1; res.sub1Name = sub1Name;
    res.sub2 = sub2; res.sub2Name = sub2Name;
    resAll{nUsed} = res;
    fprintf('  %s: %d cells, train %d (Audio%d/Light%d), test %d\n', ...
        m, nCell, nTr, sum(yCueTr==0), sum(yCueTr==1), nTe);
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 3. Cue decoder: per-time-point evaluation
methods = {'linear','glm'};
nS1 = numel(resAll{1}.sub1Name);
nS2 = numel(resAll{1}.sub2Name);
K = 5;

miPool  = nan(nValid, 2, 2, nTfull);   % (mouse, method, stage, time)
balPool = nan(nValid, 2, 2, nTfull);
subMet  = nan(nValid, 2, nS1+nS2, 2, 3, nTfull);  % (mouse, method, subset, stage, metric, time); metric: 1=MI, 2=balacc, 3=output
pLight  = nan(nValid, 2, nTfull);   % stage2: pooled mean P(light) over Transfer trials
pAudioS = nan(nValid, 2, nS2, nTfull);  % stage2: P(audio) per subset (light hit/miss)
pAudioS1 = nan(nValid, 2, nS1, nTfull); % stage1: P(audio) per subset (out-of-fold)
pHitBeh = nan(nValid, 2, 2, 2, nTfull); % (mouse, method, stage, beh hit/miss, time): mean tendency-to-hit by behavior
behAcc    = nan(nValid, 2, 2, nTfull);    % (mouse, method, stage, time): hit/miss bal. acc. from cue score

for i = 1:nValid
    r = resAll{i};
    Xtr = r.Xtr; Xte = r.Xte;
    yt = r.yCueTr; yte = r.yCueTe;
    okTr = ~isnan(yt);
    for iT = 1:nTfull
        Ftr = Xtr(:, :, iT); Fte = Xte(:, :, iT);
        FtrOK = Ftr(okTr,:); ytOK = yt(okTr);
        for met = 1:2
            [sOOF, pOOF] = iCvPredict(FtrOK, ytOK, K, met);
            balTr = iBalanceTrain(ytOK);
            if met == 1
                [sTe, pTe] = iLinDecode(FtrOK(balTr,:), ytOK(balTr), Fte);
            else
                [sTe, pTe] = iGlmDecode(FtrOK(balTr,:), ytOK(balTr), Fte);
            end
            miPool(i,met,1,iT)  = iMIFromLabels(pOOF, ytOK);
            balPool(i,met,1,iT) = iBalAcc(pOOF, ytOK);
            miPool(i,met,2,iT)  = iMIFromLabels(pTe, yte);
            balPool(i,met,2,iT) = iBalAcc(pTe, yte);
            % stage2 tendency: P(light) via sigmoid of decoder score
            % (for the GLM naive-Bayes decoder this is the exact posterior;
            %  for the linear readout it is a monotone 0-1 tendency score)
            pTeL = 1./(1+exp(-sTe));
            pLight(i,met,iT) = mean(pTeL, 'omitnan');
            for s = 1:nS2
                idx = r.sub2 == s;
                if sum(idx) < 2; continue; end
                pAudioS(i,met,s,iT) = mean(1 - pTeL(idx));   % P(audio) = 1 - P(light)
            end
            subOK = r.sub1(okTr);
            pOOF_L = 1./(1+exp(-sOOF));
            % overlapping Stage1 pools: cue1 only, cue2 only, cue1 hit, cue1 miss
            cOK = r.cueTr(okTr); bOK = r.behTr(okTr);
            masks = {cOK==0, cOK==1, cOK==0 & bOK==1, cOK==0 & bOK==0};
            for s = 1:4
                idx = masks{s};
                if sum(idx) < 2; continue; end
                subMet(i,met,s,1,1,iT) = iMIFromLabels(pOOF(idx), ytOK(idx));
                subMet(i,met,s,1,2,iT) = iBalAcc(pOOF(idx), ytOK(idx));
                subMet(i,met,s,1,3,iT) = mean(sOOF(idx));
                pAudioS1(i,met,s,iT) = mean(1 - pOOF_L(idx));   % P(audio) = 1 - P(light)
            end
            for s = 1:nS2
                idx = r.sub2 == s;
                if sum(idx) < 2; continue; end
                subMet(i,met,nS1+s,2,1,iT) = iMIFromLabels(pTe(idx), yte(idx));
                subMet(i,met,nS1+s,2,2,iT) = iBalAcc(pTe(idx), yte(idx));
                subMet(i,met,nS1+s,2,3,iT) = mean(sTe(idx));
            end
            % --- hit/miss control: does the CUE decoder also separate behavior? ---
            % Stage1 control = AudioWater only (audio task), Stage2 = LightWater (light task)
            behOK = r.behTr(okTr);
            awOK = r.srcTr(okTr) == 1;   % AudioWater trials only
            pHit = 1./(1+exp(sOOF));   % tendency to hit = sigmoid(-score); score>0 -> light/miss
            if sum(awOK) >= 4
                behAcc(i,met,1,iT) = iBalAcc(double(sOOF(awOK) < 0), behOK(awOK));
                pHitBeh(i,met,1,1,iT) = mean(pHit(awOK & behOK==1));
                pHitBeh(i,met,1,2,iT) = mean(pHit(awOK & behOK==0));
            end
            behTe = r.behTe;
            if ~isempty(behTe)
                pHitTe = 1./(1+exp(sTe));   % tendency to hit on Transfer
                % On Transfer (all light) the decoder maps hit trials to the
                % audio-like (score<0) side (see pHitBeh), so predict hit by score<0.
                behAcc(i,met,2,iT) = iBalAcc(double(sTe < 0), behTe);
                pHitBeh(i,met,2,1,iT) = mean(pHitTe(behTe==1));
                pHitBeh(i,met,2,2,iT) = mean(pHitTe(behTe==0));
            end
        end
    end
end

%% 4. Figures: one big figure per model = [Stage1 MI] [Stage1 tendency] [Stage2 tendency]
% Stage-1 decodes audio vs light (both cue classes present -> MI meaningful).
% Stage-2 (Transfer) is all-light, so instead of the degenerate MI we show the
% calibrated posterior probability of "audio", P(audio) (0=light, 1=audio),
% as a function of time.
for met = 1:2
    f = figure('Name', sprintf('Decode Cue (%s) - MI / Stage1 / Stage2', methods{met}), ...
        'Color','w', 'Position',[60 80 1900 430]);
    % --- Panel 1: Stage 1 decoded MI ---
    ax = subplot(1,3,1); hold(ax,'on');
    vals = squeeze(miPool(:,met,1,:));
    mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color', [0 0 0], 'LineWidth', 1.8, 'MarkerSize', 4, ...
        'DisplayName', iStageName(1));
    hold(ax,'off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoded MI (bits)');
    title(ax, 'Stage1: decoded MI (pre-Transfer)','FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',8);
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    box(ax,'off'); ax.FontSize = 8;
    % --- Panel 2: Stage 1 tendency to Audio (posterior P) per subset ---
    ax = subplot(1,3,2); hold(ax,'on');
    s1cols = {[0.85 0.33 0.10], [0.10 0.45 0.70], [0.30 0.60 0.20], [0.70 0.30 0.70]};
    for s = 1:4   % audio only, light only, audio hit, audio miss
        vals = squeeze(pAudioS1(:,met,s,:));
        if all(isnan(vals(:))); continue; end
        mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
        errorbar(ax, tVec, mn, se, '-', 'Color', s1cols{s}, 'LineWidth', 1.6, ...
            'MarkerSize', 3, 'DisplayName', resAll{1}.sub1Name{s});
    end
    yline(ax, 0.5, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility','off');
    hold(ax,'off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'P(audio) (0=light, 1=audio)');
    title(ax, 'Stage1: tendency to Audio (pre-Transfer)','FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    box(ax,'off'); ax.FontSize = 8;
    % --- Panel 3: Stage 2 tendency to Audio (posterior P), light hit vs miss ---
    ax = subplot(1,3,3); hold(ax,'on');
    s2cols = {[0.85 0.33 0.10], [0.20 0.20 0.80]};
    for s = 1:nS2
        vals = squeeze(pAudioS(:,met,s,:));
        if all(isnan(vals(:))); continue; end
        mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
        errorbar(ax, tVec, mn, se, '-', 'Color', s2cols{s}, 'LineWidth', 1.8, ...
            'MarkerSize', 4, 'DisplayName', resAll{1}.sub2Name{s});
    end
    yline(ax, 0.5, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility','off');
    hold(ax,'off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'P(audio) (0=light, 1=audio)');
    title(ax, 'Stage2: tendency to Audio (Transfer)','FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',8);
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    box(ax,'off'); ax.FontSize = 8;
end

%% 4b. Control: does the CUE decoder also decode hit/miss (performance)?
% Using the cue-decoder score as a predictor of behavior. In training the cue
% axis is confounded with performance (audio mostly hit, light mostly miss),
% so if the cue decoder also separates hit vs miss it reads performance too.
bnames = {'hit','miss'};
for met = 1:2
    f = figure('Name', sprintf('Decode Cue (%s) - hit/miss control', methods{met}), ...
        'Color','w', 'Position',[80 80 1060 760]);
    % Stage1: tendency to hit for AudioWater hit vs miss (out-of-fold)
    ax = subplot(2,2,1); hold(ax,'on');
    cols = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
    for b = 1:2
        vals = squeeze(pHitBeh(:,met,1,b,:));
        if all(isnan(vals(:))); continue; end
        mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
        errorbar(ax, tVec, mn, se, '-', 'Color', cols{b}, 'LineWidth', 1.6, ...
            'MarkerSize',3, 'DisplayName', sprintf('AW %s', bnames{b}));
    end
    yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'P(hit) (0=miss, 1=hit)');
    title(ax,'Stage1: AudioWater hit vs miss','FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',6);
    box(ax,'off'); ax.FontSize = 8;
    % Stage2: tendency to hit for Transfer LightWater hit vs miss
    ax = subplot(2,2,2); hold(ax,'on');
    for b = 1:2
        vals = squeeze(pHitBeh(:,met,2,b,:));
        if all(isnan(vals(:))); continue; end
        mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
        errorbar(ax, tVec, mn, se, '-', 'Color', cols{b}, 'LineWidth', 1.6, ...
            'MarkerSize',3, 'DisplayName', sprintf('LW %s', bnames{b}));
    end
    yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'P(hit) (0=miss, 1=hit)');
    title(ax,'Stage2: LightWater hit vs miss','FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize = 8;
    % Stage1: hit/miss balanced accuracy from cue score
    ax = subplot(2,2,3); hold(ax,'on');
    vals = squeeze(behAcc(:,met,1,:));
    mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color', [0 0 0], 'LineWidth', 1.8, ...
        'MarkerSize',3, 'DisplayName','hit/miss from cue score');
    yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Balanced accuracy');
    title(ax,'Stage1: decode AudioWater hit/miss with cue decoder','FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize = 8;
    % Stage2: hit/miss balanced accuracy from cue score
    ax = subplot(2,2,4); hold(ax,'on');
    vals = squeeze(behAcc(:,met,2,:));
    mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color', [0 0 0], 'LineWidth', 1.8, ...
        'MarkerSize',3, 'DisplayName','hit/miss from cue score');
    yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Balanced accuracy');
    title(ax,'Stage2: decode LightWater hit/miss with cue decoder','FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize = 8;
end

fprintf('\nDone. Pre-Transfer CUE decoder complete.\n');

% ==================== Local Functions ====================

function nm = iStageName(st)
if st==1; nm = 'Stage1 (pre-Transfer, CV)'; else; nm = 'Stage2 (Transfer)'; end
end

function nm = iMetricName(q)
if q==1; nm = 'Decoded MI'; else; nm = 'Balanced accuracy'; end
end

function X = iBuildTrialMatrix(rawTbl, cellUIDs, tIdx)
sig = double(rawTbl.TrialSignal);
sig = sig(:, tIdx);
nts = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), 'VariableNames',{'CellUID','TrialUID'});
sigCell = cell(size(sig,1),1);
for i = 1:size(sig,1); sigCell{i} = sig(i,:); end %#ok<AGROW>
nts.Signal = sigCell;
nts = nts(ismember(nts.CellUID, cellUIDs), :);
if isempty(nts); X=[]; return; end
tu = unique(nts.TrialUID);
X = zeros(numel(tu), numel(cellUIDs), size(sig,2));
for iT = 1:numel(tu)
    rows = nts(nts.TrialUID == tu(iT), :);
    [~, loc] = ismember(rows.CellUID, cellUIDs);
    for iR = 1:height(rows)
        ci = loc(iR);
        if ci > 0; X(iT, ci, :) = rows.Signal{iR}; end
    end
end
end

function X = iBaselineNorm(X, baseIdx)
% Subtract each (trial, cell) mean baseline (pre-stimulus) activity from the
% whole trial time course, removing context/baseline offsets.
mu = mean(X(:, :, baseIdx), 3);
X = X - mu;
end

function y = iTrialLabel(rawTbl, varName)
tu = unique(uint64(rawTbl.TrialUID));
y = nan(numel(tu),1);
for iT = 1:numel(tu)
    v = rawTbl.(varName)(uint64(rawTbl.TrialUID)==tu(iT));
    y(iT) = mode(v);
end
end

function [tag, name] = iTagStage1(rawTbl)
% non-exclusive trial pools: 1=audio only, 2=light only, 3=audio hit,
% 4=audio miss, 5=light hit, 6=light miss
c = iTrialLabel(rawTbl,'Cue'); b = iTrialLabel(rawTbl,'Behavior');
n = numel(c);
tag = zeros(n,1);
tag(c==0) = 1;
tag(c==1) = 2;
for i = 1:n
    if isnan(b(i)); continue; end
    if c(i)==0 && b(i)==1; tag(i)=3; end
    if c(i)==0 && b(i)==0; tag(i)=4; end
    if c(i)==1 && b(i)==1; tag(i)=5; end
    if c(i)==1 && b(i)==0; tag(i)=6; end
end
name = {'audio only','light only','audio hit','audio miss','light hit','light miss'};
end

function [tag, name] = iTagStage2(rawTbl)
b = iTrialLabel(rawTbl,'Behavior');
tag = ones(numel(b),1);
tag(b==0) = 2;
name = {'light hit','light miss'};
end

function [sOOF, pOOF] = iCvPredict(F, y, K, met)
n = size(F,1);
sOOF = nan(n,1); pOOF = nan(n,1);
perm = randperm(n);
foldSize = ceil(n/K);
for k = 1:K
    te = false(n,1);
    idx = (k-1)*foldSize+1 : min(k*foldSize, n);
    te(perm(idx)) = true;
    tr = ~te;
    if sum(y(te)==1) < 1 || sum(y(te)==0) < 1
        maj = mode(y(tr));
        sOOF(te) = 2*maj-1; pOOF(te) = maj; continue;
    end
    bal = iBalanceTrain(y(tr));
    idxTr = find(tr);
    if met == 1
        [sOOF(te), pOOF(te)] = iLinDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:));
    else
        [sOOF(te), pOOF(te)] = iGlmDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:));
    end
end
end

function bal = iBalanceTrain(y)
idx1 = find(y==1); idx0 = find(y==0);
n = min(numel(idx1), numel(idx0));
idx1 = idx1(randperm(numel(idx1), n));
idx0 = idx0(randperm(numel(idx0), n));
bal = [idx1; idx0];
end

function [score, pred] = iLinDecode(Ftr, ytr, Fte)
mu = mean(Ftr,1); sd = std(Ftr,0,1); sd(sd==0)=1;
Ftrs = (Ftr-mu)./sd; Ftes = (Fte-mu)./sd;
w = pinv([ones(size(Ftrs,1),1), Ftrs])*(2*ytr-1);
score = [ones(size(Ftes,1),1), Ftes]*w;
pred = double(score >= 0);
end

function [score, pred] = iGlmDecode(Ftr, ytr, Fte)
m0 = mean(Ftr(ytr==0,:),1); m1 = mean(Ftr(ytr==1,:),1);
s0 = std(Ftr(ytr==0,:),0,1); s1 = std(Ftr(ytr==1,:),0,1);
sp = sqrt((s0.^2 + s1.^2)/2); sp(sp==0)=1;
score = sum((Fte - m0).^2./(2*sp.^2) - (Fte - m1).^2./(2*sp.^2), 2);
pred = double(score >= 0);
end

function bal = iBalAcc(pred, lab)
a0 = mean(pred(lab==0)==0); a1 = mean(pred(lab==1)==1);
bal = mean([a0, a1], 'omitnan');
end

function mi = iMIFromLabels(pred, lab)
n = numel(lab);
if n < 4 || numel(unique(lab)) < 2; mi = 0; return; end
joint = accumarray([pred(:)+1, lab(:)+1], 1, [2 2]);
mi = iMIFromJoint(joint, n);
end

function mi = iMIFromJoint(joint, n)
joint(sum(joint,2)==0,:) = [];
if isempty(joint); mi=0; return; end
p = joint/sum(joint(:));
px = sum(p,2); py = sum(p,1);
miRaw = 0;
for i=1:size(p,1)
    for j=1:size(p,2)
        if p(i,j)>0 && px(i)>0 && py(j)>0
            miRaw = miRaw + p(i,j)*log2(p(i,j)/(px(i)*py(j)));
        end
    end
end
Mx = size(p,1); My = size(p,2);
mi = max(0, miRaw - (Mx-1)*(My-1)/(2*n*log(2)));
end
