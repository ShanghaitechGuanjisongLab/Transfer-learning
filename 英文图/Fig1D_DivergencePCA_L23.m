% English Fig1D: Naive/Transfer population trajectories in leading principal
% component space of the first light-water block (MOp2/3 cells only).
% 自 Temp/Fig1F_PCA_NaiveTransfer_L23.m 提升为正式英文图1D，替换原代表细胞 trial 曲线面板（原脚本 Fig1D_TwoRepresentativeCellTraces.m 留档不删）。
% 鼠源与英文图1F 完全一致：Naive=LightAudioBaseline+LAInterspersed 的首个纯 LW Naive 会话（LAI 中 Naive 期出现过 AudioWater 的鼠整只排除），Transfer=AudioLightBaseline 的首个 Transfer LW 会话；只取 MOp2/3 细胞（Cells.ZLayer=="MOp2/3"，MOp5 舍弃）。
% super-mouse 口径：每细胞取该会话全部 LightWater 回合（按 TrialUID 排序），尽可能均分成 nLines 组（组间最多差 1 回合）后组内平均 → 每细胞 nLines 条轨迹；归一化 ZScore（基线 1:24）匹配散度口径；绘图时段 cue 0 → +1 s（undelayed 范式给水在线索后 1 s），轨迹浅色端=cue 起点、深色端=给水时刻。
% 轨迹着色为线内时间渐变：cue 端接近白（基色仅 15%）、向给水端渐深到基色；逐段平色小线段（每条 nGradSeg 段）实现，不用跨线的深浅区分。
% 两 tile 的 PCA 独立计算（两组细胞集合不相交），各坐标轴不标注解释度、不统一轴限；展示的是 cue 后轨迹的分叉形态——Naive 扇形分叉=高散度，Transfer 平行=低散度，定量结论以逐鼠散度（Fig1E/1F）为准。
%
% Outputs (SVG):
%   - English_Fig1D_DivergencePCA_L23.svg   (legend -> Scale = 2)
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

ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

badNaiveLai = iMiceWithStimulusInPhase(LAI, "AudioWater", "Naive");
sessNaive = [iFirstPureLWNaiveSessions(LAB, strings(0, 1)); iFirstPureLWNaiveSessions(LAI, badNaiveLai)];
sessTransfer = iFirstTransferLWSessions(ALB);

GN = iNtsSuperMouseFromSessions(sessNaive, nLines);
GT = iNtsSuperMouseFromSessions(sessTransfer, nLines);
PlotDataN = iComputePcaPlotData(GN);
PlotDataT = iComputePcaPlotData(GT);
%%

f = figure('Color', 'w', 'Name', 'English Fig1D divergence PCA naive transfer L23');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
axN = nexttile(tlo, 1);
iPlotTrialsAttachedOnAxes(axN, PlotDataN, TransferLearning.NaiveColor, nGradSeg);
title(axN, "Naive light response", 'FontSize', 12);
xlabel(axN, 'PC1', 'FontSize', 12);
ylabel(axN, 'PC2', 'FontSize', 12);
iApplySingleLimits(axN, PlotDataN);

axT = nexttile(tlo, 2);
iPlotTrialsAttachedOnAxes(axT, PlotDataT, TransferLearning.TransferColor, nGradSeg);
title(axT, "Transfer light response", 'FontSize', 12);
axT.YAxisLocation = 'right';
xlabel(axT, 'PC1', 'FontSize', 12);
ylabel(axT, 'PC2', 'FontSize', 12);
iApplySingleLimits(axT, PlotDataT);

hNaiveLegend = plot(axN, nan, nan, '-', 'LineWidth', 2, 'Color', TransferLearning.NaiveColor);
hTransferLegend = plot(axN, nan, nan, '-', 'LineWidth', 2, 'Color', TransferLearning.TransferColor);

lgd = legend(axN, [hNaiveLegend, hTransferLegend], ["Naive after light cue", "Transfer after light cue"], ...
	'Orientation', 'horizontal', 'NumColumns', 2);
