%% CellReuseStudy_All.m
% 复用细胞研究（全面版）：Cue cfg2 与 Choice cfg2 均分析。
% 对多个"活跃"定义做敏感性分析；做"剔除复用"与"保留复用(反向)"对照 + 随机剔除对照。
% 活跃定义: '>0' (正响应) / '>0.1' / 'sig' (t检验显著) / 'top30' (响应 top 30%)
% 指标: OOF MI（平均）、Stage2 倾向分离 LH-LM（平均）；随机对照在 MI 峰值时点做（N 次）。
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
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);
bI = find(tVec < 0);
sI = find((tVec >= 0.3) & (tVec <= 0.96));

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

defs = {'>0','>0.1','sig','top30'};
nDef = numel(defs);
Nrand = 20;

% 预计算每鼠 Learned/Transfer 响应 + 各定义活跃细胞 + Cue/Choice 数据
S = struct(); nm = 0;
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    tr2 = table(); testTbl = table(); trA = table(); trL = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(trainAW)),:); if ~isempty(t); tr2=t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); testTbl=r{1}; testTbl=testTbl(ismember(uint64(testTbl.BlockUID),uint64(testLW)),:); end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=zeros(height(t),1); trA=t; end; end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=ones(height(t),1); trL=t; end; end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(tr2) || ~okT(testTbl) || ~okT(trA) || ~okT(trL); continue; end
    tr2 = tr2(~isnan(tr2.Behavior), :); testTbl = testTbl(~isnan(testTbl.Behavior), :);
    trA = trA(~isnan(trA.Behavior), :); trL = trL(~isnan(trL.Behavior), :);
    if isempty(tr2)||isempty(testTbl)||isempty(trA)||isempty(trL); continue; end

    % Learned(tr2)/Transfer(testTbl) 响应
    lr = iCellResponse(tr2, tIdxFull, bI, sI);
    trR = iCellResponse(testTbl, tIdxFull, bI, sI);
    actD = cell(nDef,1);
    for d = 1:nDef
        aL = iActive(lr, defs{d}); aT = iActive(trR, defs{d});
        actD{d} = intersect(aL, aT);
    end
    % Choice cfg2 矩阵
    cellC = uint64(unique([tr2.CellUID; testTbl.CellUID]));
    if numel(cellC)<10; continue; end
    Xc = iBuildTrialMatrix(tr2, cellC, tIdxFull); XteC = iBuildTrialMatrix(testTbl, cellC, tIdxFull);
    if isempty(Xc)||isempty(XteC); continue; end
    Xc = iBaselineNorm(Xc,bI); XteC = iBaselineNorm(XteC,bI);
    yc = iTrialLabel(tr2,'Behavior'); bteC = iTrialLabel(testTbl,'Behavior');
    if sum(yc==1)<3||sum(yc==0)<3; continue; end
    % Cue cfg2 矩阵
    s2 = [trA; trL];
    cellU = uint64(unique([s2.CellUID; testTbl.CellUID]));
    if numel(cellU)<10; continue; end
    Xq = iBuildTrialMatrix(s2, cellU, tIdxFull); XteQ = iBuildTrialMatrix(testTbl, cellU, tIdxFull);
    if isempty(Xq)||isempty(XteQ); continue; end
    Xq = iBaselineNorm(Xq,bI); XteQ = iBaselineNorm(XteQ,bI);
    yq = iTrialLabel(s2,'Cue'); bteQ = iTrialLabel(testTbl,'Behavior');
    if sum(yq==0)<3||sum(yq==1)<3; continue; end

    nm = nm+1;
    S(nm).Mouse = m;
    S(nm).actD = actD;
    % Choice
    S(nm).cellC = cellC; S(nm).Xc = Xc; S(nm).XteC = XteC; S(nm).yc = yc; S(nm).bteC = bteC;
    % Cue
    S(nm).cellU = cellU; S(nm).Xq = Xq; S(nm).XteQ = XteQ; S(nm).yq = yq; S(nm).bteQ = bteQ;
