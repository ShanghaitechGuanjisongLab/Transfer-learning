function Result = ComputeDivergenceWithoutLearnedActive()
%COMPUTEDIVERGENCEWITHOUTLEARNEDACTIVE 比较12 h Transfer剔除Learned活跃细胞前后的逐鼠相对散度。
% 活跃判定沿用中文Fig45E：每细胞Learned跨trial均值响应在cue+1 s超过基线均值+3SD。
% Transfer与Learned均按cue时刻零锚，保留完整trial的细胞；剔除只发生在Transfer光水侧。
DS = TransferLearning.AudioLightBaseline();
Xs = seconds(TransferLearning.Xs);
[~, IndexZero] = min(abs(Xs));
[~, IndexOne] = min(abs(Xs - 1));
BaseMask = Xs >= -3 & Xs < 0;
Layers = ["MOp2/3"; "MOp5"];
CellMap = DS.Cells(:, {'CellUID', 'ZLayer'});
CellMap.CellUID = uint64(CellMap.CellUID);
CellMap.ZLayer = string(CellMap.ZLayer);

TTransfer = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TLearned = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TTransfer.Mouse = string(TTransfer.Mouse);
TLearned.Mouse = string(TLearned.Mouse);
TTransfer.DateTime = iNormalizeDateTime(TTransfer.DateTime);
TLearned.DateTime = iNormalizeDateTime(TLearned.DateTime);
Mice = intersect(unique(TTransfer.Mouse), unique(TLearned.Mouse));
Rows = table();
for MouseIndex = 1:numel(Mice)
	Mouse = Mice(MouseIndex);
	TransferMeta = TTransfer(TTransfer.Mouse == Mouse, :);
	LearnedMeta = TLearned(TLearned.Mouse == Mouse, :);
	TransferDate = min(TransferMeta.DateTime);
	LearnedDate = max(LearnedMeta.DateTime);
	TransferTrials = unique(uint64(sortrows(TransferMeta(TransferMeta.DateTime == TransferDate, :), 'TrialIndex').TrialUID), 'stable');
	LearnedTrials = unique(uint64(sortrows(LearnedMeta(LearnedMeta.DateTime == LearnedDate, :), 'TrialIndex').TrialUID), 'stable');
	if numel(TransferTrials) < 2 || numel(LearnedTrials) < 2
		continue;
	end
	NtsTransfer = iQueryOne(DS, struct('Mouse', Mouse, 'DateTime', TransferDate, 'Stimulus', "LightWater"));
	NtsLearned = iQueryOne(DS, struct('Mouse', Mouse, 'DateTime', LearnedDate, 'Stimulus', "AudioWater"));
	if isempty(NtsTransfer) || isempty(NtsLearned)
		continue;
	end
	[CttTransfer, UidTransfer] = iBuildCtt(NtsTransfer, TransferTrials, IndexZero);
	[CttLearned, UidLearned] = iBuildCtt(NtsLearned, LearnedTrials, IndexZero);
	if isempty(CttTransfer) || isempty(CttLearned)
		continue;
	end
	LearnedMean = squeeze(mean(CttLearned, 2, 'omitnan'));
	BaseMu = mean(LearnedMean(:, BaseMask), 2, 'omitnan');
	BaseSd = std(LearnedMean(:, BaseMask), 0, 2, 'omitnan');
	LearnedActive = isfinite(LearnedMean(:, IndexOne)) & isfinite(BaseMu) & isfinite(BaseSd) & (LearnedMean(:, IndexOne) > BaseMu + 3*BaseSd);
	ActiveUIDs = UidLearned(LearnedActive);
	[HasLayer, LayerIndices] = ismember(UidTransfer, CellMap.CellUID);
	TransferLayers = strings(numel(UidTransfer), 1);
	TransferLayers(HasLayer) = CellMap.ZLayer(LayerIndices(HasLayer));
	IsActive = ismember(UidTransfer, ActiveUIDs);
	AtOne = CttTransfer(:, :, IndexOne);
	for LayerIndex = 1:numel(Layers)
		Layer = Layers(LayerIndex);
		InLayer = TransferLayers == Layer;
		NAll = nnz(InLayer);
		NActive = nnz(InLayer & IsActive);
		NRemoved = nnz(InLayer & ~IsActive);
		if NAll < 3 || NActive < 3 || NRemoved < 3
			continue;
		end
		[DivFull, NoiseFull, SignalFull] = iRelativeDivergence(AtOne(InLayer, :));
		[DivRemoved, NoiseRemoved, SignalRemoved] = iRelativeDivergence(AtOne(InLayer & ~IsActive, :));
		[DivActive, NoiseActive, SignalActive] = iRelativeDivergence(AtOne(InLayer & IsActive, :));
		NewRow = table(Mouse, TransferDate, LearnedDate, Layer, DivFull, DivRemoved, DivActive, NAll, NActive, NRemoved, NoiseFull, SignalFull, NoiseRemoved, SignalRemoved, NoiseActive, SignalActive, VariableNames=["Mouse", "DateTimeTransfer", "DateTimeLearned", "Layer", "DivFull", "DivRemoved", "DivActive", "NAll", "NActive", "NRemoved", "NoiseFull", "SignalFull", "NoiseRemoved", "SignalRemoved", "NoiseActive", "SignalActive"]);
		Rows = [Rows; NewRow]; %#ok<AGROW>
	end
