%% DecoderTopWeightCells.m
% 找出 Cue / Choice 两个解码器权重绝对值前 25% 的细胞，比较其活动特点。
% 权重（naive-Gaussian 线性形式）：w_j = (m1j - m0j) / sp_j^2，取 |w| 前 25%。
% 活动轨迹：Learned = AudioWater(trainAW)，Transfer = LightWater；每细胞跨 trial 平均、基线归一化。
% 图：2x2（行=Cue/Choice，列=Learned/Transfer），top25% vs 其余细胞平均轨迹±SEM。
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
xsSec = double(xs); nTime = numel(xs);
tIdxFull = find((xsSec>=-1)&(xsSec<=2)); tVec = xsSec(tIdxFull); nTfull = numel(tVec);   % 观察至 2s
bI = find(tVec<0);
[~, pk] = min(abs(tVec - 0.7));   % 信号时点

Blk = DS.Blocks; Blk.Design = string(Blk.Design);
DTp = DS.DateTimes(:, {'DateTime','Mouse','Phase'}); DTp.DateTime = datetime(DTp.DateTime);
if ~isempty(DTp.DateTime.TimeZone); DTp.DateTime.TimeZone=''; end
DTp.Mouse=string(DTp.Mouse); DTp.Phase=string(DTp.Phase);
blkDT=datetime(Blk.DateTime); if ~isempty(blkDT.TimeZone); blkDT.TimeZone=''; end
php=repmat("<missing>",height(Blk),1);
for j=1:height(Blk); ix=find(DTp.DateTime==blkDT(j),1); if ~isempty(ix); php(j)=DTp.Phase(ix); end; end
Blk.Phase=php;
trainAW=Blk.BlockUID(Blk.Design=="AudioWater"&(ismember(Blk.Phase,["Naive","Learned"])|ismissing(Blk.Phase)));
testLW=Blk.BlockUID(Blk.Design=="LightWater"&Blk.Phase=="Transfer");
calBlocks=Blk.BlockUID(ismember(Blk.Design,["LAu","LAuW"])&~ismember(Blk.Phase,["Recall","Final"]));
miceAll=unique(DTp.Mouse);

