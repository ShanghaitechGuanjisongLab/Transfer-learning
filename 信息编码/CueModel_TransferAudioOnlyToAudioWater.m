%% CueModel_TransferAudioOnlyToAudioWater.m
% Trial analysis (no figure number yet): the English Fig3D cue pre/post decoder,
% but with the training trials switched from the task (AudioWater Learned) to the
% audio-only calibration trials, and the held-out test set switched from the new
% task (Transfer LightWater) to the audio task itself (AudioWater).
%
% Question: does the cue-evoked population pattern trained on audio-only
% calibration trials carry into the audio-water task context, and does it also
% reach the brand-new light-water task? Fig3D asked the task -> new-task
% direction and found transfer only in the no-gap cohort; this analysis uses the
% calibration trials as the only training data, so any light-water read-out is
% carried by the audio cue response alone.
%
% Design facts verified in UniExp.AudioLightBaseline (no-gap cohort):
%   - AudioOnly trials occur ONLY in the LAu / LAuW calibration blocks (Phase
%     "Naive"), where no water is ever paired with the cue (WaterOnly is a
%     separate stimulus); 20-30 trials per mouse.
%   - Those calibration blocks sit on the same day as (or one day before) the
%     first AudioWater block.
%   - Water is delivered at cue + 1 s, so the post window (0..1 s) ends
%     exactly AT water delivery and contains no water/lick response; the
%     decoder compares cue-pre vs cue-early-response only, in both contexts.
%
% Decoder: TransferLearning.DecodeCuePrePostTransfer (same rule as
% CueModel_TransferAudioToLight.m - LASSO logistic on pre -1..0 s vs post 0..1 s
% window averages, Lambda = 0.02/sqrt(2*nTrainTrial), Stage1 = 5-fold
% trial-aware CV, Stage2 = train on all AudioOnly trials and read out at every
% time point of each held-out test set, nulls = 200 training-label shuffles).
%
% Held-out test sets, both read out with the SAME AudioOnly-trained decoder:
%   AW  - the WHOLE initial learning phase, pooled as one database: every
%         AudioWater block with Phase "Naive", "Learned" or unannotated; Recall
%         blocks are NOT part of initial learning (verified: each unannotated
%         AudioWater block precedes the first Transfer LightWater block, each
%         Recall block follows it). 2-6 blocks -> 60-180 trials per mouse.
%   LW1 - the FIRST LightWater block only (30 trials), i.e. the very first
%         exposure to the new task, before any light-water learning. Verified:
%         for every mouse the earliest LightWater block is exactly the one
%         annotated Phase "Transfer", so "first block" and "transfer block"
%         coincide. Blocks carrying a MustWarn quality flag are skipped (as in
%         Fig3D, this is vtf0353's "2/5层亮度反相"), so LW1 has one mouse fewer.
%
% Cohort: AudioLightBaseline only (no gap). 11 mice; yqn1130 has no AudioOnly
% trial and drops out -> 10 decodable mice for Stage1 and AW, 9 for LW1.
%
% Output: 信息编码/CueModel_TransferAudioOnlyToAudioWater_Results.mat
% Plot:   英文图/Trial_AudioOnlyCueDecoderTransfer.m
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

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

DS = TransferLearning.AudioLightBaseline();
dsName = 'AudioLightBaseline (no gap)';
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
tPre = (xs >= -1) & (xs <= 0);
tPost = (xs >= 0) & (xs <= 1);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
NPERM = 200;
fprintf('=== CueModel trial: AudioOnly calibration -> AudioWater task (%s) ===\n', dsName);
fprintf('Pre: %.2f-%.2fs  Post: %.2f-%.2fs  | read-out grid: %d pts (%.2f-%.2f s)  | permutations: %d\n', ...
    xs(find(tPre, 1)), xs(find(tPre, 1, 'last')), xs(find(tPost, 1)), xs(find(tPost, 1, 'last')), ...
    numel(tVec), tVec(1), tVec(end), NPERM);

%% 1. Block annotation (Design / Phase / Mouse per block)
Blk = DS.Blocks;
Blk.Design = string(Blk.Design);
Blk.BlockUID = uint64(Blk.BlockUID);
DT = DS.DateTimes(:, {'DateTime', 'Mouse', 'Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
blkDT = datetime(Blk.DateTime);
if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
mo = strings(height(Blk), 1);
ph = mo;
for i = 1:height(Blk)
    idx = find(DT.DateTime == blkDT(i), 1);
    if ~isempty(idx); ph(i) = DT.Phase(idx); mo(i) = DT.Mouse(idx); end
end
Blk.Phase = ph;
Blk.Mouse = mo;
Blk.DT = blkDT;
Blk.Warn = string(Blk.MustWarn);
Blk.Warn(ismissing(Blk.Warn)) = "-";
mice = unique(DT.Mouse)';
fprintf('Calibration blocks (LAu/LAuW): %d; initial-learning AudioWater blocks (Naive/Learned/unannotated): %d\n', ...
    sum(ismember(Blk.Design, ["LAu", "LAuW"])), ...
    sum(Blk.Design == "AudioWater" & (ismember(Blk.Phase, ["Naive", "Learned"]) | ismissing(Blk.Phase))));

% First LightWater block per mouse = its Transfer block: verified, for all 11
% mice the LightWater block with the earliest DateTime is exactly the one
% annotated Phase "Transfer" (later LightWater blocks are unannotated or Final).
lwFirst = repmat(struct('Mouse', "", 'Blk', uint64(0), 'Warn', "", 'Phase', ""), numel(mice), 1);
nLW = 0;
for m = mice
    sel = Blk.Design == "LightWater" & Blk.Mouse == m;
    if ~any(sel); continue; end
    lw = sortrows(Blk(sel, :), 'DT');
    nLW = nLW + 1;
    lwFirst(nLW) = struct('Mouse', m, 'Blk', lw.BlockUID(1), 'Warn', lw.Warn(1), ...
        'Phase', lw.Phase(1));
end
lwFirst = lwFirst(1:nLW);
nFlag = sum(string({lwFirst.Warn}) ~= "-");
fprintf('First LightWater blocks: %d (annotated Transfer: %d; carrying a quality flag: %d)\n', ...
    numel(lwFirst), sum(string({lwFirst.Phase}) == "Transfer"), nFlag);
for k = find(string({lwFirst.Warn}) ~= "-")
    fprintf('  %s first LightWater block flagged "%s" -> excluded from the LW1 test\n', ...
        lwFirst(k).Mouse, lwFirst(k).Warn);
end

%% 2. Per-mouse trial data (serial load) -> task list
% Two held-out test sets, both read out with the SAME AudioOnly-trained decoder:
%   AW  - every AudioWater block of the initial learning phase (Phase Naive /
%         Learned / unannotated, Recall excluded; see header), pooled into one
%         database: 2-6 blocks, 60-180 trials per mouse.
%   LW1 - the FIRST LightWater block only (= its Transfer block, 30 trials):
%         the moment the animal meets the new task, before any light-water
%         learning. Blocks carrying a MustWarn quality flag are skipped.
tasks = {};
for m = mice
    % --- train: AudioOnly calibration trials (LAu/LAuW, no water paired) ---
    aoT = TransferLearning.QueryZScoreNts(DS, m, 'AudioOnly');
    if isempty(aoT); continue; end
    trTbl = aoT(~isnan(aoT.Behavior), :);
    if isempty(trTbl); continue; end
    % --- test 1: AudioWater initial-learning trials, all blocks pooled ---
    awT = TransferLearning.QueryZScoreNts(DS, m, 'AudioWater');
    if isempty(awT); continue; end
    uid = Blk.BlockUID(Blk.Design == "AudioWater" & Blk.Mouse == m & ...
        (ismember(Blk.Phase, ["Naive", "Learned"]) | ismissing(Blk.Phase)));
    if isempty(uid); continue; end
    awTbl = awT(ismember(uint64(awT.BlockUID), uid), :);
    if isempty(awTbl); continue; end
    % --- test 2: first LightWater block ---
    kLW = find(string({lwFirst.Mouse}) == m, 1);
    lwTbl = table();
    if ~isempty(kLW) && lwFirst(kLW).Warn == "-"
        lwT = TransferLearning.QueryZScoreNts(DS, m, 'LightWater');
        if ~isempty(lwT)
            lwTbl = lwT(uint64(lwT.BlockUID) == lwFirst(kLW).Blk, :);
        end
    end
    % registration is shared across blocks, so all three trial types carry the
    % same cell set; intersect keeps only cells present in every used set
    cu = intersect(unique(uint64(trTbl.CellUID)), unique(uint64(awTbl.CellUID)));
    if ~isempty(lwTbl)
        cu = intersect(cu, unique(uint64(lwTbl.CellUID)));
    end
    if numel(cu) < 5; continue; end
    XTr = TransferLearning.BuildTrialMatrix(trTbl, cu);
    XAw = TransferLearning.BuildTrialMatrix(awTbl, cu);
    T = struct('DS', 1, 'Mouse', char(m), 'NCells', numel(cu), 'CellUIDs', cu, ...
        'XTrT', XTr(:, :, tIdxFull), ...
        'preTr', mean(XTr(:, :, tPre), 3), ...
        'postTr', mean(XTr(:, :, tPost), 3));
    T.Tests = iTestEntry("AW", XAw, tPre, tPost, tIdxFull);
    if ~isempty(lwTbl)
        XLw = TransferLearning.BuildTrialMatrix(lwTbl, cu);
        T.Tests(2) = iTestEntry("LW1", XLw, tPre, tPost, tIdxFull);
    end
    teInfo = sprintf('AW %d trials (%d blocks)', size(XAw, 1), numel(uid));
    if ~isempty(lwTbl)
        teInfo = [teInfo sprintf(', LW1 %d trials', T.Tests(2).nTe)]; %#ok<AGROW>
    else
        teInfo = [teInfo ', LW1 skipped (flagged / absent)']; %#ok<AGROW>
    end
    fprintf('%s: AudioOnly train %d trials | %s | cells shared %d\n', ...
        char(m), size(XTr, 1), teInfo, numel(cu));
    tasks{end + 1} = T; %#ok<AGROW>
end
fprintf('Decodable mice: %d\n', numel(tasks));
testLabels = ["AW", "LW1"];
if isempty(tasks); fprintf('Nothing to decode.\n'); return; end

%% 3. Decode (parallel over mice)
res = cell(numel(tasks), 1);
parfor i = 1:numel(tasks)
    rng(42 + i);
    res{i} = TransferLearning.DecodeCuePrePostTransfer(tasks{i}, tVec, NPERM);
end

%% 4. Summary
fprintf('\n=== Per mouse ===\n');
nT = numel(tVec);
testDesc = ["AudioWater initial learning (pooled)", "first LightWater block (Transfer)"];
% index of each test set inside every mouse's Tests array (NaN when skipped)
iOfLabel = nan(numel(testLabels), numel(res));
for k = 1:numel(testLabels)
    iOfLabel(k, :) = cellfun(@(R) iTestIdx(R, testLabels(k)), res);
end
accByTest = nan(numel(testLabels), numel(res));
pkByTest = nan(numel(testLabels), numel(res));
nTeByTest = nan(numel(testLabels), numel(res));
for i = 1:numel(res)
    R = res{i};
    parts = {sprintf('%-9s cells=%3d train=%2d | Stage1 CV=%.1f%% (p=%.4f) maxP=%.3f@%+.2fs', ...
        R.Mouse, R.nCells, R.nTr, R.s1Acc * 100, R.s1p, max(R.pPostS1T), ...
        R.tVec(find(R.pPostS1T == max(R.pPostS1T), 1)))};
    for k = 1:numel(testLabels)
        j = iOfLabel(k, i);
        if isnan(j)
            parts{end + 1} = sprintf('%s: skipped', testLabels(k)); %#ok<AGROW>
            continue;
        end
        K = R.Tests(j);
        [pk, ipk] = max(K.pPostByT);
        accByTest(k, i) = K.acc;
        pkByTest(k, i) = pk;
        nTeByTest(k, i) = K.nTe;
        parts{end + 1} = sprintf('%s: n=%3d acc=%.1f%% (p=%.4f) maxP=%.3f@%+.2fs sig_t=%d/%d', ...
            testLabels(k), K.nTe, K.acc * 100, K.p, pk, R.tVec(ipk), sum(K.pByT < 0.05), nT); %#ok<AGROW>
    end
    fprintf('%s\n', strjoin(parts, ' | '));
end

fprintf('\n=== Group means (%s) ===\n', dsName);
accS1 = cellfun(@(R) R.s1Acc, res);
[mS1, mnS1] = iGroupCurves(cellfun(@(R) R.pPostS1T, res, 'UniformOutput', false), ...
    cellfun(@(R) R.null95S1, res, 'UniformOutput', false));
iPrintStage('Stage1 AudioOnly self (5-fold CV, out-of-fold)', accS1, mS1, mnS1, tVec, nT, []);
for k = 1:numel(testLabels)
    hasK = isfinite(iOfLabel(k, :));
    if ~any(hasK)
        fprintf('Stage2 -> %s [%s]: no mouse\n', testDesc(k), testLabels(k));
        continue;
    end
    pC = cell(numel(res), 1);
    nC = cell(numel(res), 1);
    for i = find(hasK)
        j = iOfLabel(k, i);
        pC{i} = res{i}.Tests(j).pPostByT;
        nC{i} = res{i}.Tests(j).null95;
    end
    [mK, mnK] = iGroupCurves(pC(hasK), nC(hasK));
    lbl = sprintf('Stage2 -> %s [%s]', testDesc(k), testLabels(k));
    iPrintStage(lbl, accByTest(k, hasK), mK, mnK, tVec, nT, nTeByTest(k, hasK));
end

% --- paired comparisons between the read-outs (same AudioOnly decoder) ---
hasAW = isfinite(iOfLabel(1, :));
iPrintPaired('Stage1 self vs -> AudioWater', accS1(:)', accByTest(1, :), hasAW);
if ismember("LW1", testLabels)
    iLW = find(testLabels == "LW1", 1);
    hasLW = isfinite(iOfLabel(iLW, :));
    iPrintPaired('Stage1 self vs -> LightWater 1st block', accS1(:)', accByTest(iLW, :), hasLW);
    iPrintPaired('AudioWater vs LightWater 1st block', accByTest(1, :), accByTest(iLW, :), hasAW & hasLW);
end

% --- reference: the published Fig3D direction (Learned AudioWater -> Transfer LightWater) ---
refMat = fullfile(thisDir, 'CueModel_TransferAudioToLight_Results.mat');
if isfile(refMat)
    Sref = load(refMat);
    isDS1 = cellfun(@(R) R.DS == 1, Sref.res);
    accRef1 = cellfun(@(R) R.s1Acc, Sref.res(isDS1));
    accRef = cellfun(@(R) R.s2Acc, Sref.res(isDS1));
    fprintf('\nReference (English Fig3D, same cohort, Learned AudioWater -> Transfer LightWater): Stage1 %.3f +/- %.3f, Stage2 %.3f +/- %.3f (n=%d)\n', ...
        mean(accRef1), iSem(accRef1), mean(accRef), iSem(accRef), numel(accRef));
    fprintf('NB: the Fig3D .mat was computed in an earlier session; fitclinear lasso-logistic results depend on the RNG stream position, so per-time-point curves are reproducible only up to solver noise (accuracies match, curves can differ by ~0.03).\n');
else
    fprintf('\nReference Fig3D results not found (%s): comparison skipped.\n', refMat);
end

save(fullfile(thisDir, 'CueModel_TransferAudioOnlyToAudioWater_Results.mat'), ...
    'res', 'tasks', 'dsName', 'tVec', 'NPERM', 'testLabels', 'lwFirst');
fprintf('\nSaved CueModel_TransferAudioOnlyToAudioWater_Results.mat\n');
fprintf('Next: run 英文图/Trial_AudioOnlyCueDecoderTransfer.m\n');

%% ========== local functions ==========
function Te = iTestEntry(name, X, tPre, tPost, tIdxFull)
% One held-out test set entry for TransferLearning.DecodeCuePrePostTransfer.
Te = struct('Name', name, ...
    'preTe', mean(X(:, :, tPre), 3), ...
    'postTe', mean(X(:, :, tPost), 3), ...
    'XTeT', X(:, :, tIdxFull), ...
    'nTe', size(X, 1));
end

function [mn, mn95] = iGroupCurves(pCell, nCell)
% Group mean of per-mouse P(post) curves and of their permutation null 95%.
mn = mean(vertcat(pCell{:}), 1, 'omitnan');
mn95 = mean(vertcat(nCell{:}), 1, 'omitnan');
end

function iPrintStage(lbl, acc, mn, mn95, tVec, nT, nTe)
% One group-level line: mean +/- s.e.m. accuracy, peak curve, null crossing.
if isempty(acc)
    fprintf('%s: no mouse\n', lbl);
    return;
end
nSig = sum(acc > 0.5);
if isempty(nTe)
    fprintf('%s: accuracy %.3f +/- %.3f (n=%d mice), sign test > 0.5: %d/%d p=%.4f\n', ...
        lbl, mean(acc), iSem(acc), numel(acc), nSig, numel(acc), ...
        1 - binocdf(nSig - 1, numel(acc), 0.5));
else
    fprintf('%s: accuracy %.3f +/- %.3f (n=%d mice, %d-%d test trials), sign test > 0.5: %d/%d p=%.4f\n', ...
        lbl, mean(acc), iSem(acc), numel(acc), min(nTe), max(nTe), nSig, numel(acc), ...
        1 - binocdf(nSig - 1, numel(acc), 0.5));
end
[pkV, pkI] = max(mn);
fprintf('  peak mean P(post) = %.3f at %+.2f s; above null 95%% at %d/%d time points\n', ...
    pkV, tVec(pkI), sum(mn > mn95), nT);
end

function iPrintPaired(lbl, a, b, both)
% Paired signed-rank comparison restricted to mice having both read-outs.
% `both` is a logical mask over mice (not an index vector).
both = both(:)';
a = a(:)';
b = b(:)';
a = a(both);
b = b(both);
if numel(a) < 2
    fprintf('%s: only %d paired mouse, test skipped\n', lbl, numel(a));
    return;
end
[pSR, h] = signrank(a, b);
fprintf('\n%s (paired, n=%d): %.3f vs %.3f, signrank p=%.4f %s\n', ...
    lbl, numel(a), mean(a), mean(b), pSR, iif(h == 1, '(different)', '(same)'));
end

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
    s = NaN;
    return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function j = iTestIdx(R, name)
% Index of test set `name` inside R.Tests; NaN when that mouse lacks it.
j = find(string({R.Tests.name}) == name, 1);
if isempty(j)
    j = NaN;
end
end

function s = iif(c, a, b)
if c; s = a; else; s = b; end
end
