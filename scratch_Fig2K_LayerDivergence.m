% 临时探索：Fig2K divergence 按层(L2/L5)分别计算，检验差异
% 复用 Fig2K 逻辑，但按层筛选细胞

baselineSec = 0;
useCellFilter = true;
sampleRate = 8;

% --- Datasets ---
SourcesNaive = {
    builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
    builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};
SourcesTransfer = {
    builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
};

layers = ["L2", "L5"];
resultTable = table();

for iLayer = 1:numel(layers)
    layerName = layers(iLayer);
    fprintf('\n=== Layer: %s ===\n', layerName);
    
    % Naive LightOnly
    allDivN = [];
    for iS = 1:numel(SourcesNaive)
        DS = SourcesNaive{iS}.DS;
        srcName = SourcesNaive{iS}.Name;
        C = DS.Cells; C.ZLayer = string(C.ZLayer); C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse);
        divs = iComputeDivByLayer(DS, srcName, "Naive", "LightOnly", baselineSec, useCellFilter, C, layerName, sampleRate);
        allDivN = [allDivN; divs]; %#ok<AGROW>
    end
    
    % Transfer LightWater
    allDivT = [];
    for iS = 1:numel(SourcesTransfer)
        DS = SourcesTransfer{iS}.DS;
        srcName = SourcesTransfer{iS}.Name;
        C = DS.Cells; C.ZLayer = string(C.ZLayer); C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse);
        divs = iComputeDivByLayer(DS, srcName, "Transfer", "LightWater", baselineSec, useCellFilter, C, layerName, sampleRate);
        allDivT = [allDivT; divs]; %#ok<AGROW>
    end
    
    keepN = isfinite(allDivN); keepT = isfinite(allDivT);
    divN = allDivN(keepN); divT = allDivT(keepT);
    
    fprintf('  Naive mice=%d, Transfer mice=%d\n', numel(divN), numel(divT));
    if numel(divN) >= 2 && numel(divT) >= 2
        p = ranksum(divN, divT);
        fprintf('  Naive: mean=%.4f ± %.4f (SEM)\n', mean(divN), std(divN)/sqrt(numel(divN)));
        fprintf('  Transfer: mean=%.4f ± %.4f (SEM)\n', mean(divT), std(divT)/sqrt(numel(divT)));
        fprintf('  Wilcoxon rank-sum p = %.6g\n', p);
        
        row = table(layerName, numel(divN), numel(divT), ...
            mean(divN), std(divN)/sqrt(numel(divN)), ...
            mean(divT), std(divT)/sqrt(numel(divT)), p, ...
            'VariableNames', {'Layer','N_Naive','N_Transfer','Mean_Naive','SEM_Naive','Mean_Transfer','SEM_Transfer','P_RankSum'});
        resultTable = [resultTable; row]; %#ok<AGROW>
    else
        fprintf('  Not enough data\n');
    end
end

fprintf('\n=== Summary ===\n');
disp(resultTable);

%% === Local functions ===

function divVec = iComputeDivByLayer(DS, sourceName, phaseName, stimulusName, baselineSec, useCellFilter, cellTable, layerName, sampleRate)
T = DS.TableQuery(["Mouse","DateTime"], Phase=phaseName, Stimulus=stimulusName);
if isempty(T)
    divVec = [];
    return
end
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
try T.DateTime.TimeZone = ''; catch, end

mice = unique(T.Mouse);
divVec = nan(numel(mice), 1);

