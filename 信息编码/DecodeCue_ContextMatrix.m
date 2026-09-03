%% DecodeCue_ContextMatrix.m
% Cue x context 2x2 matrix (design optimization for the "Stage2 single-cue"
% limitation). Train a cue decoder (audio vs light) on CALIBRATION data only
% (AudioOnly + LightOnly from LAu/LAuW, no Recall; cue labels explicit, no
% task-vs-calibration confound). Then evaluate on 2x2 test cells:
%   Rows  = context   : Calib (LAu/LAuW) | Task (AW/LW)
%   Cols  = stimulus  : Audio            | Light
%   Cell(1,1) = AudioOnly (CV out-of-fold)
%   Cell(1,2) = LightOnly (CV out-of-fold)
%   Cell(2,1) = Naive AudioWater (held-out)
%   Cell(2,2) = Transfer LightWater (held-out)
% Metric per cell: P(light) = sigmoid(score) time course.
% Interpretation: if the cue representation survives context, audio cells
% give P(light)<0.5 and light cells give P(light)>0.5; a task-context
% remapping would weaken/flip these directions.
% Methods: linear + glm (GLM displayed). Run via MATLAB MCP.

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
met = 2;   % 1=linear, 2=glm (figure)
K = 5;

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);
fprintf('=== Cue x context 2x2 matrix ===\n');
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

calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ...
    ~ismember(Blk.Phase, ["Recall","Final"]));
naiveAW   = Blk.BlockUID(Blk.Design == "AudioWater" & Blk.Phase == "Naive");
learnedAW = Blk.BlockUID(Blk.Design == "AudioWater" & Blk.Phase == "Learned");
transLW   = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
fprintf('Calib blocks=%d; Naive AW=%d; Learned AW=%d; Transfer LW=%d\n', ...
    numel(calBlocks), numel(naiveAW), numel(learnedAW), numel(transLW));

%% 2. Per-mouse data
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n===== Data loading =====\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    % --- training: calibration AudioOnly + LightOnly ---
    calTbl = table();
    for st = ["AudioOnly","LightOnly"]
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus',st), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if isempty(r) || isempty(r{1}); continue; end
        t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :);
        if isempty(t); continue; end
        t.Cue = zeros(height(t),1) + double(st == "LightOnly");
        calTbl = [calTbl; t]; %#ok<AGROW>
    end
    if isempty(calTbl) || ~ismember('TrialSignal', string(calTbl.Properties.VariableNames)); continue; end
    % --- held-out tests ---
    teNaive = table(); teLearned = table(); teTrans = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Naive'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teNaive = r{1}; teNaive = teNaive(ismember(uint64(teNaive.BlockUID), uint64(naiveAW)), :); end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Learned'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teLearned = r{1}; teLearned = teLearned(ismember(uint64(teLearned.BlockUID), uint64(learnedAW)), :); end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); teTrans = r{1}; teTrans = teTrans(ismember(uint64(teTrans.BlockUID), uint64(transLW)), :); end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(teNaive) || ~okT(teTrans); continue; end
    cellUIDs = uint64(unique([calTbl.CellUID; teNaive.CellUID; teTrans.CellUID]));
    if okT(teLearned); cellUIDs = uint64(unique([cellUIDs; teLearned.CellUID])); end
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    Xtr = iBuildTrialMatrix(calTbl, cellUIDs, tIdxFull);
    Xnaive = iBuildTrialMatrix(teNaive, cellUIDs, tIdxFull);
    Xtrans = iBuildTrialMatrix(teTrans, cellUIDs, tIdxFull);
    if okT(teLearned); Xlearn = iBuildTrialMatrix(teLearned, cellUIDs, tIdxFull); else; Xlearn = []; end
    if isempty(Xtr) || isempty(Xnaive) || isempty(Xtrans); continue; end
    if doBaselineNorm
        bI = find(tVec < 0);
        Xtr = iBaselineNorm(Xtr, bI); Xnaive = iBaselineNorm(Xnaive, bI); Xtrans = iBaselineNorm(Xtrans, bI);
        if ~isempty(Xlearn); Xlearn = iBaselineNorm(Xlearn, bI); end
    end
    yCueTr = iTrialLabel(calTbl, 'Cue');   % audio=0, light=1
    if sum(yCueTr==1) < 3 || sum(yCueTr==0) < 3; continue; end
    nUsed = nUsed + 1;
    res = struct('Mouse',m,'NCells',nCell, ...
        'Xtr',Xtr,'Xnaive',Xnaive,'Xlearn',Xlearn,'Xtrans',Xtrans,'yCueTr',yCueTr);
    resAll{nUsed} = res;
    fprintf('  %-9s cells=%3d  calib=%d(Au%d/Li%d)  naiveAW=%d  learnAW=%d  transLW=%d\n', ...
        m, nCell, size(Xtr,1), sum(yCueTr==0), sum(yCueTr==1), ...
        size(Xnaive,1), size(Xlearn,1), size(Xtrans,1));
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 3. Decode per cell: P(light) time course
% cells: 1=Calib/Audio(OOF), 2=Calib/Light(OOF), 3=Task/Naive AW, 4=Task/Transfer LW
% (Learned AW computed as an extra task-audio cell but shown in console only)
pCell = nan(nValid, 2, 4, nTfull);   % (mouse, method, cell, time) P(light)
pLear = nan(nValid, 2, nTfull);      % task-audio learned (console only)
for i = 1:nValid
    r = resAll{i};
    Xtr = r.Xtr; yt = r.yCueTr;
    okTr = ~isnan(yt);
    for iT = 1:nTfull
        Ftr = Xtr(okTr,:,iT); ytOK = yt(okTr);
        % Calib cells: 5-fold CV out-of-fold
        [sOOF, ~] = iCvPredict(Ftr, ytOK, K, met);
        pOOFL = 1./(1+exp(-sOOF));   % P(light) OOF
        pCell(i,met,1,iT) = mean(pOOFL(ytOK==0));   % AudioOnly cell
        pCell(i,met,2,iT) = mean(pOOFL(ytOK==1));   % LightOnly cell
        % Task cells: train on balanced calib, apply held-out
        bal = iBalanceTrain(ytOK);
        if met==1
            [sN,~] = iLinDecode(Ftr(bal,:), ytOK(bal), r.Xnaive(:,:,iT));
            [sT,~] = iLinDecode(Ftr(bal,:), ytOK(bal), r.Xtrans(:,:,iT));
            if ~isempty(r.Xlearn); [sL,~] = iLinDecode(Ftr(bal,:), ytOK(bal), r.Xlearn(:,:,iT)); end
        else
            [sN,~] = iGlmDecode(Ftr(bal,:), ytOK(bal), r.Xnaive(:,:,iT));
            [sT,~] = iGlmDecode(Ftr(bal,:), ytOK(bal), r.Xtrans(:,:,iT));
            if ~isempty(r.Xlearn); [sL,~] = iGlmDecode(Ftr(bal,:), ytOK(bal), r.Xlearn(:,:,iT)); end
        end
        pCell(i,met,3,iT) = mean(1./(1+exp(-sN)));   % Naive AW
        pCell(i,met,4,iT) = mean(1./(1+exp(-sT)));   % Transfer LW
        if ~isempty(r.Xlearn); pLear(i,met,iT) = mean(1./(1+exp(-sL))); end
    end
