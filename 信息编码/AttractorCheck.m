%% AttractorCheck.m
% 检验 Cue/Choice 解码器 top25% 权重细胞是否形成"离散吸引子态"
% (1) 逐试次选择变量 DV 的双峰检验：bimodality coefficient (BC) + KS 类间分布 + Cohen's d
% (2) 状态空间 PCA：两类试次的簇分离 + 平均轨迹分叉（吸引子相空间）
% Cue : AO vs LO（训练任务）
% Choice: AW 训练域 tr2(Naive+Learned) hit vs miss（训练任务）+ Transfer hit vs miss（迁移）
% DV_j = sum_i w_i * x_ij（top 细胞在晚期窗 1.5-2s 的平均活性加权投影）
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
tIdxFull = find((xsSec>=-1)&(xsSec<=2)); tVec = xsSec(tIdxFull); nTfull = numel(tIdxFull); bI = find(tVec<0);
[~, pk] = min(abs(tVec - 0.7));
winLate = find(tVec>=1.5 & tVec<=2);       % 持续态窗口

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
calBlocks = Blk.BlockUID(ismember(Blk.Design,["LAu","LAuW"]) & ~ismember(Blk.Phase,["Recall","Final"]));
miceAll = unique(DTp.Mouse);

% 一遍循环收集每鼠原始表 + 各自有效性
S = struct('Mouse', {}, 'CueOK', {}, 'ChOK', {}); nMouse = 0;
for iM=1:numel(miceAll)
    m=miceAll(iM);
    R = iCollect(m, DS, calBlocks, naiveAW, learnAW, testLW, nTime);
    trA=R.trA; trL=R.trL; trN=R.trN; trLn=R.trLn; trTr=R.trTr;
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    stagesOK = okT(trA)&&okT(trL)&&okT(trN)&&okT(trLn)&&okT(trTr) && ...
        ~isempty(trA)&&~isempty(trL)&&~isempty(trN)&&~isempty(trLn)&&~isempty(trTr);

    cueOK=false; chOK=false;
    Xq=[]; yq=[]; wC=[]; topC=[];
    Xc=[]; yc=[]; Xtr=[]; ytr=[]; wCh=[]; topCh=[];
    % ---- Cue（需全部 5 阶段）----
    if stagesOK
        s2=[trA;trL]; cellU=uint64(unique([s2.CellUID; trTr.CellUID]));
        if numel(cellU)>=10
            Xq=iBuild(s2,cellU,tIdxFull); Xq=Xq-mean(Xq(:,:,bI),3);
            yq=iTrialLabel(s2,'Cue');
            if sum(yq==0)>=3&&sum(yq==1)>=3
                wC=iWeight(Xq(:,:,pk), yq); topC=iTopIdx(wC,0.25); cueOK=true;
            end
        end
    end
    % ---- Choice（需 tr2=Naive+Learned 与 Transfer）----
    tr2=[trN;trLn];
    if ~isempty(tr2) && ~isempty(trTr) && okT(tr2) && okT(trTr)
        cellC=uint64(unique([tr2.CellUID; trTr.CellUID]));
        if numel(cellC)>=10
            Xc=iBuild(tr2,cellC,tIdxFull); Xc=Xc-mean(Xc(:,:,bI),3);
            yc=iTrialLabel(tr2,'Behavior');
            Xtr=iBuild(trTr,cellC,tIdxFull); ytr=iTrialLabel(trTr,'Behavior');
            if sum(yc==1)>=3&&sum(yc==0)>=3&&sum(ytr==1)>=3&&sum(ytr==0)>=3
                wCh=iWeight(Xc(:,:,pk), yc); topCh=iTopIdx(wCh,0.25); chOK=true;
            end
        end
    end
    if ~cueOK && ~chOK; continue; end
    nMouse = nMouse+1;
    S(nMouse).Mouse=m; S(nMouse).CueOK=cueOK; S(nMouse).ChOK=chOK;
    S(nMouse).Xq=Xq; S(nMouse).yq=yq; S(nMouse).wC=wC; S(nMouse).topC=topC;
    S(nMouse).Xc=Xc; S(nMouse).yc=yc; S(nMouse).Xtr=Xtr; S(nMouse).ytr=ytr;
    S(nMouse).wCh=wCh; S(nMouse).topCh=topCh;
