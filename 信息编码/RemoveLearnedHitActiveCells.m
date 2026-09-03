%% RemoveLearnedHitActiveCells.m
% 找出"细胞集群"：在 Learned 阶段活跃（0-1s 平均 > 基线 -3-0s 的 mean+3*sd），
%   且在 Transfer 的 hit trials 中也活跃（同判据）。
% 对比：去掉该集群 vs 随机去掉同样数量细胞后，Choice(hit/miss) 解码器
%   在 Transfer(LightWater) 上的解码性能差异。
% 解码器：naive-Gaussian（Learned 训练，Transfer 测试），特征=0-1s 窗口平均 z
prjRoot = fileparts(fileparts(mfilename('fullpath')));
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
warning off all;
rng(42);
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
xsSec = double(xs); nTime = numel(xs);
idxB = find(xsSec>=-3 & xsSec<0);      % 基线窗 -3~0s
idxAct = find(xsSec>=0 & xsSec<=1);    % 活跃窗 0~1s

Blk = DS.Blocks; Blk.Design = string(Blk.Design);
DTp = DS.DateTimes(:, {'DateTime','Mouse','Phase'}); DTp.DateTime = datetime(DTp.DateTime);
if ~isempty(DTp.DateTime.TimeZone); DTp.DateTime.TimeZone=''; end
DTp.Mouse=string(DTp.Mouse); DTp.Phase=string(DTp.Phase);
blkDT=datetime(Blk.DateTime); if ~isempty(blkDT.TimeZone); blkDT.TimeZone=''; end
php=repmat("<missing>",height(Blk),1);
for j=1:height(Blk); ix=find(DTp.DateTime==blkDT(j),1); if ~isempty(ix); php(j)=DTp.Phase(ix); end; end
Blk.Phase=php;
naiveAW = Blk.BlockUID(Blk.Design=="AudioWater" & Blk.Phase=="Naive");
learnAW = Blk.BlockUID(Blk.Design=="AudioWater" & Blk.Phase=="Learned");
testLW  = Blk.BlockUID(Blk.Design=="LightWater" & Blk.Phase=="Transfer");
miceAll = unique(DTp.Mouse);

% 收集每鼠数据
S = struct('Mouse',{},'nCell',{},'nRem',{},'Xtr',{},'ytr',{},'Xte',{},'yte',{},'cellU',{});
nMouse = 0;
for iM=1:numel(miceAll)
    m=miceAll(iM);
    trN=table(); trLn=table(); trTr=table();
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Naive'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); trN=r{1}; trN=trN(ismember(uint64(trN.BlockUID),uint64(naiveAW)),:); end
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Learned'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); trLn=r{1}; trLn=trLn(ismember(uint64(trLn.BlockUID),uint64(learnAW)),:); end
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); trTr=r{1}; trTr=trTr(ismember(uint64(trTr.BlockUID),uint64(testLW)),:); end
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(trN)||~okT(trLn)||~okT(trTr); continue; end
    trN=iDropNaN(trN); trLn=iDropNaN(trLn); trTr=iDropNaN(trTr);
    tr2=[trN;trLn];
    if isempty(tr2)||isempty(trTr); continue; end
    ytr=iTrialLabel(tr2,'Behavior'); yte=iTrialLabel(trTr,'Behavior');
    fprintf('  %s: train(N+L) hit=%d miss=%d | Transfer hit=%d miss=%d\n', m, sum(ytr==1), sum(ytr==0), sum(yte==1), sum(yte==0));
    if sum(ytr==1)<3||sum(ytr==0)<3||sum(yte==1)<3||sum(yte==0)<3; continue; end

    cellU=uint64(unique([tr2.CellUID; trTr.CellUID]));
    if numel(cellU)<10; continue; end

    % ---- 活跃判据（per-cell median 轨迹）----
    Lmed = iMedTrace(trLn, cellU, 1:nTime);
    bL=mean(Lmed(:,idxB),2); sL=std(Lmed(:,idxB),0,2);
    actL = mean(Lmed(:,idxAct),2) > (bL + 3*sL);
    trH = trTr(trTr.Behavior==1,:);
    Hmed = iMedTrace(trH, cellU, 1:nTime);
    bT=mean(Hmed(:,idxB),2); sT=std(Hmed(:,idxB),0,2);
    actTh = mean(Hmed(:,idxAct),2) > (bT + 3*sT);
    remIdx = find(actL & actTh);   % 待去除集群（在 cellU 中的位置）

    % ---- 解码特征：0-1s 窗口平均（per-trial）----
    Xtr3 = iBuild(tr2, cellU, 1:nTime);
    Xte3 = iBuild(trTr, cellU, 1:nTime);
    Xtr = mean(Xtr3(:,:,idxAct),3);
    Xte = mean(Xte3(:,:,idxAct),3);

    nMouse=nMouse+1;
    S(nMouse).Mouse=m; S(nMouse).cellU=cellU;
    S(nMouse).nCell=numel(cellU); S(nMouse).nRem=numel(remIdx);
    S(nMouse).remIdx=remIdx;
    S(nMouse).Xtr=Xtr; S(nMouse).ytr=ytr; S(nMouse).Xte=Xte; S(nMouse).yte=yte;
