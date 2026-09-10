%% CueModel_TransferAudioToLight.m
% Transfer version of CueModel.m: does the pre-vs-post cue decoder trained on
% the audio task (AudioWater Learned) generalize to the new task
% (LightWater Transfer, held-out)?
%
% Per trial, mean population activity in the pre window (-1~0 s) and the post
% window (0~1 s); labels pre=0 / post=1; LASSO logistic regression with the
% SAME lambda rule as CueModel.m. Evaluated per mouse on two stages:
%   Stage1 = 5-fold trial-aware CV within the training set (sound decoding);
%   Stage2 = train on ALL AudioWater Learned trials, decode Transfer
%            LightWater (true held-out); permutation: shuffle training labels
%            only (200 iterations, as in CueModel.m).
% The window-trained decoder is additionally read out AT EVERY TIME POINT of
% Stage2 (accuracy and P(post)), and per-cell LASSO weights are returned.
% Results are saved to CueModel_TransferAudioToLight_Results.mat.
%
% EXCLUDED: vtf0353 (AudioLightBaseline) - its Transfer LightWater block is
% flagged "2/5层亮度反相" (inverted brightness) in the database.
%
% Runs on both datasets for comparison:
%   AudioLightBaseline (11 mice, no interval) and Vacation7 (6 mice, learn
%   audio, 7 days off, then transfer to light).
%
% Data loading uses TableQuery(ResampledSignal) + drop bad rows + row-wise
% z-score over the full trace, verified identical to DS.QueryNTS output with
% UniExp.Flags.ZScore (needed for Vacation7, whose QueryNTS throws on
% out-of-registration cells).

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
if isempty(gcp('nocreate')); parpool; end
% start the parallel pool once (decoding below runs in parfor)

DSs = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
dsNames = {'AudioLightBaseline','Vacation7'};
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
tPre  = (xs >= -1) & (xs <= 0);
tPost = (xs >= 0)  & (xs <= 1);
excludeMice = ["vtf0353"];   % Transfer LW block flagged "2/5层亮度反相" -> excluded
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);
fprintf('=== CueModel transfer: audio pre/post -> light (Learned AW -> Transfer LW) ===\n');
fprintf('Pre: %.2f-%.2fs  Post: %.2f-%.2fs  | time-point grid: %d pts (%.2f-%.2f s)\n', ...
    xs(find(tPre,1)), xs(find(tPre,1,'last')), ...
    xs(find(tPost,1)), xs(find(tPost,1,'last')), nTfull, tVec(1), tVec(end));
fprintf('Excluded mice: %s\n', strjoin(excludeMice, ', '));