end
S = S(1:nMouse);
iC = find([S.CueOK]); nC = numel(iC);
iH = find([S.ChOK]);  nH = numel(iH);
fprintf('总收集鼠=%d；Cue 有效鼠=%d；Choice 有效鼠=%d\n', nMouse, nC, nH);
if nC==0 && nH==0; error('无有效鼠'); end

%% ============ (1) 逐试次 DV 双峰检验 ============
dC=nan(nC,1); bcC=nan(nC,1); pC=nan(nC,1);
dTr=nan(nH,1); bcTr=nan(nH,1); pTr=nan(nH,1);   % 训练域 (AW)
dTe=nan(nH,1); bcTe=nan(nH,1); pTe=nan(nH,1);   % Transfer
zC0=[]; zC1=[]; zTr0=[]; zTr1=[]; zTe0=[]; zTe1=[];
for k=1:nC
    i=iC(k);
    Xw=mean(S(i).Xq(:,S(i).topC,winLate),3); DV=Xw*S(i).wC(S(i).topC).';
    g0=S(i).yq==0; g1=S(i).yq==1;
    [dC(k),bcC(k),pC(k)] = iStats(DV(g0),DV(g1));
    [~,z0,z1]=iZsplit(DV,g0,g1); zC0=[zC0;z0]; zC1=[zC1;z1];
end
for k=1:nH
    i=iH(k);
    Xw=mean(S(i).Xc(:,S(i).topCh,winLate),3); DV=Xw*S(i).wCh(S(i).topCh).';
    g0=S(i).yc==0; g1=S(i).yc==1;
    [dTr(k),bcTr(k),pTr(k)] = iStats(DV(g0),DV(g1));
    [~,z0,z1]=iZsplit(DV,g0,g1); zTr0=[zTr0;z0]; zTr1=[zTr1;z1];
    Xw=mean(S(i).Xtr(:,S(i).topCh,winLate),3); DV=Xw*S(i).wCh(S(i).topCh).';
    g0=S(i).ytr==0; g1=S(i).ytr==1;
    [dTe(k),bcTe(k),pTe(k)] = iStats(DV(g0),DV(g1));
    [~,z0,z1]=iZsplit(DV,g0,g1); zTe0=[zTe0;z0]; zTe1=[zTe1;z1];
end
fprintf('\n=== (1) 双峰检验：DV(晚期窗 1.5-2s)，逐鼠统计 ===\n');
fprintf('Cue AO/LO            : d''=%.2f±%.2f, BC=%.3f±%.3f, KS p<0.05 鼠=%d/%d\n', ...
    nanmean(dC), nanstd(dC)/sqrt(nC), nanmean(bcC), nanstd(bcC)/sqrt(nC), sum(pC<0.05), nC);
fprintf('Choice AW(训练域)    : d''=%.2f±%.2f, BC=%.3f±%.3f, KS p<0.05 鼠=%d/%d\n', ...
    nanmean(dTr), nanstd(dTr)/sqrt(nH), nanmean(bcTr), nanstd(bcTr)/sqrt(nH), sum(pTr<0.05), nH);
fprintf('Choice Transfer      : d''=%.2f±%.2f, BC=%.3f±%.3f, KS p<0.05 鼠=%d/%d\n', ...
    nanmean(dTe), nanstd(dTe)/sqrt(nH), nanmean(bcTe), nanstd(bcTe)/sqrt(nH), sum(pTe<0.05), nH);
[~,pDLT] = ttest(dTr, dTe);
fprintf('配对 t: 训练域 d'' vs Transfer d'' p=%.3g（吸引子迁移后是否衰减）\n', pDLT);

