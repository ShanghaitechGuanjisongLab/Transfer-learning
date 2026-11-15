% 表征复用：Learned ensemble 在 Transfer 的重激活率（ALB 声→光 / LAB 光→声）
%
% 设计（比"单帧 >3σ"更稳，并把"动作"问题拆出来）：
%   1) ensemble 统一用 **Learned 阶段 cue 后 0.5–1.5 s** 定义：
%      每细胞先按 line 求窗口均值 → 对 10 条 line 做单样本 t 检验（vs 0）→ t > 2.5 视为活跃
%      （z 已按 cue 前 3 s 基线逐回合归一，故 0 = 基线）
%   2) 读出窗口有两个：   "1 s" = 0.5–1.5 s（含舔/给水期）；"noLick" = 0–0.25 s（舔尚未发生）
%      ⇒ ensemble 细胞在目标阶段的活跃率 vs **非 ensemble 细胞**（同鼠同阶段）作对照
%   3) 关键对比：Transfer(ens) − Transfer(ctl)，以及 Transfer(ens) − Naive(ens)
%
% 依赖：tempdir/PCAstage_G.mat
% 输出：RepresentationReuse_Reactivation.csv + 控制台表

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

cacheFile = fullfile(tempdir, 'PCAstage_G.mat');
if exist(cacheFile, 'file') ~= 2
	fprintf('cache missing -> 先跑取数脚本（约 3–4 min）\n');
	run(fullfile(thisDir, 'PCA_StageProgression_ALBvsLAB_0to8s.m'));
	save(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
end
C = load(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames');
G = C.PCAstage_G; names = string(C.DSnames(:)); stageNames = string(C.stageNames(:));

iALB = find(names == "ALB", 1);  iLAB = find(names == "LAB", 1);
cohorts = [iALB, iLAB];
cohortNames = ["ALB 声→光", "LAB 光→声"];
iL = find(stageNames == 'Learned', 1);
tSec = (0:64)' * 0.125;
tThr = 2.5;

winDef = struct();
winDef(1).Name = "1 s (0.5-1.5s)";   winDef(1).Mask = (tSec >= 0.5) & (tSec <= 1.5);
winDef(2).Name = "noLick (0-0.25s)"; winDef(2).Mask = (tSec >= 0) & (tSec <= 0.25);

Rows = {};
for ic = 1:2
	iDS = cohorts(ic);
	common = G{iDS, 1}.CellUID;
	for s = 2:4, common = intersect(common, G{iDS, s}.CellUID); end
	common = sort(unique(common));
	ACT = cell(1, 2);
	for iw = 1:2
		A = false(numel(common), 4);
		for s = 1:4
			[~, loc] = ismember(common, G{iDS, s}.CellUID);
			D = double(G{iDS, s}.NTATS.Data(loc, :, :));       % cells × 65 × nLines
			W = squeeze(mean(D(:, winDef(iw).Mask, :), 2));    % cells × nLines
			nL = size(W, 2);
			m = mean(W, 2);
			se = std(W, 0, 2) / sqrt(nL);
			se(se == 0 | ~isfinite(se)) = NaN;
			A(:, s) = (m ./ se) > tThr;
		end
		ACT{iw} = A;
	end
	[~, loc1] = ismember(common, G{iDS, 1}.CellUID);
	MS = string(G{iDS, 1}.Mouse(loc1));
	mice = unique(MS);

	fprintf('\n=============== %s（%d 鼠, %d 细胞）===============\n', cohortNames(ic), numel(mice), numel(common));
	for iw = 1:2
		A = ACT{iw};
		fprintf('--- 读出窗口：%s ---\n', winDef(iw).Name);
		fprintf('%-9s %11s %15s %17s %15s\n', '鼠', 'Learned活跃%', 'Naive ens/ctl', 'Transfer ens/ctl', 'Final ens/ctl');
		for m = 1:numel(mice)
			isM = MS == mice(m);
			ens = A(isM, iL);
			if ~any(ens), continue; end
			ensAll = false(numel(common), 1); ensAll(isM) = ens;
			rr = nan(3, 2);
			for k = 1:3
				s = [1 3 4];
				s = s(k);
				a = A(:, s);
				rr(k, 1) = mean(a(ensAll));
				ctl = isM & ~ensAll;
				if any(ctl), rr(k, 2) = mean(a(ctl)); end
			end
			fprintf('%-9s %11.1f %7.1f/%-7.1f %8.1f/%-8.1f %7.1f/%-7.1f\n', mice(m), 100*mean(ens), ...
				100*rr(1,1), 100*rr(1,2), 100*rr(2,1), 100*rr(2,2), 100*rr(3,1), 100*rr(3,2));
			Rows(end+1, :) = {char(cohortNames(ic)), char(winDef(iw).Name), char(mice(m)), 100*mean(ens), ...
				100*rr(1,1), 100*rr(1,2), 100*rr(2,1), 100*rr(2,2), 100*rr(3,1), 100*rr(3,2)}; %#ok<SAGROW>
		end
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Window", "Mouse", "LearnedActivePct", ...
	"NaiveEnsPct", "NaiveCtlPct", "TransferEnsPct", "TransferCtlPct", "FinalEnsPct", "FinalCtlPct"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_Reactivation.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠配对，均值 ± SEM）===============\n');
for ic = 1:2
	for iw = 1:2
		sel = strcmp(T.Cohort, cohortNames(ic)) & strcmp(T.Window, winDef(iw).Name);
		if ~any(sel), continue; end
		dT = T.TransferEnsPct(sel) - T.TransferCtlPct(sel);
		dN = T.NaiveEnsPct(sel) - T.NaiveCtlPct(sel);
		tvN = T.TransferEnsPct(sel) - T.NaiveEnsPct(sel);
		fprintf('%-11s %-18s n=%2d | Transfer(ens-ctl)=%+6.1f±%4.1f p=%.3g | Naive(ens-ctl)=%+6.1f±%4.1f p=%.3g | Transf-Naive(ens)=%+6.1f±%4.1f p=%.3g\n', ...
			cohortNames(ic), winDef(iw).Name, sum(sel), mean(dT), std(dT)/sqrt(sum(sel)), iSafeSignrank(dT), ...
			mean(dN), std(dN)/sqrt(sum(sel)), iSafeSignrank(dN), mean(tvN), std(tvN)/sqrt(sum(sel)), iSafeSignrank(tvN));
	end
end

%% ========== local ==========
function p = iSafeSignrank(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0)
	p = NaN;
else
	p = signrank(x);
end
end
