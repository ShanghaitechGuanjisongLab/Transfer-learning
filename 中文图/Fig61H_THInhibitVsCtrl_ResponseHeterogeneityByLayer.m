% 中文图61H：TH抑制 vs 对照组 — MOp2/3 & MOp5 响应异质性
%
% Two bar tiles comparing Ctrl and TH groups:
%   Top:    Response heterogeneity per mouse using MOp2/3 cells only
%   Bottom: Response heterogeneity per mouse using MOp5 cells only
%
% Ctrl: AudioLightBaseline (Transfer->Final)
% TH:   THInhibit          (Transfer->Final)

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('Fig61H:No1s', 'Cannot find sample close to 1s.'); end

[~, sdL23C, sdL5C, statsC] = iCohortData(CtrlDS, idx1s, "Transfer", "Final");
[~, sdL23T, sdL5T, statsT] = iCohortData(THDS, idx1s, "Transfer", "Final");

fprintf('\n=== 中文图61H 响应异质性 by layer ===\n');
fprintf('Ctrl MOp2/3 response heterogeneity: %d mice, %d total cells, %d moderate-response cells in [-1, 1]\n', statsC.HeterogeneityL23MouseN, statsC.MOp23CellN, statsC.ModerateMOp23CellN);
fprintf('TH MOp2/3 response heterogeneity:   %d mice, %d total cells, %d moderate-response cells in [-1, 1]\n', statsT.HeterogeneityL23MouseN, statsT.MOp23CellN, statsT.ModerateMOp23CellN);
fprintf('Ctrl MOp5 response heterogeneity: %d mice, %d total cells, %d moderate-response cells in [-1, 1]\n', statsC.HeterogeneityL5MouseN, statsC.MOp5CellN, statsC.ModerateMOp5CellN);
fprintf('TH MOp5 response heterogeneity:   %d mice, %d total cells, %d moderate-response cells in [-1, 1]\n', statsT.HeterogeneityL5MouseN, statsT.MOp5CellN, statsT.ModerateMOp5CellN);

svgName = "中文图Fig61H_THInhibitVsCtrl_ResponseHeterogeneityByLayer.svg";
%% 
f = figure('Color', 'w', 'Name', 'Fig61H TH Response heterogeneity by layer');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
palette2 = [TransferLearning.ContinualColor; TransferLearning.ColorB];
colorA = palette2(1,:);
colorB = palette2(2,:);
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

