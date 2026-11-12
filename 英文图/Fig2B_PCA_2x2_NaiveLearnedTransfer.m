% 英文图2B：PCA 结果图（2×2），复用已有阶段信号，每个 tile 独立拟合 PCA
%   上排（均来自 ALB，声→光）：Naive·AW      | Learned·AW
%   下排：                     Naive·LW（LAB）| Transfer·LW（ALB）
%
% 口径与前几张完全一致：
%   - cue 后 0–8 s，65 帧；逐回合 z-score（基线 cue 前 3 s，sd = max(基线段, 0.5×全 block)）
%   - 只取 MOp2/3；超鼠：每细胞把回合均分成 10 组取平均
%   - PCA：每格仅使用本数据库、本阶段的数据和细胞，分别计算 PC1/PC2，不取跨阶段细胞交集
%     ⇒ 四格的 PC 空间独立，只展示轨迹形态，不跨 tile 比较具体坐标
%   - 着色：线内时间渐变（cue 端浅 → 8 s 端为阶段色）
%   - 每格使用自身自动轴限，并标注自身 PC 的解释方差
%
% 依赖：tempdir/PCAstage_G.mat（由 PCA_StageProgression_ALBvsLAB_0to8s.m 生成，约 3–4 min 首次）
% 输出：English_Fig2B_PCA_2x2_NaiveLearnedTransfer.svg。

thisDir = fileparts(mfilename('fullpath'));
cacheFile = fullfile(tempdir, 'PCAstage_G.mat');
if exist(cacheFile, 'file') ~= 2
	fprintf('cache missing -> 先跑取数脚本（约 3–4 min）\n');
	run(fullfile(thisDir, 'PCA_StageProgression_ALBvsLAB_0to8s.m'));
	save(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
end
C = load(cacheFile, 'PCAstage_G', 'DSnames', 'stageNames');
G = C.PCAstage_G;
names = string(C.DSnames(:));
stageNames = string(C.stageNames(:));

nLines = 10;
iALB = find(names == "ALB", 1);
iLAB = find(names == "LAB", 1);

% 每格：[数据集序号(1=ALB,2=LAB), 阶段序号, 阶段色, 标题, 来源标签]
tiles = {
	1, 1, TransferLearning.ColorNaive / 255,   "Naive audio water",    "ALB"
	1, 2, TransferLearning.ColorLearned / 255, "Learned audio water",  "ALB"
	2, 1, TransferLearning.ColorNaive / 255,   "Naive Light water",    "LAB"
	1, 3, TransferLearning.Color12h / 255,     "Transfer Light water", "ALB"
};

%% ---------- 每个 tile 独立拟合 PCA ----------
P = cell(size(tiles, 1), 1);
expVar = zeros(size(tiles, 1), 2);
dsIdx = [iALB, iLAB];
for k = 1:size(tiles, 1)
	iDS = dsIdx(tiles{k, 1});
	iS = tiles{k, 2};
	stageData = G{iDS, iS};
	T = UniExp.LinearPca(stageData.NTATS, 2, true);
	expVar(k, :) = T.Explained(1:2)';
	P{k} = double(T.Score.Data);
	fprintf('tile %d: %s %s, %d 细胞, PC1=%.2f%%, PC2=%.2f%%\n', k, names(iDS), stageNames(iS), height(stageData), expVar(k, 1), expVar(k, 2));
end

%% ---------- 版面 ----------
f = figure('Color', 'w', 'Name', 'English Fig2B PCA 2x2 Naive/Learned/Transfer');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

nSeg = 64;
tlo = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'tight');
axAll = gobjects(2, 2);
for k = 1:4
	ax = nexttile(tlo);
	xy = P{k};   % 2 × 65 × 10
	iFadeLines(ax, xy, tiles{k, 3}, nSeg);
	title(ax, tiles{k, 4});
	xlabel(ax, sprintf('PC1 (%.1f%%)', expVar(k, 1)));
	ylabel(ax, sprintf('PC2 (%.1f%%)', expVar(k, 2)));
	box(ax, 'off');
	ax.Toolbar.Visible = 'off';
	axAll(k) = ax;
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2B_PCA_2x2_NaiveLearnedTransfer.svg');
fprintf('Wrote: %s\n', svgPath);
copyfile(svgPath, fullfile(thisDir, '_chk_2x2.svg'));

%% ========== local ==========
function iFadeLines(ax, PcaData, baseColor, nSeg)
% 线内时间渐变：cue 端 88% 白（浅但可见）→ 8 s 端为基色，一次 patch 画完所有轨迹
nLines = size(PcaData, 3);
nTime = size(PcaData, 2);
tt = linspace(1, nTime, nSeg + 1);
w = linspace(0, 1, nSeg + 1)';
startC = 0.88;
cv = startC + w * (baseColor(:)' - startC);
X = nan(nSeg + 2, nLines);
Y = nan(nSeg + 2, nLines);
for iLine = 1:nLines
	xy = squeeze(PcaData(:, :, iLine));
	X(1:nSeg + 1, iLine) = interp1(1:nTime, xy(1, :), tt);
	Y(1:nSeg + 1, iLine) = interp1(1:nTime, xy(2, :), tt);
end
C = repmat(reshape(cv, [nSeg + 1, 1, 3]), 1, nLines, 1);
C(end + 1, :, :) = repmat(reshape(cv(end, :), [1, 1, 3]), 1, nLines, 1);
hold(ax, 'on');
patch(ax, X, Y, C, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.5);
view(ax, 2);
end
