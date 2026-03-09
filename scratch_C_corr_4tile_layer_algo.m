% 临时探索：L2/3、L5 × 两种异质性算法 的 Fig3C 相关性
% 算法A：Mean then SD
% 算法B：SD then Mean

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
outDirLocal = fullfile(pwd, 'Temp');
if ~isfolder(outDirLocal), mkdir(outDirLocal); end

DS_LAB      = TransferLearning.LightAudioBaseline();
DS_LAI      = TransferLearning.LAInterspersed();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
    error('scratch_C_corr_4tile_layer_algo:No1s', 'Cannot find sample close to 1s in time axis.');
end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];
algorithms = ["Current"; "TrialMean"];
algorithmLabels = ["Mean then SD"; "SD then Mean"];

CellLAB = iCellLayerTable(DS_LAB, "LAB");
CellLAI = iCellLayerTable(DS_LAI, "LAI");
CellTransfer = iCellLayerTable(DS_Transfer, "Transfer");

summaryRows = table('Size', [0 7], ...
    'VariableTypes', {'string','string','double','double','double','double','double'}, ...
    'VariableNames', {'Layer','Algorithm','NaiveN','TransferN','N','Rho','PValue'});

f = figure('Color', 'w', 'Name', 'Fig3C layer x algorithm');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

colorN = [0.8500 0.3250 0.0980];
colorT = [0      0.4470 0.7410];
fitColor = [0.4 0.4 0.4];
hLegend = gobjects(2, 1);

