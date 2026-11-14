function [Figure, Stats] = PlotRnnLearningCurve(PerformanceA, PerformanceB, SigmoidStats, GroupNames, Colors)
% 复用中文RNN图的跨鼠均值/SEM、预计算sigmoid拟合及Two-way ANOVA组效应。
arguments
	PerformanceA double
	PerformanceB double
	SigmoidStats struct
	GroupNames (1,2) string
	Colors (2,3) double
end
PerformanceSets = {PerformanceA, PerformanceB};
BlockCount = max(size(PerformanceA, 2), size(PerformanceB, 2));
Mean = nan(BlockCount, 2);
Sem = nan(BlockCount, 2);
AnovaParts = cell(2, 1);
for GroupIndex = 1:2
	Performance = PerformanceSets{GroupIndex};
	for BlockIndex = 1:size(Performance, 2)
		Values = Performance(:, BlockIndex);
		Values = Values(isfinite(Values));
		Mean(BlockIndex, GroupIndex) = mean(Values);
		if numel(Values) < 2
			Sem(BlockIndex, GroupIndex) = 0;
		else
			Sem(BlockIndex, GroupIndex) = std(Values) / sqrt(numel(Values));
		end
	end
	[MouseIndices, BlockIndices] = ndgrid(1:size(Performance, 1), 1:size(Performance, 2));
	AnovaParts{GroupIndex} = table(Performance(:), BlockIndices(:), repmat(GroupNames(GroupIndex), numel(Performance), 1), compose(GroupNames(GroupIndex) + "%03d", MouseIndices(:)), VariableNames=["Performance", "Block", "Group", "Mouse"]);
end
AnovaData = vertcat(AnovaParts{:});
PAll = TransferLearning.Style.TwoWayAnovaGroupPValue(AnovaData, 'Performance', 'Block', 'Group', 'Mouse');
PFirstSeven = TransferLearning.Style.TwoWayAnovaGroupPValue(AnovaData(AnovaData.Block <= 7, :), 'Performance', 'Block', 'Group', 'Mouse');
FitSets = {SigmoidStats.FitA, SigmoidStats.FitB};
FitX = linspace(0, BlockCount+1, 200)';
Figure = figure(Color='w', Units='centimeters');
Figure.Position(3:4) = [12 8];
Ax = gca;
hold(Ax, 'on');
LegendLines = gobjects(2, 1);
for GroupIndex = 1:2
	Fit = FitSets{GroupIndex};
	FitY = Fit.Lower + (Fit.Upper - Fit.Lower) ./ (1 + exp(-Fit.Slope .* (FitX - Fit.Midpoint)));
	Valid = isfinite(Mean(:, GroupIndex));
	errorbar(Ax, find(Valid), Mean(Valid, GroupIndex), Sem(Valid, GroupIndex), 'o', Color=Colors(GroupIndex, :), MarkerFaceColor='w', MarkerEdgeColor=Colors(GroupIndex, :), MarkerSize=4.5, LineStyle='none', CapSize=4);
	LegendLines(GroupIndex) = plot(Ax, FitX, FitY, Color=Colors(GroupIndex, :), LineWidth=1.2);
end
FirstSevenMax = max(Mean(1:min(7, BlockCount), :), [], 'all');
AutoYRange = diff(Ax.YLim);
PLineY = FirstSevenMax + 0.08*AutoYRange;
PTextY = PLineY + 0.1*AutoYRange;
plot(Ax, [1 7], [PLineY PLineY], Color='k', Tag='PLine_1', HandleVisibility='off');
text(Ax, 4, PTextY, TransferLearning.Style.iFormatPText(PFirstSeven), HorizontalAlignment='center', VerticalAlignment='top', Tag='PText_1', AffectAutoLimits=true);
xlabel(Ax, 'Block');
ylabel(Ax, 'Hit rate');
title(Ax, 'Cue B');
box(Ax, 'off');
legend(Ax, LegendLines, GroupNames, Location='southeast', Box='off');
Stats = struct('Mean', Mean, 'SEM', Sem, 'Sigmoid', SigmoidStats, 'GroupPFirstSeven', PFirstSeven, 'GroupPAll', PAll, 'PerformanceA', PerformanceA, 'PerformanceB', PerformanceB);
fprintf('模型曲线%s/%s：前七block组效应p=%.9g，完整曲线p=%.9g。\n', GroupNames(1), GroupNames(2), PFirstSeven, PAll);
end