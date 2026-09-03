%% WeightHistogram.m
% 权重直方图：横轴=权重(负→正)，纵轴=细胞数量
% 三个时间口径：t=0.7s、t=1s、所有时间点权重的时间平均（每细胞：mean_t w_j(t)）
% 解码器：Cue（AO/LO 训练）与 Choice（AW Naive+Learned 训练），各一行
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
tIdxFull = find((xsSec>=-1)&(xsSec<=2)); tVec = xsSec(tIdxFull); nTfull = numel(tIdxFull);
[~,pk07]=min(abs(tVec-0.7)); [~,pk1]=min(abs(tVec-1));

Blk = DS.Blocks; Blk.Design = string(Blk.Design);
DTp = DS.DateTimes(:, {'DateTime','Mouse','Phase'}); DTp.DateTime = datetime(DTp.DateTime);
if ~isempty(DTp.DateTime.TimeZone); DTp.DateTime.TimeZone=''; end
DTp.Mouse=string(DTp.Mouse); DTp.Phase=string(DTp.Phase);
blkDT=datetime(Blk.DateTime); if ~isempty(blkDT.TimeZone); blkDT.TimeZone=''; end
php=repmat("<missing>",height(Blk),1);
for j=1:height(Blk); ix=find(DTp.DateTime==blkDT(j),1); if ~isempty(ix); php(j)=DTp.Phase(ix); end; end
Blk.Phase=php;
trainAW = Blk.BlockUID(Blk.Design=="AudioWater" & (ismember(Blk.Phase,["Naive","Learned"]) | ismissing(Blk.Phase)));
calBlocks = Blk.BlockUID(ismember(Blk.Design,["LAu","LAuW"]) & ~ismember(Blk.Phase,["Recall","Final"]));
miceAll = unique(DTp.Mouse);

% 收集所有细胞的权重（pooled across mice）
wC07=[]; wC1=[]; wCm=[];
wH07=[]; wH1=[]; wHm=[];
cueW07=cell(0,1); cueW1=cell(0,1); cueWm=cell(0,1);
chW07=cell(0,1); chW1=cell(0,1); chWm=cell(0,1);
nCue=0; nCh=0;
for iM=1:numel(miceAll)
    m=miceAll(iM);
    R = iCollect(m, DS, calBlocks, trainAW, nTime);
    trA=R.trA; trL=R.trL; tr2=R.tr2;
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    % ---- Cue ----
    if okT(trA)&&okT(trL)&&~isempty(trA)&&~isempty(trL)
        s2=[trA;trL]; cellU=uint64(unique(s2.CellUID));
        if numel(cellU)>=10
            Xq=iBuild(s2,cellU,tIdxFull); yq=iTrialLabel(s2,'Cue');
            if sum(yq==0)>=3&&sum(yq==1)>=3
                w07=iWeight(Xq(:,:,pk07),yq).';
                w1 =iWeight(Xq(:,:,pk1),yq).';
                wm=zeros(numel(cellU),1);
                for t=1:nTfull; wm=wm+iWeight(Xq(:,:,t),yq).'; end
                wm=wm/nTfull;
                wC07=[wC07; w07]; wC1=[wC1; w1]; wCm=[wCm; wm];
                cueW07{end+1}=w07; cueW1{end+1}=w1; cueWm{end+1}=wm;
                nCue=nCue+1;
            end
        end
    end
    % ---- Choice ----
    if okT(tr2)&&~isempty(tr2)
        cellC=uint64(unique(tr2.CellUID));
        if numel(cellC)>=10
            Xc=iBuild(tr2,cellC,tIdxFull); yc=iTrialLabel(tr2,'Behavior');
            if sum(yc==1)>=3&&sum(yc==0)>=3
                w07=iWeight(Xc(:,:,pk07),yc).';
                w1 =iWeight(Xc(:,:,pk1),yc).';
                wm=zeros(numel(cellC),1);
                for t=1:nTfull; wm=wm+iWeight(Xc(:,:,t),yc).'; end
                wm=wm/nTfull;
                wH07=[wH07; w07]; wH1=[wH1; w1]; wHm=[wHm; wm];
                chW07{end+1}=w07; chW1{end+1}=w1; chWm{end+1}=wm;
                nCh=nCh+1;
            end
        end
    end
end
fprintf('Cue 有效鼠=%d（%d 个细胞）；Choice 有效鼠=%d（%d 个细胞）\n', nCue, numel(wC07), nCh, numel(wH07));