end
S = S(1:nm);
fprintf('有效鼠: %d\n', nm);

%% 分析每个解码器
for dec = 1:2   % 1=Choice, 2=Cue
    if dec==1; decName='Choice'; else; decName='Cue'; end
    fprintf('\n================ %s cfg2: 复用细胞剔除研究 ================\n', decName);
    fprintf('def    %-9s %5s %5s %5s | %6s %6s %6s | %6s %6s %6s | %5s %5s\n', ...
        'Mouse','nCell','nReuse','%Reuse','MI_all','MI_noR','MI_onlyR','S2_all','S2_noR','S2_onlyR','pMI','pS2');
    allRow = table();
    for d = 1:nDef
        for i = 1:nm
            try
            if dec==1
                cellU = S(i).cellC; Xtr = S(i).Xc; Xte = S(i).XteC; ytr = S(i).yc; bte = S(i).bteC;
            else
                cellU = S(i).cellU; Xtr = S(i).Xq; Xte = S(i).XteQ; ytr = S(i).yq; bte = S(i).bteQ;
            end
            reuseIn = intersect(S(i).actD{d}, cellU);
            nReuse = numel(reuseIn);
            keepNoR = ~ismember(cellU, reuseIn);   % 剔除复用
            keepOnlyR = ismember(cellU, reuseIn);  % 保留复用(反向)
            if sum(keepNoR)<2 || sum(keepOnlyR)<1; continue; end
            % 全细胞
            miAll=nan(1,nTfull); s2All=nan(1,nTfull);
            for it=1:nTfull
                Ftr = Xtr(:,:,it);
                [sOOF,pOOF]=iCvPredict(Ftr, ytr, K, met);
                miAll(it)=iMIFromLabels(pOOF,ytr);
                bal=iBalanceTrain(ytr);
                [sT,~]=iGlmDecode(Ftr(bal,:),ytr(bal),Xte(:,:,it));
                phT=1./(1+exp(-sT));
                s2All(it)=mean(phT(bte==1))-mean(phT(bte==0));
            end
            miAllM=mean(miAll,'omitnan'); s2AllM=mean(s2All,'omitnan');
            [~,pk]=max(miAll);
            % 剔除复用 / 保留复用（全时点平均指标）
            miNoR=nan(1,nTfull); s2NoR=nan(1,nTfull);
            miOnlyR=nan(1,nTfull); s2OnlyR=nan(1,nTfull);
            for it=1:nTfull
                Fn=Xtr(:,keepNoR,it); FteN=Xte(:,keepNoR,it);
                [so,po]=iCvPredict(Fn,ytr,K,met); miNoR(it)=iMIFromLabels(po,ytr);
                bn=iBalanceTrain(ytr); [st,~]=iGlmDecode(Fn(bn,:),ytr(bn),FteN);
                ph=1./(1+exp(-st)); s2NoR(it)=mean(ph(bte==1))-mean(ph(bte==0));
                Fo=Xtr(:,keepOnlyR,it); FteO=Xte(:,keepOnlyR,it);
                [so,po]=iCvPredict(Fo,ytr,K,met); miOnlyR(it)=iMIFromLabels(po,ytr);
                bo=iBalanceTrain(ytr); [st,~]=iGlmDecode(Fo(bo,:),ytr(bo),FteO);
                ph=1./(1+exp(-st)); s2OnlyR(it)=mean(ph(bte==1))-mean(ph(bte==0));
            end
            miNoRM=mean(miNoR,'omitnan'); s2NoRM=mean(s2NoR,'omitnan');
            miOnlyM=mean(miOnlyR,'omitnan'); s2OnlyM=mean(s2OnlyR,'omitnan');
            % 随机对照（峰值时点）
            randMI=nan(Nrand,1); randS2=nan(Nrand,1);
            for rr=1:Nrand
                keep=true(1,numel(cellU)); keep(randperm(numel(cellU),nReuse))=false; kIdx=find(keep);
                Fn=Xtr(:,kIdx,pk); FteN=Xte(:,kIdx,pk);
                [so,po]=iCvPredict(Fn,ytr,K,met); randMI(rr)=iMIFromLabels(po,ytr);
                bn=iBalanceTrain(ytr); [st,~]=iGlmDecode(Fn(bn,:),ytr(bn),FteN);
                ph=1./(1+exp(-st)); randS2(rr)=mean(ph(bte==1))-mean(ph(bte==0));
            end
            pMI = mean(randMI < miNoR(pk));
            pS2 = mean(randS2 < s2NoR(pk));
            fprintf('%s %-9s %5d %5d %5.1f | %6.3f %6.3f %6.3f | %6.3f %6.3f %6.3f | %5.2f %5.2f\n', ...
                defs{d}, S(i).Mouse, numel(cellU), nReuse, 100*nReuse/numel(cellU), ...
                miAllM, miNoRM, miOnlyM, s2AllM, s2NoRM, s2OnlyM, pMI, pS2);
            allRow = [allRow; table(string(defs{d}), string(S(i).Mouse), numel(cellU), nReuse, ...
                miAllM, miNoRM, miOnlyM, s2AllM, s2NoRM, s2OnlyM, pMI, pS2, ...
                'VariableNames',{'Def','Mouse','nCell','nReuse','MI_all','MI_noR','MI_onlyR','S2_all','S2_noR','S2_onlyR','pMI','pS2'})]; %#ok<AGROW>
            catch ME
                fprintf('ERROR dec=%d mouse=%s def=%s: %s (at %s line %d)\n', dec, char(S(i).Mouse), defs{d}, ME.message, ME.stack(1).name, ME.stack(1).line);
            end
        end
        fprintf('--- %s 跨鼠平均: MI 全=%.3f 剔复用=%.3f 保留复用=%.3f | S2 全=%.3f 剔复用=%.3f 保留复用=%.3f | pMI>0.95: %d/%d, pS2>0.95: %d/%d\n', ...
            defs{d}, mean(allRow.MI_all(allRow.Def==string(defs{d}))), ...
            mean(allRow.MI_noR(allRow.Def==string(defs{d}))), ...
            mean(allRow.MI_onlyR(allRow.Def==string(defs{d}))), ...
            mean(allRow.S2_all(allRow.Def==string(defs{d}))), ...
            mean(allRow.S2_noR(allRow.Def==string(defs{d}))), ...
            mean(allRow.S2_onlyR(allRow.Def==string(defs{d}))), ...
            sum(allRow.pMI(allRow.Def==string(defs{d}))>0.95), sum(allRow.Def==string(defs{d})), ...
            sum(allRow.pS2(allRow.Def==string(defs{d}))>0.95), sum(allRow.Def==string(defs{d})));
    end
end
warning on all;

% ==================== Local Functions ====================
function respT = iCellResponse(rawTbl, tIdx, bI, sI)
sig = double(rawTbl.TrialSignal); sig = sig(:, tIdx);
r = mean(sig(:, sI), 2) - mean(sig(:, bI), 2);
cuid = uint64(rawTbl.CellUID);
[u, ~, ic] = unique(cuid);
m = accumarray(ic, r, [], @mean);
p = accumarray(ic, r, size(m), @(x) myT(x));
respT = table(u, m, p, 'VariableNames', {'CellUID','resp','p'});
end
function pv = myT(x)
if numel(x)>=3 && std(x)>0; [~,pv]=ttest(x); else; pv=1; end
end
function a = iActive(respT, def)
switch def
    case '>0'; a = respT.CellUID(respT.resp > 0);
    case '>0.1'; a = respT.CellUID(respT.resp > 0.1);
    case 'sig'; a = respT.CellUID(respT.p < 0.05 & respT.resp > 0);
    case 'top30'
        th = prctile(respT.resp, 70);
        a = respT.CellUID(respT.resp >= th);
    otherwise; a = respT.CellUID(respT.resp > 0);
end
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