end
Stats = table();
for LayerIndex = 1:numel(Layers)+1
	if LayerIndex <= numel(Layers)
		Layer = Layers(LayerIndex);
		R = Rows(Rows.Layer == Layer, :);
	else
		Layer = "All";
		R = table();
		for MouseIndex = 1:numel(Mice)
			MouseRows = Rows(Rows.Mouse == Mice(MouseIndex), :);
			if height(MouseRows) ~= numel(Layers)
				continue;
			end
			CombinedRow = MouseRows(1, :);
			CombinedRow.Layer = Layer;
			PowerVariables = ["NoiseFull", "SignalFull", "NoiseRemoved", "SignalRemoved", "NoiseActive", "SignalActive"];
			CombinedRow{:, PowerVariables} = sum(MouseRows{:, PowerVariables}, 1);
			CombinedRow.NAll = sum(MouseRows.NAll);
			CombinedRow.NActive = sum(MouseRows.NActive);
			CombinedRow.NRemoved = sum(MouseRows.NRemoved);
			CombinedRow.DivFull = sqrt(CombinedRow.NoiseFull / CombinedRow.SignalFull);
			CombinedRow.DivRemoved = sqrt(CombinedRow.NoiseRemoved / CombinedRow.SignalRemoved);
			CombinedRow.DivActive = sqrt(CombinedRow.NoiseActive / CombinedRow.SignalActive);
			R = [R; CombinedRow]; %#ok<AGROW>
		end
	end
	Valid = isfinite(R.DivFull) & isfinite(R.DivRemoved) & isfinite(R.DivActive);
	R = R(Valid, :);
	PValue = signrank(R.DivFull, R.DivRemoved);
	PActiveRemoved = signrank(R.DivActive, R.DivRemoved);
	MeanReduction = mean((R.DivFull - R.DivRemoved) ./ R.DivFull);
	NewStat = table(Layer, height(R), PValue, PActiveRemoved, mean(R.DivFull), mean(R.DivRemoved), mean(R.DivActive), MeanReduction, median((R.DivFull - R.DivRemoved) ./ R.DivFull), nnz(R.DivRemoved < R.DivFull), nnz(R.DivRemoved > R.DivFull), nnz(R.DivRemoved == R.DivFull), sum(R.NActive), sum(R.NRemoved), sum(R.NoiseFull)/sum(R.SignalFull), sum(R.NoiseRemoved)/sum(R.SignalRemoved), sum(R.NoiseActive)/sum(R.SignalActive), VariableNames=["Layer", "NMouse", "PValueSignrank", "PActiveVsRemovedSignrank", "MeanFull", "MeanRemoved", "MeanActive", "MeanRelativeReduction", "MedianRelativeReduction", "NDecrease", "NIncrease", "NSame", "NActiveTotal", "NRemovedTotal", "PooledD2Full", "PooledD2Removed", "PooledD2Active"]);
	Stats = [Stats; NewStat]; %#ok<AGROW>
