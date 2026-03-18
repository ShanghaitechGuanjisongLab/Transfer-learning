% English Fig3J: TH inhibition vs Ctrl - Delta hit and MOp5 response heterogeneity
%
% Two bar tiles comparing Ctrl and TH groups:
%   Top:    Delta hit per session pair
%   Bottom: Response heterogeneity per mouse in MOp5 only
%
% Ctrl: AudioLightBaseline (Transfer->Final)
% TH:   THInhibit          (Transfer->Final)
%
% Execution:
%   TransferLearning.英文图3.J_THInhibitVsCtrl_DeltaHitAndSD

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('Fig3J:No1s', 'Cannot find sample close to 1s.'); end

[dhC, sdC] = iCohortData(CtrlDS, idx1s, "Transfer", "Final", "MOp5");
[dhT, sdT] = iCohortData(THDS, idx1s, "Transfer", "Final", "MOp5");

fprintf('Ctrl: %d pairs (Delta hit), %d mice (MOp5 response heterogeneity)\n', numel(dhC), numel(sdC));
fprintf('TH:   %d pairs (Delta hit), %d mice (MOp5 response heterogeneity)\n', numel(dhT), numel(sdT));

pDH = iRanksumSafe(dhC, dhT);
pSD = iRanksumSafe(sdC, sdT);
fprintf('Delta hit ranksum p=%.4g\n', pDH);
fprintf('MOp5 response heterogeneity ranksum p=%.4g\n', pSD);