% 收集每鼠：Cue/Choice 的 top25% 细胞 UID + Learned/Transfer 平均轨迹
TR = struct(); nMouse = 0;
for iM=1:numel(miceAll)
    m=miceAll(iM);
    tr2=table(); testTbl=table(); trA=table(); trL=table();
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(trainAW)),:); if ~isempty(t); tr2=t; end; end
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); testTbl=r{1}; testTbl=testTbl(ismember(uint64(testTbl.BlockUID),uint64(testLW)),:); end
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=zeros(height(t),1); trA=t; end; end
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(calBlocks)),:); if ~isempty(t); t.Cue=ones(height(t),1); trL=t; end; end
    if isempty(tr2)||isempty(testTbl)||isempty(trA)||isempty(trL); continue; end
    tr2=tr2(~isnan(tr2.Behavior),:); testTbl=testTbl(~isnan(testTbl.Behavior),:); trA=trA(~isnan(trA.Behavior),:); trL=trL(~isnan(trL.Behavior),:);
    if isempty(tr2)||isempty(testTbl)||isempty(trA)||isempty(trL); continue; end

    % 每细胞平均轨迹（Learned/Transfer），基线归一化
    AL = iCellAvgTrace(tr2, tIdxFull); uL = AL.u; avgL = AL.X; avgL = avgL - mean(avgL(:, bI), 2);
    AT = iCellAvgTrace(testTbl, tIdxFull); uT = AT.u; avgT = AT.X; avgT = avgT - mean(avgT(:, bI), 2);

    % ---- Cue cfg2 权重 ----
    s2=[trA;trL]; cellU=uint64(unique([s2.CellUID; testTbl.CellUID]));
    if numel(cellU)<10; continue; end
    Xq=iBuild(s2,cellU,tIdxFull); XteQ=iBuild(testTbl,cellU,tIdxFull);
    Xq=Xq-mean(Xq(:,:,bI),3); XteQ=XteQ-mean(XteQ(:,:,bI),3);
    yq=iTrialLabel(s2,'Cue'); bteQ=iTrialLabel(testTbl,'Behavior');
    if sum(yq==0)<3||sum(yq==1)<3; continue; end
    wCue = iWeight(Xq(:,:,pk), yq);   % |w| 用
    topCue = cellU( iTopIdx(wCue, 0.25) );
    % ---- Choice cfg2 权重 ----
    cellC=uint64(unique([tr2.CellUID; testTbl.CellUID]));
    if numel(cellC)<10; continue; end
    Xc=iBuild(tr2,cellC,tIdxFull); XteC=iBuild(testTbl,cellC,tIdxFull);
    Xc=Xc-mean(Xc(:,:,bI),3); XteC=XteC-mean(XteC(:,:,bI),3);
    yc=iTrialLabel(tr2,'Behavior'); bteC=iTrialLabel(testTbl,'Behavior');
    if sum(yc==1)<3||sum(yc==0)<3; continue; end
    wCh = iWeight(Xc(:,:,pk), yc);
    topCh = cellC( iTopIdx(wCh, 0.25) );

    % AO/LO 轨迹（Cue 训练任务）
    AO = iCellAvgTrace(trA, tIdxFull); uAO = AO.u; avgAO = AO.X; avgAO = avgAO - mean(avgAO(:, bI), 2);
    LO = iCellAvgTrace(trL, tIdxFull); uLO = LO.u; avgLO = LO.X; avgLO = avgLO - mean(avgLO(:, bI), 2);

    nMouse = nMouse+1;
    TR(nMouse).Mouse=m;
    TR(nMouse).topCue=topCue; TR(nMouse).topCh=topCh;
    TR(nMouse).uL=uL; TR(nMouse).avgL=avgL; TR(nMouse).uT=uT; TR(nMouse).avgT=avgT;
    TR(nMouse).uAO=uAO; TR(nMouse).avgAO=avgAO; TR(nMouse).uLO=uLO; TR(nMouse).avgLO=avgLO;
end
fprintf('有效鼠: %d\n', nMouse);

%% 分组平均轨迹：top25% vs 其余
topFrac = 0.25;
for dec = 1:2
    for stage = 1:2   % 1=Learned, 2=Transfer
        mTop = nan(nMouse, nTfull); mRest = nan(nMouse, nTfull);
        for i=1:nMouse
            if stage==1; u = TR(i).uL; A = TR(i).avgL; else; u = TR(i).uT; A = TR(i).avgT; end
            if dec==1; topU = TR(i).topCue; else; topU = TR(i).topCh; end
            inTop = ismember(u, topU);
            inAll = inTop | true(size(u));
            nTop = sum(inTop);
            % top 取该阶段实际存在的 top 细胞；rest 取该阶段非 top 细胞
            if nTop >= 1; mTop(i,:) = mean(A(inTop,:), 1, 'omitnan'); end
            if sum(~inTop) >= 1; mRest(i,:) = mean(A(~inTop,:), 1, 'omitnan'); end
        end
        TRm(dec, stage).top = mTop; TRm(dec, stage).rest = mRest; %#ok<AGROW>
    end
end

%% Cue 验证：top/rest 在训练任务 AO/LO 的轨迹
AOt = nan(nMouse,nTfull); LOt = nan(nMouse,nTfull); AOr = nan(nMouse,nTfull); LOr = nan(nMouse,nTfull);
for i=1:nMouse
    topU = TR(i).topCue;
    uA = TR(i).uAO; AA = TR(i).avgAO; uL2 = TR(i).uLO; AL = TR(i).avgLO;
    inTopA = ismember(uA, topU); inTopL = ismember(uL2, topU);
    if sum(inTopA)>=1; AOt(i,:)=mean(AA(inTopA,:),1,'omitnan'); end
    if sum(inTopL)>=1; LOt(i,:)=mean(AL(inTopL,:),1,'omitnan'); end
    if sum(~inTopA)>=1; AOr(i,:)=mean(AA(~inTopA,:),1,'omitnan'); end
    if sum(~inTopL)>=1; LOr(i,:)=mean(AL(~inTopL,:),1,'omitnan'); end
