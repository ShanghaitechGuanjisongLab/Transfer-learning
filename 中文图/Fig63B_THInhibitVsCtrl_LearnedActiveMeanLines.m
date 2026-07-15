% 中文图63B：声水活跃细胞，首次迁移光水 0~3 s Ctrl/TH z-score 均值线

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = Fig63BC_THInhibitCtrlActiveCalciumData();
blMask = Data.XPlot >= -1 & Data.XPlot < 0;
ctrlTrace = Data.Ctrl.Trace - mean(Data.Ctrl.Trace(:, blMask), 2, 'omitnan');
thTrace = Data.TH.Trace - mean(Data.TH.Trace(:, blMask), 2, 'omitnan');
lineMean = [mean(ctrlTrace, 1, 'omitnan').', mean(thTrace, 1, 'omitnan').'];
lineSem = [iSem(ctrlTrace, 1).', iSem(thTrace, 1).'];
%% 

f = figure('Color', 'w', 'Name', '中文图63B TH/Ctrl learned-active calcium lines');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];

ax = axes(f);
hold(ax, 'on');

lineColors = [TransferLearning.ContinualColor; TransferLearning.ColorB];
patches = MATLAB.Graphics.MultiShadowedLines( ...
	lineMean, lineSem, 0.2, ...
	X=repmat(Data.XPlot(:), 1, 2), ...
	EdgeColors=lineColors(1:2, :), ...
	Ax=ax, ...
	LineStyles=["-"; "-"]);
for p = patches(:)'
	p.LineWidth = 2;
end

xline(ax, 0, '--k');
xline(ax, 1, '--k');
box(ax, 'off');
xlabel(ax, 'Time');
ylabel(ax, 'z-score');
title(ax, 'L5 🔊💧 active cells');
ax.XTickLabel(ismember(ax.XTick,[0,1])) = {"💡", "💧"};

lg = legend(patches, ["Ctrl", "TH"], 'Location', MATLAB.Graphics.OptimizedLegendLocation(patches), 'Box', 'off');

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = '中文图Fig63B_THInhibitVsCtrl_LearnedActiveMeanLines.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('Ctrl: %d cells/%d mice; TH: %d cells/%d mice\n', Data.NCtrlCell, Data.NCtrlMouse, Data.NTHCell, Data.NTHMouse);


function semValue = iSem(x, dim)
semValue = std(x, 0, dim, 'omitnan') ./ sqrt(sum(isfinite(x), dim));
end
