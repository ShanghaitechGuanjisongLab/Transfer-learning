% Fig3.7J (alt): Adjacent-session DeltaHit vs previous-session RelDiv at 1.5s
%
% After excluding the first 100% hit session and all later sessions (per mouse),
% compute for each adjacent session pair:
% - DeltaHit = Hit(next) - Hit(prev)
% - RelDiv1p5Prev = relative divergence at 1.5s for the previous session
%
% Relative divergence algorithm follows Fig38 (per-trial ZScore at 1.5s).
%
% Execution:
%   TransferLearning.Fig37.J_DeltaHit_vs_PrevRelDiv1p5s

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

pairs = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_PrevRelDiv1p5s();
if isempty(pairs)
	error('Fig37JRelDiv:Empty', 'No valid adjacent session pairs.');
end

outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_7j_DeltaHit_vs_PrevRelDiv1p5s.svg";

f = figure('Color','w', 'Name','DeltaHit vs prev-session RelDiv@1.5s');
MATLAB.Graphics.FigureAspectRatio(1,1,MATLAB.Flags.Narrow);
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

stageList = ["LightNaive","AudioToLight"];
axesList = gobjects(2,1);

for iS = 1:2
	stageName = stageList(iS);
	ax = nexttile(TL, iS);
	axesList(iS) = ax;
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	Tp = pairs(pairs.Stage == stageName, :);
	x = Tp.RelDiv1p5Prev;
	y = Tp.DeltaHit;
	mask = isfinite(x) & isfinite(y);

	rS = NaN; pS = NaN;
	rP = NaN; pP = NaN;
	if nnz(mask) >= 6 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rS, pS] = corr(x(mask), y(mask), 'Type','Spearman');
		[rP, pP] = corr(x(mask), y(mask), 'Type','Pearson');
	end

	scatter(ax, x(mask), y(mask), 28, 'filled', 'MarkerFaceAlpha', 0.75);
	if nnz(mask) >= 2 && std(x(mask)) > 0
		pFit = polyfit(x(mask), y(mask), 1);
		xFit = [min(x(mask)) max(x(mask))];
		yFit = polyval(pFit, xFit);
		plot(ax, xFit, yFit, '-', 'LineWidth', 1.5);
	end

	grid(ax,'on');
	box(ax,'off');
	xlabel(ax, 'Prev-session RelDiv @1.5s');
	ylabel(ax, '\Delta Hit (next - prev)');
	title(ax, sprintf('%s  nPairs=%d', stageName, nnz(mask)), 'Interpreter','none');
	if isfinite(pS)
		text(ax, 0.02, 0.98, sprintf('Spearman \\rho=%.2f  p=%.3g\nPearson r=%.2f  p=%.3g', rS, pS, rP, pP), ...
			'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 9, 'Interpreter','none');
	end
end

try
	MATLAB.Graphics.UnifyAxesLims(axesList, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

sgtitle(TL, 'Adjacent-session behavior change vs previous-session relative divergence (1.5s)', 'Interpreter','none');

svgPath = fullfile(outDir, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	rethrow(ME);
end

% pooled stats
maskAll = isfinite(pairs.RelDiv1p5Prev) & isfinite(pairs.DeltaHit);
if nnz(maskAll) >= 6 && std(pairs.RelDiv1p5Prev(maskAll)) > 0 && std(pairs.DeltaHit(maskAll)) > 0
	[rS, pS] = corr(pairs.RelDiv1p5Prev(maskAll), pairs.DeltaHit(maskAll), 'Type','Spearman');
	[rP, pP] = corr(pairs.RelDiv1p5Prev(maskAll), pairs.DeltaHit(maskAll), 'Type','Pearson');
	fprintf('Pooled pairs: n=%d\n', nnz(maskAll));
	fprintf('  Spearman rho=%.4f, p=%.4g\n', rS, pS);
	fprintf('  Pearson  r =%.4f, p=%.4g\n', rP, pP);
else
	fprintf('Pooled pairs: n=%d (insufficient variance)\n', nnz(maskAll));
end

%% local helpers

function outDir = iSelectOutDir(outDirUNC)
	outDir = outDirUNC;
	try
		if ~isfolder(outDir)
			mkdir(outDir);
		end
		return;
	catch
	end
	outDir = TransferLearning.ProjectPath('exports');
	try
		if ~isfolder(outDir)
			mkdir(outDir);
		end
	catch
	end
end
