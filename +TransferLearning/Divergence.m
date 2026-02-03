function D=Divergence(CellTrials)
%输入1s处的细胞×回合矩阵，计算散度
D=sqrt(mean(var(CellTrials,[],2)))./norm(mean(CellTrials,2));
end