end
S=S(1:nMouse);
fprintf('有效鼠: %d\n', nMouse);
for i=1:nMouse; fprintf('  %s: nCell=%d, 集群=%d (%.1f%%)\n', S(i).Mouse, S(i).nCell, S(i).nRem, 100*S(i).nRem/S(i).nCell); end

%% 解码性能对比：full / removeS / removeRand
R = 40;   % 随机重复次数
accFull=nan(nMouse,1); accS=nan(nMouse,1);
accRm=nan(nMouse,1); accRse=nan(nMouse,1); pOne=nan(nMouse,1);
for i=1:nMouse
    Xtr=S(i).Xtr; ytr=S(i).ytr; Xte=S(i).Xte; yte=S(i).yte;
    nC=S(i).nCell; rm=S(i).remIdx; keepAll=(1:nC)';
    accFull(i)=iDecode(Xtr,ytr,Xte,yte,keepAll);
    if isempty(rm); accS(i)=accFull(i); else; accS(i)=iDecode(Xtr,ytr,Xte,yte,setdiff(keepAll,rm)); end
    accR=nan(R,1);
    for r=1:R
        idx=randperm(nC, numel(rm));
        accR(r)=iDecode(Xtr,ytr,Xte,yte,setdiff(keepAll,idx));
    end
    accRm(i)=mean(accR); accRse(i)=std(accR);
    pOne(i)=mean(accR >= accS(i));
end
fprintf('\n=== decode accuracy (Choice on Transfer) ===\n');
fprintf('full      : %.3f±%.3f\n', mean(accFull), std(accFull)/sqrt(nMouse));
fprintf('removeS   : %.3f±%.3f\n', mean(accS), std(accS)/sqrt(nMouse));
fprintf('removeRand: %.3f±%.3f (per mouse %d repeats)\n', mean(accRm), std(accRm)/sqrt(nMouse), R);
[~,pFS]=ttest(accFull,accS); [~,pSR]=ttest(accS,accRm);
fprintf('paired t: full vs removeS p=%.3g | removeS vs removeRand p=%.3g\n', pFS, pSR);
fprintf('single-mouse perm p(accR>=accS)<0.05: %d/%d\n', sum(pOne<0.05), nMouse);

