% 检查（不画图）：**同一队列内**相邻阶段之间的轨迹形状距离（Procrustes d）
%   与能量比（norm 比），带逐鼠 bootstrap CI。
%
% 为什么需要：现有的 English_StageShapeAlignment_d.csv 是"各队列 vs 同阶段 ALB"，
%   回答不了"naive→learned 形状变了没有""learned→transfer 形状保住了没有"。
%   本脚本给出**配对**的 d，正好对应论点 1/2/4 的"两阶段比较"。
%
% 口径：nComp = 3（取前 2 个 PC 作 2D 形状）；procrustes(...,'Scaling',true)，
%       允许旋转 + 镜像（PC 符号/基旋转是不变量，禁止镜像会把同一形状算成 d≈0.85）。
% 注意：缓存来自 PCA_StageProgression_ALBvsLAB_0to8s.m，其 LayerKeep = "MOp2/3"，
%       因此本脚本全部数字都是 **2/3 层** 的。

thisDir = fileparts(mfilename('fullpath'));
nComp = 3; B = 2000; rng(20261113, 'twister');

% ---- 层选择（可在 base 工作区预设 LayerTag = "MOp2-3" / "MOp5"）----
if ~exist('LayerTag', 'var'), LayerTag = "MOp2-3"; end
if LayerTag == "MOp2-3"
	LayerKeep = "MOp2/3";
elseif LayerTag == "MOp5"
	LayerKeep = "MOp5";
else
	LayerKeep = "";
end
tagSuffix = "_" + LayerTag;

mainCache = fullfile(tempdir, 'PCAstage_G' + tagSuffix + '.mat');
dlyCache  = fullfile(tempdir, 'PCAstage_G_delayed' + tagSuffix + '.mat');
if LayerTag == "MOp2-3"   % 兼容旧缓存
	if exist(mainCache, 'file') ~= 2 && exist(fullfile(tempdir,'PCAstage_G.mat'), 'file') == 2
		copyfile(fullfile(tempdir,'PCAstage_G.mat'), mainCache);
	end
	if exist(dlyCache, 'file') ~= 2 && exist(fullfile(tempdir,'PCAstage_G_delayed.mat'), 'file') == 2
		copyfile(fullfile(tempdir,'PCAstage_G_delayed.mat'), dlyCache);
	end
