%% CellReuseDecoderStudy.m
% 复用细胞研究：找出在 Learned（AudioWater 训练集）与 Transfer（LightWater）都活跃的细胞，
% 从 Choice cfg2（AudioWater 训练，hit/miss）解码器中剔除后重做解码，对比效果。
% 活跃 = 刺激诱发响应（t∈[0.3,0.96]s 均值 − 基线 t<0 均值）> 0。
prjRoot = fileparts(fileparts(mfilename('fullpath')));
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
warning off all;
rng(42); doBaselineNorm = true; met = 2; K = 5;

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));   % 1s 窗口
tVec = xs(tIdxFull);
nTfull = numel(tVec);
bI = find(tVec < 0);
sI = find((tVec >= 0.3) & (tVec <= 0.96)); % 刺激响应窗口

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
trainAW  = Blk.BlockUID(Blk.Design == "AudioWater" & (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
testLW   = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
miceAll = unique(DT.Mouse);

fprintf('=== Cell-reuse study: Choice cfg2 (AudioWater->Transfer) ===\n');
fprintf('%-9s %5s %5s %5s %5s | %6s %8s | %6s %6s %6s | %6s %6s\n', ...
    'Mouse','nCell','nReuse','%Reuse','nNonR', 'MIall','MInonR', 'S2all','S2nonR','dS2all','dS2nonR', ...
    'MIpeakAll','MIpeakNonR');
resTable = table();
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    tr2 = table(); testTbl = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); t = r{1}; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :); if ~isempty(t); tr2 = t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1}); testTbl = r{1}; testTbl = testTbl(ismember(uint64(testTbl.BlockUID), uint64(testLW)), :); end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(tr2) || ~okT(testTbl); continue; end
    tr2 = tr2(~isnan(tr2.Behavior), :); testTbl = testTbl(~isnan(testTbl.Behavior), :);
    if isempty(tr2) || isempty(testTbl); continue; end

    % ---- 每细胞刺激诱发响应（Learned = tr2；Transfer = testTbl） ----
    lr = iCellResponse(tr2, tIdxFull, bI, sI);   % table: CellUID, resp
    trResp = lr;                                  % Learned 活跃度
    teResp = iCellResponse(testTbl, tIdxFull, bI, sI); % Transfer 活跃度
    learnAct = trResp.CellUID(trResp.resp > 0);
    transAct = teResp.CellUID(teResp.resp > 0);
    reuseUIDs = intersect(learnAct, transAct);

    % ---- 构建解码矩阵 ----
    cellUIDs = uint64(unique([tr2.CellUID; testTbl.CellUID]));
    if numel(cellUIDs) < 10; continue; end
    Xtr2 = iBuildTrialMatrix(tr2, cellUIDs, tIdxFull);
    Xte  = iBuildTrialMatrix(testTbl, cellUIDs, tIdxFull);
    if isempty(Xtr2) || isempty(Xte); continue; end
    Xtr2 = iBaselineNorm(Xtr2, bI); Xte = iBaselineNorm(Xte, bI);
    behTr2 = iTrialLabel(tr2, 'Behavior'); behTe = iTrialLabel(testTbl, 'Behavior');
    if sum(behTr2==1) < 3 || sum(behTr2==0) < 3; continue; end

    % 剔除复用细胞：列索引
    nonreuseIdx = find(~ismember(cellUIDs, reuseUIDs));
    if numel(nonreuseIdx) < 2; continue; end

    % ---- 解码对比：全细胞 vs 剔除复用 ----
    miAll = nan(1,nTfull); miNonR = nan(1,nTfull);
    s2All = nan(1,nTfull); s2NonR = nan(1,nTfull);
    for iT = 1:nTfull
        F = Xtr2(:,:,iT); yb = behTr2;
        [sOOF, pOOF] = iCvPredict(F, yb, K, met);
        miAll(iT) = iMIFromLabels(pOOF, yb);
        bal = iBalanceTrain(yb);
        [sT,~] = iGlmDecode(F(bal,:), yb(bal), Xte(:,:,iT));
        phT = 1./(1+exp(-sT));
        s2All(iT) = mean(phT(behTe==1)) - mean(phT(behTe==0));   % LH - LM

        Fn = Xtr2(:,nonreuseIdx,iT); 
        [sOOFn, pOOFn] = iCvPredict(Fn, yb, K, met);
        miNonR(iT) = iMIFromLabels(pOOFn, yb);
        baln = iBalanceTrain(yb);
        [sTn,~] = iGlmDecode(Fn(baln,:), yb(baln), Xte(:,nonreuseIdx,iT));
        phTn = 1./(1+exp(-sTn));
        s2NonR(iT) = mean(phTn(behTe==1)) - mean(phTn(behTe==0));
    end
    % ---- 随机剔除对照（随机剔除同数量细胞，N 次，得到零分布） ----
    Nrand = 50;
    yb = behTr2;
    miAllM = mean(miAll,'omitnan'); miNonRM = mean(miNonR,'omitnan');
    s2AllM = mean(s2All,'omitnan'); s2NonRM = mean(s2NonR,'omitnan');
    randMI = nan(Nrand,1); randS2 = nan(Nrand,1);
    for rr = 1:Nrand
        keep = true(1, numel(cellUIDs));
        keep(randperm(numel(cellUIDs), numel(reuseUIDs))) = false;
        kIdx = find(keep);
        miR = nan(1,nTfull); s2R = nan(1,nTfull);
        for iT = 1:nTfull
            Fn = Xtr2(:,kIdx,iT);
            [sOOFn, pOOFn] = iCvPredict(Fn, yb, K, met);
            miR(iT) = iMIFromLabels(pOOFn, yb);
            baln = iBalanceTrain(yb);
            [sTn,~] = iGlmDecode(Fn(baln,:), yb(baln), Xte(:,kIdx,iT));
            phTn = 1./(1+exp(-sTn));
            s2R(iT) = mean(phTn(behTe==1)) - mean(phTn(behTe==0));
        end
        randMI(rr) = mean(miR,'omitnan');
        randS2(rr) = mean(s2R,'omitnan');
    end
    pMI = mean(randMI < miNonRM);   % 剔除复用的 MI 低于随机剔除的比例（越高=复用越关键）
    pS2 = mean(randS2 < s2NonRM);
    fprintf('%-9s %5d %5d %5.1f %5d | %6.3f %8.3f | %6.3f %6.3f | %5.2f %5.2f\n', ...
        m, numel(cellUIDs), numel(reuseUIDs), 100*numel(reuseUIDs)/numel(cellUIDs), numel(nonreuseIdx), ...
        miAllM, miNonRM, s2AllM, s2NonRM, pMI, pS2);
    resTable = [resTable; table(string(m), numel(cellUIDs), numel(reuseUIDs), ...
        100*numel(reuseUIDs)/numel(cellUIDs), miAllM, miNonRM, s2AllM, s2NonRM, pMI, pS2, ...
        'VariableNames',{'Mouse','nCell','nReuse','pctReuse','MI_all','MI_noReuse','S2sep_all','S2sep_noReuse','pMI','pS2'})]; %#ok<AGROW>
