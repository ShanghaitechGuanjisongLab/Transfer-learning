% 临时图（暂不赋予图号）：ALDelayed 光水 transfer 群体轨迹 PCA（仅 MOp2/3 细胞，单 tile）。
% 模仿英文图1D（英文图/Fig1D_DivergencePCA_L23.m）的做法，但只画 transfer 一组：
% 数据源 TransferLearning.ALDelayed（有延迟不舔不给水钙成像，声水转光水，延迟任务）。
% 该库无 Phase 列：transfer 会话 = 每鼠首个含 LightLearnWater 回合的 DateTime（等价 Transfer 首块），
% 与英文图/ALDelayed_DivVsHitRate_Scatter.m 口径一致；本图用该会话全部光水回合
% （LightLearnWater + LightLearnWaterAlways，等价 Fig1D 的"该会话全部 LightWater 回合"）。
% 只取 MOp2/3 细胞（Cells.ZLayer=="MOp2/3"，MOp5 舍弃），与英文图1D一致。
% super-mouse 口径同 Fig1D：每细胞取该会话全部光水回合（按 TrialUID 排序），尽可能均分成 nLines 组
% （组间最多差 1 回合）后组内平均 → 每细胞 nLines 条轨迹；归一化 ZScore（基线 1:24）匹配散度口径。
% 与 Fig1D 的差别：延迟任务的反应/名义给水时刻是 cue +1.5 s 而非 +1 s（见 ALDelayed_DivVsHitRate_Scatter），
% 绘图时段 cue 0 → +1.5 s，轨迹浅色端=cue 起点、深色端=名义给水时刻。
% 轨迹着色为线内时间渐变：cue 端接近白（基色仅 15%）、向给水端渐深到基色；逐段平色小线段（每条 nGradSeg 段）实现。
% PCA 独立计算，坐标轴不标注解释度；展示的是 cue 后轨迹的分叉形态（Naive 扇形分叉=高散度，Transfer 平行=低散度），
% 定量结论以逐鼠散度为准。着色用 TransferColor（声→光迁移的 transfer 侧颜色）。
%
% Outputs (SVG):
%   - English_ALDelayed_DivergencePCA_L23.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

% 可调参数：把每细胞的全部回合尽可能均分成多少条轨迹
nLines = 10;
% 可调参数：线内渐变的分段数（每条轨迹拆成多少段平色小线段）
nGradSeg = 40;

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.ALDelayed();
sess = iFirstTransferLightSessions(DS);
if isempty(sess)
	error('ALDelayedPCA:NoTransferSession', 'No LightLearnWater session found in ALDelayed.');
end

GN = iNtsSuperMouseFromSessions(sess, nLines);
PlotData = iComputePcaPlotData(GN);
%%

f = figure('Color', 'w', 'Name', 'ALDelayed divergence PCA transfer L23');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 8];
f.PaperSize = [6, 8];