%% 图 2x3：直方图
f = figure('Name','Weight histograms','Color','w','Position',[40 40 1500 700]);
rows = {'Cue decoder','Choice decoder'};
W07 = {wC07, wH07}; W1 = {wC1, wH1}; Wm = {wCm, wHm};
cols = {[0.85 0.33 0.10],[0.20 0.55 0.80]};
titles = {'t = 0.7 s','t = 1 s','all-time-point mean'};
for r=1:2
    for c=1:3
        ax=subplot(2,3,(r-1)*3+c); hold(ax,'on');
        if c==1; W=W07{r}; elseif c==2; W=W1{r}; else; W=Wm{r}; end
        histogram(ax,W,'NumBins',60,'FaceColor',cols{r},'FaceAlpha',0.7,'EdgeColor','none','Normalization','count');
        xline(ax,0,'--','Color',[0.3 0.3 0.3],'LineWidth',1);
        if c==1; ylabel(ax,'# cells'); end
        if r==1; title(ax,titles{c}); end
        if r==1; txt=sprintf('Cue (n=%d cells)', numel(W)); else; txt=sprintf('Choice (n=%d cells)', numel(W)); end
        xlabel(ax,'weight w');
        text(ax,0.99,0.95,sprintf('mean=%.3g\nmedian=%.3g\n%% w>0 = %.0f%%', nanmean(W), nanmedian(W), 100*mean(W>0)), ...
            'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top','FontSize',7);
        box(ax,'off'); ax.FontSize=8;
    end
end
figDir=fullfile(prjRoot,'信息编码','_figcheck');
if ~exist(figDir,'dir'); mkdir(figDir); end
out=fullfile(figDir,'WeightHistogram.png');
exportgraphics(f,out,'Resolution',200); fprintf('Saved: %s\n',out);
savefig(f,fullfile(figDir,'WeightHistogram.fig'));

% 数值
fprintf('\n=== 权重分布汇总 ===\n');
for r=1:2
    for c=1:3
        if c==1; W=W07{r}; elseif c==2; W=W1{r}; else; W=Wm{r}; end
        nm = rows{r};
        fprintf('%s %s: mean=%.3g median=%.3g skew=%.2f w>0=%.1f%%\n', nm, titles{c}, ...
            nanmean(W), nanmedian(W), skewness(W), 100*mean(W>0));
    end
end
fprintf('\n=== 分布形态与 top25%% 截断（pooled）===\n');
for r=1:2
    for c=1:3
        if c==1; W=W07{r}; elseif c==2; W=W1{r}; else; W=Wm{r}; end
        aW=abs(W); k=numel(W); nTop=max(1,round(0.25*k));
        [~,ord]=sort(aW,'descend'); topVals=aW(ord(1:nTop));
        fprintf('%s %s: excess-kurt=%.2f | |w|75%%分位=%.3g | top25%% mean|w|=%.3g (整体=%.3g) | top25%%占|w|总和=%.0f%%\n', ...
            rows{r}, titles{c}, kurtosis(W), aW(ord(round(0.75*k))), mean(topVals), mean(aW), 100*sum(topVals)/sum(aW));
    end
end
fprintf('\n=== 正/负组内 |w| top25%% 的均值（绝对值）===\n');
for r=1:2
    for c=1:3
        if c==1; W=W07{r}; elseif c==2; W=W1{r}; else; W=Wm{r}; end
        pos=W(W>0); neg=W(W<0);
        [~,op]=sort(abs(pos),'descend'); nP=max(1,round(0.25*numel(pos))); mP=mean(pos(op(1:nP)));
        [~,on]=sort(abs(neg),'descend'); nN=max(1,round(0.25*numel(neg))); mN=mean(abs(neg(on(1:nN))));
        fprintf('%s %s: w>0 top25%% n=%d mean|w|=%.3g | w<0 top25%% n=%d mean|w|=%.3g\n', ...
            rows{r}, titles{c}, nP, mP, nN, mN);
    end
end
fprintf('\n=== 正 vs 负 top25%% 均值：统计检验 ===\n');
for r=1:2
    if r==1; Wc={cueW07,cueW1,cueWm}; else; Wc={chW07,chW1,chWm}; end
    for c=1:3
        if c==1; W=W07{r}; elseif c==2; W=W1{r}; else; W=Wm{r}; end
        pos=W(W>0); neg=W(W<0);
        [~,pWel]=ttest2(pos,neg,'Vartype','unequal');
        pMW=ranksum(pos,neg);
        [mp,mn]=iSignTopMeans(Wc{c});
        [~,pPair]=ttest(mp,mn); pWil=signrank(mp,mn);
        fprintf('%s %s: pooled Welch p=%.3g MWU p=%.3g | per-mouse pair-t p=%.3g Wilcoxon p=%.3g (n鼠=%d)\n', ...
            rows{r}, titles{c}, pWel, pMW, pPair, pWil, numel(mp));
    end
