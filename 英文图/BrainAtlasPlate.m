% 从 Paxinos 图谱页面 PNG 抠出黑白线稿(外轮廓+内部主轮廓)，透明背景 SVG
% 适用于同系列扫描页: 深色线稿 + 浅灰网格 + 页边刻度
% 用法: 改 inPath / outPath / 裁剪比例即可
inPath  = 'D:\yqn\全脑-玻片\全脑-玻片\小鼠脑图谱_页面_049.png';
outPath = 'D:\git\Transfer-Learning\英文图\brain_atlas_p049.svg';
cropX   = [0.055 0.960];      % 页面横向裁剪比例
cropY   = [0.115 0.900];      % 页面纵向裁剪比例
thr     = 130;                % 线稿灰度阈值(网格约200, 线稿<100)
minArea = 300;                % 去掉文字/虚线段
W0      = 2000;               % 工作分辨率宽度

% ---------- 读图 ----------
[A, map] = imread(inPath);
if isempty(map), G0 = im2uint8(A); else, G0 = im2uint8(ind2gray(A, map)); end
[nr, nc] = size(G0);
r0 = round(cropY(1)*nr) : round(cropY(2)*nr);
c0 = round(cropX(1)*nc) : round(cropX(2)*nc);
G  = imresize(G0(r0, c0), W0/numel(c0), 'bilinear');
G  = imgaussfilt(G, 1.2);
mAll = bwareaopen(G < thr, 50);
[H, W] = size(mAll);

% ---------- 脑片剪影(最大闭合轮廓填洞) ----------
mF = imfill(mAll, 'holes');
CC = bwconncomp(mF);
[~, k] = max(cellfun(@numel, CC.PixelIdxList));
M = false(H, W); M(CC.PixelIdxList{k}) = true;
M = imfill(M, 'holes');
M = imopen(M, strel('disk', 2));

% ---------- 保留"在脑内"的线稿连通域 ----------
CC = bwconncomp(mAll);
st = regionprops(CC, 'Area', 'Centroid', 'BoundingBox');
comps = {};
for k = 1:CC.NumObjects
	if st(k).Area < minArea, continue; end
	cy = round(st(k).Centroid(2)); cx = round(st(k).Centroid(1));
	cy = min(max(cy,1),H); cx = min(max(cx,1),W);
	if ~M(cy, cx), continue; end          % 只保留脑内的结构(排除插图/刻度/文字)
	E = false(H, W); E(CC.PixelIdxList{k}) = true;
	comps{end+1} = E; %#ok<SAGROW>
end

% ---------- 矢量化 ----------
paths = {}; allP = [];
for k = 1:numel(comps)
	Bl = bwboundaries(comps{k});
	d = '';
	for j = 1:numel(Bl)
		Bd = reshape(double(Bl{j}), [], 2);
		if size(Bd,1) < 6, continue; end
		Q = iPrep(Bd, 5, 1, max(20, min(300, round(size(Bd,1)/6))));
		allP = [allP; Q]; %#ok<AGROW>
		d = [d, iBez(Q)]; %#ok<AGROW>
	end
	paths{end+1} = d; %#ok<SAGROW>
end

% ---------- 写 SVG ----------
x = allP(:,2); y = allP(:,1); pad = 4;
fid = fopen(outPath,'w','n','UTF-8');
fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n');
fprintf(fid, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%.1f %.1f %.1f %.1f" version="1.1">\n', ...
	min(x)-pad, min(y)-pad, range(x)+2*pad, range(y)+2*pad);
fprintf(fid, '  <title>coronal section outline (transparent background)</title>\n');
fprintf(fid, '  <g fill="#111111" fill-rule="evenodd" stroke="none">\n');
for k = 1:numel(paths), fprintf(fid, '    <path d="%s"/>\n', paths{k}); end
fprintf(fid, '  </g>\n</svg>\n');
fclose(fid);
fprintf('comps kept=%d, viewBox=[%.0f %.0f %.0f %.0f]\n', numel(paths), min(x), min(y), range(x), range(y));

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
