% 探查 v2（修正版）：Naive 队列改用 Fig3B 的 iGatherNaiveSessions 口径（Naive 期实际会话，
% 排除含 AudioWater 会话，不要求 Final 标记），Transfer 用 Transfer→Final。
% 学习速度用英文图1C 的 penalized sigmoid（FitPenalizedSigmoid, FixLowerZero=true，逐 trial，
% 会话序号作 block）；异质性沿用 pre-ceiling、|z|<=1、分层。按鼠对齐后算相关。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_T = TransferLearning.AudioLightBaseline();
xsSec = seconds(TransferLearning.Xs);
[~, idx1s] = min(abs(xsSec - 1.0));

% ---- Naive：Fig3B 口径的会话（含 Source 标记 LAB/LAI）----
NaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
NaiveSess = iExcludeAudioWaterSessions(NaiveSess, DS_LAB, DS_LAI);
% ---- Transfer：ALB Transfer→Final ----
TransferSess = iLightWaterSessions(DS_T);
TransferSess = iKeepPureLW_NoMustWarn(DS_T, TransferSess);
TransferSess = iKeepPhaseRange(DS_T, TransferSess, "Transfer", "Final");

% ---- 斜率 + 异质性：Naive ----
[NK, Nsd23, Nsd5, NM] = iSlopeAndHet(NaiveSess, DS_LAB, DS_LAI, idx1s);
% ---- 斜率 + 异质性：Transfer ----
[TK, Tsd23, Tsd5, TM] = iSlopeAndHet(TransferSess, DS_T, [], idx1s);

fprintf('Naive: n=%d, Transfer: n=%d\n', numel(NM), numel(TM));
for iL = 1:2
	if iL==1, sdN=Nsd23; sdT=Tsd23; else, sdN=Nsd5; sdT=Tsd5; end
	sdAll=[sdN;sdT]; kAll=[NK;TK];
	use = isfinite(sdAll)&isfinite(kAll);
	if nnz(use)>=3 && std(sdAll(use))>0 && std(kAll(use))>0
		[rho,p]=corr(sdAll(use),kAll(use),'Type','Spearman');
	else, rho=NaN;p=NaN; end
	fprintf('%s: n=%d (Naive %d + Transfer %d), Spearman rho=%.3f, p=%.4g\n', ...
		iif(iL==1,'L23','L5'), nnz(use), sum(isfinite(sdN)&isfinite(NK)), sum(isfinite(sdT)&isfinite(TK)), rho, p);
end
assignin('base','PenalizedSlopeHet_v2', struct('Naive',table(NM,NK,Nsd23,Nsd5,'VariableNames',{'Mouse','Slope','L23','L5'}), ...
	'Transfer',table(TM,TK,Tsd23,Tsd5,'VariableNames',{'Mouse','Slope','L23','L5'})));

function out = iif(c,a,b), if c, out=a; else, out=b; end; end

function [K, sd23, sd5, M] = iSlopeAndHet(Sess, DS1, DS2, idx1s)
% 斜率与异质性独立筛选（Fig3B 口径）：
%   斜率 = 该鼠全部会话的逐 trial penalized sigmoid（完整学习曲线，含学满前后）；
%   异质性 = pre-ceiling 会话（Performance<1）内 |z|<=1 细胞的 across-cell SD。
M = unique(string(Sess.Mouse));
K = nan(numel(M),1); sd23=nan(numel(M),1); sd5=nan(numel(M),1);
for iM = 1:numel(M)
	m = M(iM);
	R = sortrows(Sess(string(Sess.Mouse)==m,:),'DateTime');
	perf = double(R.Performance);
	finiteR = isfinite(perf);
	Rall = R(finiteR,:);          % 斜率用全部会话
	perfAll = perf(finiteR);
	% ---- 斜率：全部会话（不要求 pre-ceiling）----
	if height(Rall) >= 2 && numel(unique(perfAll)) >= 2
		[block, beh, ok] = iTrialsForMouse(Rall, DS1, DS2);
		if ok
			try
				fit = TransferLearning.FitPenalizedSigmoid(block, beh, FixLowerZero=true);
				if ~fit.AtSlopeBoundary, K(iM)=fit.Slope; end
			catch
			end
		end
	end
	% ---- 异质性：pre-ceiling 会话 ----
	Rhet = Rall;
	first100 = find(perfAll>=1.0,1,'first');
	if ~isempty(first100) && first100>1
		Rhet = Rall(1:first100-1,:);
	elseif ~isempty(first100) && first100==1
		Rhet = Rall([],:);   % 首个即学满：无异质性
	end
	if height(Rhet) >= 2
		[sd23(iM), sd5(iM)] = iMouseLayerSD(Rhet, DS1, DS2, idx1s);
	end
