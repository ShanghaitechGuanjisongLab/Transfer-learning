% Fig35D（Vacation7 vs Ctrl）
% Learning curve comparison, styled like English Fig1B
%
% Execution:
%   TransferLearning.Fig35.D_LearningCurve_LikeEnglishFig1B

function D_LearningCurve_LikeEnglishFig1B

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig35D_LearningCurve_LikeEnglishFig1B.svg";

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
DS_Ctrl = TransferLearning.AudioLightBaseline();
DS_V7   = TransferLearning.Vacation7();

B1 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_Ctrl, false);
B2 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_V7,   false);
if isempty(B1) || isempty(B2)
	error('Fig35D_LC:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end
B1.Group = repmat("Ctrl",      height(B1), 1);
B2.Group = repmat("Vacation7", height(B2), 1);

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

grpOrder = ["Ctrl","Vacation7"];
grpLabels = grpOrder;

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

n_Ctrl = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="Ctrl"))));
n_V7   = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="Vacation7"))));

% --- Plot
f = figure('Color','w', 'Name', 'Fig35D Learning curve');
MATLAB.Graphics.FigureAspectRatio(90, 80, 1);
ax = axes(f);
hold(ax,'on');

try
	edgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
catch
	edgeColors = lines(2);
end

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

labels = {sprintf('%s (n=%d)', grpLabels(1), n_Ctrl), sprintf('%s (n=%d)', grpLabels(2), n_V7)};
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

assignin('base', 'Fig35D_LearningCurve_Sessions', Sess);
assignin('base', 'Fig35D_LearningCurve_LearningSummarizeP', PValueLS);

end
