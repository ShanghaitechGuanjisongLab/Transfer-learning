% 英文图5E：TH 抑制组与 12 h 对照组的分层重激活率比较。
%
% 重激活率 = P(Transfer 阶段活跃 | Learned 阶段活跃)，在 cue 后 +1 s 判定。
% Learned 阶段取每鼠最后一个 Learned/AudioWater 会话，Transfer 阶段取每鼠
% 首个 Transfer/LightWater 会话。仅保留两阶段共同细胞，MOp2/3 与 MOp5
% 分别计算。活跃判定：该细胞的中位数 z 分数 > 基线（−3～0 s）均值 + 3σ。
% 数据与计算沿用英文图 S1G 所用的逐鼠逐层构造函数，不要求 Hit/Miss 分组。
%
% 样式与英文图5F一致：单个面板，横轴为层，图例为组，不画逐鼠散点，
% 柱高表示跨鼠均值，误差条表示均值标准误，两组采用独立样本秩和检验。
% 语义配色：12 h = Color12h，TH = ColorTH，RGB 原始值除以 255。
%
% 输出（SVG）：
%   - English_Fig5E_THInhibitVsCtrl_ReactivationByLayer.svg
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

RCtrl = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = TransferLearning.AudioLightBaseline(), Source = "AudioLightBaseline", RequireHitMiss = false);
RTH = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = TransferLearning.THInhibit(), Source = "THInhibit", RequireHitMiss = false);
if isempty(RCtrl) || isempty(RTH)
	error('Fig5E:Empty', '未获得有效的重激活率数据。');
end

dataCell = {double(RCtrl.Prob23), double(RTH.Prob23); ...
	double(RCtrl.Prob5), double(RTH.Prob5)};
layerLabels = ["MOp2/3", "MOp5"];
groupLabels = ["12 h", "TH"];
groupColors = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;
pLayers = nan(1, 2);
fprintf('=== 英文图5E：首个 Transfer 会话的分层重激活率 ===\n');
for iLayer = 1:2
	vCtrl = dataCell{iLayer, 1};
	vTH = dataCell{iLayer, 2};
	vCtrl = vCtrl(isfinite(vCtrl));
	vTH = vTH(isfinite(vTH));
	if numel(vCtrl) < 2 || numel(vTH) < 2
		error('Fig5E:InsufficientData', '%s 数据不足：12 h n=%d，TH n=%d。', ...
			layerLabels(iLayer), numel(vCtrl), numel(vTH));
	end
	pLayers(iLayer) = ranksum(vCtrl, vTH);
	dataCell{iLayer, 1} = vCtrl;
	dataCell{iLayer, 2} = vTH;
	if iLayer == 1
		nCtrlCells = sum(double(RCtrl.NLearnedActive23), 'omitnan');
		nTHCells = sum(double(RTH.NLearnedActive23), 'omitnan');
	else
		nCtrlCells = sum(double(RCtrl.NLearnedActive5), 'omitnan');
		nTHCells = sum(double(RTH.NLearnedActive5), 'omitnan');
	end
	fprintf('%s：12 h %.3f ± %.3f（n=%d 鼠，%d 细胞）| TH %.3f ± %.3f（n=%d 鼠，%d 细胞）| 秩和检验 p=%.4g\n', ...
		layerLabels(iLayer), mean(vCtrl), iSem(vCtrl), numel(vCtrl), nCtrlCells, ...
		mean(vTH), iSem(vTH), numel(vTH), nTHCells, pLayers(iLayer));
end

%% ---------- 绘图：单面板，横轴为层，图例为组 ----------
f = figure('Color', 'w', 'Name', 'English Fig5E TH inhibition reactivation by layer');
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
ylabel(ax, 'Reactivation');
title(ax, '💡💧 Transfer', 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
iRetunePValueLines(optional);

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig5E_THInhibitVsCtrl_ReactivationByLayer.svg');
exportgraphics(f, svgPath, 'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig5E_TH_ReactivationByLayer', struct('Control12h', RCtrl, 'TH', RTH));
assignin('base', 'Fig5E_TH_ReactivationPValues', ...
	table(layerLabels(:), pLayers(:), 'VariableNames', {'Layer', 'RankSumP'}));

%% ========== 局部函数：柱状图与显著性样式，同英文图5F ==========
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
