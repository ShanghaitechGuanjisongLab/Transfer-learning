function ActedCellsPeakSortHeatmap(dataSetNtats,IntensityDataLine,nameBlock,subName,timeLength,picTitle,lineMarker,markerSize,options)
%by 梁鸿淞
%依赖统一实验分析作图v17.1.0
%作图，将指定block（nameBlock），按照其中一个block的peaktime（dataSetNtats中必须包含）排序的细胞热图，以及每个活动的细胞（活动阈值IntensityDataLine）peaktime的连线，可选时间窗口长度（timeLength）。
arguments
    dataSetNtats
    %IntensityIndex
    IntensityDataLine
    nameBlock
    subName string
    timeLength=[-3,12]
    picTitle="ActedCellsPeakSortHeatmap"
    lineMarker="none"
    markerSize=2
    options.havePeakTimeAll(1,1){mustBeNumericOrLogical}=false
end

figure;
blockSize=numel(nameBlock);
Layout=tiledlayout(1,blockSize,TileSpacing='tight',Padding='tight');
%IntensityData=Ntats(sort(IntensityIndex),:);
IntensityData=dataSetNtats;
IntensityData.NTATS=dataSetNtats.NTATS(:,:,nameBlock);
timeLengthBegin=((timeLength(1)+3)*8)+1;
timeLengthEnd=((timeLength(end)+3)*8)+1;
assert(islogical(options.havePeakTimeAll),'输入类型不是逻辑值');
if options.havePeakTimeAll
else
   [~,IntensityData.PeakTimeAll]=max(IntensityData.NTATS,[],2); 
end
if isequaln(timeLength,[-3,12])
else
    cellNotFiredInWindow=IntensityData.PeakTimeAll{:}<timeLengthBegin|IntensityData.PeakTimeAll{:}>timeLengthEnd;
    IntensityData.PeakTimeAll{cellNotFiredInWindow}=NaN;
end
cellNoFiredAll=false(numel(IntensityData.PeakTime),blockSize);
for i=1:blockSize
    cellNoFiredAll(:,i)=max(IntensityData.NTATS.(nameBlock(i))(:,25:121),[],2)<IntensityDataLine;
end
Y=1:numel(IntensityData.PeakTime);
Colors=GlobalOptimization.ColorAllocate(3,[1,1,1]);
[~,Axes]=UniExp.LanearHeatmap(IntensityData.NTATS(:,timeLengthBegin:timeLengthEnd,nameBlock),UniExp.Flags.HideYAxis,ImagescStyle={'XData',timeLength},Layout=Layout,SubTitles=subName,LMHColor=[Colors(2,:,:);1,1,1;Colors(1,:,:)]);
for i=1:blockSize
    YIm=Y';
    YIm(cellNoFiredAll(:,i))=NaN;
    YIm(cellNotFiredInWindow(1+(i-1)*size(Y,2):i*size(Y,2)))=NaN;
    IntensityDataIm=IntensityData;
    IntensityDataIm.PeakTimeAll.(nameBlock(i))(cellNoFiredAll(:,i))=NaN;
    IntensityDataIm.PeakTimeAll.(nameBlock(i))=(IntensityDataIm.PeakTimeAll.(nameBlock(i))-1)/8-3;
    arrayfun(@(Ax)line(Ax,IntensityDataIm.PeakTimeAll.(nameBlock(i)),YIm,Color=Colors(3,:,:),Marker=lineMarker,MarkerSize=markerSize),Axes(i));
end

CB=colorbar;
CB.Layout.Tile='east';
CB.Label.String='ΔF/F_0';
xlabel(Layout,'Time(s) from cue(:) water(|)');
ylabel(Layout,'Cell');
for A=1:numel(Axes)
	xline(Axes(A),0,':');
	xline(Axes(A),1,'-');
end
title(Layout,picTitle,Interpreter='none');
end