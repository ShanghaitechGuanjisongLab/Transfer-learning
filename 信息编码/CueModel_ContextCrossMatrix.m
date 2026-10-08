%% CueModel_ContextCrossMatrix.m
% Trial analysis (no figure number yet): the English Fig3D cue pre/post decoder
% run as a complete 4x4 cross-context matrix. The SAME decoder rule is used in
% every cell; only the training and read-out contexts change.
%
%           read-out ->   Audio only   Light only   Audio-water   Light-water
%   train   Audio only    self (OOF)   AO -> LO     AO -> AW      AO -> LW
%           Light only    LO -> AO     self (OOF)   LO -> AW      LO -> LW
%           Audio water   AW -> AO     AW -> LO     self (OOF)    AW -> LW  (= Fig3D direction)
%           Light water   LW -> AO     LW -> LO     LW -> AW      self (OOF)
%
% Context order = experimental timeline: AudioOnly and LightOnly are the two
% interleaved cue-only stimuli of the same LAu / LAuW calibration blocks, then
% AudioWater (initial learning) and LightWater (the whole light task).
%
% Diagonal = 5-fold trial-aware out-of-fold self-test within the training
% context. Off-diagonal = decoder trained on ALL trials of the row context and
% read out, without retraining, on the held-out trials of the column context.
% Rows are therefore self-tests and cross-context transfers of one decoder; the
% AW -> LW cell is exactly the Fig3D no-gap cell, except that the AudioWater
% training pool is the whole initial learning phase instead of the Learned block
% alone.
%
% Contexts (all four pooled per mouse as ONE trial pool each, so every cell of
% the matrix reads out on trials the trainer never saw):
%   Audio only  - AudioOnly trials of the LAu / LAuW calibration blocks, where
%                 the cue is never paired with water (WaterOnly is a separate
%                 stimulus). 20-30 trials per mouse.
%   Light only  - LightOnly trials of the same calibration blocks: the light cue
%                 of the same cue-only phase, interleaved with AudioOnly inside
%                 the very same blocks. 20-30 trials per mouse.
%   Audio water - every AudioWater block of the initial learning phase (Phase
%                 Naive / Learned / unannotated; Recall excluded, see below).
%                 60-180 trials per mouse.
%   Light water - every LightWater block, i.e. Transfer first exposure plus its
%                 unannotated and Final blocks. 60-180 trials per mouse.
%
% Block/trial inclusion rule (applied identically to all four contexts):
%   - blocks carrying a MustWarn flag are skipped. Verified flags in this
%     cohort: AudioWater "中断两次，行为和钙对不上" (vtf0352, vtf0354) and
%     "CD1没记到" (vtf0233, yqn0020); LightWater "拍错Z层，舍弃信号" (vtf0354),
%     "水滴漏了，没有拍到" (vtf0233) and "2/5层亮度反相" (vtf0353, its Transfer
%     block - the same block Fig3D excluded, here only that block drops out).
%     No LAu / LAuW calibration block is flagged, so the two cue-only contexts
%     keep all of their blocks.
%   - trials without a Behavior annotation are dropped.
% Phase assignment (verified per block, not assumed):
%   - every unannotated AudioWater block precedes the first LightWater block, and
%     every Recall AudioWater block follows it, so "initial learning phase" is
%     unambiguous and contains no post-transfer audio session.
%   - for all 11 mice the earliest LightWater block is the one annotated Phase
%     "Transfer", so the light context starts at the first new-task exposure.
%
% Cell set: per mouse the intersection over the four contexts; verified
% identical to each single context's cell set (registration is shared), so all
% sixteen cells of a mouse's sub-matrix use the same cells and the same trial-wise
% row z-scoring.
%
% Decoder: TransferLearning.DecodeCuePrePostTransfer - per trial the mean
% population activity in the pre window (-1..0 s) and the post window (0..1 s),
% label pre = 0 / post = 1, LASSO logistic with Lambda = 0.02/sqrt(2*nTrainTrial)
% (the Fig3D rule), 200 label-shuffle permutations on the training labels only.
% Water is delivered at cue + 1 s, so the post window ends exactly at water
% delivery and holds no water/lick response in any context.
%
% Cohort: AudioLightBaseline (no gap), 11 mice; yqn1130 has no calibration
% block (no AudioOnly / LightOnly trial) and drops out -> 10 mice in all
% sixteen cells.
%
% Output: 信息编码/CueModel_ContextCrossMatrix_Results.mat
% Plots:  英文图/Trial_ContextCrossMatrix.m          (4x4 P(post) curve tiles)
%         英文图/Trial_ContextCrossMatrixDeltaBars.m (ΔP(post) grouped bars)
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
nT = numel(tVec);
NPERM = 200;
ctxStim = ["AudioOnly", "LightOnly", "AudioWater", "LightWater"];
ctxShort = ["AO", "LO", "AW", "LW"];
ctxLabel = ["Audio only", "Light only", "Audio-water", "Light-water"];
nCtx = numel(ctxStim);
fprintf('=== CueModel 4x4 cross-context matrix (%s) ===\n', dsName);
fprintf('Pre: %.2f-%.2fs  Post: %.2f-%.2fs  | read-out grid: %d pts (%.2f-%.2f s)  | permutations: %d\n', ...
    xs(find(tPre, 1)), xs(find(tPre, 1, 'last')), xs(find(tPost, 1)), xs(find(tPost, 1, 'last')), ...
    nT, tVec(1), tVec(end), NPERM);