for iA = 1:numel(algorithms)
    algorithmName = algorithms(iA);
    algorithmLabel = algorithmLabels(iA);
    for iL = 1:numel(layers)
        layerName = layers(iL);
        layerLabel = layerLabels(iL);

        [slopeN, sdN, miceN] = iNaiveCohortData(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName, algorithmName);
        [slopeT, sdT, miceT] = iTransferCohortData(DS_Transfer, CellTransfer, idx1s, layerName, algorithmName);

        slopeAll = [slopeN; slopeT];
        sdAll = [sdN; sdT];
        grpAll = [repmat("Naive", numel(miceN), 1); repmat("Transfer", numel(miceT), 1)];
        use = isfinite(slopeAll) & isfinite(sdAll);

        if nnz(use) >= 3 && std(sdAll(use)) > 0 && std(slopeAll(use)) > 0
            [rho, p] = corr(sdAll(use), slopeAll(use), 'Type', 'Spearman');
        else
            rho = NaN;
            p = NaN;
        end

        row = table(layerLabel, algorithmLabel, numel(miceN), numel(miceT), nnz(use), rho, p, ...
            'VariableNames', summaryRows.Properties.VariableNames);
        summaryRows = [summaryRows; row]; %#ok<AGROW>

        fprintf('\n=== %s | %s ===\n', layerLabel, algorithmLabel);
        fprintf('Naive:    %d mice\n', numel(miceN));
        fprintf('Transfer: %d mice\n', numel(miceT));
        fprintf('Spearman rho = %.6f, p = %.6g, n = %d\n', rho, p, nnz(use));

        ax = nexttile(tl, (iA - 1) * 2 + iL);
        hold(ax, 'on');
        box(ax, 'off');
        ax.FontSize = 6;

        maskN = grpAll == "Naive" & use;
        maskT = grpAll == "Transfer" & use;
        hN = scatter(ax, sdAll(maskN), slopeAll(maskN), 10, colorN, 'o', 'filled', 'LineWidth', 0.2);
        hT = scatter(ax, sdAll(maskT), slopeAll(maskT), 10, colorT, 's', 'filled', 'LineWidth', 0.2);
        if iA == 1 && iL == 1
            hLegend = [hN; hT];
        end

        if nnz(use) >= 2 && std(sdAll(use)) > 0
            pFit = polyfit(sdAll(use), slopeAll(use), 1);
            xFit = [min(sdAll(use)), max(sdAll(use))];
            plot(ax, xFit, polyval(pFit, xFit), '-', 'Color', fitColor, 'LineWidth', 1);
        end

        title(ax, sprintf('%s | %s', layerLabel, algorithmLabel), 'FontSize', 6);
        xlabel(ax, 'Response heterogeneity', 'FontSize', 6);
        if iL == 1
            ylabel(ax, 'Learning slope', 'FontSize', 6);
        end

        text(ax, 0.97, 0.97, sprintf('p=%s', iPString(p)), ...
            'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);
    end
end

lgd = legend(hLegend, {'Naive', 'Transfer'}, 'FontSize', 5, 'Box', 'off');
lgd.Layout.Tile = 'south';

disp(summaryRows);

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
pngUNC = fullfile(outDirUNC, 'English_Fig3C_4Tile_LayerAlgorithm.png');
pngLocal = fullfile(outDirLocal, 'English_Fig3C_4Tile_LayerAlgorithm.png');
exportgraphics(f, pngUNC, 'Resolution', 300);
exportgraphics(f, pngLocal, 'Resolution', 300);
fprintf('\nWrote: %s\n', pngUNC);
fprintf('Wrote: %s\n', pngLocal);

function S = iCellLayerTable(DS, sourceName)
S = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
S.Mouse = string(S.Mouse);
S.CellUID = uint64(S.CellUID);
S.ZLayer = string(S.ZLayer);
S.Source = repmat(string(sourceName), height(S), 1);
end

function [slopeVec, sdVec, miceKept] = iNaiveCohortData(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName, algorithmName)
Sess = iGatherNaiveSessions(DS_LAB, DS_LAI);
Sess = iExcludeAudioWaterSessions(Sess, DS_LAB, DS_LAI);
Sess = iExcludeCeilingNaive(Sess);
[SessUsed, miceAll, slopeVecAll] = iPerMouseSlopeSessions(Sess);

if isempty(SessUsed)
    slopeVec = [];
    sdVec = [];
    miceKept = string.empty(0,1);
    return;
end

rawParts = {};
cellMaps = {CellLAB, CellLAI};
for iDS = 1:2
    if iDS == 1
        DS = DS_LAB;
        srcName = "LAB";
    else
        DS = DS_LAI;
        srcName = "LAI";
    end
    dts = unique(SessUsed.DateTime(SessUsed.Source == srcName));
    if isempty(dts), continue; end
    try
        ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
            UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime", "TrialUID"]);
    catch
        continue;
    end
    if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
    part = ntsCell{1};
    part.CellUID = uint64(part.CellUID);
    part.DateTime = iNormDT(datetime(part.DateTime));
    part.TrialUID = uint64(part.TrialUID);
    part.Source = repmat(srcName, height(part), 1);
    part = iAttachLayer(part, cellMaps{iDS});
    rawParts{end+1} = part; %#ok<AGROW>
end

if algorithmName == "Current"
    sdAll = iNaiveCurrentAlgorithm(rawParts, SessUsed, miceAll, idx1s, layerName);
else
    sdAll = iNaiveTrialMeanAlgorithm(rawParts, SessUsed, miceAll, idx1s, layerName);
end

keep = isfinite(slopeVecAll) & isfinite(sdAll);
slopeVec = slopeVecAll(keep);
sdVec = sdAll(keep);
miceKept = miceAll(keep);
end

function [slopeVec, sdVec, miceKept] = iTransferCohortData(DS, CellMap, idx1s, layerName, algorithmName)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, "Transfer", "Final");
[SessUsed, miceAll, slopeVecAll] = iPerMouseSlopeSessions(Sess);

if isempty(SessUsed)
    slopeVec = [];
    sdVec = [];
    miceKept = string.empty(0,1);
    return;
end

allUsedDTs = unique(SessUsed.DateTime);
try
    ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs), ...
        UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime", "TrialUID"]);
catch
    ntsCell = {};
end

