%% 图3修改方案 MATLAB 验算脚本 v2 (仅ALB + TH)
%% 0) 加载
DS_ALB = TransferLearning.AudioLightBaseline();
DS_TH  = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));

fprintf('\n========== 图3修改方案 统计验算 ==========\n\n');

%% 1) 已有结论复验：SD vs ΔHit
fprintf('--- 1. SD vs ΔHit (Panel C 复验) ---\n');
TransferLearning.英文图3.C_SD1sVsDeltaHit_ByLayer;
close all;

%% 2) 已有结论复验：Transfer vs Naive SD
fprintf('\n--- 2. Transfer vs Naive SD (Panel D 复验) ---\n');
TransferLearning.英文图3.D_SD1s_NaiveVsTransfer_ByLayer;
close all;

%% 3) 已有结论复验：TH ΔHit & SD
fprintf('\n--- 3. TH ΔHit & SD (Panel G 复验) ---\n');
TransferLearning.英文图3.G_THInhibitVsCtrl_DeltaHitAndSD;
close all;

%% 4) 已有结论复验：Reuse vs ΔHit
fprintf('\n--- 4. Reuse vs ΔHit (Panel H 复验) ---\n');
TransferLearning.英文图3.H_ReuseRateVsDeltaHit;
close all;

%% 5) 已有结论复验：Divergence vs ΔHit
fprintf('\n--- 5. Div vs ΔHit (Panel I 复验) ---\n');
TransferLearning.英文图3.I_DivergenceVsDeltaHit;
close all;

%% 6) 新分析：AW→LW 信号保留 (per-cell Spearman)
fprintf('\n\n====== 新分析 ======\n');
fprintf('\n--- 6. AW→LW 信号保留：per-cell 相关 ---\n');

CellTbl = DS_ALB.Cells;
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);

DT = DS_ALB.DateTimes;
DT.DateTime = datetime(DT.DateTime); DT.DateTime.TimeZone = '';
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Blocks = DS_ALB.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime); Blocks.DateTime.TimeZone = '';

Trials = DS_ALB.Trials;
Trials.BlockUID = uint64(Trials.BlockUID);

mice = unique(CellTbl.Mouse);

corrPerMouse = nan(numel(mice), 1);
pPerMouse = nan(numel(mice), 1);
nCellPerMouse = nan(numel(mice), 1);
absResp_active = nan(numel(mice), 1);
absResp_inactive = nan(numel(mice), 1);

