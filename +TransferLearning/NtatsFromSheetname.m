function GroupNtats = NtatsFromSheetname(SheetName,Update)
arguments
	SheetName
	Update=false
end
ImplMemoize=memoize(@Impl);
if Update
	ImplMemoize.clearCache;
end
GroupNtats=ImplMemoize(SheetName);
end
function GroupNtats=Impl(SheetName)
GroupNtats=TransferLearning.FullCalcium().QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),SheetName),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median);
try
	GroupNtats=UniExp.NtatsCellReplenish(GroupNtats);
catch ME
	if ME.identifier~="UniExp:Exceptions:No_need_to_replenish"
		ME.rethrow;
	end
end
end