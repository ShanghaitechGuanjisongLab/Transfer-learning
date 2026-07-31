%% CueModel.m
% 钙信号能否编码 cue（听觉刺激）？— 仿 Runyan et al. 2017 解码框架
%
% 数据: AudioLightBaseline, AudioWater Learned 阶段
% 问题: Learned 阶段所有 trial 均为 hit，无法做 hit/miss 解码。
% 思路: 检测群体活动在刺激前后是否发生可靠变化。
%       对每个 trial，计算 pre-window (-1~0s) 和 post-window (0~1s) 的
%       平均群体活动向量，训练 LASSO 逻辑回归区分"刺激前" vs "刺激后"。
%       若解码显著 > 50%，说明钙信号编码了 cue。

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
rng(42);

%% 1. Load data
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end

%% 2. Time windows
tPre  = (xs >= -1) & (xs <= 0);
tPost = (xs >= 0)  & (xs <= 1);
fprintf('Pre: %.2f-%.2fs  Post: %.2f-%.2fs\n', ...
    xs(find(tPre,1)), xs(find(tPre,1,'last')), ...
    xs(find(tPost,1)), xs(find(tPost,1,'last')));

%% 3. Per-mouse: select Learned AudioWater trials
Blk = DS.Blocks;
Blk.BlockUID = uint64(Blk.BlockUID);
Blk.DateTime = datetime(Blk.DateTime);
if ~isempty(Blk.DateTime.TimeZone); Blk.DateTime.TimeZone = ''; end
Blk.Mouse = strings(height(Blk), 1);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse); DT.Phase = string(DT.Phase);
[~, idxDt] = ismember(Blk.DateTime, DT.DateTime);
Blk.Mouse(idxDt>0) = DT.Mouse(idxDt(idxDt>0));
Blk.Phase = strings(height(Blk),1);
for i=1:height(Blk); if idxDt(i); Blk.Phase(i)=DT.Phase(idxDt(i)); end; end

Tr = DS.Trials;
Tr.BlockUID = uint64(Tr.BlockUID);
Tr.Stimulus = string(Tr.Stimulus);

mice = unique(DT.Mouse);
selData = struct('Mouse',cell(numel(mice),1),'DateTime',[],'TrainUIDs',[],'ValUIDs',[]);
nValid = 0;
for iM = 1:numel(mice)
    m = mice(iM);
    blkId = find(Blk.Mouse==m & Blk.Phase=="Learned");
    blks = Blk(blkId,:);
    hasAW = false(height(blks),1);
    for iB=1:height(blks); hasAW(iB)=any(Tr.Stimulus(Tr.BlockUID==blks.BlockUID(iB))=="AudioWater"); end
    blks = blks(hasAW,:);
    if isempty(blks); continue; end
    allU = [];
    for iB=1:height(blks)
        tr = Tr(Tr.BlockUID==blks.BlockUID(iB) & Tr.Stimulus=="AudioWater" & ~isnan(double(Tr.Behavior)),:);
        allU = [allU; unique(uint64(tr.TrialUID))]; %#ok<AGROW>
    end
    if numel(allU)<30; continue; end
    rng(iM); p=randperm(numel(allU));
    nValid=nValid+1;
    selData(nValid).Mouse=m; selData(nValid).DateTime=blks.DateTime(1);
    selData(nValid).TrainUIDs=allU(p(1:20)); selData(nValid).ValUIDs=allU(p(21:30));
end
selData=selData(1:nValid);
fprintf('Valid mice: %d\n', nValid);
if nValid==0; return; end

%% 4. Window-average pre-vs-post decoding
nMice = nValid;
decAcc = nan(nMice, 1);
decPval = nan(nMice, 1);
nCells = nan(nMice, 1);