end
if exist(mainCache, 'file') ~= 2
	fprintf('生成主队列缓存（LayerKeep=%s）...\n', LayerKeep);
	ExportSvg = false;
	run(fullfile(thisDir, 'PCA_StageProgression_ALBvsLAB_0to8s.m'));
	save(mainCache, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
	clear LayerKeep ExportSvg
	LayerKeep = "MOp2/3"; if LayerTag == "MOp5", LayerKeep = "MOp5"; end
end
C = load(mainCache, 'PCAstage_G', 'DSnames');
G4 = C.PCAstage_G; names4 = string(C.DSnames(:));
G = G4; names = names4;
% 延迟组（ALD）属于**另一套任务**（1 s cue + 0.5 s delay + 1 s 响应窗），
% 当前的四条论点均在即时任务框架内比较，默认**不纳入**。需要时在 base 里设 CohortKeep 包含 "ALD"。
if ~exist('CohortKeep', 'var') || isempty(CohortKeep), CohortKeep = ["ALB", "V7"]; end
if any(strcmpi(string(CohortKeep), "ALD"))
	if exist(dlyCache, 'file') ~= 2
		fprintf('生成延迟组缓存（LayerKeep=%s）...\n', LayerKeep);
		ExportSvg = false;
		run(fullfile(thisDir, 'PCA_StageProgression_Delayed_0to8s.m'));
		save(dlyCache, 'G', 'DSnames');
		clear LayerKeep ExportSvg
	end
	Dz = load(dlyCache, 'G', 'DSnames');
	G = [G4; {Dz.G{1, 1}, Dz.G{1, 2}, Dz.G{1, 3}, Dz.G{1, 4}}];
	names = [names4; "ALD"];
end
% 按 CohortKeep 筛选/排序
selC = zeros(1, numel(CohortKeep));
for q = 1:numel(CohortKeep)
	k = find(names == string(CohortKeep(q)), 1);
	if isempty(k), error('Check_StageToStageShape:missingCohort', '未找到队列 %s', CohortKeep(q)); end
	selC(q) = k;
end
G = G(selC, :); names = names(selC);
nDS = numel(names);
fprintf('本次分析队列: %s\n', strjoin(names', ', '));
stageNames = ["Naive", "Learned", "Transfer", "Final"];

%% ---------- 每队列×阶段：群体轨迹 + 每鼠轨迹 + 能量 ----------
PC = cell(nDS, 4); PM = cell(nDS, 4); EN = nan(nDS, 4);
for iDS = 1:nDS
	for iS = 1:4
		data = double(G{iDS, iS}.NTATS.Data);
		mouse = string(G{iDS, iS}.Mouse);
		nC = size(data, 1); nT = size(data, 2); nL = size(data, 3);
		T = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), nComp, true);
		co = double(T.Coeff); S = double(T.Score.Data);
		PC{iDS, iS} = double(squeeze(mean(S(1:2, :, :), 3))');
		EN(iDS, iS) = sqrt(mean(sum(PC{iDS, iS}.^2, 2)));
		Xall = reshape(data, nC, [])';
		uM = unique(mouse);
		PM{iDS, iS} = cell(numel(uM), 1);
		for i = 1:numel(uM)
			cols = (mouse == uM(i))';
			Ssub = Xall(:, cols) * co(:, cols)';
			Sm = reshape(Ssub, nT, nL, nComp);
			mT = double(squeeze(mean(Sm, 2)));
			PM{iDS, iS}{i} = mT(:, 1:2);
		end
	end
end

%% ---------- 同队列内相邻阶段：d + 能量比 + bootstrap CI ----------
fprintf('\n=== 同一队列内，相邻阶段之间的 Procrustes d [95%% CI]（%s，nComp=2）===\n', LayerTag);fprintf('%-6s %-22s %9s %9s %9s %11s\n', '队列', '阶段对', 'd', 'CI_lo', 'CI_hi', '能量比');
Rows = {};
DBOOT = nan(nDS, 3, B);   % 每队列×阶段对的 bootstrap d 样本，用于**组间差值**检验
ERATIO = nan(nDS, 3, B);  % 同上，能量比的 bootstrap 样本
for iDS = 1:nDS
	for iS = 1:3
		A = PC{iDS, iS}; Bm = PC{iDS, iS+1};
		d0 = procrustes(A, Bm, 'Scaling', true);
		dBT = nan(B, 1); nM = numel(PM{iDS, iS});
		eA = nan(B, 1); eB = nan(B, 1);
		for t = 1:B
			ta = mean(cat(3, PM{iDS, iS}{randi(nM, nM, 1)}), 3);
			ca = PC{iDS, iS+1}; cB = PM{iDS, iS+1};
			nN = numel(cB);
			tb = mean(cat(3, cB{randi(nN, nN, 1)}), 3);
			dBT(t) = procrustes(ta, tb, 'Scaling', true);
			eA(t) = sqrt(mean(sum(ta.^2, 2)));
			eB(t) = sqrt(mean(sum(tb.^2, 2)));
		end
		ERATIO(iDS, iS, :) = eB ./ eA;
		DBOOT(iDS, iS, :) = dBT;
		ci = prctile(dBT, [2.5 97.5]);
		er = EN(iDS, iS+1) / EN(iDS, iS);
		fprintf('%-6s %-22s %9.3f %9.3f %9.3f %11.2f\n', names(iDS), ...
			stageNames(iS) + "→" + stageNames(iS+1), d0, ci(1), ci(2), er);
		Rows(end+1, :) = {names(iDS), stageNames(iS) + "→" + stageNames(iS+1), ...
			d0, ci(1), ci(2), er}; %#ok<SAGROW>
	end
	% 非相邻：Naive→Transfer（检验"是否只有学会后才有"）
	d0 = procrustes(PC{iDS, 1}, PC{iDS, 3}, 'Scaling', true);
	fprintf('%-6s %-22s %9.3f %9s %9s %11.2f\n', names(iDS), "Naive→Transfer", d0, '-', '-', EN(iDS, 3)/EN(iDS, 1));
	Rows(end+1, :) = {names(iDS), "Naive→Transfer", d0, NaN, NaN, EN(iDS, 3)/EN(iDS, 1)};
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "StagePair", "d", "CI_lo", "CI_hi", "EnergyRatio"]);
writetable(T, fullfile(thisDir, "Check_StageToStageShape" + tagSuffix + ".csv"));

