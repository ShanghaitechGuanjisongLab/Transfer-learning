function [Coeff,Score]=UnifiedPcaModel(Paradigm,varargin)
GroupNtats=TransferLearning.QueryNTATS(Paradigm+"PCA");
PcaTable=TransferLearning.PcaTable(Paradigm+"PCA");
if isscalar(varargin)
	QueryNtats=varargin{1};
	Coeff=table;
	[Coeff.CellUID,CoeffIndex,QueryIndex]=intersect(GroupNtats.CellUID,QueryNtats.CellUID);
	UntransposedCoeff=PcaTable.Coeff(:,CoeffIndex);
	NTATS=QueryNtats.NTATS(QueryIndex,:,:);
else
	CellUID=TransferLearning.FullCalcium.TableQuery("CellUID",varargin{:},Paradigm=Paradigm,ZLayer=["MOp2/3","MOp5"]).CellUID;
	Coeff=table(CellUID);
	Logical=ismember(GroupNtats.CellUID,CellUID);
	UntransposedCoeff=PcaTable.Coeff(:,Logical);
	NTATS=GroupNtats.NTATS(Logical,:,:);
end
Coeff.Coeff=UntransposedCoeff';
if nargout>1
	Score=table;
	Score.Explained=PcaTable.Explained;
	if isa(NTATS,'MATLAB.DataTypes.NDTable')
		Dimensions=NTATS.Dimensions;
		Dimensions.DimensionName(1)="PC";
		Score.Score=MATLAB.DataTypes.NDTable(pagemtimes(UntransposedCoeff,NTATS.Data),Dimensions);
	else
		Score.Score=pagemtimes(UntransposedCoeff,NTATS);
	end
end