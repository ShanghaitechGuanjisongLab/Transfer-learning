% 中文图362B：学习增加信息量（whole-block）

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
barPhases = ["NaiveAudio", "LearnedAudio", "NaiveLight", "LearnedLight", "TransferLight"];
barLabels = {"Naive 🔊💧", "Learned 🔊💧", "Naive 💡💧", "Learned 💡💧", "Transfer 💡💧"};
compareGroup = table(["NaiveAudio", "LearnedAudio"; "NaiveLight", "LearnedLight"; "NaiveLight", "TransferLight"], 'VariableNames', "GroupPair");

Data = Fig362_GlobalInformationCache(queryXlsx, string.empty(1, 0), barPhases);
entropyCell = cellfun(@(phaseName) double(Data.Phase.(phaseName).BlockEntropy(:)), cellstr(barPhases), 'UniformOutput', false);

f = figure('Color', 'w', 'Name', '中文图362B Learning increases information Whole-block');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4.5, 4.0];
f.PaperSize = [4.5, 4.0];

ax = axes(f);
[~, Opt, Bars, EB] = UniExp.BarScatterCompare(cell2struct(entropyCell(:), cellstr(barPhases), 1), false, compareGroup, AsteriskThreshold=0.01);
delete(findobj(ax, 'Type', 'Scatter'));

for eb = EB.Object(:)'
	delete(eb);
end

if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = repmat([0, 0, 0], numel(Bars.YData), 1);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
else
	for iBar = 1:numel(Bars)
		Bars(iBar).FaceColor = [0, 0, 0];
		Bars(iBar).FaceAlpha = 1;
		Bars(iBar).LineWidth = 1;
		Bars(iBar).BaseLine.LineWidth = 1;
		Bars(iBar).EdgeColor = 'none';
	end
end

means = nan(1, numel(entropyCell));
sems = nan(1, numel(entropyCell));
for iGroup = 1:numel(entropyCell)
	[meanValue, semValue] = MATLAB.DataFun.MeanSem(entropyCell{iGroup}, 1);
	means(iGroup) = meanValue;
	sems(iGroup) = semValue;
end

xPos = iBarCenters(Bars, numel(entropyCell));
iDrawOneSidedErrorbars(ax, xPos, means, sems, 1);

ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
ax.TickLabelInterpreter = 'none';
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
	ax.XTick = 1:numel(barPhases);
	ax.XTickLabel = barLabels;
	xtickangle(ax, 45);
ylabel(ax, 'Information entropy', 'FontSize', 6);
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 1;
end

if isfield(Opt, 'MultiCompare') && ismember('PText', Opt.MultiCompare.Properties.VariableNames)
	for pt = Opt.MultiCompare.PText(:)'
		pt.FontSize = 6;
	end
end

allText = findall(f, 'Type', 'Text');
for iText = 1:numel(allText)
	allText(iText).FontSize = 6;
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig362B_LearningIncreaseInformation_WholeBlock.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig362B_BarPhases', barPhases);
assignin('base', 'Fig362B_BlockEntropy', entropyCell);
assignin('base', 'Fig362B_CacheInfo', Data.CacheInfo);

function xPos = iBarCenters(Bars, nGroup)
	if isscalar(Bars)
		xPos = reshape(Bars.XEndPoints, 1, []);
	else
		xPos = nan(1, min(numel(Bars), nGroup));
		for iBar = 1:numel(xPos)
			xPos(iBar) = Bars(iBar).XEndPoints(1);
		end
	end
end

function iDrawOneSidedErrorbars(ax, xPos, means, sems, lineWidth)
	hold(ax, 'on');
	xPos = reshape(double(xPos), 1, []);
	means = reshape(double(means), 1, []);
	sems = reshape(double(sems), 1, []);
	capWidth = 0.14;
	for iPoint = 1:numel(xPos)
		if ~isfinite(means(iPoint)) || ~isfinite(sems(iPoint))
			continue;
		end
		yTop = means(iPoint) + sems(iPoint);
		line(ax, [xPos(iPoint), xPos(iPoint)], [means(iPoint), yTop], 'Color', 'k', 'LineWidth', lineWidth);
		line(ax, [xPos(iPoint) - capWidth, xPos(iPoint) + capWidth], [yTop, yTop], 'Color', 'k', 'LineWidth', lineWidth);
	end
end