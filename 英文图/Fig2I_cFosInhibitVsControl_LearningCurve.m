% English Fig2I: cFos activity-dependent inhibition vs Control
%
% v6 Panel K: cFos-MOp 精准抑制（仅学习曲线；首会话命中率柱状图已按用户要求删除）
% Shared behavior-session helpers: TransferLearning.BehaviorSessions
% Outputs (SVG):
%   - English_Fig2I_cFos_LearningCurve.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.


% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- 1) Load cFos database
matPath = "\\Data-Server-2\个人数据\张天夫\202601\cFos合集.v2.mat";
DS = UniExp.DataSet(matPath);

% --- 2) Build group table (Mouse -> Group)
S = DS.Mice;
if isempty(S)
		error('English_Fig2I:EmptyMiceTable', 'DS.Mice is empty.');
end

if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
			error('English_Fig2I:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
S.Mouse = string(S.Mouse);

needVars = ["ExpressedBrain","MarkTimes"];
for k = 1:numel(needVars)
	if ~ismember(needVars(k), string(S.Properties.VariableNames))
		error('English_Fig2I:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(k));
	end
end

S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";

% Remove weird labels with >1 spaces (match reference behavior)
try
	bad = arrayfun(@(g) nnz(char(g) == ' ') > 1, S.Group);
	S = S(~bad, :);
catch
end

% Keep only MOp vs Control
S = S(ismember(S.Group, ["Control","MOp"]), :);
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);
if isempty(S)
	error('English_Fig2I:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end

% --- 3) Query LightWater behavior blocks
B = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false);
if isempty(B)
	error('English_Fig2I:EmptyBehavior', 'No LightWater behavior rows found.');
end
B.Mouse = string(B.Mouse);
B.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(B.DateTime);

% Join group labels
J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);

% --- 4) Sessionize and add session index
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
Sess = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);
nControlMice = numel(unique(string(Sess.Mouse(Sess.Group == "Control"))));
nInhibitedMice = numel(unique(string(Sess.Mouse(Sess.Group == "MOp"))));

% --- 5) Learning curve summary (UniExp.LearningSummarize)
sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);

PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

grpOrder = ["Control","MOp"]; % data group keys
grpLabels = ["Control","cFos"]; % figure labels

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

% n per group is intentionally NOT shown in legend (match request)

%% 
% --- 6) Plot learning curve (like English Fig1B)
f = figure('Color','w', 'Name', 'English Fig2I cFos Learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8]; % 90mm x 80mm (match English Fig1B)
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax,'on');
title(ax, 'cFos-specific inhibition', 'FontSize', 12, 'FontWeight', 'normal');

edgeColors = [TransferLearning.TransferColor;TransferLearning.ColorB];

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(Sess, 'Performance', 'Session', 'Group', 'Mouse');
sessions7 = Sess(Sess.Session <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Session', 'Group', 'Mouse');
max7Ctrl = max(meanCells{1}(1:min(7, end)), [], 'omitnan');
max7CFos = max(meanCells{2}(1:min(7, end)), [], 'omitnan');
yTop7 = max(max7Ctrl, max7CFos);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
if groupP7 < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP7); end
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

fprintf('Fig334C mice: Control n = %d, cFos n = %d\n', nControlMice, nInhibitedMice);
fprintf('Two-way ANOVA Group P (all blocks) = %.4g\n', groupP);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);

labels = {char(grpLabels(1)), char(grpLabels(2))};
try
	if numel(Patches) >= 2
		lg = legend(ax, Patches(1:2), labels, 'Location', 'southeast');
	else
		lg = legend(ax, labels, 'Location', 'southeast');
	end
	lg.FontSize = 12;
	lg.Box = 'off';
	lg.Title.String = '💡💧';
	lg.Title.FontSize = 12;
catch
end

ax.FontSize = 12;
xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
box(ax, 'off');
grid(ax, 'off');

% Export learning curve
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgLC = 'English_Fig2I_cFos_LearningCurve.svg';
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
	svgLC = TransferLearning.ExportStandardFigure(f, 2, svgLC);
	fprintf('Wrote: %s\n', svgLC);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%%
% 用户裁定（2026-09-17）：I 面板只保留学习曲线，删除首 block 柱（首 block 差异不显著）。

assignin('base', 'English_Fig2I_Sessions', Sess);
assignin('base', 'English_Fig2I_LearningSummarizeP', PValueLS);


