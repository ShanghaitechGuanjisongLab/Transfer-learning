% 图3.3e：SD 组间差异（Transfer vs Naive），分 0.3s/1.5s 与 2/5 层
%
% Spec (from 论文大纲.md 3.3):
% - 1.5s (feedback) SD: Transfer significantly higher than Naive
% - 0.3s (feedforward) SD: not significant
% - Stratify by layer: MOp2/3 vs MOp5
%
% Implementation:
% - Use one-session-per-mouse (start-phase) design:
%     TransferLearning.Fig33.iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable(targetSec)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig33.E_SDTransferHigherThanNaive

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3e_SD_TransferHigherThanNaive.svg";

% --- Ensure project loaded (for UniExp)
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

T03 = TransferLearning.Fig33.iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable(0.3);
T15 = TransferLearning.Fig33.iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable(1.5);

T03.Group = string(T03.Group);
T15.Group = string(T15.Group);

% Drop mixed sessions (should already be dropped inside scratch)
if ismember('IsMixedAudio', T03.Properties.VariableNames)
	T03 = T03(~T03.IsMixedAudio, :);
end
if ismember('IsMixedAudio', T15.Properties.VariableNames)
	T15 = T15(~T15.IsMixedAudio, :);
end

assignin('base', 'Fig3_3e_T03', T03);
assignin('base', 'Fig3_3e_T15', T15);

f = figure('Color','w', 'Name', 'Fig3.3e SD group difference');
try
	MATLAB.Graphics.FigureAspectRatio(10, 6, 1/2);
catch
end

tl = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

% Row 1: 0.3s; Row 2: 1.5s
iPanel(nexttile(tl, 1), T03, 'StdCells0p3_MOp23', '0.3s | MOp2/3');
iPanel(nexttile(tl, 2), T03, 'StdCells0p3_MOp5',   '0.3s | MOp5');
iPanel(nexttile(tl, 3), T15, 'StdCells1p5_MOp23', '1.5s | MOp2/3');
iPanel(nexttile(tl, 4), T15, 'StdCells1p5_MOp5',   '1.5s | MOp5');

sgtitle(tl, 'One start-phase session per mouse: Transfer vs Naive', 'Interpreter','none');

try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- helpers

function iPanel(ax, T, varName, ttl)
	hold(ax,'on');
	box(ax,'off');
	grid(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	if ~ismember(varName, T.Properties.VariableNames)
		title(ax, ttl + " (missing var)", 'Interpreter','none');
		return;
	end

	xN = double(T.(varName)(T.Group=="Naive"));
	xT = double(T.(varName)(T.Group=="Transfer"));
	xN = xN(isfinite(xN));
	xT = xT(isfinite(xT));

	swarmchart(ax, ones(size(xN)), xN, 26, 'filled', 'MarkerFaceAlpha', 0.75);
	swarmchart(ax, 2*ones(size(xT)), xT, 26, 'filled', 'MarkerFaceAlpha', 0.75);

	medN = median(xN,'omitnan');
	medT = median(xT,'omitnan');
	plot(ax, [0.85 1.15], [medN medN], '-', 'LineWidth', 2);
	plot(ax, [1.85 2.15], [medT medT], '-', 'LineWidth', 2);

	p = NaN;
	if numel(xN) >= 3 && numel(xT) >= 3
		p = ranksum(xN, xT);
	end

	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('Naive (n=%d)', numel(xN)), sprintf('Transfer (n=%d)', numel(xT))};
	ylabel(ax, 'Inter-cell SD');
	title(ax, ttl, 'Interpreter','none');
	% p-value line (via MATLAB.Graphics.PLine)
	if isfinite(p) && ~isempty(xN) && ~isempty(xT)
		S = scatter(ax, [ones(numel(xN),1); 2*ones(numel(xT),1)], [xN(:); xT(:)], ...
			1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
		try
			if isprop(S, 'HitTest'); S.HitTest = 'off'; end
			if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
			if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
		catch
		end
		Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), 0, ...
			'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
		try
			MATLAB.Graphics.PLine(Descriptors);
		catch
		end
		try
			delete(S);
		catch
		end
	end
end