%% 1. Block annotation (Design / Phase / Mouse / quality flag per block)
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
nFlag = Blk.Warn ~= "-";
fprintf('Blocks: %d total, %d flagged (skipped): %s\n', height(Blk), sum(nFlag), ...
    strjoin(compose('%s/%s[%s]', Blk.Mouse(nFlag), Blk.Design(nFlag), Blk.Warn(nFlag)), '; '));
fprintf('Context blocks (flagged excluded): %s\n', ...
    strjoin(arrayfun(@(k) sprintf('%s=%d', ctxShort(k), sum(iCtxSel(Blk, k))), ...
    1:nCtx, 'UniformOutput', false), ', '));

%% 2. Per-mouse trial data (serial load) -> one task per matrix row
tasks = {};
meta = {};
for m = mice
    tab = cell(nCtx, 1);
    nBlk = zeros(nCtx, 1);
    for k = 1:nCtx
        [tab{k}, nBlk(k)] = iContextTrials(DS, Blk, m, k);
    end
    if any(cellfun(@isempty, tab)); continue; end   % e.g. yqn1130: no calibration trial
    cu = unique(uint64(tab{1}.CellUID));
    for k = 2:nCtx
        cu = intersect(cu, unique(uint64(tab{k}.CellUID)));
    end
    if numel(cu) < 5; continue; end
    X = cell(nCtx, 1);
    for k = 1:nCtx
        X{k} = TransferLearning.BuildTrialMatrix(tab{k}, cu);
    end
    for r = 1:nCtx
        T = struct('DS', r, 'Mouse', char(m), 'NCells', numel(cu), 'CellUIDs', cu, ...
            'XTrT', X{r}(:, :, tIdxFull), ...
            'preTr', mean(X{r}(:, :, tPre), 3), ...
            'postTr', mean(X{r}(:, :, tPost), 3));
        c = setdiff(1:nCtx, r);
        Te = struct('Name', "", 'preTe', [], 'postTe', [], 'XTeT', [], 'nTe', 0);
        Te = repmat(Te, numel(c), 1);
        for j = 1:numel(c)
            Te(j) = iTestEntry(char(ctxShort(c(j))), X{c(j)}, tPre, tPost, tIdxFull);
        end
        T.Tests = Te;
        tasks{end + 1} = T; %#ok<AGROW>
        % cell-wrapped array values, otherwise struct() would build an array
        meta{end + 1} = struct('Row', r, 'Mouse', char(m), 'Cells', numel(cu), ...
            'Cols', {c}, 'nTr', size(X{r}, 1), 'nTe', {[Te.nTe]}); %#ok<AGROW>
    end
    lin = sprintf('%-9s cells=%d |', m, numel(cu));
    for k = 1:nCtx
        lin = [lin sprintf(' %s %db/%dt |', ctxShort(k), nBlk(k), size(X{k}, 1))]; %#ok<AGROW>
    end
    fprintf('%s\n', lin);
