% English Fig2C: pie chart of hit- vs miss-preferring cell-count composition
%
% Choice (hit/miss) decoder trained on AudioWater (Naive + Learned);
% per-cell weight w = (m1 - m0)/sp^2 at t = 1.0 s (see BuildCueChoiceDecoderData).
% Pooled across mice: w > 0 = hit-preferring, w < 0 = miss-preferring.
%
% Outputs (SVG):
%   - English_Fig2C_CellCountPie.svg
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

nHitCells = 0;
nMissCells = 0;
for i = 1:numel(data.choice)
	w = data.choice{i}.w1s;
	nHitCells = nHitCells + nnz(w > 0);
	nMissCells = nMissCells + nnz(w < 0);
end
pctHit = 100 * nHitCells / (nHitCells + nMissCells);
pctMiss = 100 * nMissCells / (nHitCells + nMissCells);
fprintf('=== Fig2C cell-count composition ===\n');
fprintf('hit %d (%.1f%%) vs miss %d (%.1f%%)\n', nHitCells, pctHit, nMissCells, pctMiss);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

f = figure('Color', 'w', 'Name', 'English Fig2C cell count pie');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [6, 8];
f.PaperPositionMode = 'auto';

ax3 = axes(f);
hold(ax3, 'on');
% 不用 pie 的自动扇外标签（导出时会裁切）：只画饼，计数与占比放入 legend
hPie = pie(ax3, [nHitCells, nMissCells]);
% pie 返回 patch/text 交替句柄；无标签时 text 为空对象，删除后自行设色 patch
delete(hPie(2:2:end));
hPie(1).FaceColor = colorHit;
hPie(1).EdgeColor = 'w';
hPie(3).FaceColor = colorMiss;
hPie(3).EdgeColor = 'w';
hPie(1).DisplayName = 'hit cells';
hPie(3).DisplayName = 'miss cells';
ax3.Visible = 'off';
ax3.DataAspectRatio = [1 1 1];
lg3 = legend(ax3, 'Location', 'southoutside', 'Box', 'off');

if isprop(ax3, 'Toolbar') && ~isempty(ax3.Toolbar)
	ax3.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2C_CellCountPie.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2C_CellCounts', struct('nHit', nHitCells, 'nMiss', nMissCells, 'pctHit', pctHit, 'pctMiss', pctMiss));
