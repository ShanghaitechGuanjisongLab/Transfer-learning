% FigS2A（英文图）：2×4 群体轨迹 PCA 对照（仅 MOp2/3 细胞）：行 = 范式，列 = 声转光迁移时间线上的阶段。
% 整合现有脚本的 tile（英文图/AudioOnlyVsLastAudioWater_PCA_L23.m 的声侧 2 阶段 + 英文图1D 的
% Naive/Transfer + ALDelayed_DivergencePCA_L23 的 Transfer(delayed)），并含新增 Naive(delayed) tile：
%   列 1 🔊 Naive：初始只给声。Undelayed = AudioLightBaseline 的 AudioOnly 初始校准会话
%                              （每鼠仅一个）；Delayed = ALDelayed 的 AudioPreTrainCueOnly 首个会话
%                              （同会话 AudioPreTrainWaterOnly 只给水不给声，不取）；
%   列 2 🔊💧 Learned：转光水之前的最后一个声水（声水学会）。Undelayed = AudioLightBaseline
%                              最后一个非 Recall 的 AudioWater 会话（= Learned 会话，Recall 是
%                              光迁移后的回忆测试不算训练）；Delayed = ALDelayed 最后一个含
%                              AudioLearnWater 的会话（只取 AudioLearnWater 回合，AudioLearnWaterAlways
%                              总是给水不参与）；
%   列 3 💡💧 Naive：光水学习初始。Undelayed = 英文图1D 口径（LightAudioBaseline+LAInterspersed 首个纯 LW
%                              Naive 会话，LAI 中 Naive 期出现过 AudioWater 的鼠整只排除）；
%                              Delayed = TransferLearning.LADelayed（有延迟光声钙成像，光水转声水，延迟任务）
%                              每鼠首个含 LightLearnWater 的会话（本库无 Phase 列，光水学习=初始 Naive 阶段），
%                              该会话全部光水回合（LightLearnWater + LightLearnWaterAlways）；
%   列 4 💡💧 Transfer：转光水后的首个光水（Transfer 首块）。Undelayed = AudioLightBaseline 首个 Transfer
%                              LW 会话；Delayed = TransferLearning.ALDelayed（有延迟不舔不给水钙成像，
%                              声水转光水）每鼠首个含 LightLearnWater 的 DateTime，
%                              同英文图/ALDelayed_DivergencePCA_L23.m。
% Undelayed 声侧两列只保留两个阶段都具备的鼠（yqn1130 无 AudioOnly 校准会话，整只排除，
% 同英文图/AudioOnlyVsLastAudioWater_PCA_L23.m）；光侧两列沿用英文图1D 口径各自选鼠。
% 只取 MOp2/3 细胞（Cells.ZLayer=="MOp2/3"，MOp5 舍弃）。
% super-mouse 口径同 Fig1D：每细胞取该会话全部光水回合（按 TrialUID 排序），尽可能均分成 nLines 组
% （组间最多差 1 回合）后组内平均 → 每细胞 nLines 条轨迹；归一化 ZScore（基线 1:24）匹配散度口径。
% 绘图时段按各范式给水时刻：Undelayed 行 cue 0 → +1 s，Delayed 行 cue 0 → +1.5 s；
% 只给声的列无给水，为行内可比取同一时段。轨迹浅色端=cue 起点、深色端=时段末端，
% 着色为线内时间渐变（单次 patch 逐顶点着色，学习 UniExp.SegmentFadePlot/ColorfulMarkerPlot）。
% 8 个 tile 的 PCA 独立计算（各自 super-mouse 群体），各坐标轴不标注解释度；
% 出图后用 MATLAB.Graphics.UnifyAxesLims 的 Range 模式统一各 tile 的 X/Y 轴跨度
% （保留各自中心、统一对径），使独立 PCA 的图形尺度可比；
% 展示的是 cue 后轨迹的分叉形态（Naive 扇形分叉=高散度，Transfer 平行=低散度）。
% 着色按列沿用现有脚本配色：🔊 = NaiveColor（紫），🔊💧 = ColorB（绿），
% 💡💧 Naive = NaiveColor（紫），💡💧 Transfer = TransferColor（橙）。
% 标注规范：tile 标题只写在首行（列名；🔊/💡/💧 = 声/光线索/给水，阶段词保留英文），
% 行名（Undelayed/Delayed）写在首列 ylabel，Y 轴位置统一在左。
%
% Outputs (SVG):
%   - English_FigS2A_DelayedVsUndelayed_DivergencePCA_L23.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

% 可调参数：把每细胞的全部回合尽可能均分成多少条轨迹
nLines = 10;
% 可调参数：线内渐变的分段数（轨迹重采样顶点数，patch 逐顶点着色）
nGradSeg = 40;

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

% ---- Undelayed（英文图1D 口径）----
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
badNaiveLai = iMiceWithStimulusInPhase(LAI, "AudioWater", "Naive");
sessNU = [iFirstPureLWNaiveSessions(LAB, strings(0, 1)); iFirstPureLWNaiveSessions(LAI, badNaiveLai)];
sessTU = iFirstTransferLWSessions(ALB);
sessAU = iFirstStimSession(ALB, "AudioOnly");
sessAWU = iLastStimSession(ALB, "AudioWater", "Recall");
miceU = intersect(sessAU.Mouse, sessAWU.Mouse);
sessAU = sessAU(ismember(sessAU.Mouse, miceU), :);
sessAWU = sessAWU(ismember(sessAWU.Mouse, miceU), :);
% ---- Delayed ----
LAD = TransferLearning.LADelayed();
ALD = TransferLearning.ALDelayed();
sessND = iFirstLightLearnSessions(LAD);
sessTD = iFirstLightLearnSessions(ALD);
sessAD = iFirstStimSession(ALD, "AudioPreTrainCueOnly");
sessAWD = iLastStimSession(ALD, "AudioLearnWater", "Recall");

