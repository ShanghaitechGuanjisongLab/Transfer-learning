%% Check_MemoryComponent_LickVsReuse.m
% 记忆成分说明：两个控制检验（ALB 声→光，11 只鼠）
%
% 方向1：ITI / 无任务期「舔水时活跃」的细胞 与「复用细胞」的重合度
%        问：是否显著**低于**随机水平
% 方向2：Transfer/LightWater 中
%        hit 试次 t = 1 s 活跃细胞 与 miss 试次 t = 2 s 活跃细胞 的重合度
%
% ----------------------------------------------------------------------
% 口径（脚本内自洽实现）
%   数据：TransferLearning.AudioLightBaseline()
%   每鼠：第 1 个 Learned/AudioWater 会话的 AW block
%         第 1 个 Transfer/LightWater 会话的 LW block
%   归一化：z = (x − 本试次 1:24 帧(−3~0 s) 均值) / (本试次 1:24 帧标准差, ddof=0)
%           = QueryNTS 的 UniExp.Flags.ZScore + 1:24（与 Fig1I/Fig1J 一致）
%   活跃  ：z > 3（z 已按逐试次基线标准化，即「基线 + 3 SD」）
%           方向2 另报两种敏感性：trial 平均轨迹的基线 SD（FigS1I 写法）与「多数试次」判定
%   复用  ：Learned AW 与 Transfer LW 的 0.5–1.5 s 平均 z 均 > 1.96（Fig1I 口径）
%   舔水  ：Blocks.BlockTags.CD2 > median(CD2) + 35
%   ITI   ：试次窗（Trials.SampleRange，约 cue ±3 s）之外的帧
%
% 统计
%   逐鼠  ：重合数 obs / 期望 exp = n1*n2/n / 富集比 / 超几何单侧 p
%   组水平：鼠内标签置换 nPerm 次的重合总数零分布（保持各鼠 n1、n2 不变）
%
% 输出
%   英文图/Check_MemoryComponent_Mouse.csv
%   英文图/Check_MemoryComponent_Mouse_D2.csv
%   英文图/Check_MemoryComponent_Summary.txt
%
% 执行：MATLAB 中 Run（保持脚本）。约 2–4 min。
% ----------------------------------------------------------------------

if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ---------------- 参数 ----------------
P = struct();
P.reuseWin   = [0.5 1.5];
P.reuseThr   = 1.96;
P.actThr     = 3;
P.lickMargin = 35;
P.minITILick = 50;
P.minNSm     = 40;
P.nShift     = 200;
P.pCell      = 0.05;
P.nPerm      = 2000;
P.minHit     = 1;           % 方向2 不按试次数剔除鼠（仅防 0 试次的退化情形）；试次不均由「试次匹配」敏感性处理
P.minMiss    = 1;
rng(20261122);

Xs        = seconds(TransferLearning.Xs);
idx1s     = iNearest(Xs, 1);
idx2s     = iNearest(Xs, 2);
maskReuse = Xs >= P.reuseWin(1) & Xs <= P.reuseWin(2);
fprintf('时间轴 %d 帧；1 s -> idx %d (%.3f s)，2 s -> idx %d (%.3f s)\n', ...
	numel(Xs), idx1s, Xs(idx1s), idx2s, Xs(idx2s));

DS = TransferLearning.AudioLightBaseline();
Tr = DS.Trials; Tr.Stimulus = string(Tr.Stimulus);
B  = DS.Blocks; BS = DS.BlockSignals; DT = DS.DateTimes;
sr = Tr.SampleRange;
Sd = double(sr.Start); Ed = double(sr.End); Td = double(sr.Tag);

mice = unique(string(DT.Mouse))';
fprintf('=== 方向1：ITI 舔水活跃细胞 × 复用细胞 ===\n');