end
fprintf('\n=== 跨鼠平均 ===\n');
if height(resTable) > 0
    fprintf('  MI:  全细胞 %.3f  vs 剔除复用 %.3f\n', mean(resTable.MI_all), mean(resTable.MI_noReuse));
    fprintf('  Stage2 分离(LH-LM): 全细胞 %.3f  vs 剔除复用 %.3f\n', mean(resTable.S2sep_all), mean(resTable.S2sep_noReuse));
    fprintf('  复用细胞比例平均 %.1f%%\n', mean(resTable.pctReuse));
    fprintf('  剔除复用显著差于随机剔除(pMI>0.95)的鼠: %d/%d\n', sum(resTable.pMI>0.95), height(resTable));
    fprintf('  剔除复用显著差于随机剔除(pS2>0.95)的鼠: %d/%d\n', sum(resTable.pS2>0.95), height(resTable));
end
warning on all;

% ==================== Local Functions ====================
function respTbl = iCellResponse(rawTbl, tIdx, bI, sI)
% 每细胞刺激诱发响应 = mean over trials (stim窗口均值 - 基线均值)
sig = double(rawTbl.TrialSignal); sig = sig(:, tIdx);
base = mean(sig(:, bI), 2); stim = mean(sig(:, sI), 2);
r = stim - base;
cuid = uint64(rawTbl.CellUID);
[u, ~, ic] = unique(cuid);
resp = accumarray(ic, r, [], @mean);
respTbl = table(u, resp, 'VariableNames', {'CellUID','resp'});
end

function X = iBuildTrialMatrix(rawTbl, cellUIDs, tIdx)
sig = double(rawTbl.TrialSignal); sig = sig(:, tIdx);
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

function mi = iMIFromLabels(pred, lab)
n = numel(lab);
if n < 4 || numel(unique(lab)) < 2; mi = 0; return; end
joint = accumarray([pred(:)+1, lab(:)+1], 1, [2 2]);
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
