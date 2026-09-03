%% CompareChoiceTrainData.m
% Integrated 4x3 comparison of the four CHOICE (hit/miss) decoder training-data
% variants (same grid style as CompareCueTrainData.m).
%   Row 1: AudioWater+AudioOnly+LightOnly  = DecodePreTransfer_HitMiss.m scheme1 (allPre)
%   Row 2: AudioWater                      = scheme2 (audioOnly, main)
%   Row 3: AudioWater (Perf>0.5)           = scheme3 (high-performance blocks)
%   Row 4: AudioWater (Perf<0.6)           = scheme4 (low-performance blocks)
% Columns (test pipeline is FIXED; only training data varies):
%   Col 1: MI      = 5-fold CV decode hit/miss on the TRAINING set (Stage1)
%   Col 2: Stage1  = P(hit) by hit/miss on the training set (CV out-of-fold)
%   Col 3: Stage2  = P(hit) by hit/miss on held-out Transfer LightWater
% Method: GLM naive-Gaussian by default (set met=1 for linear).
% P(hit) = 1/(1+exp(-score)); score>0 -> hit (hit=1, miss=0).
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
fprintf('=== Integrated CHOICE (hit/miss) training-data comparison ===\n');
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

%% 2. Per-mouse data
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n===== Data loading =====\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    % --- scheme1: allPre = AudioWater(trainAW) + AudioOnly + LightOnly (no Recall) ---
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
    % --- scheme2: AudioWater (trainAW) ---
    tr2 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr2 = t; end
    end
    % --- scheme3: AudioWater (trainAWperf) ---
    tr3 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAWperf)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr3 = t; end
    end
    % --- scheme4: AudioWater (trainAWlow) ---
    tr4 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAWlow)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr4 = t; end
    end
    % --- test: Transfer LightWater (Stage2) ---
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
    % --- held-out calibration: AudioOnly / LightOnly (LAu/LAuW, no Recall/Final) ---
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
    typ1 = iTrialLabel(tr1, 'Type');   % per unique trial: 0=AW,1=AudioOnly,2=LightOnly
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

%% 3. Decode: train CV MI + tendency on held-out tests
cfgNames = {'AudioWater+AudioOnly+LightOnly','AudioWater','AudioWater (Perf>0.5)','AudioWater (Perf<0.6)'};
miCV = nan(nValid, 4, nTfull);      % (mouse, config, time) train CV MI (hit/miss)
pSt1 = nan(nValid, 4, 2, nTfull);    % Stage1: [hit, miss] P(hit)
pSt2 = nan(nValid, 4, 2, nTfull);    % Stage2: [hit, miss] P(hit)
pCal = nan(nValid, 4, 2, nTfull);    % Stage1 calib: [AudioOnly, LightOnly] choice P(hit)
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
            [sOOF, pOOF] = iCvPredict(Ftr, yb, K, met);     % train CV (out-of-fold)
            miCV(i,cfg,iT) = iMIFromLabels(pOOF, yb);
            phO = 1./(1+exp(-sOOF));    % P(hit) out-of-fold
            pSt1(i,cfg,1,iT) = mean(phO(yb==1));
            pSt1(i,cfg,2,iT) = mean(phO(yb==0));
            if cfg==1 && ~isempty(typ)
                tb = typ(okB);   % align with Ftr rows
                if sum(tb==1) >= 3; pCal(i,cfg,1,iT) = mean(phO(tb==1)); end
                if sum(tb==2) >= 3; pCal(i,cfg,2,iT) = mean(phO(tb==2)); end
            end
            bal = iBalanceTrain(yb);
            if cfg~=1 && ~isempty(r.XteA) && ~isempty(r.behTeA)
                if met==1; [sA,~] = iLinDecode(Ftr(bal,:), yb(bal), r.XteA(:,:,iT));
                else;       [sA,~] = iGlmDecode(Ftr(bal,:), yb(bal), r.XteA(:,:,iT)); end
                pCal(i,cfg,1,iT) = mean(1./(1+exp(-sA)));
            end
            if cfg~=1 && ~isempty(r.XteL) && ~isempty(r.behTeL)
                if met==1; [sL,~] = iLinDecode(Ftr(bal,:), yb(bal), r.XteL(:,:,iT));
                else;       [sL,~] = iGlmDecode(Ftr(bal,:), yb(bal), r.XteL(:,:,iT)); end
                pCal(i,cfg,2,iT) = mean(1./(1+exp(-sL)));
            end
            if met==1
                [sT,~] = iLinDecode(Ftr(bal,:), yb(bal), r.Xte(:,:,iT));
            else
                [sT,~] = iGlmDecode(Ftr(bal,:), yb(bal), r.Xte(:,:,iT));
            end
            phT = 1./(1+exp(-sT));      % P(hit) on Transfer
            pSt2(i,cfg,1,iT) = mean(phT(r.behTe==1));
            pSt2(i,cfg,2,iT) = mean(phT(r.behTe==0));
        end
    end
end

%% 4. Figure 3x3 (scheme4 AudioWater (Perf<0.6) computed but NOT shown)
f = figure('Name','Choice (hit/miss) decoder: training-data comparison','Color','w','Position',[40 40 1320 940]);
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
            iShadedError(ax, tVec, mn, se, [0 0 0], 1.6, 'glm');
            ylabel(ax,'MI (bits)');
        else
            if c==2
                P = pCal; stN = {'audio only','light only'}; stC = {[0.30 0.60 0.20], [0.70 0.30 0.70]};
                for s = 1:2
                    v = squeeze(P(:,cfg,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
                end
                iSigStars(ax, tVec, squeeze(pCal(:,cfg,1,:)), squeeze(pCal(:,cfg,2,:)), 0.02, [0.30 0.60 0.20]); % AudioOnly vs LightOnly
                P = pSt1; stN = {'audio hit','audio miss'}; stC = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
                for s = 1:2
                    v = squeeze(P(:,cfg,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
                end
                iSigStars(ax, tVec, squeeze(pSt1(:,cfg,1,:)), squeeze(pSt1(:,cfg,2,:)), 0.02, [0.85 0.33 0.10]); % audio hit vs audio miss
            else
                P = pSt2; stN = {'light hit','light miss'}; stC = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
                for s = 1:2
                    v = squeeze(P(:,cfg,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
                end
                iSigStars(ax, tVec, squeeze(pSt2(:,cfg,1,:)), squeeze(pSt2(:,cfg,2,:)), 0.02, [0 0 0]); % light hit vs light miss
            end
            yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
            ylabel(ax,'P tendency (0=miss,1=hit)');
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

exportgraphics(f, fullfile(prjRoot, '信息编码', '_figcheck', 'Choice__hit_miss__decoder__training-data-comparison.png'), 'Resolution', 200);
fprintf('Saved: %s\n', fullfile(prjRoot, '信息编码', '_figcheck', 'Choice__hit_miss__decoder__training-data-comparison.png'));
save(fullfile(prjRoot, '信息编码', '_figcheck', 'Choice_cfg2data.mat'), 'miCV','pCal','pSt1','pSt2','tVec');
fprintf('\nDone. Integrated choice training-data comparison complete.\n');

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

function bal = iBalAcc(pred, lab)
a0 = mean(pred(lab==0)==0); a1 = mean(pred(lab==1)==1);
bal = mean([a0, a1], 'omitnan');
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
