function PlotData = ComputeLocalWindowGapDecoderMatrix()
% 计算3B的曲线均值、SEM和shuffle统计并保存缓存，不创建图形。
S = LoadMatrixResults();
Time = S.Time(:)';
PreMask = Time >= -1 & Time < 0;
PostMask = Time >= 0 & Time <= 1;
TrainKeys = ["NaiveAudioOnly", "LearnedAudioWater"];
TestKeys = ["NaiveAudioOnly", "LearnedAudioWater", "Transfer12hLightWater", "Transfer7dLightWater"];
RowSpecs = ["Naive", "AudioOnly", "Naive 🔊"; "Learned", "AudioWater", "Learned 🔊💧"];
ColumnLabels = ["Naive 🔊", "Learned 🔊💧", "12 h 💡💧", "7 d 💡💧"];
DisplayedColumns = 2:4;
RowStats = cell(2, 1);
Summary = table();
PerMouse = table();
for Row = 1:2
	Curves = cell(1, 4);
	MouseNames = cell(1, 4);
	Accuracies = cell(1, 4);
	for Column = 1:4
		Selected = 1:size(S.Results, 2);
		if Column >= 3
			Selected = Selected(cellfun(@(Result) Result.DS == Column - 2, S.Results(Row, :)));
		end
		IsOOF = Row == Column;
		NMice = numel(Selected);
		Values = nan(NMice, numel(Time));
		NullDelta = nan(S.NPermutation, NMice);
		Delta = nan(NMice, 1);
		Accuracy = nan(NMice, 1);
		Mice = strings(NMice, 1);
		for MouseIndex = 1:NMice
			Result = S.Results{Row, Selected(MouseIndex)};
			Task = S.Tasks{Row, Selected(MouseIndex)};
			if IsOOF
				Curve = Result.pPostS1T(:)';
				NullCurve = Result.Shuffle.PPostOOF;
				Accuracy(MouseIndex) = Result.s1Acc;
				NTrials = Result.nTr;
			else
				TestIndex = 1 + (Column >= 3);
				Curve = Result.Tests(TestIndex).pPostByT(:)';
				NullCurve = Result.Shuffle.PPostTests(:, :, TestIndex);
				Accuracy(MouseIndex) = Result.Tests(TestIndex).acc;
				NTrials = Result.Tests(TestIndex).nTe;
				assert(isempty(intersect(Task.TrainTrialUIDs, Task.Tests(TestIndex).TrialUIDs)), 'Fig3BMatrix:TrialLeakage', '外部测试与训练trial发生重叠。');
			end
			Values(MouseIndex, :) = Curve;
			Mice(MouseIndex) = string(Result.Mouse);
			Delta(MouseIndex) = mean(Curve(PostMask)) - mean(Curve(PreMask));
			NullDelta(:, MouseIndex) = mean(NullCurve(:, PostMask), 2) - mean(NullCurve(:, PreMask), 2);
			MouseP = (1 + nnz(NullDelta(:, MouseIndex) >= Delta(MouseIndex))) / (S.NPermutation + 1);
			PerMouse = [PerMouse; table(Row, Column, TrainKeys(Row), TestKeys(Column), Result.DS, Mice(MouseIndex), IsOOF, Result.nCells, NTrials, Delta(MouseIndex), mean(NullDelta(:, MouseIndex)), MouseP, Accuracy(MouseIndex), 'VariableNames', {'TrainRow', 'TestColumn', 'Training', 'Test', 'Dataset', 'Mouse', 'IsOOF', 'NCells', 'NTrials', 'Delta', 'ShuffleMeanDelta', 'DeltaPermutationP', 'Accuracy'})];
		end
		assert(NMice >= 3 && numel(unique(Mice)) == NMice && all(isfinite(Values), 'all') && all(isfinite(NullDelta), 'all'));
		Stream = RandStream('mt19937ar', 'Seed', S.GroupSeed);
		Draws = randi(Stream, S.NPermutation, [S.NMonteCarlo, NMice]);
		GroupNull = zeros(S.NMonteCarlo, 1);
		for MouseIndex = 1:NMice
			GroupNull = GroupNull + NullDelta(Draws(:, MouseIndex), MouseIndex) / NMice;
		end
		P = (1 + nnz(GroupNull >= mean(Delta))) / (S.NMonteCarlo + 1);
		Summary = [Summary; table(Row, Column, TrainKeys(Row), TestKeys(Column), IsOOF, NMice, mean(Delta), std(Delta) / sqrt(NMice), mean(NullDelta, 'all'), P, 'VariableNames', {'TrainRow', 'TestColumn', 'Training', 'Test', 'IsOOF', 'N', 'MeanDelta', 'SEMDelta', 'ShuffleMeanDelta', 'PValue'})];
		Curves{Column} = Values;
		MouseNames{Column} = Mice;
		Accuracies{Column} = Accuracy;
	end
	MeanCurves = cellfun(@(Values) mean(Values, 1), Curves, 'UniformOutput', false);
	SEMCurves = cellfun(@(Values) std(Values, 0, 1) / sqrt(size(Values, 1)), Curves, 'UniformOutput', false);
	RowStats{Row} = struct('trainPhase', RowSpecs(Row, 1), 'trainStimulus', RowSpecs(Row, 2), 'curves', {Curves}, 'mouseNames', {MouseNames}, 'accuracy', {Accuracies}, 'MeanCurves', {MeanCurves}, 'SEMCurves', {SEMCurves});
