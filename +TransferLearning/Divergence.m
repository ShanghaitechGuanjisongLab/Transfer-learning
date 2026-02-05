function D=Divergence(CellTrialTimes)
%输入一只鼠的细胞×回合×时间张量，计算散度

%先零一化再算散度
% Baseline=CellTrialTimes(:,:,1:24);
% D=CellTrialTimes(:,:,32)>mean(Baseline,2:3)+3*std(Baseline,[],2:3);
% D=sqrt(sum(var(D,[],2),1)./sum(mean(D,2).^2));

% 候选散度算法，不零一化，更不显著
D=sqrt(sum(var(CellTrialTimes(:,:,32),[],2),1)./sum(mean(CellTrialTimes(:,:,32),2).^2));
end