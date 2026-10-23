%% EarlyOnsetCells_LickPrediction.m
% 问题：early-onset 细胞能否显著预测"一波舔水(movement bout)即将发生"，即高于随机水平？
%
% 判据不是"这些细胞在 bout 前有反应"（那正是它们被挑出来的原因，属循环论证），而是
% **留出事件的真泛化**：把每个孤立 bout 前的短时窗当正样本，把同一批 trial 内
% "时间-from-cue 分布匹配、但前后 0.6~1.5 s 无任何舔水 activity"的静息窗当负样本，
% 用 5 折 CV 训练 LASSO logistic 解码器，报告 out-of-fold AUC；置换 null 打乱窗口标签
% 跑同一条完整流水线；并在每折内部用"仅该折训练事件"重新做 early/late-onset 判定，
% 从而消除细胞选择与检验事件之间的循环。
%
% 负样本（surrogate 窗口）设计：
%   - 只在"含至少一个孤立 bout"的 trial 内取（within-trial 匹配），排除 trial 级状态差异
%   - time-from-cue 与正样本一一配对（按经验分布最近邻取样，且不重复使用）
%   - 该时刻前后 [−0.6, +1.5] s 内不得有任何 licking（与 onset 分析的 movement 锁定窗一致）
%
% 细胞组（每折内重新判定，除 earlyFixed/lateFixed 外）：
%   early   = 该折训练事件重判得到的 early-onset 细胞（主检验，无循环）
%   late    = 同折重判的 late-onset 细胞（对照：bout 后才激活）
%   active  = 同折重判的 movement-active（early ∪ late）
%   other   = 同折重判的非 movement-active 细胞（对照）
%   all     = 全部记录到的细胞（对照）
%   earlyFixed / lateFixed = 用全部事件的跨-movement 平均 PSTH 一次性判定（旧口径，含循环，仅对照）
%
% lead-time 扫描：解码特征窗改为 [−(L+0.2), −L] s（L = 提前量），L 从 0.1 到 1.3 s，
% 看"提前多久仍可显著预测"。
%
% 统计层级：per block AUC → 按鼠取均值 → 鼠水平 sign test / Wilcoxon 对 0.5 检验
% （block 内 event 不独立，鼠内 block 亦不独立，故以鼠为单位推断）。
%
% 数据与检测口径完全沿用 英文图/EarlyOnsetCells_LickLocked_Analysis.m：
%   ALDelayed、AudioLearnWater/LightLearnWater 块、原生帧率以 DS.DateTimes.SeriesInterval 为准、
%   CD2 孤立 bout 检测（前 isoWindow=1 s 无舔水）、cue 前基线 ΔF/F ZScore。
%   注意本工程用 ΔF/F 而非文献的反卷积 spike，钙动力学滞后使 early-onset 被低估、
%   且 pre-bout 幅度被压小 → 预测力属保守估计。
%
% Output:
%   - 缓存（TransferLearning.CachePath）：EarlyOnsetCells_LickPrediction_Results.mat
%     .Blk     每 block 的 AUC / 置换 p / 事件数 / 细胞组规模（不含原始张量）
%     .Mouse   按鼠聚合的 AUC（主推断层）
%     .P       参数
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

%% ---- 0. 参数 ----
thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

P = struct();
% 沿用 EarlyOnsetCells_LickLocked_Analysis.m 的检测口径
P.minNSm     = 40;              % 每 trial 原生样本数下限
P.isoWindow  = 1.0;             % 孤立 bout：其前该窗内无舔水（文献 = 1 s）
P.lickMargin = 35;              % CD2 舔水阈 = 每 trial 稳健基线 + 此值
P.tPwin      = [-1.5, 2.0];     % lick 锁定 PSTH 网格（与分析脚本一致）
P.baseline   = [-1.0, -0.5];    % 基线窗（文献）
P.detWin     = [-0.2, 1.5];     % onset 搜索窗（文献：bout 前 0.2 s → bout 结束）
P.sustain    = 0.2;             % onset 持续判据（文献 200 ms）
P.minTrials  = 10;              % block 最少可用 trial 数
P.dtFine     = 0.005;           % onset 判定的上采样网格（200 Hz）
P.lackWin    = [-0.6, 1.5];     % surrogate 时刻前后的"无舔水"要求
% 预测检验口径
P.fsMin      = 12;              % 只用 hi-res 15.2 Hz session（低采样下早发窗仅 ~1.6 样本）
P.minEvents  = 20;              % block 最少孤立 bout 数（否则 CV 与置换都不稳）
P.preWin     = [-0.4, -0.1];    % 主特征窗：bout 前 0.4~0.1 s（避开 onset 帧本身）
P.leads      = 0.1 : 0.15 : 1.3;% lead-time 扫描的提前量（s）
P.leadWin    = 0.2;             % 扫描用的特征窗宽（s）
P.lamRule    = 0.02;            % LASSO lambda = lamRule/sqrt(2*nSample)（Fig3D 规则）
P.K          = 5;               % CV 折数（按事件配对分折：正样本与其 surrogate 同折）
P.nPerm      = 200;             % 置换次数（p 分辨率 1/201）
% 只对关键组做 block 级置换 null（主要推断是跨 session 的 AUC vs 0.5，无需全组置换）
P.permSets   = ["early", "late", "other", "otherMatched", "all"];
P.seed       = 42;
P.setNames   = ["early", "late", "active", "other", "otherMatched", "all", "earlyFixed", "lateFixed"];
P.useParfor  = true;            % 置 false 可串行解码，便于定位错误堆栈
P.cacheDir   = fullfile(thisDir, '..', 'Temp', 'LickPred_BlkCache');  % 绝对路径：run 会切 cwd，避免写到 英文图\Temp
if ~exist(P.cacheDir, 'dir'), mkdir(P.cacheDir); end
nSet = numel(P.setNames);
nLead = numel(P.leads);

