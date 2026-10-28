%% FigS4_PreCueStatePCA_Analysis.m
% 仿 Nature 2026 (s41586-026-11174-3, Chen et al. "Targeted stimulation of motor
% cortex ensembles drives learned movements") Fig.3/Fig.4 的口径，在
% AudioLightBaseline（声水 Learned → 光水 Transfer）上计算"线索前群体状态"量：
%
% 文献口径（Methods 原文核对）：
%   - early-onset neurons：活动 onset 早于 movement(=舔水) onset 的细胞；onset =
%     跨 movement 平均 PSTH 在 [movement 前 0.2 s, movement 结束] 内首次高于
%     baseline([-1,-0.5] s 均值) ≥1 SD 且持续 200 ms。本工程沿用
%     EarlyOnsetCells_LickLocked_Analysis.m 的同口径实现（lick 锁定）。
%   - PCA：对 **non-target**（= 非 early-onset）神经元，取 cue 前后各 2 s
%     （文献 40 帧@10 Hz；本工程用原生帧率 ~8/30 Hz 的等长时间窗），先在
%     Learned trial 间平均为 神经元×帧 矩阵拟合 PCA，再投影逐 trial 活动；
%     保留解释 80% 方差的 PC。
%   - learned trajectory：贡献了 learned movement（= Learned 声水 hit trial）的
%     trial 的平均 PC 轨迹；逐 trial 计算 PC 空间欧氏距离 d(t)。
%   - pre/post distance：d(t) 在 trial(=cue) onset 前 0.5 s / 后 1 s 的均值。
%   - 与 learned movement 的相似度：文献为 lever 位移与 learned movement 的相关；
%     本工程 FigS4C 使用舔水率 trace 与 learned 舔水模板的 Pearson r（corrT）；
%     投影系数 simT 仅保留在缓存中，不再冒充相关系数。
%   - 解码（Fig.3d 样式）：以线索前 PC 活动为预测量、lasso 回归预测舔水模板相关；
%     该标量解码是本工程保留的迁移问题，不是文献时间轨迹残差解码的同义复刻。
%
% 循环论证防护：learned trajectory / 舔水模板对 Learned 自身 trial 用 leave-one-out；
% early-onset 分组只在 Learned block 判定，Transfer 的分组另算（仅用于 S4A 保持性）。
%
% Output（缓存，TransferLearning.CachePath，不入 git）：
%   FigS4_PreCueStatePCA_Results.mat
%     .M    每鼠 struct（坐标/距离/相似度/分组/PSTH）
%     .P    参数
%
% Execution:
% - Keep as a script. Open in MATLAB Editor and Run/F5.

%% ---- 0. 参数与加载 ----
thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

P = struct();
P.tWin     = [-2, 2];        % PCA 用的 cue 对齐窗（文献 ±2 s）
P.preWin   = [-0.5, 0];      % 线索前距离窗（文献：trial onset 前 500 ms）
P.postWin  = [0, 1];         % 线索后距离窗（文献：trial onset 后 1 s）
P.lickWin  = [0, 2];         % 舔水模板窗
P.lickSm   = 0.2;            % 舔水率平滑窗（s）
P.varExpl  = 0.80;           % PCA 保留方差比例（文献 80%）
P.minNSm   = 40;
P.minTrials= 10;
P.minHit   = 6;              % learned trajectory 模板最少 hit trial 数
% onset 判定（与 EarlyOnsetCells_LickLocked_Analysis.m 同口径）
P.isoWindow= 1.0;
P.lickMargin=35;
P.tPwin    = [-1.5, 2.0];
P.baseline = [-1.0, -0.5];
P.detWin   = [-0.2, 1.5];
P.sustain  = 0.2;
P.dtFine   = 0.005;
P.minEvents= 8;
P.nShuf    = 200;            % 解码 shuffle 次数
P.seed     = 42;
rng(P.seed);

warning('off', 'UniExp:Exception:Block_must_warn');
DS = TransferLearning.AudioLightBaseline();
Tr = DS.Trials; Tr.Stimulus = string(Tr.Stimulus);
sr = Tr.SampleRange;
Sd = double(sr.Start); Ed = double(sr.End); Td = double(sr.Tag);
bs = DS.BlockSignals;

TQ = DS.TableQuery(["Mouse","DateTime","BlockUID","Stimulus","Phase"]);
TQ.Mouse = string(TQ.Mouse); TQ.Stimulus = string(TQ.Stimulus); TQ.Phase = string(TQ.Phase);
learnedBlk  = unique(TQ(TQ.Phase=="Learned"  & TQ.Stimulus=="AudioWater", ["Mouse","DateTime","BlockUID"]), 'rows','stable');
transferBlk = unique(TQ(TQ.Phase=="Transfer" & TQ.Stimulus=="LightWater", ["Mouse","DateTime","BlockUID"]), 'rows','stable');

DTall = DS.DateTimes;
SIall = double(seconds(DTall.SeriesInterval));
DTdt = DTall.DateTime; if ~isempty(DTdt.TimeZone), DTdt.TimeZone = ''; end
MallSess = string(DTall.Mouse);

mice = intersect(learnedBlk.Mouse, transferBlk.Mouse, 'stable');
fprintf('=== FigS4 线索前群体状态（PCA 口径，仿 Nature 2026 Fig3/4）===\n');
fprintf('鼠 %d 只（Learned 与 Transfer 成对）\n', numel(mice));

%% ---- 1. 逐鼠计算 ----
M0 = builtin('struct', ...
	'Mouse',[],'fs',[],'nC',[],'k',[],'varExpl',[], ...
	'nEarly',[],'nLate',[],'nNone',[],'nEarlyT',[],'nLateT',[],'nNoneT',[], ...
	'tF',[],'coordsL',[],'coordsT',[], ...
	'dPreL',[],'dPostL',[],'dProfL',[],'dPreT',[],'dPostT',[],'dProfT',[], ...
	'simL',[],'simT',[],'corrL',[],'corrT',[], ...
	'YL',[],'YT',[],'featL',[],'featT',[], ...
	'tP',[],'psthEL',[],'psthELsem',[],'psthET',[],'psthETsem',[], ...
	'psthAllL',[],'psthAllT',[], ...
	'psthCellL',[],'psthCellT',[],'psthCellSemL',[],'psthCellSemT',[], ...
	'thrCellL',[],'thrCellT',[], ...
	'onsetCellL',[],'onsetCellT',[],'hasOnsetL',[],'hasOnsetT',[], ...
	'isEarlyL',[],'isEarlyT',[],'isLateL',[],'isLateT',[], ...
	'nMvtL',[],'nMvtT',[],'mvCovL',[],'mvCovT',[], ...
	'lickOnL',[],'lickOnT',[]);
M = repmat(M0, 0, 1);
nM = 0;
for im = 1:numel(mice)
	m = mice(im);
	iL = find(learnedBlk.Mouse == m, 1);
	iT = find(transferBlk.Mouse == m, 1);
	if isempty(iL) || isempty(iT), continue; end
	FL = iExtractCueBlock(learnedBlk(iL,:), "AudioWater", Tr, Sd, Ed, Td, bs, SIall, DTdt, MallSess, P);
	FT = iExtractCueBlock(transferBlk(iT,:), "LightWater", Tr, Sd, Ed, Td, bs, SIall, DTdt, MallSess, P);
	if isempty(FL) || isempty(FT), continue; end
	if numel(FL.fIdx) ~= numel(FT.fIdx), continue; end   % 帧率不一致则跳过（同鼠应一致）
	% 两 block 细胞按 UID 交集对齐（个别 session 细胞数不同，如 yqn0240 562/560）
	[~, iaC, ibC] = intersect(uint64(FL.cellUID), uint64(FT.cellUID), 'stable');
	if numel(iaC) < 50, continue; end
	FL.cellUID = FL.cellUID(iaC); FL.Zt = FL.Zt(:, iaC, :); FL.nC = numel(iaC);
	FT.cellUID = FT.cellUID(ibC); FT.Zt = FT.Zt(:, ibC, :); FT.nC = numel(ibC);

	% ---- early-onset 分组（Learned 定义；Transfer 另算仅用于保持性展示）----
	LL = iLickLocked(FL, P);
	LT = iLickLocked(FT, P);
	if isempty(LL) || isempty(LT), continue; end
	isEarlyL = LL.isEarly;
	nonEarly = ~isEarlyL;
	if sum(nonEarly) < 10, continue; end

	% ---- PCA：文献 Sec.24 口径，仅在 Learned 的 trial 平均活动上拟合 ----
	% 不用逐 trial×帧 作为 PCA 观测；否则 PC 会同时吸收试次平均轨迹与试次间变异，
	% 与文献的 population trajectory 定义不同。拟合后再投影全部单 trial。
	XL = squeeze(mean(FL.Zt(:, nonEarly, :), 1));           % nCnon x nF（trial 平均）
	mu = mean(XL, 2);                                      % 每细胞跨时间均值
	[coef, ~, latent] = pca(XL', 'NumComponents', min(size(XL', 2), size(XL', 1) - 1));
	cumv = cumsum(latent) / sum(latent);
	k = find(cumv >= P.varExpl, 1);
	if isempty(k), k = numel(latent); end
	coefK = coef(:, 1:k);
	XLall = reshape(permute(FL.Zt(:, nonEarly, :), [2, 1, 3]), sum(nonEarly), []);
	XTall = reshape(permute(FT.Zt(:, nonEarly, :), [2, 1, 3]), sum(nonEarly), []);
	coordsL = reshape((XLall' - mu(:).') * coefK, FL.nTr, FL.nF, k);
	coordsT = reshape((XTall' - mu(:).') * coefK, FT.nTr, FT.nF, k);

	% ---- learned trajectory（Learned hit 均值）与逐 trial 距离（LOO）----
	hitL = FL.Y == 1;
	if sum(hitL) < P.minHit, continue; end
	sumC = squeeze(sum(coordsL(hitL, :, :), 1));             % nF x k
	nH = sum(hitL);
	[dPreL, dPostL, dProfL] = iDist(coordsL, sumC, nH, hitL, FL.tF, P);
	[dPreT, dPostT, dProfT] = iDist(coordsT, sumC, nH, false(FT.nTr,1), FT.tF, P);

	% ---- 舔水模板与相似度（LOO）----
	sumLk = sum(FL.Lk(hitL, :), 1);
	[simL, corrL] = iSim(FL.Lk, sumLk, nH, hitL);
	[simT, corrT] = iSim(FT.Lk, sumLk, nH, false(FT.nTr,1));

	% ---- 解码特征：线索前窗 PC 均值 ----
	preF = FL.tF >= P.preWin(1) & FL.tF < P.preWin(2);
	featL = squeeze(mean(coordsL(:, preF, :), 2));
	featT = squeeze(mean(coordsT(:, preF, :), 2));

	nM = nM + 1;
	M(nM) = builtin('struct', ...
		'Mouse', m, 'fs', FL.fs, 'nC', FL.nC, 'k', k, 'varExpl', cumv(k), ...
		'nEarly', sum(LL.isEarly), 'nLate', sum(LL.isLate), 'nNone', sum(~LL.hasOnset), ...
		'nEarlyT', sum(LT.isEarly), 'nLateT', sum(LT.isLate), 'nNoneT', sum(~LT.hasOnset), ...
		'tF', FL.tF, 'coordsL', coordsL, 'coordsT', coordsT, ...
		'dPreL', dPreL, 'dPostL', dPostL, 'dProfL', dProfL, ...
		'dPreT', dPreT, 'dPostT', dPostT, 'dProfT', dProfT, ...
		'simL', simL, 'simT', simT, 'corrL', corrL, 'corrT', corrT, ...
		'YL', FL.Y, 'YT', FT.Y, 'featL', featL, 'featT', featT, ...
		'tP', LL.tP, 'psthEL', LL.PSTHmeanE, 'psthELsem', LL.PSTHsemE, ...
		'psthET', LT.PSTHmeanE, 'psthETsem', LT.PSTHsemE, ...
		'psthAllL', LL.PSTHmean, 'psthAllT', LT.PSTHmean, ...
		'psthCellL', LL.PSTHcell, 'psthCellT', LT.PSTHcell, ...
		'psthCellSemL', LL.PSTHcellSem, 'psthCellSemT', LT.PSTHcellSem, ...
		'thrCellL', LL.thr, 'thrCellT', LT.thr, ...
		'onsetCellL', LL.onsetT, 'onsetCellT', LT.onsetT, ...
		'hasOnsetL', LL.hasOnset, 'hasOnsetT', LT.hasOnset, ...
		'isEarlyL', LL.isEarly, 'isEarlyT', LT.isEarly, ...
		'isLateL', LL.isLate, 'isLateT', LT.isLate, ...
		'nMvtL', LL.nMvt, 'nMvtT', LT.nMvt, ...
		'mvCovL', LL.mvCov, 'mvCovT', LT.mvCov, ...
		'lickOnL', LL.lickOn, 'lickOnT', LT.lickOn);
	fprintf('%s: nC=%d early=%d(%.1f%%) | PC k=%d(%.0f%%) | nTrL=%d(hit %d) nTrT=%d(hit %d)\n', ...
		m, FL.nC, sum(LL.isEarly), 100*sum(LL.isEarly)/FL.nC, k, 100*cumv(k), ...
		FL.nTr, nH, FT.nTr, sum(FT.Y));
end
if nM == 0
	error('FigS4:NoMice', '无可用鼠。');
end

% ---- 鼠内标准化距离（跨鼠 pooling 用）----
for i = 1:nM
	allD = [M(i).dPreL; M(i).dPostL; M(i).dPreT; M(i).dPostT];
	md = median(allD, 'omitnan'); sd = std(allD, 'omitnan');
	if ~isfinite(sd) || sd == 0, sd = 1; end
	M(i).dPreLz  = (M(i).dPreL  - md) / sd;
	M(i).dPostLz = (M(i).dPostL - md) / sd;
	M(i).dPreTz  = (M(i).dPreT  - md) / sd;
	M(i).dPostTz = (M(i).dPostT - md) / sd;
	dm = median([M(i).dProfL(:); M(i).dProfT(:)], 'omitnan');
	M(i).dProfLz = (M(i).dProfL - dm) / sd;
	M(i).dProfTz = (M(i).dProfT - dm) / sd;
end

%% ---- 2. 解码：文献 Fig.3d 口径（train 80% voluntary → test 保留 voluntary + opto）----
% 本工程等价：train = 80% Learned trial，test = 保留的 20% Learned + 全部 Transfer；
% 目标 = 舔水 trace 与 Learned hit 模板的 Pearson r（corrL/corrT，连续，无舔水 trial 亦可算）。
% fitclinear 对低唯一值连续目标会误判为多类分类（报 fitcecoc），故用 lasso() 函数；
% Lambda 由训练集内 5 折 CV 选（IndexMinMSE 为索引）；shuffle = 测试目标置换 nShuf 次。
% 80/20 划分重复 nSplit 次取平均（每鼠每条件一个点，对应文献每 session 一点）。
P.nSplit = 5;
for i = 1:nM
	M(i).decRheld = NaN; M(i).decRheldSh = NaN; M(i).decR = NaN; M(i).decRsh = NaN; M(i).decNNZ = 0;
	yL = M(i).corrL; yT = M(i).corrT;
	okL = isfinite(yL) & all(isfinite(M(i).featL), 2);
	okT = isfinite(yT) & all(isfinite(M(i).featT), 2);
	if sum(okL) < 20 || sum(okT) < 10, continue; end
	idxL = find(okL);
	rH = nan(P.nSplit,1); rHs = nan(P.nSplit,1); rT = nan(P.nSplit,1); rTs = nan(P.nSplit,1); nnzC = nan(P.nSplit,1);
	for sp = 1:P.nSplit
		perm = idxL(randperm(numel(idxL)));
		n80 = round(0.8 * numel(perm));
		trI = perm(1:n80); teI = perm(n80+1:end);
		if numel(teI) < 5, continue; end
		mu = mean(M(i).featL(trI,:), 1);
		sd = std(M(i).featL(trI,:), 0, 1); sd(sd == 0) = 1;
		Xtr = (M(i).featL(trI,:) - mu) ./ sd;
		Xh  = (M(i).featL(teI,:) - mu) ./ sd;
		Xt  = (M(i).featT(okT,:) - mu) ./ sd;
		try
			[B, fi] = lasso(Xtr, yL(trI), 'Alpha', 1, 'NumLambda', 25, 'CV', 5, 'Standardize', false);
		catch
			continue;
		end
		j = fi.IndexMinMSE;
		nnzC(sp) = nnz(B(:, j));
		predH = Xh * B(:, j) + fi.Intercept(j);
		predT = Xt * B(:, j) + fi.Intercept(j);
		yh = yL(teI); yt2 = yT(okT);
		if std(predH) > 0 && std(yh) > 0
			rH(sp) = corr(predH, yh);
			rs = nan(P.nShuf, 1);
			for q = 1:P.nShuf
				yq = yh(randperm(numel(yh)));
				if std(yq) > 0, rs(q) = corr(predH, yq); else, rs(q) = 0; end
			end
			rHs(sp) = median(rs, 'omitnan');
		end
		if std(predT) > 0 && std(yt2) > 0
			rT(sp) = corr(predT, yt2);
			rs = nan(P.nShuf, 1);
			for q = 1:P.nShuf
				yq = yt2(randperm(numel(yt2)));
				if std(yq) > 0, rs(q) = corr(predT, yq); else, rs(q) = 0; end
			end
			rTs(sp) = median(rs, 'omitnan');
		end
	end
	M(i).decRheld = mean(rH, 'omitnan');  M(i).decRheldSh = mean(rHs, 'omitnan');
	M(i).decR     = mean(rT, 'omitnan');  M(i).decRsh     = mean(rTs, 'omitnan');
	M(i).decNNZ   = mean(nnzC, 'omitnan');
	fprintf('decode %s: nnz=%.1f | held-out Learned r=%+.3f (shuf %+.3f) | Transfer r=%+.3f (shuf %+.3f)\n', ...
		M(i).Mouse, M(i).decNNZ, M(i).decRheld, M(i).decRheldSh, M(i).decR, M(i).decRsh);
end

%% ---- 3. 缓存 ----
outDir = fullfile(thisDir, '..', 'Temp');
if ~exist(outDir, 'dir'), mkdir(outDir); end
matPath = fullfile(outDir, 'FigS4_PreCueStatePCA_Results.mat');
save(matPath, 'M', 'P');
fprintf('\n缓存：%s（%d 鼠）\n', matPath, nM);
assignin('base', 'FigS4_M', M);
assignin('base', 'FigS4_P', P);

%% ========== local functions ==========
function F = iExtractCueBlock(blk, stim, Tr, Sd, Ed, Td, bs, SIall, DTall, MallSess, P)
% cue 对齐的逐 trial 细胞 Z 活动（块级 cue 前基线）+ 舔水率 trace
F = [];
buid = blk.BlockUID;
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
rSI = find(MallSess == blk.Mouse & abs(seconds(DTall - blk.DateTime)) < 60, 1);
if isempty(rSI) || ~isfinite(SIall(rSI)) || SIall(rSI) <= 0, return; end
fs = 1 / SIall(rSI);
tAx1 = ((0:nSmB-1)' / fs) - (cueIdxB-1) / fs;
IDX = Sd(selT) + (0:nSmB-1);
fIdx = find(tAx1 >= P.tWin(1) & tAx1 <= P.tWin(2));
lIdx = find(tAx1 >= P.lickWin(1) & tAx1 <= P.lickWin(2));
if numel(fIdx) < 8 || numel(lIdx) < 4, return; end
ub = bs(bs.BlockUID == buid, :);
nC = height(ub);
if nC == 0, return; end
preMask = tAx1 < -0.02;
Zt = nan(nTr, nC, numel(fIdx));
% 全 trial 窗逐细胞 Z（供 lick 锁定 PSTH）：Transfer 舔水潜伏期可至 ~1.6 s，
% 若只用 ±2 s 窗，lick 锁定正端会超出采集范围 → 覆盖率塔缩、右端假性负值。
% PCA（文献 cue±2 s 口径）仍用 Zt，互不影响。
ZtAll = nan(nTr, nC, nSmB);
lickMat = false(nTr, nSmB);
wSm = max(1, round(P.lickSm * fs));
Lk = nan(nTr, numel(lIdx));
for c = 1:nC
	sig = double(ub.BlockSignal{c});
	raw = sig(IDX');                                  % nSmB x nTr
	b = mean(raw(preMask, :), 1, 'omitnan');
	s = std(raw(preMask, :), 0, 1, 'omitnan'); s(s == 0) = nan;
	Zc = ((raw - b) ./ s)';                           % nTr x nSmB
	Zt(:, c, :) = Zc(:, fIdx);
	ZtAll(:, c, :) = Zc;
end
for j = 1:nTr
	tt = Tr.TrialTags{selT(j)};
	if isempty(tt) || ~any(strcmp(fieldnames(tt), 'CD2')), continue; end
	cd2 = double(tt.CD2); cd2 = cd2(:)';
	if numel(cd2) ~= nSmB
		cd2 = interp1(linspace(0,1,numel(cd2)), cd2, linspace(0,1,nSmB));
	end
	low = cd2(cd2 < prctile(cd2, 60));
	thr = median(low) + P.lickMargin;
	lickMat(j, :) = cd2 > thr;
	rate = movmean(double(lickMat(j, :)), wSm);
	Lk(j, :) = rate(lIdx);
end
F = builtin('struct', 'BlockUID', buid, 'Mouse', blk.Mouse, 'fs', fs, 'nC', nC, ...
	'cellUID', uint64(ub.CellUID), 'nTr', nTr, 'nF', numel(fIdx), 'tF', tAx1(fIdx), ...
	'tL', tAx1(lIdx), 'tAx', tAx1, 'lick', lickMat, 'Zt', Zt, 'ZtAll', ZtAll, 'Lk', Lk, ...
	'Y', double(Tr.Behavior(selT)), 'fIdx', fIdx);
end

function L = iLickLocked(F, P)
% lick 锁定 PSTH + onset 分组（同 EarlyOnsetCells_LickLocked_Analysis 口径）
L = [];
tP = (P.tPwin(1) : 1/F.fs : P.tPwin(2))';
nTP = numel(tP);
bmask = (tP >= P.baseline(1)) & (tP <= P.baseline(2));
% 孤立 lick bout 起点（原生 CD2 掩膜）
lickT = nan(F.nTr, 1); isoOk = false(F.nTr, 1);
for j = 1:F.nTr
	licking = F.lick(j, :)';
	rise = licking & ~[false; licking(1:end-1)];
	cand = find(rise); cand = cand(F.tAx(cand) >= -0.1);
	for p = cand'                                   % find 返回列向量，须转置迭代
		pre = max(1, p-round(P.isoWindow*F.fs)) : p-1;
		if ~any(licking(pre)), lickT(j) = F.tAx(p); isoOk(j) = true; break; end
	end
	if ~isoOk(j) && ~isempty(cand), lickT(j) = F.tAx(cand(1)); end
end
isoTr = find(isoOk);
if numel(isoTr) < P.minEvents, return; end
% 逐细胞 lick 锁定 PSTH：用全 trial 窗 ZtAll/tAx（非 ±2 s 窗），避免 Transfer
% 舔水潜伏期长时 lick 锁定正端超出采集范围（右端覆盖率塔缩→假性负值）。
PSTH = nan(F.nC, nTP); PSTHsem = nan(F.nC, nTP);
tOk = tP >= F.tAx(1) & tP <= F.tAx(end);
for c = 1:F.nC
	Zc = squeeze(F.ZtAll(:, c, :));                   % nTr x nSmB
	V = nan(numel(isoTr), nTP);
	for jj = 1:numel(isoTr)
		j = isoTr(jj);
		% lick 锁定：在 lickT + tP 处采样（tP 相对 lick）
		v = interp1(F.tAx, Zc(j, :), lickT(j) + tP, 'linear', nan);
		V(jj, :) = v';
	end
	PSTH(c, tOk) = mean(V(:, tOk), 1, 'omitnan');
	nv = sum(isfinite(V(:, tOk)), 1);
	PSTHsem(c, tOk) = std(V(:, tOk), 0, 1, 'omitnan') ./ sqrt(max(nv, 1));
end
baseMean = mean(PSTH(:, bmask), 2, 'omitnan');
% movement 覆盖率：tP 处有多少比例的孤立 movement 的绝对时间(lickT+tP)仍落在采集窗
% [tAx(1),tAx(end)] 内。用于画图时裁掉右端“仅剩极少数最快舔水”的选择性偏差区。
mvCov = mean((lickT(isoTr) + tP.') >= F.tAx(1) & (lickT(isoTr) + tP.') <= F.tAx(end), 1, 'omitnan');
Vbase = nan(F.nC, numel(isoTr));
for c = 1:F.nC
	Zc = squeeze(F.ZtAll(:, c, :));
	for jj = 1:numel(isoTr)
		v = interp1(F.tAx, Zc(isoTr(jj), :), lickT(isoTr(jj)) + tP, 'linear', nan);
		Vbase(c, jj) = std(v(bmask), 'omitnan');
	end
end
baseSD = mean(Vbase, 2, 'omitnan');
tFine = (P.detWin(1) : P.dtFine : P.detWin(2))';
nSus = max(2, round(P.sustain / P.dtFine));
maxStart = numel(tFine) - nSus + 1;
onsetT = nan(F.nC, 1);
for c = 1:F.nC
	tr = PSTH(c, :); ok = isfinite(tr);
	if sum(ok) < 2, continue; end
	thr = baseMean(c) + baseSD(c);
	if ~isfinite(thr), continue; end
	trF = interp1(tP(ok), tr(ok), tFine, 'linear', nan).';
	for q = 1:maxStart
		seg = trF(q:q+nSus-1);
		if all(isfinite(seg)) && all(seg > thr)
			onsetT(c) = tFine(q); break;
		end
	end
end
hasOnset = isfinite(onsetT);
isEarly = hasOnset & onsetT < 0;
isLate = hasOnset & onsetT >= 0;
% early 细胞专属的 lick 锁定平均（供 FigS4A tile3，仿 Fig.1c 右）：
% mean 跨 early 细胞，SEM 为跨细胞标准误（无 early 细胞时置 NaN）
if any(isEarly)
	PSTHmeanE = mean(PSTH(isEarly, :), 1, 'omitnan');
	PSTHsemE = std(PSTH(isEarly, :), 0, 1, 'omitnan') ./ sqrt(sum(isEarly));
else
	PSTHmeanE = nan(1, nTP); PSTHsemE = nan(1, nTP);
end
% 逐细胞 PSTH / SEM / onset 阈值一并返回，供 FigS4A 热图（文献 Fig.1c 左）使用
L = builtin('struct', 'cellUID', F.cellUID, 'tP', tP, ...
	'PSTHmean', mean(PSTH, 1, 'omitnan'), 'PSTHsem', mean(PSTHsem, 1, 'omitnan'), ...
	'PSTHmeanE', PSTHmeanE, 'PSTHsemE', PSTHsemE, ...
	'PSTHcell', PSTH, 'PSTHcellSem', PSTHsem, ...
	'baseMean', baseMean, 'baseSD', baseSD, 'thr', baseMean + baseSD, ...
	'mvCov', mvCov, ...
	'onsetT', onsetT, 'hasOnset', hasOnset, ...
	'isEarly', isEarly, 'isLate', isLate, ...
	'nMvt', numel(isoTr), 'lickOn', median(lickT(isoTr), 'omitnan'));
end

function [dPre, dPost, dProf] = iDist(coords, sumC, nH, isSelf, tF, P)
% 逐 trial 到 learned trajectory 的 PC 空间距离；isSelf 的 hit trial 用 LOO
nTr = size(coords, 1); nF = size(coords, 2);
dProf = nan(nTr, nF);
for i = 1:nTr
	if isSelf(i)
		traj = (sumC - squeeze(coords(i, :, :))) / max(1, nH - 1);
	else
		traj = sumC / nH;
	end
	dProf(i, :) = sqrt(sum((squeeze(coords(i, :, :)) - traj).^2, 2))';
end
preM = tF >= P.preWin(1) & tF < P.preWin(2);
postM = tF >= P.postWin(1) & tF <= P.postWin(2);
dPre = mean(dProf(:, preM), 2, 'omitnan');
dPost = mean(dProf(:, postM), 2, 'omitnan');
end

function [sim, cr] = iSim(Lk, sumLk, nH, isSelf)
% 舔水 trace 在 learned 模板上的投影系数（无舔水=0，恒有定义）；cr=可定义 trial 的 Pearson r
nTr = size(Lk, 1);
sim = nan(nTr, 1); cr = nan(nTr, 1);
tn = sumLk / nH;
nT2 = sum(tn.^2);
if nT2 <= 0, return; end
for i = 1:nTr
	if isSelf(i)
		tp = (sumLk - Lk(i, :)) / max(1, nH - 1);
	else
		tp = tn;
	end
	n2 = sum(tp.^2);
	if n2 > 0, sim(i) = sum(Lk(i, :) .* tp) / n2; end
	if std(Lk(i, :)) > 0 && std(tp) > 0
		cr(i) = corr(Lk(i, :)', tp');
	end
end
end