%% ---------- 以 Learned 为锚：各阶段与"学会状态"的形状距离 / 能量比 ----------
% 这一版更适合做论点④ 的图：横轴 = 阶段，纵轴 = 与 Learned 的距离，看 V7 在
% Transfer 是否"偏离"、Final 是否恢复。
fprintf('\n=== 以 Learned 为锚（d = procrustes(阶段, Learned)，能量比 = 该阶段/Learned）===\n');
fprintf('%-6s %-10s %9s %9s %11s\n', '队列', '阶段', 'd(→Learned)', 'CI_lo', '能量比');
RowsA = {};
iLr = 2;
for iDS = 1:nDS
	for iS = [1 3 4]
		if iS == iLr, continue; end
		d0 = procrustes(PC{iDS, iLr}, PC{iDS, iS}, 'Scaling', true);
		dBT = nan(B, 1); nM = numel(PM{iDS, iLr}); nN = numel(PM{iDS, iS});
		eA = nan(B,1); eB = nan(B,1);
		for t = 1:B
			ta = mean(cat(3, PM{iDS, iLr}{randi(nM, nM, 1)}), 3);
			tb = mean(cat(3, PM{iDS, iS}{randi(nN, nN, 1)}), 3);
			dBT(t) = procrustes(ta, tb, 'Scaling', true);
			eA(t) = sqrt(mean(sum(ta.^2, 2))); eB(t) = sqrt(mean(sum(tb.^2, 2)));
		end
		ci = prctile(dBT, [2.5 97.5]);
		er = mean(eB ./ eA);
		erCI = prctile(eB ./ eA, [2.5 97.5]);
		fprintf('%-6s %-10s %9.3f %9.3f %11.2f   (能量比 95%%CI [%.2f, %.2f])\n', names(iDS), ...
			stageNames(iS), d0, ci(1), er, erCI(1), erCI(2));
		RowsA(end+1, :) = {names(iDS), stageNames(iS), d0, ci(1), ci(2), er, erCI(1), erCI(2)}; %#ok<SAGROW>
	end
	Tmp = squeeze(ERATIO(iDS, 1, :)); %#ok<NASGU>
end
TA = cell2table(RowsA, 'VariableNames', ["Cohort", "Stage", "d_to_Learned", "CI_lo", "CI_hi", ...
	"EnergyRatio_to_Learned", "ER_CI_lo", "ER_CI_hi"]);
writetable(TA, fullfile(thisDir, "Check_DistToLearned" + tagSuffix + ".csv"));

%% ---------- 组间差值：直接 bootstrap d 的差（两队列鼠独立，各自重采样）----------
iA = find(names == "ALB", 1); iV = find(names == "V7", 1);
fprintf('\n=== 组间差值检验：V7 − ALB（直接 bootstrap d 之差，而不是看两个 CI 是否重叠）===\n');
for iS = 1:3
	xA = squeeze(DBOOT(iA, iS, :)); xV = squeeze(DBOOT(iV, iS, :));
	dd = xV - xA; ci = prctile(dd, [2.5 97.5]);
	pBoot = 2 * min(mean(dd <= 0), mean(dd >= 0));
	fprintf('%-22s d_ALB=%.3f d_V7=%.3f | Δ=%.3f 95%%CI [%.3f, %.3f] 双尾 p=%.4g\n', ...
		stageNames(iS) + "→" + stageNames(iS+1), mean(xA), mean(xV), mean(dd), ci(1), ci(2), pBoot);
end
fprintf('\n=== 能量比（轨迹 RMS 半径之比）的 bootstrap 95%% CI 与组间差值（log 比）===\n');
for iDS = 1:nDS
	for iS = 1:3
		e = squeeze(ERATIO(iDS, iS, :));
		fprintf('%-6s %-22s 能量比=%.2f 95%%CI [%.2f, %.2f]\n', names(iDS), ...
			stageNames(iS) + "→" + stageNames(iS+1), mean(e), prctile(e, 2.5), prctile(e, 97.5));
	end
end
for iS = 1:3
	eA = log(squeeze(ERATIO(iA, iS, :))); eV = log(squeeze(ERATIO(iV, iS, :)));
	dd = eV - eA; ci = prctile(dd, [2.5 97.5]);
	pBoot = 2 * min(mean(dd <= 0), mean(dd >= 0));
	fprintf('log(能量比) V7−ALB  %-22s Δlog=%.2f 95%%CI [%.2f, %.2f] 双尾 p=%.4g ⇒ 比值 %.2f 倍\n', ...
		stageNames(iS) + "→" + stageNames(iS+1), mean(dd), ci(1), ci(2), pBoot, exp(mean(dd)));
end

%% ---------- "环"是否可重复：逐鼠圆度（半径的相对标准差；小 = 接近圆环）----------
% 群体平均出来的环可能是几个互相抵消的个别鼠造成 → 必须逐鼠看。
fprintf('\n=== 逐鼠圆度 circ = std(r)/mean(r)（r = 各时间点到轨迹质心的距离；越小越像环）===\n');
circ = nan(nDS, 4, 20); nMc = zeros(nDS, 4);
for iDS = 1:nDS
	for iS = 1:4
		nM = numel(PM{iDS, iS});
		nMc(iDS, iS) = nM;
		for i = 1:nM
			m = PM{iDS, iS}{i};
			r = sqrt(sum((m - mean(m, 1)).^2, 2));
			circ(iDS, iS, i) = std(r) / mean(r);
		end
	end
