function Results = AnalyzeFullLightWaterDecoderTransfer()
% 冻结当前3B两种解码器，仅将12 h光水测试从首Transfer块扩展至首次Final，保留原图和缓存。
SourcePath = TransferLearning.CachePath('CueModel_Fig3B_LocalWindow250ms_2x4_Post1000ms_FoldStandardized_Results.mat');
Source = load(SourcePath, 'Tasks', 'Results', 'Time');
CacheDir = fileparts(SourcePath);
OriginalPerMouse = readtable(fullfile(CacheDir, 'Fig3B_LocalWindow_2x4_Post1000ms_PerMouse.csv'), 'TextType', 'string');
OriginalStats = CompareTrainingWithinTests(OriginalPerMouse, OriginalPerMouse(OriginalPerMouse.Test == "Transfer12hLightWater", :), "FirstTransferBlock");
DS = TransferLearning.AudioLightBaseline();
Metadata = DS.TableQuery(["Mouse", "DateTime", "BlockUID", "TrialUID", "Stimulus", "Phase", "Behavior"], Stimulus="LightWater");
Metadata.Mouse = string(Metadata.Mouse);
Metadata.DateTime = datetime(Metadata.DateTime);
Metadata.DateTime.TimeZone = '';
Metadata.Phase = string(Metadata.Phase);
Sessions = TransferLearning.DelayComparison.LightSessionTable(DS, "LightWater", "Transfer", "Final");
Time = Source.Time(:)';
Xs = seconds(TransferLearning.Xs);
TimeIndices = find(Xs >= -1.5 & Xs <= 1.5);
assert(isequal(Time, Xs(TimeIndices)'));
Radius = round(0.25 / median(diff(Xs)));
TrainingKeys = ["NaiveAudioOnly", "LearnedAudioWater"];
Coverage = table();
PerMouse = table();
PerBlock = table();
MissingTrials = table();
Readouts = cell(0, 1);
for PairIndex = 1:size(Source.Tasks, 2)
	FirstTask = Source.Tasks{1, PairIndex};
	if FirstTask.DS ~= 1
		continue;
	end
	Mouse = string(FirstTask.Mouse);
	MouseSessions = Sessions(Sessions.Mouse == Mouse, :);
	assert(~isempty(MouseSessions) && MouseSessions.Phase(end) == "Final", 'FullLightDecoder:MissingFinal', '%s没有首次Final终点，不能按完整学会前过程分析。', Mouse);
	MouseMetadata = Metadata(Metadata.Mouse == Mouse & ismember(Metadata.DateTime, MouseSessions.DateTime), :);
	assert(all(MouseMetadata.DateTime >= MouseSessions.DateTime(1) & MouseMetadata.DateTime <= MouseSessions.DateTime(end)));
	Raw = TransferLearning.QueryZScoreNts(DS, Mouse, "LightWater");
	Raw = Raw(ismember(uint64(Raw.TrialUID), uint64(MouseMetadata.TrialUID)) & ismember(uint64(Raw.CellUID), uint64(FirstTask.CellUIDs)), :);
	TrialUIDs = unique(uint64(Raw.TrialUID));
	assert(all(ismember(TrialUIDs, uint64(MouseMetadata.TrialUID))));
	UnavailableMetadata = MouseMetadata(~ismember(uint64(MouseMetadata.TrialUID), TrialUIDs), :);
	MissingTrials = [MissingTrials; UnavailableMetadata(:, {'Mouse', 'DateTime', 'BlockUID', 'TrialUID', 'Phase'})];
	[FoundTrials, Locations] = ismember(TrialUIDs, uint64(MouseMetadata.TrialUID));
	assert(all(FoundTrials));
	TrialMetadata = MouseMetadata(Locations, :);
	MissingCellRows = numel(TrialUIDs) * FirstTask.NCells - height(unique(Raw(:, {'TrialUID', 'CellUID'})));
	X = TransferLearning.BuildTrialMatrix(Raw, FirstTask.CellUIDs);
	assert(size(X, 1) == numel(TrialUIDs) && size(X, 2) == FirstTask.NCells);
	Smoothed = LocalMean(X(:, :, TimeIndices), Radius);
	FirstRows = ismember(TrialUIDs, uint64(FirstTask.Tests(2).TrialUIDs));
	assert(nnz(FirstRows) == size(FirstTask.Tests(2).XTeT, 1));
	assert(max(abs(Smoothed(FirstRows, :, :) - FirstTask.Tests(2).XTeT), [], 'all') < 1e-8, 'FullLightDecoder:FirstFeaturesChanged', '%s的首Transfer块特征没有复现。', Mouse);
	Coverage = [Coverage; table(Mouse, numel(unique(TrialMetadata.BlockUID(FirstRows))), nnz(FirstRows), numel(unique(TrialMetadata.BlockUID)), numel(TrialUIDs), MouseSessions.DateTime(1), MouseSessions.DateTime(end), MouseSessions.Phase(end), MouseSessions.Performance(end), FirstTask.NCells, MissingCellRows, numel(unique(MouseMetadata.BlockUID)), height(MouseMetadata), numel(unique(UnavailableMetadata.BlockUID)), height(UnavailableMetadata), 'VariableNames', {'Mouse', 'FirstBlocks', 'FirstTrials', 'FullBlocks', 'FullTrials', 'StartDate', 'EndDate', 'EndPhase', 'EndHitRate', 'NCells', 'MissingTrialCellRows', 'MetadataFullBlocks', 'MetadataFullTrials', 'UnavailableBlocks', 'UnavailableTrials'})];
	for TrainingIndex = 1:2
		Task = Source.Tasks{TrainingIndex, PairIndex};
		Model = Source.Results{TrainingIndex, PairIndex};
		assert(isequal(Task.CellUIDs, FirstTask.CellUIDs) && string(Task.Mouse) == Mouse);
		assert(isempty(intersect(uint64(Task.TrainTrialUIDs), TrialUIDs)), 'FullLightDecoder:TrialLeakage', '全程光水测试与声训练trial重叠。');
		Probabilities = ApplyFixedDecoder(Smoothed, Task, Model);
		assert(max(abs(mean(Probabilities(FirstRows, :), 1) - Model.Tests(2).pPostByT)) < 1e-8, 'FullLightDecoder:FirstPredictionChanged', '%s原解码器未能复现首块读出。', Mouse);
		PreMask = Time >= -1 & Time < 0;
		PostMask = Time >= 0 & Time <= 1;
		for Window = ["FirstTransferBlock", "ThroughFirstFinal"]
			if Window == "FirstTransferBlock"
				Rows = FirstRows;
			else
				Rows = true(numel(TrialUIDs), 1);
			end
			Curve = mean(Probabilities(Rows, :), 1);
			Delta = mean(Curve(PostMask)) - mean(Curve(PreMask));
			PerMouse = [PerMouse; table(Window, Mouse, TrainingKeys(TrainingIndex), nnz(Rows), numel(unique(TrialMetadata.BlockUID(Rows))), Task.NCells, Delta, 'VariableNames', {'Window', 'Mouse', 'Training', 'NTrials', 'NBlocks', 'NCells', 'Delta'})];
		end
		BlockUIDs = unique(uint64(TrialMetadata.BlockUID));
		for BlockIndex = 1:numel(BlockUIDs)
			Rows = uint64(TrialMetadata.BlockUID) == BlockUIDs(BlockIndex);
			Curve = mean(Probabilities(Rows, :), 1);
			PerBlock = [PerBlock; table(Mouse, TrainingKeys(TrainingIndex), BlockUIDs(BlockIndex), TrialMetadata.DateTime(find(Rows, 1)), nnz(Rows), mean(Curve(PostMask)) - mean(Curve(PreMask)), 'VariableNames', {'Mouse', 'Training', 'BlockUID', 'DateTime', 'NTrials', 'Delta'})];
		end
		Readouts{end + 1, 1} = struct('Mouse', Mouse, 'Training', TrainingKeys(TrainingIndex), 'TrialUIDs', TrialUIDs, 'DateTime', TrialMetadata.DateTime, 'BlockUIDs', uint64(TrialMetadata.BlockUID), 'PPost', Probabilities, 'Time', Time, 'FirstRows', FirstRows, 'CellUIDs', Task.CellUIDs);
	end
	fprintf('冻结解码器读出：%s，首块%d trials，全程%d blocks/%d trials，共同细胞%d，缺失trial-cell行%d。\n', Mouse, nnz(FirstRows), Coverage.FullBlocks(end), numel(TrialUIDs), FirstTask.NCells, MissingCellRows);
end
assert(height(Coverage) == 9 && all(Coverage.FirstBlocks == 1) && all(Coverage.FirstTrials == 30));
assert(height(PerMouse) == 36 && numel(Readouts) == 18);
Comparisons = table();
for Window = ["FirstTransferBlock", "ThroughFirstFinal"]
	VersionStats = CompareTrainingWithinTests(OriginalPerMouse, PerMouse(PerMouse.Window == Window, :), Window);
	Comparisons = [Comparisons; VersionStats];
end
Comparisons.SignedRankPHolmAcrossWindows = HolmAdjust(Comparisons.SignedRankP);
for TestKey = ["LearnedAudioWater", "Transfer12hLightWater"]
	Baseline = Comparisons(Comparisons.Window == "FirstTransferBlock" & Comparisons.Test == TestKey, :);
	Old = OriginalStats(OriginalStats.Test == TestKey, :);
	assert(abs(Baseline.AnovaP - Old.AnovaP) < 1e-10 && abs(Baseline.SignedRankPHolm - Old.SignedRankPHolm) < 1e-12, 'FullLightDecoder:StatisticsChanged', '首块对照未复现3B原始窗口差的统计口径。');
end
fprintf('\n冻结训练与细胞，仅扩大12 h光水测试：\n');
disp(Coverage);
disp(Comparisons);
Results = struct('Comparisons', Comparisons, 'Coverage', Coverage, 'PerMouse', PerMouse, 'PerBlock', PerBlock, 'MissingTrials', MissingTrials, 'Readouts', {Readouts}, 'TrainingFrozen', true, 'CellsFrozen', true, 'SourceCache', SourcePath, 'PostDuration', 1, 'HalfWindow', 0.25, 'FullTestEnd', "FirstFinalInclusive", 'Weighting', "EqualTrialsWithinMouse_EqualMiceForGroup");
OutPath = TransferLearning.CachePath('Fig3C_12hLightWater_FirstVsFullTraining_Results.mat');
save(OutPath, 'Results');
writetable(Comparisons, fullfile(CacheDir, 'Fig3C_12hLightWater_FirstVsFullTraining_Stats.csv'));
writetable(Coverage, fullfile(CacheDir, 'Fig3C_12hLightWater_FirstVsFullTraining_Coverage.csv'));
writetable(PerMouse, fullfile(CacheDir, 'Fig3C_12hLightWater_FirstVsFullTraining_PerMouse.csv'));
writetable(PerBlock, fullfile(CacheDir, 'Fig3C_12hLightWater_FirstVsFullTraining_PerBlock.csv'));
writetable(MissingTrials, fullfile(CacheDir, 'Fig3C_12hLightWater_FirstVsFullTraining_MissingTrials.csv'));
assignin('base', 'Fig3C_FullLightWaterComparison', Results);
fprintf('全程测试对照已另存：%s；原3B/3C和解码缓存未覆盖。\n', OutPath);
end

function Probabilities = ApplyFixedDecoder(X, Task, Model)
Training = [Task.preTr; Task.postTr];
Mu = mean(Training, 1);
SD = std(Training, 0, 1);
SD(SD == 0) = 1;
Probabilities = nan(size(X, 1), size(X, 3));
for TimeIndex = 1:size(X, 3)
	Features = squeeze(X(:, :, TimeIndex));
	Features = (Features - Mu) ./ SD;
	Features(isnan(Features)) = 0;
	Probabilities(:, TimeIndex) = 1 ./ (1 + exp(-(Features * Model.w + Model.bias)));
end
end

function Y = LocalMean(X, Radius)
Y = zeros(size(X));
for TimeIndex = 1:size(X, 3)
	Indices = max(1, TimeIndex - Radius):min(size(X, 3), TimeIndex + Radius);
	Y(:, :, TimeIndex) = mean(X(:, :, Indices), 3);
end
end

function Stats = CompareTrainingWithinTests(Original, LightData, Window)
TestKeys = ["LearnedAudioWater", "Transfer12hLightWater"];
TestLabels = ["Learned", "12 h"];
TrainKeys = ["NaiveAudioOnly", "LearnedAudioWater"];
TrainLabels = ["Naive", "Learned"];
DataCell = cell(2, 2);
Stats = table();
for TestIndex = 1:2
	Mice = cell(1, 2);
	for TrainIndex = 1:2
		if TestIndex == 1
			Rows = sortrows(Original(Original.Test == TestKeys(TestIndex) & Original.Training == TrainKeys(TrainIndex), :), {'Dataset', 'Mouse'});
		else
			Rows = sortrows(LightData(LightData.Training == TrainKeys(TrainIndex), :), 'Mouse');
		end
		Mice{TrainIndex} = Rows.Mouse;
		DataCell{TestIndex, TrainIndex} = Rows.Delta;
	end
	assert(isequal(Mice{1}, Mice{2}));
	N = numel(DataCell{TestIndex, 1});
	NaiveMean = mean(DataCell{TestIndex, 1});
	LearnedMean = mean(DataCell{TestIndex, 2});
	P = signrank(DataCell{TestIndex, 2}, DataCell{TestIndex, 1}, 'method', 'exact');
	Stats = [Stats; table(Window, TestKeys(TestIndex), N, NaiveMean, std(DataCell{TestIndex, 1}) / sqrt(N), LearnedMean, std(DataCell{TestIndex, 2}) / sqrt(N), LearnedMean - NaiveMean, P, 'VariableNames', {'Window', 'Test', 'N', 'MeanNaive', 'SEMNaive', 'MeanLearned', 'SEMLearned', 'MeanLearnedMinusNaive', 'SignedRankP'})];
end
Stats.SignedRankPHolm = HolmAdjust(Stats.SignedRankP);
SampleNumbers = cellfun(@numel, DataCell);
FactorTests = [repelem(TestLabels(:), SampleNumbers(:, 1)); repelem(TestLabels(:), SampleNumbers(:, 2))];
FactorTraining = [repmat(TrainLabels(1), sum(SampleNumbers(:, 1)), 1); repmat(TrainLabels(2), sum(SampleNumbers(:, 2)), 1)];
Factors = table(FactorTests, FactorTraining, 'VariableNames', {'Test', 'Training'});
GroupPair = table([TestLabels(:), TestLabels(:)], repmat(TrainLabels, 2, 1), 'VariableNames', {'Test', 'Training'});
[AnovaComparisons, ~] = UniExp.TabularAnovaN(vertcat(DataCell{:}), Factors, Display=false, Model='full', Comparison=GroupPair);
Stats.AnovaP = nan(2, 1);
for ComparisonIndex = 1:height(AnovaComparisons)
	TestIndex = find(TestLabels == string(AnovaComparisons.Test(ComparisonIndex, 1)));
	assert(isscalar(TestIndex));
	Stats.AnovaP(TestIndex) = AnovaComparisons.PValue(ComparisonIndex);
end
assert(all(isfinite(Stats.AnovaP)) && isequal(Stats.N, [15; 9]));
end

function Adjusted = HolmAdjust(P)
[Sorted, Order] = sort(P);
Adjusted = nan(size(P));
Adjusted(Order) = min(cummax((numel(P):-1:1)' .* Sorted), 1);
end