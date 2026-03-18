% 英文图1J: Hit vs Miss Reactivation (per mouse, layers merged)
%
% Reactivation = P(Transfer active | Learned active) at 1s
%   L = Learned AudioWater active at 1s
%   T_hit/T_miss = Transfer LightWater Hit/Miss active at 1s
% Paired test: signrank(Hit > Miss)
%
% Execution:
%   TransferLearning.英文图1.K_ReactivationRate_HitVsMiss


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
	error('Fig1K:Empty', 'No valid mice for Reactivation Hit/Miss.');
end

% 合并2/3和5层数据：取各鼠每层的均值
hit23 = R.ProbHit23;
miss23 = R.ProbMiss23;
hit5 = R.ProbHit5;
miss5 = R.ProbMiss5;

% 对每只鼠取两层均值（忽略NaN）
hit = nanmean([hit23, hit5], 2);
miss = nanmean([miss23, miss5], 2);
mask = isfinite(hit) & isfinite(miss);
%% 

f = figure('Color','w', 'Name','English Fig1J Reactivation Hit vs Miss');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0]; % 30mm x 40mm
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

ax = axes(f);
hold(ax,'on');
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

p = NaN;
if nnz(mask) >= 4
	p = signrank(hit(mask), miss(mask), 'tail','right');
end

Y = [hit(mask), miss(mask)];
palette3 = TransferLearning.FigurePalette(3);
plot(ax, Y', '-', 'LineWidth', 0.75, 'Color', palette3(3,:));
scatter(ax, ones(nnz(mask),1), hit(mask), 15, palette3(1,:), 'filled');
scatter(ax, 2*ones(nnz(mask),1), miss(mask), 15, palette3(2,:), 'filled');
set(ax, 'XLim',[0.5 2.5], 'XTick',[1 2], 'XTickLabel',{'Hit','Miss'});
ylim(ax, [0 1]);
grid(ax,'off');
box(ax,'off');
ax.FontSize = 6;
ylabel(ax, 'Reactivation', 'FontSize', 6);

% p-value line with asterisk (paired signrank) via MATLAB.Graphics.PLine
if isfinite(p)
	S = scatter(ax, [ones(nnz(mask),1); 2*ones(nnz(mask),1)], [hit(mask); miss(mask)], ...
		1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end
	% Convert p to asterisk
	if p < 0.001
		pText = "***";
	elseif p < 0.01
		pText = "**";
	elseif p < 0.05
		pText = "*";
	else
		pText = "n.s.";
	end
	Descriptors = table(S, 0, 0, pText, 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		[~, pTexts] = MATLAB.Graphics.PLine(Descriptors);
		for pt = pTexts(:)'
			pt.FontSize = 6;
		end
	catch ME
		warning('Fig1K:PLineFailed', 'MATLAB.Graphics.PLine failed:\n%s', getReport(ME, 'extended', 'hyperlinks','off'));
	end
	try
		delete(S);
	catch
	end
end

text(ax, 0.02, 0.98, sprintf('n=%d', nnz(mask)), 'Units','normalized', ...
	'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 6);

% Export
try
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgName = "English_Fig1J_ReactivationRate_HitVsMiss.svg";
svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end
