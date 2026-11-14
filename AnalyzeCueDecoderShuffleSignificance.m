function [Summary, PerMouse] = AnalyzeCueDecoderShuffleSignificance(BundleIndices)
% 检验原3B/3C及四情境测试是否高于训练标签shuffle水平；原缓存不改写。
arguments
	BundleIndices (1,:) double {mustBeInteger, mustBePositive} = 1:10
end
Specs = BuildBundleSpecs();
assert(all(BundleIndices <= numel(Specs)) && numel(unique(BundleIndices)) == numel(BundleIndices), 'CueShuffleAudit:BundleSelection', '缓存编号必须互不重复且在1至10之间。');
NMonteCarlo = 1000000;
GroupSeed = 20261112;
Summary = table();
PerMouse = table();
for BundleIndex = BundleIndices
	Spec = Specs{BundleIndex};
	SourcePath = TransferLearning.CachePath(Spec.FileName);
	assert(isfile(SourcePath), 'CueShuffleAudit:MissingSource', '缺少原始解码缓存：%s。', SourcePath);
	Source = load(SourcePath);
	if isfield(Source, 'res')
		Original = Source.res;
		Tasks = Source.tasks;
		Time = Source.tVec(:)';
	else
		Original = Source.Results;
		Tasks = Source.Tasks;
		Time = Source.Time(:)';
	end
	Results = LoadShuffleResults(SourcePath, Tasks, Original, Time);
	PreMask = Time >= -1 & Time < 0;
	PostMask = Time >= 0 & Time <= Spec.PostDuration;
	assert(any(PreMask) && any(PostMask));
	if Spec.Family == "TransferCohorts"
		Contexts = ["SelfOOF12h7d", "Transfer12hLightWater", "Transfer7dLightWater"];
		TestIndices = [0, 1, 1];
		Cohorts = ["Pooled12h7d", "12h", "7d"];
	elseif Spec.Training == "NaiveAudioOnly"
		Contexts = ["NaiveAudioOOF", "NaiveLightOnly", "LearnedAudioWater", "Transfer12hLightWater"];
		TestIndices = [0, 1, 2, 3];
		Cohorts = repmat("12h", 1, 4);
	else
		Contexts = ["LearnedAudioWaterOOF", "NaiveAudioOnly", "NaiveLightOnly", "Transfer12hLightWater"];
		TestIndices = [0, 1, 2, 3];
		Cohorts = repmat("12h", 1, 4);
	end
	for ContextIndex = 1:numel(Contexts)
		Selected = 1:numel(Results);
		if Spec.Family == "TransferCohorts" && ContextIndex > 1
			Selected = Selected(cellfun(@(Result) Result.DS == ContextIndex - 1, Results));
		end
		NMice = numel(Selected);
		assert(NMice >= 3);
		ObservedDelta = nan(NMice, 1);
		ObservedAccuracy = nan(NMice, 1);
		NullDelta = nan(200, NMice);
		NullAccuracy = nan(200, NMice);
		MouseDeltaP = nan(NMice, 1);
		MouseAccuracyP = nan(NMice, 1);
		Mice = strings(NMice, 1);
		for MouseIndex = 1:NMice
			Result = Results{Selected(MouseIndex)};
			[Curve, Accuracy, OldAccuracyP] = ObservedValues(Original{Selected(MouseIndex)}, TestIndices(ContextIndex));
			if TestIndices(ContextIndex) == 0
				NullCurve = Result.Shuffle.PPostOOF;
				NullAccuracy(:, MouseIndex) = Result.Shuffle.AccuracyOOF;
			else
				NullCurve = Result.Shuffle.PPostTests(:, :, TestIndices(ContextIndex));
				NullAccuracy(:, MouseIndex) = Result.Shuffle.AccuracyTests(:, TestIndices(ContextIndex));
			end
			assert(size(NullCurve, 1) == 200 && size(NullCurve, 2) == numel(Time));
			ObservedDelta(MouseIndex) = mean(Curve(PostMask)) - mean(Curve(PreMask));
			ObservedAccuracy(MouseIndex) = Accuracy;
			NullDelta(:, MouseIndex) = mean(NullCurve(:, PostMask), 2) - mean(NullCurve(:, PreMask), 2);
			MouseDeltaP(MouseIndex) = (1 + nnz(NullDelta(:, MouseIndex) >= ObservedDelta(MouseIndex))) / 201;
			MouseAccuracyP(MouseIndex) = (1 + nnz(NullAccuracy(:, MouseIndex) >= Accuracy)) / 201;
			assert(abs(MouseAccuracyP(MouseIndex) - OldAccuracyP) < 1e-12, 'CueShuffleAudit:NullMismatch', '重算的shuffle准确率p值未能复现原缓存。');
			Mice(MouseIndex) = string(Result.Mouse);
			PerMouse = [PerMouse; table(Spec.Family, Spec.Training, Spec.PostDuration, Contexts(ContextIndex), Cohorts(ContextIndex), Mice(MouseIndex), ObservedDelta(MouseIndex), mean(NullDelta(:, MouseIndex)), MouseDeltaP(MouseIndex), Accuracy, mean(NullAccuracy(:, MouseIndex)), MouseAccuracyP(MouseIndex), 'VariableNames', {'Family', 'Training', 'PostDuration', 'Context', 'Cohort', 'Mouse', 'Delta', 'ShuffleMeanDelta', 'DeltaPermutationP', 'Accuracy', 'ShuffleMeanAccuracy', 'AccuracyPermutationP'})];
		end
		assert(numel(unique(Mice)) == NMice && all(isfinite(NullDelta), 'all') && all(isfinite(NullAccuracy), 'all'));
		Stream = RandStream('mt19937ar', 'Seed', GroupSeed);
		Draws = randi(Stream, 200, [NMonteCarlo, NMice]);
		GroupNullDelta = zeros(NMonteCarlo, 1);
		GroupNullAccuracy = zeros(NMonteCarlo, 1);
		for MouseIndex = 1:NMice
			GroupNullDelta = GroupNullDelta + NullDelta(Draws(:, MouseIndex), MouseIndex) / NMice;
			GroupNullAccuracy = GroupNullAccuracy + NullAccuracy(Draws(:, MouseIndex), MouseIndex) / NMice;
		end
		DeltaP = (1 + nnz(GroupNullDelta >= mean(ObservedDelta))) / (NMonteCarlo + 1);
		AccuracyP = (1 + nnz(GroupNullAccuracy >= mean(ObservedAccuracy))) / (NMonteCarlo + 1);
		Summary = [Summary; table(Spec.Family, Spec.Training, Spec.PostDuration, Contexts(ContextIndex), Cohorts(ContextIndex), NMice, mean(ObservedDelta), std(ObservedDelta) / sqrt(NMice), mean(NullDelta, 'all'), prctile(GroupNullDelta, 95), DeltaP, nnz(MouseDeltaP < 0.05), mean(ObservedAccuracy), std(ObservedAccuracy) / sqrt(NMice), mean(NullAccuracy, 'all'), prctile(GroupNullAccuracy, 95), AccuracyP, nnz(MouseAccuracyP < 0.05), 'VariableNames', {'Family', 'Training', 'PostDuration', 'Context', 'Cohort', 'N', 'MeanDelta', 'SEMDelta', 'ShuffleMeanDelta', 'ShuffleGroupDelta95', 'DeltaGroupP', 'NMouseDeltaRawSignificant', 'MeanAccuracy', 'SEMAccuracy', 'ShuffleMeanAccuracy', 'ShuffleGroupAccuracy95', 'AccuracyGroupP', 'NMouseAccuracyRawSignificant'})];
	end
	fprintf('shuffle审计完成 %d/10：%s，后段%.1f s。\n', BundleIndex, Spec.Family + " " + Spec.Training, Spec.PostDuration);
