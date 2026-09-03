%% DecodePreTransfer_ChoiceCuePerf.m
% Three task-variable decoders (choice / cue / performance) trained on
% PRE-TRANSFER data (Naive + Learned + unannotated-phase AudioWater, plus
% AudioOnly / LightOnly trials from LAu/LAuW blocks; NO Recall), then tested
% on Stage-1 (pre-Transfer) and Stage-2 (Transfer LightWater) trial subsets.
%
% For each decoder, per time point, per test subset, report:
%   1. decoded mutual information (bits) between decoder output and label
%   2. balanced accuracy
%   3. mean decoder output score
% Decoder methods: (A) linear readout, (B) GLM naive-Gaussian (Bayes).
% Control figures show cross-variable decoding should be near chance.
%
% Reference: Runyan et al. 2017 (Nature), decoded-information framework.

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

fprintf('=== Pre-Transfer task-variable decoders ===\n');
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

% Training: AudioWater blocks with phase Naive/Learned or unannotated (NO Recall)
trainAW  = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
% Training: LAu/LAuW blocks (Naive phase) provide LightOnly/AudioOnly trials
trainMix = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]));
% Test stage2: LightWater Transfer
testLW   = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
fprintf('Train blocks: AW=%d, LAu/LAuW=%d; Test blocks (Transfer LW)=%d\n', ...
    numel(trainAW), numel(trainMix), numel(testLW));

%% 2. Per-mouse trial data
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n========== Data loading ==========\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    allTbl = table();
    % --- pre-Transfer AudioWater (train) ---
    try
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            t = r{1};
            t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
            if ~isempty(t); t.Cue = zeros(height(t),1); allTbl = [allTbl; t]; end %#ok<AGROW>
        end
    catch
    end
    % --- pre-Transfer AudioOnly (LAu/LAuW, train cue1) ---
    try
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            t = r{1};
            if ~isempty(t); t.Cue = zeros(height(t),1); allTbl = [allTbl; t]; end %#ok<AGROW>
        end
    catch
    end
    % --- pre-Transfer LightOnly (LAu/LAuW, train cue2) ---
    try
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r) && ~isempty(r{1})
            t = r{1};
            if ~isempty(t); t.Cue = ones(height(t),1); allTbl = [allTbl; t]; end %#ok<AGROW>
        end
    catch
    end
    if isempty(allTbl) || ~ismember('TrialSignal', string(allTbl.Properties.VariableNames))
        continue;
    end
    % block performance
    bu = uint64(allTbl.BlockUID);
    perf = arrayfun(@(b) Blk.Performance(find(Blk.BlockUID == b, 1)), bu);
    allTbl.Perf = perf;
    allTbl = allTbl(~isnan(allTbl.Behavior) & ~isnan(allTbl.Perf), :);
    if isempty(allTbl); continue; end
    % --- Transfer LightWater (test stage2) ---
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

    % ---- build trial matrices (features per time point) ----
    cellUIDs = uint64(unique([allTbl.CellUID; testTbl.CellUID]));
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    Xtr = iBuildTrialMatrix(allTbl, cellUIDs, tIdxFull);   % nTr x nCell x nTfull
    Xte = iBuildTrialMatrix(testTbl, cellUIDs, tIdxFull);
    if isempty(Xtr) || isempty(Xte); continue; end
    nTr = size(Xtr,1); nTe = size(Xte,1);

    % labels (train)
    yChoiceTr = iTrialLabel(allTbl, 'Behavior');
    yCueTr    = iTrialLabel(allTbl, 'Cue');
    yPerfTr   = iTrialLabel(allTbl, 'Perf');
    % perf binarization threshold = median over training block performance
    perfThr = median(yPerfTr);
    yPerfTrBin = double(yPerfTr > perfThr);
    % labels (test)
    yChoiceTe = iTrialLabel(testTbl, 'Behavior');
    yCueTe    = iTrialLabel(testTbl, 'Cue');
    yPerfTe   = iTrialLabel(testTbl, 'Perf');
    yPerfTeBin = double(yPerfTe > perfThr);

    % subset tags for stage1 (train) and stage2 (test)
    [sub1, sub1Name] = iTagStage1(allTbl);   % per-trial subset name
    [sub2, sub2Name] = iTagStage2(testTbl);

    nUsed = nUsed + 1;
    res = struct();
    res.Mouse = m;
    res.CellUIDs = cellUIDs;
    res.NCells = nCell;
    res.Xtr = Xtr; res.Xte = Xte;
    res.yChoiceTr = yChoiceTr; res.yCueTr = yCueTr; res.yPerfTr = yPerfTrBin;
    res.yChoiceTe = yChoiceTe; res.yCueTe = yCueTe; res.yPerfTe = yPerfTeBin;
    res.sub1 = sub1; res.sub1Name = sub1Name;
    res.sub2 = sub2; res.sub2Name = sub2Name;
    resAll{nUsed} = res;
    fprintf('  %s: %d cells, train %d trials (H%d/M%d, A%d/L%d), test %d trials (H%d/M%d)\n', ...
        m, nCell, nTr, sum(yChoiceTr==1), sum(yChoiceTr==0), ...
        sum(yCueTr==0), sum(yCueTr==1), nTe, sum(yChoiceTe==1), sum(yChoiceTe==0));
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 3. Per-time-point decoders + metrics (pooled across mice)
% Variables: 1=choice, 2=cue, 3=performance
varNames = {'Choice','Cue','Performance'};
methods  = {'linear','glm'};
nS1 = numel(resAll{1}.sub1Name);
nS2 = numel(resAll{1}.sub2Name);
K = 5;   % CV folds for stage1

