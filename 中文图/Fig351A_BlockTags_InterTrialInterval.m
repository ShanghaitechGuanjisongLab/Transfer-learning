% 中文图351A：代表性初始/迁移光水会话的回合间隙 BlockTags

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
svgName = "中文图Fig351A_BlockTags_InterTrialInterval.svg";

Sess = TransferLearning.Fig351.BuildStartSessionBlockTagMetrics();
[NaiveRow, TransferRow] = iPickRepresentativeRows(Sess);

f = figure('Color', 'w', 'Name', '中文图351A BlockTags inter-trial interval');
f.Units = 'centimeters';
f.Position(3:4) = [9.0, 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9.0, 4.0];
f.PaperSize = [9.0, 4.0];

ax1 = axes(f, 'Units', 'normalized', 'Position', [0.10 0.22 0.35 0.62]);
ax2 = axes(f, 'Units', 'normalized', 'Position', [0.57 0.22 0.35 0.62]);

iPlotOneInterval(ax1, NaiveRow, 'Naive');
iPlotOneInterval(ax2, TransferRow, 'Transfer');
ax2.YTickLabel = [];

annotation(f, 'textbox', [0.36 0.04 0.28 0.06], 'String', 'Time (s)', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 6);
annotation(f, 'line', [0.12 0.18], [0.93 0.93], 'Color', [0 0 0], 'LineWidth', 1);
annotation(f, 'textbox', [0.18 0.90 0.08 0.05], 'String', 'CD1', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 6);
annotation(f, 'line', [0.27 0.33], [0.93 0.93], 'Color', [0.85 0.2 0.2], 'LineWidth', 1);
annotation(f, 'textbox', [0.33 0.90 0.08 0.05], 'String', 'CD2', 'EdgeColor', 'none', ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 6);

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig351A_NaiveRepresentative', NaiveRow);
assignin('base', 'Fig351A_TransferRepresentative', TransferRow);

function [naiveRow, transferRow] = iPickRepresentativeRows(Sess)
Naive = Sess(Sess.Group == "Naive", :);
Transfer = Sess(Sess.Group == "Transfer", :);
	if isempty(Naive) || isempty(Transfer)
		error('Fig351A:EmptyGroup', 'Naive or Transfer representative pool is empty.');
	end

	tOrder = sortrows([(1:height(Transfer))', Transfer.RepGapSec, Transfer.RepIntervalLickSec], [-2 -3]);
	nOrder = sortrows([(1:height(Naive))', Naive.RepGapSec, Naive.RepIntervalLickSec], [-2 -3]);

	found = false;
	for iT = 1:size(tOrder, 1)
		tr = Transfer(tOrder(iT, 1), :);
		cand = Naive(Naive.RepGapSec < tr.RepGapSec & Naive.RepIntervalLickSec < tr.RepIntervalLickSec, :);
		if ~isempty(cand)
			candOrder = sortrows([(1:height(cand))', cand.RepGapSec, cand.RepIntervalLickSec], [-2 -3]);
			naiveRow = cand(candOrder(1, 1), :);
			transferRow = tr;
			found = true;
			break;
		end
	end
	if ~found
		error('Fig351A:NoRepresentativePair', 'No representative Naive/Transfer pair satisfies longer gap and more CD2 licking in Transfer.');
	end
end

function iPlotOneInterval(ax, Row, panelTitle)
	cd1 = Row.CD1State{1};
	cd2 = Row.CD2State{1};
	si = Row.SeriesIntervalSec;
	p1 = Row.RepPeak1Index;
	p2 = Row.RepPeak2Index;
	pad = max(1, round(1 / si));
	i1 = max(1, p1 - pad);
	i2 = min(numel(cd1), p2 + pad);
	x = ((i1:i2)' - p1) * si;
	y1 = double(cd1(i1:i2)) + 1.2;
	y2 = double(cd2(i1:i2));

	hold(ax, 'on');
	plot(ax, x, y1, '-', 'Color', [0 0 0], 'LineWidth', 1);
	plot(ax, x, y2, '-', 'Color', [0.85 0.2 0.2], 'LineWidth', 1);
	xline(ax, 0, ':k', 'LineWidth', 1);
	xline(ax, (p2 - p1) * si, ':k', 'LineWidth', 1);
	hold(ax, 'off');

	ax.FontSize = 6;
	ax.LineWidth = 1;
	ax.TickDir = 'out';
	ax.YTick = [0.5 1.7];
	ax.YTickLabel = {'CD2', 'CD1'};
	ylim(ax, [-0.1 2.3]);
	xlim(ax, [x(1) x(end)]);
	box(ax, 'off');
	grid(ax, 'off');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	title(ax, panelTitle, 'FontSize', 6, 'FontWeight', 'normal');
end