end
for iDS = 1:nDS
	fprintf('%s:\n', names(iDS));
	for iS = 1:4
		v = circ(iDS, iS, 1:nMc(iDS, iS));
		fprintf('   %-9s circ = %.3f   (逐鼠 %s)\n', stageNames(iS), mean(v), ...
			strjoin(compose('%.2f', v), ' '));
	end
end

%% ---------- 噪声地板 & 样本量检验：TH 的 d(Naive→Learned)=0.178 是"真的没变"还是"鼠太少"？----------
% (A) 噪声地板：同一阶段内把鼠随机对半分，两组轨迹之间的 d。
%     若 d(阶段间) ≫ d(半-半)，说明阶段间差异是真的；若相当，说明只是鼠间噪声。
% (B) 降采样检验：把 ALB 也随机抽到和 TH 同样的鼠数，看 ALB 的 d 会不会掉到 0.18。
fprintf('\n=== (A) 噪声地板：同阶段内"鼠对半分"的 Procrustes d（该队列该阶段的不可约噪声）===\n');
fprintf('%-6s %-9s %8s %9s %14s\n', '队列', '阶段', 'd_noise', 'd_floor95', '鼠数');
floorD = nan(nDS, 4);
for iDS = 1:nDS
	for iS = 1:4
		nM = numel(PM{iDS, iS});
		if nM < 4, continue; end
		dv = nan(500, 1);
		for t = 1:500
			p = randperm(nM); h = floor(nM/2);
			ta = mean(cat(3, PM{iDS, iS}{p(1:h)}), 3);
			tb = mean(cat(3, PM{iDS, iS}{p(h+1:end)}), 3);
			dv(t) = procrustes(ta, tb, 'Scaling', true);
		end
		floorD(iDS, iS) = mean(dv, 'omitnan');
		fprintf('%-6s %-9s %8.3f %9.3f %14d\n', names(iDS), stageNames(iS), mean(dv,'omitnan'), ...
			prctile(dv, 95), nM);
	end
end

fprintf('\n=== 阶段间 d 与噪声地板的比值（>1.5 才算真实差异）===\n');
for iDS = 1:nDS
	for iS = 1:3
		A = PC{iDS, iS}; Bm = PC{iDS, iS+1};
		d0 = procrustes(A, Bm, 'Scaling', true);
		fl = max(floorD(iDS, iS), floorD(iDS, iS+1));
		fprintf('%-6s %-22s d=%.3f  噪声地板=%.3f  比值=%.2f\n', names(iDS), ...
			stageNames(iS) + "→" + stageNames(iS+1), d0, fl, d0 / max(fl, eps));
	end
end

fprintf('\n=== (B) 降采样：把 ALB 随机抽到 nUse 只鼠，重算 Naive→Learned 的 d ===\n');
iA0 = find(names == "ALB", 1);
iTH0 = find(names == "TH", 1);
if ~isempty(iA0) && ~isempty(iTH0)
	nUse = numel(PM{iTH0, 1});
	if ~isnan(nUse) && nUse >= 3
		dv = nan(500, 1); flv = nan(500, 1);
		nA = numel(PM{iA0, 1}); nB = numel(PM{iA0, 2});
		for t = 1:500
			pa = randperm(nA, min(nUse, nA)); pb = randperm(nB, min(nUse, nB));
			ta = mean(cat(3, PM{iA0, 1}{pa}), 3);
			tb = mean(cat(3, PM{iA0, 2}{pb}), 3);
			dv(t) = procrustes(ta, tb, 'Scaling', true);
			% 同规模下的噪声地板（在这 nUse 只里再对半分）
			h = floor(numel(pa)/2);
			fa = procrustes(mean(cat(3, PM{iA0,1}{pa(1:h)}),3), mean(cat(3, PM{iA0,1}{pa(h+1:end)}),3), 'Scaling', true);
			g  = floor(numel(pb)/2);
			fb = procrustes(mean(cat(3, PM{iA0,2}{pb(1:g)}),3), mean(cat(3, PM{iA0,2}{pb(g+1:end)}),3), 'Scaling', true);
			flv(t) = max(fa, fb);
		end
		ciA = prctile(dv, [2.5 97.5]);
		fprintf('ALB 只用 %d 只鼠: d(Naive→Learned) = %.3f ± %.3f  [%.3f, %.3f]\n', ...
			nUse, mean(dv,'omitnan'), std(dv,'omitnan'), ciA(1), ciA(2));
		fprintf('ALB 只用 %d 只鼠: 同规模噪声地板   = %.3f ± %.3f  ⇒ 信噪比 = %.2f\n', ...
			nUse, mean(flv,'omitnan'), std(flv,'omitnan'), mean(dv,'omitnan')/mean(flv,'omitnan'));
	end
end
