% 中文图362A：学习增加信息量（In-trial）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
queryXlsx = '\\Data-Server-2\个人数据\张天夫\202512\尝试查询表.xlsx';
linePhases = ["NaiveLight", "TransferLightHit", "TransferLightMiss"];
lineLegends = ["Naive", "Transfer Hit", "Transfer Miss"];

Data = Fig362_GlobalInformationCache(queryXlsx, linePhases, string.empty(1, 0));
xData = Data.XData;
meanCell = cellfun(@(phaseName) Data.Phase.(phaseName).Mean, cellstr(linePhases), 'UniformOutput', false);
semCell = cellfun(@(phaseName) Data.Phase.(phaseName).Sem, cellstr(linePhases), 'UniformOutput', false);
meanMat = vertcat(meanCell{:});
semMat = vertcat(semCell{:});

f = figure('Color', 'w', 'Name', '中文图362A Learning increases information In-trial');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;
ax.LineWidth = 2;
ax.FontName = 'Arial';
ax.TickDir = 'out';
ax.Color = 'none';
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

lineColors = TransferLearning.FigurePalette(3);
patches = MATLAB.Graphics.MultiShadowedLines( ...
	{meanMat(1, :).', meanMat(2, :).', meanMat(3, :).'}, ...
	{semMat(1, :).', semMat(2, :).', semMat(3, :).'}, ...
	0.2, ...
	X=xData, ...
	EdgeColors=lineColors);

for iPatch = 1:numel(patches)
	if isprop(patches(iPatch), 'LineWidth')
		patches(iPatch).LineWidth = 2;
	end
end

xline(ax, 0, ':k', 'LineWidth', 2);
xline(ax, 1, '-k', 'LineWidth', 2);

for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 2;
end

box(ax, 'off');
grid(ax, 'off');
ax.TickLabelInterpreter = 'none';
tickValues = ax.XTick;
tickLabels = arrayfun(@(value) sprintf('%g', value), tickValues, 'UniformOutput', false);
isZeroTick = abs(tickValues - 0) < 1e-9;
isOneTick = abs(tickValues - 1) < 1e-9;
tickLabels(isZeroTick) = {'💡'};
tickLabels(isOneTick) = {'💧'};
ax.XTickLabel = tickLabels;
if isprop(ax.XAxis, 'FontName')
	ax.XAxis.FontName = 'Segoe UI Emoji';
end
xlabel(ax, 'Time (s)', 'FontSize', 12);
ylabel(ax, 'Cell info. norm. to 0 s', 'FontSize', 12);
title(ax, 'In-trial', 'FontSize', 12, 'FontWeight', 'normal');

lgd = legend(patches, cellstr(lineLegends), 'Location', MATLAB.Graphics.OptimizedLegendLocation(patches), 'Box', 'off', 'FontSize', 12);
lgd.FontName = 'Arial';

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig362A_LearningIncreaseInformation_InTrial.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig362A_LinePhases', linePhases);
assignin('base', 'Fig362A_MeanMat', meanMat);
assignin('base', 'Fig362A_SemMat', semMat);
assignin('base', 'Fig362A_CacheInfo', Data.CacheInfo);