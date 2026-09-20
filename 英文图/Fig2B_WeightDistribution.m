% English Fig2B: |w| distribution (main) + per-mouse mean |w| (Inset)
%
% Choice (hit/miss) decoder trained on AudioWater (Naive + Learned);
% per-cell weight w = (m1 - m0)/sp^2 at t = 1.0 s (see BuildCueChoiceDecoderData).
% w > 0 = prefer-hit cell, w < 0 = prefer-miss cell. All cells (no top-25%).
%
% Main figure: per 0.05-wide |weight| bin, y = count / (total hit + miss cells), x in [0, 2].
% Inset (规范：直接输出大小两图，内嵌由人工排版): per-mouse mean |w| of the two
%   groups (paired, sign-rank), UniExp.BarScatterCompare with IndividualErrorbars
%   (one-sided SEM errorbars, per-bar color matching), internal PLine; PText
%   overwritten with paired sign-rank p (anova/multcompare is unpaired-aware).
%
% Outputs (SVG):
%   - English_Fig2B_WeightDistribution.svg        (main, white, Scale=2)
%   - English_Fig2B_PerMouseMeanWeight_Inset.svg  (inset, transparent, Scale=2, 4x4 cm)
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

data = TransferLearning.BuildCueChoiceDecoderData();

wHit = [];
wMiss = [];
perMouseHit = nan(numel(data.choice), 1);
perMouseMiss = nan(numel(data.choice), 1);
for i = 1:numel(data.choice)
	w = data.choice{i}.w1s;
	ph = w(w > 0);
	pm = w(w < 0);
	wHit = [wHit; ph]; %#ok<AGROW>
	wMiss = [wMiss; pm]; %#ok<AGROW>
	if ~isempty(ph)
		perMouseHit(i) = mean(ph);
	end
	if ~isempty(pm)
		perMouseMiss(i) = mean(abs(pm));
	end
end
perMouseHit = perMouseHit(isfinite(perMouseHit));
perMouseMiss = perMouseMiss(isfinite(perMouseMiss));
pPaired = signrank(perMouseHit, perMouseMiss);
fprintf('=== Fig2B per-mouse mean |w| (Inset) ===\n');
fprintf('hit %.4f +/- %.4f vs miss %.4f +/- %.4f (n = %d mice), signrank p = %.4g\n', ...
	mean(perMouseHit), std(perMouseHit) / sqrt(numel(perMouseHit)), ...
	mean(perMouseMiss), std(perMouseMiss) / sqrt(numel(perMouseMiss)), ...
	numel(perMouseHit), pPaired);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

% ---------- 大图：|w| 分布折线图（有 legend → Scale=2，高 4×2 cm，宽 9 cm） ----------
f = figure('Color', 'w', 'Name', 'English Fig2B weight distribution');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];
f.PaperPositionMode = 'auto';

ax1 = axes(f);
hold(ax1, 'on');
edges = 0:0.05:2;
binC = (edges(1:end - 1) + edges(2:end)) / 2;
totalCells = numel(wHit) + numel(abs(wMiss));
cH = histcounts(abs(wHit), edges);
cM = histcounts(abs(wMiss), edges);
yH = cH / totalCells;
yM = cM / totalCells;
plot(ax1, binC, yH, '-', 'Color', colorHit, 'DisplayName', 'hit cells');
plot(ax1, binC, yM, '-', 'Color', colorMiss, 'DisplayName', 'miss cells');
xlim(ax1, [0 2]);
xlabel(ax1, '|weight| at 1.0 s');
ylabel(ax1, 'proportion of all cells');
box(ax1, 'off');
ax1.Color = 'none';
legend(ax1, 'Location', 'northeast', 'Box', 'off');

if isprop(ax1, 'Toolbar') && ~isempty(ax1.Toolbar)
	ax1.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2B_WeightDistribution.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('Fig2B: total cells = %d (hit %d, miss %d)\n', totalCells, numel(wHit), numel(abs(wMiss)));

