% English FigS2F: pie chart of hit- vs miss-preferring cell-count composition on ALDelayed
% （模仿 英文图/Fig2C_CellCountPie.m，取点由 1.0 s 改为延迟任务的 1.5 s）。
%
% Choice (hit/miss) decoder trained on AudioLearnWater（声水训练；Always 不参与）；
% per-cell weight w = (m1 - m0)/sp^2 at t = +1.5 s（见 TransferLearning.BuildChoiceDecoderDataDelayed）。
% Pooled across mice: w > 0 = hit-preferring, w < 0 = miss-preferring.
%
% Outputs (SVG):
%   - English_FigS2F_Delayed_CellCountPie.svg
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
	error('FigS2F:NoMice', 'No valid AudioLearnWater choice-decoder mice in ALDelayed.');
end

nHitCells = 0;
nMissCells = 0;
for i = 1:numel(data.choice)
	w = data.choice{i}.w1p5;
	nHitCells = nHitCells + nnz(w > 0);
	nMissCells = nMissCells + nnz(w < 0);
end
pctHit = 100 * nHitCells / (nHitCells + nMissCells);
pctMiss = 100 * nMissCells / (nHitCells + nMissCells);
fprintf('=== FigS2F cell-count composition ===\n');
fprintf('hit %d (%.1f%%) vs miss %d (%.1f%%)\n', nHitCells, pctHit, nMissCells, pctMiss);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

f = figure('Color', 'w', 'Name', 'English FigS2F delayed cell count pie');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [6, 8];
f.PaperPositionMode = 'auto';

ax3 = axes(f);
hold(ax3, 'on');
% 不用 pie 的自动扇外标签（导出时会裁切）：只画饼，计数与占比放入 legend
hPie = pie(ax3, [nHitCells, nMissCells]);
delete(hPie(2:2:end));
hPie(1).FaceColor = colorHit;
hPie(1).EdgeColor = 'w';
hPie(3).FaceColor = colorMiss;
hPie(3).EdgeColor = 'w';
hPie(1).DisplayName = 'hit cells';
hPie(3).DisplayName = 'miss cells';
ax3.Visible = 'off';
ax3.DataAspectRatio = [1 1 1];
legend(ax3, 'Location', 'southoutside', 'Box', 'off');

if isprop(ax3, 'Toolbar') && ~isempty(ax3.Toolbar)
	ax3.Toolbar.Visible = 'off';
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS2F_Delayed_CellCountPie.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS2F_Delayed_CellCounts', struct('nHit', nHitCells, 'nMiss', nMissCells, 'pctHit', pctHit, 'pctMiss', pctMiss));