rawParts = {};
if ~isempty(ntsCell) && ~isempty(ntsCell{1})
    rawTbl = ntsCell{1};
    rawTbl.CellUID = uint64(rawTbl.CellUID);
    rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
    rawTbl.TrialUID = uint64(rawTbl.TrialUID);
    rawTbl = iAttachLayer(rawTbl, CellMap);
    rawParts = {rawTbl};
end

if algorithmName == "Current"
    sdAll = iTransferCurrentAlgorithm(rawParts, Sess, SessUsed, miceAll, idx1s, layerName);
else
    sdAll = iTransferTrialMeanAlgorithm(rawParts, Sess, SessUsed, miceAll, idx1s, layerName);
end

keep = isfinite(slopeVecAll) & isfinite(sdAll);
slopeVec = slopeVecAll(keep);
sdVec = sdAll(keep);
miceKept = miceAll(keep);
end

function sdAll = iNaiveCurrentAlgorithm(rawParts, SessUsed, miceAll, idx1s, layerName)
if isempty(rawParts)
    sdAll = nan(numel(miceAll), 1);
    return;
end

rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
maskLayer = iLayerMask(rawTbl.ZLayer, layerName);
rawTbl = rawTbl(maskLayer, :);
z1s = z1s(maskLayer);
if isempty(rawTbl)
    sdAll = nan(numel(miceAll), 1);
    return;
end

