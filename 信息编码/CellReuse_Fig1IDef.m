%% CellReuse_Fig1IDef.m
% 按 Fig1I 官方口径的复用细胞研究：
%   活跃 = 1s 处活动 > 基线(-3~0s)均值 + 3*SD（中位数 Z-score，QueryNTATS Median）
%   复用 = Learned AudioWater 活跃 ∩ Transfer LightWater 活跃（逐鼠）
% 输出：逐鼠复用占比（分母=Learned 活跃，与 Fig1I 一致）；并用该复用细胞做解码剔除对比（Choice/Cue cfg2 + 随机对照）。
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
xsSec = double(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s; error('No1s'); end
kSigma = 3;

% ---- Learned/Transfer session 表 ----
TLearn = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
TTran  = DS.TableQuery(["Mouse","DateTime","Behavior"], Phase="Transfer", Stimulus="LightWater", Design="LightWater");
if isempty(TLearn) || isempty(TTran); error('empty'); end
TLearn.Mouse = string(TLearn.Mouse); TLearn.DateTime = iNormDT(TLearn.DateTime);
TTran.Mouse = string(TTran.Mouse); TTran.DateTime = iNormDT(TTran.DateTime);
dtLearnT = groupsummary(TLearn, "Mouse", "max", "DateTime"); dtLearnT.Properties.VariableNames{end}='DateTimeLearned';
dtTranT = groupsummary(TTran(:,["Mouse","DateTime"]), "Mouse", "min", "DateTime"); dtTranT.Properties.VariableNames{end}='DateTimeTransfer';
Sess = innerjoin(dtLearnT(:,[ "Mouse","DateTimeLearned"]), dtTranT(:,[ "Mouse","DateTimeTransfer"]), 'Keys','Mouse');

CellMeta = DS.Cells(:, ["CellUID","Mouse"]); CellMeta.CellUID = uint64(CellMeta.CellUID); CellMeta.Mouse = string(CellMeta.Mouse);

% ---- QueryNTATS (Median ZScore), pooled 带 Mouse ----
n = height(Sess);
QLearn = table(repmat(categorical("Learned"),n,1), repmat(categorical("AudioWater"),n,1), repmat(categorical("AudioWater"),n,1), ...
    categorical(string(Sess.Mouse)), Sess.DateTimeLearned, repmat("Learned",n,1), ...
    'VariableNames',{'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
QTran = table(repmat(categorical("Transfer"),n,1), repmat(categorical("LightWater"),n,1), repmat(categorical("LightWater"),n,1), ...
    categorical(string(Sess.Mouse)), Sess.DateTimeTransfer, repmat("Transfer",n,1), ...
    'VariableNames',{'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
GL = DS.QueryNTATS(QLearn, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GT = DS.QueryNTATS(QTran, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
[XLearnAll, cellLearnAll] = iExtractNtats2D(GL);
[XTranAll, cellTranAll]   = iExtractNtats2D(GT);

fprintf('=== 复用细胞（Fig1I 口径：1s > 基线+3SD，Median ZScore）===\n');
S = struct('Mouse', {}, 'reuse', {}, 'common', {}); nm = 0;
for i = 1:n
    mouseName = string(Sess.Mouse(i));
    mouseCells = CellMeta.CellUID(CellMeta.Mouse == mouseName);
    if isempty(mouseCells); continue; end
    [~, iL] = intersect(cellLearnAll, mouseCells, 'stable');
    [~, iT] = intersect(cellTranAll, mouseCells, 'stable');
    cellL = cellLearnAll(iL); XL = XLearnAll(iL, :);
    cellT = cellTranAll(iT); XT = XTranAll(iT, :);
    if isempty(XL) || isempty(XT); continue; end
    [common, idxL, idxT] = intersect(cellL, cellT, 'stable');
    if isempty(common); continue; end
    XLc = XL(idxL, :); XTc = XT(idxT, :);
    la = iIsActiveAt1s(XLc, baseMask, idx1s, kSigma);
    ta = iIsActiveAt1s(XTc, baseMask, idx1s, kSigma);
    reuse = common(la & ta);
    nLearnAct = sum(la); nTranAct = sum(ta);
    fprintf('%-9s common=%d  Learned活跃=%d(%.0f%%) Transfer活跃=%d(%.0f%%) 复用=%d(%.1f%% of learnedAct, %.1f%% of common)\n', ...
        mouseName, numel(common), nLearnAct, 100*nLearnAct/numel(common), nTranAct, 100*nTranAct/numel(common), ...
        numel(reuse), 100*numel(reuse)/max(1,nLearnAct), 100*numel(reuse)/numel(common));
    S = [S; struct('Mouse',mouseName,'reuse',reuse,'common',common)]; %#ok<AGROW>
    nm = nm + 1;
end
S = S(1:nm);
fprintf('有效鼠: %d\n', nm);

%% 解码剔除（Fig1I 复用细胞）: Choice/Cue cfg2
% 训练/测试数据用 QueryNTS 构建（1s 窗口）
Blk = DS.Blocks; Blk.Design = string(Blk.Design);
DTp = DS.DateTimes(:, {'DateTime','Mouse','Phase'}); DTp.DateTime = datetime(DTp.DateTime);
if ~isempty(DTp.DateTime.TimeZone); DTp.DateTime.TimeZone = ''; end
DTp.Mouse = string(DTp.Mouse); DTp.Phase = string(DTp.Phase);
blkDT = datetime(Blk.DateTime); if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
php = repmat("<missing>", height(Blk), 1);
for j = 1:height(Blk); ix = find(DTp.DateTime == blkDT(j), 1); if ~isempty(ix); php(j) = DTp.Phase(ix); end; end
Blk.Phase = php;
trainAW  = Blk.BlockUID(Blk.Design == "AudioWater" & (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
testLW   = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ~ismember(Blk.Phase, ["Recall","Final"]));
tIdxFull = find((xsSec>=-1)&(xsSec<=1)); tVec = xsSec(tIdxFull); nTfull = numel(tVec); bI = find(tVec<0);
Nrand = 20;
for dec = 1:2
    if dec==1; decName='Choice'; else; decName='Cue'; end
    fprintf('\n=== %s cfg2：剔除复用（Fig1I 口径）===\n', decName);
    for i = 1:nm
        m = S(i).Mouse;
        tr2=table(); testTbl=table(); trA=table(); trL=table();
        r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(trainAW)),:); tr2=t; end
        r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r)&&~isempty(r{1}); testTbl=r{1}; testTbl=testTbl(ismember(uint64(testTbl.BlockUID),uint64(testLW)),:); end
        r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=zeros(height(t),1); trA=t; end; end
        r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=ones(height(t),1); trL=t; end; end
        okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
        if ~isempty(tr2) && ismember('Behavior', tr2.Properties.VariableNames); tr2 = tr2(~isnan(tr2.Behavior), :); end
        if ~isempty(testTbl) && ismember('Behavior', testTbl.Properties.VariableNames); testTbl = testTbl(~isnan(testTbl.Behavior), :); end
        if ~isempty(trA) && ismember('Behavior', trA.Properties.VariableNames); trA = trA(~isnan(trA.Behavior), :); end
        if ~isempty(trL) && ismember('Behavior', trL.Properties.VariableNames); trL = trL(~isnan(trL.Behavior), :); end
        try
            if dec==1
                if isempty(tr2)||isempty(testTbl); continue; end
                cellU=uint64(unique([tr2.CellUID; testTbl.CellUID]));
                Xtr=iBuild(tr2,cellU,tIdxFull); Xte=iBuild(testTbl,cellU,tIdxFull);
                ytr=iTrialLabel(tr2,'Behavior'); bte=iTrialLabel(testTbl,'Behavior');
            else
                if isempty(trA)||isempty(trL)||isempty(testTbl); continue; end
                s2=[trA;trL];
                cellU=uint64(unique([s2.CellUID; testTbl.CellUID]));
                Xtr=iBuild(s2,cellU,tIdxFull); Xte=iBuild(testTbl,cellU,tIdxFull);
                ytr=iTrialLabel(s2,'Cue'); bte=iTrialLabel(testTbl,'Behavior');
            end
            Xtr=Xtr-mean(Xtr(:,:,bI),3); Xte=Xte-mean(Xte(:,:,bI),3);
            if sum(ytr==1)<3||sum(ytr==0)<3; continue; end
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
            fprintf('%-9s nReuse=%d(%.1f%% of common)  MI:全=%.3f 剔=%.3f | S2:全=%.3f 剔=%.3f | pMI=%.2f pS2=%.2f\n', ...
                m, numel(reuseIn), 100*numel(reuseIn)/numel(cellU), mean(miAll,'omitnan'), mean(miNoR,'omitnan'), ...
                mean(s2All,'omitnan'), mean(s2NoR,'omitnan'), pMI, pS2);
        catch
        end
    end
end
warning on all;

% ==================== Local Functions ====================
function [X, cellUID] = iExtractNtats2D(G)
cellUID = uint64([]); X = [];
if isempty(G); return; end
nt = G.NTATS; cellUID = uint64(G.CellUID);
if isa(nt, 'MATLAB.DataTypes.NDTable'); X = nt.Data; else; X = nt; end
X = double(X);
if ndims(X) == 3; X = squeeze(X(:, :, 1)); end
end
function active = iIsActiveAt1s(X, baseMask, idx1s, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
active = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma .* baseSd));
end
function dt = iNormDT(dt)
dt = datetime(dt); if ~isempty(dt.TimeZone); dt.TimeZone = ''; end
end
function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[~, idx] = min(abs(xsSec - targetSec));
ok = abs(xsSec(idx) - targetSec) <= tolSec;
end
function X = iBuild(rawTbl, cellUIDs, tIdx)
sig = double(rawTbl.TrialSignal); sig = sig(:, tIdx);
nts = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), 'VariableNames',{'CellUID','TrialUID'});
sc = cell(size(sig,1),1); for i=1:size(sig,1); sc{i}=sig(i,:); end
nts.Signal = sc; nts = nts(ismember(nts.CellUID, cellUIDs), :);
tu = unique(nts.TrialUID); X = zeros(numel(tu), numel(cellUIDs), size(sig,2));
for it=1:numel(tu); rows=nts(nts.TrialUID==tu(it),:); [~,loc]=ismember(rows.CellUID,cellUIDs); for ir=1:height(rows); ci=loc(ir); if ci>0; X(it,ci,:)=rows.Signal{ir}; end; end; end
end
function y = iTrialLabel(rawTbl, varName)
tu = unique(uint64(rawTbl.TrialUID)); y = nan(numel(tu),1);
for it=1:numel(tu); y(it) = mode(rawTbl.(varName)(uint64(rawTbl.TrialUID)==tu(it))); end
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
