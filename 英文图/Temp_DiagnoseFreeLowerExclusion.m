% 逐鼠诊断：自由下限 penalized sigmoid（FixLowerZero=false）对 Naive/Transfer 队列的排除原因。
% 对照 L=0（FixLowerZero=true），列出每只鼠：是否被排除、排除原因（边界/拟合失败/不足 block）、斜率。
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_T = TransferLearning.AudioLightBaseline();

% 用 v2 的会话口径
NaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
NaiveSess = iExcludeAudioWaterSessions(NaiveSess, DS_LAB, DS_LAI);
TransferSess = iLightWaterSessions(DS_T);
TransferSess = iKeepPureLW_NoMustWarn(DS_T, TransferSess);
TransferSess = iKeepPhaseRange(DS_T, TransferSess, "Transfer", "Final");

fprintf('\n===== Naive =====\n');
iDiag(NaiveSess, DS_LAB, DS_LAI);
fprintf('\n===== Transfer =====\n');
iDiag(TransferSess, DS_T, []);

function iDiag(Sess, DS1, DS2)
for m = unique(string(Sess.Mouse))'
	R = sortrows(Sess(string(Sess.Mouse)==m,:),'DateTime');
	perf = double(R.Performance);
	R = R(isfinite(perf),:); perf = perf(isfinite(perf));
	if height(R)<2 || numel(unique(perf))<2
		fprintf('%s: skip (insufficient sessions or flat performance)\n', m);
		continue;
	end
	[block, beh, ok] = iTrialsForMouse(R, DS1, DS2);
	if ~ok
		fprintf('%s: skip (no usable trials)\n', m);
		continue;
	end
	nb = numel(unique(block));
	% L=0
	s0 = iFit(block, beh, true);
	% free lower
	sF = iFit(block, beh, false);
	fprintf('%s (blocks=%d): L0 slope=%s [%s] | freeLower slope=%s [%s]\n', m, nb, ...
		iNumStr(s0.slope), s0.status, iNumStr(sF.slope), sF.status);
end
end

function s = iFit(block, beh, fixZero)
s.slope = NaN; s.status = "";
try
	fit = TransferLearning.FitPenalizedSigmoid(block, beh, FixLowerZero=fixZero);
	s.slope = fit.Slope;
	if fit.AtSlopeBoundary
		s.status = "AtSlopeBoundary";
	else
		s.status = "OK";
	end
catch e
	s.status = "FitError: " + string(e.message);
end
end

function str = iNumStr(v)
if ~isfinite(v), str = "NaN"; else, str = sprintf('%.3f', v); end
end

% ---- 以下复用 v2 的辅助函数 ----
function [block, beh, ok] = iTrialsForMouse(R, DS1, DS2)
block=[]; beh=[]; ok=false;
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

function out = iif(c,a,b), if c, out=a; else, out=b; end; end

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
