% 探查（不改旧图）：把 Fig3B_SlopeVsHeterogeneity 的学习速度从旧会话级 sigmoid
% 换成英文图1C 的 penalized sigmoid（FitPenalizedSigmoid，固定 L=0，逐 trial 惩罚似然），
% 重新计算"响应异质性 vs 学习速度"的相关性，看是否仍显著。
% 异质性沿用 Fig3B/Fig4D 口径：Transfer→Final 的 LightWater 会话、pre-ceiling、|z|<=1、分层。
% 斜率：对每鼠的 LightWater 逐 trial 行为，按会话序号作 block，FitPenalizedSigmoid 求 k（log-odds/会话）。

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

% ---- 斜率：penalized sigmoid，逐 trial ----
% Naive = LAB+LAI 的 LightWater Naive 学习期（多会话）；Transfer = ALB 的 Transfer→Final 全过程（多会话）。
slopeN = iSlopeCohort({DS_LAB, DS_LAI}, "Naive", "Final");
slopeT = iSlopeCohort({DS_T}, "Transfer", "Final");
fprintf('slopes: Naive n=%d, Transfer n=%d\n', sum(isfinite(slopeN.Slope)), sum(isfinite(slopeT.Slope)));

% ---- 异质性：沿用 Fig4D 的 iCohortData 思路（此处内联简化版，口径一致）----
% Naive 用 LAB+LAI 的 Naive 学习期会话；Transfer 用 ALB 的 Transfer→Final。
hetN = iHeterogeneityCohort({DS_LAB, DS_LAI}, "Naive", idx1s);
hetT = iHeterogeneityCohort({DS_T}, "Transfer", idx1s);

% ---- 按鼠对齐斜率与异质性，再按层算相关（Naive+Transfer 合并，同 Fig3B）----
for iL = 1:2
	if iL==1, field='L23'; else, field='L5'; end
	% Naive
	JN = innerjoin(table(hetN.Mouse, hetN.(field), 'VariableNames',{'Mouse','SD'}), ...
		slopeN, 'Keys','Mouse');
	% Transfer
	JT = innerjoin(table(hetT.Mouse, hetT.(field), 'VariableNames',{'Mouse','SD'}), ...
		slopeT, 'Keys','Mouse');
	sdAll = [JN.SD; JT.SD]; kAll = [JN.Slope; JT.Slope];
	use = isfinite(sdAll) & isfinite(kAll);
	if nnz(use) >= 3 && std(sdAll(use))>0 && std(kAll(use))>0
		[rho,p] = corr(sdAll(use), kAll(use), 'Type','Spearman');
	else
		rho=NaN; p=NaN;
	end
	fprintf('%s: n=%d (Naive %d + Transfer %d), Spearman rho=%.3f, p=%.4g\n', ...
		field, nnz(use), height(JN), height(JT), rho, p);
end

function S = iSlopeCohort(DSlist, phaseStart, phaseEnd)
% 每鼠 penalized sigmoid 斜率（逐 trial，会话序号作 block）。取 phaseStart→phaseEnd 全过程。
M = strings(0,1); K = [];
for d = 1:numel(DSlist)
	DS = DSlist{d};
	T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"]);
	T.Mouse=string(T.Mouse); T.Stimulus=string(T.Stimulus); T.Phase=string(T.Phase); T.DateTime=datetime(T.DateTime);
	T = T(T.Stimulus=="LightWater", :);
	% 每鼠限制在 phaseStart→phaseEnd 的会话范围
	keep = false(height(T),1);
	for m = unique(T.Mouse)'
		Tm = T(T.Mouse==m,:);
		dtM = unique(Tm.DateTime);
		phS = Tm.DateTime(Tm.Phase==phaseStart);
		phE = Tm.DateTime(Tm.Phase==phaseEnd);
		if isempty(phS)||isempty(phE), continue; end
		sDT=min(phS); eDT=max(phE);
		keep = keep | ((T.Mouse==m) & (T.DateTime>=sDT) & (T.DateTime<=eDT));
	end
	T = T(keep,:);
	mice = unique(T.Mouse);
	for i = 1:numel(mice)
		m = mice(i);
		Tm = T(T.Mouse==m,:);
		dts = sort(unique(Tm.DateTime));
		block = zeros(height(Tm),1);
	 for j = 1:numel(dts)
			block(Tm.DateTime==dts(j)) = j;
		end
		beh = double(Tm.Behavior);
		ok = isfinite(beh);
		if numel(unique(block(ok))) < 2, continue; end
		try
			fit = TransferLearning.FitPenalizedSigmoid(block(ok), beh(ok), FixLowerZero=true);
			M(end+1,1)=m; K(end+1,1)=fit.Slope; %#ok<AGROW>
		catch
		end
	end
