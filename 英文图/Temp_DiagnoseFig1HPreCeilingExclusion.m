% 诊断：Fig1H 管道里鼠被排除的原因。
% 关键：异质性计算 iKeepAnalyzedBlocks_Fig3C 是 pre-ceiling 口径（Performance>=1 之后会话丢弃，
% 且 pre-ceiling 后需 >=2 会话），与 allow list 无关。逐鼠列出 pre-ceiling 会话数与是否被排除。
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_T = TransferLearning.AudioLightBaseline();

% Fig3B 口径的会话
NaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
NaiveSess = iExcludeAudioWaterSessions(NaiveSess, DS_LAB, DS_LAI);
TransferSess = iLightWaterSessions(DS_T);
TransferSess = iKeepPureLW_NoMustWarn(DS_T, TransferSess);
TransferSess = iKeepPhaseRange(DS_T, TransferSess, "Transfer", "Final");

fprintf('\n===== Naive: pre-ceiling session count =====\n');
iPreCeilingDiag(NaiveSess);
fprintf('\n===== Transfer: pre-ceiling session count =====\n');
iPreCeilingDiag(TransferSess);

function iPreCeilingDiag(Sess)
for m = unique(string(Sess.Mouse))'
	R = sortrows(Sess(string(Sess.Mouse)==m,:),'DateTime');
	perf = double(R.Performance);
	R = R(isfinite(perf),:); perf = perf(isfinite(perf));
	first100 = find(perf>=1-1e-12,1,'first');
	if ~isempty(first100)
		if first100==1
			fprintf('%s: EXCLUDED - first session already at ceiling (Performance=1)\n', m);
			continue;
		end
		R = R(1:first100-1,:);
	end
	nb = height(R);
	if nb < 2
		fprintf('%s: EXCLUDED - only %d pre-ceiling session(s) (<2)\n', m, nb);
	else
		fprintf('%s: kept (%d pre-ceiling sessions)\n', m, nb);
	end
end
end

% ---- 复用 v2 辅助函数 ----
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
