% Fig35D（Vacation7 vs Ctrl）
% First transfer-session hit rate comparison, styled like English Fig1C
%
% Execution:
%   TransferLearning.Fig35.D_FirstSessionHitRate_LikeEnglishFig1C

function D_FirstSessionHitRate_LikeEnglishFig1C

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig35D_FirstSessionHitRate_LikeEnglishFig1C.svg";

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

DS_Ctrl = TransferLearning.AudioLightBaseline();
DS_V7   = TransferLearning.Vacation7();

requirePhaseTransfer = true;
B1 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_Ctrl, requirePhaseTransfer);
B2 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_V7,   requirePhaseTransfer);
if isempty(B1) || isempty(B2)
	error('Fig35D_FS:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end
B1.Group = repmat("Ctrl",      height(B1), 1);
B2.Group = repmat("Vacation7", height(B2), 1);

B1.Mouse = string(B1.Mouse);
B2.Mouse = string(B2.Mouse);
B1.DateTime = TransferLearning.Fig35.iNormalizeDateTime(B1.DateTime);
B2.DateTime = TransferLearning.Fig35.iNormalizeDateTime(B2.DateTime);

J = [B1; B2];
J.Group = string(J.Group);

if ~ismember('Phase', J.Properties.VariableNames)
	error('Fig35D_FS:MissingPhase', 'Behavior table has no Phase column; cannot restrict to Transfer.');
end
J.Phase = string(J.Phase);
JT = J(J.Phase == "Transfer", :);
if isempty(JT)
	error('Fig35D_FS:EmptyTransfer', 'No Phase==Transfer LightWater rows found.');
end

SessT = TransferLearning.Fig35.iSessionizeByDateTime(JT(:, intersect(JT.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable')));
SessT = sortrows(SessT, {'Mouse','DateTime'});

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

xCtrl = double(First.FirstPerformance(First.Group=="Ctrl"));
xV7   = double(First.FirstPerformance(First.Group=="Vacation7"));
xCtrl = xCtrl(isfinite(xCtrl));
xV7   = xV7(isfinite(xV7));

p = TransferLearning.Fig35.iRanksumSafe(xCtrl, xV7);

% --- Plot
DataCell = {xCtrl, xV7};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'Fig35D First transfer session hit rate');
MATLAB.Graphics.FigureAspectRatio(30, 20, 1);
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

try
	ax.XTick = [1, 2];
	ax.XTickLabel = {'Ctrl', 'Vacation7'};
	legend(ax, 'off');
catch
end

if isfield(Optional, 'MultiCompare') && ismember('PText', Optional.MultiCompare.Properties.VariableNames)
	for pt = Optional.MultiCompare.PText(:)'
		pt.FontSize = 6;
	end
end

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

assignin('base', 'Fig35D_FirstTransferSession_Raw', First);
assignin('base', 'Fig35D_FirstTransferSession_P', p);

end
