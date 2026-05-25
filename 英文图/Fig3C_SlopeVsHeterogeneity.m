% English Fig3C: Per-mouse complete learning-curve slope vs Response heterogeneity

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

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
xlabel(tl, 'Response heterogeneity', 'FontSize', 12);
hLegend = gobjects(2, 1);
axAll = gobjects(numel(layers), 1);
dataParts = cell(numel(layers), 1);

[SessUsedN, miceNAll, slopeNAll] = iNaiveSlopeData(DS_LAB, DS_LAI);
[SessUsedT, miceTAll, slopeTAll] = iSingleDatasetSlopeData(DS_T, "Transfer", "Final");

for iL = 1:numel(layers)
    layerName = layers(iL);
    layerLabel = layerLabels(iL);
    sdNAll = iNaiveHeterogeneityByLayer(SessUsedN, miceNAll, DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName);
    sdTAll = iSingleDatasetHeterogeneityByLayer(SessUsedT, miceTAll, DS_T, CellT, idx1s, layerName);
    [slopeN, sdN, miceN] = iKeepFiniteLayerData(miceNAll, slopeNAll, sdNAll);
    [slopeT, sdT, miceT] = iKeepFiniteLayerData(miceTAll, slopeTAll, sdTAll);

    slopeAll = [slopeN; slopeT];
    sdAll = [sdN; sdT];
    mouseAll = [miceN; miceT];
    groupAll = [repmat("Naive", numel(miceN), 1); repmat("Transfer", numel(miceT), 1)];
    use = isfinite(slopeAll) & isfinite(sdAll);
    dataParts{iL} = table(repmat(layerLabel, nnz(use), 1), groupAll(use), mouseAll(use), sdAll(use), slopeAll(use), ...
        'VariableNames', {'Layer','Group','Mouse','Heterogeneity','Slope'});
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
    ax.LineWidth = 2;
    box(ax, 'off');

    maskN = use & (groupAll == "Naive");
    maskT = use & (groupAll == "Transfer");
    hN = scatter(ax, sdAll(maskN), slopeAll(maskN), 10, colorN, 'o', 'filled', 'LineWidth', 0.2);
    hT = scatter(ax, sdAll(maskT), slopeAll(maskT), 10, colorT, 's', 'filled', 'LineWidth', 0.2);
    if iL == 1
        hLegend = [hN; hT];
        ylabel(ax, 'Sigmoid slope', 'FontSize', 12);
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
    fprintf('Naive n = %d mice\n', nnz(maskN));
    fprintf('Continual n = %d mice\n', nnz(maskT));
    fprintf('Spearman ρ=%.3f, p=%.4g\n', rho, p);
end

iUnifyYLimits(axAll(:));
fig3CDataTable = vertcat(dataParts{:});
assignin('base', 'Fig3C_SlopeVsHeterogeneity_Data', fig3CDataTable);
iAssertSharedMouseSlopesConsistent(fig3CDataTable);

