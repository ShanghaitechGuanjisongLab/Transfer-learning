% 散度概念图：六次合成试次，曲线、状态点与相对散度均由同一组数据生成。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end

Palette = [0.7422 0.0000 0.2575; 0.9966 0.7062 0.8163; 0.2949 0.9920 0.9616; 0.2164 0.5704 0.9566; 0.8225 0.5065 0.1249; 0.9559 0.9970 0.0058; 0.0063 0.0108 0.4459; 0.0000 0.5652 0.1512; 0.2473 0.1803 0.0001];
TrialColors = Palette(1:6, :);
MeanColor = Palette(7, :);
SpreadColor = Palette(8, :);
DashedColor = Palette(9, :);
AxisColor = [0 0 0];
Time = (-0.6:0.01:2.4)';
MeanShape = zeros(size(Time));
Rising = Time >= 0 & Time <= 1;
MeanShape(Rising) = (1 - cos(pi * Time(Rising))) / 2;
Falling = Time > 1;
MeanShape(Falling) = exp(-((Time(Falling) - 1) / 0.95).^2);
SpreadShape = MeanShape;
Baseline = Time <= 1e-10;
PostCue = Time > 1e-10;
MeanVector = [0.65; 0.50];
HighResiduals = [0.3 0.2 0.1 -0.1 -0.2 -0.3; 0.1 -0.3 0.2 -0.2 0.3 -0.1];
TrialCount = size(HighResiduals, 2);
TrialAngles = pi/12 + (0:TrialCount-1) * (2*pi/TrialCount);
HighCircleRadius = sqrt(sum(var(HighResiduals, 0, 2)) * (TrialCount - 1) / TrialCount);
HighResiduals = HighCircleRadius * [cos(TrialAngles); sin(TrialAngles)];
ResidualSets = {HighResiduals / 2, HighResiduals};
RowNames = ["Low Divergence", "High Divergence"];
[~, SampleIndex] = min(abs(Time - 1));
assert(TrialCount == 6 && abs(Time(SampleIndex) - 1) < 1e-10, '试次数或取值时刻不正确。');

