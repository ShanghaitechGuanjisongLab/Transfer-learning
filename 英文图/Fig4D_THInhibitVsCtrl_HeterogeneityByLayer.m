% English Fig4D: response heterogeneity by layer across 12 h / 7 d / TH inhibition
%
% Response heterogeneity (RH) = across-cell SD of the trial-mean z-scored
% response at cue +1 s (cells restricted to |z| <= 1, moderate-response cells),
% computed per mouse within its light-water sessions from the Transfer phase up
% to the last performed block (Performance < 1.0), separately for L2/3 (MOp2/3)
% and L5 (MOp5).
%
% Data (three bars): 12 h = AudioLightBaseline (Control), 7 d = Vacation7,
% TH = THInhibit (imaging cohort only; PO behavior-only mice have no imaging).
% Two stacked bar tiles (L2/3 top, L5 bottom), same layout as Chinese Fig61H.
% Two comparisons: 12 h vs 7 d, and 12 h vs TH (both against the 12 h control).
%
% Claim: thalamus inhibition lowers population response heterogeneity;
% 7-d interval serves as the long-interval comparison against 12 h.
%
% Outputs (SVG):
%   - English_Fig4D_THInhibitVsCtrl_HeterogeneityByLayer.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "English_Fig4D_THInhibitVsCtrl_HeterogeneityByLayer.svg";

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();
THDS = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig4D:No1s', 'Cannot find sample close to 1s.');
end

[sdL23C, sdL5C, statsC] = iCohortData(CtrlDS, idx1s, "Transfer", "Final");   % 12 h
[sdL23V, sdL5V, statsV] = iCohortData(V7DS, idx1s, "Transfer", "Final");     % 7 d
[sdL23T, sdL5T, statsT] = iCohortData(THDS, idx1s, "Transfer", "Final");     % TH

fprintf('=== English Fig4D response heterogeneity by layer (12h / 7d / TH) ===\n');
fprintf('12h L2/3: %d mice | mean=%.3f +/- %.3f\n', statsC.L23MouseN, mean(sdL23C), iSem(sdL23C));
fprintf('7d  L2/3: %d mice | mean=%.3f +/- %.3f\n', statsV.L23MouseN, mean(sdL23V), iSem(sdL23V));
fprintf('TH  L2/3: %d mice | mean=%.3f +/- %.3f\n', statsT.L23MouseN, mean(sdL23T), iSem(sdL23T));
fprintf('12h L5:   %d mice | mean=%.3f +/- %.3f\n', statsC.L5MouseN, mean(sdL5C), iSem(sdL5C));
fprintf('7d  L5:   %d mice | mean=%.3f +/- %.3f\n', statsV.L5MouseN, mean(sdL5V), iSem(sdL5V));
fprintf('TH  L5:   %d mice | mean=%.3f +/- %.3f\n', statsT.L5MouseN, mean(sdL5T), iSem(sdL5T));

% 两组比较（都对 12 h）：12h-7d、12h-TH
[pL23_CV, ~] = ranksum(sdL23C, sdL23V);
[pL23_CT, ~] = ranksum(sdL23C, sdL23T);
[pL5_CV, ~] = ranksum(sdL5C, sdL5V);
[pL5_CT, ~] = ranksum(sdL5C, sdL5T);
fprintf('L2/3 12h-7d p=%.4g | 12h-TH p=%.4g\n', pL23_CV, pL23_CT);
fprintf('L5   12h-7d p=%.4g | 12h-TH p=%.4g\n', pL5_CV, pL5_CT);

% 交换维度：X 轴=层（L2/3、L5），图例=组。12h 居中，7d/TH 分列两边。每层内比 12h-7d 与 12h-TH。
% 二维表：行=层，列=组（顺序 7d/12h/TH）。配色：7d=ColorB(绿), 12h=TransferColor(橙), TH=NaiveColor(紫)
layerLabels = ["L2/3", "L5"];
groupLabels = ["7 d", "12 h", "TH"];
groupColors = [TransferLearning.ColorB; TransferLearning.TransferColor; TransferLearning.NaiveColor];

%% ---------- figure：单 tile，二维表语法（行=层，列=组） ----------
f = figure('Color', 'w', 'Name', 'English Fig4D response heterogeneity by layer 12h 7d TH');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

