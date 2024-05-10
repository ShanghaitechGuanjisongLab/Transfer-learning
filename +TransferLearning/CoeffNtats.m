function [Coeff,Ntats] = CoeffNtats(Cortex)
persistent GroupNtats Selectors Cortices
if isempty(GroupNtats)
	DataSet=TransferLearning.FullCalcium;
	GroupNtats=UniExp.NtatsCellReplenish(DataSet.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx',"统一模型"),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median)));
	Selectors={["NTATS","CellUID","ZLayer"],{GroupNtats,DataSet.Cells},'ZLayer'};
	Cortices=table('Size',[0,2],'VariableTypes',["cell","cell"],'VariableNames',["Coeff","Ntats"]);
end
try
	[Coeff,Ntats]=Cortices{Cortex,:}{:};
catch
	Ntats=MATLAB.DataTypes.Select(Selectors{:},Cortex+["2/3","5"]);
	[~,Index]=ismember(Ntats.CellUID,GroupNtats.CellUID);
	Coeff=UniExp.LinearPca(GroupNtats.NTATS,6).Coeff(:,Index);
	Cortices{Cortex,:}={Coeff,Ntats};
end