%% 1. Per (dataset, mouse): serial data load -> parallel decode
tasks = {};
for iDS = 1:numel(DSs)
    DS = DSs{iDS};
    Blk = DS.Blocks; Blk.Design = string(Blk.Design); Blk.BlockUID = uint64(Blk.BlockUID);
    DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
    DT.DateTime = datetime(DT.DateTime);
    if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
    DT.Mouse = string(DT.Mouse); DT.Phase = string(DT.Phase);
    blkDT = datetime(Blk.DateTime);
    if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
    mo = repmat(string("<missing>"), height(Blk),1); ph = mo;
    for i = 1:height(Blk)
        idx = find(DT.DateTime == blkDT(i),1);
        if ~isempty(idx); ph(i) = DT.Phase(idx); mo(i) = DT.Mouse(idx); end
    end
    Blk.Phase = ph; Blk.Mouse = mo;
    mice = setdiff(unique(DT.Mouse)', excludeMice);
    for m = mice
        % --- train: AudioWater Learned ---
        awBlocks = Blk.BlockUID(Blk.Design=="AudioWater" & Blk.Phase=="Learned" & Blk.Mouse==m);
        if isempty(awBlocks); continue; end
        awT = iQueryZScoreNts(DS, m, 'AudioWater');
        if isempty(awT); continue; end
        trTbl = awT(ismember(uint64(awT.BlockUID), awBlocks) & ~isnan(awT.Behavior), :);
        if isempty(trTbl); continue; end
        % --- test: LightWater Transfer ---
        lwBlocks = Blk.BlockUID(Blk.Design=="LightWater" & Blk.Phase=="Transfer" & Blk.Mouse==m);
        if isempty(lwBlocks); continue; end
        lwT = iQueryZScoreNts(DS, m, 'LightWater');
        if isempty(lwT); continue; end
        teTbl = lwT(ismember(uint64(lwT.BlockUID), lwBlocks), :);
        if isempty(teTbl); continue; end
        % --- cell set: seen in BOTH training and test ---
        cuTr = unique(uint64(trTbl.CellUID)); cuTe = unique(uint64(teTbl.CellUID));
        cu = intersect(cuTr, cuTe);
        if numel(cu) < 5; continue; end
        XTr = iBuildTrialMatrix(trTbl, cu);
        XTe = iBuildTrialMatrix(teTbl, cu);
        if isempty(XTr) || isempty(XTe); continue; end
        preTr  = mean(XTr(:,:,tPre),3);  postTr = mean(XTr(:,:,tPost),3);
        preTe  = mean(XTe(:,:,tPre),3);  postTe = mean(XTe(:,:,tPost),3);
        tasks{end+1} = struct('DS', iDS, 'Mouse', char(m), 'NCells', numel(cu), ... %#ok<AGROW>
            'CellUIDs', cu, 'preTr', preTr, 'postTr', postTr, ...
            'preTe', preTe, 'postTe', postTe, ...
            'XTrT', XTr(:,:,tIdxFull), 'XTeT', XTe(:,:,tIdxFull));
    end
end
fprintf('Decodable (dataset,mouse) units: %d\n', numel(tasks));
if isempty(tasks); fprintf('Nothing to decode.\n'); return; end

%% 2. Decode (parallel over units)
res = cell(numel(tasks), 1);
parfor i = 1:numel(tasks)
    rng(42 + i);
    res{i} = iDecodePrePost(tasks{i}, tVec);
end

%% 3. Summary
fprintf('\n=== Results by dataset ===\n');
s2ByDS = cell(numel(DSs), 1);
for iDS = 1:numel(DSs)
    fprintf('---- %s ----\n', dsNames{iDS});
    accs = []; s2accs = []; s2p = []; s2sig = 0; s1sig = 0; nU = 0;
    for i = 1:numel(tasks)
        R = res{i};
        if R.DS ~= iDS; continue; end
        nU = nU + 1;
        fprintf('  %-9s cells=%3d  Stage1(CV)=%.1f%% (p=%.4f) | Stage2(Transfer)=%.1f%% (p=%.4f)%s\n', ...
            R.Mouse, R.nCells, R.s1Acc*100, R.s1p, R.s2Acc*100, R.s2p, ...
            iif(R.s2p < 0.05, ' *', ''));
        accs(end+1) = R.s1Acc; %#ok<AGROW>
        s2accs(end+1) = R.s2Acc; %#ok<AGROW>
        s2p(end+1) = R.s2p; %#ok<AGROW>
        s2sig = s2sig + double(R.s2p < 0.05);
        s1sig = s1sig + double(R.s1p < 0.05);
    end
    if nU == 0; fprintf('  (none)\n'); continue; end
    fprintf('  mean Stage1 = %.1f%% (%d/%d perm-sig) | mean Stage2 = %.1f%% (%d/%d perm-sig)\n', ...
        mean(accs)*100, s1sig, nU, mean(s2accs)*100, s2sig, nU);
    % sign test Stage2 > 50% (paired direction, not the permutation null)
    k2 = sum(s2accs > 0.5);
    p2 = 1 - binocdf(k2-1, nU, 0.5);
    fprintf('  Stage2 sign test (>0.5): %d/%d, p=%.4f\n', k2, nU, p2);
    s2ByDS{iDS} = s2accs;
end
% ---- direct between-dataset comparison (Stage2 transfer accuracy) ----
if ~isempty(s2ByDS{1}) && ~isempty(s2ByDS{2})
    [pMW, h] = ranksum(s2ByDS{1}, s2ByDS{2});
    fprintf('\nBetween-dataset (Stage2 transfer accuracy): %s mean=%.1f%% vs %s mean=%.1f%%, Mann-Whitney p=%.4f %s\n', ...
        dsNames{1}, mean(s2ByDS{1})*100, dsNames{2}, mean(s2ByDS{2})*100, pMW, iif(h==1,'(different)','(same)'));
end

% ---- per-time-point readout summary (same trained decoder on Transfer) ----
fprintf('\n=== Per-time-point readout of the trained decoder (P(post) on Transfer) ===\n');
for iDS = 1:numel(DSs)
    fprintf('---- %s ----\n', dsNames{iDS});
    pCurves = []; n95 = []; nM = 0;
    for i = 1:numel(tasks)
        R = res{i};
        if R.DS ~= iDS; continue; end
        nM = nM + 1;
        [pk, ipk] = max(R.pPostByT);
        fprintf('  %-9s peak P(post)=%.3f @ %+.2fs (p@peak=%.3f, max-stat p=%.3f) | n sig times(p<.05)=%d | frac judged post: %.2f->%.2f\n', ...
            R.Mouse, pk, R.tVec(ipk), R.pByT(ipk), R.pMaxStat, sum(R.pByT < 0.05), ...
            R.fracPostByT(1), R.fracPostByT(end));
        pCurves = cat(1, pCurves, R.pPostByT); %#ok<AGROW>
        n95 = cat(1, n95, R.null95); %#ok<AGROW>
    end
    if nM == 0; continue; end
    fprintf('  dataset mean: peak P(post)=%.3f vs null95 peak=%.3f\n', ...
        max(mean(pCurves,1,'omitnan')), max(mean(n95,1,'omitnan')));
end

% ---- save results ----
save(fullfile(thisDir, 'CueModel_TransferAudioToLight_Results.mat'), ...
    'res', 'tasks', 'dsNames', 'tVec', 'excludeMice');
fprintf('\nSaved CueModel_TransferAudioToLight_Results.mat\n');

% ---- figure 1: three panels = audio-task self (Stage1), immediate transfer
% (AL Stage2), transfer after 7 days (V7 Stage2); each with mean +/- s.e.m. of
% the per-mouse P(post) time course and the mean permutation null 95% band ----
f = figure('Name','CueModel transfer: per-time-point P(post)','Color','w','Position',[60 60 1560 430]);
axs = gobjects(1,3);
% Panel A: audio task self (Stage1, both datasets pooled)
v = []; nv = [];
for i = 1:numel(tasks)
    R = res{i};
    v = cat(1, v, R.pPostS1T); nv = cat(1, nv, R.null95S1); %#ok<AGROW>
end
axs(1) = iPlotPPostTimeCourse(3, 1, v, nv, tVec, ...
    sprintf('Audio task self (n=%d mice)', size(v,1)));
% Panels B/C: transfer readouts, one dataset each
for iDS = 1:numel(DSs)
    v = []; nv = [];
    for i = 1:numel(tasks)
        R = res{i};
        if R.DS ~= iDS; continue; end
        v = cat(1, v, R.pPostByT); nv = cat(1, nv, R.null95); %#ok<AGROW>
    end
    if iDS == 1; ttl = sprintf('Immediate transfer (n=%d mice)', size(v,1));
    else;         ttl = sprintf('Transfer after 7 days (n=%d mice)', size(v,1)); end
    axs(1+iDS) = iPlotPPostTimeCourse(3, 1+iDS, v, nv, tVec, ttl);
end
set(axs, 'YLim', [0 1]);

% ---- figure 2: bar chart at t=1s (+0.96s point), immediate vs 7-day transfer ----
alP = []; v7P = [];
for i = 1:numel(tasks)
    R = res{i};
    if R.DS == 1; alP(end+1) = R.pPostByT(end);   %#ok<AGROW>
    else;         v7P(end+1) = R.pPostByT(end); end %#ok<AGROW>
end
% one-sided label-permutation test (mouse-level: is AL mean > V7 mean?)
rng(777);
NREP = 20000;
vAll = [alP(:); v7P(:)]; nAl = numel(alP);
obsD = mean(vAll(1:nAl)) - mean(vAll(nAl+1:end));
cHit = 0;
for rIdx = 1:NREP
    q = randperm(numel(vAll));
    if mean(vAll(q(1:nAl))) - mean(vAll(q(nAl+1:end))) >= obsD; cHit = cHit + 1; end
end
pPerm = (cHit + 1) / (NREP + 1);
fprintf('\nBar @1s: AL=%.3f (n=%d) vs V7=%.3f (n=%d), diff=%.3f, one-sided permutation p=%.4f\n', ...
    mean(alP), numel(alP), mean(v7P), numel(v7P), obsD, pPerm);

fb = figure('Name','CueModel transfer: P(post) at 1s','Color','w','Position',[60 60 320 360]);
ax = axes(fb); hold(ax,'on');
colBar = [0.10 0.45 0.70; 0.85 0.33 0.10];
for g = 1:2
    if g == 1; vals = alP(:); else; vals = v7P(:); end
    bar(ax, g, mean(vals), 'FaceColor', colBar(g,:), 'FaceAlpha', 0.55, ...
        'EdgeColor', [0 0 0], 'BarWidth', 0.5);
    errorbar(ax, g, mean(vals), std(vals)/sqrt(numel(vals)), 'k', 'LineWidth', 1.1, 'CapSize', 6);
    scatter(ax, ones(numel(vals),1)*g, vals, 36, [0 0 0], 'filled', ...
        'jitter','on','jitterAmount',0.12);
end
yline(ax, 0.5, ':', 'Color',[0.5 0.5 0.5],'LineWidth',0.8);
ylim(ax, [0 1]); xlim(ax, [0.5 2.5]);
set(ax, 'XTick', [1 2], 'XTickLabel', {'Immediate', 'After 7 days'});
ylabel(ax, 'P(post) at 1 s');
ax.FontSize = 8; box(ax,'off');
% significance annotation (one-sided permutation); P value label only, no method name
if pPerm < 0.001; pTxt = 'p<0.001'; else; pTxt = sprintf('p=%.3f', pPerm); end
yy = max([alP(:); v7P(:)]) + 0.14;
plot(ax, [1 1 2 2], [yy-0.05 yy yy yy-0.05], 'k-', 'LineWidth', 0.8, 'HandleVisibility','off');
text(ax, 1.5, yy + 0.015, pTxt, 'HorizontalAlignment','center','FontSize', 8);
ylim(ax, [0 yy + 0.1]);

TransferLearning.ExportStandardFigure(f, 2, 'CueModel_Transfer_TimeCourse.svg');
TransferLearning.ExportStandardFigure(fb, 2, 'CueModel_Transfer_Bar1s.svg');
fprintf('Exported CueModel_Transfer_TimeCourse.svg & CueModel_Transfer_Bar1s.svg\n');

fprintf('\nDone.\n');

function ax = iPlotPPostTimeCourse(nP, idx, v, nv, tVec, ttl)
% Mean +/- s.e.m. P(post) time course (rows = mice) with mean null 95% band.
ax = subplot(1, nP, idx); hold(ax,'on');
mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(size(v,1));
n95 = mean(nv,1,'omitnan');
plot(ax, tVec, n95, '--', 'Color',[0.65 0.65 0.65],'LineWidth',1.2,'DisplayName','null 95%');
errorbar(ax, tVec, mn, se, '-', 'Color',[0.10 0.45 0.70],'LineWidth',1.8,'MarkerSize',2,'DisplayName','P(post) mean');
sigT = mn > n95;
if any(sigT)
    plot(ax, tVec(sigT), mn(sigT), 'o', 'MarkerSize',7,'LineWidth',1.2, ...
        'Color',[0.75 0.05 0.05],'MarkerFaceColor',[1 0.35 0.35],'HandleVisibility','off');
end
yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'P(post)');
title(ax, ttl,'FontSize',9,'FontWeight','normal');
legend(ax,'Location','northwest','Box','off','FontSize',7);
box(ax,'off'); ax.FontSize = 8;
end

