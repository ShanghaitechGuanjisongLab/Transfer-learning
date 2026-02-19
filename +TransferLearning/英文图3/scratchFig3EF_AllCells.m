% scratchFig3EF_AllCells.m
% 测试 Fig3E / Fig3F 不分层(ALL cells)是否仍有显著性
warning('off','all');

DS_ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

xs = TransferLearning.Xs;
if isduration(xs), xsSec=seconds(xs); else, xsSec=double(xs); end
[~,idx1s] = min(abs(xsSec-1));

Cells_ALB = DS_ALB.Cells; Cells_ALB.CellUID=uint64(Cells_ALB.CellUID);
Cells_ALB.Mouse=string(Cells_ALB.Mouse); Cells_ALB.ZLayer=string(Cells_ALB.ZLayer);

%% ==== Transfer session pairs (same as Fig3E/F) ====
SessT = iBuildLWSessions(DS_ALB);
SessT = iKeepPureLW(DS_ALB, SessT);
SessT = iExcludeCeiling(SessT);
PairsT = iBuildPairs(SessT);
nT = height(PairsT);
fprintf('Transfer session pairs: %d\n', nT);

% Compute SD@1s for each session (all cells + by layer)
SD_T_K  = nan(nT, 3);  % [All, MOp23, MOp5]
SD_T_K1 = nan(nT, 3);

for i = 1:nT
	[SD_T_K(i,1), SD_T_K(i,2), SD_T_K(i,3)] = iComputeSD(DS_ALB, Cells_ALB, PairsT.Mouse(i), PairsT.DateTime(i), idx1s);
	[SD_T_K1(i,1), SD_T_K1(i,2), SD_T_K1(i,3)] = iComputeSD(DS_ALB, Cells_ALB, PairsT.Mouse(i), PairsT.DateTimeNext(i), idx1s);
end
SD_T_MeanPair = (SD_T_K + SD_T_K1) / 2;  % for Fig3F
deltaHitT = double(PairsT.PerformanceNext - PairsT.Performance);

%% ==== Naive session pairs (LAB + LAI, same as Fig3F) ====
allNSess = table(strings(0,1),NaT(0,1),nan(0,1),strings(0,1),'VariableNames',{'Mouse','DateTime','Performance','Source'});
CellsN = cell(2,1);
DSn = {LAB, LAI}; dsNames = ["LAB","LAI"];
for d = 1:2
	CellsD = DSn{d}.Cells; CellsD.CellUID=uint64(CellsD.CellUID);
	CellsD.Mouse=string(CellsD.Mouse); CellsD.ZLayer=string(CellsD.ZLayer);
	CellsN{d} = CellsD;
	
	S = iBuildLWSessions(DSn{d});
	S = iKeepPureLW(DSn{d}, S);
	S = iExcludeCeiling(S);
	if isempty(S), continue; end
	S.Source = repmat(dsNames(d), height(S), 1);
	allNSess = [allNSess; S]; %#ok<AGROW>
end
allNSess = sortrows(allNSess,{'Mouse','DateTime'});
[~,iu] = unique(allNSess(:,{'Mouse','DateTime'}),'rows','first');
allNSess = allNSess(iu,:);
PairsN = iBuildPairsWithSource(allNSess);
nN = height(PairsN);
fprintf('Naive session pairs: %d\n', nN);

SD_N_K  = nan(nN, 3);
SD_N_K1 = nan(nN, 3);

for i = 1:nN
	src = PairsN.Source(i);
	if src=="LAB", DS=LAB; CD=CellsN{1}; else, DS=LAI; CD=CellsN{2}; end
	[SD_N_K(i,1), SD_N_K(i,2), SD_N_K(i,3)] = iComputeSD(DS, CD, PairsN.Mouse(i), PairsN.DateTime(i), idx1s);
	[SD_N_K1(i,1), SD_N_K1(i,2), SD_N_K1(i,3)] = iComputeSD(DS, CD, PairsN.Mouse(i), PairsN.DateTimeNext(i), idx1s);
end
SD_N_MeanPair = (SD_N_K + SD_N_K1) / 2;

