%% Step2_LickAxisStability.m — 舔水相关神经维度是否跨阶段稳定（rSLDS τ 路线的轻量版）
%
% 问题
%   rSLDS 路线的核心前提是：存在一个慢潜状态，动力学时间常数 τ 长，该状态与行为（动机/
%   舔水）绑定，且在不同阶段/个体间保持一致。完整做法是拟合 rSLDS 并读 τ。本脚本做它的
%   "轻量版"：不拟合动力学模型，只问——**"与舔水最相关的那个神经方向，跨阶段是否稳定？"**
%   稳定 → 支持"存在一个固定的、行为绑定的低维读出方向"；旋转 → 该前提减弱。
%
% 为什么必须先做细胞匹配
%   "方向"只有在**同一细胞坐标系**里才能比较。本数据 CellUID 全局唯一，同一只鼠跨 block
%   若做过细胞配准，UID 集合会**完全重合**；否则完全不重合（全 0 或全等，没有中间态）。
%   故先按"UID 集合完全相同"做连通分量 → 16 个可比较组，覆盖全部 11 只鼠。
%
% ⚠ 为什么必须归一化（本脚本的关键设计）
%   两个噪声方向  w1 = s+n1, w2 = s+n2  的余弦 ≈ |s|²/(|s|²+|n|²)。噪声摊在 d 个细胞维
%   上，|n|² ∝ d，故**细胞越多余弦越低**——直接跨鼠比较 cos 是不公平的（本数据 141~771
%   细胞差 5 倍）。因此所有 cos 都用**半边数据**估计，并除以同一 block 的折半上限：
%        比例 = cos(阶段A半边, 阶段B半边) / cos(同block两半)      ~1 = 完全共享，~0 = 无共享
%   分子分母用同样多的数据、同样的细胞数，d 稀释效应抵消。
%
% 做法
%   ① 舔水轨：BlockTags.CD2 > median(CD2)+5（与 Step1c 同口径）；与钙**同格**，无需时间映射
%   ② 降采样到 1 Hz（按整秒块平均）
%   ③ 对每个高通截止 W ∈ {2,5,15,60 s, 无}：高通 → 逐细胞 z → 岭回归求"舔水轴"
%        w = (X X' + λI)^{-1} X l        （X: 细胞×时间，l: 舔水轨）
%      短 W = 只看快成分（漂白/饱食这类单 session 单调漂移被剔除）；W=无 = 含漂移（Step1c 口径）
%   ④ 每对 block 算
%        · cosCross ：全量数据的跨阶段余弦（头条数字，未归一化）
%        · cosCeil  ：同一 block 奇偶折半两轴的余弦（**估计噪声地板**）
%        · cosNull  ：把后一阶段的舔水轨循环平移半个 session 后重算轴，再取余弦
%        · cosRatio ：半边跨阶段余弦 / cosCeil      ← **归一化后的"共享比例"**
%      cosNull 是关键对照：测量"两 block 间本就存在的共享结构噪声"能贡献多少余弦。
%
% 1) 依赖：MATLAB R2023b+，本项目 +TransferLearning 包
% 2) 前置：数据源 TransferLearning.AudioLightBaseline
% 3) 图注：左＝跨阶段舔水轴的余弦（均值±SEM，每只鼠 1 个值，n＝11），另画同 block 折半上限与
%          打乱对照；右＝归一化共享比例（跨阶段÷同块折半），虚线=1 表示与同块重复一样稳定。
%          横轴＝高通截止（秒），越大越慢，"无"＝不做高通（含单 session 漂移）。
% 4) 代码