for iM = 1:nMice
    s = selData(iM);
    q = struct('Mouse',s.Mouse, 'DateTime',s.DateTime, 'Stimulus',"AudioWater");
    resp = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:numel(xs), 'ExtraColumns',["Behavior","DateTime"]);
    if isempty(resp)||isempty(resp{1}); continue; end
    tbl = resp{1};
    if ~ismember('TrialSignal',string(tbl.Properties.VariableNames)); continue; end
    
    uid = uint64(tbl.TrialUID);
    trTbl = tbl(ismember(uid,s.TrainUIDs),:);
    vlTbl = tbl(ismember(uid,s.ValUIDs),:);
    if height(trTbl)<20 || height(vlTbl)<10; continue; end
    
    cu = uint64(unique([tbl.CellUID; tbl.CellUID]));
    nC = numel(cu); if nC<5; continue; end
    nCells(iM) = nC;
    
    [XTr,~] = iBuildTrialMatrix(trTbl,cu,[]);
    [XVl,~] = iBuildTrialMatrix(vlTbl,cu,[]);
    nTr=size(XTr,1); nVl=size(XVl,1);
    
    % Average activity in pre vs post window
    preTr = mean(XTr(:,:,tPre),3);  postTr = mean(XTr(:,:,tPost),3);
    preVl = mean(XVl(:,:,tPre),3);  postVl = mean(XVl(:,:,tPost),3);
    
    % Train: pre=0, post=1
    xTrAll = [preTr; postTr]; yTrAll = [zeros(nTr,1); ones(nTr,1)];
    xVlAll = [preVl; postVl]; yVlAll = [zeros(nVl,1); ones(nVl,1)];
    
    mu=mean(xTrAll,1); sd=std(xTrAll,0,1); sd(sd==0)=1;
    xTrS=(xTrAll-mu)./sd; xTrS(isnan(xTrS))=0;
    xVlS=(xVlAll-mu)./sd; xVlS(isnan(xVlS))=0;
    
    lam = 0.02/sqrt(nTr*2);
    try; mdl=fitclinear(xTrS,yTrAll,'Learner','logistic','Regularization','lasso','Lambda',lam);
    catch; continue; end
    
    acc = mean(predict(mdl,xVlS)==yVlAll);
    
    % Permutation test
    sa=zeros(200,1);
    for iS=1:200
        sy=yTrAll(randperm(nTr*2));
        try; sm=fitclinear(xTrS,sy,'Learner','logistic','Regularization','lasso','Lambda',lam);
            sa(iS)=mean(predict(sm,xVlS)==yVlAll);
        catch; sa(iS)=0.5; end
    end
    pv = (sum(sa>=acc)+1)/201;
    
    decAcc(iM)=acc; decPval(iM)=pv;
    fprintf('%s: cells=%d Acc=%.1f%% (p=%.4f)%s\n', ...
        s.Mouse, nC, acc*100, pv, iif(pv<0.05,' *',''));
end

%% 5. Summary
fprintf('\n=== Summary ===\n');
validM = ~isnan(decAcc);
fprintf('Valid: %d/%d mice\n', sum(validM), nMice);
for iM=find(validM)'
    fprintf('  %s: cells=%.0f Acc=%.1f%% (p=%.4f)%s\n', ...
        selData(iM).Mouse, nCells(iM), decAcc(iM)*100, decPval(iM), ...
        iif(decPval(iM)<0.05,' *',''));
end
fprintf('Mean Acc: %.1f%%  Significant: %d/%d\n', ...
    mean(decAcc(validM))*100, sum(decPval(validM)<0.05), sum(validM));

%% 6. Figure
if ~any(validM); return; end
vals = decAcc(validM)*100;

f = figure('Name','CueModel','Color','w','Position',[150 150 300 320]);
ax = axes(f); hold(ax,'on');
bar(ax,1,mean(vals),'FaceColor',[0.6 0.6 0.6],'FaceAlpha',0.7,'EdgeColor','none','BarWidth',0.4);
scatter(ax, ones(sum(validM),1), vals, 36, [0 0 0], 'filled','jitter','on','jitterAmount',0.08);
yline(ax,50,':','Color',[0.3 0.3 0.3],'LineWidth',0.8);
hold(ax,'off');
ylabel(ax,'Decoding accuracy (%)');
title(ax,sprintf('Cue encoding (pre vs post, n=%d)',sum(validM)),'FontSize',9);
set(ax,'XTick',1,'XTickLabel',{'Pre vs Post'}); xlim(ax,[0.5 1.5]); ylim(ax,[30 100]);
ax.FontSize=8; box(ax,'off');
text(ax,1.15,mean(vals),sprintf('%.1f%%',mean(vals)),'FontSize',7,'Color',[0.3 0.3 0.3]);

TransferLearning.ExportStandardFigure(f,2,'CueModel_Result.svg');
fprintf('Done.\n');


% ==================== Local Functions ====================
function [X, y] = iBuildTrialMatrix(rawTbl, cellUIDs, ~)
sig = double(rawTbl.TrialSignal);
nTime = size(sig,2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID),'VariableNames',{'CellUID','TrialUID'});
sc = cell(size(sig,1),1);
for i=1:size(sig,1); sc{i}=sig(i,:); end
ntsTbl.Signal = sc;
keep = ismember(ntsTbl.CellUID, cellUIDs);
ntsTbl = ntsTbl(keep,:);
if isempty(ntsTbl); X=[]; y=[]; return; end
tuid = unique(ntsTbl.TrialUID);
nT = numel(tuid); nC = numel(cellUIDs);
X = zeros(nT,nC,nTime);
for iT=1:nT
    r = ntsTbl(ntsTbl.TrialUID==tuid(iT),:);
    [~,loc]=ismember(r.CellUID,cellUIDs);
    for iR=1:height(r); ci=loc(iR); if ci>0; X(iT,ci,:)=r.Signal{iR}; end; end
end
X(isnan(X))=0; y=[];
end

function s = iif(c,a,b)
if c; s=a; else; s=b; end
end