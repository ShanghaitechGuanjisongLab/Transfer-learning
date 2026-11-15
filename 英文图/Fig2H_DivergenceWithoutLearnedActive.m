% 英文图2H：光水Transfer剔除声水Learned活跃细胞前后的逐鼠相对散度。
% 参照Hit/Miss Reactivation：两tile、逐鼠黑线、彩色散点和PLine配对检验。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
Result = TransferLearning.ComputeDivergenceWithoutLearnedActive();
Layers = ["MOp2/3", "MOp5"];
GroupLabels = ["Within", "Without"];
Colors = [TransferLearning.ColorLearned; TransferLearning.Color12h] / 255;
DataSets = cell(2, 2);
MouseSets = cell(2, 1);
for LayerIndex = 1:2
	R = Result.Rows(Result.Rows.Layer == Layers(LayerIndex), :);
	DataSets(LayerIndex, :) = {R.DivFull, R.DivRemoved};
	MouseSets{LayerIndex} = R.Mouse;
end
[HasStats, StatIndices] = ismember(Layers, Result.Stats.Layer);
assert(all(HasStats), '汇总缺少绘图所需层。');
PValues = Result.Stats.PValueSignrank(StatIndices);
assert(isequaln(PValues(:), arrayfun(@(Index)signrank(DataSets{Index,1}, DataSets{Index,2}), 1:2)'), '图中配对检验与汇总不一致。');
%% 

Figure = figure(Color='w', Name='English Fig2H divergence after active-cell removal', Units='centimeters');
Figure.Position(3:4) = [6 8];
Layout = tiledlayout(Figure, 1, 2, TileSpacing='tight', Padding='tight');
Axes = gobjects(1, 2);
for LayerIndex = 1:2
	Ax = nexttile(Layout, LayerIndex);
	hold(Ax, 'on');
	Full = DataSets{LayerIndex, 1};
	Removed = DataSets{LayerIndex, 2};
	Y = [Full, Removed];
	PairLines = plot(Ax, Y', '-', LineWidth=1, Color=[0 0 0], HandleVisibility='off');
	for PairLine = PairLines(:)'
		setappdata(PairLine, 'TransferLearningPreserveLineWidth', true);
	end
	scatter(Ax, ones(size(Full)), Full, 15, Colors(1,:), 'filled', LineWidth=0.2, MarkerEdgeColor=Colors(1,:), HandleVisibility='off');
	scatter(Ax, 2*ones(size(Removed)), Removed, 15, Colors(2,:), 'filled', LineWidth=0.2, MarkerEdgeColor=Colors(2,:), HandleVisibility='off');
	Ax.XTick = [1 2];
	Ax.XTickLabel = GroupLabels;
	title(Ax, Layers(LayerIndex), FontWeight='normal');
	if LayerIndex == 1
		ylabel(Ax, 'Transfer 💡💧 divergence');
	else
		Ax.YAxis.Visible=false;
	end
	box(Ax, 'off');
	S = scatter(Ax, [ones(size(Full)); 2*ones(size(Removed))], [Full; Removed], 1, 'k', 'filled', Visible='off', HandleVisibility='off');
	Descriptors = table(S, 0, 0, TransferLearning.Style.iFormatPText(PValues(LayerIndex)), 0, VariableNames={'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	[PLines, PTexts] = MATLAB.Graphics.PLine(Descriptors);
	for PLine = PLines(:)'
		PLine.LineWidth = 1;
		PLine.Tag = 'PLine';
	end
	for PText = PTexts(:)'
		PText.Tag = 'PText';
	end
	delete(S);
	Axes(LayerIndex) = Ax;
	fprintf('%s：n=%d，全部=%.6f±%.6f，剔除=%.6f±%.6f，配对signrank p=%.9g。\n', Layers(LayerIndex), numel(Full), mean(Full), std(Full)/sqrt(numel(Full)), mean(Removed), std(Removed)/sqrt(numel(Removed)), PValues(LayerIndex));
end
xlabel(Layout,'🔊💧 active cells');
TransferLearning.ApplyStandardExportStyle(Figure, 2);
MATLAB.Graphics.UnifyAxesLims(Axes, @xlim, @ylim);
for LayerIndex = 1:2
	MATLAB.Graphics.PLineRetune(findall(Axes(LayerIndex), 'Tag', 'PLine'), findall(Axes(LayerIndex), 'Tag', 'PText'));
end
SvgPath = TransferLearning.StandardFigureSvgPath('English_Fig2H_DivergenceWithoutLearnedActive.svg');
print(Figure, SvgPath, '-dsvg');