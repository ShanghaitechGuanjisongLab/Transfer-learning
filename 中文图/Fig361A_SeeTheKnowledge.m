if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

rng(361);

baselines = linspace(0, 39, 4);
samples = zeros(100, 4);
samples(:, 3) = chi2rnd(1, 100, 1);
samples(:, 2) = chi2rnd(3, 100, 1);
samples(:, 1) = rand(100, 1) * 12;
samples = samples + baselines;

f = figure('Color', 'w', 'Name', '中文图361A SeeTheKnowledge');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 8];
f.PaperSize = [6, 8];

tlo = tiledlayout(f, 'flow', 'TileSpacing', 'tight', 'Padding', 'tight');
MATLAB.Graphics.FigureAspectRatio(1183, 1200, MATLAB.Flags.Narrow);
ax = nexttile(tlo);
plot(ax, samples, 'Color', 'k', 'LineWidth', 1);

ax.XAxis.Visible = 'off';
ax.FontSize = 6;
ax.FontName = 'Arial';
ax.LineWidth = 1;
yticks(ax, mean(samples, 1));
yticklabels(ax, ["Epileptic", "Knowledgeable", "Naive", "Dead"]);
ylabel(ax, '>Information entropy>', 'FontSize', 6);
box(ax, 'off');

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = '中文图Fig361A_SeeTheKnowledge.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

