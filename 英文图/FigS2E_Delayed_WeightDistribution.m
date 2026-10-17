% English FigS2E: |w| distribution (main) + per-mouse mean |w| (Inset) on ALDelayed
% （模仿 英文图/Fig2B_WeightDistribution.m，取点由 1.0 s 改为延迟任务的 1.5 s）。
%
% Choice (hit/miss) decoder trained on AudioLearnWater（声水训练全部会话；
% AudioLearnWaterAlways 总是给水不参与）；per-cell weight w = (m1 - m0)/sp^2 at
% t = +1.5 s（见 TransferLearning.BuildChoiceDecoderDataDelayed）。
% w > 0 = prefer-hit cell, w < 0 = prefer-miss cell. All cells (no top-25%).
%
% Main figure: per 0.05-wide |weight| bin, y = count / (total hit + miss cells), x in [0, 2].
% Inset（规范：直接输出大小两图，内嵌由人工排版）: per-mouse mean |w| of the two
%   groups (paired, sign-rank), UniExp.BarScatterCompare with IndividualErrorbars
%   (one-sided SEM errorbars, per-bar color matching), internal PLine; PText
%   overwritten with paired sign-rank p (anova/multcompare is unpaired-aware).
%
% Outputs (SVG):
%   - English_FigS2E_Delayed_WeightDistribution.svg        (main, white, Scale=2)
%   - English_FigS2E_Delayed_PerMouseMeanWeight_Inset.svg  (inset, transparent, Scale=2, 4x4 cm)
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

data = TransferLearning.BuildChoiceDecoderDataDelayed();
if isempty(data.choice)
	error('FigS2E:NoMice', 'No valid AudioLearnWater choice-decoder mice in ALDelayed.');
end

wHit = [];
wMiss = [];
perMouseHit = nan(numel(data.choice), 1);
perMouseMiss = nan(numel(data.choice), 1);
for i = 1:numel(data.choice)
	w = data.choice{i}.w1p5;
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
fprintf('=== FigS2E per-mouse mean |w| (Inset) ===\n');
fprintf('hit %.4f +/- %.4f vs miss %.4f +/- %.4f (n = %d mice), signrank p = %.4g\n', ...
	mean(perMouseHit), std(perMouseHit) / sqrt(numel(perMouseHit)), ...
	mean(perMouseMiss), std(perMouseMiss) / sqrt(numel(perMouseMiss)), ...
	numel(perMouseHit), pPaired);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

% ---------- 大图：|w| 分布折线图（同 Fig2B 版式，取点 1.5 s） ----------
f = figure('Color', 'w', 'Name', 'English FigS2E delayed weight distribution');
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
xlabel(ax1, '|weight| at 1.5 s');
ylabel(ax1, 'proportion of all cells');
box(ax1, 'off');
ax1.Color = 'none';
legend(ax1, 'Location', 'northeast', 'Box', 'off');

if isprop(ax1, 'Toolbar') && ~isempty(ax1.Toolbar)
	ax1.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS2E_Delayed_WeightDistribution.svg');
fprintf('Wrote: %s\n', svgPath);
fprintf('FigS2E: total cells = %d (hit %d, miss %d)\n', totalCells, numel(wHit), numel(abs(wMiss)));

% ---------- Inset 小图：每鼠 mean |w|（同 Fig2B 版式：2×缩放，4×4 cm，透明背景） ----------
f2 = figure('Color', 'none', 'Name', 'English FigS2E inset per-mouse mean weight');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];
f2.PaperPositionMode = 'auto';

ax2 = axes(f2);
DataCell = {double(perMouseHit(:)), double(perMouseMiss(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
set(ax2, 'XTick', [1 2], 'XTickLabel', {'hit', 'miss'});
ylabel(ax2, 'mean |weight|');
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
if istable(ErrorBars2) && ~isempty(ErrorBars2) && ismember('Object', ErrorBars2.Properties.VariableNames)
	barColors = [colorHit; colorMiss];
	for kE = 1:height(ErrorBars2)
		eb2 = ErrorBars2.Object(kE);
		if isgraphics(eb2) && kE <= size(barColors, 1)
			eb2.Color = barColors(kE, :);
		end
	end
end
% 配对 sign-rank p 覆盖 PText（anova/multcompare 不感知配对），PLine/PText 打标给标准样式
if isfield(Optional2, 'MultiCompare') && istable(Optional2.MultiCompare)
	mc2 = Optional2.MultiCompare;
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

svgInset = TransferLearning.ExportStandardFigureTransparent(f2, 2, 'English_FigS2E_Delayed_PerMouseMeanWeight_Inset.svg');
fprintf('Wrote: %s\n', svgInset);

assignin('base', 'FigS2E_Delayed_WeightStats', struct('wHit', wHit, 'wMiss', wMiss, ...
	'totalCells', totalCells, 'perMouseHit', perMouseHit, 'perMouseMiss', perMouseMiss, 'pPaired', pPaired));
