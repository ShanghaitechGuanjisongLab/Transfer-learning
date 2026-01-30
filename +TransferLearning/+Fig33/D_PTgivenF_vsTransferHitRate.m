% Fig3.3D: P(T|F) vs Transfer hit rate (split by layer)
%
% P(T|F): Transfer LightWater active at 1s | Final LightWater active at 1s
% Sessions (pure): see TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer
%
% Execution:
%   TransferLearning.Fig33.D_PTgivenF_vsTransferHitRate

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

% Avoid session-dependent warning states (e.g., Block_must_warn being set to error)
warnIds = [
	"UniExp:Exception:Block_must_warn"
	"UniExp:Exception:Split_trials_less_than_existing_Trials"
	"UniExp:Exception:No_TagPeaks_found"
];
for w = warnIds'
	try, warning('off', w); catch, end %#ok<CTCH>
end

R = TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer();
if isempty(R)
	error('Fig33D:Empty', 'No valid mice for P(T|F).');
end

% Exclude specific mouse(s) if needed
R.Mouse = string(R.Mouse);
excludeMouse = "yqn1130";
if any(R.Mouse == excludeMouse)
	R = R(R.Mouse ~= excludeMouse, :);
	fprintf('Fig3.3D: excluded mouse %s\n', excludeMouse);
end
if isempty(R)
	error('Fig33D:EmptyAfterExclusion', 'No mice left after exclusion.');
end

layerNames = string(["MOp2/3","MOp5"]);
outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_3d_PTgivenF_vsTransferHitRate_2panels.svg";

f = figure('Color','w', 'Name','Fig3.3D P(T|F) vs Transfer hit rate');
MATLAB.Graphics.FigureAspectRatio(73,48,3/4);
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
	% Do not show mouse names on scatter
	grid(ax,'on');
	box(ax,'off');
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

xlabel(TL, 'P(T|F) at 1 s');
ylabel(TL, 'Transfer hit rate (first pure session)');
sgtitle(TL, 'P(T|F) vs Transfer hit rate', 'Interpreter','none');

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
		error('Fig33:UNCUnreachable', 'UNC path not accessible: %s\n%s', outDirUNC, ME.message);
	end
end
