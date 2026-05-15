function stats = CompareSigmoidSlope(performanceA, performanceB, nameA, nameB, nPermutation, rngSeed)
if nargin < 3 || isempty(nameA)
	nameA = "A";
end
if nargin < 4 || isempty(nameB)
	nameB = "B";
end
if nargin < 5 || isempty(nPermutation)
	nPermutation = 2000;
end
if nargin < 6
	rngSeed = [];
end

tableA = iPerformanceMatrixToSessionTable(performanceA, string(nameA));
tableB = iPerformanceMatrixToSessionTable(performanceB, string(nameB));
fitA = iFitModelSigmoidCurve(tableA, string(nameA));
fitB = iFitModelSigmoidCurve(tableB, string(nameB));
permutation = iPermutationTestModelSigmoidSlope(tableA, tableB, fitA, fitB, nPermutation, rngSeed);

stats = struct;
stats.SessionTableA = tableA;
stats.SessionTableB = tableB;
stats.FitA = fitA;
stats.FitB = fitB;
stats.FitTable = struct2table([fitA; fitB]);
stats.ComparisonTable = table( ...
	string(nameB) + " - " + string(nameA), ...
	permutation.ObservedDifference, ...
	permutation.PValueRight, ...
	permutation.PValueTwoSided, ...
	permutation.NPermutation, ...
	mean(permutation.PermutedDifference, 'omitnan'), ...
	std(permutation.PermutedDifference, 0, 'omitnan'), ...
	'VariableNames', {'Comparison','ObservedSlopeDifference','PValueRight','PValueTwoSided','NPermutation','NullMeanDifference','NullStdDifference'});
stats.PermutedDifference = permutation.PermutedDifference;
end

function T = iPerformanceMatrixToSessionTable(performanceMatrix, conditionName)
[nMice, nSessions] = size(performanceMatrix);
[mouseIndex, sessionIndex] = ndgrid((1:nMice)', (1:nSessions)');
T = table;
T.Mouse = string(conditionName) + "_" + string(compose('%03d', mouseIndex(:)));
T.Session = sessionIndex(:);
T.Performance = performanceMatrix(:);
T.Group = repmat(string(conditionName), numel(T.Performance), 1);
end

function fitOut = iFitModelSigmoidCurve(T, groupName)
T = sortrows(T, {'Mouse','Session'});
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('THModel:NoDataForSigmoidFit', 'No valid session data for group %s.', char(groupName));
end

p0 = [iSigmoidLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); log(max(median(xObs), 1))];
obj = @(p) sum((yObs - iModelSigmoidFromParams(p, xObs)).^2, 'omitnan');
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
p = fminsearch(obj, p0, opt);
yHat = iModelSigmoidFromParams(p, xObs);
sse = sum((yObs - yHat).^2, 'omitnan');
sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
if sst == 0
	rSquared = NaN;
else
	rSquared = 1 - sse / sst;
end
[lower, upper, slope, midpoint] = iDecodeModelSigmoidParams(p);
fitOut = struct;
fitOut.Group = string(groupName);
fitOut.Lower = lower;
fitOut.Upper = upper;
fitOut.Slope = slope;
fitOut.Midpoint = midpoint;
fitOut.SSE = sse;
fitOut.RSquared = rSquared;
fitOut.NObservation = numel(yObs);
fitOut.NMouse = numel(unique(string(T.Mouse), 'stable'));
end

function permOut = iPermutationTestModelSigmoidSlope(tableA, tableB, fitA, fitB, nPermutation, rngSeed)
if ~isempty(rngSeed)
	rng(rngSeed);
end
tableA = sortrows(tableA, {'Mouse','Session'});
tableB = sortrows(tableB, {'Mouse','Session'});
miceA = unique(string(tableA.Mouse), 'stable');
miceB = unique(string(tableB.Mouse), 'stable');
allMouseTables = cell(numel(miceA) + numel(miceB), 1);
for iMouse = 1:numel(miceA)
	allMouseTables{iMouse} = tableA(string(tableA.Mouse) == miceA(iMouse), :);
end
for iMouse = 1:numel(miceB)
	allMouseTables{numel(miceA) + iMouse} = tableB(string(tableB.Mouse) == miceB(iMouse), :);
end

observedDiff = fitB.Slope - fitA.Slope;
if nPermutation <= 0
	permOut = struct;
	permOut.ObservedDifference = observedDiff;
	permOut.PermutedDifference = nan(0, 1);
	permOut.PValueRight = NaN;
	permOut.PValueTwoSided = NaN;
	permOut.NPermutation = 0;
	return;
end
permutationOrder = nan(nPermutation, numel(allMouseTables));
for iPerm = 1:nPermutation
	permutationOrder(iPerm, :) = randperm(numel(allMouseTables));
end

permDiff = nan(nPermutation, 1);
nA = numel(miceA);
parfor iPerm = 1:nPermutation
	ord = permutationOrder(iPerm, :);
	idxA = ord(1:nA);
	idxB = ord(nA+1:end);
	permA = vertcat(allMouseTables{idxA});
	permB = vertcat(allMouseTables{idxB});
	fitPermA = iFitModelSigmoidCurve(permA, "ModelSigmoidPermA");
	fitPermB = iFitModelSigmoidCurve(permB, "ModelSigmoidPermB");
	permDiff(iPerm) = fitPermB.Slope - fitPermA.Slope;
end

permOut = struct;
permOut.ObservedDifference = observedDiff;
permOut.PermutedDifference = permDiff;
permOut.PValueRight = mean(permDiff >= observedDiff);
permOut.PValueTwoSided = mean(abs(permDiff) >= abs(observedDiff));
permOut.NPermutation = nPermutation;
end

function y = iModelSigmoidFromParams(p, x)
[lower, upper, slope, midpoint] = iDecodeModelSigmoidParams(p);
y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeModelSigmoidParams(p)
lower = 1 ./ (1 + exp(-p(1)));
upper = 1;
slope = exp(p(2));
midpoint = exp(p(3));
end

function y = iSigmoidLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end