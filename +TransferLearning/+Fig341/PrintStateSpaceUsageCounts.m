function PrintStateSpaceUsageCounts(figureLabel, Counts, countSet)
arguments
	figureLabel (1,1) string
	Counts struct
	countSet (1,1) string {mustBeMember(countSet, ["Representative", "Layer"])}
end

switch countSet
	case "Representative"
		iPrintRepresentativeCounts(figureLabel, Counts.Representative);
	case "Layer"
		iPrintLayerCounts(figureLabel, Counts.Layer);
end
end

function iPrintRepresentativeCounts(figureLabel, T)
for rowIndex = 1:height(T)
	fprintf('%s %s representative trajectory: mice n = %d, cells n = %d\n', figureLabel, T.GroupLabel(rowIndex), T.NMouse(rowIndex), T.NCell(rowIndex));
end
end

function iPrintLayerCounts(figureLabel, T)
for rowIndex = 1:height(T)
	fprintf('%s %s %s: mice n = %d, cells n = %d\n', figureLabel, T.ZLayer(rowIndex), T.GroupLabel(rowIndex), T.NMouse(rowIndex), T.NCell(rowIndex));
end
end
