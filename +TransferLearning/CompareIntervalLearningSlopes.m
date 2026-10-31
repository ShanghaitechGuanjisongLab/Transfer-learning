function Result = CompareIntervalLearningSlopes(nPermutation, cohortMode)
% Compare mouse-level learning slopes across Naive/interspersed/12-h/7-d.
% Sigmoid: L + (1-L)/(1+exp(-k*(block-midpoint))), fitted per mouse.
% Primary test: two-sided permutation on the difference in median log(k).
% Complete mouse curves, never individual trials, are permuted.

if nargin < 1
	nPermutation = 50000;
end
if nargin < 2
	cohortMode = "AllBehavior";
end
[Curves, Trials] = TransferLearning.BuildIntervalBehaviorCurves();
if cohortMode == "ImagingOnly"
	excludeSources = ["ALPureBehavior","LAPureBehavior"];
	Curves = Curves(~ismember(Curves.Source,excludeSources),:);
	Trials = Trials(~ismember(Trials.Source,excludeSources),:);
elseif cohortMode ~= "AllBehavior"
	error('TransferLearning:UnknownCohort','Unknown cohort mode: %s',cohortMode);
end
groupNames = ["Naive","Interspersed","12h","7d"];
Curves.Group = categorical(Curves.Group, groupNames, 'Ordinal', true);
Trials.Group = categorical(Trials.Group, groupNames, 'Ordinal', true);
TrialTableAll = innerjoin(Trials, Curves(:, {'Group','Mouse','DateTime','Block'}), ...
	'Keys', {'Group','Mouse','DateTime'});
