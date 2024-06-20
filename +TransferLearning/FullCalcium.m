function D = FullCalcium
persistent DataSet
if isempty(DataSet)
	DataSet=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202405\全钙大模型v4.mat");
	DataSet.TrialSignals.NormalizedSignal=DataSet.TrialSignals.NormalizedSignal(:,1:40);
	DataSet.RemoveCells(5144);%此细胞包含NaN值
end
D=DataSet;