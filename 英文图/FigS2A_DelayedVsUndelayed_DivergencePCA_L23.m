% FigS2A（英文图）：2×4 代表性小鼠单 trial 轨迹 PCA 对照（仅 MOp2/3 细胞）：行 = 范式，列 = 声转光迁移时间线上的阶段。
% 每 tile 取一只代表性小鼠、每 trial 一条线（不做分组平均），PCA 在该鼠该会话全部 MOp2/3 细胞上独立计算。
% 轨迹样式参考文献（Makino et al., 2017, Neuron, Fig.4）：一条黑线（cue 对齐 → 给水/参照时刻），
% 线上打两个点：黑点 = Cue 时点（t=0），红点 = 给水时点（Undelayed +1 s / Delayed +1.5 s）；
% 只给声列（第 1 列）无给水，红点标同一参照时刻（与该行给水时刻一致，便于行内比较）。
% 代表鼠按逐鼠散度选取（散度口径同英文图1F/ALDelayed_DivVsHitRate_Scatter：z-score 后逐回合减 cue onset 值，
% 取该行给水时刻的 细胞×回合 矩阵 X，div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) ，MOp2/3 细胞）：
%   第 1、2、4 列共享同一只鼠（Undelayed 取 ALB、Delayed 取 ALDelayed）：在该范式候选鼠中，
%   选 🔊Naive 散度尽可能大、🔊💧Learned 散度尽可能小（差值最大）、且 💡💧Transfer 散度居中
%   （落在 [Learned, Naive] 区间内）者；
%   💡💧Naive 列在光侧 Naive 候选鼠（Undelayed=LAB+LAI，Delayed=LADelayed）中选散度最大者。
% 各 tile 数据源：
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
% 只取 MOp2/3 细胞（Cells.ZLayer=="MOp2/3"，MOp5 舍弃）。
% 归一化 ZScore（基线 1:24）与散度口径一致；每细胞取该会话全部目标回合（按 TrialUID 排序），
% 不做任何 trial 平均 → 每细胞 nTrial 条轨迹；Naive 列整 session 全部 trial 均入图（呈现学习分叉）。
% 绘图时段统一为 cue 0 → +3 s（黑线），红点仍标给水/参照时刻（Undelayed +1 s / Delayed +1.5 s）。
% 8 个 tile 的 PCA 独立计算（各代表鼠自身群体），各坐标轴不标注解释度；
% 出图后用 MATLAB.Graphics.UnifyAxesLims 的 Range 模式统一各 tile 的 X/Y 轴跨度
% （保留各自中心、统一对径），使独立 PCA 的图形尺度可比。
% 标注规范：tile 标题只写在首行（列名；🔊/💡/💧 = 声/光线索/给水，阶段词保留英文），
% 行名（Undelayed/Delayed）写在首列 ylabel，Y 轴位置统一在左。
%
% Outputs (SVG):
%   - English_FigS2A_DelayedVsUndelayed_DivergencePCA_L23.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

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

% ---- 代表鼠选取（逐鼠散度，MOp2/3 细胞；前两列共享同一只鼠） ----
% 第 1、2、4 列共享鼠名（Naive 用初始只给声会话，Learned 用最后声水会话，Transfer 用首个光水会话）
mouseAU = iSelectAudioRepresentative(sessAU, "AudioOnly", sessAWU, "AudioWater", sessTU, "LightWater", WinEnd(1,1));
mouseAD = iSelectAudioRepresentative(sessAD, "AudioPreTrainCueOnly", sessAWD, "AudioLearnWater", sessTD, ["LightLearnWater","LightLearnWaterAlways"], WinEnd(2,1));
SessAll{1,1} = sessAU(sessAU.Mouse == mouseAU, :);
SessAll{1,2} = sessAWU(sessAWU.Mouse == mouseAU, :);
SessAll{1,4} = sessTU(sessTU.Mouse == mouseAU, :);
SessAll{2,1} = sessAD(sessAD.Mouse == mouseAD, :);
SessAll{2,2} = sessAWD(sessAWD.Mouse == mouseAD, :);
SessAll{2,4} = sessTD(sessTD.Mouse == mouseAD, :);
% 💡💧Naive 列：散度最大者
SessAll{1,3} = iSelectByDivergence(sessNU, "LightWater", WinEnd(1,3), 'max');
SessAll{2,3} = iSelectByDivergence(sessND, ["LightLearnWater","LightLearnWaterAlways"], WinEnd(2,3), 'max');

