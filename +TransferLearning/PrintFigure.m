function PrintFigure(figHandle, outPath, options)
% TransferLearning.PrintFigure  Export a figure using MATLAB print.
%
% This is a thin wrapper used across the thesis figures to avoid
% exportgraphics and keep output sizing consistent with figure Paper settings.
%
% Supported extensions:
% - .svg (vector via -dsvg -painters)
% - .png (raster via -dpng, default 300 dpi)

arguments
	figHandle
	outPath (1,1) string
	options.Resolution (1,1) double = 300
	options.ForceLegendOrColorbar (1,1) logical = false
end

outPath = string(outPath);
[folder, ~, ext] = fileparts(outPath);
if strlength(folder) > 0 && ~isfolder(folder)
	mkdir(folder);
end

% Ensure we are printing the figure (not axes handle).
try
	if ~ishghandle(figHandle, 'figure')
		figHandle = ancestor(figHandle, 'figure');
	end
catch
end

try
	modeNow = string(get(figHandle, 'PaperPositionMode'));
	if ~strcmpi(modeNow, "manual")
		set(figHandle, 'PaperPositionMode', 'auto');
	end
catch
end

TransferLearning.PrepareFigureForExport(figHandle, ForceLegendOrColorbar=options.ForceLegendOrColorbar);

ext = lower(string(ext));
outPathChar = char(outPath);

switch ext
	case ".svg"
		try
			set(figHandle, 'Renderer', 'painters');
		catch
		end
		print(figHandle, outPathChar, '-dsvg', '-vector');
	case ".png"
		dpiArg = sprintf('-r%d', max(1, round(options.Resolution)));
		% opengl tends to match on-screen rendering for raster outputs.
		try
			set(figHandle, 'Renderer', 'opengl');
		catch
		end
		print(figHandle, outPathChar, '-dpng', dpiArg);
	otherwise
		error('TransferLearning:PrintFigure:UnsupportedExtension', ...
			'Unsupported output extension: %s (path=%s). Supported: .svg, .png', ext, outPathChar);
end

fprintf('Wrote: %s\n', outPathChar);
end
