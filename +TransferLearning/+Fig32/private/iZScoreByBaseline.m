function Z = iZScoreByBaseline(S, baseMask)
mu = mean(S(:, baseMask), 2, 'omitnan');
sd = std(S(:, baseMask), 0, 2, 'omitnan');
sd(sd == 0 | ~isfinite(sd)) = 1;
Z = (S - mu) ./ sd;
end