G = cell(2, 4);
P = cell(2, 4);
for r = 1:2
	for c = 1:4
		if isempty(SessAll{r, c})
			error('DelayVsUndelayedPCA:NoSession', 'No %s session for %s.', colName(c), rowName(r));
		end
		G{r, c} = iNtsSingleMouseTrials(SessAll{r, c}, StimAll{r, c});
		P{r, c} = iComputePcaPlotData(G{r, c}, WinEnd(r, c));
		fprintf('%s / %s -> representative mouse %s (%d cells, %d trials)\n', ...
			rowName(r), colName(c), SessAll{r, c}.Mouse, height(G{r, c}), P{r, c}.nLines);
	end
end
%%

f = figure('Color', 'w', 'Name', 'English FigS2A delayed vs undelayed divergence PCA L23');
f.Units = 'centimeters';
f.Position(3:4) = [18, 8];
f.PaperUnits = 'centimeters';

tlo = tiledlayout(f, 2, 4, 'TileSpacing', 'tight', 'Padding', 'tight');
axAll = gobjects(2, 4);
for r = 1:2
	for c = 1:4
		ax = nexttile(tlo);
		iPlotTrialsAttachedOnAxes(ax, P{r, c});
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
% 不能统一PCA尺度：因为散度是方差/强度，而MATLAB的自动坐标范围恰好把强度归一化掉了，恰好能展示出真实散度

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS2A_DelayedVsUndelayed_DivergencePCA_L23.svg');

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

function mouse = iSelectAudioRepresentative(sessN, stimN, sessL, stimL, sessT, stimT, tWaterSec)
% 第 1、2、4 列共享代表鼠（返回鼠名）：🔊Naive 散度尽可能大、🔊💧Learned 尽可能小、💡💧Transfer 居中。
% 主目标 = (divNaive - divLearned) 最大；约束 = divTransfer 落在 [divLearned, divNaive] 区间内。
divN = iDivergencePerMouse(sessN, stimN, tWaterSec);
divL = iDivergencePerMouse(sessL, stimL, tWaterSec);
divT = iDivergencePerMouse(sessT, stimT, tWaterSec);
mice = intersect(intersect(divN.Mouse, divL.Mouse, 'stable'), divT.Mouse, 'stable');
divN = divN(ismember(divN.Mouse, mice), :);
divL = divL(ismember(divL.Mouse, mice), :);
divT = divT(ismember(divT.Mouse, mice), :);
[divN, divL] = iAlignMouseTables(divN, divL);
[divN, divT] = iAlignMouseTables(divN, divT);
mice = divN.Mouse;
dN = divN.Divergence; dL = divL.Divergence; dT = divT.Divergence;
inBetween = dT >= dL & dT <= dN;
score = dN - dL;
% Transfer 居中者直接比差值；不居中者罚一个很大的量，仅在没有居中鼠时才退化到全体比差值
penalty = 1e3;
scoreAdj = score - penalty * ~inBetween;
scoreAdj(~isfinite(scoreAdj)) = -inf;
if all(~isfinite(scoreAdj))
	error('FigS2APCA:NoAudioDiv', 'No valid divergence for representative selection.');
end
[~, iBest] = max(scoreAdj);
mouse = mice(iBest);
fprintf('  shared-mouse candidates (divNaive, divLearned, divTransfer, Naive-Learned, TransferBetween):\n');
for i = 1:numel(mice)
	fprintf('    %s  %.3f  %.3f  %.3f  %.3f  %d%s\n', mice(i), dN(i), dL(i), dT(i), dN(i)-dL(i), inBetween(i), string(repmat("  <== selected", i==iBest, 1)));
end
end

function sess = iSelectByDivergence(sessAll, stimNames, tWaterSec, mode)
% 光侧代表鼠：Naive 列 'max'（散度最大），Transfer 列 'min'（散度最小）。
divTbl = iDivergencePerMouse(sessAll, stimNames, tWaterSec);
divTbl = divTbl(isfinite(divTbl.Divergence), :);
if isempty(divTbl)
	error('FigS2APCA:NoLightDiv', 'No valid light divergence for representative selection.');
