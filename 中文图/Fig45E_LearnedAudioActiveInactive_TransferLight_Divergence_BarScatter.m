% 中文图334E：模仿英文图2H的风格，比较声水学会活跃/不活跃细胞在光水迁移首会话中的相对散度

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile("\\Data-Server-2\个人数据\张天夫", char(datetime('now', 'Format', 'yyyyMM')));

DS = TransferLearning.AudioLightBaseline();
CellMap = iCellMap(DS);

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok0 || ~ok1s
	error('Fig334E:TimeIndexMissing', 'Cannot find 0 s or 1 s sample in TransferLearning.Xs.');
end

TTransfer = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TLearned = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
if isempty(TTransfer) || isempty(TLearned)
	error('Fig334E:EmptySessions', 'Transfer or Learned sessions are missing.');
end
TTransfer.Mouse = string(TTransfer.Mouse);
TLearned.Mouse = string(TLearned.Mouse);
TTransfer.DateTime = iNormalizeDateTime(TTransfer.DateTime);
TLearned.DateTime = iNormalizeDateTime(TLearned.DateTime);

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["MOp2/3"; "MOp5"];
mice = intersect(unique(TTransfer.Mouse), unique(TLearned.Mouse));
nMice = numel(mice);
DivActive = nan(nMice, numel(layers));
DivInactive = nan(nMice, numel(layers));
NCellActive = zeros(nMice, numel(layers));
NCellInactive = zeros(nMice, numel(layers));

for iM = 1:nMice
	m = mice(iM);
	RTransfer = TTransfer(TTransfer.Mouse == m, :);
	RLearned = TLearned(TLearned.Mouse == m, :);
	if isempty(RTransfer) || isempty(RLearned)
		continue;
	end

	dtTransfer = min(RTransfer.DateTime);
	dtLearned = max(RLearned.DateTime);
	transferTrials = unique(uint64(sortrows(RTransfer(RTransfer.DateTime == dtTransfer, :), 'TrialIndex').TrialUID), 'stable');
	learnedTrials = unique(uint64(sortrows(RLearned(RLearned.DateTime == dtLearned, :), 'TrialIndex').TrialUID), 'stable');
	if numel(transferTrials) < 2 || numel(learnedTrials) < 2
		continue;
	end

	ntsTransfer = DS.QueryNTS(struct('Mouse', m, 'DateTime', dtTransfer, 'Stimulus', "LightWater"), UniExp.Flags.ZScore, 1:24);
	ntsLearned = DS.QueryNTS(struct('Mouse', m, 'DateTime', dtLearned, 'Stimulus', "AudioWater"), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsTransfer)
		ntsTransfer = ntsTransfer{1};
	end
	if iscell(ntsLearned)
		ntsLearned = ntsLearned{1};
	end
	if isempty(ntsTransfer) || isempty(ntsLearned)
		continue;
	end

	[CTTTransfer, uidTransfer] = iBuildCTT(ntsTransfer, transferTrials, idx0);
	[CTTLearned, uidLearned] = iBuildCTT(ntsLearned, learnedTrials, idx0);
	if isempty(CTTTransfer) || isempty(CTTLearned)
		continue;
	end

	LearnedMean = squeeze(mean(CTTLearned, 2, 'omitnan'));
	baseMu = mean(LearnedMean(:, xsSec >= -3 & xsSec < 0), 2, 'omitnan');
	baseSd = std(LearnedMean(:, xsSec >= -3 & xsSec < 0), 0, 2, 'omitnan');
	vLearned1 = LearnedMean(:, idx1s);
	learnedActive = isfinite(vLearned1) & isfinite(baseMu) & isfinite(baseSd) & (vLearned1 > (baseMu + 3 * baseSd));
	activeUID = uidLearned(learnedActive);

	[tfLayer, locLayer] = ismember(uidTransfer, CellMap.CellUID);
	transferLayer = strings(numel(uidTransfer), 1);
	transferLayer(tfLayer) = CellMap.ZLayer(locLayer(tfLayer));
	transferAt1 = CTTTransfer(:, :, idx1s);
	isActiveTransferCell = ismember(uidTransfer, activeUID);

	for iL = 1:numel(layers)
		isLayer = transferLayer == layers(iL);
		maskActive = isLayer & isActiveTransferCell;
		maskInactive = isLayer & ~isActiveTransferCell;
		if nnz(maskActive) >= 3
			NCellActive(iM, iL) = nnz(maskActive);
			DivActive(iM, iL) = iRelativeDivergence(transferAt1(maskActive, :));
		end
		if nnz(maskInactive) >= 3
			NCellInactive(iM, iL) = nnz(maskInactive);
			DivInactive(iM, iL) = iRelativeDivergence(transferAt1(maskInactive, :));
		end
	end
