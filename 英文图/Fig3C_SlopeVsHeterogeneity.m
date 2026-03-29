% English Fig3C: Per-mouse learning slope vs Response heterogeneity

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_T = TransferLearning.AudioLightBaseline();
CellLAB = iCellLayerTable(DS_LAB, "LAB");
CellLAI = iCellLayerTable(DS_LAI, "LAI");
CellT = iCellLayerTable(DS_T, "Transfer");

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
    error('Fig3C:No1s', 'Cannot find sample close to 1s in time axis.');
end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];
palette3 = TransferLearning.FigurePalette(3);
colorN = palette3(1,:);
colorT = palette3(2,:);
colorFit = palette3(3,:);

f = figure('Color', 'w', 'Name', 'Fig3C Slope vs Response heterogeneity by layer');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tl, 'Response heterogeneity', 'FontSize', 12);
hLegend = gobjects(2, 1);
axAll = gobjects(numel(layers), 1);

for iL = 1:numel(layers)
    layerName = layers(iL);
    layerLabel = layerLabels(iL);
    [slopeN, sdN, miceN] = iNaiveCohortDataByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName);
    [slopeT, sdT, miceT] = iSingleDatasetCohortDataByLayer(DS_T, CellT, idx1s, "Transfer", "Final", layerName);

    slopeAll = [slopeN; slopeT];
    sdAll = [sdN; sdT];
    groupAll = [repmat("Naive", numel(miceN), 1); repmat("Transfer", numel(miceT), 1)];
    use = isfinite(slopeAll) & isfinite(sdAll);
    if nnz(use) >= 3 && std(sdAll(use)) > 0 && std(slopeAll(use)) > 0
        [rho, p] = corr(sdAll(use), slopeAll(use), 'Type', 'Spearman');
    else
        rho = NaN;
        p = NaN;
    end

    if ~isfinite(p)
        pLabel = 'p = NaN';
    elseif p < 0.001
        pLabel = 'p < 0.001';
    elseif p < 0.01
        pLabel = sprintf('p = %.3f', p);
    else
        pLabel = sprintf('p = %.2f', p);
    end

    ax = nexttile(tl, iL);
    hold(ax, 'on');
    ax.FontSize = 12;
    box(ax, 'off');

    maskN = use & (groupAll == "Naive");
    maskT = use & (groupAll == "Transfer");
    hN = scatter(ax, sdAll(maskN), slopeAll(maskN), 5, colorN, 'o', 'filled', 'LineWidth', 0.2);
    hT = scatter(ax, sdAll(maskT), slopeAll(maskT), 5, colorT, 's', 'filled', 'LineWidth', 0.2);
    if iL == 1
        hLegend = [hN; hT];
        ylabel(ax, 'Learning slope', 'FontSize', 12);
    else
        ax.YAxis.Visible = 'off';
    end
    if nnz(use) >= 2 && std(sdAll(use)) > 0
        fitP = polyfit(sdAll(use), slopeAll(use), 1);
        xFit = [min(sdAll(use)), max(sdAll(use))];
        plot(ax, xFit, polyval(fitP, xFit), '-', 'Color', colorFit, 'LineWidth', 2);
    end

    title(ax, layerLabel, 'FontSize', 12);
    text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12);
    axAll(iL) = ax;

    fprintf('\n=== Fig3C %s ===\n', layerLabel);
    fprintf('Naive mice: %d\n', nnz(maskN));
    fprintf('Transfer mice: %d\n', nnz(maskT));
    fprintf('Spearman rho=%.3f, p=%.4g\n', rho, p);
end

MATLAB.Graphics.UnifyAxesLims(axAll(:), @ylim);

lgd = legend(hLegend, {'Naive', 'Transfer'}, 'FontSize', 12, 'Box', 'off', 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3C_SlopeVsHeterogeneity.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

function [slopeVec, sdVec, miceKept] = iNaiveCohortDataByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName)
Sess = iGatherNaiveSessions(DS_LAB, DS_LAI);
Sess = iExcludeAudioWaterSessions(Sess, DS_LAB, DS_LAI);
Sess = iExcludeCeilingSessions(Sess);
[SessUsed, miceAll, slopeAll] = iPerMouseSlopeSessions(Sess);
if isempty(SessUsed)
    slopeVec = [];
    sdVec = [];
    miceKept = string.empty(0,1);
    return;
end

rawParts = {};
srcNames = ["LAB"; "LAI"];
srcDS = {DS_LAB; DS_LAI};
srcCellMaps = {CellLAB; CellLAI};
for i = 1:2
    dts = unique(SessUsed.DateTime(SessUsed.Source == srcNames(i)));
    if isempty(dts), continue; end
    part = iBatchQueryRawNTS(srcDS{i}, dts);
    if isempty(part), continue; end
    part.Source = repmat(srcNames(i), height(part), 1);
    part = iAttachLayer(part, srcCellMaps{i});
    rawParts{end+1} = part; %#ok<AGROW>
end
if isempty(rawParts)
    sdAll = nan(numel(miceAll), 1);
else
    medTbl = iPerSessionCellMedianTable(vertcat(rawParts{:}), idx1s, layerName, true);
    sdAll = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll, true);
