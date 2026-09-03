%% ChoiceTopCells_Stages.m
% Choice 解码器 top25% 权重细胞在各阶段的活动状态（prefer-hit / prefer-miss / rest）
% 阶段：AO / LO / AW-Naive / AW-Learned / Transfer
% 权重：Choice cfg2 (AudioWater Naive+Learned, hit/miss) 在 t=0.7s 的 w=(m1-m0)/sp^2，|w| 前 25%
% 符号：sign(w)>0 = prefer hit；sign(w)<0 = prefer miss
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

% 每鼠：Choice top25% + 各阶段平均轨迹
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

    % Choice cfg2 权重（训练：AudioWater Naive+Learned，标签 hit/miss）
    tr2=[trN;trLn]; cellU=uint64(unique([tr2.CellUID; trTr.CellUID]));
    if numel(cellU)<10; continue; end
    Xc=iBuild(tr2,cellU,tIdxFull); Xc=Xc-mean(Xc(:,:,bI),3);
    yc=iTrialLabel(tr2,'Behavior');
    if sum(yc==1)<3||sum(yc==0)<3; continue; end
    wCh = iWeight(Xc(:,:,pk), yc);
    topIdx = iTopIdx(wCh, 0.25);
    top = cellU(topIdx);
    topSign = sign(wCh(topIdx));   % top 细胞权重方向（+偏好hit, -偏好miss）

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

%% 分组：prefer-hit / prefer-miss / rest（各阶段）
stNames = {'AO','LO','AW-Naive','AW-Learned','Transfer'};
for s=1:5
    mTopH = nan(nMouse,nTfull); mTopM = nan(nMouse,nTfull); mRest = nan(nMouse,nTfull);
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
        inH = false(numel(u),1); inM = false(numel(u),1);
        inH(locTop(ok & sig>0)) = true;   % +偏好hit
        inM(locTop(ok & sig<0)) = true;   % -偏好miss
        inRest = ~ismember(u, S(i).top);
        if sum(inH)>=1; mTopH(i,:)=mean(A(inH,:),1,'omitnan'); end
        if sum(inM)>=1; mTopM(i,:)=mean(A(inM,:),1,'omitnan'); end
        if sum(inRest)>=1; mRest(i,:)=mean(A(inRest,:),1,'omitnan'); end
    end
    T(s).topH = mTopH; T(s).topM = mTopM; T(s).rest = mRest; %#ok<AGROW>
end

%% 图 1x5（三线：prefer-hit / prefer-miss / rest）
f = figure('Name','Choice top25% cells activity across stages','Color','w','Position',[40 40 1500 320]);
for s=1:5
    ax = subplot(1,5,s); hold(ax,'on');
    vH=T(s).topH; vM=T(s).topM; vR=T(s).rest;
    mtH=mean(vH,1,'omitnan'); stH=std(vH,0,1,'omitnan')/sqrt(sum(~isnan(vH(:,1))));
    mtM=mean(vM,1,'omitnan'); stM=std(vM,0,1,'omitnan')/sqrt(sum(~isnan(vM(:,1))));
    mr=mean(vR,1,'omitnan'); str_=std(vR,0,1,'omitnan')/sqrt(sum(~isnan(vR(:,1))));
    iShaded(ax,tVec,mr,str_,[0.65 0.65 0.65],'rest');
    iShaded(ax,tVec,mtH,stH,[0.20 0.55 0.80],'top·prefer hit');
    iShaded(ax,tVec,mtM,stM,[0.85 0.33 0.10],'top·prefer miss');
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
outfile = fullfile(figDir,'ChoiceTopCells_Stages.png');
exportgraphics(f, outfile, 'Resolution', 200);
fprintf('Saved: %s\n', outfile);

%% 统计：刺激诱发响应，分窗口（早期/中期/晚期）
wBins = {find(tVec>=0.3 & tVec<=0.96), find(tVec>0.96 & tVec<=1.5), find(tVec>1.5 & tVec<=2)};
wName = {'0.3-0.96s','0.96-1.5s','1.5-2s'};
fprintf('\n=== Choice top25%%：分窗口 hit/miss/rest（per-mouse 平均，n=%d）===\n', nMouse);
for s=1:5
    fprintf('--- %s ---\n', stNames{s});
    for wb=1:3
        rH=mean(T(s).topH(:,wBins{wb}),2,'omitnan'); rM=mean(T(s).topM(:,wBins{wb}),2,'omitnan'); rR=mean(T(s).rest(:,wBins{wb}),2,'omitnan');
        [~,pH_R]=ttest(rH-rR); [~,pM_R]=ttest(rM-rR); [~,pH_M]=ttest(rH-rM);
        fprintf('  %-10s hit=%+.3f±%.3f  miss=%+.3f±%.3f  rest=%+.3f±%.3f  (hit vs rest p=%.3g | miss vs rest p=%.3g | hit vs miss p=%.3g)\n', ...
            wName{wb}, ...
            mean(rH,'omitnan'), std(rH,0,'omitnan')/sqrt(sum(~isnan(rH))), ...
            mean(rM,'omitnan'), std(rM,0,'omitnan')/sqrt(sum(~isnan(rM))), ...
            mean(rR,'omitnan'), std(rR,0,'omitnan')/sqrt(sum(~isnan(rR))), ...
            pH_R, pM_R, pH_M);
    end
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
