function [p, stats] = iRanksumSafe(x, y)
% Safe wrapper around ranksum that returns NaN when not applicable.
stats = struct();
if nargin < 2
    p = nan;
    return;
end
x = x(:); y = y(:);
x = x(isfinite(x));
y = y(isfinite(y));
if numel(x) < 1 || numel(y) < 1
    p = nan;
    return;
end
try
    [p, ~, stats] = ranksum(x, y);
catch
    p = nan;
    stats = struct();
end
end