fprintf('=== early-onset 细胞能否预测即将到来的舔水 bout（ALDelayed, hi-res）===\n');
fprintf('正窗 = bout 前 [%.2f, %.2f] s；负窗 = within-trial 时间匹配且前后 [%.1f, %.1f] s 无舔水\n', ...
	P.preWin(1), P.preWin(2), P.lackWin(1), P.lackWin(2));
fprintf('%d-fold CV（折内重判 early/late，去循环）；置换 %d 次；要求 fs>%.0f Hz 且 nEvent>=%d\n', ...
	P.K, P.nPerm, P.fsMin, P.minEvents);

%% ---- 1. block 枚举（与分析脚本一致）----
DS = TransferLearning.ALDelayed();
warning('off', 'UniExp:Exception:Block_must_warn');
Tr = DS.Trials; Tr.Stimulus = string(Tr.Stimulus);
sr = Tr.SampleRange;
Sd = double(sr.Start); Ed = double(sr.End); Td = double(sr.Tag);
bs = DS.BlockSignals;

T = DS.TableQuery(["Mouse","DateTime","BlockUID","Stimulus"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus); T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone), T.DateTime.TimeZone = ''; end
lw = T(ismember(T.Stimulus, ["AudioLearnWater","LightLearnWater"]), :);
blk = unique(lw(:, ["Mouse","DateTime","BlockUID","Stimulus"]), 'stable');
blk = sortrows(blk, ["Mouse","DateTime"]);

SIall = seconds(DS.DateTimes.SeriesInterval);
DTall = DS.DateTimes.DateTime;
if ~isempty(DTall.TimeZone), DTall.TimeZone = ''; end
MallSess = string(DS.DateTimes.Mouse);

%% ---- 2. 逐 block 串行提取（张量小，后续并行只做解码）----
blkData = cell(height(blk), 1);
nKept = 0;
fprintf('\n---- 提取 ----\n');
for bi = 1:height(blk)
	D = iExtractBlock(blk, bi, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P);
	if isempty(D)
		continue;
	end
	if D.fs <= P.fsMin || D.nEv < P.minEvents
		fprintf('blk%-3d %s fs=%.1f nEv=%2d -> 跳过（fs 或事件数不足）\n', ...
			D.BlockUID, D.Mouse, D.fs, D.nEv);
		continue;
	end
	nKept = nKept + 1;
	blkData{nKept} = D;
	fprintf('blk%-3d %s %-16s fs=%.1f nC=%3d nEv=%2d nSur=%2d | tc(from cue) ev %.2f±%.2f sur %.2f±%.2f s\n', ...
		D.BlockUID, D.Mouse, string(D.Stimulus), D.fs, D.nC, D.nEv, D.nSur, ...
		mean(D.tcEv), std(D.tcEv), mean(D.tcSur), std(D.tcSur));
end
blkData = blkData(1:nKept);
if isempty(blkData)
	error('LickPrediction:NoBlocks', '没有满足 fs>%.0f 且 nEvent>=%d 的 block。', P.fsMin, P.minEvents);
end
blkArr = [blkData{:}];                       % 结构体数组：便于按字段汇总，也便于 parfor 切片
blkArr = blkArr(:);
nB = numel(blkArr);
clear blkData;
fprintf('可用 block：%d（%d 只鼠，%d 个事件对）\n', nB, ...
	numel(unique([blkArr.Mouse])), sum([blkArr.nEv]));

%% ---- 3. 逐 block 解码（并行 + 落盘缓存）----
% 先串行查缓存（避免重算），未命中的 block 用 parfor 并行计算（worker 可调用本脚本局部函数）。
Blk = cell(nB, 1);
todoIdx = zeros(1, nB);
nTodo = 0;
for ib = 1:nB
	Blk{ib} = iLoadBlkCache(P.cacheDir, blkArr(ib), P);
	if ~isempty(Blk{ib})
		fprintf('  blk%-4d %-8s 命中缓存\n', blkArr(ib).BlockUID, blkArr(ib).Mouse);
		continue;
	end
	nTodo = nTodo + 1;
	todoIdx(nTodo) = ib;
end
todoIdx = todoIdx(1:nTodo);
if nTodo > 0
	Arr = blkArr(todoIdx);                       % 可切片的子结构体数组
	clear blkArr;                                % 张量已复制到 Arr，释放余下副本
	t1 = tic;
	Res = cell(nTodo, 1);
	if P.useParfor
		if isempty(gcp('nocreate')), parpool('local'); end
		fprintf('\n并行解码 %d 个 block（%d workers）...\n', nTodo, gcp('nocreate').NumWorkers);
		parfor it = 1:nTodo
			rng(P.seed + Arr(it).BlockUID);
			Res{it} = iDecodeBlock(Arr(it), P);
		end
	else
		fprintf('\n串行解码 %d 个 block...\n', nTodo);
		for it = 1:nTodo
			rng(P.seed + Arr(it).BlockUID);
			Res{it} = iDecodeBlock(Arr(it), P);
		end
	end
	fprintf('解码完成，共 %.1f s\n', toc(t1));
	for it = 1:nTodo
		Blk{todoIdx(it)} = Res{it};
		iSaveBlkCache(P.cacheDir, Arr(it), P, Res{it});
	end
