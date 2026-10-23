%% AnalyzePreCueStateOnBehavior.m
% 问题：线索前的群体状态是否会调制 early-onset（舔水预测）细胞对行为的驱动力？
%   即是否存在"某类线索前状态 + early-onset → 舔水概率很高，另一类状态 → 显著更低"。
%
% 拆成两个可检验的子问题：
%   Q1（状态主效应）：线索前状态本身能否预测本 trial 是否舔水？
%   Q2（状态调制驱动力，= 交互项）：线索前状态高低，是否改变 early-onset 细胞
%       线索诱发活动对舔水概率的作用强度（斜率/耦合）？
%
% 数据：TransferLearning.AudioLightBaseline()
%   结果变量只能用有 hit/miss 变异的 block：
%     主分析 = Transfer LightWater（11 鼠全部混合，命中率 0.10~0.83，~337 trial）
%       细胞分组来自同鼠 Learned AudioWater 的 early-onset 判定 → 分组与结果变量
%       来自不同任务阶段，无循环论证。
%     次分析 = Naive AudioWater（10 鼠，9 block 混合）
%       分组用同一 block 自判（存在轻度循环，仅作平行验证）。
%   Learned AudioWater / Final / Recall 阶段命中率 ~100%，无结果方差，不能用于本检验。
%
% 特征（每 trial × 每细胞，块级基线，保留 trial 间波动）：
%   基线 = 该 block 全部 trial 的 cue 前样本（t < -0.02 s）的均值/SD（**逐块而非逐 trial**，
%          否则线索前状态会被自身归一化掉）
%   preZ  = 线索前 [-1.0, -0.2] s 窗内 Z 均值  ← 主状态变量
%   preZ2 = 更早 [-2.5, -1.5] s 窗内 Z 均值     ← 时间滞后/漂移对照
%   cueZ  = 线索后 [0, 1] s 窗内 Z 均值          ← "驱动力"（线索诱发活动）
%   trial 级群体指标 = 组内细胞均值（early / late / none 三组，none 作全局状态对照）
%
% 统计：
%   1) 混合效应 logistic 回归（trial 嵌套于鼠，鼠随机截距；另试随机斜率）：
%        M1: y ~ preE*0 + preE + preC + cueE + cueC + (1|Mouse)         → Q1
%        M2: y ~ preE*cueE + preC*cueC + (1|Mouse)                      → Q2（交互项）
%        M3: y ~ preE + preC + cueRz + cueRzN + preE:cueRz + (1|Mouse)  → Q2 可识别版
%      cueRz = cueE 对 preE 鼠内回归的残差（再鼠内标准化），即"独立于当前
%      持续水平的驱动增量"；cueRzN 为 none 组的同一处理。
%      必须正交化：preE 与 cueE 鼠内 Spearman ρ 中位 +0.76（none 组 +0.95），
%      两者高度共线时"状态"与"驱动力"在回归中互相抑制，交互项不可解释。
%      预测量在鼠内标准化，系数 = 每 1 鼠内 SD 的 log-odds。
%      注意：所有 fitglme 统一 FitMethod='laplace'。默认 mpl 用伪似然，其
%      LogLikelihood 跨模型不可比（曾使 Naive 的交互 LRT 误报 p=0.004，
%      Laplace 下为 p=0.135），故做 LRT/AIC 比较时一律用 Laplace 似然。
%   2) 逐鼠 logistic 回归 → 系数方向/大小的符号检验与配对比较（鼠为独立单元，稳健性）
%   3) 三分位风险差（直观回答用户设问）：鼠内按 preE 分低/中/高三档，比较命中率，
%      Friedman + 配对 Wilcoxon（high vs low），报风险差与对应概率
%  3b) 无模型 2×2 交互检验：鼠内按 preE 与驱动各自中位数二分，直接比"差之差"，
%      不依赖 link 函数。概率尺度用风险差之差 ΔRD，odds 尺度用 ΔlogOR。
%      两者同时近零 → 无论状态与驱动是"概率可加"还是"odds 可乘"，都不存在门控。
%      （log-link 的概率尺度乘积模型在本数据上拟合不收敛，故改用此无模型检验回答。）
%   4) 细胞级特异性：每细胞 point-biserial r(preZ, y)，鼠内组间中位数差，
%      以"鼠内打乱组标签"置换检验（保持细胞数与鼠内聚类），并报逐鼠方向一致性
%   5) 多重比较：主检验共 7 项（M1 preE、M2 preE:cueE、M3 正交化交互、2×2 ΔRD、
%      2×2 ΔlogOR、三分位 high-low、细胞级置换），用 Holm-Bonferroni 校正后报告。
%      M3 另拟合 none 组同口径对照交互（M3n, preN:cueRzN），但 **不计入** Holm 族：
%      none 组 Pre–Cue 共线 ρ 高达 0.93~0.96，cueRzN 退化为残余噪声，其系数不可解释。
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
P.preWin   = [-1.0, -0.2];    % 主线索前状态窗
P.preWin2  = [-2.5, -1.5];    % 更早窗（滞后对照）
P.cueWin   = [0, 1.0];        % 线索诱发窗（驱动力）
P.baseCut  = -0.02;           % 块级基线取样上界（cue 前）
P.minNSm   = 40;
P.minTrials= 10;
P.nBootTrials = 20;           % trial 少于此数不做逐鼠回归
P.ridgeLambda = 0.05;         % 逐鼠岭惩罚 logistic 的固定 lambda（预测量已鼠内标准化，跨鼠可比）
% onset 判定（与 EarlyOnsetCells_LickLocked_Analysis.m 同口径）
P.isoWindow= 1.0;
P.lickMargin=35;
P.tPwin    = [-1.5, 2.0];
P.baseline = [-1.0, -0.5];
P.detWin   = [-0.2, 1.5];
P.sustain  = 0.2;
P.boutGap  = 2;
P.dtFine   = 0.005;
P.minEvents= 8;
P.nPermCell= 10000;           % 细胞级组标签置换次数
P.seed     = 42;
rng(P.seed);

warning('off', 'UniExp:Exception:Block_must_warn');
DS = TransferLearning.AudioLightBaseline();
Tr = DS.Trials;
Tr.Stimulus = string(Tr.Stimulus);
sr = Tr.SampleRange;
Sd = double(sr.Start); Ed = double(sr.End); Td = double(sr.Tag);
bs = DS.BlockSignals;

