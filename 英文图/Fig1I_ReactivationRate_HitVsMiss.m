% 英文图1I：逐鼠配对比较Transfer光水Hit/Miss的Learned-active细胞重激活率。
%
% Reactivation = P(Transfer active | Learned active) at 1s
%   L = Learned AudioWater active at 1s
%   T_hit/T_miss = Transfer LightWater Hit/Miss active at 1s
% Paired test: signrank(Hit > Miss)


if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

R = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer();
if isempty(R)
	error('Fig1I:Empty', 'No valid mice for Reactivation Hit/Miss.');
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

f = figure('Color','w', 'Name','English Fig1I Reactivation Hit vs Miss');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];   % 30 × 40 mm（与 Fig1K 一致）
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

ax = axes(f, 'Position', [0.225, 0.155, 0.705, 0.775]);
hold(ax,'on');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

p = NaN;
if nnz(mask) >= 4
	p = signrank(hit(mask), miss(mask), 'tail','right');
end

Y = [hit(mask), miss(mask)];
hitColor = TransferLearning.ColorHit / 255;
missColor = TransferLearning.ColorMiss / 255;
% 同鼠配对连线（灰色细线）
pairLines = plot(ax, Y', '-', 'LineWidth', 0.5, 'Color', [0.55 0.55 0.55]);
for pairLine = pairLines(:)'
	setappdata(pairLine, 'TransferLearningPreserveLineWidth', true);
end
% 逐鼠圆点（与 Fig1K 同一标记尺寸）
plot(ax, ones(nnz(mask),1), hit(mask), 'o', 'MarkerSize', 3.6, ...
	'MarkerFaceColor', hitColor, 'MarkerEdgeColor', 'none');
plot(ax, 2*ones(nnz(mask),1), miss(mask), 'o', 'MarkerSize', 3.6, ...
	'MarkerFaceColor', missColor, 'MarkerEdgeColor', 'none');

set(ax, 'XTick',[1 2], 'XTickLabel',{'Hit','Miss'}, 'XLim', [0.5 2.5]);
% 轴样式：L 形、朝外刻度、无上/右框（与 Fig1K 一致）
grid(ax,'off');
ax.Box = 'off';
ax.LineWidth = 0.75;
ax.TickDir = 'out';
ax.TickLength = [0.025 0.025];
ax.FontSize = 6;
yTop = max(Y(:), [], 'omitnan') * 1.35;      % 给括号留位置
ax.YLim = [0, yTop];
ylabel(ax, 'Reactivation', 'FontSize', 6);
ttl = title(ax, '💡💧', 'FontSize', 6, 'FontWeight', 'normal');
ttl.FontName = 'Segoe UI Emoji';

% p-value line with asterisk (paired signrank) via MATLAB.Graphics.PLine
if isfinite(p)
	S = scatter(ax, [ones(nnz(mask),1); 2*ones(nnz(mask),1)], [hit(mask); miss(mask)], ...
		1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	if isprop(S, 'HitTest'); S.HitTest = 'off'; end
	if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
	if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	pText = TransferLearning.Style.iFormatPText(p);
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

svgName = "English_Fig1I_ReactivationRate_HitVsMiss.svg";
% 统一样式（散点/配对线宽自己控制，不被覆盖），再重设轴位与范围
TransferLearning.Style.ApplyStandardFigureStyle(f, 1, PreserveScatterStyle = true);
ax.Position = [0.225, 0.155, 0.705, 0.775];
ax.YLim = [0, yTop];
ax.XLim = [0.5 2.5];
ax.TickDir = 'out';
ax.LineWidth = 0.75;
ax.XTick = [1 2];  ax.XTickLabel = {'Hit','Miss'};
ylabel(ax, 'Reactivation', 'FontSize', 6);
svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== English Fig1I Reactivation Hit vs Miss ===\n');
fprintf('paired mice n = %d\n', nnz(mask));
fprintf('participating learned-active cells n = %d\n', nCells);
fprintf('signrank right-tail p = %.6g\n', p);
