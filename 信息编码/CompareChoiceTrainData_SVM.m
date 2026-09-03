%% CompareChoiceTrainData_SVM.m
% CONTROL experiment: same pipeline as CompareChoiceTrainData.m (4 training
% configs x [MI, Stage1 P(hit), Stage2 Transfer P(hit)]) but the decoder is a
% NON-LINEAR RBF-SVM instead of GLM naive-Gaussian.
% Purpose: test whether the choice-decoder conclusions are robust to decoder:
%   (1) no pre-stimulus info, (2) stimulus-evoked, (3) in-task decodable,
%   (4) Transfer weak (miss detectable, hit not).
% P(hit) = 1./(1+exp(-score)); score>0 -> hit. Run via MATLAB MCP.
% NOTE: RBF-SVM predict scores are compressed near 0, so raw sigmoid tendency
% is attenuated; use MI / balacc (scale-free) for fair comparison with GLM.

%% 0. Setup (identical to CompareChoiceTrainData.m)
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
fprintf('=== CHOICE (hit/miss) training-data comparison: NON-LINEAR RBF-SVM ===\n');
fprintf('Time window: %.2f-%.2f s (%d pts)\n', tVec(1), tVec(end), nTfull);

%% 1. Blocks with phase
Blk = DS.Blocks;
Blk.Design = string(Blk.Design);
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

trainAW  = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
trainAWperf = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)) & ...
    Blk.Performance > 0.5);
trainAWlow = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)) & ...
    Blk.Performance < 0.6);
testLW   = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ...
    ~ismember(Blk.Phase, ["Recall","Final"]));
fprintf('Train AW=%d; AW(Perf>0.5)=%d; AW(Perf<0.6)=%d; Transfer LW=%d; Calib blocks=%d\n', ...
    numel(trainAW), numel(trainAWperf), numel(trainAWlow), numel(testLW), numel(calBlocks));

