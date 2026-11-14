% 英文图3E：learned-active细胞的base/cued cue解码权重及reactivated子群堆叠直方图。
% 左为AudioLightBaseline，右为Vacation7；两者均使用原Learned声水1 s LASSO缓存的全部可用鼠。
% 负系数支持base判别，正系数支持cued判别；零系数单独记录，不归入任一权重组。
% 活跃与重激活判定保持原定义：末次非Recall声水和首次Transfer光水，+1 s处高于基线均值加3σ。
% 每柱内reactivated堆底，learned-active且未reactivated堆顶，不显示其他细胞。

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
GroupSummary = table();
for DatasetIndex = 1:2
	DS = Datasets{DatasetIndex};
	Models = CueData.Cohorts{DatasetIndex};
	Weights = struct('Weights', zeros(0, 1), 'Group', zeros(0, 1), 'Mouse', strings(0, 1), 'CellUIDs', uint64([]));
	UsedMice = strings(0, 1);
	for MouseIndex = 1:numel(Models)
		Model = Models{MouseIndex};
		[Groups, Valid] = GroupForMouse(DS, Model.Mouse, Model.CellUIDs, BaseMask, Index1s, KSigma);
		assert(Valid, 'Fig3E:MissingContext', '%s缺少Learned或Transfer活跃判定情境。', Model.Mouse);
		Weights.Weights = [Weights.Weights; Model.Weights];
		Weights.Group = [Weights.Group; Groups];
		Weights.Mouse = [Weights.Mouse; repmat(Model.Mouse, Model.NCells, 1)];
		Weights.CellUIDs = [Weights.CellUIDs; Model.CellUIDs];
		UsedMice(end + 1, 1) = Model.Mouse;
	end
	WeightsByCohort{DatasetIndex} = Weights;
	GroupSummary = [GroupSummary; table(CueData.DatasetNames(DatasetIndex), numel(UsedMice), numel(Weights.Weights), nnz(Weights.Group >= 1), nnz(Weights.Group == 2), nnz(Weights.Group >= 1 & Weights.Weights < 0), nnz(Weights.Group >= 1 & Weights.Weights > 0), nnz(Weights.Group >= 1 & Weights.Weights == 0), 'VariableNames', {'Dataset', 'NMice', 'NDecoderCells', 'NLearnedActive', 'NReactivated', 'NBaseWeighted', 'NCuedWeighted', 'NZeroLearnedActive'})];
end

%% 作图
DisplayedWeights = [];
for DatasetIndex = 1:2
	Weights = WeightsByCohort{DatasetIndex};
	DisplayedWeights = [DisplayedWeights; Weights.Weights(Weights.Group >= 1 & Weights.Weights ~= 0)];
end
MaxWeight = max(abs(DisplayedWeights));
assert(isfinite(MaxWeight) && MaxWeight > 0);
Edges = linspace(-MaxWeight, MaxWeight, 41);
BinCenters = Edges(1:end - 1) + diff(Edges) / 2;
Fig = figure('Color', 'w', 'Name', '英文图3E：base/cued cue权重与重激活子群');
Fig.Units = 'centimeters';
Fig.Position(3:4) = [21, 8];
Layout = tiledlayout(Fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
Titles = ["🔊→12h→💡", "🔊→7d→💡"];
ColorReact = TransferLearning.Color12h / 255;
ColorLearnedActive = TransferLearning.ColorLearned / 255;
CountsByCohort = cell(2, 1);
Axes = gobjects(1, 2);
Bars = cell(2, 1);
for DatasetIndex = 1:2
	Weights = WeightsByCohort{DatasetIndex};
	Ax = nexttile(Layout);
	hold(Ax, 'on');
	CountsReact = histcounts(Weights.Weights(Weights.Group == 2 & Weights.Weights ~= 0), Edges);
	CountsLearnedActive = histcounts(Weights.Weights(Weights.Group == 1 & Weights.Weights ~= 0), Edges);
	Counts = [CountsReact(:), CountsLearnedActive(:)];
	assert(sum(Counts, 'all') == nnz(Weights.Group >= 1 & Weights.Weights ~= 0));
	Handles = bar(Ax, BinCenters, Counts, 1, 'stacked', 'EdgeColor', 'none');
	Handles(1).FaceColor = ColorReact;
	Handles(2).FaceColor = ColorLearnedActive;
	xline(Ax, 0, ':', 'HandleVisibility', 'off');
	box(Ax, 'off');
	title(Ax, Titles(DatasetIndex));
	if DatasetIndex == 1
		legend(Ax, Handles, {'reactivated', 'learned-active'}, 'Box', 'off', 'Location', 'northwest');
	end
	CountsByCohort{DatasetIndex} = Counts;
	Axes(DatasetIndex) = Ax;
	Bars{DatasetIndex} = Handles;
end
xlabel(Layout, 'Cue decoder weight (base < 0; cued > 0)');
ylabel(Layout, 'Cell count');
SvgPath = TransferLearning.ExportStandardFigure(Fig, 2, sprintf('English_%s.svg', Filename));
Fig3E_CueWeightStats = struct('WeightsByCohort', {WeightsByCohort}, 'Summary', GroupSummary, 'Edges', Edges, 'CountsByCohort', {CountsByCohort}, 'SourceCache', CueData.SourceCache, 'WeightType', CueData.WeightType, 'Figure', Fig, 'Axes', Axes, 'Bars', {Bars}, 'SvgPath', SvgPath);
assignin('base', 'Fig3E_CueWeightStats', Fig3E_CueWeightStats);
save(TransferLearning.CachePath('Fig3E_CueWeight_Reactivation_Results.mat'), 'WeightsByCohort', 'GroupSummary', 'Edges', 'CountsByCohort');
disp(GroupSummary);

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