end

%% 补充图：组内 |w| top25%（与统计检验同口径）的 1s |w| 直方图，正负双色、同侧
f2 = figure('Name','Group-top25% |w| histogram (1s, by sign)','Color','w','Position',[60 60 1050 460]);
for r=1:2
    if r==1; W=W1{1}; nm='Cue'; else; W=W1{2}; nm='Choice'; end
    pos=W(W>0); neg=W(W<0);
    [~,op]=sort(abs(pos),'descend'); nP=max(1,round(0.25*numel(pos))); aP=abs(pos(op(1:nP)));
    [~,on]=sort(abs(neg),'descend'); nN=max(1,round(0.25*numel(neg))); aN=abs(neg(on(1:nN)));
    ax=subplot(1,2,r); hold(ax,'on');
    hP=histogram(ax,aP,'NumBins',28,'FaceColor',[0.85 0.33 0.10],'FaceAlpha',0.75,'EdgeColor','none','Normalization','probability','DisplayName',sprintf('w>0 top25%% |w| (n=%d)',nP));
    hN=histogram(ax,aN,'NumBins',28,'FaceColor',[0.20 0.55 0.80],'FaceAlpha',0.75,'EdgeColor','none','Normalization','probability','DisplayName',sprintf('w<0 top25%% |w| (n=%d)',nN));
    title(ax,sprintf('%s @1s：组内 |w| top25%%',nm));
    xlabel(ax,'|w|'); ylabel(ax,'proportion');
    legend(ax,[hN hP],{sprintf('w<0 top25%% |w| (blue, n=%d)',nN),sprintf('w>0 top25%% |w| (orange, n=%d)',nP)},'Box','off','FontSize',7,'Location','northeast');
    text(ax,0.97,0.95,sprintf('mean|w|: w<0=%.3g, w>0=%.3g', mean(aN), mean(aP)), ...
        'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top','FontSize',7);
    box(ax,'off'); ax.FontSize=8;
end
out2=fullfile(figDir,'WeightHistogram_Top25_1s.png');
exportgraphics(f2,out2,'Resolution',200); fprintf('Saved: %s\n',out2);
savefig(f2,fullfile(figDir,'WeightHistogram_Top25_1s.fig'));
warning on all;

% ==================== Local Functions ====================
function R = iCollect(m, DS, calBlocks, trainAW, nTime)
R = struct('trA',[],'trL',[],'tr2',[]);
trA=table(); trL=table(); tr2=table();
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=zeros(height(t),1); trA=t; end; end
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=ones(height(t),1); trL=t; end; end
r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
if ~isempty(r)&&~isempty(r{1}); tr2=r{1}; tr2=tr2(ismember(uint64(tr2.BlockUID),uint64(trainAW)),:); end
trA=iDropNaN(trA); trL=iDropNaN(trL); tr2=iDropNaN(tr2);
R.trA=trA; R.trL=trL; R.tr2=tr2;
end
function t = iDropNaN(t)
if isempty(t) || ~ismember('Behavior', string(t.Properties.VariableNames)); return; end
t = t(~isnan(t.Behavior),:);
end
function [mp,mn] = iSignTopMeans(Wc)
nM=numel(Wc); mp=nan(nM,1); mn=nan(nM,1);
for k=1:nM
    W=Wc{k}; p=W(W>0); g=W(W<0);
    if ~isempty(p); [~,op]=sort(abs(p),'descend'); kk=max(1,round(0.25*numel(p))); mp(k)=mean(p(op(1:kk))); end
    if ~isempty(g); [~,on]=sort(abs(g),'descend'); kk=max(1,round(0.25*numel(g))); mn(k)=mean(abs(g(on(1:kk)))); end
end
end
function w = iWeight(F, y)
m0=mean(F(y==0,:),1); m1=mean(F(y==1,:),1);
s0=std(F(y==0,:),0,1); s1=std(F(y==1,:),0,1);
sp=sqrt((s0.^2+s1.^2)/2); sp(sp==0)=1;
w=(m1-m0)./sp.^2;
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