dataCell = {sdL23V, sdL23C, sdL23T; sdL5V, sdL5C, sdL5T};   % 2 层 × 3 组（7d/12h/TH），每元素为该层该组逐鼠向量
dataTable = cell2table(dataCell, 'VariableNames', cellstr(groupLabels), 'RowNames', cellstr(layerLabels));
dataTable.Properties.DimensionNames = cellstr(["Layer", "Group"]);
% 比较：每层(Layer，行)内跨组(Group，列) 12h-7d、12h-TH（Fig3E 式固定行比列）
compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dataTable.Properties.DimensionNames);
colorTable = array2table(groupColors, 'VariableNames', {'R','G','B'}, 'RowNames', cellstr(groupLabels));
ax = axes(f);
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, ...
	colorTable, ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iStyleBars(ax, barHandles, errorBars, groupColors);
legendHandle = optional.Legend;
legendHandle.String = cellstr(groupLabels);
legendHandle.Title.String = 'Group';
legendHandle.Box = 'off';
legendHandle.Location = 'eastoutside';
xlabel(ax, 'Layer');
ylabel(ax, 'Respo. heter.');
box(ax, 'off');
grid(ax, 'off');
iRetunePValueLines(optional);
% PText 顺序：L2/3 行内 12h-7d、12h-TH，L5 行内 12h-7d、12h-TH
iOverridePTextMulti(optional, [pL23_CV, pL23_CT, pL5_CV, pL5_CT]);

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);

%% ========== local functions ==========
function compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dimensionNames)
% Fig3E 式：固定每个层(行)，比两个组(列)。每层配两对：12h-7d、12h-TH。
layerLabels = string(layerLabels(:));
groupLabels = string(groupLabels(:)).';
% 组对（12h 居中为第 2 列）：7d(1)-12h(2)、12h(2)-TH(3)
pairIdx = [1 2; 2 3];
nPair = size(pairIdx, 1);
nLayer = numel(layerLabels);
layerPair = strings(nLayer * nPair, 2);
groupPair = strings(nLayer * nPair, 2);
row = 0;
for iL = 1:nLayer
	for iP = 1:nPair
		row = row + 1;
		layerPair(row, :) = [layerLabels(iL), layerLabels(iL)];
		groupPair(row, :) = groupLabels(pairIdx(iP, :)).';
	end
end
GroupPair = table(layerPair, groupPair, 'VariableNames', cellstr(dimensionNames));
compareGroup = table(GroupPair);
end

function iRetunePValueLines(optional)
if ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
if ~all(ismember({'PLine','PText'}, optional.MultiCompare.Properties.VariableNames))
	return;
end
MATLAB.Graphics.PLineRetune(optional.MultiCompare.PLine, optional.MultiCompare.PText);
for pLine = optional.MultiCompare.PLine(:)'
	if isgraphics(pLine)
		pLine.LineWidth = 1;
		pLine.Tag = 'PLine';
		setappdata(pLine, 'TransferLearningPreserveLineWidth', true);
	end
end
for pText = optional.MultiCompare.PText(:)'
	if isgraphics(pText)
		pText.Tag = 'PText';
	end
end
end

function iStyleBars(ax, barHandles, errorBars, layerColors)
for iBar = 1:numel(barHandles)
	barHandles(iBar).LineStyle = 'none';
	barHandles(iBar).FaceColor = layerColors(iBar, :);
	if isprop(barHandles(iBar), 'BaseLine') && isgraphics(barHandles(iBar).BaseLine)
		barHandles(iBar).BaseLine.Visible = 'off';
	end
end
for iRow = 1:height(errorBars)
	eBar = errorBars.Object(iRow);
	if ~isgraphics(eBar)
		continue;
	end
	x = double(eBar.XData(1));
	bestDist = inf;
	bestColor = layerColors(1, :);
	for iBar2 = 1:numel(barHandles)
		xp = double(barHandles(iBar2).XEndPoints(:));
		d = min(abs(xp - x));
		if d < bestDist
			bestDist = d;
			bestColor = barHandles(iBar2).FaceColor;
		end
	end
	eBar.Color = bestColor;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iOverridePTextMulti(Optional, pVec)
% 多组比较：PText 按 compareGroup 行序一一对应 rank-sum p（12h-7d、12h-TH）
if ~(isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare))
	return;
end
mc = Optional.MultiCompare;
if ~ismember('PText', mc.Properties.VariableNames)
	return;
end
for ip = 1:height(mc)
	pt = mc.PText(ip);
	if isgraphics(pt) && ip <= numel(pVec)
		pt.String = TransferLearning.Style.iFormatPText(pVec(ip));
		pt.Tag = 'PText';
	end
end
if ismember('PLine', mc.Properties.VariableNames)
	for ip = 1:height(mc)
		pl = mc.PLine(ip);
		if isgraphics(pl)
			pl.Tag = 'PLine';
			setappdata(pl, 'TransferLearningPreserveLineWidth', true);
		end
	end
