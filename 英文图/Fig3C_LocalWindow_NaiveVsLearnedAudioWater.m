% 英文图3C：二维分组表比较3B两种训练的±1 s时点差，只展示Learned声水与12 h首Transfer block两个测试集。
% 横向分组为测试集，颜色为Naive声与Learned声水训练；只比较同一测试集内的两种训练，不画跨测试集比较。
% 直接将BarScatterCompare返回的PText改成双侧精确配对符号秩检验的两项Holm结果，默认ANOVA值另存。
% 短分组名、二维表、分组柱样式、p线调距及导出顺序沿用Fig5F_THInhibitVsCtrl_DivergenceByLayer。

ThisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	PrjFile = fullfile(ThisDir, '..', 'Transferlearning.prj');
	if exist(PrjFile, 'file')
		matlab.project.loadProject(PrjFile);
	end
end
CacheDir = fileparts(TransferLearning.CachePath('Fig3C_TrainingComparison.mat'));
SourceCSV = fullfile(CacheDir, 'Fig3B_LocalWindow_2x4_Post1000ms_PerMouse.csv');
if ~isfile(SourceCSV)
	TransferLearning.ComputeLocalWindowGapDecoderMatrix();
end
Source = readtable(SourceCSV, 'TextType', 'string');
SourceCache = TransferLearning.CachePath('CueModel_Fig3B_LocalWindow250ms_2x4_Post1000ms_FoldStandardized_Results.mat');
DecoderCache = load(SourceCache, 'Tasks', 'Results', 'Time');
Time = DecoderCache.Time(:)';
TestKeys = ["LearnedAudioWater", "Transfer12hLightWater"];
TrainKeys = ["NaiveAudioOnly", "LearnedAudioWater"];
TestLabels = ["Learned🔊💧", "12h💡💧"];
TrainLabels = ["Naive🔊", "Learned🔊💧"];
DataCell = cell(2, 2);
MouseNames = cell(2, 1);
PairedStats = table(TestKeys', zeros(2, 1), nan(2, 1), nan(2, 1), nan(2, 1), nan(2, 1), 'VariableNames', {'Test', 'N', 'MeanNaiveTrain', 'MeanLearnedTrain', 'MeanLearnedMinusNaive', 'SignedRankP'});
Selected = Source(ismember(Source.Test, TestKeys), :);
Selected.WindowMeanDelta = Selected.Delta;
Selected.PMinus1 = nan(height(Selected), 1);
Selected.PPlus1 = nan(height(Selected), 1);
for SampleIndex = 1:height(Selected)
	TrainingIndex = find(TrainKeys == Selected.Training(SampleIndex));
	PairIndex = find(cellfun(@(Task) Task.DS == Selected.Dataset(SampleIndex) && string(Task.Mouse) == Selected.Mouse(SampleIndex), DecoderCache.Tasks(1, :)));
	assert(isscalar(TrainingIndex) && isscalar(PairIndex));
	Result = DecoderCache.Results{TrainingIndex, PairIndex};
	if TrainingIndex == 2 && Selected.Test(SampleIndex) == "LearnedAudioWater"
		assert(Selected.IsOOF(SampleIndex));
		Curve = Result.pPostS1T(:)';
	else
		TestIndex = find(TestKeys == Selected.Test(SampleIndex));
		Curve = Result.Tests(TestIndex).pPostByT(:)';
		if TestIndex == 2
			assert(Result.DS == 1 && Result.Tests(2).nTe == 30);
		end
	end
	PointValues = interp1(Time, Curve, [-1, 1], 'linear');
	assert(all(isfinite(PointValues)));
	Selected.PMinus1(SampleIndex) = PointValues(1);
	Selected.PPlus1(SampleIndex) = PointValues(2);
	Selected.Delta(SampleIndex) = PointValues(2) - PointValues(1);
end
Selected.Metric = repmat("PPostAtPlus1sMinusPPostAtMinus1s", height(Selected), 1);
for TestIndex = 1:2
	NaiveRows = sortrows(Selected(Selected.Test == TestKeys(TestIndex) & Selected.Training == TrainKeys(1), :), {'Dataset', 'Mouse'});
	LearnedRows = sortrows(Selected(Selected.Test == TestKeys(TestIndex) & Selected.Training == TrainKeys(2), :), {'Dataset', 'Mouse'});
	assert(isequal(NaiveRows.Mouse, LearnedRows.Mouse) && isequal(NaiveRows.Dataset, LearnedRows.Dataset), 'Fig3C:UnpairedMice', '两种训练必须使用相同且顺序一致的鼠。');
	assert(height(NaiveRows) == numel(unique(NaiveRows.Mouse)) && all(isfinite([NaiveRows.Delta; LearnedRows.Delta])));
	assert(isequal(NaiveRows.NCells, LearnedRows.NCells), 'Fig3C:DifferentCells', '两种训练必须使用相同的共同细胞。');
	DataCell{TestIndex, 1} = NaiveRows.Delta;
	DataCell{TestIndex, 2} = LearnedRows.Delta;
	MouseNames{TestIndex} = NaiveRows.Mouse;
	PairedStats.N(TestIndex) = height(NaiveRows);
	PairedStats.MeanNaiveTrain(TestIndex) = mean(NaiveRows.Delta);
	PairedStats.MeanLearnedTrain(TestIndex) = mean(LearnedRows.Delta);
	PairedStats.MeanLearnedMinusNaive(TestIndex) = mean(LearnedRows.Delta - NaiveRows.Delta);
	PairedStats.SignedRankP(TestIndex) = signrank(LearnedRows.Delta, NaiveRows.Delta, 'method', 'exact');
end
assert(isequal(PairedStats.N, [15; 9]));
[SortedP, POrder] = sort(PairedStats.SignedRankP);
PairedStats.SignedRankPHolm = nan(2, 1);
PairedStats.SignedRankPHolm(POrder) = min(cummax([2; 1] .* SortedP), 1);
PairedStats.Metric = repmat("PPostAtPlus1sMinusPPostAtMinus1s", 2, 1);
DataTable = cell2table(DataCell, 'VariableNames', cellstr(TrainLabels), 'RowNames', cellstr(TestLabels));
DataTable.Properties.DimensionNames = {'Test', 'Training'};
GroupPair = table([TestLabels(:), TestLabels(:)], repmat(TrainLabels, 2, 1), 'VariableNames', {'Test', 'Training'});
CompareGroup = table(GroupPair);
Colors = [TransferLearning.ColorNaive; TransferLearning.ColorLearned] / 255;
ColorTable = array2table(Colors, 'VariableNames', {'R', 'G', 'B'}, 'RowNames', cellstr(TrainLabels));
%% 
Fig = figure('Color', 'w', 'Name', '英文图3C：两种训练在Learned及12 h测试中的解码差值');
Fig.Units = 'centimeters';
Fig.Position(3:4) = [6, 8];
Ax = gca;
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataTable, CompareGroup, ColorTable, Ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
StyleBars(Ax, Bars, ErrorBars, Colors);
ylabel(Ax, 'ΔP(cued), ±1s');
xlabel(Ax, 'Tested with');
box(Ax, 'off');
grid(Ax, 'off');
LegendHandle = Optional.Legend;
LegendHandle.String = cellstr(TrainLabels);
LegendHandle.Location = 'northoutside';
LegendHandle.Box = 'off';
title(LegendHandle,'Trained from');
Comparisons = Optional.MultiCompare;
ComparisonGroups = Comparisons;
if ismember('GroupPair', Comparisons.Properties.VariableNames) && istable(Comparisons.GroupPair)
	ComparisonGroups = Comparisons.GroupPair;
end
ComparisonTests = string(ComparisonGroups.Test);
assert(istable(Comparisons) && height(Comparisons) == 2 && all(ComparisonTests(:, 1) == ComparisonTests(:, 2)), 'Fig3C:UnexpectedComparisons', '只允许两个同测试集内的训练比较。');
PairedStats.AnovaP = nan(2, 1);
Comparisons.DisplayedPValue = nan(height(Comparisons), 1);
Comparisons.DisplayedMethod = repmat("PairedSignedRankExactTwoSidedHolm2", height(Comparisons), 1);
for ComparisonIndex = 1:height(Comparisons)
	TestIndex = find(TestLabels == ComparisonTests(ComparisonIndex, 1));
	assert(isscalar(TestIndex));
	PairedStats.AnovaP(TestIndex) = Comparisons.PValue(ComparisonIndex);
	PText = Comparisons.PText(ComparisonIndex);
	PLine = Comparisons.PLine(ComparisonIndex);
	DisplayedP = PairedStats.SignedRankPHolm(TestIndex);
	PText.String = TransferLearning.Style.iFormatPText(DisplayedP);
	PText.UserData = struct('Method', "PairedSignedRankExactTwoSidedHolm2", 'PValue', DisplayedP, 'PairedRawP', PairedStats.SignedRankP(TestIndex), 'AnovaP', PairedStats.AnovaP(TestIndex), 'Metric', "PPostAtPlus1sMinusPPostAtMinus1s");
	Comparisons.DisplayedPValue(ComparisonIndex) = DisplayedP;
	PText.Tag = 'PText';
	PLine.Tag = 'PLine';
end
Optional.MultiCompare = Comparisons;
RetunePValueLines(Optional);
TransferLearning.ExportStandardFigure(Fig,2,'English_Fig3C_LocalWindow_NaiveVsLearnedAudioWater.svg');

function StyleBars(Ax, Bars, ErrorBars, GroupColors)
for BarIndex = 1:numel(Bars)
	Bars(BarIndex).LineStyle = 'none';
	Bars(BarIndex).FaceColor = GroupColors(BarIndex, :);
	if isprop(Bars(BarIndex), 'BaseLine') && isgraphics(Bars(BarIndex).BaseLine)
		Bars(BarIndex).BaseLine.Visible = 'off';
	end
end
for ErrorIndex = 1:height(ErrorBars)
	ErrorBar = ErrorBars.Object(ErrorIndex);
	if ~isgraphics(ErrorBar)
		continue;
	end
	X = double(ErrorBar.XData(1));
	BestDistance = inf;
	BestColor = GroupColors(1, :);
	for BarIndex = 1:numel(Bars)
		Endpoints = double(Bars(BarIndex).XEndPoints(:));
		Distance = min(abs(Endpoints - X));
		if Distance < BestDistance
			BestDistance = Distance;
			BestColor = Bars(BarIndex).FaceColor;
		end
	end
	ErrorBar.Color = BestColor;
end
if isprop(Ax, 'Toolbar') && ~isempty(Ax.Toolbar)
	Ax.Toolbar.Visible = 'off';
end
end

function RetunePValueLines(Optional)
if ~isfield(Optional, 'MultiCompare') || ~istable(Optional.MultiCompare)
	return;
end
if ~all(ismember({'PLine', 'PText'}, Optional.MultiCompare.Properties.VariableNames))
	return;
end
MATLAB.Graphics.PLineRetune(Optional.MultiCompare.PLine, Optional.MultiCompare.PText);
for PLine = Optional.MultiCompare.PLine(:)'
	if isgraphics(PLine)
		PLine.LineWidth = 1;
		PLine.Tag = 'PLine';
		setappdata(PLine, 'TransferLearningPreserveLineWidth', true);
	end
end
for PText = Optional.MultiCompare.PText(:)'
	if isgraphics(PText)
		PText.Tag = 'PText';
	end
end
end
