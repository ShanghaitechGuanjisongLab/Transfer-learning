% English Fig4D: thalamus-inhibited vs Control response heterogeneity by layer
%
% Response heterogeneity (RH) = across-cell SD of the trial-mean z-scored
% response at cue +1 s (cells restricted to |z| <= 1, moderate-response cells),
% computed per mouse within its light-water sessions from the Transfer phase up
% to the last performed block (Performance < 1.0), separately for L2/3 (MOp2/3)
% and L5 (MOp5).
%
% Data: Control = AudioLightBaseline, TH = THInhibit (imaging cohort only; the
% PO behavior-only mice have no imaging, so RH uses THInhibit imaging mice).
% Two stacked bar tiles (L2/3 top, L5 bottom), same layout as Chinese Fig61H.
%
% Claim: thalamus inhibition lowers population response heterogeneity.
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

[sdL23C, sdL5C, statsC] = iCohortData(CtrlDS, idx1s, "Transfer", "Final");
[sdL23T, sdL5T, statsT] = iCohortData(THDS, idx1s, "Transfer", "Final");

fprintf('=== English Fig4D response heterogeneity by layer ===\n');
fprintf('Ctrl L2/3: %d mice, %d total cells, %d moderate cells | mean=%.3f +/- %.3f\n', ...
	statsC.L23MouseN, statsC.MOp23CellN, statsC.ModerateMOp23CellN, mean(sdL23C), iSem(sdL23C));
fprintf('TH   L2/3: %d mice, %d total cells, %d moderate cells | mean=%.3f +/- %.3f\n', ...
	statsT.L23MouseN, statsT.MOp23CellN, statsT.ModerateMOp23CellN, mean(sdL23T), iSem(sdL23T));
fprintf('Ctrl L5:   %d mice, %d total cells, %d moderate cells | mean=%.3f +/- %.3f\n', ...
	statsC.L5MouseN, statsC.MOp5CellN, statsC.ModerateMOp5CellN, mean(sdL5C), iSem(sdL5C));
fprintf('TH   L5:   %d mice, %d total cells, %d moderate cells | mean=%.3f +/- %.3f\n', ...
	statsT.L5MouseN, statsT.MOp5CellN, statsT.ModerateMOp5CellN, mean(sdL5T), iSem(sdL5T));

[pL23, ~] = ranksum(sdL23C, sdL23T);
[pL5, ~] = ranksum(sdL5C, sdL5T);
fprintf('L2/3 rank-sum p = %.4g | L5 rank-sum p = %.4g\n', pL23, pL5);

colorCtrl = TransferLearning.TransferColor;
colorGap = TransferLearning.ColorB;
palette2 = [colorCtrl; colorGap];
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

%% ---------- figure: 2 stacked bar tiles (中文图61H 样式) ----------
% 规范：两行 bar tile 例外，一般不放大；高 4 cm、宽 3 cm（2 bar ≤3 cm）
f = figure('Color', 'w', 'Name', 'English Fig4D TH response heterogeneity by layer');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

% 两行 tile + 旋转 x 标签：tight 外边距会裁切旋转标签，用 loose 留出空间
Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'loose');

% ---- Tile 1: L2/3 ----
nexttile(Layout, 1);
[~, Opt1, Bars1, EB1] = UniExp.BarScatterCompare({sdL23C, sdL23T}, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax1 = gca;
delete(findobj(ax1, 'Type', 'Scatter'));
iStyleBars(Bars1, palette2);
iStyleErrorBars(EB1, palette2);
iOverridePText(Opt1, pL23);
ax1.XTick = [1 2];
ax1.XTickLabel = {};
ylabel(ax1, 'L2/3');
iStyleAxesCommon(ax1);

% ---- Tile 2: L5 ----
nexttile(Layout, 2);
[~, Opt2, Bars2, EB2] = UniExp.BarScatterCompare({sdL5C, sdL5T}, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
iStyleBars(Bars2, palette2);
iStyleErrorBars(EB2, palette2);
iOverridePText(Opt2, pL5);
ax2.XTick = [1 2];
% 2-bar tile：加 3 个前导空格触发 MATLAB 自动旋转标签，免手工旋转；标签需短于 tile 高
ax2.XTickLabel = {'   Control', '   TH'};
ylabel(ax2, 'L5');
iStyleAxesCommon(ax2);

% 规范：两 tile 都是响应异质性，标题写在 Layout 级别；3 cm 宽下用缩写（同 Fig3J 先例）
title(Layout, 'Respo. heter.');

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig4D_HeterogeneityStats', struct( ...
	'sdL23C', sdL23C, 'sdL23T', sdL23T, 'pL23', pL23, ...
	'sdL5C', sdL5C, 'sdL5T', sdL5T, 'pL5', pL5, ...
	'statsC', statsC, 'statsT', statsT));

%% ========== local functions ==========
function iStyleAxesCommon(ax)
legend(ax, 'off');
box(ax, 'off');
grid(ax, 'off');
ax.Color = 'none';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iStyleBars(Bars, palette2)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	Bars.CData = repmat(palette2, ceil(nB / 2), 1);
	Bars.CData = Bars.CData(1:nB, :);
	Bars.BarWidth = 0.5;
	Bars.FaceAlpha = 1;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	return;
end
for kB = 1:numel(Bars)
	Bars(kB).FaceColor = palette2(kB, :);
	Bars(kB).BarWidth = 0.5;
	Bars(kB).FaceAlpha = 1;
	Bars(kB).LineWidth = 1;
	Bars(kB).BaseLine.LineWidth = 1;
	Bars(kB).EdgeColor = 'none';
end
end

function iStyleErrorBars(errorBars, palette2)
if ~(istable(errorBars) && ~isempty(errorBars) && ismember('Object', errorBars.Properties.VariableNames))
	return;
end
for iE = 1:height(errorBars)
	eb = errorBars.Object(iE);
	if ~isgraphics(eb)
		continue;
	end
	eb.LineWidth = 1;
	xData = double(eb.XData(:));
	xData = xData(isfinite(xData));
	if isempty(xData)
		continue;
	end
	[~, colorIndex] = min(abs((1:size(palette2, 1)).' - xData(1)));
	eb.Color = palette2(colorIndex, :);
end
end

function iOverridePText(Optional, p)
% BarScatterCompare 内部 anova/multcompare 之外统一报告 rank-sum p
if ~(isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare))
	return;
end
mc = Optional.MultiCompare;
if ~ismember('PText', mc.Properties.VariableNames)
	return;
end
for ip = 1:height(mc)
	pt = mc.PText(ip);
	if isgraphics(pt)
		pt.String = TransferLearning.Style.iFormatPText(p);
		pt.Tag = 'PText';
	end
end
if ismember('PLine', mc.Properties.VariableNames)
	for ip = 1:height(mc)
		pl = mc.PLine(ip);
		if isgraphics(pl)
			pl.Tag = 'PLine';
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