end
fprintf('Decodable mice: %d -> %d matrix rows to decode\n', numel(meta) / nCtx, numel(tasks));
if isempty(tasks); fprintf('Nothing to decode.\n'); return; end

%% 3. Decode (parallel over rows x mice)
res = cell(numel(tasks), 1);
parfor i = 1:numel(tasks)
    rng(42 + i);   % same per-task seed as CueModel_TransferAudioToLight.m
    res{i} = TransferLearning.DecodeCuePrePostTransfer(tasks{i}, tVec, NPERM);
end
clear tasks;   % the per-time-point trial tensors are not needed any more
fprintf('Decoding done (%s)\n', char(datetime('now', 'Format', 'HH:mm:ss')));

%% 4. Assemble the matrix
mouseNames = unique(string(cellfun(@(M) M.Mouse, meta, 'UniformOutput', false)), 'stable');
nM = numel(mouseNames);
% per-cell per-mouse accuracy, curves and nulls
accM = nan(nCtx, nCtx, nM);          % (train, test, mouse)
curves = cell(nCtx, nCtx);
nulls = cell(nCtx, nCtx);
nTeCell = nan(nCtx, nCtx, nM);
for i = 1:numel(res)
    R = res{i};
    M = meta{i};
    im = find(mouseNames == string(R.Mouse), 1);
    r = M.Row;
    % diagonal: out-of-fold self-test of the training context
    accM(r, r, im) = R.s1Acc;
    curves{r, r} = iPutCurve(curves{r, r}, im, R.pPostS1T);
    nulls{r, r} = iPutCurve(nulls{r, r}, im, R.null95S1);
    nTeCell(r, r, im) = R.nTr;
    % off-diagonal: held-out cross-context read-out
    for j = 1:numel(R.Tests)
        K = R.Tests(j);
        c = find(ctxShort == K.name, 1);
        accM(r, c, im) = K.acc;
        curves{r, c} = iPutCurve(curves{r, c}, im, K.pPostByT);
        nulls{r, c} = iPutCurve(nulls{r, c}, im, K.null95);
        nTeCell(r, c, im) = K.nTe;
    end
end

%% 5. Summary
fprintf('\n=== Per mouse (accuracy of every matrix cell, listed row by row) ===\n');
hdr = strings(1, nCtx * nCtx);
for r = 1:nCtx
    for c = 1:nCtx
        hdr((r - 1) * nCtx + c) = ctxShort(r) + "_" + ctxShort(c);
    end
end
fprintf('%-9s %s\n', 'mouse', strjoin(compose('%-6s', hdr), ' '));
for im = 1:nM
    lin = sprintf('%-9s', mouseNames(im));
    for r = 1:nCtx
        for c = 1:nCtx
            lin = [lin sprintf(' %-6s', iFmtPct(accM(r, c, im)))]; %#ok<AGROW>
        end
    end
    fprintf('%s\n', lin);
end

fprintf('\n=== Group means (rows = training context, columns = read-out context) ===\n');
fprintf('%-14s', 'train \ read');
for c = 1:nCtx
    fprintf('%-26s', ctxLabel(c));
end
fprintf('\n');
gMean = nan(nCtx, nCtx);
gSem = nan(nCtx, nCtx);
for r = 1:nCtx
    fprintf('%-12s', char(ctxLabel(r)));
    for c = 1:nCtx
        v = squeeze(accM(r, c, :));
        v = v(isfinite(v));
        gMean(r, c) = mean(v);
        gSem(r, c) = iSem(v);
        fprintf('%-26s', sprintf('%.3f +/- %.3f (n=%d)', gMean(r, c), gSem(r, c), numel(v)));
    end
    fprintf('\n');