function tbl = iQueryZScoreNts(DS, m, stim)
% Z-scored per-row signal table (TableQuery + ResampledSignal), equivalent to
% QueryNTS ZScore over the full window; drops all-NaN/all-zero rows
% (cells outside registration range, which make QueryNTS throw).
t = DS.TableQuery(["ResampledSignal","CellUID","TrialUID","Behavior","BlockUID"], ...
    struct('Mouse', m, 'Stimulus', stim));
if isempty(t) || height(t) == 0; tbl = table(); return; end
sig = t.ResampledSignal;
if iscell(sig); sig = double(vertcat(sig{:})); else; sig = double(sig); end
bad = any(isnan(sig), 2) | all(sig == 0, 2);
if any(bad)
    fprintf('    %s %-10s dropped %d bad rows (cells out of registration)\n', ...
        char(m), stim, sum(bad));
    sig(bad, :) = [];
    t(bad, :) = [];
end
if height(t) == 0; tbl = table(); return; end
mu = mean(sig, 2); sd = std(sig, 0, 2); sd(sd==0) = 1;
sig = (sig - mu) ./ sd;
tbl = table(uint64(t.CellUID), uint64(t.TrialUID), sig, ...
    'VariableNames', {'CellUID','TrialUID','TrialSignal'});
tbl.Behavior = t.Behavior;
tbl.BlockUID = t.BlockUID;
end