end
end

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function [sdL23Vec, sdL5Vec, stats] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
stats = iEmptyCohortStats();
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
if isempty(Sess)
	sdL23Vec = [];
	sdL5Vec = [];
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
nMice = numel(mice);
allUsedDTs = datetime.empty(0,1);
sessPerMouse = cell(nMice, 1);
for iM = 1:nMice
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2
		continue;
	end
	% 丢弃已学满（Performance>=1）之后的会话；若首个会话即学满则整鼠跳过
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2
		continue;
	end
	allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
	sessPerMouse{iM} = R.DateTime;
end

allUsedDTs = unique(allUsedDTs);
sdL23Vec = nan(nMice, 1);
sdL5Vec = nan(nMice, 1);
cellCountL23Vec = nan(nMice, 1);
cellCountL5Vec = nan(nMice, 1);
moderateCellCountL23Vec = nan(nMice, 1);
moderateCellCountL5Vec = nan(nMice, 1);
if isempty(allUsedDTs)
	sdL23Vec = [];
	sdL5Vec = [];
	return;
end

q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	sdL23Vec = [];
	sdL5Vec = [];
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
	sdL23Vec = [];
	sdL5Vec = [];
	return;
end
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

rawCellLayer = rawTbl(:, {'CellUID','ZLayer'});
[~, loc] = ismember(medTbl.CellUID, rawCellLayer.CellUID);
medTbl.ZLayer = strings(height(medTbl), 1);
has = loc > 0;
medTbl.ZLayer(has) = string(rawCellLayer.ZLayer(loc(has)));

for iM = 1:nMice
	if isempty(sessPerMouse{iM})
		continue;
	end
	m = mice(iM);
	mRows = medTbl(string(medTbl.Mouse) == m & ismember(medTbl.DateTime, sessPerMouse{iM}), :);
	if isempty(mRows)
		continue;
	end
	% --- L2/3 ---
	mRows23 = mRows(mRows.ZLayer == "MOp2/3", :);
	if ~isempty(mRows23)
		[~, ~, cellID23] = unique(mRows23.CellUID);
		meanPerCell23 = accumarray(cellID23, mRows23.Med1s, [], @mean);
		vals23 = meanPerCell23(isfinite(meanPerCell23) & meanPerCell23 >= -1 & meanPerCell23 <= 1);
		cellCountL23Vec(iM) = numel(meanPerCell23);
		moderateCellCountL23Vec(iM) = numel(vals23);
		if numel(vals23) >= 3
			sdL23Vec(iM) = std(vals23);
		end
	end
	% --- L5 ---
	mRows5 = mRows(mRows.ZLayer == "MOp5", :);
	if ~isempty(mRows5)
		[~, ~, cellID5] = unique(mRows5.CellUID);
		meanPerCell5 = accumarray(cellID5, mRows5.Med1s, [], @mean);
		vals5 = meanPerCell5(isfinite(meanPerCell5) & meanPerCell5 >= -1 & meanPerCell5 <= 1);
		cellCountL5Vec(iM) = numel(meanPerCell5);
		moderateCellCountL5Vec(iM) = numel(vals5);
		if numel(vals5) >= 3
			sdL5Vec(iM) = std(vals5);
		end
	end
end

validL23 = isfinite(sdL23Vec);
validL5 = isfinite(sdL5Vec);
stats.L23MouseN = nnz(validL23);
stats.MOp23CellN = sum(cellCountL23Vec(validL23), 'omitnan');
stats.ModerateMOp23CellN = sum(moderateCellCountL23Vec(validL23), 'omitnan');
sdL23Vec = sdL23Vec(validL23);
stats.L5MouseN = nnz(validL5);
stats.MOp5CellN = sum(cellCountL5Vec(validL5), 'omitnan');
stats.ModerateMOp5CellN = sum(moderateCellCountL5Vec(validL5), 'omitnan');
sdL5Vec = sdL5Vec(validL5);
end

function stats = iEmptyCohortStats()
stats = struct;
stats.L23MouseN = 0;
stats.L5MouseN = 0;
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
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW)
	return;
end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks, 'Keys','BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
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
	if isempty(phDates) || isempty(endDates)
		continue;
	end
	startDT = min(phDates);
	endDT = max(endDates);
	if ismissing(startDT) || ismissing(endDT)
		continue;
	end
	rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function dt = iNormDT(dt)
try
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end

function T = iAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
cellMap.CellUID = uint64(cellMap.CellUID);
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = string(cellMap.ZLayer(loc(has)));
end
