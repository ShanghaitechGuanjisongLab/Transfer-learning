% Fig5｜声→光跨模态迁移中的表征复用：成形、复用、动作无关、7 天丢失
%
% 3 行 × 4 列（20 × 12.5 cm，Scale 2）。第 1–2 行：列 = 论点，行 = 展示 / 结论；
% 第 3 行整行是 (i) —— 跨阶段时间对应性（不依赖 PC 基的几何指标），作为全图收束。
%   列1 论点①  表征成形（naive→learned）
%   列2 论点②  迁移期复用（learned→transfer）
%   列3 论点④  7 天后丢失（V7 learned→transfer）
%   列4 论点③  相似性不完全由动作引起（transfer 内 hit vs miss）
%
% 上排（展示，PCA 0–8 s 群体轨迹，cue 端浅 → 8 s 端深）：
%   (a) ALB  Naive·AW  vs Learned·AW      ← 散乱 → 大环
%   (b) ALB  Learned·AW vs Transfer·LW    ← 环 → 环
%   (c) V7   Learned·AW vs Transfer·LW    ← 环 → 小团（与 (b) 共用坐标，幅度可直接比）
%   (d) ALB Transfer·LW：hit vs miss       ← 两条只差动作轴一个方向
% 中排（结论）：
%   (e) ① 同线索、同无给水的学会前后可靠度（LAInterspersed 探针，10 鼠配对）
%   (f) ② 三模板交叉验证独特方差 u_C / u_L / u_A（2/3 层）
%   (g) ④ 以 Learned 为锚的能量比（Transfer / Final），ALB vs V7
%   (h) ③ 迁移期**未舔试次**与学会模式的相关（2/3 vs L5）
% 底排（整行）：
%   (i) RSA 跨阶段时间对应性 peakness（逐鼠，细胞空间直接算，不经过任何 PC 基）
%       L→T = Learned→Transfer（复用）、L→N = Learned→Naive（对照）、T→F = Transfer→Final
%       ALB 的 (L→T) 高于 (L→N)，V7 反转 —— 双分离
%
% 口径：cue 后 0–8 s / 65 帧；逐回合 z-score（基线 cue 前 3 s，sd = max(基线段, 0.5×全 block)）；
%       只取 MOp2/3；(a)(b)(c) 各队列用自己 4 阶段合并拟合的 PC1/PC2，超鼠 = 每细胞把回合
%       均分成 10 组取平均。(b)(c) 共用 xlim/ylim（跨队列 PC 空间不同，但都是 z 单位，
%       幅度可直比），(a)(d) 各自定轴。
%
% 配色：TransferLearning 标准语义色（Catppuccin Mocha 原色，见 TransferLearning.m）
%   Red=Naive · Teal=Learned · Peach=Transfer · Green=hit · Blue=miss
%   Sky=ALB 队列 · Pink(深)=V7 队列；轨迹/折线用 ×0.65 压暗版

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nOut = 65; nLines = 10; nSeg = nOut - 1; smoothFrames = 1;
tWin = [0, 8]; tBase = [-3, 0];
LayerKeep = "MOp2/3";

cNaive    = TransferLearning.ColorNaive   / 255;   % #F38BA8 Red      未学
cLearned  = TransferLearning.ColorLearned / 255;   % #94E2D5 Teal     学会
cTransfer = TransferLearning.Color12h     / 255;   % #FAB387 Peach    迁移阶段
cHit      = TransferLearning.ColorHit     / 255;   % #A6E3A1 Green    命中
cMiss     = TransferLearning.ColorMiss    / 255;   % #89B4FA Blue     未命中
cALB      = TransferLearning.ColorAudio   / 255;   % #89DCEB Sky      声→光（无延迟）队列
cV7       = TransferLearning.Color7d      / 255;   % #F5C2E7 Pink     7 天队列
cL23      = TransferLearning.ColorLearned / 255;
cL5       = TransferLearning.Color12h     / 255;
cTmplC    = TransferLearning.ColorcFos    / 255;   % #B4BEFE Lavender cue 模板
cTmplA    = TransferLearning.ColorTH      / 255;   % #CBA6F7 Mauve    动作模板

%% ================= A. 上排：PCA 群体轨迹 =================
% ---- A1. ALB / V7 四阶段（缓存，0–8 s，超鼠 10 线）----
cacheFile = fullfile(tempdir, 'PCAstage_G_MOp2-3.mat');
assert(exist(cacheFile, 'file') == 2, 'Fig5:NoCache', ...
	'缺 %s，请先跑 英文图/Check_StageToStageShape.m（LayerTag="MOp2-3"）生成缓存', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));