function X = iBuildTrialMatrix(rawTbl, cellUIDs)
sig = double(rawTbl.TrialSignal);
nts = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), 'VariableNames',{'CellUID','TrialUID'});
sigCell = cell(size(sig,1),1);
for i = 1:size(sig,1); sigCell{i} = sig(i,:); end %#ok<AGROW>
nts.Signal = sigCell;
nts = nts(ismember(nts.CellUID, cellUIDs), :);
if isempty(nts); X = []; return; end
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

function R = iDecodePrePost(t, tVec)
% CueModel decoding on pre/post window averages: Stage1 = 5-fold trial-aware
% CV; Stage2 = all trials train -> transfer test; 200 label-shuffle
% permutations (training labels only). LASSO lambda rule identical to CueModel.m.
% ADDITION: the SAME trained decoder is read out at every time point of the
% Stage2 trials (P(post) and fraction judged post) with a 200-permutation
% null, and per-cell LASSO weights (std-scaled space) are returned.
preTr = t.preTr; postTr = t.postTr; preTe = t.preTe; postTe = t.postTe;
nTr = size(preTr,1); nTe = size(preTe,1);
xTrAll = [preTr; postTr]; yTrAll = [zeros(nTr,1); ones(nTr,1)];
xTeAll = [preTe; postTe]; yTeAll = [zeros(nTe,1); ones(nTe,1)];
mu = mean(xTrAll,1); sd = std(xTrAll,0,1); sd(sd==0) = 1;
xTrS = (xTrAll-mu)./sd; xTrS(isnan(xTrS)) = 0;
xTeS = (xTeAll-mu)./sd; xTeS(isnan(xTeS)) = 0;
lam = 0.02/sqrt(nTr*2);
mdl = fitclinear(xTrS, yTrAll, ...
    'Learner','logistic', 'Regularization','lasso', 'Lambda',lam);