end

%% 4. Console summary (full-window mean P(light) per cell)
cellNames = {'Calib/AudioOnly','Calib/LightOnly','Task/NaiveAW','Task/TransferLW','Task/LearnedAW'};
fprintf('\n=== Full-window mean P(light) (expect audio<0.5, light>0.5) ===\n');
for c = 1:4
    vv = squeeze(nanmean(pCell(:,met,c,:),4));   % (mouse,) mean over time
    v = mean(vv,'omitnan');
    [~,pp] = ttest(vv - 0.5);
    fprintf('  %-18s P(light)=%.3f | ttest vs 0.5 p=%.4f | mice=%d\n', cellNames{c}, v, pp, sum(~isnan(vv)));
end
vv = squeeze(nanmean(pLear(:,met,:),2));   % (mouse, time)
v = mean(vv(:),'omitnan');
fprintf('  %-18s P(light)=%.3f | mice=%d\n', cellNames{5}, v, sum(~isnan(vv(:,1))));

%% 5. Figure: 2x2 matrix (GLM)
f = figure('Name','Cue decoder: cue x context 2x2 (P(light), GLM)','Color','w','Position',[60 60 1180 760]);
rowN = {'Calib (LAu/LAuW)','Task (AW/LW)'};
colN = {'Audio','Light'};
cellName = {'AudioOnly','LightOnly','Naive AudioWater','Transfer LightWater'};
colr = {[0.30 0.60 0.20], [0.70 0.30 0.70], [0.10 0.45 0.70], [0.85 0.33 0.10]};
axG = gobjects(2,2);
for c = 1:4
    [rr, cc] = ind2sub([2 2], c);
    ax = subplot(2,2,c); hold(ax,'on');
    axG(rr,cc) = ax;
    v = squeeze(pCell(:,met,c,:));
    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color',colr{c},'LineWidth',1.8,'MarkerSize',3,'DisplayName',cellName{c});
    yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'P(light) (0=audio,1=light)');
    title(ax, sprintf('%s / %s: %s', rowN{rr}, colN{cc}, cellName{c}),'FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',6);
    box(ax,'off'); ax.FontSize = 8;
end
% row labels
for rr = 1:2
    text(axG(rr,1), -0.36, 0.5, rowN{rr}, 'Units','normalized', 'Rotation',90, ...
        'HorizontalAlignment','center', 'FontWeight','bold','FontSize',10);
end
% column headers
for cc = 1:2
    text(axG(1,cc), 0.5, 1.16, colN{cc}, 'Units','normalized', 'HorizontalAlignment','center', ...
        'FontWeight','bold','FontSize',10);
end
% align y-axes across all cells
ymin = inf; ymax = -inf;
for c = 1:4
    yl = get(axG(c),'YLim');
    ymin = min(ymin, yl(1)); ymax = max(ymax, yl(2));
end
for c = 1:4
    set(axG(c),'YLim',[ymin ymax]);
end

fprintf('\nDone. Cue x context matrix complete.\n');

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