%% ==== Fig3E: SD@1s (session k+1) vs ΔHit — Spearman ====
fprintf('\n========== Fig3E: SD@1s (session k+1) vs ΔHit — Spearman ==========\n');
layerLabels = {'All cells', 'MOp2/3', 'MOp5'};
for iL = 1:3
	x = SD_T_K1(:, iL); y = deltaHitT;
	mask = isfinite(x) & isfinite(y);
	if nnz(mask) >= 4 && std(x(mask))>0 && std(y(mask))>0
		[rho, p] = corr(x(mask), y(mask), 'Type','Spearman');
		sig = iSigStr(p);
		fprintf('  %-12s: rho=%+.3f  p=%.4f %s  (n=%d)\n', layerLabels{iL}, rho, p, sig, nnz(mask));
	else
		fprintf('  %-12s: insufficient data\n', layerLabels{iL});
	end
end

%% ==== Fig3F: Naive vs Transfer SD@1s (mean of pair) — Ranksum ====
fprintf('\n========== Fig3F: Naive vs Transfer SD@1s (mean of pair) — Ranksum ==========\n');
for iL = 1:3
	tV = SD_T_MeanPair(:, iL); tV = tV(isfinite(tV));
	nV = SD_N_MeanPair(:, iL); nV = nV(isfinite(nV));
	if numel(tV)>=3 && numel(nV)>=3
		p = ranksum(tV, nV);
		sig = iSigStr(p);
		fprintf('  %-12s: T=%.3f±%.3f (n=%d), N=%.3f±%.3f (n=%d), p=%.4g %s\n', ...
			layerLabels{iL}, mean(tV), std(tV)/sqrt(numel(tV)), numel(tV), ...
			mean(nV), std(nV)/sqrt(numel(nV)), numel(nV), p, sig);
	else
		fprintf('  %-12s: insufficient data (T=%d, N=%d)\n', layerLabels{iL}, numel(tV), numel(nV));
	end
end

warning('on','all');
fprintf('\nDone.\n');

%% ======== LOCAL FUNCTIONS ========

function [sd_all, sd_23, sd_5] = iComputeSD(DS, CellTbl, mouse, dt, idx1s)
sd_all = NaN; sd_23 = NaN; sd_5 = NaN;
q.Mouse = char(mouse); q.DateTime = dt; q.Stimulus = 'LightWater';
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
if isempty(ntsCell)||isempty(ntsCell{1}), return; end
nts = ntsCell{1};
if ~istable(nts)||height(nts)==0, return; end
if ~all(ismember(["CellUID","TrialSignal"],string(nts.Properties.VariableNames))), return; end

uCells = unique(uint64(nts.CellUID));
vals = nan(numel(uCells),1);
for iC=1:numel(uCells)
	cR = double(nts.TrialSignal(uint64(nts.CellUID)==uCells(iC),:));
	med = median(cR,1,'omitnan');
	if numel(med)>=idx1s, vals(iC)=med(idx1s); end
end

vAll = vals(isfinite(vals));
if numel(vAll)>=3, sd_all = std(vAll); end

[~,loc] = ismember(uCells, CellTbl.CellUID);
layers = strings(numel(uCells),1);
layers(loc>0) = CellTbl.ZLayer(loc(loc>0));

v23 = vals(layers=="MOp2/3"); v23=v23(isfinite(v23));
v5 = vals(layers=="MOp5"); v5=v5(isfinite(v5));
if numel(v23)>=3, sd_23=std(v23); end
if numel(v5)>=3, sd_5=std(v5); end
end

function s = iSigStr(p)
if p<0.001, s="***"; elseif p<0.01, s="**"; elseif p<0.05, s="*"; else, s="n.s."; end
end

function S = iBuildLWSessions(DS)
Blocks = DS.Blocks; Blocks.BlockUID=uint64(Blocks.BlockUID);
Blocks.DateTime=datetime(Blocks.DateTime); if ~isempty(Blocks.DateTime.TimeZone),Blocks.DateTime.TimeZone='';end
if ismember("MustWarn",string(Blocks.Properties.VariableNames)), Blocks.MustWarn=string(Blocks.MustWarn);
else, Blocks.MustWarn=repmat("",height(Blocks),1); end
Blocks=Blocks(:,{'BlockUID','DateTime','MustWarn'});
DTbl=DS.DateTimes(:,{'DateTime','Mouse'}); DTbl.DateTime=datetime(DTbl.DateTime);
if ~isempty(DTbl.DateTime.TimeZone),DTbl.DateTime.TimeZone='';end; DTbl.Mouse=string(DTbl.Mouse);
Tr=DS.Trials(:,{'BlockUID','Stimulus','Behavior'}); Tr.BlockUID=uint64(Tr.BlockUID);
TrLW=Tr(string(Tr.Stimulus)=="LightWater",:);
if isempty(TrLW), S=table(strings(0,1),NaT(0,1),nan(0,1),'VariableNames',{'Mouse','DateTime','Performance'}); return; end
[G,bu]=findgroups(TrLW.BlockUID); lwP=splitapply(@(x)mean(double(x),'omitnan'),TrLW.Behavior,G);
pBB=table(uint64(bu),lwP,'VariableNames',{'BlockUID','LWPerf'});
T0=innerjoin(pBB,Blocks,'Keys','BlockUID');
keep=ismissing(T0.MustWarn)|(T0.MustWarn==""); T0=T0(keep,:);
T0=innerjoin(T0,DTbl,'Keys','DateTime');
[G2,mouse,dt]=findgroups(T0.Mouse,T0.DateTime);
perfS=splitapply(@(x)mean(double(x),'omitnan'),T0.LWPerf,G2);
S=table(mouse,dt,perfS,'VariableNames',{'Mouse','DateTime','Performance'});
S=sortrows(S,{'Mouse','DateTime'});
end

