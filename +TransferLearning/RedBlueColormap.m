function cmap = RedBlueColormap()
% 蓝-白-红发散色图（64 级）。
	n = 64; h = n/2;
	r = [linspace(0,1,h)'; ones(h,1)];
	g = [linspace(0,1,h)'; linspace(1,0,h)'];
	b = [ones(h,1); linspace(1,0,h)'];
	cmap = [r g b];
end