end
Result = struct('Rows', Rows, 'Stats', Stats, 'Dataset', "AudioLightBaseline", 'Selection', "earliest Transfer LightWater and latest Learned AudioWater", 'ActiveThreshold', "mean trial response at cue+1 s > baseline mean+3SD", 'IndexZero', IndexZero, 'IndexOne', IndexOne);
assignin('base', 'TransferDivergenceActiveRemoval', Result);
disp(Stats);
end

function Nts = iQueryOne(DS, Query)
Raw = DS.QueryNTS(Query, UniExp.Flags.ZScore, 1:24);
if iscell(Raw)
	Parts = Raw(~cellfun(@isempty, Raw));
	if isempty(Parts)
		Nts = table();
	else
		Nts = vertcat(Parts{:});
	end
else
	Nts = Raw;
end
end

function [Ctt, CellUIDs] = iBuildCtt(Nts, TrialUIDs, IndexZero)
Ctt = [];
CellUIDs = uint64([]);
Nts = Nts(ismember(uint64(Nts.TrialUID), TrialUIDs), :);
TrialUIDs = TrialUIDs(ismember(TrialUIDs, unique(uint64(Nts.TrialUID), 'stable')));
if numel(TrialUIDs) < 2
	return;
end
AllCells = unique(uint64(Nts.CellUID), 'stable');
TraceCell = cell(numel(AllCells), 1);
KeepUID = zeros(numel(AllCells), 1, 'uint64');
NKeep = 0;
for CellIndex = 1:numel(AllCells)
	CellID = AllCells(CellIndex);
	Rows = uint64(Nts.CellUID) == CellID;
	UIDs = uint64(Nts.TrialUID(Rows));
	Signals = double(Nts.TrialSignal(Rows, :));
	[Found, Locations] = ismember(TrialUIDs, UIDs);
	if ~all(Found)
		continue;
	end
	Ordered = Signals(Locations, :);
	if any(~isfinite(Ordered), 'all')
		continue;
	end
	NKeep = NKeep + 1;
	TraceCell{NKeep} = Ordered;
	KeepUID(NKeep) = CellID;
end
if NKeep < 1
	return;
end
TraceCell = TraceCell(1:NKeep);
KeepUID = KeepUID(1:NKeep);
Ctt = nan(NKeep, numel(TrialUIDs), size(TraceCell{1}, 2));
for CellIndex = 1:NKeep
	Ctt(CellIndex, :, :) = reshape(TraceCell{CellIndex}, 1, numel(TrialUIDs), size(TraceCell{1}, 2));
end
Ctt = Ctt - Ctt(:, :, IndexZero);
CellUIDs = KeepUID;
end

function [Div, NoisePower, SignalPower] = iRelativeDivergence(X)
SignalPower = sum(mean(X, 2, 'omitnan').^2, 'omitnan');
NoisePower = sum(var(X, 0, 2, 'omitnan'), 'omitnan');
if size(X, 1) < 3 || size(X, 2) < 2 || SignalPower <= 0 || ~isfinite(SignalPower) || ~isfinite(NoisePower)
	Div = NaN;
else
	Div = sqrt(NoisePower / SignalPower);
end
end

function DateTimeValue = iNormalizeDateTime(DateTimeValue)
DateTimeValue = datetime(DateTimeValue);
if ~isempty(DateTimeValue.TimeZone)
	DateTimeValue.TimeZone = '';
end
end