[G1, cellU1, dtU1, srcU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouseMap = SessUsed(:, {'DateTime','Mouse','Source'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
dtMouseMap.Source = string(dtMouseMap.Source);
[~, iU] = unique(dtMouseMap(:, {'DateTime','Source'}), 'rows');
dtMouseMap = dtMouseMap(iU, :);

medTbl = table(cellU1, dtU1, srcU1, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', {'DateTime','Source'});

sdAll = nan(numel(miceAll), 1);
if isempty(medTbl), return; end
[G2, mouseU2, ~] = findgroups(medTbl.Mouse, medTbl.CellUID);
meanPerCell = splitapply(@mean, medTbl.Med1s, G2);
for iM = 1:numel(miceAll)
    vals = meanPerCell(string(mouseU2) == miceAll(iM));
    vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
    if numel(vals) >= 3
        sdAll(iM) = std(vals);
    end
end
end

function sdAll = iTransferCurrentAlgorithm(rawParts, Sess, SessUsed, miceAll, idx1s, layerName)
if isempty(rawParts)
    sdAll = nan(numel(miceAll), 1);
    return;
end

rawTbl = rawParts{1};
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
maskLayer = iLayerMask(rawTbl.ZLayer, layerName);
rawTbl = rawTbl(maskLayer, :);
z1s = z1s(maskLayer);
if isempty(rawTbl)
    sdAll = nan(numel(miceAll), 1);
    return;
end

[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouseMap = Sess(:, {'DateTime','Mouse'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);

medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');

medTbl2 = medTbl(false, :);
for iM = 1:numel(miceAll)
    sessRows = SessUsed(string(SessUsed.Mouse) == miceAll(iM), :);
    if isempty(sessRows), continue; end
    medTbl2 = [medTbl2; medTbl(string(medTbl.Mouse) == miceAll(iM) & ismember(medTbl.DateTime, sessRows.DateTime), :)]; %#ok<AGROW>
end

sdAll = nan(numel(miceAll), 1);
if isempty(medTbl2), return; end
[G2, mouseU2, ~] = findgroups(medTbl2.Mouse, medTbl2.CellUID);
meanPerCell = splitapply(@mean, medTbl2.Med1s, G2);
for iM = 1:numel(miceAll)
    vals = meanPerCell(string(mouseU2) == miceAll(iM));
    vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
    if numel(vals) >= 3
        sdAll(iM) = std(vals);
    end
end
end

function sdAll = iNaiveTrialMeanAlgorithm(rawParts, SessUsed, miceAll, idx1s, layerName)
if isempty(rawParts)
    sdAll = nan(numel(miceAll), 1);
    return;
end

rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
maskLayer = iLayerMask(rawTbl.ZLayer, layerName);
rawTbl = rawTbl(maskLayer, :);
z1s = z1s(maskLayer);
if isempty(rawTbl)
    sdAll = nan(numel(miceAll), 1);
    return;
end

dtMouseMap = SessUsed(:, {'DateTime','Mouse','Source'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
dtMouseMap.Source = string(dtMouseMap.Source);
[~, iU] = unique(dtMouseMap(:, {'DateTime','Source'}), 'rows');
dtMouseMap = dtMouseMap(iU, :);
rawTbl = innerjoin(rawTbl, dtMouseMap, 'Keys', {'DateTime','Source'});
if isempty(rawTbl)
    sdAll = nan(numel(miceAll), 1);
    return;
end

z1s = double(rawTbl.TrialSignal(:, idx1s));
[G, mouseU, ~, ~, ~] = findgroups(string(rawTbl.Mouse), string(rawTbl.Source), rawTbl.DateTime, rawTbl.TrialUID);
trialSD = splitapply(@iBoundedSD, z1s, G);

sdAll = nan(numel(miceAll), 1);
for iM = 1:numel(miceAll)
    vals = trialSD(string(mouseU) == miceAll(iM));
    vals = vals(isfinite(vals));
    if ~isempty(vals)
        sdAll(iM) = mean(vals, 'omitnan');
    end
end
end

function sdAll = iTransferTrialMeanAlgorithm(rawParts, Sess, SessUsed, miceAll, idx1s, layerName)
if isempty(rawParts)
    sdAll = nan(numel(miceAll), 1);
    return;
end

rawTbl = rawParts{1};
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
maskLayer = iLayerMask(rawTbl.ZLayer, layerName);
rawTbl = rawTbl(maskLayer, :);
z1s = z1s(maskLayer);
if isempty(rawTbl)
    sdAll = nan(numel(miceAll), 1);
    return;
end

dtMouseMap = Sess(:, {'DateTime','Mouse'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);
rawTbl = innerjoin(rawTbl, dtMouseMap, 'Keys', 'DateTime');

useRows = false(height(rawTbl), 1);
for iM = 1:numel(miceAll)
    sessRows = SessUsed(string(SessUsed.Mouse) == miceAll(iM), :);
    if isempty(sessRows), continue; end
    useRows = useRows | (string(rawTbl.Mouse) == miceAll(iM) & ismember(rawTbl.DateTime, sessRows.DateTime));
end
rawTbl = rawTbl(useRows, :);
if isempty(rawTbl)
    sdAll = nan(numel(miceAll), 1);
    return;
end

z1s = double(rawTbl.TrialSignal(:, idx1s));
[G, mouseU, ~, ~] = findgroups(string(rawTbl.Mouse), rawTbl.DateTime, rawTbl.TrialUID);
trialSD = splitapply(@iBoundedSD, z1s, G);

sdAll = nan(numel(miceAll), 1);
for iM = 1:numel(miceAll)
    vals = trialSD(string(mouseU) == miceAll(iM));
    vals = vals(isfinite(vals));
    if ~isempty(vals)
        sdAll(iM) = mean(vals, 'omitnan');
    end
end
end

function out = iBoundedSD(vals)
vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
if numel(vals) >= 3
    out = std(vals);
else
    out = NaN;
end
end

function T = iAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = cellMap.ZLayer(loc(has));
end

function mask = iLayerMask(zLayer, layerName)
mask = string(zLayer) == string(layerName);
end

function out = iPString(p)
if ~isfinite(p)
    out = 'NaN';
elseif p < 0.001
    out = sprintf('%.1e', p);
else
    out = sprintf('%.4f', p);
end
end

function [SessUsed, mice, slopeVec] = iPerMouseSlopeSessions(Sess)
if isempty(Sess)
    SessUsed = Sess;
    mice = string.empty(0,1);
    slopeVec = [];
    return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
mice = unique(string(Sess.Mouse));
nMice = numel(mice);
slopeVec = nan(nMice, 1);
keepRows = false(height(Sess), 1);
for iM = 1:nMice
    m = mice(iM);
    R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
    if height(R) < 2, continue; end
    first100 = find(double(R.Performance) >= 1.0, 1, 'first');
    if ~isempty(first100) && first100 > 1
        R = R(1:first100-1, :);
    elseif ~isempty(first100) && first100 == 1
        continue;
    end
    n = height(R);
    if n < 2, continue; end
    xi = (1:n)';
    yi = double(R.Performance);
    ok = isfinite(yi);
    if nnz(ok) < 2, continue; end
    pFit = polyfit(xi(ok), yi(ok), 1);
    slopeVec(iM) = pFit(1);
    rows = string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime);
    if ismember('Source', Sess.Properties.VariableNames)
        rows = rows & ismember(string(Sess.Source), unique(string(R.Source)));
    end
    keepRows = keepRows | rows;
end
SessUsed = Sess(keepRows, :);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
    Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
    return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
    m = mice(iM);
    dtM = DT(DT.Mouse == m, :);
    phDates = dtM.DateTime(dtM.Phase == phaseStart);
    endDates = dtM.DateTime(dtM.Phase == phaseEnd);
    if isempty(phDates) || isempty(endDates), continue; end
    startDT = min(phDates);
    endDT = max(endDates);
    if ismissing(startDT) || ismissing(endDT), continue; end
    rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
    keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','DateTime','Performance','Source'});
for iDS = 1:2
    if iDS == 1
        DS = LAB;
        srcName = "LAB";
    else
        DS = LAI;
        srcName = "LAI";
    end
    T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
    T.Mouse = string(T.Mouse);
    T.DateTime = iNormDT(datetime(T.DateTime));
    T.Phase = string(T.Phase);
    Tr = DS.Trials;
    mice = unique(T.Mouse);
    for iM = 1:numel(mice)
        m = mice(iM);
        Tm = T(T.Mouse == m, :);
        phases = unique(Tm.Phase);
        if ~any(phases == "Naive"), continue; end

        hasLearned = any(phases == "Learned");
        hasTransfer = any(phases == "Transfer");
        sessDTs = sort(unique(Tm.DateTime));
        sessPhase = strings(numel(sessDTs), 1);
        for ii = 1:numel(sessDTs)
            ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
            ph = ph(ph ~= "" & ~ismissing(ph));
            if isempty(ph)
                sessPhase(ii) = "";
                continue;
            end
            [uPh, ~, ic] = unique(ph);
            counts = accumarray(ic, 1);
            [~, mx] = max(counts);
            sessPhase(ii) = uPh(mx);
        end

        idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
        if hasLearned
            idxEnd = find(sessPhase == "Learned", 1, 'last');
        elseif hasTransfer
            idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
            idxEnd = idxTransferStart - 1;
        else
            idxEnd = numel(sessDTs);
        end
        if isempty(idxNaiveStart) || idxEnd < idxNaiveStart, continue; end

        for k = idxNaiveStart:idxEnd
            dt = sessDTs(k);
            blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
            TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
            if isempty(TrSess), continue; end
            lwMask = string(TrSess.Stimulus) == "LightWater";
            if ~any(lwMask), continue; end
            perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
            if ~isfinite(perf), continue; end
            AllSess = [AllSess; table(m, dt, perf, srcName, 'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
        end
    end
end
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows');
AllSess = AllSess(ia, :);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess), 1);
for i = 1:height(AllSess)
    if AllSess.Source(i) == "LAB"
        DS = LAB;
    else
        DS = LAI;
    end
    if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
        keep(i) = false;
    end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
    rows = find(AllSess.Mouse == m);
    p = double(AllSess.Performance(rows));
    i100 = find(p >= 1 - 1e-12, 1, 'first');
    if ~isempty(i100)
        remove(rows(i100:end)) = true;
    end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus));
st = st(~ismissing(st));
tf = any(st == string(stim));
end

function dt = iNormDT(dt)
try
    if isdatetime(dt) && ~isempty(dt.TimeZone)
        dt.TimeZone = '';
    end
catch
end
end