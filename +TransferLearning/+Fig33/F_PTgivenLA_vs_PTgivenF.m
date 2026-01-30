% Fig3.3F: correlation between P(T|L) and P(T|F) (split by layer)
%
% P(T|L): Transfer LightWater active at 1s | Learned AudioWater active at 1s
% P(T|F): Transfer LightWater active at 1s | Final LightWater active at 1s
%
% Execution:
%   TransferLearning.Fig33.F_PTgivenLA_vs_PTgivenF

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
	try
		warning('off', w);
	catch
	end
end

RL = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer();
RF = TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer();
if isempty(RL) || isempty(RF)
	error('Fig33F:Empty', 'Missing rows for P(T|L) or P(T|F).');
end

% join by Mouse (unique per mouse expected)
RL = RL(:, {'Mouse','Prob23','Prob5'});
RF = RF(:, {'Mouse','Prob23','Prob5'});
R = innerjoin(RL, RF, 'Keys','Mouse', 'LeftVariables',{'Mouse','Prob23','Prob5'}, 'RightVariables',{'Prob23','Prob5'});
R.Properties.VariableNames = {'Mouse','PTgivenL_23','PTgivenL_5','PTgivenF_23','PTgivenF_5'};

layerNames = string(["MOp2/3","MOp5"]);
outDir = iSelectOutDir(outDirUNC);
svgName = "Fig3_3f_PTgivenLA_vs_PTgivenF_2panels.svg";

f = figure('Color','w', 'Name','Fig3.3F P(T|L) vs P(T|F)');
MATLAB.Graphics.FigureAspectRatio(48,48,1/2);
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
		x = R.PTgivenL_23;
		y = R.PTgivenF_23;
	else
		x = R.PTgivenL_5;
		y = R.PTgivenF_5;
	end
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

xlabel(TL, 'P(T|L) at 1 s');
ylabel(TL, 'P(T|F) at 1 s');
sgtitle(TL, 'P(T|L) vs P(T|F)', 'Interpreter','none');

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