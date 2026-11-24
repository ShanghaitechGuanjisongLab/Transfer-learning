% 英文图2E：learned-active细胞的base/cued cue解码权重及reactivated子群堆叠直方图。
% 左为AudioLightBaseline，右为Vacation7；两者均使用原Learned声水1 s LASSO缓存的全部可用鼠。
% 负系数支持base判别，正系数支持cued判别；零系数画在以0为中心的分箱，不归入任一权重组。
% 配色按语义：learned-active=ColorLearned（学会），reactivated=各队列迁移时点色（12 h=Color12h，7 d=Color7d）。
% 活跃与重激活判定保持原定义：末次非Recall声水和首次Transfer光水，+1 s处高于基线均值加3σ。
% 每柱内reactivated堆底，learned-active且未reactivated堆顶，不显示其他细胞；纵轴按队列内learned-active总数归一为占比。

[ThisDir, Filename] = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	PrjFile = fullfile(ThisDir, '..', 'Transferlearning.prj');
	if exist(PrjFile, 'file')
		matlab.project.loadProject(PrjFile);
	end
end

%% 计算
CueData = TransferLearning.LoadLearnedCueDecoderWeights();
Xs = seconds(TransferLearning.Xs);
BaseMask = Xs >= -3 & Xs < 0;
[~, Index1s] = min(abs(Xs - 1));
KSigma = 3;
Datasets = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
WeightsByCohort = cell(2, 1);
SummaryRows = cell(2, 1);
for DatasetIndex = 1:2
	DS = Datasets{DatasetIndex};
	Models = CueData.Cohorts{DatasetIndex};
	WeightParts = cell(numel(Models), 1);
	GroupParts = cell(numel(Models), 1);
	MouseParts = cell(numel(Models), 1);
	UIDParts = cell(numel(Models), 1);
	for MouseIndex = 1:numel(Models)
		Model = Models{MouseIndex};
		[Groups, Valid] = GroupForMouse(DS, Model.Mouse, Model.CellUIDs, BaseMask, Index1s, KSigma);
		assert(Valid, 'Fig2E:MissingContext', '%s缺少Learned或Transfer活跃判定情境。', Model.Mouse);
		WeightParts{MouseIndex} = Model.Weights(:);
		GroupParts{MouseIndex} = Groups(:);
		MouseParts{MouseIndex} = repmat(string(Model.Mouse), Model.NCells, 1);
		UIDParts{MouseIndex} = Model.CellUIDs(:);
	end
	Weights = struct( ...
		'Weights', vertcat(WeightParts{:}), ...
		'Group', vertcat(GroupParts{:}), ...
		'Mouse', vertcat(MouseParts{:}), ...
		'CellUIDs', vertcat(UIDParts{:}));
	WeightsByCohort{DatasetIndex} = Weights;
	SummaryRows{DatasetIndex} = table(CueData.DatasetNames(DatasetIndex), numel(Models), numel(Weights.Weights), nnz(Weights.Group >= 1), nnz(Weights.Group == 2), nnz(Weights.Group >= 1 & Weights.Weights < 0), nnz(Weights.Group >= 1 & Weights.Weights > 0), nnz(Weights.Group >= 1 & Weights.Weights == 0), 'VariableNames', {'Dataset', 'NMice', 'NDecoderCells', 'NLearnedActive', 'NReactivated', 'NBaseWeighted', 'NCuedWeighted', 'NZeroLearnedActive'});
end
GroupSummary = vertcat(SummaryRows{:});

