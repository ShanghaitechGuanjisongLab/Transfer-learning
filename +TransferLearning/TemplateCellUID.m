function CellUID = TemplateCellUID(TopRatio)
persistent Rank
if isempty(Rank)
	PcaCalcium=UniExp.NtatsCellReplenish(TransferLearning.FullCalcium().QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),'统一PCA'),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median));
	[~,SortIndex]=sort(min(UniExp.LinearPca(PcaCalcium.NTATS,4).Coeff(1:2,:),[],1),'descend');
	Rank=PcaCalcium.CellUID(SortIndex);
end
CellUID=Rank(1:uint8(end*TopRatio));