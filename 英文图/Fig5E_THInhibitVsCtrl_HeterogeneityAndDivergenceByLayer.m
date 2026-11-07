% 英文图5E：TH 抑制组与 12 h 对照组的分层响应异质性与散度比较。
%
% 数据与会话筛选沿用英文图4D：分别对 AudioLightBaseline（12 h 对照组）和
% THInhibit，选取 Transfer 阶段至最后一个未学满块之间的纯光水会话，并排除
% 带警告标记的块。上面板为响应异质性：逐细胞逐会话取 cue 后 +1 s 的中位数，
% 再对所选会话取均值；仅保留响应绝对值不超过 1 的中等响应细胞，逐鼠逐层
% 计算跨细胞标准差。
%
% 下面板为散度：逐鼠逐会话对全部 LightWater 回合进行 z 分数化（基线 1:24），
% 取 cue 后 +1 s 时刻的细胞×回合矩阵 X，各层独立计算
% sqrt(sum(var(X, [], 2)) / sum(mean(X, 2).^2))，再在每鼠内对会话取均值。
% 中等响应细胞筛选仅用于响应异质性，不用于散度。
%
% 上下两个面板组成单个 tiledlayout，横轴均为层，共享一组图例，不画逐鼠散点。
% 柱高表示跨鼠均值，误差条表示均值标准误，两组采用独立样本秩和检验。
% 语义配色：12 h = Color12h，TH = ColorTH，RGB 原始值除以 255。
%
% 输出（SVG）：
%   - English_Fig5E_THInhibitVsCtrl_HeterogeneityAndDivergenceByLayer.svg
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
	error('Fig5E:No1s', '无法找到接近 cue 后 1 s 的采样点。');
end

[sdCtrl23, sdCtrl5] = iCohortData(CtrlDS, idx1s, "Transfer", "Final");
[sdTH23, sdTH5] = iCohortData(THDS, idx1s, "Transfer", "Final");
dataCell = {sdCtrl23, sdTH23; sdCtrl5, sdTH5};
[divCtrl, sessCtrl] = iCohortDivergence(CtrlDS, idx1s, "Transfer", "Final");
[divTH, sessTH] = iCohortDivergence(THDS, idx1s, "Transfer", "Final");
divDataCell = {divCtrl.DivL23, divTH.DivL23; divCtrl.DivL5, divTH.DivL5};
layerLabels = ["MOp2/3", "MOp5"];
groupLabels = ["12 h", "TH"];
groupColors = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;

pLayers = nan(1, 2);
pDivLayers = nan(1, 2);
fprintf('=== 英文图5E：Transfer 光水阶段的分层响应异质性与散度 ===\n');
for iLayer = 1:2
	vCtrl = dataCell{iLayer, 1};
	vTH = dataCell{iLayer, 2};
	vCtrl = vCtrl(isfinite(vCtrl));
	vTH = vTH(isfinite(vTH));
	if numel(vCtrl) < 2 || numel(vTH) < 2
		error('Fig5E:InsufficientHeterogeneityData', '%s 响应异质性数据不足：12 h n=%d，TH n=%d。', ...
			layerLabels(iLayer), numel(vCtrl), numel(vTH));
	end
	pLayers(iLayer) = ranksum(vCtrl, vTH);
	dataCell{iLayer, 1} = vCtrl;
	dataCell{iLayer, 2} = vTH;
	fprintf('响应异质性 %s：12 h %.3f ± %.3f（n=%d）| TH %.3f ± %.3f（n=%d）| 秩和检验 p=%.4g\n', ...
		layerLabels(iLayer), mean(vCtrl), iSem(vCtrl), numel(vCtrl), ...
		mean(vTH), iSem(vTH), numel(vTH), pLayers(iLayer));

	vCtrl = divDataCell{iLayer, 1};
	vTH = divDataCell{iLayer, 2};
	vCtrl = vCtrl(isfinite(vCtrl));
	vTH = vTH(isfinite(vTH));
	if numel(vCtrl) < 2 || numel(vTH) < 2
		error('Fig5E:InsufficientDivergenceData', '%s 散度数据不足：12 h n=%d，TH n=%d。', ...
			layerLabels(iLayer), numel(vCtrl), numel(vTH));
	end
	pDivLayers(iLayer) = ranksum(vCtrl, vTH);
	divDataCell{iLayer, 1} = vCtrl;
	divDataCell{iLayer, 2} = vTH;
	fprintf('散度 %s：12 h %.3f ± %.3f（n=%d）| TH %.3f ± %.3f（n=%d）| 秩和检验 p=%.4g\n', ...
		layerLabels(iLayer), mean(vCtrl), iSem(vCtrl), numel(vCtrl), ...
		mean(vTH), iSem(vTH), numel(vTH), pDivLayers(iLayer));
end

%% ---------- 绘图：上下双面板，上为响应异质性，下为散度 ----------
f = figure('Color', 'w', 'Name', 'English Fig5E TH inhibition heterogeneity and divergence by layer');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];
Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');

dataTable = cell2table(dataCell, 'VariableNames', cellstr(groupLabels), ...
	'RowNames', cellstr(layerLabels));
