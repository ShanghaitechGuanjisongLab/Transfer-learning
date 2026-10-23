%% AnalyzeLearnedPredCellReuse.m
% 问题：声水（AudioWater）Learned 阶段的"舔水预测细胞"（early-onset），在迁移到光水
% （LightWater）Transfer 阶段是否仍然满足 early-onset 舔水预测判据（= 功能复用）？
%
% 数据：TransferLearning.AudioLightBaseline()
%   Learned AudioWater 与 Transfer LightWater 每鼠各 1 个 block，CellUID 跨阶段可配对。
%
% 判据（两阶段同一管线，每 block 独立判定）：
%   沿用 英文图/EarlyOnsetCells_LickLocked_Analysis.m 的 onset 口径：
%   - CD2 原生信号检测孤立 bout（阈 = 每 trial 稳健基线 + 35；其前 isoWindow=1 s 无舔水）
%   - 对孤立 bout 做 lick-locked PSTH（cue 前基线 ZScore，跨事件平均）
%   - onset = PSTH 首次持续 >=200 ms 超过 (基线 mu + 1 SD) 的时刻（200 Hz 上采样判定），
%     搜索窗 [-0.2, 1.5] s；onset < 0 → early（舔水前活动上升 = 预测性），>= 0 → late
%
%   三档 early 判据（"不能跟随舔水一直活跃"= 衰退要求，逐级收紧）：
%     perm = 仅要求 onset<0（原口径）
%     A    = onset<0 且 PSTH 在 onset 后、舔水结束前回落至 thr(baseMean+1SD) 以下并
%            持续 >=200 ms（排除"早发并整波维持"的细胞）
%     B    = 同 A，但回落阈为基线均值 baseMean（更强的瞬时性要求）
%   未通过衰退要求的 early 细胞单列为 sust（sustained）组，不计入 early，便于比较两者复用率。
%   舔水结束时刻 lickEnd = min(该 block 各事件 bout 平均时长, PSTH 窗末 +2.0 s)；
%   实测 Learned bout 中位 2.89 s、Transfer 2.01 s，均超过 PSTH 窗末，故等价于在窗内回落。
%   说明：onset 锁定在 bout 而非 cue，Transfer 阶段小鼠舔水时刻普遍晚于 Learned，
%   early 判据自动随 bout 时刻平移，"依然 early"即在光水任务中依然预测舔水发生。
%   ALDelayed 版 EarlyOnsetCells_LickPrediction.m 依赖的 within-trial 无舔水 surrogate
%   窗在 AudioLightBaseline 不可行（cue 后 ~0.3 s 即长 bout 舔水，trial 内无静息窗）。
%   注意：多数 block 原生 fs=7.95 Hz（125 ms/帧），onset 分辨率为帧级，判定属保守口径。
%
% 主检验（功能复用，逐鼠）：
%   rE2E = P(Transfer 同档 early | Learned 同档 early & 两阶段细胞都在)
%   对照：
%     rSust = P(Transfer 同档 early | Learned sust)
%     rLate = P(Transfer 同档 early | Learned late)   （运动伴随细胞对照）
%     rNone = P(Transfer 同档 early | Learned 无 onset)（背景基线）
%   推断：鼠水平 Wilcoxon signed-rank（三档判据各自计算，并附合并转移比例参考）。
%
% 次级参考（反应性复用，非本次主定义）：
%   Fig4D 口径 active = 声水 [0,1]s max z > 基线 mu+3SD 细胞在光水中的 active 率。
%
% Execution:
%   MATLAB Editor 中 Run/F5（保持为脚本）。

%% ---- 0. 参数与工程加载 ----
thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

P = struct();
P.minNSm    = 40;             % 每 trial 原生样本数下限
P.isoWindow = 1.0;            % 孤立 bout：其前该窗内无舔水（s）
P.lickMargin= 35;             % CD2 舔水阈 = 每 trial 稳健基线 + 此值
P.tPwin     = [-1.5, 2.0];    % lick 锁定 PSTH 时间窗
P.baseline  = [-1.0, -0.5];   % PSTH 基线窗（与分析脚本一致）
P.detWin    = [-0.2, 1.5];    % onset 搜索窗（bout 前 0.2 s → bout 结束）
P.sustain   = 0.2;            % onset 持续判据（200 ms）
P.boutGap   = 2;              % bout 终止判据：连续 <=此帧数无舔水视为 bout 结束
P.dtFine    = 0.005;          % onset 判定的上采样网格（200 Hz）
P.minEvents = 8;              % block 最少孤立 bout 数
P.minTrials = 10;             % block 最少可用 trial 数
P.kSigma    = 3;              % 次级参考 active 判据的基线 SD 倍数
P.nSim      = 20000;          % 分层 Monte-Carlo（以同鼠 none 背景率为零假设）抽样次数
P.minLickEnd = 1.0;           % 稳健性复查：Transfer lickEnd 低于此值的鼠，衰退窗过短（A/B 判据被人为压制）
P.seed      = 42;
rng(P.seed);

