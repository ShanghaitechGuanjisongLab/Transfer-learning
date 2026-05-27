function Counts = StateSpaceUsageCounts(Data)
arguments
	Data struct
end

mouseStates = Data.MouseStates(:);
Counts = struct();
Counts.Representative = iRepresentativeCounts(Data, mouseStates);
Counts.Layer = iLayerCounts(Data, mouseStates);
end

function T = iRepresentativeCounts(Data, mouseStates)
representativeGroups = ["Naive", "Transfer"];
groupLabels = ["Naive", "Continual"];
representatives = [Data.Representative.NaiveCell, Data.Representative.TransferCell];

T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), ...
	'VariableNames', {'Panel','Group','GroupLabel','Mouse','Source','NMouse','NCell'});
for groupIndex = 1:numel(representativeGroups)
	rep = representatives(groupIndex);
	stateIndex = iFindMouseState(mouseStates, rep.Mouse, rep.Source);
	T = [T; table("C", representativeGroups(groupIndex), groupLabels(groupIndex), string(rep.Mouse), string(rep.Source), 1, numel(mouseStates(stateIndex).CellUID), ...
		'VariableNames', T.Properties.VariableNames)]; %#ok<AGROW>
end
end

function T = iLayerCounts(Data, mouseStates)
groupNames = ["Naive", "Transfer"];
groupLabels = ["Naive", "Continual"];
layerNames = ["MOp2/3", "MOp5"];

T = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), ...
	'VariableNames', {'Panel','ZLayer','Group','GroupLabel','NMouse','NCell'});
for layerIndex = 1:numel(layerNames)
	layerName = layerNames(layerIndex);
	for groupIndex = 1:numel(groupNames)
		groupName = groupNames(groupIndex);
		metricRows = Data.Metrics(Data.Metrics.Group == groupName & Data.Metrics.ZLayer == layerName, :);
		nMouse = numel(unique(metricRows.Mouse));
		nCell = iCountMetricCells(mouseStates, metricRows, layerName);
		T = [T; table("D-F", layerName, groupName, groupLabels(groupIndex), nMouse, nCell, 'VariableNames', T.Properties.VariableNames)]; %#ok<AGROW>
	end
end
end

function nCell = iCountMetricCells(mouseStates, metricRows, layerName)
nCell = 0;
for rowIndex = 1:height(metricRows)
	stateIndex = iFindMouseState(mouseStates, metricRows.Mouse(rowIndex), metricRows.Source(rowIndex));
	nCell = nCell + nnz(mouseStates(stateIndex).Layers == layerName);
end
end

function stateIndex = iFindMouseState(mouseStates, mouseName, sourceName)
stateIndex = find(string({mouseStates.Mouse})' == string(mouseName) & string({mouseStates.Source})' == string(sourceName), 1, 'first');
if isempty(stateIndex)
	error('Fig341:MissingMouseStateForCounts', 'Cannot find MouseStates row for mouse %s, source %s.', string(mouseName), string(sourceName));
end
end
