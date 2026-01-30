function [pLines, pTexts] = iSwarm2(ax, yA, yB, labels, yLabel, p, opts)
% TransferLearning.Fig35.iSwarm2
% Two-group swarm plot with center line (median) and optional PLine p-value.
%
% Notes:
% - Does NOT modify fonts/sizes (keeps MATLAB defaults).
% - Designed for consistent look across Fig3.5 panels.

arguments
	ax
	yA
	yB
	labels
	yLabel
	p double = NaN
	opts.centerLine (1,1) logical = true
	opts.centerStatistic (1,1) string {mustBeMember(opts.centerStatistic,["median","mean"])} = "median"
	opts.markerSize (1,1) double = 24
	opts.markerAlpha (1,1) double = 0.75
	opts.extraOffset double = 0
end

if isempty(ax) || ~ishghandle(ax)
	ax = gca;
end

pLines = matlab.graphics.primitive.Line.empty(0,1);
pTexts = matlab.graphics.primitive.Text.empty(0,1);

try
	labels = string(labels);
catch
	labels = ["A","B"];
end
if numel(labels) ~= 2
	labels = ["GroupA","GroupB"];
end

yA = double(yA(:));
yB = double(yB(:));
yA = yA(isfinite(yA));
yB = yB(isfinite(yB));

hold(ax, 'on');

% Swarm points
if ~isempty(yA)
	swarmchart(ax, ones(size(yA)), yA, opts.markerSize, 'filled', 'MarkerFaceAlpha', opts.markerAlpha);
end
if ~isempty(yB)
	swarmchart(ax, 2*ones(size(yB)), yB, opts.markerSize, 'filled', 'MarkerFaceAlpha', opts.markerAlpha);
end

% Center line
if opts.centerLine
	if opts.centerStatistic == "mean"
		cA = mean(yA, 'omitnan');
		cB = mean(yB, 'omitnan');
	else
		cA = median(yA, 'omitnan');
		cB = median(yB, 'omitnan');
	end
	if isfinite(cA)
		plot(ax, [0.85 1.15], [cA cA], '-', 'LineWidth', 2);
	end
	if isfinite(cB)
		plot(ax, [1.85 2.15], [cB cB], '-', 'LineWidth', 2);
	end
end

ax.XLim = [0.5 2.5];
ax.XTick = [1 2];
ax.XTickLabel = {sprintf('%s (n=%d)', labels(1), numel(yA)), sprintf('%s (n=%d)', labels(2), numel(yB))};

ylabel(ax, yLabel, 'Interpreter','none');

% P-value line (via MATLAB.Graphics.PLine)
if isfinite(p) && ~isempty(yA) && ~isempty(yB)
	try
		X = [ones(numel(yA),1); 2*ones(numel(yB),1)];
		Y = [yA; yB];
		S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
		try
			if isprop(S, 'HitTest'); S.HitTest = 'off'; end
			if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
			if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
		catch
		end
		Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), opts.extraOffset, ...
			'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
		[pLines, pTexts] = MATLAB.Graphics.PLine(Descriptors);
		try, delete(S); catch, end
	catch
	end
end
end