dataTable.Properties.DimensionNames = cellstr(["Layer", "Group"]);
compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dataTable.Properties.DimensionNames);
colorTable = array2table(groupColors, 'VariableNames', {'R', 'G', 'B'}, ...
	'RowNames', cellstr(groupLabels));

axHet = nexttile(Layout, 1);
[~, optionalHet, barHet, errorHet] = UniExp.BarScatterCompare(dataTable, compareGroup, ...
	colorTable, axHet, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iStyleBars(axHet, barHet, errorHet, groupColors);
iOverridePText(optionalHet, pLayers);
legendHandle = optionalHet.Legend;
legendHandle.String = cellstr(groupLabels);
legendHandle.Title.String = 'Group';
legendHandle.Title.FontWeight = 'normal';
legendHandle.Location = 'eastoutside';
legendHandle.Box = 'off';
ylabel(axHet, 'Resp. heter.');
title(axHet, '💡💧 Transfer', 'FontWeight', 'normal');
xticklabels(axHet, {});
box(axHet, 'off');
grid(axHet, 'off');
iRetunePValueLines(optionalHet);

divDataTable = cell2table(divDataCell, 'VariableNames', cellstr(groupLabels), ...
	'RowNames', cellstr(layerLabels));
divDataTable.Properties.DimensionNames = cellstr(["Layer", "Group"]);
compareGroupDiv = iWithinLayerCompareGroup(layerLabels, groupLabels, divDataTable.Properties.DimensionNames);
axDiv = nexttile(Layout, 2);
[~, optionalDiv, barDiv, errorDiv] = UniExp.BarScatterCompare(divDataTable, compareGroupDiv, ...
	colorTable, axDiv, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iStyleBars(axDiv, barDiv, errorDiv, groupColors);
iOverridePText(optionalDiv, pDivLayers);
legend(axDiv, 'off');
ylabel(axDiv, 'Divergence');
xticklabels(axDiv, layerLabels);
box(axDiv, 'off');
grid(axDiv, 'off');
iRetunePValueLines(optionalDiv);
xlabel(Layout, 'Layer');

TransferLearning.ApplyStandardExportStyle(f, 2);
% 以下面板的误差条帽宽为基准统一两个面板。
% 沿用 Fig2O 的比例：帽宽 = 单个柱宽在坐标轴中对应点数的 0.5 倍。
iMatchTopErrorBarCaps(axHet, barHet, errorHet, axDiv, barDiv, errorDiv, 0.5);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig5E_THInhibitVsCtrl_HeterogeneityAndDivergenceByLayer.svg');
exportgraphics(f, svgPath, 'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig5E_TH_HeterogeneityByLayer', struct( ...
	'Control12h', table(sdCtrl23, sdCtrl5, 'VariableNames', {'MOp23', 'MOp5'}), ...
	'TH', table(sdTH23, sdTH5, 'VariableNames', {'MOp23', 'MOp5'})));
assignin('base', 'Fig5E_TH_HeterogeneityPValues', ...
	table(layerLabels(:), pLayers(:), 'VariableNames', {'Layer', 'RankSumP'}));
assignin('base', 'Fig5E_TH_DivergenceByLayer', struct('Control12h', divCtrl, 'TH', divTH));
assignin('base', 'Fig5E_TH_DivergenceSessions', struct('Control12h', sessCtrl, 'TH', sessTH));
assignin('base', 'Fig5E_TH_DivergencePValues', ...
	table(layerLabels(:), pDivLayers(:), 'VariableNames', {'Layer', 'RankSumP'}));

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

function [mouseDiv, sessionDiv] = iCohortDivergence(DS, idx1s, phaseStart, phaseEnd)
% 会话筛选沿用 Fig4D，逐会话散度按原英文图5F计算。
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

% ---------- 柱状图与显著性样式，同英文图5E ----------
function compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dimensionNames)
layerPair = [layerLabels(:), layerLabels(:)];
groupPair = repmat(groupLabels(1:2), numel(layerLabels), 1);
GroupPair = table(layerPair, groupPair, 'VariableNames', cellstr(dimensionNames));
compareGroup = table(GroupPair);
end

function capSize = iErrorBarCapSize(ax, barHandles, capSizeRatio)
% 将柱宽换算为坐标轴的点单位，再按比例计算误差条帽宽。
axUnits = ax.Units;
ax.Units = 'points';
axWidth = ax.Position(3);
ax.Units = axUnits;
capSize = axWidth * barHandles(1).BarWidth * barHandles(1).GroupWidth * ...
	capSizeRatio / (diff(xlim(ax)) * numel(barHandles));
end

function iMatchTopErrorBarCaps(axHet, barHet, errorHet, axDiv, barDiv, errorDiv, capSizeRatio)
% 下方面板保留默认值，上方面板使用相同的物理帽宽。
capSize = iErrorBarCapSize(axDiv, barDiv, capSizeRatio);
for iRow = 1:height(errorHet)
	eBar = errorHet.Object(iRow);
	if isgraphics(eBar) && isprop(eBar, 'CapSize')
		eBar.CapSize = capSize;
	end
end
for iRow = 1:height(errorDiv)
	eBar = errorDiv.Object(iRow);
	if isgraphics(eBar) && isprop(eBar, 'CapSize')
		eBar.CapSize = capSize;
	end
end
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
