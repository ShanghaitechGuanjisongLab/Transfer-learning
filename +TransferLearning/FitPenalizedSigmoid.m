function fit = FitPenalizedSigmoid(blockInput, behavior, options)
% Per-mouse sigmoid with free lower asymptote, slope, and midpoint.
%   p(x) = L + (1-L)/(1+exp(-k*(x-m)))
% Fit trial-level Bernoulli outcomes by penalized binomial likelihood.
% The penalty includes 0.5*log(det(I)), where I is the Fisher information
% evaluated analytically from the sigmoid derivatives (Jeffreys/Firth-type),
% and a weakly informative log(k)~N(0,2^2) penalty for identifiability.
% These limit complete-separation divergence without changing raw data.
%
% fit.Slope is k in reciprocal training-block units. Set FixLowerZero=true
% to fit only slope and midpoint when a three-parameter fit is not
% identifiable (for example, two-block curves).

arguments
	blockInput (:,1) double
	behavior (:,1) double
	options.FixLowerZero (1,1) logical = false
end
x = blockInput(:);
y = behavior(:);
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(x) < 2 || numel(unique(x)) < 2
	error('TransferLearning:SigmoidInsufficientBlocks', ...
		'At least two distinct training blocks are required.');
end
if any(y ~= 0 & y ~= 1)
	error('TransferLearning:SigmoidNonBinaryOutcome', ...
		'Behavior must contain binary trial outcomes.');
end

lowerStarts = [min(max(min(y),0.45),0.01),0.05,0.20];
slopeStarts = [0.2,0.8,2,6];
midpointStarts = unique([median(x),min(x),max(x)]);
optimOptions = optimset('Display','off','MaxFunEvals',5000,'MaxIter',2000);
bestObjective = inf;
bestParameters = NaN(1,3-2*options.FixLowerZero);
for lower = lowerStarts
	for slope = slopeStarts
		for midpoint = midpointStarts
			initial = [log(lower/(1-lower)),log(slope),midpoint];
			if options.FixLowerZero
				initial = initial(2:3);
			end
			parameters = fminsearch(@(p) iObjective(p,x,y,options.FixLowerZero),initial,optimOptions);
			objective = iObjective(parameters,x,y,options.FixLowerZero);
			if isfinite(objective) && objective < bestObjective
				bestObjective = objective;
				bestParameters = parameters;
			end
		end
	end
end
if ~all(isfinite(bestParameters))
	error('TransferLearning:SigmoidFitFailed','No finite penalized sigmoid fit.');
end

[penalizedObjective,logLikelihood,penalty,information] = ...
	iObjective(bestParameters,x,y,options.FixLowerZero);
fullParameters = iExpandParameters(bestParameters,options.FixLowerZero);
lower = 1/(1+exp(-fullParameters(1)));
slope = exp(fullParameters(2));
midpoint = fullParameters(3);
predicted = iPredict(fullParameters,unique(x),false);
observed = splitapply(@mean,y,findgroups(x));
sst = sum((observed-mean(observed)).^2);
sse = sum((observed-predicted).^2);
if sst > 0
	rSquared = 1-sse/sst;
else
	rSquared = NaN;
end
covariance = inv(information);
standardErrors = sqrt(max(diag(covariance),0));
fit = struct( ...
	'Lower',lower,'Slope',slope,'Midpoint',midpoint, ...
	'Parameters',fullParameters,'FreeParameters',bestParameters, ...
	'StandardErrors',standardErrors,'FixLowerZero',options.FixLowerZero, ...
	'LogLikelihood',logLikelihood,'Penalty',penalty, ...
	'Objective',penalizedObjective,'RSquared',rSquared, ...
	'NBlocks',numel(unique(x)),'NTrials',numel(y), ...
	'AtSlopeBoundary',slope >= 20, ...
	'Method',"Penalized binomial sigmoid; Jeffreys information and weak log-slope penalties");
end

function [objective,logLikelihood,penalty,information] = iObjective(parameters,x,y,fixLowerZero)
fullParameters = iExpandParameters(parameters,fixLowerZero);
[probability,jacobian] = iPredict(fullParameters,x,fixLowerZero);
probability = min(max(probability,1e-12),1-1e-12);
logLikelihood = sum(y.*log(probability)+(1-y).*log(1-probability));
weights = probability.*(1-probability);
information = jacobian' * (jacobian.*weights);
% Fisher information must remain positive definite. A tiny numerical ridge
% is only used for roundoff, not as a parameter-regularizing prior.
information = information + eye(size(information))*1e-10;
[cholFactor,flag] = chol(information);
if flag ~= 0
	objective = 1e12;
	penalty = NaN;
	return;
end
penalty = sum(log(diag(cholFactor)));
% Weakly informative regularization supplements, rather than replaces,
% the Jeffreys term because the latter alone can retain unbounded step fits.
logSlopePenalty = 0.5*(fullParameters(2)/2)^2;
penalty = penalty-logSlopePenalty;
objective = -(logLikelihood+penalty);
end

function fullParameters = iExpandParameters(parameters,fixLowerZero)
if fixLowerZero
	fullParameters = [-Inf,parameters];
else
	fullParameters = parameters;
end
end

function [probability,jacobian] = iPredict(parameters,x,fixLowerZero)
lower = 1/(1+exp(-parameters(1)));
slope = exp(parameters(2));
midpoint = parameters(3);
eta = slope*(x-midpoint);
% Evaluate q=1/(1+exp(-eta)) without overflow.
q = zeros(size(x));
q(eta >= 0) = 1 ./ (1+exp(-eta(eta >= 0)));
expEta = exp(eta(eta < 0));
q(eta < 0) = expEta ./ (1+expEta);
dq_deta = q.*(1-q);
probability = lower+(1-lower).*q;
% dL/d(a)=L(1-L); db=log(k), dm=midpoint.
jacobian = [ (1-q).*lower.*(1-lower), ...
	(1-lower).*dq_deta.*(x-midpoint), ...
	-(1-lower).*slope.*dq_deta ];
if fixLowerZero
	jacobian = jacobian(:,2:3);
end
end