R1  = cell(0, 14);
R2  = cell(0, 17);
G1  = struct('mouse', {}, 'stage', {}, 'nC', {}, 'iReuse', {}, 'nLick', {}, 'obs', {});
G1s = struct('mouse', {}, 'stage', {}, 'nC', {}, 'iReuse', {}, 'nLick', {}, 'obs', {});
G2  = struct('mouse', {}, 'stage', {}, 'nC', {}, 'iReuse', {}, 'nLick', {}, 'obs', {});

for ii = 1:numel(mice)
	m = mice(ii);
	iS = find(string(DT.Mouse) == m & string(DT.Phase) == "Learned", 1);
	iT = find(string(DT.Mouse) == m & string(DT.Phase) == "Transfer", 1);
	if isempty(iS) || isempty(iT), fprintf('%s：缺会话，跳过\n', m); continue; end
	dtL = DT.DateTime(iS); dtT = DT.DateTime(iT);
	bL = find(B.DateTime == dtL & string(B.Design) == "AudioWater", 1);
	bT = find(B.DateTime == dtT & string(B.Design) == "LightWater", 1);

	% ---------- 复用细胞 ----------
	[uidL, zL] = iCellWinZ(DS, struct('Mouse', char(m), 'DateTime', dtL, 'Stimulus', 'AudioWater'), maskReuse);
	[uidT, zT] = iCellWinZ(DS, struct('Mouse', char(m), 'DateTime', dtT, 'Stimulus', 'LightWater'), maskReuse);
	if isempty(uidL) || isempty(uidT), fprintf('%s：trial 数据缺失，跳过\n', m); continue; end
	[uidRT, ia, ib] = intersect(uidL, uidT);
	reuseUID = uidRT(zL(ia) > P.reuseThr & zT(ib) > P.reuseThr);

	% ---------- 方向1 ----------
	for st = 1:2
		if st == 1, blk = bL; stageName = "LearnedAW";
		else,       blk = bT; stageName = "TransferLW"; end
		[blkUID, lickMeanZ, pShuf, nLick, nITI, lickMinusNon] = iBlockITILick(BS, B, Tr, blk, Sd, Ed, Td, P);
		if isempty(blkUID) || nLick < P.minITILick
			fprintf('  %-9s %-11s ITI 舔水帧 %d 不足，跳过\n', m, stageName, nLick);
			continue;
		end
		[common, ~, iB] = intersect(uidRT(:), blkUID(:));
		common = common(:); iB = iB(:);
		isReuse = reshape(ismember(common, reuseUID), [], 1);
		% 注意：iB 是 blkUID 中的位置，可直接对 blkUID 长度的向量取子集
		isLick  = lickMeanZ(iB) > P.actThr;
		isLickS = lickMeanZ(iB) > P.actThr & pShuf(iB) < P.pCell;
		% 舔水特异：舔水帧均值 − 非舔水 ITI 帧均值 > 1 SD，且置换显著
		isLickC = lickMinusNon(iB) > 1 & pShuf(iB) < P.pCell;

		nC = numel(common); n1 = nnz(isReuse); n2 = nnz(isLick);
		obs = nnz(isReuse & isLick);
		exp = n1 * n2 / max(nC, 1);
		pLow = hygecdf(obs, nC, n1, n2);
		pUp  = 1 - hygecdf(obs - 1, nC, n1, n2);

		R1(end+1, :) = {char(m), char(stageName), nC, n1, n2, nLick, nITI, obs, exp, pLow, ...
			nnz(isLickS), nnz(isReuse & isLickS), nnz(isLickC), nnz(isReuse & isLickC)}; %#ok<SAGROW>
		G1(end+1)  = struct('mouse', char(m), 'stage', char(stageName), 'nC', nC, ...
			'iReuse', find(isReuse), 'nLick', n2, 'obs', obs); %#ok<SAGROW>
		G1s(end+1) = struct('mouse', char(m), 'stage', char(stageName), 'nC', nC, ...
			'iReuse', find(isReuse), 'nLick', nnz(isLickC), 'obs', nnz(isReuse & isLickC)); %#ok<SAGROW>

		fprintf(['  %-9s %-11s nC=%3d reuse=%3d(%4.1f%%) ITIlick=%3d(%4.1f%%) overlap=%2d ' ...
			'exp=%5.1f 比=%4.2f  p_low=%.3g  [舔水特异 set=%3d ov=%2d, 含p<.05: %3d ov=%2d; 舔水帧 %d/%d ITI]\n'], ...
			m, stageName, nC, n1, 100*n1/nC, n2, 100*n2/nC, obs, exp, obs/max(exp, eps), ...
			pLow, nnz(isLickC), nnz(isReuse & isLickC), nnz(isLickS), nnz(isReuse & isLickS), nLick, nITI);
	end

	% ---------- 方向2 ----------
	qAll = struct('Mouse', char(m), 'Phase', 'Transfer', 'Stimulus', 'LightWater');
	qH = qAll; qH.Behavior = 1;
	qM = qAll; qM.Behavior = 0;
	nAll = iQuery1(DS, qAll); nH = iQuery1(DS, qH); nMs = iQuery1(DS, qM);
	if isempty(nH) || isempty(nMs)
		fprintf('  %-9s 方向2：无 hit 或 miss，跳过\n', m); continue;
	end
	nTrH = numel(unique(uint64(nH.TrialUID)));
	nTrM = numel(unique(uint64(nMs.TrialUID)));
	if nTrH < P.minHit || nTrM < P.minMiss
		fprintf('  %-9s 方向2：hit=%d / miss=%d 过少，跳过\n', m, nTrH, nTrM); continue;
	end
	[uidH, zH, frH] = iCellPointZ(nH, idx1s);
	[uidM, zM, frM] = iCellPointZ(nMs, idx2s);
	[uidB, muB, sdB] = iCellBaseThr(nAll, 1:24);

	[u12, iH, iM] = intersect(uidH(:), uidM(:));
	[uAll, i12, iB2] = intersect(u12(:), uidB(:));
	iH = iH(i12); iH = iH(:); iM = iM(i12); iM = iM(:); iB2 = iB2(i12); iB2 = iB2(:);
	% 主判据（项目既定口径，Fig1J/FigS1I）：trial 平均轨迹基线窗的 mu + 3*SD
	thrB = muB(iB2) + P.actThr * sdB(iB2);
	isH  = zH(iH) > thrB;
	isM  = zM(iM) > thrB;
	% 敏感性 A：z > 3（逐试次基线 SD 单位，更严格）
	isHz = zH(iH) > P.actThr;
	isMz = zM(iM) > P.actThr;
	% 敏感性 B：多数试次（>=50%）超过 z>3
	isHs = frH(iH) >= 0.5;
	isMs = frM(iM) >= 0.5;

	nC2  = numel(uAll); nHc = nnz(isH); nMc = nnz(isM);
	obs2 = nnz(isH & isM);
	exp2 = nHc * nMc / max(nC2, 1);
	pUp2 = 1 - hygecdf(obs2 - 1, nC2, nHc, nMc);
	pLo2 = hygecdf(obs2, nC2, nHc, nMc);
	nHz = nnz(isHz); nMzb = nnz(isMz); obsZ = nnz(isHz & isMz);

	% 试次数匹配稳健性（两组试次数不等时，各自随机取 nSub 个试次重算）
	if nTrH ~= nTrM
		nSub = min(nTrH, nTrM);
		[~, ZH] = iCellPointZRep(nH,  idx1s, nSub, 100);
		[~, ZM] = iCellPointZRep(nMs, idx2s, nSub, 100);
		isHm = ZH(iH, :) > thrB; isMm = ZM(iM, :) > thrB;
		ovM  = sum(isHm & isMm, 1);
		expM = sum(isHm, 1) .* sum(isMm, 1) / max(nC2, 1);
		ovMatch  = median(ovM);
		ratMatch = median(ovM ./ max(expM, eps));
	else
		ovMatch  = obs2;
		ratMatch = obs2 / max(exp2, eps);
	end

	R2(end+1, :) = {char(m), nTrH, nTrM, nC2, nHc, nMc, obs2, exp2, ...
		obs2/max(exp2, eps), pUp2, pLo2, nHz, nMzb, obsZ, nnz(isHs & isMs), ovMatch, ratMatch}; %#ok<SAGROW>
	G2(end+1) = struct('mouse', char(m), 'stage', 'TransferLW', 'nC', nC2, ...
		'iReuse', find(isH), 'nLick', nMc, 'obs', obs2); %#ok<SAGROW>

	fprintf(['  %-9s 方向2 hit=%2d trials / miss=%2d trials | nC=%3d hit@1s=%3d miss@2s=%3d ' ...
		'overlap=%2d exp=%4.1f 比=%4.2f (p_up=%.3g)  [z>3: %d/%d ov=%d; 多数判定 ov=%d; 试次匹配 ov=%.0f 比=%.2f]\n'], ...
		m, nTrH, nTrM, nC2, nHc, nMc, obs2, exp2, obs2/max(exp2, eps), pUp2, nHz, nMzb, obsZ, nnz(isHs & isMs), ovMatch, ratMatch);