end
fprintf('(diagonal = 5-fold out-of-fold self-test; off-diagonal = trained on ALL trials of the row context)\n');

fprintf('\n=== Per-cell detail ===\n');
for r = 1:nCtx
    for c = 1:nCtx
        v = squeeze(accM(r, c, :));
        ok = isfinite(v);
        n = sum(ok);
        nSig = sum(v(ok) > 0.5);
        [mn, mn95] = iGroupCurves(curves{r, c}(ok, :), nulls{r, c}(ok, :));
        [pkV, pkI] = max(mn);
        kind = iif(r == c, 'self OOF', 'transfer');
        fprintf('%s -> %s (%s): %.3f +/- %.3f (n=%d), sign test > 0.5: %d/%d p=%.4f; peak P(post) %.3f at %+.2f s; above null 95%% at %d/%d; median %d trials\n', ...
            ctxLabel(r), ctxLabel(c), kind, gMean(r, c), gSem(r, c), n, nSig, n, ...
            1 - binocdf(nSig - 1, n, 0.5), pkV, tVec(pkI), sum(mn > mn95), nT, ...
            median(nTeCell(r, c, ok), 'omitnan'));
    end
end

fprintf('\n=== Row-wise paired comparisons (one training context, mice as blocks) ===\n');
for r = 1:nCtx
    cs = setdiff(1:nCtx, r);
    for c = cs
        iPrintPaired(sprintf('%s train: self vs -> %s', ctxLabel(r), ctxLabel(c)), ...
            squeeze(accM(r, r, :)), squeeze(accM(r, c, :)));
    end
    for a = 1:numel(cs)
        for b = a + 1:numel(cs)
            iPrintPaired(sprintf('%s train: -> %s vs -> %s', ctxLabel(r), ctxLabel(cs(a)), ctxLabel(cs(b))), ...
                squeeze(accM(r, cs(a), :)), squeeze(accM(r, cs(b), :)));
        end
    end
end

fprintf('\n=== Column-wise comparison (training context matters for a fixed read-out) ===\n');
for c = 1:nCtx
    A = squeeze(accM(:, c, :))';    % mice x training contexts
    keep = all(isfinite(A), 2);
    if isempty(A) || ~any(keep); continue; end
    p = friedman(A(keep, :), 1, 'off');
    fprintf('read-out %s (n=%d mice, %d training contexts): %s, Friedman p=%.4f\n', ...
        ctxLabel(c), sum(keep), nCtx, iFmtVec(mean(A(keep, :), 1)), p);
end

% --- reference: the published Fig3D direction ---
refMat = fullfile(thisDir, 'CueModel_TransferAudioToLight_Results.mat');
if isfile(refMat)
    Sref = load(refMat);
    isDS1 = cellfun(@(R) R.DS == 1, Sref.res);
    v = cellfun(@(R) R.s2Acc, Sref.res(isDS1));
    v1 = cellfun(@(R) R.s1Acc, Sref.res(isDS1));
    fprintf('\nReference (English Fig3D, same cohort): Stage1 self %.3f +/- %.3f -> Learned AudioWater to Transfer LightWater %.3f +/- %.3f (n=%d)\n', ...
        mean(v1), iSem(v1), mean(v), iSem(v), numel(v));
    iAW = find(ctxShort == "AW", 1);
    iLW = find(ctxShort == "LW", 1);
    fprintf('Here the AW->LW cell is %.3f +/- %.3f; it differs from Fig3D because the AudioWater training pool is the whole initial learning phase instead of the Learned block alone, and because flagged blocks are excluded.\n', ...
        gMean(iAW, iLW), gSem(iAW, iLW));
    fprintf('NB: fitclinear lasso-logistic results depend on the RNG stream position, so per-time-point curves are reproducible only up to solver noise (accuracies match, curves can differ by ~0.03).\n');
