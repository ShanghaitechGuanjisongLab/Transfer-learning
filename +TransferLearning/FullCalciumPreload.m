% DataSet=UniExp.DataSet("\\Data-Server-1\个人数据\张天夫\202401\全钙大模型v3.mat");
QueryTable=UniExp.ReadQueryTable("\\Data-Server-1\个人数据\张天夫\202401\统一模型查询表.xlsx","皮层分开线图");

GroupNtats=DataSet.QueryNTATS(QueryTable,UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median);
GroupNtats=UniExp.NtatsCellReplenish(GroupNtats);

PcaTable=UniExp.LinearPca(GroupNtats.NTATS,6);
MOp
MOpNtats=MATLAB.DataTypes.Select(["NTATS","CellUID","ZLayer"],{GroupNtats,DataSet.Cells},ZLayer=["MOp2/3","MOp5"]);
[~,Index]=ismember(MOpNtats.CellUID,GroupNtats.CellUID);
MOpCoeff=PcaTable.Coeff(:,Index);
MOpScore=pagemtimes(MOpCoeff,MOpNtats.NTATS{:,:,["Naive_cue1_water","Learned4_cue1_water","Transfer_cue2_water"]});
RSPd
RSPdNtats=MATLAB.DataTypes.Select(["NTATS","CellUID","ZLayer"],{GroupNtats,DataSet.Cells},ZLayer=["RSPd2/3","RSPd5"]);
[~,Index]=ismember(RSPdNtats.CellUID,GroupNtats.CellUID);
RSPdCoeff=PcaTable.Coeff(:,Index);
RSPdScore=pagemtimes(RSPdCoeff,RSPdNtats.NTATS{:,:,["Naive_cue1_water","Learned4_cue1_water","Transfer_cue2_water"]});