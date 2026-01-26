function onsetSec = iOnsetByCell(X, xsSec, baseMask)
% TransferLearning.Fig36.iOnsetByCell
% onset: first sample >=0s where X > baseMu + 3*baseSd
X = double(X);
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
th = baseMu + 3 .* baseSd;

postMask = xsSec >= 0;
idxPost = find(postMask);

onsetSec = nan(size(X,1),1);
for i = 1:size(X,1)
	if ~isfinite(th(i))
		continue;
	end
	v = X(i, idxPost);
	k = find(v > th(i), 1, 'first');
	if ~isempty(k)
		onsetSec(i) = double(xsSec(idxPost(k)));
	end
end
end
