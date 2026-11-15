% 从 D:\yqn\R-C.jpg 抠出卡通小鼠(正面)，输出透明背景 SVG
% 思路: 黑色轮廓闭合 -> 从边框泛洪得背景 -> 前景=非背景; 再按灰度分层矢量化
% 输出 英文图\mouse_RC.svg
I = imread('D:\yqn\R-C.jpg');
[H, W] = size(rgb2gray(I));
G = rgb2gray(I);
G(1:85, 1:250) = 255;                 % 抹掉左上角水印区域(仅背景)

black = G < 95;
free  = ~black;
% 背景 = 与边框相连的 free 区域
lbl = bwlabel(free);
borderLbl = unique([lbl(1,:), lbl(end,:), lbl(:,1).', lbl(:,end).']);
borderLbl(borderLbl == 0) = [];
bg = ismember(lbl, borderLbl);

sil = ~bg;
sil = bwareaopen(sil, 5000);
CC = bwconncomp(sil);
[~, k] = max(cellfun(@numel, CC.PixelIdxList));
sil = false(H, W); sil(CC.PixelIdxList{k}) = true;
sil = imfill(sil, 'holes');

% ---------- 分层 ----------
L = G;
in = sil;
layers = {};
layers{1} = in & L >= 185 & L <= 228;   % 主体浅灰
layers{2} = in & L >= 229 & L <= 246;   % 耳内亮弧
layers{3} = in & L >= 110 & L < 185;    % 耳内深灰
layers{4} = in & L > 246;               % 眼高光
layers{5} = in & L < 95;                % 黑色轮廓/五官/胡须
cols = {'#cccccc', '#f0f0f0', '#8c8c8c', '#ffffff', '#111111'};

paths = {}; allP = [];
for k = 1:numel(layers)
	M = layers{k};
	M = bwareaopen(M, 30);
	Bl = bwboundaries(M);
	d = '';
	for j = 1:numel(Bl)
		Bd = reshape(double(Bl{j}), [], 2);
		if size(Bd,1) < 6, continue; end
		Q = iPrep(Bd, 5, 1, max(20, min(300, round(size(Bd,1)/6))));
		allP = [allP; Q]; %#ok<AGROW>
		d = [d, iBez(Q)]; %#ok<AGROW>
	end
	paths{k} = d; %#ok<SAGROW>
end

% ---------- 写 SVG ----------
x = allP(:,2); y = allP(:,1); pad = 2;
fid = fopen('D:\git\Transfer-Learning\英文图\mouse_RC.svg','w','n','UTF-8');
fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n');
fprintf(fid, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%.1f %.1f %.1f %.1f" version="1.1">\n', ...
	min(x)-pad, min(y)-pad, range(x)+2*pad, range(y)+2*pad);
fprintf(fid, '  <title>mouse head, vectorized (transparent background)</title>\n');
for k = 1:numel(paths)
	fprintf(fid, '  <path fill="%s" fill-rule="evenodd" stroke="none" d="%s"/>\n', cols{k}, paths{k});
end
fprintf(fid, '</svg>\n');
fclose(fid);
fprintf('layers=%d  viewBox=[%.0f %.0f %.0f %.0f]\n', numel(paths), min(x), min(y), range(x), range(y));

% ---------------- helpers ----------------
function P = iPrep(P, w, nPass, nOut)
n = size(P,1); prev = P([n 1:n-1], :);
d = sqrt(sum((P - prev).^2, 2)); P = P(d > 0, :);
if size(P,1) > 2*w
	for p = 1:nPass
		Q = P; kk = ones(w,1)/w;
		for it = 1:2
			v = P(:,it);
			vs = [v(end-floor(w/2)+1:end); v; v(1:floor(w/2))];
			sm = conv(vs, kk, 'same');
			Q(:,it) = sm(floor(w/2)+1 : floor(w/2)+size(P,1));
		end
		P = Q;
	end
end
P2 = [P; P(1,:)];
seg = sqrt(sum(diff(P2,1,1).^2, 2));
s = [0; cumsum(seg)];
t = linspace(0, s(end), nOut+1); t = t(:); t(end) = [];
xq = interp1(s, P2(:,1), t, 'linear');
yq = interp1(s, P2(:,2), t, 'linear');
P  = [xq(:), yq(:)];
end

function d = iBez(P)
P = reshape(P, [], 2);
n = size(P,1);
d = sprintf('M %.1f %.1f', P(1,2), P(1,1));
for i = 1:n
	p0 = P(i,:); p1 = P(mod(i,n)+1,:); pm = P(mod(i-2,n)+1,:); p2 = P(mod(i+1,n)+1,:);
	c1 = p0 + (p1 - pm)/6; c2 = p1 - (p2 - p0)/6;
	d = [d, sprintf(' C %.1f %.1f %.1f %.1f %.1f %.1f', c1(2),c1(1),c2(2),c2(1),p1(2),p1(1))];
end
d = [d, ' Z'];
end
