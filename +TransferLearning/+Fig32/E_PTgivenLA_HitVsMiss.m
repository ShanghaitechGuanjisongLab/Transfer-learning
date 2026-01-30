% Fig3.2E: Hit vs Miss difference in P(T|L) within Transfer session (split by layer)
%
% P(T_hit|L) and P(T_miss|L) computed using:
%   L = Learned AudioWater active at 1s (last pure session)
%   T_hit/T_miss = Transfer LightWater Hit/Miss active at 1s within first pure session
% Paired test: signrank(Hit > Miss)
%
% Execution:
%   TransferLearning.Fig32.E_PTgivenLA_HitVsMiss

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

R = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer();
if isempty(R)
	error('Fig32E:Empty', 'No valid mice for P(T|L) Hit/Miss.');
end

layerNames = string(["MOp2/3","MOp5"]);
outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_2e_PTgivenLA_HitVsMiss_2panels.svg";

f = figure('Color','w', 'Name','P(T|L) Hit vs Miss');
MATLAB.Graphics.FigureAspectRatio(46,46,1/2);
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
ylabel(TL, 'P(T|L) at 1 s');

for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	ax = nexttile(TL, iZ);
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	if zl == "MOp2/3"
		hit = R.ProbHit23;
		miss = R.ProbMiss23;
	else
		hit = R.ProbHit5;
		miss = R.ProbMiss5;
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
	ylim(ax, [0 1]);
	grid(ax,'on');
	box(ax,'off');
	title(ax, sprintf('%s  n=%d', zl, nnz(mask)), 'Interpreter','none');
	% p-value line (paired signrank) via MATLAB.Graphics.PLine
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
			error('Fig32:E:PLineFailed', 'MATLAB.Graphics.PLine failed:\n%s', getReport(ME, 'extended', 'hyperlinks','off'));
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

sgtitle(TL, 'P(T|L) Hit vs Miss (paired)', 'Interpreter','none');

svgPath = fullfile(outDir, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
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
		error('Fig32:UNCUnreachable', 'UNC path not accessible: %s\n%s', outDirUNC, ME.message);
	end
end