end

%% ---------------- 组水平置换检验 ----------------
fprintf('\n=== 组水平（鼠内标签置换，nPerm = %d）===\n', P.nPerm);
T1  = iGroupPerm(G1,  P.nPerm, 'lower');
T1s = iGroupPerm(G1s, P.nPerm, 'lower');
T2  = iGroupPerm(G2,  P.nPerm, 'upper');

fprintf('\n方向1 主判据（ITI 舔水平均 z > 3）：\n'); disp(T1)
fprintf('方向1 敏感性（舔水特异：lick−nonlick > 1 SD 且置换 p < %.2f）：\n', P.pCell); disp(T1s)
fprintf('\n方向2（hit 1 s vs miss 2 s）：\n'); disp(T2)

%% ---------------- 写文件 ----------------
outDir = fileparts(mfilename('fullpath'));
R1t = cell2table(R1, 'VariableNames', {'Mouse','Stage','nCommon','nReuse','nITILickActive', ...
	'nITILickFrames','nITIFrames','Overlap','Expected','P_hyper_lower', ...
	'nITILickActive_perm','Overlap_perm','nLickSpecific','Overlap_lickSpecific'});
R2t = cell2table(R2, 'VariableNames', {'Mouse','nHitTrial','nMissTrial','nCommon', ...
	'nHit1sActive','nMiss2sActive','Overlap','Expected','Ratio','P_hyper_upper','P_hyper_lower', ...
	'nHit1sActive_z3','nMiss2sActive_z3','Overlap_z3','Overlap_majority', ...
	'Overlap_matched','Ratio_matched'});
