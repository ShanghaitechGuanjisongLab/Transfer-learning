function [Coeff, Score, Explained, out] = OperationVectorPca(CellTime)
%OperationVectorPca Constrained PCA with fixed PC1 (operation vector).
%
% [Coeff, Score, Explained] = TransferLearning.OperationVectorPca(CellTime)
%
% Input
%   CellTime: nCells x nTime matrix (cells as state-space dimensions)
%
% Constraint
%   PC1 direction is forced to point from initial state xInit to final state
%   xFinal. Additionally, PC1 score is normalized so that:
%     Score(tInit,1) = 0  and  Score(tFinal,1) = 1
%
% Remaining PCs (PC2+) are obtained by running standard PCA on the residual
% after removing the PC1 component (i.e., in the subspace orthogonal to the
% operation vector).
%
% Output (like pca)
%   Coeff      nCells x 2 loadings  [PC1 fixed, PC2 residual-max]
%   Score      nTime  x 2 scores
%   Explained  1 x 2 variance explained (%) relative to total variance
%
% Optional
%   out struct with intermediate results (xInit/xFinal/opVector/residual etc.)

	validateattributes(CellTime, {'numeric'}, {'2d', 'finite'}, mfilename, 'CellTime');
	X = double(CellTime);
	[nCells, nTime] = size(X);

	if nTime < 2
		error('TransferLearning:OperationVectorPca:TooFewTimepoints', 'Need at least 2 timepoints.');
	end

	% Fixed defaults per spec
	initialIdx = 1;
	finalIdx = nTime;

	% Define endpoint states (optionally averaged over windows)
	xInit = mean(X(:, initialIdx), 2);
	xFinal = mean(X(:, finalIdx), 2);
	op = xFinal - xInit;

	opNorm2 = dot(op, op);
	if ~(isfinite(opNorm2) && opNorm2 > 0)
		error('TransferLearning:OperationVectorPca:DegenerateOpVector', 'xFinal-xInit is zero/invalid; cannot define PC1.');
	end

	% Work in coordinates with xInit as origin so "initial state = 0".
	X0 = X - xInit;

	% PC1 score normalized so xInit->0 and xFinal->1.
	% score1(t) = <op, x(t)-xInit> / <op, op>
	score1 = (X0.' * op) / opNorm2; % nTime x 1

	% PC1 loading as a unit vector (for interpretability)
	pc1CoeffUnit = op / sqrt(opNorm2); % nCells x 1

	% Remove the PC1 component (anchored at xInit)
	Xpc1 = op * score1';
	R = X0 - Xpc1;

	% Residual PCA: keep only the maximum-variance component (PC2)
	% (No extra pca options by spec)
	% IMPORTANT: Use Centered=false so that when R(:,t)=0 (at init/final),
	% the corresponding PC2 score is exactly 0.
	[coeffAll, scoreAll, latentAll, ~, ~, muR] = pca(R', 'Centered', false);
	if isempty(coeffAll)
		coeffR1 = zeros(nCells, 1);
		scoreR1 = zeros(nTime, 1);
		latentR1 = 0;
	else
		coeffR1 = coeffAll(:, 1);
		scoreR1 = scoreAll(:, 1);
		latentR1 = latentAll(1);
	end

	% Numerical safeguard: enforce PC2 loading orthogonal to PC1 loading.
	% (In exact math this is already true because R lies in the orthogonal subspace.)
	coeffR1 = coeffR1 - pc1CoeffUnit * (pc1CoeffUnit' * coeffR1);
	coeffR1Norm = norm(coeffR1);
	if coeffR1Norm > 0
		coeffR1 = coeffR1 / coeffR1Norm;
		scoreR1 = R.' * coeffR1;
	end

	Coeff = [pc1CoeffUnit, coeffR1];
	Score = [score1, scoreR1];

	% Explained variance (%) computed vs total variance in X0 (centered by mean across time)
	% to be consistent with pca() conventions.
	if nTime >= 2
		totalVar = trace(cov(X0')); % cov expects observations x variables
	else
		totalVar = 0;
	end

	if totalVar <= 0 || ~isfinite(totalVar)
		Explained = zeros(1, 2);
	else
		% variance captured by PC1 (use unnormalized projection onto unit vector)
		s1 = X0.' * pc1CoeffUnit; % nTime x 1
		v1 = var(s1, 0);
		Explained = [100 * v1 / totalVar, (100 * latentR1 / totalVar)];
	end

	out = struct();
	out.xInit = xInit;
	out.xFinal = xFinal;
	out.opVector = op;
	out.pc1CoeffUnit = pc1CoeffUnit;
	out.residual = R;
	out.residualMu = muR;
end

%[appendix]{"version":"1.0"}
%---
