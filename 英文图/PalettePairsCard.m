% PalettePairsCard
% 按“配对出现”的关系给 10 个配色常量出色卡，并打印对比校验。
%
% 配色直接取自 Mocha（Catppuccin）的 accent 原色，共 12 个，去掉两个与其它色过于接近的：
%   Maroon #EBA0AC（与 Red 仅差 10°）、Sapphire #74C7EC（与 Sky 仅差 10°）
% 剩下 10 个按“配对取色相环上最远”的原则分配：
%   Naive↔Learned = Red 343° / Teal 170°（相隔 173°）
%   12h↔7d       = Peach 23° / Pink 316°（相隔 67°，同为暖调浅色）
%   12h↔TH       = Peach 23° / Mauve 267°（相隔 116°）
%   Hit↔Miss     = Green 115° / Blue 217°（相隔 102°）
%   Audio/Light/cFos = Sky 189° / Yellow 41° / Lavender 232°
%
% 颜色值直接读 TransferLearning 的 Constant。
% 输出：英文图\PalettePairs.svg

close all force;

OutDir = fileparts(mfilename('fullpath'));

Rows = {
	{'ColorNaive', 'ColorLearned', 'Color12h', 'Color7d'}, ...
	{'ColorHit', 'ColorMiss', 'ColorTH'}, ...
	{'ColorAudio', 'ColorLight', 'ColorcFos'}
};
RowTitles = {
	'学习 / 记忆进程（Naive↔Learned 173°；12h↔7d 67°）'
	'行为结果 / 干预（Hit↔Miss 102°；12h↔TH 116°）'
	'模态 / 指标（Audio↔Light 148°；Audio↔cFos 43°；Light↔cFos 169°）'
};
RowTop = [0.882, 0.598, 0.318];
RowLabel = [0.916, 0.632, 0.352];

%% 读色
AllNames = {};
for r = 1:numel(Rows)
	AllNames = [AllNames, Rows{r}]; %#ok<AGROW>
