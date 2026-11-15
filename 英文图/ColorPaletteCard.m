% ColorPaletteCard
% 把 TransferLearning.m 里当前的配色常量输出成一张色卡图。
% 颜色列表自动从 TransferLearning 的 Constant 属性读取（只取名字以 Color
% 开头、数值为 N×3 的属性），无需手工维护，改配色后重跑即可同步。
%
% 输出：英文图\TransferLearning_Palette.svg / .png

close all force;

OutDir = fileparts(mfilename('fullpath'));
Fig = figure('Units', 'centimeters', 'Position', [2 2 10 10], 'Color', 'w', ...
	'Name', 'TransferLearning Palette', 'NumberTitle', 'off');
Ax = axes(Fig, 'Units', 'normalized', 'Position', [0 0 1 1], 'Visible', 'off');
hold(Ax, 'on');
Ax.XLim = [0 1];
Ax.YLim = [0 1];
%铺一层整幅白色底，防止 exportgraphics 按内容紧裁掉四周留白
rectangle(Ax, 'Position', [0 0 1 1], 'FaceColor', 'w', 'EdgeColor', 'none');

%% 读取配色
Pal = iReadPalette();
nRow = numel(Pal.Name);

%% 版式（坐标归一化，单位为轴宽/轴高）
xSw = 0.030;
swW = 0.070;
swH = 0.042;
colName = 0.118;
colRgb = 0.300;
colHex = 0.505;
colNoteR = 0.970;
yTitle = 0.966;
yHead = 0.894;
yTop = 0.826;
dy = 0.063;