end
Summary.DeltaGroupPHolm = HolmAdjust(Summary.DeltaGroupP);
Summary.AccuracyGroupPHolm = HolmAdjust(Summary.AccuracyGroupP);
Summary.NComparisons = repmat(height(Summary), height(Summary), 1);
Summary.NShufflePerMouse = repmat(200, height(Summary), 1);
Summary.NGroupMonteCarlo = repmat(NMonteCarlo, height(Summary), 1);
Summary.GroupMonteCarloSeed = repmat(GroupSeed, height(Summary), 1);
PerMouse.DeltaPHolmWithinCondition = nan(height(PerMouse), 1);
PerMouse.AccuracyPHolmWithinCondition = nan(height(PerMouse), 1);
for SummaryIndex = 1:height(Summary)
	Rows = PerMouse.Family == Summary.Family(SummaryIndex) & PerMouse.Training == Summary.Training(SummaryIndex) & PerMouse.PostDuration == Summary.PostDuration(SummaryIndex) & PerMouse.Context == Summary.Context(SummaryIndex);
	assert(nnz(Rows) == Summary.N(SummaryIndex));
	PerMouse.DeltaPHolmWithinCondition(Rows) = HolmAdjust(PerMouse.DeltaPermutationP(Rows));
	PerMouse.AccuracyPHolmWithinCondition(Rows) = HolmAdjust(PerMouse.AccuracyPermutationP(Rows));