end
Summary.PValueHolm = HolmAdjust(Summary.PValue);
Summary.Stars = strings(8, 1);
for SummaryIndex = 1:8
	P = Summary.PValueHolm(SummaryIndex);
	if P < 0.001
		Summary.Stars(SummaryIndex) = "***";
	elseif P < 0.01
		Summary.Stars(SummaryIndex) = "**";
	elseif P < 0.05
		Summary.Stars(SummaryIndex) = "*";
	end
end
CacheDir = fileparts(S.CachePath);
writetable(Summary, fullfile(CacheDir, 'Fig3B_LocalWindow_2x4_Post1000ms_Summary.csv'));
writetable(PerMouse, fullfile(CacheDir, 'Fig3B_LocalWindow_2x4_Post1000ms_PerMouse.csv'));
PlotData = struct('rows', {RowStats}, 'rowSpecs', RowSpecs, 'columnLabels', ColumnLabels, 'tVec', Time, 'PostDuration', 1, 'Summary', Summary, 'PerMouse', PerMouse, 'CachePath', S.CachePath, 'NPermutation', S.NPermutation, 'NGroupMonteCarlo', S.NMonteCarlo, 'SignificanceMetric', "PostMinusPrePPost", 'Multiplicity', "Holm8TrainingTestConditions", 'StarTime', 1, 'FoldStandardization', true, 'DisplayedColumns', DisplayedColumns, 'DisplayedColumnLabels', ColumnLabels(DisplayedColumns), 'PlotDataVersion', 1);
PlotData.PlotDataCachePath = TransferLearning.CachePath('Fig3B_LocalWindow_GapDecoderTransfer_PlotData_Results.mat');
save(PlotData.PlotDataCachePath, 'PlotData');
fprintf('\n3B计算完成：曲线均值、SEM及原八项Holm结果已保存，未创建图形。\n');
disp(Summary);
end

function S = LoadMatrixResults()
Version = 1;
MatPath = TransferLearning.CachePath('CueModel_Fig3B_LocalWindow250ms_2x4_Post1000ms_FoldStandardized_Results.mat');
SourceNames = ["CueModel_LocalWindow250ms_NaiveAudioOnlyToTransferLightWater_12h7d_Results.mat", "CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat"];
SourceBytes = zeros(2, 1);
SourceDates = zeros(2, 1);
for SourceIndex = 1:2
	SourceInfo = dir(TransferLearning.CachePath(SourceNames(SourceIndex)));
	assert(isscalar(SourceInfo), 'Fig3BMatrix:MissingSource', '缺少原始1 s解码缓存：%s。', SourceNames(SourceIndex));
	SourceBytes(SourceIndex) = SourceInfo.bytes;
	SourceDates(SourceIndex) = SourceInfo.datenum;
end
if isfile(MatPath)
	S = load(MatPath);
	assert(S.Version == Version && isequal(S.SourceBytes, SourceBytes) && isequal(S.SourceDates, SourceDates), 'Fig3BMatrix:StaleCache', '2×4缓存与源数据不一致。');
	ValidateTasks(S.Tasks, S.Results);
	return;