warning('off', 'UniExp:Exception:Block_must_warn');
DS = TransferLearning.AudioLightBaseline();
Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);
sr = Tr.SampleRange;
Sd = double(sr.Start); Ed = double(sr.End); Td = double(sr.Tag);
bs = DS.BlockSignals;

T = DS.TableQuery(["Mouse","DateTime","BlockUID","Stimulus","Phase"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus); T.Phase = string(T.Phase);
learnedBlk = unique(T(T.Phase=="Learned" & T.Stimulus=="AudioWater", ...
	["Mouse","DateTime","BlockUID"]), 'rows', 'stable');
transferBlk = unique(T(T.Phase=="Transfer" & T.Stimulus=="LightWater", ...
	["Mouse","DateTime","BlockUID"]), 'rows', 'stable');

DTall = DS.DateTimes;
SIall = seconds(DTall.SeriesInterval);
DTdt = DTall.DateTime; if ~isempty(DTdt.TimeZone), DTdt.TimeZone = ''; end
MallSess = string(DTall.Mouse);

fprintf('=== 功能复用：声水 Learned early-onset 细胞 → 光水.Transfer 是否依然 early（AudioLightBaseline）===\n');

%% ---- 1. 逐鼠：两阶段 block 各自跑 onset 管线 ----
Stim_L = "AudioWater"; Stim_T = "LightWater";
Ons = struct('Mouse', {}, 'CellUID', {}, 'PermL', {}, 'PermT', {}, ...
	'AL', {}, 'AT', {}, 'BL', {}, 'BT', {}, ...
	'OnsetL', {}, 'OnsetT', {}, 'NEvL', {}, 'NEvT', {}, 'LickEndL', {}, 'LickEndT', {});
BlockD = {};
for bi = 1:height(learnedBlk)
	mouse = learnedBlk.Mouse(bi);
	buL = learnedBlk.BlockUID(bi);
	rT = find(transferBlk.Mouse == mouse, 1);
	if isempty(rT)
		fprintf('%s -> 跳过（无配对 Transfer block）\n', mouse);
		continue;
	end
	buT = transferBlk.BlockUID(rT);
	DL = iExtractBlock(learnedBlk, bi, Stim_L, Tr, Sd, Ed, Td, bs, SIall, DTdt, MallSess, P);
	DTx = iExtractBlock(transferBlk, rT, Stim_T, Tr, Sd, Ed, Td, bs, SIall, DTdt, MallSess, P);
	if isempty(DL) || isempty(DTx)
		fprintf('blk%-4d/%-4d %s -> 跳过（trial/事件数不满足）\n', buL, buT, mouse);
		continue;
	end
	% 按 CellUID 交集对齐两阶段（个别鼠两 block 细胞数略有出入）
	[commonUid, ia, ib] = intersect(uint64(DL.cellUID), uint64(DTx.cellUID), 'stable');
	if numel(commonUid) < 50
		fprintf('blk%-4d/%-4d %s -> 跳过（两阶段共有细胞过少 %d）\n', buL, buT, mouse, numel(commonUid));
		continue;
	end
	if numel(commonUid) < DL.nC || numel(commonUid) < DTx.nC
		fprintf('%s: 细胞对齐取交集 %d（L %d, T %d）\n', mouse, numel(commonUid), DL.nC, DTx.nC);
	end
	DL.cellUID = DL.cellUID(ia); DL.Vev = DL.Vev(ia, :, :); DL.nC = numel(ia);
	DTx.cellUID = DTx.cellUID(ib); DTx.Vev = DTx.Vev(ib, :, :); DTx.nC = numel(ib);
	LabL = iLabelSets(DL, P);
	LabT = iLabelSets(DTx, P);
	for c = 1:numel(DL.cellUID)
		Ons(end+1) = struct('Mouse', mouse, 'CellUID', DL.cellUID(c), ...
			'PermL', LabL.perm(c), 'PermT', LabT.perm(c), ...
			'AL', LabL.A(c), 'AT', LabT.A(c), ...
			'BL', LabL.B(c), 'BT', LabT.B(c), ...
			'OnsetL', LabL.onset(c), 'OnsetT', LabT.onset(c), ...
			'NEvL', DL.nEv, 'NEvT', DTx.nEv, ...
			'LickEndL', DL.lickEndRel, 'LickEndT', DTx.lickEndRel); %#ok<AGROW,SAGROW>
	end
	BlockD{end+1} = DL;  %#ok<AGROW>
	BlockD{end+1} = DTx; %#ok<AGROW>
	fprintf('%s L:blk%-4d(nEv=%2d lickEnd=%.2fs) T:blk%-4d(nEv=%2d lickEnd=%.2fs) nC=%4d\n', ...
		mouse, buL, DL.nEv, DL.lickEndRel, buT, DTx.nEv, DTx.lickEndRel, numel(DL.cellUID));
	fprintf('   L: perm early %3d | A early %3d sust %3d late %3d | B early %3d sust %3d\n', ...
		sum(LabL.perm=="early"), sum(LabL.A=="early"), sum(LabL.A=="sust"), sum(LabL.A=="late"), ...
		sum(LabL.B=="early"), sum(LabL.B=="sust"));
	fprintf('   T: perm early %3d | A early %3d sust %3d late %3d | B early %3d sust %3d\n', ...
		sum(LabT.perm=="early"), sum(LabT.A=="early"), sum(LabT.A=="sust"), sum(LabT.A=="late"), ...
		sum(LabT.B=="early"), sum(LabT.B=="sust"));
end
OnsT = struct2table(Ons);
if isempty(OnsT) || ~any(OnsT.PermL == "early")
	error('PredReuse:None', '没有任何鼠检出 Learned early-onset 细胞。');
end

%% ---- 2. 主检验：功能复用（Learned early → Transfer 依然 early），三档判据并列 ----
critCols = {'PermL','PermT'; 'AL','AT'; 'BL','BT'};
critNames = ["perm（无衰退要求）", "A（舔水结束前回落至阈下）", "B（回落至基线均值以下）"];
critLabel = ["perm early", "A early（decay<baseMu+1SD）", "B early（decay<baseMu）"];
allRows = cell(numel(critNames), 1);
Summ = table();
for ic = 1:numel(critNames)
	fprintf('\n======== 判据 %s ========\n', critNames(ic));
	[allRows{ic}, S] = iCritStats(OnsT, critCols{ic,1}, critCols{ic,2}, critLabel(ic), P);
	Summ = [Summ; table(S.Label, S.NEarlyCells, S.FracEarly, S.NMouse, ...
		S.PooledE2E, S.PooledSust, S.PooledLate, S.PooledNone, ...
		S.PVsSust, S.PVsLate, S.PVsNone, S.PSim, S.PFisher, ...
		'VariableNames', {'Label','NEarly','FracEarly','NMouse', ...
		'PoolE2E','PoolSust','PoolLate','PoolNone', ...
		'PVsSust','PVsLate','PVsNone','PSim','PFisher'})]; %#ok<AGROW>
end

fprintf('\n======== 三档判据汇总（衰退要求逐级收紧）========\n');
fprintf('%-28s %6s %7s %4s | %6s %6s %6s %6s | %8s %8s %8s %10s\n', ...
	'判据', 'nEarly', '占全体', '鼠数', 'E→E', 'sust→E', 'late→E', 'none→E', ...
	'p(sust)', 'p(late)', 'p(none)', 'p(分层MC)');
for i = 1:height(Summ)
	fprintf('%-28s %6d %6.2f%% %4d | %6.3f %6.3f %6.3f %6.3f | %8.4g %8.4g %8.4g %10.4g\n', ...
		Summ.Label(i), Summ.NEarly(i), 100*Summ.FracEarly(i), Summ.NMouse(i), ...
		Summ.PoolE2E(i), Summ.PoolSust(i), Summ.PoolLate(i), Summ.PoolNone(i), ...
		Summ.PVsSust(i), Summ.PVsLate(i), Summ.PVsNone(i), Summ.PSim(i));
end

%% ---- 2b. 稳健性复查：剔除 Transfer 衰退窗过短的鼠 ----
% 衰退窗 = [onset, lickEnd]，lickEnd = min(bout 均长, PSTH 窗末)；过短时 A/B 判据无法通过，
% 属判据可观测性限制而非生物学差异，故剔除后复查结论是否改变。
miceAll = unique(OnsT.Mouse, 'stable');
leTByMouse = arrayfun(@(m) median(OnsT.LickEndT(OnsT.Mouse == m)), miceAll);
shortMice = miceAll(leTByMouse < P.minLickEnd);
SummEx = table();
if isempty(shortMice)
	fprintf('\n---- 稳健性：无 Transfer lickEnd < %.1f s 的鼠，无需复查 ----\n', P.minLickEnd);
else
	fprintf('\n---- 稳健性：剔除 Transfer lickEnd < %.1f s 的鼠（%s，衰退窗过短）----\n', ...
		P.minLickEnd, strjoin(shortMice', ' '));
	for ic = 1:numel(critNames)
		[~, SE] = iCritStats(OnsT, critCols{ic,1}, critCols{ic,2}, ...
			critLabel(ic) + " excl", P, shortMice);
		SummEx = [SummEx; table(SE.Label, SE.NEarlyCells, SE.NMouse, SE.PooledE2E, ...
			SE.PooledSust, SE.PooledLate, SE.PooledNone, SE.PVsSust, SE.PVsLate, ...
			SE.PVsNone, SE.PSim, 'VariableNames', {'Label','NEarly','NMouse','PoolE2E', ...
			'PoolSust','PoolLate','PoolNone','PVsSust','PVsLate','PVsNone','PSim'})]; %#ok<AGROW>
	end
	fprintf('\n%-30s %6s %4s | %6s %6s %6s %6s | %8s %8s %8s %10s\n', ...
		'判据（剔除后）', 'nEarly', '鼠数', 'E→E', 'sust→E', 'late→E', 'none→E', ...
		'p(sust)', 'p(late)', 'p(none)', 'p(分层MC)');
	for i = 1:height(SummEx)
		fprintf('%-30s %6d %4d | %6.3f %6.3f %6.3f %6.3f | %8.4g %8.4g %8.4g %10.4g\n', ...
			SummEx.Label(i), SummEx.NEarly(i), SummEx.NMouse(i), SummEx.PoolE2E(i), ...
			SummEx.PoolSust(i), SummEx.PoolLate(i), SummEx.PoolNone(i), ...
			SummEx.PVsSust(i), SummEx.PVsLate(i), SummEx.PVsNone(i), SummEx.PSim(i));
	end
end

%% ---- 3. 次级参考：反应性复用（Fig4D 口径 active）----
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask01 = (xsSec >= 0) & (xsSec <= 1);

GLearn = DS.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater'), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTran = DS.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XL = iNtatsData(GLearn.NTATS);
XT = iNtatsData(GTran.NTATS);

learnedWinMx = max(XL(:, winMask01), [], 2, 'omitnan');
lBaseMu = mean(XL(:, baseMask), 2, 'omitnan');
lBaseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
learnedActive = learnedWinMx > (lBaseMu + P.kSigma .* lBaseSd);
tBaseMu = mean(XT(:, baseMask), 2, 'omitnan');
tBaseSd = std(XT(:, baseMask), 0, 2, 'omitnan');
tranWinMx = max(XT(:, winMask01), [], 2, 'omitnan');
tranActive = tranWinMx > (tBaseMu + P.kSigma .* tBaseSd);

% early 细胞（OnsT）与 NTATS 行按 CellUID 对齐（保序：ismember 查 Mouse，不做 join）
eAllPerm = OnsT.PermL == "early";
eAllA = OnsT.AL == "early";
C = DS.Cells;
cUid = uint64(C.CellUID); cMouse = string(C.Mouse);
[okLm, locL] = ismember(uint64(GLearn.CellUID), cUid);
[okTm, locT] = ismember(uint64(GTran.CellUID), cUid);
learnUid = [cMouse(locL), string(uint64(GLearn.CellUID))];
tranUid = [cMouse(locT), string(uint64(GTran.CellUID))];
for ic = 1:2
	if ic == 1
		mE = eAllPerm; eName = "perm early";
	else
		mE = eAllA; eName = "A early";
	end
	uidE = [OnsT.Mouse(mE), string(OnsT.CellUID(mE))];
	predInL = okLm & ismember(learnUid, uidE, 'rows');
	predInT = okTm & ismember(tranUid, uidE, 'rows');
	fprintf('\n---- 次级参考：%s 细胞的反应性复用（cue 后 [0,1]s active, Fig4D 口径）----\n', eName);
	fprintf('Learned %s 细胞中光水 active 比例: %.3f (%d/%d) | 全体细胞: %.3f\n', ...
		eName, mean(tranActive(predInT)), sum(tranActive(predInT)), sum(predInT), mean(tranActive));
	fprintf('Learned %s 细胞中声水 active 比例: %.3f (%d/%d)\n', ...
		eName, mean(learnedActive(predInL)), sum(learnedActive(predInL)), sum(predInL));
end

%% ---- 4. 保存 ----
outDir = fullfile(thisDir, 'Temp');
if ~exist(outDir, 'dir'), mkdir(outDir); end
matPath = fullfile(outDir, 'LearnedPredCellReuse_Results.mat');
save(matPath, 'allRows', 'Summ', 'SummEx', 'shortMice', 'critNames', 'OnsT', 'P');
fprintf('缓存已写入: %s\n', matPath);
assignin('base', 'PredReuse_Rows', allRows);
assignin('base', 'PredReuse_Summ', Summ);
assignin('base', 'PredReuse_SummEx', SummEx);
assignin('base', 'PredReuse_OnsT', OnsT);

%% ========== local functions ==========
function D = iExtractBlock(blk, bi, stim, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P)
% 单 block（Learned AudioWater 或 Transfer LightWater）：孤立 bout + lick-locked PSTH
D = [];
buid = blk.BlockUID(bi);
selT0 = find(Tr.BlockUID == buid & Tr.Stimulus == stim);
nSmT = Ed(selT0) - Sd(selT0) + 1;
selT = selT0(nSmT >= P.minNSm);
if numel(selT) < P.minTrials, return; end
nSmT = Ed(selT) - Sd(selT) + 1;
nSmB = mode(nSmT);
selT = selT(nSmT == nSmB);
nTr = numel(selT);
if nTr < P.minTrials, return; end
cueIdxB = mode(Td(selT) - Sd(selT) + 1);
rSI = find(MallSess == blk.Mouse(bi) & abs(seconds(DTall - blk.DateTime(bi))) < 60, 1);
if isempty(rSI) || ~isfinite(SIall(rSI)) || SIall(rSI) <= 0, return; end
fs = 1 / SIall(rSI);
tAx1 = ((0:nSmB-1)' / fs) - (cueIdxB-1) / fs;
Starts = Sd(selT); IDX = Starts + (0:nSmB-1);

% ---- CD2 舔水检测：孤立 bout（其前 isoWindow 内无舔水）----
isoP = zeros(nTr, 1);
isoDur = zeros(nTr, 1);
for j = 1:nTr
	cd2 = double(Tr.TrialTags{selT(j)}.CD2); cd2 = cd2(:)';
	if numel(cd2) ~= nSmB
		cd2 = interp1(linspace(0,1,numel(cd2)), cd2, linspace(0,1,nSmB));
	end
	low = cd2(cd2 < prctile(cd2, 60));
	thr = median(low) + P.lickMargin;
	licking = cd2 > thr;
	rise = licking & ~[false, licking(1:end-1)];
	cand = find(rise);
	cand = cand(tAx1(cand) >= -0.1);
	for p = cand
		pre = max(1, p - round(P.isoWindow * fs)) : p - 1;
		if ~any(licking(pre))
			isoP(j) = p;
			% bout 时长（连续舔水串，允许 <=P.boutGap 帧间隙）→ 供衰退判据定位"舔水结束"
			after = licking(p:end);
			k = 1; gap = 0;
			while k <= numel(after)
				if after(k)
					gap = 0;
				else
					gap = gap + 1;
					if gap > P.boutGap, break; end
				end
				k = k + 1;
			end
			isoDur(j) = (k - 1) / fs;
			break;
		end
	end
end
isoTr = find(isoP > 0);
nEv = numel(isoTr);
if nEv < P.minEvents
	warning('PredReuse:FewEvents', 'blk%d 孤立 bout 数 %d < %d', buid, nEv, P.minEvents);
	return;
end
pEv = isoP(isoTr);

ub = bs(bs.BlockUID == buid, :);
nC = height(ub);
cellUID = uint64(ub.CellUID);
if nC == 0, return; end

% ---- lick-locked PSTH（孤立 bout，cue 前基线 ZScore）----
tP = (P.tPwin(1) : 1/fs : P.tPwin(2))';
nTP = numel(tP);
bmask = (tP >= P.baseline(1)) & (tP <= P.baseline(2));
preMask = tAx1 < -0.02;
dOff = floor(tP.' * fs) + 1;                       % 1 x nTP 样本偏移
pIdx = pEv(:) + dOff;                              % nEv x nTP
okE = pIdx >= 1 & pIdx <= nSmB;
Vev = zeros(nC, nEv, nTP);
for c = 1:nC
	sig = double(ub.BlockSignal{c});
	raw = sig(IDX');                               % nSmB x nTr
	b = mean(raw(preMask, :), 1, 'omitnan');
	s = std(raw(preMask, :), 0, 1, 'omitnan'); s(s == 0) = nan;
	Zc = ((raw - b) ./ s)';                        % nTr x nSmB，cue 前基线 ZScore
	ii = pIdx; ii(~okE) = 1;
	Ve = reshape(Zc(sub2ind(size(Zc), repmat(isoTr(:), nTP, 1), ii(:))), nEv, nTP);
	Ve(~okE) = NaN;
	Vev(c, :, :) = reshape(Ve, 1, nEv, nTP);
end

D = struct();
D.BlockUID = buid; D.Mouse = blk.Mouse(bi); D.fs = fs; D.nC = nC;
D.cellUID = cellUID; D.nEv = nEv;
D.tP = tP; D.bmask = bmask; D.Vev = Vev;
% 舔水结束时刻（lick-locked 坐标系）：bout 平均时长，受 PSTH 窗末截断
D.boutDurMean = mean(isoDur(isoTr), 'omitnan');
D.lickEndRel = min(D.boutDurMean, P.tPwin(2));
end

function L = iLabelSets(D, P)
% 三档 early 判据的分组标签（early / sust / late / none），onset 判定口径三档共用。
Vev = D.Vev; tP = D.tP; bmask = D.bmask;
[isE, ~, isL, hasOn, onsetT] = iOnsetLabels(Vev, tP, bmask, P);                       % perm
[isEA, isSA, isLA] = iOnsetLabels(Vev, tP, bmask, P, D.lickEndRel, 1);                % A
[isEB, isSB, isLB] = iOnsetLabels(Vev, tP, bmask, P, D.lickEndRel, 0);                % B
L = struct();
L.onset = onsetT;
L.perm = iGroupCode(isE, false(size(isE)), isL, hasOn);
L.A = iGroupCode(isEA, isSA, isLA, hasOn);
L.B = iGroupCode(isEB, isSB, isLB, hasOn);
end

function g = iGroupCode(isEarly, isSust, isLate, hasOnset)
g = strings(numel(hasOnset), 1);
g(~hasOnset) = "none";
g(isLate) = "late";
g(isSust) = "sust";
g(isEarly) = "early";
end

function [isEarly, isSust, isLate, hasOnset, onsetT] = iOnsetLabels(Vev, tP, bmask, P, lickEndRel, decayLevel)
% 由 lick-locked PSTH 判定 movement-active / early / late，口径与
% EarlyOnsetCells_LickLocked_Analysis.m 一致：baseline+1SD、跨基线窗单 trial SD 均值
% （singleTrial）、持续 200 ms、上采样 200 Hz。early = onset < 0（舔水前活动上升）。
%
% 可选衰退要求（decayLevel 非空时生效）：early 细胞的 PSTH 必须在 onset 之后、舔水结束
% （lickEndRel）之前连续 >=200 ms 回落到 baseMean + decayLevel*baseSD 以下，
% 即不得"跟随这一波舔水一直活跃"。未通过者记入 isSust（sustained）而非 early。
% decayLevel=1 → 回落阈为 onset 阈本身；decayLevel=0 → 回落阈为基线均值（更严格）。
if nargin < 6 || isempty(decayLevel), decayLevel = []; end
if nargin < 5, lickEndRel = []; end
requireDecay = ~isempty(decayLevel) && ~isempty(lickEndRel) && isfinite(lickEndRel);
[nC, ~, ~] = size(Vev);
V2 = permute(Vev, [1, 3, 2]);                      % nC x nTP x nEv
PSTH = mean(V2, 3, 'omitnan');
baseMean = mean(PSTH(:, bmask), 2, 'omitnan');
sdPerEvent = std(V2(:, bmask', :), 0, 2, 'omitnan');
baseSD = squeeze(mean(sdPerEvent, 3, 'omitnan'));
dtFine = P.dtFine;
tFine = (P.detWin(1) : dtFine : P.detWin(2))';
nSus = max(2, round(P.sustain / dtFine));
maxStart = numel(tFine) - nSus + 1;
onsetT = nan(nC, 1);
decayOK = false(nC, 1);
for c = 1:nC
	tr = PSTH(c, :);
	ok = isfinite(tr);
	if sum(ok) < 2, continue; end
	thr = baseMean(c) + baseSD(c);
	if ~isfinite(thr), continue; end
	trF = interp1(tP(ok), tr(ok), tFine, 'linear', nan).';
	for i = 1:maxStart
		seg = trF(i:i + nSus - 1);
		if all(isfinite(seg)) && all(seg > thr)
			onsetT(c) = tFine(i);
			break;
		end
	end
	if ~requireDecay || ~isfinite(onsetT(c)) || onsetT(c) >= 0
		continue;
	end
	% 衰退窗：[onset, 舔水结束]，且不超出 PSTH 采样范围
	tDecEnd = min(lickEndRel, tP(end));
	if tDecEnd - onsetT(c) < P.sustain
		continue;                                  % 观察窗不足 200 ms → 视为未衰退
	end
	tDec = (onsetT(c) : dtFine : tDecEnd)';
	trD = interp1(tP(ok), tr(ok), tDec, 'linear', nan).';
	decThr = baseMean(c) + decayLevel * baseSD(c);
	below = isfinite(trD) & trD < decThr;
	if numel(below) < nSus, continue; end
	decayOK(c) = any(conv(double(below), ones(1, nSus), 'valid') == nSus);
end
hasOnset = isfinite(onsetT);
isLate = hasOnset & onsetT >= 0;
earlyCand = hasOnset & onsetT < 0;
if requireDecay
	isEarly = earlyCand & decayOK;
	isSust = earlyCand & ~decayOK;
else
	isEarly = earlyCand;
	isSust = false(size(earlyCand));
end
end

function [rows, summ] = iCritStats(OnsT, colL, colT, label, P, exclMice)
% 某一档判据的功能复用统计：逐鼠 P(Transfer early | Learned 组)、鼠水平 Wilcoxon、
% 分层 Monte-Carlo（零假设 = 同鼠 none 背景率）、合并转移比例。
if nargin < 6, exclMice = strings(0,1); end
if ~isempty(exclMice)
	OnsT = OnsT(~ismember(OnsT.Mouse, exclMice), :);
end
gLall = OnsT.(colL);
gTall = OnsT.(colT);
gNames = ["early","sust","late","none"];
mice = unique(OnsT.Mouse(gLall == "early"), 'stable');
rows = [];
for i = 1:numel(mice)
	m = mice(i);
	sel = OnsT.Mouse == m;
	gL = gLall(sel); gT = gTall(sel);
	rG = nan(1, numel(gNames));
	nG = zeros(1, numel(gNames));
	for k = 1:numel(gNames)
		msk = gL == gNames(k);
		nG(k) = sum(msk);
		if any(msk), rG(k) = mean(gT(msk) == "early"); end
	end
	tt = nan(numel(gNames));
	for a = 1:numel(gNames)
		for b = 1:numel(gNames)
			tt(a, b) = sum(gL == gNames(a) & gT == gNames(b)) / max(nG(a), 1);
		end
	end
	rows = [rows; table(m, nG(1), nG(2), nG(3), nG(4), rG(1), rG(2), rG(3), rG(4), {tt}, ...
		'VariableNames', {'Mouse','NEarly','NSust','NLate','NNone', ...
		'RE2E','RSust','RLate','RNone','TransMat'})]; %#ok<AGROW>
end

summ = struct('Label', label, 'NEarlyCells', sum(gLall == "early"), ...
	'FracEarly', mean(gLall == "early"), 'NMouse', numel(mice), ...
	'PooledE2E', NaN, 'PooledSust', NaN, 'PooledLate', NaN, 'PooledNone', NaN, ...
	'PVsSust', NaN, 'PVsLate', NaN, 'PVsNone', NaN, 'PSignDir', NaN, ...
	'PSim', NaN, 'ExpSim', NaN, 'PFisher', NaN);
for k = 1:numel(gNames)
	lg = gLall == gNames(k);
	r = sum(gTall(lg) == "early") / max(sum(lg), 1);
	switch gNames(k)
		case "early", summ.PooledE2E = r;
		case "sust",  summ.PooledSust = r;
		case "late",  summ.PooledLate = r;
		case "none",  summ.PooledNone = r;
	end
end

fprintf('【%s】Learned early 细胞：%d 个（占全体细胞 %.2f%%），分布于 %d 只鼠\n', ...
	label, summ.NEarlyCells, 100*summ.FracEarly, summ.NMouse);
if isempty(rows)
	fprintf('  无 early 细胞，跳过。\n');
	return;
end

fprintf('\n逐鼠功能复用率：P(Transfer early | Learned 组)\n');
fprintf('%-9s %5s %5s %5s %5s | %8s %8s %8s %8s\n', ...
	'mouse', 'nEar', 'nSus', 'nLat', 'nNon', 'Learly', 'Lsust', 'Llate', 'Lnone');
for i = 1:height(rows)
	fprintf('%-9s %5d %5d %5d %5d | %8.3f %8.3f %8.3f %8.3f\n', ...
		rows.Mouse(i), rows.NEarly(i), rows.NSust(i), rows.NLate(i), rows.NNone(i), ...
		rows.RE2E(i), rows.RSust(i), rows.RLate(i), rows.RNone(i));
end

fprintf('\n鼠水平检验（n=%d 鼠）：\n', height(rows));
cmpCols = {'RSust', 'RLate', 'RNone'};
cmpNames = ["Learned sust", "Learned late", "Learned none"];
pFields = {'PVsSust', 'PVsLate', 'PVsNone'};
for k = 1:numel(cmpCols)
	vC = rows.(cmpCols{k});
	ok = isfinite(vC) & isfinite(rows.RE2E);
	if sum(ok) < 6
		fprintf('  %s vs %s：可用鼠数不足（%d），跳过检验\n', label, cmpNames(k), sum(ok));
		continue;
	end
	[pV, hV] = signrank(rows.RE2E(ok), vC(ok));
	summ.(pFields{k}) = pV;
	fprintf('  %s vs %s（→T early 率）: %.3f vs %.3f (n=%d), Wilcoxon p=%.4g %s\n', ...
		label, cmpNames(k), mean(rows.RE2E(ok)), mean(vC(ok)), sum(ok), pV, ...
		iif(hV==1, '(显著不同)', '(不显著)'));
end
useBoth = isfinite(rows.RNone) & isfinite(rows.RE2E) & rows.NEarly >= 5;
if any(useBoth)
	nAbove = sum(rows.RE2E(useBoth) > rows.RNone(useBoth));
	pBin = 1 - binocdf(nAbove - 1, sum(useBoth), 0.5);
	summ.PSignDir = pBin;
	fprintf('  逐鼠方向：early 复用率 > none 背景的鼠 %d/%d, sign p=%.4g\n', nAbove, sum(useBoth), pBin);
end

% 分层 Monte-Carlo：逐鼠以 none 背景率抽样 L-early → T-early 的期望计数，检验观察值
v = isfinite(rows.RE2E) & isfinite(rows.RNone) & rows.NEarly > 0;
if any(v)
	nA = double(rows.NEarly(v));
	qA = min(max(rows.RNone(v), 0), 1);
	if sum(nA .* qA) <= 0 && summ.PooledNone > 0
		qA = repmat(summ.PooledNone, size(qA));   % 背景率全为 0 时退用合并 none 率
	end
	kObs = sum(round(rows.RE2E(v) .* nA));
	simTot = zeros(P.nSim, 1);
	for i = 1:numel(nA)
		if qA(i) > 0
			simTot = simTot + binornd(nA(i), qA(i), P.nSim, 1);
		end
	end
	summ.PSim = (sum(simTot >= kObs) + 1) / (P.nSim + 1);
	summ.ExpSim = sum(nA .* qA);
	fprintf('  分层 Monte-Carlo（零假设 = 同鼠 none 背景率）：观察 %d 个 L-early→T-early，分层期望 %.1f，单侧 p=%.4g\n', ...
		kObs, summ.ExpSim, summ.PSim);
end

fprintf('\n合并转移比例（P(Transfer 组 | Learned 组)，细胞层面，细胞非独立仅作汇总参考）：\n');
for g = gNames
	lg = gLall == g;
	if ~any(lg), continue; end
	fprintf('  Learned %-5s (n=%4d) -> T early %.3f | T sust %.3f | T late %.3f | T none %.3f\n', ...
		g, sum(lg), mean(gTall(lg)=="early"), mean(gTall(lg)=="sust"), ...
		mean(gTall(lg)=="late"), mean(gTall(lg)=="none"));
end
eAll = gLall == "early";
a = sum(gTall(eAll) == "early"); b = sum(eAll) - a;
c = sum(gTall(~eAll) == "early"); d = sum(~eAll) - c;
summ.PFisher = fishertest2(a, b, c, d);
fprintf('  合并 Fisher: L-early→T-early %d/%d, 非L-early→T-early %d/%d, p=%.3g\n', ...
	a, a+b, c, c+d, summ.PFisher);
end

function X = iNtatsData(nt)
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data;
	while isa(X, 'MATLAB.DataTypes.NDTable')
		X = X.Data;
	end
elseif isnumeric(nt)
	X = nt;
else
	error('PredReuse:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
if ~isnumeric(X)
	error('PredReuse:BadNTATSData', 'Resolved NTATS data is %s, not numeric.', class(X));
end
X = squeeze(X);
end

function [p, tbl] = fishertest2(a, b, c, d)
% Fisher exact 双侧 p（超几何分布精确计算，避免工具箱依赖）
tbl = [a b; c d];
N = sum(tbl(:));
r1 = a+b; c1 = a+c;
lo = max(0, r1+c1-N); hi = min(r1, c1);
x = lo:hi;
lpx = hygepdfLog(x, N, c1, r1);
ph = exp(lpx);
ph = ph / sum(ph);
pObs = interp1(x, ph, a);
p = sum(ph(ph <= pObs + 1e-12));
end

function lp = hygepdfLog(x, N, K, n)
lp = gammaln(K+1)-gammaln(x+1)-gammaln(K-x+1) + gammaln(N-K+1)-gammaln(n-x+1)-gammaln(N-K-n+x+1) ...
	- (gammaln(N+1)-gammaln(n+1)-gammaln(N-n+1));
end

function s = iif(c, a, b)
if c, s = a; else, s = b; end
end
