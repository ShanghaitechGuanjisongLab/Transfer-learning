% 临时图（暂不赋予图号）：声侧两阶段群体轨迹 PCA 的 2×2 对照（仅 MOp2/3 细胞）。
% 行 = 范式，列 = 声侧阶段：
%   第 1 行 Delayed   = TransferLearning.ALDelayed（有延迟不舔不给水钙成像，声水转光水）；
%   第 2 行 Undelayed = TransferLearning.AudioLightBaseline（无延迟声光迁移MOp成像）。
%   第 1 列 初始只给声   = 每鼠初始会话的纯声音线索回合：Delayed 为 AudioPreTrainCueOnly
%                     （同会话 AudioPreTrainWaterOnly 只给水不给声，不取），Undelayed 为 AudioOnly
%                     （初始校准会话，每鼠仅一个）；
%   第 2 列 最后一次声水训练 = 每鼠声水训练阶段最后一个会话：Delayed 为最后一个含 AudioLearnWater
%                     的会话（只取 AudioLearnWater 回合；AudioLearnWaterAlways 总是给水，
%                     按用户口径不参与分析），Undelayed 为最后一个非 Recall 的 AudioWater 会话
%                     （= Learned 会话；Recall 是光迁移后的回忆测试，不算训练）。
% Undelayed 两列只保留两个阶段都具备的鼠（yqn1130 无 AudioOnly 校准会话，整只排除，
% 与 CueModel_ContextCrossMatrix 的口径一致）→ 10 鼠；Delayed 行 4 鼠。
% 已核对：所选会话不含带 MustWarn 的块（标记块都在中间训练日或光侧）。
% super-mouse 口径同 Fig1D：每细胞取该会话全部目标回合（按 TrialUID 排序），尽可能均分成 nLines 组
% （组间最多差 1 回合）后组内平均 → 每细胞 nLines 条轨迹；归一化 ZScore（基线 1:24）匹配散度口径。
% 绘图时段按各范式的给水时刻：Delayed 行 cue 0 → +1.5 s，Undelayed 行 cue 0 → +1 s（Fig1D 口径）；
% 只给声音的列无给水，但为行内可比取同一时段。轨迹浅色端=cue 起点、深色端=时段末端，
% 着色为线内时间渐变（逐段平色小线段，nGradSeg 段）。
% 4 个 tile 的 PCA 独立计算（各自 super-mouse 群体），各坐标轴不标注解释度；
% 着色按列沿用上下文配色：Audio only = NaiveColor（紫），Audio-water = ColorB（绿）。
%
% Outputs (SVG):
%   - English_AudioOnlyVsLastAudioWater_PCA_L23.svg
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

% ---- Delayed（ALDelayed）----
DSD = TransferLearning.ALDelayed();
sessD1 = iFirstStimSession(DSD, "AudioPreTrainCueOnly");
sessD2 = iLastStimSession(DSD, "AudioLearnWater", "Recall");
% ---- Undelayed（AudioLightBaseline）----
DSU = TransferLearning.AudioLightBaseline();
sessU1 = iFirstStimSession(DSU, "AudioOnly");
sessU2 = iLastStimSession(DSU, "AudioWater", "Recall");
% Undelayed 只保留两个阶段都有的鼠
miceU = intersect(sessU1.Mouse, sessU2.Mouse);
sessU1 = sessU1(ismember(sessU1.Mouse, miceU), :);
sessU2 = sessU2(ismember(sessU2.Mouse, miceU), :);

SessAll = {sessD1, sessD2; sessU1, sessU2};
StimAll = {"AudioPreTrainCueOnly", "AudioLearnWater"; "AudioOnly", "AudioWater"};
WinEnd = [1.5, 1.5; 1.0, 1.0];   % 各行按范式给水时刻（延迟 +1.5 s，无延迟 +1 s）
rowName = ["Delayed", "Undelayed"];
colName = ["Audio only (initial)", "Last audio-water"];

G = cell(2, 2);
P = cell(2, 2);
for r = 1:2
	for c = 1:2
		if isempty(SessAll{r, c})
			error('AudioPCA:NoSession', 'No %s session for %s.', colName(c), rowName(r));
		end
		G{r, c} = iNtsSuperMouseFromSessions(SessAll{r, c}, nLines, StimAll{r, c});
		P{r, c} = iComputePcaPlotData(G{r, c}, WinEnd(r, c));
	end
end
%%

f = figure('Color', 'w', 'Name', 'Audio only vs last audio-water PCA delayed vs undelayed L23');
f.Units = 'centimeters';
f.Position(3:4) = [12, 16];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 16];
f.PaperSize = [12, 16];

