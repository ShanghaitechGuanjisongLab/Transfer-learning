% Fig35B（hM4D(Gi) vs mCherry）
% First transfer-session hit rate comparison, styled like English Fig1C
%
% Execution:
%   TransferLearning.Fig35.B_FirstSessionHitRate_LikeEnglishFig1C

function B_FirstSessionHitRate_LikeEnglishFig1C

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig35B_FirstSessionHitRate_LikeEnglishFig1C.svg";

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

requirePhaseTransfer = true;
B1 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_Gi,  requirePhaseTransfer);
B2 = TransferLearning.Fig35.iQueryLightWaterBlocks(DS_mCh, requirePhaseTransfer);
if isempty(B1) || isempty(B2)
	error('Fig35B_FS:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
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
Sess = TransferLearning.Fig35.iAddSessionIndex(Sess);

perMouse = TransferLearning.Fig35.iPerMouseTable(Sess);
perMouse = TransferLearning.Fig35.iAddFirstTransferPerf(perMouse, Sess);

x_mCh = double(perMouse.TransferFirstPerf(perMouse.Group=="mCherry"));
x_Gi  = double(perMouse.TransferFirstPerf(perMouse.Group=="hM4D(Gi)"));
x_mCh = x_mCh(isfinite(x_mCh));
x_Gi  = x_Gi(isfinite(x_Gi));

p = TransferLearning.Fig35.iRanksumSafe(x_mCh, x_Gi);

% --- Plot
DataCell = {x_mCh, x_Gi};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'Fig35B First transfer session hit rate');
MATLAB.Graphics.FigureAspectRatio(30, 20, 1);
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

try
	ax.XTick = [1, 2];
	ax.XTickLabel = {'mCherry', 'hM4D(Gi)'};
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

assignin('base', 'Fig35B_FirstTransferSession_PerMouse', perMouse);
assignin('base', 'Fig35B_FirstTransferSession_P', p);

end