lgd = legend(hLegend, {'Naive', 'Continual'}, 'FontSize', 12, 'Box', 'off', 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = 'English_Fig3C_SlopeVsHeterogeneity.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
iUnifyYLimits(axAll(:));
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

function [SessUsed, miceAll, slopeAll] = iNaiveSlopeData(DS_LAB, DS_LAI)
Sess = iGatherNaiveSessions(DS_LAB, DS_LAI);
Sess = iExcludeAudioWaterSessions(Sess, DS_LAB, DS_LAI);
[SessUsed, miceAll, slopeAll] = iPerMouseSlopeSessions(Sess);
end

function [SessUsed, miceAll, slopeAll] = iSingleDatasetSlopeData(DS, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
[SessUsed, miceAll, slopeAll] = iPerMouseSlopeSessions(Sess);
end

function sdAll = iNaiveHeterogeneityByLayer(SessUsed, miceAll, DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName)
if isempty(SessUsed)
    sdAll = nan(numel(miceAll), 1);
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
end

function sdAll = iSingleDatasetHeterogeneityByLayer(SessUsed, miceAll, DS, cellMap, idx1s, layerName)
if isempty(SessUsed)
    sdAll = nan(numel(miceAll), 1);
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
end

function [slopeVec, sdVec, miceKept] = iKeepFiniteLayerData(miceAll, slopeAll, sdAll)
keep = isfinite(slopeAll) & isfinite(sdAll);
slopeVec = slopeAll(keep);
sdVec = sdAll(keep);
miceKept = miceAll(keep);
end

function iAssertSharedMouseSlopesConsistent(dataTable)
if isempty(dataTable)
    return;
end
mouseId = string(dataTable.Group) + "|" + string(dataTable.Mouse);
[groupIndex, mouseIds] = findgroups(mouseId);
maxSlope = splitapply(@max, double(dataTable.Slope), groupIndex);
minSlope = splitapply(@min, double(dataTable.Slope), groupIndex);
badRows = (maxSlope - minSlope) > 1e-9 .* max(1, max(abs(maxSlope), abs(minSlope)));
if any(badRows)
    badText = mouseIds(badRows) + ": " + string(minSlope(badRows)) + " vs " + string(maxSlope(badRows));
    error('Fig3C:LayerSlopeMismatch', 'Shared mice have inconsistent slopes across layer tiles.\n%s', char(strjoin(badText, newline)));
end
end

function iUnifyYLimits(axList)
axList = axList(isgraphics(axList, 'axes'));
if numel(axList) < 2
    return;
end
yLimMat = vertcat(axList.YLim);
commonYLim = [min(yLimMat(:, 1)), max(yLimMat(:, 2))];
for iAx = 1:numel(axList)
    ylim(axList(iAx), commonYLim);
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
slopeVec = nan(numel(mice), 1);
keepRows = false(height(Sess), 1);
for iM = 1:numel(mice)
    m = mice(iM);
    R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
    if height(R) < 2, continue; end
    perf = double(R.Performance);
    finiteRows = isfinite(perf);
    R = R(finiteRows, :);
    perf = perf(finiteRows);
    if height(R) < 2, continue; end
    if numel(unique(perf)) < 2, continue; end
    usedDateTimes = R.DateTime;
    if ismember('Source', Sess.Properties.VariableNames)
        usedSources = unique(string(R.Source));
    else
        usedSources = strings(0,1);
    end
    fitTable = R(:, {'Mouse','DateTime','Performance'});
    fitTable.Group = repmat("Fit", height(fitTable), 1);
    fitTable = movevars(fitTable, 'Group', 'Before', 'Mouse');
    fitTable.Session = (1:height(fitTable))';
    fitOut = iFitSigmoidCurve(fitTable, m);
    slopeVec(iM) = fitOut.Slope;
    rows = string(Sess.Mouse) == m & ismember(Sess.DateTime, usedDateTimes);
    if ismember('Source', Sess.Properties.VariableNames)
        rows = rows & ismember(string(Sess.Source), usedSources);
    end
    keepRows = keepRows | rows;
end
SessUsed = Sess(keepRows, :);
end

function fitOut = iFitSigmoidCurve(T, groupName)
T = sortrows(T, {'Mouse','DateTime'});
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
    error('Fig3C:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
end
slopeStarts = [0, 0.2, 0.8, 2, 5, 20];
midpointStarts = unique([median(xObs), min(xObs), max(xObs), min(xObs) - numel(xObs), max(xObs) + numel(xObs)]);
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
obj = @(p) sum((yObs - iSigmoidFromFixedLowerParams(p, xObs)).^2, 'omitnan');
bestSse = inf;
p = [sqrt(0.8); median(xObs)];
for iSlope = 1:numel(slopeStarts)
    for iMidpoint = 1:numel(midpointStarts)
        p0 = [sqrt(slopeStarts(iSlope)); midpointStarts(iMidpoint)];
        pTry = fminsearch(obj, p0, opt);
        sseTry = obj(pTry);
        if sseTry < bestSse
            bestSse = sseTry;
            p = pTry;
        end
    end
end
yHat = iSigmoidFromFixedLowerParams(p, xObs);
[lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(p);
sse = sum((yObs - yHat).^2, 'omitnan');
sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if sst == 0
    rSquared = NaN;
else
    rSquared = 1 - sse / sst;
end
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.ParamRaw = p;
fitOut.Lower = lower;
fitOut.Upper = upper;
fitOut.Slope = slope;
fitOut.Midpoint = midpoint;
fitOut.SSE = sse;
fitOut.RSquared = rSquared;
fitOut.XObserved = xObs;
fitOut.YObserved = yObs;
end

function y = iSigmoidFromFixedLowerParams(p, x)
[lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(p)
lower = 0;
upper = 1;
slope = p(1).^2;
midpoint = p(2);
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
    ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', "DateTime");
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

