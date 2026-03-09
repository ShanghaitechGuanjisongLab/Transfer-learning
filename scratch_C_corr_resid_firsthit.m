% 临时探索：排除首会话命中率效应后的斜率 vs 响应异质性
% 复用当前正式版 C 图纳入规则。
% 对每只鼠，从用于拟合学习斜率的首个会话提取命中率，
% 再将 slope ~ firstHit 做线性残差化，用残差斜率与异质性做 Spearman 相关。

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
    error('scratch_C_corr_resid_firsthit:No1s', 'Cannot find sample close to 1s in time axis.');
end

[slopeN, sdN, firstHitN, miceN] = iNaiveCohortData(DS_LAB, DS_LAI, idx1s);
[slopeT, sdT, firstHitT, miceT] = iTransferCohortData(DS_Transfer, idx1s, "Transfer", "Final");

slopeAll = [slopeN; slopeT];
sdAll = [sdN; sdT];
firstHitAll = [firstHitN; firstHitT];
miceAll = [miceN; miceT];
groupAll = [repmat("Naive", numel(miceN), 1); repmat("Transfer", numel(miceT), 1)];

use = isfinite(slopeAll) & isfinite(sdAll) & isfinite(firstHitAll);
fprintf('Naive cohort:    %d mice\n', numel(miceN));
fprintf('Transfer cohort: %d mice\n', numel(miceT));
fprintf('Pooled n:        %d mice\n', nnz(use));

[rhoRaw, pRaw] = corr(sdAll(use), slopeAll(use), 'Type', 'Spearman');
b = polyfit(firstHitAll(use), slopeAll(use), 1);
slopeResid = nan(size(slopeAll));
slopeResid(use) = slopeAll(use) - polyval(b, firstHitAll(use));
[rhoResid, pResid] = corr(sdAll(use), slopeResid(use), 'Type', 'Spearman');

[rhoFirstSlope, pFirstSlope] = corr(firstHitAll(use), slopeAll(use), 'Type', 'Spearman');
[rhoFirstSD, pFirstSD] = corr(firstHitAll(use), sdAll(use), 'Type', 'Spearman');

fprintf('\nRaw correlation:\n');
fprintf('  rho = %.6f, p = %.6g\n', rhoRaw, pRaw);
fprintf('Residualized slope correlation:\n');
fprintf('  rho = %.6f, p = %.6g\n', rhoResid, pResid);
fprintf('Slope ~ firstHit linear fit:\n');
fprintf('  slope = %.6f * firstHit + %.6f\n', b(1), b(2));
fprintf('FirstHit vs slope: rho = %.6f, p = %.6g\n', rhoFirstSlope, pFirstSlope);
fprintf('FirstHit vs heterogeneity: rho = %.6f, p = %.6g\n', rhoFirstSD, pFirstSD);

resultTbl = table(miceAll(use), groupAll(use), firstHitAll(use), slopeAll(use), slopeResid(use), sdAll(use), ...
    'VariableNames', {'Mouse','Group','FirstHit','Slope','SlopeResid','Heterogeneity'});
disp(resultTbl);

f = figure('Color', 'w', 'Name', 'Fig3C residualized by first hit');
f.Units = 'centimeters';
f.Position(3:4) = [6.5, 5.5];
ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 6;

colorN = [0.8500 0.3250 0.0980];
colorT = [0      0.4470 0.7410];
fitColor = [0.4 0.4 0.4];

maskN = use & groupAll == "Naive";
maskT = use & groupAll == "Transfer";
hN = scatter(ax, sdAll(maskN), slopeResid(maskN), 12, colorN, 'o', 'filled', 'LineWidth', 0.2);
hT = scatter(ax, sdAll(maskT), slopeResid(maskT), 12, colorT, 's', 'filled', 'LineWidth', 0.2);

if nnz(use) >= 2 && std(sdAll(use)) > 0
    pFit = polyfit(sdAll(use), slopeResid(use), 1);
    xFit = [min(sdAll(use)), max(sdAll(use))];
    plot(ax, xFit, polyval(pFit, xFit), '-', 'Color', fitColor, 'LineWidth', 1);
end