csv1 = fullfile(outDir, 'Check_MemoryComponent_Mouse.csv');
csv2 = fullfile(outDir, 'Check_MemoryComponent_Mouse_D2.csv');
writetable(R1t, csv1);
writetable(R2t, csv2);

fid = fopen(fullfile(outDir, 'Check_MemoryComponent_Summary.txt'), 'w', 'n', 'UTF-8');
fprintf(fid, '方向1 主判据（ITI 舔水平均 z > 3）\n%s\n', iTableToStr(T1));
fprintf(fid, '\n方向1 敏感性（舔水特异：lick−nonlick > 1 SD 且置换 p < %.2f）\n%s\n', P.pCell, iTableToStr(T1s));
fprintf(fid, '\n方向2（hit 1 s vs miss 2 s）\n%s\n', iTableToStr(T2));
fclose(fid);

fprintf('\n已写出：\n  %s\n  %s\n  %s\n', csv1, csv2, ...
	fullfile(outDir, 'Check_MemoryComponent_Summary.txt'));

%% ============================================================
%% 局部函数
%% ============================================================
function k = iNearest(x, v)
[~, k] = min(abs(x - v));
end

function nts = iQuery1(DS, q)
% 个别细胞基线为 0 时 QueryNTS 会抛 NaN_appears_after_normalization → 该查询作废
try
	nts = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