lgd.Layout.Tile = 'south';
lgd.Box = 'off';
lgd.FontSize = 12;
lgd.ItemTokenSize(1) = 8;

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig1D_DivergencePCA_L23.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Naive cells used: %d (mice %d)\n', height(GN), numel(unique(string(GN.Mouse))));
fprintf('Transfer cells used: %d (mice %d)\n', height(GT), numel(unique(string(GT.Mouse))));
fprintf('Naive PC explained: %.1f%% / %.1f%%\n', PlotDataN.PcaTable.Explained(1), PlotDataN.PcaTable.Explained(2));
fprintf('Transfer PC explained: %.1f%% / %.1f%%\n', PlotDataT.PcaTable.Explained(1), PlotDataT.PcaTable.Explained(2));

assignin('base', 'Fig1D_PCA_Naive_GroupNtats', GN);
assignin('base', 'Fig1D_PCA_Transfer_GroupNtats', GT);

%% ========== local functions ==========
function mice = iMiceWithStimulusInPhase(DS, stimulusName, phaseName)
T = DS.TableQuery(["Mouse", "Stimulus", "Phase"], Phase=phaseName);
if isempty(T)
	mice = strings(0, 1);
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
mice = unique(T.Mouse(T.Stimulus == stimulusName));
end

function sess = iFirstPureLWNaiveSessions(DS, excludeMice)
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS','Mouse','DateTime'});
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Naive");
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
if ~isempty(excludeMice)
	T = T(~ismember(T.Mouse, string(excludeMice)), :);
end
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sessDates = sort(unique(Tm.DateTime), 'ascend');
	for s = 1:numel(sessDates)
		Tss = Tm(Tm.DateTime == sessDates(s), :);
		if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
			sess = [sess; table(DS, mice(i), sessDates(s), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
			break;
		end
	end
end
end

function sess = iFirstTransferLWSessions(DS)
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS','Mouse','DateTime'});
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Transfer");
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
T = T(T.Stimulus == "LightWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	dt = min(Tm.DateTime);
	sess = [sess; table(DS, mice(i), dt, 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function GroupNtats = iNtsSuperMouseFromSessions(sess, nLines)
% 会话表的 DS 列直接携带数据集对象；只保留 ZLayer=="MOp2/3" 的细胞。
% 每细胞取该会话全部 LightWater 回合（按 TrialUID 排序），尽可能均分成 nLines 组（组间最多差 1 回合）后组内平均 → 每细胞 nLines 条轨迹。
cellTraces = {};
cellUIDList = zeros(0, 1, 'uint64');
mouseList = strings(0, 1);
nTime = [];
for iS = 1:height(sess)
	DS = sess.DS(iS);
	ntsCell = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', sess.Mouse(iS), 'DateTime', sess.DateTime(iS)), UniExp.Flags.ZScore, 1:24);
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
		if isempty(nTime)
			nTime = size(meanSig, 2);
		end
	end
end
if isempty(cellTraces)
	error('Fig1DPCA:EmptySuperMouse', 'No MOp2/3 cells found after pooling.');
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
idxPreCue = iFindPlotTimeIndex(nTime, -3);
idxCue = iFindPlotTimeIndex(nTime, 0);
idxWater = iFindPlotTimeIndex(nTime, 1);
idxPlotTime = idxPreCue:idxWater;
PcaData = PcaDataAll(:, idxPlotTime, :);
idxCueInPlot = idxCue - idxPreCue + 1;
idxWaterInPlot = idxWater - idxPreCue + 1;
PlotData = struct();
PlotData.PcaTable = PcaTable;
PlotData.PcaData = PcaData;
PlotData.preCueSegment = 1:idxCueInPlot;
PlotData.postCueSegment = idxCueInPlot:idxWaterInPlot;
PlotData.nLines = size(PcaData, 3);
% 只画 cue 后轨迹，span 也只统计 cue 后段
postCueData = PcaData(:, idxCueInPlot:idxWaterInPlot, :);
xAll = reshape(postCueData(1, :, :), [], 1);
yAll = reshape(postCueData(2, :, :), [], 1);
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
	iGradientPath(ax, xy(1, PlotData.postCueSegment), xy(2, PlotData.postCueSegment), groupColor, nGradSeg);
end
hTrial = plot(ax, nan, nan, '-', 'LineWidth', 2, 'Color', groupColor);
view(ax, 2);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iApplySingleLimits(ax, PlotData)
% 只画 cue 后轨迹，轴限只覆盖 cue 后轨迹段
PcaData = PlotData.PcaData(:, PlotData.postCueSegment, :);
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