end
if isequal(sort(BundleIndices), 1:10)
	FileStem = 'CueDecoder_ShuffleSignificance_AllTests';
	assert(height(Summary) == 34 && height(PerMouse) == 328);
else
	FileStem = char("CueDecoder_ShuffleSignificance_Bundles" + strjoin(string(BundleIndices), '_'));
end
CachePath = TransferLearning.CachePath([FileStem, '_Results.mat']);
CacheDir = fileparts(CachePath);
writetable(Summary, fullfile(CacheDir, [FileStem, '_Summary.csv']));
writetable(PerMouse, fullfile(CacheDir, [FileStem, '_PerMouse.csv']));
save(CachePath, 'Summary', 'PerMouse', 'Specs', 'BundleIndices');
assignin('base', 'Fig3_ShuffleSignificanceSummary', Summary);
assignin('base', 'Fig3_ShuffleSignificancePerMouse', PerMouse);
fprintf('\n群体shuffle检验：各鼠等权，200次标签shuffle/鼠，%d次联合零分布抽样；差值与准确率分别对%d项进行Holm校正。\n', NMonteCarlo, height(Summary));
disp(Summary(:, {'Family', 'Training', 'PostDuration', 'Context', 'N', 'MeanDelta', 'ShuffleMeanDelta', 'DeltaGroupP', 'DeltaGroupPHolm', 'MeanAccuracy', 'ShuffleMeanAccuracy', 'AccuracyGroupP', 'AccuracyGroupPHolm'}));
end

function Specs = BuildBundleSpecs()
TrainingKeys = ["NaiveAudioOnly", "NaiveAudioWater", "LearnedAudioWater"];
FileNames = ["CueModel_LocalWindow250ms_NaiveAudioOnlyToTransferLightWater_12h7d_Results.mat", "CueModel_LocalWindow250ms_NaiveAudioWaterToTransferLightWater_12h7d_Results.mat", "CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat"];
Durations = [1, 0.3];
Specs = cell(0, 1);
for TrainingIndex = 1:3
	for DurationIndex = 1:2
		FileName = FileNames(TrainingIndex);
		if Durations(DurationIndex) == 0.3
			FileName = replace(FileName, '_Results.mat', '_Post300ms_Results.mat');
		end
		Specs{end + 1, 1} = struct('Family', "TransferCohorts", 'Training', TrainingKeys(TrainingIndex), 'PostDuration', Durations(DurationIndex), 'FileName', FileName);
	end
