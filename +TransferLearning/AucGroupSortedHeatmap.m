function Layout=AucGroupSortedHeatmap(Data,SubTitles,Colors,ScaleColor)
arguments
	Data
	SubTitles
	Colors
	ScaleColor=true
end
[~,~,Group]=MATLAB.DataFun.MaxSubs(Data,2:3);
SortedData=zeros(size(Data));
NumSorted=0;
for G=1:max(Group)
	Unsorted=Data(Group==G,:,:);
	Auc=sum(Unsorted(:,:,G),2);
	[~,SortIndex]=sort(Auc);
	NewNumSorted=NumSorted+numel(Auc);
	SortedData(NumSorted+1:NewNumSorted,:,:)=Unsorted(SortIndex,:,:);
	NumSorted=NewNumSorted;
end
Layout=TransferLearning.BasicHeatmap(SortedData,SubTitles,Colors,ScaleColor);