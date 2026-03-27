Data = Fig371_BaselineConvergenceCache();

f = figure('Color', 'w', 'Name', '中文图371A Baseline convergence PC1 trajectory');
f.Units = 'centimeters';
f.Position(3:4) = [9.0, 8.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9.0, 8.0];
f.PaperSize = [9.0, 8.0];

ax = axes(f);
hold(ax, 'on');

xSec = double(Data.XSec(:));
trialPc1 = Data.LearnedAudioPC1;
cmap = Data.TrialColormap;
for iTrial = 1:size(trialPc1, 2)
	line(ax, xSec, trialPc1(:, iTrial), 'Color', cmap(iTrial, :), 'LineWidth', 2, 'HandleVisibility', 'off');
end

colormap(ax, cmap);
clim(ax, [1, size(trialPc1, 2)]);
cb = colorbar(ax);
cb.Box = 'off';
cb.FontSize = 12;

ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
box(ax, 'off');
grid(ax, 'off');

ax.XTick = -3:1:0;
ax.XTickLabel = {'-3', '-2', '-1', '🔊'};
xlabel(ax, 'Time(s)');
ylabel(ax, 'PC1');
title(ax,'Learned🔊');

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig371A_BaselineConvergence_PC1Trajectory.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);