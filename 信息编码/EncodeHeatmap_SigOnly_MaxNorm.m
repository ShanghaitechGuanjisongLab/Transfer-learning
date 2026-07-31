%% EncodeHeatmap_SigOnly_MaxNorm.m
% 仅生成 2 张新 Max-normalized information 热图（不重跑其他图）:
%   图1: Max-norm info about choice   — 细胞 = choice 显著（0-1s, p<0.05）
%   图2: Max-norm info about stimulus — 细胞 = stimulus 显著（0-1s, p<0.05）
% 方法与 EncodeHeatmap_ALB_HitMiss_vs_Cue.m 一致。

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

tMaskFull = (xs >= -1) & (xs <= 1);
tMaskTrain = (xs >= 0) & (xs <= 1);
tIdxFull = find(tMaskFull);
tIdxTrain = find(tMaskTrain);
tVec = xs(tIdxFull);
tTrain = xs(tIdxTrain);
fprintf('=== Sig-only Max-norm heatmaps ===\n');

TQ = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialUID"]);
TQ.Mouse = string(TQ.Mouse);
mice = unique(TQ.Mouse);
nMice = numel(mice);
fprintf('Total mice: %d\n', nMice);

%% 2. Per-mouse computation (GLM significance + MI + max-norm)
resAll = cell(nMice, 1);