function S = iKeepPureLW(DS, S)
if isempty(S), return; end
Blocks=DS.Blocks(:,{'BlockUID','DateTime'}); Blocks.BlockUID=uint64(Blocks.BlockUID);
Blocks.DateTime=datetime(Blocks.DateTime); if ~isempty(Blocks.DateTime.TimeZone),Blocks.DateTime.TimeZone='';end
Tr=DS.Trials(:,{'BlockUID','Stimulus'}); Tr.BlockUID=uint64(Tr.BlockUID);
TrAW=Tr(string(Tr.Stimulus)=="AudioWater",:);
if isempty(TrAW), return; end
blkAW=unique(uint64(TrAW.BlockUID));
TAW=innerjoin(table(blkAW,'VariableNames',{'BlockUID'}),Blocks,'Keys','BlockUID');
dtAW=unique(TAW.DateTime);
S=S(~ismember(S.DateTime,dtAW),:);
end

function S = iExcludeCeiling(S)
if isempty(S), return; end
S.Mouse=string(S.Mouse); S=sortrows(S,{'Mouse','DateTime'});
rm=false(height(S),1);
for m=unique(S.Mouse)', rows=find(S.Mouse==m); p=double(S.Performance(rows));
	i100=find(p>=1-1e-12,1,'first'); if ~isempty(i100), rm(rows(i100:end))=true; end
end
S(rm,:)=[]; pf=double(S.Performance); S=S(isfinite(pf)&pf>=-1e-12&pf<1-1e-12,:);
end

function P = iBuildPairs(S)
S=sortrows(S,{'Mouse','DateTime'}); S.Mouse=string(S.Mouse);
oM=strings(0,1); oDT=NaT(0,1); oP=nan(0,1); oDT2=NaT(0,1); oP2=nan(0,1);
for m=unique(S.Mouse)', R=S(S.Mouse==m,:); pp=double(R.Performance); dd=R.DateTime;
	use=isfinite(pp)&~ismissing(dd); pp=pp(use); dd=dd(use);
	if numel(pp)<2, continue; end; n=numel(pp)-1;
	oM=[oM;repmat(m,n,1)]; oDT=[oDT;dd(1:end-1)]; oP=[oP;pp(1:end-1)];
	oDT2=[oDT2;dd(2:end)]; oP2=[oP2;pp(2:end)];
end
P=table(oM,oDT,oP,oDT2,oP2,'VariableNames',{'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext'});
end

function P = iBuildPairsWithSource(S)
S=sortrows(S,{'Mouse','DateTime'}); S.Mouse=string(S.Mouse);
oM=strings(0,1); oDT=NaT(0,1); oP=nan(0,1); oDT2=NaT(0,1); oP2=nan(0,1); oSrc=strings(0,1);
for m=unique(S.Mouse)', R=S(S.Mouse==m,:); pp=double(R.Performance); dd=R.DateTime; ss=R.Source;
	use=isfinite(pp)&~ismissing(dd); pp=pp(use); dd=dd(use); ss=ss(use);
	if numel(pp)<2, continue; end; n=numel(pp)-1;
	oM=[oM;repmat(m,n,1)]; oDT=[oDT;dd(1:end-1)]; oP=[oP;pp(1:end-1)];
	oDT2=[oDT2;dd(2:end)]; oP2=[oP2;pp(2:end)]; oSrc=[oSrc;ss(1:end-1)];
end
P=table(oM,oDT,oP,oDT2,oP2,oSrc,'VariableNames',{'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Source'});
end
