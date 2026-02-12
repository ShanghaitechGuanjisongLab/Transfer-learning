%% 继承群 (Transfer LW) vs Naive LO 全细胞 (3个数据集叠加) 非配对比较
% Naive LO: AudioLightBaseline + LightAudioBaseline + LAInterspersed
% Transfer LW 继承群: AudioLightBaseline 的 10 只鼠

sampleRate = 8;
baselineSec = 0;

Sources = {
    builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
    builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
    builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};

% ===== Part 1: Collect Naive LO divergence (all cells, per mouse) from 3 datasets =====
allNaiveLO = table();
for iS = 1:numel(Sources)
    DS = Sources{iS}.DS;
    srcName = Sources{iS}.Name;
    
    T = [];
    try
        T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Naive", Stimulus="LightOnly");
    catch
    end
    if isempty(T), fprintf('%s: no Naive LightOnly data\n', srcName); continue; end
    
    T.Mouse = string(T.Mouse);
    T.DateTime = datetime(T.DateTime); try T.DateTime.TimeZone=''; catch, end
    
    mice = unique(T.Mouse);
    fprintf('%s: %d mice with Naive LightOnly\n', srcName, numel(mice));
    
    for j = 1:numel(mice)
        m = mice(j);
        
        nts = DS.QueryNTS(struct('Stimulus',"LightOnly",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
        if iscell(nts), nts=nts{1}; end
        if isempty(nts), continue; end
        
        Tm = T(T.Mouse == m, :);
        sessionDt = min(Tm.DateTime); % first session
        Tm = sortrows(Tm(Tm.DateTime == sessionDt, :), "TrialIndex");
        trialUIDs = unique(uint64(Tm.TrialUID), 'stable');
        
        [CTT, ~] = iLocalBuildCTT(nts, trialUIDs, sampleRate, baselineSec);
        if isempty(CTT), continue; end
        
        div = TransferLearning.Divergence(CTT);
        if ~isfinite(div), continue; end
        
        row = table(m, string(srcName), div, size(CTT,1), ...
            'VariableNames', {'Mouse','Source','Divergence','NCells'});
        allNaiveLO = [allNaiveLO; row]; %#ok<AGROW>
    end
end

% Collapse by mouse if same mouse in multiple datasets
[G, miceU] = findgroups(allNaiveLO.Mouse);
divNaiveLO_perMouse = splitapply(@(x) mean(x,'omitnan'), allNaiveLO.Divergence, G);
nCellsNaiveLO = splitapply(@(x) mean(x,'omitnan'), allNaiveLO.NCells, G);

fprintf('\nNaive LO (3 datasets merged): %d unique mice (before: %d rows)\n', numel(miceU), height(allNaiveLO));

% ===== Part 2: Transfer LW 继承群散度 (from ALB) =====
DS_ALB = Sources{1}.DS;

TlearnAW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TtransLW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TlearnAW.Mouse = string(TlearnAW.Mouse); TlearnAW.DateTime = datetime(TlearnAW.DateTime); try TlearnAW.DateTime.TimeZone=''; catch, end
TtransLW.Mouse = string(TtransLW.Mouse); TtransLW.DateTime = datetime(TtransLW.DateTime); try TtransLW.DateTime.TimeZone=''; catch, end

miceTransfer = intersect(unique(TtransLW.Mouse), unique(TlearnAW.Mouse));
divTrInh = nan(numel(miceTransfer), 1);
divTrNon = nan(numel(miceTransfer), 1);
divTrAll = nan(numel(miceTransfer), 1);
nInhCells = nan(numel(miceTransfer), 1);
nTotalCells = nan(numel(miceTransfer), 1);

for i = 1:numel(miceTransfer)
    m = miceTransfer(i);
    
    ntsAW = DS_ALB.QueryNTS(struct('Stimulus',"AudioWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    ntsLW = DS_ALB.QueryNTS(struct('Stimulus',"LightWater",'Mouse',m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsAW), ntsAW=ntsAW{1}; end
    if iscell(ntsLW), ntsLW=ntsLW{1}; end
    if isempty(ntsAW) || isempty(ntsLW), continue; end
    
    % Learned AW last session
    Ta = TlearnAW(TlearnAW.Mouse==m,:); sessionDtA = max(Ta.DateTime);
    Ta = sortrows(Ta(Ta.DateTime==sessionDtA,:),"TrialIndex");
    trialUIDsA = unique(uint64(Ta.TrialUID),'stable');
    
    % Transfer LW first session
    Tt = TtransLW(TtransLW.Mouse==m,:); sessionDtT = min(Tt.DateTime);
    Tt = sortrows(Tt(Tt.DateTime==sessionDtT,:),"TrialIndex");
    trialUIDsT = unique(uint64(Tt.TrialUID),'stable');
    
    if isempty(trialUIDsA) || isempty(trialUIDsT), continue; end
    
    [CTT_AW, uid_AW] = iLocalBuildCTT(ntsAW, trialUIDsA, sampleRate, baselineSec);
    if isempty(CTT_AW), continue; end
    
    ntats_AW = squeeze(mean(CTT_AW, 2));
    bsl = ntats_AW(:,1:24);
    activeAW = ntats_AW(:,32) > mean(bsl,2) + 3*std(bsl,[],2);
    learnedActiveUIDs = uid_AW(activeAW);
    
    [CTT_LW, uid_LW] = iLocalBuildCTT(ntsLW, trialUIDsT, sampleRate, baselineSec);
    if isempty(CTT_LW), continue; end
    
    isInh = ismember(uid_LW, learnedActiveUIDs);
    nTotalCells(i) = numel(uid_LW);
    nInhCells(i) = sum(isInh);
    
    divTrAll(i) = TransferLearning.Divergence(CTT_LW);
    if sum(isInh)>=3, divTrInh(i) = TransferLearning.Divergence(CTT_LW(isInh,:,:)); end
    if sum(~isInh)>=3, divTrNon(i) = TransferLearning.Divergence(CTT_LW(~isInh,:,:)); end
end

keepT = isfinite(divTrInh);
divTrInh = divTrInh(keepT);
divTrNon = divTrNon(keepT);
divTrAll = divTrAll(keepT);
miceT = miceTransfer(keepT);

fprintf('\nTransfer LW 继承群: %d mice\n', numel(divTrInh));

% ===== Part 3: Statistical tests =====
fprintf('\n==================== NON-PAIRED TESTS ====================\n\n');

% Test A: Transfer LW 继承群 vs Naive LO 全细胞 (ranksum)
pA = ranksum(divTrInh, divNaiveLO_perMouse);
fprintf('[A] ★ Transfer LW 继承群 vs Naive LO 全细胞 (ranksum):\n');
fprintf('    Transfer Inherited: %.4f ± %.4f (n=%d)\n', mean(divTrInh), std(divTrInh)/sqrt(numel(divTrInh)), numel(divTrInh));
fprintf('    Naive LO all cells: %.4f ± %.4f (n=%d)\n', mean(divNaiveLO_perMouse), std(divNaiveLO_perMouse)/sqrt(numel(divNaiveLO_perMouse)), numel(divNaiveLO_perMouse));
if mean(divTrInh) < mean(divNaiveLO_perMouse), dir='<'; else, dir='>'; end
fprintf('    p = %.4g  (%s)\n\n', pA, dir);

% Test B: Transfer LW 非继承群 vs Naive LO 全细胞
pB = ranksum(divTrNon(isfinite(divTrNon)), divNaiveLO_perMouse);
fprintf('[B] Transfer LW 非继承群 vs Naive LO 全细胞 (ranksum):\n');
fprintf('    Transfer Non-inherited: %.4f ± %.4f (n=%d)\n', mean(divTrNon,'omitnan'), std(divTrNon,'omitnan')/sqrt(sum(isfinite(divTrNon))), sum(isfinite(divTrNon)));
fprintf('    Naive LO all cells: %.4f ± %.4f (n=%d)\n', mean(divNaiveLO_perMouse), std(divNaiveLO_perMouse)/sqrt(numel(divNaiveLO_perMouse)), numel(divNaiveLO_perMouse));
if mean(divTrNon,'omitnan') < mean(divNaiveLO_perMouse), dir='<'; else, dir='>'; end
fprintf('    p = %.4g  (%s)\n\n', pB, dir);

% Test C: Transfer LW 全细胞 vs Naive LO 全细胞 (same as previous "original bad test" but now with 3 datasets)
pC = ranksum(divTrAll, divNaiveLO_perMouse);
fprintf('[C] Transfer LW 全细胞 vs Naive LO 全细胞 (ranksum, 3 datasets):\n');
fprintf('    Transfer all: %.4f ± %.4f (n=%d)\n', mean(divTrAll), std(divTrAll)/sqrt(numel(divTrAll)), numel(divTrAll));
fprintf('    Naive LO all: %.4f ± %.4f (n=%d)\n', mean(divNaiveLO_perMouse), std(divNaiveLO_perMouse)/sqrt(numel(divNaiveLO_perMouse)), numel(divNaiveLO_perMouse));
if mean(divTrAll) < mean(divNaiveLO_perMouse), dir='<'; else, dir='>'; end
fprintf('    p = %.4g  (%s)\n\n', pC, dir);

% Print all values
fprintf('Naive LO per mouse divergence values (n=%d):\n', numel(divNaiveLO_perMouse));
for j = 1:numel(miceU)
    fprintf('  %s: %.4f (nCells=%.0f)\n', miceU(j), divNaiveLO_perMouse(j), nCellsNaiveLO(j));
end

%% === Local function ===
function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate, baselineSec)
    CTT = []; cellUIDs = uint64([]);
    if isempty(nts) || numel(trialUIDs)<2, return; end
    inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
    nts2 = nts(inTrial,:);
    if isempty(nts2), return; end
    uNts = unique(uint64(nts2.TrialUID));
    trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
    if numel(trialUIDs) < 2, return; end
    allC = unique(uint64(nts2.CellUID));
    traces = {}; keepU = [];
    for c = 1:numel(allC)
        cid = allC(c);
        rows = (uint64(nts2.CellUID)==cid);
        if sum(rows)<numel(trialUIDs), continue; end
        uid = uint64(nts2.TrialUID(rows)); sig = double(nts2.TrialSignal(rows,:));
        [tf,loc] = ismember(trialUIDs,uid);
        if ~all(tf), continue; end
        so = sig(loc,:);
        if any(~isfinite(so),'all'), continue; end
        traces{end+1,1} = so; keepU(end+1,1) = cid; %#ok<AGROW>
    end
    if isempty(traces), return; end
    nC = numel(traces); nTr = size(traces{1},1); nTi = size(traces{1},2);
    CTT = nan(nC,nTr,nTi);
    for c = 1:nC, CTT(c,:,:) = traces{c}; end
    idx0 = max(1,min(nTi, 3*sampleRate+round(baselineSec*sampleRate)));
    CTT = CTT - CTT(:,:,idx0);
    cellUIDs = uint64(keepU);
end
