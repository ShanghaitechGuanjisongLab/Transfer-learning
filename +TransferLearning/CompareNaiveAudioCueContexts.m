function Stats = CompareNaiveAudioCueContexts(PostDuration, TrainContext)
% 同一批12 h鼠的声线索解码器：OOF自测及其余三个情境；默认Naive声，也支持Learned声水训练。
% 前段保持原定义，后段采用1 s或0.3 s；均保留±250 ms跨界平滑，以鼠为单位比较后减前。
arguments
	PostDuration (1,1) double {mustBeMember(PostDuration, [0.3, 1])} = 1
	TrainContext (1,1) string {mustBeMember(TrainContext, ["NaiveAudioOnly", "LearnedAudioWater"])} = "NaiveAudioOnly"
end
S = LoadFourContexts(PostDuration, TrainContext);
Time = S.Time(:)';
PreMask = Time >= -1 & Time < 0;
PostMask = Time >= 0 & Time <= PostDuration;
assert(any(PreMask) && any(PostMask), 'NaiveAudioContexts:EmptyWindow', '时间网格没有覆盖指定的前后窗口。');
ContextKeys = ["NaiveAudioOOF", "NaiveLightOnly", "LearnedAudioWater", "Transfer12hLightWater"];
ContextLabels = ["Naive 🔊 (OOF)", "Naive 💡", "Learned 🔊💧", "12 h 💡💧"];
TrainLabel = "Naive声";
if TrainContext == "LearnedAudioWater"
	ContextKeys = ["LearnedAudioWaterOOF", "NaiveAudioOnly", "NaiveLightOnly", "Transfer12hLightWater"];
	ContextLabels = ["Learned 🔊💧 (OOF)", "Naive 🔊", "Naive 💡", "12 h 💡💧"];
	TrainLabel = "Learned声水";
end
NMice = numel(S.Results);
Mice = strings(NMice, 1);
Curves = repmat({nan(NMice, numel(Time))}, 1, 4);
Delta = nan(NMice, 4);
PreValues = nan(NMice, 4);
PostValues = nan(NMice, 4);
PerMouse = table();
for MouseIndex = 1:NMice
	Result = S.Results{MouseIndex};
	Mice(MouseIndex) = string(Result.Mouse);
	for ContextIndex = 1:4
		if ContextIndex == 1
			Curve = Result.pPostS1T(:)';
			Accuracy = Result.s1Acc;
			NTrials = Result.nTr;
		else
			Curve = Result.Tests(ContextIndex - 1).pPostByT(:)';
			Accuracy = Result.Tests(ContextIndex - 1).acc;
			NTrials = Result.Tests(ContextIndex - 1).nTe;
		end
		Curves{ContextIndex}(MouseIndex, :) = Curve;
		PreValues(MouseIndex, ContextIndex) = mean(Curve(PreMask));
		PostValues(MouseIndex, ContextIndex) = mean(Curve(PostMask));
		Delta(MouseIndex, ContextIndex) = PostValues(MouseIndex, ContextIndex) - PreValues(MouseIndex, ContextIndex);
		PerMouse = [PerMouse; table(Mice(MouseIndex), ContextKeys(ContextIndex), PostDuration, PreValues(MouseIndex, ContextIndex), PostValues(MouseIndex, ContextIndex), Delta(MouseIndex, ContextIndex), Accuracy, NTrials, Result.nCells, 'VariableNames', {'Mouse', 'Context', 'PostDuration', 'PreProbability', 'PostProbability', 'DeltaProbability', 'Accuracy', 'NTrials', 'NCells'})];
	end
end
assert(NMice >= 3 && numel(unique(Mice)) == NMice && all(isfinite(Delta), 'all'), 'NaiveAudioContexts:IncompletePairing', '四情境必须使用相同且完整的逐鼠数据。');
[FriedmanP, ~, FriedmanStats] = friedman(Delta, 1, 'off');
Summary = table(ContextKeys', repmat(NMice, 4, 1), mean(PreValues, 1)', mean(PostValues, 1)', mean(Delta, 1)', std(Delta, 0, 1)' / sqrt(NMice), median(Delta, 1)', nan(4, 1), 'VariableNames', {'Context', 'N', 'MeanPre', 'MeanPost', 'MeanDelta', 'SEMDelta', 'MedianDelta', 'PValueVsZero'});
for ContextIndex = 1:4
	Summary.PValueVsZero(ContextIndex) = SignedRankP(Delta(:, ContextIndex));