end
Naive = TransferLearning.LoadLocalWindowCueTransferResults("Naive", "AudioOnly", 1);
Learned = TransferLearning.LoadLocalWindowCueTransferResults("Learned", "AudioWater", 1);
assert(isequal(Naive.tVec, Learned.tVec) && Naive.halfWindow == 0.25 && Learned.halfWindow == 0.25);
Tasks = cell(2, 0);
for NaiveIndex = 1:numel(Naive.tasks)
	NaiveTask = Naive.tasks{NaiveIndex};
	Matches = find(cellfun(@(Task) Task.DS == NaiveTask.DS && string(Task.Mouse) == string(NaiveTask.Mouse), Learned.tasks));
	if isempty(Matches)
		continue;
	end
	assert(isscalar(Matches));
	LearnedTask = RecoverLearnedTrialIDs(Learned.tasks{Matches});
	CommonCells = intersect(uint64(NaiveTask.CellUIDs), uint64(LearnedTask.CellUIDs));
	if numel(CommonCells) < 5
		fprintf('3B跳过%s：三情境共同细胞不足5个。\n', string(NaiveTask.Mouse));
		continue;
	end
	assert(isequal(uint64(NaiveTask.TestTrialUIDs), uint64(LearnedTask.TestTrialUIDs)), 'Fig3BMatrix:DifferentTrials', '两种训练必须使用相同的迁移测试trial。');
	[FoundNaive, NaiveCells] = ismember(CommonCells, uint64(NaiveTask.CellUIDs));
	[FoundLearned, LearnedCells] = ismember(CommonCells, uint64(LearnedTask.CellUIDs));
	assert(all(FoundNaive) && all(FoundLearned));
	NaiveContext = struct('Name', "NaiveAudioOnly", 'preTe', NaiveTask.preTr(:, NaiveCells), 'postTe', NaiveTask.postTr(:, NaiveCells), 'XTeT', NaiveTask.XTrT(:, NaiveCells, :), 'TrialUIDs', uint64(NaiveTask.TrainTrialUIDs));
	LearnedContext = struct('Name', "LearnedAudioWater", 'preTe', LearnedTask.preTr(:, LearnedCells), 'postTe', LearnedTask.postTr(:, LearnedCells), 'XTeT', LearnedTask.XTrT(:, LearnedCells, :), 'TrialUIDs', uint64(LearnedTask.TrainTrialUIDs));
	LightContext = struct('Name', "TransferLightWater", 'preTe', NaiveTask.preTe(:, NaiveCells), 'postTe', NaiveTask.postTe(:, NaiveCells), 'XTeT', NaiveTask.XTeT(:, NaiveCells, :), 'TrialUIDs', uint64(NaiveTask.TestTrialUIDs));
	PairIndex = size(Tasks, 2) + 1;
	Tasks{1, PairIndex} = MakeTask(NaiveTask, CommonCells, NaiveContext, [LearnedContext; LightContext]);
	Tasks{2, PairIndex} = MakeTask(NaiveTask, CommonCells, LearnedContext, [NaiveContext; LightContext]);
end
assert(size(Tasks, 2) >= 3, 'Fig3BMatrix:NoMice', '三情境齐全的鼠不足3只。');
Results = cell(size(Tasks));
WorkerLimit = 0;
Pool = gcp('nocreate');
if ~isempty(Pool)
	WorkerLimit = min(Pool.NumWorkers, 8);
end
Time = Naive.tVec(:)';
parfor (TaskIndex = 1:numel(Tasks), WorkerLimit)
	rng(42 + TaskIndex, 'twister');
	Results{TaskIndex} = TransferLearning.DecodeCuePrePostTransfer(Tasks{TaskIndex}, Time, 200);
	fprintf('3B矩阵解码 %d/%d：%s，训练%s，%d细胞。\n', TaskIndex, numel(Tasks), Tasks{TaskIndex}.Mouse, Tasks{TaskIndex}.Training, Tasks{TaskIndex}.NCells);
end
ValidateTasks(Tasks, Results);
S = struct('Version', Version, 'SourceBytes', SourceBytes, 'SourceDates', SourceDates, 'Tasks', {Tasks}, 'Results', {Results}, 'Time', Time, 'PostDuration', 1, 'HalfWindow', 0.25, 'NPermutation', 200, 'NMonteCarlo', 1000000, 'GroupSeed', 20261112, 'CachePath', MatPath);
save(MatPath, '-struct', 'S');
end

function Task = RecoverLearnedTrialIDs(Task)
if isfield(Task, 'TrainTrialUIDs') && isfield(Task, 'TestTrialUIDs')
	return;
end
if Task.DS == 1
	DS = TransferLearning.AudioLightBaseline();
else
	DS = TransferLearning.Vacation7();
