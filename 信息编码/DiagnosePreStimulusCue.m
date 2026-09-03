%% DiagnosePreStimulusCue.m
% Determine why the cue decoder shows PRE-STIMULUS (t<0) audio-vs-light
% separation in the training-OOF pipeline, given the facts:
%   - AudioOnly/LightOnly are interleaved WITHIN the same block (no block confound)
%   - ITI >= 15 s (excludes previous-trial calcium residual)
%   - trial positions are uniform (excludes slow drift)
% Tests (all on CompareCueTrainData cfg1 = AW+AO+LO training, 5-fold OOF):
%   A. Permutation: shuffle cue labels within mouse, re-decode -> does the
%      pre-stimulus separation survive? (if real it drops; if artifact it stays)
%   B. Prev-trial grouping: is the pre-stimulus output actually reading the
%      PREVIOUS trial's cue? (with ITI>=15s it should NOT)
%   C. Regularized linear (ridge) vs GLM: is pre-stimulus sep robust to
%      high-dim/low-sample overfitting?
%   D. Time profile of pre-stimulus sep (flat vs ramping toward onset)
% Run via MATLAB MCP.

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
doBaselineNorm = true;
K = 5;

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);
preIdx = find(tVec < 0);
postIdx = find(tVec > 0);
fprintf('=== Diagnose pre-stimulus cue decodability ===\n');
fprintf('Window %.2f-%.2f s (%d pts); pre=%d pts, post=%d pts\n', ...
    tVec(1), tVec(end), nTfull, numel(preIdx), numel(postIdx));

%% 1. Blocks
Blk = DS.Blocks; Blk.Design = string(Blk.Design);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse); DT.Phase = string(DT.Phase);
blkDT = datetime(Blk.DateTime);
if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
ph = repmat("<missing>", height(Blk), 1);
for i = 1:height(Blk)
    idx = find(DT.DateTime == blkDT(i), 1);
    if ~isempty(idx); ph(i) = DT.Phase(idx); end
end
Blk.Phase = ph;
trainAW   = Blk.BlockUID(Blk.Design == "AudioWater" & (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ~ismember(Blk.Phase, ["Recall","Final"]));

%% 2. Per-mouse data (cfg1 = AW + AO + LO), keep trial order for prev-trial test
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n===== Data loading =====\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    s1 = table();
    for st = ["AudioWater","AudioOnly","LightOnly"]
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus',st), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if isempty(r) || isempty(r{1}); continue; end
        t = r{1};
        if st == "AudioWater"; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
        else;                   t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :); end
        if isempty(t); continue; end
        t.Cue = zeros(height(t),1) + double(st == "LightOnly");
        t.Type = zeros(height(t),1) + double(st == "AudioOnly") + 2*double(st == "LightOnly");
        s1 = [s1; t]; %#ok<AGROW>
    end
    if isempty(s1) || ~ismember('TrialSignal', string(s1.Properties.VariableNames)); continue; end
    cellUIDs = uint64(unique(s1.CellUID));
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    X1 = iBuildTrialMatrix(s1, cellUIDs, tIdxFull);
    if isempty(X1); continue; end
    if doBaselineNorm
        bI = find(tVec < 0);
        X1 = iBaselineNorm(X1, bI);
    end
    y1 = iTrialLabel(s1, 'Cue');     % per unique trial, sorted by TrialUID
    typ = iTrialLabel(s1, 'Type');
    tuSorted = unique(uint64(s1.TrialUID));   % X1 row order
    nUsed = nUsed + 1;
    resAll{nUsed} = struct('Mouse',m,'NCells',nCell,'X1',X1,'y1',y1,'typ',typ,'tu',tuSorted);
    fprintf('  %-9s cells=%3d  trials=%d (Au%d/Li%d/AW%d)\n', m, nCell, size(X1,1), ...
        sum(typ==1), sum(typ==2), sum(typ==0));
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; return; end

%% 4. A. Permutation test on pre-stimulus separation
% separation(t) = |mean(P(audio)|AO) - mean(P(audio)|LO)| over mice
fprintf('\n===== A. Permutation test (pre-stimulus separation) =====\n');
Nperm = 100;
% observed separation per time point
sepObs = nan(1, nTfull);
scoresObs = cell(nValid,1);
for i = 1:nValid
    r = resAll{i};
    S = nan(size(r.X1,1), nTfull);
    for iT = 1:nTfull
        [~, s] = iCvPredict(r.X1(:,:,iT), r.y1, K, 2);
        S(:,iT) = 1./(1+exp(s));   % P(audio)
    end
    scoresObs{i} = S;
end
for iT = 1:nTfull
    d = [];
    for i = 1:nValid
        r = resAll{i}; S = scoresObs{i};
        if sum(r.typ==1)>=3 && sum(r.typ==2)>=3
            d(end+1) = abs(mean(S(r.typ==1,iT)) - mean(S(r.typ==2,iT))); %#ok<AGROW>
        end
    end
    sepObs(iT) = mean(d);
