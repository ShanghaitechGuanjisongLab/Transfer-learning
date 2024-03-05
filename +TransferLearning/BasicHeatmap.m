function [Layout,Axes] = BasicHeatmap(SortedData,SubTitles,Colors,ScaleColor)
figure;
Layout=tiledlayout(1,numel(SubTitles),TileSpacing='none',Padding='none');
if ScaleColor
	ScaleColor={UniExp.Flags.ScaleColor};
else
	ScaleColor={};
end
[~,Axes]=UniExp.LanearHeatmap(SortedData,UniExp.Flags.HideYAxis,ScaleColor{:},Layout=Layout,ImagescStyle={'XData',[-3,12]},SubTitles=SubTitles,LMHColor=[Colors(1,:);1,1,1;Colors(2,:)]);
xlabel(Layout,'Time(s) from cue(:) water(|)');
ylabel(Layout,'Cell');
CB=colorbar;
CB.Layout.Tile='east';
CB.Label.String='ΔF/F_0';
Axes=Axes';
for A=Axes
	xline(A,0,':',Color=Colors(3,:,:));
	xline(A,1,'-',Color=Colors(3,:,:));
end
CB.TickLabels=MATLAB.SignificantFixedpoint(2.^str2double(CB.TickLabels)-1,2);