end
Specs = ["Learned", "AudioWater"; "Transfer", "LightWater"];
Xs = seconds(TransferLearning.Xs);
PreMask = Xs >= -1.25 & Xs <= 0.25;
PostMask = Xs >= -0.25 & Xs <= 1.25;
for ContextIndex = 1:2
	Metadata = DS.TableQuery(["Mouse", "BlockUID"], Phase=Specs(ContextIndex, 1), Stimulus=Specs(ContextIndex, 2));
	Blocks = unique(uint64(Metadata.BlockUID(string(Metadata.Mouse) == string(Task.Mouse))));
	Raw = TransferLearning.QueryZScoreNts(DS, Task.Mouse, Specs(ContextIndex, 2));
	Raw = Raw(ismember(uint64(Raw.BlockUID), Blocks) & ismember(uint64(Raw.CellUID), uint64(Task.CellUIDs)), :);
	if ContextIndex == 1
		Raw = Raw(~isnan(Raw.Behavior), :);
		ExpectedPre = Task.preTr;
		ExpectedPost = Task.postTr;
	else
		ExpectedPre = Task.preTe;
		ExpectedPost = Task.postTe;
	end
	X = TransferLearning.BuildTrialMatrix(Raw, Task.CellUIDs);
	Pre = mean(X(:, :, PreMask), 3);
	Post = mean(X(:, :, PostMask), 3);
	assert(isequal(size(Pre), size(ExpectedPre)) && max(abs(Pre - ExpectedPre), [], 'all') < 1e-8 && max(abs(Post - ExpectedPost), [], 'all') < 1e-8, 'Fig3BMatrix:RecoveredTrialsMismatch', '恢复的%s %s特征不能复现旧缓存。', string(Task.Mouse), Specs(ContextIndex, 2));
	TrialUIDs = unique(uint64(Raw.TrialUID));
	assert(numel(TrialUIDs) == size(ExpectedPre, 1));
	if ContextIndex == 1
		Task.TrainTrialUIDs = TrialUIDs;
	else
		Task.TestTrialUIDs = TrialUIDs;
	end
end
end

function Task = MakeTask(Source, Cells, Train, Tests)
assert(size(Train.preTe, 1) >= 5);
for TestIndex = 1:numel(Tests)
	assert(isempty(intersect(Train.TrialUIDs, Tests(TestIndex).TrialUIDs)), 'Fig3BMatrix:TrialLeakage', '训练trial与外部测试trial发生重叠。');
end
Task = struct('DS', Source.DS, 'Mouse', Source.Mouse, 'Training', Train.Name, 'NCells', numel(Cells), 'CellUIDs', Cells, 'preTr', Train.preTe, 'postTr', Train.postTe, 'XTrT', Train.XTeT, 'TrainTrialUIDs', Train.TrialUIDs, 'Tests', Tests, 'FoldStandardization', true);
end

function ValidateTasks(Tasks, Results)
assert(isequal(size(Tasks), size(Results)) && size(Tasks, 1) == 2);
for PairIndex = 1:size(Tasks, 2)
	assert(string(Tasks{1, PairIndex}.Mouse) == string(Tasks{2, PairIndex}.Mouse));
	assert(isequal(Tasks{1, PairIndex}.CellUIDs, Tasks{2, PairIndex}.CellUIDs));
	assert(isequal(Tasks{1, PairIndex}.Tests(2), Tasks{2, PairIndex}.Tests(2)));
	for Row = 1:2
		Task = Tasks{Row, PairIndex};
		Result = Results{Row, PairIndex};
		assert(Result.FoldStandardization && Result.nPerm == 200 && numel(Result.TrialFold) == size(Task.preTr, 1));
		assert(all(Result.TrialFold >= 1 & Result.TrialFold <= 5));
		Samples = [Task.preTr; Task.postTr];
		for Fold = 1:5
			HeldOut = Result.TrialFold == Fold;
			TrainingRows = ~[HeldOut; HeldOut];
			ExpectedSD = std(Samples(TrainingRows, :), 0, 1);
			ExpectedSD(ExpectedSD == 0) = 1;
			assert(max(abs(Result.FoldMean{Fold} - mean(Samples(TrainingRows, :), 1))) < 1e-10);
			assert(max(abs(Result.FoldSD{Fold} - ExpectedSD)) < 1e-10);
		end
		for TestIndex = 1:2
			assert(isempty(intersect(Task.TrainTrialUIDs, Task.Tests(TestIndex).TrialUIDs)));
		end
	end
end
end

function Adjusted = HolmAdjust(P)
[Sorted, Order] = sort(P);
Adjusted = nan(size(P));
Adjusted(Order) = min(cummax((numel(P):-1:1)' .* Sorted), 1);
end