w = mdl.Beta; b0 = mdl.Bias;                  % per-cell weights + bias
[labelTe, ~] = predict(mdl, xTeS);
accTe = mean(labelTe == yTeAll);              % observed Stage2 accuracy (window averages)
% ---- Stage1: 5-fold CV over trials (pre & post sample of each trial go to the same fold) ----
% Fold models are kept so the SAME per-fold decoders can also be read out at
% every time point of the out-of-fold training trials (Stage1 time course).
K = 5;
perm = randperm(nTr);
foldSize = ceil(nTr/K);
foldTET = cell(K,1);            % trial-level fold test mask (pre/post pairs kept together)
foldMdl = cell(K,1);
predCv = zeros(2*nTr, 1); trueCv = [zeros(nTr,1); ones(nTr,1)];
for k = 1:K
    idxT = (k-1)*foldSize + 1 : min(k*foldSize, nTr);
    teT = false(nTr,1); teT(perm(idxT)) = true;
    teI = [teT; teT];
    xTrF = xTrS(~teI, :); yTrF = yTrAll(~teI);
    xTeF = xTrS(teI, :);
    mF = fitclinear(xTrF, yTrF, ...
        'Learner','logistic', 'Regularization','lasso', 'Lambda', lam);
    predCv(teI) = predict(mF, xTeF);
    foldTET{k} = teT; foldMdl{k} = mF;