for i = 1:numel(mice)
    m = mice(i);
    dts = T.DateTime(T.Mouse == m);
    sessionDt = max(dts);
    
    ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Mouse', string(m)), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsCell) && ~isempty(ntsCell)
        nts = ntsCell{1};
    else
        nts = ntsCell;
    end
    if isempty(nts), continue; end
    
    Ts = DS.TableQuery(["TrialUID","TrialIndex"], Phase=phaseName, Stimulus=stimulusName, Mouse=m, DateTime=sessionDt);
    if isempty(Ts), continue; end
    Ts = sortrows(Ts, "TrialIndex");
    trialUIDs = unique(uint64(Ts.TrialUID), 'stable');
    
    inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
    nts2 = nts(inTrial, :);
    if isempty(nts2), continue; end
    uNts = unique(uint64(nts2.TrialUID));
    trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
    if numel(trialUIDs) < 2, continue; end
    
    % Cell filter (late-peak)
    if useCellFilter
        queryStruct = struct('Stimulus', string(stimulusName), 'Phase', string(phaseName), 'Mouse', string(m), 'DateTime', sessionDt);
        ntatsG = DS.QueryNTATS(queryStruct, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
        keepUids = iSelectLatePeakCells(ntatsG, sampleRate);
    else
        keepUids = unique(uint64(nts2.CellUID));
    end
    if isempty(keepUids), continue; end
    
    % Layer filter
    mouseLayer = cellTable(cellTable.Mouse == m, :);
    layerUIDs = mouseLayer.CellUID(mouseLayer.ZLayer == layerName);
    keepUids = intersect(keepUids, layerUIDs);
    if numel(keepUids) < 3, continue; end
    
    divVec(i) = iDivForSession(nts2, trialUIDs, keepUids, baselineSec, sampleRate);
end

keep = isfinite(divVec);
fprintf('  %s %s %s [%s]: %d/%d mice\n', sourceName, phaseName, stimulusName, layerName, sum(keep), numel(mice));
divVec = divVec(keep);
end

function keepUids = iSelectLatePeakCells(ntatsGroup, sampleRate)
keepUids = uint64([]);
if isempty(ntatsGroup) || height(ntatsGroup) == 0, return; end
data = squeeze(ntatsGroup.NTATS{:,:,1});
if ~ismatrix(data), return; end
cellUIDs = uint64(ntatsGroup.CellUID);
idxCue0 = 3 * sampleRate;
idx0 = max(1, min(size(data, 2), idxCue0));
sigNtats = data - data(:, idx0);
idx0_1 = idxCue0:(idxCue0 + sampleRate);
idx1_2 = (idxCue0 + sampleRate):(idxCue0 + 2 * sampleRate);
idx0_1 = idx0_1(idx0_1 >= 1 & idx0_1 <= size(sigNtats, 2));
idx1_2 = idx1_2(idx1_2 >= 1 & idx1_2 <= size(sigNtats, 2));
if isempty(idx0_1) || isempty(idx1_2), return; end
peak0_1 = max(sigNtats(:, idx0_1), [], 2);
peak1_2 = max(sigNtats(:, idx1_2), [], 2);
keepUids = cellUIDs(peak1_2 > peak0_1);
end

function div = iDivForSession(nts2, trialUIDs, keepUids, baselineSec, sampleRate)
div = nan;
cellUIDs = unique(uint64(nts2.CellUID));
cellUIDs = cellUIDs(ismember(cellUIDs, uint64(keepUids)));
if isempty(cellUIDs), return; end

cellTraces = cell(0,1);
for iC = 1:numel(cellUIDs)
    cid = cellUIDs(iC);
    rowsC = (uint64(nts2.CellUID) == cid);
    if sum(rowsC) < numel(trialUIDs), continue; end
    uid = uint64(nts2.TrialUID(rowsC));
    sig = double(nts2.TrialSignal(rowsC, :));
    [tf, loc] = ismember(trialUIDs, uid);
    if ~all(tf), continue; end
    sigOrdered = sig(loc, :);
    if any(~isfinite(sigOrdered), 'all'), continue; end
    cellTraces{end+1, 1} = sigOrdered; %#ok<AGROW>
end

if isempty(cellTraces), return; end

nCells = numel(cellTraces);
nTrials = size(cellTraces{1}, 1);
nTime = size(cellTraces{1}, 2);
CellTrialTimes = nan(nCells, nTrials, nTime);
for iC = 1:nCells
    CellTrialTimes(iC,:,:) = cellTraces{iC};
end

idx0 = 3 * sampleRate + round(baselineSec * sampleRate);
idx0 = max(1, min(nTime, idx0));
baseline0 = CellTrialTimes(:,:,idx0);
CellTrialTimes = CellTrialTimes - baseline0;

div = TransferLearning.Divergence(CellTrialTimes);
end
