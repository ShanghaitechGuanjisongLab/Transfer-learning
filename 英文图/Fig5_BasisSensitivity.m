% Fig5 补充：**PC 基敏感性检验**（留出基 held-out basis）
%
% 问题：Fig5 的 (a)(b)(c) 与所有形态学统计都在"每队列四阶段合并拟合"的 PC 基里做。
%       合并方差 = 阶段内 + 阶段间，所以 PC1/PC2 会优先挑"阶段之间差别大"的方向 ——
%       这会让阶段间差异看起来更清楚（一种"基里偷看答案"的隐忧）。
%
% 做法：把 PC 基的来源换成**单个阶段**，其余阶段全部**投影**进去（out-of-sample），
%       重算 d 与能量比，看结论是否改变。三种基：
%         Pooled  = 四阶段合并拟合（主口径，同 Fig5）
%         Naive   = 只用 Naive 拟合（学习前的中立基）
%         Learned = 只用 Learned 拟合
%       ⚠ Naive 基下 Learned/Transfer 都是 out-of-sample，因此最适合检验 (b)(c) 的比较；
%         Learned 基下 Learned 是 in-sample，其幅度会被高估（分母偏大）→ 能量比偏低。
%
% 输出：Fig5_Morphology_BasisSensitivity.csv

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nLines = 10; Bboot = 2000; rng(20261113, 'twister');
cacheFile = fullfile(tempdir, 'PCAstage_G_MOp2-3.mat');
assert(exist(cacheFile, 'file') == 2, 'BasisSens:NoCache', '缺 %s', cacheFile);
Cs = load(cacheFile, 'PCAstage_G', 'DSnames');
G = Cs.PCAstage_G; dsNames = string(Cs.DSnames(:));
cohorts = ["ALB", "V7"];
basisNames = ["Pooled", "Naive", "Learned"];

%% ---------- 取各阶段数据（四阶段共有细胞）----------
DATA = cell(2, 4); MO = cell(2, 4);
for k = 1:2
	iDS = find(dsNames == cohorts(k), 1);
	common = G{iDS, 1}.CellUID;
	for iS = 2:4, common = intersect(common, G{iDS, iS}.CellUID); end
	common = sort(unique(common));
	for iS = 1:4
		[ok, loc] = ismember(common, G{iDS, iS}.CellUID);
		assert(all(ok));
		DATA{k, iS} = double(G{iDS, iS}.NTATS.Data(loc, :, :));
		mo = string(G{iDS, iS}.Mouse);
		MO{k, iS} = mo(loc);
	end
	fprintf('%s: %d 个四阶段共有细胞\n', cohorts(k), numel(common));
end

%% ---------- 三种基 × 两队列 ----------
f = @(x) [mean(x), prctile(x, 2.5), prctile(x, 97.5)];
Res = struct();
Rows = {};
for k = 1:2
	nm = cohorts(k);
	nCk = size(DATA{k, 1}, 1);
	for b = 1:numel(basisNames)
		switch basisNames(b)
			case "Pooled",  BX = cat(3, DATA{k, 1}, DATA{k, 2}, DATA{k, 3}, DATA{k, 4});
			case "Naive",   BX = DATA{k, 1};
			case "Learned", BX = DATA{k, 2};
		end
		Tb = UniExp.LinearPca(MATLAB.DataTypes.NDTable(BX), 2, true);
		cob = double(Tb.Coeff);
		% 逐鼠轨迹（在**该基**上的投影）
		PMb = cell(1, 4);
		for iS = 1:4
			mo = MO{k, iS}; uM = unique(mo); X = DATA{k, iS};
			PMb{iS} = cell(numel(uM), 1);
			for i = 1:numel(uM)
				x = squeeze(mean(X(mo == uM(i), :, :), 3, 'omitnan'));   % cells_m × T
				PMb{iS}{i} = (cob(:, mo == uM(i)) * x)';                 % T × 2
			end
		end
		n1 = numel(PMb{1}); n2 = numel(PMb{2}); n3 = numel(PMb{3}); n4 = numel(PMb{4});
		vNL = nan(Bboot,1); vLT = nan(Bboot,1);
		wNL = nan(Bboot,1); wLT = nan(Bboot,1);
		eLT = nan(Bboot,1); eFI = nan(Bboot,1);
		for t = 1:Bboot
			a1 = mean(cat(3, PMb{1}{randi(n1, n1, 1)}), 3);
			a2 = mean(cat(3, PMb{2}{randi(n2, n2, 1)}), 3);
			b3 = mean(cat(3, PMb{3}{randi(n3, n3, 1)}), 3);
			b4 = mean(cat(3, PMb{4}{randi(n4, n4, 1)}), 3);
			vNL(t) = iDNoRot(a1, a2); vLT(t) = iDNoRot(a2, b3);
			wNL(t) = procrustes(a1, a2, 'Scaling', true);
			wLT(t) = procrustes(a2, b3, 'Scaling', true);
			eLT(t) = rms(vecnorm(b3, 2, 2)) / rms(vecnorm(a2, 2, 2));
			eFI(t) = rms(vecnorm(b4, 2, 2)) / rms(vecnorm(a2, 2, 2));
		end
		fn = char(basisNames(b));
		Res.(nm).(fn) = struct('NLrot', wNL, 'LTrot', wLT, 'NLnrt', vNL, 'LTnrt', vLT, 'eLT', eLT, 'eFI', eFI);
		a = f(wNL); c = f(vNL);
		Rows(end+1, :) = {nm, fn, 'Naive→Learned', a(1), a(2), a(3), c(1), c(2), c(3)}; %#ok<SAGROW>
		a = f(wLT); c = f(vLT);
		Rows(end+1, :) = {nm, fn, 'Learned→Transfer', a(1), a(2), a(3), c(1), c(2), c(3)}; %#ok<SAGROW>
		e = f(eLT);
		Rows(end+1, :) = {nm, fn, 'EnergyRatio_T/L', NaN, NaN, NaN, e(1), e(2), e(3)}; %#ok<SAGROW>
		e = f(eFI);
		Rows(end+1, :) = {nm, fn, 'EnergyRatio_F/L', NaN, NaN, NaN, e(1), e(2), e(3)}; %#ok<SAGROW>
	end
