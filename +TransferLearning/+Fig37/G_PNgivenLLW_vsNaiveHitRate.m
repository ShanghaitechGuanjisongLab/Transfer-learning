% Fig3.7G: P(N|L) vs Naive hit rate (split by layer)
%
% P(N|L): Naive LightWater active at 1s | Learned LightWater active at 1s
% Sessions (pure):
% - Naive  LightWater: first pure session (forbid AudioWater)
% - Learned LightWater: last  pure session (forbid AudioWater)
% Behavior: Naive hit rate in the chosen Naive session (trial-level)
%
% Execution:
%   TransferLearning.Fig37.G_PNgivenLLW_vsNaiveHitRate

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

R = TransferLearning.Fig37.iBuildProb_NaiveHitMissGivenLearnedLight_1s_PerMouseLayer();
if isempty(R)
	error('Fig37G:Empty', 'No valid mice for P(N|L).');
end

layerNames = string(["MOp2/3","MOp5"]);
outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_7g_PNgivenLLW_vsNaiveHitRate_2panels.svg";

f = figure('Color','w', 'Name','P(N|L) vs Naive hit rate');
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
		x = R.Prob23;
	else
		x = R.Prob5;
	end
	y = R.NaiveHitRate;
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
	% Do not show mouse names on scatter
	grid(ax,'on');
	box(ax,'off');
	xlim(ax, [0 1]);
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

xlabel(TL, 'P(N|L) at 1 s');
ylabel(TL, 'Naive hit rate (first pure session)');
sgtitle(TL, 'P(N|L) vs Naive hit rate', 'Interpreter','none');

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
		error('Fig37:UNCUnreachable', 'UNC path not accessible: %s\n%s', outDirUNC, ME.message);
	end
end