SessAll = {sessAU, sessAWU, sessNU, sessTU; sessAD, sessAWD, sessND, sessTD};
StimAll = {"AudioOnly", "AudioWater", "LightWater", "LightWater"; ...
	"AudioPreTrainCueOnly", "AudioLearnWater", ["LightLearnWater","LightLearnWaterAlways"], ["LightLearnWater","LightLearnWaterAlways"]};
WinEnd = [1, 1, 1, 1; 1.5, 1.5, 1.5, 1.5];   % 各行按范式给水时刻（延迟 +1.5 s，无延迟 +1 s）
rowName = ["Undelayed", "Delayed"];
% 列标题用 emoji 标刺激（🔊=声线索，💡=光线索，💧=给水），阶段词用 Naive/Learned/Transfer
colName = ["🔊 Naive", "🔊💧 Learned", "💡💧 Naive", "💡💧 Transfer"];

G = cell(2, 4);
P = cell(2, 4);
for r = 1:2
	for c = 1:4
		if isempty(SessAll{r, c})
			error('DelayVsUndelayedPCA:NoSession', 'No %s session for %s.', colName(c), rowName(r));
		end
		G{r, c} = iNtsSuperMouseFromSessions(SessAll{r, c}, nLines, StimAll{r, c});
		P{r, c} = iComputePcaPlotData(G{r, c}, WinEnd(r, c));
	end
end
%%

f = figure('Color', 'w', 'Name', 'English FigS2A delayed vs undelayed divergence PCA L23');
f.Units = 'centimeters';
f.Position(3:4) = [18, 8];
f.PaperUnits = 'centimeters';

colColor = [TransferLearning.NaiveColor; TransferLearning.ColorB; TransferLearning.NaiveColor; TransferLearning.TransferColor];
tlo = tiledlayout(f, 2, 4, 'TileSpacing', 'tight', 'Padding', 'tight');
axAll = gobjects(2, 4);
for r = 1:2
	for c = 1:4
		ax = nexttile(tlo);
		iPlotTrialsAttachedOnAxes(ax, P{r, c}, colColor(c, :), nGradSeg);
		% 规范：tile 标题只标在首行（列名），行名（范式）写在首列 ylabel，Y 轴统一在左
		if r == 1
			title(ax, colName(c));
		end
		if c == 1
			ylabel(ax, rowName(r));
		end
		iApplySingleLimits(ax, P{r, c});
		axAll(r, c) = ax;
	end
end
xlabel(tlo, 'PC1');
ylabel(tlo, 'PC2');
% 统一各 tile 的 X/Y 轴跨度（Range 模式：保留各自中心、统一对径），使独立 PCA 的尺度可比
MATLAB.Graphics.UnifyAxesLims(axAll, MATLAB.Flags.Range, @xlim, @ylim);

TransferLearning.ApplyStandardExportStyle(f, 1);
svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS2A_DelayedVsUndelayed_DivergencePCA_L23.svg');

%% ========== local functions（口径同英文图1D，延迟库会话定义同 ALDelayed_DivergencePCA_L23） ==========
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

function sess = iFirstLightLearnSessions(DS)
% 延迟库（ALDelayed/LADelayed）无 Phase 列：每鼠取首个含 LightLearnWater 回合的 DateTime。
% ALDelayed 中等价 Transfer 首块；LADelayed（光水转声水）中光水学习=初始 Naive 阶段。
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
	error('DelayVsUndelayedPCA:EmptySuperMouse', 'No MOp2/3 cells found after pooling.');
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
iGradientLines(ax, PcaData, groupColor, nGradSeg);
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

function iGradientLines(ax, PcaData, baseColor, nSeg)
% 线内时间渐变：cue→末端折线按时间重采样成 nSeg 段，cue 端接近白、末端为基色。
% 学习 UniExp.SegmentFadePlot / UniExp.ColorfulMarkerPlot 的 patch 画法：
% 矩阵 X/Y 每列一条折线 + 末行 NaN 断开 patch 闭合边 + 逐顶点色 + EdgeColor='flat'，
% 全部轨迹一次 patch 调用画完（不再逐段调用 line，每条 40 次 → 全部 1 次）。
nLines = size(PcaData, 3);
nTime = size(PcaData, 2);
tt = linspace(1, nTime, nSeg + 1);
w = linspace(0, 1, nSeg + 1)';
cv = 1 - w * (1 - baseColor(:)');   % (nSeg+1)×3 逐顶点颜色：cue 端近白 → 末端基色
X = nan(nSeg + 2, nLines);
Y = nan(nSeg + 2, nLines);
for iLine = 1:nLines
	xy = squeeze(PcaData(:, :, iLine));
	X(1:nSeg+1, iLine) = interp1(1:nTime, xy(1, :), tt);
	Y(1:nSeg+1, iLine) = interp1(1:nTime, xy(2, :), tt);
end
C = repmat(reshape(cv, [nSeg+1, 1, 3]), 1, nLines, 1);
C(end+1, :, :) = repmat(reshape(cv(end, :), [1, 1, 3]), 1, nLines);
patch(ax, X, Y, C, 'EdgeColor', 'flat', 'FaceColor', 'none', ...
	'LineWidth', 2, 'HandleVisibility', 'off');
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