end
S = table(M,K,'VariableNames',{'Mouse','Slope'});
end

function H = iHeterogeneityCohort(DSlist, phase, idx1s)
% 每鼠分层 RH：phase→Final 会话 pre-ceiling，每细胞 median z@+1s，|z|<=1，across-cell SD
M = strings(0,1); L23=[]; L5=[];
for d = 1:numel(DSlist)
	DS = DSlist{d};
	Sess = iLightWaterSessions(DS);
	Sess = iKeepPhaseRange(DS, Sess, phase, "Final");
	mice = unique(string(Sess.Mouse));
	for iM = 1:numel(mice)
		m = mice(iM);
		R = sortrows(Sess(string(Sess.Mouse)==m,:),'DateTime');
		if height(R)<2, continue; end
		first100 = find(double(R.Performance)>=1.0,1,'first');
		if ~isempty(first100) && first100>1, R=R(1:first100-1,:); elseif ~isempty(first100)&&first100==1, continue; end
		if height(R)<2, continue; end
		[sd23,sd5] = iMouseLayerSD(DS, m, R.DateTime, idx1s);
		M(end+1,1)=m; L23(end+1,1)=sd23; L5(end+1,1)=sd5; %#ok<AGROW>
	end
end
H = struct('Mouse',M,'L23',L23,'L5',L5);
end

function [sd23,sd5] = iMouseLayerSD(DS, m, dts, idx1s)
sd23=NaN; sd5=NaN;
q = struct('Stimulus','LightWater','Mouse',m,'DateTime',dts);
try, nts = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns',["DateTime"]); catch, return; end
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
sig = double(nts.TrialSignal);
z = sig(:,idx1s);
% 每细胞跨会话 median
[G,cid] = findgroups(nts.CellUID);
med = splitapply(@(x) median(x,'omitnan'), z, G);
CellTbl = DS.Cells; CellTbl.CellUID=uint64(CellTbl.CellUID); CellTbl.ZLayer=string(CellTbl.ZLayer);
[~,loc]=ismember(cid,CellTbl.CellUID);
layers = CellTbl.ZLayer(loc);
v23 = med(layers=="MOp2/3"); v5 = med(layers=="MOp5");
v23 = v23(isfinite(v23)&abs(v23)<=1); v5 = v5(isfinite(v5)&abs(v5)<=1);
if numel(v23)>=3, sd23=std(v23); end
if numel(v5)>=3, sd5=std(v5); end
end

% ---- 会话筛选（同 Fig4D）----
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

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime=datetime(DT.DateTime); DT.Mouse=string(DT.Mouse); DT.Phase=string(DT.Phase);
keep = false(height(SessOut),1);
for m = unique(string(SessOut.Mouse))'
	dtM = DT(DT.Mouse==m,:);
	phDates = dtM.DateTime(dtM.Phase==phaseStart);
	endDates = dtM.DateTime(dtM.Phase==phaseEnd);
	if isempty(phDates)||isempty(endDates), continue; end
	startDT=min(phDates); endDT=max(endDates);
	rows = (string(SessOut.Mouse)==m) & (SessOut.DateTime>=startDT) & (SessOut.DateTime<=endDT);
	keep = keep|rows;
end
SessOut = SessOut(keep,:);
end
