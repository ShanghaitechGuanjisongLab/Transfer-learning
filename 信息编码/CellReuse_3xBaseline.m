%% CellReuse_3xBaseline.m
% 复用细胞研究（3x基线定义）：活跃 = 刺激后 0-1s 平均活动 > 基线(t<0)平均活动的 3 倍。
% Learned=AudioWater trainAW，Transfer=LightWater。复用 = 两阶段都活跃的交集。
% 输出：每鼠复用细胞数量/比例；Choice/Cue cfg2 解码（全细胞 vs 剔除复用）+ 随机对照。
prjRoot = fileparts(fileparts(mfilename('fullpath')));
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
warning off all;
rng(42); met = 2; K = 5;

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);
bI = find(tVec < 0);
sI = find((tVec >= 0) & (tVec <= 1));   % 0-1s 刺激后窗口

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
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ~ismember(Blk.Phase, ["Recall","Final"]));
miceAll = unique(DT.Mouse);

fprintf('=== 复用细胞（3x基线定义，0-1s vs t<0）===\n');
S = struct(); nm = 0;
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    tr2=table(); testTbl=table(); trA=table(); trL=table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(trainAW)),:); if ~isempty(t); tr2=t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); testTbl=r{1}; testTbl=testTbl(ismember(uint64(testTbl.BlockUID),uint64(testLW)),:); end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=zeros(height(t),1); trA=t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=ones(height(t),1); trL=t; end; end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(tr2)||~okT(testTbl)||~okT(trA)||~okT(trL); continue; end
    tr2=tr2(~isnan(tr2.Behavior),:); testTbl=testTbl(~isnan(testTbl.Behavior),:);
    trA=trA(~isnan(trA.Behavior),:); trL=trL(~isnan(trL.Behavior),:);
    if isempty(tr2)||isempty(testTbl)||isempty(trA)||isempty(trL); continue; end

    lr = iResp(tr2, tIdxFull, bI, sI); trR = iResp(testTbl, tIdxFull, bI, sI);
    lAct = lr.CellUID(lr.stim > 3*lr.base);
    tAct = trR.CellUID(trR.stim > 3*trR.base);
    reuse = intersect(lAct, tAct);

    cellC = uint64(unique([tr2.CellUID; testTbl.CellUID]));
    if numel(cellC)<10; continue; end
    Xc = iBuildTrialMatrix(tr2, cellC, tIdxFull); XteC = iBuildTrialMatrix(testTbl, cellC, tIdxFull);
    if isempty(Xc)||isempty(XteC); continue; end
    Xc = iBaselineNorm(Xc,bI); XteC = iBaselineNorm(XteC,bI);
    yc = iTrialLabel(tr2,'Behavior'); bteC = iTrialLabel(testTbl,'Behavior');
    if sum(yc==1)<3||sum(yc==0)<3; continue; end
    s2 = [trA; trL];
    cellU = uint64(unique([s2.CellUID; testTbl.CellUID]));
    if numel(cellU)<10; continue; end
    Xq = iBuildTrialMatrix(s2, cellU, tIdxFull); XteQ = iBuildTrialMatrix(testTbl, cellU, tIdxFull);
    if isempty(Xq)||isempty(XteQ); continue; end
    Xq = iBaselineNorm(Xq,bI); XteQ = iBaselineNorm(XteQ,bI);
    yq = iTrialLabel(s2,'Cue'); bteQ = iTrialLabel(testTbl,'Behavior');
    if sum(yq==0)<3||sum(yq==1)<3; continue; end

    nm = nm+1;
    S(nm).Mouse=m; S(nm).reuse=reuse; S(nm).lAct=lAct; S(nm).tAct=tAct;
    S(nm).baseL = lr.base; S(nm).baseT = trR.base;
    S(nm).cellC=cellC; S(nm).Xc=Xc; S(nm).XteC=XteC; S(nm).yc=yc; S(nm).bteC=bteC;
    S(nm).cellU=cellU; S(nm).Xq=Xq; S(nm).XteQ=XteQ; S(nm).yq=yq; S(nm).bteQ=bteQ;
    fprintf('%-9s nCell=%d  Learned活跃=%d(%.0f%%)  Transfer活跃=%d(%.0f%%)  复用=%d(%.1f%%)\n', ...
        m, numel(cellC), numel(lAct), 100*numel(lAct)/numel(cellC), numel(tAct), 100*numel(tAct)/numel(cellC), ...
        numel(reuse), 100*numel(reuse)/numel(cellC));
