%% CueTopCells_Stages.m
% Cue 解码器 top25% 权重细胞在各阶段的活动状态（top vs rest）
% 阶段：AO / LO / AW-Naive / AW-Learned / Transfer
% 权重：Cue cfg2 (AO+LO) 在 t=0.7s 的 w=(m1-m0)/sp^2，|w| 前 25%
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
tIdxFull = find((xsSec>=-1)&(xsSec<=2)); tVec = xsSec(tIdxFull); nTfull = numel(tVec); bI = find(tVec<0);
[~, pk] = min(abs(tVec - 0.7));

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

% 每鼠：Cue top25% + 各阶段平均轨迹
S = struct('Mouse', {}, 'top', {}); nMouse = 0;
for iM=1:numel(miceAll)
    m=miceAll(iM);
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
    okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
    if ~okT(trA)||~okT(trL)||~okT(trN)||~okT(trLn)||~okT(trTr); continue; end
    trA=trA(~isnan(trA.Behavior),:); trL=trL(~isnan(trL.Behavior),:);
    trN=trN(~isnan(trN.Behavior),:); trLn=trLn(~isnan(trLn.Behavior),:); trTr=trTr(~isnan(trTr.Behavior),:);
    if isempty(trA)||isempty(trL)||isempty(trN)||isempty(trLn)||isempty(trTr); continue; end

    % Cue cfg2 权重
    s2=[trA;trL]; cellU=uint64(unique([s2.CellUID; trTr.CellUID]));
    if numel(cellU)<10; continue; end
    Xq=iBuild(s2,cellU,tIdxFull); Xq=Xq-mean(Xq(:,:,bI),3);
    yq=iTrialLabel(s2,'Cue');
    if sum(yq==0)<3||sum(yq==1)<3; continue; end
    w = iWeight(Xq(:,:,pk), yq);
    topIdx = iTopIdx(w, 0.25);
    top = cellU(topIdx);
    topSign = sign(w(topIdx));   % top 细胞权重方向（+偏好light, -偏好audio）

    nMouse = nMouse+1;
    S(nMouse).Mouse=m; S(nMouse).top=top; S(nMouse).topSign=topSign;
    % 各阶段平均轨迹
    R = iCellAvgTrace(trA, tIdxFull); S(nMouse).AOu=R.u; S(nMouse).AO=R.X-mean(R.X(:,bI),2);
    R = iCellAvgTrace(trL, tIdxFull); S(nMouse).LOu=R.u; S(nMouse).LO=R.X-mean(R.X(:,bI),2);
    R = iCellAvgTrace(trN, tIdxFull); S(nMouse).Nu=R.u; S(nMouse).Nv=R.X-mean(R.X(:,bI),2);
    R = iCellAvgTrace(trLn, tIdxFull); S(nMouse).Lnu=R.u; S(nMouse).Lv=R.X-mean(R.X(:,bI),2);
    R = iCellAvgTrace(trTr, tIdxFull); S(nMouse).Tu=R.u; S(nMouse).Tv=R.X-mean(R.X(:,bI),2);
end
S = S(1:nMouse);
fprintf('有效鼠: %d\n', nMouse);

%% 分组：top vs rest（各阶段）
stNames = {'AO','LO','AW-Naive','AW-Learned','Transfer'};
for s=1:5
    mTop = nan(nMouse,nTfull); mRest = nan(nMouse,nTfull);
    for i=1:nMouse
        switch s
            case 1; u=S(i).AOu; A=S(i).AO;
            case 2; u=S(i).LOu; A=S(i).LO;
            case 3; u=S(i).Nu; A=S(i).Nv;
            case 4; u=S(i).Lnu; A=S(i).Lv;
            case 5; u=S(i).Tu; A=S(i).Tv;
        end
        [~, locTop] = ismember(S(i).top, u);
        sig = S(i).topSign(:); ok = locTop(:)>0;
        inTop = ismember(u, S(i).top);
        inPA = false(numel(u),1); inPL = false(numel(u),1);
        inPA(locTop(ok & sig<0)) = true;
        inPL(locTop(ok & sig>0)) = true;
        if sum(inTop)>=1; mTop(i,:)=mean(A(inTop,:),1,'omitnan'); end
        if sum(inPA)>=1; mTopPA(i,:)=mean(A(inPA,:),1,'omitnan'); end
        if sum(inPL)>=1; mTopPL(i,:)=mean(A(inPL,:),1,'omitnan'); end
        if sum(~inTop)>=1; mRest(i,:)=mean(A(~inTop,:),1,'omitnan'); end
    end
    T(s).top = mTop; T(s).topPA = mTopPA; T(s).topPL = mTopPL; T(s).rest = mRest; %#ok<AGROW>