%% 标题
text(Ax, xSw, yTitle, 'TransferLearning 配色常量', ...
	'FontSize', 7, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
text(Ax, colNoteR, yTitle, sprintf('%d 个常量 / %d 组唯一颜色', nRow, numel(unique(Pal.Hex))), ...
	'FontSize', 6, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
	'Color', [0.40 0.40 0.40]);
iHLine(Ax, xSw, colNoteR, 0.932);

%% 表头
hdrColor = [0.40 0.40 0.40];
text(Ax, xSw, yHead, '色块', 'FontSize', 6, 'Color', hdrColor, 'VerticalAlignment', 'middle');
text(Ax, colName, yHead, '常量名', 'FontSize', 6, 'Color', hdrColor, 'VerticalAlignment', 'middle');
text(Ax, colRgb, yHead, 'RGB (0–255)', 'FontSize', 6, 'Color', hdrColor, 'VerticalAlignment', 'middle');
text(Ax, colHex, yHead, 'HEX', 'FontSize', 6, 'Color', hdrColor, 'VerticalAlignment', 'middle');
text(Ax, colNoteR, yHead, '口径 / 别名', 'FontSize', 6, 'Color', hdrColor, ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
iHLine(Ax, xSw, colNoteR, 0.864);

%% 逐行
for k = 1:nRow
	yC = yTop - (k - 1) * dy;
	% 色块（加一道极细描边，浅色也能看出边界）
	rectangle(Ax, 'Position', [xSw, yC - swH / 2, swW, swH], ...
		'FaceColor', Pal.Rgb01(k, :), 'EdgeColor', [0.55 0.55 0.55], 'LineWidth', 0.25);
	text(Ax, colName, yC, Pal.Name{k}, 'FontSize', 6, 'VerticalAlignment', 'middle');
	text(Ax, colRgb, yC, Pal.RgbTxt{k}, 'FontSize', 6, 'VerticalAlignment', 'middle', ...
		'FontName', 'Consolas');
	text(Ax, colHex, yC, Pal.Hex{k}, 'FontSize', 6, 'VerticalAlignment', 'middle', ...
		'FontName', 'Consolas');
	if ~isempty(Pal.Note{k})
		text(Ax, colNoteR, yC, Pal.Note{k}, 'FontSize', 5.5, 'VerticalAlignment', 'middle', ...
			'HorizontalAlignment', 'right', 'Color', [0.40 0.40 0.40]);
	end
end

%% 梯度顺序预览（按声明顺序去重）
yRampLabel = 0.186;
yRamp = 0.106;
rampH = 0.052;
[uniqRgb, iFirst] = unique(Pal.Rgb01, 'rows', 'stable');
rampRgb = Pal.Rgb01(sort(iFirst), :);
rampName = strrep(Pal.Name(sort(iFirst)), 'Color', '');
nSeg = size(rampRgb, 1);
segW = (colNoteR - xSw) / nSeg;
text(Ax, xSw, yRampLabel, '声明顺序预览（ColorNaive → ColorcFos）', 'FontSize', 5.5, ...
	'Color', [0.40 0.40 0.40], 'VerticalAlignment', 'middle');
for k = 1:nSeg
	rectangle(Ax, 'Position', [xSw + (k - 1) * segW, yRamp, segW, rampH], ...
		'FaceColor', rampRgb(k, :), 'EdgeColor', [0.55 0.55 0.55], 'LineWidth', 0.25);
	txtColor = iTextColor(rampRgb(k, :));
	text(Ax, xSw + (k - 0.5) * segW, yRamp + rampH / 2, rampName{k}, ...
		'FontSize', 5.5, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
		'Color', txtColor);
end

%% 页脚
n255 = sum(Pal.Is255);
n01 = nRow - n255;
text(Ax, xSw, 0.045, sprintf( ...
	'0–255 口径 %d 个（绘图前 /255）· 0–1 口径 %d 个（可直接用）· 别名表示与前者完全同色', ...
	n255, n01), 'FontSize', 5.5, 'Color', [0.40 0.40 0.40], 'VerticalAlignment', 'middle');

%% 导出
SvgPath = fullfile(OutDir, 'TransferLearning_Palette.svg');
%用 print 而不是 exportgraphics：后者会按内容紧裁，把四周留白裁掉
print(Fig, SvgPath, '-dsvg');
fprintf('Wrote: %s\n', SvgPath);

%% ===== 局部函数 =====
function Pal = iReadPalette()
%从 TransferLearning 的 Constant 属性里挑出配色常量。
%只按名字前缀筛选，避免访问 memoize 属性时触发数据加载。
Names = properties('TransferLearning');
Names = Names(startsWith(Names, 'Color'));
Pal = struct('Name', {{}}, 'Rgb01', [], 'RgbTxt', {{}}, 'Hex', {{}}, ...
	'Note', {{}}, 'Is255', false(0, 1));
for k = 1:numel(Names)
	nm = Names{k};
	v = TransferLearning.(nm);
	if ~isnumeric(v) || isempty(v) || size(v, 2) ~= 3
		continue
	end
	for r = 1:size(v, 1)
		rgb = double(v(r, :));
		if any(rgb < 0) || any(rgb > 255)
			continue
		end
		is255 = any(rgb > 1);
		if is255
			rgb01 = rgb / 255;
			rgbTxt = sprintf('[%d %d %d]', round(rgb));
		else
			rgb01 = rgb;
			rgbTxt = sprintf('[%g %g %g]', round(rgb, 4));
		end
		rowName = nm;
		if size(v, 1) > 1
			rowName = sprintf('%s(%d)', nm, r);
		end
		Pal.Name{end + 1, 1} = rowName;
		Pal.Rgb01(end + 1, :) = rgb01;
		Pal.RgbTxt{end + 1, 1} = rgbTxt;
		Pal.Hex{end + 1, 1} = sprintf('#%02X%02X%02X', round(rgb01 * 255));
		Pal.Note{end + 1, 1} = '';
		Pal.Is255(end + 1, 1) = is255;
	end
end

%口径 + 别名
for k = 1:numel(Pal.Name)
	parts = {};
	if Pal.Is255(k)
		parts{end + 1} = '0–255';
	else
		parts{end + 1} = '0–1';
	end
	prev = find(all(abs(Pal.Rgb01(1:k - 1, :) - Pal.Rgb01(k, :)) < 1e-9, 2), 1);
	if ~isempty(prev)
		parts{end + 1} = ['= ' Pal.Name{prev}];
	end
	Pal.Note{k} = strjoin(parts, ' · ');
end
end

function iHLine(Ax, x1, x2, y)
plot(Ax, [x1 x2], [y y], 'Color', [0.78 0.78 0.78], 'LineWidth', 0.5);
end

function c = iTextColor(rgb01)
%根据亮度选黑/白字，保证色块内文字可读
lum = 0.2126 * rgb01(1) + 0.7152 * rgb01(2) + 0.0722 * rgb01(3);
if lum > 0.55
	c = [0.15 0.15 0.15];
else
	c = [1 1 1];
end
end
