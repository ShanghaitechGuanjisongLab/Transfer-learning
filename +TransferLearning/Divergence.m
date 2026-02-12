function D=Divergence(CellTrialTimes)
%输入一只鼠的细胞×回合×时间张量，计算散度

%先零一化再算散度
% D=CellTrialTimes(:,:,32)>3*std(CellTrialTimes(:,:,1:24)-mean(CellTrialTimes(:,:,1:24),3),[],2:3);
% D=sqrt(sum(var(D,[],2),1)./sum(mean(D,2).^2));

% 候选散度算法，不零一化，更不显著
D=sqrt(sum(var(CellTrialTimes(:,:,32),[],2),1)./sum(mean(CellTrialTimes(:,:,32),2).^2));

%主成分协方差行列式算法
% [~,D]=pca(CellTrialTimes(:,:,32).',Centered='off',NumComponents=2);
% D=sqrt(det(cov(D)))./norm(mean(D,1));
end