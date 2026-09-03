%% CompareCueTrainData.m
% Integrated 3x3 comparison of the three CUE-decoder training-data variants.
%   Row 1: Pre-Transfer (mixed)     = DecodePreTransfer_Cue.m
%   Row 2: Calibration (all trials) = DecodeCalibCue_TaskContexts.m
%   Row 3: Calibration (miss only)  = DecodePureCue_CalibMiss.m
% Columns (test pipeline is FIXED; only training data varies):
%   Col 1: MI      = 5-fold CV decode audio vs light on the TRAINING set (cue separability)
%   Col 2: Stage1  = P(audio) on TRAINING SET (incl. Naive AW trials; NOT strict held-out)
%   Col 3: Stage2  = P(audio) on held-out Transfer LightWater (TRUE held-out)
% Method: GLM naive-Gaussian by default (set met=1 for linear).
% P(audio) = 1 - sigmoid(score); score>0 -> light.
% Data: UniExp.AudioLightBaseline; no Recall. Run via MATLAB MCP.

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
met = 2;   % 1=linear, 2=glm
K = 5;

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);
fprintf('=== Integrated CUE training-data comparison ===\n');
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

trainAW   = Blk.BlockUID(Blk.Design == "AudioWater" & (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
naiveAW   = Blk.BlockUID(Blk.Design == "AudioWater" & Blk.Phase == "Naive");
testLW    = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ~ismember(Blk.Phase, ["Recall","Final"]));
fprintf('Train AW=%d; Naive AW=%d; Transfer LW=%d; Calib blocks=%d\n', ...
    numel(trainAW), numel(naiveAW), numel(testLW), numel(calBlocks));

%% 2. Per-mouse data
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n===== Data loading =====\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    trAW = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); t.Type = zeros(height(t),1); trAW = t; end
    end
    trA = table();   % AudioOnly calib (cue 0)
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); t.Type = ones(height(t),1); trA = t; end
    end
    trL = table();   % LightOnly calib (cue 1)
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :);
        if ~isempty(t); t.Cue = ones(height(t),1); t.Type = 2*ones(height(t),1); trL = t; end
    end
    teNaive = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Naive'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teNaive = r{1}; teNaive = teNaive(ismember(uint64(teNaive.BlockUID), uint64(naiveAW)), :); end
    teTrans = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teTrans = r{1}; teTrans = teTrans(ismember(uint64(teTrans.BlockUID), uint64(testLW)), :); end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(trAW) || ~okT(trA) || ~okT(trL) || ~okT(teNaive) || ~okT(teTrans); continue; end
    trAW = trAW(~isnan(trAW.Behavior), :); trA = trA(~isnan(trA.Behavior), :); trL = trL(~isnan(trL.Behavior), :);
    teNaive = teNaive(~isnan(teNaive.Behavior), :); teTrans = teTrans(~isnan(teTrans.Behavior), :);
    trAm = trA(trA.Behavior==0, :);
    trLm = trL(trL.Behavior==0, :);
    s1 = [trAW; trA; trL];
    s2 = [trA; trL];
    s3 = [trAm; trLm];   % MISS only
    typ1 = iTrialLabel(s1, 'Type');   % per unique trial: 0=AW,1=AudioOnly,2=LightOnly
    typ2 = iTrialLabel(s2, 'Type');
    typ3 = iTrialLabel(s3, 'Type');
    yc = @(x) iTrialLabel(x, 'Cue');
    if sum(yc(s1)==0)<3 || sum(yc(s1)==1)<3; continue; end
    if sum(yc(s2)==0)<3 || sum(yc(s2)==1)<3; continue; end
    if sum(yc(s3)==0)<3 || sum(yc(s3)==1)<3; continue; end
    cellUIDs = uint64(unique([s1.CellUID; s2.CellUID; s3.CellUID; teNaive.CellUID; teTrans.CellUID]));
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    X1 = iBuildTrialMatrix(s1, cellUIDs, tIdxFull);
    X2 = iBuildTrialMatrix(s2, cellUIDs, tIdxFull);
    X3 = iBuildTrialMatrix(s3, cellUIDs, tIdxFull);
    Xn = iBuildTrialMatrix(teNaive, cellUIDs, tIdxFull);
    Xt = iBuildTrialMatrix(teTrans, cellUIDs, tIdxFull);
    if isempty(X1) || isempty(X2) || isempty(X3) || isempty(Xn) || isempty(Xt); continue; end
    if doBaselineNorm
        bI = find(tVec < 0);
        X1 = iBaselineNorm(X1, bI); X2 = iBaselineNorm(X2, bI); X3 = iBaselineNorm(X3, bI);
        Xn = iBaselineNorm(Xn, bI); Xt = iBaselineNorm(Xt, bI);
    end
    nUsed = nUsed + 1;
    res = struct('Mouse',m,'NCells',nCell, ...
        'X1',X1,'X2',X2,'X3',X3,'Xn',Xn,'Xt',Xt, ...
        'y1',yc(s1),'y2',yc(s2),'y3',yc(s3), ...
        'typ1',typ1,'typ2',typ2,'typ3',typ3, ...
        'behN',iTrialLabel(teNaive,'Behavior'),'behT',iTrialLabel(teTrans,'Behavior'));
    resAll{nUsed} = res;
    fprintf('  %-9s cells=%3d  S1=%d(h%d/l%d) S2=%d(h%d/l%d) S3=%d(h%d/l%d)  naive=%d trans=%d\n', ...
        m, nCell, size(X1,1), sum(res.y1==0), sum(res.y1==1), ...
        size(X2,1), sum(res.y2==0), sum(res.y2==1), ...
        size(X3,1), sum(res.y3==0), sum(res.y3==1), size(Xn,1), size(Xt,1));
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 3. Decode: train CV MI + tendency on held-out tests
cfgNames = {'AudioWater+AudioOnly+LightOnly','AudioOnly+LightOnly','AudioOnly+LightOnly (miss)'};
miCV = nan(nValid, 3, nTfull);       % (mouse, config, time) train CV MI
pSt1 = nan(nValid, 3, 4, nTfull);     % Stage1: [audio only, light only, audio hit, audio miss]
pSt2 = nan(nValid, 3, 2, nTfull);     % Stage2: [light hit, light miss]
for i = 1:nValid
    r = resAll{i};
    for cfg = 1:3
        if cfg==1; Xtr = r.X1; ytr = r.y1; typ = r.typ1;
        elseif cfg==2; Xtr = r.X2; ytr = r.y2; typ = r.typ2;
        else; Xtr = r.X3; ytr = r.y3; typ = r.typ3; end
        for iT = 1:nTfull
            Ftr = Xtr(:,:,iT);
            [sOOF, pOOF] = iCvPredict(Ftr, ytr, K, met);       % train CV (out-of-fold)
            miCV(i,cfg,iT) = iMIFromLabels(pOOF, ytr);
            pAOOF = 1./(1+exp(sOOF));   % P(audio) out-of-fold
            % Stage1 controls: audio-only / light-only (training subsets, OOF)
            pSt1(i,cfg,1,iT) = mean(pAOOF(typ==1));
            pSt1(i,cfg,2,iT) = mean(pAOOF(typ==2));
            bal = iBalanceTrain(ytr);
            if met==1
                [sN,~] = iLinDecode(Ftr(bal,:), ytr(bal), r.Xn(:,:,iT));
                [sT,~] = iLinDecode(Ftr(bal,:), ytr(bal), r.Xt(:,:,iT));
            else
                [sN,~] = iGlmDecode(Ftr(bal,:), ytr(bal), r.Xn(:,:,iT));
                [sT,~] = iGlmDecode(Ftr(bal,:), ytr(bal), r.Xt(:,:,iT));
            end
            pAN = 1./(1+exp(sN));   % P(audio) = 1 - sigmoid(score)
            pAT = 1./(1+exp(sT));
            % Stage1: audio hit/miss (held-out Naive AW)
            pSt1(i,cfg,3,iT) = mean(pAN(r.behN==1));
            pSt1(i,cfg,4,iT) = mean(pAN(r.behN==0));
            % Stage2: light hit/miss (held-out Transfer LW)
            pSt2(i,cfg,1,iT) = mean(pAT(r.behT==1));
            pSt2(i,cfg,2,iT) = mean(pAT(r.behT==0));
        end
    end
