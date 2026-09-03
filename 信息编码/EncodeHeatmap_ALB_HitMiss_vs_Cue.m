%% EncodeHeatmap_ALB_HitMiss_vs_Cue.m
% Runyan et al. 2017 Fig.2f,g,h — 编码热图 + 互信息 + 累积信息
%
% 数据: Learned AudioWater + Transfer LightWater 合并
% 两个编码模型（每只鼠独立建模）:
%   模型1: choice — hit vs miss（行为标签）
%   模型2: stimulus — cue（LightWater vs AudioWater 刺激类型）
%
% 方法: 逐细胞逐时间点
%   (1) MI = -0.5 × log₂(1 - r²) bits,  r = 点双列相关系数
%   (2) GLM: activity = β₀ + β₁ × label → 编码权重
%
% 训练窗口: 0-1s post-stimulus
% 热图范围: -1 到 1s

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
fprintf('=== Encoding heatmap: choice vs stimulus ===\n');
fprintf('Training window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxTrain(1)), xs(tIdxTrain(end)), nTtrain);
fprintf('Heatmap window: %.2f-%.2f s (%d time points)\n', ...
    xs(tIdxFull(1)), xs(tIdxFull(end)), nTfull);

%% 3. List mice
TQ = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialUID"]);
TQ.Mouse = string(TQ.Mouse);
TQ.Phase = string(TQ.Phase);
mice = unique(TQ.Mouse);
fprintf('Total mice: %d\n', numel(mice));

%% 4. Per-mouse analysis
nMice = numel(mice);
resAll = cell(nMice, 1);

for iM = 1:nMice
    m = mice(iM);
    fprintf('\n========== Mouse %s (%d/%d) ==========\n', m, iM, nMice);

    % Load combined data
    allRaw = table();
    for phase = ["Learned", "Transfer"]
        stim = "AudioWater";
        if phase == "Transfer"; stim = "LightWater"; end
        try
            resp = DS.QueryNTS(struct('Mouse',m,'Phase',phase,'Stimulus',stim), ...
                UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","DateTime"]);
            if ~isempty(resp) && ~isempty(resp{1})
                tbl = resp{1};
                tbl.Phase = repmat(phase, height(tbl), 1);
                tbl.Cue = repmat(double(stim == "LightWater"), height(tbl), 1);
                allRaw = [allRaw; tbl];
            end
        catch, end
    end

    if isempty(allRaw) || ~ismember('TrialSignal', string(allRaw.Properties.VariableNames))
        fprintf('  SKIP: no data\n'); continue;
    end

    cellUIDs = uint64(unique(allRaw.CellUID));
    nCell = numel(cellUIDs);
    if nCell < 5; fprintf('  SKIP: %d cells\n', nCell); continue; end

    [X, yBeh, yCue] = iBuildTrialMatrixWithCue(allRaw, cellUIDs);
    if isempty(X); fprintf('  SKIP: empty matrix\n'); continue; end
    X = X(:, :, tIdxFull);
    nTr = size(X, 1);
    fprintf('  Cells=%d  Trials=%d (H=%d/M=%d, AW=%d/LW=%d)\n', ...
        nCell, nTr, sum(yBeh==1), sum(yBeh==0), sum(yCue==0), sum(yCue==1));

    if sum(yBeh==1) < 2 || sum(yBeh==0) < 2 || sum(yCue==0) < 2 || sum(yCue==1) < 2
        fprintf('  SKIP: class imbalance\n'); continue;
    end

    % ---- Per-cell per-time-point MI (bits) + GLM encoding weights ----
    miBeh = nan(nCell, nTfull);
    miCue = nan(nCell, nTfull);
    encBeh = nan(nCell, nTfull);
    encPvl = nan(nCell, nTfull);
    encCue = nan(nCell, nTfull);
    encPvc = nan(nCell, nTfull);

    % Number of bins for standard (binned) MI estimation
    nBins = max(3, min(8, round(sqrt(nTr)/2)*2));

    for iC = 1:nCell
        for iT = 1:nTfull
            act = squeeze(X(:, iC, iT));
            if all(isnan(act)) || range(act) == 0; continue; end

            % GLM for choice
            try
                [b, ~, stats] = glmfit(yBeh, act, 'normal');
                encBeh(iC, iT) = b(2);
                encPvl(iC, iT) = stats.p(2);
            catch, end

            % GLM for stimulus
            try
                [b, ~, stats] = glmfit(yCue, act, 'normal');
                encCue(iC, iT) = b(2);
                encPvc(iC, iT) = stats.p(2);
            catch, end

            % MI for choice (standard binned estimator + Panzeri-Treves correction)
            miBeh(iC, iT) = iPtCorrectedMI(act, yBeh, nBins);

            % MI for stimulus (standard binned estimator + Panzeri-Treves correction)
            miCue(iC, iT) = iPtCorrectedMI(act, yCue, nBins);
        end
    end

    % Max-normalize MI per cell within 0-1s training window
    % This avoids a pre-stimulus noise peak in [-1,1] s inflating the denominator
    % and attenuating the true training-window encoding strength.
    miBehNorm = nan(size(miBeh));
    miCueNorm = nan(size(miCue));
    for iC = 1:nCell
        denomB = max(miBeh(iC, tIdxTrainInFull), [], 'omitnan');
        denomC = max(miCue(iC, tIdxTrainInFull), [], 'omitnan');
        if ~isnan(denomB) && denomB > 0
            miBehNorm(iC, :) = miBeh(iC, :) ./ denomB;
        end
        if ~isnan(denomC) && denomC > 0
            miCueNorm(iC, :) = miCue(iC, :) ./ denomC;
        end
    end

    % Store
    res = struct();
    res.Mouse = m;
    res.CellUIDs = cellUIDs;
    res.NCells = nCell;
    res.NTrials = nTr;
    res.NHit = sum(yBeh==1);
    res.NMiss = sum(yBeh==0);
    res.Naudio = sum(yCue==0);
    res.Nlight = sum(yCue==1);
    res.MiBehRaw = miBeh;
    res.MiCueRaw = miCue;
    res.MiBehNorm = miBehNorm;
    res.MiCueNorm = miCueNorm;
    res.EncBeh = encBeh;
    res.EncPvl = encPvl;
    res.EncCue = encCue;
    res.EncPvc = encPvc;
    res.TimeVec = xs(tIdxFull);
    resAll{iM} = res;

    fprintf('  Done. Sig cells (p<0.05): choice=%d/%d, stimulus=%d/%d\n', ...
        sum(any(encPvl < 0.05, 2)), nCell, ...
        sum(any(encPvc < 0.05, 2)), nCell);
end

%% 5. Figures
validIdx = find(~cellfun(@isempty, resAll));
nValid = numel(validIdx);
fprintf('\n========== Valid mice: %d/%d ==========\n', nValid, nMice);
for i = 1:nValid
    r = resAll{validIdx(i)};
    fprintf('  %s: %d cells, %d trials (H%d/M%d, AW%d/LW%d)\n', ...
        r.Mouse, r.NCells, r.NTrials, r.NHit, r.NMiss, r.Naudio, r.Nlight);
end
if nValid == 0; return; end

nCols = min(4, nValid);
nRows = ceil(nValid / nCols);
tVec = xs(tIdxFull);
tTrain = xs(tIdxTrain);

% ===== Fig.2d: Cumulative information (integrated per-cell MI over time) =====
% For each cell at each time point, compute MI(activity[t]; label).
% Cumulative info at time T = sum_{t=0}^{T} mean MI across cells at time t.
% This is mathematically guaranteed to be monotonically increasing.
nTtr = numel(tTrain);
cumBitsBeh = nan(nValid, nTtr);
cumBitsCue = nan(nValid, nTtr);

for i = 1:nValid
    r = resAll{validIdx(i)};
    cellU = r.CellUIDs;
    % Rebuild full data to get trial-level activity
    allRaw = table();
    for phase = ["Learned", "Transfer"]
        stim = "AudioWater";
        if phase == "Transfer"; stim = "LightWater"; end
        try
            resp = DS.QueryNTS(struct('Mouse',r.Mouse,'Phase',phase,'Stimulus',stim), ...
                UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","DateTime"]);
            if ~isempty(resp) && ~isempty(resp{1})
                tbl = resp{1}; tbl.Cue = repmat(double(stim=="LightWater"),height(tbl),1);
                allRaw = [allRaw; tbl];
            end
        catch, end
    end
    if isempty(allRaw); continue; end
    [Xfull, yB, yC] = iBuildTrialMatrixWithCue(allRaw, cellU);
    if isempty(Xfull); continue; end
    
    % Restrict to training window time indices
    trainFullIdx = find(ismember(r.TimeVec, tTrain));
    Xtr = Xfull(:, :, trainFullIdx);
    
    % Select cells with significant encoding (p<0.05)
    sigBeh = any(r.EncPvl < 0.05, 2);
    sigCue = any(r.EncPvc < 0.05, 2);
    nSigBeh = sum(sigBeh);
    nSigCue = sum(sigCue);
    
    % Per time point: compute mean MI across significant cells only
    miTBeh = zeros(nTtr, 1);
    miTCue = zeros(nTtr, 1);
    nBinsC = max(3, min(8, round(sqrt(size(Xtr,1))/2)*2));
    for iT = 1:nTtr
        act = squeeze(Xtr(:, :, iT));
        % Choice: only significant cells
        miB = zeros(nSigBeh, 1); idxB = 1;
        for iC = find(sigBeh)'
            a = act(:, iC);
            if range(a) == 0; continue; end
            miB(idxB) = iPtCorrectedMI(a, yB, nBinsC);
            idxB = idxB + 1;
        end
        % Stimulus: only significant cells
        miC = zeros(nSigCue, 1); idxC = 1;
        for iC = find(sigCue)'
            a = act(:, iC);
            if range(a) == 0; continue; end
            miC(idxC) = iPtCorrectedMI(a, yC, nBinsC);
            idxC = idxC + 1;
        end
        miTBeh(iT) = mean(miB(1:idxB-1), 'omitnan');
        miTCue(iT) = mean(miC(1:idxC-1), 'omitnan');
    end
    
    % Cumulative sum (monotonically increasing by construction)
    cumBitsBeh(i, :) = cumsum(miTBeh)';
    cumBitsCue(i, :) = cumsum(miTCue)';
    fprintf('  %s done (sig cells: choice=%d, stimulus=%d)\n', r.Mouse, nSigBeh, nSigCue);
end

fMean = figure('Name','Cumulative decoder info','Color','w',...
    'Position',[200 200 420 300]);
ax = axes(fMean); hold(ax,'on');
mnB = mean(cumBitsBeh,1,'omitnan'); seB = std(cumBitsBeh,0,1,'omitnan')/sqrt(nValid);
mnC = mean(cumBitsCue,1,'omitnan'); seC = std(cumBitsCue,0,1,'omitnan')/sqrt(nValid);
errorbar(ax,tTrain,mnB,seB,'-o','Color',[0.85 0.33 0.10],'LineWidth',2,'MarkerSize',4,'MarkerFaceColor',[0.85 0.33 0.10]);
errorbar(ax,tTrain,mnC,seC,'-o','Color',[0 0.45 0.74],'LineWidth',2,'MarkerSize',4,'MarkerFaceColor',[0 0.45 0.74]);
hold(ax,'off');
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Cumulative information (bits)');
title(ax,'Cumulative info (significant cells, p<0.05)','FontSize',9,'FontWeight','normal');
legend(ax,{'Choice (hit/miss)','Stimulus (cue)'},'Location','northwest','Box','off');
xlim(ax,[tTrain(1) tTrain(end)]);
ylim(ax,[0 max([mnB+seB,mnC+seC])*1.3]);
box(ax,'off');
fprintf('Cumulative decoder info: choice final=%.4f bits, stimulus final=%.4f bits\n',...
    mnB(end), mnC(end));

% ===== Per-time-point MI curves (full -1 to 1s window) =====
% For each time point, mean MI across significant cells (choice vs stimulus).
nTfullPts = numel(tVec);
miTBeh = nan(nValid, nTfullPts);
miTCue = nan(nValid, nTfullPts);
for i = 1:nValid
    r = resAll{validIdx(i)};
    ti = ismember(r.TimeVec, tTrain);
    sigB = any(r.EncPvl(:, ti) < 0.05, 2);
    sigC = any(r.EncPvc(:, ti) < 0.05, 2);
    for iT = 1:nTfullPts
        miTBeh(i, iT) = mean(r.MiBehRaw(sigB, iT), 'omitnan');
        miTCue(i, iT) = mean(r.MiCueRaw(sigC, iT), 'omitnan');
    end
end

fMiCurve = figure('Name','Per-time-point MI','Color','w',...
    'Position',[200 200 420 300]);
ax = axes(fMiCurve); hold(ax,'on');
mnB = mean(miTBeh,1,'omitnan'); seB = std(miTBeh,0,1,'omitnan')/sqrt(nValid);
mnC = mean(miTCue,1,'omitnan'); seC = std(miTCue,0,1,'omitnan')/sqrt(nValid);
errorbar(ax,tVec,mnB,seB,'-o','Color',[0.85 0.33 0.10],'LineWidth',2,'MarkerSize',4,'MarkerFaceColor',[0.85 0.33 0.10]);
errorbar(ax,tVec,mnC,seC,'-o','Color',[0 0.45 0.74],'LineWidth',2,'MarkerSize',4,'MarkerFaceColor',[0 0.45 0.74]);
hold(ax,'off');
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'MI (bits)');
title(ax,'Per-time-point MI (significant cells, PT-corrected)','FontSize',9,'FontWeight','normal');
legend(ax,{'Choice (hit/miss)','Stimulus (cue)'},'Location','northwest','Box','off');
xlim(ax,[tVec(1) tVec(end)]);
xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6);
ylim(ax,[0 max([mnB+seB,mnC+seC])*1.3]);
box(ax,'off');
fprintf('Per-time-point MI: choice peak=%.4f bits, stimulus peak=%.4f bits\n',max(mnB),max(mnC));

% ===== Fig.2f+g: Max-norm info — choice vs stimulus, same cell order =====
% Pool all significant cells (p<0.05 for both), sort by stimulus peak time
allBeh = []; allCue = []; allMouse = []; allPeakStim = [];
for i=1:nValid
    r=resAll{validIdx(i)};
    ti=ismember(r.TimeVec,tTrain);
    % Only cells significant for BOTH choice and stimulus IN 0-1s TRAINING WINDOW
    sigBehTr = any(r.EncPvl(:,ti) < 0.05, 2);
    sigCueTr = any(r.EncPvc(:,ti) < 0.05, 2);
    sigBoth = sigBehTr & sigCueTr;
    [~,pkS]=max(r.MiCueNorm(:,ti),[],2,'omitnan');
    validC = ~isnan(pkS) & sigBoth;
    allBeh=[allBeh; r.MiBehNorm(validC,:)];
    allCue=[allCue; r.MiCueNorm(validC,:)];
    allMouse=[allMouse; repmat(string(r.Mouse),sum(validC),1)];
    allPeakStim=[allPeakStim; tTrain(pkS(validC))];
end
[~, sortOrder]=sort(allPeakStim,'descend');
allBeh=allBeh(sortOrder,:);
allCue=allCue(sortOrder,:);
allMouse=allMouse(sortOrder);

nTotal=size(allBeh,1);
fComb = figure('Name','Max-norm Info Combined','Color','w',...
    'Position',[100 100 900 600]);
tl=tiledlayout(fComb,1,2,'TileSpacing','compact','Padding','compact');

% Left: choice
ax1=nexttile;
imagesc(ax1,tVec,1:nTotal,allBeh);
colormap(ax1,iBlueBlackRedCmap()); caxis(ax1,[0 1]);
cb=colorbar(ax1); cb.Label.String='Norm. info';
xlabel(ax1,'Time (s)'); ylabel(ax1,'Cell #');
title(ax1,sprintf('Choice (sig cells, N=%d)',nTotal),...
    'FontSize',9,'FontWeight','normal');
xline(ax1,0,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
xline(ax1,1,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
ax1.FontSize=8; box(ax1,'off');
% Mouse separators
mouseList=unique(allMouse,'stable'); cumC=0;
for iM=1:numel(mouseList)
    nThis=sum(allMouse==mouseList(iM)); cumC=cumC+nThis;
    if cumC<nTotal; yline(ax1,cumC+0.5,':','Color',[0.3 0.3 0.3],'LineWidth',0.3); end
end

% Right: stimulus
ax2=nexttile;
imagesc(ax2,tVec,1:nTotal,allCue);
colormap(ax2,iBlueBlackRedCmap()); caxis(ax2,[0 1]);
cb=colorbar(ax2); cb.Label.String='Norm. info';
xlabel(ax2,'Time (s)');
title(ax2,sprintf('Stimulus (Light vs Audio, N=%d)',nTotal),...
    'FontSize',9,'FontWeight','normal');
xline(ax2,0,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
xline(ax2,1,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
ax2.FontSize=8; box(ax2,'off');
% Match y limits
ylim(ax2,ylim(ax1));
% Mouse separators
cumC=0;
for iM=1:numel(mouseList)
    nThis=sum(allMouse==mouseList(iM)); cumC=cumC+nThis;
    if cumC<nTotal; yline(ax2,cumC+0.5,':','Color',[0.3 0.3 0.3],'LineWidth',0.3); end
end

sgtitle(tl,sprintf('Max-normalized instantaneous information (sig cells, sorted by stimulus peak, N=%d)',nTotal),...
    'FontSize',10);
fprintf('Combined max-norm (stim-sorted): %d cells from %d mice\n',nTotal,nValid);

% ===== Same figure, but sorted by choice peak time =====
% Reuse allBeh/allCue/allMouse, just re-sort by choice peak
% Reconstruct with choice sorting (significant cells only)
allBeh2=[]; allCue2=[]; allMouse2=[]; allPeakCh2=[];
for i=1:nValid
    r=resAll{validIdx(i)};
    ti=ismember(r.TimeVec,tTrain);
    sigBehTr = any(r.EncPvl(:,ti) < 0.05, 2);
    sigCueTr = any(r.EncPvc(:,ti) < 0.05, 2);
    sigBoth = sigBehTr & sigCueTr;
    [~,pkC]=max(r.MiBehNorm(:,ti),[],2,'omitnan');
    validC = ~isnan(pkC) & sigBoth;
    allBeh2=[allBeh2; r.MiBehNorm(validC,:)];
    allCue2=[allCue2; r.MiCueNorm(validC,:)];
    allMouse2=[allMouse2; repmat(string(r.Mouse),sum(validC),1)];
    allPeakCh2=[allPeakCh2; tTrain(pkC(validC))];
end
[~, so2]=sort(allPeakCh2,'descend');
allBeh2=allBeh2(so2,:); allCue2=allCue2(so2,:); allMouse2=allMouse2(so2);

nTotal2=size(allBeh2,1);
fComb2 = figure('Name','Max-norm Info Combined By Choice','Color','w',...
    'Position',[150 150 900 600]);
tl2=tiledlayout(fComb2,1,2,'TileSpacing','compact','Padding','compact');

ax1=nexttile;
imagesc(ax1,tVec,1:nTotal2,allBeh2);
colormap(ax1,iBlueBlackRedCmap()); caxis(ax1,[0 1]);
cb=colorbar(ax1); cb.Label.String='Norm. info';
xlabel(ax1,'Time (s)'); ylabel(ax1,'Cell #');
title(ax1,sprintf('Choice (sig cells, N=%d)',nTotal2),'FontSize',9,'FontWeight','normal');
xline(ax1,0,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5); xline(ax1,1,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
ax1.FontSize=8; box(ax1,'off');
mouseList2=unique(allMouse2,'stable'); cumC=0;
for iM=1:numel(mouseList2)
    nThis=sum(allMouse2==mouseList2(iM)); cumC=cumC+nThis;
    if cumC<nTotal2; yline(ax1,cumC+0.5,':','Color',[0.3 0.3 0.3],'LineWidth',0.3); end
end

ax2=nexttile;
imagesc(ax2,tVec,1:nTotal2,allCue2);
colormap(ax2,iBlueBlackRedCmap()); caxis(ax2,[0 1]);
cb=colorbar(ax2); cb.Label.String='Norm. info';
xlabel(ax2,'Time (s)');
title(ax2,sprintf('Stimulus (sig cells, N=%d)',nTotal2),'FontSize',9,'FontWeight','normal');
xline(ax2,0,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5); xline(ax2,1,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
ax2.FontSize=8; box(ax2,'off'); ylim(ax2,ylim(ax1));
cumC=0;
for iM=1:numel(mouseList2)
    nThis=sum(allMouse2==mouseList2(iM)); cumC=cumC+nThis;
    if cumC<nTotal2; yline(ax2,cumC+0.5,':','Color',[0.3 0.3 0.3],'LineWidth',0.3); end
end
sgtitle(tl2,sprintf('Max-normalized instantaneous information (sig cells, sorted by choice peak, N=%d)',nTotal2),'FontSize',10);
fprintf('Combined max-norm (choice-sorted): %d cells from %d mice\n',nTotal2,nValid);

% ===== Combined norm-MI heatmap (-1 to 1s), sorted by 0-1s peak time =====
% Peak finding from 0-1s (8 time points × 2 conditions = 16 values).
% Primary = time of max across all 16. Secondary = other condition's max time.
% ===== Combined norm-MI heatmap (original: GLM p<0.05, either sig) =====
allNBeh = []; allNCue = []; allMouse3 = [];
allPkPrim = []; allPkSec = []; allPkFromChoice = [];

for i=1:nValid
    r=resAll{validIdx(i)};
    ti=ismember(r.TimeVec,tTrain);
    tVals = r.TimeVec(ti);
    sigEither = any(r.EncPvl(:,ti) < 0.05, 2) | any(r.EncPvc(:,ti) < 0.05, 2);
    if ~any(sigEither); continue; end
    
    nBfull = r.MiBehNorm(sigEither, :);
    nCfull = r.MiCueNorm(sigEither, :);
    nBtr = r.MiBehNorm(sigEither, ti);
    nCtr = r.MiCueNorm(sigEither, ti);
    nSig = size(nBtr, 1);
    
    allNBeh = [allNBeh; nBfull];
    allNCue = [allNCue; nCfull];
    allMouse3 = [allMouse3; repmat(string(r.Mouse), nSig, 1)];
    
    for iC = 1:nSig
        [maxB, idxB] = max(nBtr(iC,:));
        [maxC, idxC] = max(nCtr(iC,:));
        tB = tVals(idxB); tC = tVals(idxC);
        if maxB > maxC
            allPkPrim = [allPkPrim; tB];
            allPkSec  = [allPkSec; tC];
            allPkFromChoice = [allPkFromChoice; true];
        else
            allPkPrim = [allPkPrim; tC];
            allPkSec  = [allPkSec; tB];
            allPkFromChoice = [allPkFromChoice; false];
        end
    end
end

nChoicePrim = sum(allPkFromChoice);
nStimPrim = sum(~allPkFromChoice);
fprintf('  Combined MI: choice-primary=%d/%d (%.1f%%), stimulus-primary=%d/%d (%.1f%%)\n', ...
    nChoicePrim, numel(allPkFromChoice), nChoicePrim/numel(allPkFromChoice)*100, ...
    nStimPrim, numel(allPkFromChoice), nStimPrim/numel(allPkFromChoice)*100);

% Sort by primary time then secondary time (both as real time values)
[~, so3] = sortrows([allPkPrim, allPkSec]);
allNBeh = allNBeh(so3, :);
allNCue = allNCue(so3, :);
allMouse3 = allMouse3(so3);
nT3 = size(allNBeh, 1);
combMat = [allNBeh, allNCue];
tFull = xs(tIdxFull);

fCmb = figure('Name','Combined norm-MI heatmap','Color','w',...
    'Position',[100 100 900 600]);
ax=axes(fCmb);
imagesc(ax, 1:32, 1:nT3, combMat);
colormap(ax, iBlueBlackRedCmap()); caxis(ax,[0 1]);
cb=colorbar(ax); cb.Label.String='Norm. MI';
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Cell #');
title(ax,sprintf('Max-norm MI: choice vs stimulus (N=%d, sorted by 0-1s peak)',nT3),...
    'FontSize',9,'FontWeight','normal');
ax.XTick=1:2:32; ax.XTickLabel=string(round(tFull(1:2:end),2)); ax.FontSize=7; box(ax,'off');
xline(ax,16.5,'-','Color',[0.3 0.3 0.3],'LineWidth',1);
text(ax,8,nT3*1.03,'Choice','HorizontalAlignment','center','FontSize',8);
text(ax,24,nT3*1.03,'Stimulus','HorizontalAlignment','center','FontSize',8);
fprintf('Combined norm-MI heatmap: %d cells, sorted by 0-1s peak time\n',nT3);

% ===== Raw MI (non-normalized) heatmaps =====
% Same cell selection (sigEither) & sorting as the norm-MI combined figure,
% but display RAW MI values (bits) instead of max-normalized.
allRBeh = []; allRCue = []; allRMouse = []; allRPk = []; allRPkSec = [];
for i=1:nValid
    r=resAll{validIdx(i)};
    ti=ismember(r.TimeVec,tTrain);
    tVals = r.TimeVec(ti);
    sigEither = any(r.EncPvl(:,ti) < 0.05, 2) | any(r.EncPvc(:,ti) < 0.05, 2);
    if ~any(sigEither); continue; end
    rbFull = r.MiBehRaw(sigEither, :);
    rcFull = r.MiCueRaw(sigEither, :);
    rbTr = r.MiBehRaw(sigEither, ti);
    rcTr = r.MiCueRaw(sigEither, ti);
    nSig = size(rbTr, 1);
    allRBeh = [allRBeh; rbFull];
    allRCue = [allRCue; rcFull];
    allRMouse = [allRMouse; repmat(string(r.Mouse), nSig, 1)];
    for iC = 1:nSig
        [mB, iB] = max(rbTr(iC,:));
        [mC, iC2] = max(rcTr(iC,:));
        if mB > mC
            allRPk = [allRPk; tVals(iB)];
            allRPkSec = [allRPkSec; tVals(iC2)];
        else
            allRPk = [allRPk; tVals(iC2)];
            allRPkSec = [allRPkSec; tVals(iB)];
        end
    end
end
[~, soR] = sortrows([allRPk, allRPkSec]);
allRBeh = allRBeh(soR, :);
allRCue = allRCue(soR, :);
allRMouse = allRMouse(soR);
nRaw = size(allRBeh, 1);
maxRaw = max([allRBeh(:); allRCue(:)], [], 'omitnan');
if maxRaw <= 0; maxRaw = 0.05; end

% Combined raw MI heatmap
fRawCmb = figure('Name','Combined raw MI heatmap','Color','w',...
    'Position',[100 100 900 600]);
ax=axes(fRawCmb);
imagesc(ax, 1:32, 1:nRaw, [allRBeh, allRCue]);
colormap(ax, iBlueBlackRedCmap()); caxis(ax,[0 maxRaw]);
cb=colorbar(ax); cb.Label.String='MI (bits)';
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Cell #');
title(ax,sprintf('Raw MI: choice vs stimulus (N=%d, max=%.4f bits)',nRaw,maxRaw),...
    'FontSize',9,'FontWeight','normal');
ax.XTick=1:2:32; ax.XTickLabel=string(round(tFull(1:2:end),2)); ax.FontSize=7; box(ax,'off');
xline(ax,16.5,'-','Color',[0.3 0.3 0.3],'LineWidth',1);
text(ax,8,nRaw*1.03,'Choice','HorizontalAlignment','center','FontSize',8);
text(ax,24,nRaw*1.03,'Stimulus','HorizontalAlignment','center','FontSize',8);
fprintf('Combined raw MI heatmap: %d cells, max=%.4f bits\n',nRaw,maxRaw);

% Raw MI: choice (choice-sig cells only)
allRC = []; allRMC = []; allRPC = [];
for i=1:nValid
    r=resAll{validIdx(i)};
    ti=ismember(r.TimeVec,tTrain);
    sigC = any(r.EncPvl(:,ti) < 0.05, 2);
    [~,pk]=max(r.MiBehRaw(:,ti),[],2,'omitnan');
    vc = ~isnan(pk) & sigC;
    allRC = [allRC; r.MiBehRaw(vc,:)];
    allRMC = [allRMC; repmat(string(r.Mouse),sum(vc),1)];
    allRPC = [allRPC; tTrain(pk(vc))];
end
[~,soRC]=sort(allRPC,'descend');
allRC=allRC(soRC,:); allRMC=allRMC(soRC);
nRC=size(allRC,1);

% Raw MI: stimulus (stim-sig cells only)
allRS = []; allRMS = []; allRPS = [];
for i=1:nValid
    r=resAll{validIdx(i)};
    ti=ismember(r.TimeVec,tTrain);
    sigS = any(r.EncPvc(:,ti) < 0.05, 2);
    [~,pk]=max(r.MiCueRaw(:,ti),[],2,'omitnan');
    vc = ~isnan(pk) & sigS;
    allRS = [allRS; r.MiCueRaw(vc,:)];
    allRMS = [allRMS; repmat(string(r.Mouse),sum(vc),1)];
    allRPS = [allRPS; tTrain(pk(vc))];
end
[~,soRS]=sort(allRPS,'descend');
allRS=allRS(soRS,:); allRMS=allRMS(soRS);
nRS=size(allRS,1);

% Shared color scale for choice & stimulus (aligned color bars)
maxRC = max(allRC(:),[],'omitnan'); if maxRC<=0; maxRC=0.05; end
maxRS = max(allRS(:),[],'omitnan'); if maxRS<=0; maxRS=0.05; end
maxShared = max(maxRC, maxRS);

fRawC = figure('Name','Raw MI choice','Color','w','Position',[100 100 500 600]);
axC=axes(fRawC);
imagesc(axC,tVec,1:nRC,allRC);
colormap(axC,iBlueBlackRedCmap()); caxis(axC,[0 maxShared]);
cb=colorbar(axC); cb.Label.String='MI (bits)';
xlabel(axC,'Time (s)'); ylabel(axC,'Cell #');
title(axC,sprintf('Raw MI: choice (choice-sig cells, N=%d, max=%.4f)',nRC,maxShared),...
    'FontSize',9,'FontWeight','normal');
xline(axC,0,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
xline(axC,1,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
axC.FontSize=8; box(axC,'off');
fprintf('Raw MI choice: %d cells (shared max=%.4f)\n',nRC,maxShared);

fRawS = figure('Name','Raw MI stimulus','Color','w','Position',[100 100 500 600]);
axS=axes(fRawS);
imagesc(axS,tVec,1:nRS,allRS);
colormap(axS,iBlueBlackRedCmap()); caxis(axS,[0 maxShared]);
cb=colorbar(axS); cb.Label.String='MI (bits)';
xlabel(axS,'Time (s)'); ylabel(axS,'Cell #');
title(axS,sprintf('Raw MI: stimulus (stim-sig cells, N=%d, max=%.4f)',nRS,maxShared),...
    'FontSize',9,'FontWeight','normal');
xline(axS,0,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
xline(axS,1,'--','Color',[0.7 0.7 0.7],'LineWidth',0.5);
axS.FontSize=8; box(axS,'off');
fprintf('Raw MI stimulus: %d cells (shared max=%.4f)\n',nRS,maxShared);

% ===== Fig.2h: Encoding weights choice =====
fEc = figure('Name','Enc weights choice','Color','w',...
    'Position',[50 50 nCols*300 nRows*350]);
tl=tiledlayout(fEc,nRows,nCols,'TileSpacing','compact','Padding','compact');
for i=1:nValid
    r=resAll{validIdx(i)}; ax=nexttile;
    ti=ismember(r.TimeVec,tTrain);
    % Sort by MI peak time
    [~,pk]=max(r.MiBehNorm(:,ti),[],2,'omitnan'); [~,so]=sort(pk,'descend');
    imagesc(ax,r.TimeVec,1:r.NCells,r.EncBeh(so,:));
    colormap(ax,iRedBlueCmap());
    ma=max(abs(r.EncBeh(:)),[],'omitnan'); caxis(ax,[-1 1]*max(0.1,ma));
    colorbar(ax); xlabel(ax,'Time (s)'); ylabel(ax,'Cell #');
    title(ax,sprintf('%s: choice (n=%d)',r.Mouse,r.NCells),'FontSize',8,'FontWeight','normal');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.5);
    xline(ax,1,'--','Color',[0.5 0.5 0.5],'LineWidth',0.5);
    ax.FontSize=7; box(ax,'off');
end
sgtitle(tl,'Encoding weights: choice (sorted by MI peak)','FontSize',9);

% ===== Fig.2h: Encoding weights stimulus =====
fEs = figure('Name','Enc weights stimulus','Color','w',...
    'Position',[50 50 nCols*300 nRows*350]);
tl=tiledlayout(fEs,nRows,nCols,'TileSpacing','compact','Padding','compact');
for i=1:nValid
    r=resAll{validIdx(i)}; ax=nexttile;
    ti=ismember(r.TimeVec,tTrain);
    [~,pk]=max(r.MiCueNorm(:,ti),[],2,'omitnan'); [~,so]=sort(pk,'descend');
    imagesc(ax,r.TimeVec,1:r.NCells,r.EncCue(so,:));
    colormap(ax,iRedBlueCmap());
    ma=max(abs(r.EncCue(:)),[],'omitnan'); caxis(ax,[-1 1]*max(0.1,ma));
    colorbar(ax); xlabel(ax,'Time (s)'); ylabel(ax,'Cell #');
    title(ax,sprintf('%s: stimulus (n=%d)',r.Mouse,r.NCells),'FontSize',8,'FontWeight','normal');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.5);
    xline(ax,1,'--','Color',[0.5 0.5 0.5],'LineWidth',0.5);
    ax.FontSize=7; box(ax,'off');
end
sgtitle(tl,'Encoding weights: stimulus (sorted by MI peak)','FontSize',9);

% ===== Summary bar =====
fSum = figure('Name','Summary sig cells','Color','w','Position',[150 150 500 300]);
ax=axes(fSum); hold(ax,'on');
fracB=nan(nValid,1); fracC=nan(nValid,1);
for i=1:nValid
    r=resAll{validIdx(i)};
    fracB(i)=sum(any(r.EncPvl<0.05,2))/r.NCells;
    fracC(i)=sum(any(r.EncPvc<0.05,2))/r.NCells;
end
xM=1:nValid;
bar(ax,xM-0.15,fracB*100,0.3,'FaceColor',[0.85 0.33 0.10],'EdgeColor','none');
bar(ax,xM+0.15,fracC*100,0.3,'FaceColor',[0 0.45 0.74],'EdgeColor','none');
hold(ax,'off');
xlabel(ax,'Mouse'); ylabel(ax,'Significant cells (%)');
title(ax,'Fraction of cells with significant encoding (p<0.05)','FontSize',9,'FontWeight','normal');
ax.XTick=xM; ax.XTickLabel=arrayfun(@(i)resAll{validIdx(i)}.Mouse,1:nValid,'uni',0);
ax.XTickLabelRotation=45; ax.FontSize=7; box(ax,'off');
legend(ax,{'Choice','Stimulus'},'Location','northeast','Box','off');
fprintf('\nDone. %d/%d mice.\n',nValid,nMice);


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
% Discretize activity into nBins equal-count bins
[~, edges] = histcounts(act, nBins);
if numel(unique(edges)) < 2; mi = 0; return; end
actBin = discretize(act, edges);
if all(isnan(actBin)); mi = 0; return; end

% Joint histogram: P(activity_bin, label)
joint = zeros(nBins, 2);
for i = 1:n
    if ~isnan(actBin(i))
        joint(actBin(i), label(i)+1) = joint(actBin(i), label(i)+1) + 1;
    end
end
% Remove empty bins
joint(sum(joint,2)==0, :) = [];

% Normalize to probabilities
pJoint = joint / sum(joint(:));  % P(x,y)
px = sum(pJoint, 2);              % P(x)
py = sum(pJoint, 1);              % P(y)

% Raw MI
miRaw = 0;
for i = 1:size(pJoint,1)
    for j = 1:2
        if pJoint(i,j) > 0 && px(i) > 0 && py(j) > 0
            miRaw = miRaw + pJoint(i,j) * log2(pJoint(i,j) / (px(i) * py(j)));
        end
    end
end

% Panzeri-Treves bias correction (Panzeri & Treves 1996, eq. 13)
% bias = (1/(2*N*ln(2))) * (M_x-1)*(M_y-1)
% where M_x = number of non-empty bins, M_y = 2
Mx = size(pJoint, 1);
My = 2;
bias = (Mx - 1) * (My - 1) / (2 * n * log(2));
mi = max(0, miRaw - bias);
end


function [X, yBeh, yCue] = iBuildTrialMatrixWithCue(rawTbl, cellUIDs)
sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), double(rawTbl.Cue), ...
    'VariableNames', {'CellUID','TrialUID','Behavior','Cue'});
sigCell = cell(size(sig,1), 1);
for i = 1:size(sig,1); sigCell{i} = sig(i,:); end
ntsTbl.Signal = sigCell;
keepRows = ismember(ntsTbl.CellUID, cellUIDs);
ntsTbl = ntsTbl(keepRows, :);
if isempty(ntsTbl); X=[]; yBeh=[]; yCue=[]; return; end
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
        if ci > 0; X(iT, ci, :) = rows.Signal{iR}; end
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

function mi = iConfusionMi(yTrue, yPred)
% Compute mutual information (bits) from predicted vs true labels
valid = ~isnan(yTrue) & ~isnan(yPred);
if sum(valid) < 4 || numel(unique(yTrue(valid))) < 2 || numel(unique(yPred(valid))) < 2
    mi = 0; return;
end
cm = confusionmat(yTrue(valid), yPred(valid));
cm = cm + 0.5; % pseudo-count to avoid log(0)
joint = cm / sum(cm(:)); % P(y_true, y_pred)
py = sum(joint, 2);      % P(y_true)
pp = sum(joint, 1);      % P(y_pred)
expected = py * pp;
mi = sum(joint(:) .* log2(joint(:) ./ expected(:)), 'omitnan');
mi = max(0, mi); % MI is always ≥ 0
end

function map = iRedBlueCmap()
n = 64; half = round(n/2);
r = [linspace(0,1,half)'; ones(half,1)];
g = [linspace(0,1,half)'; linspace(1,0,half)'];
b = [ones(half,1); linspace(1,0,half)'];
map = [r,g,b];
end

function map = iBlueBlackRedCmap()
n = 128;
map = [linspace(0.05,0.95,n)', linspace(0.05,0.40,n)', linspace(0.35,0.05,n)'];
map = map .^ 0.7;
map = max(0, min(1, map));
end

function map = iHotCmap()
% White-hot colormap for non-negative MI display (white=0, red=max)
n = 128;
map = [linspace(1,0.8,n)', linspace(1,0.2,n)', linspace(1,0,n)'];
map = max(0, min(1, map));
end