% pooled two-class metrics: (mouse, var, method, stage[1=S1,2=S2], time)
miPool  = nan(nValid, 3, 2, 2, nTfull);
balPool = nan(nValid, 3, 2, 2, nTfull);
% per-subset mean decoder output: (mouse, var, method, subset, stage, time)
outSub  = nan(nValid, 3, 2, nS1+nS2, 2, nTfull);

for i = 1:nValid
    r = resAll{i};
    Xtr = r.Xtr; Xte = r.Xte;
    yTr = {r.yChoiceTr, r.yCueTr, r.yPerfTr};
    yTe = {r.yChoiceTe, r.yCueTe, r.yPerfTe};
    for v = 1:3
        yt = yTr{v};
        okTr = ~isnan(yt);
        if sum(yt==1) < 3 || sum(yt==0) < 3; continue; end
        yte = yTe{v};
        for iT = 1:nTfull
            Ftr = Xtr(:, :, iT); Fte = Xte(:, :, iT);
            FtrOK = Ftr(okTr,:); ytOK = yt(okTr);
            for met = 1:2   % 1=linear, 2=glm
                % stage1: 5-fold CV -> out-of-fold predictions/scores
                [sOOF, pOOF] = iCvPredict(FtrOK, ytOK, K, met);
                % stage2: full-model prediction on Transfer (balanced training)
                balTr = iBalanceTrain(ytOK);
                if met == 1
                    [sTe, pTe] = iLinDecode(FtrOK(balTr,:), ytOK(balTr), Fte);
                else
                    [sTe, pTe] = iGlmDecode(FtrOK(balTr,:), ytOK(balTr), Fte);
                end
                % pooled two-class metrics (stage1 from out-of-fold)
                miPool(i,v,met,1,iT)  = iMIFromLabels(pOOF, ytOK);
                balPool(i,v,met,1,iT) = iBalAcc(pOOF, ytOK);
                miPool(i,v,met,2,iT)  = iMIFromLabels(pTe, yte);
                balPool(i,v,met,2,iT) = iBalAcc(pTe, yte);
                % stage1 per-subset output (out-of-fold scores)
                subOK = r.sub1(okTr);
                for s = 1:nS1
                    idx = subOK == s;
                    if sum(idx) < 2; continue; end
                    outSub(i,v,met,s,1,iT) = mean(sOOF(idx));
                end
                % stage2 per-subset output (Transfer scores)
                for s = 1:nS2
                    idx = r.sub2 == s;
                    if sum(idx) < 2; continue; end
                    outSub(i,v,met,nS1+s,2,iT) = mean(sTe(idx));
                end
            end
        end
    end
end

%% 4. Figures
% figure A: pooled two-class decoded MI + balanced accuracy (per stage)
for v = 1:3
    for met = 1:2
        f = figure('Name', sprintf('Decode %s (%s) - pooled info', varNames{v}, methods{met}), ...
            'Color','w', 'Position',[80 60 1000 640]);
        tl = tiledlayout(f, 2, 1, 'TileSpacing','compact','Padding','compact');
        for q = 1:2   % 1=MI, 2=balanced acc
            ax = nexttile(tl); hold(ax,'on');
            for st = 1:2
                if q == 1; vals = squeeze(miPool(:,v,met,st,:)); else; vals = squeeze(balPool(:,v,met,st,:)); end
                mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
                ls = '-'; if st==2; ls='--'; end
                errorbar(ax, tVec, mn, se, ls, 'LineWidth', 1.8, 'MarkerSize', 4, ...
                    'DisplayName', iStageName(st));
            end
            hold(ax,'off');
            xlabel(ax,'Time from stimulus (s)');
            if q==1; ylabel(ax,'Decoded MI (bits)'); else; ylabel(ax,'Balanced accuracy'); end
            title(ax, sprintf('%s decoder - %s', varNames{v}, iMetricName(q)), ...
                'FontSize',9,'FontWeight','normal');
            legend(ax,'Location','northwest','Box','off','FontSize',8);
            xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
            box(ax,'off'); ax.FontSize = 8;
        end
    end
end

