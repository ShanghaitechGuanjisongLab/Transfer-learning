% 跨队列轨迹形状比较（不需要同一批细胞）：② 形状不变量 + ③ Procrustes 对齐
%
% 背景：四个队列（ALB / TH / V7 / LAB）是不同鼠、不同 CellUID，PCA 的变量（细胞）
%       对不上 ⇒ 不能"合并拟合"。但轨迹形状比较可以退到**群体层面**：
%       各自拟合 PCA → 取各自 2-D 平均轨迹（65 时间点）→
%       用 (a) 与坐标无关的不变量、(b) 允许旋转+缩放的 Procrustes 对齐来比较。
%
% 首次运行会 run(PCA_StageProgression_ALBvsLAB_0to8s.m) 取数据，并把取数结果缓存到
% tempdir/PCAstage_G.mat，之后重跑本脚本只读缓存（改指标/调试很快）。
%
% 输出：打印 3 张表 + CSV(PCA_StageShape_Invariants.csv)

thisDir = fileparts(mfilename('fullpath'));
cacheFile = fullfile(tempdir, 'PCAstage_G.mat');

if exist('PCAstage_G', 'var') && ~isempty(PCAstage_G) && exist('nDS', 'var')
	% 已有
elseif exist(cacheFile, 'file')
	load(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
else
	run(fullfile(thisDir, 'PCA_StageProgression_ALBvsLAB_0to8s.m'));
	save(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
	fprintf('cached -> %s\n', cacheFile);
end
G = PCAstage_G;
DSnames = string(DSnames);
stageNames = string(stageNames);

nStat = 10;   % 计算不变量用前 10 个成分

%% ---------- 1) 不变量 ----------
Inv = struct('Row', {}, 'Stage', {}, 'PC1', {}, 'PC2', {}, 'PC3', {}, 'PR', {}, ...
	'Energy', {}, 'Closure', {}, 'RetDist', {}, 'Traj', {});
k = 0;
for iDS = 1:nDS
	for iS = 1:4
		k = k + 1;
		T = UniExp.LinearPca(G{iDS, iS}.NTATS, nStat, true);
		D = double(T.Score.Data);         % nStat × T × nLines
		m = mean(D, 3);                   % 对 nLines 平均 = 去 trial 噪声
		a = range(m, 2)';
		E = sqrt(sum(a(1:3).^2) / 12);    % 轨迹能量（前 3 维，≈ z 单位）
		xy = double(m(1:2, :)');
		L = sum(vecnorm(diff(xy, 1, 1), 2, 2));
		d0 = norm(xy(end, :) - xy(1, :));
		closure = d0 / max(L, eps);
		dtS = 8 / (size(xy, 1) - 1);
		idxAfter = find((0:size(xy, 1) - 1)' * dtS >= 0.5);
		dRet = min(vecnorm(xy(idxAfter, :) - xy(1, :), 2, 2));
		e = T.Explained(1:nStat);
		PR = sum(e)^2 / sum(e.^2);
		Inv(k).Row = DSnames(iDS);
		Inv(k).Stage = stageNames(iS);
		Inv(k).PC1 = T.Explained(1);
		Inv(k).PC2 = T.Explained(2);
		Inv(k).PC3 = T.Explained(3);
		Inv(k).PR = PR;
		Inv(k).Energy = E;
		Inv(k).Closure = closure;
		Inv(k).RetDist = dRet / max(L, eps);
		Inv(k).Traj = xy;
	end
end
assert(all(arrayfun(@(x) isnumeric(x.Traj) && size(x.Traj, 2) == 2, Inv)), ...
	'Traj must be numeric n-by-2.');

fprintf('\n=== 形状不变量（每阶段各自拟合 10 成分）===\n');
fprintf('%-4s %-9s %6s %6s %6s %5s %6s %7s %7s\n', '行', '阶段', 'PC1%', 'PC2%', 'PC3%', 'PR', '能量E', '闭合度', '回转距');
for i = 1:numel(Inv)
	fprintf('%-4s %-9s %6.2f %6.2f %6.2f %5.2f %6.1f %7.2f %7.2f\n', Inv(i).Row, Inv(i).Stage, ...
		Inv(i).PC1, Inv(i).PC2, Inv(i).PC3, Inv(i).PR, Inv(i).Energy, Inv(i).Closure, Inv(i).RetDist);
end

%% ---------- 2) Procrustes ----------
iFind = @(r, s) find(strcmp(string({Inv.Row}), r) & strcmp(string({Inv.Stage}), s), 1);
getT = @(idx) double(Inv(idx).Traj);

fprintf('\n=== Procrustes 对齐（允许旋转+缩放；d 越小形状越像）===\n');
for iS = 1:4
	fprintf('\n--- 同阶段跨队列：%s ---\n', stageNames(iS));
	fprintf('%-6s', '');
	for j = 1:nDS, fprintf('%8s', DSnames(j)); end
	fprintf('%9s %9s %8s\n', 'd(镜像)', '旋转角°', 'scale');
	for i = 1:nDS
		fprintf('%-6s', DSnames(i));
		for j = 1:nDS
			if i == j
				fprintf('%8s', '-');
			else
				d = procrustes(getT(iFind(DSnames(i), stageNames(iS))), ...
					getT(iFind(DSnames(j), stageNames(iS))), 'Scaling', true, 'Reflection', false);
				fprintf('%8.3f', d);
			end
		end
		[d2, ~, tr] = procrustes(getT(iFind('ALB', stageNames(iS))), ...
			getT(iFind(DSnames(i), stageNames(iS))), 'Scaling', true, 'Reflection', true);
		ang = atan2d(tr.T(2, 1), tr.T(1, 1));
		if strcmp(stageNames(iS), 'Learned')
			refTxt = '-';
		else
			dr = procrustes(getT(iFind(DSnames(i), 'Learned')), ...
				getT(iFind(DSnames(i), stageNames(iS))), 'Scaling', true, 'Reflection', false);
			refTxt = sprintf('%.3f', dr);
		end
		fprintf('%9.3f %9.1f %8.2f  [同队列 Learned→%s d=%s]\n', d2, ang, tr.b, stageNames(iS), refTxt);
	end
end

%% ---------- 3) CSV（手写，避开 table 的维度名冲突）----------
csvPath = fullfile(thisDir, 'PCA_StageShape_Invariants.csv');
fid = fopen(csvPath, 'w');
fprintf(fid, 'Row,Stage,PC1pct,PC2pct,PC3pct,PR,Energy,Closure,RetDist\n');
for i = 1:numel(Inv)
	fprintf(fid, '%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.4f,%.4f\n', Inv(i).Row, Inv(i).Stage, ...
		Inv(i).PC1, Inv(i).PC2, Inv(i).PC3, Inv(i).PR, Inv(i).Energy, Inv(i).Closure, Inv(i).RetDist);
end
fclose(fid);
fprintf('\nWrote: %s\n', csvPath);

assignin('base', 'PCAstage_Inv', rmfield(Inv, 'Traj'));