cohorts = ["ALB", "V7"];
TR = cell(2, 4); EXP = zeros(2, 2);
PM = cell(2, 4);       % 逐鼠轨迹（同一公共 PC 基），用于 bootstrap / 圆度
DATA = cell(2, 4); MO = cell(2, 4);   % 分阶段数据与鼠标签（留出基检验复用）
for k = 1:2
	iDS = find(dsNames == cohorts(k), 1);
	assert(~isempty(iDS), 'Fig5:NoCohort', '缓存里没有 %s', cohorts(k));
	common = G{iDS, 1}.CellUID;
	for iS = 2:4
		common = intersect(common, G{iDS, iS}.CellUID);
	end
	common = sort(unique(common));
	nT = size(G{iDS, 1}.NTATS.Data, 2);
	data = nan(numel(common), nT, 4 * nLines);
	MONst = cell(1, 4);
	for iS = 1:4
		[ok, loc] = ismember(common, G{iDS, iS}.CellUID);
		assert(all(ok), 'Fig5:CellMismatch', 'Cell mismatch');
		data(:, :, (iS - 1) * nLines + (1:nLines)) = double(G{iDS, iS}.NTATS.Data(loc, :, :));
		mo = string(G{iDS, iS}.Mouse); MONst{iS} = mo(loc);
	end
	Tp = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), 2, true);
	EXP(k, :) = Tp.Explained(1:2)';
	if k == 1
		commonALB = common;
		MUALB = mean(reshape(data, numel(common), []), 2);
		COALB = double(Tp.Coeff);      % 2 × nCell
	end
	co2 = double(Tp.Coeff);
	sc = double(Tp.Score.Data);
	for iS = 1:4
		TR{k, iS} = sc(:, :, (iS - 1) * nLines + (1:nLines));
		% 逐鼠轨迹：该鼠细胞在公共 PC 基上的投影（T × 2）
		X = data(:, :, (iS - 1) * nLines + (1:nLines));
		DATA{k, iS} = X; MO{k, iS} = MONst{iS};
		mo = MONst{iS}; uM = unique(mo);
		PM{k, iS} = cell(numel(uM), 1);
		for i = 1:numel(uM)
			x = squeeze(mean(X(mo == uM(i), :, :), 3, 'omitnan'));   % cells_m × T
			PM{k, iS}{i} = (co2(:, mo == uM(i)) * x)';               % T × 2
		end
	end
	fprintf('%s: %d 细胞, PC1=%.2f%%, PC2=%.2f%%\n', cohorts(k), numel(common), EXP(k, 1), EXP(k, 2));
end

