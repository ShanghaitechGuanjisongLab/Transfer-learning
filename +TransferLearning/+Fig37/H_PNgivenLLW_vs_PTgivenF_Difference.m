% Fig3.7H: Difference between P(T|F) and P(N|L) (UNPAIRED cohorts, split by layer)
%
% NOTE: P(T|F) cohort and P(N|L) cohort are NOT the same mice.
% This panel therefore compares distributions (unpaired) rather than paired deltas.
%
% Statistics: ranksum (Mann–Whitney U) two-sided per layer.
%
% Execution:
%   TransferLearning.Fig37.H_PNgivenLLW_vs_PTgivenF_Difference

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

RT = TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer();
RN = TransferLearning.Fig37.iBuildProb_NaiveHitMissGivenLearnedLight_1s_PerMouseLayer();
if isempty(RT) || isempty(RN)
	error('Fig37H:Empty', 'Empty builder output. RT empty=%d, RN empty=%d.', isempty(RT), isempty(RN));
end

layerNames = string(["MOp2/3","MOp5"]);
outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_7h_PNgivenLLW_vs_PTgivenF_UnpairedDifference_2panels.svg";

f = figure('Color','w', 'Name','P(T|F) vs P(N|L) (unpaired)');
MATLAB.Graphics.FigureAspectRatio(1,1,MATLAB.Flags.Narrow);
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

ylabel(TL, 'Probability at 1 s');

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
		yT = RT.Prob23;
		yN = RN.Prob23;
	else
		yT = RT.Prob5;
		yN = RN.Prob5;
	end
	maskT = isfinite(yT);
	maskN = isfinite(yN);
	yT = yT(maskT);
	yN = yN(maskN);

	p = NaN;
	if numel(yT) >= 3 && numel(yN) >= 3
		p = ranksum(yT, yN, 'tail','both');
	end

	% --- jittered scatter
	x1 = 1 + 0.10 * randn(size(yT));
	x2 = 2 + 0.10 * randn(size(yN));
	scatter(ax, x1, yT, 28, 'filled', 'MarkerFaceAlpha',0.75);
	scatter(ax, x2, yN, 28, 'filled', 'MarkerFaceAlpha',0.75);

	% --- summary (median + IQR)
	if ~isempty(yT)
		medT = median(yT, 'omitnan');
		qT = quantile(yT, [0.25 0.75]);
		plot(ax, [0.85 1.15], [medT medT], '-', 'LineWidth',2);
		plot(ax, [1 1], qT, '-', 'LineWidth',2);
	end
	if ~isempty(yN)
		medN = median(yN, 'omitnan');
		qN = quantile(yN, [0.25 0.75]);
		plot(ax, [1.85 2.15], [medN medN], '-', 'LineWidth',2);
		plot(ax, [2 2], qN, '-', 'LineWidth',2);
	end

	set(ax, 'XLim',[0.5 2.5], 'XTick',[1 2], 'XTickLabel',{'P(T|F)','P(N|L)'});
	ylim(ax, [0 1]);
	grid(ax,'on');
	box(ax,'off');

	dMed = median(yT,'omitnan') - median(yN,'omitnan');
	title(ax, sprintf('%s  nT=%d  nN=%d', zl, numel(yT), numel(yN)), 'Interpreter','none');
	% p-value line via MATLAB.Graphics.PLine (unpaired ranksum)
	if isfinite(p)
		% NOTE: MATLAB.Graphics.PLine requires exactly 2 unique XData values for a single Scatter object.
		% Use an invisible 2-point anchor scatter (no jitter) solely for PLine placement.
		yAnchor = [max(yT, [], 'omitnan'), max(yN, [], 'omitnan')];
		S = scatter(ax, [1 2], yAnchor, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
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
			error('Fig37:H:PLineFailed', 'MATLAB.Graphics.PLine failed: %s', ME.message);
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

sgtitle(TL, 'Unpaired: P(T|F) vs P(N|L)', 'Interpreter','none');

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