tlo = tiledlayout(f, 1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
axT = nexttile(tlo, 1);
iPlotTrialsAttachedOnAxes(axT, PlotData, TransferLearning.TransferColor, nGradSeg);
title(axT, "Transfer (delayed)");
xlabel(tlo, 'PC1');
ylabel(tlo, 'PC2');
iApplySingleLimits(axT, PlotData);

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_ALDelayed_DivergencePCA_L23.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Sessions used:\n');
for iS = 1:height(sess)
	fprintf('  %s  %s\n', sess.Mouse(iS), datestr(sess.DateTime(iS), 'yyyy-mm-dd HH:MM'));
end
fprintf('Transfer cells used: %d (mice %d)\n', height(GN), numel(unique(string(GN.Mouse))));
fprintf('Transfer PC explained: %.1f%% / %.1f%%\n', PlotData.PcaTable.Explained(1), PlotData.PcaTable.Explained(2));

assignin('base', 'ALDelayed_PCA_Transfer_GroupNtats', GN);

%% ========== local functions（口径同英文图1D，会话定义适配 ALDelayed） ==========
function sess = iFirstTransferLightSessions(DS)
% 该库无 Phase 列：每鼠取首个含 LightLearnWater 回合的 DateTime，等价 Transfer 首块。
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS','Mouse','DateTime'});
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"]);
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
T = T(T.Stimulus == "LightLearnWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	dt = min(Tm.DateTime);
	sess = [sess; table(DS, mice(i), dt, 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function GroupNtats = iNtsSuperMouseFromSessions(sess, nLines)
% 会话表的 DS 列直接携带数据集对象；只保留 ZLayer=="MOp2/3" 的细胞。
% 每细胞取该会话全部光水回合（LightLearnWater+LightLearnWaterAlways，按 TrialUID 排序），
% 尽可能均分成 nLines 组（组间最多差 1 回合）后组内平均 → 每细胞 nLines 条轨迹。
cellTraces = {};
cellUIDList = zeros(0, 1, 'uint64');
mouseList = strings(0, 1);
for iS = 1:height(sess)
	DS = sess.DS(iS);
	ntsCell = DS.QueryNTS(struct('Stimulus', ["LightLearnWater","LightLearnWaterAlways"], 'Mouse', sess.Mouse(iS), 'DateTime', sess.DateTime(iS)), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
	if isempty(nts)
		continue;
	end
	cellTbl = DS.Cells;
	cellTbl.CellUID = uint64(cellTbl.CellUID);
	cellTbl.ZLayer = string(cellTbl.ZLayer);
	cellTbl.Mouse = string(cellTbl.Mouse);
	mCell = cellTbl(cellTbl.Mouse == sess.Mouse(iS), :);
	cellUIDs = unique(uint64(nts.CellUID));
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		[isIn, loc] = ismember(cid, mCell.CellUID);
		if ~isIn || mCell.ZLayer(loc) ~= "MOp2/3"
			continue;
		end
		rowsC = (uint64(nts.CellUID) == cid);
		uid = uint64(nts.TrialUID(rowsC));
		sig = double(nts.TrialSignal(rowsC, :));
		[~, order] = sort(uid);
		sig = sig(order, :);
		meanSig = iAverageIntoNLines(sig, nLines);
		if isempty(meanSig)
			continue;
		end
		cellTraces{end+1, 1} = meanSig; %#ok<AGROW>
		cellUIDList(end+1, 1) = cid; %#ok<AGROW>
		mouseList(end+1, 1) = sess.Mouse(iS); %#ok<AGROW>
	end
end
if isempty(cellTraces)
	error('ALDelayedPCA:EmptySuperMouse', 'No MOp2/3 cells found after pooling.');
end
nCells = numel(cellTraces);
nGroupActual = size(cellTraces{1}, 1);
nTime = size(cellTraces{1}, 2);
CellTrialTimes = nan(nCells, nGroupActual, nTime);
for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellTraces{iC};
end
ntatsData = permute(CellTrialTimes, [1, 3, 2]);
ntats = MATLAB.DataTypes.NDTable(ntatsData);
GroupNtats = table(ntats, cellUIDList, mouseList, 'VariableNames', ["NTATS", "CellUID", "Mouse"]);
end

function meanSig = iAverageIntoNLines(sig, nLines)
% 把 sig（nTrial × nTime）按回合顺序尽可能均分成 nLines 组，组内平均；组间最多差 1 回合，靠前的组多 1 回合。
nTrial = size(sig, 1);
nTime = size(sig, 2);
if nTrial < 1 || nTime < 1
	meanSig = [];
	return;
end
nLines = min(nLines, nTrial);
groupSize = ones(1, nLines) * floor(nTrial / nLines);
groupSize(1:(nTrial - floor(nTrial / nLines) * nLines)) = groupSize(1:(nTrial - floor(nTrial / nLines) * nLines)) + 1;
boundStart = [1, cumsum(groupSize(1:end-1)) + 1];
boundEnd = cumsum(groupSize);
meanSig = nan(nLines, nTime);
for k = 1:nLines
	meanSig(k, :) = mean(sig(boundStart(k):boundEnd(k), :), 1, 'omitnan');
end
end

function PlotData = iComputePcaPlotData(GroupNtats)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2, true);
PcaLines = PcaTable.Score;
PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
idxCue = iFindPlotTimeIndex(nTime, 0);
idxWater = iFindPlotTimeIndex(nTime, 1.5);
idxPlotTime = idxCue:idxWater;
PcaData = PcaDataAll(:, idxPlotTime, :);
PlotData = struct();
PlotData.PcaTable = PcaTable;
PlotData.PcaData = PcaData;
PlotData.nLines = size(PcaData, 3);
% 只画 cue 后轨迹（cue 0 → 名义给水 +1.5 s），span 也只统计该段
xAll = reshape(PcaData(1, :, :), [], 1);
yAll = reshape(PcaData(2, :, :), [], 1);
PlotData.xSpan = max(xAll) - min(xAll);
PlotData.ySpan = max(yAll) - min(yAll);
if ~(isfinite(PlotData.xSpan) && PlotData.xSpan > 0)
	PlotData.xSpan = 1;
end
if ~(isfinite(PlotData.ySpan) && PlotData.ySpan > 0)
	PlotData.ySpan = 1;
end
end

function hTrial = iPlotTrialsAttachedOnAxes(ax, PlotData, groupColor, nGradSeg)
ax.FontSize = 12;
ax.LineWidth = 1;
box(ax, 'off');
grid(ax, 'off');
hold(ax, 'on');
PcaData = PlotData.PcaData;
for iLine = 1:PlotData.nLines
	xy = squeeze(PcaData(:, :, iLine));
	iGradientPath(ax, xy(1, :), xy(2, :), groupColor, nGradSeg);
end
hTrial = plot(ax, nan, nan, '-', 'LineWidth', 2, 'Color', groupColor);
view(ax, 2);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iApplySingleLimits(ax, PlotData)
% 轴限只覆盖 cue 后轨迹段
PcaData = PlotData.PcaData;
xAll = reshape(PcaData(1, :, :), [], 1);
yAll = reshape(PcaData(2, :, :), [], 1);
xMargin = 0.06 * PlotData.xSpan;
yMargin = 0.08 * PlotData.ySpan;
if ~(isfinite(xMargin) && xMargin > 0)
	xMargin = 1;
end
if ~(isfinite(yMargin) && yMargin > 0)
	yMargin = 1;
end
xlim(ax, [min(xAll) - xMargin, max(xAll) + xMargin]);
ylim(ax, [min(yAll) - yMargin, max(yAll) + yMargin]);
end

function iGradientPath(ax, x, y, baseColor, nSeg)
% 线内时间渐变：把 cue→water 折线按时间重采样成 nSeg 段，逐段平色，
% 早段接近白（baseColor 仅 15%）、晚段为基色。
% 用 line 图元逐段绘制：plot 返回的 2 点线会被标准样式误判为轴对齐细线
% （line 图元不受影响），且平色段在 SVG 导出中保持稳定。
x = x(:)';
y = y(:)';
n = numel(x);
tt = linspace(1, n, nSeg + 1);
xs = interp1(1:n, x, tt);
ys = interp1(1:n, y, tt);
f = linspace(0, 1, nSeg);
for k = 1:nSeg
	ck = 1 - f(k) * (1 - baseColor(:)');
	line(ax, xs(k:k+1), ys(k:k+1), 'Color', ck, 'LineWidth', 2, 'HandleVisibility', 'off');
end
end

function idx = iFindPlotTimeIndex(nTime, targetSec)
xsSec = seconds(TransferLearning.Xs);
if numel(xsSec) == nTime
	[~, idx] = min(abs(xsSec(:) - targetSec));
	return;
end
sampleRate = 8;
idx = round((targetSec + 3) * sampleRate) + 1;
idx = max(1, min(nTime, idx));
end
