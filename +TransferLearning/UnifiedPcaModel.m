function [Coeff,Score]=UnifiedPcaModel(varargin)
persistent DataSet GroupNtats PcaTable
if isempty(GroupNtats)
	DataSet=TransferLearning.FullCalcium;
	GroupNtats=UniExp.NtatsCellReplenish(DataSet.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),'统一PCA'),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median));
	PcaTable=UniExp.LinearPca(GroupNtats.NTATS,5);
end
CellUID=DataSet.TableQuery("CellUID",varargin{:}).CellUID;
Coeff=table(CellUID);
Logical=ismember(GroupNtats.CellUID,CellUID);
UntransposedCoeff=PcaTable.Coeff(:,Logical);
Coeff.Coeff=UntransposedCoeff';
if nargout>1
	Score=table;
	Score.Explained=PcaTable.Explained;
	Dimensions=GroupNtats.NTATS.Dimensions;
	Dimensions.DimensionName(1)="PC";
	Score.Score=MATLAB.DataTypes.NDTable(pagemtimes(UntransposedCoeff,GroupNtats.NTATS{Logical,:,:}),Dimensions);
end