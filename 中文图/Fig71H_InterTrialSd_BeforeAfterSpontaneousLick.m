% 中文图71H：自发舔水前后回合间 SD 与舔水概率

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
Data = Fig71_ConvergenceInheritanceCache();

f = figure('Color', 'w', 'Name', '中文图71H Inter-trial SD before after spontaneous lick');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

ax = axes(f);
hold(ax, 'on');
yyaxis(ax, 'left');
Lines = MATLAB.Graphics.MultiShadowedLines(Data.StdMean, Data.StdSem, 1/4, X=double(Data.X), EdgeColors=[1, 0, 0; 0, 0, 1]);
set(Lines, 'LineWidth', 2);
ylabel(ax, 'Divergence', 'FontSize', 12);
ax.YAxis(1).Color = [0.5, 0, 0.5];

yyaxis(ax, 'right');
behaviorColor = [0, 0.6809, 0];
BehaviorLines = MATLAB.Graphics.MultiShadowedLines(Data.BehaviorMean, Data.BehaviorSem, 1/4, X=double(Data.X), EdgeColors=behaviorColor);
set(BehaviorLines, 'LineWidth', 2);
ylabel(ax, 'Lick probability', 'FontSize', 12);
ax.YAxis(2).Color = behaviorColor;

ax.FontSize = 12;
ax.FontName = 'Arial';
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
end
if isprop(ax.YAxis(1), 'LineWidth')
	ax.YAxis(1).LineWidth = 2;
	ax.YAxis(2).LineWidth = 2;
end
ax.TickLabelInterpreter = 'none';
box(ax, 'off');
grid(ax, 'off');
title(ax, 'Divergence B/A spontaneous lick', 'FontSize', 12, 'FontWeight', 'normal');
xlabel(ax, 'Time (s)', 'FontSize', 12);

lgd = legend(Lines, ["Before spontaneous lick", "After spontaneous lick"], 'Location', 'northeast', 'Box', 'off', 'FontSize', 12);
lgd.FontName = 'Arial';

for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 2;
end
allText = findall(f, 'Type', 'Text');
for iText = 1:numel(allText)
	allText(iText).FontSize = 12;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig71H_InterTrialSd_BeforeAfterSpontaneousLick.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'Fig71H_Data', Data);
assignin('base', 'Fig71H_BehaviorLines', BehaviorLines);

