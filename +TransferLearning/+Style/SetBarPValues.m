function SetBarPValues(optional)
% SetBarPValues Replace asterisk text on bar P-value lines with
% formatted P-values from the BarScatterCompare result.
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
for i = 1:height(mc)
    pt = mc.PText(i);
    pv = mc.PValue(i);
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
