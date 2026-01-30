% Fig3.7J (alt, by-layer): Adjacent-session DeltaHit vs previous-session RelDiv at 1.5s
%
% Same as J_DeltaHit_vs_PrevRelDiv1p5s, but split by layer (MOp2/3 vs MOp5).
%
% Execution:
%   TransferLearning.Fig37.J_DeltaHit_vs_PrevRelDiv1p5s_ByLayer

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

pairs = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_PrevRelDiv1p5s_ByLayer();
if isempty(pairs)
	error('Fig37JRelDivByLayer:Empty', 'No valid adjacent session pairs (by layer).');
end

outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_7j_DeltaHit_vs_PrevRelDiv1p5s_ByLayer.svg";

f = figure('Color','w', 'Name','DeltaHit vs prev-session RelDiv@1.5s (by layer)');
MATLAB.Graphics.FigureAspectRatio(1.5,1,MATLAB.Flags.Narrow);
TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

stageList = ["LightNaive","AudioToLight"];
layerList = ["MOp23","MOp5"];
axesList = gobjects(4,1);
axN = 0;

for iL = 1:2
	zKey = layerList(iL);
	for iS = 1:2
		stageName = stageList(iS);
		ax = nexttile(TL, (iL-1)*2 + iS);
		axN = axN + 1;
		axesList(axN) = ax;
		hold(ax,'on');
		try
			if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
				ax.Toolbar.Visible = 'off';
			end
		catch
		end

		Tp = pairs(pairs.Stage == stageName & pairs.ZKey == zKey, :);
		x = Tp.RelDiv1p5Prev;
		y = Tp.DeltaHit;
		mask = isfinite(x) & isfinite(y);

		rS = NaN; pS = NaN;
		rP = NaN; pP = NaN;
		if nnz(mask) >= 6 && std(x(mask)) > 0 && std(y(mask)) > 0
			[rS, pS] = corr(x(mask), y(mask), 'Type','Spearman');
			[rP, pP] = corr(x(mask), y(mask), 'Type','Pearson');
		end

		scatter(ax, x(mask), y(mask), 26, 'filled', 'MarkerFaceAlpha', 0.75);
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
		title(ax, sprintf('%s  %s  nPairs=%d', stageName, zKey, nnz(mask)), 'Interpreter','none');
		if isfinite(pS)
			text(ax, 0.02, 0.98, sprintf('Spearman \\rho=%.2f  p=%.3g\nPearson r=%.2f  p=%.3g', rS, pS, rP, pP), ...
				'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 8.5, 'Interpreter','none');
		end
	end
end

try
	MATLAB.Graphics.UnifyAxesLims(axesList, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

sgtitle(TL, 'Adjacent-session behavior change vs previous-session relative divergence (1.5s, by layer)', 'Interpreter','none');

svgPath = fullfile(outDir, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	rethrow(ME);
end

% pooled stats (within each layer)
for zKey = layerList
	maskAll = isfinite(pairs.RelDiv1p5Prev) & isfinite(pairs.DeltaHit) & (pairs.ZKey == zKey);
	if nnz(maskAll) >= 6 && std(pairs.RelDiv1p5Prev(maskAll)) > 0 && std(pairs.DeltaHit(maskAll)) > 0
		[rS, pS] = corr(pairs.RelDiv1p5Prev(maskAll), pairs.DeltaHit(maskAll), 'Type','Spearman');
		[rP, pP] = corr(pairs.RelDiv1p5Prev(maskAll), pairs.DeltaHit(maskAll), 'Type','Pearson');
		fprintf('Pooled pairs %s: n=%d\n', zKey, nnz(maskAll));
		fprintf('  Spearman rho=%.4f, p=%.4g\n', rS, pS);
		fprintf('  Pearson  r =%.4f, p=%.4g\n', rP, pP);
	else
		fprintf('Pooled pairs %s: n=%d (insufficient variance)\n', zKey, nnz(maskAll));
	end
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