end

%% ---------- 打印 ----------
fprintf('\n===== 三种 PC 基下的形态学指标（逐鼠 bootstrap %d 次）=====\n', Bboot);
fprintf('%-4s %-8s | %-19s | %-19s | %-13s | %s\n', '队列', 'PC基', ...
	'd(旋转) N→L / L→T', 'd(禁旋转) N→L / L→T', '能量比 T/L', 'F/L');
for k = 1:2
	nm = cohorts(k);
	for b = 1:numel(basisNames)
		R = Res.(nm).(char(basisNames(b)));
		fprintf('%-4s %-8s | %.3f / %.3f       | %.3f / %.3f       | %.2f [%.2f,%.2f] | %.2f\n', ...
			nm, basisNames(b), mean(R.NLrot), mean(R.LTrot), mean(R.NLnrt), mean(R.LTnrt), ...
			mean(R.eLT), prctile(R.eLT,2.5), prctile(R.eLT,97.5), mean(R.eFI));
	end
end

fprintf('\n===== 组间差 V7 − ALB（Learned→Transfer），按 PC 基分别给 =====\n');
for b = 1:numel(basisNames)
	fn = char(basisNames(b));
	dR = Res.V7.(fn).LTrot - Res.ALB.(fn).LTrot;
	dN = Res.V7.(fn).LTnrt - Res.ALB.(fn).LTnrt;
	eE = log(Res.V7.(fn).eLT) - log(Res.ALB.(fn).eLT);
	a = f(dR); c = f(dN); e = f(eE);
	p1 = 2*min(mean(dR<=0), mean(dR>=0));
	p2 = 2*min(mean(dN<=0), mean(dN>=0));
	p3 = 2*min(mean(eE<=0), mean(eE>=0));
	fprintf('  %-8s d(旋转)   Δ=%+.3f [%+.3f,%+.3f] p=%.4g\n', fn, a(1), a(2), a(3), p1);
	fprintf('  %-8s d(禁旋转) Δ=%+.3f [%+.3f,%+.3f] p=%.4g\n', fn, c(1), c(2), c(3), p2);
	fprintf('  %-8s 能量比     V7/ALB=%.2f 倍 p=%.4g\n', fn, exp(e(1)), p3);
end

%% ---------- 写 CSV ----------
Tab = cell2table(Rows, 'VariableNames', ["Cohort", "PCBasis", "Metric", ...
	"d_rot", "d_rot_lo", "d_rot_hi", "d_norot", "d_norot_lo", "d_norot_hi"]);
writetable(Tab, fullfile(thisDir, 'Fig5_Morphology_BasisSensitivity.csv'));
fprintf('\nWrote: %s\n', fullfile(thisDir, 'Fig5_Morphology_BasisSensitivity.csv'));

%% ========== local ==========
function d = iDNoRot(A, B)
% Procrustes 距离，禁止旋转与镜像，只允许平移 + 等比缩放；d = 2(1-cos)
a = A - mean(A, 1); b = B - mean(B, 1);
a = a / norm(a, 'fro'); b = b / norm(b, 'fro');
d = 2 - 2 * sum(a(:) .* b(:));
end