%% 图1：DV 分布直方图（跨鼠 z-scored pooled）
f1 = figure('Name','Attractor check: DV distributions','Color','w','Position',[40 40 1200 820]);
dats = {zC0,zC1; zTr0,zTr1; zTe0,zTe1};
cols = {[0.85 0.33 0.10],[0.70 0.30 0.70]; [0.20 0.55 0.80],[0.85 0.33 0.10]; [0.20 0.55 0.80],[0.85 0.33 0.10]};
names = {'AO','LO'; 'hit','miss'; 'hit','miss'};
ttl = {'Cue: AO vs LO','Choice AW训练域: hit vs miss','Choice Transfer: hit vs miss'};
bcs = {[nanmean(bcC),nanstd(bcC)/sqrt(nC)], [nanmean(bcTr),nanstd(bcTr)/sqrt(nH)], [nanmean(bcTe),nanstd(bcTe)/sqrt(nH)]};
for g=1:3
    ax=subplot(2,2,g); hold(ax,'on');
    histogram(ax,dats{g,1},'NumBins',24,'Normalization','pdf','FaceColor',cols{g,1},'FaceAlpha',0.55,'EdgeColor','none','DisplayName',names{g,1});
    histogram(ax,dats{g,2},'NumBins',24,'Normalization','pdf','FaceColor',cols{g,2},'FaceAlpha',0.55,'EdgeColor','none','DisplayName',names{g,2});
    title(ax,sprintf('%s\nBC=%.3f±%.3f', ttl{g}, bcs{g}(1), bcs{g}(2)));
    xlabel(ax,'DV (z)'); ylabel(ax,'density');
    legend(ax,'Location','northeast','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize=8;
end
ax=subplot(2,2,4); hold(ax,'on');
barm=[nanmean(bcC) nanmean(bcTr) nanmean(bcTe)];
bar(ax,1:3,barm,0.6,'FaceColor',[0.5 0.5 0.5]);
set(ax,'XTick',1:3,'XTickLabel',{'Cue AO/LO','Choice AW','Choice Trans'});
yline(ax,5/9,'--','Color',[0.8 0 0],'LineWidth',1,'DisplayName','BC=5/9');
ylabel(ax,'Bimodality coeff.'); title(ax,'双峰系数（>5/9 提示双峰）');
legend(ax,'Box','off','FontSize',7); box(ax,'off'); ax.FontSize=8;
out1 = fullfile(prjRoot,'信息编码','_figcheck','Attractor_DV_Distributions.png');
exportgraphics(f1, out1, 'Resolution', 200); fprintf('Saved: %s\n', out1);
savefig(f1, fullfile(prjRoot,'信息编码','_figcheck','Attractor_DV_Distributions.fig'));

%% ============ (2) PCA 相空间：簇分离 + 轨迹分叉 ============
sepC=nan(nC,1); sepTr=nan(nH,1); sepTe=nan(nH,1);
for k=1:nC
    i=iC(k);
    Xw=mean(S(i).Xq(:,S(i).topC,winLate),3);
    sepC(k)=iClusterSep(Xw, S(i).yq==0, S(i).yq==1);
end
for k=1:nH
    i=iH(k);
    Xw=mean(S(i).Xc(:,S(i).topCh,winLate),3);
    sepTr(k)=iClusterSep(Xw, S(i).yc==0, S(i).yc==1);
    Xw=mean(S(i).Xtr(:,S(i).topCh,winLate),3);
    sepTe(k)=iClusterSep(Xw, S(i).ytr==0, S(i).ytr==1);
end
[~,pSepLT] = ttest(sepTr, sepTe);
fprintf('\n=== (2) PCA 簇分离度（类间质心距 / 平均类内半径，晚期窗）===\n');
fprintf('Cue AO/LO            : %.3f±%.3f (n=%d)\n', nanmean(sepC), nanstd(sepC)/sqrt(nC), nC);
fprintf('Choice AW(训练域)    : %.3f±%.3f (n=%d)\n', nanmean(sepTr), nanstd(sepTr)/sqrt(nH), nH);
fprintf('Choice Transfer      : %.3f±%.3f (n=%d)  (训练域 vs Transfer p=%.3g)\n', nanmean(sepTe), nanstd(sepTe)/sqrt(nH), nH, pSepLT);

% 图2：代表鼠 PCA 相空间
[~,rC]=max(dC); rC=iC(rC); [~,rH]=max(dTr); rH=iH(rH);
f2 = figure('Name','Attractor check: PCA phase space','Color','w','Position',[40 40 1300 900]);
% Cue
Xw=mean(S(rC).Xq(:,S(rC).topC,winLate),3); g0=S(rC).yq==0; g1=S(rC).yq==1;
[coef,sc]=iProj(Xw);
ax=subplot(2,2,1); hold(ax,'on');
scatter(ax,sc(g0,1),sc(g0,2),14,[0.85 0.33 0.10],'filled','MarkerFaceAlpha',0.6,'DisplayName','AO');
scatter(ax,sc(g1,1),sc(g1,2),14,[0.70 0.30 0.70],'filled','MarkerFaceAlpha',0.6,'DisplayName','LO');
iTraj(ax,S(rC).Xq(:,S(rC).topC,:),g0,g1,coef,[0.85 0.33 0.10],[0.70 0.30 0.70]);
title(ax,sprintf('Cue (%s): AO vs LO, sep=%.2f', S(rC).Mouse, sepC(find(rC==iC))));
xlabel(ax,'PC1'); ylabel(ax,'PC2'); legend(ax,'Box','off','FontSize',7); box(ax,'off'); ax.FontSize=8;
% Choice 训练域
Xw=mean(S(rH).Xc(:,S(rH).topCh,winLate),3); g0=S(rH).yc==0; g1=S(rH).yc==1;
[coef,sc]=iProj(Xw);
ax=subplot(2,2,2); hold(ax,'on');
scatter(ax,sc(g0,1),sc(g0,2),14,[0.85 0.33 0.10],'filled','MarkerFaceAlpha',0.6,'DisplayName','miss');
scatter(ax,sc(g1,1),sc(g1,2),14,[0.20 0.55 0.80],'filled','MarkerFaceAlpha',0.6,'DisplayName','hit');
iTraj(ax,S(rH).Xc(:,S(rH).topCh,:),g0,g1,coef,[0.85 0.33 0.10],[0.20 0.55 0.80]);
title(ax,sprintf('Choice AW训练域 (%s): hit vs miss, sep=%.2f', S(rH).Mouse, sepTr(find(rH==iH))));
xlabel(ax,'PC1'); ylabel(ax,'PC2'); legend(ax,'Box','off','FontSize',7); box(ax,'off'); ax.FontSize=8;
% Choice Transfer
Xw=mean(S(rH).Xtr(:,S(rH).topCh,winLate),3); g0=S(rH).ytr==0; g1=S(rH).ytr==1;
[coef,sc]=iProj(Xw);
ax=subplot(2,2,3); hold(ax,'on');
scatter(ax,sc(g0,1),sc(g0,2),14,[0.85 0.33 0.10],'filled','MarkerFaceAlpha',0.6,'DisplayName','miss');
scatter(ax,sc(g1,1),sc(g1,2),14,[0.20 0.55 0.80],'filled','MarkerFaceAlpha',0.6,'DisplayName','hit');
iTraj(ax,S(rH).Xtr(:,S(rH).topCh,:),g0,g1,coef,[0.85 0.33 0.10],[0.20 0.55 0.80]);
title(ax,sprintf('Choice Transfer (%s): hit vs miss, sep=%.2f', S(rH).Mouse, sepTe(find(rH==iH))));
xlabel(ax,'PC1'); ylabel(ax,'PC2'); legend(ax,'Box','off','FontSize',7); box(ax,'off'); ax.FontSize=8;
% 跨鼠分离度汇总
ax=subplot(2,2,4); hold(ax,'on');
xx=[1 2 3]; yy=[nanmean(sepC) nanmean(sepTr) nanmean(sepTe)];
ee=[nanstd(sepC) nanstd(sepTr) nanstd(sepTe)]./sqrt([nC nH nH]);
errorbar(ax,xx,yy,ee,'o-','Color',[0.2 0.2 0.2],'LineWidth',1.6,'MarkerFaceColor',[0.6 0.6 0.6],'MarkerSize',8);
set(ax,'XTick',1:3,'XTickLabel',{'Cue AO/LO','Choice AW','Choice Trans'});
ylabel(ax,'cluster separation (d)'); title(ax, sprintf('簇分离度\nChoice 训练域 vs Transfer p=%.3g', pSepLT));
box(ax,'off'); ax.FontSize=8;
out2 = fullfile(prjRoot,'信息编码','_figcheck','Attractor_PCA_PhaseSpace.png');
exportgraphics(f2, out2, 'Resolution', 200); fprintf('Saved: %s\n', out2);
savefig(f2, fullfile(prjRoot,'信息编码','_figcheck','Attractor_PCA_PhaseSpace.fig'));

%% (3) 固定子空间检验：训练域 PCA 主轴固定投影 Transfer（区分"换轴" vs "信息丢失"）
rPC = 5; nRand = 20;
sepFx=nan(nH,1); sepRd=nan(nH,1); sepTe5=nan(nH,1);
for k=1:nH
    i=iH(k);
    Xaw = mean(S(i).Xc(:,S(i).topCh,winLate),3);
    mu = mean(Xaw,1);
    coefAw = pca(Xaw, 'NumComponents', rPC);
    Xtr = mean(S(i).Xtr(:,S(i).topCh,winLate),3);
    P = (Xtr - mu)*coefAw;
    yh=S(i).ytr==1; ym=S(i).ytr==0;
    sepFx(k)=iClusterSep(P,yh,ym);
    sR=nan(nRand,1);
    for rr=1:nRand
        Q=orth(randn(size(coefAw,1),rPC));
        sR(rr)=iClusterSep((Xtr-mu)*Q,yh,ym);
    end
    sepRd(k)=mean(sR);
    % Transfer 独立 PCA（同维度 rPC）对照
    coefTe=pca(Xtr,'NumComponents',rPC);
    Pte=(Xtr-mean(Xtr,1))*coefTe;
    sepTe5(k)=iClusterSep(Pte,yh,ym);
end
[~,pFxRd]=ttest(sepFx,sepRd);
[~,pTe5Fx]=ttest(sepTe5,sepFx); [~,pTe5Rd]=ttest(sepTe5,sepRd);
fprintf('\n=== (3) 固定子空间检验（训练域 PCA %d 维主轴 → Transfer）===\n', rPC);
fprintf('Transfer 独立PCA(%dd): %.3f±%.3f；训练域固定(%dd): %.3f±%.3f；随机(%dd): %.3f±%.3f\n', ...
    rPC, nanmean(sepTe5), nanstd(sepTe5)/sqrt(nH), rPC, nanmean(sepFx), nanstd(sepFx)/sqrt(nH), rPC, nanmean(sepRd), nanstd(sepRd)/sqrt(nH));
fprintf('配对：独立 vs 固定 p=%.3g；固定 vs 随机 p=%.3g；独立 vs 随机 p=%.3g\n', pTe5Fx, pFxRd, pTe5Rd);
fprintf('（对照：训练权重轴 wCh 的 d'' 训练域=%.2f → Transfer=%.2f）\n', nanmean(dTr), nanmean(dTe));

% 图3：固定子空间检验
[~,rH2]=max(sepFx); rH2=iH(rH2);
f3 = figure('Name','Fixed subspace check','Color','w','Position',[40 40 1200 520]);
Xaw=mean(S(rH2).Xc(:,S(rH2).topCh,winLate),3); mu=mean(Xaw,1);
[coef2,~]=pca(Xaw,'NumComponents',2);
Xtr=mean(S(rH2).Xtr(:,S(rH2).topCh,winLate),3);
P=(Xtr-mu)*coef2; yh=S(rH2).ytr==1; ym=S(rH2).ytr==0;
ax=subplot(1,2,1); hold(ax,'on');
scatter(ax,P(ym,1),P(ym,2),14,[0.85 0.33 0.10],'filled','MarkerFaceAlpha',0.6,'DisplayName','miss');
scatter(ax,P(yh,1),P(yh,2),14,[0.20 0.55 0.80],'filled','MarkerFaceAlpha',0.6,'DisplayName','hit');
title(ax,sprintf('Transfer 试次投影到训练域 PC 子空间 (%s)\nsep(fixed)=%.2f', S(rH2).Mouse, sepFx(find(rH2==iH))));
xlabel(ax,'train PC1'); ylabel(ax,'train PC2'); legend(ax,'Box','off','FontSize',7); box(ax,'off'); ax.FontSize=8;
ax=subplot(1,2,2); hold(ax,'on');
barm=[nanmean(sepTe5) nanmean(sepFx) nanmean(sepRd)];
bare=[nanstd(sepTe5) nanstd(sepFx) nanstd(sepRd)]/sqrt(nH);
bar(ax,1:3,barm,0.6,'FaceColor',[0.6 0.6 0.6]);
errorbar(ax,1:3,barm,bare,'k.','LineWidth',1);
set(ax,'XTick',1:3,'XTickLabel',{'独立PCA','训练域固定','随机'});
ylabel(ax,'cluster separation (d)'); title(ax,sprintf('Transfer 的 %d 维子空间分离 (n=%d)\n独立 vs 固定 p=%.3g | 固定 vs 随机 p=%.3g', rPC, nH, pTe5Fx, pFxRd));
box(ax,'off'); ax.FontSize=8;
out3 = fullfile(prjRoot,'信息编码','_figcheck','Attractor_FixedSubspace.png');
exportgraphics(f3, out3, 'Resolution', 200); fprintf('Saved: %s\n', out3);
savefig(f3, fullfile(prjRoot,'信息编码','_figcheck','Attractor_FixedSubspace.fig'));

%% 综合图 3x3：吸引子检验汇总（单张输出）
fC = figure('Name','Attractor combined','Color','w','Position',[30 30 1700 1320]);
% ---- Row1: DV 分布直方图 ----
dvT={'Cue: AO vs LO','Choice AW: hit vs miss','Choice Transfer: hit vs miss'};
dvD={zC0,zC1; zTr0,zTr1; zTe0,zTe1};
dvN={'AO','LO';'hit','miss';'hit','miss'};
dvC={[0.85 0.33 0.10],[0.70 0.30 0.70];[0.20 0.55 0.80],[0.85 0.33 0.10];[0.20 0.55 0.80],[0.85 0.33 0.10]};
dvM=[nanmean(dC) nanmean(dTr) nanmean(dTe)];
dvB=[nanmean(bcC) nanmean(bcTr) nanmean(bcTe)];
for g=1:3
    ax=subplot(3,3,g); hold(ax,'on');
    histogram(ax,dvD{g,1},'NumBins',24,'Normalization','pdf','FaceColor',dvC{g,1},'FaceAlpha',0.55,'EdgeColor','none','DisplayName',dvN{g,1});
    histogram(ax,dvD{g,2},'NumBins',24,'Normalization','pdf','FaceColor',dvC{g,2},'FaceAlpha',0.55,'EdgeColor','none','DisplayName',dvN{g,2});
    title(ax,sprintf('%s\nd''=%.2f, BC=%.3f',dvT{g},dvM(g),dvB(g)));
    xlabel(ax,'DV (z)'); ylabel(ax,'density'); legend(ax,'Box','off','FontSize',6,'Location','northeast'); box(ax,'off'); ax.FontSize=7;
end
% ---- Row2: PCA 相空间 ----
ax=subplot(3,3,4);
iPhasePanel(ax,S(rC).Xq(:,S(rC).topC,:),S(rC).yq==0,S(rC).yq==1,winLate,[0.85 0.33 0.10],[0.70 0.30 0.70],sprintf('Cue %s: AO vs LO (sep=%.2f)',S(rC).Mouse,sepC(rC==iC)));
ax=subplot(3,3,5);
iPhasePanel(ax,S(rH).Xc(:,S(rH).topCh,:),S(rH).yc==0,S(rH).yc==1,winLate,[0.85 0.33 0.10],[0.20 0.55 0.80],sprintf('Choice AW %s: hit vs miss (sep=%.2f)',S(rH).Mouse,sepTr(rH==iH)));
ax=subplot(3,3,6);
iPhasePanel(ax,S(rH).Xtr(:,S(rH).topCh,:),S(rH).ytr==0,S(rH).ytr==1,winLate,[0.85 0.33 0.10],[0.20 0.55 0.80],sprintf('Choice Trans %s: hit vs miss (sep=%.2f)',S(rH).Mouse,sepTe(rH==iH)));
% ---- Row3 ----
% (3,1) 固定子空间散点（代表鼠：Transfer 投影到训练域 PC1-2）
Xaw=mean(S(rH2).Xc(:,S(rH2).topCh,winLate),3); mu=mean(Xaw,1);
[coef2,~]=pca(Xaw,'NumComponents',2);
Xtr=mean(S(rH2).Xtr(:,S(rH2).topCh,winLate),3);
P=(Xtr-mu)*coef2; yh=S(rH2).ytr==1; ym=S(rH2).ytr==0;
ax=subplot(3,3,7); hold(ax,'on');
scatter(ax,P(ym,1),P(ym,2),14,[0.85 0.33 0.10],'filled','MarkerFaceAlpha',0.6,'DisplayName','miss');
scatter(ax,P(yh,1),P(yh,2),14,[0.20 0.55 0.80],'filled','MarkerFaceAlpha',0.6,'DisplayName','hit');
title(ax,sprintf('Transfer→训练域PC子空间 (%s)\nsep(fixed)=%.2f',S(rH2).Mouse,sepFx(rH2==iH)));
xlabel(ax,'train PC1'); ylabel(ax,'train PC2'); legend(ax,'Box','off','FontSize',6); box(ax,'off'); ax.FontSize=7;
% (3,2) 固定子空间三值汇总（同维度 5 维）
ax=subplot(3,3,8); hold(ax,'on');
barm=[nanmean(sepTe5) nanmean(sepFx) nanmean(sepRd)]; bare=[nanstd(sepTe5) nanstd(sepFx) nanstd(sepRd)]/sqrt(nH);
bar(ax,1:3,barm,0.6,'FaceColor',[0.6 0.6 0.6]); errorbar(ax,1:3,barm,bare,'k.','LineWidth',1);
set(ax,'XTick',1:3,'XTickLabel',{'独立PCA','训练固定','随机'});
title(ax,sprintf('Transfer 5维子空间 (n=%d)\n独立vs固定 p=%.3g, 固定vs随机 p=%.3g',nH,pTe5Fx,pFxRd));
ylabel(ax,'separation'); box(ax,'off'); ax.FontSize=7;
% (3,3) 上=BC 汇总，下=簇分离汇总
ax9=subplot(3,3,9); p9=ax9.Position; delete(ax9);
axA=axes(fC,'Position',[p9(1) p9(2)+0.52*p9(4) p9(3) 0.48*p9(4)]); hold(axA,'on');
bar(axA,1:3,[nanmean(bcC) nanmean(bcTr) nanmean(bcTe)],0.6,'FaceColor',[0.5 0.5 0.5]);
set(axA,'XTick',1:3,'XTickLabel',{'Cue','Ch.AW','Ch.Trans'});
yline(axA,5/9,'--','Color',[0.8 0 0]);
title(axA,'BC 双峰系数（>5/9 提示双峰）'); ylabel(axA,'BC'); box(axA,'off'); axA.FontSize=6.5;
axB=axes(fC,'Position',[p9(1) p9(2) p9(3) 0.48*p9(4)]); hold(axB,'on');
bar(axB,1:3,[nanmean(sepC) nanmean(sepTr) nanmean(sepTe)],0.6,'FaceColor',[0.5 0.5 0.5]);
set(axB,'XTick',1:3,'XTickLabel',{'Cue','Ch.AW','Ch.Trans'});
title(axB,sprintf('簇分离度 (n=%d)  Ch.AW vs Trans p=%.3g',nH,pSepLT)); ylabel(axB,'sep'); box(axB,'off'); axB.FontSize=6.5;
outC = fullfile(prjRoot,'信息编码','_figcheck','Attractor_Combined.png');
exportgraphics(fC, outC, 'Resolution', 200); fprintf('Saved: %s\n', outC);
savefig(fC, fullfile(prjRoot,'信息编码','_figcheck','Attractor_Combined.fig'));
warning on all;

% ==================== Local Functions ====================
function R = iCollect(m, DS, calBlocks, naiveAW, learnAW, testLW, nTime)
R = struct('trA',[],'trL',[],'trN',[],'trLn',[],'trTr',[]);
trA=table(); trL=table(); trN=table(); trLn=table(); trTr=table();
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=zeros(height(t),1); trA=t; end; end
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=ones(height(t),1); trL=t; end; end
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Naive'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); trN=r{1}; trN=trN(ismember(uint64(trN.BlockUID),uint64(naiveAW)),:); end
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater','Phase','Learned'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); trLn=r{1}; trLn=trLn(ismember(uint64(trLn.BlockUID),uint64(learnAW)),:); end
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); trTr=r{1}; trTr=trTr(ismember(uint64(trTr.BlockUID),uint64(testLW)),:); end
trA=iDropNaN(trA); trL=iDropNaN(trL);
trN=iDropNaN(trN); trLn=iDropNaN(trLn); trTr=iDropNaN(trTr);
R.trA=trA; R.trL=trL; R.trN=trN; R.trLn=trLn; R.trTr=trTr;
end
function t = iDropNaN(t)
if isempty(t) || ~ismember('Behavior', string(t.Properties.VariableNames)); return; end
t = t(~isnan(t.Behavior),:);
end
function [d, bc, p] = iStats(g0, g1)
g0=g0(~isnan(g0)); g1=g1(~isnan(g1));
if numel(g0)<5 || numel(g1)<5; d=nan; bc=nan; p=nan; return; end
d = (mean(g1)-mean(g0))/sqrt((var(g0)+var(g1))/2);
x = [g0; g1];
n=numel(x); g1s=skewness(x); g2=kurtosis(x);
bc = (g1s^2+1) / (g2 + 3*(n-1)^2/((n-2)*(n-3)));
[~,p] = kstest2(g0, g1);
end
function [z, z0, z1] = iZsplit(DV, g0, g1)
dv=DV(g0|g1); mu=mean(dv); sd=std(dv); if sd==0; sd=1; end
z0=(DV(g0)-mu)/sd; z1=(DV(g1)-mu)/sd; z=z0;
end
function sep = iClusterSep(X, g0, g1)
m0=mean(X(g0,:),1); m1=mean(X(g1,:),1);
d0=sqrt(sum((X(g0,:)-m0).^2,2)); d1=sqrt(sum((X(g1,:)-m1).^2,2));
r=(mean(d0)+mean(d1))/2; sep=norm(m1-m0)/(r+eps);
end
function [coef, sc] = iProj(Xw)
Xw=Xw-mean(Xw,1);
[coef, sc] = pca(Xw, 'NumComponents', 2);
end
function iPhasePanel(ax, X3, g0, g1, winLate, c0, c1, ttl)
Xw=mean(X3(:,:,winLate),3);
[coef,sc]=iProj(Xw);
hold(ax,'on');
scatter(ax,sc(g0,1),sc(g0,2),14,c0,'filled','MarkerFaceAlpha',0.6,'DisplayName','class0');
scatter(ax,sc(g1,1),sc(g1,2),14,c1,'filled','MarkerFaceAlpha',0.6,'DisplayName','class1');
iTraj(ax,X3,g0,g1,coef,c0,c1);
title(ax,ttl);
xlabel(ax,'PC1'); ylabel(ax,'PC2'); legend(ax,'Box','off','FontSize',6); box(ax,'off'); ax.FontSize=7;
end
function iTraj(ax, X3, g0, g1, coef, c0, c1)
nt = size(X3,3);
tr0 = squeeze(mean(X3(g0,:,:),1)); tr1 = squeeze(mean(X3(g1,:,:),1));
p0 = tr0'*coef(:,1:2); p1 = tr1'*coef(:,1:2);
sel = round(linspace(1,nt,min(nt,12)));
plot(ax,p0(sel,1),p0(sel,2),'o-','Color',c0,'LineWidth',1.6,'MarkerSize',4,'DisplayName','class0 avg');
plot(ax,p1(sel,1),p1(sel,2),'o-','Color',c1,'LineWidth',1.6,'MarkerSize',4,'DisplayName','class1 avg');
plot(ax,p0(1,1),p0(1,2),'ks','MarkerFaceColor','k','MarkerSize',7,'HandleVisibility','off');
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
function w = iWeight(F, y)
m0=mean(F(y==0,:),1); m1=mean(F(y==1,:),1);
s0=std(F(y==0,:),0,1); s1=std(F(y==1,:),0,1);
sp=sqrt((s0.^2+s1.^2)/2); sp(sp==0)=1;
w=(m1-m0)./sp.^2;
end
function idx = iTopIdx(w, frac)
[~,ord]=sort(abs(w),'descend'); idx=ord(1:max(1,round(frac*numel(w))));
end
