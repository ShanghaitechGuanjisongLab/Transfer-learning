function Table = SortByCell(Table,CellUID)
[~,CellUID]=ismember(CellUID,Table.CellUID);
Table=Table(CellUID,:);