end

%% 4. Figure 3x3
f = figure('Name','Cue decoder: training-data comparison (3 scripts)','Color','w','Position',[40 40 1320 940]);
subCol  = {'MI (train CV)','Stage1 prob-tendency (train-set, incl. Naive)','Stage2 prob-tendency (Transfer held-out)'};
st1N = {'audio only','light only','audio hit','audio miss'};
st1C = {[0.30 0.60 0.20], [0.70 0.30 0.70], [0.85 0.33 0.10], [0.10 0.45 0.70]};
st2N = {'light hit','light miss'};
st2C = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
axGrid = gobjects(3,3);
for cfg = 1:3
    for c = 1:3
        ax = subplot(3,3,(cfg-1)*3+c); hold(ax,'on');
        axGrid(cfg,c) = ax;
        if c==1
            v = squeeze(miCV(:,cfg,:));
            mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
            iShadedError(ax, tVec, mn, se, [0 0 0], 1.6, 'glm');
            ylabel(ax,'MI (bits)');
        else
            if c==2; P = pSt1; L = st1N; CC = st1C; else; P = pSt2; L = st2N; CC = st2C; end
            for s = 1:size(P,3)
                v = squeeze(P(:,cfg,s,:));
                if all(isnan(v(:))); continue; end
                mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                iShadedError(ax, tVec, mn, se, CC{s}, 1.4, L{s});
            end
            % significance stars: paired t-test p<0.05 per time point
            if c==2
                iSigStars(ax, tVec, squeeze(P(:,cfg,1,:)), squeeze(P(:,cfg,2,:)), 0.02, [0.30 0.60 0.20]); % audio only vs light only
                iSigStars(ax, tVec, squeeze(P(:,cfg,3,:)), squeeze(P(:,cfg,4,:)), 0.02, [0.85 0.33 0.10]); % audio hit vs audio miss
            else
                iSigStars(ax, tVec, squeeze(P(:,cfg,1,:)), squeeze(P(:,cfg,2,:)), 0.02, [0 0 0]); % light hit vs light miss
            end
            yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
            ylabel(ax,'P(audio) tendency (0=light,1=audio)');
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
% align y-axes (MI shared across both decoder figures: [0 0.5])
ym1 = 0.5;
for cfg=1:3; set(axGrid(cfg,1),'YLim',[0 ym1]); end
for cfg=1:3
    for c=2:3; set(axGrid(cfg,c),'YLim',[0 1]); end
