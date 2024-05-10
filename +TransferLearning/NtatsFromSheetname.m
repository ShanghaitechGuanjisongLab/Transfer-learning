function GroupNtats = NtatsFromSheetname(SheetName,Update)
arguments
	SheetName
	Update=false
end
persistent NtatsDictionary
if isempty(NtatsDictionary)
	NtatsDictionary=dictionary;
end
if Update
	GroupNtats=UncachedQuery(SheetName);
	NtatsDictionary{SheetName}=GroupNtats;
else
	try
		GroupNtats=NtatsDictionary{SheetName};
	catch ME
		if any(ME.identifier==["MATLAB:dictionary:UnconfiguredLookupNotSupported","MATLAB:dictionary:ScalarKeyNotFound"])
			GroupNtats=UncachedQuery(SheetName);
			NtatsDictionary{SheetName}=GroupNtats;
		else
			ME.rethrow;
		end
	end
end
end
function GroupNtats=UncachedQuery(SheetName)
GroupNtats=TransferLearning.FullCalcium().QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),SheetName),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median);
try
	GroupNtats=UniExp.NtatsCellReplenish(GroupNtats);
catch ME
	if ME.identifier~="UniExp:Exceptions:No_need_to_replenish"
		ME.rethrow;
	end
end
end