Figure = figure('Color', 'w', 'Name', 'Trial-to-trial divergence', 'Units', 'centimeters', 'Position', [2 2 17 11]);
Layout = tiledlayout(Figure, 4, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(Layout, 'Trial-to-trial divergence', 'FontName', 'Helvetica', 'FontSize', 11, 'FontWeight', 'bold');
TraceAxes = gobjects(2, 2);
StateAxes = gobjects(2, 1);
RatioAxes = gobjects(2, 1);
TrialLines = cell(2, 2);
MeanLines = gobjects(2, 2);
StatePoints = cell(2, 1);
Rows = cell(2, 1);
CircleAngle = linspace(0, 2*pi, 240);
for RowIndex = 1:2
	Residuals = ResidualSets{RowIndex};
	Signals = reshape(MeanShape * MeanVector', [], 2, 1) + reshape(SpreadShape, [], 1, 1) .* reshape(Residuals, 1, 2, TrialCount);
	MeanSignals = mean(Signals, 3);
	ExpectedMean = MeanShape * MeanVector';
	assert(max(abs(MeanSignals - ExpectedMean), [], 'all') < 1e-12, '合成曲线的均值不一致。');
	assert(all(Signals(Baseline, :, :) == 0, 'all'), 'cue前的trial应完全重合在零基线。');
	AtOneSecond = reshape(Signals(SampleIndex, :, :), 2, TrialCount);
	Sigma = sqrt(sum(var(AtOneSecond, 0, 2)));
	MeanNorm = norm(mean(AtOneSecond, 2));
	Divergence = Sigma / MeanNorm;
	CenteredStates = AtOneSecond - mean(AtOneSecond, 2);
	TrialRadii = vecnorm(CenteredStates, 2, 1);
	CircleRadius = mean(TrialRadii);
	StateAngles = sort(mod(atan2(CenteredStates(2, :), CenteredStates(1, :)), 2*pi));
	AngleGaps = diff([StateAngles StateAngles(1) + 2*pi]);
	assert(max(abs(TrialRadii - CircleRadius)) < 1e-12 && max(abs(AngleGaps - 2*pi/TrialCount)) < 1e-12, '六个trial应等角度分布在同一圆周。');
	assert(abs(Sigma - CircleRadius*sqrt(TrialCount/(TrialCount-1))) < 1e-12, '圆半径与样本标准差的关系不正确。');
	MinimumSeparation = zeros(1, 2);
	FirstTile = (RowIndex - 1) * 6 + 1;
	for CellIndex = 1:2
		Responses = reshape(Signals(:, CellIndex, :), numel(Time), TrialCount);
		SortedResponses = sort(Responses, 2);
		MinimumSeparation(CellIndex) = min(diff(SortedResponses(PostCue, :), 1, 2), [], 'all');
		assert(MinimumSeparation(CellIndex) > 1e-8, 'cue后的trial应平滑分开且不交叉。');
		assert(min(abs(Responses(PostCue, :) - MeanSignals(PostCue, CellIndex)), [], 'all') > 1e-8, 'cue后的trial与均值线重合。');
		Ax = nexttile(Layout, FirstTile + (CellIndex - 1)*3);
		hold(Ax, 'on');
		xline(Ax, 1, '--', 'Color', DashedColor, 'LineWidth', 0.6, 'HandleVisibility', 'off');
		PatchX = [repmat(Time, 1, TrialCount); nan(1, TrialCount)];
		PatchY = [Responses; nan(1, TrialCount)];
		PatchColors = repmat(reshape(TrialColors, 1, TrialCount, 3), numel(Time) + 1, 1, 1);
		TrialLines{RowIndex, CellIndex} = patch(Ax, PatchX, PatchY, PatchColors, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 0.75, 'DisplayName', 'Trial');
		TrialLines{RowIndex, CellIndex}.UserData = struct('Trial', 1:TrialCount, 'Cell', CellIndex, 'Row', RowIndex, 'TrialColors', TrialColors);
		MeanLines(RowIndex, CellIndex) = plot(Ax, Time, MeanSignals(:, CellIndex), 'Color', MeanColor, 'LineWidth', 1.5, 'DisplayName', 'Mean');
		axis(Ax, 'padded');
		ylabel(Ax, "Cell " + CellIndex);
		if CellIndex == 1 && RowIndex == 1
			title(Ax, 'Repeated trials', 'FontWeight', 'normal');
		end
		Ax.XTick = [0 1 2];
		Ax.YTick = [];
		if RowIndex ~= 2 || CellIndex ~= 2
			Ax.XTickLabel = [];
		else
			xlabel(Ax, 'Time from cue (s)');
		end
		TraceAxes(RowIndex, CellIndex) = Ax;
	end

	Ax = nexttile(Layout, FirstTile + 1, [2 1]);
	hold(Ax, 'on');
	plot(Ax, MeanVector(1) + CircleRadius*cos(CircleAngle), MeanVector(2) + CircleRadius*sin(CircleAngle), '--', 'Color', DashedColor, 'LineWidth', 0.85);
	quiver(Ax, 0, 0, MeanVector(1), MeanVector(2), 0, 'Color', MeanColor, 'LineWidth', 0.65, 'MaxHeadSize', 0.05);
	quiver(Ax, MeanVector(1), MeanVector(2), Sigma, 0, 0, 'Color', SpreadColor, 'LineWidth', 1, 'MaxHeadSize', 0.4);
	Points = gobjects(TrialCount, 1);
	for TrialIndex = 1:TrialCount
		Points(TrialIndex) = plot(Ax, AtOneSecond(1, TrialIndex), AtOneSecond(2, TrialIndex), 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', TrialColors(TrialIndex, :), 'MarkerEdgeColor', 'w');
		Points(TrialIndex).UserData = struct('Trial', TrialIndex, 'Row', RowIndex);
	end
	plot(Ax, MeanVector(1), MeanVector(2), '+', 'Color', MeanColor, 'MarkerSize', 7, 'LineWidth', 1.2);
	text(Ax, MeanVector(1)/2, MeanVector(2)/2, '‖μ‖', 'Color', MeanColor, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Interpreter', 'none');
	text(Ax, MeanVector(1) + Sigma/2, MeanVector(2), 'σ', 'Color', SpreadColor, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Interpreter', 'none');
	StateUpperBounds = MeanVector + 1.15*Sigma;
	plot(Ax, [0 StateUpperBounds(1)], [0 StateUpperBounds(2)], 'LineStyle', 'none', 'HandleVisibility', 'off');
	axis(Ax, 'image');
	Ax.XTick = [];
	Ax.YTick = [];
	if RowIndex == 1
		title(Ax, {'Population state', char(RowNames(RowIndex))}, 'FontWeight', 'normal');
	else
		title(Ax, RowNames(RowIndex), 'FontWeight', 'normal');
		xlabel(Ax, 'Cell 1');
		ylabel(Ax, 'Cell 2');
	end
	StateAxes(RowIndex) = Ax;
	StatePoints{RowIndex} = Points;

	Ax = nexttile(Layout, FirstTile + 2, [2 1]);
	hold(Ax, 'on');
	plot(Ax, [0 Sigma], [2 2], 'Color', SpreadColor, 'LineWidth', 3);
	plot(Ax, [0 0 NaN Sigma Sigma], [1.92 2.08 NaN 1.92 2.08], 'Color', SpreadColor, 'LineWidth', 0.8);
	plot(Ax, [0 MeanNorm], [1 1], 'Color', MeanColor, 'LineWidth', 3);
	plot(Ax, [0 0 NaN MeanNorm MeanNorm], [0.92 1.08 NaN 0.92 1.08], 'Color', MeanColor, 'LineWidth', 0.8);
	text(Ax, 0, 2, 'σ_{trials}  ', 'Color', SpreadColor, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Interpreter', 'tex');
	text(Ax, 0, 1, '‖μ‖  ', 'Color', MeanColor, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
	text(Ax, MeanNorm/2, 0.2, sprintf('Divergence = %.2f', Divergence), 'Color', AxisColor, 'HorizontalAlignment', 'center', 'FontSize', 10);
	plot(Ax, [0 MeanNorm], [0 2.4], 'LineStyle', 'none', 'HandleVisibility', 'off');
	axis(Ax, 'off');
	if RowIndex == 1
		title(Ax, 'Relative spread', 'FontWeight', 'normal');
	end
	RatioAxes(RowIndex) = Ax;
	Rows{RowIndex} = struct('Signals', Signals, 'AtOneSecond', AtOneSecond, 'Mean', MeanVector, 'Sigma', Sigma, 'CircleRadius', CircleRadius, 'AngleGaps', AngleGaps, 'MeanNorm', MeanNorm, 'D', Divergence, 'MinimumSeparation', MinimumSeparation);
end

AllAxes = [TraceAxes(:); StateAxes; RatioAxes];
set(AllAxes, 'FontName', 'Helvetica', 'FontSize', 8, 'XColor', AxisColor, 'YColor', AxisColor, 'LineWidth', 0.7, 'Box', 'off', 'Color', 'none');
MATLAB.Graphics.UnifyAxesLims(TraceAxes(:), @xlim, @ylim);
MATLAB.Graphics.UnifyAxesLims(StateAxes, @xlim, @ylim);
MATLAB.Graphics.UnifyAxesLims(RatioAxes, @xlim, @ylim);
Legend = legend(TraceAxes(2, 2), [MeanLines(2, 2); TrialLines{2, 2}], ["Mean", "Trial"], 'Location', 'southoutside', 'Orientation', 'horizontal', 'NumColumns', 2, 'Box', 'off', 'FontSize', 7);
Legend.ItemTokenSize = [10 8];
drawnow;
SvgPath = TransferLearning.StandardFigureSvgPath('散度_概念示意图.svg');
exportgraphics(Figure, SvgPath, 'ContentType', 'vector', 'BackgroundColor', 'white');
DivergenceConceptStats = struct('Time', Time, 'TrialColors', TrialColors, 'Rows', {Rows}, 'TraceAxes', TraceAxes, 'StateAxes', StateAxes, 'TrialLines', {TrialLines}, 'StatePoints', {StatePoints}, 'Figure', Figure, 'Legend', Legend, 'SvgPath', SvgPath);
assignin('base', 'DivergenceConceptStats', DivergenceConceptStats);
fprintf('已导出六试次散度概念图：%s\n', SvgPath);
fprintf('低/高 D = %.6f / %.6f；cue前trial完全重合，cue后最小间距 = %.6g / %.6g。\n', Rows{1}.D, Rows{2}.D, min(Rows{1}.MinimumSeparation), min(Rows{2}.MinimumSeparation));