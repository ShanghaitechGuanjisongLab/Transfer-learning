function Fit = FitSigmoidGroup(T, GroupName, LowerFixed)
%FITSIGMOIDGROUP Group-level sigmoid fit of hit rate over block index.
%   Fit = FitSigmoidGroup(T, GroupName) fits lower asymptote, slope and
%   midpoint, with the upper asymptote fixed at 1 (spec of
%   FigS1D_UndelayedLearningCurveAndFirstBlock and Fig1G).
%   Fit = FitSigmoidGroup(T, GroupName, true) additionally fixes the lower
%   asymptote at 0 (spec of Fig1B_LearningCurve_Sigmoid).
arguments
	T table
	GroupName (1,1) string
	LowerFixed (1,1) logical = false
end
xObs = double(T.Block(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('DelayComparison:NoDataForFit', 'No valid block data for %s.', GroupName);
end
opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
if LowerFixed
	p0 = [log(0.8); max(median(xObs), 1)];
	obj = @(p) sum((yObs - iSigmoidZeroLower(p, xObs)).^2, 'omitnan');
	p = fminsearch(obj, p0, opt);
	lower = 0; upper = 1; slope = exp(p(1)); midpoint = p(2);
	yHat = iSigmoidZeroLower(p, xObs);
else
	p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); max(median(xObs), 1)];
	obj = @(p) sum((yObs - iSigmoidFreeLower(p, xObs)).^2, 'omitnan');
	p = fminsearch(obj, p0, opt);
	lower = 1 ./ (1 + exp(-p(1))); upper = 1; slope = exp(p(2)); midpoint = p(3);
	yHat = iSigmoidFreeLower(p, xObs);
end
SSE = sum((yObs - yHat).^2, 'omitnan');
SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
Fit = struct;
Fit.Group = GroupName;
Fit.ParamRaw = p;
Fit.LowerFixed = LowerFixed;
Fit.Lower = lower;
Fit.Upper = upper;
Fit.Slope = slope;
Fit.Midpoint = midpoint;
Fit.SSE = SSE;
if SST > 0
	Fit.RSquared = 1 - SSE / SST;
else
	Fit.RSquared = NaN;
end
end

function y = iSigmoidFreeLower(p, x)
lower = 1 ./ (1 + exp(-p(1)));
y = lower + (1 - lower) ./ (1 + exp(-exp(p(2)) .* (x - p(3))));
end

function y = iSigmoidZeroLower(p, x)
y = 1 ./ (1 + exp(-exp(p(1)) .* (x - p(2))));
end

function y = iLogit(x)
x = min(max(x, 1e-6), 1 - 1e-6);
y = log(x ./ (1 - x));
end
