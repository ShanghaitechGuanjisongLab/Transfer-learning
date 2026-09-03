% 中文图43C：Hit vs Miss Reactivation（秩和检验 + 手动P值线）

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

p = NaN;
if nnz(mask) >= 4
	p = ranksum(hit(mask), miss(mask));
end

Y = [hit(mask), miss(mask)];
hitColor = TransferLearning.TransferColor;
missColor = TransferLearning.ColorB;
plot(ax, Y', '-', 'Color', [0, 0, 0]);
scatter(ax, ones(nnz(mask),1), hit(mask), 15, hitColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', hitColor);
scatter(ax, 2*ones(nnz(mask),1), miss(mask), 15, missColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', missColor);
set(ax, 'XTick',[1 2], 'XTickLabel',{'Hit','Miss'});
grid(ax,'off');
box(ax,'off');
ylabel(ax, '🔊 learned cells reactivation');
xlabel(ax, '💡💧');

yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = max(max(hit(mask)), max(miss(mask))) + 0.08 * yrange;
textY = yPLine + 0.08 * yrange;
plot(ax, [1, 2], [yPLine, yPLine], 'k-', 'LineWidth', 1, 'Tag', 'PLine_1');
text(ax, 1.5, textY, TransferLearning.Style.iFormatPText(p), ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 6, 'Tag', 'PText_1');

svgName = "中文图Fig43C_ReactivationRate_HitVsMiss.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== 中文图43C Reactivation Hit vs Miss ===\n');
fprintf('paired mice n = %d\n', nnz(mask));
fprintf('participating learned-active cells n = %d\n', nCells);
fprintf('ranksum p = %.6g\n', p);
fprintf('Figure caption (4.3C) P = %s\n', TransferLearning.Style.iFormatPText(p));