PerMouse = table();
FitInfo = table();
for g = groupNames
	mice = unique(Curves.Mouse(Curves.Group == g));
	for m = mice.'
		Q = Curves(Curves.Group == g & Curves.Mouse == m, :);
		Q = sortrows(Q, 'Block');
		x = double(Q.Block);
		y = double(Q.Performance);
		n = double(Q.NTrial);
		fit = iFitSigmoid(x, y);
		first7 = x <= 7;
		earlySlope = iEarlyLogitSlope(x(first7), y(first7), n(first7));
		firstCriterion = find(y >= 1 - 1e-12, 1, 'first');
		if isempty(firstCriterion)
			criterion = NaN;
		else
			criterion = x(firstCriterion);
		end
		QT = TrialTableAll(TrialTableAll.Group == g & TrialTableAll.Mouse == m, :);
		trialLogitSlope = iFitFirthLogistic(QT.Block, QT.Behavior);
		QT7 = QT(QT.Block <= 7,:);
		trialLogitSlopeFirst7 = iFitFirthLogistic(QT7.Block, QT7.Behavior);
		PerMouse = [PerMouse; table(g, m, fit.Lower, fit.Slope, log(fit.Slope), ...
			fit.Midpoint, fit.RSquared, numel(x), earlySlope, criterion, numel(x) >= 3, fit.Slope >= 19.99, trialLogitSlope, trialLogitSlopeFirst7, ...
			'VariableNames', {'Group','Mouse','Lower','Slope','LogSlope','Midpoint', ...
			'RSquared','NBlocks','EarlyLogitSlope','BlocksToCriterion','FitEligible','AtSlopeBound','TrialLogitSlope','TrialLogitSlopeFirst7'})]; %#ok<AGROW>
		FitInfo = [FitInfo; table(g, m, string(mat2str(y.',4)), fit.Slope, fit.RSquared, ...
			'VariableNames', {'Group','Mouse','ObservedPerformance','Slope','RSquared'})]; %#ok<AGROW>
	end
end
PerMouse.Group = categorical(PerMouse.Group, groupNames, 'Ordinal', true);
Pairwise = table();
NullDifferences = cell(6,1);
pairIndex = 0;
for i = 1:numel(groupNames)-1
	for j = i+1:numel(groupNames)
		pairIndex = pairIndex + 1;
		g1 = groupNames(i);
		g2 = groupNames(j);
		x1 = PerMouse.LogSlope(PerMouse.Group == g1 & PerMouse.FitEligible);
		x2 = PerMouse.LogSlope(PerMouse.Group == g2 & PerMouse.FitEligible);
		[perm, observed] = iPermuteMedianDifference(x1, x2, nPermutation, pairIndex);
		pValue = (1 + sum(abs(perm) >= abs(observed))) / (numel(perm) + 1);
		Pairwise = [Pairwise; table(g2 + " - " + g1, numel(x1), numel(x2), ...
			median(x1), median(x2), exp(median(x1)), exp(median(x2)), observed, ...
			median(x2)-median(x1), pValue, numel(perm), ...
			'VariableNames', {'Comparison','N1','N2','MedianLogSlope1','MedianLogSlope2', ...
			'MedianSlope1','MedianSlope2','ObservedLogSlopeDifference','ObservedMedianDifference', ...
			'PValue','NPermutation'})]; %#ok<AGROW>
		NullDifferences{pairIndex} = perm;
	end
end
Pairwise.PValueHolm = iHolmAdjust(Pairwise.PValue);
Pairwise.RankSumPValue = nan(height(Pairwise),1);
for pairIndex = 1:height(Pairwise)
	[g1, g2] = iPairNames(pairIndex, groupNames);
	x1 = PerMouse.LogSlope(PerMouse.Group == g1 & PerMouse.FitEligible);
	x2 = PerMouse.LogSlope(PerMouse.Group == g2 & PerMouse.FitEligible);
	Pairwise.RankSumPValue(pairIndex) = ranksum(x1, x2);
end

CriterionStats = iMetricPairwise(PerMouse, 'BlocksToCriterion', groupNames, nPermutation);
EarlySlopeStats = iMetricPairwise(PerMouse, 'EarlyLogitSlope', groupNames, nPermutation);
TrialLogitStats = iMetricPairwise(PerMouse, 'TrialLogitSlope', groupNames, nPermutation);
TrialLogitFirst7Stats = iMetricPairwise(PerMouse, 'TrialLogitSlopeFirst7', groupNames, nPermutation);

% Trial-level model for the prespecified first seven training blocks.
TrialTable = TrialTableAll(TrialTableAll.Block <= 7 & isfinite(TrialTableAll.Behavior), :);
TrialTable.Group = categorical(TrialTable.Group, groupNames);
TrialTable.Mouse = categorical(TrialTable.Mouse);
TrialTable.Block = double(TrialTable.Block);
TrialTable.BlockC = TrialTable.Block - 1;
% Mouse-specific random intercepts and slopes preserve the repeated-measures
% hierarchy. BlockC=0 is the first new-task block.
GLME = fitglme(TrialTable, 'Behavior ~ BlockC*Group + (BlockC|Mouse)', ...
	'Distribution', 'Binomial', 'Link', 'logit', 'FitMethod', 'Laplace');
coefNames = string(GLME.Coefficients.Name);
interactionMask = startsWith(coefNames, "BlockC:Group_") | startsWith(coefNames, "Group_") & endsWith(coefNames, ":BlockC");
L = zeros(nnz(interactionMask), numel(coefNames));
L(:, interactionMask) = eye(nnz(interactionMask));
[interactionP, F, df1, df2] = coefTest(GLME, L);

% Omnibus mouse-level permutation: between-group sum of squares of log slope.
[omnibusP, omnibusObserved, omnibusNull] = iOmnibusPermutation(PerMouse, groupNames, nPermutation);

Result = struct();
Result.Curves = Curves;
Result.TrialTable = TrialTable;
Result.PerMouse = PerMouse;
Result.FitInfo = FitInfo;
Result.Pairwise = Pairwise;
Result.NullDifferences = NullDifferences;
Result.CriterionStats = CriterionStats;
Result.EarlySlopeStats = EarlySlopeStats;
Result.TrialLogitStats = TrialLogitStats;
Result.TrialLogitFirst7Stats = TrialLogitFirst7Stats;
Result.GLME = GLME;
Result.GroupByBlockInteractionP = interactionP;
Result.GroupByBlockInteractionF = F;
Result.GroupByBlockInteractionDF = [df1,df2];
Result.OmnibusP = omnibusP;
Result.OmnibusObserved = omnibusObserved;
Result.OmnibusNull = omnibusNull;
Result.NPermutation = nPermutation;
Result.CohortMode = cohortMode;
end

function fit = iFitSigmoid(x, y)
pLower0 = log(max(min(min(y),0.45),0.01) / (1-max(min(min(y),0.45),0.01)));
midpoint0 = median(x);
slopeStarts = [0.1,0.3,0.8,2,5,15];
midpointStarts = unique([midpoint0,min(x),max(x),min(x)-numel(x),max(x)+numel(x)]);
lowerStarts = [pLower0,log(0.01/0.99),log(0.2/0.8),log(0.4/0.6)];
bestSSE = inf;
bestP = [pLower0,log(0.8),midpoint0];
options = optimset('Display','off','MaxFunEvals',20000,'MaxIter',10000);
for iL = 1:numel(lowerStarts)
	for iS = 1:numel(slopeStarts)
		for iM = 1:numel(midpointStarts)
			p0 = [lowerStarts(iL),log(slopeStarts(iS)),midpointStarts(iM)];
			p = fminsearch(@(p) iSSE(p,x,y),p0,options);
			sse = iSSE(p,x,y);
			if sse < bestSSE
				bestSSE = sse;
				bestP = p;
			end
		end
	end
end
lower = 1/(1+exp(-bestP(1)));
slope = exp(bestP(2));
midpoint = bestP(3);
sst = sum((y-mean(y)).^2);
fit = struct('Lower',lower,'Slope',slope,'Midpoint',midpoint, ...
	'RSquared',1-bestSSE/sst,'SSE',bestSSE,'Parameters',bestP);
end

function sse = iSSE(p, x, y)
lower = 1/(1+exp(-p(1)));
slope = exp(p(2));
% Keep optimization within a numerically identifiable range; the flag records
% when this bound is approached instead of allowing an arbitrary infinite slope.
if slope > 20 || abs(p(3)) > 1000
	sse = 1e6 + slope^2;
	return;
end
yHat = lower + (1-lower) ./ (1+exp(-slope.*(x-p(3))));
sse = sum((y-yHat).^2);
end

function slope = iEarlyLogitSlope(x, y, n)
% Empirical-logit transform, corrected for exact zero or one proportions.
z = log((y.*(n-1)+0.5) ./ ((1-y).*(n-1)+0.5));
if numel(x) < 2 || std(x) == 0
	slope = NaN;
else
	p = polyfit(x,z,1);
	slope = p(1);
end
end

function slope = iFitFirthLogistic(x, y)
% Firth bias-reduced logistic regression; finite under complete separation.
x = double(x(:));
y = double(y(:));
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(unique(x)) < 2
	slope = NaN;
	return;
end
X = [ones(numel(x),1),x-mean(x)];
beta = zeros(2,1);
for iteration = 1:100
	eta = X*beta;
	p = 1 ./ (1+exp(-eta));
	w = max(p.*(1-p),1e-10);
	fisher = X' * (X.*w);
	adjustment = (X/fisher) .* w;
	h = sum(X.*adjustment,2);
	score = X' * (y-p+h.*(0.5-p));
	step = fisher\score;
	if max(abs(step)) < 1e-9
		break;
	end
	step = max(min(step,5),-5);
	oldObjective = iFirthObjective(beta,X,y);
	backtrack = 1;
	for k = 1:30
		candidate = beta+backtrack*step;
		if iFirthObjective(candidate,X,y) >= oldObjective
			beta = candidate;
			break;
		end
		backtrack = backtrack/2;
	end
	if backtrack < 1e-8
		break;
	end
end
slope = beta(2);
end

function value = iFirthObjective(beta,X,y)
eta = X*beta;
p = 1 ./ (1+exp(-eta));
w = max(p.*(1-p),1e-10);
fisher = X'*(X.*w);
[~,logDet] = chol(fisher);
if logDet > 0
	logDeterminant = 2*sum(log(diag(logDet)));
else
	logDeterminant = log(max(det(fisher),1e-300));
end
value = sum(y.*eta-log(1+exp(eta)))+0.5*logDeterminant;
end

function [permDiff, observed] = iPermuteMedianDifference(x1, x2, nPermutation, seed)
x1 = x1(:);
x2 = x2(:);
x1 = x1(isfinite(x1));
x2 = x2(isfinite(x2));
observed = median(x2) - median(x1);
allX = [x1;x2];
n1 = numel(x1);
nTotal = numel(allX);
nAssign = nchoosek(nTotal,n1);
if nAssign <= nPermutation
	assignments = nchoosek(1:nTotal,n1);
else
	rng(seed,'twister');
	assignments = nan(nPermutation,n1);
	for i = 1:nPermutation
		assignments(i,:) = randperm(nTotal,n1);
	end
end
permDiff = nan(size(assignments,1),1);
for i = 1:size(assignments,1)
	mask = false(nTotal,1);
	mask(assignments(i,:)) = true;
	permDiff(i) = median(allX(~mask)) - median(allX(mask));
end
end

function Stats = iMetricPairwise(PerMouse, variable, groupNames, nPermutation)
Stats = table();
pairIndex = 0;
for i = 1:numel(groupNames)-1
	for j = i+1:numel(groupNames)
		pairIndex = pairIndex + 1;
		g1 = groupNames(i);
		g2 = groupNames(j);
		x1 = PerMouse.(variable)(PerMouse.Group == g1);
		x2 = PerMouse.(variable)(PerMouse.Group == g2);
		[perm,observed] = iPermuteMedianDifference(x1,x2,nPermutation,pairIndex+100);
		pValue = (1+sum(abs(perm)>=abs(observed)))/(numel(perm)+1);
		Stats = [Stats; table(g2+" - "+g1,nnz(isfinite(x1)),nnz(isfinite(x2)), ...
			median(x1,'omitnan'),median(x2,'omitnan'),observed,pValue, ...
			'VariableNames',{'Comparison','N1','N2','Median1','Median2','ObservedMedianDifference','PValue'})]; %#ok<AGROW>
	end
end
Stats.PValueHolm = iHolmAdjust(Stats.PValue);
end

function pAdjusted = iHolmAdjust(p)
[sorted,order] = sort(p);
n = numel(p);
adjustedSorted = cummax((n:-1:1).' .* sorted);
adjustedSorted = min(adjustedSorted,1);
pAdjusted = nan(size(p));
pAdjusted(order) = adjustedSorted;
end

function [g1,g2] = iPairNames(index, groupNames)
k = 0;
for i = 1:numel(groupNames)-1
	for j = i+1:numel(groupNames)
		k = k + 1;
		if k == index
			g1 = groupNames(i);
			g2 = groupNames(j);
			return;
		end
	end
end
end

function [pValue,observed,nullStats] = iOmnibusPermutation(PerMouse,groupNames,nPermutation)
x = PerMouse.LogSlope(PerMouse.FitEligible);
g = PerMouse.Group(PerMouse.FitEligible);
observed = iBetweenGroupSS(x,g,groupNames);
rng(20261029,'twister');
nullStats = nan(nPermutation,1);
for i = 1:nPermutation
	nullStats(i) = iBetweenGroupSS(x,g(randperm(numel(g))),groupNames);
end
pValue = (1+sum(nullStats>=observed))/(nPermutation+1);
end

function value = iBetweenGroupSS(x,g,groupNames)
value = 0;
for group = groupNames
	mask = g == group;
	value = value + nnz(mask)*(mean(x(mask))-mean(x))^2;
end
end
