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
[lineMean, lineSem] = iZeroAlignedLineStats(Data);
%% 

f = figure('Color', 'w', 'Name', '中文图63B TH/Ctrl learned-active calcium lines');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12, 8];
f.PaperSize = [12, 8];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;
ax.XAxis.LineWidth = 2;
ax.YAxis.LineWidth = 2;

lineColors = [TransferLearning.ContinualColor; TransferLearning.ColorA];
patches = MATLAB.Graphics.MultiShadowedLines( ...
	lineMean, lineSem, 0.2, ...
	X=repmat(Data.XPlot(:), 1, 2), ...
	EdgeColors=lineColors(1:2, :), ...
	Ax=ax, ...
	LineStyles=["-"; "-"]);
for p = patches(:)'
	p.LineWidth = 2;
end

xline(ax, 0, '--k', 'LineWidth', 2);
xline(ax, 1, '--k', 'LineWidth', 2);
box(ax, 'off');
grid(ax, 'off');
xlim(ax, [0, 3]);
xlabel(ax, 'Time', 'FontSize', 12);
ylabel(ax, 'z-score', 'FontSize', 12);
	title(ax, 'L5 🔊💧 active cells', 'FontSize', 12, 'FontWeight', 'normal', 'FontName', 'Segoe UI Emoji');
ax.XTick = [0 1 3];
ax.XTickLabel = {"💡", "💧", "3"};

lg = legend(patches, ["Ctrl", "TH"], 'Location', MATLAB.Graphics.OptimizedLegendLocation(patches), 'Box', 'off');
lg.FontSize = 12;

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

svgPath = '中文图Fig63B_THInhibitVsCtrl_LearnedActiveMeanLines.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('Ctrl: %d cells/%d mice; TH: %d cells/%d mice\n', Data.NCtrlCell, Data.NCtrlMouse, Data.NTHCell, Data.NTHMouse);

assignin('base', 'Fig63B_Data', Data);

function [lineMean, lineSem] = iZeroAlignedLineStats(Data)
[~, idx0] = min(abs(Data.XPlot(:)));
ctrlTrace = Data.Ctrl.Trace - Data.Ctrl.Trace(:, idx0);
thTrace = Data.TH.Trace - Data.TH.Trace(:, idx0);
lineMean = [mean(ctrlTrace, 1, 'omitnan').', mean(thTrace, 1, 'omitnan').'];
lineSem = [iSem(ctrlTrace, 1).', iSem(thTrace, 1).'];
end

function semValue = iSem(x, dim)
semValue = std(x, 0, dim, 'omitnan') ./ sqrt(sum(isfinite(x), dim));
end
