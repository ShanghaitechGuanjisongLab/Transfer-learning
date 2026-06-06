% 中文图72G：知识增减（Unused old / Newly learned）

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
Data = Fig72_GlobalKnowledgeChangeCache(queryXlsx);

usageKeys = {'Unused old', 'Newly learned'};
usageLabels = {'Unused old', 'Newly learned'};
transitionKeys = {'NaiveToLearned', 'LearnedToTransfer', 'TransferToFinal', 'LearnedToFinal'};
transitionLabels = {'Naive→Learned', 'Learned→Continual start', 'Continual start→Continual learned', 'Learned→Continual learned'};
transitionPhasePairs = ["NaiveLight", "LearnedLight"; "LearnedAudio", "TransferLight"; "TransferLight", "FinalLight"; "LearnedAudio", "FinalLight"];
transitionColors = iTransitionColors(transitionPhasePairs);
compareGroup = table(table(["NaiveToLearned", "LearnedToTransfer"; "NaiveToLearned", "LearnedToTransfer"], ["Unused old", "Unused old"; "Newly learned", "Newly learned"], 'VariableNames', {'Pair', 'Usage'}), 'VariableNames', {'GroupPair'});

f = figure('Color', 'w', 'Name', '中文图72G Knowledge change bar');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

ax = axes(f);
hold(ax, 'on');
[~, Opt, Bars, EB] = UniExp.BarScatterCompare(Data.UNCompare, compareGroup, UniExp.Flags.IndividualErrorbars, AsteriskThreshold=0.01);
delete(findobj(ax, 'Type', 'Scatter'));
for eb = EB.Object(:)'
	eb.LineWidth = 2;
end
for iBar = 1:min(numel(Bars), numel(transitionLabels))
	Bars(iBar).FaceColor = transitionColors(iBar, :);
	Bars(iBar).FaceAlpha = 1;
	Bars(iBar).LineWidth = 2;
	Bars(iBar).BaseLine.LineWidth = 2;
	Bars(iBar).EdgeColor = 'none';
end
iStyleErrorBars(EB, Bars, transitionColors);

ax.FontSize = 12;
ax.FontName = 'Arial';
ax.TickLabelInterpreter = 'none';
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
ax.XTick = 1:numel(usageKeys);
ax.XTickLabel = usageLabels;
ylabel(ax, 'Knowledge bits per cell', 'FontSize', 12);
title(ax, 'Knowledge gain/loss', 'FontSize', 12, 'FontWeight', 'normal');
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
if isfield(Opt, 'Legend') && ~isempty(Opt.Legend)
	Opt.Legend.String = transitionLabels;
	Opt.Legend.Location = 'northwest';
	Opt.Legend.Box = 'off';
	Opt.Legend.FontSize = 12;
	Opt.Legend.FontName = 'Arial';
end

for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 2;
end
if isfield(Opt, 'MultiCompare') && ismember('PText', Opt.MultiCompare.Properties.VariableNames)
	for pt = Opt.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end
allText = findall(f, 'Type', 'Text');
for iText = 1:numel(allText)
	allText(iText).FontSize = 12;
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig72G_KnowledgeChange_Bar.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

function colors = iTransitionColors(transitionPhasePairs)
	colors = zeros(size(transitionPhasePairs, 1), 3);
	for iPair = 1:size(transitionPhasePairs, 1)
		colors(iPair, :) = mean([iPhaseColor(transitionPhasePairs(iPair, 1)); iPhaseColor(transitionPhasePairs(iPair, 2))], 1);
	end
end

function color = iPhaseColor(phaseName)
	phaseName = string(phaseName);
	if contains(phaseName, "Naive")
		color = TransferLearning.NaiveColor;
	elseif contains(phaseName, "Learned")
		color = TransferLearning.LearnedColor;
	elseif contains(phaseName, "Transfer") || contains(phaseName, "Continual")
		color = TransferLearning.ContinualColor;
	elseif contains(phaseName, "Final")
		color = TransferLearning.ColorA;
	else
		color = TransferLearning.GroupColors(phaseName);
	end
end

function iStyleErrorBars(errorBars, bars, colors)
	if istable(errorBars) && ismember('Object', errorBars.Properties.VariableNames)
		errorBarObjects = errorBars.Object;
	elseif isstruct(errorBars) && isfield(errorBars, 'Object')
		errorBarObjects = errorBars.Object;
	else
		errorBarObjects = gobjects(0, 1);
	end

	for iError = 1:numel(errorBarObjects)
		if ~isgraphics(errorBarObjects(iError))
			continue;
		end
		colorIndex = iNearestBarIndex(errorBarObjects(iError), bars, size(colors, 1));
		errorBarObjects(iError).Color = colors(colorIndex, :);
		errorBarObjects(iError).LineWidth = 2;
	end
end

function colorIndex = iNearestBarIndex(errorBar, bars, nColor)
	if isscalar(bars)
		xCenters = double(bars.XEndPoints(:));
		[~, colorIndex] = min(abs(xCenters - mean(double(errorBar.XData(:)), 'omitnan')));
		colorIndex = min(colorIndex, nColor);
		return;
	end
	xData = double(errorBar.XData(:));
	distances = inf(1, min(numel(bars), nColor));
	for iBar = 1:numel(distances)
		barX = double(bars(iBar).XEndPoints(:));
		distances(iBar) = min(abs(barX - mean(xData, 'omitnan')));
	end
	[~, colorIndex] = min(distances);
end

