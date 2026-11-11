% 英文图2B：PCA 结果图（2×2），复用已有 PCA（每数据集 4 阶段合并拟合），只重排版面
%   上排（均来自 ALB，声→光）：Naive·AW      | Learned·AW
%   下排：                     Naive·LW（LAB）| Transfer·LW（ALB）
%
% 口径与前几张完全一致：
%   - cue 后 0–8 s，65 帧；逐回合 z-score（基线 cue 前 3 s，sd = max(基线段, 0.5×全 block)）
%   - 只取 MOp2/3；超鼠：每细胞把回合均分成 10 组取平均
%   - PCA：ALB 用其 4 阶段合并拟合的 PC1/PC2；LAB 用其 4 阶段合并拟合的 PC1/PC2
%     ⇒ 上排两格 + 右下格共用 ALB 的 PC 空间；左下格用 LAB 的 PC 空间
%   - 着色：线内时间渐变（cue 端浅 → 8 s 端为阶段色）
%   - 四格统一轴跨度（各自保留中心）
%
% 依赖：tempdir/PCAstage_G.mat（由 PCA_StageProgression_ALBvsLAB_0to8s.m 生成，约 3–4 min 首次）
% 输出：English_Fig2B_PCA_2x2_NaiveLearnedTransfer.svg，以及每格自适应轴限的_tilescale版本。

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

%% ---------- 每个数据集：4 阶段合并拟合一次 PCA（与之前一致）----------
P = cell(2, 4);  expVar = zeros(2, 2);
dsIdx = [iALB, iLAB];
for k = 1:2
	iDS = dsIdx(k);
	common = G{iDS, 1}.CellUID;
	for iS = 2:4
		common = intersect(common, G{iDS, iS}.CellUID);
	end
	common = sort(unique(common));
	data = nan(numel(common), size(G{iDS, 1}.NTATS.Data, 2), 4 * nLines);
	for iS = 1:4
		[ok, loc] = ismember(common, G{iDS, iS}.CellUID);
		assert(all(ok), 'Cell mismatch');
		data(:, :, (iS - 1) * nLines + (1:nLines)) = G{iDS, iS}.NTATS.Data(loc, :, :);
	end
	T = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), 2, true);
	expVar(k, :) = T.Explained(1:2)';
	score = double(T.Score.Data);
	for iS = 1:4
		P{k, iS} = score(:, :, (iS - 1) * nLines + (1:nLines));
	end
	fprintf('%s: %d 细胞, PC1=%.2f%%, PC2=%.2f%%\n', names(iDS), numel(common), expVar(k, 1), expVar(k, 2));
end

%% ---------- 版面 ----------
% 每格：[数据集序号(1=ALB,2=LAB), 阶段序号, 阶段色, 标题, 来源标签]
tiles = {
	1, 1, TransferLearning.ColorNaive / 255,   "Naive audio water",    "ALB"
	1, 2, TransferLearning.ColorLearned / 255, "Learned audio water",  "ALB"
	2, 1, TransferLearning.ColorNaive / 255,   "Naive Light water",    "LAB"
	1, 3, TransferLearning.Color12h / 255,     "Transfer Light water", "ALB"
};

f = figure('Color', 'w', 'Name', 'English Fig2B PCA 2x2 Naive/Learned/Transfer');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

nSeg = 64;
AxisModes = ["unified", "tile"];   % unified = 四格同跨度可比；tile = 每格自适应（形状最大化）
for iM = 1:numel(AxisModes)
	set(f, 'Name', sprintf('English Fig2B PCA 2x2 [%s]', AxisModes(iM)));
	delete(f.Children);
	tlo = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'tight');
	axAll = gobjects(2, 2);
	for k = 1:4
		ax = nexttile(tlo);
		xy = P{tiles{k, 1}, tiles{k, 2}};   % 2 × 65 × 10
		iFadeLines(ax, xy, tiles{k, 3}, nSeg);
		title(ax, tiles{k, 4});
		box(ax, 'off');
		ax.Toolbar.Visible = 'off';
		axAll(k) = ax;
	end
	% 轴标签：只标外圈，并写出该格所用 PC 空间的解释度
	ylabel(axAll(1), sprintf('PC2 (%.1f%%)', expVar(1, 2)));
	ylabel(axAll(3), sprintf('PC2 (%.1f%%)', expVar(2, 2)));
	xlabel(axAll(3), sprintf('PC1 (%.1f%%)', expVar(2, 1)));
	xlabel(axAll(4), sprintf('PC1 (%.1f%%)', expVar(1, 1)));
	% 规范：右列不重复 y 刻度标签，上排不重复 x 刻度标签
	for kk = [2 4], axAll(kk).YTickLabel = {}; end
	for kk = [1 2], axAll(kk).XTickLabel = {}; end

	if AxisModes(iM) == "unified"
		% 四格统一轴跨度（保留各自中心）
		xl = reshape([axAll.XLim], 2, []);
		yl = reshape([axAll.YLim], 2, []);
		sx = max(xl(2, :) - xl(1, :));
		sy = max(yl(2, :) - yl(1, :));
		for k = 1:4
			cx = mean(axAll(k).XLim); cy = mean(axAll(k).YLim);
			axAll(k).XLim = cx + [-1 1] * sx / 2;
			axAll(k).YLim = cy + [-1 1] * sy / 2;
		end
	else
		% 每格按自己的轨迹自适应（+8% 余量）
		for k = 1:4
			xy = P{tiles{k, 1}, tiles{k, 2}};
			xx = reshape(xy(1, :, :), [], 1); yy = reshape(xy(2, :, :), [], 1);
			axAll(k).XLim = [min(xx), max(xx)] + [-1 1] * 0.08 * range(xx);
			axAll(k).YLim = [min(yy), max(yy)] + [-1 1] * 0.08 * range(yy);
		end
	end

	if AxisModes(iM) == "unified"
		fname = 'English_Fig2B_PCA_2x2_NaiveLearnedTransfer.svg';
		lname = '_chk_2x2.svg';
	else
		fname = 'English_Fig2B_PCA_2x2_NaiveLearnedTransfer_tilescale.svg';
		lname = '_chk_2x2_tile.svg';
	end
	svgPath = TransferLearning.ExportStandardFigure(f, 2, fname);
	fprintf('Wrote: %s\n', svgPath);
	copyfile(svgPath, fullfile(thisDir, lname));
end

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
