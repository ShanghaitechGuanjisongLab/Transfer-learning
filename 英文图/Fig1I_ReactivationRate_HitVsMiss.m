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
f.Position(3:4) = [4,8];   % 30 × 40 mm（与 Fig1K 一致）
hold on;

p = NaN;
if nnz(mask) >= 4
	p = signrank(hit(mask), miss(mask), 'tail','right');
end

Y = [hit(mask), miss(mask)];
hitColor = TransferLearning.ColorHit / 255;
missColor = TransferLearning.ColorMiss / 255;
% 同鼠配对连线（灰色细线）
pairLines = plot( Y', '-', 'LineWidth', 1, 'Color', [0.55 0.55 0.55]);
for pairLine = pairLines(:)'
	setappdata(pairLine, 'TransferLearningPreserveLineWidth', true);
end
% 逐鼠圆点（与 Fig1K 同一标记尺寸）
plot(ones(nnz(mask),1), hit(mask), 'o', 'MarkerSize', 3.6, ...
	'MarkerFaceColor', hitColor, 'MarkerEdgeColor', 'none');
plot( 2*ones(nnz(mask),1), miss(mask), 'o', 'MarkerSize', 3.6, ...
	'MarkerFaceColor', missColor, 'MarkerEdgeColor', 'none');
% 轴样式：L 形、朝外刻度、无上/右框（与 Fig1K 一致）
box off;
ylabel(ax, 'Reactivation');
ttl = title( '💡💧');

% p-value line with asterisk (paired signrank) via MATLAB.Graphics.PLine
if isfinite(p)
	S = scatter([ones(nnz(mask),1); 2*ones(nnz(mask),1)], [hit(mask); miss(mask)], ...
		2, 'k', 'filled');
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
xticks(1:2);
xlim([0,3]);
xticklabels({'Hit','Miss'});
% 统一样式（散点/配对线宽自己控制，不被覆盖），再重设轴位与范围
svgPath = TransferLearning.ExportStandardFigure(f,2,svgName);