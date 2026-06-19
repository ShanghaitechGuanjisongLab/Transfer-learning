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
f.Position(3:4) = [4.0, 8.0]; % 30mm x 40mm
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4, 8];
f.PaperSize = [4, 8];

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

compareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, optional, barsHidden, errorBarsHidden] = UniExp.BarScatterCompare({double(hit(mask)), double(miss(mask))}, UniExp.Flags.empty, compareGroup, ax, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optional);
for barHandle = barsHidden(:)'
	if isgraphics(barHandle)
		barHandle.Visible = 'off';
		barHandle.HandleVisibility = 'off';
	end
end
if istable(errorBarsHidden) && ismember('Object', errorBarsHidden.Properties.VariableNames)
	for errorBar = errorBarsHidden.Object(:)'
		if isgraphics(errorBar)
			errorBar.Visible = 'off';
			errorBar.HandleVisibility = 'off';
		end
	end
end
if isfield(optional, 'MultiCompare') && istable(optional.MultiCompare)
	if ismember('PLine', optional.MultiCompare.Properties.VariableNames)
		for pLine = optional.MultiCompare.PLine(:)'
			if isgraphics(pLine)
				pLine.LineWidth = 1;
				pLine.Tag = 'PLine';
			end
		end
	end
	if ismember('PText', optional.MultiCompare.Properties.VariableNames)
		for pText = optional.MultiCompare.PText(:)'
			if isgraphics(pText)
				pText.FontSize = 6;
				pText.Tag = 'PText';
			end
		end
	end
end

svgName = "中文图Fig43C_ReactivationRate_HitVsMiss.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== English Fig1J Reactivation Hit vs Miss ===\n');
fprintf('paired mice n = %d\n', nnz(mask));
fprintf('participating learned-active cells n = %d\n', nCells);
fprintf('signrank right-tail p = %.6g\n', p);
fprintf('Figure caption (4.3C) P = %s\n', TransferLearning.Style.iFormatPText(optional.MultiCompare.PValue(1)));