% figure B: per-subset mean decoder output (control curves, solid=S1, dashed=S2)
subNamesAll = [resAll{1}.sub1Name, resAll{1}.sub2Name];
subStage = [ones(1,nS1), 2*ones(1,nS2)];
cols = [0.85 0.33 0.10; 0.10 0.45 0.70; 0.30 0.60 0.20; 0.70 0.30 0.70; ...
        0.0 0.0 0.0; 0.5 0.5 0.5; 0.85 0.33 0.10; 0.10 0.45 0.70];
for v = 1:3
    for met = 1:2
        f = figure('Name', sprintf('Decode %s (%s) - subset output', varNames{v}, methods{met}), ...
            'Color','w', 'Position',[80 60 1000 560]);
        ax = axes(f); hold(ax,'on');
        for s = 1:(nS1+nS2)
            st = 1; if s > nS1; st = 2; end
            vals = squeeze(outSub(:,v,met,s,st,:));
            if all(isnan(vals(:))); continue; end
            mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
            ls = '-'; if subStage(s)==2; ls='--'; end
            errorbar(ax, tVec, mn, se, ls, 'Color', cols(s,:), 'LineWidth', 1.6, 'MarkerSize', 3, ...
                'DisplayName', subNamesAll{s});
        end
        hold(ax,'off');
        xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoder output');
        title(ax, sprintf('%s decoder - output per subset (solid=S1, dashed=S2)', varNames{v}), ...
            'FontSize',9,'FontWeight','normal');
        legend(ax,'Location','northwest','Box','off','FontSize',7);
        xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        box(ax,'off'); ax.FontSize = 8;
    end
end

fprintf('\nDone. Pre-Transfer decoder analysis complete.\n');

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
if ~ismember(varName, string(rawTbl.Properties.VariableNames)); y=[]; return; end
tu = unique(uint64(rawTbl.TrialUID));
y = nan(numel(tu),1);
for iT = 1:numel(tu)
    v = rawTbl.(varName)(uint64(rawTbl.TrialUID)==tu(iT));
    y(iT) = mode(v);
end
end

function [tag, name] = iTagStage1(rawTbl)
% non-exclusive trial pools: 1=cue1 only, 2=cue2 only, 3=cue1 hit,
% 4=cue1 miss, 5=cue2 hit, 6=cue2 miss
c = iTrialLabel(rawTbl,'Cue'); b = iTrialLabel(rawTbl,'Behavior');
n = numel(c);
tag = zeros(n,1);
tag(c==0) = 1;   % all audio -> cue1-only pool
tag(c==1) = 2;   % all light -> cue2-only pool
for i = 1:n
    if isnan(b(i)); continue; end
    if c(i)==0 && b(i)==1; tag(i)=3; end
    if c(i)==0 && b(i)==0; tag(i)=4; end
    if c(i)==1 && b(i)==1; tag(i)=5; end
    if c(i)==1 && b(i)==0; tag(i)=6; end
end
name = {'cue1 only','cue2 only','cue1 hit','cue1 miss','cue2 hit','cue2 miss'};
end

function [tag, name] = iTagStage2(rawTbl)
% stage2 subsets: 1=cue2 hit, 2=cue2 miss
b = iTrialLabel(rawTbl,'Behavior');
tag = ones(numel(b),1);
tag(b==0) = 2;
name = {'cue2 hit','cue2 miss'};
end

function [sOOF, pOOF] = iCvPredict(F, y, K, met)
% K-fold CV within the training set with class-balanced training folds;
% returns out-of-fold scores/predictions.
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
% Down-sample the majority class to the minority count (class balancing).
idx1 = find(y==1); idx0 = find(y==0);
n = min(numel(idx1), numel(idx0));
idx1 = idx1(randperm(numel(idx1), n));
idx0 = idx0(randperm(numel(idx0), n));
bal = [idx1; idx0];
end

function nm = iStageName(st)
if st==1; nm = 'Stage1 (pre-Transfer, CV)'; else; nm = 'Stage2 (Transfer)'; end
end

function nm = iMetricName(q)
if q==1; nm = 'Decoded MI'; else; nm = 'Balanced accuracy'; end
end

function [score, pred] = iLinDecode(Ftr, ytr, Fte)
% Minimum-norm linear readout on standardized features (training set is
% already class-balanced by iBalanceTrain).
mu = mean(Ftr,1); sd = std(Ftr,0,1); sd(sd==0)=1;
Ftrs = (Ftr-mu)./sd; Ftes = (Fte-mu)./sd;
w = pinv([ones(size(Ftrs,1),1), Ftrs])*(2*ytr-1);
score = [ones(size(Ftes,1),1), Ftes]*w;
pred = double(score >= 0);
end

function [score, pred] = iGlmDecode(Ftr, ytr, Fte)
% naive-Gaussian (GLM-based) Bayes decoder: per-cell class means + pooled sd
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
% PT-corrected MI (bits) between predicted and true binary labels
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
