% English Fig2K: cFos activity-dependent inhibition vs Control
%
% v6 Panel K: cFos-MOp 精准抑制（学习曲线 + 首会话命中率）
% Data source: Fig3.5A (TransferLearning.Fig35.A_cFos_MOpVsControl)
% Outputs (SVG):
%   - English_Fig2K_cFos_LearningCurve.svg
%   - English_Fig2K_cFos_FirstSessionHitRate.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

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
B = TransferLearning.Fig35.iQueryLightWaterBlocks(DS, false);
if isempty(B)
	error('English_Fig2K:EmptyBehavior', 'No LightWater behavior rows found.');
end
B.Mouse = string(B.Mouse);
B.DateTime = TransferLearning.Fig35.iNormalizeDateTime(B.DateTime);

% Join group labels
J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);

% --- 4) Sessionize and add session index
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
Sess = TransferLearning.Fig35.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.Fig35.iAddSessionIndex(Sess);

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
grpLabels = ["Control","Inhibited"]; % figure labels

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
title(ax, 'cFos-specific inhibition', 'FontSize', 6, 'FontWeight', 'normal');

% Reference palette from 范例 SVGs: Control=#e60012, Experimental=#0070c0
edgeColors = [230/255, 0, 18/255; 0, 112/255, 192/255];

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

% --- 6b) Stats: draw overall learning-curve significance (like English Fig1B)
% Use LME Group main effect (additive model): tests overall curve separation
lmeTbl = table;
lmeTbl.Performance = double(Sess.Performance);
lmeTbl.Session = double(Sess.Session);
lmeTbl.Group = categorical(string(Sess.Group));
lmeTbl.Mouse = categorical(string(Sess.Mouse));
lmeModel = fitlme(lmeTbl, 'Performance ~ Session + Group + (1|Mouse)');
lmeAnova = anova(lmeModel);
rowGrp = find(string(lmeAnova.Term) == "Group", 1);
pCurve = NaN;
if ~isempty(rowGrp)
	pCurve = lmeAnova.pValue(rowGrp);
end
if isfinite(pCurve)
	sessIdx = min(2, min(numel(meanCells{1}), numel(meanCells{2})));
	y1 = meanCells{1}(sessIdx);
	y2 = meanCells{2}(sessIdx);
	yMid = (y1 + y2) / 2;
	yHalfLen = abs(y1 - y2) / 4;
	plot(ax, [sessIdx sessIdx], [yMid - yHalfLen, yMid + yHalfLen], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	if pCurve < 0.001
		astStr = '***';
	elseif pCurve < 0.01
		astStr = '**';
	elseif pCurve < 0.05
		astStr = '*';
	else
		astStr = 'n.s.';
	end
	ht = text(ax, sessIdx + 0.1, yMid, astStr, 'FontSize', 6, ...
		'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
		'HandleVisibility', 'off');
	ht.AffectAutoLimits = 'on';
end
fprintf('Learning curve overall p = %.4g\n', pCurve);

labels = {char(grpLabels(1)), char(grpLabels(2))};
try
	if numel(Patches) >= 2
		lg = legend(ax, Patches(1:2), labels, 'Location', 'best');
	else
		lg = legend(ax, labels, 'Location', 'best');
	end
	lg.FontSize = 6;
catch
end

ax.FontSize = 6;
xlabel(ax, 'Session', 'FontSize', 6);
ylabel(ax, 'Hit rate', 'FontSize', 6);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');

% Export learning curve
svgLC = fullfile(outDirUNC, 'English_Fig2K_cFos_LearningCurve.svg');
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
	TransferLearning.PrintFigure(f, svgLC);
	fprintf('Wrote: %s\n', svgLC);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% 
% --- 7) First transfer session hit-rate bar compare (Control vs Inhibited)
perMouse = TransferLearning.Fig35.iPerMouseTable(Sess);
perMouse = TransferLearning.Fig35.iAddFirstTransferPerf(perMouse, Sess);

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
[pFS, ~] = TransferLearning.Fig35.iRanksumSafe(xCtrl, xInh);

DataCell = {double(xCtrl(:)), double(xInh(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

%% 
f2 = figure('Color','w', 'Name', 'English Fig2K cFos First transfer session');
try
	f2.Units = 'centimeters';
	f2.Position(3:4) = [4, 3];
	try, f2.PaperPositionMode = 'auto'; catch, end
	try, f2.InvertHardcopy = 'off'; catch, end
catch
end

[~, ~, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
ax2.FontSize = 6;
ax2.Color = 'w';
ax2.XAxis.Visible = false;
ax2.XTick = [];
legend(ax2, 'off');

	% Bar styling – reference palette from 范例 SVGs
	colorA = [230/255, 0, 18/255];    % #e60012 Control
	colorB = [0, 112/255, 192/255];   % #0070c0 Experimental
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nBars = numel(Bars2.YData);
	reps = ceil(nBars/2);
	Bars2.CData = repmat([colorA; colorB], reps, 1);
	Bars2.CData = Bars2.CData(1:nBars, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 0.5;
	try, Bars2.FaceAlpha = 1/3; catch, end
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorA;
		Bars2(2).FaceColor = colorB;
		Bars2(1).LineWidth = 0.5;
		Bars2(2).LineWidth = 0.5;
		try, Bars2(1).FaceAlpha = 1/3; catch, end
		try, Bars2(2).FaceAlpha = 1/3; catch, end
	end
end
for eb = ErrorBars2.Object(:)'
	eb.LineWidth = 0.5;
end
ax2.XLim = [0.5, 2.5];

ylabel(ax2, 'Hit rate', 'FontSize', 6);
title(ax2, 'First block', 'FontSize', 6, 'FontWeight', 'normal');
box(ax2, 'off');

svgFS = fullfile(outDirUNC, 'English_Fig2K_cFos_FirstSessionHitRate.svg');
try
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar), ax2.Toolbar.Visible = 'off'; end
	TransferLearning.PrintFigure(f2, svgFS);
	fprintf('Wrote: %s (p=%.4g)\n', svgFS, pFS);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

assignin('base', 'English_Fig2K_Sessions', Sess);
assignin('base', 'English_Fig2K_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig2K_FirstSessionP', pFS);
