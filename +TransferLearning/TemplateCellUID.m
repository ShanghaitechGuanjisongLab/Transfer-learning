function CellUID = TemplateCellUID(TopRatio,PCs)
persistent Coeff
if isempty(Coeff)
	Coeff=TransferLearning.UnifiedPcaModel(Paradigm="光声");
end
[~,SortIndex]=sort(min(abs(Coeff.Coeff(:,PCs)),[],2),'descend');
Rank=Coeff.CellUID(SortIndex);
CellUID=Rank(1:uint8(end*TopRatio));