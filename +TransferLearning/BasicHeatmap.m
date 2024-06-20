function [Layout,Axes] = BasicHeatmap(SortedData,SubTitles,Colors,ScaleColor,options)
arguments
	SortedData
	SubTitles
	Colors
	ScaleColor
	options.CLim
	options.WaterLine=true;
	options.Flags=[UniExp.Flags.HideYAxis,UniExp.Flags.SymmetricColormap]
end
figure;
Layout=tiledlayout(1,numel(SubTitles),TileSpacing='tight',Padding='tight');
if ScaleColor
	ScaleColor={UniExp.Flags.ScaleColor};
else
	ScaleColor={};
end
if isfield(options,'CLim')
	CLim={'CLim',options.CLim};
else
	CLim={};
end
[~,Axes]=UniExp.LanearHeatmap(SortedData,ScaleColor{:},CLim{:},Flags=options.Flags,Layout=Layout,ImagescStyle={'XData',[-3,2]},SubTitles=SubTitles,LMHColor=[Colors(1,:);1,1,1;Colors(2,:)]);
Axes(1).YAxis.Visible='on';
xlabel(Layout,'Time(s) from cue(:) water(|)');
ylabel(Layout,'Cell');
CB=colorbar;
CB.Layout.Tile='east';
CB.Label.String='ΔF/F_0';
Axes=Axes';
for A=Axes
	xline(A,0,':',Color=Colors(3,:));
	if options.WaterLine
		xline(A,1,'-',Color=Colors(3,:));
	end
end