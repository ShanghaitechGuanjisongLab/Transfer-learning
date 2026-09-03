%% DecodePureCue_CalibMiss.m
% PURE cue decoder: trained ONLY on AudioOnly vs LightOnly trials from
% LAu/LAuW calibration blocks, RESTRICTED to MISS trials in both classes.
% The two training classes are therefore matched on:
%   - context: both from calibration (LAu/LAuW, Naive phase)
%   - behavior: both all-miss (hit rate 0% in both classes)
% so the ONLY difference between the two classes is the stimulus cue.
% This removes both the task-vs-calibration and the hit/miss confounds.
%
% Tested on:
%   1. Naive AudioWater     (expect tendency to audio: P(audio) > 0.5)
%   2. Transfer LightWater  (expect tendency to light: P(audio) < 0.5)
% Output = tendency-to-Audio P(audio) via sigmoid of decoder score.
% Methods: (A) linear readout, (B) GLM naive-Gaussian (Bayes).

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

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);

fprintf('=== PURE cue decoder (calib, miss-only) -> Naive AW / Transfer LW ===\n');
fprintf('Time window: %.2f-%.2f s (%d pts)\n', tVec(1), tVec(end), nTfull);

%% 1. Blocks with phase; define calibration (train) / test blocks
Blk = DS.Blocks;
Blk.Design = string(Blk.Design);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
blkDT = datetime(Blk.DateTime);
if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
mIdx = nan(height(Blk), 1);
ph = repmat("<missing>", height(Blk), 1);
for i = 1:height(Blk)
    idx = find(DT.DateTime == blkDT(i), 1);
    if ~isempty(idx); mIdx(i) = idx; ph(i) = DT.Phase(idx); end
end
Blk.Mouse = DT.Mouse(mIdx);
Blk.Phase = ph;

% Train: AudioOnly + LightOnly from LAu/LAuW calibration blocks (no Recall)
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ...
    ~ismember(Blk.Phase, ["Recall","Final"]));
% Test contexts
naiveAW = Blk.BlockUID(Blk.Design == "AudioWater" & Blk.Phase == "Naive");
transLW = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
fprintf('Calibration blocks (LAu/LAuW): %d; Naive AW: %d; Transfer LW: %d\n', ...
    numel(calBlocks), numel(naiveAW), numel(transLW));