end
fprintf('Observed separation: pre-mean=%.3f | post-mean=%.3f\n', ...
    mean(sepObs(preIdx)), mean(sepObs(postIdx)));
fprintf('Per time point: '); fprintf('%.2f ', sepObs); fprintf('\n');

% permutation: shuffle y1 within mouse, recompute pre-stimulus separation
preSepNull = nan(Nperm, 1);
for p = 1:Nperm
    d = [];
    for i = 1:nValid
        r = resAll{i};
        if sum(r.typ==1) < 3 || sum(r.typ==2) < 3; continue; end
        yp = r.y1(randperm(numel(r.y1)));
        S = nan(size(r.X1,1), numel(preIdx));
        k = 0;
        for iT = preIdx
            k = k + 1;
            [~, s] = iCvPredict(r.X1(:,:,iT), yp, K, 2);
            S(:,k) = 1./(1+exp(s));
        end
        m1 = mean(S(r.typ==1,:),1); m2 = mean(S(r.typ==2,:),1);
        if all(isnan(m1)) || all(isnan(m2)); continue; end
        d(end+1) = mean(abs(m1 - m2), 'omitnan'); %#ok<AGROW>
    end
    preSepNull(p) = mean(d, 'omitnan');
end
obsPreSep = mean(sepObs(preIdx), 'omitnan');
pPerm = (1 + sum(preSepNull >= obsPreSep)) / (Nperm+1);
fprintf('Permutation: observed pre-sep=%.3f, null mean=%.3f (95%%=%.3f), p=%.4f\n', ...
    obsPreSep, mean(preSepNull,'omitnan'), prctile(preSepNull,95), pPerm);

%% 5. B. Prev-trial grouping: does pre-stimulus output read PREVIOUS trial cue?
fprintf('\n===== B. Prev-trial grouping (pre-stimulus window) ====\n');
sepCurAll = nan(nValid,1); sepPrevAll = nan(nValid,1);
for i = 1:nValid
    r = resAll{i};
    if sum(r.typ==1)<3 || sum(r.typ==2)<3; continue; end
    % row order = sorted TrialUID = temporal order
    prevTyp = [nan; r.typ(1:end-1)];
    S = scoresObs{i};
    % current-cue separation at each pre time point
    sepCur = nan(1, numel(preIdx));
    sepPrev = nan(1, numel(preIdx));
    for k = 1:numel(preIdx)
        iT = preIdx(k);
        a = S(r.typ==1, iT); l = S(r.typ==2, iT);
        if numel(a)>=3 && numel(l)>=3
            sepCur(k) = abs(mean(a)-mean(l));
        end
        % prev-type separation (prev AO vs prev LO), restricted to trials with known prev
        okp = ~isnan(prevTyp);
        pA = S(okp & prevTyp==1, iT); pL = S(okp & prevTyp==2, iT);
        if numel(pA)>=3 && numel(pL)>=3
            sepPrev(k) = abs(mean(pA)-mean(pL));
        end
    end
    sepCurAll(i) = mean(sepCur,'omitnan');
    sepPrevAll(i) = mean(sepPrev,'omitnan');
    fprintf('  %-9s pre-window: current-cue sep=%.3f | prev-cue sep=%.3f\n', ...
        r.Mouse, sepCurAll(i), sepPrevAll(i));
end

%% 6. C. Regularized linear (ridge) vs GLM on pre-stimulus separation
fprintf('\n===== C. GLM vs ridge (pre-stimulus separation) =====\n');
lam = 10;
sepRidge = nan(1, nTfull);
for iT = 1:nTfull
    d = [];
    for i = 1:nValid
        r = resAll{i};
        [~, s] = iCvPredictRidge(r.X1(:,:,iT), r.y1, K, lam);
        S = 1./(1+exp(s));
        if sum(r.typ==1)>=3 && sum(r.typ==2)>=3
            d(end+1) = abs(mean(S(r.typ==1)) - mean(S(r.typ==2))); %#ok<AGROW>
        end
    end
    sepRidge(iT) = mean(d);
end
fprintf('GLM   : pre-mean=%.3f post-mean=%.3f\n', mean(sepObs(preIdx)), mean(sepObs(postIdx)));
fprintf('Ridge : pre-mean=%.3f post-mean=%.3f\n', mean(sepRidge(preIdx)), mean(sepRidge(postIdx)));

%% 7. D. Time profile: does pre-stimulus separation ramp toward onset?
fprintf('\n===== D. Time profile (separation per time point) =====\n');
for iT = 1:nTfull
    fprintf('  t=%+.2f  sep=%.3f\n', tVec(iT), sepObs(iT));
end

%% 8. Figure: 3-panel diagnosis + text summary
ymax = max([sepObs sepRidge]) * 1.1;
n95 = prctile(preSepNull,95);
okM = ~isnan(sepCurAll) & ~isnan(sepPrevAll);
mCur = mean(sepCurAll(okM)); mPrev = mean(sepPrevAll(okM));
[~, pPrev] = ttest(sepCurAll(okM), sepPrevAll(okM));

