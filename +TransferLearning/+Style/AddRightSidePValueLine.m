function [pLine, pText] = AddRightSidePValueLine(ax, xLine, yBottom, yTop, pValue)
XSpan=xlim(ax);
XSpan=(XSpan(2)-XSpan(1))/20;
xLine=xLine+XSpan;
	pLine = plot(ax, [xLine xLine], [yBottom yTop], 'k-', 'LineWidth', 0.5, 'Clipping', 'off');
	pText = text(ax, xLine + XSpan, (yTop+yBottom)/2, iFormatPValue(pValue), ...
	'FontSize', 7, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
	'Rotation', 0, 'Clipping', 'off');
	pText.AffectAutoLimits = 'on';
	ax.XLimMode = 'auto';
end

function s = iFormatPValue(pValue)
if ~isfinite(pValue)
	s = 'p=NaN';
elseif pValue < 1e-300
	s = 'p<1e-300';
elseif pValue < 0.001
    s = '＊';
elseif pValue < 0.05
	s = '＊';
else
	s = sprintf('p = %.3f', pValue);
end
end