end
keep = isfinite(slopeAll) & isfinite(sdAll);
slopeVec = slopeAll(keep);
sdVec = sdAll(keep);
miceKept = miceAll(keep);
end

function [slopeVec, sdVec, miceKept] = iSingleDatasetCohortDataByLayer(DS, cellMap, idx1s, phaseStart, phaseEnd, layerName)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
Sess = iExcludeCeilingSessions(Sess);
[SessUsed, miceAll, slopeAll] = iPerMouseSlopeSessions(Sess);
if isempty(SessUsed)
    slopeVec = [];
    sdVec = [];
    miceKept = string.empty(0,1);
    return;
end
rawTbl = iBatchQueryRawNTS(DS, unique(SessUsed.DateTime));
if isempty(rawTbl)
    sdAll = nan(numel(miceAll), 1);
else
    rawTbl = iAttachLayer(rawTbl, cellMap);
    medTbl = iPerSessionCellMedianTable(rawTbl, idx1s, layerName, false);
    sdAll = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll, false);
end
keep = isfinite(slopeAll) & isfinite(sdAll);
slopeVec = slopeAll(keep);
sdVec = sdAll(keep);
miceKept = miceAll(keep);
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
slopeVec = nan(numel(mice), 1);
keepRows = false(height(Sess), 1);
for iM = 1:numel(mice)
    m = mice(iM);
    R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
    if height(R) < 2, continue; end
    first100 = find(double(R.Performance) >= 1 - 1e-12, 1, 'first');
    if ~isempty(first100)
        if first100 == 1, continue; end
        R = R(1:first100-1, :);
    end
    if height(R) < 2, continue; end
    xi = (1:height(R))';
    yi = double(R.Performance);
    ok = isfinite(yi);
    if nnz(ok) < 2, continue; end
    fitP = polyfit(xi(ok), yi(ok), 1);
    slopeVec(iM) = fitP(1);
    rows = string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime);
    if ismember('Source', Sess.Properties.VariableNames)
        rows = rows & ismember(string(Sess.Source), unique(string(R.Source)));
    end
    keepRows = keepRows | rows;
end
SessUsed = Sess(keepRows, :);
end

function sdVec = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll, hasSource)
sdVec = nan(numel(miceAll), 1);
if isempty(medTbl), return; end
for iM = 1:numel(miceAll)
    rowsSess = SessUsed(string(SessUsed.Mouse) == miceAll(iM), :);
    if isempty(rowsSess), continue; end
    if hasSource
        rowsMed = ismember(medTbl.DateTime, rowsSess.DateTime) & ismember(string(medTbl.Source), string(rowsSess.Source));
    else
        rowsMed = ismember(medTbl.DateTime, rowsSess.DateTime);
    end
    sub = medTbl(rowsMed, :);
    if isempty(sub), continue; end
    [~, ~, ic] = unique(sub.CellUID);
    meanPerCell = accumarray(ic, sub.Med1s, [], @mean);
    vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
    if numel(vals) >= 3
        sdVec(iM) = std(vals);
    end
end
end

function medTbl = iPerSessionCellMedianTable(rawTbl, idx1s, layerName, hasSource)
mask = iLayerMask(rawTbl.ZLayer, layerName);
rawTbl = rawTbl(mask, :);
if isempty(rawTbl)
    medTbl = table();
    return;
end
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
if hasSource
    [G, cellU, dtU, srcU] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
    med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
    medTbl = table(cellU, dtU, srcU, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
else
    [G, cellU, dtU] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
    med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
    medTbl = table(cellU, dtU, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
end
end

function rawTbl = iBatchQueryRawNTS(DS, dts)
q = struct('Stimulus', 'LightWater', 'DateTime', dts);
try
    ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
    rawTbl = table();
    return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
    rawTbl = table();
    return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
end

function S = iCellLayerTable(DS, sourceName)
S = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
S.Mouse = string(S.Mouse);
S.CellUID = uint64(S.CellUID);
S.ZLayer = string(S.ZLayer);
S.Source = repmat(string(sourceName), height(S), 1);
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

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
blockVars = string(DS.Blocks.Properties.VariableNames);
if any(blockVars == "MustWarn")
    Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
else
    Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
    Blocks.MustWarn = strings(height(Blocks), 1);
end
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
keep = false(height(SessOut), 1);
for m = unique(string(SessOut.Mouse))'
    dtM = DT(DT.Mouse == m, :);
    phDates = dtM.DateTime(dtM.Phase == phaseStart);
    endDates = dtM.DateTime(dtM.Phase == phaseEnd);
    if isempty(phDates) || isempty(endDates), continue; end
    startDT = min(phDates);
    endDT = max(endDates);
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
            idxEnd = find(sessPhase == "Transfer", 1, 'first') - 1;
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

function SessOut = iExcludeCeilingSessions(SessIn)
SessOut = sortrows(SessIn, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
    rows = find(SessOut.Mouse == m);
    p = double(SessOut.Performance(rows));
    i100 = find(p >= 1 - 1e-12, 1, 'first');
    if ~isempty(i100), remove(rows(i100:end)) = true; end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
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
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end