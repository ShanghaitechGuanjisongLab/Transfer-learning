function [rho, p] = iSpearman(x, y)
% TransferLearning.Fig36.iSpearman
rho = NaN; p = NaN;
if numel(x) < 4 || numel(y) < 4
	return;
end
if std(x,'omitnan') <= 0 || std(y,'omitnan') <= 0
	return;
end
try
	[rho, p] = corr(double(x(:)), double(y(:)), 'Type','Spearman', 'Rows','complete');
catch
end
end
