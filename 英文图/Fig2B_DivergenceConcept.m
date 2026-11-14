% 英文图2B：六次合成试次的散度概念图，计算与作图分开，曲线及状态点来自同一组数据。
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
Rows = BuildDivergenceData(Time, MeanShape, MeanVector, ResidualSets);
TrialPlotIndices = unique([1:4:numel(Time), SampleIndex, numel(Time)]);
%% 

Figure = figure('Color', 'w', 'Units', 'centimeters');
Figure.Position(3:4)=[6,8];
Layout = tiledlayout(Figure, 4, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
title(Layout, '$$Divergence =\frac{\sigma_{trials}}{\|\mu\|}$$',Interpreter='latex');
TraceAxes = gobjects(2, 2);
StateAxes = gobjects(2, 1);
TrialLines = cell(2, 2);
MeanLines = gobjects(2, 2);
StatePoints = cell(2, 1);
CircleAngle = linspace(0, 2*pi, 240);
for RowIndex = 1:2
	Signals = Rows{RowIndex}.Signals;
	MeanSignals = Rows{RowIndex}.MeanSignals;
	AtOneSecond = Rows{RowIndex}.AtOneSecond;
	Sigma = Rows{RowIndex}.Sigma;
	CircleRadius = Rows{RowIndex}.CircleRadius;
	FirstTile = (RowIndex - 1) * 4 + 1;
	for CellIndex = 1:2
		Responses = reshape(Signals(:, CellIndex, :), numel(Time), TrialCount);
		Ax = nexttile(Layout, FirstTile + (CellIndex - 1)*2);
		hold(Ax, 'on');
		xline(Ax, 1, '--', 'Color', DashedColor, 'LineWidth', 0.6, 'HandleVisibility', 'off');
		PatchX = [repmat(Time(TrialPlotIndices), 1, TrialCount); nan(1, TrialCount)];
		PatchY = [Responses(TrialPlotIndices, :); nan(1, TrialCount)];
		PatchColors = repmat(reshape(TrialColors, 1, TrialCount, 3), numel(TrialPlotIndices) + 1, 1, 1);
		TrialLines{RowIndex, CellIndex} = patch(Ax, PatchX, PatchY, PatchColors, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 0.5, 'DisplayName', 'Trial');
		TrialLines{RowIndex, CellIndex}.UserData = struct('Trial', 1:TrialCount, 'Cell', CellIndex, 'Row', RowIndex, 'TrialColors', TrialColors);
		MeanLines(RowIndex, CellIndex) = plot(Ax, Time, MeanSignals(:, CellIndex), 'Color', MeanColor, 'LineWidth', 1.5, 'DisplayName', 'Mean');
		axis(Ax, 'padded');
		ylabel(Ax, "Cell " + CellIndex);
		if CellIndex == 1 && RowIndex == 1
			title(Ax, 'Repeated trials');
		end
		Ax.YTick = [];
		if RowIndex ~= 2 || CellIndex ~= 2
			Ax.XAxis.Visible=false;
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
		title(Ax, {char(RowNames(RowIndex))}, 'FontWeight', 'normal');
	else
		title(Ax, RowNames(RowIndex), 'FontWeight', 'normal');
		xlabel(Ax, 'Cell 1');
	end
	ylabel(Ax, 'Cell 2');
	StateAxes(RowIndex) = Ax;
	StatePoints{RowIndex} = Points;
end
MATLAB.Graphics.UnifyAxesLims(TraceAxes(:), @xlim, @ylim);
MATLAB.Graphics.UnifyAxesLims(StateAxes, @xlim, @ylim);
Legend = legend(TraceAxes(2, 2), [MeanLines(2, 2); TrialLines{2, 2}], ["Mean", "Trial"], 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
LineWidthObjects = findall(Figure, '-property', 'LineWidth');
OriginalLineWidths = arrayfun(@(LineWidthObject)LineWidthObject.LineWidth, LineWidthObjects);
for LineWidthIndex = 1:numel(LineWidthObjects)
	setappdata(LineWidthObjects(LineWidthIndex), 'TransferLearningPreserveLineWidth', true);
end
TransferLearning.ExportStandardFigure(Figure,1,'English_Fig2B_DivergenceConcept.svg');
assert(isequal(arrayfun(@(LineWidthObject)LineWidthObject.LineWidth, LineWidthObjects), OriginalLineWidths), '统一导出改变了已标记保留的线宽。');
function Rows = BuildDivergenceData(Time, MeanShape, MeanVector, ResidualSets)
TrialCount = size(ResidualSets{1}, 2);
Baseline = Time <= 1e-10;
PostCue = Time > 1e-10;
[~, SampleIndex] = min(abs(Time - 1));
Rows = cell(numel(ResidualSets), 1);
for RowIndex = 1:numel(ResidualSets)
	Residuals = ResidualSets{RowIndex};
	Signals = reshape(MeanShape * MeanVector', [], 2, 1) + reshape(MeanShape, [], 1, 1) .* reshape(Residuals, 1, 2, TrialCount);
	MinimumTraceDistance = zeros(1, 2);
	PeakTimes = zeros(2, TrialCount);
	for CellIndex = 1:2
		Responses = reshape(Signals(:, CellIndex, :), numel(Time), TrialCount);
		assert(max(abs(Responses ./ (MeanVector(CellIndex) + Residuals(CellIndex, :)) - MeanShape), [], 'all') < 1e-12, 'trial应仅有幅度差异，不应叠加形状变化。');
		TraceDifferences = reshape(Responses(PostCue, :), [], TrialCount, 1) - reshape(Responses(PostCue, :), [], 1, TrialCount);
		TraceDistances = squeeze(sqrt(mean(TraceDifferences.^2, 1)));
		TraceDistances(1:TrialCount+1:end) = Inf;
		MinimumTraceDistance(CellIndex) = min(TraceDistances, [], 'all');
		assert(MinimumTraceDistance(CellIndex) > 0.01, '合成trial存在整段重复的曲线。');
		[~, PeakIndices] = max(Responses, [], 1);
		PeakTimes(CellIndex, :) = reshape(Time(PeakIndices), 1, TrialCount);
		assert(all(abs(PeakTimes(CellIndex, :) - 1) < 1e-10), '简单平滑trial应在1秒达峰。');
	end
	MeanSignals = mean(Signals, 3);
	assert(max(abs(MeanSignals - MeanShape * MeanVector'), [], 'all') < 1e-12, '合成曲线的均值不一致。');
	assert(all(Signals(Baseline, :, :) == 0, 'all'), 'cue前的trial应完全重合在零基线。');
	AtOneSecond = reshape(Signals(SampleIndex, :, :), 2, TrialCount);
	assert(max(abs(AtOneSecond - (MeanVector + Residuals)), [], 'all') < 1e-12, '形状变化不应改变1秒取值。');
	Sigma = sqrt(sum(var(AtOneSecond, 0, 2)));
	MeanNorm = norm(mean(AtOneSecond, 2));
	CenteredStates = AtOneSecond - mean(AtOneSecond, 2);
	TrialRadii = vecnorm(CenteredStates, 2, 1);
	CircleRadius = mean(TrialRadii);
	StateAngles = sort(mod(atan2(CenteredStates(2, :), CenteredStates(1, :)), 2*pi));
	AngleGaps = diff([StateAngles StateAngles(1) + 2*pi]);
	assert(max(abs(TrialRadii - CircleRadius)) < 1e-12 && max(abs(AngleGaps - 2*pi/TrialCount)) < 1e-12, '六个trial应等角度分布在同一圆周。');
	assert(abs(Sigma - CircleRadius*sqrt(TrialCount/(TrialCount-1))) < 1e-12, '圆半径与样本标准差的关系不正确。');
	Rows{RowIndex} = struct('Signals', Signals, 'MeanSignals', MeanSignals, 'AtOneSecond', AtOneSecond, 'Mean', MeanVector, 'Sigma', Sigma, 'CircleRadius', CircleRadius, 'AngleGaps', AngleGaps, 'MeanNorm', MeanNorm, 'D', Sigma/MeanNorm, 'MinimumTraceDistance', MinimumTraceDistance, 'PeakTimes', PeakTimes);
end
end