% 英文图5D：TH 抑制组与 12 h 对照组的分层响应异质性比较。
%
% 数据与计算完全沿用英文图4D：分别对 AudioLightBaseline（12 h 对照组）和
% THInhibit，选取 Transfer 阶段至最后一个未学满块之间的纯光水会话，并排除
% 带警告标记的块。逐细胞逐会话取 cue 后 +1 s 的中位数，再对所选会话取均值；
% 仅保留响应绝对值不超过 1 的中等响应细胞，逐鼠逐层计算跨细胞标准差。
%
% 样式与英文图5F一致：单个面板，横轴为层，图例为组，不画逐鼠散点，
% 柱高表示跨鼠均值，误差条表示均值标准误，两组采用独立样本秩和检验。
% 语义配色：12 h = Color12h，TH = ColorTH，RGB 原始值除以 255。
%
% 输出（SVG）：
%   - English_Fig5D_THInhibitVsCtrl_HeterogeneityByLayer.svg
%
% 执行要求：
% - 保持脚本形式，不得改为函数。
% - 在 MATLAB 编辑器中打开并运行（F5）。

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
	error('Fig5D:No1s', '无法找到接近 cue 后 1 s 的采样点。');
end

[sdCtrl23, sdCtrl5] = iCohortData(CtrlDS, idx1s, "Transfer", "Final");
[sdTH23, sdTH5] = iCohortData(THDS, idx1s, "Transfer", "Final");
dataCell = {sdCtrl23, sdTH23; sdCtrl5, sdTH5};
layerLabels = ["MOp2/3", "MOp5"];
groupLabels = ["12 h", "TH"];
groupColors = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;

pLayers = nan(1, 2);
fprintf('=== 英文图5D：Transfer 光水阶段的分层响应异质性 ===\n');
for iLayer = 1:2
	vCtrl = dataCell{iLayer, 1};
	vTH = dataCell{iLayer, 2};
	vCtrl = vCtrl(isfinite(vCtrl));
	vTH = vTH(isfinite(vTH));
	if numel(vCtrl) < 2 || numel(vTH) < 2
		error('Fig5D:InsufficientData', '%s 数据不足：12 h n=%d，TH n=%d。', ...
			layerLabels(iLayer), numel(vCtrl), numel(vTH));
	end
	pLayers(iLayer) = ranksum(vCtrl, vTH);
	dataCell{iLayer, 1} = vCtrl;
	dataCell{iLayer, 2} = vTH;
	fprintf('%s：12 h %.3f ± %.3f（n=%d）| TH %.3f ± %.3f（n=%d）| 秩和检验 p=%.4g\n', ...
		layerLabels(iLayer), mean(vCtrl), iSem(vCtrl), numel(vCtrl), ...
		mean(vTH), iSem(vTH), numel(vTH), pLayers(iLayer));
end

%% ---------- 绘图：单面板，横轴为层，图例为组 ----------
f = figure('Color', 'w', 'Name', 'English Fig5D TH inhibition response heterogeneity by layer');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];

dataTable = cell2table(dataCell, 'VariableNames', cellstr(groupLabels), ...
	'RowNames', cellstr(layerLabels));
dataTable.Properties.DimensionNames = cellstr(["Layer", "Group"]);
compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dataTable.Properties.DimensionNames);
colorTable = array2table(groupColors, 'VariableNames', {'R', 'G', 'B'}, ...
	'RowNames', cellstr(groupLabels));

