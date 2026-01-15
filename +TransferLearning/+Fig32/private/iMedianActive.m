function act = iMedianActive(X, baseMask, winMask, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
winMx = max(X(:, winMask), [], 2, 'omitnan');
act = winMx > (baseMu + kSigma .* baseSd);
end
