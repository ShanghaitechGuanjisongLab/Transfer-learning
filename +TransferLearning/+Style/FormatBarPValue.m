function FormatBarPValue(ax, pValue)
% Add formatted P-value text between two bars at positions 1 and 2.
% pValue: scalar P-value (NaN to skip).
% Formatting rules:
%   p < 0.001  → "p<0.001"
%   p < 0.1    → 3 decimal places (e.g., "p=0.023")
%   p ≥ 0.1    → 2 decimal places (e.g., "p=0.65")
if nargin < 2 || ~isfinite(pValue)
    return;
end

if pValue < 0.001
    pStr = 'p<0.001';
elseif pValue < 0.1
    pStr = sprintf('p=%.3f', pValue);
else
    pStr = sprintf('p=%.2f', pValue);
end

% Remove any existing PLine/PText objects
delete(findobj(ax, 'Tag', 'PLine'));
delete(findobj(ax, 'Tag', 'PText'));

% Find the highest data point in the axes to position text
children = findobj(ax, '-property', 'YData');
maxY = -inf;
for c = children(:)'
    try
        y = get(c, 'YData');
        if ~isempty(y)
            maxY = max(maxY, max(y(:)));
        end
    catch
    end
end

% Also consider error bars (which may extend above data)
eb = findobj(ax, 'Type', 'ErrorBar');
for e = eb(:)'
    try
        if isprop(e, 'YPositiveDelta')
            yd = e.YPositiveDelta;
            if ~isempty(yd)
                yBase = e.YData;
                maxY = max(maxY, max(yBase(:) + yd(:)));
            end
        end
    catch
    end
end

if ~isfinite(maxY)
    maxY = 1;
end

yl = ylim(ax);
yrange = yl(2) - yl(1);
% Position text above the highest data point
textY = max(max(yl(2), maxY), maxY + 0.05 * yrange);
text(ax, 1.5, textY, pStr, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', ...
    'FontSize', 12, ...
    'Tag', 'PText');
end
