% 形状比较的不确定性：按鼠 bootstrap（比 LOMO 稳）
%
% 复用 PCA_StageProgression_ALBvsLAB_0to8s.m 的取数缓存（tempdir/PCAstage_G.mat），不重新取数。
%
% 做法：每个队列×阶段在全数据上拟合 PCA(3) 得公共基；
%       把每只鼠自己的细胞投到该基上 → 每鼠的 2-D 群体轨迹（65×2）；
%       队列轨迹 = 鼠轨迹等权平均；再对"鼠"有放回重采样 B 次 → d 的 95% CI。
%       （同时也给 line bootstrap 作为 trial 噪声的对照，通常远窄于鼠间变异）
%
% 输出：两组关键配对的 Procrustes d + 95% CI。

thisDir = fileparts(mfilename('fullpath'));
cacheFile = fullfile(tempdir, 'PCAstage_G.mat');
if exist(cacheFile, 'file') ~= 2
	fprintf('cache missing -> 先跑取数脚本（约 3-4 min）\n');
	run(fullfile(thisDir, 'PCA_StageProgression_ALBvsLAB_0to8s.m'));
	save(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
	fprintf('cached -> %s\n', cacheFile);
end
load(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
G = PCAstage_G; DSnames = string(DSnames); stageNames = string(stageNames);

nComp = 3;
B = 1000;   % 鼠 bootstrap 次数

%% ---------- 每鼠轨迹（投到全数据基上）----------
PM = cell(nDS, 4);     % 每鼠轨迹：cell{鼠} = T×2
PB = cell(nDS, 4);     % line bootstrap 轨迹：B×T×2
PC = cell(nDS, 4);     % 细胞加权（全数据）轨迹，作图口径
for iDS = 1:nDS
	for iS = 1:4
		data = double(G{iDS, iS}.NTATS.Data);     % cells × T × L
		mouse = string(G{iDS, iS}.Mouse);
		nC = size(data, 1); nT = size(data, 2); nL = size(data, 3);
		nd = MATLAB.DataTypes.NDTable(data);
		T = UniExp.LinearPca(nd, nComp, true);
		co = double(T.Coeff);                      % nComp × nC
		S = double(T.Score.Data);                  % nComp × T × L
		PC{iDS, iS} = double(squeeze(mean(S(1:2, :, :), 3))');
		Xall = reshape(data, nC, [])';             % (T*L) × nC，第 1 维 T 最快变化
		uM = unique(mouse);
		PM{iDS, iS} = cell(numel(uM), 1);
		for i = 1:numel(uM)
			cols = (mouse == uM(i))';
			Ssub = Xall(:, cols) * co(:, cols)';   % (T*L) × nComp
			Sm = reshape(Ssub, nT, nL, nComp);
			m = squeeze(mean(Sm, 2));             % T × nComp
			PM{iDS, iS}{i} = double(m(:, 1:2));
		end
		boot = nan(B, nT, 2);
		for b = 1:B
			idx = randi(nL, nL, 1);
			mb = mean(S(:, :, idx), 3);
			boot(b, :, :) = double(mb(1:2, :)');
		end
		PB{iDS, iS} = boot;
	end
end

%% ---------- 配对 ----------
pairsStage = ["Learned", "ALB", "TH"; "Learned", "ALB", "V7"; "Learned", "ALB", "LAB"; ...
	"Transfer", "ALB", "TH"; "Transfer", "ALB", "V7"; "Transfer", "TH", "V7"; ...
	"Transfer", "ALB", "LAB"; "Final", "ALB", "TH"];
pairsWithin = ["ALB", "Transfer"; "TH", "Transfer"; "V7", "Transfer"; "LAB", "Transfer"; ...
	"ALB", "Final"; "TH", "Final"];
iL = find(stageNames == 'Learned', 1);

fprintf('\n=== (a) 同阶段跨队列：Procrustes d ===\n');
fprintf('%-22s %8s %20s %17s\n', '配对', 'd(细胞加权)', '鼠bootstrap 95%CI', 'lineBoot 95%CI');
for k = 1:size(pairsStage, 1)
	s = pairsStage(k, 1); a = pairsStage(k, 2); b = pairsStage(k, 3);
	iA = find(DSnames == a, 1); iB = find(DSnames == b, 1); iS = find(stageNames == s, 1);
	d0 = iDp(PC{iA, iS}, PC{iB, iS});
	dmb = zeros(B, 1);
	NA = numel(PM{iA, iS}); NB = numel(PM{iB, iS});
	for t = 1:B
		tA = mean(cat(3, PM{iA, iS}{randi(NA, NA, 1)}), 3);
		tB = mean(cat(3, PM{iB, iS}{randi(NB, NB, 1)}), 3);
		dmb(t) = iDp(tA, tB);
	end
	dl = zeros(B, 1);
	for t = 1:B
		dl(t) = iDp(squeeze(PB{iA, iS}(t, :, :)), squeeze(PB{iB, iS}(t, :, :)));
	end
	fprintf('%-22s %8.3f   [%6.3f, %6.3f]    [%6.3f, %6.3f]\n', ...
		sprintf('%s: %s–%s', s, a, b), d0, prctile(dmb, 2.5), prctile(dmb, 97.5), ...
		prctile(dl, 2.5), prctile(dl, 97.5));
end

fprintf('\n=== (b) 同队列 Learned→该阶段（"换阶段"的形状变化量）===\n');
fprintf('%-22s %8s %20s %17s\n', '配对', 'd(细胞加权)', '鼠bootstrap 95%CI', 'lineBoot 95%CI');
for k = 1:size(pairsWithin, 1)
	a = pairsWithin(k, 1); s = pairsWithin(k, 2);
	iA = find(DSnames == a, 1); iS = find(stageNames == s, 1);
	d0 = iDp(PC{iA, iL}, PC{iA, iS});
	Nm = numel(PM{iA, iL});
	dmb = zeros(B, 1);
	for t = 1:B
		idx = randi(Nm, Nm, 1);          % 同一组鼠用于两个阶段
		t1 = mean(cat(3, PM{iA, iL}{idx}), 3);
		t2 = mean(cat(3, PM{iA, iS}{idx}), 3);
		dmb(t) = iDp(t1, t2);
	end
	dl = zeros(B, 1);
	for t = 1:B
		dl(t) = iDp(squeeze(PB{iA, iL}(t, :, :)), squeeze(PB{iA, iS}(t, :, :)));
	end
	fprintf('%-22s %8.3f   [%6.3f, %6.3f]    [%6.3f, %6.3f]\n', ...
		sprintf('%s: Learned→%s', a, s), d0, prctile(dmb, 2.5), prctile(dmb, 97.5), ...
		prctile(dl, 2.5), prctile(dl, 97.5));
end

%% ========== local ==========
function d = iDp(X, Y)
d = procrustes(double(X), double(Y), 'Scaling', true, 'Reflection', false);
end
