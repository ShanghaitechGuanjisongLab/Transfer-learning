function Y = SigmoidCurve(Fit, X)
%SIGMOIDCURVE Evaluate a FitSigmoidGroup fit on X.
Y = Fit.Lower + (Fit.Upper - Fit.Lower) ./ (1 + exp(-Fit.Slope .* (X - Fit.Midpoint)));
end