end
Summary.PValueVsZeroHolm = HolmAdjust(Summary.PValueVsZero);
PairIndices = nchoosek(1:4, 2);
Pairwise = table(ContextKeys(PairIndices(:, 1))', ContextKeys(PairIndices(:, 2))', repmat(NMice, 6, 1), nan(6, 1), nan(6, 1), 'VariableNames', {'Context1', 'Context2', 'N', 'MeanDelta1Minus2', 'PValue'});
for PairIndex = 1:height(Pairwise)
	Difference = Delta(:, PairIndices(PairIndex, 1)) - Delta(:, PairIndices(PairIndex, 2));
	Pairwise.MeanDelta1Minus2(PairIndex) = mean(Difference);
	Pairwise.PValue(PairIndex) = SignedRankP(Difference);
end
Pairwise.PValueHolm = HolmAdjust(Pairwise.PValue);
fprintf('\n%s训练，四情境配对比较：后段%.1f s，n=%d，Friedman p=%.9g。\n', TrainLabel, PostDuration, NMice, FriedmanP);
fprintf('前段P(post)平均范围为[-1,0) s，后段为[0,%.1f] s；保留±250 ms跨界平滑。\n', PostDuration);
disp(Summary);
disp(Pairwise);
[Fig, CurveAxes, DeltaAx, SvgPath] = PlotContexts(Time, Curves, Delta, ContextLabels, PostDuration, FriedmanP, TrainContext);
CacheDir = fileparts(S.CachePath);
FileStem = sprintf('%s_FourContexts_Post%dms', TrainContext, round(1000 * PostDuration));
writetable(PerMouse, fullfile(CacheDir, [FileStem, '_PerMouse.csv']));
writetable(Summary, fullfile(CacheDir, [FileStem, '_Summary.csv']));
writetable(Pairwise, fullfile(CacheDir, [FileStem, '_Pairwise.csv']));
Stats = struct('PostDuration', PostDuration, 'PreDuration', 1, 'HalfWindow', S.HalfWindow, 'Mice', Mice, 'Time', Time, 'Curves', {Curves}, 'Delta', Delta, 'PerMouse', PerMouse, 'Summary', Summary, 'Pairwise', Pairwise, 'FriedmanP', FriedmanP, 'FriedmanStats', FriedmanStats, 'Figure', Fig, 'CurveAxes', CurveAxes, 'DeltaAxes', DeltaAx, 'SvgPath', SvgPath, 'CachePath', S.CachePath, 'TrainContext', TrainContext);
end

function S = LoadFourContexts(PostDuration, TrainContext)
CacheVersion = 1;
HalfWindow = 0.250;
NPermutation = 200;
MatPath = TransferLearning.CachePath(sprintf('CueModel_LocalWindow250ms_%s_FourContexts_Post%dms_Results.mat', TrainContext, round(1000 * PostDuration)));
if isfile(MatPath)
	S = load(MatPath);
	assert(S.Version == CacheVersion && S.PostDuration == PostDuration && S.HalfWindow == HalfWindow && S.NPermutation == NPermutation, 'NaiveAudioContexts:CacheSettings', '四情境缓存的版本或时间窗不一致。');
	S.CachePath = MatPath;
	return;
end
if TrainContext == "LearnedAudioWater"
	S = LoadFourContexts(PostDuration, "NaiveAudioOnly");
	S.Tasks = UseLearnedTraining(S.Tasks);
	S.TrainContext = TrainContext;
	S.TestSpecs = ["Naive", "AudioOnly", "NaiveAudioOnly"; "Naive", "LightOnly", "NaiveLightOnly"; "Transfer", "LightWater", "Transfer12hLightWater"];
	S.CachePath = MatPath;
	S = DecodeFourContexts(S);
	return;
end
Base = TransferLearning.LoadLocalWindowCueTransferResults("Naive", "AudioOnly", PostDuration);
DS = TransferLearning.AudioLightBaseline();
TestSpecs = ["Naive", "LightOnly", "NaiveLightOnly"; "Learned", "AudioWater", "LearnedAudioWater"; "Transfer", "LightWater", "Transfer12hLightWater"];
Metadata = cell(2, 1);
CompleteMice = strings(0, 1);
for BaseIndex = 1:numel(Base.tasks)
	if Base.tasks{BaseIndex}.DS == 1
		CompleteMice(end + 1, 1) = string(Base.tasks{BaseIndex}.Mouse);
	end