else
    fprintf('\nReference Fig3D results not found (%s): comparison skipped.\n', refMat);
end

save(fullfile(thisDir, 'CueModel_ContextCrossMatrix_Results.mat'), ...
    'res', 'meta', 'dsName', 'tVec', 'NPERM', 'ctxStim', 'ctxShort', 'ctxLabel', ...
    'accM', 'curves', 'nulls', 'nTeCell', 'mouseNames');
fprintf('\nSaved CueModel_ContextCrossMatrix_Results.mat\n');
fprintf('Next: run 英文图/Trial_ContextCrossMatrix.m\n');

%% ========== local functions ==========
function sel = iCtxSel(Blk, k)
% Block selection of one context (quality-flagged blocks excluded).
% k follows the ctxStim order: 1 AudioOnly, 2 LightOnly, 3 AudioWater, 4 LightWater.
% The two cue-only contexts share the LAu / LAuW calibration blocks.
sel = Blk.Warn == "-";
switch k
    case {1, 2}
        sel = sel & ismember(Blk.Design, ["LAu", "LAuW"]);
    case 3
        sel = sel & Blk.Design == "AudioWater" & ...
            (ismember(Blk.Phase, ["Naive", "Learned"]) | ismissing(Blk.Phase));
    case 4
        sel = sel & Blk.Design == "LightWater";
end
end

function [T, nBlk] = iContextTrials(DS, Blk, m, k)
% Trial table of one context for one mouse, z-scored through QueryZScoreNts.
% Must follow the same order as ctxStim in the main script.
ctxStimLocal = ["AudioOnly", "LightOnly", "AudioWater", "LightWater"];
uid = Blk.BlockUID(iCtxSel(Blk, k) & Blk.Mouse == m);
nBlk = numel(uid);
T = table();
if nBlk == 0; return; end
T = TransferLearning.QueryZScoreNts(DS, m, ctxStimLocal(k));
if isempty(T); return; end
T = T(~isnan(T.Behavior), :);
T = T(ismember(uint64(T.BlockUID), uint64(uid)), :);
end

function Te = iTestEntry(name, X, tPre, tPost, tIdxFull)
% One held-out test set entry for TransferLearning.DecodeCuePrePostTransfer.
Te = struct('Name', name, ...
    'preTe', mean(X(:, :, tPre), 3), ...
    'postTe', mean(X(:, :, tPost), 3), ...
    'XTeT', X(:, :, tIdxFull), ...
    'nTe', size(X, 1));
end

function C = iPutCurve(C, iRow, v)
% Store one mouse's curve into a (mouse x time) cell slot, growing on demand.
if isempty(C) || size(C, 1) < iRow
    C(iRow, 1:numel(v)) = NaN;
end
C(iRow, :) = v(:)';
end

function [mn, mn95] = iGroupCurves(M, N)
% Group mean of per-mouse P(post) curves (rows) and of their null 95% bands.
mn = mean(M, 1, 'omitnan');
mn95 = mean(N, 1, 'omitnan');
end

function iPrintPaired(lbl, a, b)
% Paired signed-rank test on mice having both values.
a = a(:);
b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 2
    fprintf('%s: fewer than 2 paired mice, test skipped\n', lbl);
    return;
end
[p, h] = signrank(a(ok), b(ok));
fprintf('%s (n=%d): %.3f vs %.3f, signrank p=%.4f %s\n', lbl, sum(ok), ...
    mean(a(ok)), mean(b(ok)), p, iif(h == 1, '(different)', '(same)'));
end

function s = iFmtPct(v)
if isfinite(v); s = sprintf('%.0f%%', 100 * v); else; s = '-'; end
end

function s = iFmtVec(v)
s = strjoin(compose('%.3f', v(:)'), ', ');
end

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok); s = NaN; return; end
s = std(v(ok)) / sqrt(sum(ok));
end

function s = iif(c, a, b)
if c; s = a; else; s = b; end
end
