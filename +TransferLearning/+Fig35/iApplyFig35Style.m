function iApplyFig35Style(figHandle)
% TransferLearning.Fig35.iApplyFig35Style
% Unify visual style for Fig3.5 panels (titles, labels, text, legends, axes).

if nargin < 1 || isempty(figHandle)
	figHandle = gcf;
end

try
	if ~ishghandle(figHandle, 'figure')
		figHandle = ancestor(figHandle, 'figure');
	end
catch
end

% Global defaults (do NOT modify fonts; keep MATLAB automatic)
axisLineWidth = 0.75;
minLineWidth = 1.0;

% Figure background
try
	figHandle.Color = 'w';
catch
end

% Axes
axAll = [];
try
	axAll = findall(figHandle, 'Type', 'axes');
catch
end

for i = 1:numel(axAll)
	ax = axAll(i);
	try
		ax.LineWidth = axisLineWidth;
		ax.TickDir = 'out';
		ax.Box = 'off';
		ax.Clipping = 'off';
		ax.Layer = 'top';
		ax.XColor = [0 0 0];
		ax.YColor = [0 0 0];
		grid(ax, 'off');
	catch
	end

	% Labels / titles
	try
		if ~isempty(ax.Title)
			ax.Title.Interpreter = 'none';
		end
	catch
	end
	try
		if ~isempty(ax.XLabel)
			ax.XLabel.Interpreter = 'none';
		end
	catch
	end
	try
		if ~isempty(ax.YLabel)
			ax.YLabel.Interpreter = 'none';
		end
	catch
	end

	% Do not auto-adjust ylim here (panel-specific ylim preferred).
end

% Legends
try
	lgdAll = findall(figHandle, 'Type', 'legend');
	for i = 1:numel(lgdAll)
		lgd = lgdAll(i);
		try
			lgd.Interpreter = 'none';
			lgd.Box = 'off';
		catch
		end
	end
catch
end

% Text objects (annotations, p-values, etc.)
try
	txtAll = findall(figHandle, 'Type', 'text');
	for i = 1:numel(txtAll)
		t = txtAll(i);
		try
			t.Interpreter = 'none';
		catch
		end
	end
catch
end

% Lines / markers
try
	lnAll = findall(figHandle, 'Type', 'line');
	for i = 1:numel(lnAll)
		ln = lnAll(i);
		try
			if isprop(ln, 'LineWidth') && isfinite(ln.LineWidth) && ln.LineWidth < minLineWidth
				ln.LineWidth = minLineWidth;
			end
		catch
		end
	end
catch
end

% Swarm/Scatter sizing (best-effort)
try
	objAll = findall(figHandle);
	for i = 1:numel(objAll)
		obj = objAll(i);
		try
			if isprop(obj, 'SizeData') && isnumeric(obj.SizeData)
				% Normalize scalar SizeData only (avoid per-point arrays)
				if isscalar(obj.SizeData)
					obj.SizeData = 20;
				end
			end
		catch
		end
	end
catch
end

try
	drawnow;
catch
end
end