end
accCv = mean(predCv == trueCv);
nT = numel(tVec);
% ---- Stage1 time course: the SAME fold decoders read out-of-fold training trials ----
pPostS1 = iTimePointReadout(t.XTrT, mu, sd, foldTET, foldMdl, nT);   % (nTr, nT) OOF P(post)
pPostS1T = mean(pPostS1, 1, 'omitnan');                              % per time point
fracPostS1T = mean(pPostS1 >= 0.5, 1, 'omitnan');                    % per time point
% ---- Stage2 time course: the SAME full decoder on Transfer trials ----
pPostS2 = iTimePointReadoutFull(t.XTeT, mu, sd, w, b0, nT);   % (nTe, nT)
pPostByT = mean(pPostS2, 1);                    % mean P(post) over trials
fracPostByT = mean(pPostS2 >= 0.5, 1);          % fraction of trials judged post
% ---- permutation nulls (shuffle TRAINING labels only) ----
Nperm = 200;
saTe = zeros(Nperm,1);
saCv = zeros(Nperm,1);
nullPP = nan(Nperm, nT);      % Stage2 null
nullS1 = nan(Nperm, nT);      % Stage1 null
for iS = 1:Nperm
    sy = yTrAll(randperm(nTr*2));    % shuffle trial labels (pre/post pairing)
    mS = fitclinear(xTrS, sy, ...
        'Learner','logistic', 'Regularization','lasso', 'Lambda',lam);
    [labelS, ~] = predict(mS, xTeS);
    saTe(iS) = mean(labelS == yTeAll);
    % Stage2 per-time-point null curve under the same shuffled decoder
    pShS2 = iTimePointReadoutFull(t.XTeT, mu, sd, mS.Beta, mS.Bias, nT);
    nullPP(iS, :) = mean(pShS2, 1);
    % CV under the same shuffled labels (Stage1 accuracy null + time course null)
    predS = zeros(2*nTr,1);
    foldMdlS = cell(K,1);
    for k = 1:K
        teI = [foldTET{k}; foldTET{k}];
        mF = fitclinear(xTrS(~teI,:), sy(~teI), ...
            'Learner','logistic', 'Regularization','lasso', 'Lambda', lam);
        predS(teI) = predict(mF, xTrS(teI,:));
        foldMdlS{k} = mF;
    end
    saCv(iS) = mean(predS == trueCv);
    nullS1(iS, :) = mean(iTimePointReadout(t.XTrT, mu, sd, foldTET, foldMdlS, nT), 1, 'omitnan');
end
pTe = (sum(saTe >= accTe) + 1) / (Nperm + 1);
pCv = (sum(saCv >= accCv) + 1) / (Nperm + 1);
pByT = (sum(nullPP >= pPostByT, 1) + 1) / (Nperm + 1);   % Stage2 per time point
null95 = prctile(nullPP, 95, 1);
pMaxStat = (sum(max(nullPP, [], 2) >= max(pPostByT)) + 1) / (Nperm + 1);
pByT1 = (sum(nullS1 >= pPostS1T, 1) + 1) / (Nperm + 1);  % Stage1 per time point
null95S1 = prctile(nullS1, 95, 1);
pMaxStat1 = (sum(max(nullS1, [], 2) >= max(pPostS1T)) + 1) / (Nperm + 1);
R = struct('DS', t.DS, 'Mouse', t.Mouse, 'nCells', t.NCells, ...
    's1Acc', accCv, 's1p', pCv, 's2Acc', accTe, 's2p', pTe, ...
    'cellUIDs', t.CellUIDs, 'w', w, 'bias', b0, 'tVec', tVec, ...
    'pPostS1T', pPostS1T, 'fracPostS1T', fracPostS1T, ...
    'pByT1', pByT1, 'null95S1', null95S1, 'pMaxStat1', pMaxStat1, ...
    'pPostByT', pPostByT, 'fracPostByT', fracPostByT, ...
    'pByT', pByT, 'null95', null95, 'pMaxStat', pMaxStat);
end

function pS = iTimePointReadoutFull(XT, mu, sd, w, b0, nT)
% Read one decoder out at every time point: P(post) per trial x time point.
pS = zeros(size(XT,1), nT);
for iT = 1:nT
    F = squeeze(XT(:, :, iT));
    Fs = (F - mu)./sd; Fs(isnan(Fs)) = 0;
    pS(:, iT) = 1 ./ (1 + exp(-(Fs * w + b0)));
end
end

function pS = iTimePointReadout(XT, mu, sd, foldTET, foldMdl, nT)
% Per-fold out-of-fold P(post) at every time point, one row per TRAINING trial
% (XT rows = trials; foldTET{k} selects that fold's out-of-fold trials; both
% pre/post samples of a trial always go to the same fold).
nTr = size(XT,1);
pS = nan(nTr, nT);
for k = 1:numel(foldMdl)
    teT = foldTET{k};
    mF = foldMdl{k};
    wF = mF.Beta; bF = mF.Bias;
    for iT = 1:nT
        F = squeeze(XT(:, :, iT));
        Fs = (F - mu)./sd; Fs(isnan(Fs)) = 0;
        pS(teT, iT) = 1 ./ (1 + exp(-(Fs(teT, :) * wF + bF)));
    end
end
end

function s = iif(c, a, b)
if c; s = a; else; s = b; end
end
