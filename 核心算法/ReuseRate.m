function RR=ReuseRate(TargetSession,LearnedSession)
%计算LearnedSession中活跃的细胞在TargetSession中复用的比例
arguments (Input)
	%要计算复用率的目标会话数据，假设是（细胞×时间×回合）的张量。每个回合取Cue前3s到后3s，一共6s，采样率8㎐，因此时间轴有48个点
	TargetSession(:,48,:)
	%作为基准的“学会”会话数据
	LearnedSession(:,48,:)
end
arguments(Output)
	%输出复用率，标量
	RR(1,1)
end
%首先计算两个会话各自的细胞活跃性逻辑向量
TargetSession=CellActive(TargetSession);
LearnedSession=CellActive(LearnedSession);

%取出LearnedSession中活跃的细胞，计算它们在TargetSession中也被判定为活跃的比例
RR=mean(TargetSession(LearnedSession));
end