for mi = 1:numel(mice)
    m = mice(mi);
    mouseDTs = DT(DT.Mouse == m, :);
    learnedDTs = mouseDTs.DateTime(mouseDTs.Phase == "Learned");
    if isempty(learnedDTs), continue; end
    
    % 找有AW的Learned sessions
    awDTs = datetime.empty;
    for di = 1:numel(learnedDTs)
        dt = learnedDTs(di);
        blks = Blocks.BlockUID(Blocks.DateTime == dt);
        tr = Trials(ismember(Trials.BlockUID, blks), :);
        if any(string(tr.Stimulus) == "AudioWater"), awDTs(end+1) = dt; end
    end
    if isempty(awDTs), continue; end
    lastAWdt = max(awDTs);
    
    % 找第一个纯LW session
    allDTs = sort(unique(mouseDTs.DateTime));
    lwDTs = datetime.empty;
    for di = 1:numel(allDTs)
        dt = allDTs(di);
        if dt <= lastAWdt, continue; end
        blks = Blocks.BlockUID(Blocks.DateTime == dt);
        tr = Trials(ismember(Trials.BlockUID, blks), :);
        stims = unique(string(tr.Stimulus));
        if any(stims == "LightWater") && ~any(stims == "AudioWater")
            lwDTs(end+1) = dt; break;
        end
    end
    if isempty(lwDTs), continue; end
    firstLWdt = lwDTs(1);
    
    % AW per-cell median @1s
    ntsAW = DS_ALB.QueryNTS(struct('Stimulus','AudioWater','DateTime',lastAWdt,'Mouse',char(m)), UniExp.Flags.ZScore, 1:24);
    if iscell(ntsAW), ntsAW = ntsAW{1}; end
    if isempty(ntsAW) || ~istable(ntsAW), continue; end
    awCells = unique(uint64(ntsAW.CellUID));
    awMedian = nan(numel(awCells), 1);
    for ci = 1:numel(awCells)
        rows = ntsAW(uint64(ntsAW.CellUID) == awCells(ci), :);
        med = median(double(rows.TrialSignal), 1, 'omitnan');
        if numel(med) >= idx1s, awMedian(ci) = med(idx1s); end
    end
    
    % LW per-cell median @1s
    ntsLW = DS_ALB.QueryNTS(struct('Stimulus','LightWater','DateTime',firstLWdt,'Mouse',char(m)), UniExp.Flags.ZScore, 1:24);
    if iscell(ntsLW), ntsLW = ntsLW{1}; end
    if isempty(ntsLW) || ~istable(ntsLW), continue; end
    lwCells = unique(uint64(ntsLW.CellUID));
    lwMedian = nan(numel(lwCells), 1);
    for ci = 1:numel(lwCells)
        rows = ntsLW(uint64(ntsLW.CellUID) == lwCells(ci), :);
        med = median(double(rows.TrialSignal), 1, 'omitnan');
        if numel(med) >= idx1s, lwMedian(ci) = med(idx1s); end
    end
    
    % 交集细胞
    [commonCells, iAW, iLW] = intersect(awCells, lwCells);
    awV = awMedian(iAW); lwV = lwMedian(iLW);
    valid = isfinite(awV) & isfinite(lwV);
    if sum(valid) < 10, continue; end
    
    [rho, p] = corr(awV(valid), lwV(valid), 'Type', 'Spearman');
    corrPerMouse(mi) = rho;
    pPerMouse(mi) = p;
    nCellPerMouse(mi) = sum(valid);
    
    % AW-active vs inactive: |LW response|
    absAW = abs(awV(valid));
    nHalf = ceil(numel(absAW)/2);
    [~, sortIdx] = sort(absAW, 'descend');
    activeIdx = sortIdx(1:nHalf);
    inactiveIdx = sortIdx(nHalf+1:end);
    absResp_active(mi) = mean(abs(lwV(valid(sortIdx(1:nHalf)))));
    
    lwValid = lwV(valid);
    absResp_active(mi) = mean(abs(lwValid(activeIdx)));
    absResp_inactive(mi) = mean(abs(lwValid(inactiveIdx)));
    
    fprintf('  %s: AW→LW ρ=%.3f p=%.4g n=%d | |LW|_act=%.3f |LW|_inact=%.3f\n', ...
        m, rho, p, sum(valid), absResp_active(mi), absResp_inactive(mi));
end

vm = isfinite(corrPerMouse);
fprintf('\n  === AW→LW 信号保留 (per-cell Spearman) ===\n');
fprintf('  %d mice, mean ρ = %.3f ± %.3f\n', sum(vm), mean(corrPerMouse(vm)), std(corrPerMouse(vm))/sqrt(sum(vm)));
if sum(vm) >= 3
    [pSR] = signrank(corrPerMouse(vm));
    fprintf('  signrank vs 0: p = %.4g\n', pSR);
end

vm2 = isfinite(absResp_active) & isfinite(absResp_inactive);
fprintf('\n  === AW-active vs inactive |LW resp| ===\n');
fprintf('  %d mice, active=%.3f±%.3f, inactive=%.3f±%.3f\n', ...
    sum(vm2), mean(absResp_active(vm2)), std(absResp_active(vm2))/sqrt(sum(vm2)), ...
    mean(absResp_inactive(vm2)), std(absResp_inactive(vm2))/sqrt(sum(vm2)));
if sum(vm2) >= 3
    [pAI] = signrank(absResp_active(vm2), absResp_inactive(vm2));
    fprintf('  signrank: p = %.4g\n', pAI);
