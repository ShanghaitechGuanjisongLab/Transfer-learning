function PeakSortHeatmap(Coeff,Ntats,Title,Scale,ScaleX,ScaleY,Filt,options)
arguments
	Coeff
	Ntats
	Title
	Scale
	ScaleX=8
	ScaleY=5
	Filt=true;
	options.Fig=true
	options.SubTitles
end
if options.Fig
	figure;
end
if Filt
	Coeff=Coeff(1:3,:);
	Logical=any(Coeff>mean2(Coeff)+std2(Coeff),1);
	Ntats=Ntats(Logical,:,:);
end
[~,MaxTime]=max(Ntats.Learned4_cue1_water,[],2);
[~,SortIndex]=sort(MaxTime);
Layout=tiledlayout(1,size(Ntats,3),TileSpacing='tight',Padding='tight');
if isfield(options,'SubTitles')
	[~,Axes]=UniExp.LanearHeatmap(Ntats(SortIndex,:,:),UniExp.Flags.HideYAxis,ImagescStyle={'XData',[-3,12]},Layout=Layout,SubTitles=options.SubTitles);
else
	[~,Axes]=UniExp.LanearHeatmap(Ntats(SortIndex,:,:),UniExp.Flags.HideYAxis,ImagescStyle={'XData',[-3,12]},Layout=Layout);
end
xlabel(Layout,'Time(s) from cue(:) water(|)');
ylabel(Layout,'Cell');
if strlength(Title)
	title(Layout,Title,Interpreter='none');
end
CB=colorbar;
CB.Layout.Tile='east';
CB.Label.String='ΔF/F_0';
for A=1:numel(Axes)
	xline(Axes(A),0,':');
	xline(Axes(A),1,'-');
end
MATLAB.Graphics.FigureAspectRatio(ScaleX,ScaleY,Scale);
CB.TickLabels=MATLAB.SignificantFixedpoint(2.^str2double(CB.TickLabels)-1,2);