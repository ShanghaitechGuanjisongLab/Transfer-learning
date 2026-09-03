%% Cfg2Figure_15_4line.m
% 1.5s 时间窗、Stage1 四线版（2x2）：行1 = Cue cfg2 (AudioOnly+LightOnly)，行2 = Choice cfg2 (AudioWater)
% 列 = [Stage1 prob-tendency, Stage2 prob-tendency]（无 MI 列）
%   Cue Stage1 四线：audio only / light only（OOF）+ audio hit / audio miss（held-out Naive AudioWater）
%   Choice Stage1 四线：audio hit / audio miss（OOF）+ audio only / light only（held-out 校准 AudioOnly/LightOnly）
%   Stage2 = light hit / light miss（Transfer held-out）。时间窗 [-0.957, +1.468] s（20 点），1s 参考线。
prjRoot = fileparts(fileparts(mfilename('fullpath')));
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
rng(42);
doBaselineNorm = true;
met = 2; K = 5;

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1.5));
tVec = xs(tIdxFull);
nTfull = numel(tVec);
fprintf('Time window %.3f..%.3f s (%d pts)\n', tVec(1), tVec(end), nTfull);

% ---------- Blocks ----------
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
naiveAW   = Blk.BlockUID(Blk.Design == "AudioWater" & Blk.Phase == "Naive");
testLW    = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ~ismember(Blk.Phase, ["Recall","Final"]));
miceAll = unique(DT.Mouse);

%% 1. CUE cfg2 (AO+LO): Stage1 4 线 + Stage2
resCue = cell(numel(miceAll),1); nCue = 0;
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    trA = table(); trL = table(); teTrans = table(); teNaive = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :); if ~isempty(t); t.Cue = zeros(height(t),1); t.Type = ones(height(t),1); trA=t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :); if ~isempty(t); t.Cue = ones(height(t),1); t.Type = 2*ones(height(t),1); trL=t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teTrans = r{1}; teTrans = teTrans(ismember(uint64(teTrans.BlockUID), uint64(testLW)), :); end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Naive'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teNaive = r{1}; teNaive = teNaive(ismember(uint64(teNaive.BlockUID), uint64(naiveAW)), :); end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(trA) || ~okT(trL) || ~okT(teTrans) || ~okT(teNaive); continue; end
    trA = trA(~isnan(trA.Behavior), :); trL = trL(~isnan(trL.Behavior), :);
    teTrans = teTrans(~isnan(teTrans.Behavior), :); teNaive = teNaive(~isnan(teNaive.Behavior), :);
    s2 = [trA; trL];
    y2 = iTrialLabel(s2, 'Cue'); typ2 = iTrialLabel(s2, 'Type');
    if sum(y2==0)<3 || sum(y2==1)<3; continue; end
    cellUIDs = uint64(unique([s2.CellUID; teTrans.CellUID; teNaive.CellUID]));
    if numel(cellUIDs) < 10; continue; end
    X2 = iBuildTrialMatrix(s2, cellUIDs, tIdxFull);
    Xt = iBuildTrialMatrix(teTrans, cellUIDs, tIdxFull);
    Xn = iBuildTrialMatrix(teNaive, cellUIDs, tIdxFull);
    if isempty(X2) || isempty(Xt) || isempty(Xn); continue; end
    if doBaselineNorm
        bI = find(tVec < 0);
        X2 = iBaselineNorm(X2, bI); Xt = iBaselineNorm(Xt, bI); Xn = iBaselineNorm(Xn, bI);
    end
    nCue = nCue + 1;
    resCue{nCue} = struct('X2',X2,'Xt',Xt,'Xn',Xn,'y2',y2,'typ2',typ2, ...
        'behT',iTrialLabel(teTrans,'Behavior'),'behN',iTrialLabel(teNaive,'Behavior'));
end
resCue = resCue(1:nCue);
fprintf('Cue cfg2 valid mice: %d\n', nCue);
pSt1Cue = nan(nCue, 4, nTfull);   % [AO, LO, AH, AM]
pSt2Cue = nan(nCue, 2, nTfull);   % [light hit, light miss]
for i = 1:nCue
    r = resCue{i};
    for iT = 1:nTfull
        Ftr = r.X2(:,:,iT);
        [sOOF, ~] = iCvPredict(Ftr, r.y2, K, met);
        pAOOF = 1./(1+exp(sOOF));
        pSt1Cue(i,1,iT) = mean(pAOOF(r.typ2==1));   % audio only
        pSt1Cue(i,2,iT) = mean(pAOOF(r.typ2==2));   % light only
        bal = iBalanceTrain(r.y2);
        [sN,~] = iGlmDecode(Ftr(bal,:), r.y2(bal), r.Xn(:,:,iT));
        [sT,~] = iGlmDecode(Ftr(bal,:), r.y2(bal), r.Xt(:,:,iT));
        pAN = 1./(1+exp(sN)); pAT = 1./(1+exp(sT));
        pSt1Cue(i,3,iT) = mean(pAN(r.behN==1));     % audio hit
        pSt1Cue(i,4,iT) = mean(pAN(r.behN==0));     % audio miss
        pSt2Cue(i,1,iT) = mean(pAT(r.behT==1));     % light hit
        pSt2Cue(i,2,iT) = mean(pAT(r.behT==0));     % light miss
    end