end

%% 图 2x2
f = figure('Name','Decoder top-weight cells activity','Color','w','Position',[60 60 1100 800]);
labels = {'Cue decoder','Choice decoder'};
stages = {'Learned (AudioWater)','Transfer (LightWater)'};
cols = {[0.85 0.33 0.10], [0.30 0.60 0.20]};
for dec=1:2
    for st=1:2
        ax = subplot(2,2,(dec-1)*2+st); hold(ax,'on');
        vT = TRm(dec,st).top; vR = TRm(dec,st).rest;
        mt = mean(vT,1,'omitnan'); stt = std(vT,0,1,'omitnan')/sqrt(sum(~isnan(vT(:,1))));
        mr = mean(vR,1,'omitnan'); str_ = std(vR,0,1,'omitnan')/sqrt(sum(~isnan(vR(:,1))));
        iShaded(ax, tVec, mr, str_, [0.6 0.6 0.6], 'rest');
        iShaded(ax, tVec, mt, stt, cols{dec}, sprintf('top %d%%', round(topFrac*100)));
        xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        yline(ax,0,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        title(ax, sprintf('%s · %s', labels{dec}, stages{st}));
        if st==1; ylabel(ax,'ΔF/F (z, baseline-norm)'); end
        if dec==2; xlabel(ax,'Time from stimulus (s)'); end
        legend(ax,'Location','northwest','Box','off','FontSize',8);
        box(ax,'off'); ax.FontSize = 8;
    end
end
figDir = fullfile(prjRoot,'信息编码','_figcheck');
if ~exist(figDir,'dir'); mkdir(figDir); end
outfile = fullfile(figDir,'DecoderTopWeightCells.png');
exportgraphics(f, outfile, 'Resolution', 200);
fprintf('Saved: %s\n', outfile);

%% 验证图：Cue top/rest 在训练任务 AO vs LO 的轨迹
f2 = figure('Name','Cue top-weight cells in training task (AO vs LO)','Color','w','Position',[80 80 950 420]);
ax1 = subplot(1,2,1); hold(ax1,'on');
iShaded(ax1, tVec, mean(AOr,1,'omitnan'), std(AOr,0,1,'omitnan')/sqrt(sum(~isnan(AOr(:,1)))), [0.72 0.72 0.72], 'rest AO');
iShaded(ax1, tVec, mean(LOr,1,'omitnan'), std(LOr,0,1,'omitnan')/sqrt(sum(~isnan(LOr(:,1)))), [0.55 0.55 0.55], 'rest LO');
iShaded(ax1, tVec, mean(AOt,1,'omitnan'), std(AOt,0,1,'omitnan')/sqrt(sum(~isnan(AOt(:,1)))), [0.85 0.33 0.10], 'top AO');
iShaded(ax1, tVec, mean(LOt,1,'omitnan'), std(LOt,0,1,'omitnan')/sqrt(sum(~isnan(LOt(:,1)))), [0.70 0.30 0.70], 'top LO');
xline(ax1,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off'); yline(ax1,0,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
title(ax1,'Cue top 25% cells (training task AO vs LO)'); xlabel(ax1,'Time (s)'); ylabel(ax1,'ΔF/F (z)');
legend(ax1,'Location','northwest','Box','off','FontSize',7); box(ax1,'off'); ax1.FontSize=8;
ax2 = subplot(1,2,2); hold(ax2,'on');
sIv = find(tVec>=0.3 & tVec<=0.96);
% 按细胞 |AO-LO| 分离（响应窗口）——top 混合正/负偏好，须用绝对值
absSepTop = nan(nMouse,1); absSepRest = nan(nMouse,1);
for i=1:nMouse
    uA=TR(i).uAO; AA=TR(i).avgAO; uL2=TR(i).uLO; AL=TR(i).avgLO; topU=TR(i).topCue;
    [comA, ia, il] = intersect(uA, uL2);
    if isempty(comA); continue; end
    respA = mean(AA(ia, sIv),2,'omitnan'); respL = mean(AL(il, sIv),2,'omitnan');
    as = abs(respA - respL);
    isTop = ismember(comA, topU);
    if sum(isTop)>=1; absSepTop(i)=mean(as(isTop)); end
    if sum(~isTop)>=1; absSepRest(i)=mean(as(~isTop)); end
end
mT = mean(absSepTop,'omitnan'); mR = mean(absSepRest,'omitnan');
sT = std(absSepTop,0,'omitnan')/sqrt(sum(~isnan(absSepTop))); sR = std(absSepRest,0,'omitnan')/sqrt(sum(~isnan(absSepRest)));
bar(ax2, [1 2], [mT mR], 0.6, 'FaceColor',[0.6 0.6 0.6]);
errorbar(ax2, [1 2], [mT mR], [sT sR], 'k','LineStyle','none');
set(ax2,'XTick',[1 2],'XTickLabel',{'top 25%','rest'});
ylabel(ax2,'|AO−LO| separation (0.3-0.96s)'); title(ax2,'Cue: separation in training task');
box(ax2,'off'); ax2.FontSize=8;
out2 = fullfile(figDir,'CueTopCells_AOLO.png');
exportgraphics(f2, out2, 'Resolution', 200);
fprintf('Saved: %s\n', out2);
fprintf('Cue |AO-LO| 分离(0.3-0.96s): top=%.3f±%.3f, rest=%.3f±%.3f\n', mT, sT, mR, sR);

%% 活动特点统计（top vs rest 的刺激诱发响应，Learned/Transfer）
fprintf('\n=== 活动特点（刺激诱发响应 0.3-0.96s 均值，跨鼠 mean±SEM）===\n');
for dec=1:2
    fprintf('%s: ', labels{dec});
    for st=1:2
        vT = TRm(dec,st).top; vR = TRm(dec,st).rest;
        sI = find(tVec>=0.3 & tVec<=0.96);
        rT = mean(vT(:,sI),2,'omitnan'); rR = mean(vR(:,sI),2,'omitnan');
        fprintf('%s top=%.3f±%.3f rest=%.3f±%.3f | ', stages{st}, mean(rT,'omitnan'), std(rT,0,'omitnan')/sqrt(sum(~isnan(rT))), mean(rR,'omitnan'), std(rR,0,'omitnan')/sqrt(sum(~isnan(rR))));
    end
    fprintf('\n');
end
warning on all;

% ==================== Local Functions ====================
function w = iWeight(F, y)
m0 = mean(F(y==0,:),1); m1 = mean(F(y==1,:),1);
s0 = std(F(y==0,:),0,1); s1 = std(F(y==1,:),0,1);
sp = sqrt((s0.^2+s1.^2)/2); sp(sp==0)=1;
w = (m1-m0)./sp.^2;
end
function idx = iTopIdx(w, frac)
[~, ord] = sort(abs(w), 'descend');
idx = ord(1:max(1, round(frac*numel(w))));
end
function R = iCellAvgTrace(rawTbl, tIdx)
sig = double(rawTbl.TrialSignal); sig = sig(:, tIdx);
cuid = uint64(rawTbl.CellUID);
[u, ~, ic] = unique(cuid);
nT = size(sig,2);
X = nan(numel(u), nT);
for c=1:numel(u)
    rows = sig(ic==c, :);
    X(c,:) = mean(rows,1,'omitnan');
end
R.u = u; R.X = X;
end
function iShaded(ax, x, mn, se, col, dn)
x=x(:)'; mn=mn(:)'; se=se(:)';
ok = ~isnan(mn) & ~isnan(se); x=x(ok); mn=mn(ok); se=se(ok);
if isempty(x); return; end
fill(ax,[x fliplr(x)],[mn+se fliplr(mn-se)],col,'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
plot(ax,x,mn,'-','Color',col,'LineWidth',1.8,'DisplayName',dn);
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
