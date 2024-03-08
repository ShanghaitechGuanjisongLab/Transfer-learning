function [Layout,Axes] = BasicHeatmap(SortedData,SubTitles,Colors,ScaleColor,CLim)
figure;
Layout=tiledlayout(1,numel(SubTitles),TileSpacing='none',Padding='none');
if ScaleColor
	ScaleColor={UniExp.Flags.ScaleColor};
else
	ScaleColor={};
end
if exist('CLim','var')
	CLim={'CLim',CLim};
else
	CLim={};
end
[~,Axes]=UniExp.LanearHeatmap(SortedData,UniExp.Flags.HideYAxis,UniExp.Flags.SymmetricColormap,ScaleColor{:},CLim{:},Layout=Layout,ImagescStyle={'XData',[-3,12]},SubTitles=SubTitles,LMHColor=[Colors(1,:);1,1,1;Colors(2,:)]);
xlabel(Layout,'Time(s) from cue(:) water(|)');
ylabel(Layout,'Cell');
CB=colorbar;
CB.Layout.Tile='east';
CB.Label.String='ΔF/F_0';
Axes=Axes';
for A=Axes
	xline(A,0,':',Color=Colors(3,:));
	xline(A,1,'-',Color=Colors(3,:));
end