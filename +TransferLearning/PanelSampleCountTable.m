function CountTable = PanelSampleCountTable(SourceTable, PanelNames, RowMaskByPanel, CellMeta)
% Build per-panel unique mouse and cell counts from row masks aligned to SourceTable.
if nargin < 4
	CellMeta = table();
end
PanelNames = string(PanelNames(:));
if isvector(RowMaskByPanel)
	RowMaskByPanel = RowMaskByPanel(:);
end
if size(RowMaskByPanel, 2) ~= numel(PanelNames)
	error('TransferLearning:PanelSampleCountTable:PanelCountMismatch', 'PanelNames and RowMaskByPanel columns must have the same length.');
end
if istable(SourceTable) && height(SourceTable) ~= size(RowMaskByPanel, 1)
	error('TransferLearning:PanelSampleCountTable:RowCountMismatch', 'SourceTable rows and RowMaskByPanel rows must match.');
end

numPanels = numel(PanelNames);
NMouse = nan(numPanels, 1);
NCell = nan(numPanels, 1);
for panelIndex = 1:numPanels
	rowMask = RowMaskByPanel(:, panelIndex);
	NMouse(panelIndex) = iCountMice(SourceTable, rowMask, CellMeta);
	NCell(panelIndex) = iCountCells(SourceTable, rowMask);
end

CountTable = table(PanelNames, NMouse, NCell, 'VariableNames', {'Panel','NMouse','NCell'});
end

function nMouse = iCountMice(SourceTable, rowMask, CellMeta)
if istable(SourceTable) && ismember('Mouse', SourceTable.Properties.VariableNames)
	mouseValues = string(SourceTable.Mouse(rowMask));
else
	mouseValues = iLookupMouseByCell(SourceTable, rowMask, CellMeta);
end
if isempty(mouseValues)
	nMouse = NaN;
	return;
end
mouseValues = mouseValues(~ismissing(mouseValues) & strlength(mouseValues) > 0);
nMouse = numel(unique(mouseValues));
end

function mouseValues = iLookupMouseByCell(SourceTable, rowMask, CellMeta)
mouseValues = strings(0, 1);
if ~istable(SourceTable) || ~ismember('CellUID', SourceTable.Properties.VariableNames)
	return;
end
if ~istable(CellMeta) || ~all(ismember({'CellUID','Mouse'}, CellMeta.Properties.VariableNames))
	return;
end
cellMap = CellMeta(:, {'CellUID','Mouse'});
cellMap.CellUID = uint64(cellMap.CellUID);
selectedCellIds = uint64(SourceTable.CellUID(rowMask));
[matched, loc] = ismember(selectedCellIds, cellMap.CellUID);
mouseValues = strings(numel(selectedCellIds), 1);
mouseValues(matched) = string(cellMap.Mouse(loc(matched)));
end

function nCell = iCountCells(SourceTable, rowMask)
if istable(SourceTable) && ismember('CellUID', SourceTable.Properties.VariableNames)
	cellIds = SourceTable.CellUID(rowMask);
	nCell = numel(unique(cellIds));
else
	nCell = nnz(rowMask);
end
end