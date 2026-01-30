% Fig3.8A: RelDiv(T) vs Transfer hit rate (split by layer)
%
% RelDiv(T): relative divergence of per-trial ZScore at 1s in Transfer LightWater,
% computed from the Transfer session alone.
%
% Execution:
%   TransferLearning.Fig38.A_RelDivTgivenLA_vsTransferHitRate

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

R = TransferLearning.Fig38.iBuildRelDiv_TransferGivenLearnedAudio_1s_PerMouseLayer();
if isempty(R)
	error('Fig38A:Empty', 'No valid mice for RelDiv(T).');
end

layerNames = string(["MOp2/3","MOp5"]);

outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_8a_RelDivTgivenLA_vsTransferHitRate_2panels.svg";

f = figure('Color','w', 'Name','RelDiv(T) vs Transfer hit rate');
MATLAB.Graphics.FigureAspectRatio(1,1,MATLAB.Flags.Narrow);
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
axesList = gobjects(numel(layerNames), 1);

for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	ax = nexttile(TL, iZ);
	axesList(iZ) = ax;
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	if zl == "MOp2/3"
		x = R.RelDiv23;
	else
		x = R.RelDiv5;
	end
	y = R.TransferHitRate;
	mask = isfinite(x) & isfinite(y);

	rho = NaN; p = NaN;
	if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rho, p] = corr(x(mask), y(mask), 'type','Spearman');
	end

	scatter(ax, x(mask), y(mask), 50, 'filled');
	if nnz(mask) >= 2 && std(x(mask)) > 0
		pFit = polyfit(x(mask), y(mask), 1);
		xFit = [min(x(mask)) max(x(mask))];
		yFit = polyval(pFit, xFit);
		plot(ax, xFit, yFit, '-', 'LineWidth', 1.5);
	end

	grid(ax,'on');
	box(ax,'off');
	try
		xlim(ax, iNiceNonnegLim(x(mask)));
	catch
	end
	ylim(ax, [0 1]);
	title(ax, sprintf('%s  n=%d', zl, nnz(mask)), 'Interpreter','none');
	if isfinite(p)
		text(ax, 0.02, 0.98, sprintf('rho=%.2f\np=%.3g', rho, p), 'Units','normalized', ...
			'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 9, 'Interpreter','none');
	end
	if iZ == 2
		try
			ax.YAxis.Visible = 'off';
		catch
			ax.YTickLabel = [];
		end
	end
end

try
	MATLAB.Graphics.UnifyAxesLims(axesList, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

xlabel(TL, 'RelDiv(T) at 1 s');
ylabel(TL, 'Transfer hit rate (first pure session)');
sgtitle(TL, 'RelDiv(T) vs Transfer hit rate', 'Interpreter','none');

svgPath = fullfile(outDir, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	rethrow(ME);
end

%% local helpers

function outDir = iSelectOutDir(outDirUNC)
	outDir = outDirUNC;
	try
		if ~isfolder(outDir)
			mkdir(outDir);
		end
	catch ME
		error('Fig38:UNCUnreachable', 'UNC path not accessible: %s\n%s', outDirUNC, ME.message);
	end
end

function lim = iNiceNonnegLim(x)
	if isempty(x)
		lim = [0 1];
		return;
	end
	x = x(isfinite(x));
	if isempty(x)
		lim = [0 1];
		return;
	end
	xMax = max(x);
	if ~isfinite(xMax) || xMax <= 0
		lim = [0 1];
	else
		lim = [0, xMax * 1.05];
	end
end
