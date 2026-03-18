% Fig35B（hM4D(Gi) vs mCherry）
% Learning curve comparison, styled like English Fig1B
%
% Execution:
%   TransferLearning.Fig35.B_LearningCurve_LikeEnglishFig1B

function B_LearningCurve_LikeEnglishFig1B

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig35B_LearningCurve_LikeEnglishFig1B.svg";

% --- Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

% --- Load datasets
pathGi  = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制 声水转光水.v3.mat";
pathmCh = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.v2.mat";
DS_Gi  = UniExp.DataSet(pathGi);
DS_mCh = UniExp.DataSet(pathmCh);

B1 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_Gi, false);
B2 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_mCh, false);
if isempty(B1) || isempty(B2)
	error('Fig35B_LC:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end
B1.Group = repmat("hM4D(Gi)", height(B1), 1);
B2.Group = repmat("mCherry",  height(B2), 1);

B1.Mouse = string(B1.Mouse);
B2.Mouse = string(B2.Mouse);
B1.DateTime = TransferLearning.Fig35.iNormalizeDateTime(B1.DateTime);
B2.DateTime = TransferLearning.Fig35.iNormalizeDateTime(B2.DateTime);

J = [B1; B2];
J.Group = string(J.Group);

Sess = TransferLearning.Fig35.iSessionizeByDateTime(J(:, intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable')));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});

sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);

PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

grpOrder = ["mCherry","hM4D(Gi)"];
grpLabels = grpOrder;

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

n_mCh = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="mCherry"))));
n_Gi  = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="hM4D(Gi)"))));

% --- Plot
f = figure('Color','w', 'Name', 'Fig35B Learning curve');
MATLAB.Graphics.FigureAspectRatio(90, 80, 1);
ax = axes(f);
hold(ax,'on');

edgeColors = TransferLearning.FigurePalette(2);

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

labels = {sprintf('%s (n=%d)', grpLabels(1), n_mCh), sprintf('%s (n=%d)', grpLabels(2), n_Gi)};
try
	if numel(Patches) >= 2
		lg = legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2)));
	else
		lg = legend(ax, labels, 'Location', 'best');
	end
	lg.FontSize = 12;
	try, lg.Title.String = '💡💧'; catch, end
catch
end

ax.FontSize = 12;
xlabel(ax, 'Session', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');

% --- Export
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
svgPath = fullfile(outDirUNC, svgName);
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

assignin('base', 'Fig35B_LearningCurve_Sessions', Sess);
assignin('base', 'Fig35B_LearningCurve_LearningSummarizeP', PValueLS);

end
