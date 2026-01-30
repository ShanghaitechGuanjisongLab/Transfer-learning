% Fig3.8F: Hit vs Miss difference in RelDiv(T) within Transfer session (split by layer)
%
% RelDiv(T) computed from per-trial ZScore at 1s in Transfer LightWater,
% using Transfer session data alone.
% Cohort note: mouse cohort is filtered to those that also have Final metadata.
% Paired test: signrank(Hit > Miss)
%
% Execution:
%   TransferLearning.Fig38.F_RelDivTgivenF_HitVsMiss

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

R = TransferLearning.Fig38.iBuildRelDiv_TransferHitMissGivenFinal_1s_PerMouseLayer();
if isempty(R)
	error('Fig38F:Empty', 'No valid mice for RelDiv(T) Hit/Miss.');
end

layerNames = string(["MOp2/3","MOp5"]);
outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_8f_RelDivTgivenF_HitVsMiss_2panels.svg";

f = figure('Color','w', 'Name','RelDiv(T) Hit vs Miss');
MATLAB.Graphics.FigureAspectRatio(1,1,MATLAB.Flags.Narrow);
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
ylabel(TL, 'RelDiv(T) at 1 s');

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
		hit = R.RelDivHit23;
		miss = R.RelDivMiss23;
	else
		hit = R.RelDivHit5;
		miss = R.RelDivMiss5;
	end
	mask = isfinite(hit) & isfinite(miss);

	p = NaN;
	if nnz(mask) >= 4
		p = signrank(hit(mask), miss(mask), 'tail','right');
	end

	Y = [hit(mask), miss(mask)];
	plot(ax, Y', '-k', 'LineWidth', 0.75);
	scatter(ax, ones(nnz(mask),1), hit(mask), 30, 'filled');
	scatter(ax, 2*ones(nnz(mask),1), miss(mask), 30, 'filled');
	set(ax, 'XLim',[0.5 2.5], 'XTick',[1 2], 'XTickLabel',{'Hit','Miss'});
	try
		ylim(ax, iNiceNonnegLim([hit(mask); miss(mask)]));
	catch
	end
	grid(ax,'on');
	box(ax,'off');
	title(ax, sprintf('%s  n=%d', zl, nnz(mask)), 'Interpreter','none');

	if isfinite(p)
		S = scatter(ax, [ones(nnz(mask),1); 2*ones(nnz(mask),1)], [hit(mask); miss(mask)], ...
			1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
		try
			if isprop(S, 'HitTest'); S.HitTest = 'off'; end
			if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
			if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
		catch
		end
		Descriptors = table(S, 0, 0, ("p=" + sprintf('%.3g', p)), 0, ...
			'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
		try
			MATLAB.Graphics.PLine(Descriptors);
		catch ME
			error('Fig38:F:PLineFailed', 'MATLAB.Graphics.PLine failed:\n%s', getReport(ME, 'extended', 'hyperlinks','off'));
		end
		try
			delete(S);
		catch
		end
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
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

sgtitle(TL, 'RelDiv(T) Hit vs Miss (paired)', 'Interpreter','none');

svgPath = fullfile(outDir, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

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
		lim = [0, xMax * 1.10];
	end
end
