% English Fig3C2: Pairwise ΔHit vs Response heterogeneity
%
% One point = one adjacent session pair.
% For each pair:
%   - ΔHit = Performance(session k+1) - Performance(session k)
%   - Response heterogeneity = std of per-cell mean z@1s across the two sessions
%       after filtering cell means to [-1, 1]
%
% Cohorts combined:
%   - Naive   (LightAudioBaseline + LAInterspersed): Naive->Learned
%   - Transfer (AudioLightBaseline): Transfer->Final

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

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

%% 
f = figure('Color', 'w', 'Name', 'Fig3C2 Pairwise DeltaHit vs Response heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 4];
f.PaperSize = [6, 4];

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tl, 'Response heterogeneity', 'FontSize', 12);

hLegend = gobjects(2,1);
for iL = 1:numel(layers)
    layerName = layers(iL);
    layerLabel = layerLabels(iL);
    [dhN, sdN] = iNaivePairDataByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName);
    [dhT, sdT] = iSingleDatasetPairDataByLayer(DS_T, CellT, idx1s, "Transfer", "Final", layerName);

    useN = isfinite(dhN) & isfinite(sdN);
    useT = isfinite(dhT) & isfinite(sdT);
    xAll = [sdN(useN); sdT(useT)];
    yAll = [dhN(useN); dhT(useT)];
    if numel(xAll) >= 3 && std(xAll) > 0 && std(yAll) > 0
        [rho, p] = corr(xAll, yAll, 'Type', 'Spearman');
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
    ax.FontSize = 12;
    box(ax, 'off');
    hN = scatter(ax, sdN(useN), dhN(useN), 6, colorN, 'o', 'filled', 'LineWidth', 0.2);
    hT = scatter(ax, sdT(useT), dhT(useT), 6, colorT, 's', 'filled', 'LineWidth', 0.2);
    if iL == 1
        hLegend = [hN; hT];
                ylabel(ax, 'ΔHit', 'FontSize', 12);
    end
    if numel(xAll) >= 2 && std(xAll) > 0
        b = polyfit(xAll, yAll, 1);
        xFit = [min(xAll), max(xAll)];
                plot(ax, xFit, polyval(b, xFit), '-', 'Color', colorFit, 'LineWidth', 2);
    end
        title(ax, layerLabel, 'FontSize', 12);
    text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
		'VerticalAlignment', 'top', 'FontSize', 12);

    fprintf('\n=== Fig3C2 %s ===\n', layerLabel);
    fprintf('Naive pairs: %d\n', nnz(useN));
    fprintf('Transfer pairs: %d\n', nnz(useT));
    fprintf('Spearman rho=%.3f, p=%.4g\n', rho, p);
end

lgd = legend(hLegend, {'Naive', 'Transfer'}, 'FontSize', 12, 'Box', 'off', 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3C2_PairwiseDeltaHitVsHeterogeneity.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

function [dhVec, sdVec] = iSingleDatasetPairDataByLayer(DS, cellMap, idx1s, phaseStart, phaseEnd, layerName)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
Sess = iExcludeCeilingSessions(Sess);
if isempty(Sess)
    dhVec = [];
    sdVec = [];
    return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

allDTs = unique(Sess.DateTime);
rawTbl = iBatchQueryRawNTS(DS, allDTs);
if isempty(rawTbl)
    dhVec = [];
    sdVec = [];
    return;
end
rawTbl = iAttachLayer(rawTbl, cellMap);
medTbl = iPerSessionCellMedianTable(rawTbl, idx1s, layerName);
[dhVec, sdVec] = iBuildPairVectors(Sess, medTbl, false);
end

function [dhVec, sdVec] = iNaivePairDataByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layerName)
Sess = iGatherNaiveSessions(DS_LAB, DS_LAI);
Sess = iExcludeAudioWaterSessions(Sess, DS_LAB, DS_LAI);
Sess = iExcludeCeilingNaive(Sess);
if isempty(Sess)
    dhVec = [];
    sdVec = [];
    return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

rawParts = {};
srcNames = ["LAB"; "LAI"];
srcDS = {DS_LAB; DS_LAI};
srcCellMaps = {CellLAB; CellLAI};
for i = 1:2
    dts = unique(Sess.DateTime(Sess.Source == srcNames(i)));
    if isempty(dts), continue; end
    part = iBatchQueryRawNTS(srcDS{i}, dts);
    if isempty(part), continue; end
    part.Source = repmat(srcNames(i), height(part), 1);
    part = iAttachLayer(part, srcCellMaps{i});
    rawParts{end+1} = part; %#ok<AGROW>
end
if isempty(rawParts)
    dhVec = [];
    sdVec = [];
    return;
end
medTbl = iPerSessionCellMedianTable(vertcat(rawParts{:}), idx1s, layerName);
[dhVec, sdVec] = iBuildPairVectors(Sess, medTbl, true);
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
if ismember('Source', rawTbl.Properties.VariableNames)
    [G, cellU, dtU, srcU] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
    med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
    medTbl = table(cellU, dtU, srcU, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
else
    [G, cellU, dtU] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
    med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
    medTbl = table(cellU, dtU, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
end
end

function [dhVec, sdVec] = iBuildPairVectors(Sess, medTbl, hasSource)
dhVec = [];
sdVec = [];
mice = unique(string(Sess.Mouse));
for iM = 1:numel(mice)
    R = sortrows(Sess(string(Sess.Mouse) == mice(iM), :), 'DateTime');
    if height(R) < 2, continue; end
    for iP = 1:(height(R)-1)
        dh = double(R.Performance(iP+1)) - double(R.Performance(iP));
        if hasSource
            pairRows = medTbl(ismember(medTbl.DateTime, [R.DateTime(iP); R.DateTime(iP+1)]) & ...
                ismember(string(medTbl.Source), [string(R.Source(iP)); string(R.Source(iP+1))]), :);
        else
            pairRows = medTbl(ismember(medTbl.DateTime, [R.DateTime(iP); R.DateTime(iP+1)]), :);
        end
        if isempty(pairRows), continue; end
        [~, ~, ic] = unique(pairRows.CellUID);
        meanPerCell = accumarray(ic, pairRows.Med1s, [], @mean);
        vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
        if numel(vals) < 3, continue; end
        dhVec(end+1,1) = dh; %#ok<AGROW>
        sdVec(end+1,1) = std(vals); %#ok<AGROW>
    end
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
    Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
    return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
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
TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks, 'Keys','BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
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

function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','DateTime','Performance','Source'});
for iDS = 1:2
    if iDS == 1
        DS = LAB; srcName = "LAB";
    else
        DS = LAI; srcName = "LAI";
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

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
    rows = find(AllSess.Mouse == m);
    p = double(AllSess.Performance(rows));
    i100 = find(p >= 1 - 1e-12, 1, 'first');
    if ~isempty(i100), remove(rows(i100:end)) = true; end
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
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