%% 2. Per-mouse trial data (cue: Audio=0, Light=1)
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n========== Data loading (train = calib MISS only) ==========\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    % --- calibration training trials: AudioOnly + LightOnly, MISS only ---
    calTbl = table();
    for st = ["AudioOnly", "LightOnly"]
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus',st), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            t = r{1};
            t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :);
            t = t(~isnan(t.Behavior) & t.Behavior == 0, :);   % MISS only
            if ~isempty(t)
                t.Cue = zeros(height(t),1) + double(st == "LightOnly");
                calTbl = [calTbl; t]; %#ok<AGROW>
            end
        end
    end
    if isempty(calTbl) || ~ismember('TrialSignal', string(calTbl.Properties.VariableNames))
        continue;
    end
    % --- test: Naive AudioWater ---
    teNaive = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Naive'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(teNaive) && ~isempty(teNaive{1}); teNaive = teNaive{1}; else; teNaive = table(); end
    if isempty(teNaive) || ~ismember('TrialSignal', string(teNaive.Properties.VariableNames)); continue; end
    teNaive = teNaive(ismember(uint64(teNaive.BlockUID), uint64(naiveAW)), :);
    % --- test: Transfer LightWater ---
    teTrans = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(teTrans) && ~isempty(teTrans{1}); teTrans = teTrans{1}; else; teTrans = table(); end
    if isempty(teTrans) || ~ismember('TrialSignal', string(teTrans.Properties.VariableNames)); continue; end
    teTrans = teTrans(ismember(uint64(teTrans.BlockUID), uint64(transLW)), :);
    if isempty(teNaive) || isempty(teTrans); continue; end

    cellUIDs = uint64(unique([calTbl.CellUID; teNaive.CellUID; teTrans.CellUID]));
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    Xtr    = iBuildTrialMatrix(calTbl,  cellUIDs, tIdxFull);
    Xnaive = iBuildTrialMatrix(teNaive, cellUIDs, tIdxFull);
    Xtrans = iBuildTrialMatrix(teTrans, cellUIDs, tIdxFull);
    if isempty(Xtr) || isempty(Xnaive) || isempty(Xtrans); continue; end
    yCueTr = iTrialLabel(calTbl, 'Cue');   % calibration cue labels
    if sum(yCueTr==1) < 3 || sum(yCueTr==0) < 3; continue; end
    behNaive = iTrialLabel(teNaive, 'Behavior');
    behTrans = iTrialLabel(teTrans, 'Behavior');

    nUsed = nUsed + 1;
    res = struct('Mouse',m,'NCells',nCell, ...
        'Xtr',Xtr,'Xnaive',Xnaive,'Xtrans',Xtrans, ...
        'yCueTr',yCueTr,'behNaive',behNaive,'behTrans',behTrans);
    resAll{nUsed} = res;
    fprintf('  %-9s cells=%3d  calibMiss(tr)=%d (Au%d/Li%d)  naiveAW=%d  transLW=%d\n', ...
        m, nCell, size(Xtr,1), sum(yCueTr==0), sum(yCueTr==1), ...
        size(Xnaive,1), size(Xtrans,1));
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 3. Decode: tendency-to-Audio (P) on Naive AW and Transfer LW
methods = {'linear','glm'};
nPool = 3;   % 1=all, 2=hit, 3=miss
pNaive = nan(nValid, 2, nPool, nTfull);   % (mouse, method, pool, time)
pTrans = nan(nValid, 2, nPool, nTfull);
for i = 1:nValid
    r = resAll{i};
    Xtr = r.Xtr; yt = r.yCueTr;
    okTr = ~isnan(yt);
    for iT = 1:nTfull
        Ftr = Xtr(:, :, iT);
        FtrOK = Ftr(okTr,:); ytOK = yt(okTr);
        for met = 1:2
            bal = iBalanceTrain(ytOK);
            if met == 1
                [sN, ~] = iLinDecode(FtrOK(bal,:), ytOK(bal), r.Xnaive(:,:,iT));
                [sT, ~] = iLinDecode(FtrOK(bal,:), ytOK(bal), r.Xtrans(:,:,iT));
            else
                [sN, ~] = iGlmDecode(FtrOK(bal,:), ytOK(bal), r.Xnaive(:,:,iT));
                [sT, ~] = iGlmDecode(FtrOK(bal,:), ytOK(bal), r.Xtrans(:,:,iT));
            end
            pnA = 1./(1+exp(sN));   % P(audio) on Naive AudioWater
            ptA = 1./(1+exp(sT));   % P(audio) on Transfer LightWater
            pNaive(i,met,1,iT) = mean(pnA,'omitnan');
            pTrans(i,met,1,iT) = mean(ptA,'omitnan');
            for p = 2:3             % hit (p=2), miss (p=3)
                sel = (r.behNaive == (3-p));   % 1 -> hit, 0 -> miss
                if sum(sel) >= 2; pNaive(i,met,p,iT) = mean(pnA(sel)); end
                sel = (r.behTrans == (3-p));
                if sum(sel) >= 2; pTrans(i,met,p,iT) = mean(ptA(sel)); end
            end
        end
    end
end

%% 4. Figures: P(audio) on Naive AudioWater vs Transfer LightWater
poolNames = {'all','hit','miss'};
pcols = {[0 0 0], [0.30 0.60 0.20], [0.70 0.30 0.70]};
for met = 1:2
    f = figure('Name', sprintf('Pure cue decoder (%s) - tendency to Audio', methods{met}), ...
        'Color','w', 'Position',[100 100 1100 420]);
    for ctx = 1:2
        ax = subplot(1,2,ctx); hold(ax,'on');
        if ctx == 1
            V = pNaive; ttl = 'Naive AudioWater'; ctxCol = [0.10 0.45 0.70];
        else
            V = pTrans; ttl = 'Transfer LightWater'; ctxCol = [0.85 0.33 0.10];
        end
        for p = 1:nPool
            vals = squeeze(V(:,met,p,:));
            if all(isnan(vals(:))); continue; end
            mn = mean(vals,1,'omitnan');
            se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
            lc = pcols{p}; if p == 1; lc = ctxCol; end
            errorbar(ax, tVec, mn, se, '-', 'Color', lc, 'LineWidth', 1.8, ...
                'MarkerSize',3, 'DisplayName', poolNames{p});
        end
        yline(ax, 0.5, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility','off');
        xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility','off');
        xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'P(audio) (0=light, 1=audio)');
        title(ax, ttl, 'FontSize',10, 'FontWeight','normal');
        legend(ax,'Location','northwest','Box','off','FontSize',7);
        box(ax,'off'); ax.FontSize = 8;
    end
    sgtitle(f, sprintf('PURE cue decoder: calib AudioOnly/LightOnly MISS-only - %s', methods{met}), ...
        'FontSize', 10);
end

fprintf('\nDone. Pure cue decoder complete.\n');

% ==================== Local Functions ====================

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

function y = iTrialLabel(rawTbl, varName)
tu = unique(uint64(rawTbl.TrialUID));
y = nan(numel(tu),1);
for iT = 1:numel(tu)
    v = rawTbl.(varName)(uint64(rawTbl.TrialUID)==tu(iT));
    y(iT) = mode(v);
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