end
%% 

f = figure('Color', 'w', 'Name', 'Fig334E Learned active/inactive transfer divergence');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6,8];
f.PaperSize = [6,8];

palette2 = TransferLearning.GroupColors(["Active", "Inactive"]);
Stats = table(layerLabels, nan(numel(layers), 1), nan(numel(layers), 1), nan(numel(layers), 1), nan(numel(layers), 1), nan(numel(layers), 1), nan(numel(layers), 1), ...
	'VariableNames', {'Layer','MeanActive','MeanInactive','PValue','NMouse','NCellActive','NCellInactive'});
layerData = cell(numel(layers), 2);

for iL = 1:numel(layers)
	vA = DivActive(:, iL);
	vI = DivInactive(:, iL);
	use = isfinite(vA) & isfinite(vI);
	vA = vA(use);
	vI = vI(use);
	if numel(vA) < 3
		error('Fig334E:TooFewPairs', 'Too few paired mice for %s.', layerLabels(iL));
	end
	p = signrank(vA, vI);
	nMouseLayer = numel(vA);
	nCellActive = sum(NCellActive(use, iL));
	nCellInactive = sum(NCellInactive(use, iL));
	Stats.MeanActive(iL) = mean(vA, 'omitnan');
	Stats.MeanInactive(iL) = mean(vI, 'omitnan');
	Stats.PValue(iL) = p;
	Stats.NMouse(iL) = nMouseLayer;
	Stats.NCellActive(iL) = nCellActive;
	Stats.NCellInactive(iL) = nCellInactive;
	layerData{iL, 1} = double(vA(:));
	layerData{iL, 2} = double(vI(:));

	fprintf('\n=== Fig334E %s ===\n', layerLabels(iL));
	fprintf('Mouse count: n = %d paired mice\n', nMouseLayer);
	fprintf('Cell count: Active %d cells; Inactive %d cells\n', nCellActive, nCellInactive);
	fprintf('Active:   %.3f ± %.3f (n=%d mice)\n', mean(vA), std(vA)/sqrt(numel(vA)), numel(vA));
	fprintf('Inactive: %.3f ± %.3f (n=%d mice)\n', mean(vI), std(vI)/sqrt(numel(vI)), numel(vI));
	fprintf('signrank p = %.6g\n', p);
end

ax = axes(f);
groupLabels = ["Active", "Inactive"];
dataTable = cell2table(layerData, 'VariableNames', cellstr(groupLabels), 'RowNames', cellstr(layerLabels));
dataTable.Properties.DimensionNames = {'Layer', 'Group'};
compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dataTable.Properties.DimensionNames);
[~, optional, bars, errorBars] = UniExp.BarScatterCompare(dataTable, UniExp.Flags.IndividualErrorbars, compareGroup, iColorTable(groupLabels, palette2), ax, 'AsteriskThreshold', 0.05);
for iBar = 1:numel(bars)
	bars(iBar).BarWidth = 0.5;
	bars(iBar).LineWidth = 1;
	bars(iBar).EdgeColor = 'none';
	bars(iBar).LineStyle = 'none';
	bars(iBar).DisplayName = groupLabels(iBar);
	if isprop(bars(iBar), 'FaceAlpha')
		bars(iBar).FaceAlpha = 1;
	end
	if isprop(bars(iBar), 'BaseLine') && isgraphics(bars(iBar).BaseLine)
		bars(iBar).BaseLine.Visible = 'off';
	end
end
iStyleErrorBars(errorBars, bars, groupLabels, palette2);
iRetunePValueLines(optional);

