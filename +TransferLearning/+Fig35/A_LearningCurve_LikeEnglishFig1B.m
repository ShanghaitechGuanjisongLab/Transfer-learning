% Fig35A（cFos: MOp inhibited vs Control）
% Learning curve comparison, styled like English Fig1B
%
% Execution:
%   TransferLearning.Fig35.A_LearningCurve_LikeEnglishFig1B

function A_LearningCurve_LikeEnglishFig1B

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig35A_LearningCurve_LikeEnglishFig1B.svg";

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

% --- Load cFos dataset + group table
matPath = "\\Data-Server-2\个人数据\张天夫\202601\cFos合集.v2.mat";
DS = UniExp.DataSet(matPath);
S = DS.Mice;
if isempty(S)
	error('Fig35A_LC:EmptyMice', 'DS.Mice is empty.');
end
if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
		error('Fig35A_LC:MissingMouse', 'DS.Mice has no Mouse column/rownames.');
	end
end
S.Mouse = string(S.Mouse);

need = ["ExpressedBrain","MarkTimes"];
if ~all(ismember(need, string(S.Properties.VariableNames)))
	error('Fig35A_LC:MissingVars', 'DS.Mice lacks required vars: %s', char(strjoin(need, ', ')));
end

S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";

% remove weird labels with >1 spaces (match Fig35A)
try
	bad = arrayfun(@(g) nnz(char(g) == ' ') > 1, S.Group);
	S = S(~bad, :);
catch
end

S = S(ismember(S.Group, ["Control","MOp"]), :);
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);
if isempty(S)
	error('Fig35A_LC:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end

% --- Query LightWater behavior blocks, then keep only mice in S
B = TransferLearning.Fig35.iQueryLightWaterBlocks(DS, false);
if isempty(B)
	error('Fig35A_LC:EmptyBehavior', 'No LightWater behavior rows found.');
end
B.Mouse = string(B.Mouse);
B.DateTime = TransferLearning.Fig35.iNormalizeDateTime(B.DateTime);

J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);
if isempty(J)
	error('Fig35A_LC:EmptyJoin', 'No LightWater rows after joining to group table.');
end

% --- Sessionize (one row per mouse per session)
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

grpOrder = ["Control","MOp"];
grpLabels = ["Control","Inhibited"]; % display

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

% curves for MultiShadowedLines (row vectors)
meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

nCtrl = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="Control"))));
nMOp  = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="MOp"))));

% --- Plot
f = figure('Color','w', 'Name', 'Fig35A Learning curve');
MATLAB.Graphics.FigureAspectRatio(90, 80, 1);
ax = axes(f);
hold(ax,'on');

try
	edgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
catch
	edgeColors = lines(2);
end

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

labels = {sprintf('%s (n=%d)', grpLabels(1), nCtrl), sprintf('%s (n=%d)', grpLabels(2), nMOp)};
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

assignin('base', 'Fig35A_LearningCurve_Sessions', Sess);
assignin('base', 'Fig35A_LearningCurve_LearningSummarizeP', PValueLS);

end