end
for ContextIndex = 1:2
	Metadata{ContextIndex} = DS.TableQuery(["Mouse", "BlockUID"], Phase=TestSpecs(ContextIndex, 1), Stimulus=TestSpecs(ContextIndex, 2));
	CompleteMice = intersect(CompleteMice, unique(string(Metadata{ContextIndex}.Mouse)));
end
Tasks = cell(0, 1);
Xs = seconds(TransferLearning.Xs);
PreFeatureMask = Xs >= -1 - HalfWindow & Xs <= HalfWindow;
PostFeatureMask = Xs >= -HalfWindow & Xs <= PostDuration + HalfWindow;
if PostDuration == 1
	TimeIndices = find(Xs >= -1.5 & Xs <= 1.5);
else
	TimeIndices = find(Xs >= -1.5 & Xs <= PostDuration);
end
Time = Xs(TimeIndices);
assert(isequal(Time, Base.tVec), 'NaiveAudioContexts:DifferentGrids', '四情境与基础解码缓存的时间网格不一致。');
Radius = round(HalfWindow / median(diff(Xs)));
for BaseIndex = 1:numel(Base.tasks)
	SeedTask = Base.tasks{BaseIndex};
	if SeedTask.DS ~= 1 || ~ismember(string(SeedTask.Mouse), CompleteMice)
		continue;
	end
	RawTests = cell(2, 1);
	CommonCells = uint64(SeedTask.CellUIDs);
	for ContextIndex = 1:2
		ContextMetadata = Metadata{ContextIndex};
		Blocks = unique(uint64(ContextMetadata.BlockUID(string(ContextMetadata.Mouse) == string(SeedTask.Mouse))));
		Raw = TransferLearning.QueryZScoreNts(DS, SeedTask.Mouse, TestSpecs(ContextIndex, 2));
		if isempty(Raw)
			CommonCells = uint64([]);
			break;
		end
		Raw = Raw(ismember(uint64(Raw.BlockUID), Blocks), :);
		if TestSpecs(ContextIndex, 2) == "AudioWater"
			Raw = Raw(isfinite(double(Raw.Behavior)), :);
		end
		RawTests{ContextIndex} = Raw;
		CommonCells = intersect(CommonCells, unique(uint64(Raw.CellUID)));
	end
	if numel(CommonCells) < 5
		fprintf('四情境跳过%s：共同细胞不足5个。\n', string(SeedTask.Mouse));
		continue;
	end
	[Found, CellLocations] = ismember(CommonCells, uint64(SeedTask.CellUIDs));
	assert(all(Found));
	Tests = repmat(struct('Name', "", 'preTe', [], 'postTe', [], 'XTeT', [], 'TrialUIDs', uint64([])), 3, 1);
	for ContextIndex = 1:2
		Raw = RawTests{ContextIndex};
		Raw = Raw(ismember(uint64(Raw.CellUID), CommonCells), :);
		TrialUIDs = unique(uint64(Raw.TrialUID));
		assert(isempty(intersect(uint64(SeedTask.TrainTrialUIDs), TrialUIDs)), 'NaiveAudioContexts:TrialLeakage', '训练回合与外部测试回合发生重叠。');
		X = TransferLearning.BuildTrialMatrix(Raw, CommonCells);
		assert(~isempty(X) && size(X, 1) == numel(TrialUIDs));
		if PostDuration == 1
			Smoothed = LocalMean(X(:, :, TimeIndices), Radius);
		else
			Smoothed = LocalMean(X, Radius);
			Smoothed = Smoothed(:, :, TimeIndices);
		end
		Tests(ContextIndex) = struct('Name', TestSpecs(ContextIndex, 3), 'preTe', mean(X(:, :, PreFeatureMask), 3), 'postTe', mean(X(:, :, PostFeatureMask), 3), 'XTeT', Smoothed, 'TrialUIDs', TrialUIDs);
	end
	assert(isempty(intersect(uint64(SeedTask.TrainTrialUIDs), uint64(SeedTask.TestTrialUIDs))), 'NaiveAudioContexts:TrialLeakage', '训练回合与迁移测试回合发生重叠。');
	Tests(3) = struct('Name', TestSpecs(3, 3), 'preTe', SeedTask.preTe(:, CellLocations), 'postTe', SeedTask.postTe(:, CellLocations), 'XTeT', SeedTask.XTeT(:, CellLocations, :), 'TrialUIDs', uint64(SeedTask.TestTrialUIDs));
	Tasks{end + 1, 1} = struct('DS', 1, 'Mouse', SeedTask.Mouse, 'NCells', numel(CommonCells), 'CellUIDs', CommonCells, 'preTr', SeedTask.preTr(:, CellLocations), 'postTr', SeedTask.postTr(:, CellLocations), 'XTrT', SeedTask.XTrT(:, CellLocations, :), 'Tests', Tests, 'TrainTrialUIDs', uint64(SeedTask.TrainTrialUIDs));
