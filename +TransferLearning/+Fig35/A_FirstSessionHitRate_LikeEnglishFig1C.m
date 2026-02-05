% Fig35A（cFos: MOp inhibited vs Control）
% First transfer-session hit rate comparison, styled like English Fig1C
%
% Execution:
%   TransferLearning.Fig35.A_FirstSessionHitRate_LikeEnglishFig1C

function A_FirstSessionHitRate_LikeEnglishFig1C

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig35A_FirstSessionHitRate_LikeEnglishFig1C.svg";

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
	error('Fig35A_FS:EmptyMice', 'DS.Mice is empty.');
end
if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
		error('Fig35A_FS:MissingMouse', 'DS.Mice has no Mouse column/rownames.');
	end
end
S.Mouse = string(S.Mouse);

need = ["ExpressedBrain","MarkTimes"];
if ~all(ismember(need, string(S.Properties.VariableNames)))
	error('Fig35A_FS:MissingVars', 'DS.Mice lacks required vars: %s', char(strjoin(need, ', ')));
end

S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";

try
	bad = arrayfun(@(g) nnz(char(g) == ' ') > 1, S.Group);
	S = S(~bad, :);
catch
end

S = S(ismember(S.Group, ["Control","MOp"]), :);
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);
if isempty(S)
	error('Fig35A_FS:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end

% --- Query LightWater behavior blocks (require Phase for Transfer-only)
B = TransferLearning.Fig35.iQueryLightWaterBlocks(DS, true);
if isempty(B)
	error('Fig35A_FS:EmptyBehavior', 'No LightWater behavior rows found.');
end
B.Mouse = string(B.Mouse);
B.DateTime = TransferLearning.Fig35.iNormalizeDateTime(B.DateTime);

J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);

if ~ismember('Phase', J.Properties.VariableNames)
	error('Fig35A_FS:MissingPhase', 'Behavior table has no Phase column; cannot restrict to Transfer.');
end
J.Phase = string(J.Phase);
JT = J(J.Phase == "Transfer", :);
if isempty(JT)
	error('Fig35A_FS:EmptyTransfer', 'No Phase==Transfer LightWater rows found after joining groups.');
end

% Sessionize within Transfer only
SessT = TransferLearning.Fig35.iSessionizeByDateTime(JT(:, intersect(JT.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable')));
SessT = sortrows(SessT, {'Mouse','DateTime'});

% First Transfer session per mouse
mice = unique(string(SessT.Mouse));
First = table(string.empty(0,1), strings(0,1), nan(0,1), 'VariableNames', {'Mouse','Group','FirstPerformance'});
First.Mouse = mice;
First.Group = strings(numel(mice),1);
First.FirstPerformance = nan(numel(mice),1);
for i = 1:numel(mice)
	m = mice(i);
	Sm = SessT(string(SessT.Mouse) == m, :);
	Sm = sortrows(Sm, 'DateTime');
	First.Group(i) = string(Sm.Group(1));
	First.FirstPerformance(i) = double(Sm.Performance(1));
end

xCtrl = double(First.FirstPerformance(First.Group=="Control"));
xMOp  = double(First.FirstPerformance(First.Group=="MOp"));
xCtrl = xCtrl(isfinite(xCtrl));
xMOp  = xMOp(isfinite(xMOp));

p = TransferLearning.Fig35.iRanksumSafe(xCtrl, xMOp);

% --- Plot (BarScatterCompare)
DataCell = {xCtrl, xMOp};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'Fig35A First transfer session hit rate');
MATLAB.Graphics.FigureAspectRatio(30, 20, 1);
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

try
	ax.XTick = [1, 2];
	ax.XTickLabel = {'Control', 'Inhibited'};
	legend(ax, 'off');
catch
end

% asterisk font size
if isfield(Optional, 'MultiCompare') && ismember('PText', Optional.MultiCompare.Properties.VariableNames)
	for pt = Optional.MultiCompare.PText(:)'
		pt.FontSize = 6;
	end
end

% bar colors: red/blue like English Fig1C
colorA = [1 0 0];
colorB = [0 0 1];
try
	if numel(Bars) == 1
		Bars.FaceColor = 'flat';
		nBars = numel(Bars.YData);
		reps = ceil(nBars/2);
		Bars.CData = repmat([colorA; colorB], reps, 1);
		Bars.CData = Bars.CData(1:nBars, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	else
		if numel(Bars) >= 2
			Bars(1).FaceColor = colorA;
			Bars(2).FaceColor = colorB;
			Bars(1).LineWidth = 0.5;
			Bars(2).LineWidth = 0.5;
			Bars(1).FaceAlpha = 1/3;
			Bars(2).FaceAlpha = 1/3;
		end
	end
catch
end
for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end
try, ax.XLim = [0.5, 2.5]; catch, end

ylabel(ax, 'Hit rate', 'FontSize', 6);
title(ax, 'Session#1 (Transfer)', 'FontSize', 6);
box(ax, 'off');
grid(ax, 'off');
try, ax.Toolbar.Visible = 'off'; catch, end

% --- Export
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

assignin('base', 'Fig35A_FirstTransferSession_Raw', First);
assignin('base', 'Fig35A_FirstTransferSession_P', p);

end
