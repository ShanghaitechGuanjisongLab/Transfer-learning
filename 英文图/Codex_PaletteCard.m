% Codex_PaletteCard
% 输出 Codex CLI 默认主题（Catppuccin）的 accent 色卡，每组 12 色：
%   上组 Mocha —— Codex 深色背景下的默认语法主题
%   下组 Latte —— Codex 浅色背景下的默认语法主题
% 已从 14 色中删除 Rosewater 与 Flamingo：Mocha 里两者最淡（白底几乎不可见），
% Latte 里两者几乎同色（#DC8A78 vs #DD7878），区分度最低。两组删除同一对索引，
% 因此仍一一对应。
%
% 依据 openai/codex 的 codex-rs/tui/src/render/highlight.rs:
%   adaptive_default_theme_selection() 在浅色背景返回 catppuccin-latte，
%   其余（含默认）返回 catppuccin-mocha。
% 颜色值取自 catppuccin/palette 的 palette.json（按官方 order，
% 与 TransferLearning.CodexPalette / CodexPaletteLight 一致）。
%
% 输出：英文图\Codex_Palette.svg

close all force;

OutDir = fileparts(mfilename('fullpath'));

Names = {'Pink', 'Mauve', 'Red', 'Maroon', 'Peach', 'Yellow', ...
	'Green', 'Teal', 'Sky', 'Sapphire', 'Blue', 'Lavender'};

RgbMocha = double(TransferLearning.CodexPalette);
RgbLatte = double(TransferLearning.CodexPaletteLight);

%% 画布
Fig = figure('Units', 'centimeters', 'Position', [2 2 13 7.4], 'Color', 'w', ...
	'Name', 'Codex Palette', 'NumberTitle', 'off');
Ax = axes(Fig, 'Units', 'normalized', 'Position', [0 0 1 1], 'Visible', 'off');
hold(Ax, 'on');
Ax.XLim = [0 1];
Ax.YLim = [0 1];
%铺一层整幅白色底，防止 print 时按内容紧裁掉四周留白
rectangle(Ax, 'Position', [0 0 1 1], 'FaceColor', 'w', 'EdgeColor', 'none');

%% 标题
text(Ax, 0.020, 0.962, 'Codex CLI 默认配色（Catppuccin accent）', ...
	'FontSize', 7, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
text(Ax, 0.980, 0.962, '每组 12 色 · 已去除最淡/最难分的 Rosewater、Flamingo', ...
	'FontSize', 5.5, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
	'Color', [0.40 0.40 0.40]);

%% 两组
iDrawGroup(Ax, RgbMocha, Names, 0.880, 'Mocha —— Codex 深色背景默认主题', 0.916);
iDrawGroup(Ax, RgbLatte, Names, 0.442, 'Latte —— Codex 浅色背景主题（白底论文图更实用）', 0.478);

%% 页脚
text(Ax, 0.020, 0.028, ...
	['RGB(0–255) 见 TransferLearning.CodexPalette（Mocha）/ CodexPaletteLight（Latte）'], ...
	'FontSize', 5.5, 'Color', [0.40 0.40 0.40], 'VerticalAlignment', 'middle');

%% 导出
SvgPath = fullfile(OutDir, 'Codex_Palette.svg');
%用 print 而不是 exportgraphics：后者会按内容紧裁，把四周留白裁掉
print(Fig, SvgPath, '-dsvg');
fprintf('Wrote: %s\n', SvgPath);
for g = 1:2
	if g == 1
		Rgb = RgbMocha;
		tag = 'Mocha';
	else
		Rgb = RgbLatte;
		tag = 'Latte';
	end
	for k = 1:size(Rgb, 1)
		fprintf('  %-6s %-9s #%02X%02X%02X  [%3d %3d %3d]\n', ...
			tag, Names{k}, round(Rgb(k, :)), round(Rgb(k, :)));
	end
end

%% ===== 局部函数 =====
function iDrawGroup(Ax, Rgb, Names, yTop, Title, yTitle)
nCol = 6;
xLeft = 0.020;
xRight = 0.980;
swW = 0.150;
gapX = (xRight - xLeft - nCol * swW) / (nCol - 1);
swH = 0.140;
dyRow = 0.200;

text(Ax, xLeft, yTitle, Title, 'FontSize', 6, 'FontWeight', 'bold', ...
	'Color', [0.30 0.30 0.30], 'VerticalAlignment', 'middle');

for k = 1:numel(Names)
	r = ceil(k / nCol);
	c = mod(k - 1, nCol) + 1;
	xSw = xLeft + (c - 1) * (swW + gapX);
	ySw = yTop - (r - 1) * dyRow - swH;
	rgb01 = Rgb(k, :) / 255;

	%色块（极细描边，浅色也能看出边界）
	rectangle(Ax, 'Position', [xSw, ySw, swW, swH], ...
		'FaceColor', rgb01, 'EdgeColor', [0.55 0.55 0.55], 'LineWidth', 0.25);

	%色块内：官方色名
	text(Ax, xSw + swW / 2, ySw + swH / 2, Names{k}, 'FontSize', 5, ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
		'Color', iTextColor(rgb01));

	%色块下：HEX
	text(Ax, xSw + swW / 2, ySw - 0.022, ...
		sprintf('#%02X%02X%02X', round(Rgb(k, :))), 'FontSize', 4.5, ...
		'FontName', 'Consolas', 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle', 'Color', [0.35 0.35 0.35]);
end
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
