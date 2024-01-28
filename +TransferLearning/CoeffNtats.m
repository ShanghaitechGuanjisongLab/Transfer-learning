function [Coeff,Ntats] = CoeffNtats(Cortex)
persistent GroupNtats Selectors Cortices
if isempty(GroupNtats)
	DataSet=UniExp.DataSet("\\Data-Server-1\个人数据\张天夫\202401\全钙大模型v3.mat");
	GroupNtats=UniExp.NtatsCellReplenish(DataSet.QueryNTATS(UniExp.ReadQueryTable("\\Data-Server-1\个人数据\张天夫\202401\统一模型查询表.xlsx","皮层分开线图"),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median));
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