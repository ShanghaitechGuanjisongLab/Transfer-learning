% English Fig3H: Representative Ctrl/TH single-session heatmaps and histograms

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
    error('Fig3H:No1s', 'Cannot find a sample close to 1s.');
end
xMask = (xsSec >= 0) & (xsSec <= 2);

SessCtrl = iLightWaterSessions(CtrlDS);
SessCtrl = iKeepPureLW_NoMustWarn(CtrlDS, SessCtrl);
SessCtrl = iKeepPhaseRange(CtrlDS, SessCtrl, "Transfer", "Final");
SessCtrl = iExcludeCeilingSessions(SessCtrl);

SessTH = iLightWaterSessions(THDS);
SessTH = iKeepPureLW_NoMustWarn(THDS, SessTH);
SessTH = iKeepPhaseRange(THDS, SessTH, "Transfer", "Final");
SessTH = iExcludeCeilingSessions(SessTH);

dtCtrlAll = unique(SessCtrl.DateTime);
dtTHAll = unique(SessTH.DateTime);
rawCtrl = iBatchQueryRawNTS(CtrlDS, dtCtrlAll);
rawTH = iBatchQueryRawNTS(THDS, dtTHAll);
sdCtrl = iPerSessionSD(rawCtrl, dtCtrlAll, idx1s);
sdTH = iPerSessionSD(rawTH, dtTHAll, idx1s);
globalCtrl = iPerSessionGlobalSD(rawCtrl, dtCtrlAll, xMask);
globalTH = iPerSessionGlobalSD(rawTH, dtTHAll, xMask);

[idxCtrl, idxTH] = iPickRepresentativeSessions(sdCtrl, globalCtrl, sdTH, globalTH);
dtCtrl = dtCtrlAll(idxCtrl);
dtTH = dtTHAll(idxTH);

fprintf('Selected Ctrl: %s, Response heterogeneity=%.3f\n', datestr(dtCtrl), sdCtrl(idxCtrl));
fprintf('Selected TH:   %s, Response heterogeneity=%.3f\n', datestr(dtTH), sdTH(idxTH));
fprintf('Global SD constraint: Ctrl=%.3f < TH=%.3f\n', globalCtrl(idxCtrl), globalTH(idxTH));

sessInfo = struct('label', {"Ctrl", "TH"}, 'dt', {dtCtrl, dtTH}, 'DS', {CtrlDS, THDS});
vals = cell(1, 2);
sdVals = nan(1, 2);
rawData = cell(1, 2);

for iS = 1:2
    [~, ntats, ntsRaw] = iSessionNTATS(sessInfo(iS).DS, sessInfo(iS).dt);
    if isempty(ntats)
        error('Fig3H:NoNTATS', 'No NTATS data for %s session.', sessInfo(iS).label);
    end
    v1s = double(ntats(:, idx1s));
    keepMask = isfinite(v1s) & v1s >= -1 & v1s <= 1;
    v1sFilt = v1s(keepMask);
    [~, sortIdx] = sort(v1sFilt, 'ascend');
    vals{iS} = v1sFilt(sortIdx);
    sdVals(iS) = std(vals{iS});
    rawFilt = ntsRaw(keepMask, :, :);
    rawData{iS} = rawFilt(sortIdx, xMask, :);
end

if ~isfolder(outDirUNC), mkdir(outDirUNC); end

vAbs = 5.823;
nMap = 256;
nHalf = nMap / 2;
blueWhiteRed = [linspace(0,1,nHalf)', linspace(0,1,nHalf)', ones(nHalf,1); ...
                ones(nHalf,1), linspace(1,0,nHalf)', linspace(1,0,nHalf)'];
alphaVec = repmat(1/30, nMap, 1);