end
assert(numel(Tasks) >= 3, 'NaiveAudioContexts:NoTasks', '情境齐全且有足够共同细胞的鼠不足3只。');
S = struct('Version', CacheVersion, 'PostDuration', PostDuration, 'PreDuration', 1, 'HalfWindow', HalfWindow, 'NPermutation', NPermutation, 'Time', Time, 'FeaturePreTimes', Xs(PreFeatureMask), 'FeaturePostTimes', Xs(PostFeatureMask), 'TestSpecs', TestSpecs, 'Tasks', {Tasks}, 'Results', {cell(numel(Tasks), 1)}, 'CachePath', MatPath, 'TrainContext', TrainContext);
S = DecodeFourContexts(S);
end

function Tasks = UseLearnedTraining(SourceTasks)
Tasks = SourceTasks;
for TaskIndex = 1:numel(SourceTasks)
	Source = SourceTasks{TaskIndex};
	Learned = Source.Tests(2);
	assert(string(Learned.Name) == "LearnedAudioWater" && size(Learned.preTe, 1) >= 5, 'NaiveAudioContexts:WrongTrainingContext', '缓存中Learned声水训练情境不完整。');
	Task = Source;
	Task.preTr = Learned.preTe;
	Task.postTr = Learned.postTe;
	Task.XTrT = Learned.XTeT;
	Task.TrainTrialUIDs = Learned.TrialUIDs;
	Task.Tests(1) = struct('Name', "NaiveAudioOnly", 'preTe', Source.preTr, 'postTe', Source.postTr, 'XTeT', Source.XTrT, 'TrialUIDs', Source.TrainTrialUIDs);
	Task.Tests(2) = Source.Tests(1);
	Task.Tests(3) = Source.Tests(3);
	for TestIndex = 1:3
		assert(isempty(intersect(uint64(Task.TrainTrialUIDs), uint64(Task.Tests(TestIndex).TrialUIDs))), 'NaiveAudioContexts:TrialLeakage', 'Learned声水训练回合与外部测试回合发生重叠。');
	end
	Tasks{TaskIndex} = Task;
end
end

function S = DecodeFourContexts(S)
Tasks = S.Tasks;
Time = S.Time;
PostDuration = S.PostDuration;
NPermutation = S.NPermutation;
Results = cell(numel(Tasks), 1);
WorkerLimit = 0;
Pool = gcp('nocreate');
if ~isempty(Pool)
	WorkerLimit = min(Pool.NumWorkers, 8);