catch ME
	warning('MemComp:QueryFailed', '查询失败（%s）：%s', ME.identifier, ME.message);
	nts = {}; return;
end
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID  = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
end

% 窗口平均 z（先逐试次窗内平均，再对试次取平均）—— 与 Fig1I iCellWinMean 等价
function [uid, z] = iCellWinZ(DS, q, maskWin)
nts = iQuery1(DS, q);
uid = uint64([]); z = [];
if isempty(nts), return; end
sig = double(nts.TrialSignal);
w   = mean(sig(:, maskWin), 2);
[g, uid] = findgroups(uint64(nts.CellUID));
z = splitapply(@(v) mean(v, 'omitnan'), w, g);
uid = uid(:);
end

% 指定时刻 z 的跨试次中位数 + 超过 3 的试次占比
function [uid, medZ, fracAbove] = iCellPointZ(nts, idx)
sig = double(nts.TrialSignal);
w   = sig(:, idx);
[g, uid]      = findgroups(uint64(nts.CellUID));
medZ          = splitapply(@(v) median(v, 'omitnan'), w, g);
fracAbove     = splitapply(@(v) mean(v > 3), w, g);
uid = uid(:);
end

% 试次数匹配：每次随机取 nSub 个试次重算中位数（nRep 次），返回 nCell×nRep
function [uid, Zrep] = iCellPointZRep(nts, idx, nSub, nRep)
sig = double(nts.TrialSignal);
v   = sig(:, idx);
cu  = uint64(nts.CellUID); tu = uint64(nts.TrialUID);
[g, uid] = findgroups(cu); uid = uid(:);
[~, ~, tCode] = unique(tu);
nT = numel(unique(tu));
if nSub >= nT
	Zrep = repmat(splitapply(@(v) median(v, 'omitnan'), v, g), 1, nRep);
	return;
end
Zrep = nan(numel(uid), nRep);
for r = 1:nRep
	sel  = randperm(nT, nSub);
	keep = ismember(tCode, sel);
	Zrep(:, r) = splitapply(@(v) median(v, 'omitnan'), v(keep), g(keep));
end
end

% 基线 mu / sd：先对试次取平均得到基线窗轨迹，再对窗内帧求 mu/sd
function [uid, mu, sd] = iCellBaseThr(nts, baseIdx)
sig = double(nts.TrialSignal);
[g, uid] = findgroups(uint64(nts.CellUID));
M = zeros(numel(uid), numel(baseIdx));
for k = 1:numel(baseIdx)
	M(:, k) = splitapply(@(v) mean(v, 'omitnan'), sig(:, baseIdx(k)), g);
end
mu = mean(M, 2);
sd = std(M, 0, 2);
uid = uid(:);
end

% 单个 block：ITI 舔水帧上的逐细胞平均 z + 随机置换零模型
function [cellUID, lickMeanZ, pShuf, nLick, nITI, lickMinusNon] = iBlockITILick(BS, B, Tr, blk, Sd, Ed, Td, P)
cellUID = uint64([]); lickMeanZ = []; pShuf = []; nLick = 0; nITI = 0; lickMinusNon = [];
if isempty(blk) || ~isfinite(blk), return; end
uid = B.BlockUID(blk);
ri = find(BS.BlockUID == uid);
if numel(ri) < 10, return; end
L = cellfun(@numel, BS.BlockSignal(ri));
nSamp = mode(L);
ri = ri(L == nSamp);
if numel(ri) < 10, return; end