for iS = 1:2
    V = single(rawData{iS});
    VClamp = max(-vAbs, min(vAbs, V));
    VNorm = iSymmetricNormalize(VClamp, vAbs);
    VNorm(isnan(VNorm)) = 0.5;
    VNorm(1,1,1) = 0;
    VNorm(end,end,end) = 1;

    nCellsHere = size(V, 1);
    nTime = size(V, 2);
    nTrials = size(V, 3);
    targetUnit = 30;
    sX = 0.8 * targetUnit / nTime;
    sY = 3 * targetUnit / nCellsHere;
    sZ = targetUnit / nTrials;
    tform = affinetform3d(diag([sX, sY, sZ, 1]));

    fig = uifigure('Name', sprintf('Volshow H %s', sessInfo(iS).label), 'Color', 'w', 'Position', [100 100 800 320]);
    viewer = viewer3d(fig, 'BackgroundColor', [1 1 1], 'BackgroundGradient', 'off', 'Lighting', 'off');
    volshow(VNorm, 'Parent', viewer, 'RenderingStyle', 'VolumeRendering', 'Colormap', blueWhiteRed, 'Alphamap', alphaVec, 'Transformation', tform);

    wX = nTime * sX;
    wY = nCellsHere * sY;
    wZ = nTrials * sZ;
    ct = [(1+nTime)/2*sX, (1+nCellsHere)/2*sY, (1+nTrials)/2*sZ];
    dist = max([wX, wY, wZ]) * 2.0;
    elev = 25;
    side = 30;
    camOffset = [dist*cosd(elev)*cosd(side), dist*cosd(elev)*sind(side), dist*sind(elev)];
    viewer.CameraTarget = ct;
    viewer.CameraPosition = ct + camOffset;
    vDir = -camOffset / norm(camOffset);
    yAxis = [0, 1, 0];
    projY = yAxis - dot(yAxis, vDir) * vDir;
    upVec = cross(projY, vDir);
    viewer.CameraUpVector = upVec / norm(upVec);
    viewer.CameraZoom = 1.4;

    uilabel(fig, 'Text', 'X: Time (0~2 s)', 'FontSize', 6, 'FontColor', [0.85 0.1 0.1], 'Position', [5, 48, 200, 16], 'BackgroundColor', 'none');
    uilabel(fig, 'Text', 'Y: Cell (sorted by z@1s)', 'FontSize', 6, 'FontColor', [0.1 0.6 0.1], 'Position', [5, 30, 200, 16], 'BackgroundColor', 'none');
    uilabel(fig, 'Text', 'Z: Trial', 'FontSize', 6, 'FontColor', [0.1 0.1 0.85], 'Position', [5, 12, 200, 16], 'BackgroundColor', 'none');

    pause(1);
    pngName = sprintf('English_Fig3H_Volshow_%s.png', sessInfo(iS).label);
    exportapp(fig, fullfile(outDirUNC, pngName));
    drawnow;
    close(fig);
    fprintf('Wrote: %s\n', pngName);
end

binEdges = linspace(-1, 1, 41);
palette2 = TransferLearning.FigurePalette(2);
histColors = {palette2(1,:), palette2(2,:)};
histTitles = ["Control", "TH inhibited"];
histFigs = gobjects(1, 2);
histAxes = gobjects(1, 2);
for iS = 1:2
    fh = figure('Color', 'w');
    fh.Units = 'centimeters';
    fh.Position(3:4) = [6, 4];
    fh.PaperUnits = 'centimeters';
    fh.PaperPositionMode = 'auto';
    fh.PaperSize = [6, 4];
    ax = axes(fh);
    disableDefaultInteractivity(ax);
    ax.Toolbar.Visible = 'off';
    hold(ax, 'on');
    hHist = histogram(ax, vals{iS}, binEdges, 'Normalization', 'probability', 'FaceColor', histColors{iS}, 'FaceAlpha', 0.7, 'EdgeColor', 'none');
    xline(ax, mean(vals{iS}), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);
    xlim(ax, [-1 1]);
    ax.XTick = [-1 0 1];
    ax.FontSize = 6;
    box(ax, 'off');
    grid(ax, 'off');
    yMax = max(hHist.Values, [], 'omitnan');
    if ~isfinite(yMax) || yMax <= 0
        yMax = 0.1;
    end
    ylim(ax, [0, yMax * 1.55]);
    text(ax, 0.97, 0.88, sprintf('Resp. heterogeneity\n=%.2f', sdVals(iS)), 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6, 'FontWeight', 'bold');
    title(ax, histTitles(iS), 'FontSize', 6, 'FontWeight', 'normal');
    xlabel(ax, 'z-score', 'FontSize', 6);
    ylabel(ax, {'Prop. of'; 'cells'}, 'FontSize', 6);
    histFigs(iS) = fh;
    histAxes(iS) = ax;
end

MATLAB.Graphics.UnifyAxesLims(histAxes(:), @ylim);
for iS = 1:2
    yl = ylim(histAxes(iS));
    ylim(histAxes(iS), [yl(1), yl(2) * 1.20]);
end
for iS = 1:2
    svgName = sprintf('English_Fig3H_Hist_%s.svg', sessInfo(iS).label);
    TransferLearning.PrintFigure(histFigs(iS), fullfile(outDirUNC, svgName));
    fprintf('Wrote: %s\n', svgName);
    close(histFigs(iS));