end
end

function [block, beh, ok] = iTrialsForMouse(R, DS1, DS2)
block=[]; beh=[]; ok=false;
for d=1:2
	if d==1, DS=DS1; else, DS=DS2; end
	if isempty(DS), continue; end
	% 该鼠在 R 里属于哪个 DS（Naive 有 Source；Transfer 只有 DS1）
	if ismember('Source',R.Properties.VariableNames)
		srcName = iif(d==1,"LAB","LAI");
		Rd = R(string(R.Source)==srcName,:);
	else
		Rd = R;
	end
	if isempty(Rd), continue; end
	T = DS.TableQuery(["Mouse","DateTime","TrialUID","Behavior","Stimulus"]);
	T.Mouse=string(T.Mouse); T.Stimulus=string(T.Stimulus);
	T.DateTime=datetime(T.DateTime);
	if ~isempty(T.DateTime.TimeZone), T.DateTime.TimeZone=''; end
	T = T(T.Stimulus=="LightWater" & ismember(T.DateTime, Rd.DateTime),:);
	if isempty(T), continue; end
	dts = sort(Rd.DateTime);
	for j=1:numel(dts)
		rows = T.DateTime==dts(j);
		block = [block; repmat(j,sum(rows),1)]; %#ok<AGROW>
		beh = [beh; double(T.Behavior(rows))]; %#ok<AGROW>
	end
end
ok = numel(block)>=2 && numel(unique(block))>=2 && any(isfinite(beh));
if ok
	finite = isfinite(beh); block=block(finite); beh=beh(finite);
	ok = numel(unique(block))>=2;
end
end

function [sd23,sd5] = iMouseLayerSD(R, DS1, DS2, idx1s)
sd23=NaN; sd5=NaN;
allZ = []; allLayer = strings(0,1);
for d=1:2
	if d==1, DS=DS1; else, DS=DS2; end
	if isempty(DS), continue; end
	if ismember('Source',R.Properties.VariableNames)
		srcName = iif(d==1,"LAB","LAI");
		Rd = R(string(R.Source)==srcName,:);
	else
		Rd = R;
	end
	if isempty(Rd), continue; end
	try, nts = DS.QueryNTS(struct('Stimulus','LightWater','DateTime',Rd.DateTime), UniExp.Flags.ZScore, 1:24); catch, continue; end
	if iscell(nts), nts=nts{1}; end
	if isempty(nts), continue; end
	nts.CellUID=uint64(nts.CellUID);
	sig = double(nts.TrialSignal);
	z = sig(:,idx1s);
	[G,cid]=findgroups(nts.CellUID);
	med = splitapply(@(x) median(x,'omitnan'),z,G);
	CellTbl = DS.Cells; CellTbl.CellUID=uint64(CellTbl.CellUID); CellTbl.ZLayer=string(CellTbl.ZLayer);
	[~,loc]=ismember(cid,CellTbl.CellUID);
	layers = CellTbl.ZLayer(loc);
	allZ=[allZ;med]; allLayer=[allLayer;layers]; %#ok<AGROW>
end
v23 = allZ(allLayer=="MOp2/3"); v5 = allZ(allLayer=="MOp5");
v23 = v23(isfinite(v23)&abs(v23)<=1); v5 = v5(isfinite(v5)&abs(v5)<=1);
if numel(v23)>=3, sd23=std(v23); end
if numel(v5)>=3, sd5=std(v5); end
end