end

%% 2. CHOICE cfg2 (AudioWater): Stage1 4 线 + Stage2
resCh = cell(numel(miceAll),1); nCh = 0;
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    tr2 = table(); testTbl = table(); teA = table(); teL = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :); if ~isempty(t); tr2 = t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); testTbl = r{1}; testTbl = testTbl(ismember(uint64(testTbl.BlockUID), uint64(testLW)), :); end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teA = r{1}; teA = teA(ismember(uint64(teA.BlockUID), uint64(calBlocks)), :); end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teL = r{1}; teL = teL(ismember(uint64(teL.BlockUID), uint64(calBlocks)), :); end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(tr2) || ~okT(testTbl) || ~okT(teA) || ~okT(teL); continue; end
    tr2 = tr2(~isnan(tr2.Behavior), :); testTbl = testTbl(~isnan(testTbl.Behavior), :);
    teA = teA(~isnan(teA.Behavior), :); teL = teL(~isnan(teL.Behavior), :);
    if isempty(tr2) || isempty(testTbl); continue; end
    cellUIDs = uint64(unique([tr2.CellUID; testTbl.CellUID; teA.CellUID; teL.CellUID]));
    if numel(cellUIDs) < 10; continue; end
    Xtr2 = iBuildTrialMatrix(tr2, cellUIDs, tIdxFull);
    Xte  = iBuildTrialMatrix(testTbl, cellUIDs, tIdxFull);
    XteA = iBuildTrialMatrix(teA, cellUIDs, tIdxFull);
    XteL = iBuildTrialMatrix(teL, cellUIDs, tIdxFull);
    if isempty(Xtr2) || isempty(Xte); continue; end
    if doBaselineNorm
        bI = find(tVec < 0);
        Xtr2 = iBaselineNorm(Xtr2, bI); Xte = iBaselineNorm(Xte, bI);
        XteA = iBaselineNorm(XteA, bI); XteL = iBaselineNorm(XteL, bI);
    end
    behTr2 = iTrialLabel(tr2, 'Behavior'); behTe = iTrialLabel(testTbl, 'Behavior');
    if sum(behTr2==1) < 3 || sum(behTr2==0) < 3; continue; end
    nCh = nCh + 1;
    resCh{nCh} = struct('Xtr2',Xtr2,'Xte',Xte,'XteA',XteA,'XteL',XteL, ...
        'behTr2',behTr2,'behTe',behTe);
end
resCh = resCh(1:nCh);
fprintf('Choice cfg2 valid mice: %d\n', nCh);
pCalCh = nan(nCh, 2, nTfull);   % [audio only, light only] held-out calib
pSt1Ch = nan(nCh, 2, nTfull);   % [audio hit, audio miss] OOF
pSt2Ch = nan(nCh, 2, nTfull);   % [light hit, light miss]
for i = 1:nCh
    r = resCh{i};
    okB = ~isnan(r.behTr2);
    for iT = 1:nTfull
        Ftr = r.Xtr2(okB,:,iT); yb = r.behTr2(okB);
        [sOOF, ~] = iCvPredict(Ftr, yb, K, met);
        phO = 1./(1+exp(-sOOF));
        pSt1Ch(i,1,iT) = mean(phO(yb==1));   % audio hit
        pSt1Ch(i,2,iT) = mean(phO(yb==0));   % audio miss
        bal = iBalanceTrain(yb);
        [sA,~] = iGlmDecode(Ftr(bal,:), yb(bal), r.XteA(:,:,iT));
        [sL,~] = iGlmDecode(Ftr(bal,:), yb(bal), r.XteL(:,:,iT));
        [sT,~] = iGlmDecode(Ftr(bal,:), yb(bal), r.Xte(:,:,iT));
        pCalCh(i,1,iT) = mean(1./(1+exp(-sA)));   % audio only
        pCalCh(i,2,iT) = mean(1./(1+exp(-sL)));   % light only
        phT = 1./(1+exp(-sT));
        pSt2Ch(i,1,iT) = mean(phT(r.behTe==1));  % light hit
        pSt2Ch(i,2,iT) = mean(phT(r.behTe==0));  % light miss
    end
