% English Fig2C: hit weights larger than miss weights
%
% Choice (hit/miss) decoder trained on AudioWater (Naive + Learned);
% per-cell weight w = (m1 - m0)/sp^2 at t = 0.7 s. w > 0 = prefer-hit cell,
% w < 0 = prefer-miss cell. All cells (no top-25% restriction).
% Left: pooled |w| histograms of prefer-hit vs prefer-miss cells.
% Right: per-mouse mean |w| of the two groups (paired, sign-rank).
%
% Outputs (SVG):
%   - English_Fig2C_WeightHistogramHitVsMiss.svg
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
	w = data.choice{i}.w07;
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
pPooled = ranksum(wHit, abs(wMiss));

fprintf('=== Fig2C weights (all cells, pooled) ===\n');
fprintf('prefer-hit  |w|: mean %.4f, n = %d cells\n', mean(wHit), numel(wHit));
fprintf('prefer-miss |w|: mean %.4f, n = %d cells\n', mean(abs(wMiss)), numel(abs(wMiss)));
fprintf('per-mouse mean |w|: hit %.4f +/- %.4f vs miss %.4f +/- %.4f (n = %d mice), signrank p = %.4g; pooled ranksum p = %.4g\n', ...
	mean(perMouseHit), std(perMouseHit) / sqrt(numel(perMouseHit)), ...
	mean(perMouseMiss), std(perMouseMiss) / sqrt(numel(perMouseMiss)), ...
	numel(perMouseHit), pPaired, pPooled);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

f = figure('Color', 'w', 'Name', 'English Fig2C hit vs miss weights');
f.Units = 'centimeters';
f.Position(3:4) = [10, 4.5];
f.PaperUnits = 'centimeters';
f.PaperSize = [10, 4.5];
f.PaperPositionMode = 'auto';

ax1 = subplot(1, 2, 1);
hold(ax1, 'on');
edges = 0:0.05:3;
histogram(ax1, wHit, edges, 'FaceColor', colorHit, 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'Normalization', 'probability', 'DisplayName', 'prefer-hit cells');
histogram(ax1, abs(wMiss), edges, 'FaceColor', colorMiss, 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'Normalization', 'probability', 'DisplayName', 'prefer-miss cells');
xlabel(ax1, '|weight| at 0.7 s', 'FontSize', 8);
ylabel(ax1, 'proportion of cells', 'FontSize', 8);
legend(ax1, 'Location', 'northeast', 'Box', 'off', 'FontSize', 7);
box(ax1, 'off');
ax1.FontSize = 7;
ax1.LineWidth = 1;
ax1.Color = 'none';

ax2 = subplot(1, 2, 2);
hold(ax2, 'on');
b = bar(ax2, [mean(perMouseHit), mean(perMouseMiss)], 0.5);
b.FaceColor = 'flat';
b.CData = [colorHit; colorMiss];
b.EdgeColor = 'none';
b.FaceAlpha = 1/3;
b.LineWidth = 1;
se = [std(perMouseHit) / sqrt(numel(perMouseHit)), std(perMouseMiss) / sqrt(numel(perMouseMiss))];
errorbar(ax2, 1:2, [mean(perMouseHit), mean(perMouseMiss)], se, 'k.', 'CapSize', 4, 'LineWidth', 1, 'HandleVisibility', 'off');
for i = 1:numel(perMouseHit)
	plot(ax2, [1 2], [perMouseHit(i) perMouseMiss(i)], '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5, 'HandleVisibility', 'off');
end
plot(ax2, 1:numel(perMouseHit) * 0 + 1, perMouseHit, '.', 'Color', colorHit, 'MarkerSize', 8, 'HandleVisibility', 'off');
plot(ax2, 1:numel(perMouseMiss) * 0 + 2, perMouseMiss, '.', 'Color', colorMiss, 'MarkerSize', 8, 'HandleVisibility', 'off');
% significance line
yl = ylim(ax2);
yrange = yl(2) - yl(1);
yLine = yl(2) + 0.05 * yrange;
plot(ax2, [1 1.15 1.15 2 2], [yLine - 0.02 * yrange, yLine, yLine, yLine, yLine - 0.02 * yrange], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
if pPaired < 0.001
	starStr = '＊＊＊';
elseif pPaired < 0.01
	starStr = '＊＊';
elseif pPaired < 0.05
	starStr = '＊';
else
	starStr = 'n.s.';
end
text(ax2, 1.5, yLine + 0.02 * yrange, starStr, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8, 'HandleVisibility', 'off');
ylim(ax2, [0, yLine + 0.25 * yrange]);
set(ax2, 'XTick', [1 2], 'XTickLabel', {'prefer-hit', 'prefer-miss'});
ylabel(ax2, 'mean |weight| per mouse', 'FontSize', 8);
box(ax2, 'off');
ax2.FontSize = 7;
ax2.LineWidth = 1;
ax2.Color = 'none';

if isprop(ax1, 'Toolbar') && ~isempty(ax1.Toolbar)
	ax1.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2C_WeightHistogramHitVsMiss.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2C_WeightStats', struct('wHit', wHit, 'wMiss', wMiss, 'perMouseHit', perMouseHit, 'perMouseMiss', perMouseMiss, 'pPaired', pPaired, 'pPooled', pPooled));
