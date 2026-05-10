function [p, h] = iRanksumSafe(x, y)
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if isempty(x) || isempty(y)
	p = NaN;
	h = NaN;
	return;
end
[p, h] = ranksum(x, y);
end