svgName = "English_Fig3J_THInhibitVsCtrl_DeltaHitAndSD.svg";
f = figure('Color', 'w', 'Name', 'Fig3J TH Delta hit and MOp5 response heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
palette2 = TransferLearning.FigurePalette(2);
colorA = palette2(1,:);
colorB = palette2(2,:);
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
pLineAll = gobjects(0, 1);
pTextAll = gobjects(0, 1);

nexttile(Layout, 1);
[~, Opt1, Bars1, EB1] = UniExp.BarScatterCompare({dhC, dhT}, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {};
ylabel(ax1, 'ΔHit', 'FontSize', 6);
legend(ax1, 'off');
box(ax1, 'off');
iStyleBars(Bars1, colorA, colorB);
iKeepUpperErrorBarOnly(EB1);
if isfield(Opt1, 'MultiCompare') && ismember('PText', Opt1.MultiCompare.Properties.VariableNames)
	for pt = Opt1.MultiCompare.PText(:)', pt.FontSize = 6; end
end
[pLineAll, pTextAll] = iAppendPLineHandles(Opt1, pLineAll, pTextAll);

nexttile(Layout, 2);
[~, Opt2, Bars2, EB2] = UniExp.BarScatterCompare({sdC, sdT}, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
ax2.FontSize = 6;
ax2.XTick = [1 2];
ax2.XTickLabel = {'Ctrl', 'TH'};
ylabel(ax2, 'Heterogeneity', 'FontSize', 6);
title(ax2, 'MOp5', 'FontSize', 6, 'FontWeight', 'normal');
legend(ax2, 'off');
box(ax2, 'off');
iStyleBars(Bars2, colorA, colorB);
iKeepUpperErrorBarOnly(EB2);
if isfield(Opt2, 'MultiCompare') && ismember('PText', Opt2.MultiCompare.Properties.VariableNames)
	for pt = Opt2.MultiCompare.PText(:)', pt.FontSize = 6; end
end
[pLineAll, pTextAll] = iAppendPLineHandles(Opt2, pLineAll, pTextAll);

if ~isempty(pLineAll) || ~isempty(pTextAll)
	MATLAB.Graphics.PLineRetune(pLineAll, pTextAll);
end

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
close(f);

function [dhVec, sdVec] = iCohortData(DS, idx1s, phaseStart, phaseEnd, layerName)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
if isempty(Sess)
	dhVec = [];
	sdVec = [];
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
nMice = numel(mice);
dhVec = [];
allUsedDTs = datetime.empty(0,1);
sessPerMouse = cell(nMice, 1);
for iM = 1:nMice
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	first100 = find(double(R.Performance) >= 1 - 1e-12, 1, 'first');
	if ~isempty(first100)
		if first100 == 1, continue; end
		R = R(1:first100-1, :);
	end
	if height(R) < 2, continue; end
	perf = double(R.Performance);
	dhVec = [dhVec; diff(perf)]; %#ok<AGROW>
	allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
	sessPerMouse{iM} = R.DateTime;
end

allUsedDTs = unique(allUsedDTs);
sdFull = nan(nMice, 1);
if isempty(allUsedDTs)
	sdVec = [];
	return;
end

q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
if isempty(ntsCell) || isempty(ntsCell{1})
	sdVec = [];
	return;
end

rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
rawTbl = iAttachLayer(rawTbl, DS.Cells(:, {'CellUID','ZLayer'}));
rawTbl = rawTbl(string(rawTbl.ZLayer) == string(layerName), :);
if isempty(rawTbl)
	sdVec = [];
	return;
end

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

for iM = 1:nMice
	if isempty(sessPerMouse{iM}), continue; end
	m = mice(iM);
	mRows = medTbl(string(medTbl.Mouse) == m & ismember(medTbl.DateTime, sessPerMouse{iM}), :);
	if isempty(mRows), continue; end
	[~, ~, cellID] = unique(mRows.CellUID);
	meanPerCell = accumarray(cellID, mRows.Med1s, [], @mean);
	vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
	if numel(vals) >= 3
		sdFull(iM) = std(vals);
	end
	end

sdVec = sdFull(isfinite(sdFull));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function p = iRanksumSafe(x, y)
p = NaN;
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if numel(x) >= 2 && numel(y) >= 2
	p = ranksum(x, y);
end
end

function Sess = iLightWaterSessions(DS)
blkCols = DS.Blocks.Properties.VariableNames;
hasMustWarn = ismember('MustWarn', blkCols);
if hasMustWarn
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
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

function T = iAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
cellMap.CellUID = uint64(cellMap.CellUID);
cellMap.ZLayer = string(cellMap.ZLayer);
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = cellMap.ZLayer(loc(has));
end

function dt = iNormDT(dt)
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function iStyleBars(Bars, colorA, colorB)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	Bars.CData = repmat([colorA; colorB], ceil(nB/2), 1);
	Bars.CData = Bars.CData(1:nB, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.FaceAlpha = 1/3;
else
	if numel(Bars) >= 2
		Bars(1).FaceColor = colorA;
		Bars(2).FaceColor = colorB;
		Bars(1).LineWidth = 1;
		Bars(2).LineWidth = 1;
		Bars(1).FaceAlpha = 1/3;
		Bars(2).FaceAlpha = 1/3;
	end
	end
end

function iKeepUpperErrorBarOnly(errorBars)
for eb = errorBars.Object(:)'
	if ~isgraphics(eb)
		continue;
	end
	if ~isprop(eb, 'YPositiveDelta') || ~isprop(eb, 'YNegativeDelta')
		continue;
	end
	eb.YNegativeDelta = zeros(size(eb.YPositiveDelta));
	eb.LineWidth = 1;
	eb.Color = [0 0 0];
	eb.HandleVisibility = 'off';
	if isprop(eb, 'Marker')
		eb.Marker = 'none';
	end
end
end

function [pLineAll, pTextAll] = iAppendPLineHandles(optional, pLineAll, pTextAll)
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
mc = optional.MultiCompare;
if ismember('PLine', mc.Properties.VariableNames)
	pLine = mc.PLine;
	pLine = pLine(isgraphics(pLine));
	if ~isempty(pLine)
		pLineAll(end+1:end+numel(pLine), 1) = pLine(:); %#ok<AGROW>
	end
end
if ismember('PText', mc.Properties.VariableNames)
	pText = mc.PText;
	pText = pText(isgraphics(pText));
	if ~isempty(pText)
		pTextAll(end+1:end+numel(pText), 1) = pText(:); %#ok<AGROW>
	end
end
end