end

%% 7) 新分析：信号保留强度 vs 平均ΔHit
fprintf('\n--- 7. 信号保留 vs 平均ΔHit ---\n');
% per-mouse 平均ΔHit
SessT = iLightWaterSessions_s(DS_ALB);
SessT = iExcludeCeiling_s(SessT);
SessT = iKeepPureLW_s(DS_ALB, SessT);
SessT = sortrows(SessT, {'Mouse','DateTime'});

meanDH = nan(numel(mice), 1);
for mi = 1:numel(mice)
    m = mice(mi);
    R = SessT(SessT.Mouse == m, :);
    perf = double(R.Performance);
    if numel(perf) < 2, continue; end
    meanDH(mi) = mean(diff(perf), 'omitnan');
end

both = isfinite(corrPerMouse) & isfinite(meanDH);
if sum(both) >= 4
    [rho_rd, p_rd] = corr(corrPerMouse(both), meanDH(both), 'Type', 'Spearman');
    fprintf('  AW→LW retention vs mean ΔHit: ρ=%.3f p=%.4g n=%d\n', rho_rd, p_rd, sum(both));
end

fprintf('\n========== 验算完毕 ==========\n');

%% helpers
function Sess = iLightWaterSessions_s(DS)
B = DS.Blocks; B.BlockUID = uint64(B.BlockUID); B.DateTime = datetime(B.DateTime); B.DateTime.TimeZone='';
D = DS.DateTimes(:,{'DateTime','Mouse'}); D.DateTime=datetime(D.DateTime); D.DateTime.TimeZone=''; D.Mouse=string(D.Mouse);
T = DS.Trials(:,{'BlockUID','Stimulus','Behavior'}); T.BlockUID=uint64(T.BlockUID);
TL = T(string(T.Stimulus)=="LightWater",:);
[G,bu]=findgroups(uint64(TL.BlockUID)); lp=splitapply(@(x)mean(double(x),'omitnan'),TL.Behavior,G);
pb=table(uint64(bu),lp,'VariableNames',{'BlockUID','LWPerf'});
J=innerjoin(pb,B(:,{'BlockUID','DateTime'}),'Keys','BlockUID');
J=innerjoin(J,D,'Keys','DateTime');
[G2,mouse,dt]=findgroups(J.Mouse,J.DateTime);
ps=splitapply(@(x)mean(double(x),'omitnan'),J.LWPerf,G2);
Sess=table(mouse,dt,ps,'VariableNames',{'Mouse','DateTime','Performance'});
Sess=sortrows(Sess,{'Mouse','DateTime'});
end
function SO = iExcludeCeiling_s(SI)
SO=SI; SO.Mouse=string(SO.Mouse); SO=sortrows(SO,{'Mouse','DateTime'});
rm=false(height(SO),1);
for m=unique(SO.Mouse)', r=find(SO.Mouse==m); p=double(SO.Performance(r));
i1=find(p>=1-1e-12,1,'first'); if ~isempty(i1),rm(r(i1:end))=true;end;end
SO(rm,:)=[]; p=double(SO.Performance); SO=SO(isfinite(p)&p>=-1e-12&p<1-1e-12,:);
end
function SO = iKeepPureLW_s(DS,SI)
SO=SI; B=DS.Blocks(:,{'BlockUID','DateTime'}); B.BlockUID=uint64(B.BlockUID);
B.DateTime=datetime(B.DateTime); B.DateTime.TimeZone='';
T=DS.Trials(:,{'BlockUID','Stimulus'}); T.BlockUID=uint64(T.BlockUID);
TA=T(string(T.Stimulus)=="AudioWater",:); if isempty(TA),return;end
ba=unique(uint64(TA.BlockUID));
TAW=innerjoin(table(ba,'VariableNames',{'BlockUID'}),B,'Keys','BlockUID');
SO=SO(~ismember(SO.DateTime,unique(TAW.DateTime)),:);
end
