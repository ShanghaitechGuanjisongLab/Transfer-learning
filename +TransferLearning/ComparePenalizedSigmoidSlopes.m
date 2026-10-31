function Result = ComparePenalizedSigmoidSlopes(nPermutation,TrialTableInput,options)
% Compare per-mouse penalized sigmoid slopes across interval cohorts.
% Mouse-level label permutation is performed on log(k), with Holm-
% corrected pairwise contrasts. Curves with fewer than two distinct
% training blocks are excluded. Two-block curves fix lower asymptote=0.
% Set FixLowerZero=true to impose the zero-lower model for every mouse.

arguments
	nPermutation (1,1) double {mustBePositive,mustBeInteger} = 50000
	TrialTableInput table = table()
	options.FixLowerZero (1,1) logical = false
end
if isempty(TrialTableInput)
	[Curves,Trials] = TransferLearning.BuildIntervalBehaviorCurves();
	groupNames = ["Naive","Interspersed","12h","7d"];
	Curves.Group = categorical(Curves.Group,groupNames,'Ordinal',true);
	Trials.Group = categorical(Trials.Group,groupNames,'Ordinal',true);
	TrialTable = innerjoin(Trials,Curves(:,{'Group','Mouse','DateTime','Block'}), ...
		'Keys',{'Group','Mouse','DateTime'});
else
	TrialTable = TrialTableInput;
	groupNames = unique(string(TrialTable.Group),'stable').';
	Curves = TrialTable(:,{'Group','Mouse','DateTime','Block','Behavior'});
	[G,group,mouse,dateTime,block] = findgroups(Curves.Group,Curves.Mouse,Curves.DateTime,Curves.Block);
	performance = splitapply(@mean,Curves.Behavior,G);
	nTrial = splitapply(@numel,Curves.Behavior,G);
	Curves = table(group,mouse,dateTime,block,performance,nTrial, ...
		'VariableNames',{'Group','Mouse','DateTime','Block','Performance','NTrial'});
	Curves.Group = string(Curves.Group);
	TrialTable.Group = string(TrialTable.Group);
end
PerMouse = table();
for group = groupNames
	mice = unique(Curves.Mouse(Curves.Group == group));
	for mouse = mice.'
		Q = TrialTable(TrialTable.Group == group & TrialTable.Mouse == mouse,:);
		nBlocks = numel(unique(Q.Block));
		if nBlocks < 2
			PerMouse = [PerMouse; table(group,mouse,nBlocks,height(Q),NaN,NaN,NaN,NaN,NaN,NaN,false,false, ...
				'VariableNames',{'Group','Mouse','NBlocks','NTrials','Slope','LogSlope','Lower','Midpoint','RSquared','Objective','FitEligible','AtSlopeBoundary'})]; %#ok<AGROW>
			continue;
		end
		fit = TransferLearning.FitPenalizedSigmoid(Q.Block,Q.Behavior,FixLowerZero=options.FixLowerZero || nBlocks==2);
		fitEligible = ~fit.AtSlopeBoundary;
		PerMouse = [PerMouse; table(group,mouse,nBlocks,height(Q),fit.Slope,log(fit.Slope), ...
			fit.Lower,fit.Midpoint,fit.RSquared,fit.Objective,fitEligible,fit.AtSlopeBoundary, ...
			'VariableNames',{'Group','Mouse','NBlocks','NTrials','Slope','LogSlope','Lower','Midpoint','RSquared','Objective','FitEligible','AtSlopeBoundary'})]; %#ok<AGROW>
	end
end
PerMouse.Group = categorical(PerMouse.Group,groupNames,'Ordinal',true);
Pairwise = table();
NullDifferences = cell(6,1);
pairIndex = 0;
for i = 1:numel(groupNames)-1
	for j = i+1:numel(groupNames)
		pairIndex = pairIndex+1;
		g1 = groupNames(i);
		g2 = groupNames(j);
		x1 = PerMouse.LogSlope(PerMouse.Group == g1 & PerMouse.FitEligible);
		x2 = PerMouse.LogSlope(PerMouse.Group == g2 & PerMouse.FitEligible);
		[nullDifference,observedDifference] = iPermutation(x1,x2,nPermutation,pairIndex);
		pValue = (1+sum(abs(nullDifference) >= abs(observedDifference)))/(numel(nullDifference)+1);
		Pairwise = [Pairwise; table(g2+" - "+g1,numel(x1),numel(x2), ...
			exp(median(x1)),exp(median(x2)),observedDifference,pValue,numel(nullDifference), ...
			'VariableNames',{'Comparison','N1','N2','MedianSlope1','MedianSlope2','ObservedLogSlopeDifference','PValue','NPermutation'})]; %#ok<AGROW>
		NullDifferences{pairIndex} = nullDifference;
	end
end
Pairwise.PValueHolm = iHolm(Pairwise.PValue);
Pairwise = iAddWelchTests(Pairwise,PerMouse,groupNames);
Result = struct('Curves',Curves,'TrialTable',TrialTable,'PerMouse',PerMouse, ...
	'Pairwise',Pairwise,'NullDifferences',{NullDifferences}, ...
	'NPermutation',nPermutation,'FixLowerZero',options.FixLowerZero, ...
	'Method',"Free lower/midpoint sigmoid; lower=0 for two-block curves");
end

function Pairwise = iAddWelchTests(Pairwise,PerMouse,groupNames)
Pairwise.WelchPValue = nan(height(Pairwise),1);
Pairwise.WelchDF = nan(height(Pairwise),1);
Pairwise.MeanLogSlopeDifference = nan(height(Pairwise),1);
pairIndex = 0;
for i = 1:numel(groupNames)-1
	for j = i+1:numel(groupNames)
		pairIndex = pairIndex+1;
		x = PerMouse.LogSlope(PerMouse.Group == groupNames(j) & PerMouse.FitEligible);
		y = PerMouse.LogSlope(PerMouse.Group == groupNames(i) & PerMouse.FitEligible);
		[~,p,~,stats] = ttest2(x,y,'Vartype','unequal');
		Pairwise.WelchPValue(pairIndex) = p;
		Pairwise.WelchDF(pairIndex) = stats.df;
		Pairwise.MeanLogSlopeDifference(pairIndex) = mean(x)-mean(y);
	end
end
Pairwise.WelchPValueHolm = iHolm(Pairwise.WelchPValue);
end

function [nullDifference,observedDifference] = iPermutation(x1,x2,nPermutation,seed)
x1 = x1(isfinite(x1));
x2 = x2(isfinite(x2));
observedDifference = median(x2)-median(x1);
allX = [x1(:);x2(:)];
n1 = numel(x1);
nTotal = numel(allX);
nAssignments = nchoosek(nTotal,n1);
if nAssignments <= nPermutation
	assignments = nchoosek(1:nTotal,n1);
else
	rng(seed+20261030,'twister');
	assignments = nan(nPermutation,n1);
	for i = 1:nPermutation
		assignments(i,:) = randperm(nTotal,n1);
	end
end
nullDifference = nan(size(assignments,1),1);
for i = 1:size(assignments,1)
	mask = false(nTotal,1);
	mask(assignments(i,:)) = true;
	nullDifference(i) = median(allX(~mask))-median(allX(mask));
end
end

function adjusted = iHolm(p)
[sorted,order] = sort(p);
n = numel(p);
sortedAdjusted = min(cummax((n:-1:1).'.*sorted),1);
adjusted = nan(size(p));
adjusted(order) = sortedAdjusted;
end