%% 0. 参数
phases     = ["Naive", "Learned", "Transfer", "Final"];
setTol     = 0.9;                   % 组内细胞集合的 Jaccard 阈值（<1 时靠"取交集"保证同格）
minCells   = 20;                    % 交集后至少这么多细胞才入组
hpList     = [2, 5, 15, 60, Inf];   % 高通截止（秒）；Inf = 不做高通（保留漂移）
hpLabel    = ["2", "5", "15", "60", "无"];
durListMin = [5, 10, 15, 20];       % 时长扫描（分钟）；只用两个 block 都 ≥ max 的配对
thrCD2     = 5;                     % CD2 高于基线多少算"正在舔"
ridgeAlpha = 0.1;                   % 岭回归强度（相对 trace(XX')/d）
fs         = 1;                     % 降采样目标频率（Hz）

%% 1. Setup
% 队列：`ALB` = 对照组（AudioLightBaseline）；`TH` = 后部丘脑化学遗传抑制（THInhibit）。
% 可在 base 工作区覆盖：`Step2Cohort = "TH";`
if ~exist('Step2Cohort', 'var'); Step2Cohort = "ALB"; end
if Step2Cohort == "ALB"; Step2Tag = ""; else, Step2Tag = "_" + Step2Cohort; end
thisFile = mfilename('fullpath');
thisDir  = fileparts(thisFile);
prjRoot  = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end

switch Step2Cohort
	case "TH"; DS = TransferLearning.THInhibit();
	otherwise;  DS = TransferLearning.AudioLightBaseline();
end
B = DS.Blocks; BS = DS.BlockSignals; DT = DS.DateTimes;
mice = reshape(unique(string(DT.Mouse)), 1, []);
fprintf('=== Step 2：舔水轴跨阶段稳定性 [%s, %d 只鼠] ===\n', Step2Cohort, numel(mice));

%% 1b. ⚠ `Blocks` 与 `DateTimes` 的行序**不一致**（同一日期在两张表里位置不同），必须按 `DateTime` 对齐。
% 否则会把 A 鼠的阶段标签装到 B 鼠的记录上（本项目之前就这么错过）。
[bMouse, bPhase, bDesign] = iAlignBlocks(B, DT);
if any(bMouse == "") || numel(unique(bMouse)) ~= numel(mice)
	warning('有 block 未能映射到 DateTimes');
end

%% 2. 按"细胞集合基本一致"做连通分量（全程在 B 的行空间里）
% 判据：Jaccard ≥ setTol。配准做得不完美的鼠（如 `yqn0240`，各 session 有细胞进出）
% 也能入组；入组后**只保留在该组各 session 都出现的细胞**（交集）。
% ⚠ 组里保留**全部 session**（不只 4 个阶段）——每只鼠的任务是连续几天的序列，
%   任务 A = `AudioWater`（声→水），任务 B = `LightWater`（光→水），“无法名的 session”
%   就是学习过程本身。阶段只是序列上的两个采样点。
groups = struct('mouse', {}, 'cells', {}, 'blkIdx', {}, 'phase', {}, 'design', {}, 'timeH', {});
for mouse = mice
	idx = find(bMouse == mouse);
	sets = cell(1, numel(idx));
	for i = 1:numel(idx)
		sets{i} = sort(double(BS.CellUID(BS.BlockUID == B.BlockUID(idx(i)))));
	end
	n = numel(idx);
	lab = 1:n;
	changed = true;
	while changed
		changed = false;
		for i = 1:n
			for j = i+1:n
				if lab(i) ~= lab(j) && ~isempty(sets{i}) && ~isempty(sets{j}) && iJaccard(sets{i}, sets{j}) >= setTol
					lab(lab == lab(j)) = lab(i);
					changed = true;
				end
			end
		end
	end
	for g = unique(lab)
		sel = find(lab == g);
		cells = iIntersectAll(sets(sel));
		if numel(cells) < minCells; continue; end
		t0 = min(B.DateTime(idx(sel)));
		groups(end+1) = struct('mouse', char(mouse), 'cells', cells, ...
			'blkIdx', idx(sel)', 'phase', bPhase(idx(sel))', ...
			'design', bDesign(idx(sel))', ...
			'timeH', hours(B.DateTime(idx(sel)) - t0)'); %#ok<SAGROW>
	end
end
fprintf('细胞匹配后得到 %d 个可比较组：\n', numel(groups));
for g = 1:numel(groups)
	ud = unique(groups(g).design);
	fprintf('  %-9s nCell=%3d  %2d session  Design=%s\n', groups(g).mouse, ...
		numel(groups(g).cells), numel(groups(g).blkIdx), strjoin(cellstr(ud)', '+'));
end

%% 2b. 每个 block 的真实采样率
% ⚠ `DateTimes.SeriesInterval` 不可靠：8 Hz 组与 30 Hz 组存的都是 0.1257 s。
% 实测：100 个 block ≈8 Hz；**12 个 block ≈30 Hz**（yqn0020 全部 10 块 + yqn0240 两块 Naive）。
% 估计法：用 `diff(SampleRange.Tag)`（帧）÷ `diff(Trials.Time)`（秒）再按 (鼠, 采样率聚类) 取中位。
rBlk = iBlockRate(DS, B, bMouse);
fprintf('采样率：8 Hz 组 %d 个，30 Hz 组 %d 个（中位 %.2f / %.2f Hz）\n', ...
	sum(rBlk < 15), sum(rBlk >= 15), median(rBlk(rBlk < 15)), median(rBlk(rBlk >= 15)));

%% 3. 抽取每个 block 的降采样钙矩阵与舔水轨（按组存放，便于 parfor 切片传递）
blkG = cell(1, numel(groups));
nBlk = 0;
for g = 1:numel(groups)
	grp = groups(g);
	for b = 1:numel(grp.blkIdx)
		iB = grp.blkIdx(b);
		uid = B.BlockUID(iB);
		nSamp = numel(BS.BlockSignal{find(BS.BlockUID == uid, 1, 'first')});
		bt = B.BlockTags{iB};
		if ~istable(bt) || height(bt) ~= nSamp; continue; end
		cd2 = bt.CD2(:)';
		lickBin = double(cd2 > median(cd2) + thrCD2);
		if mean(lickBin) == 0; continue; end
		[M, ok] = iBlockMatrix(BS, uid, nSamp, grp.cells);
		if ~ok || any(all(~isfinite(M), 2)); continue; end
		[Md, ld] = iDecimate(M, lickBin, nSamp, 1/rBlk(iB), fs);
		blkG{g}(end+1) = struct('mouse', grp.mouse, 'phase', char(grp.phase(b)), ...
			'design', char(grp.design(b)), 'timeH', grp.timeH(b), ...
			'M', Md, 'lick', ld, 'durMin', size(Md, 2)/60);
		nBlk = nBlk + 1;
	end
end
fprintf('取出 %d 个 block（其中舔水轨非空且细胞齐备）\n', nBlk);

%% 4. 逐组计算（默认并行；如并行池不可用，可在 base 里先置 Step2UseParallel = false）
nG = numel(groups);
if ~exist('Step2UseParallel', 'var'); Step2UseParallel = true; end
pairRes = cell(1, nG);
if Step2UseParallel
	parfor g = 1:nG
		pairRes{g} = iGroupMetrics(blkG{g}, hpList, fs, ridgeAlpha, durListMin*60, phases);
	end
else
	for g = 1:nG
		pairRes{g} = iGroupMetrics(blkG{g}, hpList, fs, ridgeAlpha, durListMin*60, phases);
	end
end

%% 5. 汇总（每只鼠先平均 → n = 11）
pair = struct('mouse', {}, 'kind', {}, 'phaseA', {}, 'phaseB', {}, 'samePhase', {}, ...
	'design', {}, 'gapH', {}, 'nCell', {}, ...
	'durMinA', {}, 'durMinB', {}, 'durSec', {}, 'cosCross', {}, 'cosCeil', {}, 'cosNull', {}, ...
	'cosRatio', {}, 'rCross', {}, 'rCeil', {}, 'rRatio', {}, 'dCosCross', {}, 'dCosCeil', {});
for g = 1:nG
	for k = 1:numel(pairRes{g})
		pair(end+1) = pairRes{g}(k);
	end
end
nW = numel(hpList);
isPhase = string({pair.kind}) == "phase";
isCross = isPhase & ~[pair.samePhase];
S = struct('cosCross', nan(numel(mice), nW), 'cosCeil', nan(numel(mice), nW), ...
	'cosNull', nan(numel(mice), nW), 'cosRatio', nan(numel(mice), nW), ...
	'rCross', nan(numel(mice), nW), 'rCeil', nan(numel(mice), nW), ...
	'rRatio', nan(numel(mice), nW), 'nPair', nan(numel(mice), nW));
R = struct('cosRatio', nan(numel(mice), nW), 'rRatio', nan(numel(mice), nW), 'nPair', nan(numel(mice), nW));
for m = 1:numel(mice)
	sel = find(string({pair.mouse}) == mice(m) & isCross);
	if ~isempty(sel)
		S.cosCross(m, :) = iRowMean(reshape([pair(sel).cosCross], nW, []));
		S.cosCeil(m, :)  = iRowMean(reshape([pair(sel).cosCeil], nW, []));
		S.cosNull(m, :)  = iRowMean(reshape([pair(sel).cosNull], nW, []));
		S.cosRatio(m, :) = iRowMean(reshape([pair(sel).cosRatio], nW, []));
		S.rCross(m, :)   = iRowMean(reshape([pair(sel).rCross], nW, []));
		S.rCeil(m, :)    = iRowMean(reshape([pair(sel).rCeil], nW, []));
		S.rRatio(m, :)   = iRowMean(reshape([pair(sel).rRatio], nW, []));
		S.nPair(m, :)    = sum(isfinite(reshape([pair(sel).cosCross], nW, [])), 2)';
	end
	selR = find(string({pair.mouse}) == mice(m) & isPhase & ~isCross);
	if ~isempty(selR)
		R.cosRatio(m, :) = iRowMean(reshape([pair(selR).cosRatio], nW, []));
		R.rRatio(m, :)   = iRowMean(reshape([pair(selR).rRatio], nW, []));
		R.nPair(m, :)    = sum(isfinite(reshape([pair(selR).cosRatio], nW, [])), 2)';
	end
end

fprintf('\n=== 每鼠×高通截止：跨阶段轴余弦（未归一化）===\n');
fprintf('%-9s %s\n', '鼠', sprintf('%9s', hpLabel));
for m = 1:numel(mice)
	fprintf('%-9s %s\n', mice(m), sprintf('%9.3f', S.cosCross(m, :)));
end
fprintf('\n%-9s %s\n', '中位', sprintf('%9.3f', median(S.cosCross, 1, 'omitnan')));
fprintf('同块折半上限  中位 = %s\n', sprintf('%9.3f', median(S.cosCeil, 1, 'omitnan')));
fprintf('打乱对照      中位 = %s\n', sprintf('%9.3f', median(S.cosNull, 1, 'omitnan')));

fprintf('\n=== 归一化共享比例（跨阶段 ÷ 同块折半；1=与同块重复一样稳定）===\n');
fprintf('%-9s %s\n', '鼠', sprintf('%9s', hpLabel));
for m = 1:numel(mice)
	fprintf('%-9s %s\n', mice(m), sprintf('%9.3f', S.cosRatio(m, :)));
end
fprintf('%-9s %s\n', '中位', sprintf('%9.3f', median(S.cosRatio, 1, 'omitnan')));
fprintf('--- 同阶段重复（两次 block 标同一阶段）作参照，仅 %d 只鼠有 ---\n', ...
	sum(any(isfinite(R.cosRatio), 2)));
fprintf('%s\n', sprintf('%9.3f', median(R.cosRatio, 1, 'omitnan')));
fprintf('解码：rCross 中位 = %s\n', sprintf('%9.3f', median(S.rCross, 1, 'omitnan')));
fprintf('      rCeil  中位 = %s\n', sprintf('%9.3f', median(S.rCeil, 1, 'omitnan')));
fprintf('      rRatio 中位 = %s\n', sprintf('%9.3f', median(S.rRatio, 1, 'omitnan')));

fprintf('\n配对总数 = %d（阶段对 %d：跨阶段 %d + 同阶段重复 %d；序列对 %d）\n', ...
	numel(pair), sum(isPhase), sum(isCross), sum(isPhase & ~isCross), sum(~isPhase));
fprintf('%-9s %-8s %-8s %-4s %5s %6s %6s  cosCross(2/5/15/60/无)      cosRatio\n', ...
	'鼠', '阶段A', '阶段B', '同', 'nCell', 'durA', 'durB');
for i = find(isPhase)
	fprintf('%-9s %-8s %-8s %-4d %5d %6.1f %6.1f  %s  %s\n', pair(i).mouse, pair(i).phaseA, ...
		pair(i).phaseB, pair(i).samePhase, pair(i).nCell, pair(i).durMinA, pair(i).durMinB, ...
		sprintf('%.2f ', pair(i).cosCross), sprintf('%.2f ', pair(i).cosRatio));
end

%% 5a2. ⭐ 序列分析：同一 Design 的连续 session 之间，轴相似度是否随间隔衰减？
% 每只鼠的任务是连续几天、每天两次的序列（A=AudioWater，B=LightWater）。
% 这些配对“同任务、同设计、同细胞”，且带着“相隔多久”的信息。
isSeries = ~isPhase;
gapEdges = [0, 18, 36, 72, Inf];
gapLabel = ["<18h", "18-36h", "36-72h", ">72h"];
nBin = numel(gapLabel);
gapBin = discretize([pair(isSeries).gapH], gapEdges);
G = struct('cosCross', nan(numel(mice), nBin*nW), 'cosCeil', nan(numel(mice), nBin*nW), ...
	'rCross', nan(numel(mice), nBin*nW), 'nPair', nan(numel(mice), nBin));
pairS = pair(isSeries); gB = gapBin;
for m = 1:numel(mice)
	sel = find(string({pairS.mouse}) == mice(m));
	if isempty(sel); continue; end
	CC = nan(nBin, nW); CE = nan(nBin, nW); RC = nan(nBin, nW); NP = zeros(nBin, 1);
	for iT = 1:nBin
		s = sel(gB(sel) == iT);
		if isempty(s); continue; end
		CC(iT, :) = iRowMean(reshape([pairS(s).cosCross], nW, []));
		CE(iT, :) = iRowMean(reshape([pairS(s).cosCeil], nW, []));
		RC(iT, :) = iRowMean(reshape([pairS(s).rCross], nW, []));
		NP(iT) = numel(s);
	end
	G.cosCross(m, :) = reshape(CC, 1, []);
	G.cosCeil(m, :)  = reshape(CE, 1, []);
	G.rCross(m, :)   = reshape(RC, 1, []);
	G.nPair(m, :)    = NP';
end
G.cosRatio = reshape(G.cosCross, numel(mice), nBin, nW) ./ reshape(G.cosCeil, numel(mice), nBin, nW);
fprintf('\n=== 序列分析（%d 对，同 Design 连续 session）===\n', numel(pairS));
fprintf('间隔箱        %s\n', sprintf('%9s', gapLabel));
G3 = struct('cosCross', reshape(G.cosCross, numel(mice), nBin, nW), ...
	'cosCeil', reshape(G.cosCeil, numel(mice), nBin, nW), ...
	'rCross', reshape(G.rCross, numel(mice), nBin, nW));
for iw = 1:nW
	fprintf('W=%-4s cosCross %s\n', hpLabel(iw), sprintf('%9.3f', median(G3.cosCross(:, :, iw), 1, 'omitnan')));
	fprintf('%-9s cosCeil  %s\n', '', sprintf('%9.3f', median(G3.cosCeil(:, :, iw), 1, 'omitnan')));
	fprintf('%-9s cosRatio %s\n', '', sprintf('%9.3f', median(G.cosRatio(:, :, iw), 1, 'omitnan')));
end
fprintf('每箱配对总数: %s\n', sprintf('%9d', histcounts([pairS.gapH], gapEdges)));

% 匹配间隔对照：同一间隔箱内，“跨阶段” vs “同任务序列”。若两者同级 → 阶段/任务本身不额外降低相似度。
pc = pair(isCross); gapBinP = discretize([pc.gapH], gapEdges);
RCp = reshape([pc.cosRatio], nW, [])';
fprintf('\n=== 间隔匹配对照（中位 cosRatio，每鼠先平均；W=2 s）===\n');
fprintf('%-10s %8s %10s %10s\n', '间隔箱', 'n同任务', '同任务', '跨阶段');
for iT = 1:nBin
	sS = find(gB == iT); sP = find(gapBinP == iT);
	vS = iPerMouseMedian(pairS(sS), mice, 'cosRatio', 1);
	vP = iPerMouseMedian(pc(sP), mice, 'cosRatio', 1);
	fprintf('%-10s %8d %10.3f %10.3f  (跨阶段 n=%d)\n', gapLabel(iT), numel(sS), median(vS, 'omitnan'), ...
		median(vP, 'omitnan'), numel(sP));
end

%% 5b. 时长扫描（同一批配对，固定配对集）
nD = numel(durListMin);
durMinSec = max(durListMin)*60;
selD = find(isCross & [pair.durSec] >= durMinSec);
fprintf('\n=== 时长扫描：仅用两个 block 都 ≥ %g min 的配对（%d 对，%d 只鼠）===\n', ...
	max(durListMin), numel(selD), numel(unique(string({pair(selD).mouse}))));
E = struct('cosCross', nan(numel(mice), nD*nW), 'cosCeil', nan(numel(mice), nD*nW));
for m = 1:numel(mice)
	sel = selD(string({pair(selD).mouse}) == mice(m));
	if isempty(sel); continue; end
	E.cosCross(m, :) = iRowMean(reshape([pair(sel).dCosCross], nD*nW, []));
	E.cosCeil(m, :)  = iRowMean(reshape([pair(sel).dCosCeil], nD*nW, []));
end
D3 = struct('cosCross', reshape(E.cosCross, numel(mice), nD, nW), ...
	'cosCeil', reshape(E.cosCeil, numel(mice), nD, nW));
D3.cosRatio = D3.cosCross ./ D3.cosCeil;
fprintf('%-8s%s\n', 'T(min)', sprintf('%10s', "W=" + hpLabel));
for iT = 1:nD
	fprintf('%-8g cosCross %s\n', durListMin(iT), sprintf('%10.3f', median(D3.cosCross(:, iT, :), 1, 'omitnan')));
	fprintf('%-8s cosCeil  %s\n', '', sprintf('%10.3f', median(D3.cosCeil(:, iT, :), 1, 'omitnan')));
	fprintf('%-8s cosRatio %s\n', '', sprintf('%10.3f', median(D3.cosRatio(:, iT, :), 1, 'omitnan')));
end

%% 5c. 作图
f = iNewFigure('Step2 axis stability', [9, 4]);
tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
iLinePanel(nexttile(tlo, 1), ...
	cat(2, iMeanSem(S.cosCross), iMeanSem(S.cosCeil), iMeanSem(S.cosNull)), ...
	["跨阶段", "同块折半上限", "打乱对照"], hpLabel, ...
	'舔水轴跨阶段余弦', '余弦相似度', []);
iLinePanel(nexttile(tlo, 2), ...
	cat(2, iMeanSem(S.cosRatio), iMeanSem(S.rRatio)), ...
	["轴方向共享比例", "解码共享比例"], hpLabel, ...
	'归一化共享比例（跨阶段÷同块折半）', '比例', 1);
TransferLearning.ExportStandardFigure(f, 1, "Step2_LickAxisStability" + Step2Tag + ".svg");

% 图 2：时长扫描（解释"是不是数据不够"）
f2 = iNewFigure('Step2 duration sweep', [9, 4]);
tlo2 = tiledlayout(f2, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axA = nexttile(tlo2, 1);
hold(axA, 'on');
iw0 = 1;   % W = 2 s
A = squeeze(D3.cosCross(:, :, iw0)); B2 = squeeze(D3.cosCeil(:, :, iw0));
errorbar(axA, durListMin, mean(A, 1, 'omitnan'), std(A, 0, 1, 'omitnan')./sqrt(sum(isfinite(A),1)), '-o', ...
	'Color', [0 0 0], 'MarkerSize', 3, 'MarkerFaceColor', 'w', 'CapSize', 2);
errorbar(axA, durListMin, mean(B2, 1, 'omitnan'), std(B2, 0, 1, 'omitnan')./sqrt(sum(isfinite(B2),1)), '-s', ...
	'Color', [0.45 0.45 0.45], 'MarkerSize', 3, 'MarkerFaceColor', 'w', 'CapSize', 2);
set(axA, 'XTick', durListMin, 'XLim', [durListMin(1)-3, durListMin(end)+6], 'YLim', [0, 1]);
xlabel(axA, '每段使用的时长（min）'); ylabel(axA, '余弦相似度'); box(axA, 'off');
title(axA, '数据量确实限制单轴估计精度（W=2 s）', 'FontWeight', 'normal');
text(axA, durListMin(end)+0.6, mean(A(:, end), 'omitnan'), '跨阶段', 'FontSize', 6, 'VerticalAlignment', 'middle');
text(axA, durListMin(end)+0.6, mean(B2(:, end), 'omitnan'), '同块折半上限', 'FontSize', 6, 'VerticalAlignment', 'middle');

axB = nexttile(tlo2, 2);
hold(axB, 'on');
mk = {'o', 's', '^', 'd', 'v'};
cl = {[0 0 0], [0.3 0.3 0.3], [0.5 0.5 0.5], [0.68 0.68 0.68], [0.72 0.45 0.12]};
Rr = squeeze(D3.cosRatio);   % 鼠 × 时长 × W
for iw = 1:nW
	Y = squeeze(Rr(:, :, iw));
	errorbar(axB, durListMin, mean(Y, 1, 'omitnan'), std(Y, 0, 1, 'omitnan')./sqrt(sum(isfinite(Y),1)), ...
		['-' mk{iw}], 'Color', cl{iw}, 'MarkerSize', 3, 'MarkerFaceColor', 'w', 'CapSize', 2);
end
yline(axB, 1, '--', 'Color', [0.7 0.7 0.7]);
set(axB, 'XTick', durListMin, 'XLim', [durListMin(1)-3, durListMin(end)+6], 'YLim', [0, 1.15]);
xlabel(axB, '每段使用的时长（min）'); ylabel(axB, '跨阶段 ÷ 同块折半'); box(axB, 'off');
title(axB, '但共享比例只随时长微升（远不足以填平）', 'FontWeight', 'normal');
yEnd = mean(squeeze(Rr(:, end, :)), 1, 'omitnan')';
[ys, ord] = sort(yEnd); gap = 0.075;
for i = 2:numel(ys); if ys(i) - ys(i-1) < gap; ys(i) = ys(i-1) + gap; end; end
for i = 1:numel(ord)
	text(axB, durListMin(end)+0.6, ys(i), "W="+hpLabel(ord(i))+' s', 'FontSize', 6, ...
		'VerticalAlignment', 'middle', 'Clipping', 'off');
end
TransferLearning.ExportStandardFigure(f2, 1, "Step2b_LickAxisRatioVsDuration" + Step2Tag + ".svg");

% 图 3：序列分析 —— 轴相似度 vs 两个 session 相隔多久
f3 = iNewFigure('Step2 session gap', [9, 4]);
tlo3 = tiledlayout(f3, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xg = 1:nBin;
axC = nexttile(tlo3, 1);
hold(axC, 'on');
Yc = squeeze(G3.cosCross(:, :, 1));   % 鼠 × 间隔箱（W=2 s）
Yr = squeeze(G3.cosCeil(:, :, 1));
errorbar(axC, xg, mean(Yc, 1, 'omitnan'), std(Yc, 0, 1, 'omitnan')./sqrt(sum(isfinite(Yc),1)), '-o', ...
	'Color', [0 0 0], 'MarkerSize', 3, 'MarkerFaceColor', 'w', 'CapSize', 2);
errorbar(axC, xg, mean(Yr, 1, 'omitnan'), std(Yr, 0, 1, 'omitnan')./sqrt(sum(isfinite(Yr),1)), '-s', ...
	'Color', [0.45 0.45 0.45], 'MarkerSize', 3, 'MarkerFaceColor', 'w', 'CapSize', 2);
set(axC, 'XTick', xg, 'XTickLabel', cellstr(gapLabel), 'XLim', [0.6, nBin + 2.2], 'YLim', [0, 1]);
xlabel(axC, '两个 session 的间隔'); ylabel(axC, '余弦相似度'); box(axC, 'off');
title(axC, '同任务序列（W=2 s）', 'FontWeight', 'normal');
text(axC, nBin + 0.3, mean(Yc(:, end), 'omitnan'), '跨session', 'FontSize', 6, 'VerticalAlignment', 'middle');
text(axC, nBin + 0.3, mean(Yr(:, end), 'omitnan'), '折半上限', 'FontSize', 6, 'VerticalAlignment', 'middle');

axD = nexttile(tlo3, 2);
hold(axD, 'on');
for iw = 1:nW
	Y = squeeze(G.cosRatio(:, :, iw));
	errorbar(axD, xg, mean(Y, 1, 'omitnan'), std(Y, 0, 1, 'omitnan')./sqrt(sum(isfinite(Y),1)), ...
		['-' mk{iw}], 'Color', cl{iw}, 'MarkerSize', 3, 'MarkerFaceColor', 'w', 'CapSize', 2);
end
yline(axD, 1, '--', 'Color', [0.7 0.7 0.7]);
set(axD, 'XTick', xg, 'XTickLabel', cellstr(gapLabel), 'XLim', [0.6, nBin + 2.2], 'YLim', [0, 1.15]);
xlabel(axD, '两个 session 的间隔'); ylabel(axD, '跨session ÷ 同块折半'); box(axD, 'off');
title(axD, '间隔越长是否越低？', 'FontWeight', 'normal');
yEnd = squeeze(mean(G.cosRatio(:, end, :), 1, 'omitnan'));
[ys, ord] = sort(yEnd); gapY = 0.08;
for i = 2:numel(ys); if ys(i) - ys(i-1) < gapY; ys(i) = ys(i-1) + gapY; end; end
for i = 1:numel(ord)
	text(axD, nBin + 0.3, ys(i), "W="+hpLabel(ord(i))+' s', 'FontSize', 6, ...
		'VerticalAlignment', 'middle', 'Clipping', 'off');
end
TransferLearning.ExportStandardFigure(f3, 1, "Step2c_LickAxisVsSessionGap" + Step2Tag + ".svg");

%% 7. 存盘（供跨队列比较用；这是**可复用中间产物**，不要当临时文件删掉）
pairFile = fullfile(thisDir, "Step2_pairs_" + Step2Cohort + ".mat");
save(pairFile, 'pair', 'mice', 'hpList', 'hpLabel', 'gapEdges', 'gapLabel');
fprintf('配对已存：%s\n', pairFile);
fprintf('\nDone.\n');

%% ===== Local functions =====
function [bMouse, bPhase, bDesign] = iAlignBlocks(B, DT)
% `Blocks` 与 `DateTimes` 行序不同，按 DateTime 对齐（两张表里 DateTime 均无重复）
bMouse = strings(height(B), 1); bPhase = strings(height(B), 1);
bDesign = strings(height(B), 1);
for j = 1:height(B)
	k = find(DT.DateTime == B.DateTime(j), 1);
	if isempty(k); continue; end
	bMouse(j) = string(DT.Mouse(k));
	p = string(DT.Phase(k));
	if ismissing(p); p = "(无)"; end
	bPhase(j) = p;
	bDesign(j) = string(B.Design(j));
end
end

function r = iBlockRate(DS, B, bMouse)
% 逐 block 估计真实采样率（Hz）。`SeriesInterval` 不可靠（8 Hz 与 30 Hz 组同值）。
r = nan(height(B), 1);
for i = 1:height(B)
	tt = DS.Trials.Time(DS.Trials.BlockUID == B.BlockUID(i));
	sr = DS.Trials.SampleRange(DS.Trials.BlockUID == B.BlockUID(i), :);
	if numel(tt) < 5 || ~istable(sr); continue; end
	n = min(numel(tt), height(sr));
	dR = diff(double(sr.Tag(1:n))); dT = seconds(diff(tt(1:n)));
	ok = dT > 0 & dR > 0;
	if sum(ok) < 4; continue; end
	r(i) = median(dR(ok) ./ dT(ok));
end
% 按 (鼠, 采样率聚类) 取中位，抹掉单 block 噪声
for m = reshape(unique(bMouse), 1, [])
	if m == ""; continue; end
	sel = find(bMouse == m & isfinite(r));
	if isempty(sel); continue; end
	for g = [false, true]
		s = sel((r(sel) >= 15) == g);
		if ~isempty(s); v = median(r(s)); r(s) = v; end
	end
end
r(isnan(r)) = 8;
end

function [M, ok] = iBlockMatrix(BS, uid, nSamp, cells)
ok = false;
rowIdx = find(BS.BlockUID == uid);
cu = double(BS.CellUID(rowIdx));
[~, loc] = ismember(cells(:), cu);
if any(loc == 0); return; end
M = nan(numel(cells), nSamp);
for i = 1:numel(cells)
	v = double(BS.BlockSignal{rowIdx(loc(i))});
	if numel(v) ~= nSamp; return; end
	M(i, :) = v(:)';
end
ok = true;
end

function [Md, ld] = iDecimate(M, lick, nSamp, dt, fs)
% 按整秒块平均降到 fs Hz（默认 1 Hz）
nBin = floor(nSamp * dt * fs);
binIdx = min(floor((0:nSamp-1) * dt * fs) + 1, nBin)';
cnt = accumarray(binIdx, 1, [nBin, 1]);
Md = zeros(size(M, 1), nBin);
for c = 1:size(M, 1)
	Md(c, :) = (accumarray(binIdx, M(c, :)', [nBin, 1], @sum, 0) ./ cnt)';
end
ld = (accumarray(binIdx, lick(:), [nBin, 1], @sum, 0) ./ cnt)';
end

function pr = iGroupMetrics(blk, hpList, fs, ridgeAlpha, durListSec, phases)
nW = numel(hpList);
nD = numel(durListSec);
pr = struct('mouse', {}, 'kind', {}, 'phaseA', {}, 'phaseB', {}, 'samePhase', {}, ...
	'design', {}, 'gapH', {}, 'nCell', {}, ...
	'durMinA', {}, 'durMinB', {}, 'durSec', {}, 'cosCross', {}, 'cosCeil', {}, 'cosNull', {}, ...
	'cosRatio', {}, 'rCross', {}, 'rCeil', {}, 'rRatio', {}, 'dCosCross', {}, 'dCosCeil', {});
if numel(blk) < 2; return; end

for a = 1:numel(blk)
	for b = a+1:numel(blk)
		phA = string(blk(a).phase); phB = string(blk(b).phase);
		isPhasePair = ismember(phA, phases) && ismember(phB, phases);
		isSeriesPair = strcmp(blk(a).design, blk(b).design) && ...
			ismember(string(blk(a).design), ["AudioWater", "LightWater"]) && ...
			phA ~= "Recall" && phB ~= "Recall";
		if ~isPhasePair && ~isSeriesPair; continue; end

		Ma = blk(a).M; la = blk(a).lick;
		Mb = blk(b).M; lb = blk(b).lick;
		if size(Ma, 1) ~= size(Mb, 1); continue; end
		L = min(size(Ma, 2), size(Mb, 2));
		Ma = Ma(:, 1:L); la = la(1:L);
		Mb = Mb(:, 1:L); lb = lb(1:L);

		cc = nan(1, nW); ce = nan(1, nW); cn = nan(1, nW);
		cr = nan(1, nW); rc = nan(1, nW); re = nan(1, nW); rr = nan(1, nW);
		dcc = nan(nD, nW); dce = nan(nD, nW);
		for iw = 1:nW
			[Xa, ya] = iPrep(Ma, la, hpList(iw), fs);
			[Xb, yb] = iPrep(Mb, lb, hpList(iw), fs);
			if isempty(Xa) || isempty(Xb); continue; end

			% 全量轴（头条数字）
			wa = iAxis(Xa, ya, ridgeAlpha);
			wb = iAxis(Xb, yb, ridgeAlpha);
			wbNull = iAxis(Xb, circshift(yb, round(numel(yb)/2)), ridgeAlpha);
			cc(iw) = wa' * wb;
			cn(iw) = wa' * wbNull;
			rc(iw) = mean([iCorr(Xb' * wa, yb), iCorr(Xa' * wb, ya)]);

			% 时长扫描：对每个 T 重新高通+z，保证与全长口径一致
			for iT = 1:nD
				LT = durListSec(iT);
				if LT > L; continue; end
				[XaT, yaT] = iPrep(Ma(:, 1:LT), la(1:LT), hpList(iw), fs);
				[XbT, ybT] = iPrep(Mb(:, 1:LT), lb(1:LT), hpList(iw), fs);
				if isempty(XaT) || isempty(XbT); continue; end
				[oa, ea] = iHalves(LT);
				a1 = iAxis(XaT(:, oa), yaT(oa), ridgeAlpha);
				a2 = iAxis(XaT(:, ea), yaT(ea), ridgeAlpha);
				b1 = iAxis(XbT(:, oa), ybT(oa), ridgeAlpha);
				b2 = iAxis(XbT(:, ea), ybT(ea), ridgeAlpha);
				dce(iT, iw) = mean([a1' * a2, b1' * b2]);
				dcc(iT, iw) = mean([a1' * b1, a1' * b2, a2' * b1, a2' * b2]);
			end

			% 半边轴（用于归一化，保证分子分母同数据量、同细胞数）
			[oa, ea] = iHalves(numel(ya));
			[ob, eb] = iHalves(numel(yb));
			wA1 = iAxis(Xa(:, oa), ya(oa), ridgeAlpha);
			wA2 = iAxis(Xa(:, ea), ya(ea), ridgeAlpha);
			wB1 = iAxis(Xb(:, ob), yb(ob), ridgeAlpha);
			wB2 = iAxis(Xb(:, eb), yb(eb), ridgeAlpha);
			ce(iw) = mean([wA1' * wA2, wB1' * wB2]);
			cr(iw) = mean([wA1' * wB1, wA1' * wB2, wA2' * wB1, wA2' * wB2]);
			re(iw) = mean([iCorr(Xa(:, ea)' * wA1, ya(ea)), iCorr(Xa(:, oa)' * wA2, ya(oa)), ...
				iCorr(Xb(:, eb)' * wB1, yb(eb)), iCorr(Xb(:, ob)' * wB2, yb(ob))]);
			rr(iw) = mean([iCorr(Xb(:, eb)' * wA1, yb(eb)), iCorr(Xb(:, ob)' * wA2, yb(ob)), ...
				iCorr(Xa(:, ea)' * wB1, ya(ea)), iCorr(Xa(:, oa)' * wB2, ya(oa))]);
		end

		kindList = strings(0, 1); gapList = [];
		if isPhasePair; kindList(end+1) = "phase"; gapList(end+1) = abs(blk(a).timeH - blk(b).timeH); end
		if isSeriesPair
			kindList(end+1) = "series";
			gapList(end+1) = abs(blk(a).timeH - blk(b).timeH);
		end
		for kk = 1:numel(kindList)
			pr(end+1) = struct('mouse', blk(a).mouse, 'kind', kindList(kk), ...
				'phaseA', blk(a).phase, 'phaseB', blk(b).phase, ...
				'samePhase', strcmp(blk(a).phase, blk(b).phase), ...
				'design', blk(a).design, 'gapH', gapList(kk), 'nCell', size(Ma, 1), ...
				'durMinA', blk(a).durMin, 'durMinB', blk(b).durMin, ...
				'durSec', L, 'cosCross', cc, 'cosCeil', ce, 'cosNull', cn, 'cosRatio', cr ./ ce, ...
				'rCross', rc, 'rCeil', re, 'rRatio', rr ./ re, ...
				'dCosCross', dcc, 'dCosCeil', dce);
		end
	end
end
end

function [o, e] = iHalves(n)
o = false(1, n); o(1:2:n) = true;
e = ~o;
end

function J = iJaccard(A, B)
% 两个**互异**集合的 Jaccard 指数
u = [A(:); B(:)];
[~, ~, ic] = unique(u);
cnt = accumarray(ic, 1);
inter = sum(cnt >= 2);
J = inter / (numel(A) + numel(B) - inter);
end

function I = iIntersectAll(cellSets)
% 多个**互异**集合的交集
u = vertcat(cellSets{:});
[uu, ~, ic] = unique(u);
cnt = accumarray(ic, 1);
I = uu(cnt == numel(cellSets));
end

function [X, y] = iPrep(M, lick, W, fs)
% 高通 → 逐细胞 z；返回 细胞×时间
if isfinite(W)
	k = max(2, round(W * fs));
	M = M - movmean(M, k, 2);
	lick = lick - movmean(lick, k);
end
sd = std(M, 0, 2);
good = isfinite(sd) & sd > 0;
M = M(good, :);
sy = std(lick);
if isempty(M) || ~isfinite(sy) || sy == 0; X = []; y = []; return; end
X = (M - mean(M, 2)) ./ sd(good);
y = (lick - mean(lick)) / sy;
end

function w = iAxis(X, y, alpha)
% 岭回归方向：X 细胞×时间（已 z），y 1×时间（已 z）
d = size(X, 1);
G = X * X';
G = G + alpha * (trace(G) / d) * eye(d);
w = G \ (X * y(:));
nw = norm(w);
if ~isfinite(nw) || nw == 0; w = nan(d, 1); return; end
w = w / nw;
end

function r = iCorr(a, b)
a = a(:); b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 5; r = NaN; return; end
a = a(ok) - mean(a(ok)); b = b(ok) - mean(b(ok));
if all(a == 0) || all(b == 0); r = NaN; return; end
r = (a' * b) / sqrt((a' * a) * (b' * b));
end

function r = iRowMean(X)
r = mean(X, 2, 'omitnan')';
end

function v = iPerMouseMedian(pr, mice, field, iw)
% 先把同一只鼠的配对平均，再返回逐鼠的值（NaN 表示该鼠无数据）
v = nan(numel(mice), 1);
if isempty(pr); return; end
X = reshape([pr.(field)], numel(pr(1).(field)), [])';
mo = string({pr.mouse});
for m = 1:numel(mice)
	s = mo == mice(m);
	if any(s); v(m) = mean(X(s, iw), 'omitnan'); end
end
end

function C = iMeanSem(X)
% 输入 鼠×窗 → 输出 窗×2（第 1 列均值、第 2 列 SEM）
n = sum(isfinite(X), 1);
C = [mean(X, 1, 'omitnan'); std(X, 0, 1, 'omitnan') ./ sqrt(max(n, 1))]';
end

function iLinePanel(ax, CE, labels, hpLabel, ttl, ylab, yRef)
% CE: 窗×(2*系列数)，奇数列=均值，偶数列=SEM
% yRef: 水平参考线位置（空则不画）
nW = numel(hpLabel);
nS = size(CE, 2) / 2;
Y = CE(:, 1:2:end); E = CE(:, 2:2:end);
hold(ax, 'on');
mk = {'o', 's', '^', 'd'};
cl = {[0 0 0], [0.35 0.35 0.35], [0.6 0.6 0.6], [0.6 0.35 0.1]};
for s = 1:nS
	errorbar(ax, 1:nW, Y(:, s), E(:, s), ['-' mk{s}], 'Color', cl{s}, ...
		'MarkerSize', 3, 'MarkerFaceColor', 'w', 'CapSize', 2);
end
set(ax, 'XTick', 1:nW, 'XTickLabel', cellstr(hpLabel), 'XLim', [0.6, nW + 2.2]);
xlabel(ax, '高通截止（s）');
ylabel(ax, ylab);
title(ax, ttl, 'FontWeight', 'normal');
box(ax, 'off');
if contains(ylab, '余弦'); ylim(ax, [0, 1]); end
if ~isempty(yRef)
	yline(ax, yRef, '--', 'Color', [0.7 0.7 0.7], 'HandleVisibility', 'off');
	ylim(ax, [0, max(1.15, max(Y(:) + E(:)) * 1.1)]);
end
% 行末标签，强制最小间距
yEnd = Y(end, :);
[ys, ord] = sort(yEnd);
gap = 0.07 * diff(ylim(ax));
for i = 2:numel(ys)
	if ys(i) - ys(i-1) < gap; ys(i) = ys(i-1) + gap; end
end
for i = 1:numel(ord)
	text(ax, nW + 0.2, ys(i), labels(ord(i)), 'FontSize', 6, ...
		'VerticalAlignment', 'middle', 'Clipping', 'off');
end
end

function f = iNewFigure(figName, sizeCm)
f = figure('Color', 'w', 'Name', figName);
f.Units = 'centimeters';
f.Position(3:4) = sizeCm;
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, sizeCm];
f.PaperSize = sizeCm;
end
