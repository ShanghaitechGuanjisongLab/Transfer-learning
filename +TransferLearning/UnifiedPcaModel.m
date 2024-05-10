function [Coeff,Score]=UnifiedPcaModel(varargin)
persistent DataSet GroupNtats PcaTable
if isempty(GroupNtats)
	DataSet=TransferLearning.FullCalcium;
	GroupNtats=UniExp.NtatsCellReplenish(DataSet.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),'统一PCA'),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median));
	PcaTable=UniExp.LinearPca(GroupNtats.NTATS,12);
end
if nargin>1
	CellUID=DataSet.TableQuery("CellUID",varargin{:}).CellUID;
	Coeff=table(CellUID);
	Logical=ismember(GroupNtats.CellUID,CellUID);
	UntransposedCoeff=PcaTable.Coeff(:,Logical);
	NTATS=GroupNtats.NTATS(Logical,:,:);
else
	QueryNtats=varargin{1};
	Coeff=table;
	[Coeff.CellUID,CoeffIndex,QueryIndex]=intersect(GroupNtats.CellUID,QueryNtats.CellUID);
	UntransposedCoeff=PcaTable.Coeff(:,CoeffIndex);
	NTATS=QueryNtats.NTATS(QueryIndex,:,:);
end
Coeff.Coeff=UntransposedCoeff';
if nargout>1
	Score=table;
	Score.Explained=PcaTable.Explained;
	Dimensions=NTATS.Dimensions;
	Dimensions.DimensionName(1)="PC";
	Score.Score=MATLAB.DataTypes.NDTable(pagemtimes(UntransposedCoeff,NTATS.Data),Dimensions);
end