nexttile(Layout, 1);
[~, Opt1, Bars1, EB1] = UniExp.BarScatterCompare({sdL23C, sdL23T}, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax1 = gca;
delete(findobj(ax1, 'Type', 'Scatter'));
for iE = 1:height(EB1)
	eb = EB1.Object(iE);
	eb.LineWidth = 1;
	xData = double(eb.XData(:));
	[~, colorIndex] = min(abs((1:size(palette2, 1)).' - xData(1)));
	eb.Color = palette2(colorIndex, :);
end
ax1.FontSize = 6;
ax1.LineWidth = 1;
if isprop(ax1.XAxis, 'LineWidth')
	ax1.XAxis.LineWidth = 1;
	ax1.YAxis.LineWidth = 1;
end
ax1.XTickLabel = {};
ylabel(ax1, 'L2/3', 'FontSize', 6);
legend(ax1, 'off');
box(ax1, 'off');
if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	nB = numel(Bars1.YData);
	Bars1.CData = repmat([colorA; colorB], ceil(nB/2), 1);
	Bars1.CData = Bars1.CData(1:nB, :);
	Bars1.BarWidth = 0.5;
	Bars1.LineWidth = 1;
	Bars1.BaseLine.LineWidth = 1;
	Bars1.EdgeColor = 'none';
	Bars1.FaceAlpha = 1;
end
TransferLearning.Style.SetBarPValues(Opt1);
[Opt1, ~, ~, ~] = iRetagPValueLinesFromOpt(Opt1, ax1);
for ln = findobj(ax1, 'Type', 'Line')'
	ln.LineWidth = 1;
end

nexttile(Layout, 2);
[~, Opt2, Bars2, EB2] = UniExp.BarScatterCompare({sdL5C, sdL5T}, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
for iE = 1:height(EB2)
	eb = EB2.Object(iE);
	eb.LineWidth = 1;
	xData = double(eb.XData(:));
	[~, colorIndex] = min(abs((1:size(palette2, 1)).' - xData(1)));
	eb.Color = palette2(colorIndex, :);
end
ax2.FontSize = 6;
ax2.LineWidth = 1;
if isprop(ax2.XAxis, 'LineWidth')
	ax2.XAxis.LineWidth = 1;
	ax2.YAxis.LineWidth = 1;
end
ax2.XTick = [1 2];
ax2.XTickLabel = {'Control', 'TH'};
ylabel(ax2, 'L5', 'FontSize', 6);
legend(ax2, 'off');
box(ax2, 'off');
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB = numel(Bars2.YData);
	Bars2.CData = repmat([colorA; colorB], ceil(nB/2), 1);
	Bars2.CData = Bars2.CData(1:nB, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 1;
	Bars2.BaseLine.LineWidth = 1;
	Bars2.EdgeColor = 'none';
	Bars2.FaceAlpha = 1;
end
TransferLearning.Style.SetBarPValues(Opt2);
[Opt2, ~, ~, ~] = iRetagPValueLinesFromOpt(Opt2, ax2);
for ln = findobj(ax2, 'Type', 'Line')'
	ln.LineWidth = 1;
end

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
title(Layout,'Response heterogeneity');
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== Figure caption P-values ===\n');
fprintf('MOp2/3 response heterogeneity: %s\n', TransferLearning.Style.iFormatPText(Opt1.MultiCompare.PValue(1)));
fprintf('MOp5 response heterogeneity: %s\n', TransferLearning.Style.iFormatPText(Opt2.MultiCompare.PValue(1)));

function [dhVec, sdL23Vec, sdL5Vec, stats] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
stats = iEmptyCohortStats();
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
if isempty(Sess)
	dhVec = []; sdL23Vec = []; sdL5Vec = [];
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
nMice = numel(mice);
dhVec = [];
allUsedDTs = datetime.empty(0,1);
sessPerMouse = cell(nMice, 1);
hasDeltaHit = false(nMice, 1);
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
	if height(R) < 2, continue; end
	perf = double(R.Performance);
	dhVec = [dhVec; diff(perf)]; %#ok<AGROW>
	hasDeltaHit(iM) = true;
	allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
	sessPerMouse{iM} = R.DateTime;
	end

stats.DeltaHitMouseN = nnz(hasDeltaHit);
stats.DeltaHitPairN = numel(dhVec);

allUsedDTs = unique(allUsedDTs);
sdL23Vec = nan(nMice, 1);
sdL5Vec = nan(nMice, 1);
cellCountL23Vec = nan(nMice, 1);
cellCountL5Vec = nan(nMice, 1);
moderateCellCountL23Vec = nan(nMice, 1);
moderateCellCountL5Vec = nan(nMice, 1);
if isempty(allUsedDTs), sdL23Vec = []; sdL5Vec = []; return; end

q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	sdL23Vec = []; sdL5Vec = []; return;
end
if isempty(ntsCell) || isempty(ntsCell{1}), sdL23Vec = []; sdL5Vec = []; return; end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
rawTbl = iAttachLayer(rawTbl, DS.Cells);
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

% Attach layer to medTbl for per-cell lookup
rawCellLayer = rawTbl(:, {'CellUID','ZLayer'});
[~, loc] = ismember(medTbl.CellUID, rawCellLayer.CellUID);
medTbl.ZLayer = strings(height(medTbl), 1);
has = loc > 0;
medTbl.ZLayer(has) = string(rawCellLayer.ZLayer(loc(has)));

for iM = 1:nMice
	if isempty(sessPerMouse{iM}), continue; end
	m = mice(iM);
	mRows = medTbl(string(medTbl.Mouse) == m & ismember(medTbl.DateTime, sessPerMouse{iM}), :);
	if isempty(mRows), continue; end

	% --- L2/3 heterogeneity ---
	mRows23 = mRows(mRows.ZLayer == "MOp2/3", :);
	if ~isempty(mRows23)
		[~, ~, cellID23] = unique(mRows23.CellUID);
		meanPerCell23 = accumarray(cellID23, mRows23.Med1s, [], @mean);
		vals23 = meanPerCell23(isfinite(meanPerCell23) & meanPerCell23 >= -1 & meanPerCell23 <= 1);
		cellCountL23Vec(iM) = numel(meanPerCell23);
		moderateCellCountL23Vec(iM) = numel(vals23);
		if numel(vals23) >= 3, sdL23Vec(iM) = std(vals23); end
	end

	% --- L5 heterogeneity ---
	mRows5 = mRows(mRows.ZLayer == "MOp5", :);
	if ~isempty(mRows5)
		[~, ~, cellID5] = unique(mRows5.CellUID);
		meanPerCell5 = accumarray(cellID5, mRows5.Med1s, [], @mean);
		vals5 = meanPerCell5(isfinite(meanPerCell5) & meanPerCell5 >= -1 & meanPerCell5 <= 1);
		cellCountL5Vec(iM) = numel(meanPerCell5);
		moderateCellCountL5Vec(iM) = numel(vals5);
		if numel(vals5) >= 3, sdL5Vec(iM) = std(vals5); end
	end
end

validL23 = isfinite(sdL23Vec);
validL5 = isfinite(sdL5Vec);
stats.HeterogeneityL23MouseN = nnz(validL23);
stats.MOp23CellN = sum(cellCountL23Vec(validL23), 'omitnan');
stats.ModerateMOp23CellN = sum(moderateCellCountL23Vec(validL23), 'omitnan');
sdL23Vec = sdL23Vec(validL23);
stats.HeterogeneityL5MouseN = nnz(validL5);
stats.MOp5CellN = sum(cellCountL5Vec(validL5), 'omitnan');
stats.ModerateMOp5CellN = sum(moderateCellCountL5Vec(validL5), 'omitnan');
sdL5Vec = sdL5Vec(validL5);
end

function stats = iEmptyCohortStats()
stats = struct;
stats.DeltaHitMouseN = 0;
stats.DeltaHitPairN = 0;
stats.HeterogeneityL23MouseN = 0;
stats.HeterogeneityL5MouseN = 0;
stats.MOp23CellN = 0;
stats.MOp5CellN = 0;
stats.ModerateMOp23CellN = 0;
stats.ModerateMOp5CellN = 0;
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
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

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end

function T = iAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
cellMap.CellUID = uint64(cellMap.CellUID);
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = string(cellMap.ZLayer(loc(has)));
end

function [Optional, Bars, ErrorBars, Ax] = iRetagPValueLinesFromOpt(Optional, Ax)
if ~isfield(Optional, 'MultiCompare') || ~istable(Optional.MultiCompare)
	Bars = []; ErrorBars = table; return;
end
mc = Optional.MultiCompare;
allPLines = findall(Ax, '-regexp', 'Tag', '^PLine_');
allPTexts = findall(Ax, '-regexp', 'Tag', '^PText_');
for iP = 1:numel(allPLines)
	num = str2double(extractAfter(allPLines(iP).Tag, 'PLine_'));
	if ~isfinite(num) || num > height(mc), continue; end
	mc.PLine(num) = allPLines(iP);
	mc.PLine(num).LineWidth = 1;
	mc.PLine(num).Tag = sprintf('PLine_%d', num);
end
for iP = 1:numel(allPTexts)
	num = str2double(extractAfter(allPTexts(iP).Tag, 'PText_'));
	if ~isfinite(num) || num > height(mc), continue; end
	mc.PText(num) = allPTexts(iP);
	mc.PText(num).FontSize = 6;
	mc.PText(num).Tag = sprintf('PText_%d', num);
end
Optional.MultiCompare = mc;
Bars = []; ErrorBars = table;
end