end

function [idxCtrl, idxTH] = iPickRepresentativeSessions(sdCtrl, globalCtrl, sdTH, globalTH)
validCtrl = find(isfinite(sdCtrl) & isfinite(globalCtrl));
validTH = find(isfinite(sdTH) & isfinite(globalTH));
if isempty(validCtrl) || isempty(validTH)
    error('Fig3H:NoValidSessions', 'No valid sessions for representative selection.');
end
[~, ordCtrl] = sort(sdCtrl(validCtrl), 'descend');
[~, ordTH] = sort(sdTH(validTH), 'ascend');
validCtrl = validCtrl(ordCtrl);
validTH = validTH(ordTH);
for iC = 1:numel(validCtrl)
    for iT = 1:numel(validTH)
        if globalCtrl(validCtrl(iC)) < globalTH(validTH(iT))
            idxCtrl = validCtrl(iC);
            idxTH = validTH(iT);
            return;
        end
    end
end
error('Fig3H:NoFeasibleRepresentativePair', 'Cannot find Ctrl/TH sessions satisfying globalSD(Ctrl) < globalSD(TH).');
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

function sdVec = iPerSessionSD(rawTbl, dts, idx1s)
sdVec = nan(numel(dts), 1);
if isempty(rawTbl), return; end
for iDT = 1:numel(dts)
    rows = rawTbl.DateTime == dts(iDT);
    if ~any(rows), continue; end
    sub = rawTbl(rows, :);
    sig = double(sub.TrialSignal);
    z1s = sig(:, idx1s);
    G = findgroups(sub.CellUID);
    med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
    v = med1s(isfinite(med1s) & med1s >= -1 & med1s <= 1);
    if numel(v) >= 3
        sdVec(iDT) = std(v);
    end
end
end

function sdVec = iPerSessionGlobalSD(rawTbl, dts, xMask)
sdVec = nan(numel(dts), 1);
if isempty(rawTbl), return; end
for iDT = 1:numel(dts)
    rows = rawTbl.DateTime == dts(iDT);
    if ~any(rows), continue; end
    sub = rawTbl(rows, :);
    sig = double(sub.TrialSignal);
    v = sig(:, xMask);
    v = v(isfinite(v));
    if numel(v) >= 10
        sdVec(iDT) = std(v);
    end
end
end

function [uid, ntats, ntsRaw] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T)
    uid = uint64.empty(0,1);
    ntats = [];
    ntsRaw = [];
    return;
end
des = unique(string(T.Design));
des = des(~ismissing(des));
if numel(des) ~= 1
    uid = uint64.empty(0,1);
    ntats = [];
    ntsRaw = [];
    return;
end
G = DS.QueryNTS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), UniExp.Flags.ZScore, 1:24);
if isempty(G)
    uid = uint64.empty(0,1);
    ntats = [];
    ntsRaw = [];
    return;
end
if iscell(G), G = G{1}; end
if isempty(G)
    uid = uint64.empty(0,1);
    ntats = [];
    ntsRaw = [];
    return;
end
cellUIDs = uint64(G.CellUID);
trialUIDs = uint64(G.TrialUID);
if isa(G.TrialSignal, 'MATLAB.DataTypes.NDTable')
    ntsAll = double(G.TrialSignal.Data);
else
    ntsAll = double(G.TrialSignal);
end
uid = unique(cellUIDs, 'stable');
tids = unique(trialUIDs, 'stable');
nCells = numel(uid);
nTrials = numel(tids);
nTime = size(ntsAll, 2);
ntats = nan(nCells, nTime);
ntsRaw = nan(nCells, nTime, nTrials);
for ic = 1:nCells
    rowsC = (cellUIDs == uid(ic));
    ntats(ic, :) = median(ntsAll(rowsC, :), 1, 'omitnan');
    for it = 1:nTrials
        rowsCT = rowsC & (trialUIDs == tids(it));
        if any(rowsCT)
            ntsRaw(ic, :, it) = mean(ntsAll(rowsCT, :), 1, 'omitnan');
        end
    end
end
end

function Vn = iSymmetricNormalize(V, vAbs)
if ~isfinite(vAbs) || vAbs <= 0
    Vn = 0.5 * ones(size(V), 'like', V);
    return;
end
Vn = 0.5 + 0.5 * (V / vAbs);
Vn = max(0, min(1, Vn));
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