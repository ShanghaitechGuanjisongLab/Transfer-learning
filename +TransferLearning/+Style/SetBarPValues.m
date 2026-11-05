function SetBarPValues(optional, pValues)
% SetBarPValues Replace asterisk text on bar P-value lines with formatted P-values.
%   SetBarPValues(optional) —— 沿用 BarScatterCompare 内部检验的 P 值
%   SetBarPValues(optional, pValues) —— 改用外部提供的 P 值（逐行对应 P 值线，
%       例如逐被试配对检验）。仅改写文本，线的位置仍由 MATLAB.Graphics.PLine
%       自动布局，因此当设计不是未配对检验时应使用此重载。
%   optional: second output of UniExp.BarScatterCompare.
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare')
    return;
end
mc = optional.MultiCompare;
if ~istable(mc) || ~ismember('PText', mc.Properties.VariableNames)
    return;
end
if ~ismember('PValue', mc.Properties.VariableNames)
    return;
end
if nargin < 2 || isempty(pValues)
    pValues = mc.PValue;
else
    assert(numel(pValues) == height(mc), ...
        'SetBarPValues:PValueCountMismatch', 'P 值个数（%d）必须与 P 值线条数（%d）一致。', ...
        numel(pValues), height(mc));
end
for i = 1:height(mc)
    pt = mc.PText(i);
    pv = pValues(i);
    if isgraphics(pt) && isfinite(pv)
        pt.String = TransferLearning.Style.iFormatPText(pv);
        pt.Tag = sprintf('PText_%d', i);
    end
end
if ismember('PLine', mc.Properties.VariableNames)
    for i = 1:height(mc)
        pl = mc.PLine(i);
        if isgraphics(pl)
            pl.Tag = sprintf('PLine_%d', i);
        end
    end
end
end