% ---------- Inset 小图：每鼠 mean |w|（规范：2×缩放，图窗高宽 4 cm，透明背景） ----------
f2 = figure('Color', 'none', 'Name', 'English Fig2B inset per-mouse mean weight');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];
f2.PaperPositionMode = 'auto';

ax2 = axes(f2);
DataCell = {double(perMouseHit(:)), double(perMouseMiss(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
% IndividualErrorbars 旗帜：每根误差条为独立对象，便于逐根着色与所属 bar 同色；Ax 默认 gca 即刚建的 ax2
[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
set(ax2, 'XTick', [1 2], 'XTickLabel', {'hit', 'miss'});
ylabel(ax2, 'mean |weight|');
% bar 不设透明度：FaceAlpha<1 会冲淡柱色，与全饱和的 errorbar 视觉不同色（违反同色规范）
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB = numel(Bars2.YData);
	barCData = repmat([colorHit; colorMiss], ceil(nB / 2), 1);
	Bars2.CData = barCData(1:nB, :);
	Bars2.EdgeColor = 'none';
	Bars2.FaceAlpha = 1;
	Bars2.BarWidth = 0.5;
else
	Bars2(1).FaceColor = colorHit;
	Bars2(2).FaceColor = colorMiss;
	for kB = 1:numel(Bars2)
		Bars2(kB).EdgeColor = 'none';
		Bars2(kB).FaceAlpha = 1;
		Bars2(kB).BarWidth = 0.5;
	end
end
% 均值全为正时 BarScatterCompare 只画单侧（上半）误差条，天然满足"不要双向errorbar"
% 误差条颜色与所属 bar 相同（第 k 行对应第 k 根 bar，IndividualErrorbars 下 Index 全为 1）
if istable(ErrorBars2) && ~isempty(ErrorBars2) && ismember('Object', ErrorBars2.Properties.VariableNames)
	barColors = [colorHit; colorMiss];
	for kE = 1:height(ErrorBars2)
		eb2 = ErrorBars2.Object(kE);
		if isgraphics(eb2) && kE <= size(barColors, 1)
			eb2.Color = barColors(kE, :);
		end
	end
end
% BarScatterCompare 内部 PLine 已在 CompareGroup 下自动绘制；但其 anova/multcompare 口径不感知配对，
% 故用配对 sign-rank p 覆盖 PText 文本（图注报告口径），PLine 位置沿用函数自动优化结果
if isfield(Optional2, 'MultiCompare') && istable(Optional2.MultiCompare)
	mc2 = Optional2.MultiCompare;
	if ismember('PValue', mc2.Properties.VariableNames) && ~isempty(mc2.PValue)
		fprintf('BarScatterCompare internal anova/multcompare p = %.4g (unpaired, not displayed)\n', mc2.PValue(1));
	end
	if ismember('PText', mc2.Properties.VariableNames)
		for ip = 1:height(mc2)
			pt2 = mc2.PText(ip);
			if isgraphics(pt2)
				pt2.String = TransferLearning.Style.iFormatPText(pPaired);
				pt2.Tag = 'PText';
			end
		end
	end
	if ismember('PLine', mc2.Properties.VariableNames)
		for ip = 1:height(mc2)
			pl2 = mc2.PLine(ip);
			if isgraphics(pl2)
				pl2.Tag = 'PLine';
			end
		end
	end
end
box(ax2, 'off');
ax2.Color = 'none';
legend(ax2, 'off');

if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end

svgInset = TransferLearning.ExportStandardFigureTransparent(f2, 2, 'English_Fig2B_PerMouseMeanWeight_Inset.svg');
fprintf('Wrote: %s\n', svgInset);

assignin('base', 'Fig2B_WeightDistributionStats', struct('wHit', wHit, 'wMiss', wMiss, ...
	'totalCells', totalCells, 'perMouseHit', perMouseHit, 'perMouseMiss', perMouseMiss, 'pPaired', pPaired));