end
switch mode
	case 'max'
		[~, iBest] = max(divTbl.Divergence);
	case 'min'
		[~, iBest] = min(divTbl.Divergence);
	otherwise
		error('FigS2APCA:BadMode', 'Unknown mode %s.', mode);
end
sess = sessAll(sessAll.Mouse == divTbl.Mouse(iBest), :);
fprintf('  light-stage candidates (%s):\n', mode);
for i = 1:height(divTbl)
	fprintf('    %s  div=%.3f%s\n', divTbl.Mouse(i), divTbl.Divergence(i), string(repmat("  <== selected", i==iBest, 1)));
end
end

function [a, b] = iAlignMouseTables(a, b)
% 按 Mouse 对齐两个散度表（同序）
[tf, loc] = ismember(a.Mouse, b.Mouse);
a = a(tf, :);
b = b(loc(tf), :);
end

function divTbl = iDivergencePerMouse(sessAll, stimNames, tWaterSec)
% 逐鼠散度（口径同 Fig1F/ALDelayed_DivVsHitRate_Scatter，限 MOp2/3 细胞）：
% z-score 后逐回合减 cue onset 值，取 tWaterSec 时刻的 细胞×回合 矩阵 X，
% div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )。
divTbl = table(strings(0,1), zeros(0,1), 'VariableNames', {'Mouse','Divergence'});
for iS = 1:height(sessAll)
	sess = sessAll(iS, :);
	div = iSessionDivergence(sess, stimNames, tWaterSec);
	divTbl = [divTbl; table(sess.Mouse, div, 'VariableNames', {'Mouse','Divergence'})]; %#ok<AGROW>
end
end

function div = iSessionDivergence(sess, stimNames, tWaterSec)
div = NaN;
DS = sess.DS(1);
ntsCell = DS.QueryNTS(struct('Stimulus', stimNames, 'Mouse', sess.Mouse(1), 'DateTime', sess.DateTime(1)), UniExp.Flags.ZScore, 1:24);
if iscell(ntsCell)
	nts = ntsCell{1};
else
	nts = ntsCell;
end
if isempty(nts)
	return;
end
% 只保留 MOp2/3 细胞
cellTbl = DS.Cells;
cellTbl.CellUID = uint64(cellTbl.CellUID);
cellTbl.ZLayer = string(cellTbl.ZLayer);
cellTbl.Mouse = string(cellTbl.Mouse);
keepUID = cellTbl.CellUID(cellTbl.Mouse == sess.Mouse(1) & cellTbl.ZLayer == "MOp2/3");
nts = nts(ismember(uint64(nts.CellUID), keepUID), :);
if isempty(nts)
	return;
end
nTime = size(nts.TrialSignal, 2);
idx0 = iFindPlotTimeIndex(nTime, 0);
idxW = iFindPlotTimeIndex(nTime, tWaterSec);
trialUIDs = unique(uint64(nts.TrialUID), 'stable');
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = {};
for iC = 1:numel(allCells)
	rows = uint64(nts.CellUID) == allCells(iC);
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
	traceCell{end+1} = ordered; %#ok<AGROW>
end
if numel(traceCell) < 3 || numel(trialUIDs) < 2
	return;
end
nTrial = numel(trialUIDs);
ctt = nan(numel(traceCell), nTrial, nTime);
for iC = 1:numel(traceCell)
	ctt(iC, :, :) = traceCell{iC};
end
ctt = ctt - ctt(:, :, idx0);
X = ctt(:, :, idxW);
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
end
end

function GroupNtats = iNtsSingleMouseTrials(sess, stimNames)
% 单代表鼠：该会话全部 MOp2/3 细胞 × 全部目标回合（按 TrialUID 排序），不做任何平均。
DS = sess.DS(1);
ntsCell = DS.QueryNTS(struct('Stimulus', stimNames, 'Mouse', sess.Mouse(1), 'DateTime', sess.DateTime(1)), UniExp.Flags.ZScore, 1:24);
if iscell(ntsCell)
	nts = ntsCell{1};
else
	nts = ntsCell;
end
if isempty(nts)
	error('FigS2APCA:EmptyMouse', 'No trials for representative mouse %s.', sess.Mouse(1));
