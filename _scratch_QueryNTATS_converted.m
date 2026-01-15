function GroupNtats = QueryNTATS(obj,Query,varargin)
%  QUERYNTATS 使用查询表，查询多组归一化回合累积信号值 (Normalized Trial-Accumulated Trial Signals, NTATS)
% 
% 如果TrialSignals表中包含NormalizedSignal列，将优先从此列取得数据，否则从TrialSignal列取得数据。NormalizedSignal一般从SampleNormalize方法生成，保证所有回合信号长度相同。
%% 语法
%%
% 
%   GroupNtats=obj.QueryNTATS(QueryStruct);
%   %根据查询结构体查询单组NTATS
%   
%   GroupNtats=obj.QueryNTATS(QueryTable);
%   %根据查询表查询多组NTATS
%   
%   GroupNtats=obj.QueryNTATS(___,Normalize,F0Samples);
%   %与上述任意语法组合使用，额外指定归一化操作和基线时间范围
%   
%   GroupNtats=obj.QueryNTATS(___,Accumulate);
%   %与上述任意语法组合使用，额外指定累积方法
%
%% 输入参数
% QueryStruct(1,1)struct，查询结构体，此函数调用TableQuery方法执行表查询，此参数将被直接传递给TableQuery，详见TableQuery文档。
% 
% QueryTable tabular，查询条件，此函数调用TableQuery方法执行表查询，此参数将被直接传递给TableQuery，详见TableQuery文档。特别地，如果使用GroupName设置分组名，不允许有名为“CellUID”的组名。
% 
% Normalize(1,1)UniExp.Flags=UniExp.Flags.No_special_operation，归一化方法，默认不做归一化，可选 
% dFdF0 log2FdF0 ZScore，详见UniExp.F0Normalize的Method参数
% 
% F0Samples(1,:)uint16，用作基线的信号索引。例如采样率为8、回合前2s作为基线时，F0Samples设为1:16。详见UniExp.F0Normalize的F0Index参数
% 
% Accumulate(1,1)UniExp.Flags=UniExp.Flags.Median，回合累积方法，可选：
%% 
% * Mean，算术平均
% * Median，中位数
% * Std，标准差
% * VariationCoefficient，变异系数（标准差除以算术平均）
%% 返回值
% GroupNtats，查询结果。
% 
% 如果各组查询出的细胞群体（CellUID）完全相同或只有一个查询组，将返回table，表的每一行对应一个细胞。包含以下列：
%% 
% * NTATS(:,:,:)MATLAB.DataTypes.NDTable，第2维时间，第3维分组。如果指定了各组名称（GroupName），将会作为第3维的索引。
% * CellUID(:,1)uint16，每个细胞的UID
%% 
% 如果各组查询出的细胞群体不完全相同，将为每组返回一个结果表table。如果指定了各组名称，将返回(1,1)struct，每个字段对应每个组名，字段值是该组的结果表。如果未指定各组名称，将返回(:,1)cell，每个元胞对应一个分组，元胞内是该组的结果表。每组的结果表每行对应一个细胞，均包含以下列：
%% 
% * NTATS(:,:)，第2维时间
% * CellUID(:,1)uint16，每个细胞的UID
%% 
% *See also* <matlab:edit UniExp.Flags UniExp.Flags> <matlab:MATLAB.Doc('UniExp.DataSet.TableQuery'); 
% UniExp.DataSet.TableQuery> <matlab:doc UniExp.F0Normalize UniExp.F0Normalize> 
% <matlab:doc UniExp.DataSet.QueryNTS UniExp.DataSet.QueryNTS> <matlab:doc MATLAB.DataTypes.NDTable 
% MATLAB.DataTypes.NDTable> <matlab:doc UniExp.DataSet.SampleNormalize UniExp.DataSet.SampleNormalize>
import UniExp.Flags
Normalize=Flags.No_special_operation;
F0Samples=[];
Accumulate=@median;
for V=varargin
	if isenum(V{1})
		switch V{1}
			case {Flags.dFdF0,Flags.log2FdF0,Flags.ZScore,Flags.DeltaF}
				Normalize=V{1};
			case Flags.Mean
				Accumulate=@mean;
			case Flags.Std
				Accumulate=@(Data,Dimension,MissingFlag)std(Data,0,Dimension,MissingFlag);
			case Flags.VariationCoefficient
				Accumulate=@(Data,Dimension,MissingFlag)mean(Data,Dimension,MissingFlag)./std(Data,0,Dimension,MissingFlag);
		end
	else
		F0Samples=V{1};
	end
