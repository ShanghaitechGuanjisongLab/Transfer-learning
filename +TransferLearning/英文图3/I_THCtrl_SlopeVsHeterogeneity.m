% English Fig3I: TH/Ctrl per-mouse learning slope vs Response heterogeneity

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();
CtrlCell = iCellLayerTable(CtrlDS, "Ctrl");
THCell = iCellLayerTable(THDS, "TH");

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
    error('Fig3I:No1s', 'Cannot find sample close to 1s in time axis.');
end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];
colorC = [238 124 121] / 255;
colorT = [0 0.4470 0.7410];

f = figure('Color', 'w', 'Name', 'Fig3I TH/Ctrl slope vs Response heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 4];
f.PaperSize = [6, 4];

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tl, 'Response heterogeneity', 'FontSize', 6);
hLegend = gobjects(2, 1);
axAll = gobjects(numel(layers), 1);

for iL = 1:numel(layers)
    layerName = layers(iL);
    [slopeC, sdC, miceC] = iSingleDatasetCohortDataByLayer(CtrlDS, CtrlCell, idx1s, "Transfer", "Final", layerName);
    [slopeT, sdT, miceT] = iSingleDatasetCohortDataByLayer(THDS, THCell, idx1s, "Transfer", "Final", layerName);

    slopeAll = [slopeC; slopeT];
    sdAll = [sdC; sdT];
    groupAll = [repmat("Ctrl", numel(miceC), 1); repmat("TH", numel(miceT), 1)];
    use = isfinite(slopeAll) & isfinite(sdAll);
    if nnz(use) >= 3 && std(sdAll(use)) > 0 && std(slopeAll(use)) > 0
        [rho, p] = corr(sdAll(use), slopeAll(use), 'Type', 'Spearman');
    else
        rho = NaN;
        p = NaN;
    end

    if p < 0.001
        pLabel = sprintf('p=%.1e', p);
    elseif p < 0.01
        pLabel = sprintf('p=%.4f', p);
    else
        pLabel = sprintf('p=%.2f', p);
    end

    ax = nexttile(tl, iL);
    hold(ax, 'on');
    ax.FontSize = 6;
    box(ax, 'off');

    maskC = use & (groupAll == "Ctrl");
    maskT = use & (groupAll == "TH");
    hC = scatter(ax, sdAll(maskC), slopeAll(maskC), 5, colorC, 'o', 'filled', 'LineWidth', 0.2);
    hT = scatter(ax, sdAll(maskT), slopeAll(maskT), 5, colorT, 's', 'filled', 'LineWidth', 0.2);
    if iL == 1
        hLegend = [hC; hT];
        ylabel(ax, 'Learning slope', 'FontSize', 6);
    else
        ax.YAxis.Visible = 'off';
    end
    if nnz(use) >= 2 && std(sdAll(use)) > 0
        fitP = polyfit(sdAll(use), slopeAll(use), 1);
        xFit = [min(sdAll(use)), max(sdAll(use))];
        plot(ax, xFit, polyval(fitP, xFit), '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
    end
    title(ax, layerLabels(iL), 'FontSize', 6);
    text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);
    axAll(iL) = ax;

    fprintf('\n=== Fig3I %s ===\n', layerLabels(iL));
    fprintf('Ctrl mice: %d\n', nnz(maskC));
    fprintf('TH mice: %d\n', nnz(maskT));
    fprintf('Spearman rho=%.3f, p=%.4g\n', rho, p);
end

MATLAB.Graphics.UnifyAxesLims(axAll(:), @ylim);

lgd = legend(hLegend, {'Ctrl', 'TH'}, 'FontSize', 6, 'Box', 'off', 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3I_THCtrl_SlopeVsHeterogeneity.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
close(f);

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
    medTbl = iPerSessionCellMedianTable(rawTbl, idx1s, layerName);
    sdAll = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll);
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
    keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
end
SessUsed = Sess(keepRows, :);
end

function sdVec = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll)
sdVec = nan(numel(miceAll), 1);
if isempty(medTbl), return; end
for iM = 1:numel(miceAll)
    rowsSess = SessUsed(string(SessUsed.Mouse) == miceAll(iM), :);
    if isempty(rowsSess), continue; end
    sub = medTbl(ismember(medTbl.DateTime, rowsSess.DateTime), :);
    if isempty(sub), continue; end
    [~, ~, ic] = unique(sub.CellUID);
    meanPerCell = accumarray(ic, sub.Med1s, [], @mean);
    vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
    if numel(vals) >= 3
        sdVec(iM) = std(vals);
    end
end
end

function medTbl = iPerSessionCellMedianTable(rawTbl, idx1s, layerName)
mask = iLayerMask(rawTbl.ZLayer, layerName);
rawTbl = rawTbl(mask, :);
if isempty(rawTbl)
    medTbl = table();
    return;
end
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
[G, cellU, dtU] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
medTbl = table(cellU, dtU, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
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

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end