end
cellTbl = DS.Cells;
cellTbl.CellUID = uint64(cellTbl.CellUID);
cellTbl.ZLayer = string(cellTbl.ZLayer);
cellTbl.Mouse = string(cellTbl.Mouse);
mCell = cellTbl(cellTbl.Mouse == sess.Mouse(1) & cellTbl.ZLayer == "MOp2/3", :);
cellUIDs = unique(uint64(nts.CellUID));
cellTraces = {};
cellUIDList = zeros(0, 1, 'uint64');
for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	if ~ismember(cid, mCell.CellUID)
		continue;
	end
	rowsC = (uint64(nts.CellUID) == cid);
	uid = uint64(nts.TrialUID(rowsC));
	sig = double(nts.TrialSignal(rowsC, :));
	[~, order] = sort(uid);
	sig = sig(order, :);
	cellTraces{end+1, 1} = sig; %#ok<AGROW>
	cellUIDList(end+1, 1) = cid; %#ok<AGROW>
end
if isempty(cellTraces)
	error('FigS2APCA:NoL23Cell', 'No MOp2/3 cells for representative mouse %s.', sess.Mouse(1));
end
nCells = numel(cellTraces);
nTrial = size(cellTraces{1}, 1);
nTime = size(cellTraces{1}, 2);
CellTrialTimes = nan(nCells, nTrial, nTime);
for iC = 1:nCells
	CellTrialTimes(iC, :, :) = cellTraces{iC};
end
ntatsData = permute(CellTrialTimes, [1, 3, 2]);
ntats = MATLAB.DataTypes.NDTable(ntatsData);
GroupNtats = table(ntats, cellUIDList, repmat(sess.Mouse(1), nCells, 1), 'VariableNames', ["NTATS", "CellUID", "Mouse"]);
end

function PlotData = iComputePcaPlotData(GroupNtats, tEndSec)
PcaTable = UniExp.LinearPca(GroupNtats.NTATS, 2, true);
PcaLines = PcaTable.Score;
PcaDataAll = PcaLines.Data;
nTime = size(PcaDataAll, 2);
idxCue = iFindPlotTimeIndex(nTime, 0);
idxEnd = iFindPlotTimeIndex(nTime, 3);   % 作图时段统一延长到 cue +3 s
idxWater = iFindPlotTimeIndex(nTime, tEndSec);
idxPlotTime = idxCue:idxEnd;
PcaData = PcaDataAll(:, idxPlotTime, :);
PlotData = struct();
PlotData.PcaTable = PcaTable;
PlotData.PcaData = PcaData;
PlotData.nLines = size(PcaData, 3);
% 文献样式标记：Cue 时点 = 第 1 个采样点（黑）；给水/参照时点（红）= 该范式给水时刻，不再是轨迹终点
PlotData.idxCue = 1;
PlotData.idxWater = idxWater - idxCue + 1;
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

function iPlotTrialsAttachedOnAxes(ax, PlotData)
% 文献样式（Makino 2017 Fig.4）：每 trial 一条黑线 + Cue 黑点 + 给水/参照红点
ax.FontSize = 12;
ax.LineWidth = 1;
box(ax, 'off');
grid(ax, 'off');
hold(ax, 'on');
PcaData = PlotData.PcaData;
% 所有 trial 的黑线一次 plot（每列一条）；豁免标准样式线宽调整，保持 LineWidth=0.5
hLines = plot(ax, squeeze(PcaData(1, :, :)), squeeze(PcaData(2, :, :)), '-', ...
	'Color', [0 0 0], 'LineWidth', 0.5, 'HandleVisibility', 'off');
for iL = 1:numel(hLines)
	setappdata(hLines(iL), 'TransferLearningPreserveLineWidth', true);
end
% Cue 时点（黑）与给水/参照时点（红）：每 trial 各一点
plot(ax, squeeze(PcaData(1, PlotData.idxCue, :)), squeeze(PcaData(2, PlotData.idxCue, :)), 'o', ...
	'MarkerSize', 3, 'MarkerEdgeColor', 'none', 'MarkerFaceColor', [0 0 0], 'HandleVisibility', 'off');
plot(ax, squeeze(PcaData(1, PlotData.idxWater, :)), squeeze(PcaData(2, PlotData.idxWater, :)), 'o', ...
	'MarkerSize', 3, 'MarkerEdgeColor', 'none', 'MarkerFaceColor', [1 0 0], 'HandleVisibility', 'off');
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