%% 作图
% 分箱边界取(整数+0.5)×BinWidth，使0恰为箱中心：零权重落在中心箱，不会被划入base或cued侧。
DisplayedWeights = cellfun(@(W) W.Weights(W.Group >= 1), WeightsByCohort, 'UniformOutput', false);
[MinWeight, MaxWeight] = bounds(vertcat(DisplayedWeights{:}));
BinWidth = (MaxWeight - MinWeight) / 40;
FirstEdgeIndex = floor(MinWeight / BinWidth - 0.5);
LastEdgeIndex = ceil(MaxWeight / BinWidth - 0.5);
Edges = ((FirstEdgeIndex:LastEdgeIndex) + 0.5) * BinWidth;
BinCenters = Edges(1:end - 1) + diff(Edges) / 2;
Fig = figure('Color', 'w', 'Name', '英文图2E：base/cued cue权重与重激活子群');
Fig.Units = 'centimeters';
Fig.Position(3:4) = [9, 8];
Layout = tiledlayout(Fig, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
Titles = ["🔊→12h→💡", "🔊→7d→💡"];
ColorReact = [TransferLearning.Color12h; TransferLearning.Color7d] / 255;
ColorLearnedActive = TransferLearning.ColorLearned / 255;
CountsByCohort = cell(2, 1);
Axes = gobjects(1, 2);
Bars = cell(2, 1);
for DatasetIndex = 1:2
	Weights = WeightsByCohort{DatasetIndex};
	Ax = nexttile(Layout);
	hold(Ax, 'on');
	CountsReact = histcounts(Weights.Weights(Weights.Group == 2), Edges);
	CountsLearnedActive = histcounts(Weights.Weights(Weights.Group == 1), Edges);
	Counts = [CountsReact(:), CountsLearnedActive(:)];
	TotalCells = sum(Counts, 'all');
	assert(TotalCells > 0, 'Fig2E:EmptyCohort', '%s没有learned-active细胞。', Titles(DatasetIndex));
	Counts = Counts / TotalCells;
	Handles = bar(Ax, BinCenters, Counts, 1, 'stacked', 'EdgeColor', 'none');
	Handles(1).FaceColor = ColorReact(DatasetIndex, :);
	Handles(2).FaceColor = ColorLearnedActive;
	xline(Ax, 0, ':', 'HandleVisibility', 'off');
	box(Ax, 'off');
	title(Ax, Titles(DatasetIndex));
	if DatasetIndex == 1
		DummyReact7d = bar(Ax, NaN, NaN, FaceColor=ColorReact(2, :), EdgeColor='none');
		L = legend(Ax, [Handles(1), DummyReact7d, Handles(2)], {'reactivated (12h)', 'reactivated (7d)', 'learned-active'}, Box='off', Orientation='horizontal');
		L.Layout.Tile = 'north';
	end
	CountsByCohort{DatasetIndex} = Counts;
	Axes(DatasetIndex) = Ax;
	Bars{DatasetIndex} = Handles;
end
xlabel(Layout, 'Decoder weight (base < 0; cued > 0)');
ylabel(Layout, 'Cell fraction');
SvgPath = TransferLearning.ExportStandardFigure(Fig, 2, sprintf('English_%s.svg', Filename));

function [Groups, Valid] = GroupForMouse(DS, Mouse, CellUIDs, BaseMask, Index1s, KSigma)
Groups = zeros(numel(CellUIDs), 1);
Valid = false;
Metadata = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
Metadata.Mouse = string(Metadata.Mouse);
Metadata.Stimulus = string(Metadata.Stimulus);
Metadata.Phase = string(Metadata.Phase);
Metadata.DateTime = datetime(Metadata.DateTime);
MouseRows = Metadata(Metadata.Mouse == Mouse, :);
AudioWater = MouseRows(MouseRows.Stimulus == "AudioWater" & MouseRows.Phase ~= "Recall", :);
LightWater = MouseRows(MouseRows.Stimulus == "LightWater" & MouseRows.Phase == "Transfer", :);
if isempty(AudioWater) || isempty(LightWater)
	return;
end
LearnedDate = max(AudioWater.DateTime);
TransferDate = min(LightWater.DateTime);
Learned = DS.QueryNTATS(struct('Mouse', Mouse, 'Stimulus', "AudioWater", 'DateTime', LearnedDate), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
Transfer = DS.QueryNTATS(struct('Mouse', Mouse, 'Stimulus', "LightWater", 'DateTime', TransferDate), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
ActiveLearned = ActiveFromNtats(Learned, BaseMask, Index1s, KSigma);
ActiveTransfer = ActiveFromNtats(Transfer, BaseMask, Index1s, KSigma);
Reactivated = intersect(ActiveLearned, ActiveTransfer);
LearnedOnly = setdiff(ActiveLearned, Reactivated);
Groups(ismember(CellUIDs, LearnedOnly)) = 1;
Groups(ismember(CellUIDs, Reactivated)) = 2;
Valid = true;
end

function IDs = ActiveFromNtats(Group, BaseMask, Index1s, KSigma)
IDs = uint64([]);
if isempty(Group)
	return;
end
Stripped = UniExp.NtatsCellStrip(struct('Q', Group));
NTATS = Stripped.NTATS;
try
	X = NTATS.Data.Data;
catch
	X = NTATS{:,:,:}.Data;
end
if size(X, 3) > 1
	MeanTrace = squeeze(X(:, :, 1));
else
	MeanTrace = squeeze(X);
end
BaseMean = mean(MeanTrace(:, BaseMask), 2, 'omitnan');
BaseSD = std(MeanTrace(:, BaseMask), 0, 2, 'omitnan');
Response = MeanTrace(:, Index1s);
IsActive = isfinite(Response) & isfinite(BaseMean) & isfinite(BaseSD) & Response > BaseMean + KSigma * BaseSD;
IDs = uint64(Stripped.CellUID(IsActive));
end
