function values = Zeros(sz)
if isscalar(sz)
	sz = [sz, 1];
end
values = zeros(sz);
end