end
clear blkArr Arr Res;
nDone = sum(~cellfun(@isempty, Blk));
if nDone < nB
	fprintf('\n仅完成 %d/%d 个 block，汇总以已完成者为准。\n', nDone, nB);
	keepBlk = ~cellfun(@isempty, Blk);
	Blk = Blk(keepBlk);
	nB = nDone;
end

% ---- 汇总为表 ----
aucBlk = nan(nB, nSet);            % 主窗 AUC（block x cell set）
pBlk   = nan(nB, nSet);            % 置换 p
nEvB   = nan(nB, 1);
nCellB = nan(nB, nSet);
aucLead = nan(nB, nLead, 3);       % lead 扫描：early / late / all
fracSigB = nan(nB, nSet);          % 折外逐细胞预测显著比例
mouseB  = strings(nB, 1);
blkUidB = nan(nB, 1);
stimB = strings(nB, 1);
for ib = 1:nB
	B = Blk{ib};
	aucBlk(ib, :) = B.auc;
	pBlk(ib, :) = B.pPerm;
	nEvB(ib) = B.nEv;
	nCellB(ib, :) = B.nCells;
	aucLead(ib, :, :) = B.aucLead;
	fracSigB(ib, :) = B.fracSig;
	mouseB(ib) = string(B.Mouse);
	blkUidB(ib) = B.BlockUID;
	stimB(ib) = string(B.Stimulus);
end

fprintf('\n---- 主窗（bout 前 %.1f~%.1f s）：per block（AUC，括号内置换 p×1000）----\n', P.preWin(1), P.preWin(2));
fprintf('%-9s %-4s %5s | %s\n', 'mouse', 'blk', 'nEv', strjoin(compose('%-11s', P.setNames), ' '));
for ib = 1:nB
	fprintf('%-9s %-4d %5d | %s\n', mouseB(ib), Blk{ib}.BlockUID, nEvB(ib), ...
		strjoin(iFmtAucP(aucBlk(ib, :), pBlk(ib, :)), ' '));
end