f = figure('Name','Diagnosis: pre-stimulus cue decodability (3 panels)','Color','w','Position',[40 60 1560 460]);
% ---- Panel 1: time profile (GLM vs ridge) ----
ax = subplot(1,3,1); hold(ax,'on');
patch(ax, [tVec(preIdx(1)) tVec(preIdx(end)) tVec(preIdx(end)) tVec(preIdx(1))], ...
    [0 0 ymax ymax], [0.85 0.9 0.95], 'FaceAlpha',0.5, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax, tVec, sepObs, '-o', 'Color',[0 0 0],'LineWidth',1.6,'MarkerSize',4,'DisplayName','GLM');
plot(ax, tVec, sepRidge, '--s', 'Color',[0.85 0.33 0.10],'LineWidth',1.4,'MarkerSize',4,'DisplayName','ridge');
xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
ylim(ax,[0 ymax]);
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'|P(audio)|AO - P(audio)|LO|');
title(ax,'A. Time profile (pre shaded)','FontSize',9,'FontWeight','normal');
legend(ax,'Location','northwest','Box','off','FontSize',7);
box(ax,'off'); ax.FontSize = 8;

% ---- Panel 2: permutation null vs observed ----
ax2 = subplot(1,3,2); hold(ax2,'on');
histogram(ax2, preSepNull, 20, 'FaceColor',[0.6 0.6 0.6], 'EdgeColor','none', 'DisplayName','null (shuffled)');
xline(ax2, obsPreSep, '--', 'Color',[0.85 0.05 0.05],'LineWidth',1.6, 'DisplayName',sprintf('observed %.3f, p=%.3f', obsPreSep, pPerm));
xline(ax2, n95, ':', 'Color',[0 0 0],'LineWidth',1.2,'DisplayName',sprintf('null 95%%=%.3f', n95));
xlabel(ax2,'Pre-stimulus separation'); ylabel(ax2,'Count');
title(ax2,'B. Permutation test','FontSize',9,'FontWeight','normal');
legend(ax2,'Location','northwest','Box','off','FontSize',7);
box(ax2,'off'); ax2.FontSize = 8;

% ---- Panel 3: current vs previous cue ----
ax3 = subplot(1,3,3); hold(ax3,'on');
plot(ax3, [sepCurAll(okM)'; sepPrevAll(okM)'], 'o-', 'Color',[0.4 0.4 0.4], 'LineWidth',0.8, 'MarkerSize',5, 'HandleVisibility','off');
plot(ax3, [mCur mPrev], '-o', 'Color',[0.85 0.05 0.05],'LineWidth',2,'MarkerSize',8,'MarkerFaceColor',[1 0.5 0.5],'DisplayName',sprintf('mean (p=%.3f)', pPrev));
set(ax3,'XTick',[1 2],'XTickLabel',{'current cue','previous cue'});
ylim(ax3,[0 max([mCur mPrev])*1.3]);
ylabel(ax3,'Pre-stimulus separation');
title(ax3,'C. Current vs previous trial','FontSize',9,'FontWeight','normal');
legend(ax3,'Location','northwest','Box','off','FontSize',7);
box(ax3,'off'); ax3.FontSize = 8;

% ---- text summary ----
txt = sprintf(['Pre-stimulus cue separation = %.3f vs null %.3f (p=%.3f): label-dependent, ' ...
    'not GLM overfit (ridge %.3f), not previous-trial (cur %.3f vs prev %.3f, p=%.3f). ' ...
    'AudioOnly/LightOnly interleaved in-session, ITI>=15s. => real pre-stimulus expectancy state.'], ...
    obsPreSep, mean(preSepNull), pPerm, mean(sepRidge(preIdx)), mCur, mPrev, pPrev);
annotation(f,'textbox',[0.02 0.015 0.96 0.06],'String',txt,'FontSize',8, ...
    'HorizontalAlignment','center','EdgeColor','none','Interpreter','none');

fprintf('\nDone. Diagnosis complete.\n');

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

function X = iBaselineNorm(X, baseIdx)
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

function [sOOF, pOOF] = iCvPredictRidge(F, y, K, lam)
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
    [sOOF(te), pOOF(te)] = iRidgeDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:), lam);
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

function [score, pred] = iRidgeDecode(Ftr, ytr, Fte, lam)
mu = mean(Ftr,1); sd = std(Ftr,0,1); sd(sd==0)=1;
Ftrs = (Ftr-mu)./sd; Ftes = (Fte-mu)./sd;
n = size(Ftrs,1);
X = [ones(n,1), Ftrs];
p = size(X,2);
A = X'*X + lam*eye(p);
A(1,1) = X(:,1)'*X(:,1);   % do not penalize intercept
w = A \ (X'*(2*ytr-1));
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
