function CA=CellActive(Data)
%细胞活跃性判定算法，返回逻辑向量，指示每个细胞被判定为活跃还是不活跃
arguments (Input)
	%假设输入数据是（细胞×时间×回合）的张量。每个回合取Cue前3s到后3s，一共6s，采样率8㎐，因此时间轴有48个点
	Data(:,48,:)
end
arguments(Output)
	%输出为只有一个细胞维度的逻辑向量
	CA(:,1)
end
CA=NTATS(Data);
%首先计算细胞×时间的NTATS矩阵

Baseline=CA(:,1:24);
%取-3~0s，即前24个时间点作为基线。

CA=CA(:,32)>mean(Baseline,2)+3*std(Baseline,[],2);
%判定细胞在Cue后1s（即第32个时间点）处的NTATS是否大于基线均值加3倍标准差，若是则判定为活跃（true），否则为不活跃（false）
end