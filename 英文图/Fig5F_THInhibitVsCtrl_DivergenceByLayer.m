% 英文图5F：TH 抑制组与 12 h 对照组的分层散度比较。
%
% 数据与会话筛选沿用英文图4D：分别对 AudioLightBaseline（12 h 对照组）和
% THInhibit，选取 Transfer 阶段至最后一个未学满块之间的纯光水会话，并排除
% 带警告标记的块。本图仅比较 Transfer 阶段的光水散度，使用单个面板。
%
% 散度计算沿用英文图2O：逐鼠逐会话对全部 LightWater 回合进行 z 分数化
% （基线为 1:24），取 cue 后 +1 s 时刻的细胞×回合矩阵 X，各层独立计算：
%   div = sqrt(sum(var(X, [], 2)) / sum(mean(X, 2).^2))。
% 先在每鼠内对会话取均值，柱高表示跨鼠均值，误差条表示均值标准误。
% Fig4D 的中等响应细胞筛选仅用于响应异质性，不用于本图的散度计算。
%
% 样式沿用英文图2O 的分层视图：横轴为层，图例为组，不画逐鼠散点，
% 两组采用独立样本检验。语义配色：12 h = Color12h，TH = ColorTH，
% RGB 原始取值范围为 0～255，绘图前除以 255。
%
% 输出（SVG）：
%   - English_Fig5F_THInhibitVsCtrl_DivergenceByLayer.svg
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
	error('Fig5F:No1s', 'Cannot find sample close to 1 s.');
end

[divCtrl, sessCtrl] = iCohortDivergence(CtrlDS, idx1s, "Transfer", "Final");
[divTH, sessTH] = iCohortDivergence(THDS, idx1s, "Transfer", "Final");

layerLabels = ["MOp2/3", "MOp5"];
groupLabels = ["12 h", "TH"];
groupColors = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;
layerFields = ["DivL23", "DivL5"];

pLayers = nan(1, 2);
dataCell = cell(2, 2);
for iLayer = 1:2
	vCtrl = divCtrl.(layerFields(iLayer));
	vTH = divTH.(layerFields(iLayer));
	vCtrl = vCtrl(isfinite(vCtrl));
	vTH = vTH(isfinite(vTH));
	if numel(vCtrl) < 2 || numel(vTH) < 2
		error('Fig5F:InsufficientData', '%s has insufficient mice: 12 h n=%d, TH n=%d.', ...
			layerLabels(iLayer), numel(vCtrl), numel(vTH));
	end
	pLayers(iLayer) = ranksum(vCtrl, vTH);
	dataCell{iLayer, 1} = vCtrl;
	dataCell{iLayer, 2} = vTH;
end

fprintf('=== English Fig5F divergence by layer, Transfer light water ===\n');
for iLayer = 1:2
	vCtrl = dataCell{iLayer, 1};
	vTH = dataCell{iLayer, 2};
	fprintf('%s: 12 h %.3f +/- %.3f (n=%d mice, %d sessions) | TH %.3f +/- %.3f (n=%d mice, %d sessions) | ranksum p=%.4g\n', ...
		layerLabels(iLayer), mean(vCtrl), iSem(vCtrl), numel(vCtrl), ...
		nnz(isfinite(sessCtrl.(layerFields(iLayer)))), mean(vTH), iSem(vTH), ...
		numel(vTH), nnz(isfinite(sessTH.(layerFields(iLayer)))), pLayers(iLayer));
end

%% ---------- 绘图：单面板，横轴为层，图例为组 ----------
f = figure('Color', 'w', 'Name', 'English Fig5F TH inhibition divergence by layer');
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
legendHandle.Orientation = "horizontal";
legendHandle.Box = 'off';

