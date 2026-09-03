function EncodingGLMPlotHeat(ax, tAxis, B, S, cl, cmap)
% 画编码 beta 热图并叠加显著点（黑），t=0 画竖线。
arguments
	ax (1,1) matlab.graphics.axis.Axes
	tAxis double
	B double
	S logical
	cl (1,1) double
	cmap double
end
	imagesc(ax, tAxis, 1:size(B,1), B);
	set(ax, 'YDir','normal');
	colormap(ax, cmap);
	climSafe = cl; if ~isfinite(climSafe) || climSafe==0; climSafe=1; end
	caxis(ax, [-1 1]*climSafe);
	hold(ax,'on');
	[r,c] = find(S);
	if ~isempty(r)
		plot(ax, tAxis(c), r, '.', 'Color',[0 0 0], 'MarkerSize', 1);
	end
	xline(ax, 0, '-', 'Color',[0.2 0.2 0.2], 'LineWidth', 0.8);
	hold(ax,'off');
	xlim(ax, [tAxis(1) tAxis(end)]);
	ylim(ax, [1 size(B,1)]);
	ax.FontSize = 7;
	box(ax,'off');
end