end
S = S(1:nm);
fprintf('有效鼠: %d\n', nm);
bL = cat(1, S.baseL); bT = cat(1, S.baseT);
fprintf('基线均值(t<0)分布: Learned median=%.4f (range [%.4f %.4f]) ; Transfer median=%.4f (range [%.4f %.4f])\n', ...
    median(bL), min(bL), max(bL), median(bT), min(bT), max(bT));
fprintf('3x基线阈值(median): Learned %.4f ; Transfer %.4f\n', 3*median(bL), 3*median(bT));

%% 解码对比（3x基线复用细胞）
for dec = 1:2
    if dec==1; decName='Choice'; else; decName='Cue'; end
    fprintf('\n=== %s cfg2：剔除复用（3x基线）===\n', decName);
    Nrand=20;
    for i = 1:nm
        try
            if dec==1; cellU=S(i).cellC; Xtr=S(i).Xc; Xte=S(i).XteC; ytr=S(i).yc; bte=S(i).bteC;
            else; cellU=S(i).cellU; Xtr=S(i).Xq; Xte=S(i).XteQ; ytr=S(i).yq; bte=S(i).bteQ; end
            reuseIn = intersect(S(i).reuse, cellU);
            keepNoR = ~ismember(cellU, reuseIn);
            if sum(keepNoR)<2; continue; end
            miAll=nan(1,nTfull); s2All=nan(1,nTfull); miNoR=nan(1,nTfull); s2NoR=nan(1,nTfull);
            for it=1:nTfull
                Ftr=Xtr(:,:,it);
                [so,po]=iCvPredict(Ftr,ytr,K,met); miAll(it)=iMIFromLabels(po,ytr);
                bal=iBalanceTrain(ytr); [st,~]=iGlmDecode(Ftr(bal,:),ytr(bal),Xte(:,:,it));
                ph=1./(1+exp(-st)); s2All(it)=mean(ph(bte==1))-mean(ph(bte==0));
                Fn=Xtr(:,keepNoR,it);
                [so,po]=iCvPredict(Fn,ytr,K,met); miNoR(it)=iMIFromLabels(po,ytr);
                bn=iBalanceTrain(ytr); [st,~]=iGlmDecode(Fn(bn,:),ytr(bn),Xte(:,keepNoR,it));
                ph=1./(1+exp(-st)); s2NoR(it)=mean(ph(bte==1))-mean(ph(bte==0));
            end
            [~,pk]=max(miAll);
            randMI=nan(Nrand,1); randS2=nan(Nrand,1);
            for rr=1:Nrand
                keep=true(1,numel(cellU)); keep(randperm(numel(cellU),numel(reuseIn)))=false; kIdx=find(keep);
                Fn=Xtr(:,kIdx,pk);
                [so,po]=iCvPredict(Fn,ytr,K,met); randMI(rr)=iMIFromLabels(po,ytr);
                bn=iBalanceTrain(ytr); [st,~]=iGlmDecode(Fn(bn,:),ytr(bn),Xte(:,kIdx,pk));
                ph=1./(1+exp(-st)); randS2(rr)=mean(ph(bte==1))-mean(ph(bte==0));
            end
            pMI=mean(randMI < miNoR(pk)); pS2=mean(randS2 < s2NoR(pk));
            fprintf('%-9s nReuse=%d(%.1f%%)  MI:全=%.3f 剔=%.3f | S2:全=%.3f 剔=%.3f | pMI=%.2f pS2=%.2f\n', ...
                S(i).Mouse, numel(reuseIn), 100*numel(reuseIn)/numel(cellU), ...
                mean(miAll,'omitnan'), mean(miNoR,'omitnan'), mean(s2All,'omitnan'), mean(s2NoR,'omitnan'), pMI, pS2);
        catch ME
            fprintf('ERR %s: %s\n', S(i).Mouse, ME.message);
        end
    end