%% 2. Per-mouse data (identical to CompareChoiceTrainData.m)
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n===== Data loading =====\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    tr1 = table();
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
        tr1 = [tr1; t]; %#ok<AGROW>
    end
    tr2 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr2 = t; end
    end
    tr3 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAWperf)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr3 = t; end
    end
    tr4 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAWlow)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr4 = t; end
    end
    testTbl = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        testTbl = r{1}; testTbl = testTbl(ismember(uint64(testTbl.BlockUID), uint64(testLW)), :);
    end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(tr1) || ~okT(tr2) || ~okT(tr3) || ~okT(testTbl); continue; end
    tr1 = tr1(~isnan(tr1.Behavior), :);
    tr2 = tr2(~isnan(tr2.Behavior), :);
    tr3 = tr3(~isnan(tr3.Behavior), :);
    if ~isempty(tr4) && ismember('Behavior', tr4.Properties.VariableNames)
        tr4 = tr4(~isnan(tr4.Behavior), :);
    end
    testTbl = testTbl(~isnan(testTbl.Behavior), :);
    if isempty(tr1) || isempty(tr2) || isempty(tr3) || isempty(testTbl); continue; end
    teA = table(); teL = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        teA = r{1}; teA = teA(ismember(uint64(teA.BlockUID), uint64(calBlocks)), :);
    end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        teL = r{1}; teL = teL(ismember(uint64(teL.BlockUID), uint64(calBlocks)), :);
    end
    if ~isempty(teA) && ismember('Behavior', teA.Properties.VariableNames); teA = teA(~isnan(teA.Behavior), :); end
    if ~isempty(teL) && ismember('Behavior', teL.Properties.VariableNames); teL = teL(~isnan(teL.Behavior), :); end
    cellUIDs = uint64(unique([tr1.CellUID; tr2.CellUID; tr3.CellUID; testTbl.CellUID]));
    if ~isempty(tr4); cellUIDs = uint64(unique([cellUIDs; tr4.CellUID])); end
    if okT(teA); cellUIDs = uint64(unique([cellUIDs; teA.CellUID])); end
    if okT(teL); cellUIDs = uint64(unique([cellUIDs; teL.CellUID])); end
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    Xtr1 = iBuildTrialMatrix(tr1, cellUIDs, tIdxFull);
    Xtr2 = iBuildTrialMatrix(tr2, cellUIDs, tIdxFull);
    Xtr3 = iBuildTrialMatrix(tr3, cellUIDs, tIdxFull);
    Xte  = iBuildTrialMatrix(testTbl, cellUIDs, tIdxFull);
    if okT(teA); XteA = iBuildTrialMatrix(teA, cellUIDs, tIdxFull); behTeA = iTrialLabel(teA, 'Behavior');
    else; XteA = []; behTeA = []; end
    if okT(teL); XteL = iBuildTrialMatrix(teL, cellUIDs, tIdxFull); behTeL = iTrialLabel(teL, 'Behavior');
    else; XteL = []; behTeL = []; end
    if isempty(tr4)
        Xtr4 = []; behTr4 = [];
    else
        Xtr4 = iBuildTrialMatrix(tr4, cellUIDs, tIdxFull);
        behTr4 = iTrialLabel(tr4, 'Behavior');
    end
    if isempty(Xtr1) || isempty(Xtr2) || isempty(Xtr3) || isempty(Xte); continue; end
    if doBaselineNorm
        bI = find(tVec < 0);
        Xtr1 = iBaselineNorm(Xtr1, bI); Xtr2 = iBaselineNorm(Xtr2, bI); Xtr3 = iBaselineNorm(Xtr3, bI);
        Xte  = iBaselineNorm(Xte, bI);
        if ~isempty(Xtr4); Xtr4 = iBaselineNorm(Xtr4, bI); end
        if ~isempty(XteA); XteA = iBaselineNorm(XteA, bI); end
        if ~isempty(XteL); XteL = iBaselineNorm(XteL, bI); end
    end
    behTr1 = iTrialLabel(tr1, 'Behavior');
    behTr2 = iTrialLabel(tr2, 'Behavior');
    behTr3 = iTrialLabel(tr3, 'Behavior');
    behTe  = iTrialLabel(testTbl, 'Behavior');
    typ1 = iTrialLabel(tr1, 'Type');
    if sum(behTr1==1) < 3 || sum(behTr1==0) < 3; continue; end
    if sum(behTr2==1) < 3 || sum(behTr2==0) < 3; continue; end
    if sum(behTr3==1) < 3 || sum(behTr3==0) < 3; continue; end
    nUsed = nUsed + 1;
    res = struct('Mouse',m,'NCells',nCell, ...
        'Xtr1',Xtr1,'Xtr2',Xtr2,'Xtr3',Xtr3,'Xtr4',Xtr4,'Xte',Xte, ...
        'XteA',XteA,'XteL',XteL, ...
        'behTr1',behTr1,'behTr2',behTr2,'behTr3',behTr3,'behTr4',behTr4, ...
        'behTe',behTe,'behTeA',behTeA,'behTeL',behTeL,'typ1',typ1);
    resAll{nUsed} = res;
    h4 = 0; m4 = 0;
    if ~isempty(behTr4); h4 = sum(behTr4==1); m4 = sum(behTr4==0); end
    fprintf('  %-9s cells=%3d  S1=%d(h%d/m%d) S2=%d(h%d/m%d) S3=%d(h%d/m%d) S4=%d(h%d/m%d) test=%d\n', ...
        m, nCell, size(Xtr1,1), sum(behTr1==1), sum(behTr1==0), ...
        size(Xtr2,1), sum(behTr2==1), sum(behTr2==0), ...
        size(Xtr3,1), sum(behTr3==1), sum(behTr3==0), ...
        size(Xtr4,1), h4, m4, size(Xte,1));
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 3. Decode with RBF-SVM (train CV MI + tendency + balacc on held-out tests)
cfgNames = {'AudioWater+AudioOnly+LightOnly','AudioWater','AudioWater (Perf>0.5)','AudioWater (Perf<0.6)'};
miCV = nan(nValid, 4, nTfull);      % (mouse, config, time) train CV MI (hit/miss)
pSt1 = nan(nValid, 4, 2, nTfull);    % Stage1: [hit, miss] P(hit) (sigmoid, scale-compressed)
pSt2 = nan(nValid, 4, 2, nTfull);    % Stage2: [hit, miss] P(hit)
% scale-free: Stage2 balacc (Transfer, all light): [hit->pred hit, miss->pred miss]
balSt2 = nan(nValid, 4, 2, nTfull);
% scale-free: Stage1 OOF balacc [hit, miss]
balSt1 = nan(nValid, 4, 2, nTfull);
for i = 1:nValid
    r = resAll{i};
    for cfg = 1:4
        if cfg==1; Xtr = r.Xtr1; beh = r.behTr1; typ = r.typ1;
        elseif cfg==2; Xtr = r.Xtr2; beh = r.behTr2; typ = [];
        elseif cfg==3; Xtr = r.Xtr3; beh = r.behTr3; typ = [];
        else; Xtr = r.Xtr4; beh = r.behTr4; typ = []; end
        if isempty(Xtr); continue; end
        okB = ~isnan(beh);
        if sum(beh(okB)==1) < 3 || sum(beh(okB)==0) < 3; continue; end
        for iT = 1:nTfull
            Ftr = Xtr(okB,:,iT); yb = beh(okB);
            [sOOF, pOOF] = iCvPredictSVM(Ftr, yb, K);   % Stage1 OOF
            miCV(i,cfg,iT) = iMIFromLabels(pOOF, yb);
            phO = 1./(1+exp(-sOOF));
            pSt1(i,cfg,1,iT) = mean(phO(yb==1));
            pSt1(i,cfg,2,iT) = mean(phO(yb==0));
            balSt1(i,cfg,1,iT) = mean(pOOF(yb==1)==1);
            balSt1(i,cfg,2,iT) = mean(pOOF(yb==0)==0);
            bal = iBalanceTrain(yb);
            [sT,~] = iSvmDecode(Ftr(bal,:), yb(bal), r.Xte(:,:,iT));
            phT = 1./(1+exp(-sT));   % P(hit) on Transfer (scale-compressed)
            pSt2(i,cfg,1,iT) = mean(phT(r.behTe==1));
            pSt2(i,cfg,2,iT) = mean(phT(r.behTe==0));
            pT = double(sT>0);       % 1=hit
            balSt2(i,cfg,1,iT) = mean(pT(r.behTe==1)==1);   % hit trial predicted hit
            balSt2(i,cfg,2,iT) = mean(pT(r.behTe==0)==0);   % miss trial predicted miss
        end
    end