M = zeros(numel(ri), nSamp);
for j = 1:numel(ri)
	s = BS.BlockSignal{ri(j)};
	M(j, :) = s(:).';
end
cellUID = uint64(BS.CellUID(ri));
cellUID = cellUID(:);

selT = find(Tr.BlockUID == uid);
nSm  = Ed(selT) - Sd(selT) + 1;
selT = selT(nSm >= P.minNSm & Sd(selT) >= 1 & Ed(selT) <= nSamp);
if numel(selT) < 10, return; end

baseIdx   = false(1, nSamp);
trialMask = false(1, nSamp);
for j = 1:numel(selT)
	a = Sd(selT(j)); b = Ed(selT(j)); c = Td(selT(j));
	trialMask(a:b) = true;
	baseIdx(a:max(a, c - 1)) = true;
end
mu = mean(M(:, baseIdx), 2);
sd = std(M(:, baseIdx), 0, 2);
Z  = (M - mu) ./ sd;
Z(sd <= 0, :) = NaN;

bt = B.BlockTags{blk};
if ~istable(bt) || height(bt) < nSamp, return; end
cd2  = double(bt.CD2(:)).';
cd2  = cd2(1:nSamp);
lick = cd2 > median(cd2) + P.lickMargin;

iti     = ~trialMask;
itiLick = iti & lick;
nITI  = nnz(iti);
nLick = nnz(itiLick);
if nLick < 1, return; end

lickMeanZ = mean(Z(:, itiLick), 2, 'omitnan');
nonLick   = iti & ~lick;
if nnz(nonLick) < 10, return; end
lickMinusNon = lickMeanZ - mean(Z(:, nonLick), 2, 'omitnan');

idxITI = find(iti);
nS = numel(idxITI);
V  = false(nS, P.nShift);
base = lick(idxITI);
for k = 1:P.nShift
	V(:, k) = base(randperm(nS));
end
nullMean = Z(:, idxITI) * double(V) / nLick;
pShuf = (1 + sum(nullMean >= lickMeanZ, 2)) / (1 + P.nShift);
end

% 组水平：鼠内保持 n2（或 n1）不变，置换标签
function T = iGroupPerm(G, nPerm, tail)
if isempty(G)
	T = table(); return;
end
obsTotal = sum([G.obs]);
expTotal = sum(arrayfun(@(g) numel(g.iReuse) * g.nLick / max(g.nC, 1), G));
nullTotal = zeros(nPerm, 1);
for p = 1:nPerm
	tot = 0;
	for k = 1:numel(G)
		g = G(k);
		if g.nLick == 0 || numel(g.iReuse) == 0, continue; end
		isR = false(g.nC, 1); isR(g.iReuse) = true;
		pm = randperm(g.nC);
		tot = tot + nnz(isR(pm(1:min(g.nLick, g.nC))));
	end
	nullTotal(p) = tot;
end
if strcmpi(tail, 'lower')
	pVal = (1 + nnz(nullTotal <= obsTotal)) / (1 + nPerm);
else
	pVal = (1 + nnz(nullTotal >= obsTotal)) / (1 + nPerm);
end
pLowAll = (1 + nnz(nullTotal <= obsTotal)) / (1 + nPerm);
pUpAll  = (1 + nnz(nullTotal >= obsTotal)) / (1 + nPerm);
T = table(string(strjoin(unique(string({G.stage})), '+')), numel(G), ...
	sum([G.nC]), sum(arrayfun(@(g) numel(g.iReuse), G)), sum([G.nLick]), ...
	obsTotal, expTotal, obsTotal / max(expTotal, eps), mean(nullTotal), pVal, pLowAll, pUpAll, ...
	'VariableNames', {'Stage','nEntry','nCellTotal','nSet1Total','nSet2Total', ...
	'ObsTotal','ExpTotal','Ratio','NullMean','P','P_lower','P_upper'});
end

function s = iTableToStr(T)
s = evalc('disp(T)');
end