end
parfor (TaskIndex = 1:numel(Tasks), WorkerLimit)
	fprintf('四情境解码，后段%.1f s：%d/%d，%s，%d细胞。\n', PostDuration, TaskIndex, numel(Tasks), Tasks{TaskIndex}.Mouse, Tasks{TaskIndex}.NCells);
	rng(42 + TaskIndex, 'twister');
	Results{TaskIndex} = TransferLearning.DecodeCuePrePostTransfer(Tasks{TaskIndex}, Time(:)', NPermutation);
end
S.Results = Results;
save(S.CachePath, '-struct', 'S');
fprintf('四情境缓存已保存：%s\n', S.CachePath);
end

function Y = LocalMean(X, Radius)
Y = zeros(size(X));
for TimeIndex = 1:size(X, 3)
	Indices = max(1, TimeIndex - Radius):min(size(X, 3), TimeIndex + Radius);
	Y(:, :, TimeIndex) = mean(X(:, :, Indices), 3);
end
end

function P = SignedRankP(Values)
if all(Values == 0)
	P = 1;
else
	P = signrank(Values, 0, 'method', 'exact');
end
end

function Adjusted = HolmAdjust(P)
[Sorted, Order] = sort(P);
Adjusted = nan(size(P));
Adjusted(Order) = min(cummax((numel(P):-1:1)' .* Sorted), 1);
end

function [Fig, CurveAxes, DeltaAx, SvgPath] = PlotContexts(Time, Curves, Delta, ContextLabels, PostDuration, FriedmanP, TrainContext)
Colors = [TransferLearning.CurveNaive; TransferLearning.CurveNaive; TransferLearning.CurveLearned; TransferLearning.Curve12h] / 255;
if TrainContext == "LearnedAudioWater"
	Colors = [TransferLearning.CurveLearned; TransferLearning.CurveNaive; TransferLearning.CurveNaive; TransferLearning.Curve12h] / 255;
end
Fig = figure('Color', 'w', 'Name', sprintf('%s解码器四情境，后段%.1f s', TrainContext, PostDuration));
Fig.Units = 'centimeters';
Fig.Position(3:4) = [12, 8];
Layout = tiledlayout(Fig, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
CurveLayout = tiledlayout(Layout, 1, 4, 'TileSpacing', 'tight', 'Padding', 'tight');
CurveLayout.Layout.Tile = 1;
CurveAxes = gobjects(1, 4);
for ContextIndex = 1:4
	Ax = nexttile(CurveLayout, ContextIndex);
	hold(Ax, 'on');
	MeanCurve = mean(Curves{ContextIndex}, 1);
	SEMCurve = std(Curves{ContextIndex}, 0, 1) / sqrt(size(Delta, 1));
	fill(Ax, [Time, fliplr(Time)], [MeanCurve + SEMCurve, fliplr(MeanCurve - SEMCurve)], Colors(ContextIndex, :), 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
	plot(Ax, Time, MeanCurve, 'Color', Colors(ContextIndex, :), 'LineWidth', 1.2);
	yline(Ax, 0.5, ':', 'Color', [0.75, 0.75, 0.75], 'HandleVisibility', 'off');
	xline(Ax, 0, '--', 'Color', [0.35, 0.35, 0.35], 'HandleVisibility', 'off');
	TitleLabel = replace(ContextLabels(ContextIndex), " (OOF)", string(newline) + "(OOF)");
	title(Ax, TitleLabel, 'FontWeight', 'normal');
	if ContextIndex > 1
		Ax.YAxis.Visible = 'off';
	end
	box(Ax, 'off');
	legend(Ax, 'off');
	CurveAxes(ContextIndex) = Ax;
end
xlabel(CurveLayout, 'Time from cue onset (s)');
ylabel(CurveLayout, 'P(post)');
DeltaAx = nexttile(Layout, 2);
hold(DeltaAx, 'on');
plot(DeltaAx, 1:4, Delta', '-', 'Color', [0.8, 0.8, 0.8], 'LineWidth', 0.4, 'HandleVisibility', 'off');
for ContextIndex = 1:4
	scatter(DeltaAx, repmat(ContextIndex, size(Delta, 1), 1), Delta(:, ContextIndex), 8, Colors(ContextIndex, :), 'filled', 'HandleVisibility', 'off');
	errorbar(DeltaAx, ContextIndex, mean(Delta(:, ContextIndex)), std(Delta(:, ContextIndex)) / sqrt(size(Delta, 1)), 'o', 'Color', Colors(ContextIndex, :), 'MarkerFaceColor', Colors(ContextIndex, :), 'MarkerSize', 4, 'LineWidth', 1.2, 'HandleVisibility', 'off');
end
yline(DeltaAx, 0, ':', 'Color', [0.6, 0.6, 0.6], 'HandleVisibility', 'off');
xticks(DeltaAx, 1:4);
xticklabels(DeltaAx, replace(ContextLabels, " (OOF)", ""));
ylabel(DeltaAx, 'ΔP(post)');
title(DeltaAx, sprintf('Friedman p = %.4g, n = %d', FriedmanP, size(Delta, 1)), 'FontWeight', 'normal');
box(DeltaAx, 'off');
legend(DeltaAx, 'off');
TransferLearning.ApplyStandardExportStyle(Fig, 2);
MATLAB.Graphics.UnifyAxesLims(CurveAxes, @xlim, @ylim);
SvgPath = TransferLearning.StandardFigureSvgPath(sprintf('English_Fig3_%s_FourContexts_Post%dms.svg', TrainContext, round(1000 * PostDuration)));
print(Fig, SvgPath, '-dsvg');
fprintf('四情境图已导出：%s\n', SvgPath);
end