end
Rgb = zeros(numel(AllNames), 3);
for k = 1:numel(AllNames)
	Rgb(k, :) = double(TransferLearning.(AllNames{k})(:).');
end

%% 画布
Fig = figure('Units', 'centimeters', 'Position', [2 2 13 8.2], 'Color', 'w', ...
	'Name', 'Palette Pairs', 'NumberTitle', 'off');
Ax = axes(Fig, 'Units', 'normalized', 'Position', [0 0 1 1], 'Visible', 'off');
hold(Ax, 'on');
Ax.XLim = [0 1];
Ax.YLim = [0 1];
%铺一层整幅白色底，防止 print 时按内容紧裁掉四周留白
rectangle(Ax, 'Position', [0 0 1 1], 'FaceColor', 'w', 'EdgeColor', 'none');

%% 标题
text(Ax, 0.045, 0.958, '配色常量（全部取自 Mocha 原色，按配对分配）', ...
	'FontSize', 7, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
text(Ax, 0.955, 0.958, '色块内为常量名，下方为 HEX', ...
	'FontSize', 5.5, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
	'Color', [0.40 0.40 0.40]);

%% 三行
nCol = 4;
xLeft = 0.045;
xRight = 0.955;
swW = 0.205;
gapX = (xRight - xLeft - nCol * swW) / (nCol - 1);
swH = 0.150;

idx = 0;
for r = 1:numel(Rows)
	text(Ax, xLeft, RowLabel(r), RowTitles{r}, 'FontSize', 6, 'FontWeight', 'bold', ...
		'Color', [0.30 0.30 0.30], 'VerticalAlignment', 'middle');

	for c = 1:numel(Rows{r})
		idx = idx + 1;
		xSw = xLeft + (c - 1) * (swW + gapX);
		ySw = RowTop(r) - swH;
		rgb01 = Rgb(idx, :) / 255;

		rectangle(Ax, 'Position', [xSw, ySw, swW, swH], ...
			'FaceColor', rgb01, 'EdgeColor', [0.55 0.55 0.55], 'LineWidth', 0.25);

		text(Ax, xSw + swW / 2, ySw + swH / 2, ...
			strrep(AllNames{idx}, 'Color', ''), 'FontSize', 6, 'FontWeight', 'bold', ...
			'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
			'Color', iTextColor(rgb01));

		text(Ax, xSw + swW / 2, ySw - 0.024, ...
			sprintf('#%02X%02X%02X', round(Rgb(idx, :))), 'FontSize', 5, ...
			'FontName', 'Consolas', 'HorizontalAlignment', 'center', ...
			'VerticalAlignment', 'middle', 'Color', [0.35 0.35 0.35]);
	end
end

%% 页脚
text(Ax, 0.045, 0.058, ...
	'ΔE76 为 CIE1976 色差（>10 即可辨，>40 强对比）；灰度为 0.2126R+0.7152G+0.0722B', ...
	'FontSize', 5.5, 'Color', [0.40 0.40 0.40], 'VerticalAlignment', 'middle');

%% 导出
SvgPath = fullfile(OutDir, 'PalettePairs.svg');
%用 print 而不是 exportgraphics：后者会按内容紧裁，把四周留白裁掉
print(Fig, SvgPath, '-dsvg');
fprintf('Wrote: %s\n', SvgPath);

%% 校验
fprintf('\n%-14s %-9s %5s %5s %5s %6s %6s\n', 'Name', 'HEX', 'H', 'S', 'L', 'Gray', 'CvsW');
for k = 1:numel(AllNames)
	hsl = iRgb2Hsl(Rgb(k, :) / 255);
	fprintf('%-14s %-9s %5.0f %5.2f %5.2f %6.0f %6.2f\n', AllNames{k}, ...
		sprintf('#%02X%02X%02X', round(Rgb(k, :))), hsl(1), hsl(2), hsl(3), ...
		iGray(Rgb(k, :)), iContrastWhite(Rgb(k, :)));
end

Pairs = {
	{'Naive vs Learned',   'ColorNaive',   'ColorLearned'}
	{'Learned vs 12h',     'ColorLearned', 'Color12h'}
	{'12h vs 7d',          'Color12h',     'Color7d'}
	{'12h vs TH',          'Color12h',     'ColorTH'}
	{'TH vs 7d',           'ColorTH',      'Color7d'}
	{'Hit vs Miss',        'ColorHit',     'ColorMiss'}
	{'Audio vs Light',     'ColorAudio',   'ColorLight'}
	{'Audio vs cFos',      'ColorAudio',   'ColorcFos'}
	{'Light vs cFos',      'ColorLight',   'ColorcFos'}
	{'Audio vs Hit',       'ColorAudio',   'ColorHit'}
};
fprintf('\n%-18s %7s %7s %7s\n', 'Pair', 'dHue', 'dGray', 'dE76');
for p = 1:size(Pairs, 1)
	iA = find(strcmp(AllNames, Pairs{p}{2}));
	iB = find(strcmp(AllNames, Pairs{p}{3}));
	hA = iRgb2Hsl(Rgb(iA, :) / 255);
	hB = iRgb2Hsl(Rgb(iB, :) / 255);
	dH = abs(hA(1) - hB(1));
	dH = min(dH, 360 - dH);
	fprintf('%-18s %7.0f %7.0f %7.1f\n', Pairs{p}{1}, dH, ...
		abs(iGray(Rgb(iA, :)) - iGray(Rgb(iB, :))), ...
		iDeltaE76(Rgb(iA, :), Rgb(iB, :)));
end

%% ===== 局部函数 =====
function hsl = iRgb2Hsl(rgb)
mx = max(rgb);
mn = min(rgb);
L = (mx + mn) / 2;
d = mx - mn;
if d == 0
	H = 0;
	S = 0;
else
	S = d / (1 - abs(2 * L - 1));
	switch mx
		case rgb(1)
			H = 60 * mod((rgb(2) - rgb(3)) / d, 6);
		case rgb(2)
			H = 60 * ((rgb(3) - rgb(1)) / d + 2);
		otherwise
			H = 60 * ((rgb(1) - rgb(2)) / d + 4);
	end
end
hsl = [H, S, L];
end

function y = iGray(rgb)
y = 0.2126 * rgb(1) + 0.7152 * rgb(2) + 0.0722 * rgb(3);
end

function c = iContrastWhite(rgb)
c255 = rgb / 255;
lin = c255;
mask = c255 <= 0.03928;
lin(mask) = c255(mask) / 12.92;
lin(~mask) = ((c255(~mask) + 0.055) / 1.055) .^ 2.4;
L = 0.2126 * lin(1) + 0.7152 * lin(2) + 0.0722 * lin(3);
c = 1.05 / (L + 0.05);
end

function dE = iDeltaE76(r1, r2)
L1 = iLab(r1);
L2 = iLab(r2);
dE = sqrt(sum((L1 - L2) .^ 2));
end

function lab = iLab(rgb)
c = rgb / 255;
mask = c <= 0.03928;
lin = c;
lin(mask) = c(mask) / 12.92;
lin(~mask) = ((c(~mask) + 0.055) / 1.055) .^ 2.4;
X = (0.4124564*lin(1) + 0.3575761*lin(2) + 0.1804375*lin(3)) / 0.95047;
Y = (0.2126729*lin(1) + 0.7151522*lin(2) + 0.0721750*lin(3));
Z = (0.0193339*lin(1) + 0.1191920*lin(2) + 0.9503041*lin(3)) / 1.08883;
f = @(t) (t > 0.008856) .* t.^(1/3) + (t <= 0.008856) .* (7.787*t + 16/116);
fx = f(X);
fy = f(Y);
fz = f(Z);
lab = [116*fy - 16, 500*(fx - fy), 200*(fy - fz)];
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