%% 图：每鼠三点 + 跨鼠条形
f = figure('Name','Remove Learned+Transfer-hit active cells','Color','w','Position',[60 60 720 480]);
ax=subplot(1,2,1); hold(ax,'on');
xx=1:nMouse;
plot(ax,xx,accFull,'o-','Color',[0.2 0.2 0.2],'MarkerFaceColor',[0.2 0.2 0.2],'LineWidth',1.2);
plot(ax,xx,accS,'s-','Color',[0.85 0.33 0.10],'MarkerFaceColor',[0.85 0.33 0.10],'LineWidth',1.2);
errorbar(ax,xx,accRm,accRse,'^-','Color',[0.30 0.55 0.80],'MarkerFaceColor',[0.30 0.55 0.80],'LineWidth',1.2,'MarkerSize',6);
set(ax,'XTick',1:nMouse,'XTickLabel',{S.Mouse},'XTickLabelRotation',45);
ylabel(ax,'Transfer decode accuracy'); title(ax,'per-mouse');
legend(ax,{'full','remove cluster','remove random (mean±sem)'},'Box','off','FontSize',7,'Location','southwest');
box(ax,'off'); ax.FontSize=8;
ax=subplot(1,2,2); hold(ax,'on');
barm=[mean(accFull) mean(accS) mean(accRm)]; bare=[std(accFull) std(accS) std(accRm)]/sqrt(nMouse);
bar(ax,1:3,barm,0.6,'FaceColor',[0.6 0.6 0.6]);
errorbar(ax,1:3,barm,bare,'k.','LineWidth',1);
set(ax,'XTick',1:3,'XTickLabel',{'full','removeS','removeRand'});
ylabel(ax,'Transfer decode accuracy'); title(ax,sprintf('across mice (n=%d)\nfull vs S p=%.3g | S vs Rand p=%.3g',nMouse,pFS,pSR));
box(ax,'off'); ax.FontSize=8;
figDir=fullfile(prjRoot,'信息编码','_figcheck');
if ~exist(figDir,'dir'); mkdir(figDir); end
out=fullfile(figDir,'RemoveLearnedHitActiveCells.png');
exportgraphics(f,out,'Resolution',200); fprintf('Saved: %s\n',out);
savefig(f,fullfile(figDir,'RemoveLearnedHitActiveCells.fig'));
warning on all;

% ==================== Local Functions ====================
function t = iDropNaN(t)
if isempty(t) || ~ismember('Behavior', string(t.Properties.VariableNames)); return; end
t = t(~isnan(t.Behavior),:);
end
function M = iMedTrace(rawTbl, cellU, tIdx)
sig=double(rawTbl.TrialSignal); sig=sig(:,tIdx);
cuid=uint64(rawTbl.CellUID);
M=nan(numel(cellU),numel(tIdx));
for c=1:numel(cellU)
    rows=cuid==cellU(c);
    if nnz(rows)>0; M(c,:)=median(sig(rows,:),1); end
end
end
function acc = iDecode(Xtr,ytr,Xte,yte,keep)
Xtr=Xtr(:,keep); Xte=Xte(:,keep);
m0=mean(Xtr(ytr==0,:),1); m1=mean(Xtr(ytr==1,:),1);
s0=std(Xtr(ytr==0,:),0,1); s1=std(Xtr(ytr==1,:),0,1);
sp=sqrt((s0.^2+s1.^2)/2); sp(sp==0)=1;
sc0=sum((Xte-m0).^2./(2*sp.^2),2);
sc1=sum((Xte-m1).^2./(2*sp.^2),2);
acc=mean((sc0>sc1)==yte);
end
function X = iBuild(rawTbl, cellUIDs, tIdx)
sig=double(rawTbl.TrialSignal); sig=sig(:,tIdx);
nts=table(uint64(rawTbl.CellUID),uint64(rawTbl.TrialUID),'VariableNames',{'CellUID','TrialUID'});
sc=cell(size(sig,1),1); for i=1:size(sig,1); sc{i}=sig(i,:); end
nts.Signal=sc; nts=nts(ismember(nts.CellUID,cellUIDs),:);
tu=unique(nts.TrialUID); X=zeros(numel(tu),numel(cellUIDs),size(sig,2));
for it=1:numel(tu); rows=nts(nts.TrialUID==tu(it),:); [~,loc]=ismember(rows.CellUID,cellUIDs); for ir=1:height(rows); ci=loc(ir); if ci>0; X(it,ci,:)=rows.Signal{ir}; end; end; end
end
function y = iTrialLabel(rawTbl, varName)
tu=unique(uint64(rawTbl.TrialUID)); y=nan(numel(tu),1);
for it=1:numel(tu); y(it)=mode(rawTbl.(varName)(uint64(rawTbl.TrialUID)==tu(it))); end
end