end

%% 图 1x5
f = figure('Name','Cue top25% cells activity across stages','Color','w','Position',[40 40 1500 320]);
for s=1:5
    ax = subplot(1,5,s); hold(ax,'on');
    vPA=T(s).topPA; vPL=T(s).topPL; vR=T(s).rest;
    mtPA=mean(vPA,1,'omitnan'); stPA=std(vPA,0,1,'omitnan')/sqrt(sum(~isnan(vPA(:,1))));
    mtPL=mean(vPL,1,'omitnan'); stPL=std(vPL,0,1,'omitnan')/sqrt(sum(~isnan(vPL(:,1))));
    mr=mean(vR,1,'omitnan'); str_=std(vR,0,1,'omitnan')/sqrt(sum(~isnan(vR(:,1))));
    iShaded(ax,tVec,mr,str_,[0.65 0.65 0.65],'rest');
    iShaded(ax,tVec,mtPA,stPA,[0.85 0.33 0.10],'top·prefer audio');
    iShaded(ax,tVec,mtPL,stPL,[0.70 0.30 0.70],'top·prefer light');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    yline(ax,0,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    title(ax,stNames{s});
    if s==1; ylabel(ax,'ΔF/F (z)'); end
    xlabel(ax,'Time (s)');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize=8;
end
figDir = fullfile(prjRoot,'信息编码','_figcheck');
if ~exist(figDir,'dir'); mkdir(figDir); end
outfile = fullfile(figDir,'CueTopCells_Stages.png');
exportgraphics(f, outfile, 'Resolution', 200);
fprintf('Saved: %s\n', outfile);

%% 拆分图：top 按权重方向，在 AO/LO 的轨迹（直观展示类间判别）
f2 = figure('Name','Cue top cells by weight sign (AO/LO)','Color','w','Position',[60 60 1000 380]);
for st = 1:2
    mTa = nan(nMouse,nTfull); mTl = nan(nMouse,nTfull); mR = nan(nMouse,nTfull);
    for i=1:nMouse
        if st==1; u=S(i).AOu; A=S(i).AO; else; u=S(i).LOu; A=S(i).LO; end
        [~, locTop] = ismember(S(i).top, u);
        ok = (locTop(:) > 0); sig = S(i).topSign(:);
        neg = sig < 0; pos = sig > 0;
        pa = locTop(ok & neg); pl = locTop(ok & pos);
        if ~isempty(pa); mTa(i,:)=mean(A(pa,:),1,'omitnan'); end
        if ~isempty(pl); mTl(i,:)=mean(A(pl,:),1,'omitnan'); end
        rp = find(~ismember(u, S(i).top));
        if ~isempty(rp); mR(i,:)=mean(A(rp,:),1,'omitnan'); end
    end
    ax = subplot(1,2,st); hold(ax,'on');
    iShaded(ax,tVec,mean(mR,1,'omitnan'),std(mR,0,1,'omitnan')/sqrt(sum(~isnan(mR(:,1)))),[0.65 0.65 0.65],'rest');
    iShaded(ax,tVec,mean(mTa,1,'omitnan'),std(mTa,0,1,'omitnan')/sqrt(sum(~isnan(mTa(:,1)))),[0.85 0.33 0.10],'top·prefer audio');
    iShaded(ax,tVec,mean(mTl,1,'omitnan'),std(mTl,0,1,'omitnan')/sqrt(sum(~isnan(mTl(:,1)))),[0.70 0.30 0.70],'top·prefer light');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    yline(ax,0,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    if st==1; title(ax,'AO (audio only)'); else; title(ax,'LO (light only)'); end
    if st==1; ylabel(ax,'ΔF/F (z)'); end
    xlabel(ax,'Time (s)');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize=8;
    % 统计：刺激窗(0.3-0.96s) per-mouse 平均活性
    wIdx = find(tVec>=0.3 & tVec<=0.96);
    a_pa = mean(mTa(:,wIdx),2,'omitnan');
    a_pl = mean(mTl(:,wIdx),2,'omitnan');
    a_r  = mean(mR(:,wIdx),2,'omitnan');
    if st==1; nm='AO'; else; nm='LO'; end
    fprintf('\n=== %s 刺激窗(0.3-0.96s) top按方向拆分 ===\n', nm);
    fprintf('prefer-audio top: %.3f ± %.3f (n=%d)\n', mean(a_pa,'omitnan'), std(a_pa,'omitnan')/sqrt(sum(~isnan(a_pa))), sum(~isnan(a_pa)));
    fprintf('prefer-light top: %.3f ± %.3f (n=%d)\n', mean(a_pl,'omitnan'), std(a_pl,'omitnan')/sqrt(sum(~isnan(a_pl))), sum(~isnan(a_pl)));
    fprintf('rest            : %.3f ± %.3f (n=%d)\n', mean(a_r,'omitnan'), std(a_r,'omitnan')/sqrt(sum(~isnan(a_r))), sum(~isnan(a_r)));
    [~,p_pa_r] = ttest(a_pa - a_r); [~,p_pl_r] = ttest(a_pl - a_r);
    [~,p_pa_pl] = ttest(a_pa - a_pl);
    fprintf('paired t: prefer-audio vs rest p=%.3g | prefer-light vs rest p=%.3g | pa vs pl p=%.3g\n', p_pa_r, p_pl_r, p_pa_pl);
end
out2 = fullfile(figDir,'CueTopCells_AO_LO_bySign.png');
exportgraphics(f2, out2, 'Resolution', 200);
fprintf('Saved: %s\n', out2);

%% 统计：刺激诱发响应 top vs rest
sIv = find(tVec>=0.3 & tVec<=0.96);
fprintf('\n=== Cue top25%% vs rest：刺激诱发响应(0.3-0.96s) ===\n');
for s=1:5
    rT = mean(T(s).top(:,sIv),2,'omitnan'); rR = mean(T(s).rest(:,sIv),2,'omitnan');
    fprintf('%-12s top=%.3f±%.3f  rest=%.3f±%.3f\n', stNames{s}, ...
        mean(rT,'omitnan'), std(rT,0,'omitnan')/sqrt(sum(~isnan(rT))), ...
        mean(rR,'omitnan'), std(rR,0,'omitnan')/sqrt(sum(~isnan(rR))));
end
warning on all;

% ==================== Local Functions ====================
function w = iWeight(F, y)
m0=mean(F(y==0,:),1); m1=mean(F(y==1,:),1);
s0=std(F(y==0,:),0,1); s1=std(F(y==1,:),0,1);
sp=sqrt((s0.^2+s1.^2)/2); sp(sp==0)=1;
w=(m1-m0)./sp.^2;
end
function idx = iTopIdx(w, frac)
[~,ord]=sort(abs(w),'descend'); idx=ord(1:max(1,round(frac*numel(w))));
end
function R = iCellAvgTrace(rawTbl, tIdx)
sig=double(rawTbl.TrialSignal); sig=sig(:,tIdx);
cuid=uint64(rawTbl.CellUID); [u,~,ic]=unique(cuid); nT=size(sig,2);
X=nan(numel(u),nT);
for c=1:numel(u); X(c,:)=mean(sig(ic==c,:),1,'omitnan'); end
R.u=u; R.X=X;
end
function iShaded(ax,x,mn,se,col,dn)
x=x(:)'; mn=mn(:)'; se=se(:)';
ok=~isnan(mn)&~isnan(se); x=x(ok); mn=mn(ok); se=se(ok);
if isempty(x); return; end
fill(ax,[x fliplr(x)],[mn+se fliplr(mn-se)],col,'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
plot(ax,x,mn,'-','Color',col,'LineWidth',1.8,'DisplayName',dn);
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