end

%% 4. Console summary (scale-free metrics; 3 core conclusions)
fprintf('\n===== SVM CHOICE results: 3 core conclusions =====\n');
for cfg = 1:3
    v = mean(miCV(:,cfg,:),1,'omitnan');
    [pk, pi_] = max(v);
    fprintf('cfg%d: MI peak=%.3f@%.2f | pre MI=%.3f | Stage1 balacc hit=%.3f miss=%.3f\n', ...
        cfg, pk, tVec(pi_), mean(v(tVec<0)), ...
        mean(balSt1(:,cfg,1,16),'omitnan'), mean(balSt1(:,cfg,2,16),'omitnan'));
    fprintf('      Stage2 balacc (Transfer): hit=%.3f miss=%.3f (chance 0.5)\n', ...
        mean(balSt2(:,cfg,1,16),'omitnan'), mean(balSt2(:,cfg,2,16),'omitnan'));
end
fprintf('NOTE: raw sigmoid tendency is scale-compressed for SVM; use balacc/MI.\n');

%% 5. Figure 3x3 (SVM) - use balacc for Stage panels for fair comparison
f = figure('Name','Choice (hit/miss) decoder: RBF-SVM control','Color','w','Position',[40 40 1320 940]);
subCol  = {'MI (train CV)','Stage1 prob-tendency','Stage2 prob-tendency'};
stC = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
axGrid = gobjects(3,3);
for cfg = 1:3
    for c = 1:3
        ax = subplot(3,3,(cfg-1)*3+c); hold(ax,'on');
        axGrid(cfg,c) = ax;
        if c==1
            v = squeeze(miCV(:,cfg,:));
            mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
            iShadedError(ax, tVec, mn, se, [0 0 0], 1.6, 'rbf-svm');
            ylabel(ax,'MI (bits)');
        else
            if c==2; P = balSt1; stN = {'hit','miss'}; else; P = balSt2; stN = {'light hit','light miss'}; end
            for s = 1:2
                v = squeeze(P(:,cfg,s,:));
                if all(isnan(v(:))); continue; end
                mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
            end
            iSigStars(ax, tVec, squeeze(P(:,cfg,1,:)), squeeze(P(:,cfg,2,:)), 0.02, [0.85 0.33 0.10]);
            yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
            ylabel(ax,'Balanced accuracy (0-1)');
        end
        xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        if cfg==3; xlabel(ax,'Time from stimulus (s)'); end
        if c>1
            lg = legend(ax,'Location','northwest','Box','off','FontSize',7);
            p = lg.Position; p(2) = p(2) + 0.03; lg.Position = p;
        end
        box(ax,'off'); ax.FontSize = 7;
    end
