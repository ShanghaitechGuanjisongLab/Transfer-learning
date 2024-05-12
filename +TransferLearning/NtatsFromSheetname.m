function GroupNtats = NtatsFromSheetname(SheetName,DifferentCells)
arguments
	SheetName
	DifferentCells=TransferLearning.Flags.Different_cells_replenished;
end
ImplMemoize=memoize(@Impl);
GroupNtats=ImplMemoize(SheetName,DifferentCells);
end
function GroupNtats=Impl(SheetName,DifferentCells)
import TransferLearning.*
GroupNtats=FullCalcium().QueryNTATS(UniExp.ReadQueryTable(ProjectPath('查询表.xlsx'),SheetName),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median);
switch DifferentCells
	case Flags.Different_cells_not_handled
	case Flags.Different_cells_replenished
		try
			GroupNtats=UniExp.NtatsCellReplenish(GroupNtats);
		catch ME
			if ME.identifier~="UniExp:Exceptions:No_need_to_replenish"
				ME.rethrow;
			end
		end
	case Flags.Different_cells_stripped
		GroupNtats=UniExp.NtatsCellStrip(GroupNtats);
	otherwise
		Exception.Different_cell_processing_strategies_unknown.Throw;
end
end