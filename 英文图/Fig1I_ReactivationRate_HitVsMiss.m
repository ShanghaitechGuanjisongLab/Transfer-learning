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

% 合并 2/3 与 5 层：按 learned-active 细胞数加权（= 两层细胞合并后重算 P(T|L)）
hit23 = R.ProbHit23;
miss23 = R.ProbMiss23;
hit5 = R.ProbHit5;
miss5 = R.ProbMiss5;

hit = iPooledProb(R.NLearnedActive23, hit23, R.NLearnedActive5, hit5);
miss = iPooledProb(R.NLearnedActive23, miss23, R.NLearnedActive5, miss5);
mask = isfinite(hit) & isfinite(miss);
learnedActiveCells = R.NLearnedActive23 + R.NLearnedActive5;
nCells = sum(learnedActiveCells(mask), 'omitnan');
%% 

f = figure('Color','w', 'Name','English Fig1I Reactivation Hit vs Miss');
f.Units = 'centimeters';
f.Position(3:4) = [3,4];   % 30 × 40 mm（与 Fig1J/1K 一致）
f.PaperUnits = 'centimeters';
f.PaperSize = [3,4];
f.PaperPosition = [0 0 3 4];
f.PaperPositionMode = 'manual';
ax = gca;   % 显式取当前轴（旧版依赖工作区残留的 ax，单独运行会报错）
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
ttl = title( '');

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
svgPath = TransferLearning.ExportStandardFigure(f,1,svgName);
function p = iPooledProb(n23, p23, n5, p5)
%按 learned-active 细胞数加权合并 L2/3 与 L5 的 P(T|L)：
%   (n23*p23 + n5*p5) / (n23 + n5)，等价于把两层细胞合并成一池后重算。
%   缺失( NaN )的一层按 0 权重计；两层都缺失则返回 NaN。
n23 = double(n23(:));  n5 = double(n5(:));
n23(~isfinite(n23)) = 0;  n5(~isfinite(n5)) = 0;
w23 = n23 .* double(p23(:));  w23(~isfinite(w23)) = 0;
w5  = n5  .* double(p5(:));   w5(~isfinite(w5))  = 0;
nT = n23 + n5;
p = (w23 + w5) ./ nT;
p(nT == 0) = NaN;
end