end

%% 3. Figure 2x2
f = figure('Name','Cfg2 1.5s 4-line: Cue vs Choice','Color','w','Position',[60 60 900 640]);
axGrid = gobjects(2,2);
stN1 = {'audio only','light only','audio hit','audio miss'};
stC1 = {[0.30 0.60 0.20], [0.70 0.30 0.70], [0.85 0.33 0.10], [0.10 0.45 0.70]};
stN2 = {'light hit','light miss'};
stC2 = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
for r = 1:2
    for c = 1:2
        ax = subplot(2,2,(r-1)*2+c); hold(ax,'on');
        axGrid(r,c) = ax;
        if c == 1   % Stage1 (4 线)
            if r == 1   % Cue
                P = pSt1Cue;
                for s = 1:4
                    v = squeeze(P(:,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC1{s}, 1.4, stN1{s});
                end
                iSigStars(ax, tVec, squeeze(P(:,1,:)), squeeze(P(:,2,:)), 0.02, stC1{1});
                iSigStars(ax, tVec, squeeze(P(:,3,:)), squeeze(P(:,4,:)), 0.02, stC1{3});
                ylbl = 'P(audio) tendency (0=light,1=audio)';
            else   % Choice
                for s = 1:2
                    v = squeeze(pCalCh(:,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC1{s}, 1.4, stN1{s});
                end
                for s = 1:2
                    v = squeeze(pSt1Ch(:,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC1{s+2}, 1.4, stN1{s+2});
                end
                iSigStars(ax, tVec, squeeze(pCalCh(:,1,:)), squeeze(pCalCh(:,2,:)), 0.02, stC1{1});
                iSigStars(ax, tVec, squeeze(pSt1Ch(:,1,:)), squeeze(pSt1Ch(:,2,:)), 0.02, stC1{3});
                ylbl = 'P tendency (0=miss,1=hit)';
            end
            ylabel(ax, ylbl); set(ax,'YLim',[0 1]);
        else   % Stage2
            if r==1; P = pSt2Cue; ylbl = 'P(audio) tendency (0=light,1=audio)';
            else; P = pSt2Ch; ylbl = 'P tendency (0=miss,1=hit)'; end
            for s = 1:2
                v = squeeze(P(:,s,:));
                if all(isnan(v(:))); continue; end
                mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                iShadedError(ax, tVec, mn, se, stC2{s}, 1.4, stN2{s});
            end
            iSigStars(ax, tVec, squeeze(P(:,1,:)), squeeze(P(:,2,:)), 0.02, stC2{1});
            ylabel(ax, ylbl); set(ax,'YLim',[0 1]);
        end
        yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        xline(ax,1,'-.','Color',[0.35 0.35 0.35],'LineWidth',0.8,'HandleVisibility','off');
        if r==2; xlabel(ax,'Time from stimulus (s)'); end
        legend(ax,'Location','northwest','Box','off','FontSize',8);
        box(ax,'off'); ax.FontSize = 7;
    end
end
text(axGrid(1,1), 0.5, 1.16, 'Stage1 prob-tendency', 'Units','normalized','HorizontalAlignment','center','FontWeight','bold','FontSize',10);
text(axGrid(1,2), 0.5, 1.16, 'Stage2 prob-tendency', 'Units','normalized','HorizontalAlignment','center','FontWeight','bold','FontSize',10);
text(axGrid(1,1), -0.3, 0.5, 'Cue (AudioOnly+LightOnly)', 'Units','normalized','Rotation',90,'HorizontalAlignment','center','FontWeight','bold','FontSize',9);
text(axGrid(2,1), -0.3, 0.5, 'Choice (AudioWater)', 'Units','normalized','Rotation',90,'HorizontalAlignment','center','FontWeight','bold','FontSize',9);

figDir = fullfile(prjRoot, '信息编码', '_figcheck');
if ~exist(figDir,'dir'); mkdir(figDir); end
outfile = fullfile(figDir, 'Cfg2_Compare_CueChoice_simple_15_4line.png');
exportgraphics(f, outfile, 'Resolution', 200);
fprintf('Saved: %s\n', outfile);
save(fullfile(figDir, 'Cfg2_15_4line_data.mat'), 'pSt1Cue','pCalCh','pSt1Ch','pSt2Cue','pSt2Ch','tVec','nCue','nCh');
fprintf('Saved data: Cfg2_15_4line_data.mat\n');

% ==================== Local Functions ====================
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