end
SignalColumn=obj.GetSignalColumn;
Query=obj.TableQuery([SignalColumn,"CellUID"],Query);
HasGroupNames=isstruct(Query);
if HasGroupNames
	FieldNames=string(fieldnames(Query));
	Query=struct2cell(Query);
end
if istable(Query)
	Query={Query};
end
NumQueries=numel(Query);
if HasGroupNames
	GroupID=FieldNames;
else
	GroupID=compose("第%u组",1:NumQueries);
end
[GroupNtats,UidCell]=deal(cell(NumQueries,1));
%不需要并行，基本无收益
for Q=1:NumQueries
	[Groups,CellUID]=findgroups(Query{Q}.CellUID);
	ID=GroupID(Q);
	if isempty(Groups)
		UniExp.Exception.Empty_group.Throw(ID);
	end
	try
		[NTATS,Incomplete]=splitapply(@(Cell)GroupAccumulate(Cell,Accumulate,Normalize,F0Samples),Query{Q}.(SignalColumn),Groups);
		%细胞×时间
	catch ME
		switch ME.identifier
			case "MATLAB:catenate:dimensionMismatch"
				UniExp.Exception.Lengths_of_TrialSignals_within_the_query_group_is_different.Throw(sprintf('%s内TrialSignal长度不同，考虑使用<a href="matlab:doc UniExp.DataSet.ResampleTrials">UniExp.DataSet.ResampleTrials</a>',ID));
			case "UniExp.Exception.Found_an_empty_signal"
				UniExp.Exception.Found_an_empty_signal.Throw(ID);
			otherwise
				ME.rethrow;
		end
	end
	if any(Incomplete)
		UniExp.Exception.Some_trials_are_incomplete.Warn(ID);
	end
	NanIndex=find(any(isnan(NTATS),2));
	if ~isempty(NanIndex)
		UniExp.Exception.NaN_appears_after_normalization.Throw(sprintf('%s：归一化数据出现NaN，这通常是因为细胞圈出了配准范围之外，导致基线信号为0。涉事细胞UID：%s',ID,join(string(CellUID(NanIndex)),',')));
	end
	GroupNtats{Q}=NTATS;
	UidCell{Q}=CellUID;
end
if isequal(UidCell(1:end-1),UidCell(2:end))
	if HasGroupNames
		IndexNames={[];[];FieldNames};
	else
		IndexNames={[];[];[]};
	end
	DimensionName=["细胞";"时间";"分组"];
	GroupNtats=table(UidCell{1},MATLAB.DataTypes.NDTable(cat(3,GroupNtats{:}),table(DimensionName,IndexNames)),'VariableNames',["CellUID","NTATS"]);
	GroupNtats.Properties.DimensionNames(1)="细胞";
else
	NumCells=cellfun(@numel,UidCell);
	if isequal(NumCells(1:end-1),NumCells(2:end))
		UniExp.Exception.CellUIDs_differ_among_groups.Warn;
	else
		if HasGroupNames
			CellsDetail=compose("%u(%s)",NumCells,FieldNames);
		else
			CellsDetail=compose("%u",NumCells);
		end
		UniExp.Exception.Numbers_of_cells_differ_among_groups.Warn([sprintf('每组的细胞数不同，不同组之间可能不具有可比性，请确认筛选条件正确？分别有 %s 个细胞\n',join(CellsDetail,' ')),'使用<a href="matlab:groupsummary(DataSet.Cells,''Mouse'')">groupsummary(DataSet.Cells,''Mouse'')</a>查看每只鼠的细胞数']);
	end
	for Q=1:NumQueries
		GroupNtats{Q}=table(GroupNtats{Q},UidCell{Q},'VariableNames',["NTATS","CellUID"]);
		GroupNtats{Q}.Properties.DimensionNames(1)="细胞";
	end
	if HasGroupNames
		GroupNtats=cell2struct(GroupNtats,FieldNames);
	end
end
end
%%
function [NTAT,Incomplete]=GroupAccumulate(Data,Accumulate,Normalize,F0Samples)
if iscell(Data)
	if any(cellfun(@isempty,Data))
		UniExp.Exception.Found_an_empty_signal.Throw;
	end
	try
		Data=vertcat(Data{:});
		Incomplete=false;
	catch ME
		if ME.identifier~="MATLAB:catenate:dimensionMismatch"
			ME.rethrow;
		end
		Incomplete=true;
		Data=MATLAB.ElMat.PadCat(1,Data{:},NaN);
	end
else
	Incomplete=false;
end
NTAT=Accumulate(UniExp.F0Normalize(Data,Normalize,F0Samples),1,'omitmissing');
end