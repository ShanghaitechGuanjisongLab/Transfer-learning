DataSet=TransferLearning.FullCalcium();
QueryTable=UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),"统一模型");

GroupNtats=DataSet.QueryNTATS(QueryTable,UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median);
GroupNtats=UniExp.NtatsCellReplenish(GroupNtats);

PcaTable=UniExp.LinearPca(GroupNtats.NTATS,6);
MOpNtats=MATLAB.DataTypes.Select(["NTATS","CellUID","ZLayer"],{GroupNtats,DataSet.Cells},ZLayer=["MOp2/3","MOp5"]);
[~,Index]=ismember(MOpNtats.CellUID,GroupNtats.CellUID);
MOpCoeff=PcaTable.Coeff(:,Index);
MOpScore=pagemtimes(MOpCoeff,MOpNtats.NTATS{:,:,["Naive_cue1_water","Learned4_cue1_water","Transfer_cue2_water"]});
RSPdNtats=MATLAB.DataTypes.Select(["NTATS","CellUID","ZLayer"],{GroupNtats,DataSet.Cells},ZLayer=["RSPd2/3","RSPd5"]);
[~,Index]=ismember(RSPdNtats.CellUID,GroupNtats.CellUID);
RSPdCoeff=PcaTable.Coeff(:,Index);
RSPdScore=pagemtimes(RSPdCoeff,RSPdNtats.NTATS{:,:,["Naive_cue1_water","Learned4_cue1_water","Transfer_cue2_water"]});