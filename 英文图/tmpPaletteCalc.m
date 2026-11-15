% 临时：为 10 个配色常量按配对关系求值并校验
close all force; clc;

% 名称, 基色(注明), H, S, L
Spec = {
	'ColorNaive',   'Red',    347, 0.80, 0.55
	'ColorLearned', 'Red-Peach', 8, 0.85, 0.76
	'Color12h',     'Peach',   23, 0.92, 0.82
	'Color7d',      'Peach-Yellow', 35, 0.90, 0.90
	'ColorTH',      'Mauve',  267, 0.80, 0.66
	'ColorHit',     'Green',  137, 0.62, 0.56
	'ColorMiss',    'Pink',   316, 0.80, 0.66
	'ColorAudio',   'Sky',    189, 0.75, 0.62
	'ColorLight',   'Yellow',  41, 0.88, 0.45
	'ColorcFos',    'Blue',   220, 0.85, 0.52
};

n = size(Spec, 1);
Rgb = zeros(n, 3);
for k = 1:n
	Rgb(k, :) = iHsl2Rgb(Spec{k, 3}, Spec{k, 4}, Spec{k, 5});
end

fprintf('%-14s %-14s %-16s %-9s %5s %5s %5s %6s %6s\n', ...
	'Name', 'Base', 'RGB', 'HEX', 'H', 'S', 'L', 'GrayY', 'CvsW');
for k = 1:n
	rgb = Rgb(k, :);
	hsl = iRgb2Hsl(rgb / 255);
	fprintf('%-14s %-14s [%3d %3d %3d]  %s  %5.0f %5.2f %5.2f %6.0f %6.2f\n', ...
		Spec{k, 1}, Spec{k, 2}, rgb, sprintf('#%02X%02X%02X', rgb), ...
		hsl(1), hsl(2), hsl(3), iGray(rgb), iContrastWhite(rgb));
end

%% 配对校验
Pairs = {
	'Naive vs Learned', 'ColorNaive', 'ColorLearned'
	'Hit vs Miss',      'ColorHit', 'ColorMiss'
	'12h vs TH',        'Color12h', 'ColorTH'
	'12h vs 7d',        'Color12h', 'Color7d'
	'TH vs 7d',         'ColorTH', 'Color7d'
	'Audio vs cFos',    'ColorAudio', 'ColorcFos'
	'Audio vs Light',   'ColorAudio', 'ColorLight'
	'Audio vs Hit',     'ColorAudio', 'ColorHit'
	'Light vs cFos',    'ColorLight', 'ColorcFos'
	'Learned vs 12h',   'ColorLearned', 'Color12h'
};
fprintf('\n%-18s %8s %8s %8s %8s\n', 'Pair', 'dHue', 'dGray', 'dE76', 'note');
for p = 1:size(Pairs, 1)
	iA = find(strcmp(Spec(:, 1), Pairs{p, 2}));
	iB = find(strcmp(Spec(:, 1), Pairs{p, 3}));
	hA = iRgb2Hsl(Rgb(iA, :)/255); hB = iRgb2Hsl(Rgb(iB, :)/255);
	dH = abs(hA(1) - hB(1)); dH = min(dH, 360 - dH);
	dG = abs(iGray(Rgb(iA, :)) - iGray(Rgb(iB, :)));
	dE = iDeltaE76(Rgb(iA, :), Rgb(iB, :));
	fprintf('%-18s %8.0f %8.0f %8.1f\n', Pairs{p, 1}, dH, dG, dE);
end

%% ===== 局部函数 =====
function rgb = iHsl2Rgb(h, s, l)
h = mod(h, 360) / 60;
c = (1 - abs(2 * l - 1)) * s;
x = c * (1 - abs(mod(h, 2) - 1));
m = l - c / 2;
switch floor(h)
	case 0, t = [c x 0];
	case 1, t = [x c 0];
	case 2, t = [0 c x];
	case 3, t = [0 x c];
	case 4, t = [x 0 c];
	otherwise, t = [c 0 x];
end
rgb = round((t + m) * 255);
end

function hsl = iRgb2Hsl(rgb)
mx = max(rgb); mn = min(rgb); L = (mx + mn) / 2; d = mx - mn;
if d == 0, H = 0; S = 0;
else
	S = d / (1 - abs(2 * L - 1));
	switch mx
		case rgb(1), H = 60 * mod((rgb(2) - rgb(3)) / d, 6);
		case rgb(2), H = 60 * ((rgb(3) - rgb(1)) / d + 2);
		otherwise,   H = 60 * ((rgb(1) - rgb(2)) / d + 4);
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
L1 = iLab(r1); L2 = iLab(r2);
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
fx = f(X); fy = f(Y); fz = f(Z);
lab = [116*fy - 16, 500*(fx - fy), 200*(fy - fz)];
end