xlabel(ax, 'Layer');
ylabel(ax, 'Divergence');
title(ax, '💡💧 Transfer', 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
iRetunePValueLines(optional);

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig5F_THInhibitVsCtrl_DivergenceByLayer.svg');
exportgraphics(f, svgPath, 'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig5F_TH_DivergenceByLayer', ...
	struct('Control12h', divCtrl, 'TH', divTH));
assignin('base', 'Fig5F_TH_DivergenceSessions', ...
	struct('Control12h', sessCtrl, 'TH', sessTH));
assignin('base', 'Fig5F_TH_DivergencePValues', ...
	table(layerLabels(:), pLayers(:), 'VariableNames', {'Layer', 'RankSumP'}));

%% ========== 局部函数 ==========
function [mouseDiv, sessionDiv] = iCohortDivergence(DS, idx1s, phaseStart, phaseEnd)
% 会话筛选沿用 Fig4D，逐会话散度按 Fig2O 计算。
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
sessionDiv = iEmptySessionTable();
mouseDiv = table(strings(0, 1), nan(0, 1), nan(0, 1), ...
	'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
if isempty(Sess)
	return;
end
Sess = sortrows(Sess, {'Mouse', 'DateTime'});

mice = unique(string(Sess.Mouse));
sessPerMouse = cell(numel(mice), 1);
allUsedDTs = datetime.empty(0, 1);
for iM = 1:numel(mice)
	m = mice(iM);
	R = Sess(string(Sess.Mouse) == m, :);
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
	sessPerMouse{iM} = R;
	allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
end
allUsedDTs = unique(allUsedDTs);
if isempty(allUsedDTs)
	return;
end

q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
	return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
rawTbl = iAttachLayer(rawTbl, DS.Cells);

cellLayerMap = unique(rawTbl(:, {'CellUID', 'ZLayer'}), 'rows');
for iM = 1:numel(mice)
	if isempty(sessPerMouse{iM})
		continue;
	end
	R = sessPerMouse{iM};
	for iS = 1:height(R)
		rowsSess = rawTbl(rawTbl.DateTime == R.DateTime(iS), :);
		if isempty(rowsSess)
			continue;
		end
		trialUIDs = unique(uint64(rowsSess.TrialUID), 'stable');
		if numel(trialUIDs) < 2
			continue;
		end
		[CTT, cellUIDs] = iBuildCtt(rowsSess, trialUIDs);
		if isempty(CTT) || size(CTT, 1) < 3
			continue;
		end
		X = CTT(:, :, idx1s);
		[tf, loc] = ismember(cellUIDs, cellLayerMap.CellUID);
		layers = strings(numel(cellUIDs), 1);
		layers(tf) = string(cellLayerMap.ZLayer(loc(tf)));
		mask23 = layers == "MOp2/3";
		mask5 = layers == "MOp5";
		d23 = NaN;
		d5 = NaN;
		if nnz(mask23) >= 3
			d23 = iDivFromX(X(mask23, :));
		end
		if nnz(mask5) >= 3
			d5 = iDivFromX(X(mask5, :));
		end
		sessionDiv = [sessionDiv; table(mice(iM), R.DateTime(iS), d23, d5, ...
			nnz(mask23), nnz(mask5), 'VariableNames', sessionDiv.Properties.VariableNames)]; %#ok<AGROW>
	end
end

valid = isfinite(sessionDiv.DivL23) | isfinite(sessionDiv.DivL5);
sessionDiv = sessionDiv(valid, :);
if isempty(sessionDiv)
	return;
end
[G, mouseU] = findgroups(sessionDiv.Mouse);
d23 = splitapply(@(v) mean(v, 'omitnan'), sessionDiv.DivL23, G);
d5 = splitapply(@(v) mean(v, 'omitnan'), sessionDiv.DivL5, G);
mouseDiv = table(mouseU, d23, d5, 'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
end

function T = iEmptySessionTable()
T = table(strings(0, 1), NaT(0, 1), nan(0, 1), nan(0, 1), zeros(0, 1), zeros(0, 1), ...
	'VariableNames', {'Mouse', 'DateTime', 'DivL23', 'DivL5', 'NCellL23', 'NCellL5'});
end

function [CTT, cellUIDs] = iBuildCtt(nts, trialUIDs)
allCells = unique(uint64(nts.CellUID));
traces = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rowsC = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rowsC));
	sig = double(nts.TrialSignal(rowsC, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	so = sig(loc, :);
	if any(~isfinite(so), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepUID(nKeep) = cid;
end
if nKeep < 3
	CTT = [];
	cellUIDs = uint64([]);
	return;
end
traces = traces(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = numel(trialUIDs);
nTime = size(traces{1}, 2);
CTT = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, nTrial, nTime);
end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

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

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

