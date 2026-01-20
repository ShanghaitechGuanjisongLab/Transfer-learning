function ICS=InterCellSD(Data,Time)
%计算指定时间点的细胞间标准差，基于NTATS
arguments (Input)
	%假设输入数据是（细胞×时间×回合）的张量。每个回合取Cue前3s到后3s，一共6s，采样率8㎐，因此时间轴有48个点
	Data(:,48,:)
	%要计算标准差的时间点
	Time(1,1)duration
end
arguments(Output)
	%输出为标量，表示指定时点的细胞间标准差
	ICS(1,1)
end
Data=NTATS(Data);
%首先计算细胞×时间的NTATS矩阵

%取指定时间点的数据，计算细胞间标准差
ICS=std(Data(:,uint8(Time/seconds(1/8))),[],1);
end