legend(ax, [hN, hT], {'Naive', 'Transfer'}, 'FontSize', 5, 'Box', 'off', 'Location', 'best');
xlabel(ax, 'Response heterogeneity', 'FontSize', 6);
ylabel(ax, 'Residualized learning slope', 'FontSize', 6);
text(ax, 0.97, 0.97, sprintf('rho=%.3f\np=%s\nn=%d', rhoResid, iPString(pResid), nnz(use)), ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
pngUNC = fullfile(outDirUNC, 'English_Fig3C_ResidualizedByFirstHit.png');
pngLocal = fullfile(outDirLocal, 'English_Fig3C_ResidualizedByFirstHit.png');
exportgraphics(f, pngUNC, 'Resolution', 300);
exportgraphics(f, pngLocal, 'Resolution', 300);
fprintf('\nWrote: %s\n', pngUNC);
fprintf('Wrote: %s\n', pngLocal);

function [slopeVec, sdVec, firstHitVec, miceKept] = iNaiveCohortData(DS_LAB, DS_LAI, idx1s)
Sess = iGatherNaiveSessions(DS_LAB, DS_LAI);
Sess = iExcludeAudioWaterSessions(Sess, DS_LAB, DS_LAI);
Sess = iExcludeCeilingNaive(Sess);
[SessUsed, miceAll, slopeVecAll, firstHitAll] = iPerMouseSlopeSessionsWithFirstHit(Sess);

if isempty(SessUsed)
    slopeVec = [];
    sdVec = [];
    firstHitVec = [];
    miceKept = string.empty(0,1);
    return;
end

rawParts = {};
for dsName = ["LAB"; "LAI"]'
    dts = unique(SessUsed.DateTime(SessUsed.Source == dsName));
    if isempty(dts), continue; end
    if dsName == "LAB"
        DS = DS_LAB;
    else
        DS = DS_LAI;
    end
    try
        ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
            UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
    catch
        continue;
    end
    if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
    part = ntsCell{1};
    part.CellUID = uint64(part.CellUID);
    part.DateTime = iNormDT(datetime(part.DateTime));
    part.Source = repmat(dsName, height(part), 1);
    rawParts{end+1} = part; %#ok<AGROW>
end

sdAll = iNaiveCurrentAlgorithm(rawParts, SessUsed, miceAll, idx1s);
keep = isfinite(slopeVecAll) & isfinite(sdAll) & isfinite(firstHitAll);
slopeVec = slopeVecAll(keep);
sdVec = sdAll(keep);
firstHitVec = firstHitAll(keep);
miceKept = miceAll(keep);
end

function [slopeVec, sdVec, firstHitVec, miceKept] = iTransferCohortData(DS, idx1s, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
[SessUsed, miceAll, slopeVecAll, firstHitAll] = iPerMouseSlopeSessionsWithFirstHit(Sess);

if isempty(SessUsed)
    slopeVec = [];
    sdVec = [];
    firstHitVec = [];
    miceKept = string.empty(0,1);
    return;
end

allUsedDTs = unique(SessUsed.DateTime);
try
    ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs), ...
        UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
    ntsCell = {};
end

rawParts = {};
if ~isempty(ntsCell) && ~isempty(ntsCell{1})
    rawTbl = ntsCell{1};
    rawTbl.CellUID = uint64(rawTbl.CellUID);
    rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
    rawParts = {rawTbl};
end

sdAll = iTransferCurrentAlgorithm(rawParts, Sess, SessUsed, miceAll, idx1s);
keep = isfinite(slopeVecAll) & isfinite(sdAll) & isfinite(firstHitAll);
slopeVec = slopeVecAll(keep);
sdVec = sdAll(keep);
firstHitVec = firstHitAll(keep);
miceKept = miceAll(keep);
end

function sdAll = iNaiveCurrentAlgorithm(rawParts, SessUsed, miceAll, idx1s)
if isempty(rawParts)
    sdAll = nan(numel(miceAll), 1);
    return;
end
rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
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

function sdAll = iTransferCurrentAlgorithm(rawParts, Sess, SessUsed, miceAll, idx1s)
if isempty(rawParts)
    sdAll = nan(numel(miceAll), 1);
    return;
end
rawTbl = rawParts{1};
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
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

function [SessUsed, mice, slopeVec, firstHitVec] = iPerMouseSlopeSessionsWithFirstHit(Sess)
if isempty(Sess)
    SessUsed = Sess;
    mice = string.empty(0,1);
    slopeVec = [];
    firstHitVec = [];
    return;
end

Sess = sortrows(Sess, {'Mouse','DateTime'});
mice = unique(string(Sess.Mouse));
nMice = numel(mice);
slopeVec = nan(nMice, 1);
firstHitVec = nan(nMice, 1);
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
    firstHitVec(iM) = yi(find(ok, 1, 'first'));

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

function out = iPString(p)
if ~isfinite(p)
    out = 'NaN';
elseif p < 0.001
    out = sprintf('%.1e', p);
else
    out = sprintf('%.4f', p);
end
end

function dt = iNormDT(dt)
try
    if isdatetime(dt) && ~isempty(dt.TimeZone)
        dt.TimeZone = '';
    end
catch
end
end