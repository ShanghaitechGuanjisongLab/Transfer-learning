function CellUID = TemplateCellUID(TopRatio,PCs,Paradigm)
persistent UnifiedPcaModel
if isempty(UnifiedPcaModel)
	UnifiedPcaModel=memoize(@TransferLearning.UnifiedPcaModel);
end
Coeff=UnifiedPcaModel(Paradigm);
[~,SortIndex]=sort(min(Coeff.Coeff(:,PCs),[],2),'descend');
Rank=Coeff.CellUID(SortIndex);
CellUID=Rank(1:uint8(end*TopRatio));