T = DS.TableQuery(["Mouse","DateTime","BlockUID","Stimulus","Phase","Behavior"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus); T.Phase = string(T.Phase);
T.Behavior = double(T.Behavior);

TQ = DS.TableQuery(["Mouse","DateTime","BlockUID","Stimulus","Phase"]);
TQ.Mouse = string(TQ.Mouse); TQ.Stimulus = string(TQ.Stimulus); TQ.Phase = string(TQ.Phase);
learnedBlk = unique(TQ(TQ.Phase=="Learned" & TQ.Stimulus=="AudioWater", ["Mouse","DateTime","BlockUID"]), 'rows','stable');
transferBlk= unique(TQ(TQ.Phase=="Transfer" & TQ.Stimulus=="LightWater", ["Mouse","DateTime","BlockUID"]), 'rows','stable');
naiveBlk   = unique(TQ(TQ.Phase=="Naive" & TQ.Stimulus=="AudioWater", ["Mouse","DateTime","BlockUID"]), 'rows','stable');

DTall = DS.DateTimes;
SIall = seconds(DTall.SeriesInterval);
DTdt = DTall.DateTime; if ~isempty(DTdt.TimeZone), DTdt.TimeZone = ''; end
MallSess = string(DTall.Mouse);

fprintf('=== 线索前状态是否调制 early-onset 细胞的行为驱动力（AudioLightBaseline）===\n');

%% ---- 1. 主分析：Learned 定义分组 → Transfer trial 级检验 ----
[Dat, Rep] = iBuildMouseData(learnedBlk, transferBlk, "AudioWater", "LightWater", ...
	Tr, Sd, Ed, Td, bs, SIall, DTdt, MallSess, P, "Transfer（分组来自 Learned，无循环）");

%% ---- 2. 次分析：Naive 组内自判 ----
[DatN, RepN] = iBuildMouseData(naiveBlk, naiveBlk, "AudioWater", "AudioWater", ...
	Tr, Sd, Ed, Td, bs, SIall, DTdt, MallSess, P, "Naive（分组同 block 自判）");

%% ---- 3. 统计分析（两套数据同流程）----
RepAll = {}; 
fprintf('\n################ 主分析：%s ################\n', Rep.tag);
RepAll{1} = iStatReport(Dat, Rep, P);
if ~isempty(DatN)
	fprintf('\n################ 次分析：%s ################\n', RepN.tag);
	RepAll{2} = iStatReport(DatN, RepN, P);
end

%% ---- 4. 保存 ----
outDir = fullfile(thisDir, 'Temp');
if ~exist(outDir, 'dir'), mkdir(outDir); end
matPath = fullfile(outDir, 'PreCueStateOnBehavior_Results.mat');
save(matPath, 'Dat', 'Rep', 'DatN', 'RepN', 'RepAll', 'P');
fprintf('\n缓存已写入: %s\n', matPath);
assignin('base', 'PreCueState_Dat', Dat);
assignin('base', 'PreCueState_Rep', Rep);
assignin('base', 'PreCueState_RepAll', RepAll);

%% ========== local functions ==========
function [Dat, Rep] = iBuildMouseData(blkDef, blkOut, stimDef, stimOut, ...
	Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P, tag)
% blkDef: 定义 early-onset 分组的 block；blkOut: 提供 trial 级结果的 block。
% 返回 Dat（trial 级长表）与 Rep（细胞级 point-biserial 结构）。
rows = {};
repMice = {};
nSkip = 0;
for bi = 1:height(blkDef)
	mouse = blkDef.Mouse(bi);
	rO = find(blkOut.Mouse == mouse, 1);
	if isempty(rO)
		fprintf('%s: 无配对结果 block，跳过\n', mouse);
		nSkip = nSkip + 1;
		continue;
	end
	DD = iExtractOnsetBlock(blkDef, bi, stimDef, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P);
	if isempty(DD)
		fprintf('%s: 定义 block 事件不足，跳过\n', mouse);
		nSkip = nSkip + 1;
		continue;
	end
	FO = iExtractTrialFeatures(blkOut, rO, stimOut, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P);
	if isempty(FO)
		fprintf('%s: 结果 block 提取失败，跳过\n', mouse);
		nSkip = nSkip + 1;
		continue;
	end
	% 分组（定义 block）
	Lab = iOnsetGroupLabels(DD, P);
	% 按 CellUID 对齐到结果 block
	[uid, ia, ib] = intersect(uint64(DD.cellUID), uint64(FO.cellUID), 'stable');
	if numel(uid) < 50
		fprintf('%s: 两 block 共有细胞过少（%d），跳过\n', mouse, numel(uid));
		nSkip = nSkip + 1;
		continue;
	end
	gLab = Lab(ia);                          % early / late / none（定义 block 口径）
	preE = FO.preZ(ib, :); cueE = FO.cueZ(ib, :); pre2E = FO.preZ2(ib, :);
	cueEc = FO.cueZc(ib, :);
	nTr = size(FO.y, 1);
	% 组内群体指标（每组细胞均值）。要求组内 >=5 个细胞，否则该指标置 NaN
	idxE = gLab == "early"; idxL = gLab == "late"; idxN = gLab == "none";
	pE = iPopMean(preE, idxE);  cE = iPopMean(cueE, idxE);  p2E = iPopMean(pre2E, idxE);
	pL = iPopMean(preE, idxL);  cL = iPopMean(cueE, idxL);
	pN = iPopMean(preE, idxN);  cN = iPopMean(cueE, idxN);  cEc = iPopMean(cueEc, idxE);
	y = FO.y;
	tbl = table(repmat(mouse, nTr, 1), (1:nTr)', y, FO.prevY, pE, pL, pN, cE, cL, cN, p2E, cEc, ...
		FO.lickFracPre, FO.nCleanPre, ...
		repmat(sum(idxE), nTr, 1), repmat(sum(idxL), nTr, 1), repmat(sum(idxN), nTr, 1), ...
		'VariableNames', {'Mouse','Trial','Y','PrevY','PreE','PreL','PreN','CueE','CueL','CueN', ...
		'Pre2E','CueEc','LickFracPre','NCleanPre','NEarly','NLate','NNone'});
	rows{end+1} = tbl; %#ok<AGROW>
	% 细胞级 point-biserial（preZ vs y）
	if sum(y == 1) >= 5 && sum(y == 0) >= 5
		rCell = nan(numel(uid), 1);
		for c = 1:numel(uid)
			v = preE(c, :).';                    % nTr x 1（禁止与 y 隐式扩展）
			ok = isfinite(v) & isfinite(y);
			if sum(ok) >= 10 && std(v(ok)) > 0
				rCell(c) = corr(v(ok), y(ok), 'Type', 'Pearson');
			end
		end
		ru = nan(numel(uid), 1);
		for c = 1:numel(uid)
			v = cueE(c, :).';
			ok = isfinite(v) & isfinite(y);
			if sum(ok) >= 10 && std(v(ok)) > 0
				ru(c) = corr(v(ok), y(ok), 'Type', 'Pearson');
			end
		end
		repMice{end+1} = builtin('struct', 'Mouse', mouse, 'CellUID', uid, ...
			'Group', gLab, 'RPre', rCell, 'RCue', ru); %#ok<AGROW>
	end
	fprintf('%s: nCell(共有)=%4d [early %3d late %3d none %3d] nTrial=%2d hit=%.2f\n', ...
		mouse, numel(uid), sum(idxE), sum(idxL), sum(idxN), nTr, mean(y, 'omitnan'));
end
Dat = [];
if ~isempty(rows)
	Dat = vertcat(rows{:});
end
% 注意：不能用 struct(...) 构造 Rep——cell 数组字段会被展开成结构体数组
Rep = struct();
Rep.tag = tag;
Rep.nSkip = nSkip;
Rep.cells = repMice;
Rep.nMouse = 0;
Rep.nTrial = 0;
if ~isempty(Dat)
	Rep.nMouse = numel(unique(Dat.Mouse));
	Rep.nTrial = height(Dat);
end
end

function m = iPopMean(M, idx)
% M: nCell x nTrial；idx: 组内细胞逻辑向量。返回 nTrial x 1 列向量。
% 组内细胞 <5 时返回 NaN（群体指标不可靠）。
if sum(idx) < 5
	m = nan(size(M, 2), 1);
	return;
end
m = mean(M(idx, :), 1, 'omitnan').';
end

function D = iExtractOnsetBlock(blk, bi, stim, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P)
% 定义 block：孤立 bout + lick-locked PSTH（供 early/late/none 分组）
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
IDX = Sd(selT) + (0:nSmB-1);

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
			after = licking(p:end);
			k = 1; gap = 0;
			while k <= numel(after)
				if after(k), gap = 0;
				else, gap = gap + 1; if gap > P.boutGap, break; end
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
if nEv < P.minEvents, return; end
pEv = isoP(isoTr);

ub = bs(bs.BlockUID == buid, :);
nC = height(ub);
if nC == 0, return; end
cellUID = uint64(ub.CellUID);

tP = (P.tPwin(1) : 1/fs : P.tPwin(2))';
nTP = numel(tP);
bmask = (tP >= P.baseline(1)) & (tP <= P.baseline(2));
preMask = tAx1 < P.baseCut;
dOff = floor(tP.' * fs) + 1;
pIdx = pEv(:) + dOff;
okE = pIdx >= 1 & pIdx <= nSmB;
Vev = zeros(nC, nEv, nTP);
for c = 1:nC
	sig = double(ub.BlockSignal{c});
	raw = sig(IDX');
	b = mean(raw(preMask, :), 1, 'omitnan');
	s = std(raw(preMask, :), 0, 1, 'omitnan'); s(s == 0) = nan;
	Zc = ((raw - b) ./ s)';
	ii = pIdx; ii(~okE) = 1;
	Ve = reshape(Zc(sub2ind(size(Zc), repmat(isoTr(:), nTP, 1), ii(:))), nEv, nTP);
	Ve(~okE) = NaN;
	Vev(c, :, :) = reshape(Ve, 1, nEv, nTP);
end

D = builtin('struct', 'BlockUID', buid, 'Mouse', blk.Mouse(bi), 'fs', fs, 'nC', nC, ...
	'cellUID', cellUID, 'nEv', nEv, 'tP', tP, 'bmask', bmask, 'Vev', Vev, ...
	'boutDurMean', mean(isoDur(isoTr), 'omitnan'));
D.lickEndRel = min(D.boutDurMean, P.tPwin(2));
end

function g = iOnsetGroupLabels(D, P)
% early / late / none（perm 口径，无衰退要求）
[isE, ~, isL, hasOn, ~] = iOnsetLabels(D.Vev, D.tP, D.bmask, P);
g = strings(D.nC, 1);
g(~hasOn) = "none";
g(isL) = "late";
g(isE) = "early";
end

function [isEarly, isSust, isLate, hasOnset, onsetT] = iOnsetLabels(Vev, tP, bmask, P, lickEndRel, decayLevel)
% 与 EarlyOnsetCells_LickLocked_Analysis.m 同口径：baseline+1SD、singleTrial SD、
% 持续 200 ms、200 Hz 上采样。early = onset < 0。
% 可选衰退要求（decayLevel 非空）：early 须在 [onset, lickEndRel] 内连续 >=200 ms
% 回落到 baseMean + decayLevel*baseSD 以下；未通过者记为 sust。
if nargin < 6 || isempty(decayLevel), decayLevel = []; end
if nargin < 5, lickEndRel = []; end
requireDecay = ~isempty(decayLevel) && ~isempty(lickEndRel) && isfinite(lickEndRel);
[nC, ~, ~] = size(Vev);
V2 = permute(Vev, [1, 3, 2]);
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
	if ~requireDecay || ~isfinite(onsetT(c)) || onsetT(c) >= 0, continue; end
	tDecEnd = min(lickEndRel, tP(end));
	if tDecEnd - onsetT(c) < P.sustain, continue; end
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

function F = iExtractTrialFeatures(blk, bi, stim, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P)
% 结果 block：逐 trial × 逐细胞的窗均值（块级基线，保留 trial 间波动）
F = [];
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
IDX = Sd(selT) + (0:nSmB-1);

ub = bs(bs.BlockUID == buid, :);
nC = height(ub);
if nC == 0, return; end
cellUID = uint64(ub.CellUID);

% ---- CD2 舔水掩蔽：线索前窗内混入的舔水（含上一 trial 拖尾）是运动/荧光伪迹，
%      会与结果变量人为相关，故基线与各线索前窗只用无舔水样本 ----
lickMat = false(nTr, nSmB);
noTag = 0;
for j = 1:nTr
	tt = Tr.TrialTags{selT(j)};
	% 注意：TrialTags 元素并非普通 struct，isfield 会恒返回 false，须用 fieldnames 判定
	if isempty(tt) || ~any(strcmp(fieldnames(tt), 'CD2'))
		noTag = noTag + 1;
		continue;
	end
	cd2 = double(tt.CD2); cd2 = cd2(:)';
	if numel(cd2) ~= nSmB
		cd2 = interp1(linspace(0,1,numel(cd2)), cd2, linspace(0,1,nSmB));
	end
	low = cd2(cd2 < prctile(cd2, 60));
	thr = median(low) + P.lickMargin;
	lickMat(j, :) = cd2 > thr;
end
if noTag > 0
	warning('PreCueState:NoTags', 'blk%d 有 %d/%d trial 缺 TrialTags，未做舔水掩蔽', buid, noTag, nTr);
end

baseMask = tAx1 < P.baseCut;
wPre  = tAx1 >= P.preWin(1)  & tAx1 <= P.preWin(2);
wPre2 = tAx1 >= P.preWin2(1) & tAx1 <= P.preWin2(2);
wCue  = tAx1 >= P.cueWin(1)  & tAx1 <= P.cueWin(2);
if sum(baseMask) < 3 || sum(wPre) < 2 || sum(wCue) < 2
	warning('PreCueState:BadWindows', 'blk%d 窗内样本过少（base %d, pre %d, cue %d）', ...
		buid, sum(baseMask), sum(wPre), sum(wCue));
	if sum(baseMask) < 3, return; end
end

% 逐 trial 干净样本掩蔽（线索前窗与基线）
cleanPre  = bsxfun(@and, repmat(wPre.',  nTr, 1), ~lickMat);   % nTr x nSmB
cleanPre2 = bsxfun(@and, repmat(wPre2.', nTr, 1), ~lickMat);
cleanBase = bsxfun(@and, repmat(baseMask.', nTr, 1), ~lickMat);
lickFracPre = sum(lickMat(:, wPre), 2) ./ max(sum(wPre), 1);   % nTr x 1 污染比例
nCleanPre = sum(cleanPre, 2);                                  % nTr x 1

preZ = nan(nC, nTr); preZ2 = nan(nC, nTr); cueZ = nan(nC, nTr); cueZc = nan(nC, nTr);
for c = 1:nC
	sig = double(ub.BlockSignal{c});
	raw = sig(IDX');                          % nSmB x nTr
	Zraw = raw.';                             % nTr x nSmB
	% 块级基线：全部 trial 的 cue 前无舔水样本
	Zb = Zraw(cleanBase);
	if numel(Zb) < 20, continue; end
	B = mean(Zb, 'omitnan');
	S = std(Zb, 0, 'omitnan');
	if ~isfinite(S) || S == 0, continue; end
	Z = (Zraw - B) / S;                       % nTr x nSmB，块级基线 Z
	if any(wPre),  preZ(c, :)  = iMaskedMean(Z, cleanPre,  2); end
	if any(wPre2), preZ2(c, :) = iMaskedMean(Z, cleanPre2, 2); end
	if any(wCue)
		cueZc(c, :) = iMaskedMean(Z, bsxfun(@and, repmat(wCue.', nTr, 1), ~lickMat), 2);
		cueZ(c, :)  = mean(Z(:, wCue), 2, 'omitnan').';   % 不掩蔽（与 Fig4D 等口径一致）
	end
end

yv = double(Tr.Behavior(selT));
y = yv(:);
prevY = [nan; y(1:end-1)];                    % 上一 trial 结果（控制序列依赖）

F = builtin('struct', 'BlockUID', buid, 'Mouse', blk.Mouse(bi), 'fs', fs, ...
	'nC', nC, 'cellUID', cellUID, 'nTr', nTr, 'y', y, 'prevY', prevY, ...
	'preZ', preZ, 'preZ2', preZ2, 'cueZ', cueZ, 'cueZc', cueZc, ...
	'lickFracPre', lickFracPre, 'nCleanPre', nCleanPre);
end

function m = iMaskedMean(Z, mask, minN)
% Z: nTr x nSm；mask: nTr x nSm。逐 trial 求掩蔽样本均值（列向量输出）。
% 干净样本 < minN 时该 trial 置 NaN。
Zm = Z; Zm(~mask) = NaN;
nOk = sum(mask, 2);
m = sum(Zm, 2, 'omitnan') ./ nOk;
m(nOk < minN) = NaN;
m = m(:);
end

function S = iStatReport(Dat, Rep, P)
S = struct('Tag', Rep.tag, 'PM1Pre', NaN, 'PM2Inter', NaN, 'PTerc', NaN, 'PCell', NaN, ...
	'BPre', NaN, 'BInter', NaN, 'RD', NaN, 'MedDiffCell', NaN, 'PM1Cue', NaN, ...
	'PM1Lag', NaN, 'PM1Prev', NaN, 'PM2bInter', NaN, 'PM3Inter', NaN, 'BInter3', NaN, ...
	'PM3nInter', NaN, 'BPreM3', NaN, 'BCueM3', NaN, 'P2x2RD', NaN, 'P2x2OR', NaN, ...
	'MedRD2x2', NaN, 'DriveSpanLo', NaN, 'DriveSpanHi', NaN, 'StateSpanLo', NaN, 'StateSpanHi', NaN, ...
	'PRhoPre', NaN, 'PRhoPreVsNone', NaN, 'PIntSlope', NaN, 'PFriedman', NaN, 'PSignDir', NaN, ...
	'RhoE', NaN, 'RhoN', NaN);
if isempty(Dat)
	fprintf('无可用数据，跳过。\n');
	return;
end

fprintf('线索前窗舔水掩蔽：平均掩掉 %.1f%% 样本，中位保留干净样本 %.1f 个/trial\n', ...
	100*mean(Dat.LickFracPre, 'omitnan'), median(Dat.NCleanPre, 'omitnan'));

% 鼠内标准化（各预测量在鼠内 z 化，便于跨鼠合并与解释为"每 1 鼠内 SD"）
mice = unique(Dat.Mouse, 'stable');
vn = {'PreE','PreN','CueE','CueN','Pre2E','CueEc'};
zn = {'PreEz','PreNz','CueEz','CueNz','Pre2Ez','CueEcz'};
Zc = nan(height(Dat), numel(vn));
for i = 1:numel(mice)
	sel = Dat.Mouse == mice(i);
	for k = 1:numel(vn)
		v = Dat.(vn{k})(sel);
		sd = std(v, 'omitnan');
		if sd > 0
			Zc(sel, k) = (v - mean(v, 'omitnan')) / sd;
		end
	end
end
for k = 1:numel(zn)
	Dat.(zn{k}) = Zc(:, k);
end

% 共线性诊断 + 正交化"驱动力"：Cue 对 Pre 做鼠内回归取残差
%   early 组 → CueRz，none 组 → CueRzN（同口径，供交叉对照）。
% 因为钙信号的 cue 前水平与 cue 诱发幅度高度自相关（none 组尤甚），不残差化则
% "状态"与"驱动力"在回归里互相抑制（suppression），交互项无法解释。
gDef = {'PreEz','CueEz','CueRz'; 'PreNz','CueNz','CueRzN'};
gLab = {'early','none'};
rhoPC = nan(numel(mice), size(gDef,1));
for g = 1:size(gDef,1)
	Dat.(gDef{g,3}) = nan(height(Dat), 1);
	for i = 1:numel(mice)
		sel = Dat.Mouse == mice(i) & isfinite(Dat.(gDef{g,1})) & isfinite(Dat.(gDef{g,2}));
		if sum(sel) < 10 || std(Dat.(gDef{g,1})(sel)) == 0, continue; end
		b = polyfit(Dat.(gDef{g,1})(sel), Dat.(gDef{g,2})(sel), 1);
		Dat.(gDef{g,3})(sel) = Dat.(gDef{g,2})(sel) - polyval(b, Dat.(gDef{g,1})(sel));
		rhoPC(i,g) = corr(Dat.(gDef{g,1})(sel), Dat.(gDef{g,2})(sel), 'Type', 'Spearman');
		ok1 = isfinite(Dat.(gDef{g,3})(sel));
		sd = std(Dat.(gDef{g,3})(sel(ok1)));
		if sd > 0
			tmp = Dat.(gDef{g,3})(sel);
			tmp(ok1) = (tmp(ok1) - mean(tmp(ok1))) / sd;
			Dat.(gDef{g,3})(sel) = tmp;
		end
	end
end
rhoMed = nan(size(gDef,1), 1);
for g = 1:size(gDef,1)
	okRho = isfinite(rhoPC(:,g));
	rhoMed(g) = median(rhoPC(okRho,g));
	fprintf('%s 组 Pre–Cue 鼠内共线：中位 ρ=%+.3f（%d/%d 鼠为正）→ 用残差化驱动 %s 表示"独立于状态的驱动增量"\n', ...
		gLab{g}, rhoMed(g), sum(rhoPC(okRho,g) > 0), sum(okRho), gDef{g,3});
end
S.RhoE = rhoMed(1);  S.RhoN = rhoMed(2);

okAll = isfinite(Dat.Y) & isfinite(Dat.PreEz) & isfinite(Dat.PreNz) & isfinite(Dat.CueEz) & isfinite(Dat.CueNz);
fprintf('可用 trial：%d/%d（缺组指标的 trial 已排除），鼠 %d 只，总命中 %d\n', ...
	sum(okAll), height(Dat), numel(unique(Dat.Mouse(okAll))), sum(Dat.Y(okAll)));
D2 = Dat(okAll, :);

fprintf('\n---- (1) 混合效应 logistic 回归（鼠随机截距；系数 = 每 1 鼠内 SD 的 log-odds）----\n');
M1 = iFitGLME(D2, 'Y ~ PreEz + PreNz + CueEz + CueNz + (1|Mouse)', 'M1 主模型（Q1）');
if ~isempty(M1)
	q = iPick(M1, 'PreEz');
	S.PM1Pre = q.pv; S.BPre = q.est;
	qc = iPick(M1, 'PreNz');
	qe = iPick(M1, 'CueEz');
	S.PM1Cue = qe.pv;
	fprintf('  → 状态对照 PreNz（none 细胞同一窗）：β=%+.3f p=%.4g\n', qc.est, qc.pv);
	fprintf('  → 驱动对照 CueEz（early 细胞线索诱发）：β=%+.3f p=%.4g\n', qe.est, qe.pv);
end

% M1b：更早窗（[-2.5,-1.5] s）作滞后对照，排除慢漂移解释
ok1b = okAll & isfinite(Dat.Pre2Ez);
if sum(ok1b) >= 60
	M1b = iFitGLME(Dat(ok1b, :), 'Y ~ PreEz + Pre2Ez + PreNz + (1|Mouse)', 'M1b 滞后窗对照');
	if ~isempty(M1b), S.PM1Lag = iPick(M1b, 'Pre2Ez').pv; end
end

% M1c：控制上一 trial 结果（序列依赖）
ok1c = okAll & isfinite(Dat.PrevY);
if sum(ok1c) >= 60
	M1c = iFitGLME(Dat(ok1c, :), ...
		'Y ~ PreEz + PreNz + CueEz + CueNz + PrevY + (1|Mouse)', 'M1c 控制上一trial结果');
	if ~isempty(M1c), S.PM1Prev = iPick(M1c, 'PreEz').pv; end
end

% M2：Q2 —— 状态是否调制 early 细胞线索诱发活动对行为的作用（交互项）
M2 = iFitGLME(D2, 'Y ~ PreEz*CueEz + PreNz*CueNz + (1|Mouse)', 'M2 交互模型（Q2）');
if ~isempty(M2)
	qi = iPick(M2, 'PreEz:CueEz');
	S.PM2Inter = qi.pv; S.BInter = qi.est;
	qn = iPick(M2, 'PreNz:CueNz');
	fprintf('  → 对照交互 PreNz:CueNz：β=%+.3f p=%.4g\n', qn.est, qn.pv);
end
try
	M2r = fitglme(D2, 'Y ~ PreEz*CueEz + PreNz*CueNz + (1+PreEz|Mouse)', 'Distribution','binomial');
	[~, nmR] = iFE(M2r);
	ir = find(nmR == "PreEz:CueEz", 1);
	if ~isempty(ir)
		fprintf('  M2（随机斜率）交互：β=%+.3f p=%.4g\n', ...
			M2r.Coefficients.Estimate(ir), M2r.Coefficients.pValue(ir));
	end
catch
	fprintf('  M2（随机斜率）未收敛，略。\n');
end

% M2b：交互项改用掩蔽舔水后的线索窗（排除舔水运动伪迹解释）
ok2b = okAll & isfinite(Dat.CueEcz);
if sum(ok2b) >= 60
	M2b = iFitGLME(Dat(ok2b, :), 'Y ~ PreEz*CueEcz + PreNz*CueNz + (1|Mouse)', 'M2b 掩蔽舔水的线索窗');
	if ~isempty(M2b), S.PM2bInter = iPick(M2b, 'PreEz:CueEcz').pv; end
end

% M3：Q2 的可识别版本 —— 驱动力取"与线索前状态正交"的残差 CueRz。
% 原始 PreEz*CueEz 交互因两者高度共线（见上）而难以解释；正交化后，
% PreEz:CueRz 的系数即"状态每升 1 SD，独立于状态的那部分线索诱发活动
% 对舔水概率的作用改变多少 log-odds"。
ok3 = okAll & isfinite(Dat.CueRz);
ok3n = ok3 & isfinite(Dat.CueRzN);
if sum(ok3n) >= 60
	D3 = Dat(ok3n, :);
	% M3a 可加基线（两组状态 + 两组正交化驱动）；M3 加 early 交互；M3n 加 none 交互（对照）
	M3a = iFitGLME(D3, 'Y ~ PreEz + PreNz + CueRz + CueRzN + (1|Mouse)', 'M3a 可加基线（无交互）');
	M3  = iFitGLME(D3, 'Y ~ PreEz + PreNz + CueRz + CueRzN + PreEz:CueRz + (1|Mouse)', 'M3 early 组交互（Q2）');
	M3n = iFitGLME(D3, 'Y ~ PreEz + PreNz + CueRz + CueRzN + PreNz:CueRzN + (1|Mouse)', 'M3n none 组交互（同口径对照）');
	fprintf('  → 判读：交互 β>0 = 高状态放大驱动力；β<0 = 高状态削弱驱动力；β≈0 = 状态与驱动可加\n');
	if ~isempty(M3a) && ~isempty(M3)
		q3 = iPick(M3, 'PreEz:CueRz');
		S.PM3Inter = q3.pv; S.BInter3 = q3.est; S.CI3 = exp(q3.est + [-1.96, 1.96] * q3.se);
		LR3 = 2 * (M3.ll - M3a.ll);   % Laplace 积分似然，跨模型可比
		fprintf('  → early 交互 95%%CI OR [%.2f, %.2f]；LRT（df=1）LR=%.3f p=%.4g；ΔAIC=%+.2f（|ΔAIC|<2 = 与可加模型等价）\n', ...
			S.CI3(1), S.CI3(2), LR3, 1-chi2cdf(max(LR3,0),1), M3.aic - M3a.aic);
	end
	if ~isempty(M3a) && ~isempty(M3n)
		q3n = iPick(M3n, 'PreNz:CueRzN');
		S.PM3nInter = q3n.pv;
		LR3n = 2 * (M3n.ll - M3a.ll);
		fprintf('  → none 组对照交互 β=%+.3f p=%.4g，LRT p=%.4g\n', q3n.est, q3n.pv, 1-chi2cdf(max(LR3n,0),1));
		if isfinite(rhoMed(2)) && rhoMed(2) > 0.9
			fprintf('    [警告] none 组 Pre–Cue ρ=%.3f > 0.9：PreNz 与 CueNz 近乎同一变量，CueRzN 退化为残余噪声，\n', rhoMed(2));
			fprintf('           其主效应与交互系数均不得作生物学解释（典型的共线抑制）。该组仅作为 early 组的同口径参照，\n');
			fprintf('           不计入 Holm 主检验族（避免用退化项污染多重比较）。\n');
		elseif ~isempty(M3)
			fprintf('    → 与 early 组零结果一致，说明 early 组的交互零结果不是该组特有的识别缺陷\n');
		end
		if ~isempty(M3)
			fprintf('  → 交互系数差 early−none = %+.3f\n', iPick(M3,'PreEz:CueRz').est - q3n.est);
		end
	end
	if ~isempty(M3a)
		qPa = iPick(M3a,'PreEz');  qCa = iPick(M3a,'CueRz');  qCn = iPick(M3a,'CueRzN');  qPn = iPick(M3a,'PreNz');
		S.BPreM3 = qPa.est; S.BCueM3 = qCa.est;
		fprintf('  → 可加模型效应量：early 状态 PreEz β=%+.3f OR=%.2f p=%.4g | none 状态 PreNz β=%+.3f p=%.4g\n', ...
			qPa.est, exp(qPa.est), qPa.pv, qPn.est, qPn.pv);
		fprintf('                    early 独立驱动 CueRz β=%+.3f OR=%.2f p=%.4g | none 独立驱动 CueRzN β=%+.3f OR=%.2f p=%.4g\n', ...
			qCa.est, exp(qCa.est), qCa.pv, qCn.est, exp(qCn.est), qCn.pv);
	end
elseif sum(ok3) >= 60
	M3 = iFitGLME(Dat(ok3, :), 'Y ~ PreEz + CueRz + PreEz:CueRz + PreNz + (1|Mouse)', ...
		'M3 正交化驱动交互（Q2 可识别版，缺 none 组指标）');
	if ~isempty(M3)
		q3 = iPick(M3, 'PreEz:CueRz');
		S.PM3Inter = q3.pv; S.BInter3 = q3.est;
		fprintf('  → 判读：交互 β>0 = 高状态放大驱动力；β<0 = 高状态削弱驱动力；β≈0 = 状态与驱动可加\n');
	end
end

fprintf('\n---- (2) 逐鼠稳健检验（Spearman ρ + 固定 λ 岭 logistic；完全分离时不发散）----\n');
fprintf('%-9s %5s %5s | %9s %9s %9s | %10s\n', 'mouse', 'nTr', 'hit', 'rhoPreE', 'rhoPreN', 'rhoCueE', 'ridge bInt');
rhoPre = []; rhoPreN = []; rhoCue = []; bInt = [];
for i = 1:numel(mice)
	sel = Dat.Mouse == mice(i) & okAll;
	d = Dat(sel, :);
	if height(d) < P.nBootTrials || numel(unique(d.Y)) < 2, continue; end
	r1 = corr(d.PreEz, d.Y, 'Type', 'Spearman', 'Rows', 'complete');
	r2 = corr(d.PreNz, d.Y, 'Type', 'Spearman', 'Rows', 'complete');
	r3 = corr(d.CueEz, d.Y, 'Type', 'Spearman', 'Rows', 'complete');
	msk = isfinite(d.PreEz) & isfinite(d.CueEz) & isfinite(d.PreNz) & isfinite(d.Y);
	bi = NaN;
	if sum(msk) >= P.nBootTrials && numel(unique(d.Y(msk))) == 2
		Xm = [d.PreEz(msk), d.CueEz(msk), d.PreNz(msk), d.PreEz(msk) .* d.CueEz(msk)];
		try
			lm = fitclinear(Xm, d.Y(msk), 'Learner', 'logistic', 'Regularization', 'ridge', ...
				'Lambda', P.ridgeLambda, 'Solver', 'lbfgs', 'IterationLimit', 2000);
			bi = lm.Beta(4);
		catch
			bi = NaN;
		end
	end
	rhoPre(end+1) = r1; rhoPreN(end+1) = r2; rhoCue(end+1) = r3; bInt(end+1) = bi; %#ok<AGROW>
	fprintf('%-9s %5d %5d | %+9.3f %+9.3f %+9.3f | %+10.3f\n', mice(i), height(d), sum(d.Y==1), r1, r2, r3, bi);
end
if numel(rhoPre) >= 6
	nTot = numel(rhoPre);
	nNeg = sum(rhoPre < 0);
	[pR, hR] = signrank(rhoPre(:));
	S.PRhoPre = pR;
	pBSign = min(1, 2 * min(binocdf(nNeg, nTot, 0.5), 1 - binocdf(nNeg - 1, nTot, 0.5)));
	S.PSignDir = pBSign;
	fprintf('  逐鼠 ρ(preE, y)：中位 %+.3f，%d/%d 鼠为负（状态越高越不易舔水），Wilcoxon p=%.4g %s，双侧符号 p=%.4g\n', ...
		median(rhoPre), nNeg, nTot, pR, iif(hR==1,'(显著)','(不显著)'), pBSign);
	[pRn, hRn] = signrank(rhoPreN(:));
	fprintf('  逐鼠 ρ(preN, y)：中位 %+.3f，%d/%d 鼠为负，Wilcoxon p=%.4g %s\n', ...
		median(rhoPreN), sum(rhoPreN < 0), numel(rhoPreN), pRn, iif(hRn==1,'(显著)','(不显著)'));
	[pRd, hRd] = signrank(rhoPre(:), rhoPreN(:));
	S.PRhoPreVsNone = pRd;
	fprintf('  逐鼠 ρpreE vs ρpreN 配对（early 细胞特异性）：Wilcoxon p=%.4g %s\n', ...
		pRd, iif(hRd==1,'(不同)','(相同)'));
	[pRc, hRc] = signrank(rhoCue(:));
	fprintf('  逐鼠 ρ(cueE, y)：中位 %+.3f，Wilcoxon p=%.4g %s（early 细胞线索诱发活动与行为关联）\n', ...
		median(rhoCue), pRc, iif(hRc==1,'(显著)','(不显著)'));
end
okB = isfinite(bInt);
if sum(okB) >= 6
	[pI, hI] = signrank(bInt(okB));
	S.PIntSlope = pI;
	fprintf('  逐鼠岭交互系数：中位 %+.3f，%d/%d 为负，Wilcoxon p=%.4g %s（状态调制驱动力）\n', ...
		median(bInt(okB)), sum(bInt(okB) < 0), sum(okB), pI, iif(hI==1,'(显著)','(不显著)'));
end

fprintf('\n---- (3) 三分位风险差：鼠内按 preE 分档的命中率 ----\n');
fprintf('%-9s | %14s %14s %14s | %8s\n', 'mouse', 'low (n,rate)', 'mid (n,rate)', 'high (n,rate)', 'high-low');
terc = {};
for i = 1:numel(mice)
	sel = Dat.Mouse == mice(i) & okAll;
	if sum(sel) < 12, continue; end
	d = Dat(sel, :);
	% 鼠内按 preE 均分三档（tiedrank 处理并列值）
	rk = tiedrank(d.PreEz);
	bin = ceil(rk ./ (numel(rk) / 3));
	bin(bin > 3) = 3; bin(bin < 1) = 1;
	if numel(unique(bin)) < 3, continue; end
	r = nan(1,3); nn = zeros(1,3);
	for k = 1:3
		m2 = bin == k;
		nn(k) = sum(m2);
		if nn(k) > 0, r(k) = mean(d.Y(m2)); end
	end
	terc{end+1} = builtin('struct', 'Mouse', mice(i), 'R', r, 'N', nn); %#ok<AGROW>
	fprintf('%-9s | %6d %7.3f %6d %7.3f %6d %7.3f | %+8.3f\n', mice(i), ...
		nn(1), r(1), nn(2), r(2), nn(3), r(3), r(3)-r(1));
end
if numel(terc) >= 6
	% 显式装配 nMouse x 3 矩阵（cell2mat 会把行 cell 横向拼接成 1x3n，故不用）
	Rm = zeros(numel(terc), 3);
	for k = 1:numel(terc)
		Rm(k, :) = terc{k}.R(:).';
	end
	RmAll = Rm;
	Rm = Rm(all(isfinite(Rm), 2), :);         % 含 NaN（某档命中率不可算）的鼠剔除
	if size(Rm, 1) < 6
		fprintf('  可用鼠数不足（%d/%d），跳过三档检验\n', size(Rm, 1), size(RmAll, 1));
	else
		S.PFriedman = friedman(Rm, 1, 'off');
		fprintf('  Friedman（三档重复测量，n=%d 鼠）p=%.4g\n', size(Rm, 1), S.PFriedman);
		dHL = Rm(:, 3) - Rm(:, 1);
		[pHL, hHL] = signrank(Rm(:, 3), Rm(:, 1));
		fprintf('  high vs low：%.3f vs %.3f，风险差中位 %+.3f，Wilcoxon p=%.4g %s\n', ...
			mean(Rm(:, 3)), mean(Rm(:, 1)), median(dHL), pHL, iif(hHL==1,'(显著)','(不显著)'));
		S.PTerc = pHL; S.RD = median(dHL);
		nAbove = sum(dHL > 0);
		pB = min(1, 2 * min(binocdf(nAbove, numel(dHL), 0.5), 1 - binocdf(nAbove - 1, numel(dHL), 0.5)));
		fprintf('  方向一致性：%d/%d 鼠 high>low，双侧符号 p=%.4g\n', nAbove, numel(dHL), pB);
	end
end

fprintf('\n---- (3b) 无模型 2×2 交互检验：鼠内中位数二分 状态×驱动，不依赖 link 函数 ----\n');
% 概率尺度用风险差之差 ΔRD =（高高−高低）−（低高−低低）；
% odds 尺度用 ΔlogOR = log(OR高高·OR低低 / (OR低高·OR高低))。
% 两者同时近零 → 无论把两因素理解为"概率可加"还是"odds 可乘"，都不存在门控。
spDef = {'CueEz','原始线索诱发 CueE（未正交化，格子会失衡）'; 'CueRz','正交化驱动增量 CueR（格子平衡）'};
for si = 1:size(spDef,1)
	t2cn = spDef{si,1};
	t2RD = nan(numel(mice),1);  t2LOR = nan(numel(mice),1);  t2H = nan(numel(mice),4);  t2CNT = zeros(numel(mice),4);
	for i = 1:numel(mice)
		t2msk = okAll & Dat.Mouse == mice(i) & isfinite(Dat.(t2cn));
		if sum(t2msk) < 12, continue; end
		hs = Dat.PreEz(t2msk) > median(Dat.PreEz(t2msk));
		hc = Dat.(t2cn)(t2msk) > median(Dat.(t2cn)(t2msk));
		t2g = hs*2 + hc + 1;        % 1=低状态低驱动 2=低状态高驱动 3=高状态低驱动 4=高状态高驱动
		t2y = Dat.Y(t2msk);  t2k = histcounts(t2g, 0.5:1:4.5);   % 1×4，各格 trial 数
		t2h = nan(1,4);
		for t2q = 1:4
			t2s = t2g == t2q;
			if any(t2s), t2h(t2q) = mean(t2y(t2s)); end
		end
		if ~all(isfinite(t2h)), continue; end
		t2H(i,:) = t2h;  t2CNT(i,:) = t2k;
		t2RD(i) = (t2h(4)-t2h(3)) - (t2h(2)-t2h(1));
		t2od = (t2h + 0.5) ./ (1 - t2h + 0.5);   % 连续性校正，避免 0/1 命中率导致 OR 无定义
		t2LOR(i) = log(t2od(4)*t2od(1) / (t2od(3)*t2od(2)));
	end
	t2ok = isfinite(t2RD);  t2n = sum(t2ok);
	if t2n < 6
		fprintf('  %s：可用鼠 %d < 6，跳过。\n', spDef{si,2}, t2n);
		continue;
	end
	t2mH = mean(t2H(t2ok,:), 1);
	drvLo = t2mH(2)-t2mH(1);  drvHi = t2mH(4)-t2mH(3);
	stLo  = t2mH(3)-t2mH(1);  stHi  = t2mH(4)-t2mH(2);
	fprintf('  --- 二分变量 = %s（n=%d 鼠）---\n', spDef{si,2}, t2n);
	fprintf('      鼠均命中率  低状态·低驱动 %.3f | 低状态·高驱动 %.3f | 高状态·低驱动 %.3f | 高状态·高驱动 %.3f\n', ...
		t2mH(1), t2mH(2), t2mH(3), t2mH(4));
	fprintf('      驱动跨度：低状态 %+.3f，高状态 %+.3f  →  差 %+.4f\n', drvLo, drvHi, drvHi-drvLo);
	fprintf('      状态跨度：低驱动 %+.3f，高驱动 %+.3f  →  差 %+.4f\n', stLo, stHi, stHi-stLo);
	[t2pRD, t2hRD] = signrank(t2RD(t2ok));
	[t2pOR, t2hOR] = signrank(t2LOR(t2ok));
	fprintf('      概率尺度交互 ΔRD：中位 %+.3f，均值 %+.3f ± %.3f，正号 %d/%d，Wilcoxon p=%.4g %s\n', ...
		median(t2RD(t2ok)), mean(t2RD(t2ok)), std(t2RD(t2ok))/sqrt(t2n), sum(t2RD(t2ok)>0), t2n, t2pRD, iif(t2hRD==1,'(显著)','(不显著)'));
	fprintf('      odds 尺度交互 ΔlogOR：中位 %+.3f，正号 %d/%d，Wilcoxon p=%.4g %s\n', ...
		median(t2LOR(t2ok)), sum(t2LOR(t2ok)>0), t2n, t2pOR, iif(t2hOR==1,'(显著)','(不显著)'));
	if si == 2
		S.P2x2RD = t2pRD; S.P2x2OR = t2pOR; S.MedRD2x2 = median(t2RD(t2ok));
		S.DriveSpanLo = drvLo; S.DriveSpanHi = drvHi; S.StateSpanLo = stLo; S.StateSpanHi = stHi;
		fprintf('      格子样本量中位（低低/低高/高低/高高）：%s\n', mat2str(round(median(t2CNT(t2ok,:),1))));
	end
end

fprintf('\n---- (4) 细胞级特异性：point-biserial r(preZ, y) 的组间差 + 鼠内置换 ----\n');
if ~isempty(Rep.cells)
	obs = []; 
	for i = 1:numel(Rep.cells)
		C = Rep.cells{i};
		r = C.RPre; g = C.Group;
		re = r(g == "early"); rn = r(g == "none");
		if numel(re) >= 5 && numel(rn) >= 5 && any(isfinite(re)) && any(isfinite(rn))
			obs(end+1) = median(re, 'omitnan') - median(rn, 'omitnan'); %#ok<AGROW>
			fprintf('  %-9s early r中位 %+.3f (n=%d) | none r中位 %+.3f (n=%d) | 差 %+.3f\n', ...
				C.Mouse, median(re,'omitnan'), numel(re), median(rn,'omitnan'), numel(rn), obs(end));
		end
	end
	if numel(obs) >= 2
		nullMean = zeros(P.nPermCell, 1);
		for ip = 1:P.nPermCell
			dd = 0; cnt = 0;
			for i = 1:numel(Rep.cells)
				C = Rep.cells{i};
				r = C.RPre; g = C.Group;
				okG = ismember(g, ["early","none"]);
				if sum(okG) < 10, continue; end
				lab = g(okG); rr = r(okG);
				permLab = lab(randperm(numel(lab)));
				re = rr(permLab == "early"); rn = rr(permLab == "none");
				if ~any(isfinite(re)) || ~any(isfinite(rn)), continue; end
				dd = dd + median(re, 'omitnan') - median(rn, 'omitnan');
				cnt = cnt + 1;
			end
			if cnt > 0, nullMean(ip) = dd / cnt; end
		end
		obsMean = mean(obs);
		pPerm = (sum(nullMean >= obsMean) + 1) / (P.nPermCell + 1);
		fprintf('  跨鼠平均差 %+.3f，鼠内置换（%d 次）单侧 p=%.4g\n', obsMean, P.nPermCell, pPerm);
		nAbove2 = sum(obs > 0);
		pB2 = 1 - binocdf(nAbove2 - 1, numel(obs), 0.5);
		fprintf('  方向一致：%d/%d 鼠 early 的 r 中位数高于 none，sign p=%.4g\n', nAbove2, numel(obs), pB2);
		S.PCell = pPerm; S.MedDiffCell = obsMean;
	end
	% 线索诱发窗（cueZ）的同样比较，用于区分"状态"与"诱发反应"的组间选择性
	fprintf('  对照：r(cueZ, y) 组间差\n');
	for i = 1:numel(Rep.cells)
		C = Rep.cells{i};
		r = C.RCue; g = C.Group;
		re = r(g == "early"); rn = r(g == "none");
		if numel(re) >= 5 && numel(rn) >= 5 && any(isfinite(re)) && any(isfinite(rn))
			fprintf('    %-9s early %+.3f | none %+.3f | 差 %+.3f\n', C.Mouse, ...
				median(re,'omitnan'), median(rn,'omitnan'), median(re,'omitnan')-median(rn,'omitnan'));
		end
	end
end

fprintf('\n---- (5) Holm-Bonferroni 校正（主检验 7 项）----\n');
nm = ["M1 preE 主效应", "M2 preE×cueE 交互", "M3 正交化驱动交互", "2×2 ΔRD 概率尺度交互", ...
	"2×2 ΔlogOR odds尺度交互", "三分位 high-low", "细胞级组间差置换"];
pv = [S.PM1Pre, S.PM2Inter, S.PM3Inter, S.P2x2RD, S.P2x2OR, S.PTerc, S.PCell];
pvH = iHolm(pv);
for k = 1:numel(nm)
	if isfinite(pvH(k))
		fprintf('  %-22s 原始 p=%.4g → 校正 p=%.4g %s\n', nm(k), pv(k), pvH(k), ...
			iif(pvH(k) < 0.05, '(显著)', '(不显著)'));
	else
		fprintf('  %-22s 未获得\n', nm(k));
	end
end
S.PHolm = pvH;
end

function pH = iHolm(p)
% Holm-Bonferroni 校正（NaN 位置保留为 NaN，有效项数参与校正）
pH = p;
ok = isfinite(p);
n = sum(ok);
if n < 2, return; end
[srt, ord] = sort(p(ok));
srt = srt(:);
mult = (n - (0:n-1))';
adj = min(cummax(mult .* srt), 1);
q = nan(n, 1);
q(ord(:)) = adj;
pH(ok) = q.';
end

function s = iif(c, a, b)
if c, s = a; else, s = b; end
end

function R = iFitGLME(tbl, formula, mtitle)
% 拟合混合效应 logistic 回归（鼠随机截距）并打印固定效应；失败返回 []
R = [];
try
	% FitMethod='laplace'：默认 mpl 用伪似然，其 LogLikelihood 跨模型不可比，
	% 用它做 LRT 会给出假阳性（本数据 Naive 交互曾误报 p=0.004，Laplace 下 p=0.135）。
	mdl = fitglme(tbl, formula, 'Distribution', 'binomial', 'FitMethod', 'laplace');
catch ME
	fprintf('  %s 拟合失败：%s\n', mtitle, ME.message);
	return;
end
[C, nm] = iFE(mdl);
if numel(nm) ~= numel(C.Estimate)
	fprintf('  %s 系数名与估计值数量不符，跳过。\n', mtitle);
	return;
end
fprintf('  %s 固定效应：\n', mtitle);
for k = 1:numel(nm)
	fprintf('    %-16s β=%+.3f (SE %.3f) OR=%.2f  p=%.4g\n', nm(k), ...
		C.Estimate(k), C.SE(k), exp(C.Estimate(k)), C.pValue(k));
end
R = builtin('struct', 'names', nm, 'est', C.Estimate(:).', 'se', C.SE(:).', 'pv', C.pValue(:).', ...
	'll', mdl.LogLikelihood, 'aic', mdl.ModelCriterion.AIC, 'mdl', mdl);
end

function [C, nm] = iFE(mdl)
% 兼容两种系数容器：
%   fitglme → Coefficients 为 titleddataset（名称在 Name 列；本版本无 varnames 函数）
%   fitglm  → Coefficients 为 table（名称在 Properties.RowNames）
C = mdl.Coefficients;
nm = strings(0);
try
	nm = string(C.Name(:));
catch
end
if isempty(nm)
	try
		nm = string(C.Properties.RowNames(:));
	catch
	end
end
if isempty(nm)
	try
		nm = string(mdl.CoefficientNames(:));
	catch
	end
end
end

function v = iPick(R, termName)
% 按名取回归系数；找不到时打印可用名并返回 NaN（避免静默给出错误结论）
termName = string(termName);
v = builtin('struct', 'est', NaN, 'se', NaN, 'pv', NaN);
i = find(R.names == termName, 1);
if isempty(i)
	fprintf('    [提示] 未找到系数 "%s"；可用：%s\n', termName, strjoin(R.names, ', '));
	return;
end
v.est = R.est(i);
v.se = R.se(i);
v.pv = R.pv(i);
end
