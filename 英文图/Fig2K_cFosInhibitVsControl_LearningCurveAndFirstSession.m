% English Fig2K: cFos activity-dependent inhibition vs Control
%
% v6 Panel K: cFos-MOp 精准抑制（学习曲线 + 首会话命中率）
% Shared behavior-session helpers: TransferLearning.BehaviorSessions
% Outputs (SVG):
%   - English_Fig2K_cFos_LearningCurve.svg
%   - English_Fig2K_cFos_FirstSessionHitRate.svg
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
	error('English_Fig2K:EmptyMiceTable', 'DS.Mice is empty.');
end

if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
		error('English_Fig2K:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
S.Mouse = string(S.Mouse);

needVars = ["ExpressedBrain","MarkTimes"];
for k = 1:numel(needVars)
	if ~ismember(needVars(k), string(S.Properties.VariableNames))
		error('English_Fig2K:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(k));
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
	error('English_Fig2K:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end

% --- 3) Query LightWater behavior blocks
B = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false);
if isempty(B)
	error('English_Fig2K:EmptyBehavior', 'No LightWater behavior rows found.');
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
f = figure('Color','w', 'Name', 'English Fig2K cFos Learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8]; % 90mm x 80mm (match English Fig1B)
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax,'on');
title(ax, 'cFos-specific inhibition', 'FontSize', 12, 'FontWeight', 'normal');

edgeColors = [TransferLearning.ContinualColor;TransferLearning.ColorA];

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
svgLC = 'English_Fig2K_cFos_LearningCurve.svg';
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
% --- 7) First transfer session hit-rate bar compare (Control vs Inhibited)
perMouse = TransferLearning.BehaviorSessions.iPerMouseTable(Sess);
perMouse = TransferLearning.BehaviorSessions.iAddFirstTransferPerf(perMouse, Sess);

xCtrl = perMouse.TransferFirstPerf(perMouse.Group=="Control");
xInh  = perMouse.TransferFirstPerf(perMouse.Group=="MOp");

% Fallback if Phase/Transfer not available
if ~any(isfinite(xCtrl)) || ~any(isfinite(xInh))
	xCtrl = nan(height(perMouse),1);
	xInh  = nan(height(perMouse),1);
	for i = 1:height(perMouse)
		m = perMouse.Mouse(i);
		S1 = Sess(Sess.Mouse==m, :);
		S1 = sortrows(S1, 'Session');
		p1 = double(S1.Performance(find(S1.Session==1,1,'first')));
		if perMouse.Group(i)=="Control"
			xCtrl(i) = p1;
		else
			xInh(i) = p1;
		end
	end
end

xCtrl = xCtrl(isfinite(xCtrl));
xInh  = xInh(isfinite(xInh));
[pFSRanksum, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(xCtrl, xInh);

DataCell = {double(xCtrl(:)), double(xInh(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

%% 
f2 = figure('Color','none', 'Name', 'English Fig2K cFos First transfer session');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperPositionMode = 'auto';
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];

tiledlayout(1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
nexttile;
[~, Opt2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
pFS = iBarScatterPValue(Opt2, pFSRanksum);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
ax2.FontSize = 12;
ax2.LineWidth = 2;
if isprop(ax2.XAxis, 'LineWidth')
	ax2.XAxis.LineWidth = 2;
	ax2.YAxis.LineWidth = 2;
end
ax2.Color = 'none';
ax2.XAxis.Visible = false;
ax2.XTick = [];
legend(ax2, 'off');

if isfield(Opt2, 'MultiCompare') && ismember('PText', Opt2.MultiCompare.Properties.VariableNames)
	for pt = Opt2.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end
if isfield(Opt2, 'MultiCompare') && ismember('PLine', Opt2.MultiCompare.Properties.VariableNames)
	for pl = Opt2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
	end
end
iStyleBars(Bars2, edgeColors(1,:), edgeColors(2,:));
iStyleErrorBars(ErrorBars2, edgeColors);
ax2.XLim = [0.5, 2.5];

ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end

svgFS = 'English_Fig2K_cFos_FirstSessionHitRate.svg';
svgFS = TransferLearning.ExportStandardFigureTransparent(f2, 2, svgFS);
fprintf('Wrote: %s (first-block p=%.4g)\n', svgFS, pFS);
fprintf('Fig334C first-block hit-rate BarScatterCompare p = %.4g\n', pFS);
fprintf('Fig334C first-block hit-rate ranksum p = %.4g\n', pFSRanksum);

assignin('base', 'English_Fig2K_Sessions', Sess);
assignin('base', 'English_Fig2K_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig2K_FirstSessionP', pFS);

function h = iText(varargin)
h = text(varargin{:});
end

function pValue = iBarScatterPValue(options, fallbackPValue)
pValue = fallbackPValue;
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PValue', options.MultiCompare.Properties.VariableNames) && ~isempty(options.MultiCompare.PValue)
	pCandidate = options.MultiCompare.PValue(1);
	if isnumeric(pCandidate) && isfinite(pCandidate)
		pValue = double(pCandidate);
	end
end
end

function iStyleBars(barsObj, colorControl, colorInhibited)
if isscalar(barsObj)
	barsObj.FaceColor = 'flat';
	nBars = numel(barsObj.YData);
	barsObj.CData = repmat([colorControl; colorInhibited], ceil(nBars/2), 1);
	barsObj.CData = barsObj.CData(1:nBars, :);
	barsObj.BarWidth = 0.5;
	barsObj.LineWidth = 2;
	barsObj.BaseLine.LineWidth = 2;
	barsObj.EdgeColor = 'none';
	barsObj.FaceAlpha = 1;
	return;
end
barsObj(1).FaceColor = colorControl;
barsObj(2).FaceColor = colorInhibited;
barsObj(1).BarWidth = 0.5;
barsObj(2).BarWidth = 0.5;
barsObj(1).LineWidth = 2;
barsObj(2).LineWidth = 2;
barsObj(1).BaseLine.LineWidth = 2;
barsObj(2).BaseLine.LineWidth = 2;
barsObj(1).EdgeColor = 'none';
barsObj(2).EdgeColor = 'none';
barsObj(1).FaceAlpha = 1;
barsObj(2).FaceAlpha = 1;
end

function iStyleErrorBars(errorBars, colors)
for iE = 1:height(errorBars)
	errorBar = errorBars.Object(iE);
	errorBar.LineWidth = 2;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
end
end