for iM = 1:nMice
    m = mice(iM);
    allRaw = table();
    for phase = ["Learned","Transfer"]
        stim = "AudioWater"; if phase == "Transfer"; stim = "LightWater"; end
        try
            resp = DS.QueryNTS(struct('Mouse',m,'Phase',phase,'Stimulus',stim), ...
                UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","DateTime"]);
            if ~isempty(resp) && ~isempty(resp{1})
                t = resp{1};
                cueCol = double(stim=="LightWater") * ones(height(t), 1);
                t.Cue = cueCol;
                allRaw = [allRaw; t];
            end
        catch, end
    end
    if isempty(allRaw) || size(allRaw.TrialSignal, 2) < nTime; continue; end

    cu = uint64(unique(allRaw.CellUID)); nCell = numel(cu);
    tUid = unique(uint64(allRaw.TrialUID)); nTr = numel(tUid);

    % Build trial matrix
    X = zeros(nTr, nCell, nTime);
    yB = zeros(nTr,1); yC = zeros(nTr,1);
    ts = allRaw.TrialSignal;
    cellU = uint64(allRaw.CellUID);
    trialU = uint64(allRaw.TrialUID);
    beh = double(allRaw.Behavior);
    cue = allRaw.Cue;
    for iTr = 1:nTr
        rowMask = (trialU == tUid(iTr));
        rowsIdx = find(rowMask);
        for iR = 1:numel(rowsIdx)
            idx = rowsIdx(iR);
            ci = find(cu == cellU(idx));
            if ~isempty(ci); X(iTr, ci, :) = ts(idx, :); end
        end
        yB(iTr) = mode(beh(rowMask & ~isnan(beh)));
        yC(iTr) = mode(cue(rowMask & ~isnan(cue)));
    end

    % GLM encoding weights + p-values
    encBeh = nan(nCell, nTime); encPvl = nan(nCell, nTime);
    encCue = nan(nCell, nTime); encPvc = nan(nCell, nTime);
    miBeh = nan(nCell, nTime); miCue = nan(nCell, nTime);
    for iC = 1:nCell
        for iT = 1:nTime
            a = squeeze(X(:, iC, iT));
            if range(a) == 0; continue; end
            try
                [b,~,s] = glmfit(yB, a, 'normal'); encBeh(iC,iT)=b(2); encPvl(iC,iT)=s.p(2);
                [b,~,s] = glmfit(yC, a, 'normal'); encCue(iC,iT)=b(2); encPvc(iC,iT)=s.p(2);
            catch, end
            rb = corr(a, yB, 'rows','complete');
            if ~isnan(rb) && abs(rb) > eps; miBeh(iC,iT) = max(0, -0.5*log2(1-rb^2)); end
            rc = corr(a, yC, 'rows','complete');
            if ~isnan(rc) && abs(rc) > eps; miCue(iC,iT) = max(0, -0.5*log2(1-rc^2)); end
        end
    end

    % Max-normalize
    miBehNorm = miBeh ./ max(miBeh, [], 2, 'omitnan');
    miCueNorm = miCue ./ max(miCue, [], 2, 'omitnan');

    res = struct('Mouse', m, 'NCells', nCell, ...
        'EncPvl', encPvl, 'EncPvc', encPvc, ...
        'MiBehNorm', miBehNorm, 'MiCueNorm', miCueNorm);
    resAll{iM} = res;
    fprintf('  %s done (%d cells)\n', m, nCell);
end

validIdx = find(~cellfun(@isempty, resAll));
nValid = numel(validIdx);

%% 3. Fig A: Max-norm info about choice — choice-sig cells only
allC = []; allMouseC = []; allPkC = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    ti = ismember(tVec, tTrain);
    sigC = any(r.EncPvl(:, ti) < 0.05, 2);
    [~, pk] = max(r.MiBehNorm(:, ti), [], 2, 'omitnan');
    vc = ~isnan(pk) & sigC;
    allC = [allC; r.MiBehNorm(vc, :)];
    allMouseC = [allMouseC; repmat(string(r.Mouse), sum(vc), 1)];
    allPkC = [allPkC; tTrain(pk(vc))];
end
[~, soC] = sort(allPkC, 'descend');
allC = allC(soC, :); allMouseC = allMouseC(soC);
nC = size(allC, 1);

fA = figure('Name','Max-norm Info Choice (sig-choice cells)','Color','w',...
    'Position',[100 100 500 600]);
axA = axes(fA);
imagesc(axA, tVec, 1:nC, allC);
colormap(axA, iBlueBlackRedCmap()); caxis(axA, [0 1]);
cb = colorbar(axA); cb.Label.String = 'Norm. info';
xlabel(axA, 'Time (s)'); ylabel(axA, 'Cell #');
title(axA, sprintf('Max-norm info: choice (choice-sig cells, N=%d)', nC), ...
    'FontSize', 9, 'FontWeight', 'normal');
xline(axA, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
xline(axA, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
axA.FontSize = 8; box(axA, 'off');
fprintf('Fig A (choice sig): %d cells from %d mice\n', nC, numel(unique(allMouseC)));

%% 4. Fig B: Max-norm info about stimulus — stimulus-sig cells only
allS = []; allMouseS = []; allPkS = [];
for i = 1:nValid
    r = resAll{validIdx(i)};
    ti = ismember(tVec, tTrain);
    sigS = any(r.EncPvc(:, ti) < 0.05, 2);
    [~, pk] = max(r.MiCueNorm(:, ti), [], 2, 'omitnan');
    vc = ~isnan(pk) & sigS;
    allS = [allS; r.MiCueNorm(vc, :)];
    allMouseS = [allMouseS; repmat(string(r.Mouse), sum(vc), 1)];
    allPkS = [allPkS; tTrain(pk(vc))];
end
[~, soS] = sort(allPkS, 'descend');
allS = allS(soS, :); allMouseS = allMouseS(soS);
nS = size(allS, 1);

fB = figure('Name','Max-norm Info Stimulus (sig-stim cells)','Color','w',...
    'Position',[100 100 500 600]);
axB = axes(fB);
imagesc(axB, tVec, 1:nS, allS);
colormap(axB, iBlueBlackRedCmap()); caxis(axB, [0 1]);
cb = colorbar(axB); cb.Label.String = 'Norm. info';
xlabel(axB, 'Time (s)'); ylabel(axB, 'Cell #');
title(axB, sprintf('Max-norm info: stimulus (stim-sig cells, N=%d)', nS), ...
    'FontSize', 9, 'FontWeight', 'normal');
xline(axB, 0, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
xline(axB, 1, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
axB.FontSize = 8; box(axB, 'off');
fprintf('Fig B (stim sig): %d cells from %d mice\n', nS, numel(unique(allMouseS)));

fprintf('\nDone. Only the 2 new figures generated.\n');


% ==================== Local Functions ====================

function map = iBlueBlackRedCmap()
n = 128;
map = [linspace(0.05,0.95,n)', linspace(0.05,0.40,n)', linspace(0.35,0.05,n)'];
map = map .^ 0.7;
map = max(0, min(1, map));
end