end
for TrainingKey = ["NaiveAudioOnly", "LearnedAudioWater"]
	for Duration = Durations
		FileName = sprintf('CueModel_LocalWindow250ms_%s_FourContexts_Post%dms_Results.mat', TrainingKey, round(1000 * Duration));
		Specs{end + 1, 1} = struct('Family', "FourContexts", 'Training', TrainingKey, 'PostDuration', Duration, 'FileName', FileName);
	end
end
end

function Results = LoadShuffleResults(SourcePath, Tasks, Original, Time)
Version = 1;
SourceInfo = dir(SourcePath);
[~, SourceName] = fileparts(SourcePath);
AuditPath = TransferLearning.CachePath([SourceName, '_ShuffleAudit_Results.mat']);
if isfile(AuditPath)
	Audit = load(AuditPath);
	assert(Audit.Version == Version && Audit.SourceBytes == SourceInfo.bytes && Audit.SourceDatenum == SourceInfo.datenum, 'CueShuffleAudit:StaleAudit', 'shuffle审计缓存与原文件不一致：%s。', AuditPath);
	Results = Audit.Results;
else
	Results = cell(numel(Tasks), 1);
	WorkerLimit = 0;
	Pool = gcp('nocreate');
	if ~isempty(Pool)
		WorkerLimit = min(Pool.NumWorkers, 8);
	end
	parfor (TaskIndex = 1:numel(Tasks), WorkerLimit)
		rng(42 + TaskIndex, 'twister');
		Results{TaskIndex} = TransferLearning.DecodeCuePrePostTransfer(Tasks{TaskIndex}, Time, 200);
		ValidateObserved(Original{TaskIndex}, Results{TaskIndex});
		fprintf('保留完整shuffle分布：%d/%d，%s。\n', TaskIndex, numel(Tasks), Tasks{TaskIndex}.Mouse);
	end
	Audit = struct('Version', Version, 'SourceBytes', SourceInfo.bytes, 'SourceDatenum', SourceInfo.datenum, 'Results', {Results}, 'NPermutation', 200, 'SeedBase', 42);
	save(AuditPath, '-struct', 'Audit');
end
assert(numel(Original) == numel(Results));
for ResultIndex = 1:numel(Results)
	ValidateObserved(Original{ResultIndex}, Results{ResultIndex});
end
end

function ValidateObserved(Original, Replayed)
assert(string(Original.Mouse) == string(Replayed.Mouse) && isfield(Replayed, 'Shuffle'));
for TestIndex = 0:numel(Replayed.Tests)
	[OldCurve, OldAccuracy, OldP] = ObservedValues(Original, TestIndex);
	[NewCurve, NewAccuracy, NewP] = ObservedValues(Replayed, TestIndex);
	assert(numel(OldCurve) == numel(NewCurve) && max(abs(OldCurve - NewCurve)) < 1e-8 && abs(OldAccuracy - NewAccuracy) < 1e-12 && abs(OldP - NewP) < 1e-12, 'CueShuffleAudit:ReplayMismatch', '原随机种子未能复现%s的第%d项测试；停止以避免混用原观测与新shuffle。', string(Original.Mouse), TestIndex);
end
end

function [Curve, Accuracy, P] = ObservedValues(Result, TestIndex)
if TestIndex == 0
	Curve = Result.pPostS1T(:)';
	Accuracy = Result.s1Acc;
	P = Result.s1p;
elseif isfield(Result, 'Tests')
	Curve = Result.Tests(TestIndex).pPostByT(:)';
	Accuracy = Result.Tests(TestIndex).acc;
	P = Result.Tests(TestIndex).p;
else
	assert(TestIndex == 1);
	Curve = Result.pPostByT(:)';
	Accuracy = Result.s2Acc;
	P = Result.s2p;
end
end

function Adjusted = HolmAdjust(P)
[Sorted, Order] = sort(P);
Adjusted = nan(size(P));
Adjusted(Order) = min(cummax((numel(P):-1:1)' .* Sorted), 1);
end