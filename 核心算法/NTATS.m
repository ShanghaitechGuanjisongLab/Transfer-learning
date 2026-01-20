function Data=NTATS(Data)
%NTATS算法，基于ZScore
arguments (Input)
	%假设输入数据是（细胞×时间×回合）的张量。每个回合取Cue前3s到后3s，一共6s，采样率8㎐，因此时间轴有48个点
	Data(:,48,:)
end
arguments(Output)
	%输出为（细胞×时间）的矩阵，输入的回合维度被规约为中位数了
	Data(:,48)
end
%直接对ZScore取回合间中位数
Data=median(ZScore(Data),3);
end