end
warning on all;

% ==================== Local Functions ====================
function rt = iResp(rawTbl, tIdx, bI, sI)
sig = double(rawTbl.TrialSignal); sig = sig(:, tIdx);
base = mean(sig(:, bI), 2); stim = mean(sig(:, sI), 2);
cuid = uint64(rawTbl.CellUID);
[u, ~, ic] = unique(cuid);
b = accumarray(ic, base, [], @mean); s = accumarray(ic, stim, [], @mean);
rt = table(u, b, s, 'VariableNames', {'CellUID','base','stim'});
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
X = X - mean(X(:, :, baseIdx), 3);
end
function y = iTrialLabel(rawTbl, varName)
tu = unique(uint64(rawTbl.TrialUID)); y = nan(numel(tu),1);
for iT = 1:numel(tu); y(iT) = mode(rawTbl.(varName)(uint64(rawTbl.TrialUID)==tu(iT))); end
end
function [sOOF, pOOF] = iCvPredict(F, y, K, met)
n = size(F,1); sOOF = nan(n,1); pOOF = nan(n,1);
perm = randperm(n); foldSize = ceil(n/K);
for k = 1:K
    te = false(n,1); idx = (k-1)*foldSize+1 : min(k*foldSize, n);
    te(perm(idx)) = true; tr = ~te;
    if sum(y(te)==1) < 1 || sum(y(te)==0) < 1
        maj = mode(y(tr)); sOOF(te) = 2*maj-1; pOOF(te) = maj; continue;
    end
    bal = iBalanceTrain(y(tr)); idxTr = find(tr);
    if met == 1; [sOOF(te), pOOF(te)] = iLinDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:));
    else; [sOOF(te), pOOF(te)] = iGlmDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:)); end
end
end
function bal = iBalanceTrain(y)
i1 = find(y==1); i0 = find(y==0); n = min(numel(i1), numel(i0));
i1 = i1(randperm(numel(i1), n)); i0 = i0(randperm(numel(i0), n)); bal = [i1; i0];
end
function mi = iMIFromLabels(pred, lab)
n = numel(lab);
if n < 4 || numel(unique(lab)) < 2; mi = 0; return; end
joint = accumarray([pred(:)+1, lab(:)+1], 1, [2 2]);
joint(sum(joint,2)==0,:) = [];
if isempty(joint); mi=0; return; end
p = joint/sum(joint(:)); px = sum(p,2); py = sum(p,1);
miRaw = 0;
for i=1:size(p,1)
    for j=1:size(p,2)
        if p(i,j)>0 && px(i)>0 && py(j)>0; miRaw = miRaw + p(i,j)*log2(p(i,j)/(px(i)*py(j))); end
    end
end
Mx = size(p,1); My = size(p,2);
mi = max(0, miRaw - (Mx-1)*(My-1)/(2*n*log(2)));
end
function [score, pred] = iLinDecode(Ftr, ytr, Fte)
mu = mean(Ftr,1); sd = std(Ftr,0,1); sd(sd==0)=1;
Ftrs = (Ftr-mu)./sd; Ftes = (Fte-mu)./sd;
w = pinv([ones(size(Ftrs,1),1), Ftrs])*(2*ytr-1);
score = [ones(size(Ftes,1),1), Ftes]*w; pred = double(score >= 0);
end
function [score, pred] = iGlmDecode(Ftr, ytr, Fte)
m0 = mean(Ftr(ytr==0,:),1); m1 = mean(Ftr(ytr==1,:),1);
s0 = std(Ftr(ytr==0,:),0,1); s1 = std(Ftr(ytr==1,:),0,1);
sp = sqrt((s0.^2 + s1.^2)/2); sp(sp==0)=1;
score = sum((Fte - m0).^2./(2*sp.^2) - (Fte - m1).^2./(2*sp.^2), 2);
pred = double(score >= 0);
end
