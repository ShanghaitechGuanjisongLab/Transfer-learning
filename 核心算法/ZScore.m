function Data=ZScore(Data)
%z-score算法，以Cue前3s为基线
arguments (Input)
	%假设输入数据是（细胞×时间×回合）的张量。每个回合取Cue前3s到后3s，一共6s，采样率8㎐，因此时间轴有48个点
	Data(:,48,:)
end
arguments(Output)
	%输出相同形状的张量
	Data(:,48,:)
end
%取-3~0s，即前24个时间点作为基线。
Baseline=Data(:,1:24,:);

%用数据减去基线时间均值后，再除以时间标准差，得到z-score
Data=(Data-mean(Baseline,2))./std(Baseline,[],2);
end