end
ym1 = 0.5;
for cfg=1:3; set(axGrid(cfg,1),'YLim',[0 ym1]); end
for cfg=1:3
    for c=2:3; set(axGrid(cfg,c),'YLim',[0 1]); end
end
for c = 1:3
    text(axGrid(1,c), 0.5, 1.16, subCol{c}, 'Units','normalized', 'HorizontalAlignment','center', 'FontWeight','bold','FontSize',10);
end
for cfg = 1:3
    text(axGrid(cfg,1), -0.34, 0.5, cfgNames{cfg}, 'Units','normalized', 'Rotation',90, 'HorizontalAlignment','center', 'FontWeight','bold','FontSize',10);
end

fprintf('\nDone. SVM CHOICE control complete.\n');

% auto-save
outDir = fullfile(thisDir, '_figcheck');
if ~exist(outDir, 'dir'); mkdir(outDir); end
exportgraphics(f, fullfile(outDir, 'Choice__hit_miss__decoder__SVM_control.png'), 'Resolution', 200);
fprintf('saved SVM choice control figure to _figcheck.\n');

% ==================== Local Functions ====================

function [sOOF, pOOF] = iCvPredictSVM(F, y, K)
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
    [sOOF(te), pOOF(te)] = iSvmDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:));
end
end

function bal = iBalanceTrain(y)
idx1 = find(y==1); idx0 = find(y==0);
n = min(numel(idx1), numel(idx0));
idx1 = idx1(randperm(numel(idx1), n));
idx0 = idx0(randperm(numel(idx0), n));
bal = [idx1; idx0];
end

function [score, pred] = iSvmDecode(Ftr, ytr, Fte)
yy = 2*ytr - 1;   % miss=0->-1, hit=1->+1
mdl = fitcsvm(Ftr, yy, 'KernelFunction','rbf', 'KernelScale','auto', ...
    'BoxConstraint', 1, 'Standardize', true);
[~, sc2] = predict(mdl, Fte);
score = sc2(:, 2);      % score of +1 (hit) class; >0 -> hit
pred = double(score > 0);
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

function iSigStars(ax, tVec, v1, v2, yoff, col)
hold(ax,'on');
m1 = mean(v1,1,'omitnan'); m2 = mean(v2,1,'omitnan');
for iT = 1:numel(tVec)
    a = v1(:,iT); b = v2(:,iT);
    ok = ~isnan(a) & ~isnan(b);
    if sum(ok) < 4; continue; end
    [~, pp] = ttest(a(ok), b(ok));
    if pp < 0.05
        y = max(m1(iT), m2(iT)) + yoff;
        text(ax, tVec(iT), y, '*', 'Color', col, 'FontSize', 9, ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','HandleVisibility','off');
    end
end
end

function iShadedError(ax, x, mn, se, col, lw, dn)
x = x(:)'; mn = mn(:)'; se = se(:)';
ok = ~isnan(mn) & ~isnan(se);
x = x(ok); mn = mn(ok); se = se(ok);
if isempty(x); return; end
hold(ax,'on');
fill(ax, [x fliplr(x)], [mn+se fliplr(mn-se)], col, ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mn, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', dn);
end