ax.FontName = 'Arial';
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ax.XTickLabelRotation = 0;
ylabel(ax, '💡💧 Divergence', 'FontName', 'Arial', 'FontSize', 6);
xlabel(ax, 'Layer', 'FontName', 'Arial', 'FontSize', 6);
title(ax, 'Learned active vs inactive', 'FontName', 'Arial', 'FontSize', 6, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
leg = legend(bars, cellstr(groupLabels), 'Location', 'northwest', 'Box', 'off');
leg.FontName = 'Arial';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig45E_LearnedAudioActiveInactive_TransferLight_Divergence_BarScatter.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig334E_Stats', Stats);
assignin('base', 'Fig334E_Data', struct('Mouse', mice, 'DivActive', DivActive, 'DivInactive', DivInactive, 'NCellActive', NCellActive, 'NCellInactive', NCellInactive, 'Layers', layers));

function CellMap = iCellMap(DS)
CellMap = DS.Cells(:, {'CellUID', 'ZLayer'});
CellMap.CellUID = uint64(CellMap.CellUID);
CellMap.ZLayer = string(CellMap.ZLayer);
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0)
ctt = [];
cellUIDs = uint64([]);
keepTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts = nts(keepTrial, :);
if isempty(nts)
	return;
end
trialUIDs = trialUIDs(ismember(trialUIDs, unique(uint64(nts.TrialUID), 'stable')));
if numel(trialUIDs) < 2
	return;
end
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rows = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rows));
	sig = double(nts.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	ordered = sig(loc, :);
	if any(~isfinite(ordered), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traceCell{nKeep} = ordered;
	keepUID(nKeep) = cid;
	end
	if nKeep < 1
		return;
	end
	traceCell = traceCell(1:nKeep);
	keepUID = keepUID(1:nKeep);
	nTrial = size(traceCell{1}, 1);
	nTime = size(traceCell{1}, 2);
	ctt = nan(nKeep, nTrial, nTime);
	for iC = 1:nKeep
		ctt(iC, :, :) = traceCell{iC};
	end
	ctt = ctt - ctt(:, :, idx0);
	cellUIDs = keepUID;
end

function div = iRelativeDivergence(X)
if size(X, 1) < 3 || size(X, 2) < 2
	div = NaN;
	return;
end
signalPower = sum(mean(X, 2, 'omitnan').^2, 'omitnan');
noisePower = sum(var(X, 0, 2, 'omitnan'), 'omitnan');
if signalPower <= 0 || ~isfinite(signalPower) || ~isfinite(noisePower)
	div = NaN;
	return;
end
div = sqrt(noisePower / signalPower);
end

function compareGroup = iWithinLayerCompareGroup(layerLabels, groupLabels, dimensionNames)
layerLabels = string(layerLabels(:));
groupLabels = string(groupLabels(:)).';
layerPair = [layerLabels, layerLabels];
groupPair = repmat(groupLabels(1:2), numel(layerLabels), 1);
GroupPair = table(layerPair, groupPair, 'VariableNames', cellstr(dimensionNames));
compareGroup = table(GroupPair);
end

function colors = iColorTable(groupLabels, groupColors)
colors = array2table(groupColors, 'VariableNames', {'R','G','B'}, 'RowNames', cellstr(groupLabels));
end

function iStyleErrorBars(errorBars, bars, groupLabels, groupColors)
if isempty(errorBars)
	return;
end
% 构建 DisplayName → color 映射
nameToColor = containers.Map(cellstr(groupLabels), mat2cell(groupColors, ones(size(groupColors,1),1), size(groupColors,2)));
for rowIndex = 1:height(errorBars)
	errorBar = errorBars.Object(rowIndex);
	if ~isgraphics(errorBar)
		continue;
	end
	x = double(errorBar.XData(1));
	% 找到 X 位置最接近的 bar，用其 DisplayName 确定颜色
	bestDist = inf;
	bestName = '';
	for iBar = 1:numel(bars)
		xp = double(bars(iBar).XEndPoints(:));
		d = min(abs(xp - x));
		if d < bestDist
			bestDist = d;
			bestName = bars(iBar).DisplayName;
		end
	end
	errorBar.LineWidth = 1;
	errorBar.Color = nameToColor(bestName);
	errorBar.HandleVisibility = 'off';
	setappdata(errorBar, 'TransferLearningPreserveLineWidth', true);
end
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
	end
end
for pText = optional.MultiCompare.PText(:)'
	if isgraphics(pText)
		pText.Tag = 'PText';
	end
end
end