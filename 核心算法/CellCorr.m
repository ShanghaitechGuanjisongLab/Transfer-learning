function [Rho,P]=CellCorr(Data)
%预测正确率算法，计算1s-1.5s的全细胞相关性
arguments (Input)
	%假设输入数据是（细胞×时间×回合）的张量。每个回合取Cue前3s到后3s，一共6s，采样率8㎐，因此时间轴有48个点
	Data(:,48,:)
end
arguments(Output)
	%输出为标量，表示细胞相关性
	Rho(1,1)
	%显著相关性的p值
	P(1,1)
end
Data=NTATS(Data);
%首先计算细胞×时间的NTATS矩阵

%取1s和1.5s，即第32和第36个时间点，计算Spearman相关性
[Rho,P]=corr(Data(:,32),Data(:,36),Type='Spearman');
end