% ---- Fig3B 的 Naive 会话口径 ----
function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','DateTime','Performance','Source'});
for iDS = 1:2
	if iDS==1, DS=LAB; srcName="LAB"; else, DS=LAI; srcName="LAI"; end
	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse=string(T.Mouse); T.Phase=string(T.Phase);
	T.DateTime=datetime(T.DateTime);
	if ~isempty(T.DateTime.TimeZone), T.DateTime.TimeZone=''; end
	Tr = DS.Trials;
	for m = unique(T.Mouse)'
		Tm = T(T.Mouse==m,:);
		phases = unique(Tm.Phase);
		if ~any(phases=="Naive"), continue; end
		hasLearned = any(phases=="Learned"); hasTransfer = any(phases=="Transfer");
		sessDTs = sort(unique(Tm.DateTime));
		sessPhase = strings(numel(sessDTs),1);
		for ii=1:numel(sessDTs)
			ph = Tm.Phase(Tm.DateTime==sessDTs(ii));
			ph = ph(ph~="" & ~ismissing(ph));
			if isempty(ph), sessPhase(ii)=""; continue; end
			[uPh,~,ic]=unique(ph); counts=accumarray(ic,1); [~,mx]=max(counts); sessPhase(ii)=uPh(mx);
		end
		idxNaiveStart = find(sessPhase=="Naive",1,'first');
		if hasLearned, idxEnd = find(sessPhase=="Learned",1,'last');
		elseif hasTransfer, idxEnd = find(sessPhase=="Transfer",1,'first')-1;
		else, idxEnd = numel(sessDTs); end
		if isempty(idxNaiveStart)||idxEnd<idxNaiveStart, continue; end
		for k = idxNaiveStart:idxEnd
			dt = sessDTs(k);
			blks = uint64(Tm.BlockUID(Tm.DateTime==dt));
			TrSess = Tr(ismember(uint64(Tr.BlockUID),blks),:);
			if isempty(TrSess), continue; end
			lwMask = string(TrSess.Stimulus)=="LightWater";
			if ~any(lwMask), continue; end
			perf = mean(double(TrSess.Behavior(lwMask)),'omitnan');
			if ~isfinite(perf), continue; end
			AllSess=[AllSess; table(m,dt,perf,srcName,'VariableNames',{'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
		end
	end
end
AllSess = sortrows(AllSess,{'Mouse','DateTime'});
[~,ia]=unique(AllSess(:,{'Mouse','DateTime'}),'rows'); AllSess=AllSess(ia,:);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess),1);
for i=1:height(AllSess)
	if AllSess.Source(i)=="LAB", DS=LAB; else, DS=LAI; end
	Tdt = DS.TableQuery("Stimulus", Mouse=AllSess.Mouse(i), DateTime=AllSess.DateTime(i));
	if isempty(Tdt), continue; end
	st = unique(string(Tdt.Stimulus)); st=st(~ismissing(st));
	if any(st=="AudioWater"), keep(i)=false; end
end
AllSess = AllSess(keep,:);
end

% ---- Fig4D 的 LightWater 会话与 pre-ceiling 筛选 ----
function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:,{'BlockUID','DateTime'});
Blocks.BlockUID=uint64(Blocks.BlockUID); Blocks.DateTime=datetime(Blocks.DateTime);
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime=datetime(DT.DateTime); DT.Mouse=string(DT.Mouse); DT.Phase=string(DT.Phase);
Tr = DS.Trials(:,{'BlockUID','Stimulus','Behavior'});
Tr.BlockUID=uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus)=="LightWater",{'BlockUID','Behavior'});
[G,bu]=findgroups(uint64(TrLW.BlockUID));
perf=splitapply(@(x) mean(double(x),'omitnan'),TrLW.Behavior,G);
pb=table(uint64(bu),perf,'VariableNames',{'BlockUID','Perf'});
T=innerjoin(pb,Blocks,'Keys','BlockUID');
T=innerjoin(T,DT,'Keys','DateTime');
[G2,mouse,dt]=findgroups(T.Mouse,T.DateTime);
perf2=splitapply(@(x) mean(double(x),'omitnan'),T.Perf,G2);
phase2=splitapply(@(x) string(x(1)),T.Phase,G2);
Sess=table(mouse,dt,phase2,perf2,'VariableNames',{'Mouse','DateTime','Phase','Performance'});
Sess=sortrows(Sess,{'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:,{'BlockUID','DateTime'});
Blocks.BlockUID=uint64(Blocks.BlockUID); Blocks.DateTime=datetime(Blocks.DateTime);
Tr = DS.Trials(:,{'BlockUID','Stimulus'});
Tr.BlockUID=uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus)=="AudioWater",{'BlockUID'});
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}),Blocks,'Keys','BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime,dtAW),:);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime=datetime(DT.DateTime); DT.Mouse=string(DT.Mouse); DT.Phase=string(DT.Phase);
keep = false(height(SessOut),1);
for m = unique(string(SessOut.Mouse))'
	dtM = DT(DT.Mouse==m,:);
	phS = dtM.DateTime(dtM.Phase==phaseStart);
	phE = dtM.DateTime(dtM.Phase==phaseEnd);
	if isempty(phS)||isempty(phE), continue; end
	sDT=min(phS); eDT=max(phE);
	rows = (string(SessOut.Mouse)==m)&(SessOut.DateTime>=sDT)&(SessOut.DateTime<=eDT);
	keep=keep|rows;
end
SessOut = SessOut(keep,:);
end
