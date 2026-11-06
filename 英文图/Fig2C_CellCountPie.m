% English Fig2C: cell-count composition pie
% 样式参照 Guan-lab Nat Commun 2026 Fig.5k：灰/彩色扇区 + 白色细缝，
% 彩色粗体名称（上）+ 黑色百分比（下），无图例、无边框、无标题。
%
% Choice (hit/miss) decoder trained on AudioWater (Naive + Learned);
% per-cell weight w = (m1 - m0)/sp^2 at t = 1.0 s (see BuildCueChoiceDecoderData).
% Pooled across mice: w > 0 = hit-preferring, w < 0 = miss-preferring.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

data = TransferLearning.BuildCueChoiceDecoderData();

nHitCells = 0;
nMissCells = 0;
for i = 1:numel(data.choice)
	w = data.choice{i}.w1s;
	nHitCells = nHitCells + nnz(w > 0);
	nMissCells = nMissCells + nnz(w < 0);
end
nTot = nHitCells + nMissCells;
pctHit = 100 * nHitCells / nTot;
pctMiss = 100 * nMissCells / nTot;
fprintf('=== Fig2C cell-count composition ===\n');
fprintf('hit %d (%.1f%%) vs miss %d (%.1f%%)\n', nHitCells, pctHit, nMissCells, pctMiss);

vals  = [nHitCells, nMissCells];
names = ["hit-preferring", "miss-preferring"];
cols  = [0.85 0.33 0.10;    % 橙红
         0.16 0.36 0.55];   % 深蓝

f = figure('Color', 'w', 'Name', 'English Fig2C cell count pie');
f.Units = 'centimeters';
f.Position(3:4) = [7.6, 3.2];
f.PaperUnits = 'centimeters';
f.PaperSize = [7.6, 3.2];
f.PaperPositionMode = 'auto';

ax = axes(f, 'Position', [0.03 0.03 0.94 0.94]);
hP = pie(ax, vals);
delete(hP(2:2:end));                     % 去掉 pie 的自动外侧标签（导出会被裁）
for k = 1:numel(vals)
	hP(2*k-1).FaceColor = cols(k,:);
	hP(2*k-1).EdgeColor = 'w';
	hP(2*k-1).LineWidth = 1;
end
ax.Visible = 'off';
axis(ax, 'equal');

% 手动标签：彩色粗体名称在上，黑色百分比在下
frac = vals / sum(vals);
cum  = [0, cumsum(frac)];
angMid = 90 - (cum(1:end-1) + frac/2) * 360;
R = 1.02;
for k = 1:numel(vals)
	x = R * cosd(angMid(k));
	y = R * sind(angMid(k));
	if x >= 0
		ha = 'left';  dx = 0.03;
	else
		ha = 'right'; dx = -0.03;
	end
	text(ax, x + dx, y + 0.12, names(k), 'Color', cols(k,:), 'FontWeight', 'bold', ...
		'FontSize', 6, 'HorizontalAlignment', ha, 'VerticalAlignment', 'bottom');
	text(ax, x + dx, y - 0.02, sprintf('%.1f%%', 100*frac(k)), 'Color', 'k', ...
		'FontSize', 6, 'HorizontalAlignment', ha, 'VerticalAlignment', 'top');
end
xlim(ax, [-3.00, 3.00]);
ylim(ax, [-1.30, 1.30]);

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_Fig2C_CellCountPie.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2C_CellCounts', struct('nHit', nHitCells, 'nMiss', nMissCells, ...
	'pctHit', pctHit, 'pctMiss', pctMiss));
