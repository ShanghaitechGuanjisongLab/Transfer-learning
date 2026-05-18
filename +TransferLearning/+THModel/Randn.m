function values = Randn(sz)
if isscalar(sz)
	sz = [sz, 1];
end
values = randn(sz);
end