% ---- 主推断：session 水平（本库 hi-res 仅 2 只鼠，故以 session 为单元，与原图 panel C 口径一致）----
fprintf('\n---- session 水平推断（n=%d 个 session，%s）----\n', nB, ...
	strjoin(unique(mouseB)', ' + '));
ums = unique(mouseB);
for s = 1:nSet
	v = aucBlk(:, s);
	ok = isfinite(v);
	nAbove = sum(v(ok) > 0.5);
	pBin = 1 - binocdf(nAbove - 1, sum(ok), 0.5);
	pW = NaN;
	if sum(ok) >= 6 && ~all(v(ok) == 0.5), pW = signrank(v(ok) - 0.5); end
	fprintf('%-11s AUC = %.3f ± %.3f (range %.3f–%.3f) | >0.5: %d/%d, sign p=%.2g, Wilcoxon p=%.2g | 置换显著 %d/%d | 细胞数中位 %d | 逐细胞预测显著 %.1f%%\n', ...
		P.setNames(s), mean(v(ok)), iSem(v(ok)), min(v(ok)), max(v(ok)), nAbove, sum(ok), pBin, pW, ...
		sum(pBlk(ok, s) < 0.05), sum(ok), median(nCellB(ok, s), 'omitnan'), ...
		100 * mean(fracSigB(ok, s), 'omitnan'));
end

% ---- 鼠水平（稳健性检查；仅 2 只鼠，不做检验）----
fprintf('\n---- 鼠水平均值（稳健性检查，n=%d 鼠，不作假设检验）----\n', numel(ums));
Mouse = table();
for i = 1:numel(ums)
	sel = mouseB == ums(i);
	Mouse = [Mouse; table(ums(i), sum(sel), mean(aucBlk(sel, :), 1, 'omitnan'), ...
		mean(nEvB(sel)), 'VariableNames', {'Mouse','nBlock','AUC','nEvMean'})]; %#ok<AGROW>
end
fprintf('%-9s %6s %6s | %s\n', 'mouse', 'nBlk', 'nEv', strjoin(compose('%-11s', P.setNames), ' '));
for i = 1:height(Mouse)
	fprintf('%-9s %6d %6.0f | %s\n', Mouse.Mouse(i), Mouse.nBlock(i), Mouse.nEvMean(i), ...
		strjoin(compose('%.3f', Mouse.AUC(i, :).'), ' '));
end

% ---- early vs 对照组：按 session 配对 ----
iEarly = find(P.setNames == "early", 1);
fprintf('\n---- early 与其他细胞组按 session 配对比较 ----\n');
for cmpName = ["late", "active", "other", "otherMatched", "all"]
	iC = find(P.setNames == cmpName, 1);
	a = aucBlk(:, iEarly); b = aucBlk(:, iC);
	ok = isfinite(a) & isfinite(b);
	if sum(ok) >= 6
		[pC, hC] = signrank(a(ok), b(ok));
		fprintf('early vs %s（n=%d session）：%.3f vs %.3f，Wilcoxon p=%.4g %s\n', ...
			cmpName, sum(ok), mean(a(ok)), mean(b(ok)), pC, iif(hC == 1, '(不同)', '(相同)'));
	else
		fprintf('early vs %s：session 数不足（%d），跳过检验\n', cmpName, sum(ok));
	end
end

fprintf('\n---- lead-time 扫描（特征窗 [−(L+%.1f), −L] s，session 水平）----\n', P.leadWin);
fprintf('%5s | %-21s %-21s %-21s\n', 'L(s)', 'early', 'late', 'all');
for k = 1:nLead
	line = sprintf('%5.2f |', P.leads(k));
	for g = 1:3
		x = squeeze(aucLead(:, k, g));
		x = x(isfinite(x));
		line = [line sprintf(' %.3f±%.3f %2d/%2d*', mean(x), iSem(x), ...
			sum(x > 0.5), numel(x))]; %#ok<AGROW>
	end
	fprintf('%s   (* = AUC>0.5 的 session 数)\n', line);
end
% 最远可显著预测的提前量
mEbyL = zeros(nLead, 1);
for k = 1:nLead
	mEbyL(k) = mean(squeeze(aucLead(:, k, 1)), 'omitnan');
end
sigL = P.leads(mEbyL > 0.5);
if ~isempty(sigL)
	fprintf('early 组 session 平均 AUC > 0.5 的最远提前量：%.2f s（峰值 AUC %.3f @ L=%.2f s）\n', ...
		max(sigL), max(mEbyL), P.leads(find(mEbyL == max(mEbyL), 1)));
else
	fprintf('early 组没有任何提前量的 session 平均 AUC 超过 0.5。\n');
end

%% ---- 4. 缓存 ----
matPath = TransferLearning.CachePath('EarlyOnsetCells_LickPrediction_Results.mat');
save(matPath, 'Blk', 'Mouse', 'aucBlk', 'pBlk', 'nEvB', 'nCellB', 'aucLead', ...
	'fracSigB', 'mouseB', 'blkUidB', 'stimB', 'P');
fprintf('\n缓存已写入: %s\n', matPath);
assignin('base', 'LickPred_Blk', Blk);
assignin('base', 'LickPred_Mouse', Mouse);
assignin('base', 'LickPred_P', P);

%% ========== local functions ==========
function D = iExtractBlock(blk, bi, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P)
% 复现 EarlyOnsetCells_LickLocked_Analysis.m 的逐 block 提取，但保留单事件张量。
D = [];
buid = blk.BlockUID(bi);
selT0 = find(Tr.BlockUID == buid & ismember(Tr.Stimulus, ["AudioLearnWater","LightLearnWater"]));
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
tAx1 = ((0:nSmB-1)' / fs) - (cueIdxB-1) / fs;      % cue @ t=0
tP = (P.tPwin(1) : 1/fs : P.tPwin(2))';
nTP = numel(tP);
preMask = tAx1 < -0.02;                            % cue 前基线样本
Starts = Sd(selT); IDX = Starts + (0:nSmB-1);

% ---- CD2 舔水检测（与分析脚本一律）----
lickMat = false(nTr, nSmB);
lickT = nan(nTr, 1);
isoP = zeros(nTr, 1);          % 孤立 bout 的样本位（trial 内）
for j = 1:nTr
	cd2 = double(Tr.TrialTags{selT(j)}.CD2); cd2 = cd2(:)';
	low = cd2(cd2 < prctile(cd2, 60));
	thr = median(low) + P.lickMargin;
	licking = cd2 > thr;
	rise = licking & ~[false, licking(1:end-1)];
	cand = find(rise);
	cand = cand(tAx1(cand) >= -0.1);            % 只取 cue 之后的上升沿
	for p = cand
		pre = max(1, p - round(P.isoWindow * fs)) : p - 1;
		if ~any(licking(pre))
			lickT(j) = tAx1(p);
			isoP(j) = p;
			break;
		end
	end
	if isoP(j) == 0 && ~isempty(cand)
		lickT(j) = tAx1(cand(1));                % 与分析脚本同：非孤立也记（但不作为事件）
	end
	lickMat(j, :) = licking;
end
isoTr = find(isoP > 0);
nEv = numel(isoTr);

ub = bs(bs.BlockUID == buid, :);
nC = height(ub);
cellUID = uint64(ub.CellUID);
if nEv == 0 || nC == 0
	return;
end
pEv = isoP(isoTr);
tcEv = tAx1(pEv);                                % 事件相对 cue 的时刻

% ---- 负样本：within-trial 时间匹配且前后无舔水的静息窗 ----
winEdge = round((0.45 + P.lackWin(2)) * fs) + 2;
lackLo = round(P.lackWin(1) * fs);               % 负数
lackHi = round(P.lackWin(2) * fs);
% 候选池：仅在"有事件"的 trial 内（within-trial 对照）
candJ = []; candP = []; candT = [];
for j = isoTr'
	lick = lickMat(j, :);
	cs = winEdge : (nSmB - winEdge);
	if isempty(cs); continue; end
	free = false(1, numel(cs));
	for i = 1:numel(cs)
		lo = max(1, cs(i) + lackLo);
		hi = min(nSmB, cs(i) + lackHi);
		free(i) = ~any(lick(lo:hi));
	end
	if ~any(free); continue; end
	cs = cs(free);
	candJ = [candJ, repmat(j, 1, numel(cs))]; %#ok<AGROW>
	candP = [candP, cs]; %#ok<AGROW>
	candT = [candT, tAx1(cs).']; %#ok<AGROW>   % tAx1 为列向量，转成行拼接
end
nSur = min(nEv, numel(candP));
if nSur < P.minEvents
	return;
end
% greedy 1-1 匹配：按 tc 排序后每个事件取最近的未被用候选
[~, ord] = sort(tcEv);
[~, ordC] = sort(candT);
candT = candT(ordC); candJ = candJ(ordC); candP = candP(ordC);
used = false(numel(candT), 1);
pSur = zeros(nEv, 1); jSur = zeros(nEv, 1); tcSur = nan(nEv, 1);
for k = 1:nEv
	i = ord(k);
	best = 0; bd = inf;
	st = max(1, iSurSearch(candT, tcEv(i)) - 60);
	en = min(numel(candT), st + 120);
	for q = st:en
		if used(q); continue; end
		d = abs(candT(q) - tcEv(i));
		if d < bd, bd = d; best = q; end
	end
	if best == 0
		for q = 1:numel(candT)
			if used(q); continue; end
			used(q) = true;
			best = q;
			break;
		end
	else
		used(best) = true;
	end
	if best == 0, continue; end                  % 无可用候选：该事件作废
	jSur(i) = candJ(best);
	pSur(i) = candP(best);
	tcSur(i) = candT(best);
end
hasSur = jSur > 0;
if sum(hasSur) < P.minEvents
	return;
end
isoTr = isoTr(hasSur); pEv = pEv(hasSur);
tcEv = tcEv(hasSur); jSur = jSur(hasSur);
pSur = pSur(hasSur); tcSur = tcSur(hasSur);
nEv = numel(isoTr);
nSur = nEv;                                      % 一一配对

% ---- 相对事件/负样本的采样偏移 ----
dPre = round(P.preWin(1) * fs) : round(P.preWin(2) * fs);
nLead = numel(P.leads);
dLead = cell(nLead, 1);
for k = 1:nLead
	dLead{k} = round(-(P.leads(k) + P.leadWin) * fs) : round(-P.leads(k) * fs);
end
validEv = true(nEv, 1); validSur = true(nEv, 1);
for k = 1:nEv
	validEv(k) = all(pEv(k) + dPre >= 1 & pEv(k) + dPre <= nSmB);
	validSur(k) = all(pSur(k) + dPre >= 1 & pSur(k) + dPre <= nSmB);
end

% ---- lick 锁定 PSTH（仅孤立 bout，与分析脚本同口径）----
bmask = (tP >= P.baseline(1) & tP <= P.baseline(2));
Vev = zeros(nC, nEv, nTP);
MainEv = zeros(nC, nEv);
MainSur = zeros(nC, nEv);
LeadEv = zeros(nLead, nC, nEv);
LeadSur = zeros(nLead, nC, nEv);
for c = 1:nC
	sig = double(ub.BlockSignal{c});
	raw = sig(IDX');                              % nSmB x nTr
	b = mean(raw(preMask, :), 1);
	s = std(raw(preMask, :), 0, 1); s(s == 0) = nan;
	Zc = ((raw - b) ./ s)';                        % nTr x nSmB，cue 前基线 ZScore
	dOff = floor(tP.' * fs) + 1;                     % 1 x nTP 样本偏移
	pIdx = pEv(:) + dOff;                            % nEv x nTP
	sIdx = pSur(:) + dOff;
	okE = pIdx >= 1 & pIdx <= nSmB;
	okS = sIdx >= 1 & sIdx <= nSmB;
	Ve = nan(nEv, nTP); Vs = nan(nEv, nTP);
	for q = 1:nTP
		iiE = pIdx(:, q); iiE(~okE(:, q)) = 1;
		iiS = sIdx(:, q); iiS(~okS(:, q)) = 1;
		Ve(:, q) = Zc(sub2ind(size(Zc), isoTr(:), iiE(:)));
		Vs(:, q) = Zc(sub2ind(size(Zc), jSur(:), iiS(:)));
		Ve(~okE(:, q), q) = NaN; Vs(~okS(:, q), q) = NaN;
	end
	Vev(c, :, :) = reshape(Ve, 1, nEv, nTP);
	% 主特征窗：窗内均值 z
	% 注意 MATLAB 列主序：iE2(:) 沿"事件"维最快，故 trial 下标须用 repmat 而非 repelem
	nDP = numel(dPre);
	iE = pEv(:) + dPre;                            % nEv x nDP
	iS = pSur(:) + dPre;
	okE2 = iE >= 1 & iE <= nSmB;
	okS2 = iS >= 1 & iS <= nSmB;
	iE2 = iE; iE2(~okE2) = 1;
	iS2 = iS; iS2(~okS2) = 1;
	ze = reshape(Zc(sub2ind(size(Zc), repmat(isoTr(:), nDP, 1), iE2(:))), nEv, nDP);
	zs = reshape(Zc(sub2ind(size(Zc), repmat(jSur(:), nDP, 1), iS2(:))), nEv, nDP);
	ze(~okE2) = NaN; zs(~okS2) = NaN;
	MainEv(c, :) = mean(ze, 2, 'omitnan').';
	MainSur(c, :) = mean(zs, 2, 'omitnan').';
	for k = 1:nLead
		dL = dLead{k};
		nDL = numel(dL);
		iE3 = pEv(:) + dL; iS3 = pSur(:) + dL;    % nEv x nDL
		okE3 = iE3 >= 1 & iE3 <= nSmB;
		okS3 = iS3 >= 1 & iS3 <= nSmB;
		iE3(~okE3) = 1; iS3(~okS3) = 1;           % 越界样本先钳位，取值后置 NaN
		ze3 = reshape(Zc(sub2ind(size(Zc), repmat(isoTr(:), nDL, 1), iE3(:))), nEv, nDL);
		zs3 = reshape(Zc(sub2ind(size(Zc), repmat(jSur(:), nDL, 1), iS3(:))), nEv, nDL);
		ze3(~okE3) = NaN; zs3(~okS3) = NaN;
		LeadEv(k, c, :) = reshape(mean(ze3, 2, 'omitnan').', 1, 1, nEv);
		LeadSur(k, c, :) = reshape(mean(zs3, 2, 'omitnan').', 1, 1, nEv);
	end
end

% ---- “旧口径” early/late 标签（用全部事件的 PSTH，含循环，仅作对照）----
[isEarlyF, isLateF, hasOnF] = iOnsetLabels(Vev, tP, bmask, P);

D = struct();
D.BlockUID = buid; D.Mouse = blk.Mouse(bi); D.DateTime = blk.DateTime(bi);
D.Stimulus = blk.Stimulus(bi); D.fs = fs; D.nSmB = nSmB; D.cueIdxB = cueIdxB;
D.tP = tP; D.bmask = bmask; D.nC = nC; D.cellUID = cellUID;
D.nEv = nEv; D.nSur = nSur; D.tcEv = tcEv; D.tcSur = tcSur;
D.Vev = Vev; D.MainEv = MainEv; D.MainSur = MainSur;
D.LeadEv = LeadEv; D.LeadSur = LeadSur;
D.isEarlyFixed = isEarlyF; D.isLateFixed = isLateF; D.hasOnsetFixed = hasOnF;
D.validEv = validEv & validSur;
end

function p = iSurSearch(v, x)
% 升序向量 v 中最接近 x 的位置（用于限定匹配搜索窗）。
if isempty(v), p = 1; return; end
[~, p] = min(abs(v - x));
end

function [isEarly, isLate, hasOnset, onsetT] = iOnsetLabels(Vev, tP, bmask, P)
% 由（子集事件的）lick-PSTH 判定 movement-active / early / late，口径与分析脚本一致：
% baseline+1SD、跨基线窗单 trial SD 均值（singleTrial）、持续 200 ms、上采样 200 Hz。
[nC, ~, ~] = size(Vev);
V2 = permute(Vev, [1, 3, 2]);                    % nC x nTP x nEv
PSTH = mean(V2, 3, 'omitnan');
baseMean = mean(PSTH(:, bmask), 2, 'omitnan');   % bmask 为 nTP x 1 列逻辑
% singleTrial 口径：每个事件先算基线窗内跨时间的 SD，再对事件取均
sdPerEvent = std(V2(:, bmask', :), 0, 2, 'omitnan');
baseSD = squeeze(mean(sdPerEvent, 3, 'omitnan'));
dtFine = P.dtFine;
tFine = (P.detWin(1) : dtFine : P.detWin(2))';
nSus = max(2, round(P.sustain / dtFine));
maxStart = numel(tFine) - nSus + 1;
onsetT = nan(nC, 1);
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
end
hasOnset = isfinite(onsetT);
isEarly = hasOnset & onsetT < 0;
isLate = hasOnset & onsetT >= 0;
end

%% ========== 解码 ==========
function B = iDecodeBlock(D, P)
% 5 折 CV（事件与其 surrogate 同折）+ 折内重判细胞标签去循环 + 置换 null。
nC = D.nC;
nEv = D.nEv;
setNames = P.setNames;
nSet = numel(setNames);
permIdx = find(ismember(setNames, P.permSets));    % 仅这些组计算 block 级置换 p
nLead = numel(P.leads);
use = D.validEv(:);
nUse = sum(use);
B = struct('BlockUID', D.BlockUID, 'Mouse', D.Mouse, 'Stimulus', D.Stimulus, ...
	'fs', D.fs, 'nC', nC, 'nEv', nUse, 'auc', nan(1, nSet), 'pPerm', nan(1, nSet), ...
	'nCells', nan(1, nSet), 'aucLead', nan(nLead, 3), ...
	'tCell', nan(nSet, nC), 'pCell', nan(nSet, nC), ...
	'fracSig', nan(1, nSet), 'nCSet', nan(1, nSet));
if nUse < max(P.minEvents, P.K * 2)
	return;
end
% 折分配（仅用有效配对）
idxU = find(use);
permEv = idxU(randperm(nUse));
foldSeq = repmat(1:P.K, 1, ceil(nUse / P.K));
foldSeq = foldSeq(1:nUse);
foldOf = nan(nEv, 1);
foldOf(permEv) = foldSeq(:);
Xev = D.MainEv.';                                  % nEv x nC
Xsur = D.MainSur.';
Vev = D.Vev;

aucFold = nan(P.K, nSet);
nCellFold = nan(P.K, nSet);
setMasks = cell(P.K, 1);
% 折外逐细胞差值累积：每个细胞只统计"它被归入该组、且该事件属于检验折"的配对差
OofD = cell(nSet, 1);
for s = 1:nSet
	OofD{s} = nan(nEv, nC);
end
for k = 1:P.K
	tr = ~isnan(foldOf) & foldOf ~= k;
	if ~any(tr), continue; end
	% 折内重判（仅用该折训练事件）：切断细胞选择与检验事件的循环
	[isEarly, isLate, hasOn] = iOnsetLabels(Vev(:, tr, :), D.tP, D.bmask, P);
	setMasks{k} = iCellSets(isEarly, isLate, hasOn, D.isEarlyFixed, D.isLateFixed, nC);
	te = ~isnan(foldOf) & foldOf == k;
	if ~any(te), continue; end
	for s = 1:nSet
		ci = setMasks{k}{s};
		if numel(ci) < 5, continue; end
		nCellFold(k, s) = numel(ci);
		aucFold(k, s) = iFitAuc(Xev(tr, ci), Xsur(tr, ci), Xev(te, ci), Xsur(te, ci), P);
		OofD{s}(te, ci) = Xev(te, ci) - Xsur(te, ci);
	end
end
B.auc = iPoolFoldAuc(aucFold);
B.nCells = median(nCellFold, 1, 'omitnan');

% ---- 逐细胞证据（独立于解码器）：折外配对差值的 t 与符号置换 null ----
tCell = nan(nSet, nC);
pCell = nan(nSet, nC);
for s = 1:nSet
	Dd = OofD{s};
	if all(isnan(Dd(:))), continue; end
	[tCell(s, :), pCell(s, :)] = iPairedSignPerm(Dd, P.nPerm);
end
B.tCell = tCell;
B.pCell = pCell;
B.fracSig = nan(1, nSet);
B.nCSet = nan(1, nSet);
for s = 1:nSet
	pv = pCell(s, :);
	ok = isfinite(pv);
	B.nCSet(s) = sum(ok);
	if any(ok)
		B.fracSig(s) = sum(pv(ok) < 0.05) / sum(ok);
	end
end

% ---- lead-time 扫描（early / late / all）----
iEarlyS = find(setNames == "early", 1);
iLateS = find(setNames == "late", 1);
iAllS = find(setNames == "all", 1);
for q = 1:nLead
	Xe = squeeze(D.LeadEv(q, :, :)).';               % nEv x nC
	Xs = squeeze(D.LeadSur(q, :, :)).';
	aucL = nan(P.K, 3);
	for k = 1:P.K
		tr = ~isnan(foldOf) & foldOf ~= k;
		te = ~isnan(foldOf) & foldOf == k;
		if ~any(tr) || ~any(te) || isempty(setMasks{k}), continue; end
		mE = setMasks{k}{iEarlyS}; mL = setMasks{k}{iLateS}; mA = setMasks{k}{iAllS};
		aucL(k, 1) = iFitAuc(Xe(tr, mE), Xs(tr, mE), Xe(te, mE), Xs(te, mE), P);
		aucL(k, 2) = iFitAuc(Xe(tr, mL), Xs(tr, mL), Xe(te, mL), Xs(te, mL), P);
		aucL(k, 3) = iFitAuc(Xe(tr, mA), Xs(tr, mA), Xe(te, mA), Xs(te, mA), P);
	end
	B.aucLead(q, :) = iPoolFoldAuc(aucL);
end

% ---- 置换 null：对每对随机交换事件/negative 窗 ----
% 细胞集掩模沿用真实数据折内判定的结果（不重算）：这是偏保守的零分布，
% 因为掩模本身用了真实事件信息；主要推断仍以跨 session 的 AUC vs 0.5 符号检验为准。
nullAuc = nan(P.nPerm, nSet);
for ip = 1:P.nPerm
	sw = rand(nEv, 1) < 0.5;
	sel = use & ~isnan(foldOf);
	Xp = Xev; Xq = Xsur;
	Xp(sel & sw, :) = Xsur(sel & sw, :);
	Xq(sel & sw, :) = Xev(sel & sw, :);
	aucP = nan(P.K, nSet);
	for k = 1:P.K
		tr = ~isnan(foldOf) & foldOf ~= k;
		te = ~isnan(foldOf) & foldOf == k;
		if ~any(tr) || ~any(te) || isempty(setMasks{k}), continue; end
		for s = permIdx
			ci = setMasks{k}{s};
			if numel(ci) < 5, continue; end
			aucP(k, s) = iFitAuc(Xp(tr, ci), Xq(tr, ci), Xp(te, ci), Xq(te, ci), P);
		end
	end
	nullAuc(ip, :) = iPoolFoldAuc(aucP);
end
for s = permIdx
	if ~isfinite(B.auc(s)), continue; end
	v = nullAuc(:, s);
	v = v(isfinite(v));
	if isempty(v), continue; end
	B.pPerm(s) = (sum(v >= B.auc(s)) + 1) / (numel(v) + 1);
end
end

function masks = iCellSets(isEarly, isLate, hasOn, isEarlyF, isLateF, nC)
% 返回与 P.setNames 同序的细胞索引集合（顺序：early, late, active, other,
% otherMatched, all, earlyFixed, lateFixed）。
% otherMatched：从非活跃细胞中随机抽取与 early 等量的细胞，用于剖离“维度/细胞数”效应。
allCells = 1:nC;
active = find(hasOn);
early = find(isEarly);
other = setdiff(allCells, active);
nMatch = min(numel(early), numel(other));
if nMatch > 0
	otherMatched = other(randperm(numel(other), nMatch));
else
	otherMatched = other;
end
masks = {early, find(isLate), active, other, otherMatched, allCells, ...
	find(isEarlyF), find(isLateF)};
end

function auc = iFitAuc(XtrE, XtrS, XteE, XteS, P)
% 在训练折（事件 vs 匹配静息窗）上拟合 LASSO logistic，用训练折的 mu/sd 标准化测试折，
% 返回测试折的折外 AUC。训练与测试样本严格分离；标签 y 由行位置决定，不用得分符号。
if isempty(XtrE) || isempty(XtrS) || isempty(XteE) || isempty(XteS), auc = NaN; return; end
nTrE = size(XtrE, 1); nTrS = size(XtrS, 1);
nTeE = size(XteE, 1); nTeS = size(XteS, 1);
if nTrE < 3 || nTrS < 3 || nTeE < 2 || nTeS < 2, auc = NaN; return; end
Xtr = [XtrE; XtrS];
ytr = [ones(nTrE, 1); zeros(nTrS, 1)];
mu = mean(Xtr, 1, 'omitnan');
sd = std(Xtr, 0, 1, 'omitnan');
sd(~isfinite(sd) | sd == 0) = 1;
XtrS = (Xtr - mu) ./ sd;
XtrS(isnan(XtrS)) = 0;
lam = P.lamRule / sqrt(2 * nTrE);                    % 与 Fig3D 同规则（lasso 不可用 dual）
mdl = fitclinear(XtrS, ytr, 'Learner', 'logistic', 'Regularization', 'lasso', 'Lambda', lam);
Xte = [XteE; XteS];
XteS = (Xte - mu) ./ sd;
XteS(isnan(XteS)) = 0;
score = XteS * mdl.Beta + mdl.Bias;
yte = [ones(nTeE, 1); zeros(nTeS, 1)];
auc = iAuc(score(yte == 1), score(yte == 0));
end

function out = iPoolFoldAuc(aucFold)
% 把各折 OOF AUC 均值作为该 block 的 AUC（各折事件数相近，差 ≤1）。
out = mean(aucFold, 1, 'omitnan');
end

function [tObs, pSign] = iPairedSignPerm(Dd, nPerm)
% 逐细胞配对检验：Dd 为 nEvent x nCell 的（事件窗 − 匹配静息窗）差值（NaN = 该折未归入该组）。
% null：逐事件随机翻转正负号（等价于在该对内交换事件/静息窗），单侧检验"正向预测"。
[nEvD, nC] = size(Dd);
nOk = sum(isfinite(Dd), 1);
mu = mean(Dd, 1, 'omitnan');
sd = std(Dd, 0, 1, 'omitnan');
sd(~isfinite(sd) | sd == 0) = NaN;
tObs = mu ./ (sd ./ sqrt(max(nOk, 1)));
greater = zeros(nPerm, nC);
for ip = 1:nPerm
	sgn = (rand(nEvD, 1) < 0.5) * 2 - 1;          % ±1，逐事件
	Dp = Dd .* sgn;
	mp = mean(Dp, 1, 'omitnan');
	sp = std(Dp, 0, 1, 'omitnan');
	sp(~isfinite(sp) | sp == 0) = NaN;
	greater(ip, :) = mp ./ (sp ./ sqrt(max(nOk, 1))) >= tObs;
end
pSign = (sum(greater, 1) + 1) / (nPerm + 1);
pSign(~isfinite(tObs)) = NaN;
end

function s = iFmtAucP(auc, p)
% 把一组 AUC 与置换 p 格式化为一行；p 为 NaN（未做置换的细胞组）时打印 '-'。
n = numel(auc);
s = strings(1, n);
for k = 1:n
	if ~isfinite(auc(k))
		s(k) = "  --   ";
	elseif isfinite(p(k))
		s(k) = sprintf('%4.3f(p%3.0f)', auc(k), min(999, round(p(k) * 1000)));
	else
		s(k) = sprintf('%4.3f(p -- )', auc(k));
	end
end
end

function R = iLoadBlkCache(cacheDir, D, P)
% 读取该 block 的已有解码结果；参数不一致或不存在则返回 []。
R = [];
f = iBlkCacheFile(cacheDir, D, P);
if ~exist(f, 'file'), return; end
S = load(f);
if ~isfield(S, 'R') || S.R.nC ~= D.nC || numel(S.R.auc) ~= numel(P.setNames)
	return;
end
R = S.R;
end

function iSaveBlkCache(cacheDir, D, P, R)
f = iBlkCacheFile(cacheDir, D, P);
d = fileparts(f);
if ~exist(d, 'dir'), mkdir(d); end
save(f, 'R');
end

function f = iBlkCacheFile(cacheDir, D, P)
% 文件名含关键参数，避免改动口径后误用旧缓存。
f = fullfile(cacheDir, sprintf('blk%d_%s_K%d_P%d_L%d.mat', D.BlockUID, ...
	erase(string(D.Mouse), " "), P.K, P.nPerm, numel(P.leads)));
end

function auc = iAuc(sp, sn)
% 秩法 AUC（Mann-Whitney），处理并列秩。
sp = sp(isfinite(sp)); sn = sn(isfinite(sn));
if isempty(sp) || isempty(sn), auc = NaN; return; end
v = [sp; sn];
g = [true(numel(sp), 1); false(numel(sn), 1)];
r = tiedrank(v);
n1 = sum(g); n2 = numel(v) - n1;
auc = (sum(r(g)) - n1 * (n1 + 1) / 2) / (n1 * n2);
end

function s = iSem(v)
v = v(:); ok = isfinite(v);
if ~any(ok), s = NaN; return; end
s = std(v(ok)) / sqrt(sum(ok));
end

function s = iif(c, a, b)
if c, s = a; else, s = b; end
end