colColor = [TransferLearning.NaiveColor; TransferLearning.ColorB];
tlo = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'tight');
for r = 1:2
	for c = 1:2
		ax = nexttile(tlo);
		iPlotTrialsAttachedOnAxes(ax, P{r, c}, colColor(c, :), nGradSeg);
		title(ax, sprintf('%s\n%s', rowName(r), colName(c)));
		iApplySingleLimits(ax, P{r, c});
		if c == 2
			ax.YAxisLocation = 'right';
		end
	end
end
xlabel(tlo, 'PC1');
ylabel(tlo, 'PC2');

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_AudioOnlyVsLastAudioWater_PCA_L23.svg');
fprintf('Wrote: %s\n', svgPath);
for r = 1:2
	for c = 1:2
		fprintf('=== %s / %s\n', rowName(r), colName(c));
		for iS = 1:height(SessAll{r, c})
			fprintf('  %s  %s\n', SessAll{r, c}.Mouse(iS), datestr(SessAll{r, c}.DateTime(iS), 'yyyy-mm-dd HH:MM'));
		end
		fprintf('  cells used: %d (mice %d)\n', height(G{r, c}), numel(unique(string(G{r, c}.Mouse))));
		fprintf('  PC explained: %.1f%% / %.1f%%\n', P{r, c}.PcaTable.Explained(1), P{r, c}.PcaTable.Explained(2));
	end
end

assignin('base', 'AudioPCA_GroupNtats', G);
assignin('base', 'AudioPCA_PlotData', P);

%% ========== local functions（口径同 ALDelayed_DivergencePCA_L23） ==========
function sess = iFirstStimSession(DS, stim)
% 每鼠首个含 stim 回合的 DateTime（初始阶段，如只给声的预训练/校准会话）。
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T)
	return;
end
T = T(ismember(T.Stimulus, stim), :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iLastStimSession(DS, stim, excludePhases)
% 每鼠最后一个含 stim 回合的 DateTime；excludePhases 中的 Phase 会话跳过
% （如 Recall：光迁移后的回忆测试，不算训练）。无 Phase 列的库忽略该参数。
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T)
	return;
end
T = T(ismember(T.Stimulus, stim), :);
if ~isempty(excludePhases) && ismember('Phase', T.Properties.VariableNames)
	T = T(~ismember(T.Phase, excludePhases), :);
end
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), max(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iEmptySessTable(DS)
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS','Mouse','DateTime'});
end

function T = iTrialTable(DS)
% 通用回合表；库带 Phase 列时一并取出（用于排除 Recall 等）。
vars = ["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"];
if any(strcmp('Phase', DS.DateTimes.Properties.VariableNames))
	vars(end+1) = "Phase";
end
T = DS.TableQuery(vars);
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
if ismember('Phase', T.Properties.VariableNames)
	T.Phase = string(T.Phase);
end
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
end

function GroupNtats = iNtsSuperMouseFromSessions(sess, nLines, stimNames)
% 会话表的 DS 列直接携带数据集对象；只保留 ZLayer=="MOp2/3" 的细胞。
% 每细胞取该会话全部目标回合（stimNames，按 TrialUID 排序），尽可能均分成 nLines 组
% （组间最多差 1 回合）后组内平均 → 每细胞 nLines 条轨迹。
cellTraces = {};
cellUIDList = zeros(0, 1, 'uint64');
mouseList = strings(0, 1);
for iS = 1:height(sess)
	DS = sess.DS(iS);
	ntsCell = DS.QueryNTS(struct('Stimulus', stimNames, 'Mouse', sess.Mouse(iS), 'DateTime', sess.DateTime(iS)), UniExp.Flags.ZScore, 1:24);
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
	error('AudioPCA:EmptySuperMouse', 'No MOp2/3 cells found after pooling.');
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

function PlotData = iComputePcaPlotData(GroupNtats, tEndSec)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2, true);
PcaLines = PcaTable.Score;
PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
idxCue = iFindPlotTimeIndex(nTime, 0);
idxWater = iFindPlotTimeIndex(nTime, tEndSec);
idxPlotTime = idxCue:idxWater;
PcaData = PcaDataAll(:, idxPlotTime, :);
PlotData = struct();
PlotData.PcaTable = PcaTable;
PlotData.PcaData = PcaData;
PlotData.nLines = size(PcaData, 3);
% 只画 cue 后轨迹（cue 0 → 给水时刻），span 也只统计该段
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
% 线内时间渐变：把 cue→末端折线按时间重采样成 nSeg 段，逐段平色，
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
