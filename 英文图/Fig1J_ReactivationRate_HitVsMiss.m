% 英文图1J: Hit vs Miss Reactivation (per mouse, layers merged)
%
% Reactivation = P(Transfer active | Learned active) at 1s
%   L = Learned AudioWater active at 1s
%   T_hit/T_miss = Transfer LightWater Hit/Miss active at 1s
% Paired test: signrank(Hit > Miss)
%
% Execution:
%   TransferLearning.英文图1.K_ReactivationRate_HitVsMiss


if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

R = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer();
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
learnedActiveCells = R.NLearnedActive23 + R.NLearnedActive5;
nCells = sum(learnedActiveCells(mask), 'omitnan');
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
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
ax.LineWidth = 1;

p = NaN;
if nnz(mask) >= 4
	p = signrank(hit(mask), miss(mask), 'tail','right');
end

Y = [hit(mask), miss(mask)];
hitColor = TransferLearning.ColorA;
missColor = TransferLearning.ColorB;
plot(ax, Y', '-', 'LineWidth', 1, 'Color', [0, 0, 0]);
scatter(ax, ones(nnz(mask),1), hit(mask), 15, hitColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', hitColor);
scatter(ax, 2*ones(nnz(mask),1), miss(mask), 15, missColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', missColor);
set(ax, 'XTick',[1 2], 'XTickLabel',{'Hit','Miss'});
grid(ax,'off');
box(ax,'off');
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
ylabel(ax, 'Reactivation', 'FontSize', 6);
title(ax, '💡💧', 'FontSize', 6, 'FontWeight', 'normal');

% p-value line with asterisk (paired signrank) via MATLAB.Graphics.PLine
if isfinite(p)
	S = scatter(ax, [ones(nnz(mask),1); 2*ones(nnz(mask),1)], [hit(mask); miss(mask)], ...
		1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	if isprop(S, 'HitTest'); S.HitTest = 'off'; end
	if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
	if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	% Convert p to asterisk
	if p < 0.05
		pText = "＊";
	else
		pText = "n.s.";
	end
	Descriptors = table(S, 0, 0, pText, 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	[pLines, pTexts] = MATLAB.Graphics.PLine(Descriptors);
	for pl = pLines(:)'
		pl.LineWidth = 1;
		pl.Tag = 'PLine';
	end
	for pt = pTexts(:)'
		pt.FontSize = 6;
		pt.Tag = 'PText';
	end
	delete(S);
end

svgName = "English_Fig1J_ReactivationRate_HitVsMiss.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== English Fig1J Reactivation Hit vs Miss ===\n');
fprintf('paired mice n = %d\n', nnz(mask));
fprintf('participating learned-active cells n = %d\n', nCells);
fprintf('signrank right-tail p = %.6g\n', p);
