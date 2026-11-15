% 形状对齐的"镜像敏感性"检查：允许镜像 vs 禁止镜像（只允许旋转+平移+等比缩放）
%
% ⚠ 先说原理：本工程的轨迹 PC 是**每个队列×阶段独立拟合**的（见 StageShapeAlignment.m
%   循环内 UniExp.LinearPca(...)），而独立 PCA 的 PC 符号是任意的（一根轴翻号 = 二维平面里的镜像）。
%   所以在原理上"禁止镜像"会把**符号约定差异**算成**形状差异**。本脚本只是把它量化出来。
%
% 输出：
%   1) 逐队列×阶段：d(允许镜像) / d(禁止镜像) / 最优变换是否含镜像(det T = -1) / 形状相关 r=1-d/2
%   2) 结论是否翻转（同一显著性判断下）
%   CSV: English_StageShapeAlignment_ReflectionCheck.csv

thisDir = fileparts(mfilename('fullpath'));
nComp = 3;

mainCache = fullfile(tempdir, 'PCAstage_G.mat');
dlyCache  = fullfile(tempdir, 'PCAstage_G_delayed.mat');
assert(exist(mainCache, 'file') == 2, '缺缓存，请先跑 PCA_StageProgression_ALBvsLAB_0to8s.m');

C = load(mainCache, 'PCAstage_G', 'DSnames', 'stageNames');
G4 = C.PCAstage_G; names4 = string(C.DSnames(:)); stageNames = string(C.stageNames(:));
G = G4; names = names4;
% 延迟组（ALD）是另一套任务，当前分析默认**不纳入**；需要时在 base 里设 IncludeALD = true。
if ~exist('IncludeALD', 'var') || ~islogical(IncludeALD), IncludeALD = false; end
if IncludeALD && exist(dlyCache, 'file') == 2
	Dz = load(dlyCache, 'G', 'DSnames');
	G = [G4; {Dz.G{1,1}, Dz.G{1,2}, Dz.G{1,3}, Dz.G{1,4}}];
	names = [names4; "ALD"];
elseif exist(dlyCache, 'file') ~= 2
	fprintf('提示：无 ALD 缓存，仅比较 %s\n', strjoin(names, '/'));
end
nDS = numel(names);
iALB = find(names == "ALB", 1);

%% ---------- 每队列×阶段：群体轨迹（与 StageShapeAlignment 完全同口径）----------
PC = cell(nDS, 4);
for iDS = 1:nDS
	for iS = 1:4
		data = double(G{iDS, iS}.NTATS.Data);
		nC = size(data, 1); nT = size(data, 2); nL = size(data, 3);
		T = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), nComp, true);
		S = double(T.Score.Data);
		PC{iDS, iS} = double(squeeze(mean(S(1:2, :, :), 3))');
	end
end

%% ---------- 两种 Procrustes ----------
dFree = nan(nDS, 4); dNoRef = nan(nDS, 4); usedMirror = false(nDS, 4);
for iS = 1:4
	for iDS = 1:nDS
		if iDS == iALB, continue; end
		X = PC{iALB, iS}; Y = PC{iDS, iS};
		[dFree(iDS, iS), ~, tr] = procrustes(X, Y, 'Scaling', true);
		usedMirror(iDS, iS) = det(tr.T) < 0;
		dNoRef(iDS, iS) = procrustes(X, Y, 'Scaling', true, 'Reflection', false);
	end
end

Rows = {};
fprintf('\n=== 镜像敏感性：d(允许镜像) vs d(禁止镜像) ===\n');
fprintf('%-9s %-6s %10s %10s %8s %8s %8s %10s\n', ...
	'阶段', '队列', 'd(自由)', 'd(禁镜像)', '倍数', 'r自由', 'r禁镜像', '最优变换');
for iS = 1:4
	for iDS = 1:nDS
		if iDS == iALB, continue; end
		fprintf('%-9s %-6s %10.3f %10.3f %8.2f %8.2f %8.2f %10s\n', ...
			stageNames(iS), names(iDS), dFree(iDS, iS), dNoRef(iDS, iS), ...
			dNoRef(iDS, iS) / max(dFree(iDS, iS), eps), 1 - dFree(iDS, iS)/2, 1 - dNoRef(iDS, iS)/2, ...
			string(ifelse(usedMirror(iDS, iS), "含镜像", "纯旋转")));
		Rows(end+1, :) = {string(stageNames(iS)), string(names(iDS)), dFree(iDS, iS), dNoRef(iDS, iS), ...
			dNoRef(iDS, iS)/max(dFree(iDS, iS), eps), 1 - dFree(iDS, iS)/2, 1 - dNoRef(iDS, iS)/2, ...
			usedMirror(iDS, iS)}; %#ok<SAGROW>
	end
end

T = cell2table(Rows, 'VariableNames', ["Stage", "Cohort", "d_Free", "d_NoReflect", ...
	"Ratio", "r_Free", "r_NoReflect", "UsedMirror"]);
csvPath = fullfile(thisDir, 'English_StageShapeAlignment_ReflectionCheck.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

%% ---------- 阈值判断（沿用之前的口径：d<0.25 视为"同形状"）----------
thr = 0.25;
fprintf('\n=== 判定翻转检查（阈值 d < %.2f 视为"形状一致"）===\n', thr);
anyFlip = false;
for iS = 1:4
	for iDS = 1:nDS
		if iDS == iALB, continue; end
		a = dFree(iDS, iS) < thr;  b = dNoRef(iDS, iS) < thr;
		if a ~= b
			anyFlip = true;
			fprintf('  ⚠ %-9s %-4s：允许镜像 %s（d=%.3f）→ 禁止镜像 %s（d=%.3f）\n', ...
				stageNames(iS), names(iDS), string(ifelse(a, "一致", "不一致")), dFree(iDS, iS), ...
				string(ifelse(b, "一致", "不一致")), dNoRef(iDS, iS));
		end
	end
end
if ~anyFlip
	fprintf('  无翻转：所有组合在两种设置下判定一致。\n');
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