ax = axes(f);
[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, ...
	colorTable, ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iStyleBars(ax, barHandles, errorBars, groupColors);
iOverridePText(optional, pLayers);
legendHandle = optional.Legend;
legendHandle.String = cellstr(groupLabels);
legendHandle.Location = 'southoutside';
legendHandle.Orientation="horizontal";
legendHandle.Box = 'off';
xlabel(ax, 'Layer');
ylabel(ax, 'Response heterogeneity');
title(ax, '💡💧 Transfer', 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
iRetunePValueLines(optional);

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig5D_THInhibitVsCtrl_HeterogeneityByLayer.svg');
exportgraphics(f, svgPath, 'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig5D_TH_HeterogeneityByLayer', struct( ...
	'Control12h', table(sdCtrl23, sdCtrl5, 'VariableNames', {'MOp23', 'MOp5'}), ...
	'TH', table(sdTH23, sdTH5, 'VariableNames', {'MOp23', 'MOp5'})));
assignin('base', 'Fig5D_TH_HeterogeneityPValues', ...
	table(layerLabels(:), pLayers(:), 'VariableNames', {'Layer', 'RankSumP'}));

%% ========== 局部函数 ==========
function [sdL23Vec, sdL5Vec] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
% 会话筛选、响应聚合和中等响应细胞筛选完全沿用 Fig4D。
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
if isempty(Sess)
	sdL23Vec = [];
	sdL5Vec = [];
	return;
end
Sess = sortrows(Sess, {'Mouse', 'DateTime'});

mice = unique(string(Sess.Mouse));
nMice = numel(mice);
allUsedDTs = datetime.empty(0, 1);
sessPerMouse = cell(nMice, 1);
for iM = 1:nMice
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2
		continue;
	end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100 - 1, :);
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

dtMouseMap = Sess(:, {'DateTime', 'Mouse'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);

medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID', 'DateTime', 'Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');

rawCellLayer = rawTbl(:, {'CellUID', 'ZLayer'});
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
	mRows23 = mRows(mRows.ZLayer == "MOp2/3", :);
	if ~isempty(mRows23)
		[~, ~, cellID23] = unique(mRows23.CellUID);
		meanPerCell23 = accumarray(cellID23, mRows23.Med1s, [], @mean);
		vals23 = meanPerCell23(isfinite(meanPerCell23) & meanPerCell23 >= -1 & meanPerCell23 <= 1);
		if numel(vals23) >= 3
			sdL23Vec(iM) = std(vals23);
		end
	end
	mRows5 = mRows(mRows.ZLayer == "MOp5", :);
	if ~isempty(mRows5)
		[~, ~, cellID5] = unique(mRows5.CellUID);
		meanPerCell5 = accumarray(cellID5, mRows5.Med1s, [], @mean);
		vals5 = meanPerCell5(isfinite(meanPerCell5) & meanPerCell5 >= -1 & meanPerCell5 <= 1);
		if numel(vals5) >= 3
			sdL5Vec(iM) = std(vals5);
		end
	end
end

sdL23Vec = sdL23Vec(isfinite(sdL23Vec));
sdL5Vec = sdL5Vec(isfinite(sdL5Vec));
end

% ---------- 会话筛选，完全沿用 Fig4D ----------
function Sess = iLightWaterSessions(DS)
blkCols = DS.Blocks.Properties.VariableNames;
hasMustWarn = ismember('MustWarn', blkCols);
if hasMustWarn
	Blocks = DS.Blocks(:, {'BlockUID', 'DateTime', 'MustWarn'});
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks = DS.Blocks(:, {'BlockUID', 'DateTime'});
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
DT = DS.DateTimes(:, {'DateTime', 'Mouse', 'Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID', 'Stimulus', 'Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID', 'Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0, 1), NaT(0, 1), string.empty(0, 1), nan(0, 1), ...
		'VariableNames', {'Mouse', 'DateTime', 'Phase', 'Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID', 'LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse', 'DateTime', 'Phase', 'Performance'});
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
Blocks = DS.Blocks(:, {'BlockUID', 'DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID', 'Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW)
	return;
end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
DT = DS.DateTimes(:, {'DateTime', 'Mouse', 'Phase'});
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
cellMap = cellMap(:, {'CellUID', 'ZLayer'});
cellMap.CellUID = uint64(cellMap.CellUID);
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = string(cellMap.ZLayer(loc(has)));
end

% ---------- 柱状图与显著性样式，同英文图5F ----------
function compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dimensionNames)
layerPair = [layerLabels(:), layerLabels(:)];
groupPair = repmat(groupLabels(1:2), numel(layerLabels), 1);
GroupPair = table(layerPair, groupPair, 'VariableNames', cellstr(dimensionNames));
compareGroup = table(GroupPair);
end

function iOverridePText(optional, pLayers)
if ~(isfield(optional, 'MultiCompare') && istable(optional.MultiCompare))
	return;
end
mc = optional.MultiCompare;
if ~ismember('PText', mc.Properties.VariableNames)
	return;
end
for iP = 1:min(height(mc), numel(pLayers))
	pt = mc.PText(iP);
	if isgraphics(pt)
		pt.String = TransferLearning.Style.iFormatPText(pLayers(iP));
		pt.Tag = 'PText';
	end
end
end

function iStyleBars(ax, barHandles, errorBars, groupColors)
for iBar = 1:numel(barHandles)
	barHandles(iBar).LineStyle = 'none';
	barHandles(iBar).FaceColor = groupColors(iBar, :);
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
	bestColor = groupColors(1, :);
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

function iRetunePValueLines(optional)
if ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
if ~all(ismember({'PLine', 'PText'}, optional.MultiCompare.Properties.VariableNames))
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

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
