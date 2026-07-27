Data = Fig71_BaselineConvergenceCache();
%% 

f = figure('Color', 'w', 'Name', '中文图71B Baseline convergence deviation');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8.0];

ax = axes(f);
hold(ax, 'on');
Colors=[TransferLearning.LearnedColor; TransferLearning.NaiveColor; TransferLearning.ColorA; TransferLearning.ColorB];
patches = MATLAB.Graphics.MultiShadowedLines( ...
	Data.DeviationMean, ...
	Data.DeviationSem, ...
	1 / (numel(Data.Phases) + 1), ...
	X=double(Data.XSec(:)), ...
	EdgeColors=[TransferLearning.LearnedColor; TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB], ...
	LineStyles=Data.PhaseLineStyles, ...
	Ax=ax);
lg = legend(ax, patches, cellstr(Data.LegendLabels), 'Location', 'northeast');
lg.Box = 'off';
box(ax, 'off');
grid(ax, 'off');
xlabel(ax, 'Time(s)');
ylabel(ax, 'log_2(Divergence)');
lineObj = findobj(ax, 'Type', 'Line');
for iLine = 1:numel(lineObj)
	lineObj(iLine).LineWidth = 2;
end
svgPath = '中文图Fig71B_BaselineConvergence_Deviation.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

