function pStr = iFormatPText(pValue)
% Format a P-value for text display.
%   p < 0.001  → "p<0.001"
%   p < 0.1    → 3 decimal places (e.g., "p=0.023")
%   p ≥ 0.1    → 2 decimal places (e.g., "p=0.65")
if nargin < 1 || ~isfinite(pValue)
    pStr = '';
    return;
end
if pValue < 0.001
    pStr = "p<0.001";
elseif pValue < 0.1
    pStr = sprintf("p=%.3f", pValue);
else
    pStr = sprintf("p=%.2f", pValue);
end
end