% ---- A2. ALB Transfer 的 hit / miss 轨迹（投影到 (a)(b) 同一 PC 空间）----
fprintf('取 ALB Transfer 的 hit / miss 0-8 s 轨迹...\n');
DS = TransferLearning.AudioLightBaseline();
trAll = DS.Trials;
trH_acc = []; trM_acc = []; nUse = 0;
for m = unique(iMouse(DS))'
	dtT = iFirst(DS, m, "Transfer", "LightWater");
	if isnat(dtT), continue; end
	nts = iQuery(DS, m, dtT, "LightWater");
	if isempty(nts), continue; end
	Tu = unique(uint64(nts.TrialUID), 'stable');
	Tb = DS.TableQuery(["TrialUID", "Behavior"]);
	[okb, ib] = ismember(Tu, uint64(Tb.TrialUID));
	beh = nan(numel(Tu), 1); beh(okb) = double(Tb.Behavior(ib(okb)));
	uHit = Tu(beh == 1); uMiss = Tu(beh == 0);
	if numel(uHit) < 2 || numel(uMiss) < 2, continue; end
	trH = trAll(ismember(uint64(trAll.TrialUID), uHit), :);
	trM = trAll(ismember(uint64(trAll.TrialUID), uMiss), :);
	[H, uidH] = iExtract0to8s(DS, trH, LayerKeep, nOut, tWin, tBase);
	[MM, uidM] = iExtract0to8s(DS, trM, LayerKeep, nOut, tWin, tBase);
	if isempty(H) || isempty(MM), continue; end
	[~, ia, ib2] = intersect(uidH, uidM);
	cellsM = uidH(ia);
	[okc, pos] = ismember(cellsM, commonALB);
	if sum(okc) < 50, continue; end
	Xh = reshape(mean(H(ia(okc), :, :), 2, 'omitnan'), sum(okc), []);
	Xm = reshape(mean(MM(ib2(okc), :, :), 2, 'omitnan'), sum(okc), []);
	mc = MUALB(pos(okc))';
	cc = COALB(:, pos(okc))';                  % m × 2（pca 的 loading 方向）
	th = ((Xh' - mc) * cc)';                   % 2 × nOut
	tm = ((Xm' - mc) * cc)';                   % 2 × nOut
	trH_acc = cat(3, trH_acc, th);  %#ok<AGROW> % 累加维度：改成 3维
	trM_acc = cat(3, trM_acc, tm);
	nUse = nUse + 1;
end
assert(~isempty(trH_acc), 'Fig5:NoHitMiss', '没有取到 hit/miss 轨迹');
% 群体轨迹 = 各鼠投影**相加**（PC 分数是全体细胞加权和）；用 mean 会因细胞少 10 倍而缩小一个量级
TRc = {sum(trH_acc, 3, 'omitnan'), sum(trM_acc, 3, 'omitnan')};
fprintf('hit/miss: %d 只鼠投影到 ALB PC 空间\n', nUse);

%% ================= A3. 形态学统计（与上图完全同一投影口径）=================
% 主口径 = 每队列四阶段合并拟合的公共 PC 空间（跨阶段比较必须用同一套基）。
% d 给两个版本：允许旋转/镜像（宽松）与只允许平移+等比缩放（严格）。
Bboot = 2000; rng(20261113, 'twister');
stageOrderOut = {'Naive', 'Learned', 'Transfer', 'Final'};
Dg = struct(); Eg = struct(); Dn = struct();
circK = nan(2, 4, 20); nMK = zeros(2, 4);
for k = 1:2
		n1 = numel(PM{k, 1}); n2 = numel(PM{k, 2}); n3 = numel(PM{k, 3}); n4 = numel(PM{k, 4});
	vNL = nan(Bboot, 1); vLT = nan(Bboot, 1);
	wNL = nan(Bboot, 1); wLT = nan(Bboot, 1);
	eLT = nan(Bboot, 1); eFI = nan(Bboot, 1);
	for t = 1:Bboot
		a1 = mean(cat(3, PM{k, 1}{randi(n1, n1, 1)}), 3);
		a2 = mean(cat(3, PM{k, 2}{randi(n2, n2, 1)}), 3);
		b3 = mean(cat(3, PM{k, 3}{randi(n3, n3, 1)}), 3);
		b4 = mean(cat(3, PM{k, 4}{randi(n4, n4, 1)}), 3);
		vNL(t) = iDNoRot(a1, a2); vLT(t) = iDNoRot(a2, b3);
		wNL(t) = procrustes(a1, a2, 'Scaling', true);
		wLT(t) = procrustes(a2, b3, 'Scaling', true);
		eLT(t) = rms(vecnorm(b3, 2, 2)) / rms(vecnorm(a2, 2, 2));
		eFI(t) = rms(vecnorm(b4, 2, 2)) / rms(vecnorm(a2, 2, 2));
	end
	Dg.(cohorts(k)).NL_norot = vNL; Dg.(cohorts(k)).LT_norot = vLT;
	Dg.(cohorts(k)).NL_rot = wNL;   Dg.(cohorts(k)).LT_rot = wLT;
	Eg.(cohorts(k)).LT = eLT; Eg.(cohorts(k)).FI = eFI;
	for iS = 1:4
		nM = numel(PM{k, iS}); nMK(k, iS) = nM;
		for i = 1:nM
			mn = PM{k, iS}{i};
			rr = sqrt(sum((mn - mean(mn, 1)).^2, 2));
			circK(k, iS, i) = std(rr) / mean(rr);
		end
	end
end
ddR = Dg.V7.LT_rot - Dg.ALB.LT_rot;
ddN = Dg.V7.LT_norot - Dg.ALB.LT_norot;
ee  = log(Eg.V7.LT) - log(Eg.ALB.LT);
pR  = 2 * min(mean(ddR <= 0), mean(ddR >= 0));
pN  = 2 * min(mean(ddN <= 0), mean(ddN >= 0));
pE  = 2 * min(mean(ee <= 0),  mean(ee >= 0));

fprintf('\n===== 形态学（公共 PC 空间；逐鼠 bootstrap %d 次）=====\n', Bboot);
fprintf('%-4s %-18s %8s %-18s %8s\n', '队列', '阶段对', 'd(旋转)', '[95%CI]', 'd(禁旋转)');
Mrows = {};
for k = 1:2
	nm = cohorts(k);
	pairs = {'NL', 'Naive→Learned'; 'LT', 'Learned→Transfer'};
	for p = 1:2
		r = Dg.(nm).([pairs{p, 1} '_rot']); q = Dg.(nm).([pairs{p, 1} '_norot']);
		fprintf('%-4s %-18s %8.3f [%5.3f,%5.3f]      %8.3f [%5.3f,%5.3f]\n', nm, pairs{p, 2}, ...
			mean(r), prctile(r, 2.5), prctile(r, 97.5), mean(q), prctile(q, 2.5), prctile(q, 97.5));
		Mrows(end+1, :) = {nm, pairs{p, 2}, mean(r), prctile(r,2.5), prctile(r,97.5), ...
			mean(q), prctile(q,2.5), prctile(q,97.5)}; %#ok<SAGROW>
	end
	fprintf('%-4s 能量比 Transfer/Learned = %.2f [%.2f, %.2f]   Final/Learned = %.2f [%.2f, %.2f]\n', nm, ...
		mean(Eg.(nm).LT), prctile(Eg.(nm).LT, 2.5), prctile(Eg.(nm).LT, 97.5), ...
		mean(Eg.(nm).FI), prctile(Eg.(nm).FI, 2.5), prctile(Eg.(nm).FI, 97.5));
	Mrows(end+1, :) = {nm, 'EnergyRatio_T/L', mean(Eg.(nm).LT), prctile(Eg.(nm).LT,2.5), prctile(Eg.(nm).LT,97.5), NaN, NaN, NaN}; %#ok<SAGROW>
	Mrows(end+1, :) = {nm, 'EnergyRatio_F/L', mean(Eg.(nm).FI), prctile(Eg.(nm).FI,2.5), prctile(Eg.(nm).FI,97.5), NaN, NaN, NaN}; %#ok<SAGROW>
end
fprintf('组间差 (V7−ALB)  Learned→Transfer:\n');
fprintf('   d(旋转)  Δ=%.3f [%.3f,%.3f] p=%.4g\n', mean(ddR), prctile(ddR,2.5), prctile(ddR,97.5), pR);
fprintf('   d(禁旋转) Δ=%.3f [%.3f,%.3f] p=%.4g\n', mean(ddN), prctile(ddN,2.5), prctile(ddN,97.5), pN);
fprintf('   能量比   Δlog=%.2f [%.2f,%.2f] p=%.4g ⇒ V7 是 ALB 的 %.2f 倍\n', ...
	mean(ee), prctile(ee,2.5), prctile(ee,97.5), pE, exp(mean(ee)));
fprintf('\n逐鼠圆度 circ = std(r)/mean(r)（0 = 正圆；穿过质心的直线 ≈ 0.58）:\n');
for k = 1:2
	fprintf('  %s: ', cohorts(k));
	for iS = 1:4
		v = circK(k, iS, 1:nMK(k, iS));
		fprintf('%s %.3f   ', stageOrderOut{iS}, mean(v));
	end
	fprintf('\n');
end
MT = cell2table(Mrows, 'VariableNames', ["Cohort", "StagePair", "d_rot", "d_rot_lo", "d_rot_hi", ...
	"d_norot", "d_norot_lo", "d_norot_hi"]);
writetable(MT, fullfile(thisDir, 'Fig5_Morphology_PooledPC.csv'));

%% ================= A4. RSA 时间对应性（逐鼠，细胞空间，不经过任何 PC 基）=================
% C[i,j] = corr(阶段A的bin i, 阶段B的bin j)；peakness = mean(diag) − mean(|i−j|≥2)
% L→T 大 = 迁移轨迹与学会轨迹按时间对齐；L→N 是对照（与 naive 的对齐程度）
nBinR = 8;
pairsR = [2 3; 2 1; 3 4];
pairLabR = ["L→T", "L→N", "T→F"];
PkR = cell(1, 2);
for k = 1:2
	PB = cell(1, 4); uM = [];
	for iS = 1:4
		X = DATA{k, iS}; nT = size(X, 2);
		ed = round(linspace(0, nT, nBinR + 1));
		mo = MO{k, iS}; uM = unique(mo);
		PB{iS} = cell(numel(uM), 1);
		for i = 1:numel(uM)
			sel = (mo == uM(i));
			Bi = nan(sum(sel), nBinR);
			for b = 1:nBinR
				Bi(:, b) = mean(mean(X(sel, (ed(b) + 1):ed(b + 1), :), 3, 'omitnan'), 2, 'omitnan');
			end
			PB{iS}{i} = Bi;
		end
	end
	PkR{k} = nan(numel(uM), numel(pairLabR));
	for i = 1:numel(uM)
		for p = 1:numel(pairLabR)
			PkR{k}(i, p) = iPeakCell(PB{pairsR(p, 1)}{i}, PB{pairsR(p, 2)}{i});
		end
	end
	fprintf('RSA peakness %s: L→T %+.3f | L→N %+.3f | T→F %+.3f  (选择性 %+.3f)\n', cohorts(k), ...
		mean(PkR{k}(:, 1), 'omitnan'), mean(PkR{k}(:, 2), 'omitnan'), mean(PkR{k}(:, 3), 'omitnan'), ...
		mean(PkR{k}(:, 1) - PkR{k}(:, 2), 'omitnan'));
end
selALB = PkR{1}(:, 1) - PkR{1}(:, 2); selALB = selALB(isfinite(selALB));
selV7  = PkR{2}(:, 1) - PkR{2}(:, 2); selV7  = selV7(isfinite(selV7));
fprintf(' 选择性指数 ALB %+.3f ± %.3f (p=%.3g) vs V7 %+.3f ± %.3f (p=%.3g); 组间 p=%.3g\n', ...
	mean(selALB), std(selALB)/sqrt(numel(selALB)), signrank(selALB, 0), ...
	mean(selV7), std(selV7)/sqrt(numel(selV7)), signrank(selV7, 0), ranksum(selALB, selV7));

%% ================= B. 下排：定量数据 =================
Tprobe = readtable(fullfile(thisDir, 'Check_PostLearningProbe_MOp2-3.csv'), 'TextType', 'string');
Tfd1   = readtable(fullfile(thisDir, 'RepresentationReuse_FormalVarDecomp_MOp2-3.csv'), 'TextType', 'string');
Tpa1   = readtable(fullfile(thisDir, 'RepresentationReuse_PartialActionClaim_MOp2-3.csv'), 'TextType', 'string');
Tpa2   = readtable(fullfile(thisDir, 'RepresentationReuse_PartialActionClaim_MOp5.csv'), 'TextType', 'string');
Tdl    = readtable(fullfile(thisDir, 'Check_DistToLearned_MOp2-3.csv'), 'TextType', 'string');

relNa = Tprobe.rel_NaiveLO; relTr = Tprobe.rel_TrnLO;
okp = isfinite(relNa) & isfinite(relTr);
relNa = relNa(okp); relTr = relTr(okp);

% LAI 给水对照（同一天/同阶段/同线索，仅差给水）
Twc = readtable(fullfile(thisDir, 'Check_ProbeWaterControl_MOp2-3.csv'), 'TextType', 'string');
wcN = Twc.rel_NaiveLO; wcA = Twc.rel_TrnLO; wcW = Twc.rel_TrnLW;
okw = isfinite(wcN) & isfinite(wcA) & isfinite(wcW);
wcN = wcN(okw); wcA = wcA(okw); wcW = wcW(okw);

% ALB 本队列 matched-trial 可靠度（未溼 AudioOnly @ Naive → 命中 AudioWater @ Learned）
Trc = readtable(fullfile(thisDir, 'Check_ReliabilityAndTemplateCos_MOp2-3.csv'), 'TextType', 'string');
Trc = Trc(Trc.Cohort == "ALB", :);
albN = Trc.rel_NaiveAO; albL = Trc.rel_LrnAW;
oka = isfinite(albN) & isfinite(albL);
albN = albN(oka); albL = albL(oka);

Fd = Tfd1(Tfd1.Subset == "all", :);
uC = Fd.uniq_C; uL = Fd.uniq_L; uA = Fd.uniq_A;

wA = Tpa1.r2_orthA_raw(Tpa1.Cohort == "ALB"); wA = wA(isfinite(wA));   % 剔除**独立**动作模板(Naive/WaterOnly)后
wB = Tpa2.r2_orthA_raw(Tpa2.Cohort == "ALB"); wB = wB(isfinite(wB));

stageOrder = ["Naive", "Learned", "Transfer", "Final"];
% (g) 用 A3 里同一口径（公共 PC 空间 + 逐鼠 bootstrap）的能量比；
% 这里把 95%CI 的半宽换算成误差棒。
yER = nan(2, 4); eER = nan(2, 4);
for k = 1:2
	yER(k, 2) = 1; eER(k, 2) = 0;
	nm = cohorts(k);
	yER(k, 3) = mean(Eg.(nm).LT); eER(k, 3) = (prctile(Eg.(nm).LT, 97.5) - prctile(Eg.(nm).LT, 2.5)) / 2;
	yER(k, 4) = mean(Eg.(nm).FI); eER(k, 4) = (prctile(Eg.(nm).FI, 97.5) - prctile(Eg.(nm).FI, 2.5)) / 2;
end

%% ================= C. 画布 =================
f = figure('Color', 'w', 'Name', 'Fig5 representation reuse v2');
f.Units = 'centimeters';
f.Position = [2, 2, 20, 18.5];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 20, 18.5];
f.PaperSize = [20, 18.5];

% 左列：阶段轨迹竖排（共享 PC 轴标签）；右侧：统计说明横行
tOuter = tiledlayout(f, 1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
tLeft  = tiledlayout(tOuter, 4, 1, 'TileSpacing', 'compact', 'Padding', 'none');
tLeft.Layout.Tile = 1;
tRight = tiledlayout(tOuter, 4, 3, 'TileSpacing', 'compact', 'Padding', 'none');
tRight.Layout.Tile = 2; tRight.Layout.TileSpan = [1 4];

% ---------- (a) ① ALB Naive vs Learned ----------
axA = nexttile(tLeft, 1);
iGrad(axA, TR{1, 1}, cNaive, nSeg, smoothFrames);
iGrad(axA, TR{1, 2}, cLearned, nSeg, smoothFrames);
iTailPCA(axA); title(axA, '(a)', 'FontWeight', 'normal');

% ---------- (b) ② ALB Learned vs Transfer ----------
axB = nexttile(tLeft, 2);
iGrad(axB, TR{1, 2}, cLearned, nSeg, smoothFrames);
iGrad(axB, TR{1, 3}, cTransfer, nSeg, smoothFrames);
iTailPCA(axB); title(axB, '(b)', 'FontWeight', 'normal');

% ---------- (c) ④ V7 Learned vs Transfer ----------
axC = nexttile(tLeft, 3);
iGrad(axC, TR{2, 2}, cLearned, nSeg, smoothFrames);
iGrad(axC, TR{2, 3}, cTransfer, nSeg, smoothFrames);
iTailPCA(axC); title(axC, '(c)', 'FontWeight', 'normal');

% ---------- (d) ③ ALB Transfer hit vs miss ----------
axD = nexttile(tLeft, 4);
iGrad(axD, TRc{1}, cHit, nSeg, smoothFrames);
iGrad(axD, TRc{2}, cMiss, nSeg, smoothFrames);
iTailPCA(axD); title(axD, '(d)', 'FontWeight', 'normal'); xlabel(axD, 'PC1');
MATLAB.Graphics.UnifyAxesLims([axB, axC, axD], @xlim, @ylim);
% 四个轨迹面板共享同一对轴标签 → 只在 Layout 级别放一次
ylabel(tLeft, 'PC2');   % 四个轨迹面板共享纵轴标签


% ---------- (g) ② 三模板独特方差（横向条形：标签可用全称）----------
axG = nexttile(tRight, 4, [1 2]);
gC = 100 * uC ./ Fd.R2_full;
gL = 100 * uL ./ Fd.R2_full; gA = 100 * uA ./ Fd.R2_full;
iBarScatterH(axG, {gC, gL, gA}, {cTmplC, cLearned, cTmplA}, {'Cue', 'Learned', 'Action'});
axG.XTick = [0 50 100];
xlabel(axG, 'u (% of R^2)'); iTailQ(axG);
gV = {gC, gL, gA};
for k = 1:3
	m = mean(gV{k}, 'omitnan');
text(axG, max(m, 0) + 6, k + 0.30, sprintf('%.1f', m), 'HorizontalAlignment', 'left', ...
	'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end
		title(axG, '(g)', 'FontWeight', 'normal');

% ---------- (i) ③ 未舔试次的相关 ----------
axI = nexttile(tRight, 6);
iBarScatter(axI, {wA, wB}, {cL23, cL5});
axI.XTick = [1 2]; axI.XTickLabel = {'2/3', 'L5'};
ylabel(axI, 'r_\perp'); iTailQ(axI);
		title(axI, '(h)', 'FontWeight', 'normal');

% ---------- (j) RSA 时间对应性 ----------
		axJ = nexttile(tRight, 7, [1 2]);
iTwoSeries(axJ, {PkR{1}(:, 1), PkR{1}(:, 2), PkR{1}(:, 3), selALB}, ...
	{PkR{2}(:, 1), PkR{2}(:, 2), PkR{2}(:, 3), selV7}, cALB, cV7);
axJ.XTick = [1 2 3 4];
		axJ.XTickLabel = {'L→T', 'L→N', 'T→F', 'Δ(L→T)−(L→N)'};
		ylabel(axJ, 'temporal peakness'); iTailQ(axJ);
		title(axJ, '(i)', 'FontWeight', 'normal');
		% (j) 内在维度（twoNN，与 PR 仅 ρ=0.50，非冗余）
		axJ2 = nexttile(tRight, 9);
		iTwoSeries(axJ2, {msPick("ALB", "N→L", "ID_A"), msPick("ALB", "N→L", "ID_B")}, ...
			{msPick("V7", "N→L", "ID_A"),  msPick("V7", "N→L", "ID_B")}, cALB, cV7, true);
		axJ2.XTick = [1 2]; axJ2.XTickLabel = {'Naive', 'Learned'};
		ylabel(axJ2, 'twoNN ID'); iTailQ(axJ2);
		title(axJ2, '(j)', 'FontWeight', 'normal');

% ---------- (k) 子空间一致性（A）+ 有效维度（D）----------
% A：各阶段各自独立估子空间（不共用 PCA 基）→ 主角度 overlap，按同阶段 split-half 归一化
% D：participation ratio（去时间均值）——排除"复用由维度塔缩产生"
MS = readtable(fullfile(thisDir, 'Check_ManifoldSimilarity_MOp2-3_k3_w8000ms.csv'));
msPick = @(c, pn, v) MS{MS.Cohort == c & MS.Pair == pn, v};
		% ---------- (e) 子空间一致性：overlap（按同阶段 split-half 归一化）----------
	axK1 = nexttile(tRight, 1, [1 2]);
		iTwoSeries(axK1, {msPick("ALB", "N→T", "ovRatio"), msPick("ALB", "L→T", "ovRatio"), msPick("ALB", "T→F", "ovRatio")}, ...
			{msPick("V7", "N→T", "ovRatio"),  msPick("V7", "L→T", "ovRatio"),  msPick("V7", "T→F", "ovRatio")}, cALB, cV7);
		axK1.XTick = [1 2 3]; axK1.XTickLabel = {'N→T', 'L→T', 'T→F'};
		ylabel(axK1, 'overlap'); iTailQ(axK1);
		title(axK1, '(e)', 'FontWeight', 'normal');
		% ---------- (g) 有效维度：participation ratio（中位数柱，抵抗 V7 的 PR=12.3 离群点）----------
		axK2 = nexttile(tRight, 3);
		iTwoSeries(axK2, {msPick("ALB", "N→L", "PR_A"), msPick("ALB", "N→L", "PR_B")}, ...
			{msPick("V7", "N→L", "PR_A"),  msPick("V7", "N→L", "PR_B")}, cALB, cV7, true);
		axK2.XTick = [1 2]; axK2.XTickLabel = {'Naive', 'Learned'};
		ylabel(axK2, 'PR'); iTailQ(axK2);
		title(axK2, '(f)', 'FontWeight', 'normal');

% ---------- 全局图例（右区末行第 3 格，两列竖排）----------
axL = nexttile(tRight, 10, [1 3]);
axL.Box = 'off'; axL.XColor = 'none'; axL.YColor = 'none';
axL.XTick = []; axL.YTick = []; axL.Color = 'none';
hold(axL, 'on');
namesL = {'Naive', 'Learned', 'Transfer', 'hit', 'miss', 'ALB', 'V7'};
colsL  = {cNaive, cLearned, cTransfer, cHit, cMiss, cALB, cV7};
hL = gobjects(1, numel(namesL));
for i = 1:numel(namesL)
	hs = plot(axL, nan, nan, '-', 'Color', colsL{i} * 0.58, 'LineWidth', 2.2, 'HandleVisibility', 'off');
	hL(i) = plot(axL, nan, nan, '-', 'Color', colsL{i}, 'LineWidth', 1.5, 'DisplayName', namesL{i});
	setappdata(hs, 'TransferLearningPreserveLineWidth', true);
	setappdata(hL(i), 'TransferLearningPreserveLineWidth', true);
end
lgd = legend(axL, hL, 'Orientation', 'vertical', 'Box', 'off');
lgd.NumColumns = 7;
lgd.FontSize = 8;

%% ---------- 导出 ----------
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig5_RepresentationReuse.svg');
fprintf('Wrote: %s\n', svgPath);
exportgraphics(f, fullfile(thisDir, '_fig5_check.png'), 'Resolution', 400, 'BackgroundColor', 'white');

%% ================= local functions =================
function iGrad(ax, X, color, nSeg, smoothFrames)
% 线内时间渐变：cue 端浅 → 8 s 端基色
if smoothFrames > 1
	X = movmean(X, smoothFrames, 2);
end
nL = size(X, 3); nT = size(X, 2);
tt = linspace(1, nT, nSeg + 1);
w = linspace(0, 1, nSeg + 1)';
% 内芯保持原色（起点向白混 75%，保留色相）；外圈加同色相深描边，白底也能看见
c0 = 0.75 + 0.25 * color(:)';
cv = c0 + w * (color(:)' - c0);
Xp = nan(nSeg + 2, nL); Yp = nan(nSeg + 2, nL);
for i = 1:nL
	xy = squeeze(X(:, :, i));
	Xp(1:nSeg + 1, i) = interp1(1:nT, xy(1, :), tt);
	Yp(1:nSeg + 1, i) = interp1(1:nT, xy(2, :), tt);
end
C = repmat(reshape(cv, [nSeg + 1, 1, 3]), 1, nL, 1);
C(end + 1, :, :) = repmat(reshape(cv(end, :), [1, 1, 3]), 1, nL, 1);
hold(ax, 'on');
% 个体轨迹：淡化细线，不描边（避免 10 条线互相描边后发毛）
hi = patch(ax, Xp, Yp, C, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.0, 'EdgeAlpha', 0.26, 'HandleVisibility', 'off');
setappdata(hi, 'TransferLearningPreserveLineWidth', true);
% 群体均值：同色相深描边 + 原色芯，保证白底可见
Xm = mean(Xp, 2, 'omitnan'); Ym = mean(Yp, 2, 'omitnan');
Cm = reshape(cv, [nSeg + 1, 1, 3]);
Cm(end + 1, :, :) = reshape(cv(end, :), [1, 1, 3]);
hd = patch(ax, Xm, Ym, Cm * 0.58, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 2.2, 'HandleVisibility', 'off');
setappdata(hd, 'TransferLearningPreserveLineWidth', true);
hc = patch(ax, Xm, Ym, Cm, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.5);
setappdata(hc, 'TransferLearningPreserveLineWidth', true);
view(ax, 2);
end

function iTailPCA(ax)
% 状态空间面板：去掉刻度数字，只留轴框
ax.Box = 'off';
ax.XTick = []; ax.YTick = [];
ax.LineWidth = 1;
end

function iTailQ(ax)
% 定量面板：保留刻度，仅统一轴框样式
ax.Box = 'off';
ax.LineWidth = 1;
end

function iTwoSeries(ax, A, B, cA, cB, useMed)
% 每个 group 两根柱（两队列）+ 逐鼠散点；useMed=true 时柱高用中位数（对离群点稳健）
if nargin < 6, useMed = false; end
hold(ax, 'on');
n = numel(A);
for g = 1:n
	for s = 1:2
		if s == 1, v = A{g}; cc = cA; dx = -0.17;
		else,      v = B{g}; cc = cB; dx = 0.17; end
		v = v(:); v = v(isfinite(v));
		if isempty(v), continue; end
		if useMed
			m = median(v); se = 1.2533 * std(v) / sqrt(numel(v));
		else
			m = mean(v); se = std(v) / sqrt(numel(v));
		end
		bar(ax, g + dx, m, 0.28, 'FaceColor', cc, 'EdgeColor', 'none', 'HandleVisibility', 'off');
		errorbar(ax, g + dx, m, se, 'Color', cc, 'LineStyle', 'none', ...
			'LineWidth', 1, 'CapSize', 3, 'HandleVisibility', 'off');
		plot(ax, g + dx + (rand(numel(v), 1) - 0.5) * 0.13, v, 'o', 'MarkerSize', 2.2, ...
			'MarkerFaceColor', 'none', 'MarkerEdgeColor', cc, 'LineWidth', 0.4, ...
			'HandleVisibility', 'off');
	end
end
xlim(ax, [0.5 n + 0.5]);
yline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end

function pk = iPeakCell(A, B)
% A,B: cells × nBin（同一细胞的模式）→ 跨阶段时间对应矩阵的对角优势
n = size(A, 2);
C = nan(n);
for i = 1:n
	for j = 1:n
		a = A(:, i); b = B(:, j);
		ok = isfinite(a) & isfinite(b);
		a = a(ok); b = b(ok);
		a = a - mean(a); b = b - mean(b);
		sa = norm(a); sb = norm(b);
		if sa == 0 || sb == 0, continue; end
		C(i, j) = (a' * b) / (sa * sb);
	end
end
m = abs(bsxfun(@minus, 1:n, (1:n)')) >= 2;
pk = mean(diag(C), 'omitnan') - mean(C(m), 'omitnan');
end

function d = iDNoRot(A, B)
% Procrustes 距离，但**禁止旋转与镜像**，只允许平移 + 等比缩放
% （两边各自中心化并归一化到单位 Frobenius 范数）。量纲与
% procrustes(...,'Scaling',true) 一致：d = 2(1-cos)，0 = 同形。
a = A - mean(A, 1); b = B - mean(B, 1);
a = a / norm(a, 'fro'); b = b / norm(b, 'fro');
d = 2 - 2 * sum(a(:) .* b(:));
end

function iBarScatterH(ax, D, colors, labs)
hold(ax, 'on');
nG = numel(D);
for k = 1:nG
	v = D{k}(:); v = v(isfinite(v));
	if isempty(v), continue; end
	m = mean(v); s = std(v) / sqrt(numel(v));
	barh(ax, k, m, 0.55, 'FaceColor', colors{k}, 'EdgeColor', 'none');
	errorbar(ax, m, k, s, 'horizontal', 'Color', colors{k}, 'LineStyle', 'none', ...
	'LineWidth', 1, 'CapSize', 3, 'HandleVisibility', 'off');
	plot(ax, v, k + (rand(numel(v), 1) - 0.5) * 0.26, 'o', 'MarkerSize', 2.2, ...
	'MarkerFaceColor', 'none', 'MarkerEdgeColor', colors{k}, 'LineWidth', 0.4);
end
% 按数据范围自动加边距（左侧留 4%，避免 y 轴标签贴住柱子与负值散点）
xv = []; for kk = 1:nG, xv = [xv; D{kk}(:)]; end
xv = xv(isfinite(xv));
lo = min([0; xv]); hi = max([0; xv]);
padx = 0.04 * max(hi - lo, eps);
xlim(ax, [lo - padx, hi + padx]);
ylim(ax, [0.5 nG + 0.5]);
ax.YTick = 1:nG; ax.YTickLabel = labs;
xline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end

function iBarScatter(ax, D, colors)
hold(ax, 'on');
nG = numel(D);
for k = 1:nG
	v = D{k}(:); v = v(isfinite(v));
	if isempty(v), continue; end
	m = mean(v); s = std(v) / sqrt(numel(v));
	bar(ax, k, m, 0.55, 'FaceColor', colors{k}, 'EdgeColor', 'none');
	errorbar(ax, k, m, s, 'Color', colors{k}, 'LineStyle', 'none', ...
		'LineWidth', 1, 'CapSize', 3, 'HandleVisibility', 'off');
	n = numel(v);
	plot(ax, k + (rand(n, 1) - 0.5) * 0.26, v, 'o', 'MarkerSize', 2.2, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', colors{k}, 'LineWidth', 0.4);
end
xlim(ax, [0.5 nG + 0.5]);
yline(ax, 0, '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end

function iPairLine(ax, S, C, lab)
% 多条件逐鼠配对散点：灰线连同一只鼠，彩点 + 均值/SEM
hold(ax, 'on');
nS = numel(S); n = numel(S{1});
for i = 1:n
	y = zeros(1, nS);
	for j = 1:nS, y(j) = S{j}(i); end
	if all(isfinite(y))
		plot(ax, 1:nS, y, '-', 'Color', [0.82 0.82 0.82], 'LineWidth', 0.4, ...
			'HandleVisibility', 'off');
	end
end
for j = 1:nS
	v = S{j};
	plot(ax, j + (rand(n, 1) - 0.5) * 0.20, v, 'o', 'MarkerSize', 2.4, ...
		'MarkerFaceColor', 'none', 'MarkerEdgeColor', C{j}, 'LineWidth', 0.5, ...
		'HandleVisibility', 'off');
	m = mean(v, 'omitnan'); s = std(v, 'omitnan') / sqrt(sum(isfinite(v)));
	errorbar(ax, j, m, s, 'Color', C{j}, 'LineStyle', 'none', 'LineWidth', 1.0, ...
		'CapSize', 3, 'HandleVisibility', 'off');
	plot(ax, j, m, '_', 'Color', C{j}, 'MarkerSize', 7, 'LineWidth', 1.2, ...
		'HandleVisibility', 'off');
end
xlim(ax, [0.5 nS + 0.5]);
ax.XTick = 1:nS;
if nargin > 3, ax.XTickLabel = lab; end
end

function u = iMouse(DS)
T = DS.TableQuery(["Mouse", "DateTime"]);
u = unique(string(T.Mouse));
end

function dt = iFirst(DS, m, ph, stim)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse); T.Phase = string(T.Phase); T.Stimulus = string(T.Stimulus);
sel = T.Mouse == m & T.Phase == ph & T.Stimulus == stim;
if ~any(sel), dt = NaT; return; end
d = sort(unique(T.DateTime(sel))); dt = d(1);
end

function nts = iQuery(DS, mouse, dt, stim)
nts = [];
try
	nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), UniExp.Flags.ZScore, 1:24);
catch
	return;
end
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
end

function dtStr = iDtStr(x)
x = datetime(x);
if ~isempty(x.TimeZone), x.TimeZone = ''; end
dtStr = string(x);
end

function [Zout, uidOut] = iExtract0to8s(DS, trials, layerKeep, nOut, tWin, tBase)
% 从 BlockSignals 截取 cue 后 tWin 段，逐回合 z-score（基线 tBase）。
% 返回 Zout: nCell × nTrial × nOut；uidOut: nCell × 1 uint64
cellsTbl = DS.Cells;
cellsTbl.CellUID = uint64(cellsTbl.CellUID);
cellsTbl.ZLayer = string(cellsTbl.ZLayer);
if strlength(layerKeep) > 0
	keepMask = cellsTbl.ZLayer == layerKeep;
else
	keepMask = true(height(cellsTbl), 1);
end
cellUIDset = cellsTbl.CellUID(keepMask);

trAll = DS.Trials;
[isIn, loc] = ismember(uint64(trials.TrialUID), uint64(trAll.TrialUID));
assert(all(isIn), 'Fig5:MissingTrial', 'Some trials are not in DS.Trials.');
cue = double(trAll.SampleRange.Tag(loc));
blk = double(trAll.BlockUID(loc));
dates = DS.DateTimes;
dates.DateTime = iDtStr(dates.DateTime);
dtAll = seconds(dates.SeriesInterval);
dtMed = median(dtAll(isfinite(dtAll) & dtAll > 0));
blocksTbl = DS.Blocks;
dtOfBlock = containers.Map('KeyType', 'double', 'ValueType', 'double');
for iD = 1:height(dates)
	bIds = blocksTbl.BlockUID(iDtStr(blocksTbl.DateTime) == dates.DateTime(iD));
	dB = dtMed;
	if isfinite(dtAll(iD)) && dtAll(iD) > 0, dB = dtAll(iD); end
	for j = 1:numel(bIds)
		dtOfBlock(double(bIds(j))) = dB;
	end
end
bs = DS.BlockSignals;
bs.CellUID = uint64(bs.CellUID);
MapZ = containers.Map('KeyType', 'uint64', 'ValueType', 'any');
uB = unique(blk);
for iB = 1:numel(uB)
	b = uB(iB);
	rTrial = find(blk == b);
	cueB = cue(rTrial);
	if isKey(dtOfBlock, b), dtB = dtOfBlock(b); else, dtB = dtMed; end
	off = round(linspace(tWin(1), tWin(2), nOut) / dtB);
	idxWin = cueB(:) + off;
	nBase = max(1, round(diff(tBase) / dtB));
	baseOff = round(linspace(tBase(1), tBase(2) - dtB, nBase) / dtB);
	idxBase = cueB(:) + baseOff;
	rowsB = find(bs.BlockUID == b);
	if isempty(rowsB), continue; end
	lenB = numel(bs.BlockSignal{rowsB(1)});
	validTrial = all(idxWin >= 1, 2) & all(idxWin <= lenB, 2) & all(idxBase >= 1, 2);
	if ~any(validTrial), continue; end
	for r = 1:numel(rowsB)
		cid = bs.CellUID(rowsB(r));
		if ~any(cellUIDset == cid), continue; end
		full = double(bs.BlockSignal{rowsB(r)});
		full = full(:)';
		ok = validTrial & all(idxWin <= numel(full), 2);
		if ~any(ok), continue; end
		cellSd = std(full(isfinite(full)));
		if ~isfinite(cellSd) || cellSd < 1e-6, continue; end
		W = full(idxWin(ok, :));
		B = full(idxBase(ok, :));
		mu = mean(B, 2, 'omitnan');
		sd = std(B, 0, 2, 'omitnan');
		sd = max(sd, 0.5 * cellSd);
		sd(~isfinite(sd)) = cellSd;
		Z = (W - mu) ./ sd;
		if isKey(MapZ, cid)
			MapZ(cid) = [MapZ(cid); Z];
		else
			MapZ(cid) = Z;
		end
	end
end
ks = MapZ.keys;
n = numel(ks);
if n == 0, Zout = []; uidOut = uint64([]); return; end
nTrialMax = 0;
for i = 1:n, nTrialMax = max(nTrialMax, size(MapZ(ks{i}), 1)); end
Zout = nan(n, nTrialMax, nOut);
uidOut = zeros(n, 1, 'uint64');
for i = 1:n
	Zi = MapZ(ks{i});
	Zout(i, 1:size(Zi, 1), :) = Zi;
	uidOut(i) = ks{i};
end
end