end
% column headers
for c = 1:3
    text(axGrid(1,c), 0.5, 1.16, subCol{c}, 'Units','normalized', 'HorizontalAlignment','center', 'FontWeight','bold','FontSize',10);
end
% row labels (rotated, left of first column)
for cfg = 1:3
    text(axGrid(cfg,1), -0.34, 0.5, cfgNames{cfg}, 'Units','normalized', 'Rotation',90, 'HorizontalAlignment','center', 'FontWeight','bold','FontSize',10);
end

exportgraphics(f, fullfile(prjRoot, '信息编码', '_figcheck', 'Cue_decoder__training-data-comparison__3_scripts_.png'), 'Resolution', 200);
fprintf('Saved: %s\n', fullfile(prjRoot, '信息编码', '_figcheck', 'Cue_decoder__training-data-comparison__3_scripts_.png'));
save(fullfile(prjRoot, '信息编码', '_figcheck', 'Cue_cfg2data.mat'), 'miCV','pSt1','pSt2','tVec');
fprintf('\nDone. Integrated cue training-data comparison complete.\n');

% ==================== Local Functions ====================

function iSigStars(ax, tVec, v1, v2, yoff, col)
% Mark time points where paired t-test (per-mouse) p<0.05, with '*'
% placed just above the max of the two group means.
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
% Mean line + SEM shaded band.
x = x(:)'; mn = mn(:)'; se = se(:)';
ok = ~isnan(mn) & ~isnan(se);
x = x(ok); mn = mn(ok); se = se(ok);
if isempty(x); return; end
hold(ax,'on');
fill(ax, [x fliplr(x)], [mn+se fliplr(mn-se)], col, ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mn, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', dn);
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
