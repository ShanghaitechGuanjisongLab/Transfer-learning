%% CellReuse_Summary.m
% 汇总各"活跃"定义下 Learned/Transfer 活跃细胞比例与复用比例（QueryNTS，0-1s 窗口，逐鼠→跨鼠平均）
prjRoot = fileparts(fileparts(mfilename('fullpath')));
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
warning off all;
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
xsSec = double(xs); nTime = numel(xs);
tIdxFull = find((xsSec>=-1)&(xsSec<=1)); tVec = xsSec(tIdxFull);
bI = find(tVec<0); sI = find((tVec>=0)&(tVec<=1));
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
miceAll=unique(DTp.Mouse);
defs = {'>0','3x','base3sd','abs1','abs2','top10','top20'};
nDef=numel(defs);
accL = nan(numel(miceAll),nDef); accT = nan(numel(miceAll),nDef); accR = nan(numel(miceAll),nDef);
mi = 0;
for iM=1:numel(miceAll)
    m=miceAll(iM);
    tr2=table(); testTbl=table();
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); t=r{1}; t=t(ismember(uint64(t.BlockUID),uint64(trainAW)),:); if ~isempty(t); tr2=t; end; end
    r=DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'),UniExp.Flags.ZScore,1:nTime,'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r)&&~isempty(r{1}); testTbl=r{1}; testTbl=testTbl(ismember(uint64(testTbl.BlockUID),uint64(testLW)),:); end
    if isempty(tr2)||isempty(testTbl)||~ismember('TrialSignal',string(tr2.Properties.VariableNames)); continue; end
    tr2=tr2(~isnan(tr2.Behavior),:); testTbl=testTbl(~isnan(testTbl.Behavior),:);
    if isempty(tr2)||isempty(testTbl); continue; end
    lr=iResp(tr2,tIdxFull,bI,sI); trR=iResp(testTbl,tIdxFull,bI,sI);
    common=intersect(lr.CellUID, trR.CellUID);
    if isempty(common); continue; end
    mi=mi+1;
    for d=1:nDef
        aL=iActive(lr,defs{d}); aT=iActive(trR,defs{d});
        nL=nnz(ismember(common,aL)); nT=nnz(ismember(common,aT));
        nR=nnz(ismember(common,intersect(aL,aT)));
        accL(mi,d)=100*nL/numel(common); accT(mi,d)=100*nT/numel(common); accR(mi,d)=100*nR/numel(common);
    end
end
accL=accL(1:mi,:); accT=accT(1:mi,:); accR=accR(1:mi,:);
fprintf('有效鼠: %d（分母 = 同鼠 common 细胞）\n', mi);
fprintf('%-8s | %14s | %14s | %10s\n','定义','Learned活跃%','Transfer活跃%','复用%');
fprintf('%s\n', repmat('-',1,56));
for d=1:nDef
    fprintf('%-8s | %5.1f±%-6.1f(%4.1f-%4.1f) | %5.1f±%-6.1f(%4.1f-%4.1f) | %5.1f±%-6.1f\n', ...
        defs{d}, mean(accL(:,d)), std(accL(:,d)), min(accL(:,d)), max(accL(:,d)), ...
        mean(accT(:,d)), std(accT(:,d)), min(accT(:,d)), max(accT(:,d)), mean(accR(:,d)), std(accR(:,d)));
end
warning on all;

function rt = iResp(rawTbl, tIdx, bI, sI)
sig=double(rawTbl.TrialSignal); sig=sig(:,tIdx);
base=mean(sig(:,bI),2); stim=mean(sig(:,sI),2);
cuid=uint64(rawTbl.CellUID);
[u,~,ic]=unique(cuid);
bm=accumarray(ic,base,[],@mean); bs=accumarray(ic,base,[],@std); sm=accumarray(ic,stim,[],@mean);
rt=table(u,bm,bs,sm,'VariableNames',{'CellUID','baseMean','baseSD','stim'});
end
function a=iActive(rt,def)
switch def
    case '>0'; a=rt.CellUID(rt.stim>0);
    case '3x'; a=rt.CellUID(rt.stim>3*rt.baseMean);
    case 'base3sd'; a=rt.CellUID(rt.stim>rt.baseMean+3*rt.baseSD);
    case 'abs1'; a=rt.CellUID(rt.stim>1);
    case 'abs2'; a=rt.CellUID(rt.stim>2);
    case 'top10'; th=prctile(rt.stim,90); a=rt.CellUID(rt.stim>=th);
    case 'top20'; th=prctile(rt.stim,80); a=rt.CellUID(rt.stim>=th);
end
end
